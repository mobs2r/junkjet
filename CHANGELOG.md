# Quality-of-life update

- Correct the addon layout so a repository checkout is loadable.
- Enable native gravity-gun launch state on real sawblade physics props: proper spin axis, sharp-prop damage, zombie dismemberment, and the engine's embedding/release interaction. Add direct sawblade-only selection.
- First lethal body cuts usually leave a living classic-zombie torso with an intact headcrab (75% by default). Preserve the original NPC, AI, relationships and cleanup tracking; head hits and later crawler hits remain lethal. Configure with `junkjet_crawlerchance`.
- Curate and validate 12 base-game physics props. Remove optional-content paths and random default weapon/entity pickups.
- Fix personal default removal, empty-pool behavior, duplicate handling, input normalization, and player isolation.
- Persist versioned personal pools on the server; sanitize malformed content and retain missing custom models for future mounts.
- Add searchable pool editor, model preview, availability status, explicit restore defaults, cleanup, and diagnostics.
- Add launch modes, optional spread, direct velocity, true scale multipliers, useful slider ranges, and settings reset.
- Add muzzle clearance checks, creation/physics checks, rate limits, per-player live limits, Sandbox spawn hooks, admin restrictions, undo, cleanup, and disconnect removal.
- Replace nonexistent base `Entity:Dissolve()` calls with engine dissolution and a removal fallback.
- Add regression coverage and an opt-in native-engine smoke test.

## Compatibility changes

`junkjet_clearitems` now means empty, not restore defaults; use `junkjet_resetitems` to restore. Empty entity lists stay empty. Saved launch speed/scale values use new multiplier semantics and are server-clamped. Random mode samples items uniformly. Only the three documented entity classes are accepted; physics model scanning remains extensible. Sawblade collision behavior belongs to the native engine, including its impact-speed, angle, surface, and first-collision conditions.
