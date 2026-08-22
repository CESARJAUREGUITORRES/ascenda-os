# Loop 6 V2 exact-head validation trigger

PR #337 integrates the credit/ownership V2 policy into the existing `app/public/calls-loop6.js` runtime; the temporary companion loader is no longer part of the final diff. This control-only commit exists to force all pull-request validation workflows to run against the final integrated runtime head after the deterministic loader patch completed.

Loop 6 remains NOT CERTIFIED and Loop 7 remains NOT STARTED until the expanded canary matrix, exact-head CI, Railway deploy, genuine-operation gate and downstream invariants pass.
