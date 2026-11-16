#!/bin/zsh
# 弹出系统对话框让你粘贴密钥，存进 macOS 钥匙串。密钥不会显示，也不会写进任何文件。
# 用法：./set-key.sh [服务商名]   默认 deepseek

provider="${1:-deepseek}"

key="$(/usr/bin/osascript <<EOF
try
  set r to display dialog "粘贴 ${provider} 的 API 密钥，然后点“保存”。" default answer "" with hidden answer buttons {"取消", "保存"} default button "保存" with title "提示词优化"
  return text returned of r
on error
  return ""
end try
EOF
)"

# 去掉首尾空白和换行
key="${key//[[:space:]]/}"

if [[ -z "$key" ]]; then
  echo "没有保存：输入为空或已取消。"
  exit 1
fi

/usr/bin/security add-generic-password -U -s prompt-polish -a "$provider" -w "$key" || {
  echo "保存失败。"
  exit 1
}
echo "已保存 ${provider} 的密钥，长度 ${#key} 个字符。"
