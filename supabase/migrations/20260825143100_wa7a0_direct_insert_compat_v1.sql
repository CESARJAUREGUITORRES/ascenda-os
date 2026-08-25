-- WA-7A.0 direct conversation insert compatibility.
-- Existing WA-3/WA-4 controlled code and tests may create phone conversations directly.
-- Populate the generic address automatically without changing their caller contract.

begin;

create or replace function public.aos_wa7a0_conversation_address_compat_v1()
returns trigger
language plpgsql
set search_path=public,pg_temp
as $$
declare v_phone text;
begin
  if new.contact_address is null and new.contact_number is not null then
    v_phone:=nullif(regexp_replace(new.contact_number,'[^0-9]','','g'),'');
    if v_phone is not null and char_length(v_phone) between 8 and 20 then
      new.contact_number:=v_phone;
      new.contact_address:=v_phone;
      new.contact_address_type:='PHONE';
    end if;
  end if;
  if new.contact_address_type='PHONE' and new.contact_number is null and new.contact_address is not null then
    v_phone:=nullif(regexp_replace(new.contact_address,'[^0-9]','','g'),'');
    if v_phone is not null and char_length(v_phone) between 8 and 20 then new.contact_number:=v_phone;new.contact_address:=v_phone; end if;
  end if;
  return new;
end
$$;

drop trigger if exists trg_aos_wa7a0_conversation_address_compat_v1 on public.aos_wa_conversations_v1;
create trigger trg_aos_wa7a0_conversation_address_compat_v1
before insert or update of contact_number,contact_address,contact_address_type on public.aos_wa_conversations_v1
for each row execute function public.aos_wa7a0_conversation_address_compat_v1();

revoke all on function public.aos_wa7a0_conversation_address_compat_v1() from public,anon,authenticated;

commit;
