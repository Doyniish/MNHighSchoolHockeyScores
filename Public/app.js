
(function() {
  const $ = (sel) => document.querySelector(sel);
  const $$ = (sel) => Array.from(document.querySelectorAll(sel));

  const gamesEl = $('#games');
  const loadingEl = $('#loading');
  const datePicker = $('#datePicker');
  const prevDayBtn = $('#prevDay');
  const nextDayBtn = $('#nextDay');
  const teamSearch = $('#teamSearch');
  const addTeamBtn = $('#addTeam');
  const activeTeamsEl = $('#activeTeams');
  const liveIndicator = $('#liveIndicator');

  let activeTeams = [];
  let currentDate = new Date();

  function fmtDate(d) {
    const y = d.getFullYear();
    const m = String(d.getMonth()+1).padStart(2, '0');
    const day = String(d.getDate()).padStart(2, '0');
    return `${y}-${m}-${day}`;
  }

  function setDate(d) {
    currentDate = d;
    datePicker.value = fmtDate(d);
    refresh();
  }

  function adjustDate(deltaDays) {
    const d = new Date(currentDate);
    d.setDate(d.getDate() + deltaDays);
    setDate(d);
  }

  function initials(name) {
    if (!name) return '';
    return name.split(/\\s+/).map(s => s[0]).join('').slice(0,3).toUpperCase();
  }

  function badgeColor(name) {
    let hash = 0; for (let i=0; i<name.length; i++) hash = (hash*31 + name.charCodeAt(i))|0;
    const hue = Math.abs(hash) % 360;
    return `hsl(${hue} 25% 30%)`;
  }

  function teamBadge(name) {
    const el = document.createElement('div');
    el.className = 'team-badge';
    el.textContent = initials(name);
    el.style.background = badgeColor(name||'');
    return el;
  }

  function renderGames(items) {
    gamesEl.innerHTML = '';
    let anyLive = false;

    items.forEach(item => {
      const card = document.createElement('div');
      card.className = 'game-card';

      const teams = document.createElement('div');
      teams.className = 'teams';

      const vRow = document.createElement('div');
      vRow.className = 'team-row';
      vRow.appendChild(teamBadge(item.visitorTeam||''));
      const vName = document.createElement('div'); vName.className = 'team-name'; vName.textContent = item.visitorTeam||''; vRow.appendChild(vName);
      const vScore = document.createElement('div'); vScore.className = 'score' + ((item.visitorScore ?? -1) > (item.homeScore ?? -1) ? ' winner' : ''); vScore.textContent = item.visitorScore ?? '-'; vRow.appendChild(vScore);

      const hRow = document.createElement('div');
      hRow.className = 'team-row';
      hRow.appendChild(teamBadge(item.homeTeam||''));
      const hName = document.createElement('div'); hName.className = 'team-name'; hName.textContent = item.homeTeam||''; hRow.appendChild(hName);
      const hScore = document.createElement('div'); hScore.className = 'score' + ((item.homeScore ?? -1) > (item.visitorScore ?? -1) ? ' winner' : ''); hScore.textContent = item.homeScore ?? '-'; hRow.appendChild(hScore);

      teams.appendChild(vRow);
      teams.appendChild(hRow);

      const meta = document.createElement('div');
      meta.className = 'meta';

      const status = document.createElement('div');
      status.className = 'status';
      if (item.status === 'in_progress') { status.classList.add('live'); status.textContent = 'LIVE'; anyLive = true; }
      else if (item.status === 'completed') { status.classList.add('final'); status.textContent = item.statusLabel || 'FINAL'; }
      else { status.textContent = item.statusLabel || 'Scheduled'; }

      meta.appendChild(status);

      const location = document.createElement('div');
      location.className = 'location';
      location.textContent = item.location || '';

      card.appendChild(teams);
      card.appendChild(meta);
      card.appendChild(location);

      gamesEl.appendChild(card);
    });

    liveIndicator.classList.toggle('hidden', !anyLive);
  }

  async function fetchScores() {
    loadingEl.style.display = 'block';

    const y = currentDate.getFullYear();
    const m = currentDate.getMonth() + 1;
    const d = currentDate.getDate();

    let url = `/scores/${y}/${m}/${d}`;

    const teamParams = activeTeams.map(t => t.trim()).filter(Boolean);
    if (teamParams.length === 1) {
      url = `/scores/team/${encodeURIComponent(teamParams[0])}`;
    } else if (teamParams.length > 1) {
      const names = encodeURIComponent(teamParams.join(','));
      url = `/scores/teams?names=${names}`;
    }

    const res = await fetch(url);
    const data = await res.json();

    renderGames(data);
    loadingEl.style.display = 'none';
  }

  function refresh() { fetchScores().catch(console.error); }

  function renderTeamChips() {
    activeTeamsEl.innerHTML = '';
    activeTeams.forEach((t, idx) => {
      const chip = document.createElement('div'); chip.className='chip'; chip.textContent = t;
      const x = document.createElement('button'); x.textContent='✕'; x.addEventListener('click', () => { activeTeams.splice(idx,1); renderTeamChips(); refresh(); });
      chip.appendChild(x);
      activeTeamsEl.appendChild(chip);
    });
  }

  datePicker.addEventListener('change', () => {
    const d = new Date(datePicker.value);
    if (!isNaN(d)) setDate(d);
  });
  prevDayBtn.addEventListener('click', () => adjustDate(-1));
  nextDayBtn.addEventListener('click', () => adjustDate(1));
  addTeamBtn.addEventListener('click', () => {
    const v = teamSearch.value.trim();
    if (v && !activeTeams.includes(v)) { activeTeams.push(v); renderTeamChips(); refresh(); }
    teamSearch.value = '';
  });
  teamSearch.addEventListener('keydown', (e) => { if (e.key === 'Enter') { addTeamBtn.click(); } });

  setDate(new Date());
  renderTeamChips();
  refresh();
  setInterval(refresh, 60000);
})();
