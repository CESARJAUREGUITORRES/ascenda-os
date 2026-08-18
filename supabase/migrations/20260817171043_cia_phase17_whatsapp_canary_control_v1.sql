-- F17 history tombstone: production 20260817171043 created aos_cia_channel_canary_control_v1.
-- CURRENT has no consumer of that RPC. Durable canary governance is superseded by
-- aos_cia_channel_register_canary_recipient_v1 in 20260817183507.
-- Intentionally no-op on rebuild; version retained to preserve production migration order.
do $$ begin null; end $$;
