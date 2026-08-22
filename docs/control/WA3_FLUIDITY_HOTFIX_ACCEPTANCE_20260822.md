# WA-3 Fluidity Hotfix Acceptance

Acceptance target:
- ownership loss must never be rendered as a fake 2FA/session failure;
- release/reassign must keep the user inside WhatsApp Hub and refresh to the currently visible inbox;
- admin presence should reflect advisor status within approximately 5 seconds under normal connectivity;
- successful sends should rely on timeline/status updates, not provider-ID toast noise;
- security failures remain explicit and fail-closed.
