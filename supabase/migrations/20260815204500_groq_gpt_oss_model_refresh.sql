-- Groq model refresh required by external shutdown of Llama 3.1/3.3 developer-tier IDs on 2026-08-16.
begin;
update public.aos_agentes
set modelo = case
  when id in ('clasificador','resumidor','recepcion') then 'openai/gpt-oss-20b'
  when id in ('analista','analista_mkt','kronia','planificador') then 'openai/gpt-oss-120b'
  else modelo end
where id in ('clasificador','resumidor','recepcion','analista','analista_mkt','kronia','planificador')
  and coalesce(modelo,'') in ('llama-3.1-8b-instant','llama-3.3-70b-versatile','');
update public.aos_integraciones
set nombre='Groq (GPT-OSS)'
where lower(tipo)='groq' and nombre='Groq (Llama)';
commit;
