// Side panel — macOS glass style. Profile, live feed, chat, metrics.
const { useState: useSideState, useEffect: useSideEffect, useMemo: useSideMemo, useRef: useSideRef } = React;

const STATUS_MAP = {
  working:   { c: '#10B981', label: 'Trabajando' },
  meeting:   { c: '#F59E0B', label: 'En reunión' },
  blocked:   { c: '#EF4444', label: 'Bloqueado' },
  idle:      { c: '#94A3B8', label: 'Inactivo' },
  traveling: { c: '#06B6D4', label: 'Moviéndose' },
  paused:    { c: '#64748B', label: 'Pausado' },
};

function StatusDot({ status }) {
  const m = STATUS_MAP[status] || STATUS_MAP.idle;
  return (
    <span style={{
      display: 'inline-flex', alignItems: 'center', gap: 6,
      fontSize: 11, fontFamily: 'JetBrains Mono, monospace', color: '#475569',
      fontWeight: 500,
    }}>
      <span style={{
        width: 8, height: 8, background: m.c, borderRadius: '50%',
        boxShadow: `0 0 0 2px ${m.c}25`,
      }} />
      {m.label}
    </span>
  );
}

function DeptChip({ dept }) {
  const d = window.DEPARTMENTS[dept];
  if (!d) return null;
  return (
    <span style={{
      display: 'inline-flex', alignItems: 'center', gap: 5,
      padding: '3px 9px', borderRadius: 6, fontSize: 10.5,
      fontFamily: 'JetBrains Mono, monospace', fontWeight: 600,
      letterSpacing: '0.04em', textTransform: 'uppercase',
      background: d.color + '15', color: d.color,
      border: `1px solid ${d.color}30`,
    }}>
      <span>{d.icon}</span>{d.name}
    </span>
  );
}

function formatTime(ts) {
  const diff = Date.now() - ts;
  if (diff < 60000) return 'ahora';
  if (diff < 3600000) return Math.floor(diff / 60000) + 'm';
  if (diff < 86400000) return Math.floor(diff / 3600000) + 'h';
  return Math.floor(diff / 86400000) + 'd';
}

function Sparkline({ data, color = '#10B981', h = 32, w = 140 }) {
  const max = Math.max(...data, 1);
  const points = data.map((v, i) => `${(i / (data.length - 1)) * w},${h - (v / max) * (h - 3) - 1.5}`).join(' ');
  const area = `0,${h} ${points} ${w},${h}`;
  return (
    <svg width={w} height={h} style={{ display: 'block' }}>
      <defs>
        <linearGradient id={`sg-${color.slice(1)}`} x1="0" x2="0" y1="0" y2="1">
          <stop offset="0%" stopColor={color} stopOpacity="0.25" />
          <stop offset="100%" stopColor={color} stopOpacity="0" />
        </linearGradient>
      </defs>
      <polygon points={area} fill={`url(#sg-${color.slice(1)})`} />
      <polyline points={points} fill="none" stroke={color} strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}

// ————— AGENT PROFILE —————
function AgentProfile({ agent, onAction, messages, onSendMessage }) {
  const [tab, setTab] = useSideState('activity');
  const [draft, setDraft] = useSideState('');
  const d = window.DEPARTMENTS[agent.dept];
  const status = STATUS_MAP[agent.status] || STATUS_MAP.idle;

  const activitySeries = useSideMemo(() =>
    Array.from({ length: 24 }, (_, i) =>
      Math.max(2, Math.floor(agent.efficiency / 3 + Math.sin(i / 2 + agent.id.charCodeAt(1)) * 12 + Math.random() * 8))
    ), [agent.id]);

  const chatScrollRef = useSideRef();
  useSideEffect(() => {
    if (chatScrollRef.current) chatScrollRef.current.scrollTop = chatScrollRef.current.scrollHeight;
  }, [messages]);

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%', minHeight: 0 }}>
      {/* Header */}
      <div style={{ padding: 16 }}>
        <div style={{ display: 'flex', gap: 14, alignItems: 'flex-start' }}>
          <div style={{
            width: 56, height: 56, borderRadius: 14,
            background: `linear-gradient(135deg, ${d.color}, ${d.color}B0)`,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            fontSize: 32, position: 'relative', flexShrink: 0,
            boxShadow: `0 8px 20px -6px ${d.color}60, inset 0 1px 0 rgba(255,255,255,0.25)`,
          }}>
            <span style={{ filter: 'drop-shadow(0 2px 2px rgba(0,0,0,0.3))' }}>{agent.avatar}</span>
            <span style={{
              position: 'absolute', bottom: -3, right: -3,
              width: 16, height: 16, borderRadius: '50%',
              background: status.c,
              border: '2.5px solid #fff',
              boxShadow: `0 0 0 1px ${status.c}40`,
            }}/>
          </div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ fontSize: 16, fontWeight: 700, color: '#0F172A', lineHeight: 1.2, letterSpacing: '-0.01em' }}>
              {agent.name}
            </div>
            <div style={{ fontSize: 11, color: '#64748B', marginTop: 3, fontFamily: 'JetBrains Mono, monospace', fontWeight: 500 }}>
              {agent.id.toUpperCase()} · {agent.level}
            </div>
            <div style={{ marginTop: 8, display: 'flex', gap: 6, flexWrap: 'wrap' }}>
              <DeptChip dept={agent.dept} />
              <StatusDot status={agent.status} />
            </div>
          </div>
        </div>

        {/* Quick actions */}
        <div style={{ display: 'flex', gap: 6, marginTop: 14 }}>
          <button className={`sp-btn ${agent.status === 'paused' ? 'accent' : 'ghost'}`}
            onClick={() => onAction('toggle-pause')} style={{ flex: 1 }}>
            {agent.status === 'paused' ? '▶ Reanudar' : '⏸ Pausar'}
          </button>
          <button className="sp-btn primary" onClick={() => onAction('clone')} style={{ flex: 1 }}>
            ⊕ Clonar
          </button>
        </div>
      </div>

      {/* Current task */}
      <div style={{
        margin: '0 14px 10px', padding: 12,
        background: `linear-gradient(135deg, ${d.color}08, transparent)`,
        border: `1px solid ${d.color}20`,
        borderRadius: 10,
        position: 'relative', overflow: 'hidden',
      }}>
        <div style={{
          position: 'absolute', left: 0, top: 0, bottom: 0, width: 3,
          background: d.color,
        }} />
        <div style={{ fontSize: 9, color: d.color, fontFamily: 'JetBrains Mono, monospace', letterSpacing: '0.08em', fontWeight: 700 }}>
          TAREA ACTUAL
        </div>
        <div style={{ fontSize: 13.5, color: '#0F172A', fontWeight: 600, marginTop: 4, lineHeight: 1.35 }}>
          {agent.activity?.label || '—'}
        </div>
        <div style={{ fontSize: 11.5, color: '#475569', marginTop: 4, fontStyle: 'italic', lineHeight: 1.4 }}>
          "{agent.activity?.thought}"
        </div>
      </div>

      {/* Tabs */}
      <div className="tab-row">
        {['activity', 'logs', 'chat'].map(x => (
          <button key={x} onClick={() => setTab(x)} className={`tab-btn ${tab === x ? 'active' : ''}`}>
            {x === 'activity' ? 'Actividad' : x === 'logs' ? 'Logs' : 'Chat 1-a-1'}
          </button>
        ))}
      </div>

      {/* Tab content */}
      <div style={{ flex: 1, overflow: 'auto', minHeight: 0 }}>
        {tab === 'activity' && (
          <div style={{ padding: 14 }}>
            <div className="metric-row" style={{ gridTemplateColumns: '1fr 1fr' }}>
              <MetricCard label="Eficiencia"  value={agent.efficiency + '%'} accent="#10B981"
                sub={agent.efficiency > 85 ? '↑ top 20%' : 'normal'} />
              <MetricCard label="Tareas hoy"  value={agent.tasksDone} accent="#3B82F6" sub="completadas" />
              <MetricCard label="En cola"     value={agent.tasksQueued} accent="#F59E0B" sub="pendientes" />
              <MetricCard label="Nivel"       value={agent.level} accent="#8B5CF6" sub={window.DEPARTMENTS[agent.dept].name} />
            </div>
            <div style={{
              marginTop: 12, padding: 14,
              background: '#fff', border: '1px solid rgba(15,23,42,0.06)',
              borderRadius: 10,
            }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', marginBottom: 8 }}>
                <div style={{ fontSize: 9.5, color: '#64748B', fontFamily: 'JetBrains Mono, monospace', letterSpacing: '0.08em', fontWeight: 600 }}>
                  ACTIVIDAD 24H
                </div>
                <div style={{ fontSize: 13, fontWeight: 700, color: d.color, fontFamily: 'JetBrains Mono, monospace' }}>
                  {activitySeries.reduce((a, b) => a + b, 0)}
                </div>
              </div>
              <Sparkline data={activitySeries} color={d.color} />
            </div>
          </div>
        )}

        {tab === 'logs' && (
          <div>
            {agent.log.map((l, i) => (
              <div key={i} style={{
                padding: '10px 14px', borderBottom: '1px solid rgba(15,23,42,0.04)',
                display: 'flex', gap: 10, alignItems: 'flex-start',
              }}>
                <div style={{
                  width: 18, height: 18, borderRadius: 5, marginTop: 2, flexShrink: 0,
                  background: l.status === 'done' ? '#10B98115' : '#94A3B815',
                  color: l.status === 'done' ? '#10B981' : '#94A3B8',
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  fontSize: 11, fontWeight: 700,
                }}>{l.status === 'done' ? '✓' : '×'}</div>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ fontSize: 12, color: '#0F172A', fontWeight: 500 }}>{l.label}</div>
                  <div style={{ fontSize: 11, color: '#64748B', marginTop: 1 }}>{l.detail}</div>
                </div>
                <div style={{ fontSize: 10, color: '#94A3B8', fontFamily: 'JetBrains Mono, monospace' }}>{formatTime(l.t)}</div>
              </div>
            ))}
          </div>
        )}

        {tab === 'chat' && (
          <div style={{ display: 'flex', flexDirection: 'column', height: '100%' }}>
            <div ref={chatScrollRef} style={{ flex: 1, overflow: 'auto', padding: 12 }}>
              {messages.length === 0 && (
                <div style={{ color: '#94A3B8', fontSize: 12, textAlign: 'center', padding: 32 }}>
                  Envía un mensaje directo a {agent.name.split(' ')[0]}.
                </div>
              )}
              {messages.map((m, i) => (
                <div key={i} style={{
                  display: 'flex', justifyContent: m.from === 'me' ? 'flex-end' : 'flex-start',
                  marginBottom: 8,
                }}>
                  <div style={{
                    maxWidth: '82%', padding: '9px 12px', borderRadius: 14,
                    background: m.from === 'me' ? '#0F2847' : '#fff',
                    color: m.from === 'me' ? '#F8FAFC' : '#0F172A',
                    fontSize: 12.5, lineHeight: 1.45,
                    border: m.from === 'me' ? 'none' : '1px solid rgba(15,23,42,0.08)',
                    borderBottomRightRadius: m.from === 'me' ? 4 : 14,
                    borderBottomLeftRadius:  m.from === 'me' ? 14 : 4,
                  }}>{m.text}</div>
                </div>
              ))}
            </div>
            <div style={{ padding: 10, borderTop: '1px solid rgba(15,23,42,0.06)', display: 'flex', gap: 6, background: 'rgba(255,255,255,0.5)' }}>
              <input
                value={draft}
                onChange={e => setDraft(e.target.value)}
                onKeyDown={e => {
                  if (e.key === 'Enter' && draft.trim()) { onSendMessage(draft); setDraft(''); }
                }}
                placeholder="Mensaje directo…"
                style={{
                  flex: 1, border: '1px solid rgba(15,23,42,0.1)', borderRadius: 8,
                  padding: '8px 11px', fontSize: 12.5, outline: 'none',
                  background: '#fff',
                }}
              />
              <button className="sp-btn accent" onClick={() => { if (draft.trim()) { onSendMessage(draft); setDraft(''); } }}>
                ↵
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

function MetricCard({ label, value, accent, sub }) {
  return (
    <div className="metric-card" style={{ '--accent': accent }}>
      <div className="metric-label">{label}</div>
      <div className="metric-value" style={{ color: accent }}>{value}</div>
      {sub && <div className="metric-sub">{sub}</div>}
    </div>
  );
}

// ————— LIVE FEED (no agent selected) —————
function LiveFeed({ agents, events, onSelectAgent, metrics, alerts = [] }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%', minHeight: 0 }}>
      {/* Org metrics */}
      <div style={{ padding: 14 }}>
        <div style={{
          fontSize: 9.5, color: '#64748B', fontFamily: 'JetBrains Mono, monospace',
          letterSpacing: '0.1em', marginBottom: 10, fontWeight: 600,
          display: 'flex', alignItems: 'center', gap: 8,
        }}>
          <span className="live-dot" style={{ width: 6, height: 6 }} />
          ORGANIZACIÓN · EN VIVO
        </div>
        <div className="metric-row" style={{ gridTemplateColumns: 'repeat(2, 1fr)' }}>
          <MetricCard label="Activos" value={`${metrics.working}/${agents.length}`} accent="#10B981"
            sub={`${Math.round(metrics.working / agents.length * 100)}% utilización`} />
          <MetricCard label="Reuniones" value={metrics.meeting} accent="#F59E0B"
            sub={metrics.meeting === 0 ? 'sin reuniones' : 'en curso'} />
          <MetricCard label="Bloqueados" value={metrics.blocked} accent="#EF4444"
            sub={metrics.blocked > 0 ? 'requieren input' : 'todo fluye'} />
          <MetricCard label="Tareas hoy" value={metrics.tasksDone} accent="#3B82F6"
            sub="completadas" />
        </div>

        {/* Efficiency gauge */}
        <div style={{
          marginTop: 10, padding: 12,
          background: '#fff', border: '1px solid rgba(15,23,42,0.06)',
          borderRadius: 10,
        }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline' }}>
            <div style={{ fontSize: 9.5, color: '#64748B', fontFamily: 'JetBrains Mono, monospace', letterSpacing: '0.08em', fontWeight: 600 }}>
              EFICIENCIA PROMEDIO
            </div>
            <div style={{ fontSize: 20, fontWeight: 800, color: '#10B981', letterSpacing: '-0.02em' }}>
              {metrics.avgEfficiency}%
            </div>
          </div>
          <div style={{
            marginTop: 8, height: 6, background: 'rgba(15,23,42,0.06)', borderRadius: 3, overflow: 'hidden',
          }}>
            <div style={{
              width: metrics.avgEfficiency + '%', height: '100%',
              background: 'linear-gradient(90deg, #10B981, #059669)',
              boxShadow: '0 0 8px rgba(16,185,129,0.4)',
              transition: 'width 0.6s',
            }} />
          </div>
        </div>
      </div>

      {/* Department breakdown */}
      <div className="section-head">POR DEPARTAMENTO</div>
      <div style={{ paddingBottom: 8 }}>
        {Object.keys(window.DEPARTMENTS).map(key => {
          const d = window.DEPARTMENTS[key];
          const deptAgents = agents.filter(a => a.dept === key);
          if (deptAgents.length === 0) return null;
          const activeN = deptAgents.filter(a => a.status === 'working' || a.status === 'meeting').length;
          const blockedN = deptAgents.filter(a => a.status === 'blocked').length;
          const pct = (activeN / deptAgents.length) * 100;
          return (
            <div key={key} className="dept-bar-row">
              <div style={{ width: 14, textAlign: 'center', color: d.color, fontSize: 12, fontWeight: 700 }}>{d.icon}</div>
              <div style={{ width: 90, color: '#0F172A', fontWeight: 500, fontSize: 11.5 }}>{d.name}</div>
              <div style={{ flex: 1, height: 5, background: 'rgba(15,23,42,0.06)', borderRadius: 3, overflow: 'hidden', position: 'relative' }}>
                <div style={{
                  width: `${pct}%`, height: '100%',
                  background: `linear-gradient(90deg, ${d.color}, ${d.color}CC)`,
                  transition: 'width 0.5s',
                }} />
              </div>
              {blockedN > 0 && (
                <span style={{
                  fontSize: 9, color: '#fff', background: '#EF4444',
                  padding: '1px 5px', borderRadius: 3, fontWeight: 700,
                }}>!{blockedN}</span>
              )}
              <div style={{ width: 30, textAlign: 'right', color: '#64748B', fontFamily: 'JetBrains Mono, monospace', fontSize: 10, fontWeight: 500 }}>
                {activeN}/{deptAgents.length}
              </div>
            </div>
          );
        })}
      </div>

      {/* Feed */}
      <div className="section-head" style={{ borderTop: '1px solid rgba(15,23,42,0.06)', paddingTop: 10 }}>
        FEED EN VIVO
        <span style={{ fontSize: 9, color: '#94A3B8', fontWeight: 500 }}>{events.length} eventos</span>
      </div>
      <div style={{ flex: 1, overflow: 'auto' }}>
        {events.map((e) => {
          const a = agents.find(x => x.id === e.agentId);
          if (!a) return null;
          const d = window.DEPARTMENTS[a.dept];
          return (
            <div key={e.id} onClick={() => onSelectAgent(a.id)} className={`feed-item ${e.isAlert ? 'alert' : ''}`}>
              <div style={{
                width: 3, borderRadius: 2,
                background: e.isAlert ? '#EF4444' : d.color,
                flexShrink: 0, alignSelf: 'stretch',
              }}/>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', gap: 6 }}>
                  <div style={{ fontSize: 12, color: '#0F172A', fontWeight: 600, display: 'flex', alignItems: 'center', gap: 6 }}>
                    {e.isAlert && <span className="alert-dot" style={{ width: 6, height: 6 }} />}
                    {a.name}
                  </div>
                  <div style={{ fontSize: 10, color: '#94A3B8', fontFamily: 'JetBrains Mono, monospace', flexShrink: 0 }}>{formatTime(e.t)}</div>
                </div>
                <div style={{ fontSize: 11, color: e.isAlert ? '#DC2626' : '#475569', marginTop: 1, fontWeight: e.isAlert ? 600 : 400 }}>
                  {e.text}
                </div>
              </div>
            </div>
          );
        })}
        {events.length === 0 && (
          <div style={{ padding: 32, textAlign: 'center', color: '#94A3B8', fontSize: 12 }}>
            Esperando eventos...
          </div>
        )}
      </div>
    </div>
  );
}

window.AgentProfile = AgentProfile;
window.LiveFeed = LiveFeed;
window.StatusDot = StatusDot;
window.DeptChip = DeptChip;
