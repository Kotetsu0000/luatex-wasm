![License](https://img.shields.io/github/license/Kotetsu0000/luatex-wasm)
![Release](https://img.shields.io/badge/Release-TeX%20Live%202025-2c9f42)
![Pages](https://img.shields.io/github/actions/workflow/status/Kotetsu0000/luatex-wasm/pages.yml?label=pages)
![Playground](https://img.shields.io/website?url=https%3A%2F%2Fkotetsu0000.github.io%2Fluatex-wasm%2F&label=playground)

[English](README.md) | [日本語](README_ja.md) | [中文](README_zh.md) | [한국어](README_ko.md) | [Español](README_es.md) | [Deutsch](README_de.md) | [Français](README_fr.md) | [Português (BR)](README_pt.md)

# LuaTeX WASM Playground

Compiler LuaTeX (LuaLaTeX) en WebAssembly et l’exécuter dans le navigateur. Ce dépôt publie aussi un Playground sur GitHub Pages.

- Playground: https://kotetsu0000.github.io/luatex-wasm/
- Dépôt: https://github.com/Kotetsu0000/luatex-wasm

## Vue d’ensemble

Le projet construit une version WebAssembly de LuaTeX et un format `lualatex`, puis compile du LaTeX en PDF dans le navigateur. La compilation tourne dans un Web Worker pour garder l’UI réactive.

## Fonctionnalités

- Compilation LuaLaTeX dans le navigateur
- Import de `.tex` et ajout de `.sty` personnalisés
- Logs, aperçu PDF et téléchargement
- Sous‑ensemble TeX Live sélectionné (LaTeX de base / LuaTeX / fontspec / pgf/tikz / jlreq)
- Paquets supplémentaires comme `emath`

## Fonctionnement

- `scripts/build-luatex-wasm.sh` compile LuaTeX avec Emscripten et prépare TeX Live.
- Les artefacts sont générés dans `wasm/<year>` : `luatex.js`, `luatex.wasm`, `luatex.data`, `lualatex.fmt`.
- Le Playground (`docs/`) charge ces fichiers et exécute `lualatex` dans `docs/worker.js`.

## Démarrage rapide (Playground)

Ouvrez le Playground en ligne et compilez l’exemple.

En local :

```bash
cd docs
python3 -m http.server 8080
```

Ouvrez `http://localhost:8080`.

## Compiler depuis les sources

> Note : téléchargements volumineux et temps de build importants.

Prérequis (Linux typique) :

- `bash`, `curl`, `tar`, `xz`, `unzip`
- `python3`, `node`
- Outils de build comme `make`, `gcc`, `g++`

Build (par défaut TeX Live 2025) :

```bash
./scripts/build-luatex-wasm.sh

# Spécifier l’année
TL_YEAR=2024 ./scripts/build-luatex-wasm.sh
```

Étapes du script :

1. Résolution du dernier tarball TeX Live pour l’année.
2. Téléchargement des sources + texmf depuis le mirror Utah.
3. Build des outils host et LuaTeX WASM.
4. Génération de `lualatex.fmt` avec Node.
5. Copie vers `wasm/<year>` et `docs/`.

Tailles et checksums : `wasm/<year>/info.md`.

## Publication sur GitHub Pages

`.github/workflows/pages.yml` s’exécute lors de la **publication d’un release** (ou manuellement) et :

1. Télécharge les assets du dernier release.
2. Les copie dans `docs/`.
3. Déploie sur GitHub Pages.

Pour publier :

1. Exécuter `scripts/build-luatex-wasm.sh`.
2. Créer un GitHub Release.
3. Joindre `luatex.js`, `luatex.wasm`, `luatex.data`, `lualatex.fmt` depuis `wasm/<year>`.

## Structure du projet

- `scripts/` — scripts de build
- `docs/` — frontend du Playground
- `wasm/<year>/` — artefacts & checksums
- `texmf/<year>/` — TeX Live sélectionné
- `external/` — sources téléchargées
- `build/` — sorties de build

## Notes

- `luatex.data` est volumineux (~200MB en 2025), le premier chargement peut être long.
- Seul un sous‑ensemble TeX Live est inclus ; ajoutez des paquets dans `scripts/build-luatex-wasm.sh`.
- Les fichiers vivent dans un FS mémoire du Worker (non persistant).

## Licence

GPL-2.0-only. Voir `LICENSE`.
