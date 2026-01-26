![License](https://img.shields.io/github/license/Kotetsu0000/luatex-wasm)
![Release](https://img.shields.io/badge/Release-TeX%20Live%202025-2c9f42)
![Pages](https://img.shields.io/github/actions/workflow/status/Kotetsu0000/luatex-wasm/pages.yml?label=pages)
![Playground](https://img.shields.io/website?url=https%3A%2F%2Fkotetsu0000.github.io%2Fluatex-wasm%2F&label=playground)

[English](README.md) | [日本語](README_ja.md) | [中文](README_zh.md) | [한국어](README_ko.md) | [Español](README_es.md) | [Deutsch](README_de.md) | [Français](README_fr.md) | [Português (BR)](README_pt.md)

# LuaTeX WASM Playground

LuaTeX (LuaLaTeX) als WebAssembly bauen und im Browser ausführen. Dieses Repository veröffentlicht außerdem ein Playground auf GitHub Pages.

- Playground: https://kotetsu0000.github.io/luatex-wasm/
- Repository: https://github.com/Kotetsu0000/luatex-wasm

## Überblick

Das Projekt erzeugt eine WebAssembly-Version von LuaTeX und ein `lualatex`-Format und kompiliert LaTeX im Browser zu PDF. Die Kompilierung läuft in einem Web Worker, damit die UI reaktionsfähig bleibt.

## Funktionen

- LuaLaTeX-Kompilierung im Browser
- Upload von `.tex` und eigene `.sty`
- Log-Ausgabe, PDF-Vorschau und Download
- Kuratierter TeX-Live-Subset (Basis-LaTeX / LuaTeX / fontspec / pgf/tikz / jlreq)
- Zusätzliche Pakete wie `emath`

## Wie es funktioniert

- `scripts/build-luatex-wasm.sh` baut LuaTeX mit Emscripten und bereitet TeX Live vor.
- Artefakte landen in `wasm/<year>`: `luatex.js`, `luatex.wasm`, `luatex.data`, `lualatex.fmt`.
- Das Playground (`docs/`) lädt sie und führt `lualatex` in `docs/worker.js` aus.

## Schnellstart (Playground)

Öffne das Online-Playground und kompiliere das Beispiel.

Lokal starten:

```bash
cd docs
python3 -m http.server 8080
```

Dann `http://localhost:8080` im Browser öffnen.

## Build aus dem Quellcode

> Hinweis: Große Downloads und lange Build-Zeiten.

Typische Anforderungen (Linux):

- `bash`, `curl`, `tar`, `xz`, `unzip`
- `python3`, `node`
- Build-Tools wie `make`, `gcc`, `g++`

Build (Standard: TeX Live 2025):

```bash
./scripts/build-luatex-wasm.sh

# Jahr angeben
TL_YEAR=2024 ./scripts/build-luatex-wasm.sh
```

Ablauf:

1. Ermittelt das neueste TeX-Live-Archiv für das Jahr.
2. Lädt Source + texmf vom Utah-Mirror.
3. Baut Host-Tools und LuaTeX WASM.
4. Erzeugt `lualatex.fmt` mit Node.
5. Kopiert Artefakte nach `wasm/<year>` und `docs/`.

Größen und Checksummen stehen in `wasm/<year>/info.md`.

## Veröffentlichung auf GitHub Pages

`.github/workflows/pages.yml` läuft beim **Release-Publish** (oder manuell) und:

1. Lädt die neuesten Release-Assets.
2. Kopiert sie nach `docs/`.
3. Deployt zu GitHub Pages.

So veröffentlichst du einen neuen Build:

1. `scripts/build-luatex-wasm.sh` ausführen.
2. GitHub Release erstellen.
3. `luatex.js`, `luatex.wasm`, `luatex.data`, `lualatex.fmt` aus `wasm/<year>` anhängen.

## Projektstruktur

- `scripts/` — Build-Skripte
- `docs/` — Playground-Frontend
- `wasm/<year>/` — Artefakte & Checksummen
- `texmf/<year>/` — kuratierter TeX-Live-Subset
- `external/` — heruntergeladene Quellen
- `build/` — Build-Ausgaben

## Hinweise

- `luatex.data` ist groß (~200MB für 2025), erster Load dauert.
- Enthält nur einen TeX-Live-Subset. Fehlende Pakete in `scripts/build-luatex-wasm.sh` ergänzen.
- Dateien liegen im Worker-Storage (In-Memory), nicht persistent.

## Lizenz

GPL-2.0-only. Siehe `LICENSE`.
