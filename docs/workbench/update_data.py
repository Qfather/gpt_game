"""收工时按需运行：只读工程配置，更新数据.md的指定快照区。"""
from datetime import date
import hashlib
import json
from pathlib import Path
import re

DOCS = Path(__file__).resolve().parent.parent
ROOT = DOCS.parent
BEGIN = "<!-- 配置快照开始 -->"
END = "<!-- 配置快照结束 -->"
CLASSES = {}
for path in (ROOT / "Script").rglob("*.gd"):
    match = re.search(r"^class_name\s+(\w+)", path.read_text(encoding="utf-8-sig"), re.M)
    if match:
        CLASSES[match[1]] = path


def scalar(value):
    value = value.strip().removeprefix("&")
    try:
        return json.loads(value)
    except (ValueError, TypeError):
        return value


def defaults(path, seen=None):
    seen = set() if seen is None else seen
    if not path or path in seen or not path.is_file():
        return {}
    seen.add(path)
    content = path.read_text(encoding="utf-8-sig")
    parent = re.search(r"^extends\s+(\w+)", content, re.M)
    result = defaults(CLASSES.get(parent[1]) if parent else None, seen)
    for line in content.splitlines():
        match = re.match(r"@export\w*(?:\([^\n]*\))?\s+var\s+(\w+)[^=\n]*=\s*(.*)", line)
        if match:
            result[match[1]] = match[2].rstrip(":").strip()
    return result


def properties(text):
    return {m[1]: m[2].strip() for m in re.finditer(r"^(\w+) = ([\s\S]*?)(?=^\w+ = |\Z)", text, re.M)}


def table(values, supplied=None):
    lines = ["| 字段 | 配置值 | 来源 |", "| --- | --- | --- |"]
    for key, value in values.items():
        shown = value.replace("\n", " ").replace("|", "\\|").replace("`", "'")
        lines.append(f"| `{key}` | `{shown}` | {'资源显式值' if supplied is None or key in supplied else '脚本导出默认值'} |")
    return "\n".join(lines)


def snapshot():
    entries = []
    for path in sorted((ROOT / "data").rglob("*.tres")):
        raw = path.read_text(encoding="utf-8-sig")
        main = re.search(r"^\[resource\]\s*\n([\s\S]*)", raw, re.M)
        if not main:
            continue
        ext = {m[2]: m[1].removeprefix("res://") for m in re.finditer(r'^\[ext_resource [^\n]*path="([^"]+)"[^\n]*id="([^"]+)"\]', raw, re.M)}
        supplied = properties(main[1])
        script_id = re.fullmatch(r'ExtResource\("([^"]+)"\)', supplied.get("script", ""))
        script = ROOT / ext[script_id[1]] if script_id and script_id[1] in ext else None
        values = defaults(script)
        values.update(supplied)
        category = path.relative_to(ROOT / "data").parts[0]
        kind = {"units": "unit", "enemies": "unit", "buildings": "building", "resources": "resource", "traits": "tag", "abilities": "ability"}.get(category, "config")
        ident = str(scalar(values.get("id", values.get("ability_id", values.get("trait_id", '""')))))
        slug = ident or path.relative_to(ROOT / "data").with_suffix("").as_posix()
        anchor = kind + "-" + re.sub(r"[^a-z0-9]+", "-", slug.lower()).strip("-")
        if any(x["anchor"] == anchor for x in entries):
            anchor += "-" + hashlib.sha256(path.relative_to(ROOT).as_posix().encode()).hexdigest()[:6]
        title = str(scalar(values.get("display_name", '""'))) or path.stem
        if category == "enemies":
            title += "（" + {"raid": "袭扰", "rift": "裂缝"}.get(path.parent.name, path.parent.name) + "）"
        meta = {"kind": kind, "title": title, "checked": str(date.today()), "generated": True, "category": category, "source": path.relative_to(ROOT).as_posix()}
        if kind == "unit" and script and script.name in {"unit_data.gd", "enemy_data.gd"}:
            for field, key in {"health": "max_health", "attack": "damage", "attack_interval": "attack_interval", "attack_range": "attack_range", "move_speed": "move_speed"}.items():
                number = scalar(values.get(key, "null"))
                if isinstance(number, (int, float)) and not isinstance(number, bool):
                    meta[field] = number
            meta["unit_id"] = ident
            meta["role"] = "敌方单位" if category == "enemies" else {0: "非军事／自卫", 1: "近战士兵", 2: "远程士兵", 3: "民兵"}.get(scalar(values.get("combat_role", "0")), "待核对")
        sections = []
        for m in re.finditer(r'^\[sub_resource ([^\n]+)\]\s*\n([\s\S]*?)(?=^\[(?:sub_resource|resource)|\Z)', raw, re.M):
            props = properties(m[2])
            sid = re.fullmatch(r'ExtResource\("([^"]+)"\)', props.get("script", ""))
            sub_script = ROOT / ext[sid[1]] if sid and sid[1] in ext else None
            merged = defaults(sub_script)
            merged.update(props)
            sections.append((m[1], merged, props))
        entries.append({"path": path, "anchor": anchor, "title": title, "meta": meta, "ext": ext, "values": values, "supplied": supplied, "subs": sections})
    index = {e["path"].relative_to(ROOT).as_posix(): e for e in entries}
    unit_index = {e["meta"].get("unit_id"): e for e in entries if e["meta"].get("category") == "units"}
    output = [f"快照核对：{date.today()}。覆盖工程 `data/**/*.tres` 中 {len(entries)} 份配置资源。只读静态配置，不计算运行时修正；未解释的表达式保留原值，不执行GDScript。\n"]
    for e in entries:
        meta = "\n".join(f"{k}: {json.dumps(v, ensure_ascii=False)}" for k, v in e["meta"].items())
        output.append(f"## {e['title']} {{#{e['anchor']}}}\n\n<!-- record\n{meta}\n-->\n\n来源：[{e['meta']['source']}](../{e['meta']['source']})。\n\n" + table(e["values"], e["supplied"]))
        links = set()
        for value in e["ext"].values():
            if value in index and value != e["meta"]["source"]:
                target = index[value]
                links.add((target["title"], target["anchor"]))
        parent_id = scalar(e["values"].get("upgrade_from_id", '""'))
        for candidate in entries:
            if candidate["meta"]["kind"] == "building" and scalar(candidate["values"].get("id", '""')) == parent_id and parent_id:
                links.add((candidate["title"], candidate["anchor"]))
        for name, merged, supplied in e["subs"]:
            output.append("### 子资源 " + name.replace('"', '') + "\n\n" + table(merged, supplied))
            unit_id = scalar(merged.get("unit_id", '""'))
            if unit_id in unit_index:
                target = unit_index[unit_id]
                links.add((target["title"], target["anchor"]))
        if links:
            output.append("### 关联\n\n" + " · ".join(f"[{title}](#{anchor})" for title, anchor in sorted(links)))
        if e["meta"]["kind"] == "unit":
            if e["meta"].get("category") == "units":
                role = scalar(e["values"].get("combat_role", "0"))
                duties = []
                if role in (1, 2, 3):
                    duties.append("[主动迎战](#tag-engage)")
                if role in (1, 3):
                    duties.append("[近战](#tag-melee)")
                for owner in entries:
                    if owner["meta"]["kind"] == "building" and any(scalar(sub[1].get("unit_id", '""')) == e["meta"].get("unit_id") for sub in owner["subs"]):
                        duties.append(f"[{owner['title']}](#{owner['anchor']})")
                if duties:
                    output.append("### 职责与训练\n\n" + " · ".join(duties))
            output.append("[战斗规则](系统.md#system-combat)。基础数值不包含特性、增益、实际命中或运行实例状态。")
    return "\n\n".join(output) + "\n"


def update():
    path = DOCS / "数据.md"
    generated = snapshot()
    initial = "# 游戏数据\n\n数据来自工程配置。快照区由收工更新维护，手工说明写在末尾；在网页中编辑MD不会修改Godot配置。\n\n" + BEGIN + "\n" + END + "\n\n## 手工说明\n\n暂无补充。\n"
    original = path.read_bytes() if path.exists() else None
    existing = original.decode("utf-8-sig") if original is not None else initial
    pattern = re.compile(re.escape(BEGIN) + r"[\s\S]*?" + re.escape(END))
    if len(pattern.findall(existing)) != 1:
        raise ValueError("数据.md必须有且只有一对快照边界，未写入，请先检查原文")
    updated = pattern.sub(lambda _: BEGIN + "\n\n" + generated + "\n" + END, existing)
    if updated != existing:
        if (path.read_bytes() if path.exists() else None) != original:
            raise ValueError("数据.md在更新期间被外部修改，未覆盖；请重新读取后更新")
        # 与WebUI使用同一备份规则，保留覆盖前原文。
        if original is not None:
            backup = DOCS / "workbench/.history/数据.md" / (hashlib.sha256(original).hexdigest() + ".bak")
            backup.parent.mkdir(parents=True, exist_ok=True)
            backup.write_bytes(original)
        from server import LOCK
        with LOCK:
            import os
            import tempfile
            temporary = None
            try:
                with tempfile.NamedTemporaryFile(dir=DOCS, prefix=".workbench-", suffix=".tmp", delete=False) as stream:
                    temporary = Path(stream.name)
                    stream.write(updated.encode("utf-8"))
                if (path.read_bytes() if path.exists() else None) != original:
                    raise ValueError("数据.md在更新期间被外部修改，未覆盖")
                os.replace(temporary, path)
            finally:
                if temporary and temporary.exists():
                    temporary.unlink()
    print(f"数据快照已更新：{path}")


if __name__ == "__main__":
    update()
