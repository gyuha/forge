"use strict";
// Shared, side-effect-free survey. CLI formatting stays in forge-status.js.
const fs = require("fs");
const path = require("path");
function surveyForge(root, { bounded = false } = {}) {
  const MAX_BYTES = 256 * 1024;
  const absoluteRoot = path.resolve(root);
  // Browser reads cannot follow symlinks, including a symlinked directory.
  // The CLI retains its historical behavior when this option is absent.
  const safePath = (p) => {
    if (!bounded) return true;
    const absolute = path.resolve(p);
    const relative = path.relative(absoluteRoot, absolute);
    if (
      relative === ".." ||
      relative.startsWith(".." + path.sep) ||
      path.isAbsolute(relative)
    )
      return false;
    try {
      if (fs.realpathSync(absoluteRoot) !== absoluteRoot) return false;
      let current = absoluteRoot;
      if (fs.lstatSync(current).isSymbolicLink()) return false;
      for (const part of relative.split(path.sep).filter(Boolean)) {
        current = path.join(current, part);
        if (fs.lstatSync(current).isSymbolicLink()) return false;
      }
      return true;
    } catch {
      return false;
    }
  };
  const list = (dir) => {
    if (!safePath(dir)) return [];
    const names = fs.readdirSync(dir);
    return bounded ? names.slice(0, 1000) : names;
  };
  const DONE_ROWS = 5;
  const isDir = (p) => {
    try {
      return safePath(p) && fs.statSync(p).isDirectory();
    } catch (_) {
      return false;
    }
  };
  const isFile = (p) => {
    try {
      const stat = safePath(p) && fs.statSync(p);
      return !!stat && stat.isFile() && (!bounded || stat.size <= MAX_BYTES);
    } catch (_) {
      return false;
    }
  };
  const read = (p) => {
    try {
      if (!bounded) return fs.readFileSync(p, "utf8");
      if (!isFile(p)) return "";
      const fd = fs.openSync(
        p,
        fs.constants.O_RDONLY | (fs.constants.O_NOFOLLOW || 0),
      );
      try {
        const stat = fs.fstatSync(fd);
        if (!stat.isFile() || stat.size > MAX_BYTES) return "";
        const bytes = Buffer.alloc(MAX_BYTES + 1);
        const size = fs.readSync(fd, bytes, 0, bytes.length, 0);
        return size > MAX_BYTES ? "" : bytes.toString("utf8", 0, size);
      } finally {
        fs.closeSync(fd);
      }
    } catch (_) {
      return "";
    }
  };

  // --- Field extractors (accept both `field:` and `- field:` forms) -----------
  function field(file, name) {
    if (!isFile(file)) return "";
    const re = new RegExp(`^[\\t ]*-?[\\t ]*${name}:[\\t ]*(\\S*)`, "m");
    const m = read(file).match(re);
    return m ? m[1] : "";
  }
  function slugof(file) {
    const m = read(file).match(/forge-slug:[\t ]*(\S*)[\t ]*-->/);
    return m ? m[1] : "";
  }
  function taskof(file) {
    const m = read(file).match(/task:[\t ]*([0-9]+)/);
    return m ? m[1] : "";
  }
  function looptag(file) {
    return /generated-by:[\t ]*fg-loop/.test(read(file)) ? " (loop)" : "";
  }
  // Normalize a STATUS field token before deciding on it — see the .sh twin.
  const norm = (v) =>
    (String(v || "")
      .toLowerCase()
      .match(/^[a-z/]*/) || [""])[0];
  function vsym(v) {
    switch (norm(v)) {
      case "yes":
        return "O";
      case "skipped":
      case "n/a":
        return "~";
      case "failed":
        return "x";
      default:
        return "-";
    }
  }
  // EXACT match, not a `*-<slug>.md` suffix glob — see the .sh twin's comment.
  const RETRO_PREFIX = /^(\d{6}-\d{6}[a-z]?|\d{4}-\d{2}-\d{2})$/;
  function retroFileExists(slug) {
    const dir = path.join(root, "retro");
    if (!isDir(dir)) return false;
    const suffix = `-${slug}.md`;
    return list(dir).some(
      (f) =>
        f.endsWith(suffix) && RETRO_PREFIX.test(f.slice(0, -suffix.length)),
    );
  }
  function rsym(r, slug) {
    const n = norm(r);
    if (n === "skipped") return "X";
    if (n === "" || n === "pending") return retroFileExists(slug) ? "O" : "-";
    return "O"; // a retro path
  }

  const lsMd = (dir) =>
    isDir(dir)
      ? list(dir)
          .filter(
            (f) => f.endsWith(".md") && (!bounded || isFile(path.join(dir, f))),
          )
          .sort()
      : [];
  const subDirs = (dir) =>
    isDir(dir)
      ? list(dir)
          .filter((f) => isDir(path.join(dir, f)))
          .sort()
      : [];

  // --- Collect rows -----------------------------------------------------------
  const rows = [];
  const addRow = (no, date, task, stage, v, r) =>
    rows.push([no, date, task, stage, v, r]);

  // Active slot
  const planPath = path.join(root, "plan.md");
  if (isFile(planPath)) {
    let slug = slugof(planPath) || "plan";
    let no = taskof(planPath);
    no = no ? `#${no}` : "-";
    const tag = looptag(planPath);
    const st = path.join(root, "STATUS.md");
    if (isFile(path.join(root, "run.md"))) {
      let date = field(st, "executed") || "-";
      const v = field(st, "verified");
      // Stage is gated on the verification gate, not on run.md's existence — see
      // the bash twin's comment (fg-run still owns a pending/failed UAT).
      const stage = ["yes", "skipped", "n/a"].includes(norm(v))
        ? "learn"
        : "run";
      addRow(
        no,
        date,
        `${slug}${tag}`,
        stage,
        vsym(v),
        rsym(field(st, "retro"), slug),
      );
    } else {
      addRow(no, "-", `${slug}${tag}`, "run", "-", "-");
    }
  }

  // Backlog — ordered by fg-run's selection contract: priority(high→med→low) →
  // part N → slug (NOT filename glob order, which misorders priorities and 10+ parts
  // vs how fg-run actually runs — ADR-0022 review). Mirrors the .sh `LC_ALL=C sort`.
  const prioRank = (txt) => {
    const m = txt.match(/priority:[\t ]*([A-Za-z]+)/);
    const p = m ? m[1] : "";
    return p === "high" ? 0 : p === "low" ? 2 : 1;
  };
  const partPad = (txt) => {
    const m = txt.match(/part:[\t ]*([0-9]+)\//);
    return m ? String(m[1]).padStart(3, "0") : "000";
  };
  const backlogDir = path.join(root, "backlog");
  if (isDir(backlogDir)) {
    const entries = list(backlogDir)
      .filter(
        (f) =>
          f.endsWith(".md") && (!bounded || isFile(path.join(backlogDir, f))),
      )
      .map((f) => {
        const fp = path.join(backlogDir, f);
        const txt = read(fp);
        const slug = slugof(fp) || path.basename(f, ".md");
        return { key: `${prioRank(txt)}\t${partPad(txt)}\t${slug}`, fp, slug };
      });
    entries.sort((a, b) => (a.key < b.key ? -1 : a.key > b.key ? 1 : 0));
    for (const e of entries) {
      let no = taskof(e.fp);
      no = no ? `#${no}` : "-";
      addRow(no, "-", `${e.slug}${looptag(e.fp)}`, "ask", "-", "-");
    }
  }

  // Awaiting retro (executed/)
  for (const d of subDirs(path.join(root, "executed"))) {
    const dir = path.join(root, "executed", d);
    const p = path.join(dir, "plan.md");
    const st = path.join(dir, "STATUS.md");
    let slug = slugof(p) || d;
    let no = taskof(p);
    no = no ? `#${no}` : "-";
    let date = field(st, "executed") || "-";
    const v = field(st, "verified");
    // Only `failed` goes back to fg-run (unpark); a parked `pending` routes to
    // fg-learn — see the bash twin's comment.
    const stage = norm(v) === "failed" ? "run" : "learn";
    addRow(
      no,
      date,
      `${slug}${looptag(p)}`,
      stage,
      vsym(v),
      rsym(field(st, "retro"), slug),
    );
  }

  // Done (most recent DONE_ROWS by directory name, which is date-prefixed)
  let doneTotal = 0;
  const doneRoot = path.join(root, "done");
  if (isDir(doneRoot)) {
    const dirs = subDirs(doneRoot);
    doneTotal = dirs.length;
    const recent = dirs.slice().sort().reverse().slice(0, DONE_ROWS);
    for (const name of recent) {
      const dir = path.join(doneRoot, name);
      const p = path.join(dir, "plan.md");
      const st = path.join(dir, "STATUS.md");
      // Date from STATUS (format-agnostic YYYY-MM-DD); fall back to the legacy dirname prefix.
      // The dir name is a timestamp prefix (YYMMDD-HHMMSS or old YYYY-MM-DD), NOT always a date.
      // Fallback split by FORM, not fixed offsets — see the .sh twin.
      const m = name.match(/^(\d{6}-\d{6}[a-z]?|\d{4}-\d{2}-\d{2})-(.+)$/);
      const idPfx = m ? m[1] : name;
      const nameSlug = m ? m[2] : name;
      const date = field(st, "completed") || field(st, "executed") || idPfx;
      let slug = slugof(p) || field(st, "slug") || nameSlug;
      let no = taskof(p);
      no = no ? `#${no}` : "-";
      addRow(
        no,
        date,
        `${slug}${looptag(p)}`,
        "done",
        vsym(field(st, "verified")),
        rsym(field(st, "retro"), slug),
      );
    }
  }

  let quickN = 0;
  const logPath = path.join(root, "quick", "LOG.md");
  if (isFile(logPath)) {
    quickN = read(logPath)
      .split("\n")
      .filter((l) => /^## /.test(l)).length;
  }
  const retroN = lsMd(path.join(root, "retro")).length;
  let adrDir = path.join(root, "adr");
  if (!isDir(adrDir)) adrDir = ".forge/adr";
  const adrN = lsMd(adrDir).length;

  let footer = `done: ${doneTotal} · quick: ${quickN} · retro: ${retroN} · adr: ${adrN}`;
  const loopPath = path.join(root, "loop.md");
  if (isFile(loopPath)) {
    const rnd = field(loopPath, "replan-round");
    const cap = field(loopPath, "replan-cap");
    if (rnd && cap) footer += ` · loop: r${rnd}/${cap}`;
  }
  return { exists: isDir(root), rows, footer };
}
module.exports = { surveyForge };
