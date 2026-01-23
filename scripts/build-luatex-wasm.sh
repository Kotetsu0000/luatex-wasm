#!/usr/bin/env bash
# Copyright (c) 2026 kotetsu0000
# SPDX-License-Identifier: GPL-2.0-only

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${ROOT_DIR}"
cd "${ROOT_DIR}"

TL_YEAR="${1:-${TL_YEAR:-2025}}"
if ! [[ "${TL_YEAR}" =~ ^[0-9]{4}$ ]]; then
  echo "TL_YEAR must be 4 digits (e.g. 2025). Got: ${TL_YEAR}" >&2
  exit 1
fi

TL_BASE_URL="https://ftp.math.utah.edu/pub/tex/historic/systems/texlive/${TL_YEAR}"

resolve_tl_date() {
  local listing dates
  listing="$(curl -fsSL "${TL_BASE_URL}/")"
  dates="$(printf "%s" "${listing}" | sed -n 's/.*texlive-\([0-9]\{8\}\)-source\.tar\.xz.*/\1/p' | sort -u)"
  if [ -z "${dates}" ]; then
    echo "Failed to detect texlive source tarball under: ${TL_BASE_URL}/" >&2
    return 1
  fi
  printf "%s\n" "${dates}" | tail -n 1
}

TL_DATE="$(resolve_tl_date)"
if [ "${TL_DATE:0:4}" != "${TL_YEAR}" ]; then
  echo "Detected TL_DATE ${TL_DATE} does not match TL_YEAR ${TL_YEAR}" >&2
  exit 1
fi

TL_SRC_TARBALL="texlive-${TL_DATE}-source.tar.xz"
TEXMF_TARBALL="texlive-${TL_DATE}-texmf.tar.xz"

EXTERNAL_DIR="${ROOT_DIR}/external"
SRC_DIR="${EXTERNAL_DIR}/texlive-${TL_DATE}-source"
BUILD_DIR="${ROOT_DIR}/build/texlive-wasm-luatex-${TL_DATE}"
HOST_BUILD_DIR="${ROOT_DIR}/build/texlive-host-tools-${TL_DATE}"
HOST_KPSE_BUILD="${HOST_BUILD_DIR}/texk/kpathsea"
HOST_WEB2C_BUILD="${HOST_BUILD_DIR}/texk/web2c"
HOST_TANGLE="${HOST_WEB2C_BUILD}/tangle"
HOST_CTANGLE="${HOST_WEB2C_BUILD}/ctangle"
HOST_TIE="${HOST_WEB2C_BUILD}/tie"
HOST_OTANGLE="${HOST_WEB2C_BUILD}/otangle"
EMSDK_DIR="${EXTERNAL_DIR}/emsdk"
EMSDK_TARBALL="${EXTERNAL_DIR}/emsdk-main.tar.gz"
TEXMF_BASE_DIR="${ROOT_DIR}/texmf/${TL_YEAR}"
TEXMF_DST_DIR="${TEXMF_BASE_DIR}/texmf-dist"
TEXMF_VAR_DIR="${TEXMF_BASE_DIR}/texmf-var"
OUTPUT_DIR="${ROOT_DIR}/wasm/${TL_YEAR}"
DOCS_DIR="${ROOT_DIR}/docs"

mkdir -p "${EXTERNAL_DIR}" "${BUILD_DIR}" "${HOST_BUILD_DIR}" "${HOST_KPSE_BUILD}" "${HOST_WEB2C_BUILD}" "${OUTPUT_DIR}"

ensure_texlive_source() {
  local tarball_path="${EXTERNAL_DIR}/${TL_SRC_TARBALL}"
  if [ ! -f "${tarball_path}" ]; then
    echo "[download] ${TL_SRC_TARBALL}"
    curl -L -o "${tarball_path}" "${TL_BASE_URL}/${TL_SRC_TARBALL}"
  else
    echo "[resume] ${TL_SRC_TARBALL}"
    curl -L -C - -o "${tarball_path}" "${TL_BASE_URL}/${TL_SRC_TARBALL}" || true
  fi

  if ! xz -t "${tarball_path}"; then
    echo "[retry] ${TL_SRC_TARBALL} (verify failed)"
    python3 - <<PY
from pathlib import Path
Path("${tarball_path}").unlink(missing_ok=True)
PY
    curl -L -o "${tarball_path}" "${TL_BASE_URL}/${TL_SRC_TARBALL}"
  fi

  if [ ! -d "${SRC_DIR}" ]; then
    echo "[extract] ${TL_SRC_TARBALL}"
    tar -xf "${tarball_path}" -C "${EXTERNAL_DIR}"
  fi
}

ensure_texmf() {
  local texmf_tarball_path="${EXTERNAL_DIR}/${TEXMF_TARBALL}"
  if [ ! -f "${texmf_tarball_path}" ]; then
    echo "[download] ${TEXMF_TARBALL}"
    curl -L -o "${texmf_tarball_path}" "${TL_BASE_URL}/${TEXMF_TARBALL}"
  else
    if xz -t "${texmf_tarball_path}"; then
      echo "[ok] ${TEXMF_TARBALL}"
    else
      echo "[resume] ${TEXMF_TARBALL}"
      curl -L -C - -o "${texmf_tarball_path}" "${TL_BASE_URL}/${TEXMF_TARBALL}" || true
      if ! xz -t "${texmf_tarball_path}"; then
        echo "[retry] ${TEXMF_TARBALL} (verify failed)"
        rm -f "${texmf_tarball_path}"
        curl -L -o "${texmf_tarball_path}" "${TL_BASE_URL}/${TEXMF_TARBALL}"
      fi
    fi
  fi

  rm -rf "${TEXMF_DST_DIR}"
  mkdir -p "${TEXMF_DST_DIR}"

  local -a EXTRACT_DIRS=(
    "tex/latex/base"
    "tex/latex/latexconfig"
    "tex/latex/tex-ini-files"
    "tex/latex/l3kernel"
    "tex/latex/l3packages"
    "tex/latex/l3backend"
    "tex/latex/graphics"
    "tex/latex/graphics-def"
    "tex/latex/graphics-cfg"
    "tex/latex/tools"
    "tex/latex/amsmath"
    "tex/latex/amsfonts"
    "tex/latex/enumitem"
    "tex/latex/etoolbox"
    "tex/latex/epstopdf-pkg"
    "tex/latex/fancyhdr"
    "tex/latex/filehook"
    "tex/latex/jlreq"
    "tex/latex/lm"
    "tex/latex/pgf"
    "tex/latex/xcolor"
    "tex/latex/fontspec"
    "tex/latex/xkeyval"
    "tex/generic"
    "tex/plain/base"
    "tex/plain/etex"
    "tex/luatex"
    "fonts/tfm/public/cm"
    "fonts/tfm/public/amsfonts"
    "fonts/tfm/public/knuth-lib"
    "fonts/tfm/public/latex-fonts"
    "fonts/tfm/public/lm"
    "fonts/type1/public/amsfonts/cm"
    "fonts/type1/public/amsfonts/latxfont"
    "fonts/type1/public/amsfonts/symbols"
    "fonts/type1/public/lm"
    "fonts/opentype/public/lm"
    "fonts/opentype/public/haranoaji"
    "fonts/opentype/public/haranoaji-extra"
    "fonts/type1/hoekwater/manfnt-font"
    "fonts/enc/dvips/base"
    "fonts/enc/dvips/lm"
    "fonts/map/pdftex/updmap"
    "web2c"
  )

  local -a TARBALL_PATHS=()
  for rel in "${EXTRACT_DIRS[@]}"; do
    TARBALL_PATHS+=("texlive-${TL_DATE}-texmf/texmf-dist/${rel}")
  done

  tar -xf "${texmf_tarball_path}" -C "${TEXMF_DST_DIR}" --strip-components=2 --ignore-failed-read "${TARBALL_PATHS[@]}"

  local cm_tfm_dir="${TEXMF_DST_DIR}/fonts/tfm/public/cm"
  if [ -d "${cm_tfm_dir}" ] && [ -f "${cm_tfm_dir}/cmex10.tfm" ]; then
    for size in 7 8 9; do
      if [ ! -f "${cm_tfm_dir}/cmex${size}.tfm" ]; then
        cp -f "${cm_tfm_dir}/cmex10.tfm" "${cm_tfm_dir}/cmex${size}.tfm"
      fi
    done
  fi

  mkdir -p "${TEXMF_VAR_DIR}/web2c"
  : > "${TEXMF_VAR_DIR}/.keep"

  local custom_sty_dir="${TEXMF_DST_DIR}/tex/latex/local"
  mkdir -p "${custom_sty_dir}"
  cat <<'STY' > "${custom_sty_dir}/wasm-sample.sty"
\NeedsTeXFormat{LaTeX2e}
\ProvidesPackage{wasm-sample}[2026/01/22 LuaTeX WASM sample style]

\newcommand{\WasmTitle}[1]{%
  {\Large\bfseries #1\par}%
}

\newcommand{\WasmBadge}[1]{%
  {\sffamily\fbox{#1}}%
}
STY
}

ensure_emath() {
  local emath_url="http://emath.s40.xrea.com/lime/lime.cgi?0001"
  local emath_zip_name="emathf051107c.zip"
  local emath_zip="${EXTERNAL_DIR}/${emath_zip_name}"
  local emath_work="${EXTERNAL_DIR}/emath"
  local emath_sty_zip="${emath_work}/sty.zip"
  local emath_sty_dir="${emath_work}/sty"
  local emath_dst="${TEXMF_DST_DIR}/tex/latex/emath"

  mkdir -p "${EXTERNAL_DIR}" "${emath_work}" "${emath_sty_dir}" "${emath_dst}"

  if [ ! -f "${emath_zip}" ]; then
    echo "[download] ${emath_zip_name}"
    curl -L -o "${emath_zip}" "${emath_url}"
  else
    echo "[ok] ${emath_zip_name}"
  fi

  unzip -o "${emath_zip}" "sty.zip" -d "${emath_work}"
  unzip -o "${emath_sty_zip}" -d "${emath_sty_dir}"

  cp -a "${emath_sty_dir}/." "${emath_dst}/"

  EMATH_DST="${emath_dst}" python3 - <<'PY'
from pathlib import Path
import os

dst = Path(os.environ["EMATH_DST"])

for path in list(dst.glob("*.sty")) + list(dst.glob("*.fd")):
    data = path.read_bytes()
    text = None
    if b"\x1b" in data:
        try:
            text = data.decode("iso2022_jp")
        except Exception:
            text = data.decode("iso2022_jp", errors="ignore")
    if text is None:
        try:
            text = data.decode("utf-8")
        except Exception:
            try:
                text = data.decode("cp932")
            except Exception:
                text = data.decode("utf-8", errors="replace")
    text = text.replace("¥", "\\")
    text = text.replace("＼", "\\")
    # 1行＋"\\n"だらけの壊れたテキストを復元
    if text.count("\n") <= 1 and "\\n" in text:
        text = text.replace("\\r\\n", "\n").replace("\\n", "\n")
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    if path.name == "emath.sty":
        lines = text.splitlines()
        out = []
        skipping = False
        depth = 0
        patched = False
        for line in lines:
            stripped = line.lstrip()
            if not patched and line.strip() == r"\\ifpapersize":
                out.append("% luatex-wasm: papersize 特殊処理は無効化（pLaTeX 向け）")
                out.append("%" + line)
                skipping = True
                depth = 1
                patched = True
                continue
            if skipping:
                if stripped.startswith(r"\\if") and not stripped.startswith(r"\\ifpapersize"):
                    depth += 1
                if stripped.startswith(r"\\fi"):
                    depth -= 1
                    out.append("%" + line)
                    if depth == 0:
                        skipping = False
                    continue
                out.append("%" + line)
                continue
            out.append(line)
        text = "\n".join(out) + ("\n" if text.endswith("\n") else "")
    path.write_text(text, encoding="utf-8")
PY

  echo "[ok] emath installed -> ${emath_dst}"
}

ensure_host_tools() {
  if [ -x "${HOST_TANGLE}" ] && [ -x "${HOST_CTANGLE}" ] && [ -x "${HOST_TIE}" ] && [ -x "${HOST_OTANGLE}" ]; then
    return 0
  fi
  echo "[build] host tools (tangle/ctangle/tie/otangle)"
  if [ ! -f "${HOST_BUILD_DIR}/.configured" ]; then
    pushd "${HOST_BUILD_DIR}" >/dev/null
    env CC=gcc CXX=g++ AR=ar RANLIB=ranlib \
      "${SRC_DIR}/configure" \
      --disable-all-pkgs \
      --enable-web2c \
      --disable-shared \
      --enable-static \
      --without-x \
      --disable-synctex \
      --disable-multiplatform
    touch "${HOST_BUILD_DIR}/.configured"
    popd >/dev/null
  fi
  local host_libs_makefile="${HOST_BUILD_DIR}/libs/Makefile"
  if [ -f "${host_libs_makefile}" ]; then
    python3 - <<PY
from pathlib import Path
import re

path = Path("${host_libs_makefile}")
data = path.read_text()
data = re.sub(r"^MAKE_SUBDIRS = .*?$", "MAKE_SUBDIRS = zlib", data, flags=re.MULTILINE)
data = re.sub(r"^CONF_SUBDIRS = .*?$", "CONF_SUBDIRS = zlib", data, flags=re.MULTILINE)
path.write_text(data)
PY
  fi
  if [ -f "${HOST_BUILD_DIR}/libs/Makefile" ]; then
    env CC=gcc CXX=g++ AR=ar RANLIB=ranlib \
      make -C "${HOST_BUILD_DIR}/libs" -j"$(nproc)"
  fi
  if [ ! -f "${HOST_KPSE_BUILD}/Makefile" ]; then
    pushd "${HOST_KPSE_BUILD}" >/dev/null
    env CC=gcc CXX=g++ AR=ar RANLIB=ranlib \
      "${SRC_DIR}/texk/kpathsea/configure" \
      --disable-shared \
      --enable-static \
      --with-system-zlib=no
    popd >/dev/null
  fi
  env CC=gcc CXX=g++ AR=ar RANLIB=ranlib \
    make -C "${HOST_KPSE_BUILD}" -j"$(nproc)"
  if [ ! -f "${HOST_WEB2C_BUILD}/Makefile" ]; then
    pushd "${HOST_WEB2C_BUILD}" >/dev/null
    env CC=gcc CXX=g++ AR=ar RANLIB=ranlib \
      "${SRC_DIR}/texk/web2c/configure" \
      --disable-all-pkgs \
      --enable-web2c \
      --disable-shared \
      --enable-static \
      --without-x \
      --disable-synctex \
      --disable-multiplatform
    popd >/dev/null
  fi
  env CC=gcc CXX=g++ AR=ar RANLIB=ranlib \
    make -C "${HOST_WEB2C_BUILD}" tangle ctangle tie otangle -j"$(nproc)"
}

ensure_emsdk() {
  if [ ! -d "${EMSDK_DIR}" ]; then
    echo "[download] emsdk"
    curl -L -o "${EMSDK_TARBALL}" "https://github.com/emscripten-core/emsdk/archive/refs/heads/main.tar.gz"
    tar -xf "${EMSDK_TARBALL}" -C "${EXTERNAL_DIR}"
    mv "${EXTERNAL_DIR}/emsdk-main" "${EMSDK_DIR}"
  fi
  pushd "${EMSDK_DIR}" >/dev/null
  ./emsdk install latest
  ./emsdk activate latest
  # shellcheck source=/dev/null
  source "${EMSDK_DIR}/emsdk_env.sh"
  popd >/dev/null
}

write_pre_js() {
  local pre_js="${BUILD_DIR}/emscripten-env.js"
  cat <<'JS' > "${pre_js}"
// Copyright (c) 2026 kotetsu0000
// SPDX-License-Identifier: GPL-2.0-only

// Merge Module.ENV into the runtime environment before first getenv().
if (typeof Module !== "undefined") {
  var mergeEnv = function () {
    if (!Module.ENV) {
      return;
    }
    for (var key in Module.ENV) {
      if (Object.prototype.hasOwnProperty.call(Module.ENV, key)) {
        ENV[key] = Module.ENV[key];
      }
    }
  };
  if (!Module.preInit) {
    Module.preInit = [];
  } else if (typeof Module.preInit === "function") {
    Module.preInit = [Module.preInit];
  }
  Module.preInit.push(mergeEnv);
}
JS
  echo "${pre_js}"
}

ensure_texlive_source
ensure_host_tools
ensure_emsdk

if [ ! -d "${TEXMF_DST_DIR}" ]; then
  ensure_texmf
fi
if [ ! -f "${TEXMF_DST_DIR}/tex/latex/emath/emath.sty" ]; then
  ensure_emath
fi

export CC=emcc
export CXX=em++
export AR=emar
export RANLIB=emranlib
export CFLAGS="-O0 -g -fno-strict-aliasing -fwrapv -fno-omit-frame-pointer"
export CXXFLAGS="-O0 -g -fno-strict-aliasing -fwrapv -fno-omit-frame-pointer"
export CC_FOR_BUILD=gcc
export CXX_FOR_BUILD=g++
export CCexe=gcc
export TANGLEBOOT="${HOST_TANGLE}"
export TANGLE="${HOST_TANGLE}"
export CTANGLEBOOT="${HOST_CTANGLE}"
export CTANGLE="${HOST_CTANGLE}"
export TIE="${HOST_TIE}"
export OTANGLE="${HOST_OTANGLE}"

PRE_JS_FILE="$(write_pre_js)"
EM_LDFLAGS="-O0 -sWASM=1 -sALLOW_MEMORY_GROWTH=1 -sSTACK_SIZE=8388608 -sEXIT_RUNTIME=0 -sENVIRONMENT=web,worker,node -sFORCE_FILESYSTEM=1 -sMODULARIZE=1 -sEXPORT_ES6=1 -sEXPORTED_RUNTIME_METHODS=['FS','callMain','ENV'] --pre-js ${PRE_JS_FILE}"
PRELOAD_FLAGS="--preload-file ${TEXMF_BASE_DIR}@/texmf"

pushd "${BUILD_DIR}" >/dev/null
if [ ! -f "${BUILD_DIR}/.configured" ]; then
  emconfigure "${SRC_DIR}/configure" \
    --build=x86_64-pc-linux-gnu \
    --host=wasm32-unknown-emscripten \
    --disable-all-pkgs \
    --enable-web2c \
    --enable-luatex \
    --disable-mp \
    --disable-luahbtex \
    --disable-luajittex \
    --disable-luajithbtex \
    --disable-xetex \
    --disable-mflua \
    --disable-mfluajit \
    --disable-shared \
    --enable-static \
    --without-x \
    --disable-synctex \
    --disable-multiplatform
  touch "${BUILD_DIR}/.configured"
fi

# out-of-tree ビルドで texk 配下のサブディレクトリが作られない場合の保険
if [ ! -f "${BUILD_DIR}/texk/kpathsea/Makefile" ]; then
  mkdir -p "${BUILD_DIR}/texk/kpathsea"
  pushd "${BUILD_DIR}/texk/kpathsea" >/dev/null
  emconfigure "${SRC_DIR}/texk/kpathsea/configure" \
    --build=x86_64-pc-linux-gnu \
    --host=wasm32-unknown-emscripten \
    --disable-shared \
    --enable-static \
    --with-system-zlib=no
  popd >/dev/null
fi
if [ ! -f "${BUILD_DIR}/texk/ptexenc/Makefile" ]; then
  mkdir -p "${BUILD_DIR}/texk/ptexenc"
  pushd "${BUILD_DIR}/texk/ptexenc" >/dev/null
  emconfigure "${SRC_DIR}/texk/ptexenc/configure" \
    --build=x86_64-pc-linux-gnu \
    --host=wasm32-unknown-emscripten \
    --disable-shared \
    --enable-static
  popd >/dev/null
fi
if [ ! -f "${BUILD_DIR}/texk/web2c/Makefile" ]; then
  mkdir -p "${BUILD_DIR}/texk/web2c"
  pushd "${BUILD_DIR}/texk/web2c" >/dev/null
  emconfigure "${SRC_DIR}/texk/web2c/configure" \
    --build=x86_64-pc-linux-gnu \
    --host=wasm32-unknown-emscripten \
    --disable-all-pkgs \
    --enable-web2c \
    --enable-luatex \
    --disable-mp \
    --disable-luahbtex \
    --disable-luajittex \
    --disable-luajithbtex \
    --disable-xetex \
    --disable-mflua \
    --disable-mfluajit \
    --disable-shared \
    --enable-static \
    --without-x \
    --disable-synctex \
    --disable-multiplatform
  popd >/dev/null
fi

TEXK_MAKEFILE="${BUILD_DIR}/texk/Makefile"
if [ -f "${TEXK_MAKEFILE}" ]; then
  python3 - <<PY
from pathlib import Path
import re

path = Path("${TEXK_MAKEFILE}")
data = path.read_text()
data = re.sub(r"^MAKE_SUBDIRS = .*?$", "MAKE_SUBDIRS = web2c", data, flags=re.MULTILINE)
data = re.sub(r"^CONF_SUBDIRS = .*?$", "CONF_SUBDIRS = web2c", data, flags=re.MULTILINE)
path.write_text(data)
PY
fi

WEB2C_MAKEFILE="${BUILD_DIR}/texk/web2c/Makefile"
if [ -f "${WEB2C_MAKEFILE}" ]; then
  python3 - <<PY
from pathlib import Path
import re

path = Path("${WEB2C_MAKEFILE}")
data = path.read_text()
cflags = "CFLAGS = -O0 -g -fno-strict-aliasing -fwrapv -fno-omit-frame-pointer"
cxxflags = "CXXFLAGS = -O0 -g -fno-strict-aliasing -fwrapv -fno-omit-frame-pointer"
data = re.sub(r"^CFLAGS = .*?$", cflags, data, flags=re.MULTILINE)
data = re.sub(r"^CXXFLAGS = .*?$", cxxflags, data, flags=re.MULTILINE)
path.write_text(data)
PY
fi

LIBS_SUBDIRS="zlib lua53 libpng freetype2 pixman cairo gmp mpfr mpfi xpdf zziplib pplib"
LIBS_MAKEFILE="${BUILD_DIR}/libs/Makefile"
if [ -f "${LIBS_MAKEFILE}" ]; then
  python3 - <<PY
from pathlib import Path
import re

path = Path("${LIBS_MAKEFILE}")
data = path.read_text()
data = re.sub(r"^MAKE_SUBDIRS = .*?$", "MAKE_SUBDIRS = ${LIBS_SUBDIRS}", data, flags=re.MULTILINE)
data = re.sub(r"^CONF_SUBDIRS = .*?$", "CONF_SUBDIRS = ${LIBS_SUBDIRS}", data, flags=re.MULTILINE)
path.write_text(data)
PY
fi

ICU_MAKEFILE="${BUILD_DIR}/libs/icu/Makefile"
if [ ! -f "${ICU_MAKEFILE}" ] && [ -d "${SRC_DIR}/libs/icu" ]; then
  mkdir -p "${BUILD_DIR}/libs/icu"
  pushd "${BUILD_DIR}/libs/icu" >/dev/null
  emconfigure "${SRC_DIR}/libs/icu/configure" \
    --build=x86_64-pc-linux-gnu \
    --host=wasm32-unknown-emscripten \
    --disable-all-pkgs \
    --enable-web2c \
    --enable-luatex \
    --disable-mp \
    --disable-luahbtex \
    --disable-luajittex \
    --disable-luajithbtex \
    --disable-xetex \
    --disable-mflua \
    --disable-mfluajit \
    --disable-shared \
    --enable-static \
    --without-x \
    --disable-synctex \
    --disable-multiplatform
  popd >/dev/null
fi
if [ -f "${ICU_MAKEFILE}" ]; then
  python3 - <<PY
from pathlib import Path
import re

path = Path("${ICU_MAKEFILE}")
data = path.read_text()
data = re.sub(
    r"^icu_native_args = .*?$",
    "icu_native_args = --disable-strict --build=x86_64-pc-linux-gnu --host=x86_64-pc-linux-gnu --disable-icuio 'CC=gcc' 'CXX=g++' 'AR=ar' 'RANLIB=ranlib'",
    data,
    flags=re.MULTILINE,
)
path.write_text(data)
PY
fi

ICU_MH_SRC="${SRC_DIR}/libs/icu/icu-src/source/config/mh-linux"
ICU_MH_DST="${BUILD_DIR}/libs/icu/icu-build/config/mh-unknown"
ICU_MH_SRC_UNKNOWN="${SRC_DIR}/libs/icu/icu-src/source/config/mh-unknown"
if [ -f "${ICU_MH_SRC}" ]; then
  cp -f "${ICU_MH_SRC}" "${ICU_MH_SRC_UNKNOWN}"
fi
if [ -f "${ICU_MH_SRC}" ]; then
  mkdir -p "$(dirname "${ICU_MH_DST}")"
  cp -f "${ICU_MH_SRC}" "${ICU_MH_DST}"
fi

emmake make -C libs -j"$(nproc)"

ZZIP_CONFIG="${BUILD_DIR}/libs/zziplib/include/zzip/_config.h"
if [ -f "${ZZIP_CONFIG}" ]; then
  python3 - <<PY
from pathlib import Path

path = Path("${ZZIP_CONFIG}")
data = path.read_text()
if "ZZIP_off64_t" not in data:
    data += "\\n#ifndef ZZIP_off64_t\\n#define ZZIP_off64_t off_t\\n#endif\\n"
    path.write_text(data)
PY
fi

# luatex に必要な最小サブコンポーネントをビルド
emmake make -C texk/kpathsea -j"$(nproc)"
emmake make -C texk/ptexenc -j"$(nproc)"

# luatex のみビルド
emmake make -C texk/web2c luatex -j"$(nproc)"

# 最終リンク時に preloaded texmf を付与
rm -f "${BUILD_DIR}/texk/web2c/luatex.js" "${BUILD_DIR}/texk/web2c/luatex.data" "${BUILD_DIR}/texk/web2c/luatex.wasm"
emmake make -C texk/web2c luatex.js \
  LDFLAGS="${EM_LDFLAGS} ${PRELOAD_FLAGS}" \
  EXEEXT=.js

popd >/dev/null

LUA_JS="${BUILD_DIR}/texk/web2c/luatex.js"
LUA_WASM="${BUILD_DIR}/texk/web2c/luatex.wasm"
LUA_DATA="${BUILD_DIR}/texk/web2c/luatex.data"

if [ ! -f "${LUA_JS}" ]; then
  echo "luatex.js not found: ${LUA_JS}" >&2
  exit 1
fi

mkdir -p "${OUTPUT_DIR}"
cp -a "${LUA_JS}" "${OUTPUT_DIR}/luatex.js"
cp -a "${LUA_JS}" "${DOCS_DIR}/luatex.js"
if [ -f "${LUA_WASM}" ]; then
  cp -a "${LUA_WASM}" "${OUTPUT_DIR}/luatex.wasm"
  cp -a "${LUA_WASM}" "${DOCS_DIR}/luatex.wasm"
fi
if [ -f "${LUA_DATA}" ]; then
  cp -a "${LUA_DATA}" "${OUTPUT_DIR}/luatex.data"
  cp -a "${LUA_DATA}" "${DOCS_DIR}/luatex.data"
fi

# lualatex.fmt を生成して wasm/{year} に配置
FMT_CACHE_DIR="${ROOT_DIR}/build/node-run"
FMT_CACHE="${FMT_CACHE_DIR}/lualatex.fmt"
FMT_OUTPUT="${OUTPUT_DIR}/lualatex.fmt"
if ! command -v node >/dev/null 2>&1; then
  echo "node not found: required to generate lualatex.fmt" >&2
  exit 1
fi
rm -f "${FMT_CACHE}"
FMT_SCRIPT="${ROOT_DIR}/build/run-node-fmt.mjs"
cat > "${FMT_SCRIPT}" <<'JS'
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { fileURLToPath, pathToFileURL } from "node:url";
import path from "node:path";

const wasmDir = process.env.LUATEX_WASM_DIR;
if (!wasmDir) {
  throw new Error("LUATEX_WASM_DIR is not set");
}
const wasmDirUrl = pathToFileURL(path.resolve(wasmDir) + "/");
const outDir = path.resolve("build", "node-run");
mkdirSync(outDir, { recursive: true });

const envOverrides = {
  TEXMFCNF: "/texmf/texmf-dist/web2c",
  TEXMFROOT: "/texmf",
  TEXMFDIST: "/texmf/texmf-dist",
  TEXMFMAIN: "/texmf/texmf-dist",
  TEXMFVAR: "/texmf/texmf-var",
  TEXMFSYSCONFIG: "/texmf/texmf-config",
  TEXMFCONFIG: "/texmf/texmf-config",
  TEXMF: "/texmf/texmf-var,/texmf/texmf-dist",
  TEXMFDBS: "/texmf/texmf-dist",
  TEXMFHOME: "/texmf/home",
  HOME: "/texmf/home",
  TEXINPUTS: ".;/texmf/texmf-dist/tex//;",
  TEXFORMATS: "/texmf/texmf-var/web2c//;/texmf/texmf-dist/web2c//;",
  KPATHSEA_DEBUG: "0",
};

const fmtDir = "/texmf/texmf-var/web2c";
const fmtName = "lualatex";
const fmtIni = "lualatex.ini";
const fmtPath = `${fmtDir}/${fmtName}.fmt`;
const fmtHostPath = path.join(outDir, `${fmtName}.fmt`);

const ensureDir = (module, dir) => {
  const parts = dir.split("/").filter(Boolean);
  let current = "";
  for (const part of parts) {
    current += `/${part}`;
    try {
      module.FS.mkdir(current);
    } catch {
      // ignore
    }
  }
};

const createModule = async () => {
  const createLuaTeX = (await import(new URL("./luatex.js", wasmDirUrl))).default;
  return createLuaTeX({
    locateFile: (p) => fileURLToPath(new URL(p, wasmDirUrl)),
    thisProgram: "/texmf/bin/luatex",
    noExitRuntime: true,
    noInitialRun: true,
    ENV: envOverrides,
  });
};

const setupModule = (module) => {
  ensureDir(module, "/texmf");
  ensureDir(module, "/texmf/bin");
  ensureDir(module, "/texmf/texmf-var/web2c");
  ensureDir(module, "/texmf/texmf-dist/web2c");
  ensureDir(module, "/work");

  module.FS.writeFile("/texmf/bin/luatex", "");
  try {
    const cnfSrc = "/texmf/texmf-dist/web2c/texmf.cnf";
    const cnfDst = "/texmf-dist/web2c/texmf.cnf";
    const cnfData = module.FS.readFile(cnfSrc);
    module.FS.writeFile(cnfDst, cnfData);
  } catch {
    // ignore missing cnf
  }

};

const main = async () => {
  const module = await createModule();
  setupModule(module);
  const iniDir = "/texmf/texmf-dist/tex/latex/tex-ini-files";
  const prevCwd = module.FS.cwd();
  module.FS.chdir(iniDir);
  module.callMain([
    `-progname=${fmtName}`,
    "-ini",
    `-jobname=${fmtName}`,
    "-interaction=nonstopmode",
    "-halt-on-error",
    "-output-directory",
    fmtDir,
    fmtIni,
  ]);
  module.FS.chdir(prevCwd);
  const fmtBytes = module.FS.readFile(fmtPath);
  writeFileSync(fmtHostPath, fmtBytes);
};

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
JS
LUATEX_WASM_DIR="${OUTPUT_DIR}" node "${FMT_SCRIPT}"
if [ -f "${FMT_CACHE}" ]; then
  cp -a "${FMT_CACHE}" "${FMT_OUTPUT}"
  cp -a "${FMT_CACHE}" "${DOCS_DIR}/lualatex.fmt"
else
  echo "lualatex.fmt not generated: ${FMT_CACHE}" >&2
  exit 1
fi

echo "[ok] build complete -> wasm/${TL_YEAR}/luatex.js (.wasm/.data/.fmt)"
