#!/usr/bin/env node
'use strict';
const fs=require('fs'),os=require('os'),path=require('path'),cp=require('child_process'),assert=require('assert');
const here=__dirname, tmp=fs.mkdtempSync(path.join(os.tmpdir(),'forge-followups-test-'));
const id='fu-123456abcdef', marker=`<!-- followup: ${id} | source: sample | task: 1 | date: 2026-10-20 | status: open | taken: - -->`;
const snapshots=[];
try {
 for(const runtime of ['sh','js']) {
  const cwd=path.join(tmp,runtime);fs.mkdirSync(cwd);
  const run=(name,args=[],code=0)=>{const r=cp.spawnSync(runtime==='sh'?'bash':'node',[path.join(here,`${name}.${runtime}`),...args],{cwd,encoding:'utf8'});assert.equal(r.status,code,`${runtime} ${name}: ${r.stdout} ${r.stderr}`);return r;};
  const ledger=path.join(cwd,'.forge/followups.md');
  run('forge-followups',['list']);assert(!fs.existsSync(ledger));
  const add=['add','--id',id,'--source','sample','--task','1','--date','2026-10-20','--text','Candidate 한글\n\nDetails \\ and "quoted"'];
  run('forge-followups',[...add.slice(0,-1),marker+'\nInjected'],6);assert(!fs.existsSync(ledger));
  run('forge-followups',add);run('forge-followups',['take','--id',id,'--task','2']);
  run('forge-followups',add);assert(fs.readFileSync(ledger,'utf8').includes('status: taken | taken: 2'));
  run('forge-followups',['take','--id',id,'--task','2']);
  run('forge-followups',['take','--id',id,'--task','3'],6);
  run('forge-followups',['dismiss','--id',id],6);
  let before=fs.readFileSync(ledger,'utf8');
  const incoming=path.join(cwd,'incoming.md');fs.writeFileSync(incoming,marker+'\nCandidate\n<!-- followup: broken -->\nbad\n');
  run('forge-followups',['collect','--file',incoming],6);assert.equal(fs.readFileSync(ledger,'utf8'),before);
  fs.writeFileSync(path.join(cwd,'.forge/plan.md'),'<!-- forge-slug: sample -->\n');
  fs.writeFileSync(path.join(cwd,'.forge/STATUS.md'),'status: executed\nverified: pending\nretro: skipped\n');
  fs.writeFileSync(path.join(cwd,'.forge/run.md'),marker+'\nCandidate\n');
  run('forge-done',[],3);assert.equal(fs.readFileSync(ledger,'utf8'),before);
  fs.writeFileSync(path.join(cwd,'.forge/STATUS.md'),'status: executed\nverified: yes\nretro: skipped\n');
  fs.writeFileSync(path.join(cwd,'.forge/run.md'),'<!-- followup: bad -->\nCandidate\n');
  run('forge-done',[],6);assert(fs.existsSync(path.join(cwd,'.forge/plan.md')));assert(!fs.existsSync(path.join(cwd,'.forge/done')));
  fs.writeFileSync(path.join(cwd,'.forge/run.md'),marker+'\nCandidate\n');
  fs.mkdirSync(path.join(cwd,'.forge/retro'));
  const marker2=marker.replace(id,'fu-abcdef123456');
  fs.writeFileSync(path.join(cwd,'.forge/retro/261020-100000-sample.md'),marker2+'\nRetro candidate\n');
  fs.writeFileSync(path.join(cwd,'.forge/retro/261020-100000-other-sample.md'),'<!-- followup: bad -->\nUnrelated\n');
  run('forge-done',['--skip-retro','automatic','--sealed-id','261020-120000']);
  before=fs.readFileSync(ledger,'utf8'); assert(before.includes('Retro candidate')); assert(before.includes('status: taken | taken: 2'));
  run('forge-done',['--slug','sample'],5);assert.equal(fs.readFileSync(ledger,'utf8'),before);
  run('forge-followups',['dismiss','--id','fu-abcdef123456']);run('forge-followups',['collect','--file',path.join(cwd,'.forge/retro/261020-100000-sample.md')]);
  assert(fs.readFileSync(ledger,'utf8').includes('status: dismissed | taken: -'));
  run('forge-followups',['take','--id','fu-abcdef123456','--task','9'],6);
  run('forge-followups',['dismiss','--id','fu-abcdef123456']);
  run('forge-followups',['add','--id','fu-000000000002','--source','후속.후보-수집','--task','-','--date','2026-10-20','--text','한글 slug 후보']);
  for (const invalid of ['../escape','.hidden','a..b','a/b','a\\b','two words','a|b','a>b']) run('forge-followups',['add','--source',invalid,'--text','invalid'],6);
  snapshots.push(fs.readFileSync(ledger,'utf8'));
  // A failed archive leaves collected candidates durable; retry is idempotent.
  fs.writeFileSync(path.join(cwd,'.forge/plan.md'),'<!-- forge-slug: retry -->\n');
  fs.writeFileSync(path.join(cwd,'.forge/STATUS.md'),'status: executed\nverified: yes\nretro: skipped\n');
  fs.writeFileSync(path.join(cwd,'.forge/run.md'),marker.replace(id,'fu-000000000001').replace('source: sample','source: retry')+'\nRetry candidate\n');
  fs.renameSync(path.join(cwd,'.forge/done'),path.join(cwd,'.forge/old-done'));
  fs.writeFileSync(path.join(cwd,'.forge/done'),'blocked archive');
  run('forge-done',[],6);assert(fs.existsSync(path.join(cwd,'.forge/run.md')));
  before=fs.readFileSync(ledger,'utf8');fs.unlinkSync(path.join(cwd,'.forge/done'));
  run('forge-done',[]);assert.equal(fs.readFileSync(ledger,'utf8'),before);
  // Branch resolution isolates the ledger and works from a repository subdirectory.
  const git=(args)=>cp.execFileSync('git',args,{cwd,stdio:'pipe'});
  git(['init','-b','main']);git(['-c','user.name=Test','-c','user.email=test@example.com','commit','--allow-empty','-m','test']);git(['checkout','-b','topic']);
  fs.mkdirSync(path.join(cwd,'sub'));
  const branch=cp.spawnSync(runtime==='sh'?'bash':'node',[path.join(here,`forge-followups.${runtime}`),...add],{cwd:path.join(cwd,'sub'),encoding:'utf8'});
  assert.equal(branch.status,0,branch.stderr);assert(fs.existsSync(path.join(cwd,'.forge/branch/topic/followups.md')));
  assert.equal(fs.readFileSync(ledger,'utf8'),before);
  const generated=run('forge-followups',['add','--root','generated','--source','sample','--text','Generated candidate']).stdout.trim();assert(/^fu-[0-9a-f]{12}$/.test(generated));

 }
 assert.equal(snapshots[0],snapshots[1]);console.log('PASS followups: twins, lazy storage, state transitions, atomic validation, gate-first collection, exact retro, duplicate seal');
} finally {fs.rmSync(tmp,{recursive:true,force:true});}
