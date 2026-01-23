// Copyright (c) 2026 kotetsu0000
// SPDX-License-Identifier: GPL-2.0-only

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
  TEXINPUTS: ".;/work//;/texmf/texmf-dist/tex//;",
  TEXFORMATS: "/texmf/texmf-var/web2c//;/texmf/texmf-dist/web2c//;",
  KPATHSEA_DEBUG: "0",
};

const fmtName = "lualatex";
const fmtPath = "/texmf/texmf-var/web2c/lualatex.fmt";
const baseUrl = new URL("./", import.meta.url);

const fmtCache = new Map();
let createLuaTeXCache = { buildId: null, fn: null };

const withBuild = (path, buildId) => {
  const url = new URL(path, baseUrl);
  if (buildId) {
    url.searchParams.set("build", buildId);
  }
  return url.toString();
};

const ensureDir = (module, dir) => {
  const parts = dir.split("/").filter(Boolean);
  let current = "";
  for (const part of parts) {
    current += `/${part}`;
    try {
      module.FS.mkdir(current);
    } catch {
      // already exists
    }
  }
};

const setupModule = (module) => {
  ensureDir(module, "/texmf/bin");
  ensureDir(module, "/texmf/texmf-var/web2c");
  ensureDir(module, "/texmf/texmf-config");
  ensureDir(module, "/texmf/home");
  ensureDir(module, "/work");
  ensureDir(module, "/texmf-dist/web2c");

  module.FS.writeFile("/texmf/bin/luatex", "");

  try {
    const cnfSrc = "/texmf/texmf-dist/web2c/texmf.cnf";
    const cnfDst = "/texmf-dist/web2c/texmf.cnf";
    const cnfData = module.FS.readFile(cnfSrc);
    module.FS.writeFile(cnfDst, cnfData);
  } catch {
    // ignore missing cnf
  }

  const env = module.ENV ?? {};
  Object.assign(env, envOverrides);
  module.ENV = env;
  if (typeof module._setenv === "function") {
    for (const [key, value] of Object.entries(env)) {
      module._setenv(key, value, 1);
    }
  }
};

const loadFmt = async (buildId) => {
  const key = buildId ?? "default";
  if (!fmtCache.has(key)) {
    const promise = fetch(withBuild("./lualatex.fmt", buildId)).then(
      async (res) => {
        if (!res.ok) {
          throw new Error(`fmt fetch failed: ${res.status}`);
        }
        return new Uint8Array(await res.arrayBuffer());
      },
    );
    fmtCache.set(key, promise);
  }
  return fmtCache.get(key);
};

const loadCreateLuaTeX = async (buildId) => {
  if (!createLuaTeXCache.fn || createLuaTeXCache.buildId !== buildId) {
    const module = await import(withBuild("./luatex.js", buildId));
    createLuaTeXCache = { buildId, fn: module.default };
  }
  return createLuaTeXCache.fn;
};

const createModule = async (id, buildId) => {
  const createLuaTeX = await loadCreateLuaTeX(buildId);
  const module = await createLuaTeX({
    locateFile: (p) => withBuild(p, buildId),
    print: (text) => self.postMessage({ type: "log", text, id }),
    printErr: (text) => self.postMessage({ type: "log", text, id }),
    thisProgram: "/texmf/bin/luatex",
    noExitRuntime: true,
    noInitialRun: true,
    preInit: () => {
      if (typeof ENV !== "undefined") {
        Object.assign(ENV, envOverrides);
      }
    },
    ENV: envOverrides,
    onAbort: (reason) => {
      throw new Error(`abort: ${reason}`);
    },
  });
  return module;
};

const compile = async (payload) => {
  const { id, source, styles, buildId } = payload;
  try {
    self.postMessage({ type: "status", text: "loading...", id });
    const [module, fmtBytes] = await Promise.all([
      createModule(id, buildId),
      loadFmt(buildId),
    ]);
    setupModule(module);
    module.FS.writeFile(fmtPath, fmtBytes);

    if (Array.isArray(styles)) {
      for (const entry of styles) {
        if (!entry?.safeName) continue;
        module.FS.writeFile(`/work/${entry.safeName}`, entry.content ?? "");
      }
    }

    module.FS.writeFile("/work/input.tex", source ?? "");
    self.postMessage({ type: "status", text: "compiling...", id });

    module.callMain([
      `-progname=${fmtName}`,
      "-interaction=nonstopmode",
      "-halt-on-error",
      `-fmt=${fmtName}`,
      "-output-directory",
      "/work",
      "/work/input.tex",
    ]);

    const pdfPath = "/work/input.pdf";
    const exists = module.FS.analyzePath(pdfPath).exists;
    if (!exists) {
      throw new Error("output.pdf not found");
    }

    const pdfBytes = module.FS.readFile(pdfPath);
    const buffer = pdfBytes.buffer.slice(
      pdfBytes.byteOffset,
      pdfBytes.byteOffset + pdfBytes.byteLength,
    );
    self.postMessage(
      { type: "result", pdf: buffer, size: pdfBytes.byteLength, id },
      [buffer],
    );
  } catch (err) {
    self.postMessage({
      type: "error",
      message: err?.message ?? String(err),
      id,
    });
  }
};

self.addEventListener("message", (event) => {
  const payload = event.data ?? {};
  if (payload.type === "compile") {
    compile(payload);
  }
});
