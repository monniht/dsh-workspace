#!/usr/bin/env python3
"""DSH 会话清理工具 - 交互式删除无用会话，删除前自动备份"""

import os
import shutil
from datetime import datetime

SESSIONS_DIR = r"C:\Users\LENOVO\.dsh\sessions\--D-deepseek-~5DE5~4F5C~533A--"
BACKUP_ROOT = r"D:\deepseek\sessions-backup"

def get_size(path):
    total = 0
    for root, _, files in os.walk(path):
        for f in files:
            fp = os.path.join(root, f)
            total += os.path.getsize(fp)
    return total

def main():
    print("=" * 60)
    print("DSH 会话清理工具")
    print("=" * 60)
    print(f"会话目录: {SESSIONS_DIR}")
    print()

    if not os.path.isdir(SESSIONS_DIR):
        print(f"目录不存在: {SESSIONS_DIR}")
        return

    sessions = sorted(
        [d for d in os.listdir(SESSIONS_DIR) if os.path.isdir(os.path.join(SESSIONS_DIR, d))],
        key=lambda x: os.path.getmtime(os.path.join(SESSIONS_DIR, x)),
        reverse=True
    )

    if not sessions:
        print("没有找到会话文件夹。")
        return

    print(f"找到 {len(sessions)} 个会话：\n")
    items = []
    for i, name in enumerate(sessions, 1):
        path = os.path.join(SESSIONS_DIR, name)
        size = get_size(path)
        size_mb = round(size / (1024 * 1024), 2)
        mtime = datetime.fromtimestamp(os.path.getmtime(path)).strftime("%Y-%m-%d %H:%M")
        items.append({"index": i, "name": name, "size_mb": size_mb, "mtime": mtime, "path": path})
        print(f"  [{i:2}] {name:<45} {size_mb:>8} MB  {mtime}")

    print()
    choice = input("请输入要删除的会话编号（多个用逗号分隔，如 1,3,5），输入 q 退出：").strip()

    if choice.lower() == 'q':
        print("已取消。")
        return

    indices = []
    for part in choice.split(','):
        part = part.strip()
        if part.isdigit():
            idx = int(part)
            if 1 <= idx <= len(items):
                indices.append(idx)
            else:
                print(f"编号 {idx} 无效，跳过。")
        else:
            print(f"无效输入: {part}")

    if not indices:
        print("没有有效的删除目标。")
        return

    to_delete = [items[i - 1] for i in indices]
    print()
    print("即将删除以下会话：")
    for d in to_delete:
        print(f"  - {d['name']} ({d['size_mb']} MB, {d['mtime']})")

    confirm = input("确认删除？(y/N): ").strip()
    if confirm.lower() != 'y':
        print("已取消。")
        return

    # 备份
    os.makedirs(BACKUP_ROOT, exist_ok=True)
    backup_sub = os.path.join(BACKUP_ROOT, "backup-" + datetime.now().strftime("%Y%m%d-%H%M%S"))
    os.makedirs(backup_sub, exist_ok=True)

    for d in to_delete:
        dest = os.path.join(backup_sub, d["name"])
        shutil.copytree(d["path"], dest)
        print(f"已备份: {d['name']}")
        shutil.rmtree(d["path"])
        print(f"已删除: {d['name']}")

    print()
    print(f"完成！备份保存在: {backup_sub}")
    print("如需恢复，将备份文件夹复制回 sessions 目录即可。")

if __name__ == "__main__":
    main()
