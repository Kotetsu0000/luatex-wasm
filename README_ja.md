![License](https://img.shields.io/github/license/Kotetsu0000/luatex-wasm)
![Release](https://img.shields.io/badge/Release-TeX%20Live%202025-2c9f42)
![Pages](https://img.shields.io/github/actions/workflow/status/Kotetsu0000/luatex-wasm/pages.yml?label=pages)
![Playground](https://img.shields.io/website?url=https%3A%2F%2Fkotetsu0000.github.io%2Fluatex-wasm%2F&label=playground)

[English](README.md) | [日本語](README_ja.md) | [中文](README_zh.md) | [한국어](README_ko.md) | [Español](README_es.md) | [Deutsch](README_de.md) | [Français](README_fr.md) | [Português (BR)](README_pt.md)

# LuaTeX WASM Playground

LuaTeX（LuaLaTeX）を WebAssembly 化し、ブラウザ上で動かすためのプロジェクトです。GitHub Pages 上に Playground も公開しています。

- Playground: https://kotetsu0000.github.io/luatex-wasm/
- リポジトリ: https://github.com/Kotetsu0000/luatex-wasm

## 概要

LuaTeX を WebAssembly でビルドし、`lualatex` 形式ファイルと合わせてブラウザから PDF を生成します。
Playground は Web Worker 上でコンパイルを行うため、UI がブロックされません。

## 特長

- ブラウザで LuaLaTeX を実行し PDF を生成
- `.tex` の読み込みと `.sty` 追加に対応
- ログ表示、PDF プレビュー、ダウンロード
- 速度重視で TeX Live を厳選（基礎 LaTeX / LuaTeX / fontspec / pgf/tikz / jlreq など）
- `emath` などの追加パッケージを同梱

## 仕組み

- `scripts/build-luatex-wasm.sh` が LuaTeX を Emscripten でビルドし、TeX Live の必要部分を用意します。
- 生成物は `wasm/<year>` に `luatex.js`, `luatex.wasm`, `luatex.data`, `lualatex.fmt` として出力されます。
- Playground（`docs/`）はこれらを読み込み、`docs/worker.js` 内で `lualatex` を実行します。

## すぐ試す（Playground）

公開中の Playground にアクセスし、サンプルをコンパイルしてください。

ローカルで動かす場合は簡易サーバーを起動します：

```bash
cd docs
python3 -m http.server 8080
```

ブラウザで `http://localhost:8080` を開きます。

## ビルド方法

> 注意: 大容量のダウンロードと長時間のビルドが発生します。

必要なもの（一般的な Linux ビルド環境）:

- `bash`, `curl`, `tar`, `xz`, `unzip`
- `python3`, `node`
- `make`, `gcc`, `g++` などのビルドツール

ビルド（デフォルトは TeX Live 2025）：

```bash
# TeX Live 2025 をビルド（デフォルト）
./scripts/build-luatex-wasm.sh

# 年を指定する場合
TL_YEAR=2024 ./scripts/build-luatex-wasm.sh
```

スクリプトの流れ:

1. 指定年の最新 TeX Live ソースを解決
2. Utah ミラーからソースと texmf を取得
3. ホスト用ツールと WASM をビルド
4. Node で `lualatex.fmt` を生成
5. `wasm/<year>` と `docs/` に成果物を配置

生成物のサイズやチェックサムは `wasm/<year>/info.md` に記録されます。

## GitHub Pages への公開

`.github/workflows/pages.yml` は **release 公開時**（または手動）に実行され、以下を行います。

1. 最新リリースのアセットを取得
2. `docs/` に配置
3. GitHub Pages にデプロイ

公開するには:

1. `scripts/build-luatex-wasm.sh` でビルド
2. GitHub Release を作成
3. `wasm/<year>` から `luatex.js`, `luatex.wasm`, `luatex.data`, `lualatex.fmt` を添付

## ディレクトリ構成

- `scripts/` — ビルドスクリプト一式
- `docs/` — Playground のフロント（HTML/JS/worker）
- `wasm/<year>/` — ビルド成果物とチェックサム
- `texmf/<year>/` — 取り込んだ TeX Live の一部
- `external/` — ダウンロードした外部ソース
- `build/` — ビルド途中の生成物

## 注意点

- `luatex.data` が大きく（2025 で約 200MB）、初回読み込みに時間がかかります。
- TeX Live は厳選セットです。必要なパッケージは `scripts/build-luatex-wasm.sh` に追加してください。
- ファイルは Worker 内のメモリ FS に保存され、永続化されません。

## ライセンス

GPL-2.0-only。`LICENSE` を参照してください。
