![License](https://img.shields.io/github/license/Kotetsu0000/luatex-wasm)
![Release](https://img.shields.io/badge/Release-TeX%20Live%202025-2c9f42)
![Pages](https://img.shields.io/github/actions/workflow/status/Kotetsu0000/luatex-wasm/pages.yml?label=pages)
![Playground](https://img.shields.io/website?url=https%3A%2F%2Fkotetsu0000.github.io%2Fluatex-wasm%2F&label=playground)

[English](README.md) | [日本語](README_ja.md) | [中文](README_zh.md) | [한국어](README_ko.md) | [Español](README_es.md) | [Deutsch](README_de.md) | [Français](README_fr.md) | [Português (BR)](README_pt.md)

# LuaTeX WASM Playground

Build LuaTeX (LuaLaTeX) for WebAssembly and run it in the browser. This repository also hosts a playground on GitHub Pages.

- Playground: https://kotetsu0000.github.io/luatex-wasm/
- Repository: https://github.com/Kotetsu0000/luatex-wasm

## Overview

This project builds a WebAssembly version of LuaTeX and a `lualatex` format file, then serves a browser UI that compiles LaTeX into PDF.
The playground runs fully in the browser and uses a Web Worker to keep the UI responsive.

## Features

- Browser-based LuaLaTeX compilation to PDF
- Upload `.tex` sources and add custom `.sty` files
- Live log output + PDF preview and download
- Curated TeX Live subset for faster load (e.g. base LaTeX, LuaTeX, fontspec, pgf/tikz, jlreq)
- Extra packages like `emath` bundled in the build script

## How it works

- `scripts/build-luatex-wasm.sh` builds LuaTeX with Emscripten and prepares TeX Live assets.
- The build outputs `luatex.js`, `luatex.wasm`, `luatex.data`, and `lualatex.fmt` into `wasm/<year>`.
- The playground (`docs/`) loads those assets and compiles with `lualatex` inside a Web Worker (`docs/worker.js`).

## Quick start (playground)

Open the hosted playground and compile the sample document.

If you want to run it locally:

```bash
cd docs
python3 -m http.server 8080
```

Then open `http://localhost:8080` in your browser.

## Build from source

> Note: This is a heavy build. Expect large downloads and long compile times.

Requirements (typical Linux build env):

- `bash`, `curl`, `tar`, `xz`, `unzip`
- `python3`, `node`
- Build tools such as `make`, `gcc`, `g++`

Build the latest TeX Live release for a given year (default: 2025):

```bash
# Build TeX Live 2025 assets (default)
./scripts/build-luatex-wasm.sh

# Or specify the TeX Live year
TL_YEAR=2024 ./scripts/build-luatex-wasm.sh
```

The script will:

1. Resolve the latest TeX Live source tarball for the selected year.
2. Download TeX Live source + texmf from the Utah mirror.
3. Build host tools and the WebAssembly LuaTeX.
4. Generate `lualatex.fmt` using Node.
5. Copy artifacts into `wasm/<year>` and `docs/`.

Artifacts and checksums are recorded in `wasm/<year>/info.md`.

## Publish to GitHub Pages

The workflow `.github/workflows/pages.yml` runs on **release publish** (and manually). It:

1. Downloads the latest release assets.
2. Copies them into `docs/`.
3. Deploys `docs/` to GitHub Pages.

To publish a new playground build:

1. Build locally with `scripts/build-luatex-wasm.sh`.
2. Create a GitHub release.
3. Attach `luatex.js`, `luatex.wasm`, `luatex.data`, and `lualatex.fmt` from `wasm/<year>`.

## Project structure

- `scripts/` — build scripts (LuaTeX + TeX Live + wasm packaging)
- `docs/` — playground site (HTML/JS/worker)
- `wasm/<year>/` — built artifacts and checksums
- `texmf/<year>/` — curated TeX Live texmf subset
- `external/` — downloaded sources (emsdk, TeX Live)
- `build/` — build outputs (generated)

## Notes & limitations

- `luatex.data` is large (~200MB for 2025). First load can take time.
- Only a curated TeX Live subset is included. If a package is missing, add it in `scripts/build-luatex-wasm.sh`.
- Files are stored in an in-memory FS inside the worker (not persisted).

## License

GPL-2.0-only. See `LICENSE`.
