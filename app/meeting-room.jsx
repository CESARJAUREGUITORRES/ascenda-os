// Meeting Room — grupo chat con múltiples agentes
const { useState: useMRState, useEffect: useMREffect, useRef: useMRRef, useMemo: useMRMemo } = React;

function MeetingRoom({ agents, onClose, onPingAgent }) {
  const [selectedAgents, setSelectedAgents] = useMRState([]);
  const [topic, setTopic] = useMRState('');
  const [started, setStarted] = useMRState(false);
  const [messages, setMessages] = useMRState([]);
  const [draft, setDraft] = useMRState('');
  const [thinking, setThinking] = useMRState([]);
  const scrollRef = useMRRef();

  useMREffect(() => {
    if (scrollRef.current) scrollRef.current.scrollTop = scrollRef.current.scrollHeight;
  }, [messages, thinking]);

  const toggleAgent = (id) => {
    setSelectedAgents(prev => prev.includes(id) ? prev.filter(x => x !== id) : [...prev, id]);
  };
  const toggleDept = (dept) => {
    const deptAgents = agents.filter(a => a.dept === dept).map(a => a.id);
    const allIn = deptAgents.every(id => selectedAgents.includes(id));
    setSelectedAgents(prev => allIn
      ? prev.filter(id => !deptAgents.includes(id))
      : [...new Set([...prev, ...deptAgents])]);
  };

  const startMeeting = () => {
    if (selectedAgents.length === 0 || !topic.trim()) return;
    setStarted(true);
    setMessages([{
      id: 'sys-' + Date.now(),
      from: 'system',
      text: `Reunión iniciada · ${selectedAgents.length} participantes · Tema: "${topic}"`,
      t: Date.now(),
    }]);
    // Each agent opens with a thought
    setTimeout(() => {
      selectedAgents.forEach((id, i) => {
        setTimeout(() => agentRespond(id, topic, true), 600 + i * 900 + Math.random() * 400);
      });
    }, 400);
  };

  const agentRespond = (agentId, prompt, isOpening = false) => {
    const a = agents.find(x => x.id === agentId);
    if (!a) return;
    setThinking(prev => [...prev, agentId]);
    onPingAgent && onPingAgent(agentId);
    setTimeout(() => {
      setThinking(prev => prev.filter(x => x !== agentId));
      setMessages(prev => [...prev, {
        id: 'm-' + Math.random().toString(36).slice(2),
        from: agentId,
        text: generateResponse(a, prompt, isOpening),
        t: Date.now(),
      }]);
    }, 1400 + Math.random() * 1800);
  };

  const sendQuestion = () => {
    if (!draft.trim()) return;
    const userMsg = {
      id: 'u-' + Date.now(),
      from: 'me',
      text: draft,
      t: Date.now(),
    };
    setMessages(prev => [...prev, userMsg]);
    const currentDraft = draft;
    setDraft('');
    // 60-80% of selected agents respond
    const responders = selectedAgents.filter(() => Math.random() > 0.25);
    responders.forEach((id, i) => {
      setTimeout(() => agentRespond(id, currentDraft), 500 + i * 1000 + Math.random() * 600);
    });
  };

  const endMeeting = () => {
    setStarted(false);
    setMessages([]);
    setSelectedAgents([]);
    setTopic('');
  };

  // ————— Setup view —————
  if (!started) {
    const deptGroups = {};
    agents.forEach(a => {
      (deptGroups[a.dept] = deptGroups[a.dept] || []).push(a);
    });

    return (
      <div className="mr-modal">
        <div className="mr-panel" style={{ width: 540, maxHeight: '85vh' }}>
          <div className="mr-header">
            <div>
              <div className="mr-title">Convocar reunión</div>
              <div className="mr-subtitle">Invita agentes y plantea un tema para discutir.</div>
            </div>
            <button className="mr-close" onClick={onClose}>×</button>
          </div>

          <div className="mr-body" style={{ overflow: 'auto', flex: 1 }}>
            <div className="mr-field">
              <label className="mr-label">Tema de la reunión</label>
              <input
                autoFocus
                className="mr-input"
                value={topic}
                onChange={e => setTopic(e.target.value)}
                placeholder="¿Cómo aumentamos la conversión del call center un 20%?"
              />
            </div>

            <div className="mr-field">
              <label className="mr-label">Participantes ({selectedAgents.length})</label>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 10, marginTop: 8 }}>
                {Object.entries(deptGroups).map(([dept, list]) => {
                  const d = window.DEPARTMENTS[dept];
                  if (!d) return null;
                  const allIn = list.every(a => selectedAgents.includes(a.id));
                  return (
                    <div key={dept}>
                      <button className="mr-dept-head" onClick={() => toggleDept(dept)} style={{ borderLeftColor: d.color }}>
                        <span style={{ color: d.color, fontWeight: 700 }}>{d.icon}</span>
                        <span style={{ flex: 1, textAlign: 'left' }}>{d.name}</span>
                        <span style={{ fontSize: 10, color: '#64748B', fontFamily: 'JetBrains Mono, monospace' }}>
                          {list.filter(a => selectedAgents.includes(a.id)).length}/{list.length}
                        </span>
                        <span style={{ fontSize: 11, color: allIn ? '#10B981' : '#94A3B8' }}>
                          {allIn ? 'Todos' : 'Añadir todos'}
                        </span>
                      </button>
                      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, marginTop: 6, paddingLeft: 2 }}>
                        {list.map(a => {
                          const on = selectedAgents.includes(a.id);
                          return (
                            <button key={a.id} className={'mr-agent-chip' + (on ? ' on' : '')}
                              onClick={() => toggleAgent(a.id)}
                              style={on ? { background: d.color + '18', borderColor: d.color, color: d.color } : {}}
                            >
                              <span style={{ fontSize: 14, lineHeight: 1 }}>{a.avatar}</span>
                              <span>{a.name.split(' ')[0]}</span>
                            </button>
                          );
                        })}
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>
          </div>

          <div className="mr-footer">
            <button className="mr-btn-ghost" onClick={onClose}>Cancelar</button>
            <button className="mr-btn-primary" onClick={startMeeting}
              disabled={selectedAgents.length === 0 || !topic.trim()}>
              Iniciar reunión · {selectedAgents.length}
            </button>
          </div>
        </div>
      </div>
    );
  }

  // ————— Active meeting —————
  return (
    <div className="mr-modal">
      <div className="mr-panel" style={{ width: 720, height: '85vh' }}>
        <div className="mr-header" style={{ borderBottom: '1px solid rgba(148,163,184,0.2)' }}>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
              <span className="live-dot" style={{ background: '#EF4444', animation: 'pulse-red 1.8s infinite' }} />
              <div className="mr-title" style={{ fontSize: 14 }}>Reunión en curso</div>
            </div>
            <div className="mr-subtitle" style={{ fontSize: 12, marginTop: 2 }}>"{topic}"</div>
          </div>
          <div style={{ display: 'flex', gap: 6 }}>
            <button className="mr-btn-ghost" onClick={endMeeting} style={{ fontSize: 11 }}>Finalizar</button>
            <button className="mr-close" onClick={onClose}>×</button>
          </div>
        </div>

        {/* Participants bar */}
        <div style={{ padding: '8px 16px', borderBottom: '1px solid rgba(148,163,184,0.15)', display: 'flex', gap: 6, flexWrap: 'wrap', flexShrink: 0 }}>
          {selectedAgents.map(id => {
            const a = agents.find(x => x.id === id);
            if (!a) return null;
            const d = window.DEPARTMENTS[a.dept];
            const isThinking = thinking.includes(id);
            return (
              <div key={id} style={{
                display: 'inline-flex', alignItems: 'center', gap: 5,
                padding: '3px 7px', background: '#F8FAFC', borderRadius: 12,
                border: `1px solid ${d.color}40`, fontSize: 11, color: '#0F172A',
              }}>
                <span style={{ fontSize: 13 }}>{a.avatar}</span>
                <span style={{ fontWeight: 500 }}>{a.name.split(' ')[0]}</span>
                {isThinking && (
                  <span style={{ color: d.color, fontSize: 10, fontStyle: 'italic' }}>escribiendo...</span>
                )}
              </div>
            );
          })}
        </div>

        {/* Messages */}
        <div ref={scrollRef} style={{ flex: 1, overflow: 'auto', padding: 16, background: '#FAFBFC' }}>
          {messages.map(m => {
            if (m.from === 'system') {
              return (
                <div key={m.id} style={{ textAlign: 'center', padding: '10px 0', fontSize: 11, color: '#64748B', fontFamily: 'JetBrains Mono, monospace' }}>
                  · {m.text} ·
                </div>
              );
            }
            if (m.from === 'me') {
              return (
                <div key={m.id} style={{ display: 'flex', justifyContent: 'flex-end', marginBottom: 12 }}>
                  <div style={{ maxWidth: '70%' }}>
                    <div style={{ fontSize: 10, color: '#64748B', textAlign: 'right', marginBottom: 2, fontFamily: 'JetBrains Mono, monospace' }}>TÚ</div>
                    <div style={{
                      background: '#0F2847', color: '#fff', padding: '10px 14px',
                      borderRadius: '16px 16px 4px 16px', fontSize: 13, lineHeight: 1.5,
                    }}>{m.text}</div>
                  </div>
                </div>
              );
            }
            const a = agents.find(x => x.id === m.from);
            if (!a) return null;
            const d = window.DEPARTMENTS[a.dept];
            return (
              <div key={m.id} style={{ display: 'flex', gap: 10, marginBottom: 14 }}>
                <div style={{
                  width: 32, height: 32, borderRadius: 8, flexShrink: 0,
                  background: `linear-gradient(135deg, ${d.color}, ${d.color}99)`,
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  fontSize: 18,
                }}>{a.avatar}</div>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ display: 'flex', alignItems: 'baseline', gap: 6, marginBottom: 3 }}>
                    <span style={{ fontSize: 13, fontWeight: 700, color: '#0F172A' }}>{a.name}</span>
                    <span style={{ fontSize: 10, color: d.color, fontWeight: 600, fontFamily: 'JetBrains Mono, monospace' }}>{d.name.toUpperCase()}</span>
                  </div>
                  <div style={{
                    background: '#fff', border: '1px solid #E2E8F0', borderLeft: `3px solid ${d.color}`,
                    padding: '10px 14px', borderRadius: 8,
                    fontSize: 13, lineHeight: 1.55, color: '#0F172A',
                  }}>{m.text}</div>
                </div>
              </div>
            );
          })}
          {thinking.length > 0 && messages[messages.length - 1]?.from === 'me' && (
            <div style={{ padding: '4px 0', fontSize: 11, color: '#64748B', fontStyle: 'italic' }}>
              {thinking.length} agente{thinking.length > 1 ? 's' : ''} pensando...
            </div>
          )}
        </div>

        <div className="mr-footer" style={{ borderTop: '1px solid rgba(148,163,184,0.2)' }}>
          <input
            className="mr-input"
            value={draft}
            onChange={e => setDraft(e.target.value)}
            onKeyDown={e => e.key === 'Enter' && sendQuestion()}
            placeholder="Pregunta al equipo..."
            style={{ flex: 1 }}
          />
          <button className="mr-btn-primary" onClick={sendQuestion} disabled={!draft.trim()}>
            Enviar
          </button>
        </div>
      </div>
    </div>
  );
}

function generateResponse(agent, prompt, isOpening) {
  const d = window.DEPARTMENTS[agent.dept];
  const low = prompt.toLowerCase();
  const templates = {
    executive: [
      `Desde estrategia: esto es prioridad si mueve ARR más de 5%. Necesito data de ${d.name} para el board.`,
      `Alineado. Propongo OKR trimestral: objetivo medible, owner único, revisión semanal.`,
      `Antes de comprometer recursos — ¿cuál es el ROI esperado? Nori, ¿puedes modelar escenarios?`,
    ],
    marketing: [
      `Puedo lanzar una campaña test en 48h con $3-5k budget. Medimos CAC y conversión por canal.`,
      `Desde mi lado: el mensaje debe enfocarse en "tiempo ahorrado", no en features. Ya probé ambos en A/B.`,
      `Tengo data de que LinkedIn performa 3× mejor que Meta para este perfil. Recomiendo ahí.`,
    ],
    finance: [
      `Cash flow lo soporta si no supera 8% del OPEX mensual. Runway actual: 14 meses — margen seguro.`,
      `Necesito ver el supuesto de ingresos. Si el payback es >9 meses no lo apruebo.`,
      `OK pero meto guardrail: si burn sube 10% en 30 días pausamos.`,
    ],
    callcenter: [
      `Con 5 agentes puedo procesar 200 llamadas/día. Script nuevo aumentó conversión 12% la semana pasada.`,
      `Detecté que 40% de los no-show son por horario. Si cambiamos slot a 6pm sube asistencia.`,
      `Llevo 3 semanas midiendo: el mejor handoff es cuando ventas llama a los 12 min post-demo.`,
    ],
    sales: [
      `Pipeline actual: $680k ponderado, 14 opps. Si cerramos 30% llegamos al target Q2.`,
      `El bloqueo principal es precio — 60% pide descuento. Propongo plan "starter" a $49/mes.`,
      `Demo-to-close subió a 28% con el nuevo deck. Puedo replicarlo en outbound.`,
    ],
    hr: [
      `Para sostener este ritmo hay que contratar 2 personas más en call center en 30 días.`,
      `El engagement cayó 4 pts este mes — relacionado a carga. Propongo bloque "focus time" protegido.`,
      `Tengo 3 perfiles pre-validados para marketing senior. Puedo hacer shortlist esta semana.`,
    ],
    scheduler: [
      `Puedo bloquear calendarios ya. Martes y jueves 10-12 son los picos de productividad.`,
      `Si agrupamos reuniones en 2 días salen 14h de focus time por persona/semana.`,
      `Detecté 12h/semana en meetings sin agenda clara. Auto-cancelo los sin objetivo?`,
    ],
    research: [
      `Según el último user research, el 73% abandona en el onboarding paso 3. Es el bloqueador #1.`,
      `Competidor X acaba de bajar precios 18%. Nuestro pricing necesita revisarse antes de Q3.`,
      `Hay 2 segments no atendidos que suman $240M TAM. Puedo armar deep-dive en 5 días.`,
    ],
    accounting: [
      `Cierre de abril al día. IVA Q1 ya presentado — $8.2k recuperables de crédito fiscal.`,
      `Detecté 2 facturas sin conciliar por $3.4k. Flagged y esperando respuesta del proveedor.`,
      `Si facturamos 3 días antes del fin de mes mejora el DSO a 28 días.`,
    ],
    legal: [
      `Antes de firmar con ese proveedor hay 3 cláusulas que debo renegociar — cláusula 7.3 es un riesgo.`,
      `GDPR compliance del nuevo feature requiere DPA actualizado. Lo tengo en draft, listo mañana.`,
      `Propongo NDA mutuo para todas las conversaciones de partnership. Template estándar, 5 min.`,
    ],
  };
  const pool = templates[agent.dept] || [`Desde ${d.name}: recibido, procesando.`];
  if (low.includes('urg') || low.includes('alert') || low.includes('rojo')) {
    return `Desde ${d.name}: ya lo estoy escalando. Priorizado en mi cola.`;
  }
  return pool[Math.floor(Math.random() * pool.length)];
}

window.MeetingRoom = MeetingRoom;
