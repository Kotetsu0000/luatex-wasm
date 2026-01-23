// Copyright (c) 2026 kotetsu0000
// SPDX-License-Identifier: GPL-2.0-only

const statusEl = document.getElementById("status");
const logEl = document.getElementById("log");
const runBtn = document.getElementById("run");
const sourceEl = document.getElementById("source");
const fileInput = document.getElementById("file-input");
const styleInput = document.getElementById("style-input");
const styleList = document.getElementById("style-list");
const styleCount = document.getElementById("style-count");
const pdfFrame = document.getElementById("pdf-frame");
const downloadLink = document.getElementById("download");
const metaEl = document.getElementById("meta");

let activeUrl;
let running = false;
let worker;
let jobId = 0;
const BUILD_ID = Date.now().toString();

const styleFiles = new Map();

const defaultSource = String.raw`\documentclass[a4paper,11pt]{ltjsarticle}

% 数式
\usepackage{amsmath,amssymb}

% emath（例：\bunsuu など）
\usepackage{emath}

% TikZ
\usepackage{tikz}
\usetikzlibrary{calc}

\begin{document}

\section{日本語と emath の使用例}
これは Lua\TeX{}（Lua\LaTeX）でコンパイルできるサンプルです。日本語も含みます。

次の式は emath の分数マクロ \verb|\bunsuu| を使っています：
\[
  \bunsuu{1}{2} + \bunsuu{1}{3} = \bunsuu{5}{6}
\]

\section{TikZ による幾何学模様}
\begin{center}
\begin{tikzpicture}[scale=3, line join=round, line cap=round]
  % 外接円
  \draw (0,0) circle [radius=1];

  % 12本の半径（放射状）
  \foreach \a in {0,30,...,330}{
    \draw (0,0) -- (\a:1);
  }

  % 星形多角形（12点を飛び飛びに結ぶ）
  \foreach \a in {0,30,...,330}{
    \draw (\a:1) -- (\a+150:1);
  }

  % ロゼット（花弁状）：内側円周上の点を中心とする同半径円を重ねる
  \foreach \a in {0,30,...,330}{
    \draw (\a:0.5) circle [radius=0.5];
  }

  % 中央の正六角形
  \foreach \a/\name in {0/H0,60/H1,120/H2,180/H3,240/H4,300/H5}{
    \coordinate (\name) at (\a:0.55);
  }
  \draw (H0)--(H1)--(H2)--(H3)--(H4)--(H5)--cycle;
\end{tikzpicture}
\end{center}

\section{日本語の説明}
上の図は、円周上の12点を放射状に結び、星形多角形とロゼット（花弁）を重ねた幾何学模様です。

\end{document}
`;

sourceEl.value = defaultSource;

const appendLog = (text) => {
  if (!text) return;
  const next = document.createElement("div");
  next.textContent = text;
  logEl.appendChild(next);
  const limit = 300;
  while (logEl.childElementCount > limit) {
    logEl.removeChild(logEl.firstChild);
  }
  logEl.scrollTop = logEl.scrollHeight;
};

const setStatus = (text) => {
  statusEl.textContent = text;
};

const resetLog = () => {
  logEl.textContent = "";
};

const setSource = (text) => {
  sourceEl.value = text;
};

const readFileText = (file) =>
  new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(String(reader.result ?? ""));
    reader.onerror = () => reject(reader.error ?? new Error("file read failed"));
    reader.readAsText(file);
  });

const formatBytes = (size) => `${(size / 1024).toFixed(1)} KB`;

const sanitizeFileName = (name) => {
  const base = name.replace(/[\\/]/g, "_").trim();
  return base || "style.sty";
};

const uniqueSafeName = (name, existing) => {
  if (!existing.has(name)) return name;
  const dot = name.lastIndexOf(".");
  const stem = dot >= 0 ? name.slice(0, dot) : name;
  const ext = dot >= 0 ? name.slice(dot) : "";
  let i = 2;
  while (existing.has(`${stem}-${i}${ext}`)) i += 1;
  return `${stem}-${i}${ext}`;
};

const renderStyleList = () => {
  if (!styleList) return;
  styleList.textContent = "";
  if (styleFiles.size === 0) {
    const empty = document.createElement("div");
    empty.className = "style-empty";
    empty.textContent = "No styles loaded.";
    styleList.appendChild(empty);
  } else {
    for (const [key, entry] of styleFiles.entries()) {
      const item = document.createElement("div");
      item.className = "style-item";

      const info = document.createElement("div");
      info.className = "style-info";

      const name = document.createElement("div");
      name.className = "style-name";
      name.textContent = entry.name;

      const meta = document.createElement("div");
      meta.className = "style-meta";
      const metaParts = [];
      if (entry.sizeLabel) metaParts.push(entry.sizeLabel);
      if (entry.safeName !== entry.name) {
        metaParts.push(`saved as ${entry.safeName}`);
      }
      meta.textContent = metaParts.join(" · ");

      info.append(name, meta);

      const removeBtn = document.createElement("button");
      removeBtn.type = "button";
      removeBtn.className = "style-remove";
      removeBtn.textContent = "Remove";
      removeBtn.addEventListener("click", () => {
        styleFiles.delete(key);
        renderStyleList();
      });

      item.append(info, removeBtn);
      styleList.appendChild(item);
    }
  }
  if (styleCount) {
    styleCount.textContent = String(styleFiles.size);
  }
};

const ensureWorker = () => {
  if (worker) return worker;
  const workerUrl = new URL("./worker.js", import.meta.url);
  workerUrl.searchParams.set("build", BUILD_ID);
  worker = new Worker(workerUrl, { type: "module" });
  worker.addEventListener("message", (event) => {
    const data = event.data ?? {};
    if (data.id && data.id !== jobId) return;
    if (data.type === "log") {
      appendLog(data.text);
      return;
    }
    if (data.type === "status") {
      setStatus(data.text);
      return;
    }
    if (data.type === "result") {
      const bytes = new Uint8Array(data.pdf ?? []);
      const blob = new Blob([bytes], { type: "application/pdf" });
      if (activeUrl) {
        URL.revokeObjectURL(activeUrl);
      }
      activeUrl = URL.createObjectURL(blob);
      pdfFrame.src = activeUrl;
      downloadLink.href = activeUrl;
      metaEl.textContent = `PDF size: ${(blob.size / 1024).toFixed(1)} KB`;
      setStatus("done");
      running = false;
      runBtn.disabled = false;
      return;
    }
    if (data.type === "error") {
      appendLog(`ERROR: ${data.message ?? data.error ?? data}`);
      setStatus("error");
      running = false;
      runBtn.disabled = false;
    }
  });
  worker.addEventListener("error", (event) => {
    appendLog(`ERROR: ${event.message}`);
    setStatus("error");
    running = false;
    runBtn.disabled = false;
  });
  return worker;
};

const compile = () => {
  if (running) return;
  running = true;
  runBtn.disabled = true;
  setStatus("loading...");
  resetLog();
  appendLog("--- run ---");

  const styles = Array.from(styleFiles.values()).map((entry) => ({
    name: entry.name,
    safeName: entry.safeName,
    content: entry.content,
  }));

  jobId += 1;
  ensureWorker().postMessage({
    type: "compile",
    id: jobId,
    source: sourceEl.value,
    styles,
    buildId: BUILD_ID,
  });
};

runBtn.addEventListener("click", () => {
  compile();
});

if (fileInput) {
  fileInput.addEventListener("change", async (event) => {
    const [file] = event.target.files ?? [];
    if (!file) return;
    try {
      const text = await readFileText(file);
      setSource(text);
      appendLog(`Loaded ${file.name}`);
      setStatus("ready");
    } catch (err) {
      appendLog(`ERROR: ${err.message ?? err}`);
      setStatus("error");
    } finally {
      event.target.value = "";
    }
  });
}

if (styleInput) {
  styleInput.addEventListener("change", async (event) => {
    const files = Array.from(event.target.files ?? []);
    if (!files.length) return;
    try {
      const existingSafeNames = new Set(
        Array.from(styleFiles.values(), (entry) => entry.safeName),
      );
      const entries = await Promise.all(
        files.map(async (file) => {
          const content = await readFileText(file);
          let safeName = sanitizeFileName(file.name);
          if (styleFiles.has(file.name)) {
            safeName = styleFiles.get(file.name).safeName;
          } else {
            safeName = uniqueSafeName(safeName, existingSafeNames);
            existingSafeNames.add(safeName);
          }
          return {
            name: file.name,
            safeName,
            sizeLabel: formatBytes(file.size),
            content,
          };
        }),
      );
      for (const entry of entries) {
        styleFiles.set(entry.name, entry);
      }
      renderStyleList();
      appendLog(`Added ${entries.length} style file(s)`);
      setStatus("ready");
    } catch (err) {
      appendLog(`ERROR: ${err.message ?? err}`);
      setStatus("error");
    } finally {
      event.target.value = "";
    }
  });
}

renderStyleList();
setStatus("ready");
