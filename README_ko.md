![License](https://img.shields.io/github/license/Kotetsu0000/luatex-wasm)
![Release](https://img.shields.io/badge/Release-TeX%20Live%202025-2c9f42)
![Pages](https://img.shields.io/github/actions/workflow/status/Kotetsu0000/luatex-wasm/pages.yml?label=pages)
![Playground](https://img.shields.io/website?url=https%3A%2F%2Fkotetsu0000.github.io%2Fluatex-wasm%2F&label=playground)

[English](README.md) | [日本語](README_ja.md) | [中文](README_zh.md) | [한국어](README_ko.md) | [Español](README_es.md) | [Deutsch](README_de.md) | [Français](README_fr.md) | [Português (BR)](README_pt.md)

# LuaTeX WASM Playground

LuaTeX(LuaLaTeX)를 WebAssembly로 빌드해 브라우저에서 실행하는 프로젝트입니다. GitHub Pages Playground도 제공합니다.

- Playground: https://kotetsu0000.github.io/luatex-wasm/
- 리포지토리: https://github.com/Kotetsu0000/luatex-wasm

## 개요

WebAssembly 버전 LuaTeX와 `lualatex` 포맷 파일을 빌드해, 브라우저에서 LaTeX를 PDF로 컴파일합니다. Playground는 Web Worker를 사용해 UI가 멈추지 않도록 합니다.

## 기능

- 브라우저 내 LuaLaTeX 컴파일
- `.tex` 업로드와 사용자 `.sty` 추가
- 로그 출력, PDF 미리보기 및 다운로드
- 최소화된 TeX Live 세트(기본 LaTeX / LuaTeX / fontspec / pgf/tikz / jlreq 등)
- 빌드 스크립트에 `emath` 등 추가 패키지 포함

## 동작 방식

- `scripts/build-luatex-wasm.sh`가 Emscripten으로 LuaTeX를 빌드하고 TeX Live 리소스를 준비합니다.
- 결과물은 `wasm/<year>`에 `luatex.js`, `luatex.wasm`, `luatex.data`, `lualatex.fmt`로 저장됩니다.
- Playground(`docs/`)가 이를 로드하고 `docs/worker.js`에서 `lualatex`를 실행합니다.

## 빠른 시작(Playground)

온라인 Playground에 접속해 샘플을 컴파일하세요.

로컬 실행:

```bash
cd docs
python3 -m http.server 8080
```

브라우저에서 `http://localhost:8080`을 여세요.

## 소스 빌드

> 주의: 대용량 다운로드와 긴 빌드 시간이 필요합니다.

필수(일반적인 Linux 빌드 환경):

- `bash`, `curl`, `tar`, `xz`, `unzip`
- `python3`, `node`
- `make`, `gcc`, `g++` 등 빌드 도구

빌드(기본 TeX Live 2025):

```bash
./scripts/build-luatex-wasm.sh

# 연도 지정
TL_YEAR=2024 ./scripts/build-luatex-wasm.sh
```

스크립트 흐름:

1. 지정 연도의 최신 TeX Live 소스 해석
2. Utah 미러에서 소스와 texmf 다운로드
3. 호스트 도구 및 WASM 빌드
4. Node로 `lualatex.fmt` 생성
5. `wasm/<year>`와 `docs/`로 복사

산출물 크기/체크섬은 `wasm/<year>/info.md`에 기록됩니다.

## GitHub Pages 배포

`.github/workflows/pages.yml`는 **Release 발행**(또는 수동) 시 실행되며:

1. 최신 Release 자산 다운로드
2. `docs/`에 배치
3. GitHub Pages 배포

새 빌드 배포 절차:

1. `scripts/build-luatex-wasm.sh` 실행
2. GitHub Release 생성
3. `wasm/<year>`의 `luatex.js`, `luatex.wasm`, `luatex.data`, `lualatex.fmt` 업로드

## 디렉터리 구조

- `scripts/` — 빌드 스크립트
- `docs/` — Playground 프론트엔드
- `wasm/<year>/` — 산출물/체크섬
- `texmf/<year>/` — 선별된 TeX Live 리소스
- `external/` — 다운로드된 외부 소스
- `build/` — 빌드 중 생성물

## 주의사항

- `luatex.data`가 크며(2025 기준 약 200MB) 첫 로딩이 느립니다.
- TeX Live는 선별 세트입니다. 필요한 패키지는 `scripts/build-luatex-wasm.sh`에 추가하세요.
- 파일은 Worker의 메모리 FS에만 저장되어 영구 보관되지 않습니다.

## 라이선스

GPL-2.0-only. `LICENSE`를 참고하세요.
