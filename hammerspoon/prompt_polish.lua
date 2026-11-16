-- ===========================================================
-- 提示词优化：快速连按四下空格，把当前输入框里的全部文字
-- 交给 ~/prompt-polish/polish.py 改写，再原地替换。
--   · 替换后按 ⌘Z 可以撤销。
--   · 正常情况下不弹任何提示；只有失败时才提示一下，原文不会被改动。
--   · 下面 EXCLUDE 里的应用不触发。
-- ===========================================================

local M = {}

local HOME       = os.getenv("HOME")
local SCRIPT     = HOME .. "/prompt-polish/polish.py"
local LOG_FILE   = HOME .. "/prompt-polish/hs.log"

local TAPS       = 4       -- 连按几下空格触发
local TAP_GAP    = 0.35    -- 相邻两下空格间隔小于这个秒数才算连按
local MIN_CHARS  = 8       -- 少于这个字数不处理（“OK”“好的”这类没什么可优化的）
local MAX_CHARS  = 4000    -- 超过这个字数不处理，避免误把整篇文档送去改写
local SPACE      = 49      -- 空格键的键码

-- 在这些应用里连按空格不触发（终端里全选会把整屏内容都选上）
local EXCLUDE = {
  ["com.apple.Terminal"]    = true,
  ["com.googlecode.iterm2"] = true,
  ["com.apple.finder"]      = true,
}

local busy       = false
local lastSpace  = 0
local spaceCount = 0

local function log(msg)
  local f = io.open(LOG_FILE, "a")
  if f then f:write(os.date("%m-%d %H:%M:%S ") .. msg .. "\n"); f:close() end
end

local function restoreClipboard(saved)
  if saved and next(saved) then
    hs.pasteboard.writeAllData(saved)
  else
    hs.pasteboard.clearContents()
  end
end

-- 取消全选，把光标放回文字末尾
local function deselect()
  hs.eventtap.keyStroke({}, "right", 0)
end

local function finish(saved, message)
  restoreClipboard(saved)
  busy = false
  if message then hs.alert.show(message, 1.6) end
end

local function polish(text, app, saved)
  M.task = hs.task.new("/usr/bin/python3", function(code, out, err)
    out = (out or ""):gsub("%s+$", "")

    if code ~= 0 or out == "" or (err and err ~= "") then
      log("失败: " .. tostring(err))
      deselect()
      finish(saved, "优化失败，原文未改动")
      return
    end
    if out == text then
      deselect()
      finish(saved, nil)
      return
    end

    local front = hs.application.frontmostApplication()
    if not front or not app or front:pid() ~= app:pid() then
      -- 等待期间切到了别的应用：不乱贴，把结果留在剪贴板
      hs.pasteboard.setContents(out)
      busy = false
      hs.alert.show("已优化，结果在剪贴板里（⌘V 粘贴）", 2.5)
      return
    end

    hs.pasteboard.setContents(out)
    hs.eventtap.keyStroke({ "cmd" }, "a", 0)
    hs.eventtap.keyStroke({ "cmd" }, "v", 0)
    M.restoreTimer = hs.timer.doAfter(0.5, function()
      finish(saved, nil)
    end)
    log("完成: " .. utf8.len(text) .. " 字 → " .. (utf8.len(out) or #out) .. " 字")
  end, { SCRIPT })
  M.task:setInput(text)
  M.task:start()
end

local function run()
  if busy then return end
  local app = hs.application.frontmostApplication()
  if app and EXCLUDE[app:bundleID() or ""] then return end
  busy = true

  -- 借用剪贴板取出输入框里的全部文字，之后会还原剪贴板原有内容
  local saved = hs.pasteboard.readAllData()
  hs.pasteboard.clearContents()
  local before = hs.pasteboard.changeCount()
  hs.eventtap.keyStroke({ "cmd" }, "a", 0)
  hs.eventtap.keyStroke({ "cmd" }, "c", 0)

  local tries = 0
  M.waiter = hs.timer.doEvery(0.05, function()
    tries = tries + 1
    if hs.pasteboard.changeCount() == before and tries < 14 then return end
    M.waiter:stop()

    local text = hs.pasteboard.getContents() or ""
    text = text:gsub("%s+$", "")
    if text == "" then
      deselect()
      finish(saved, "没有取到文字")
      return
    end
    if (utf8.len(text) or #text) < MIN_CHARS then
      -- 太短的内容没什么可优化的，多半是误触：不改动，也不打扰
      deselect()
      finish(saved, nil)
      return
    end
    if (utf8.len(text) or #text) > MAX_CHARS then
      deselect()
      finish(saved, "文字超过 " .. MAX_CHARS .. " 字，未处理")
      return
    end
    polish(text, app, saved)
  end)
end

M.tap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(ev)
  if ev:getKeyCode() ~= SPACE then spaceCount = 0; return false end
  local f = ev:getFlags()
  if f.cmd or f.alt or f.ctrl or f.shift or f.fn then spaceCount = 0; return false end
  -- 按住空格不放产生的重复不算
  if ev:getProperty(hs.eventtap.event.properties.keyboardEventAutorepeat) ~= 0 then
    spaceCount = 0
    return false
  end

  local now = hs.timer.secondsSinceEpoch()
  if now - lastSpace < TAP_GAP then
    spaceCount = spaceCount + 1
  else
    spaceCount = 1
  end
  lastSpace = now

  if spaceCount >= TAPS then
    spaceCount = 0
    lastSpace = 0
    if not busy then
      M.startTimer = hs.timer.doAfter(0.05, function()
        -- 删掉前面已经打出来的几个空格，再开始优化
        for _ = 1, TAPS - 1 do hs.eventtap.keyStroke({}, "delete", 0) end
        M.runTimer = hs.timer.doAfter(0.08, run)
      end)
    end
    return true   -- 吞掉最后一下空格
  end
  return false
end)
M.tap:start()

log("已加载：连按四下空格优化提示词")
return M
