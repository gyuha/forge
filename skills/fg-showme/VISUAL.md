# Visual Companion Guide

Browser-based visual companion for showing mockups, diagrams, and options during a conversation — most commonly during fg-ask grilling.

> Adapted from obra/superpowers v6.1.1 (`skills/brainstorming/visual-companion.md`; re-checked against v6.3.0 — no upstream change to port), MIT License, Copyright (c) 2025 Jesse Vincent — see [LICENSE](./LICENSE). forge modifications: session paths under `.forge/showme/`, Claude Code-only launch instructions (ADR-0025), forge lifecycle rules.

## When to Use

Decide per-screen, not per-session. The test: **would the user understand this better by seeing it than reading it?** — and it applies in **both directions**: a *question* whose answer you need from them, and an *explanation* whose structure they need from you. The test says "the user", not "the answer", so an explanation is inside it, not an extension of it.

For an explanation the boundary is a text flow diagram: if `A -> B -> C` carries it, write that in the terminal. The browser is for what a text diagram cannot hold — several branches at once, a state machine's transitions, a deep hierarchy, or a comparison across more than one axis.

**Use the browser** when the content itself is visual:

- **UI mockups** — wireframes, layouts, navigation structures, component designs
- **Architecture diagrams** — system components, data flow, relationship maps
- **Side-by-side visual comparisons** — comparing two layouts, two color schemes, two design directions
- **Design polish** — when the question is about look and feel, spacing, visual hierarchy
- **Spatial relationships** — state machines, flowcharts, entity relationships rendered as diagrams

**Use the terminal** when the content is text or tabular:

- **Requirements and scope questions** — "what does X mean?", "which features are in scope?"
- **Conceptual A/B/C choices** — picking between approaches described in words
- **Tradeoff lists** — pros/cons, comparison tables
- **Technical decisions** — API design, data modeling, architectural approach selection
- **Clarifying questions** — anything where the answer is words, not a visual preference

A question *about* a UI topic is not automatically a visual question. "What kind of wizard do you want?" is conceptual — use the terminal. "Which of these wizard layouts feels right?" is visual — use the browser.

**This test is separate from deciding whether the companion will be wanted at all.** fg-ask judges that once, up front (does this task touch a visual surface, or carry enough structure that explaining it will want a picture?), and then makes the *offer* at the moment the first genuinely visual question **or explanation** arrives. Judging early is what keeps the offer from being missed; this test is what keeps conceptual questions — and explanations a text flow diagram already carries — out of the browser. Don't collapse the two — see fg-ask's SKILL.md.

## How It Works

The server watches a directory for HTML files and serves the newest one to the browser. You write HTML content to `screen_dir`, the user sees it in their browser and can click to select options — or type into a text input you put on the screen. Those interactions are recorded to `state_dir/events`, and they count as real answers, not just hints (ADR `260730-224259`).

**What the browser does and does not do.** It is a display surface *and* a secondary answer channel. An exploratory click just sits in `state_dir/events` until you read it — nothing wakes on its own. A **confirmed** selection is different: with the wake watch armed (see Starting a Session), pressing the confirm button wakes you directly, no terminal turn required. Pillar #1 does not rest on "only the terminal can resume you" — it rests on the browser never being a runtime input to a Dynamic Workflow, and grilling never running inside one: it stays a one-question-at-a-time conversation outside any workflow, whatever wakes it.

**Content fragments vs full documents:** If your HTML file starts with `<!DOCTYPE` or `<html`, the server serves it as-is (just injects the helper script). Otherwise, the server automatically wraps your content in the frame template — adding the header, CSS theme, connection status, and all interactive infrastructure. **Write content fragments by default.** Only write full documents when you need complete control over the page.

## Starting a Session

```bash
# Start AFTER the user approves the companion. --open auto-opens their browser on
# the first screen; --project-dir persists mockups and enables same-port restart.
"${CLAUDE_PLUGIN_ROOT}/skills/fg-showme/scripts/start-server.sh" --project-dir /path/to/project --open

# Returns: {"type":"server-started","port":52341,
#           "url":"http://localhost:52341/?key=ab12…",
#           "screen_dir":"/path/to/project/.forge/showme/12345-1706000000/content",
#           "state_dir":"/path/to/project/.forge/showme/12345-1706000000/state"}
```

Save `screen_dir` and `state_dir` from the response. With `--open`, the browser opens itself when you push the first screen — you don't need to ask the user to open it, but still share the URL as a fallback (headless/remote setups won't auto-open).

**The URL contains a session key (`?key=…`).** The server rejects any request without it, so always give the user the **complete** URL from the `url` field — never strip the query string, and never hand out a bare `http://host:port`. The key gates HTTP and WebSocket access so a stray browser tab or another machine on the network can't read the screens or inject events. After the first load the browser remembers the key via a cookie, so reloads and `/files/*` assets work without repeating it.

**Finding connection info:** The server writes its startup JSON to `$STATE_DIR/server-info`. If you launched the server in the background and didn't capture stdout, read that file to get the URL and port. When using `--project-dir`, check `<project>/.forge/showme/` for the session directory.

**Note:** Pass the project root as `--project-dir` so mockups persist in `.forge/showme/` and survive server restarts. Without it, files go to `/tmp` and get cleaned up. `.forge/showme/` is volatile display state — make sure it is gitignored (forge's standard `.gitignore` policy excludes `.forge/*` by default and never whitelists `showme/`; remind the user if their project's policy differs).

**Launching (Claude Code):**

```bash
# Default mode works — the script backgrounds the server itself.
"${CLAUDE_PLUGIN_ROOT}/skills/fg-showme/scripts/start-server.sh" --project-dir /path/to/project --open
```

On Windows, the script auto-detects and switches to foreground mode (which blocks the tool call). Use `run_in_background: true` on the Bash tool call so the server survives across conversation turns, then read `$STATE_DIR/server-info` on the next turn to get the URL and port.

If the URL is unreachable from your browser (common in remote/containerized setups), bind a non-loopback host:

```bash
"${CLAUDE_PLUGIN_ROOT}/skills/fg-showme/scripts/start-server.sh" \
  --project-dir /path/to/project \
  --host 0.0.0.0 \
  --url-host localhost
```

Use `--url-host` to control what hostname is printed in the returned URL JSON.

**Arm the wake watch (mandatory):** immediately after the server starts, arm a watch on the events file so a confirmed click can wake you without a terminal turn:

```
Monitor(command: "tail -n0 -F <state_dir>/events 2>/dev/null | grep --line-buffered -E '\"choice\":\"(confirm|text):'",
        description: "fg-showme confirm/text events",
        persistent: true)
```

`Monitor` is a deferred tool — look it up before the first call if its schema isn't loaded yet.

- **`tail -n0`** — don't replay lines already in the file, only new ones.
- **`-F`** — survives the file being cleared when you push a new screen (plain `-f` would keep following the old, now-deleted inode).
- **The filter passes only `confirm:` and `text:`** — an exploratory option click (`"choice":"a"`) never matches, so browsing never wakes you; only a confirmed selection or a submitted Ask input does.
- **`--line-buffered` is required, not cosmetic.** Without it, `grep`'s own output buffering holds matches until the buffer fills — the watch looks armed but delivers nothing. This is the worst failure shape: it appears to work and silently doesn't.
- **`persistent: true`, not a `timeout_ms`.** `Monitor`'s timeout caps at 1 hour; the visual server's idle timeout is 4 hours. A timed watch would die first and leave the user clicking into a watch that is no longer there.

**If `Monitor` is unavailable** (tool missing, or arming it errors), fall back to the pre-watch behavior: skip this step, and end your turn with the old instruction — press 확정, then send anything in the terminal (see The Loop, step 2). This is a graceful degradation, the same pattern as `fg-map`/eco/tdd being absent — never a hard dependency.

## The Loop

1. **Check server is alive**, then **write HTML** to a new file in `screen_dir`:
   - **Required: confirm the server is alive before referring to the URL or pushing a screen.** Check that `$STATE_DIR/server-info` exists and `$STATE_DIR/server-stopped` does not. If it has shut down, restart it with `start-server.sh` using the **same `--project-dir`** — it reuses the same port, so the user's open tab reconnects on its own (it shows a "paused" overlay while the server is down) and you don't need to send a new URL. The server auto-exits after 4 hours idle (configurable with `--idle-timeout-minutes`).
   - Use semantic filenames: `platform.html`, `visual-style.html`, `layout.html`
   - **Never reuse filenames** — each screen gets a fresh file
   - Use your file-creation tool — **never use cat/heredoc** (dumps noise into terminal)
   - Server automatically serves the newest file

2. **Tell user what to expect and end your turn:**
   - Remind them of the URL (every step, not just first)
   - Give a brief text summary of what's on screen (e.g., "Showing 3 layout options for the homepage")
   - **With the watch armed** (the default — see Starting a Session): tell them to explore freely and press **이걸로 확정** when they've settled — that alone wakes you, no terminal message needed. e.g. "Take a look — click through the options, then press 이걸로 확정 when you've settled. No need to send anything here."
   - **Without the watch** (fallback, see Starting a Session): tell them they can answer **either way**: "Take a look — click an option (or type in the box on screen), then send anything here and I'll pick it up." A terminal turn is what wakes you, so they still have to send *something*; it does not have to be the answer itself.

3. **On your next turn** — woken by a confirmed click (the watch firing) or by the user sending a terminal turn:
   - Read `$STATE_DIR/events` if it exists — this contains the user's browser interactions (clicks, selections, text submissions) as JSON lines
   - **Merge both channels.** Neither is subordinate: for a choice question a click **is** the answer, and a submitted `text` event **is** the answer, exactly as if typed in the terminal. A terminal message like "ok" or "봤어" after a click is a wake token, not a retraction of the click.
   - **On a genuine contradiction between the two — ask one line; never pick silently.** e.g. the browser has option A plus a note, the terminal says B: "the browser has A (+ header fixed) and the terminal says B — which one?" Discarding one channel's input silently is the failure this rule exists to prevent.
   - If `$STATE_DIR/events` doesn't exist, the user answered in the terminal only — use that.

4. **Iterate or advance** — if feedback changes current screen, write a new file (e.g., `layout-v2.html`). Only move to the next question when the current step is validated.

5. **Unload when returning to terminal** — when the next step doesn't need the browser (e.g., a clarifying question, a tradeoff discussion), push a waiting screen to clear the stale content:

   ```html
   <!-- filename: waiting.html (or waiting-2.html, etc.) -->
   <div style="display:flex;align-items:center;justify-content:center;min-height:60vh">
     <p class="subtitle">Continuing in terminal...</p>
   </div>
   ```

   This prevents the user from staring at a resolved choice while the conversation has moved on. When the next visual question comes up, push a new content file as usual.

6. Repeat until done.

## Writing Content Fragments

Write just the content that goes inside the page. The server wraps it in the frame template automatically (header, theme CSS, connection status, and all interactive infrastructure).

**Minimal example:**

```html
<h2>Which layout works better?</h2>
<p class="subtitle">Consider readability and visual hierarchy</p>

<div class="options">
  <div class="option" data-choice="a" onclick="toggleSelect(this)">
    <div class="letter">A</div>
    <div class="content">
      <h3>Single Column</h3>
      <p>Clean, focused reading experience</p>
    </div>
  </div>
  <div class="option" data-choice="b" onclick="toggleSelect(this)">
    <div class="letter">B</div>
    <div class="content">
      <h3>Two Column</h3>
      <p>Sidebar navigation with main content</p>
    </div>
  </div>
</div>

<button class="mock-button" onclick="
  var sel = Array.from(document.querySelectorAll('.option.selected, .card.selected'))
                 .map(function(e){ return e.dataset.choice; });
  var key = sel.join(',') || 'none';
  if (this.dataset.sent === key) return;   // same selection re-sent (double-click) — drop
  this.dataset.sent = key;
  window.brainstorm.send({type:'confirm', choice:'confirm:'+key, value:sel});
  this.textContent='확정됨';
">이걸로 확정</button>
```

That's it. No `<html>`, no CSS, no `<script>` tags needed. The server provides all of that.

**The confirm button is required on every choice screen** — see Confirm button below for why, and what it must not carry.

## CSS Classes Available

The frame template provides these CSS classes for your content:

### Options (A/B/C choices)

```html
<div class="options">
  <div class="option" data-choice="a" onclick="toggleSelect(this)">
    <div class="letter">A</div>
    <div class="content">
      <h3>Title</h3>
      <p>Description</p>
    </div>
  </div>
</div>
```

**Multi-select:** Add `data-multiselect` to the container to let users select multiple options. Each click toggles the item's selected styling.

```html
<div class="options" data-multiselect>
  <!-- same option markup — users can select/deselect multiple -->
</div>
```

**Every options screen needs a confirm button** (single- or multi-select alike) — see Confirm button below.

### Confirm button (required on choice screens)

A choice screen without a confirm button leaves the user unable to tell whether *this* screen wakes you or not — "some screens wake, some don't" is the exact confusion this feature exists to remove. Add it to every `options`/`cards` screen:

```html
<button class="mock-button" onclick="
  var sel = Array.from(document.querySelectorAll('.option.selected, .card.selected'))
                 .map(function(e){ return e.dataset.choice; });
  var key = sel.join(',') || 'none';
  if (this.dataset.sent === key) return;   // same selection re-sent (double-click) — drop
  this.dataset.sent = key;
  window.brainstorm.send({type:'confirm', choice:'confirm:'+key, value:sel});
  this.textContent='확정됨';
">이걸로 확정</button>
```

- **No `data-choice` on this button.** `helper.js`'s global click listener auto-sends any `[data-choice]` element (`{type:'click', text:<label>, choice:<data-choice>, id:<id|null>}`); adding `data-choice` here would double-send alongside the inline handler.
- **`choice` is REQUIRED** — same server guard as Ask input below (`if (event && event.choice)`): omit it and the confirm event is silently dropped.
- **Read `.selected`, not `window.selectedChoice`.** `toggleSelect` only ever sets `window.selectedChoice` to the *last* clicked element, which is wrong once a screen allows multiple selections; querying `.option.selected, .card.selected` is correct for both single- and multi-select.
- **`confirm:none` is a valid signal** — pressed with nothing selected, it tells you exactly that, so you can ask instead of guessing.
- **Keep the label "이걸로 확정."** The user must understand that clicking it ends the screen — that is what stops you from advancing while they were still thinking. A workaround must pin down what it is working around, or the next reader "cleans it up"; do not rename or restyle this away.
- **The `dataset.sent` guard drops a re-send of the *same* selection, and only that.** Measured on the first real run: a double-click produced two identical `confirm:gamma` events 798 ms apart — one decision, two wakes. The guard suppresses that while deliberately leaving a **re-confirm of a different selection** working, because that is a real user move (the same run went `confirm:gamma` → explore → `confirm:beta` 10 s later). Do not "improve" this into a disabled button: that would block the legitimate change of mind.
- **On wake, the last confirm wins — and repeats are idempotent.** Read the whole `state_dir/events` file, not just the event you were woken with: take the **last** `confirm` line as the answer (that is what makes a re-confirm authoritative), and if it names what you already acted on, do not answer twice. Two notifications for one decision are still possible (a fast double-click can outrun the guard, and the file is append-only), so idempotence lives on your side too, not only in the button.

### Cards (visual designs)

```html
<div class="cards">
  <div class="card" data-choice="design1" onclick="toggleSelect(this)">
    <div class="card-image"><!-- mockup content --></div>
    <div class="card-body">
      <h3>Name</h3>
      <p>Description</p>
    </div>
  </div>
</div>
```

**Wrap a mockup in a single root element.** `.card-image` is a centering flex container that stretches its *only* child to full width; several siblings dropped straight in would each shrink to their own intrinsic width (near zero for a mockup built from absolutely-positioned parts). The slot grows to fit the mockup's height, so it is never clipped at narrow card widths.

### Mockup container

```html
<div class="mockup">
  <div class="mockup-header">Preview: Dashboard Layout</div>
  <div class="mockup-body"><!-- your mockup HTML --></div>
</div>
```

### Split view (side-by-side)

```html
<div class="split">
  <div class="mockup"><!-- left --></div>
  <div class="mockup"><!-- right --></div>
</div>
```

### Pros/Cons

```html
<div class="pros-cons">
  <div class="pros"><h4>Pros</h4><ul><li>Benefit</li></ul></div>
  <div class="cons"><h4>Cons</h4><ul><li>Drawback</li></ul></div>
</div>
```

### Mock elements (wireframe building blocks)

```html
<div class="mock-nav">Logo | Home | About | Contact</div>
<div style="display: flex;">
  <div class="mock-sidebar">Navigation</div>
  <div class="mock-content">Main content area</div>
</div>
<button class="mock-button">Action Button</button>
<input class="mock-input" placeholder="Input field">
<div class="placeholder">Placeholder area</div>
```

**`mock-*` elements are wireframe props, not live controls.** `mock-input` *draws* an input inside a mockup — it sends nothing. Do not use it to collect an answer; use the ask-input below, which is deliberately named differently so the two never blur together.

### Ask input (a live text answer, next to what it is about)

For a question whose answer is words but whose *subject* is on screen — annotating a specific mockup, naming what is wrong with a layout — put a real input on the page. It submits a `text` event you read like any other.

```html
<h3>Anything to note about this layout?</h3>
<div class="ask-input">
  <textarea id="note" rows="3" placeholder="e.g. header should stay fixed"></textarea>
  <button class="mock-button" onclick="
    window.brainstorm.send({type:'text', choice:'text:layout-note',
                            field:'layout-note', value:document.getElementById('note').value});
    this.textContent='Sent';
  ">Send</button>
</div>
```

- **`choice` is REQUIRED and is not decoration — omit it and the event is silently dropped.** `server.cjs`'s `handleMessage` appends to `state_dir/events` only under `if (event && event.choice)`; an event without it is logged to the server's stdout and never reaches the file you read. Verified by probe: the same `text` event landed in `events` with `choice` present and vanished without it. Use the `text:<field>` form so it is visibly not an option letter. **Do not "clean this up"** — it is what lets the input work with **no vendored file changed**, keeping re-vendoring upstream conflict-free (ADR `260719-224442`). If upstream ever relaxes that guard, this key can go.
- `ask-input` is a **semantic wrapper the frame template does not style** — add inline styling if you want any; the name exists to keep it distinct from `mock-input`.
- **Submit on an explicit button**, never on every keystroke or on blur — otherwise you collect half-typed fragments.
- Give each input a **distinct `field`** so several inputs on one screen stay distinguishable.
- The plain terminal is still the better channel for long prose (history, editing, paste). Reach for this when being *next to the visual* is the point.

### Typography and sections

- `h2` — page title
- `h3` — section heading
- `.subtitle` — secondary text below title
- `.section` — content block with bottom margin
- `.label` — small uppercase label text

## Browser Events Format

When the user interacts with the browser, their actions are recorded to `$STATE_DIR/events` (one JSON object per line). The file is cleared automatically when you push a new screen.

```jsonl
{"type":"click","choice":"a","text":"Option A - Simple Layout","timestamp":1706000101}
{"type":"click","choice":"c","text":"Option C - Complex Grid","timestamp":1706000108}
{"type":"click","choice":"b","text":"Option B - Hybrid","timestamp":1706000115}
{"type":"text","choice":"text:layout-note","field":"layout-note","value":"header should stay fixed","timestamp":1706000131}
```

Note the `choice` on the `text` line: the server only persists events that carry it (see Ask input above). Branch on `type`, not on the presence of `choice` — a `text` event's `choice` is a routing key, not a chosen option.

The full event stream shows the user's exploration path — they may click multiple options before settling. The last `choice` event is typically the final selection, but the pattern of clicks can reveal hesitation or preferences worth asking about.

**These are answers.** For a choice question the settled `click` is the answer; a `text` event is the answer in the user's own words. Treat them as you would the same content typed in the terminal, merge with the terminal turn, and only ask when the two genuinely contradict (see The Loop, step 3).

If `$STATE_DIR/events` doesn't exist, the user didn't interact with the browser — use only their terminal text.

## Design Tips

- **Scale fidelity to the question** — wireframes for layout, polish for polish questions
- **Explain the question on each page** — "Which layout feels more professional?" not just "Pick one"
- **Iterate before advancing** — if feedback changes current screen, write a new version
- **2-4 options max** per screen
- **Use real content when it matters** — for a photography portfolio, use actual images (Unsplash). Placeholder content obscures design issues.
- **Keep mockups simple** — focus on layout and structure, not pixel-perfect design

## File Naming

- Use semantic names: `platform.html`, `visual-style.html`, `layout.html`
- Never reuse filenames — each screen must be a new file
- For iterations: append version suffix like `layout-v2.html`, `layout-v3.html`
- Server serves newest file by modification time

## Lifecycle (forge rules)

- **Within fg-ask**: the companion's job ends where the plan begins — stop the server at Output time (when the plan lands in the backlog and the handoff is delivered). See fg-ask's Forge integration section.
- **Standalone (fg-showme)**: stop when the visual discussion is done, or when the user says `fg-showme stop`.
- **Abandoned sessions**: the 4-hour idle timeout is the backstop — a forgotten server shuts itself down.
- Mockup files persist in `.forge/showme/` after stop for later reference (only `/tmp` sessions are deleted).
- **The wake watch is `persistent` — stop it explicitly.** It never times out on its own, so stop it with `TaskStop` at every point the server itself gets stopped: `fg-showme stop` and fg-ask's Output time (the two bullets above). A server stop without a matching `TaskStop` leaves the watch running against a dead events file.
- **A session restart kills the watch but not the server** — the server survives on the same port (see Starting a Session), but the watch was armed by a tool call in the session that just ended. Re-entry must re-arm it (see Starting a Session) before a confirmed click can wake you again.

## Cleaning Up

```bash
"${CLAUDE_PLUGIN_ROOT}/skills/fg-showme/scripts/stop-server.sh" $SESSION_DIR
```

If the session used `--project-dir`, mockup files persist in `.forge/showme/` for later reference. Only `/tmp` sessions get deleted on stop.

## Reference

- Frame template (CSS reference): `scripts/frame-template.html`
- Helper script (client-side): `scripts/helper.js`
