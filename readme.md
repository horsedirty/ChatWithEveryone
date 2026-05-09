# ChatWithEveryone

<div align="center">

**AI 聊天客户端 | 原生 macOS 多模型对话应用**

[![Platform](https://img.shields.io/badge/platform-macOS%2015%2B-blue)](https://github.com/horsedirty/ChatWithEveryone/releases)
[![Swift](https://img.shields.io/badge/Swift-5.0-orange)](https://swift.org)
[![Version](https://img.shields.io/badge/version-1.2.1-lightgrey)](https://github.com/horsedirty/ChatWithEveryone/releases)

</div>

## 概述

ChatWithEveryone 是一款为 macOS 打造的原生 AI 聊天客户端，集成 **多模型无缝切换**、**流式对话**、**联网搜索**、**图片生成** 与 **屏幕截图对话** 等能力，让你在一个轻量应用里同时驾驭 DeepSeek、硅基流动、OpenAI 等主流大模型。应用采用 SwiftUI + AppKit 混合架构，通过全局悬浮面板和菜单栏常驻，把 AI 助手变成触手可及的桌面伴侣。

## 核心功能

### 多模型接入

- **三大内置供应商** — 开箱即用，填入 API Key 即可对话
    | 供应商 | 默认模型 | 特色 |
    |--------|----------|------|
    | **DeepSeek** | deepseek-v4-flash / v4-pro | 深度推理，思考过程可见 |
    | **硅基流动 (SiliconFlow)** | DeepSeek-V3 / Qwen2.5-72B / QwQ-32B / Llama-3.1-405B | 模型品类丰富，支持图片生成 (Kolors / SD3.5 / FLUX) |
    | **AIAPI.world** | gpt-4o / claude-3-5-sonnet / gemini-2.0-flash | 国际主流模型一站式接入 |
- **自定义端点** — 兼容任意 OpenAI 格式 API，自由扩展你的模型库
- **自定义模型列表** — 每个供应商可手动添加/移除模型，灵活对接新发布模型

### 智能对话

- **流式输出** — 基于 SSE 的实时打字机效果，回复逐字呈现
- **思考过程展示** — 支持 DeepSeek-R1 等推理模型，可折叠查看完整思考链及耗时
- **上下文长度控制** — 8K / 16K / 32K / 64K / 128K / 256K / 1M / 2M / 4M 自由切换，彩色进度条实时指示用量
- **消息操作** — 编辑已发送消息、重新生成回复、撤销对话轮次

### 联网搜索

- **实时搜索增强** — 一键开启，通过 DuckDuckGo 获取最新网络信息注入对话
- **智能降级** — API 不可用时自动切换 HTML 抓取，保证搜索结果始终可用

### 图片生成

- **文生图** — 支持 Kolors / Stable Diffusion 3.5 / FLUX.1 等模型
- **结果直显** — 生成图片自动渲染在对话气泡中，点击可保存

### 文件与截图

- **图片附件** — 拖拽或选择图片作为对话上下文，JPEG 编码内嵌发送
- **文本文件** — 支持 `.txt` / `.md` / `.markdown` 文件内容直接导入对话
- **屏幕捕获** — 基于 ScreenCaptureKit，可捕获全屏或任意窗口画面发送给 AI

### 多会话管理

- **侧边栏导航** — 左侧会话列表，支持新建、重命名（双击）、删除
- **持久化存储** — 所有会话和供应商配置自动保存至本地 JSON，启动即恢复
- **独立模型绑定** — 每个会话可单独选择供应商和模型，互不干扰

### 全局悬浮面板

- **一键唤起** — 按下 `Option + Space`，非侵入式面板浮现在屏幕中央
- **跨空间驻留** — 面板跟随所有桌面空间和全屏应用，随时对话不中断
- **无缝切换** — 面板可一键展开至完整主窗口

### 代码与公式渲染

- **语法高亮** — 代码块自动识别语言并高亮，每段代码独立复制按钮
- **LaTeX 数学公式** — 基于 MathJax 渲染行内公式和块级公式，完美支持学术讨论

### 自动更新

- **Sparkle 集成** — 自动检测 GitHub Release，一键升级至最新版本

## 快捷键

| 快捷键 | 作用域 | 功能 |
|--------|--------|------|
| `Option + Space` | 全局 | 唤起/隐藏悬浮对话面板 |
| `⌘ + N` | 主窗口 | 新建对话会话 |
| `Enter`（双击） | 输入框 | 发送消息 |
| `Shift + Enter` | 输入框 | 插入换行 |
| `⌘ + 0` | 全局 | 显示主窗口 |

## 系统要求

- **操作系统**：macOS 15.0 (Sequoia) 或更高版本
- **架构**：Apple Silicon 原生支持
- **网络**：需联网访问各 AI API 端点

## 技术架构

| 层级 | 技术选型 |
|------|----------|
| UI 框架 | SwiftUI + AppKit (NSViewRepresentable) |
| Markdown 渲染 | [Textual](https://github.com/gonzalezreal/Textual) |
| 自动更新 | [Sparkle](https://github.com/sparkle-project/Sparkle) |
| 全局热键 | Carbon Event API |
| 屏幕捕获 | ScreenCaptureKit |
| 数据持久化 | Codable + JSON (Application Support) |
| 密钥存储 | 内存持有（API Key 不落盘明文） |
| 架构模式 | MVVM + Singleton Services |

## 安装

### 直接下载

从 [Releases](https://github.com/horsedirty/ChatWithEveryone/releases) 页面下载最新版本 `ChatWithEveryone-vX.X.X.dmg`，打开后将 ChatWithEveryone.app 拖入 `/Applications` 即可。

### 从源码构建

```bash
git clone https://github.com/horsedirty/ChatWithEveryone.git
cd ChatWithEveryone
open ChatWithEveryone.xcodeproj
```

在 Xcode 中选择 `ChatWithEveryone` scheme，按 `⌘ + R` 运行。

> **注意**：首次构建时 Xcode 会自动解析 SPM 依赖（Sparkle、Textual），请确保网络连接正常。

---

<div align="center">

**ChatWithEveryone** — 一个App，聊遍所有 AI

</div>
