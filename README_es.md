![License](https://img.shields.io/github/license/Kotetsu0000/luatex-wasm)
![Release](https://img.shields.io/badge/Release-TeX%20Live%202025-2c9f42)
![Pages](https://img.shields.io/github/actions/workflow/status/Kotetsu0000/luatex-wasm/pages.yml?label=pages)
![Playground](https://img.shields.io/website?url=https%3A%2F%2Fkotetsu0000.github.io%2Fluatex-wasm%2F&label=playground)

[English](README.md) | [日本語](README_ja.md) | [中文](README_zh.md) | [한국어](README_ko.md) | [Español](README_es.md) | [Deutsch](README_de.md) | [Français](README_fr.md) | [Português (BR)](README_pt.md)

# LuaTeX WASM Playground

Compila LuaTeX (LuaLaTeX) a WebAssembly y ejecútalo en el navegador. Este repositorio también publica un Playground en GitHub Pages.

- Playground: https://kotetsu0000.github.io/luatex-wasm/
- Repositorio: https://github.com/Kotetsu0000/luatex-wasm

## Resumen

El proyecto construye una versión WebAssembly de LuaTeX y el formato `lualatex`, y compila LaTeX a PDF en el navegador. El Playground usa Web Worker para mantener la UI fluida.

## Funcionalidades

- Compilación LuaLaTeX en el navegador
- Carga de `.tex` y estilos `.sty` personalizados
- Logs, previsualización de PDF y descarga
- Subconjunto curado de TeX Live (LaTeX base / LuaTeX / fontspec / pgf/tikz / jlreq)
- Paquetes extra como `emath` incluidos en el build

## Cómo funciona

- `scripts/build-luatex-wasm.sh` construye LuaTeX con Emscripten y prepara TeX Live.
- Los artefactos se guardan en `wasm/<year>`: `luatex.js`, `luatex.wasm`, `luatex.data`, `lualatex.fmt`.
- El Playground (`docs/`) los carga y ejecuta `lualatex` en `docs/worker.js`.

## Inicio rápido (Playground)

Abre el Playground online y compila el ejemplo.

Para usarlo localmente:

```bash
cd docs
python3 -m http.server 8080
```

Abre `http://localhost:8080` en el navegador.

## Compilar desde código fuente

> Nota: Descargas grandes y tiempos de build largos.

Requisitos típicos (Linux):

- `bash`, `curl`, `tar`, `xz`, `unzip`
- `python3`, `node`
- Herramientas de build como `make`, `gcc`, `g++`

Build (por defecto TeX Live 2025):

```bash
./scripts/build-luatex-wasm.sh

# Especificar año
TL_YEAR=2024 ./scripts/build-luatex-wasm.sh
```

Flujo del script:

1. Resuelve el último tarball de TeX Live para el año elegido.
2. Descarga fuente y texmf desde el mirror de Utah.
3. Compila herramientas host y LuaTeX WASM.
4. Genera `lualatex.fmt` con Node.
5. Copia artefactos a `wasm/<year>` y `docs/`.

Tamaños y checksums en `wasm/<year>/info.md`.

## Publicación en GitHub Pages

`.github/workflows/pages.yml` se ejecuta al **publicar un release** (o manualmente) y:

1. Descarga los assets del release más reciente.
2. Los coloca en `docs/`.
3. Despliega en GitHub Pages.

Para publicar una nueva versión:

1. Ejecuta `scripts/build-luatex-wasm.sh`.
2. Crea un GitHub Release.
3. Sube `luatex.js`, `luatex.wasm`, `luatex.data`, `lualatex.fmt` desde `wasm/<year>`.

## Estructura del proyecto

- `scripts/` — scripts de build
- `docs/` — frontend del Playground
- `wasm/<year>/` — artefactos y checksums
- `texmf/<year>/` — TeX Live curado
- `external/` — fuentes descargadas
- `build/` — salidas de build

## Notas y limitaciones

- `luatex.data` es grande (~200MB en 2025) y la primera carga puede tardar.
- Solo se incluye un subconjunto de TeX Live; añade paquetes en `scripts/build-luatex-wasm.sh`.
- Los archivos viven en un FS en memoria del Worker (no persistente).

## Licencia

GPL-2.0-only. Ver `LICENSE`.
