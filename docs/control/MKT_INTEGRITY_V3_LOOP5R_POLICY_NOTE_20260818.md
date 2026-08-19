# Historical inferred-call policy — frozen for MKT-INTEGRITY-HOTFIX-V3

A legacy/imported sale + attended/effective Agenda does not, by itself, prove an observed call.

One historical call unit may be reconstructed only when:

- a Marketing lead predates first conversion;
- no call exists through that first conversion;
- no prior sale or attended/effective conversion predates the selected lead;
- the selected lead is the nearest valid prior Marketing touchpoint;
- the conversion Agenda identifies the advisor.

The reconstructed row must use `tipo_gestion=INFERIDA_HISTORICA`, `estado=CITA CONFIRMADA`, direct Marketing lead linkage, lead date as an explicit proxy date, `00:00:00` as a sentinel/proxy time, and an observation stating that real call time is unavailable.

Rows without a prior Marketing lead remain historical/legacy patient conversions and do not receive a synthetic Marketing call.

Observed call evidence always overrides inferred reconstruction.
