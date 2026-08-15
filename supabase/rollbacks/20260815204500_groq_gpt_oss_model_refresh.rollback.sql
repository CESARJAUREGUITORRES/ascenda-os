-- Fail-safe degradation: never restore externally retired Llama model IDs.
-- If GPT-OSS 120B must be rolled back operationally, degrade reasoning agents to GPT-OSS 20B.
begin;
update public.aos_agentes
set modelo='openai/gpt-oss-20b'
where id in ('analista','analista_mkt','kronia','planificador')
  and modelo='openai/gpt-oss-120b';
update public.aos_integraciones
set nombre='Groq (GPT-OSS fallback)'
where lower(tipo)='groq' and nombre='Groq (GPT-OSS)';
commit;
