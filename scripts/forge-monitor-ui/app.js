'use strict';

(function () {
  const agentLabels = {running: '실행 중', waiting: '대기 중', ended: '응답 종료', unknown: '확인 불가', failed: '실패'};
  const stageLabels = {ask: '계획', run: '실행', verify: '검증', learn: '회고', done: '완료'};
  const eventLabels = {
    SessionStart: '세션 시작', UserPromptSubmit: '요청 접수', PreToolUse: '도구 실행',
    PostToolUse: '도구 실행 종료', PostToolUseFailure: '도구 실행 오류',
    PermissionRequest: '승인 대기', Stop: '응답 종료 · 입력 대기',
    SubagentStart: '서브에이전트 시작', SubagentStop: '서브에이전트 응답 종료', SessionEnd: '세션 종료'
  };

  function apiURL(path, search) {
    return `${path}?${new URLSearchParams({key: new URLSearchParams(search).get('key') || ''})}`;
  }

  function agentState(status, connected, archived) {
    const label = agentLabels[status] || '확인 불가';
    if (archived) return `종료된 세션 · 마지막 상태: ${label}`;
    if (!connected) return `연결 끊김 · 마지막 상태: ${label}`;
    return label;
  }

  function field(document, name) {
    const token = (String(document || '').match(new RegExp(`^[\\t ]*-?[\\t ]*${name}:[\\t ]*(\\S+)`, 'm')) || [])[1] || '';
    return (token.toLowerCase().match(/^[a-z/]*/) || [''])[0];
  }

  function phase(active) {
    if (!active) return null;
    if (field(active.status, 'status') === 'done') return 'done';
    if (!active.run) return 'run';
    if (['yes', 'skipped', 'n/a'].includes(field(active.status, 'verified'))) return 'learn';
    return 'verify';
  }

  function progressText(progress) {
    if (!progress || !Number.isInteger(progress.completed) || !Number.isInteger(progress.total) ||
        progress.total <= 0 || progress.completed < 0 || progress.completed > progress.total) return '진행률 확인 불가';
    return `완료 ${progress.completed} / ${progress.total}개 항목`;
  }

  // Generation checks prevent an in-flight live response from painting over a selected archive.
  function createController(request, render) {
    const state = {snapshot: null, record: null, connected: false, loading: true, error: null};
    let generation = 0;
    async function load() {
      const current = ++generation;
      state.loading = !state.snapshot;
      render(state);
      try {
        const snapshot = await request(state.record ? `/api/history/${encodeURIComponent(state.record)}` : '/api/snapshot');
        if (current !== generation) return;
        state.snapshot = snapshot;
        state.connected = true;
        state.error = null;
      } catch (error) {
        if (current !== generation) return;
        state.connected = false;
        state.error = error.message;
      }
      state.loading = false;
      render(state);
    }
    function select(record) {
      state.record = record;
      state.snapshot = null;
      state.connected = false;
      state.error = null;
      return load();
    }
    return {state, load, select};
  }

  if (typeof module !== 'undefined' && module.exports) {
    module.exports = {apiURL, agentState, phase, progressText, createController};
  }
  if (typeof document === 'undefined') return;

  const $ = id => document.getElementById(id);
  const set = (id, text) => { $(id).textContent = text; };
  const element = (tag, text, className) => {
    const node = document.createElement(tag);
    if (text !== undefined) node.textContent = text;
    if (className) node.className = className;
    return node;
  };
  function time(value, short = false) {
    if (!value || Number.isNaN(Date.parse(value))) return '관측 없음';
    return new Date(value).toLocaleString('ko-KR', short
      ? {hour: '2-digit', minute: '2-digit', second: '2-digit', hour12: false}
      : {month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', second: '2-digit', hour12: false});
  }
  async function request(path) {
    const response = await fetch(apiURL(path, location.search), {cache: 'no-store', signal: AbortSignal.timeout(1800)});
    if (!response.ok) throw Error(response.status === 401 || response.status === 403 ? '접속 키를 확인해 주세요.' : `조회 실패 (${response.status})`);
    return response.json();
  }
  let view = 'overview';
  let doc = 'plan';
  let historyGeneration = 0;
  const controller = createController(request, render);

  function render(state) {
    const snapshot = state.snapshot;
    const archived = Boolean(state.record || snapshot?.session?.endedAt);
    const connection = $('connection');
    connection.className = state.connected ? 'connected' : (state.loading ? '' : 'disconnected');
    connection.textContent = archived ? (state.connected ? '보관 기록' : '보관 기록 조회 중단')
      : (state.loading ? '연결 중' : state.connected ? '연결됨 · 자동 갱신' : '연결 끊김');
    $('notice').className = `notice${!state.connected && !state.loading ? ' warning' : ''}`;
    if (!state.connected) {
      set('notice', state.loading ? '세션의 작업과 에이전트 상태를 불러오고 있습니다.'
        : `${state.error || '서버에 연결할 수 없습니다.'} ${snapshot ? '마지막 관측을 표시합니다. 현재 상태는 확인할 수 없습니다.' : '모니터가 실행 중인지와 접속 URL을 확인해 주세요.'} 현재 세션은 자동으로 재연결합니다.`);
    } else if (archived) {
      set('notice', `종료된 세션의 보관 기록입니다. 종료: ${time(snapshot?.session?.endedAt)}. 현재 실시간 상태가 아닙니다.`);
    } else {
      set('notice', snapshot?.session?.collection === 'unavailable'
        ? '에이전트 이벤트가 아직 관측되지 않았습니다. 상태는 확인 불가로 표시됩니다. 훅 설치 후 시작한 Claude 세션인지 확인해 주세요.'
        : '현재 브랜치의 작업과 이 Claude 세션의 에이전트를 관찰하고 있습니다. 응답 종료는 작업 검증 성공을 뜻하지 않습니다.');
    }
    set('scope-label', archived ? '보관된 세션' : '현재 세션');
    $('current-session').hidden = !archived;
    set('updated', snapshot ? time(snapshot.updatedAt) : '—');
    if (!snapshot) {
      set('task-title', state.loading ? '작업을 불러오는 중' : '작업을 조회할 수 없습니다');
      set('document', state.loading ? '연결을 기다리고 있습니다.' : '접속 상태를 확인해 주세요.');
      $('agents').replaceChildren(element('p', '관측 데이터가 없습니다.', 'empty'));
      $('activities').replaceChildren();
      set('agent-count', '—'); set('collection', ''); set('task-state', '확인 불가');
      set('progress', '진행률 확인 불가'); set('verification', '');
      $('task-rows').replaceChildren();
      document.querySelectorAll('[data-phase]').forEach(node => { node.classList.remove('current'); node.removeAttribute('aria-current'); });
      return;
    }
    set('project-name', snapshot.project?.name || '현재 프로젝트');
    set('branch', snapshot.project?.branch || '브랜치 확인 불가');
    set('retention', snapshot.session?.retention === 'keep' ? '종료 후 기록 보관' : '종료 시 임시 기록 삭제');
    set('session-id', `세션 ${snapshot.session?.id || '확인 불가'}`);
    const active = snapshot.tasks?.active;
    const currentPhase = phase(active);
    document.querySelectorAll('[data-phase]').forEach(node => {
      const current = node.dataset.phase === currentPhase;
      node.classList.toggle('current', current);
      if (current) node.setAttribute('aria-current', 'step'); else node.removeAttribute('aria-current');
    });
    set('task-state', stageLabels[currentPhase] || '활성 작업 없음');
    set('task-title', active ? (active.plan.match(/^#\s+(.+)$/m)?.[1] || '현재 작업') : '현재 진행 중인 작업이 없습니다');
    set('progress', progressText(active?.progress));
    const verified = field(active?.status, 'verified');
    set('verification', verified === 'failed' ? '검증 실패 · 실행 기록에서 원인을 확인해 주세요.'
      : verified === 'yes' ? '검증 통과' : ['skipped', 'n/a'].includes(verified) ? '검증 생략 또는 대상 없음 · 검증 결과 참조' : '검증 결과 미확인');
    $('verification').className = verified === 'failed' ? 'failure' : '';
    set('document', active ? (active[doc] || '아직 기록이 없습니다.') : 'Claude에서 forge 작업을 시작하면 계획과 실행 기록이 여기에 표시됩니다.');
    const agents = snapshot.agents || [];
    set('agent-count', `${agents.length}개 관측`);
    set('collection', snapshot.session?.collection === 'unavailable' ? '이벤트 수집 확인 불가' : '이 세션에서 관측된 주 에이전트와 서브에이전트');
    $('agents').replaceChildren(...agents.map(agent => {
      const row = element('div', undefined, 'agent');
      const line = element('div', undefined, 'agent-line');
      const name = element('span', agent.name || agent.id, 'agent-name');
      name.append(element('span', agent.id === 'main' ? '주 에이전트' : '서브에이전트', 'agent-type'));
      line.append(name, element('span', agentState(agent.status, state.connected, archived),
        `agent-state ${state.connected && !archived ? agent.status : 'unknown'}`));
      row.append(line, element('p', agent.task || '수행 작업 미확인'), element('time', `최근 관측 ${time(agent.lastSeen)}`));
      return row;
    }));
    if (!agents.length) $('agents').append(element('p', '관측된 에이전트가 없습니다.', 'empty'));
    $('activities').replaceChildren(...(snapshot.activities || []).slice().reverse().map(activity => {
      const row = element('li', undefined, activity.error ? 'error' : '');
      const agent = agents.find(item => item.id === activity.agentId);
      row.append(element('time', time(activity.time, true)), element('span',
        `${agent?.name || activity.agentId || 'Claude'} · ${eventLabels[activity.event] || activity.event}${activity.tool ? ` (${activity.tool})` : ''}`));
      return row;
    }));
    if (!snapshot.activities?.length) $('activities').append(element('li', '아직 관측된 활동이 없습니다.', 'empty'));
    const rows = snapshot.tasks?.rows || [];
    set('task-count', `${rows.length}개 작업`);
    $('task-rows').replaceChildren(...rows.map(task => {
      const row = element('tr');
      const verification = {O:'통과', x:'실패', '~':'생략 / 해당 없음', '-':'미확인'};
      const retro = {O:'기록됨', X:'생략', '-':'대기'};
      [ `${task.number || ''} ${task.slug}`, stageLabels[task.stage] || task.stage,
        verification[task.verified] || task.verified, retro[task.retro] || task.retro, task.date ].forEach(value => row.append(element('td', value || '—')));
      return row;
    }));
    if (!rows.length) {
      const row = element('tr'); const cell = element('td', '이 브랜치에 기록된 작업이 없습니다.');
      cell.colSpan = 5; row.append(cell); $('task-rows').append(row);
    }
  }

  async function loadHistory() {
    const generation = ++historyGeneration;
    $('history-list').replaceChildren(element('p', '보관 기록을 불러오는 중입니다.', 'empty'));
    try {
      const data = await request('/api/history');
      if (generation !== historyGeneration) return;
      const records = data.records || [];
      $('history-list').replaceChildren(...records.map(record => {
        const button = element('button', `${time(record.startedAt)} 시작`, 'history-item');
        button.append(element('small', `${record.branch} · ${time(record.endedAt)} 종료`));
        button.addEventListener('click', () => { setView('overview'); controller.select(record.id); });
        return button;
      }));
      if (!records.length) $('history-list').append(element('p', '보관된 세션이 없습니다. 기록 보관을 선택한 세션이 종료되면 여기에 표시됩니다.', 'empty'));
    } catch (error) {
      if (generation === historyGeneration) $('history-list').replaceChildren(element('p', `보관 기록을 조회할 수 없습니다. ${error.message}`, 'empty'));
    }
  }
  function setView(next) {
    view = next;
    set('view-title', {overview:'전체 현황', tasks:'작업 기록', history:'모니터 기록'}[view]);
    $('dashboard').hidden = view !== 'overview';
    $('tasks-view').hidden = view !== 'tasks';
    $('history-view').hidden = view !== 'history';
    document.querySelectorAll('[data-view]').forEach(button => {
      const selected = button.dataset.view === view;
      button.classList.toggle('selected', selected);
      if (selected) button.setAttribute('aria-current', 'page'); else button.removeAttribute('aria-current');
    });
    if (view === 'history') loadHistory();
  }
  document.querySelectorAll('[data-view]').forEach(button => button.addEventListener('click', () => setView(button.dataset.view)));
  document.querySelectorAll('[data-doc]').forEach(button => button.addEventListener('click', () => {
    doc = button.dataset.doc;
    document.querySelectorAll('[data-doc]').forEach(tab => {
      const selected = tab.dataset.doc === doc;
      tab.classList.toggle('selected', selected); tab.setAttribute('aria-pressed', String(selected));
    });
    render(controller.state);
  }));
  function returnLive() {
    setView('overview');
    controller.select(null);
  }
  $('return-live').addEventListener('click', returnLive);
  $('current-session').addEventListener('click', returnLive);
  // Sequential refreshes avoid overlap. No polling takes place while viewing an archive.
  async function poll() {
    if (!controller.state.record) await controller.load();
    setTimeout(poll, 1200);
  }
  poll();
}());
