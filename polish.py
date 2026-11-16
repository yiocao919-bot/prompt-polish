#!/usr/bin/python3
"""提示词优化：从标准输入读原始文字，向标准输出写优化后的提示词。

config.json 里选服务商，有两种接法：
  - codex：调用本机的 Codex 命令行，用 ChatGPT 账号登录，不需要密钥，每次约 10 秒。
  - 接口：调用兼容 OpenAI 聊天接口的服务（OpenAI、DeepSeek 等），密钥从 macOS 钥匙串读取。
任何一步失败都原样输出原文，保证选中的文字不会被弄丢；失败原因写到标准错误。

用法：
  echo "帮我写个周报" | ./polish.py
  ./polish.py --check        检查配置，并做一次真实调用
"""
import json
import os
import subprocess
import sys
import tempfile
import urllib.error
import urllib.request

DIR = os.path.dirname(os.path.abspath(__file__))
KEYCHAIN_SERVICE = "prompt-polish"


class PolishError(Exception):
    pass


def load_config():
    try:
        with open(os.path.join(DIR, "config.json"), encoding="utf-8") as f:
            cfg = json.load(f)
        name = cfg["provider"]
        provider = cfg["providers"][name]
    except (OSError, ValueError, KeyError) as e:
        raise PolishError("config.json 读取失败或缺少字段：%r" % e)
    return name, provider, cfg.get("timeout_seconds", 60)


def load_system_prompt():
    with open(os.path.join(DIR, "system-prompt.md"), encoding="utf-8") as f:
        return f.read()


def wrap(raw):
    return "<raw>\n%s\n</raw>" % raw


def load_key(provider_name):
    key = os.environ.get("POLISH_API_KEY")
    if key:
        return key.strip()
    result = subprocess.run(
        ["/usr/bin/security", "find-generic-password",
         "-s", KEYCHAIN_SERVICE, "-a", provider_name, "-w"],
        capture_output=True, text=True,
    )
    key = result.stdout.strip()
    if result.returncode == 0 and not key:
        raise PolishError(
            "钥匙串里 %s 的密钥是空的，请运行 set-key.sh 重新保存。" % provider_name
        )
    if result.returncode != 0:
        raise PolishError(
            "钥匙串里没有找到 %s 的密钥（服务名 %s）。" % (provider_name, KEYCHAIN_SERVICE)
        )
    return key


def polish_with_codex(raw, provider, timeout):
    binary = os.path.expanduser(provider.get("bin") or "codex")
    if not os.path.exists(binary):
        raise PolishError("找不到 Codex 命令行：%s" % binary)

    # 在空目录里运行，只读沙箱，不加载用户配置和插件，不留会话记录
    with tempfile.TemporaryDirectory() as workdir:
        out_path = os.path.join(workdir, "out.txt")
        cmd = [
            binary, "exec",
            "--skip-git-repo-check", "--ephemeral",
            "--ignore-user-config", "--ignore-rules",
            "-s", "read-only", "--color", "never",
            "--disable", "plugins", "--disable", "remote_plugin",
            "--disable", "apps", "--disable", "memories",
            "-c", 'model_reasoning_effort="%s"' % provider.get("effort", "low"),
            "-o", out_path,
        ]
        if provider.get("model"):
            cmd += ["-m", provider["model"]]
        cmd.append("-")

        # 快捷键服务启动时的 PATH 很短，补上 Codex 自己所在的目录（它依赖同目录的 node）
        env = dict(os.environ)
        env["PATH"] = os.pathsep.join(
            [os.path.dirname(binary), env.get("PATH", ""), "/usr/local/bin", "/opt/homebrew/bin",
             "/usr/bin", "/bin"]
        )
        try:
            result = subprocess.run(
                cmd, input=load_system_prompt() + "\n" + wrap(raw) + "\n",
                capture_output=True, text=True, timeout=timeout, cwd=workdir, env=env,
            )
        except subprocess.TimeoutExpired:
            raise PolishError("Codex 超过 %s 秒没有返回。" % timeout)
        except OSError as e:
            raise PolishError("Codex 启动失败：%r" % e)

        text = ""
        if os.path.exists(out_path):
            with open(out_path, encoding="utf-8") as f:
                text = f.read().strip()
        if result.returncode != 0 or not text:
            tail = (result.stderr or result.stdout or "").strip()[-300:]
            raise PolishError("Codex 调用失败（退出码 %s）：%s" % (result.returncode, tail))
        return text


def polish_with_api(raw, name, provider, timeout):
    key = load_key(name)
    body = {
        "model": provider["model"],
        "messages": [
            {"role": "system", "content": load_system_prompt()},
            {"role": "user", "content": wrap(raw)},
        ],
        "stream": False,
    }
    body.update(provider.get("extra") or {})

    request = urllib.request.Request(
        provider["url"],
        data=json.dumps(body).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "Authorization": "Bearer " + key,
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            data = json.load(response)
    except urllib.error.HTTPError as e:
        detail = e.read().decode("utf-8", "replace")[:300]
        raise PolishError("%s 返回错误 %s：%s" % (name, e.code, detail))
    except (urllib.error.URLError, OSError, ValueError) as e:
        raise PolishError("连接 %s 失败：%r" % (name, e))

    try:
        text = data["choices"][0]["message"]["content"]
    except (KeyError, IndexError, TypeError):
        raise PolishError("%s 的返回格式不符合预期：%s" % (name, json.dumps(data)[:300]))
    if not text or not text.strip():
        raise PolishError("%s 返回了空内容。" % name)
    return text.strip()


def polish(raw):
    name, provider, timeout = load_config()
    if provider.get("type") == "codex":
        return polish_with_codex(raw, provider, timeout)
    return polish_with_api(raw, name, provider, timeout)


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "--check":
        try:
            name, provider, _ = load_config()
            print("服务商：%s　模型：%s" % (name, provider.get("model") or "默认"))
            print("试调用结果：" + polish("帮我写个周报"))
        except PolishError as e:
            print("未通过：%s" % e)
            sys.exit(1)
        return

    raw = sys.stdin.read()
    if not raw.strip():
        sys.stdout.write(raw)
        return
    try:
        sys.stdout.write(polish(raw))
    except PolishError as e:
        sys.stderr.write("提示词优化失败，已保留原文：%s\n" % e)
        sys.stdout.write(raw)


if __name__ == "__main__":
    main()
