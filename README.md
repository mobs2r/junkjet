# Junk Jet

A Garry's Mod Sandbox tool for launching a personal collection of junk. Uses base-game assets; no other games or Workshop dependencies are required.

## Install

Extract the `junkjet` folder into `GarrysMod/garrysmod/addons/`, then restart the game/server. The finished path must be `addons/junkjet/lua/weapons/gmod_tool/stools/junkjet.lua`. Remove an older loose copy of the same tool if you installed one manually, so it cannot override this version.

Choose **Tools > Fun + Games > Junk Jet**.

## Controls

- **Left click:** launch one item in the selected mode.
- **Right click:** add/remove the aimed physics prop or supported entity.
- **Reload (R):** open the pool editor, with search, model previews, content availability, and add/remove controls.
- **Undo (Z):** remove the most recent launch. **Clean up my launches** removes all your Junk Jet objects.

The tool panel provides random, props-only, entities-only, and **sawblade-only** modes. Sawblade-only deliberately bypasses your saved pool. Random mode gives each available item equal probability.

Speed `1` means 1500 Source units/second, independent of prop mass; scale `1` means original size. Spread `0` fires straight. Speed, scale, spread, and lifetime are bounded on the server, including manually entered console values. Old saved slider values above the new range are clamped; use **Reset launch settings** to get the new defaults.

Fire and slippery modes are optional. Dissolve is enabled by default after 10 seconds, with a removal fallback for entities that cannot dissolve. The slippery setting applies to ordinary physics projectiles; sawblade launches retain their native blade physics.

## A real saved pool

Every player starts with their own copy of the default props. Removing a default prop works immediately. **Empty pool** really empties it; **Restore default props** is a separate action. No entity pickups or weapons are mixed into the default pool.

Pools persist on that server across reconnects and restarts in `garrysmod/data/junkjet/<SteamID64>.json`. They do not automatically transfer to other servers. Missing custom models remain saved, but are skipped when firing; the server is authoritative even if a client's availability column differs. Invalid saved JSON falls back to defaults. Each prop/entity list supports up to 128 unique items.

Supported entity classes are `sent_ball`, `item_healthkit`, and `item_battery`. Arbitrary classes and weapons are deliberately excluded because many cannot be safely created and launched as physics objects. Custom **physics prop models** remain supported. Player, NPC, and NextBot scanning is rejected.

## Sawblade behavior

Sawblade-only mode launches the actual sawblade model as a native `prop_physics`. The addon enables the same first-impact state and physics flags used for a gravity-gun launch, and applies spin around the blade's proper axis.

The Source engine handles sharp-prop collision damage, material/angle-dependent embedding, and releasing an embedded blade with the gravity gun. Blade flight and embedding use no scripted movement controller, weld, or freeze-on-contact callback.

By default, **75% of qualifying first lethal body cuts leave a living classic-zombie torso** when the headcrab is intact. The original NPC changes to its native torso state, keeps its AI/relationships and headcrab, drops its legs, and receives half its original maximum health. Head-level impacts, headless zombies, existing crawlers, and unrelated props/NPC classes do not get this survival treatment. A brief grace for repeat contact with that same blade prevents one collision from instantly killing its new crawler; other attacks still work. Server damage vetoes remain effective. This is an intentional first-cut survival adjustment on top of native blade physics.

Set `junkjet_crawlerchance` from 0 to 100 to control survival; 0 restores fully native lethal cutting. This applies to standard `npc_zombie` models, not third-party zombie implementations.

Native behavior has native conditions: slow impacts, glancing hits, metal/grate surfaces, and impacts after the initial collision can bounce rather than embed. Damage depends on physics and server rules. Gravity, drag, and the server's VPhysics velocity limits still apply. Default speed is chosen above the native embedding threshold. These are the engine's rules, not a guarantee that every shot cuts or sticks.

See `TESTING.md` for actual zombie torso/leg separation and native embedding checks.

## Default props

Watermelon, traffic cone, sawblade, wooden chair, oil drum, wooden crate, metal bucket, metal can, milk carton, plastic bottle, radiator, and radio receiver. The list uses Half-Life 2 assets bundled with Garry's Mod. Each model is validated as a physics prop on the server before it enters a fresh default pool and again before launch. Optional-content models, the incorrect explosive-barrel path, and default weapon pickups were removed.

Run **Audit default models** (`junkjet_diagnose`) for the actual mounted-content verdict on your server.

## Console commands

| Command | Action |
| --- | --- |
| `junkjet_menu` | Open the pool editor |
| `junkjet_addprop <model>` | Validate and add a physics model |
| `junkjet_removeprop <model>` | Remove a model, including defaults or missing content |
| `junkjet_addentity <class>` | Add a supported entity |
| `junkjet_removeentity <class>` | Remove an entity |
| `junkjet_clearitems` | Save empty prop and entity lists |
| `junkjet_resetitems` | Restore available default props |
| `junkjet_listitems` | Print the pool to the console |
| `junkjet_cleanup` | Remove your live launches |
| `junkjet_diagnose` | Audit default models |

## Server controls

| ConVar | Default | Allowed range / purpose |
| --- | --- | --- |
| `sbox_maxjunkjet` | 40 | 0-200 live objects per player; 0 disables launching |
| `junkjet_cooldown` | 0.2 | 0.1-5 seconds between launches |
| `junkjet_crawlerchance` | 75 | 0-100 percent chance of surviving a qualifying first body cut |


Normal Sandbox prop/SENT limits, spawn permission hooks, entity admin restrictions, and spawned-object hooks are respected. Each launch has creator attribution, undo, and a dedicated cleanup category. Objects are removed when their owner disconnects. Blocked muzzle space and unusable physics produce feedback instead of invisible or stuck launches.

## Development

Runtime files live under `lua/`; no build step is needed. See `TESTING.md` for Lua regression tests and opt-in engine tests. Changes and compatibility notes are in `CHANGELOG.md`.
