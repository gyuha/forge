// Vendored from obra/superpowers v6.1.1 (skills/brainstorming/scripts/helper.js).
// MIT License, Copyright (c) 2025 Jesse Vincent — see LICENSE in the parent directory.
// forge modifications: user-visible "brainstorm" wording localized to "visual companion";
//   click events now carry a short title label instead of the element's whole subtree,
//   and a click shows a hint that clicks alone don't reach the agent.
(function() {
  const MIN_RECONNECT_MS = 500;
  const MAX_RECONNECT_MS = 30000;
  const TOMBSTONE_AFTER_MS = 15000; // show the "paused" overlay after this long disconnected

  // Pure: next backoff delay (doubles, capped). Exported for unit tests.
  function nextReconnectDelay(current, max) {
    return Math.min(current * 2, max);
  }
  if (typeof module !== 'undefined' && module.exports) {
    module.exports = { nextReconnectDelay, MIN_RECONNECT_MS, MAX_RECONNECT_MS, TOMBSTONE_AFTER_MS };
  }

  // Everything below is browser-only; bail out when loaded in Node (tests).
  if (typeof window === 'undefined') return;

  let ws = null;
  let eventQueue = [];
  let reconnectDelay = MIN_RECONNECT_MS;
  let reconnectTimer = null;
  let disconnectedSince = null;
  let everConnected = false;
  let tombstoneShown = false;

  function sessionKey() {
    try {
      return window.sessionStorage && window.sessionStorage.getItem('brainstorm-session-key');
    } catch (e) {}
    return null;
  }

  function websocketUrl() {
    const key = sessionKey();
    return 'ws://' + window.location.host + (key ? '/?key=' + encodeURIComponent(key) : '');
  }

  function reloadAfterRecovery() {
    const key = sessionKey();
    if (key) {
      window.location.replace('/?key=' + encodeURIComponent(key));
    } else {
      window.location.reload();
    }
  }

  // Reflect connection state in the frame's status pill (absent on full-doc screens).
  function setStatus(state) {
    const el = document.querySelector('.status');
    if (!el) return;
    const map = {
      connecting:   ['Connecting…',   'var(--text-tertiary)'],
      connected:    ['Connected',     'var(--success)'],
      reconnecting: ['Reconnecting…', 'var(--warning)'],
      disconnected: ['Disconnected',  'var(--error)']
    };
    const [text, color] = map[state] || map.disconnected;
    el.textContent = text;
    el.style.setProperty('--status-color', color);
  }

  // Self-styled so it works on framed and full-document screens alike.
  function showTombstone() {
    if (tombstoneShown) return;
    tombstoneShown = true;
    const el = document.createElement('div');
    el.id = 'bs-tombstone';
    el.style.cssText = 'position:fixed;inset:0;z-index:99999;display:flex;' +
      'align-items:center;justify-content:center;padding:2rem;text-align:center;' +
      'background:rgba(20,20,22,0.92);color:#f5f5f7;font-family:system-ui,sans-serif';
    el.innerHTML = '<div style="max-width:480px">' +
      '<h2 style="margin:0 0 .5rem;font-weight:600">Companion paused</h2>' +
      '<p style="margin:0;opacity:.85">This visual companion has stopped. ' +
      'Ask your coding agent to bring it back — this page reconnects automatically.</p></div>';
    if (document.body) document.body.appendChild(el);
  }

  // A short, human-readable label for a choice element. Prefer its card/option title:
  // a card's mockup lives in .card-image *before* .card-body, so a bare textContent
  // (or a plain h3 lookup) would swallow the whole mockup instead of the title.
  function choiceLabel(el) {
    const titled = el.querySelector('.card-body h3, .content h3') || el.querySelector('h3');
    const raw = (titled ? titled.textContent : el.textContent) || '';
    return raw.trim().replace(/\s+/g, ' ').slice(0, 120);
  }

  // Clicks are recorded to the session's event log, but they cannot wake the agent —
  // it reads them on its next turn, after the user says something in the terminal.
  // Nothing on screen said so, so say it here. Self-styled like the tombstone above so
  // it works on framed and full-document screens alike, and it stays put: this is a
  // state, not a transient notice. Pushing the next screen reloads the page, clearing it.
  function showClickHint(label, deselected) {
    let el = document.getElementById('bs-click-hint');
    if (!el) {
      el = document.createElement('div');
      el.id = 'bs-click-hint';
      el.style.cssText = 'position:fixed;right:1rem;bottom:1rem;z-index:99998;max-width:22rem;' +
        'padding:0.7rem 0.9rem;border-radius:10px;background:rgba(20,20,22,0.92);color:#f5f5f7;' +
        'font-family:system-ui,-apple-system,sans-serif;font-size:0.8rem;line-height:1.45;' +
        'box-shadow:0 6px 24px rgba(0,0,0,0.3)';
      el.innerHTML = '<div style="font-weight:600;margin-bottom:0.15rem"></div>' +
        '<div style="opacity:0.85">Tell your agent in the terminal — clicks alone don\'t reach it.</div>';
      if (document.body) document.body.appendChild(el);
    }
    // textContent, not innerHTML — the label comes from screen content.
    el.firstChild.textContent = (deselected ? 'Deselected: ' : 'Selected: ') + label;
  }

  function connect() {
    if (reconnectTimer) { clearTimeout(reconnectTimer); reconnectTimer = null; }
    setStatus(everConnected ? 'reconnecting' : 'connecting');
    ws = new WebSocket(websocketUrl());

    ws.onopen = () => {
      const recovered = tombstoneShown;
      everConnected = true;
      disconnectedSince = null;
      reconnectDelay = MIN_RECONNECT_MS;
      tombstoneShown = false;
      setStatus('connected');
      eventQueue.forEach(e => ws.send(JSON.stringify(e)));
      eventQueue = [];
      // Recovered from a tombstoned outage (e.g. the server restarted on the same
      // port) — reload through the keyed bootstrap when possible so the cookie is
      // refreshed before the visible URL returns to bare /.
      if (recovered) reloadAfterRecovery();
    };

    ws.onmessage = (msg) => {
      let data;
      try { data = JSON.parse(msg.data); } catch (e) { return; }
      if (data.type === 'reload') window.location.reload();
    };

    ws.onclose = () => {
      ws = null;
      if (disconnectedSince === null) disconnectedSince = Date.now();
      if (Date.now() - disconnectedSince >= TOMBSTONE_AFTER_MS) {
        setStatus('disconnected');
        showTombstone();
      } else {
        setStatus('reconnecting');
      }
      reconnectTimer = setTimeout(connect, reconnectDelay);
      reconnectDelay = nextReconnectDelay(reconnectDelay, MAX_RECONNECT_MS);
    };

    // Let onclose own reconnection so we don't schedule it twice.
    ws.onerror = () => { try { ws.close(); } catch (e) {} };
  }

  function sendEvent(event) {
    event.timestamp = Date.now();
    if (ws && ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify(event));
    } else {
      eventQueue.push(event);
    }
  }

  // Capture clicks on choice elements
  document.addEventListener('click', (e) => {
    const target = e.target.closest('[data-choice]');
    if (!target) return;

    const label = choiceLabel(target);
    sendEvent({
      type: 'click',
      text: label,
      choice: target.dataset.choice,
      id: target.id || null
    });

    // toggleSelect() is an inline onclick, so it has already run by the time this
    // bubbling listener fires — classList reflects the post-click state. Only a
    // multi-select container can leave an element unselected after a click.
    const multi = target.closest('[data-multiselect]');
    showClickHint(label, !!multi && !target.classList.contains('selected'));
  });

  // Frame UI: selection tracking
  window.selectedChoice = null;

  window.toggleSelect = function(el) {
    const container = el.closest('.options') || el.closest('.cards');
    const multi = container && container.dataset.multiselect !== undefined;
    if (container && !multi) {
      container.querySelectorAll('.option, .card').forEach(o => o.classList.remove('selected'));
    }
    if (multi) {
      el.classList.toggle('selected');
    } else {
      el.classList.add('selected');
    }
    window.selectedChoice = el.dataset.choice;
  };

  // Expose API for explicit use
  window.brainstorm = {
    send: sendEvent,
    choice: (value, metadata = {}) => sendEvent({ type: 'choice', value, ...metadata })
  };

  connect();
})();
