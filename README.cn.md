# maclisten

[![OpenSSF Scorecard](https://api.securityscorecards.dev/projects/github.com/ljh-sh/maclisten/badge)](https://scorecard.dev/)
[![CI](https://github.com/ljh-sh/maclisten/actions/workflows/ci.yml/badge.svg)](https://github.com/ljh-sh/maclisten/actions/workflows/ci.yml)
[![Docs](https://img.shields.io/badge/Docs-website-blue.svg)](https://ljh-sh.github.io/maclisten)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE.txt)

> 私密、轻量的 macOS ASR CLI —— 本地语音转文字，系统占用极低。

**maclisten** 把 Apple 的 `Speech` 框架封装成一个极小的 Swift 二进制。它能在本地转录音频文件、录制麦克风，并持续监听语音关键词，所有数据都不离开你的 Mac。所有输出都是紧凑 JSON，方便管道和 AI 智能体使用。

## 亮点

- **默认私密** —— 音频由 Apple `Speech` 框架本地处理；开启 `--on-device` 后完全不上传。
- **系统占用极低** —— 单个约 500 KB 二进制，无需下载模型，无守护进程，无后台服务。
- **JSON 优先** —— 每个命令都输出紧凑 JSON，方便管道和智能体解析。
- **持续监听** —— `watch` 保持麦克风开启，实时输出分段 / 关键词 JSON 行。

文档：[ljh-sh.github.io/maclisten](https://ljh-sh.github.io/maclisten)

## 安装

### Homebrew（推荐）

```sh
brew install ljh-sh/cli/maclisten
```

或先 tap：

```sh
brew tap ljh-sh/cli
brew install maclisten
```

### 直接下载二进制

```sh
curl -L https://github.com/ljh-sh/maclisten/releases/latest/download/maclisten-darwin-universal.tar.xz | tar xJ -
sudo mv bin/maclisten /usr/local/bin/
```

`universal` 包是 fat Mach-O（arm64 + x86_64），Apple Silicon 和 Intel Mac 都能用。

### eget

```sh
x eget use --tag v0.2.0 ljh-sh/maclisten
```

### 从源码构建

需要 Swift 5.10+ / macOS 12+。

```sh
git clone https://github.com/ljh-sh/maclisten
cd maclisten
swift build -c release
```

## 权限

macOS 不会可靠地给命令行工具弹出“语音识别”或“麦克风”授权框。在使用 `file`、`mic`、`watch` 前，先到系统设置里给终端授权：

- **系统设置 > 隐私与安全性 > 语音识别**
- **系统设置 > 隐私与安全性 > 麦克风**（`mic` / `watch` 需要）

快速打开设置面板：

```sh
maclisten auth
```

### 重要：请在真正的终端模拟器里运行

macOS TCC 把权限授给**终端模拟器 app**（如 `Terminal.app`、`iTerm.app`、`Warp.app`），而不是 shell 或 `maclisten` 二进制本身。如果你从裸 CLI 进程（比如编辑器插件）里启动 `maclisten`，它没有 bundle ID，系统设置里根本找不到它，权限永远加不上。

## 用法

```sh
maclisten locales                        # 列出支持的语言
maclisten file ./recording.wav           # 转录音频文件
maclisten file ./recording.m4a --locale zh-CN --on-device
maclisten file ./recording.m4a --cn --on-device

maclisten mic --timeout 5                # 录制 5 秒麦克风
maclisten mic --auto-stop                # 检测到停止说话后自动停止
maclisten mic --partial                  # 流式输出中间结果
maclisten mic --output ./note.wav        # 同时保存 WAV 音频

# 持续监听关键词 / 命令短语
maclisten watch --keyword "computer" --partial
maclisten watch --output ./stream.wav    # 边听边录
maclisten watch --fr --keyword "ordinateur"
# 按 Ctrl-C 或 Ctrl-D 停止
```

语言区域可以用 `--locale` 指定，也可以用快捷标志如 `--cn`、`--hk`、`--fr`、`--de`、`--us` 等。如果都没有提供，会依次读取环境变量 `$MACLISTEN_LOCALE`、`$LANG`，最后回退到 `en-US`。

```sh
MACLISTEN_LOCALE=fr-FR maclisten mic --timeout 5
LANG=de_DE.UTF-8 maclisten file ./recording.wav
```

默认输出 JSON：

```json
{"ok":true,"locale":"en-US","onDevice":false,"text":"hello world"}
```

`watch` 每捕获一段会输出一行 JSON：

```json
{"ok":true,"segment":"computer open safari"}
```

## FAQ

详见 [docs/faq.md](docs/faq.md) 或 [在线 FAQ](https://ljh-sh.github.io/maclisten/faq)。常见问题包括：权限/TCC、`watch` 不捕获、音频格式、Siri 接口等。

## 设计

- **小表面**：`locales`、`file`、`mic`、`watch`、`auth`。
- **JSON 输出**：紧凑单行 JSON，方便 `jq` 处理。
- **持续模式**：`watch` 保持音频引擎运行，自动重启识别会话，可一直监听直到按 `Ctrl-C`。
- **音频录制**：`--output` 同时把麦克风音频存成 WAV（16 kHz，16-bit，mono）。
- **NSApplication 生命周期**：`Speech` 框架的回调需要 run loop；`maclisten` 内部启动一个隐藏的 accessory NSApp，对外仍然像普通二进制。

## 贡献

请阅读 [CONTRIBUTING.md](CONTRIBUTING.md)。所有改动通过 PR 提交，需管理员审批后合并。

## 安全

漏洞报告见 [SECURITY.md](SECURITY.md)。

## 路线图

见 [ROADMAP.md](ROADMAP.md)。

## 许可

Apache-2.0
