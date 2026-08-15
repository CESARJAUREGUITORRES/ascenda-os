     or old.contact_key is distinct from new.contact_key
     or old.recipient_email is distinct from new.recipient_email
     or old.purpose is distinct from new.purpose
     or old.template_version_id is distinct from new.template_version_id
     or old.template_digest is distinct from new.template_digest
     or old.idempotency_key is distinct from new.idempotency_key
     or old.eligibility_status is distinct from new.eligibility_status
     or old.consent_status is distinct from new.consent_status
     or old.render_context is distinct from new.render_context
     or old.requested_by_user_id is distinct from new.requested_by_user_id
     or old.authorization_provenance is distinct from new.authorization_provenance
     or old.created_at is distinct from new.created_at then
    raise exception 'EMAIL_SEND_REQUEST_IDENTITY_IMMUTABLE';
  end if;

  if old.state is distinct from new.state then
    if not (
      (old.state = 'PREPARED' and new.state in ('QUEUED','CANCELLED')) or
      (old.state = 'QUEUED' and new.state in ('DISPATCHING','CANCELLED')) or
      (old.state = 'DISPATCHING' and new.state in ('ACCEPTED','FAILED','QUEUED','CANCELLED')) or
      (old.state = 'FAILED' and new.state in ('QUEUED','CANCELLED')) or
      (old.state = 'ACCEPTED' and new.state in ('DELIVERED','BOUNCED','COMPLAINED','FAILED')) or
      (old.state = 'DELIVERED' and new.state = 'COMPLAINED')
    ) then
      raise exception 'EMAIL_SEND_REQUEST_INVALID_TRANSITION:%->%', old.state, new.state;
    end if;
  end if;

  new.updated_at := now();
  if new.state in ('DELIVERED','BOUNCED','COMPLAINED','CANCELLED') and new.terminal_at is null then
    new.terminal_at := now();
  end if;
  return new;
end
$function$;

create or replace function public.aos_cia_email_prepare_request_v2(
  p_actor_user_id uuid,
  p_activation_id uuid,
  p_contact_key text,
  p_template_version_id uuid,
  p_render_context jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
