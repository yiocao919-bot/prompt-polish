#!/bin/zsh
# 不经过快捷键，直接让系统运行已安装的「优化提示词」服务，验证它能工作。
WF="$HOME/Library/Services/优化提示词.workflow"
echo "### 通过系统服务运行，输入：fix the login bug, users say it sometimes logs them out randomly"
t0=$(date +%s)
/usr/bin/automator -i "fix the login bug, users say it sometimes logs them out randomly" "$WF"
echo "--- 用时 $(( $(date +%s) - t0 )) 秒，退出码 $?"
echo "### 输入：帮我写个周报"
/usr/bin/automator -i "帮我写个周报" "$WF"
echo SERVICE_TEST_DONE
