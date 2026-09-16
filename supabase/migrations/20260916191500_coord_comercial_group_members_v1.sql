begin;

-- Keep Coordination channel membership and task-group membership aligned.
update public.aos_canales
set participantes=jsonb_build_array('ADMIN','CESAR','SRA CARMEN','MIREYA','RODRIGO','RUVILA','WILMER'),
    updated_at=now()
where id='CH-GRP-COMERCIAL';

update public.aos_grupos
set miembros=jsonb_build_array('CESAR','SRA CARMEN','MIREYA','RODRIGO','RUVILA','WILMER')
where id='GRP-COMERCIAL' and activo=true;

commit;