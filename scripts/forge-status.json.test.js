#!/usr/bin/env node
'use strict';
const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const {spawnSync} = require('child_process');
const here = __dirname, temp = fs.mkdtempSync(path.join(os.tmpdir(), 'forge-status-한글-"-\\-'));
let checks = 0;
function run(cwd, runtime, args = ['--json']) {
  return spawnSync(runtime, [path.join(here, `forge-status.${runtime === 'bash' ? 'sh' : 'js'}`), ...args], {cwd, encoding:'utf8'});
}
function survey(cwd) {
  const results = ['bash','node'].map(runtime => {const r=run(cwd,runtime); assert.strictEqual(r.status,0,r.stderr); return JSON.parse(r.stdout);});
  assert.deepStrictEqual(results[0],results[1]); checks++; return results[0];
}
function write(relative,text) { const p=path.join(temp,relative); fs.mkdirSync(path.dirname(p),{recursive:true});fs.writeFileSync(p,text); }
try {
  const empty=survey(temp); assert.strictEqual(empty.exists,false); assert.deepStrictEqual(empty.tasks,[]);assert.strictEqual(empty.loop,null);
  write('.forge/plan.md','<!-- forge-slug: active --> <!-- task: 009 -->\r\n#   제목 "quoted" \\ path\r\n');
  write('.forge/STATUS.md','- status: executed\r\n- verified: failed ("a\\b"\t한글\u0001)\r\n- retro: skipped (reason with spaces)\r\n');
  write('.forge/running.md','workflow: pending\r\nreason: "quote" \\ tab\t\u0002\r\n');
  write('.forge/backlog/next.md','<!-- forge-slug: next --> <!-- task: 10 -->\n# Next\n');
  write('.forge/executed/parked/plan.md','<!-- forge-slug: parked --> <!-- task: 8 -->\n# Parked\n');
  write('.forge/executed/parked/STATUS.md','verified: pending (legacy)\nretro: pending\n');
  for(let n=1;n<=7;n++) {write(`.forge/done/261020-12000${n}-old-${n}/plan.md`,`<!-- forge-slug: old-${n} --> <!-- task: ${n} -->\n# Old ${n}\n`);write(`.forge/done/261020-12000${n}-old-${n}/STATUS.md`,'verified: yes (all green)\nretro: skipped (auto)\n');}
  write('.forge/loop.md','# LOOP — 목표 "hello" \\ world\rinside\r\nreplan-round: 1\r\nreplan-cap: 3\r\nbudget-tokens: none\r\nbudget-spent: 12 · since: today\r\nretro: skip\r\nwall: no-progress (C1)\r\n\r\n## Check progress\r\n- C1: fail ×2 · last-evidence: "failed"\r\n');
  write('.forge/quick/LOG.md','## one\ntext\n## two\n');write('.forge/retro/261020-120000-old-1.md','# Retro\n');write('.forge/adr/one.md','# ADR\n');
  const marker=(id,status,taken)=>`<!-- followup: fu-${id} | source: old-1 | task: 1 | date: 2026-10-20 | status: ${status} | taken: ${taken} -->`;
  write('.forge/followups.md',`# Follow-ups\r\n\r\n${marker('000000000001','open','-')}\r\n후속 "quote" \\ tab\t\u0003\r\nsecond line\r\n\r\n${marker('000000000002','taken','10')}\r\nTaken\r\n\r\n${marker('000000000003','dismissed','-')}\r\nDismissed\r\n`);
  const populated=survey(temp);assert.strictEqual(populated.tasks[0].task,9);assert.strictEqual(populated.tasks[0].title,'제목 \"quoted\" \\ path');assert(populated.loop.content.includes('world\rinside'));assert.strictEqual(populated.tasks.length,10);assert.strictEqual(populated.counts.done,7);assert.strictEqual(populated.tasks[0].verified,'failed ("a\\b"\t한글\u0001)');assert.strictEqual(populated.tasks[0].retro,'skipped (reason with spaces)');assert.strictEqual(populated.loop.wall,'no-progress (C1)');assert(populated.loop.content.includes('fail ×2'));assert.strictEqual(populated.running.content.includes('\u0002'),true);assert.deepStrictEqual(populated.counts.followups,{open:1,taken:1,dismissed:1});assert.strictEqual(populated.followups[1].taken,10);assert.strictEqual(populated.followups[0].taken,null);
  write('.forge/run.md','result');assert.strictEqual(survey(temp).tasks[0].hasRun,true);
  for(const mode of [[],['--table']]) {const a=run(temp,'bash',mode),b=run(temp,'node',mode);assert.strictEqual(a.status,0,a.stderr);assert.strictEqual(b.status,0,b.stderr);assert.strictEqual(a.stdout,b.stdout);checks++;}
  write('.forge/followups.md','<!-- followup: broken -->\nbody\n');
  for(const runtime of ['bash','node']) {const r=run(temp,runtime);assert.notStrictEqual(r.status,0);assert.strictEqual(r.stdout,'');assert(r.stderr);checks++;}
  for(const kind of ['directory','symlink']) {
    fs.rmSync(path.join(temp,'.forge/followups.md'));
    if(kind==='directory') fs.mkdirSync(path.join(temp,'.forge/followups.md'));
    else fs.symlinkSync(path.join(temp,'.forge/plan.md'),path.join(temp,'.forge/followups.md'));
    for(const runtime of ['bash','node']) {const r=run(temp,runtime);assert.notStrictEqual(r.status,0);assert.strictEqual(r.stdout,'');assert(r.stderr);checks++;}
    fs.rmSync(path.join(temp,'.forge/followups.md'),{recursive:true});
    write('.forge/followups.md','# Follow-ups\n');
  }
  // Branch resolution, including invocation below repository root.
  const git = (...args) => {const r=spawnSync('git',args,{cwd:temp,encoding:'utf8'});assert.strictEqual(r.status,0,r.stderr);};
  git('init','-q','-b','main');git('-c','user.name=Test','-c','user.email=test@example.com','commit','--allow-empty','-qm','init');git('checkout','-qb','feature/json');
  write('.forge/branch/feature/json/backlog/branch.md','<!-- forge-slug: branch --> <!-- task: 12 -->\n# Branch\n');
  fs.mkdirSync(path.join(temp,'nested'));const branch=survey(path.join(temp,'nested'));assert.strictEqual(branch.tasks.length,1);assert.strictEqual(branch.tasks[0].slug,'branch');assert(branch.root.endsWith('/.forge/branch/feature/json'));
  console.log(`forge-status JSON: ${checks} parity/behavior checks passed`);
} finally {fs.rmSync(temp,{recursive:true,force:true});}
