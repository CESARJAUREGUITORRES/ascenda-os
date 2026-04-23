// Department focus view — full-screen drill-down of one department.
// Shows agents of that dept, projects board, group chat, metrics.

const { useState: useDfState, useEffect: useDfEffect, useRef: useDfRef, useMemo: useDfMemo } = React;

// Mock projects per department
const DEPT_PROJECTS = {
  executive: [
    { id: 'p1', name: 'Expansión LATAM Q3',       status: 'en curso', progress: 62, owner: 'a01', priority: 'high' },
    { id: 'p2', name: 'Board deck inversores',    status: 'en revisión', progress: 85, owner: 'a02', priority: 'high' },
    { id: 'p3', name: 'OKRs Q2 review',            status: 'en curso', progress: 40, owner: 'a03', priority: 'medium' },
  ],
  marketing: [
    { id: 'p1', name: 'Campaña Google Ads Q2',    status: 'en curso', progress: 74, owner: 'a04', priority: 'high' },
    { id: 'p2', name: 'A/B test landing hero',    status: 'testing',  progress: 55, owner: 'a05', priority: 'medium' },
    { id: 'p3', name: 'Email nurture flow v3',    status: 'en curso', progress: 30, owner: 'a06', priority: 'medium' },
    { id: 'p4', name: 'LinkedIn content plan',    status: 'brief',    progress: 15, owner: 'a07', priority: 'low' },
  ],
  finance: [
    { id: 'p1', name: 'Cash flow 90 días',        status: 'en curso', progress: 90, owner: 'a08', priority: 'high' },
    { id: 'p2', name: 'Proyección P&L Q3',        status: 'en curso', progress: 68, owner: 'a09', priority: 'high' },
    { id: 'p3', name: 'Reconciliación bancaria',  status: 'bloqueado', progress: 45, owner: 'a10', priority: 'medium' },
    { id: 'p4', name: 'Review burn rate mensual', status: 'en curso', progress: 72, owner: 'a11', priority: 'medium' },
  ],
  callcenter: [
    { id: 'p1', name: 'Recuperación carritos',    status: 'en curso', progress: 58, owner: 'a12', priority: 'high' },
    { id: 'p2', name: 'Seguimiento leads calientes', status: 'en curso', progress: 71, owner: 'a13', priority: 'high' },
    { id: 'p3', name: 'Encuesta NPS Q2',          status: 'en curso', progress: 44, owner: 'a14', priority: 'medium' },
    { id: 'p4', name: 'Soporte técnico tickets',  status: 'en curso', progress: 82, owner: 'a15', priority: 'high' },
  ],
  sales: [
    { id: 'p1', name: 'Pipeline Q2 push',         status: 'en curso', progress: 65, owner: 'a17', priority: 'high' },
    { id: 'p2', name: 'Demo Zara Group',          status: 'en curso', progress: 80, owner: 'a18', priority: 'high' },
    { id: 'p3', name: 'Cold outreach batch 12',   status: 'en curso', progress: 35, owner: 'a19', priority: 'medium' },
  ],
  hr: [
    { id: 'p1', name: 'Hiring Marketing Lead',    status: 'en curso', progress: 55, owner: 'a21', priority: 'high' },
    { id: 'p2', name: 'Onboarding abril',         status: 'en curso', progress: 70, owner: 'a22', priority: 'medium' },
    { id: 'p3', name: 'Survey clima laboral',     status: 'análisis', progress: 88, owner: 'a21', priority: 'medium' },
  ],
  scheduler: [
    { id: 'p1', name: 'Optimización turnos Call', status: 'en curso', progress: 62, owner: 'a23', priority: 'high' },
    { id: 'p2', name: 'Sync calendarios Q3',      status: 'en curso', progress: 40, owner: 'a24', priority: 'medium' },
  ],
  research: [
    { id: 'p1', name: 'Análisis competidor X',    status: 'en curso', progress: 78, owner: 'a25', priority: 'high' },
    { id: 'p2', name: 'User research síntesis',   status: 'análisis', progress: 60, owner: 'a26', priority: 'medium' },
    { id: 'p3', name: 'Benchmark LATAM',          status: 'en curso', progress: 30, owner: 'a27', priority: 'medium' },
  ],
  accounting: [
    { id: 'p1', name: 'Cierre contable Marzo',    status: 'en curso', progress: 92, owner: 'a28', priority: 'high' },
    { id: 'p2', name: 'IVA Q1 presentación',      status: 'listo',    progress: 100, owner: 'a29', priority: 'high' },
    { id: 'p3', name: 'Auditoría gastos',         status: 'análisis', progress: 48, owner: 'a30', priority: 'medium' },
  ],
  legal: [
    { id: 'p1', name: 'Contrato proveedor SaaS',  status: 'revisión', progress: 70, owner: 'a31', priority: 'high' },
    { id: 'p2', name: 'T&C v4',                    status: 'en curso', progress: 85, owner: 'a32', priority: 'medium' },
  ],
};

function DepartmentFocus({ zoneId, agents, onBack, onSelectAgent, onNavigate }) {
  const [tab, setTab] = useDfState('overview'); // overview | projects | chat
  const [chatDraft, setChatDraft] = useDfState('');
  const [chatMessages, setChatMessages] = useDfState([]);
  const chatScrollRef = useDfRef();

  const zone = window.ZONES.find(z => z.id === zoneId);
  if (!zone) return null;
  const dept = window.DEPARTMENTS[zone.dept];
  const deptKey = zone.dept;
  const deptAgents = useDfMemo(() => agents.filter(a => a.dept === deptKey), [agents, deptKey]);
  const projects = DEPT_PROJECTS[deptKey] || [];

  // Metrics
  const metrics = useDfMemo(() => {
    const total = deptAgents.length;
    const working = deptAgents.filter(a => ['working','traveling','meeting'].includes(a.status)).length;
    const blocked = deptAgents.filter(a => a.status === 'blocked').length;
    const paused = deptAgents.filter(a => a.status === 'paused').length;
    const avgEff = total ? Math.round(deptAgents.reduce((s, a) => s + a.efficiency, 0) / total) : 0;
    const totalTasks = deptAgents.reduce((s, a) => s + a.tasksDone, 0);
    const queued = deptAgents.reduce((s, a) => s + a.tasksQueued, 0);
    return { total, working, blocked, paused, avgEff, totalTasks, queued };
  }, [deptAgents]);

  // All depts for quick nav
  const allZones = window.ZONES.filter(z => z.dept !== 'hall' && z.dept !== 'meeting');

  useDfEffect(() => {
    if (chatScrollRef.current) chatScrollRef.current.scrollTop = chatScrollRef.current.scrollHeight;
  }, [chatMessages]);

  const sendGroupMessage = () => {
    if (!chatDraft.trim()) return;
    const myMsg = { id: Date.now(), from: 'me', name: 'Tú', text: chatDraft, ts: Date.now() };
    setChatMessages(prev => [...prev, myMsg]);
    setChatDraft('');
    // Auto-replies from 1-2 agents
    const responders = [...deptAgents].sort(() => Math.random() - 0.5).slice(0, 1 + Math.floor(Math.random() * 2));
    responders.forEach((agent, i) => {
      setTimeout(() => {
        const reply = groupReply(agent, chatDraft, projects);
        setChatMessages(prev => [...prev, {
          id: Date.now() + Math.random(),
          from: agent.id, name: agent.name, avatar: agent.avatar,
          color: dept.color, text: reply, ts: Date.now(),
        }]);
      }, 900 + i * 1200 + Math.random() * 600);
    });
  };

  return (
    <div style={{
      position: 'absolute', inset: 0,
      display: 'flex', flexDirection: 'column',
      background: `
        radial-gradient(ellipse at top left, ${dept.color}18, transparent 50%),
        radial-gradient(ellipse at bottom right, ${dept.color}10, transparent 50%),
        linear-gradient(180deg, #F8FAFC 0%, #EEF2FA 100%)
      `,
      borderRadius: 14,
      overflow: 'hidden',
      animation: 'df-enter 0.35s cubic-bezier(0.16, 1, 0.3, 1)',
    }}>
      <style>{`
        @keyframes df-enter {
          from { opacity: 0; transform: scale(1.03); }
          to { opacity: 1; transform: scale(1); }
        }
      `}</style>

      {/* Breadcrumb + header */}
      <div style={{
        padding: '14px 20px',
        background: 'rgba(255, 255, 255, 0.7)',
        backdropFilter: 'blur(24px) saturate(180%)',
        WebkitBackdropFilter: 'blur(24px) saturate(180%)',
        borderBottom: '1px solid rgba(15, 23, 42, 0.06)',
        display: 'flex', alignItems: 'center', gap: 12, flexShrink: 0,
      }}>
        {/* Back chip */}
        <button onClick={onBack} style={{
          display: 'inline-flex', alignItems: 'center', gap: 6,
          padding: '7px 12px', borderRadius: 8,
          background: '#fff', border: '1px solid rgba(15,23,42,0.1)',
          color: '#0F172A', fontSize: 12, fontWeight: 600,
          cursor: 'pointer', fontFamily: 'inherit',
          boxShadow: '0 1px 2px rgba(15,23,42,0.04)',
        }}>
          ← Vista general
        </button>
        <span style={{ color: '#CBD5E1', fontSize: 14 }}>›</span>
        <div style={{
          display: 'inline-flex', alignItems: 'center', gap: 10,
          padding: '6px 14px', borderRadius: 9,
          background: dept.color + '15',
          border: `1px solid ${dept.color}30`,
          color: dept.color, fontSize: 14, fontWeight: 700,
        }}>
          <span style={{ fontSize: 16 }}>{dept.icon}</span>
          {dept.name}
        </div>

        <div style={{ flex: 1 }} />

        {/* Quick nav to other depts */}
        <div style={{
          display: 'flex', gap: 4, alignItems: 'center',
          padding: 3, background: 'rgba(15,23,42,0.04)', borderRadius: 9,
        }}>
          {allZones.map(z => {
            const dz = window.DEPARTMENTS[z.dept];
            if (!dz) return null;
            const active = z.id === zoneId;
            return (
              <button key={z.id}
                onClick={() => onNavigate(z.id)}
                title={dz.name}
                style={{
                  padding: '5px 9px', borderRadius: 6,
                  background: active ? '#fff' : 'transparent',
                  border: 'none', cursor: 'pointer',
                  color: active ? dz.color : '#64748B',
                  fontSize: 13, fontWeight: 700,
                  fontFamily: 'JetBrains Mono, monospace',
                  boxShadow: active ? '0 1px 2px rgba(15,23,42,0.08)' : 'none',
                  display: 'flex', alignItems: 'center', gap: 5,
                }}>
                <span>{dz.icon}</span>
                <span style={{ fontSize: 10 }}>{dz.name.slice(0, 4).toUpperCase()}</span>
              </button>
            );
          })}
        </div>
      </div>

      {/* Tabs */}
      <div style={{
        padding: '0 20px',
        background: 'rgba(255, 255, 255, 0.4)',
        borderBottom: '1px solid rgba(15,23,42,0.06)',
        display: 'flex', gap: 4, flexShrink: 0,
      }}>
        {[
          { id: 'overview', label: 'Vista general', icon: '◉' },
          { id: 'projects', label: 'Proyectos', icon: '▦', count: projects.length },
          { id: 'chat',     label: 'Chat grupal',  icon: '◇' },
        ].map(x => (
          <button key={x.id} onClick={() => setTab(x.id)} style={{
            padding: '10px 14px', border: 'none', background: 'none',
            borderBottom: `2px solid ${tab === x.id ? dept.color : 'transparent'}`,
            color: tab === x.id ? '#0F172A' : '#64748B',
            fontSize: 12, fontWeight: 600, cursor: 'pointer',
            display: 'flex', alignItems: 'center', gap: 6,
            fontFamily: 'inherit',
            transition: 'all 0.15s',
          }}>
            <span>{x.icon}</span>{x.label}
            {x.count !== undefined && (
              <span style={{
                padding: '1px 6px', borderRadius: 10,
                background: tab === x.id ? dept.color + '18' : 'rgba(15,23,42,0.06)',
                color: tab === x.id ? dept.color : '#64748B',
                fontSize: 10, fontWeight: 700,
              }}>{x.count}</span>
            )}
          </button>
        ))}
      </div>

      {/* Content */}
      <div style={{ flex: 1, overflow: 'auto', padding: 20 }}>
        {tab === 'overview' && (
          <OverviewTab metrics={metrics} agents={deptAgents} dept={dept} onSelectAgent={onSelectAgent} />
        )}
        {tab === 'projects' && (
          <ProjectsTab projects={projects} dept={dept} agents={agents} onSelectAgent={onSelectAgent} />
        )}
        {tab === 'chat' && (
          <ChatTab
            agents={deptAgents}
            dept={dept}
            messages={chatMessages}
            draft={chatDraft}
            setDraft={setChatDraft}
            onSend={sendGroupMessage}
            chatScrollRef={chatScrollRef}
          />
        )}
      </div>
    </div>
  );
}

function OverviewTab({ metrics, agents, dept, onSelectAgent }) {
  return (
    <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16, maxWidth: 1100, margin: '0 auto' }}>
      {/* Metrics row - spans both */}
      <div style={{ gridColumn: '1 / -1', display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12 }}>
        <BigMetric label="Equipo" value={`${metrics.working}/${metrics.total}`} sub="activos ahora" color={dept.color} icon="●" />
        <BigMetric label="Proyectos" value={(DEPT_PROJECTS[Object.keys(window.DEPARTMENTS).find(k => window.DEPARTMENTS[k] === dept)] || []).length} sub="en curso" color="#3B82F6" icon="▦" />
        <BigMetric label="Eficiencia" value={`${metrics.avgEff}%`} sub="promedio" color="#10B981" icon="↑" />
        <BigMetric label="Tareas hoy" value={metrics.totalTasks} sub={`${metrics.queued} en cola`} color="#F59E0B" icon="✓" />
      </div>

      {/* Team roster */}
      <div style={{
        gridColumn: '1 / -1',
        background: 'rgba(255, 255, 255, 0.7)',
        backdropFilter: 'blur(20px) saturate(180%)',
        WebkitBackdropFilter: 'blur(20px) saturate(180%)',
        border: '1px solid rgba(255,255,255,0.8)',
        borderRadius: 14, padding: 18,
        boxShadow: '0 4px 16px -4px rgba(15,23,42,0.08)',
      }}>
        <div style={{ fontSize: 10, color: '#64748B', fontFamily: 'JetBrains Mono, monospace', letterSpacing: '0.1em', fontWeight: 600, marginBottom: 12 }}>
          EQUIPO DEL DEPARTAMENTO
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(220px, 1fr))', gap: 10 }}>
          {agents.map(a => (
            <AgentMiniCard key={a.id} agent={a} onClick={() => onSelectAgent(a.id)} deptColor={dept.color} />
          ))}
        </div>
      </div>
    </div>
  );
}

function BigMetric({ label, value, sub, color, icon }) {
  return (
    <div style={{
      background: 'rgba(255, 255, 255, 0.8)',
      backdropFilter: 'blur(20px)',
      border: '1px solid rgba(255,255,255,0.9)',
      borderRadius: 12, padding: 14, position: 'relative', overflow: 'hidden',
      boxShadow: '0 2px 8px -2px rgba(15,23,42,0.06)',
    }}>
      <div style={{
        position: 'absolute', top: 0, left: 0, right: 0, height: 3,
        background: `linear-gradient(90deg, ${color}, ${color}80)`,
      }} />
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
        <div style={{ fontSize: 10, color: '#64748B', fontFamily: 'JetBrains Mono, monospace', letterSpacing: '0.08em', fontWeight: 600, textTransform: 'uppercase' }}>
          {label}
        </div>
        <div style={{ fontSize: 14, color: color + 'A0' }}>{icon}</div>
      </div>
      <div style={{ fontSize: 26, fontWeight: 800, color, marginTop: 4, letterSpacing: '-0.02em', lineHeight: 1 }}>
        {value}
      </div>
      <div style={{ fontSize: 11, color: '#94A3B8', marginTop: 4 }}>{sub}</div>
    </div>
  );
}

function AgentMiniCard({ agent, onClick, deptColor }) {
  const status = {
    working:   { c: '#10B981', l: 'trabajando' },
    meeting:   { c: '#F59E0B', l: 'reunión' },
    blocked:   { c: '#EF4444', l: 'bloqueado' },
    paused:    { c: '#94A3B8', l: 'pausa' },
    traveling: { c: '#06B6D4', l: 'moviéndose' },
    idle:      { c: '#94A3B8', l: 'libre' },
  }[agent.status] || { c: '#94A3B8', l: 'idle' };

  return (
    <button onClick={onClick} style={{
      display: 'flex', alignItems: 'center', gap: 10,
      padding: 10, borderRadius: 10,
      background: '#fff', border: '1px solid rgba(15,23,42,0.08)',
      cursor: 'pointer', textAlign: 'left', width: '100%',
      fontFamily: 'inherit', transition: 'all 0.15s',
    }}
    onMouseEnter={e => { e.currentTarget.style.transform = 'translateY(-1px)'; e.currentTarget.style.boxShadow = '0 4px 12px -2px rgba(15,23,42,0.12)'; e.currentTarget.style.borderColor = deptColor + '50'; }}
    onMouseLeave={e => { e.currentTarget.style.transform = 'translateY(0)'; e.currentTarget.style.boxShadow = 'none'; e.currentTarget.style.borderColor = 'rgba(15,23,42,0.08)'; }}>
      <div style={{
        width: 38, height: 38, borderRadius: 10,
        background: `linear-gradient(135deg, ${deptColor}, ${deptColor}C0)`,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        fontSize: 20, flexShrink: 0, position: 'relative',
        boxShadow: `0 3px 8px -2px ${deptColor}60`,
      }}>
        {agent.avatar}
        <span style={{
          position: 'absolute', bottom: -2, right: -2,
          width: 12, height: 12, borderRadius: '50%',
          background: status.c, border: '2px solid #fff',
        }}/>
      </div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontSize: 12.5, fontWeight: 700, color: '#0F172A' }}>{agent.name}</div>
        <div style={{ fontSize: 10.5, color: '#64748B', marginTop: 1 }}>{agent.level} · {status.l}</div>
        <div style={{ fontSize: 10, color: '#94A3B8', marginTop: 3, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
          {agent.activity?.label}
        </div>
      </div>
    </button>
  );
}

function ProjectsTab({ projects, dept, agents, onSelectAgent }) {
  const statusColor = {
    'en curso':  '#10B981',
    'en revisión': '#F59E0B',
    'testing':   '#06B6D4',
    'brief':     '#94A3B8',
    'bloqueado': '#EF4444',
    'análisis':  '#8B5CF6',
    'revisión':  '#F59E0B',
    'listo':     '#10B981',
  };
  const priorityBg = { high: '#FEE2E2', medium: '#FEF3C7', low: '#E0F2FE' };
  const priorityColor = { high: '#DC2626', medium: '#D97706', low: '#0284C7' };

  return (
    <div style={{ maxWidth: 1100, margin: '0 auto', display: 'grid', gap: 12 }}>
      {projects.map(p => {
        const owner = agents.find(a => a.id === p.owner);
        return (
          <div key={p.id} style={{
            background: 'rgba(255, 255, 255, 0.8)',
            backdropFilter: 'blur(20px)',
            border: '1px solid rgba(255,255,255,0.9)',
            borderRadius: 12, padding: 16,
            display: 'grid', gridTemplateColumns: '3px 1fr auto', gap: 16, alignItems: 'center',
            boxShadow: '0 2px 6px -2px rgba(15,23,42,0.04)',
          }}>
            <div style={{ alignSelf: 'stretch', background: statusColor[p.status] || '#94A3B8', borderRadius: 2 }} />
            <div>
              <div style={{ display: 'flex', gap: 8, alignItems: 'center', marginBottom: 6 }}>
                <span style={{
                  padding: '2px 8px', borderRadius: 4, fontSize: 9.5,
                  fontFamily: 'JetBrains Mono, monospace', fontWeight: 700,
                  letterSpacing: '0.06em', textTransform: 'uppercase',
                  background: priorityBg[p.priority], color: priorityColor[p.priority],
                }}>{p.priority}</span>
                <span style={{
                  padding: '2px 8px', borderRadius: 4, fontSize: 9.5,
                  fontFamily: 'JetBrains Mono, monospace', fontWeight: 700,
                  letterSpacing: '0.06em', textTransform: 'uppercase',
                  background: (statusColor[p.status] || '#94A3B8') + '18',
                  color: statusColor[p.status] || '#64748B',
                }}>{p.status}</span>
              </div>
              <div style={{ fontSize: 15, fontWeight: 700, color: '#0F172A', marginBottom: 8 }}>
                {p.name}
              </div>
              {/* Progress bar */}
              <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                <div style={{ flex: 1, height: 6, background: 'rgba(15,23,42,0.06)', borderRadius: 3, overflow: 'hidden' }}>
                  <div style={{
                    width: p.progress + '%', height: '100%',
                    background: `linear-gradient(90deg, ${dept.color}, ${dept.color}C0)`,
                    transition: 'width 0.5s',
                  }} />
                </div>
                <div style={{ fontSize: 11, fontWeight: 700, color: dept.color, fontFamily: 'JetBrains Mono, monospace', minWidth: 40 }}>
                  {p.progress}%
                </div>
              </div>
            </div>
            {owner && (
              <button onClick={() => onSelectAgent(owner.id)} style={{
                display: 'flex', alignItems: 'center', gap: 8,
                padding: '6px 10px', borderRadius: 8,
                background: '#fff', border: '1px solid rgba(15,23,42,0.1)',
                cursor: 'pointer', fontFamily: 'inherit',
              }}>
                <span style={{
                  width: 24, height: 24, borderRadius: 6,
                  background: `linear-gradient(135deg, ${dept.color}, ${dept.color}C0)`,
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  fontSize: 14,
                }}>{owner.avatar}</span>
                <span style={{ fontSize: 11, color: '#475569', fontWeight: 600 }}>
                  {owner.name.split(' ')[0]}
                </span>
              </button>
            )}
          </div>
        );
      })}
      {projects.length === 0 && (
        <div style={{ textAlign: 'center', color: '#94A3B8', padding: 40, fontSize: 13 }}>
          Sin proyectos registrados para este departamento.
        </div>
      )}
    </div>
  );
}

function ChatTab({ agents, dept, messages, draft, setDraft, onSend, chatScrollRef }) {
  return (
    <div style={{
      maxWidth: 800, margin: '0 auto', height: '100%',
      display: 'flex', flexDirection: 'column', minHeight: 0,
    }}>
      <div style={{
        flex: 1, overflow: 'auto',
        background: 'rgba(255, 255, 255, 0.6)',
        backdropFilter: 'blur(20px)',
        border: '1px solid rgba(255,255,255,0.8)',
        borderRadius: 14, padding: 16,
        minHeight: 300,
      }} ref={chatScrollRef}>
        {/* Online banner */}
        <div style={{
          display: 'flex', gap: 6, flexWrap: 'wrap',
          paddingBottom: 12, marginBottom: 12,
          borderBottom: '1px solid rgba(15,23,42,0.06)',
        }}>
          {agents.map(a => (
            <div key={a.id} style={{
              display: 'inline-flex', alignItems: 'center', gap: 5,
              padding: '3px 8px', borderRadius: 12,
              background: '#fff', border: '1px solid rgba(15,23,42,0.08)',
              fontSize: 11, color: '#475569', fontWeight: 500,
            }}>
              <span style={{
                width: 7, height: 7, borderRadius: '50%',
                background: a.status === 'blocked' ? '#EF4444' : a.status === 'paused' ? '#94A3B8' : '#10B981',
              }} />
              {a.avatar} {a.name.split(' ')[0]}
            </div>
          ))}
        </div>

        {messages.length === 0 && (
          <div style={{ textAlign: 'center', color: '#94A3B8', padding: 40, fontSize: 12.5 }}>
            <div style={{ fontSize: 28, marginBottom: 8 }}>{dept.icon}</div>
            Chat grupal de {dept.name}.<br/>
            Todos los agentes del departamento reciben el mensaje.
          </div>
        )}

        {messages.map(m => (
          <div key={m.id} style={{
            display: 'flex', gap: 8, marginBottom: 10,
            justifyContent: m.from === 'me' ? 'flex-end' : 'flex-start',
          }}>
            {m.from !== 'me' && (
              <div style={{
                width: 30, height: 30, borderRadius: 8,
                background: `linear-gradient(135deg, ${m.color}, ${m.color}C0)`,
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                fontSize: 16, flexShrink: 0,
              }}>{m.avatar}</div>
            )}
            <div style={{ maxWidth: '70%' }}>
              {m.from !== 'me' && (
                <div style={{ fontSize: 10.5, color: '#64748B', fontWeight: 600, marginBottom: 3, paddingLeft: 2 }}>
                  {m.name}
                </div>
              )}
              <div style={{
                padding: '8px 12px', borderRadius: 12,
                background: m.from === 'me' ? dept.color : '#fff',
                color: m.from === 'me' ? '#fff' : '#0F172A',
                fontSize: 12.5, lineHeight: 1.45,
                border: m.from === 'me' ? 'none' : '1px solid rgba(15,23,42,0.08)',
                borderBottomRightRadius: m.from === 'me' ? 4 : 12,
                borderBottomLeftRadius:  m.from === 'me' ? 12 : 4,
              }}>{m.text}</div>
            </div>
          </div>
        ))}
      </div>

      <div style={{ display: 'flex', gap: 8, marginTop: 12 }}>
        <input
          value={draft}
          onChange={e => setDraft(e.target.value)}
          onKeyDown={e => { if (e.key === 'Enter') onSend(); }}
          placeholder={`Mensaje a todo el equipo de ${dept.name}…`}
          style={{
            flex: 1, padding: '10px 14px', borderRadius: 10,
            border: '1px solid rgba(15,23,42,0.12)', fontSize: 13,
            background: '#fff', outline: 'none', fontFamily: 'inherit',
          }}
        />
        <button onClick={onSend} disabled={!draft.trim()} style={{
          padding: '10px 18px', borderRadius: 10,
          background: draft.trim() ? `linear-gradient(180deg, ${dept.color}, ${dept.color}DD)` : '#CBD5E1',
          color: '#fff', border: 'none', cursor: draft.trim() ? 'pointer' : 'not-allowed',
          fontWeight: 600, fontSize: 13,
          boxShadow: draft.trim() ? `0 2px 6px -2px ${dept.color}80` : 'none',
        }}>
          Enviar ↵
        </button>
      </div>
    </div>
  );
}

function groupReply(agent, text, projects) {
  const low = text.toLowerCase();
  if (low.includes('status') || low.includes('estado') || low.includes('?')) {
    if (projects.length > 0) {
      const p = projects[Math.floor(Math.random() * projects.length)];
      return `Estoy con "${p.name}" (${p.progress}%). ${agent.activity?.label}`;
    }
    return `Estoy en: ${agent.activity?.label}. ${agent.efficiency}% eficiencia.`;
  }
  if (low.includes('urgente') || low.includes('prior')) {
    return `Entendido, reviso ahora y priorizo.`;
  }
  const replies = [
    `👍 Recibido.`,
    `Confirmado desde ${window.DEPARTMENTS[agent.dept].name}.`,
    `Ok, ajusto y reporto.`,
    `Procesando tu mensaje.`,
    `Agendado, te aviso en 30 min.`,
  ];
  return replies[Math.floor(Math.random() * replies.length)];
}

window.DepartmentFocus = DepartmentFocus;
