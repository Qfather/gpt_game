"""本地 Markdown 工作台。仅使用 Python 标准库；不读写游戏运行数据。"""
import argparse
import hashlib
import json
import mimetypes
import os
from pathlib import Path
import re
import secrets
import tempfile
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, unquote, urlsplit
import webbrowser

APP = Path(__file__).resolve().parent
DOCS = APP.parent
PROJECT = DOCS.parent
TOKEN = secrets.token_hex(24)
LOCK = threading.Lock()
PRIMARY = ("项目.md", "系统.md", "数据.md", "任务.md", "日志.md", "决策.md", "参考.md")


def confined(root, name):
    if not isinstance(name, str) or not name or "\\" in name:
        raise ValueError("文件路径无效")
    target = (root / name).resolve()
    if not target.is_relative_to(root.resolve()):
        raise ValueError("文件必须位于项目允许的目录内")
    return target


def md_path(name):
    path = confined(DOCS, name)
    if path.parent != DOCS or path.name not in PRIMARY:
        raise ValueError("只允许编辑七份主Markdown，归档资料只读")
    return path


def revision(raw):
    return hashlib.sha256(raw).hexdigest()


def metadata(content):
    meta = {}
    match = re.match(r"\A---\r?\n(.*?)\r?\n---(?:\r?\n|$)", content, re.S)
    if match:
        for line in match[1].splitlines():
            key, sep, value = line.partition(":")
            if sep and re.fullmatch(r"[a-z_]+", key.strip()):
                value = value.strip()
                try:
                    meta[key.strip()] = json.loads(value)
                except json.JSONDecodeError:
                    meta[key.strip()] = value
    return meta


def document(path):
    raw = path.read_bytes()
    content = raw.decode("utf-8-sig")
    meta = metadata(content)
    heading = re.search(r"^#\s+(.+)$", content, re.M)
    return {"path": path.relative_to(DOCS).as_posix(), "content": content,
            "revision": revision(raw), "meta": meta,
            "title": str(meta.get("title") or (heading[1].strip() if heading else path.stem)),
            "modified": path.stat().st_mtime}


def entry_spans(content):
    masked = re.sub(r"^```[\s\S]*?^```[^\n]*", lambda m: re.sub(r"[^\n]", " ", m[0]), content, flags=re.M)
    headings = list(re.finditer(r"^## [^\n]+", masked, re.M))
    for i, heading in enumerate(headings):
        match = re.fullmatch(r"## (.*?) \{#([a-z0-9-]+)\}\s*", heading[0])
        if not match:
            continue
        end = headings[i + 1].start() if i + 1 < len(headings) else len(content)
        chunk = content[heading.end():end]
        fields = re.match(r"\s*<!-- record\r?\n([\s\S]*?)\r?\n-->\s*", chunk)
        if fields:
            yield {"title": match[1], "anchor": match[2], "start": heading.start(), "end": end,
                   "fields": fields[1], "body": chunk[fields.end():]}


def entries(parent):
    result = []
    for item in entry_spans(parent["content"]):
        virtual = "---\n" + item["fields"] + "\n---\n\n# " + item["title"] + "\n\n" + re.sub(r"^(#{3,6}) ", lambda m: m[1][1:] + " ", item["body"], flags=re.M)
        result.append({**parent, "path": parent["path"] + "#" + item["anchor"], "file": parent["path"],
                       "anchor": item["anchor"], "title": item["title"], "content": virtual, "meta": metadata(virtual)})
    return result


def merge_entry(content, anchor, virtual):
    if not re.fullmatch(r"[a-z0-9-]+", anchor):
        raise ValueError("条目编号无效")
    match = re.match(r"---\r?\n([\s\S]*?)\r?\n---\s*\n# ([^\n]+)\n([\s\S]*)", virtual)
    if not match:
        raise ValueError("条目必须保留元数据和一级标题")
    current = next((e for e in entry_spans(content) if e["anchor"] == anchor), None)
    if current and metadata("---\n" + current["fields"] + "\n---\n").get("generated"):
        raise ValueError("配置快照条目只读，请依据游戏配置更新数据.md")
    body = re.sub(r"^(#{2,5}) ", lambda m: m[1] + "# ", match[3].strip(), flags=re.M)
    replacement = f"## {match[2]} {{#{anchor}}}\n\n<!-- record\n{match[1]}\n-->\n\n{body}\n\n"
    if current:
        return content[:current["start"]] + replacement + content[current["end"]:]
    return content.rstrip() + "\n\n" + replacement


class Handler(BaseHTTPRequestHandler):
    def reply(self, value, status=200):
        raw = json.dumps(value, ensure_ascii=False).encode("utf-8")
        self.send_bytes(raw, "application/json; charset=utf-8", status)

    def send_bytes(self, raw, mime, status=200):
        self.send_response(status)
        self.send_header("Content-Type", mime)
        self.send_header("Content-Length", str(len(raw)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Content-Security-Policy", "default-src 'self'; img-src 'self' data:; style-src 'self' 'unsafe-inline'; script-src 'self'; object-src 'none'; frame-ancestors 'none'")
        self.end_headers()
        self.wfile.write(raw)

    def valid_host(self):
        return self.headers.get("Host") == f"127.0.0.1:{self.server.server_port}"

    def do_GET(self):
        if not self.valid_host():
            return self.reply({"error": "请使用终端显示的本地地址"}, 403)
        url = urlsplit(self.path)
        try:
            if url.path == "/api/workspace":
                docs = [document(DOCS / name) for name in PRIMARY if (DOCS / name).is_file()]
                project_name = PROJECT.name
                readme = PROJECT / "README.md"
                if readme.is_file():
                    heading = re.search(r"^#\s+(.+)$", readme.read_text(encoding="utf-8-sig"), re.M)
                    if heading:
                        project_name = heading[1].strip()
                return self.reply({"name": project_name, "documents": docs, "entries": [e for d in docs for e in entries(d)], "token": TOKEN})
            if url.path == "/api/archive":
                return self.reply({"documents": [{**document(p), "readonly": True} for p in sorted((DOCS / "归档").rglob("*.md")) if p.resolve().is_relative_to(DOCS / "归档")]})
            if url.path == "/api/source":
                name = parse_qs(url.query).get("path", [""])[0]
                path = confined(PROJECT, name)
                if path.suffix.lower() not in {".md", ".gd", ".tres", ".tscn"}:
                    raise ValueError("此类型不提供源码预览")
                return self.reply({"path": name, "content": path.read_text(encoding="utf-8-sig")})
            asset = {"/": "index.html", "/index.html": "index.html", "/app.js": "app.js", "/style.css": "style.css"}.get(url.path)
            if not asset:
                return self.reply({"error": "页面不存在"}, 404)
            mime = mimetypes.guess_type(asset)[0] or "text/plain"
            self.send_bytes((APP / asset).read_bytes(), mime + "; charset=utf-8")
        except FileNotFoundError:
            self.reply({"error": "文件不存在，可能已被移动；请刷新资料"}, 404)
        except (ValueError, UnicodeError) as exc:
            self.reply({"error": str(exc)}, 400)
        except OSError as exc:
            self.reply({"error": f"无法读取文件：{exc}"}, 500)

    def do_POST(self):
        origin = f"http://127.0.0.1:{self.server.server_port}"
        if (not self.valid_host() or self.headers.get("Origin") not in (None, origin)
                or self.headers.get("X-Workbench-Token") != TOKEN):
            return self.reply({"error": "保存请求来源无效，请刷新工作台"}, 403)
        if self.path != "/api/save":
            return self.reply({"error": "接口不存在"}, 404)
        try:
            size = int(self.headers.get("Content-Length", "0"))
            if size < 1 or size > 4 * 1024 * 1024:
                raise ValueError("文档大小必须在4MB以内")
            body = json.loads(self.rfile.read(size))
            if not isinstance(body, dict):
                raise ValueError("保存请求格式无效")
            name = body.get("path")
            if not isinstance(name, str):
                raise ValueError("文件路径无效")
            filename, _, anchor = name.partition("#")
            path = md_path(filename)
            text = body.get("content")
            if not isinstance(text, str):
                raise ValueError("文档内容无效")
            with LOCK:
                old = path.read_bytes() if path.exists() else None
                expected = body.get("revision")
                if (revision(old) if old is not None else None) != expected:
                    return self.reply({"error": "文件已被外部修改。你的草稿仍保留，请查看最新原文并手动合并。", "current": document(path) if path.exists() else None}, 409)
                if anchor:
                    text = merge_entry(old.decode("utf-8-sig") if old is not None else "# " + path.stem + "\n", anchor, text)
                if old is not None:
                    backup = APP / ".history" / path.relative_to(DOCS) / (revision(old) + ".bak")
                    backup.parent.mkdir(parents=True, exist_ok=True)
                    backup.write_bytes(old)
                path.parent.mkdir(parents=True, exist_ok=True)
                temp = None
                try:
                    with tempfile.NamedTemporaryFile(dir=path.parent, prefix=".workbench-", suffix=".tmp", delete=False) as output:
                        temp = Path(output.name)
                        output.write(text.encode("utf-8"))
                    os.replace(temp, path)
                finally:
                    if temp and temp.exists():
                        temp.unlink()
                parent = document(path)
                self.reply(next((e for e in entries(parent) if e["anchor"] == anchor), parent))
        except (ValueError, UnicodeError) as exc:
            self.reply({"error": str(exc)}, 400)
        except OSError as exc:
            self.reply({"error": f"保存失败，草稿保留：{exc}"}, 500)

    def log_message(self, fmt, *args):
        print(fmt % args)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="启动本地 Markdown 工作台")
    parser.add_argument("--port", type=int, default=0)
    parser.add_argument("--no-open", action="store_true")
    args = parser.parse_args()
    with ThreadingHTTPServer(("127.0.0.1", args.port), Handler) as server:
        url = f"http://127.0.0.1:{server.server_port}"
        print(f"\n项目知识工作台：{url}\n资料目录：{DOCS}\n关闭本窗口或按 Ctrl+C 停止。\n", flush=True)
        if not args.no_open:
            threading.Timer(0.5, lambda: webbrowser.open(url)).start()
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            print("工作台已停止。")
