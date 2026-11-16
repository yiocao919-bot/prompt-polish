#!/bin/zsh
# 用 Vibe Coding 场景的样例测试 polish.py，打印输出和耗时。
# 这些样例都没有出现在 system-prompt.md 的例子里，用来看指令能否举一反三。
DIR="${0:A:h}"

samples=(
  "这个页面在手机上显示不太对，按钮都挤在一起了，你调一下"
  "帮我加个登录功能吧，用邮箱就行"
  "报错了 TypeError: Cannot read properties of undefined (reading 'map') at UserList.tsx:42 你看看"
  "我想做一个小工具，可以把会议录音转成文字然后总结，你觉得怎么做比较好"
  "把这个组件重构一下，太乱了"
  "这个RAG的召回效果不太好，用户问产品价格它老是找不到"
  "我们那个agent现在调工具老是调错，就是它明明应该先查数据库的，它老是直接就回答了，你看看是不是提示词的问题"
  "测试挂了，修一下"
  "可以，按你说的方案二来"
  "make the dashboard look more modern"
)

for s in "${samples[@]}"; do
  t0=$(date +%s)
  echo "### 输入：$s"
  echo "### 输出："
  printf '%s' "$s" | "$DIR/polish.py"
  echo
  echo "--- 用时 $(( $(date +%s) - t0 )) 秒"
  echo
done
echo TEST_DONE
