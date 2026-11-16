#!/bin/zsh
# 复测上一轮有问题的几句，再加两句新句子。
DIR="${0:A:h}"
samples=(
  "帮我加个登录功能吧，用邮箱就行"
  "报错了 TypeError: Cannot read properties of undefined (reading 'map') at UserList.tsx:42 你看看"
  "我们那个agent现在调工具老是调错，就是它明明应该先查数据库的，它老是直接就回答了，你看看是不是提示词的问题"
  "上传图片的时候偶尔会失败，也没有报错，你处理一下"
  "为什么这个接口本地好好的，部署上去就500了"
)
for s in "${samples[@]}"; do
  echo "### 输入：$s"
  echo "### 输出："
  printf '%s' "$s" | "$DIR/polish.py"
  echo; echo
done
echo TEST_DONE
