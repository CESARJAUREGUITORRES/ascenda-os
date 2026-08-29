#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SB_DIR="$ROOT/ci/wa4c-full-local"
DB_URL="postgresql://postgres:postgres@127.0.0.1:60202/postgres"

psqlf(){ psql "$DB_URL" -X -v ON_ERROR_STOP=1 -f "$ROOT/$1"; }

cd "$SB_DIR"
supabase stop --no-backup >/dev/null 2>&1 || true
docker ps -aq --filter 'name=ascenda-wa4c-full-local' | xargs -r docker rm -f >/dev/null 2>&1 || true
rm -rf supabase/.temp supabase/.branches

supabase start
for _ in $(seq 1 60); do
  if pg_isready -h 127.0.0.1 -p 60202 -U postgres >/dev/null 2>&1 && curl -fsS http://127.0.0.1:60201/rest/v1/ >/dev/null 2>&1; then
    break
  fi
  sleep 1
done
pg_isready -h 127.0.0.1 -p 60202 -U postgres >/dev/null

supabase status -o env > /tmp/ascenda-wa4c-full-local.env
set -a
# shellcheck disable=SC1091
source /tmp/ascenda-wa4c-full-local.env
set +a
LOCAL_ANON_KEY="${ANON_KEY:-${PUBLISHABLE_KEY:-}}"
LOCAL_SERVICE_ROLE_KEY="${SERVICE_ROLE_KEY:-${SECRET_KEY:-}}"
test -n "$LOCAL_ANON_KEY"
test -n "$LOCAL_SERVICE_ROLE_KEY"

cd "$ROOT"

# WA canonical runtime substrate + deterministic synthetic Auth/2FA resolver.
psqlf ci/wa3-boxes-routing-handoff/schema_contract.sql
psqlf supabase/migrations/20260815160000_wa1_secure_gateway_v1.sql
psqlf supabase/migrations/20260815175500_wa2_conversation_live_inbox_v1.sql
psqlf supabase/migrations/20260815190500_wa3_boxes_routing_handoff_v1.sql
psqlf supabase/migrations/20260822173000_wa3_multiagent_readiness_v2.sql
psqlf supabase/migrations/20260815203000_wa4_ai_sales_router_v1.sql

# Provider/model registry and service-only secret boundary.
psqlf ci/wa4c-full-local/provider_fixture.sql
psqlf supabase/migrations/20260815204500_groq_gpt_oss_model_refresh.sql
psqlf supabase/migrations/20260815205000_integration_secret_boundary_v1.sql
psqlf supabase/migrations/20260829101000_wa4c_sales_playbook_audit_task_v1.sql

# Reconstruct the certified SEP26 CURRENT catalog shape in isolated TEST.
psqlf ci/wa4a-knowledge-fabric/source_contract.sql
psqlf ci/catalog-sep2026/current_fixture.sql
psqlf supabase/migrations/20260828140500_catalog_sep2026_reconciliation_foundation_v1.sql
psqlf supabase/migrations/20260828140510_catalog_sep2026_services_slice_1_v1.sql
psqlf supabase/migrations/20260828140520_catalog_sep2026_services_slice_2_v1.sql
psqlf supabase/migrations/20260828140530_catalog_sep2026_services_slice_3_v1.sql
psqlf supabase/migrations/20260828140540_catalog_sep2026_services_slice_4_v1.sql
psqlf supabase/migrations/20260828140550_catalog_sep2026_services_slice_5_v1.sql
psqlf supabase/migrations/20260828140560_catalog_sep2026_services_slice_6_v1.sql
psqlf supabase/migrations/20260828140590_catalog_sep2026_finalize_v1.sql

# Governed knowledge + commercial graph + process/price authority + V3 included benefits.
psqlf supabase/migrations/20260827185000_wa4a_knowledge_fabric_v1.sql
psqlf supabase/migrations/20260828001500_wa4a1_zivital_governed_knowledge_v1.sql
psqlf supabase/migrations/20260828014500_wa4a1b_zivital_commercial_knowledge_graph_v1.sql
psqlf supabase/migrations/20260828014600_wa4a1b_prephase_and_mapping_hardening_v1.sql
psqlf supabase/migrations/20260828014700_wa4a1b_explicit_exception_mapping_v1.sql
psqlf supabase/migrations/20260828014800_wa4a1b_product_composition_semantics_v1.sql
psqlf supabase/migrations/20260828014900_wa4a1b_relation_reconciliation_v1.sql
psqlf supabase/migrations/20260828015000_wa4a1b_domain_code_reconciliation_v1.sql
psqlf supabase/data_patches/20260828_wa4a1b_vitaminas_detox_commercial_enrichment.sql
psqlf supabase/data_patches/20260828_wa4a1b_internal_product_completion.sql
psqlf supabase/data_patches/20260828_wa4a1b_prunex_knowledge_hardening.sql
psqlf supabase/migrations/20260828033500_wa4a1c_treatment_pricing_architecture_v1.sql
psqlf supabase/migrations/20260828142000_wa4a1c_multicurrency_hardening_v1.sql
psqlf supabase/migrations/20260828235500_wa4c_included_benefit_knowledge_v3.sql
psqlf ci/wa4c-full-local/seed.sql

psql "$DB_URL" -X -v ON_ERROR_STOP=1 -c "notify pgrst, 'reload schema';"
sleep 2

# Exact local-data readiness assertions.
test "$(psql "$DB_URL" -X -qAt -c "select count(*) from public.aos_catalogo_servicios where tipo='SERVICIO' and estado='ACTIVO'")" = "184"
test "$(psql "$DB_URL" -X -qAt -c "select count(*) from public.aos_catalogo_servicios where tipo='PRODUCTO' and estado='ACTIVO'")" = "50"
test "$(psql "$DB_URL" -X -qAt -c "select count(*) from public.aos_wa4_process_entity_context_v1 where ready_for_quote is true and freshness_state<>'STALE_REVIEW'")" = "234"
test "$(psql "$DB_URL" -X -qAt -c "select count(*) from public.aos_promociones")" = "0"
test "$(psql "$DB_URL" -X -qAt -c "select copilot_enabled and not auto_reply_enabled from public.aos_wa_ai_control_v1 where id=1")" = "t"
test "$(psql "$DB_URL" -X -qAt -c "select human_send_enabled and not ai_send_enabled and not auto_routing_enabled from public.aos_wa_routing_control_v1 where id=1")" = "t"

echo "SUPABASE_URL=http://127.0.0.1:60201" >> "${GITHUB_ENV:-/tmp/ascenda-wa4c-env}"
echo "SUPABASE_ANON_KEY=$LOCAL_ANON_KEY" >> "${GITHUB_ENV:-/tmp/ascenda-wa4c-env}"
echo "SUPABASE_SERVICE_ROLE_KEY=$LOCAL_SERVICE_ROLE_KEY" >> "${GITHUB_ENV:-/tmp/ascenda-wa4c-env}"
echo "WA4C_LOCAL_DB_URL=$DB_URL" >> "${GITHUB_ENV:-/tmp/ascenda-wa4c-env}"

echo 'WA4C_FULL_LOCAL_BOOTSTRAP_PASS'
