# F16 Live Provider Canary — 2026-08-15

Temporary production certification scope only.

- Fixed Resend simulator recipient only: `delivered+ascenda-f16-20260815@resend.dev`.
- Provider credential remains environment-only in Railway.
- Signed webhook is verified by existing F16 Svix boundary before temporary evidence capture.
- Exact captured signed request is replayed byte-for-byte only within the existing 5-minute verification window.
- Temporary evidence table is service-role only and contains provider/webhook evidence, no patient/customer identifiers.
- Temporary routes/module/table/workflow are removed immediately after readiness certification.
- Certification run 31912759493 on exact head d0c6e3e0e35c8aa4c66e7caf55952f8938729343: FAST runtime PASS, FAST fixed-recipient security PASS, Zero-Cost DB/RLS/rollback PASS.
