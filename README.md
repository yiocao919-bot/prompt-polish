# prompt-polish 提示词优化

在 Mac 上任何输入框里写完一段要发给 AI 的话，**快速连按四下空格**，这段话就会被改写得更完整、更清楚，然后原地替换。按 ⌘Z 可以撤销。

改写时只把你没说完的意思补全：前因后果、你想要什么、为什么要做、期望的结果。它不会替你做决定，也不会给每句话都加一堆流程要求。改写指令是为 Vibe Coding 场景写的，也就是跟 Claude Code、Codex、Cursor 这类 AI 编程助手对话。

例子：

> 这个页面在手机上显示不太对，按钮都挤在一起了，你调一下

↓

> 这个页面在手机上显示不太对，按钮都挤在一起了，看着乱，也不太好点。你调一下手机上的布局，让按钮之间排开、留出间距，在小屏幕上也能看清、点准。

## 工作原理

- `hammerspoon/prompt_polish.lua`：用 [Hammerspoon](https://www.hammerspoon.org/) 监听键盘。检测到连按四下空格后，借用剪贴板取出输入框里的全部文字，交给 `polish.py` 改写，再贴回去，最后还原剪贴板原来的内容。终端和 Finder 里不触发。
- `polish.py`：从标准输入读入原文，调用大模型 API，输出改写结果。任何环节出错都原样输出原文，所以不会把你的文字弄丢。
- `system-prompt.md`：改写指令，想调整改写风格就改这个文件，保存后立即生效。
- `config.json`：选用哪家模型。默认是 DeepSeek（`deepseek-flash`），也可以换成 OpenAI 或本机的 Codex CLI。
- `service/`：一个 macOS「服务」（快速操作），可以在右键菜单 → 服务里手动运行，可选。

## 安装

需要 macOS 和系统自带的 `/usr/bin/python3`。

1. 安装脚本和系统服务：

   ```bash
   ./install.sh
   ```

   脚本装到 `~/prompt-polish`，服务装到 `~/Library/Services/优化提示词.workflow`。

2. 把 API 密钥存进 macOS 钥匙串（会弹出一个对话框让你粘贴，密钥不会写进任何文件）：

   ```bash
   ~/prompt-polish/set-key.sh deepseek
   ```

3. 测试一下：

   ```bash
   echo "帮我把这个按钮改成蓝色" | ~/prompt-polish/polish.py
   ```

4. 启用连按空格：安装 Hammerspoon 并给它「辅助功能」权限，然后执行

   ```bash
   cp hammerspoon/prompt_polish.lua ~/.hammerspoon/
   ```

   在 `~/.hammerspoon/init.lua` 末尾加一行：

   ```lua
   require("prompt_polish")
   ```

   最后在 Hammerspoon 菜单里点「Reload Config」。

## 调整

- 连按几下、间隔多久：改 `prompt_polish.lua` 开头的 `TAPS` 和 `TAP_GAP`。
- 最少、最多处理多少字：改 `MIN_CHARS`（默认 8）和 `MAX_CHARS`（默认 4000）。
- 换模型：改 `~/prompt-polish/config.json` 里的 `provider`。用 OpenAI 的话，先运行 `set-key.sh openai` 存好密钥。
- 出问题时看日志：`~/prompt-polish/hs.log`。

## 卸载

删除 `~/prompt-polish`、`~/Library/Services/优化提示词.workflow` 和 `~/.hammerspoon/prompt_polish.lua`，再去掉 `init.lua` 里那行 `require`。钥匙串里的密钥可以用下面的命令删掉：

```bash
security delete-generic-password -s prompt-polish -a deepseek
```
