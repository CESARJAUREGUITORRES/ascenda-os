-- WA-7A.0 phone conversation-key compatibility
-- Preserve the certified WA-2 key shape for PHONE conversations while BSUID
-- conversations use their explicit typed namespace.

begin;

create or replace function public.aos_wa7a0_conversation_address_compat_v1()
returns trigger
language plpgsql
set search_path=public,pg_temp
as $$
declare v_phone text; v_scope text;
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
    if v_phone is not null and char_length(v_phone) between 8 and 20 then
      new.contact_number:=v_phone;
      new.contact_address:=v_phone;
    end if;
  end if;

  -- WA-2 certified PHONE key is `<phone_number_id>:<digits>`.
  -- Only rewrite the new WA-7A.0 typed candidate; never rewrite arbitrary
  -- conversation keys created by controlled WA-3/WA-4 fixtures or tools.
  if new.contact_address_type='PHONE' and new.contact_address is not null then
    v_scope:=coalesce(nullif(trim(new.phone_number_id),''),'default');
    if new.conversation_key=v_scope||':PHONE:'||new.contact_address then
      new.conversation_key:=v_scope||':'||new.contact_address;
    end if;
  end if;
  return new;
end
$$;

revoke all on function public.aos_wa7a0_conversation_address_compat_v1() from public,anon,authenticated;

commit;
