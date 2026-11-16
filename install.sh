#!/bin/zsh
# 安装「优化提示词」：把脚本复制到 ~/prompt-polish，把快速操作装到 ~/Library/Services。
# 可重复运行；已有的 config.json 不会被覆盖。
# 卸载：删除 ~/prompt-polish 和 ~/Library/Services/优化提示词.workflow 即可。
set -e
SRC="${0:A:h}"
APP="$HOME/prompt-polish"
WF="$HOME/Library/Services/优化提示词.workflow"

mkdir -p "$APP"
cp "$SRC/polish.py" "$SRC/system-prompt.md" "$SRC/set-key.sh" "$APP/"
[[ -f "$APP/config.json" ]] || cp "$SRC/config.json" "$APP/"
chmod +x "$APP/polish.py" "$APP/set-key.sh"

mkdir -p "$WF/Contents"
cp "$SRC/service/Info.plist" "$SRC/service/document.wflow" "$WF/Contents/"

# 让系统重新读取服务列表
/System/Library/CoreServices/pbs -update 2>/dev/null || true

echo "已安装："
echo "  脚本  $APP"
echo "  服务  $WF"
