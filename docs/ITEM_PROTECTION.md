# Item protection

The established strict native lock remains the only shipping mode. Protection is saved per physical item GUID. Unprotect a copy before using, moving or equipping it. Foreign locks and replacement items in stale slots are never unlocked.

The separate disposal-only preview, developer pickup-check controls and their settings sections were removed at the user's request on 2026-11-14. Existing protected records and lock controls are preserved; obsolete experimental mode fields have no effect on strict lock acquisition. No saved-account files are edited by deployment.

The previous use/pickup unlock exception allowed destruction in a live test and remains removed. Selective protection research is recorded historically in CONTEXT.md; no experimental safety behavior is enabled. Ordinary strict pickup blocking was observed previously; universal vendor/trade/destruction coverage is not inferred from mocks.

Regression coverage retains exact-copy persistence, native lock readback, foreign ownership, stale slots, bank-sort compatibility, strict startup without use/pickup wrappers, preserved normal settings and absence of test/preview controls. Developer behavior checks stay in the harness.
