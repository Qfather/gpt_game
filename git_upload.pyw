
# -*- coding: utf-8 -*-

import os
import subprocess
import tkinter as tk
from tkinter import simpledialog, messagebox


# ============================================================
# 配置
# ============================================================

# True：上传成功后自动关闭
# False：最后保留结果弹窗
AUTO_CLOSE = False


# ============================================================
# Git 命令
# ============================================================

def run_git(args, timeout=60):
    """
    执行 Git 命令。
    返回：
        returncode, stdout, stderr
    """

    # pyw 双击启动时，将工作目录固定到脚本所在目录
    script_dir = os.path.dirname(os.path.abspath(__file__))

    try:
        result = subprocess.run(
            ["git"] + args,
            cwd=script_dir,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=timeout,
            creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0)
        )
    except FileNotFoundError:
        return 1, "", "找不到 git 命令，请先安装 Git 并加入 PATH。"
    except subprocess.TimeoutExpired:
        return 1, "", f"Git 命令执行超过 {timeout} 秒，可能是网络连接或认证等待超时。"

    return result.returncode, result.stdout.strip(), result.stderr.strip()


def get_git_value(args):
    code, out, err = run_git(args)
    if code != 0:
        return None, err or out
    return out, ""


def format_git_error(out, err):
    text = (out + "\n" + err).strip()
    lower_text = text.lower()

    if "couldn't connect" in lower_text or "failed to connect" in lower_text:
        return text + "\n\n请检查网络、代理或防火墙是否允许访问 github.com。"

    if "authentication failed" in lower_text or "invalid username or password" in lower_text:
        return text + "\n\nGitHub 登录凭据无效，请重新登录或更新 Token。"

    if "rejected" in lower_text or "non-fast-forward" in lower_text:
        return text + "\n\n远程仓库有本地没有的提交。请先手动执行 git pull --rebase，确认无冲突后再上传。"

    return text


# ============================================================
# 主程序
# ============================================================

def main():

    root = tk.Tk()
    root.withdraw()

    script_dir = os.path.dirname(os.path.abspath(__file__))

    # --------------------------------------------------------
    # 检查是不是 Git 仓库
    # --------------------------------------------------------

    code, out, err = run_git(["rev-parse", "--is-inside-work-tree"])

    if code != 0:
        messagebox.showerror(
            "Git 上传失败",
            "当前目录不是 Git 仓库：\n\n" + script_dir
        )
        return

    branch, err = get_git_value(["branch", "--show-current"])

    if not branch:
        messagebox.showerror(
            "Git 上传失败",
            "当前处于 detached HEAD 状态，无法自动确定上传分支。\n\n"
            + (err or "请先切换到 main 等正常分支。")
        )
        return

    remote, err = get_git_value(["remote", "get-url", "origin"])

    if not remote:
        messagebox.showerror(
            "Git 上传失败",
            "没有配置 origin 远程仓库。\n\n"
            "请先执行：\n"
            "git remote add origin <GitHub 仓库地址>"
        )
        return

    # --------------------------------------------------------
    # 输入提交日志
    # --------------------------------------------------------

    commit_message = simpledialog.askstring(
        "Git 自动上传",
        "请输入本次修改日志：",
        parent=root
    )

    if commit_message is None:
        return

    commit_message = commit_message.strip()

    if not commit_message:
        messagebox.showwarning(
            "提示",
            "提交日志不能为空。"
        )
        return

    # --------------------------------------------------------
    # git add .
    # --------------------------------------------------------

    code, out, err = run_git(["add", "."])

    if code != 0:
        messagebox.showerror(
            "git add 失败",
            err or out
        )
        return

    # --------------------------------------------------------
    # 检查是否真的有修改
    # --------------------------------------------------------

    code, out, err = run_git(["status", "--porcelain"])

    if code != 0:
        messagebox.showerror(
            "检查 Git 状态失败",
            err or out
        )
        return

    if not out:
        messagebox.showinfo(
            "Git",
            "没有检测到需要提交的修改。"
        )
        return

    # --------------------------------------------------------
    # git commit
    # --------------------------------------------------------

    code, out, err = run_git([
        "commit",
        "-m",
        commit_message
    ])

    if code != 0:
        messagebox.showerror(
            "git commit 失败",
            (out + "\n" + err).strip()
        )
        return

    commit_result = out

    # --------------------------------------------------------
    # git push
    # --------------------------------------------------------

    # 显式指定远程、分支并设置 upstream，避免首次上传时没有跟踪分支。
    code, out, err = run_git([
        "push",
        "--set-upstream",
        "origin",
        branch
    ], timeout=90)

    if code != 0:

        messagebox.showerror(
            "git push 失败",
            "Commit 已经创建成功，但 Push 失败。\n\n"
            "远程仓库：\n"
            + remote
            + "\n当前分支："
            + branch
            + "\n\n"
            "Git 返回信息：\n\n"
            + format_git_error(out, err)
        )

        return

    # --------------------------------------------------------
    # 完成
    # --------------------------------------------------------

    if not AUTO_CLOSE:
        messagebox.showinfo(
            "上传成功",
            "Git 上传完成！\n\n"
            "提交日志：\n"
            + commit_message
            + "\n\n"
            + commit_result
        )


if __name__ == "__main__":
    main()
