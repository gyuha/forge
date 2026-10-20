#!/usr/bin/env node
"use strict";
// Silent, bounded hook input. A malformed observation cannot block Claude.
let input = "";
process.stdin.setEncoding("utf8");
process.stdin.on("data", (chunk) => {
  if (input.length + chunk.length > 1024 * 1024) {
    input = "";
    process.stdin.destroy();
    return;
  }
  input += chunk;
});
process.stdin.on("end", () => {
  try {
    require("./forge-monitor.js").collect(JSON.parse(input));
  } catch {}
});
process.stdin.on("error", () => {});
