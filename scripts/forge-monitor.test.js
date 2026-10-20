"use strict";

// One cross-platform entry point covers runtime, browser logic and shipped hooks.
require("./forge-monitor-ui.test.js");
require("./forge-monitor-wiring.test.js");
const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawn, spawnSync } = require("node:child_process");
const { once } = require("node:events");
const monitor = require("./forge-monitor.js");
const { surveyForge } = require("./forge-status-query.js");
const cli = path.join(__dirname, "forge-monitor.js");
const hook = path.join(__dirname, "forge-hook-monitor.js");
const delay = (ms) => new Promise((r) => setTimeout(r, ms));
async function fixture(t, retention = "delete") {
  const cwd = fs.mkdtempSync(path.join(os.tmpdir(), "forge-monitor-"));
  fs.mkdirSync(path.join(cwd, ".forge"));
  if (retention !== null)
    fs.writeFileSync(
      path.join(cwd, ".forge/config.json"),
      JSON.stringify({ monitorRetention: retention, other: true }),
    );
  const owner = spawn(process.execPath, ["-e", "setInterval(()=>{},1000)"], {
    stdio: "ignore",
  });
  const env = {
    ...process.env,
    CLAUDE_PID: String(owner.pid),
    CLAUDE_CODE_SESSION_ID: crypto.randomUUID(),
    CLAUDE_PROJECT_DIR: cwd,
  };
  t.after(async () => {
    await command("off", cwd, env).catch(() => {});
    owner.kill();
    await delay(60);
    fs.rmSync(cwd, { recursive: true, force: true });
  });
  return { cwd, env, owner };
}
function command(action, cwd, env, args = []) {
  return new Promise((resolve, reject) => {
    const p = spawn(process.execPath, [cli, action, ...args], { cwd, env });
    let out = "",
      err = "";
    p.stdout.on("data", (v) => (out += v));
    p.stderr.on("data", (v) => (err += v));
    p.on("error", reject);
    p.on("exit", (code) => {
      try {
        resolve({ ...JSON.parse(out || err), code });
      } catch {
        reject(Error(out + err));
      }
    });
  });
}
function event(f, name, extra = {}) {
  const result = spawnSync(process.execPath, [hook], {
    cwd: f.cwd,
    env: f.env,
    input: JSON.stringify({
      session_id: f.env.CLAUDE_CODE_SESSION_ID,
      hook_event_name: name,
      cwd: f.cwd,
      ...extra,
    }),
    encoding: "utf8",
  });
  assert.equal(result.status, 0);
  assert.equal(result.stdout, "");
  assert.equal(result.stderr, "");
}
async function waitFor(fn, timeout = 4000) {
  const deadline = Date.now() + timeout;
  while (Date.now() < deadline) {
    if (await fn()) return;
    await delay(80);
  }
  assert.fail("condition timed out");
}
async function snapshot(url) {
  return (
    await fetch(new URL("/api/snapshot" + new URL(url).search, url))
  ).json();
}
const crypto = require("node:crypto");
test("configuration is explicit, preserves keys, rejects malformed values", async (t) => {
  const f = await fixture(t, null);
  assert.equal(
    (await command("on", f.cwd, f.env)).status,
    "needs-configuration",
  );
  assert.equal(
    (await command("config", f.cwd, f.env, ["keep"])).status,
    "configured",
  );
  assert.equal(
    JSON.parse(fs.readFileSync(path.join(f.cwd, ".forge/config.json")))
      .monitorRetention,
    "keep",
  );
  fs.writeFileSync(path.join(f.cwd, ".forge/config.json"), "{broken");
  assert.equal((await command("config", f.cwd, f.env, ["delete"])).code, 1);
  assert.equal((await command("on", f.cwd, f.env)).code, 1);
});
test("HTTP authentication, duplicate on/off, immutable scope, hook agent states and isolation", async (t) => {
  const f = await fixture(t);
  const a = await command("on", f.cwd, f.env);
  assert.equal(a.status, "started");
  assert.equal(a.host, "127.0.0.1");
  assert.equal((await command("on", f.cwd, f.env)).url, a.url);
  assert.equal(
    (await command("on", f.cwd, f.env, ["--host", "0.0.0.0"])).code,
    1,
  );
  assert.equal((await fetch(new URL("/api/snapshot", a.url))).status, 401);
  assert.equal(
    (await fetch(new URL("/api/snapshot?key=" + "한".repeat(64), a.url)))
      .status,
    401,
  );
  assert.equal(
    (await fetch(new URL("/api/snapshot?key=wrong", a.url))).status,
    401,
  );
  assert.equal(
    (
      await fetch(
        new URL("/api/history/..%2F.." + new URL(a.url).search, a.url),
      )
    ).status,
    404,
  );
  assert.equal((await fetch(a.url, { method: "POST" })).status, 405);
  event(f, "UserPromptSubmit", { prompt: "SECRET PROMPT" });
  event(f, "SubagentStart", { agent_id: "worker-a", agent_type: "Explore" });
  event(f, "PostToolUseFailure", {
    agent_id: "worker-a",
    tool_name: "Bash",
    error: "SECRET ERROR",
  });
  event(f, "Stop");
  await waitFor(async () => (await snapshot(a.url)).agents.length === 2);
  let s = await snapshot(a.url);
  assert.equal(s.agents.find((x) => x.id === "main").status, "waiting");
  assert.equal(s.agents.find((x) => x.id === "worker-a").status, "running");
  assert.equal(JSON.stringify(s).includes("SECRET"), false);
  assert.equal(s.tasks.active, null);
  event(f, "SubagentStop", { agent_id: "worker-a", agent_type: "Explore" });
  await waitFor(
    async () =>
      (await snapshot(a.url)).agents.find((x) => x.id === "worker-a").status ===
      "ended",
  );
  event(f, "SubagentStart", { session_id: "forged", agent_id: "forged" });
  assert.equal((await snapshot(a.url)).agents.length, 2);
  assert.equal((await command("off", f.cwd, f.env)).status, "stopped");
  assert.equal((await command("off", f.cwd, f.env)).status, "already-stopped");
  await waitFor(async () => {
    try {
      await fetch(a.url);
      return false;
    } catch {
      return true;
    }
  });
});
test("owner disappearance stops listener; keep archive contains no credentials and survives delete runs", async (t) => {
  const f = await fixture(t, "keep");
  const a = await command("on", f.cwd, f.env);
  event(f, "UserPromptSubmit");
  f.owner.kill();
  await waitFor(async () => {
    try {
      await fetch(a.url);
      return false;
    } catch {
      return true;
    }
  }, 10000);
  const records = path.join(f.cwd, ".forge/monitor/records");
  let names = fs.readdirSync(records);
  assert.equal(names.length, 1);
  const archived = fs.readFileSync(
    path.join(records, names[0], "summary.json"),
    "utf8",
  );
  assert.ok(JSON.parse(archived).session.endedAt);
  assert.equal(
    archived.includes(new URL(a.url).searchParams.get("key")),
    false,
  );
  assert.equal(
    fs.existsSync(path.join(records, names[0], "runtime.json")),
    false,
  );
  const owner = spawn(process.execPath, ["-e", "setInterval(()=>{},1000)"], {
    stdio: "ignore",
  });
  t.after(() => owner.kill());
  f.env.CLAUDE_PID = String(owner.pid);
  await command("config", f.cwd, f.env, ["delete"]);
  const b = await command("on", f.cwd, f.env);
  const h = await (
    await fetch(new URL("/api/history" + new URL(b.url).search, b.url))
  ).json();
  assert.equal(h.records.length, 1);
  event(f, "SessionEnd");
  await waitFor(async () => {
    try {
      await fetch(b.url);
      return false;
    } catch {
      return true;
    }
  });
  assert.equal(fs.readdirSync(records).length, 1);
});
test("session isolation, external bind, running retention fixed, stale PID never signaled", async (t) => {
  const f = await fixture(t);
  const second = { ...f.env, CLAUDE_CODE_SESSION_ID: crypto.randomUUID() };
  const a = await command("on", f.cwd, f.env, ["--host", "0.0.0.0"]);
  const b = await command("on", f.cwd, second);
  assert.equal(a.host, "0.0.0.0");
  assert.notEqual(a.port, b.port);
  event(f, "SessionEnd");
  await waitFor(async () => {
    try {
      await fetch(a.url);
      return false;
    } catch {
      return true;
    }
  });
  assert.equal((await snapshot(b.url)).version, 1);
  await command("config", f.cwd, second, ["keep"]);
  assert.equal((await snapshot(b.url)).session.retention, "delete");
  await command("off", f.cwd, second);
  assert.equal(
    fs.readdirSync(path.join(f.cwd, ".forge/monitor/records")).length,
    0,
  );
  assert.doesNotThrow(() => process.kill(f.owner.pid, 0));
});
test("missing owner/session is rejected; occupied port is reported", async (t) => {
  const f = await fixture(t);
  assert.equal(
    (await command("on", f.cwd, { ...f.env, CLAUDE_PID: "" })).code,
    1,
  );
  const a = await command("on", f.cwd, f.env);
  assert.equal(
    (
      await command(
        "on",
        f.cwd,
        { ...f.env, CLAUDE_CODE_SESSION_ID: "other" },
        ["--port", String(a.port)],
      )
    ).code,
    1,
  );
});
test("status shared query and bounded metadata handle partial/duplicate events", () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "forge-state-"));
  try {
    fs.writeFileSync(
      path.join(dir, "plan.md"),
      "<!-- forge-slug: example -->\n<!-- task: 9 -->\n# Example\n",
    );
    let q = surveyForge(dir);
    assert.equal(q.rows[0][2], "example");
    assert.equal(q.rows[0][3], "run");
    fs.writeFileSync(path.join(dir, "run.md"), "result");
    fs.writeFileSync(path.join(dir, "STATUS.md"), "verified: failed\n");
    assert.equal(surveyForge(dir).rows[0][3], "run");
    fs.writeFileSync(path.join(dir, "STATUS.md"), "verified: yes\n");
    assert.equal(surveyForge(dir).rows[0][3], "learn");
    const e = {
      id: "one",
      time: new Date().toISOString(),
      event: "SubagentStart",
      agentId: "a",
      type: "Explore",
    };
    assert.equal(monitor.reduceEvents([e, e, { bad: true }]).agents.length, 2);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
test("concurrent starts share one listener and idle live owner remains attached", async (t) => {
  const f = await fixture(t);
  const [a, b] = await Promise.all([
    command("on", f.cwd, f.env),
    command("on", f.cwd, f.env),
  ]);
  assert.deepEqual(
    new Set([a.status, b.status]),
    new Set(["started", "already-running"]),
  );
  assert.equal(a.url, b.url);
  await delay(1300);
  assert.equal((await snapshot(a.url)).session.collection, "unavailable");
  assert.equal((await snapshot(a.url)).agents[0].status, "unknown");
  const settings = JSON.parse(
    fs.readFileSync(path.join(f.cwd, ".forge/config.json")),
  );
  assert.equal(settings.other, true);
});
test("stale metadata pointing at a live unrelated PID is not signaled or adopted", async (t) => {
  const f = await fixture(t);
  const project = monitor.projectContext(f.cwd);
  const id = "a".repeat(32);
  const base = path.join(f.cwd, ".forge/monitor");
  const dir = path.join(base, "records", id);
  fs.mkdirSync(path.join(dir, "events"), { recursive: true });
  fs.mkdirSync(path.join(base, "active"), { recursive: true });
  const active = path.join(
    base,
    "active",
    crypto
      .createHash("sha256")
      .update(f.env.CLAUDE_CODE_SESSION_ID)
      .digest("hex") + ".json",
  );
  fs.writeFileSync(active, JSON.stringify({ id }));
  fs.writeFileSync(
    path.join(dir, "runtime.json"),
    JSON.stringify({
      id,
      project,
      sessionId: f.env.CLAUDE_CODE_SESSION_ID,
      ownerPid: process.pid,
      host: "127.0.0.1",
      port: 1,
      key: "stale-key",
      retention: "delete",
      startedAt: new Date().toISOString(),
    }),
  );
  assert.equal((await command("on", f.cwd, f.env)).code, 1);
  assert.equal((await command("off", f.cwd, f.env)).code, 1);
  assert.doesNotThrow(() => process.kill(process.pid, 0));
  assert.equal(fs.existsSync(active), true);
});
test("branch capture remains immutable after checkout and history never crosses branches", async (t) => {
  const f = await fixture(t, "keep");
  const git = (...args) => {
    const p = spawnSync("git", args, { cwd: f.cwd, encoding: "utf8" });
    assert.equal(p.status, 0, p.stderr);
  };
  git("init", "-b", "main");
  git("config", "user.name", "fixture");
  git("config", "user.email", "fixture@example.test");
  git("add", ".forge/config.json");
  git("commit", "-m", "fixture");
  git("checkout", "-b", "feature-one");
  fs.mkdirSync(path.join(f.cwd, ".forge/branch/feature-one"), {
    recursive: true,
  });
  fs.writeFileSync(
    path.join(f.cwd, ".forge/branch/feature-one/plan.md"),
    "<!-- forge-slug: branch-one -->\n# One",
  );
  const a = await command("on", f.cwd, f.env);
  git("checkout", "-b", "feature-two");
  fs.mkdirSync(path.join(f.cwd, ".forge/branch/feature-two"), {
    recursive: true,
  });
  fs.writeFileSync(
    path.join(f.cwd, ".forge/branch/feature-two/plan.md"),
    "<!-- forge-slug: branch-two -->\n# Two",
  );
  const s = await snapshot(a.url);
  assert.equal(s.project.branch, "feature-one");
  assert.equal(s.tasks.rows[0].slug, "branch-one");
  assert.equal((await command("on", f.cwd, f.env)).code, 1);
  await command("off", f.cwd, f.env);
  const b = await command("on", f.cwd, f.env);
  const h = await (
    await fetch(new URL("/api/history" + new URL(b.url).search, b.url))
  ).json();
  assert.equal(h.records.length, 0);
});
test("checkpoint preserves agent lifecycle after more than 1000 activity events; partial writes ignored", () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "forge-events-"));
  fs.mkdirSync(path.join(dir, "events"));
  try {
    const time = "2026-10-20T00:00:00.000Z";
    fs.writeFileSync(
      path.join(dir, "events/start.json"),
      JSON.stringify({
        id: "start",
        time,
        event: "SubagentStart",
        agentId: "worker",
        type: "Explore",
      }),
    );
    monitor.compactEvents(dir);
    for (let i = 0; i < 1100; i++)
      fs.writeFileSync(
        path.join(dir, "events", i + ".json"),
        JSON.stringify({
          id: String(i),
          time: "2026-10-20T00:00:01.000Z",
          event: "PostToolUse",
          agentId: "main",
          tool: "Read",
        }),
      );
    fs.writeFileSync(path.join(dir, "events/partial.tmp"), "{");
    fs.writeFileSync(path.join(dir, "events/broken.json"), "{");
    monitor.compactEvents(dir);
    const state = JSON.parse(
      fs.readFileSync(path.join(dir, "checkpoint.json")),
    );
    assert.equal(state.agents.find((x) => x.id === "worker").status, "running");
    assert.equal(state.activities.length, 100);
    assert.deepEqual(fs.readdirSync(path.join(dir, "events")), ["partial.tmp"]);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test("SessionEnd remains durable after compaction consumes its event file", () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "forge-end-race-"));
  fs.mkdirSync(path.join(dir, "events"));
  try {
    // The old timer checked this empty batch, then a hook wrote SessionEnd
    // before compactEvents read again and erased the only termination signal.
    assert.deepEqual(monitor.readEvents(dir), []);
    fs.writeFileSync(
      path.join(dir, "events/end.json"),
      JSON.stringify({
        id: "end",
        time: "2026-10-20T00:00:02.000Z",
        event: "SessionEnd",
        agentId: "main",
      }),
    );
    monitor.compactEvents(dir);
    assert.deepEqual(monitor.readEvents(dir), []);
    assert.equal(
      JSON.parse(fs.readFileSync(path.join(dir, "checkpoint.json")))
        .sessionEnded,
      true,
    );
    assert.equal(monitor.compactEvents(dir).sessionEnded, true);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test("late and post-terminal events cannot rewind or revive a checkpointed agent", () => {
  const ended = monitor.reduceEvents([
    {
      id: "stop",
      time: "2026-10-20T00:00:02.000Z",
      event: "SubagentStop",
      agentId: "worker",
    },
  ]);
  const late = monitor.reduceEvents(
    [
      {
        id: "late-start",
        time: "2026-10-20T00:00:01.000Z",
        event: "SubagentStart",
        agentId: "worker",
      },
    ],
    ended,
  );
  assert.equal(late.agents.find((a) => a.id === "worker").status, "ended");
  assert.equal(
    late.agents.find((a) => a.id === "worker").lastSeen,
    "2026-10-20T00:00:02.000Z",
  );
  const future = monitor.reduceEvents(
    [
      {
        id: "restart",
        time: "2026-10-20T00:00:03.000Z",
        event: "SubagentStart",
        agentId: "worker",
      },
    ],
    late,
  );
  assert.equal(future.agents.find((a) => a.id === "worker").status, "ended");
  const stoppedSession = monitor.reduceEvents(
    [
      {
        id: "session-end",
        time: "2026-10-20T00:00:04.000Z",
        event: "SessionEnd",
      },
    ],
    future,
  );
  const delayed = monitor.reduceEvents(
    [
      {
        id: "prompt",
        time: "2026-10-20T00:00:05.000Z",
        event: "UserPromptSubmit",
      },
    ],
    stoppedSession,
  );
  assert.equal(delayed.agents.find((a) => a.id === "main").status, "ended");
});

test("monitor query excludes symlinked and oversized state without changing CLI defaults", (t) => {
  const dir = fs.realpathSync(
    fs.mkdtempSync(path.join(os.tmpdir(), "forge-query-boundary-")),
  );
  const root = path.join(dir, ".forge");
  fs.mkdirSync(root);
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  fs.writeFileSync(path.join(root, "plan.md"), "<!-- forge-slug: safe -->");
  assert.equal(surveyForge(root, { bounded: true }).rows[0][2], "safe");
  fs.unlinkSync(path.join(root, "plan.md"));
  const outside = path.join(dir, "outside.md");
  fs.writeFileSync(outside, "<!-- forge-slug: EXTERNAL_SECRET -->\n");
  try {
    fs.symlinkSync(outside, path.join(root, "plan.md"));
  } catch (e) {
    if (process.platform === "win32" && e.code === "EPERM") {
      t.skip("Windows symlink privilege unavailable");
      return;
    }
    throw e;
  }
  assert.equal(surveyForge(root).rows[0][2], "EXTERNAL_SECRET");
  assert.deepEqual(surveyForge(root, { bounded: true }).rows, []);
  const snapshot = monitor.makeSnapshot({
    id: "a".repeat(32),
    project: { path: dir, forgeRoot: root, branch: "main" },
    sessionId: "fixture",
    retention: "delete",
    startedAt: new Date().toISOString(),
  });
  assert.deepEqual(snapshot.tasks.rows, []);
  fs.unlinkSync(path.join(root, "plan.md"));
  fs.writeFileSync(
    path.join(root, "plan.md"),
    "<!-- forge-slug: oversized -->\n" + "x".repeat(256 * 1024),
  );
  assert.equal(surveyForge(root).rows[0][2], "oversized");
  assert.deepEqual(surveyForge(root, { bounded: true }).rows, []);
  fs.mkdirSync(path.join(dir, "outside-backlog"));
  fs.writeFileSync(
    path.join(dir, "outside-backlog", "leaked.md"),
    "<!-- forge-slug: LEAKED -->",
  );
  fs.symlinkSync(
    path.join(dir, "outside-backlog"),
    path.join(root, "backlog"),
    "junction",
  );
  assert.deepEqual(surveyForge(root, { bounded: true }).rows, []);
});
