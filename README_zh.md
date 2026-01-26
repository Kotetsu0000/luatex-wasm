![License](https://img.shields.io/github/license/Kotetsu0000/luatex-wasm)
![Release](https://img.shields.io/badge/Release-TeX%20Live%202025-2c9f42)
![Pages](https://img.shields.io/github/actions/workflow/status/Kotetsu0000/luatex-wasm/pages.yml?label=pages)
![Playground](https://img.shields.io/website?url=https%3A%2F%2Fkotetsu0000.github.io%2Fluatex-wasm%2F&label=playground)

[English](README.md) | [日本語](README_ja.md) | [中文](README_zh.md) | [한국어](README_ko.md) | [Español](README_es.md) | [Deutsch](README_de.md) | [Français](README_fr.md) | [Português (BR)](README_pt.md)

# LuaTeX WASM Playground

将 LuaTeX（LuaLaTeX）构建为 WebAssembly，并在浏览器中运行。本仓库同时提供 GitHub Pages 的在线 Playground。

- Playground: https://kotetsu0000.github.io/luatex-wasm/
- 仓库: https://github.com/Kotetsu0000/luatex-wasm

## 概览

项目会构建 WebAssembly 版 LuaTeX 和 `lualatex` 格式文件，然后在浏览器端将 LaTeX 编译为 PDF。Playground 使用 Web Worker 进行编译，避免阻塞 UI。

## 功能

- 浏览器内 LuaLaTeX 编译 PDF
- 支持上传 `.tex` 与添加自定义 `.sty`
- 日志输出、PDF 预览与下载
- 精简的 TeX Live 子集（基础 LaTeX / LuaTeX / fontspec / pgf/tikz / jlreq 等）
- 构建脚本中额外打包 `emath` 等包

## 工作原理

- `scripts/build-luatex-wasm.sh` 负责用 Emscripten 构建 LuaTeX，并准备 TeX Live 资源。
- 构建产物输出到 `wasm/<year>`：`luatex.js`, `luatex.wasm`, `luatex.data`, `lualatex.fmt`。
- Playground（`docs/`）加载这些资源，并在 `docs/worker.js` 中执行 `lualatex`。

## 快速体验（Playground）

直接访问在线 Playground 并编译示例即可。

本地运行：

```bash
cd docs
python3 -m http.server 8080
```

浏览器打开 `http://localhost:8080`。

## 从源码构建

> 注意：构建体量较大，会下载大量资源并耗时较长。

常见 Linux 构建环境需要：

- `bash`, `curl`, `tar`, `xz`, `unzip`
- `python3`, `node`
- `make`, `gcc`, `g++` 等构建工具

构建（默认 TeX Live 2025）：

```bash
./scripts/build-luatex-wasm.sh

# 指定年份
TL_YEAR=2024 ./scripts/build-luatex-wasm.sh
```

脚本流程：

1. 解析指定年份最新的 TeX Live 源码包
2. 从 Utah 镜像下载源码与 texmf
3. 构建宿主工具与 WASM
4. 使用 Node 生成 `lualatex.fmt`
5. 产物复制到 `wasm/<year>` 和 `docs/`

产物大小与校验写入 `wasm/<year>/info.md`。

## 发布到 GitHub Pages

`.github/workflows/pages.yml` 在 **发布 Release**（或手动）时执行：

1. 下载最新 Release 资产
2. 写入 `docs/`
3. 部署到 GitHub Pages

发布新版本：

1. 本地执行 `scripts/build-luatex-wasm.sh`
2. 创建 GitHub Release
3. 上传 `wasm/<year>` 中的 `luatex.js`, `luatex.wasm`, `luatex.data`, `lualatex.fmt`

## 目录结构

- `scripts/` — 构建脚本
- `docs/` — Playground 前端
- `wasm/<year>/` — 产物与校验
- `texmf/<year>/` — 精简 TeX Live 资源
- `external/` — 下载的外部源码
- `build/` — 构建过程文件

## 注意事项

- `luatex.data` 体积较大（2025 约 200MB），首次加载较慢。
- 仅包含精简 TeX Live 子集，缺失包请在 `scripts/build-luatex-wasm.sh` 中追加。
- 文件存放在 Worker 的内存 FS 中，刷新后不会保留。

## 许可证

GPL-2.0-only。详见 `LICENSE`。
