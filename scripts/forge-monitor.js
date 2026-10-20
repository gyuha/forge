#!/usr/bin/env node
"use strict";
// Node 22+, no shell service or external dependencies. Never signals stored PIDs.
const fs = require("node:fs");
const path = require("node:path");
const os = require("node:os");
const http = require("node:http");
const crypto = require("node:crypto");
const { fork, execFileSync } = require("node:child_process");
const { resolveForgeRoot } = require("./resolve-forge-root.js");
const { surveyForge } = require("./forge-status-query.js");
const EVENTS = new Set([
  "SessionStart",
  "SessionEnd",
  "UserPromptSubmit",
  "Stop",
  "SubagentStart",
  "SubagentStop",
  "PreToolUse",
  "PostToolUse",
  "PostToolUseFailure",
  "PermissionRequest",
  "Notification",
]);
const hash = (value) => crypto.createHash("sha256").update(value).digest("hex");
const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
const text = (value) =>
  typeof value === "string" ? value.slice(0, 160) : null;
function readJSON(file) {
  try {
    if (fs.statSync(file).size > 2 * 1024 * 1024) return null;
    return JSON.parse(fs.readFileSync(file, "utf8"));
  } catch {
    return null;
  }
}
function writeJSON(file, value) {
  const tmp = file + "." + crypto.randomUUID() + ".tmp";
  fs.writeFileSync(tmp, JSON.stringify(value), { mode: 0o600, flag: "wx" });
  try {
    fs.renameSync(tmp, file);
  } finally {
    try {
      fs.unlinkSync(tmp);
    } catch {}
  }
}
function alive(pid) {
  try {
    process.kill(pid, 0);
    return true;
  } catch {
    return false;
  }
}
function fingerprint(pid) {
  if (process.platform !== "linux") return null;
  try {
    return fs
      .readFileSync(`/proc/${pid}/stat`, "utf8")
      .split(") ")[1]
      .split(" ")[19];
  } catch {
    return null;
  }
}
function ownerAlive(r) {
  return (
    alive(r.ownerPid) &&
    (!r.ownerFingerprint || fingerprint(r.ownerPid) === r.ownerFingerprint)
  );
}
function projectContext(cwd = process.cwd()) {
  cwd = fs.realpathSync(cwd);
  let project = cwd,
    branch = "(detached)";
  try {
    project = fs.realpathSync(
      execFileSync("git", ["rev-parse", "--show-toplevel"], {
        cwd,
        stdio: ["ignore", "pipe", "ignore"],
      })
        .toString()
        .trim(),
    );
    branch = execFileSync("git", ["rev-parse", "--abbrev-ref", "HEAD"], {
      cwd,
      stdio: ["ignore", "pipe", "ignore"],
    })
      .toString()
      .trim();
  } catch {}
  const forgeRoot = path.resolve(cwd, resolveForgeRoot(cwd).root);
  return { name: path.basename(project), path: project, branch, forgeRoot };
}
function identity(env = process.env) {
  const id = env.CLAUDE_CODE_SESSION_ID;
  const pid = Number(env.CLAUDE_PID);
  if (
    !id ||
    id.length > 256 ||
    !Number.isSafeInteger(pid) ||
    pid <= 1 ||
    !alive(pid)
  )
    throw Error(
      "Claude session ownership unavailable: CLAUDE_CODE_SESSION_ID and live CLAUDE_PID required",
    );
  return { id, pid };
}
function baseDir(project) {
  return path.join(project.path, ".forge", "monitor");
}
function paths(project, session) {
  const base = baseDir(project);
  return {
    base,
    active: path.join(base, "active", hash(session) + ".json"),
    lock: path.join(base, "active", hash(session) + ".lock"),
  };
}
function prepare(project) {
  const base = baseDir(project);
  fs.mkdirSync(path.join(base, "active"), { recursive: true, mode: 0o700 });
  fs.mkdirSync(path.join(base, "records"), { recursive: true, mode: 0o700 });
  fs.writeFileSync(path.join(base, ".gitignore"), "*\n");
}
function config(project, allowRetentionRepair = false) {
  const file = path.join(project.path, ".forge/config.json");
  if (!fs.existsSync(file)) return {};
  let value;
  try {
    value = JSON.parse(fs.readFileSync(file, "utf8"));
  } catch {
    throw Error("Invalid .forge/config.json; repair it before starting");
  }
  if (!value || Array.isArray(value) || typeof value !== "object")
    throw Error("Invalid project configuration");
  if (
    !allowRetentionRepair &&
    value.monitorRetention !== undefined &&
    !["delete", "keep"].includes(value.monitorRetention)
  )
    throw Error("Invalid monitorRetention; expected delete or keep");
  return value;
}
function configure(project, value) {
  if (!["delete", "keep"].includes(value))
    throw Error("Expected delete or keep");
  const current = config(project, true);
  fs.mkdirSync(path.join(project.path, ".forge"), { recursive: true });
  writeJSON(path.join(project.path, ".forge/config.json"), {
    ...current,
    monitorRetention: value,
  });
  return { status: "configured", monitorRetention: value };
}
async function withLock(p, work) {
  for (let i = 0; i < 100; i++) {
    try {
      fs.mkdirSync(p);
      try {
        return await work();
      } finally {
        fs.rmSync(p, { recursive: true, force: true });
      }
    } catch (e) {
      if (e.code !== "EEXIST") throw e;
      await delay(50);
    }
  }
  throw Error(
    "Monitor operation already in progress; retry shortly (stale lock requires inspection)",
  );
}
function recordDir(project, id) {
  if (!/^[a-f0-9]{32}$/.test(id || "")) throw Error("Invalid record id");
  return path.join(baseDir(project), "records", id);
}
function runtimeFor(project, session) {
  const p = paths(project, session);
  const a = readJSON(p.active);
  if (!a || !/^[a-f0-9]{32}$/.test(a.id)) return null;
  const r = readJSON(path.join(recordDir(project, a.id), "runtime.json"));
  if (
    !r ||
    r.sessionId !== session ||
    r.project.path !== project.path ||
    r.id !== a.id
  )
    return null;
  return r;
}
function urls(r) {
  const hosts =
    r.host === "0.0.0.0"
      ? [
          "127.0.0.1",
          ...Object.values(os.networkInterfaces())
            .flat()
            .filter((x) => x && x.family === "IPv4" && !x.internal)
            .map((x) => x.address),
        ]
      : [r.host];
  return [...new Set(hosts)].map(
    (host) => `http://${host}:${r.port}/?key=${r.key}`,
  );
}
async function probe(r) {
  try {
    const response = await fetch(
      `http://127.0.0.1:${r.port}/api/identity?key=${r.key}`,
      { signal: AbortSignal.timeout(700) },
    );
    const data = await response.json();
    return response.ok && data.id === r.id;
  } catch {
    return false;
  }
}
function readEvents(dir) {
  let names = [];
  try {
    names = fs
      .readdirSync(path.join(dir, "events"))
      .filter((x) => x.endsWith(".json"))
      .sort();
  } catch {}
  return names
    .map((name) => readJSON(path.join(dir, "events", name)))
    .filter(Boolean);
}

function compactEvents(dir) {
  const eventsDir = path.join(dir, "events");
  const names = fs
    .readdirSync(eventsDir)
    .filter((name) => name.endsWith(".json"))
    .sort();
  if (!names.length)
    return reduceEvents([], readJSON(path.join(dir, "checkpoint.json")));
  const events = names
    .map((name) => readJSON(path.join(eventsDir, name)))
    .filter(Boolean);
  const checkpoint = reduceEvents(
    events,
    readJSON(path.join(dir, "checkpoint.json")),
  );
  writeJSON(path.join(dir, "checkpoint.json"), checkpoint);
  for (const name of names)
    fs.rmSync(path.join(eventsDir, name), { force: true });
  return checkpoint;
}

function reduceEvents(events, checkpoint = null) {
  const agents = checkpoint
    ? new Map(checkpoint.agents.map((a) => [a.id, { ...a }]))
    : new Map([
        [
          "main",
          {
            id: "main",
            name: "Claude",
            type: "main",
            task: null,
            status: "unknown",
            lastSeen: null,
          },
        ],
      ]);
  let sessionEnded = checkpoint?.sessionEnded === true;
  const activities = checkpoint ? [...checkpoint.activities] : [],
    seen = new Set(activities.map((e) => e.id));
  for (const e of events
    .filter((e) => e && e.id && e.time && EVENTS.has(e.event))
    .sort((a, b) => a.time.localeCompare(b.time) || a.id.localeCompare(b.id))) {
    if (seen.has(e.id)) continue;
    seen.add(e.id);
    const id = e.agentId || "main";
    if (!agents.has(id))
      agents.set(id, {
        id,
        name: e.type || id,
        type: e.type || null,
        task: null,
        status: "unknown",
        lastSeen: null,
      });
    const a = agents.get(id);
    // Delayed writes remain visible as activity, but cannot rewind current state.
    // A subagent ID represents one lifetime; a stopped agent cannot be revived.
    const latest = !a.lastSeen || e.time >= a.lastSeen;
    if (latest) {
      a.lastSeen = e.time;
      if (e.type) {
        a.type = e.type;
        a.name = e.type;
      }
      if (!sessionEnded && a.status !== "ended") {
        if (
          ["UserPromptSubmit", "PreToolUse", "SubagentStart"].includes(e.event)
        )
          a.status = "running";
        if (e.event === "Stop" || e.event === "PermissionRequest")
          a.status = "waiting";
      }
    }
    // Terminal evidence wins even if an earlier event is delivered late.
    if (e.event === "SubagentStop") a.status = "ended";
    if (e.event === "SessionEnd") sessionEnded = true;
    if (sessionEnded) for (const item of agents.values()) item.status = "ended";
    activities.push({
      id: e.id,
      time: e.time,
      event: e.event,
      agentId: id,
      tool: e.tool || null,
      error: e.event === "PostToolUseFailure",
    });
  }
  return {
    sessionEnded,
    agents: [...agents.values()].slice(-1000),
    activities: activities.slice(-100),
  };
}
function document(file) {
  try {
    if (fs.realpathSync(file) !== path.resolve(file)) return "";
    if (fs.statSync(file).size > 256 * 1024)
      return "[문서가 커서 표시하지 않습니다]";
    return fs.readFileSync(file, "utf8");
  } catch {
    return "";
  }
}
function makeSnapshot(r, endedAt = null) {
  const dir = recordDir(r.project, r.id);
  const events = readEvents(dir);
  const checkpoint = readJSON(path.join(dir, "checkpoint.json"));
  const state = reduceEvents(events, checkpoint);
  const q = surveyForge(r.project.forgeRoot, { bounded: true });
  const plan = document(path.join(r.project.forgeRoot, "plan.md"));
  const active = plan
    ? {
        plan,
        run: document(path.join(r.project.forgeRoot, "run.md")),
        status: document(path.join(r.project.forgeRoot, "STATUS.md")),
        progress: null,
      }
    : null;
  // Only explicit checklist evidence is counted; agent activity never updates tasks.
  if (active) {
    const checks = plan.match(/^\s*- \[[ xX]\] /gm) || [];
    if (checks.length)
      active.progress = {
        completed: checks.filter((x) => /\[[xX]\]/.test(x)).length,
        total: checks.length,
      };
  }
  if (endedAt)
    for (const a of state.agents)
      if (a.status !== "ended") a.status = "unknown";
  return {
    version: 1,
    project: r.project,
    session: {
      id: r.sessionId,
      startedAt: r.startedAt,
      endedAt,
      retention: r.retention,
      collection:
        events.length || checkpoint?.activities?.length
          ? "observed"
          : "unavailable",
    },
    updatedAt: new Date().toISOString(),
    tasks: {
      rows: q.rows.map(([number, date, slug, stage, verified, retro]) => ({
        number,
        date,
        slug,
        stage,
        verified,
        retro,
      })),
      active,
    },
    ...state,
  };
}
function history(r) {
  const records = [];
  for (const id of fs.readdirSync(path.join(baseDir(r.project), "records"))) {
    if (!/^[a-f0-9]{32}$/.test(id)) continue;
    const s = readJSON(path.join(recordDir(r.project, id), "summary.json"));
    if (
      s?.session?.endedAt &&
      s.project?.branch === r.project.branch &&
      s.project?.path === r.project.path
    )
      records.push({
        id,
        branch: s.project.branch,
        startedAt: s.session.startedAt,
        endedAt: s.session.endedAt,
      });
  }
  return records.sort((a, b) => b.startedAt.localeCompare(a.startedAt));
}
function cleanup(r) {
  const dir = recordDir(r.project, r.id);
  if (!fs.existsSync(dir)) return;
  if (r.retention === "keep") {
    const summary = makeSnapshot(r, new Date().toISOString());
    summary.tasks.active = null;
    writeJSON(path.join(dir, "summary.json"), summary);
    for (const name of ["runtime.json", "events", "stop", "checkpoint.json"])
      fs.rmSync(path.join(dir, name), { recursive: true, force: true });
  } else if (r.retention === "delete")
    fs.rmSync(dir, { recursive: true, force: true });
  else return;
  const p = paths(r.project, r.sessionId);
  if (readJSON(p.active)?.id === r.id) fs.rmSync(p.active, { force: true });
}
async function start(project, session, { host = "127.0.0.1", port = 0 } = {}) {
  if (!["127.0.0.1", "0.0.0.0"].includes(host))
    throw Error("Host must be 127.0.0.1 or 0.0.0.0");
  if (!Number.isInteger(port) || port < 0 || port > 65535)
    throw Error("Invalid port");
  const settings = config(project);
  if (settings.monitorRetention === undefined)
    return { status: "needs-configuration", choices: ["delete", "keep"] };
  prepare(project);
  const p = paths(project, session.id);
  return withLock(p.lock, async () => {
    const old = runtimeFor(project, session.id);
    if (old && (await probe(old))) {
      if (old.ownerPid !== session.pid) throw Error("Session owner mismatch");
      if (old.host !== host || old.project.branch !== project.branch)
        throw Error("Monitor scope/binding differs; run off before restarting");
      return {
        status: "already-running",
        host: old.host,
        port: old.port,
        url: urls(old)[0],
        urls: urls(old),
      };
    }
    if (old) {
      if (ownerAlive(old))
        throw Error(
          "Existing monitor is unreachable while its owner lives; refusing duplicate start",
        );
      cleanup(old);
    }
    const id = crypto.randomBytes(16).toString("hex");
    const r = {
      id,
      project,
      sessionId: session.id,
      ownerPid: session.pid,
      ownerFingerprint: fingerprint(session.pid),
      host,
      port,
      key: crypto.randomBytes(32).toString("hex"),
      retention: settings.monitorRetention,
      startedAt: new Date().toISOString(),
    };
    const dir = recordDir(project, id);
    fs.mkdirSync(path.join(dir, "events"), { recursive: true, mode: 0o700 });
    writeJSON(path.join(dir, "runtime.json"), r);
    try {
      const ready = await new Promise((resolve, reject) => {
        const child = fork(
          __filename,
          ["_serve", path.join(dir, "runtime.json")],
          {
            cwd: project.path,
            detached: true,
            stdio: ["ignore", "ignore", "ignore", "ipc"],
          },
        );
        const timer = setTimeout(() => {
          child.disconnect();
          child.unref();
          reject(Error("Monitor startup timed out"));
        }, 5000);
        child.once("error", (e) => {
          clearTimeout(timer);
          reject(e);
        });
        child.once("exit", (code) => {
          clearTimeout(timer);
          reject(Error("Monitor startup failed (" + code + ")"));
        });
        child.once("message", (message) => {
          clearTimeout(timer);
          child.disconnect();
          child.unref();
          if (message.error) reject(Error(message.error));
          else resolve(message);
        });
      });
      Object.assign(r, ready);
      writeJSON(p.active, { id });
      return {
        status: "started",
        host: r.host,
        port: r.port,
        url: urls(r)[0],
        urls: urls(r),
      };
    } catch (e) {
      fs.rmSync(dir, { recursive: true, force: true });
      throw e;
    }
  });
}
async function stop(project, session) {
  prepare(project);
  return withLock(paths(project, session.id).lock, async () => {
    const r = runtimeFor(project, session.id);
    if (!r) return { status: "already-stopped" };
    if (r.ownerPid !== session.pid) throw Error("Session owner mismatch");
    if (!(await probe(r))) {
      if (!ownerAlive(r)) cleanup(r);
      else
        throw Error(
          "Monitor unreachable; refusing to signal an unverified PID",
        );
      return { status: "already-stopped" };
    }
    fs.writeFileSync(path.join(recordDir(project, r.id), "stop"), r.id, {
      mode: 0o600,
    });
    for (let i = 0; i < 40; i++) {
      if (!(await probe(r))) return { status: "stopped" };
      await delay(75);
    }
    throw Error("Monitor did not stop in time");
  });
}
async function serve(file) {
  const r = readJSON(file);
  if (!r || !ownerAlive(r)) throw Error("Owner unavailable");
  const dir = recordDir(r.project, r.id);
  let stopping = false,
    timer;
  const sockets = new Set();
  const server = http.createServer((req, res) => {
    const send = (code, value, type = "application/json") => {
      res.writeHead(code, {
        "Content-Type": type,
        "Cache-Control": "no-store",
        "Referrer-Policy": "no-referrer",
        "X-Content-Type-Options": "nosniff",
        "Content-Security-Policy":
          "default-src 'self'; script-src 'self'; style-src 'self'; connect-src 'self'; img-src 'self' data:; frame-ancestors 'none'; base-uri 'none'",
      });
      res.end(type === "application/json" ? JSON.stringify(value) : value);
    };
    try {
      if (req.method !== "GET") return send(405, { error: "read-only" });
      const u = new URL(req.url, "http://localhost");
      const key = u.searchParams.get("key") || "";
      if (
        Buffer.byteLength(key) !== Buffer.byteLength(r.key) ||
        !crypto.timingSafeEqual(Buffer.from(key), Buffer.from(r.key))
      )
        return send(401, { error: "unauthorized" });
      if (u.pathname === "/api/identity") return send(200, { id: r.id });
      if (u.pathname === "/api/snapshot") return send(200, makeSnapshot(r));
      if (u.pathname === "/api/history")
        return send(200, { records: history(r) });
      const match = u.pathname.match(/^\/api\/history\/([a-f0-9]{32})$/);
      if (match) {
        const s =
          history(r).some((x) => x.id === match[1]) &&
          readJSON(path.join(recordDir(r.project, match[1]), "summary.json"));
        return s ? send(200, s) : send(404, { error: "not found" });
      }
      const assets = {
        "/": ["index.html", "text/html; charset=utf-8"],
        "/app.js": ["app.js", "text/javascript; charset=utf-8"],
        "/style.css": ["style.css", "text/css; charset=utf-8"],
      };
      if (assets[u.pathname]) {
        const [name, type] = assets[u.pathname];
        let body = fs.readFileSync(
          path.join(__dirname, "forge-monitor-ui", name),
          "utf8",
        );
        if (name === "index.html")
          body = body.replace(
            /(?:src|href)="\/?(app\.js|style\.css)"/g,
            (all, asset) => all.replace(asset, asset + "?key=" + r.key),
          );
        return send(200, body, type);
      }
      send(404, { error: "not found" });
    } catch {
      send(500, { error: "snapshot unavailable" });
    }
  });
  server.on("connection", (socket) => {
    sockets.add(socket);
    socket.on("close", () => sockets.delete(socket));
  });
  const shutdown = () => {
    if (stopping) return;
    stopping = true;
    clearInterval(timer);
    try {
      cleanup(r);
    } catch {}
    server.close(() => process.exit(0));
    for (const socket of sockets) socket.destroy();
    setTimeout(() => process.exit(0), 300).unref();
  };

  await new Promise((resolve, reject) => {
    server.once("error", reject);
    server.listen(r.port, r.host, resolve);
  });
  r.port = server.address().port;
  writeJSON(file, r);
  if (process.send) process.send({ port: r.port });
  timer = setInterval(() => {
    try {
      if (
        !ownerAlive(r) ||
        fs.existsSync(path.join(dir, "stop")) ||
        compactEvents(dir).sessionEnded
      )
        shutdown();
    } catch {
      shutdown();
    }
  }, 400);
  process.on("SIGTERM", shutdown);
  process.on("SIGINT", shutdown);
}
function collect(input, env = process.env) {
  try {
    if (
      !input ||
      !EVENTS.has(input.hook_event_name) ||
      input.session_id !== env.CLAUDE_CODE_SESSION_ID
    )
      return;
    const pid = Number(env.CLAUDE_PID);
    if (!Number.isSafeInteger(pid) || pid <= 1) return;
    // No git/subprocess work in a hook: look only for this session's active
    // pointer, then use its immutable captured project and branch.
    let projectPath = fs.realpathSync(
      env.CLAUDE_PROJECT_DIR || input.cwd || process.cwd(),
    );
    while (
      !fs.existsSync(paths({ path: projectPath }, input.session_id).active)
    ) {
      const parent = path.dirname(projectPath);
      if (parent === projectPath) return;
      projectPath = parent;
    }
    const r = runtimeFor({ path: projectPath }, input.session_id);
    if (!r || r.ownerPid !== pid || !ownerAlive(r)) return;
    const dir = path.join(recordDir(r.project, r.id), "events");
    if (!fs.existsSync(dir)) return;
    const time = new Date().toISOString(),
      id = crypto.randomUUID();
    const e = {
      id,
      time,
      event: input.hook_event_name,
      agentId: text(input.agent_id) || "main",
      type: text(input.agent_type),
      tool: text(input.tool_name),
    };
    writeJSON(path.join(dir, Date.now() + "-" + id + ".json"), e);
    // The single server checkpoints state and prunes processed event files; hooks never race on mutable state.
  } catch {
    /* Hook must never affect host decisions. */
  }
}
async function main() {
  const [action, ...args] = process.argv.slice(2);
  if (action === "_serve") {
    await serve(args[0]);
    return;
  }
  const project = projectContext();
  let result;
  if (action === "config") {
    if (args.length !== 1) throw Error("Usage: config delete|keep");
    result = configure(project, args[0]);
  } else if (action === "on" || action === "off") {
    const session = identity();
    const options = {};
    for (let i = 0; i < args.length; i += 2) {
      if (
        action === "off" ||
        !["--host", "--port"].includes(args[i]) ||
        args[i + 1] === undefined
      )
        throw Error("Usage: on [--host 0.0.0.0] [--port N] | off");
      options[args[i].slice(2)] =
        args[i] === "--port" ? Number(args[i + 1]) : args[i + 1];
    }
    result =
      action === "on"
        ? await start(project, session, options)
        : await stop(project, session);
  } else throw Error("Usage: on [--host 0.0.0.0] | off | config delete|keep");
  process.stdout.write(JSON.stringify(result) + "\n");
}
module.exports = {
  compactEvents,
  projectContext,
  configure,
  identity,
  start,
  stop,
  collect,
  reduceEvents,
  makeSnapshot,
  readEvents,
};
if (require.main === module)
  main().catch((e) => {
    if (process.send) process.send({ error: e.message });
    else
      process.stderr.write(
        JSON.stringify({ status: "error", error: e.message }) + "\n",
      );
    process.exitCode = 1;
  });
