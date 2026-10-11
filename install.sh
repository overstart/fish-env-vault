#!/usr/bin/env sh
# 手动安装（不使用 fisher）：软链 CLI 与插件到 ~/.config/fish。
set -eu

SRC=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DST="$HOME/.config/fish"

mkdir -p "$DST/bin"
for b in "$SRC"/bin/*; do
    ln -sf "$b" "$DST/bin/$(basename "$b")"
done

for d in conf.d functions completions; do
    mkdir -p "$DST/$d"
    for f in "$SRC"/$d/*.fish; do
        ln -sf "$f" "$DST/$d/$(basename "$f")"
    done
done

echo "已安装到 $DST"
echo "若命令不可用，在 fish 中执行: fish_add_path $DST/bin"
