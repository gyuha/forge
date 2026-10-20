#!/usr/bin/env node
// Persistent follow-up ledger. Bash twin has no Node dependency.
'use strict';
const fs = require('fs'), path = require('path'), crypto = require('crypto');
const { resolveForgeRoot } = require('./resolve-forge-root.js');
const marker = /^<!-- followup: (fu-[0-9a-f]{12}) \| source: ([^\s|<>/\\]+) \| task: (-|[1-9][0-9]*) \| date: ([0-9]{4}-[0-9]{2}-[0-9]{2}) \| status: (open|taken|dismissed) \| taken: (-|[1-9][0-9]*) -->$/;
function parse(text) {
  const result = []; let current;
  for (const line of text.replace(/\r/g, '').split('\n')) {
    if (line.includes('<!-- followup:')) {
      const m = marker.exec(line);
      if (!m || m[2].startsWith('.') || m[2].includes('..') || (m[5] === 'taken') !== (m[6] !== '-')) throw Error('malformed followup marker');
      current = { id:m[1], source:m[2], task:m[3], date:m[4], status:m[5], taken:m[6], body:'' }; result.push(current);
    } else if (current) current.body += line + '\n';
  }
  for (const e of result) { e.body = e.body.trim(); if (!e.body) throw Error('empty followup body'); }
  return result;
}
function render(entries) { return '# Follow-ups\n\n' + entries.map(e => `<!-- followup: ${e.id} | source: ${e.source} | task: ${e.task} | date: ${e.date} | status: ${e.status} | taken: ${e.taken} -->\n${e.body}\n`).join('\n'); }
function main(argv) {
  const command = argv.shift(), opts = {}, files = []; let addedId = ''; 
  while (argv.length) { const k = argv.shift(); if (!['--root','--id','--source','--task','--date','--text','--file'].includes(k) || !argv.length) throw Error('invalid arguments'); const v=argv.shift(); if(k==='--file') files.push(v); else opts[k.slice(2)]=v; }
  if (!['add','collect','take','dismiss','list'].includes(command)) throw Error('expected add, collect, take, dismiss or list');
  const root = opts.root || resolveForgeRoot().root || '.forge', ledger = path.join(root,'followups.md');
  let ledgerStat; try { ledgerStat = fs.lstatSync(ledger); } catch (e) { if (e.code !== 'ENOENT') throw e; }
  if (ledgerStat && !ledgerStat.isFile()) throw Error('ledger is not a regular file');
  const original = fs.existsSync(ledger) ? fs.readFileSync(ledger,'utf8') : '';
  if(command==='list') { parse(original); process.stdout.write(original); return; }
  const entries = [], byId = new Map();
  function merge(e) { const old=byId.get(e.id); if(old) { if(old.source!==e.source || old.task!==e.task || old.date!==e.date) throw Error('followup identity conflict'); return; } entries.push(e); byId.set(e.id,e); }
  parse(original).forEach(merge);
  if(command==='add') { if ((opts.text || '').includes('<!-- followup:')) throw Error('text must not contain a followup marker'); const e={id:opts.id || `fu-${crypto.randomBytes(6).toString('hex')}`,source:opts.source,task:opts.task || '-',date:opts.date || (() => { const d=new Date(); return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`; })(),status:'open',taken:'-',body:opts.text || ''}; parse(render([e])).forEach(merge); addedId = e.id; }
  if(command==='collect') { if(!files.length) throw Error('collect requires --file'); files.forEach(f=>parse(fs.readFileSync(f,'utf8')).forEach(merge)); }
  if(command==='take' || command==='dismiss') { const e=byId.get(opts.id); if(!e) throw Error('unknown followup id'); if(command==='take' && !/^[1-9][0-9]*$/.test(opts.task || '')) throw Error('take requires positive task'); const status=command==='take'?'taken':'dismissed'; if(e.status!=='open' && (e.status!==status || (status==='taken' && e.taken!==opts.task))) throw Error('terminal followup state'); e.status=status; e.taken=status==='taken'?opts.task:'-'; }
  if(!entries.length) return;
  const output=render(entries); if(output===original) { if (addedId) process.stdout.write(addedId+'\n'); return; }
  fs.mkdirSync(root,{recursive:true}); const temp=fs.mkdtempSync(path.join(root,'.followups.'));
  try { fs.writeFileSync(path.join(temp,'ledger'),output); fs.renameSync(path.join(temp,'ledger'),ledger); } finally { fs.rmSync(temp,{recursive:true,force:true}); }
  if (addedId) process.stdout.write(addedId+'\n');
}
if(require.main===module) { try { main(process.argv.slice(2)); } catch(e) { process.stderr.write(`forge-followups: ${e.message}\n`); process.exitCode=6; } }
module.exports={parse,render,main};
