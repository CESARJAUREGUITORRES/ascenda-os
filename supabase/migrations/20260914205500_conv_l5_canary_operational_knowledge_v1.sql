-- ASCENDA OS · CONV-L5 controlled canary continuity hardening
-- Adds governed PUBLIC_CLIENT knowledge for routine operational questions that
-- must stay inside the automated commercial flow instead of escalating to
-- HUMAN_COMMERCIAL solely because static knowledge retrieval is sparse.
-- No autonomy flags, provider settings, booking writes, or routing controls change.

begin;

insert into public.aos_knowledge_nodes_v1(
  code,node_type,parent_code,title,aliases,public_client,advisor_internal,owner_admin,
  clinical_restricted,system_reference,keywords,risk_level,source_code,source_locator,
  status,version,approved_at,updated_at
) values (
  'OP_PROFESSIONAL_ASSIGNMENT_DYNAMIC',
  'OPERATIONAL_POLICY',
  null,
  'Profesional que atiende según agenda',
  '["quien es la doctora que atiende","quién es la doctora que atiende","y quien es la doctora que atiende","y quién es la doctora que atiende","que doctora atiende","qué doctora atiende","quien atiende","quién atiende","que profesional atiende","qué profesional atiende"]'::jsonb,
  'La profesional que atiende depende de la sede, la fecha y la disponibilidad real de agenda. No se debe prometer ni asignar una doctora sin revisar el turno disponible. Si me indicas la sede y el día que prefieres, puedo revisar las opciones.',
  'Ante preguntas por la doctora o profesional exacta, no inventar nombres ni derivar por defecto. Mantener la conversación comercial y pedir sede + día/fecha para consultar disponibilidad real en Agenda/Booking Core. Solo escalar si la agenda no puede resolverlo o si la pregunta exige criterio clínico.',
  'Canary L5: continuidad comercial gobernada. La identidad del profesional se obtiene únicamente desde disponibilidad real; este nodo nunca autoriza a inventar nombres.',
  null,
  '{"authority":"BOOKING_CORE_REQUIRED_FOR_EXACT_PROFESSIONAL","canary_hardening":"CONV-L5-20260914"}'::jsonb,
  array['doctora','doctor','profesional','quien atiende','quién atiende','agenda','sede','disponibilidad'],
  'LOW',
  'CONV_L5_CANARY_OWNER_FEEDBACK_20260914',
  'human-canary: routine professional question must continue toward governed availability',
  'APPROVED',
  1,
  now(),
  now()
)
on conflict (code) do update set
  node_type=excluded.node_type,
  title=excluded.title,
  aliases=excluded.aliases,
  public_client=excluded.public_client,
  advisor_internal=excluded.advisor_internal,
  owner_admin=excluded.owner_admin,
  system_reference=excluded.system_reference,
  keywords=excluded.keywords,
  risk_level=excluded.risk_level,
  source_code=excluded.source_code,
  source_locator=excluded.source_locator,
  status='APPROVED',
  version=public.aos_knowledge_nodes_v1.version+1,
  approved_at=now(),
  updated_at=now();

insert into public.aos_knowledge_nodes_v1(
  code,node_type,parent_code,title,aliases,public_client,advisor_internal,owner_admin,
  clinical_restricted,system_reference,keywords,risk_level,source_code,source_locator,
  status,version,approved_at,updated_at
) values (
  'OP_REALTIME_AVAILABILITY_DYNAMIC',
  'OPERATIONAL_POLICY',
  null,
  'Turnos y disponibilidad en tiempo real',
  '["que dias tienes turnos","qué días tienes turnos","o que dias tienes turnos","o qué días tienes turnos","que dias hay turnos","qué días hay turnos","hay turnos","que disponibilidad tienes","qué disponibilidad tienes"]'::jsonb,
  'Los turnos cambian en tiempo real y se revisan directamente en la agenda antes de ofrecer un horario. Si me dices la sede y el día o fecha aproximada que prefieres, puedo revisar las opciones disponibles.',
  'Las preguntas de turnos o disponibilidad son flujo de booking, no HUMAN_COMMERCIAL por defecto. Pedir solo los datos faltantes (sede y fecha/día) y consultar Booking Core; nunca inventar disponibilidad.',
  'Canary L5: disponibilidad siempre gobernada por Booking Core. Este nodo solo explica el proceso y conserva continuidad conversacional.',
  null,
  '{"authority":"BOOKING_CORE","canary_hardening":"CONV-L5-20260914"}'::jsonb,
  array['turnos','disponibilidad','agenda','horarios','dias','días','sede','booking'],
  'LOW',
  'CONV_L5_CANARY_OWNER_FEEDBACK_20260914',
  'human-canary: routine availability question must continue into Booking Core',
  'APPROVED',
  1,
  now(),
  now()
)
on conflict (code) do update set
  node_type=excluded.node_type,
  title=excluded.title,
  aliases=excluded.aliases,
  public_client=excluded.public_client,
  advisor_internal=excluded.advisor_internal,
  owner_admin=excluded.owner_admin,
  system_reference=excluded.system_reference,
  keywords=excluded.keywords,
  risk_level=excluded.risk_level,
  source_code=excluded.source_code,
  source_locator=excluded.source_locator,
  status='APPROVED',
  version=public.aos_knowledge_nodes_v1.version+1,
  approved_at=now(),
  updated_at=now();

commit;