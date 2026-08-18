-- F17 history tombstone: production 20260817171102 introduced mark_dispatch v1.
-- The function is durably replaced by final adapter 20260817183507.
-- Intentionally no-op on rebuild; version retained to preserve production migration order.
do $$ begin null; end $$;
