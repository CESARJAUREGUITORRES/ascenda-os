# Marketing Web Booking Lineage V1

Status: implementation candidate for production.

## Authority
- `aos_agenda_citas` remains the canonical booking ledger.
- Direct landing bookings are **not** duplicated into `aos_leads`.
- `aos_landing_booking_attribution` is append-only acquisition lineage.
- Marketing reads are admin + 2FA only through `/api/marketing/rpc`.

## Landing registry
Each landing is registered once in `aos_landing_registry` with an opaque token and canonical mapping:

`landing -> platform -> campaign -> ad -> treatment -> optional advisor booking token`

The browser may send UTMs as evidence, but the registry is the canonical attribution source.

## Public booking RPC
RPC: `aos_agendar_publica_landing_v1`

Required:
- `p_landing_token`
- `p_idempotency_key` (UUID recommended)
- `p_nombre`
- `p_apellido`
- `p_telefono`
- `p_treatment_id`
- `p_fecha`
- `p_hora`
- `p_sede`

Optional:
- `p_profesional_id`
- `p_dni`
- `p_email`
- `p_nota`
- `p_tipo_cita`
- `p_utm_source`
- `p_utm_medium`
- `p_utm_campaign`
- `p_utm_content`
- `p_utm_term`
- `p_referrer_url`
- `p_client_event_id`

The RPC resolves the landing token, calls the certified `aos_agendar_publica_v2`, then snapshots attribution against the returned `agenda_id`. The existing availability, patient, calendar, notification and booking authority are preserved.

### Example payload
```json
{
  "p_landing_token": "<opaque token from Ascenda>",
  "p_idempotency_key": "4f7f038d-bcec-4b98-aaf1-2d37f16c0d72",
  "p_nombre": "MARIA",
  "p_apellido": "PEREZ",
  "p_telefono": "999999999",
  "p_treatment_id": "00000000-0000-0000-0000-000000000000",
  "p_fecha": "2026-10-03",
  "p_hora": "16:30",
  "p_sede": "SAN ISIDRO",
  "p_utm_source": "meta",
  "p_utm_medium": "paid_social",
  "p_utm_campaign": "hifu_sep",
  "p_utm_content": "reel_03",
  "p_referrer_url": "https://example.com/hifu"
}
```

## Read model
Admin RPC: `aos_marketing_web_bookings_admin_v1(p_token,p_desde,p_hasta,p_filters)`.

It returns:
- reservations;
- contacted;
- attended;
- customers;
- sales;
- revenue;
- detailed spend when available;
- cost per reservation;
- CAC;
- ROAS;
- dimensions for platform/campaign/ad/landing filters;
- row-level lineage from landing through calls and sales.

Commercial state precedence:
1. `VENDIDO`
2. `ASISTIO`
3. `NO ASISTIO`
4. `CANCELADA`
5. `CONTACTADO`
6. `SIN CONTACTO`
7. `REAGENDADA`
8. `AGENDADO`

Repeated landing bookings for the same phone are bounded by the next landing booking timestamp so calls and sales are not credited to every historical booking.

## Spend lineage
`aos_marketing_spend_items` stores granular spend at:

`year/month + platform + campaign + ad + optional landing`

CAC/ROAS in the Citas Web modal are shown only when granular spend exists. The system deliberately does not invent campaign/ad costs from the broader treatment-level `aos_inversion_campanas` ledger.

## Marketing UI
Asset: `app/public/admin-marketing-web-bookings.js`.

The Marketing header adds `🌐 Citas Web` next to `Ver Leads`. The modal provides range, platform, campaign, ad, landing, status and search filters; KPI strip; operational table; and CSV export.

## Safety invariants
- no insert into `aos_leads`;
- no second booking backend;
- no duplicate Google/email/notification dispatch;
- opaque landing tokens;
- idempotency lock + replay;
- append-only attribution ledger;
- RLS enabled on new internal tables;
- no direct browser read of internal lineage tables;
- no polling owner or recurring timer added.
