begin;

-- CIA A3 canary fix: keep fast catalog membership aligned with the
-- Acquisition preset count cache and the generic acquisition resolver.

create or replace function public.aos_cia_workspace_catalog_members_v1(
  p_preset_key text
)
returns setof public.aos_cia_contact_runtime_cache_v1
language sql
stable
security definer
set search_path to ''
as $function$
  select c.*
  from public.aos_cia_contact_runtime_cache_v1 c
  where case upper(coalesce(p_preset_key,''))
    when 'ATTENDED_APPOINTMENT' then coalesce(c.attended_count,0)>0
    when 'EVER_NO_SHOW' then coalesce(c.ever_no_show,false)
    when 'HAS_FUTURE_APPOINTMENT' then coalesce(c.has_future_appointment,false)
    when 'NEVER_APPOINTED' then coalesce(c.appointments_never_had,false)
    when 'NO_SHOW_NO_FUTURE' then coalesce(c.ever_no_show,false) and not coalesce(c.has_future_appointment,false)
    when 'CALL_STALE_30D' then coalesce(c.days_since_last_call,0)>30
    when 'CALL_STALE_7D' then coalesce(c.days_since_last_call,0)>7
    when 'CALLED_NO_EFFECTIVE_CONTACT' then coalesce(c.call_count,0)>0 and coalesce(c.effective_contact_count,0)=0
    when 'CALLED_TODAY' then coalesce(c.called_today,false)
    when 'EFFECTIVE_CONTACTS' then coalesce(c.effective_contact_count,0)>0
    when 'NEVER_CALLED_CONTACTS' then coalesce(c.calls_never_called,false)
    when 'IDENTITY_CONFLICT' then coalesce(c.identity_conflict,false)
    when 'PATIENTS' then coalesce(c.exists_as_patient,false)
    when 'AGE_18_24' then c.age_band='18_24'
    when 'AGE_25_34' then c.age_band='25_34'
    when 'AGE_35_44' then c.age_band='35_44'
    when 'AGE_45_54' then c.age_band='45_54'
    when 'AGE_55_64' then c.age_band='55_64'
    when 'AGE_65_PLUS' then c.age_band='65_PLUS'
    when 'SEX_FEMALE' then c.sex='F'
    when 'SEX_MALE' then c.sex='M'
    when 'EMAIL_BOUNCED' then coalesce(c.email_bounced_count,0)>0
    when 'EMAIL_CLICKED' then coalesce(c.email_clicked_count,0)>0
    when 'EMAIL_OPENED' then coalesce(c.email_opened_count,0)>0
    when 'EMAIL_VALID' then coalesce(c.email_valid,false)
    when 'NEVER_EMAILED_KNOWN' then coalesce(c.email_never_sent,false)
    when 'FOLLOWUP_OVERDUE' then coalesce(c.overdue_followup_count,0)>0
    when 'PENDING_FOLLOWUPS' then coalesce(c.pending_followup_count,0)>0
    when 'ALL_LEADS' then coalesce(c.exists_as_lead,false)
    when 'LEAD_PRODUCT_INTEREST' then c.latest_interest_type='PRODUCTO'
    when 'LEAD_SERVICE_INTEREST' then c.latest_interest_type='SERVICIO'
    when 'LEADS_UNWORKED' then coalesce(c.lead_unworked_since_latest_entry,false)
    when 'LEADS_UNWORKED_7D' then coalesce(c.lead_unworked_since_latest_entry,false) and coalesce(c.days_since_last_lead,999999)<=7
    when 'DORMANT_BUYERS_90D' then coalesce(c.days_since_last_sale,0)>90
    when 'NEVER_BOUGHT' then coalesce(c.sales_never_bought,false)
    when 'PRODUCT_BUYERS' then coalesce(c.traits,'{}'::text[]) @> array['PRODUCT_BUYER']::text[]
    when 'RECENT_BUYERS_30D' then coalesce(c.days_since_last_sale,999999)<=30
    when 'SERVICE_BUYERS' then coalesce(c.traits,'{}'::text[]) @> array['SERVICE_BUYER']::text[]
    when 'ACTIVE_CUSTOMERS' then c.lifecycle='ACTIVE_CUSTOMER'
    when 'ACTIVE_PROSPECTS' then c.lifecycle in ('ACTIVE_PROSPECT','APPOINTMENT_READY_PROSPECT')
    when 'COLD_PROSPECTS' then c.lifecycle='COLD_PROSPECT'
    when 'DIAMOND_CUSTOMERS' then c.value_tier='DIAMANTE'
    when 'GOLD_CUSTOMERS' then c.value_tier='GOLD'
    when 'HIGH_VALUE_COOLING' then c.value_tier in ('GOLD','DIAMANTE') and c.lifecycle in ('COOLING_CUSTOMER','INACTIVE_CUSTOMER')
    when 'INACTIVE_CUSTOMERS' then c.lifecycle='INACTIVE_CUSTOMER'
    when 'NEW_CUSTOMERS' then c.lifecycle='NEW_CUSTOMER'
    when 'WARM_PROSPECTS' then c.lifecycle='WARM_PROSPECT'
    when 'WEB_BOOKINGS' then coalesce(c.web_booking_count,0)>0
    when 'WEB_BOOKINGS_FUTURE' then coalesce(c.web_booking_count,0)>0 and coalesce(c.has_future_appointment,false)
    when 'WEB_BOOKINGS_NO_PURCHASE' then coalesce(c.web_booking_count,0)>0 and coalesce(c.sales_never_bought,false)
    else false
  end
$function$;

select pg_notify('pgrst','reload schema');

commit;
