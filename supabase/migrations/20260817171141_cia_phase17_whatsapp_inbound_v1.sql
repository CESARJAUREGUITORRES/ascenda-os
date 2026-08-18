-- F17 history tombstone: production 20260817171141 introduced record_inbound v1.
-- CURRENT has no consumer of that RPC. Durable inbound ingestion is superseded by
-- aos_cia_channel_ingest_inbound_v1 in 20260817183507.
-- Intentionally no-op on rebuild; version retained to preserve production migration order.
do $$ begin null; end $$;
