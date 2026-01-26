![License](https://img.shields.io/github/license/Kotetsu0000/luatex-wasm)
![Release](https://img.shields.io/badge/Release-TeX%20Live%202025-2c9f42)
![Pages](https://img.shields.io/github/actions/workflow/status/Kotetsu0000/luatex-wasm/pages.yml?label=pages)
![Playground](https://img.shields.io/website?url=https%3A%2F%2Fkotetsu0000.github.io%2Fluatex-wasm%2F&label=playground)

[English](README.md) | [日本語](README_ja.md) | [中文](README_zh.md) | [한국어](README_ko.md) | [Español](README_es.md) | [Deutsch](README_de.md) | [Français](README_fr.md) | [Português (BR)](README_pt.md)

# LuaTeX WASM Playground

Compile o LuaTeX (LuaLaTeX) para WebAssembly e rode no navegador. Este repositório também publica um Playground no GitHub Pages.

- Playground: https://kotetsu0000.github.io/luatex-wasm/
- Repositório: https://github.com/Kotetsu0000/luatex-wasm

## Visão geral

O projeto constrói uma versão WebAssembly do LuaTeX e o formato `lualatex`, compilando LaTeX para PDF no navegador. O Playground usa Web Worker para manter a UI responsiva.

## Recursos

- Compilação LuaLaTeX no navegador
- Upload de `.tex` e estilos `.sty` personalizados
- Logs, prévia de PDF e download
- Subconjunto curado do TeX Live (LaTeX base / LuaTeX / fontspec / pgf/tikz / jlreq)
- Pacotes extras como `emath` incluídos

## Como funciona

- `scripts/build-luatex-wasm.sh` compila LuaTeX com Emscripten e prepara o TeX Live.
- Os artefatos são gerados em `wasm/<year>`: `luatex.js`, `luatex.wasm`, `luatex.data`, `lualatex.fmt`.
- O Playground (`docs/`) carrega esses arquivos e executa `lualatex` em `docs/worker.js`.

## Início rápido (Playground)

Abra o Playground online e compile o exemplo.

Para rodar localmente:

```bash
cd docs
python3 -m http.server 8080
```

Abra `http://localhost:8080` no navegador.

## Build a partir do código-fonte

> Nota: downloads grandes e build demorado.

Requisitos típicos (Linux):

- `bash`, `curl`, `tar`, `xz`, `unzip`
- `python3`, `node`
- Ferramentas de build como `make`, `gcc`, `g++`

Build (padrão TeX Live 2025):

```bash
./scripts/build-luatex-wasm.sh

# Especificar ano
TL_YEAR=2024 ./scripts/build-luatex-wasm.sh
```

Fluxo do script:

1. Resolve o tarball mais recente do TeX Live para o ano.
2. Baixa fonte e texmf do mirror de Utah.
3. Compila ferramentas host e LuaTeX WASM.
4. Gera `lualatex.fmt` com Node.
5. Copia para `wasm/<year>` e `docs/`.

Tamanhos e checksums em `wasm/<year>/info.md`.

## Publicação no GitHub Pages

`.github/workflows/pages.yml` roda ao **publicar um release** (ou manualmente) e:

1. Baixa os assets do último release.
2. Copia para `docs/`.
3. Faz deploy no GitHub Pages.

Para publicar um novo build:

1. Execute `scripts/build-luatex-wasm.sh`.
2. Crie um GitHub Release.
3. Anexe `luatex.js`, `luatex.wasm`, `luatex.data`, `lualatex.fmt` de `wasm/<year>`.

## Estrutura do projeto

- `scripts/` — scripts de build
- `docs/` — frontend do Playground
- `wasm/<year>/` — artefatos e checksums
- `texmf/<year>/` — TeX Live selecionado
- `external/` — fontes baixadas
- `build/` — saídas de build

## Observações

- `luatex.data` é grande (~200MB em 2025) e o primeiro carregamento pode demorar.
- Apenas um subconjunto do TeX Live é incluído; adicione pacotes em `scripts/build-luatex-wasm.sh`.
- Os arquivos vivem em um FS de memória do Worker (não persistente).

## Licença

GPL-2.0-only. Veja `LICENSE`.
