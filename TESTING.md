# Testing Junk Jet

## Verified in this update

Garry's Mod build **2026.05.08 (10029)**, Windows, single-player Sandbox on `gm_flatgrass`, with no Workshop addons mounted:

- All 12 default models loaded and created valid physics objects.
- All three supported entity classes created valid physics objects.
- Native sawblade launches enabled `m_bFirstCollisionAfterLaunch`, `FVPHYSICS_WAS_THROWN`, and `FVPHYSICS_DMG_SLICE` on real `prop_physics` objects.
- A 1500 units/second blade impact produced native `DMG_CRUSH | DMG_SLASH` damage, credited the launching player, and created separate zombie torso and leg gibs.
- A 1500 units/second world impact invoked native embedding, enabled the physcannon-release spawn flag, and created the engine's `point_enable_motion_fixup` release-position helper. No Lua collision callback froze or welded the blade.
- The actual tool launched the native blade with the expected creator and initial velocity.
- Immediate repeated fire was blocked, spawn veto hooks were honored, and blocked muzzle space was rejected.
- Random prop launch and timed sawblade dissolution succeeded.
- Pool editor opened in-game with all 12 defaults; its rendered layout was inspected.

The final engine smoke suite produced **52 passing checks**. Six engine-independent regression cases passed, and all Lua files passed Lua 5.1 parsing. Asset archive checks found both `.mdl` and `.phy` files for the 15 models used by the default props and supported entities.

These checks do not establish compatibility with every multiplayer server, third-party NPC, damage hook, custom physics model, or game branch. Multiplayer pool isolation/reconnect behavior, interactive editor mutations, every scale setting, and dedicated-server behavior still need the manual checks below. Native blade behavior retains the engine's speed, impact-angle, material, and first-collision conditions.

## Automated Lua checks

From the repository root, with Lua 5.1+:

```sh
lua tests/core_spec.lua
```

Alternatively install `fengari-node-cli` and run `fengari tests/core_spec.lua`. The suite covers default removal without shared-list mutation, intentional empty pools, path normalization, duplicate rejection, numeric bounds including NaN/infinities, capacity limits, and the entity allowlist.

For syntax checks, install `luaparse` and run:

```sh
node tests/parse.cjs
```

`LUAPARSE_PATH` can point to an existing installation of the package. No Node dependencies are needed by the addon at runtime.

## Opt-in engine smoke test

Use a fresh **single-player Sandbox** `gm_flatgrass` session. The test spawns props, zombies, and sawblades; it temporarily moves your player and removes its test entities afterwards. It does not edit your saved launch pool. Do not run it on a live multiplayer server.

1. Install the addon normally.
2. Copy `tests/engine_smoke.lua` to `lua/junkjet/engine_smoke.lua` inside that addon.
3. In the server console, run `lua_openscript junkjet/engine_smoke.lua` after the map has loaded.
4. Wait roughly ten seconds. Read the `JUNKJET_TEST` console lines and `garrysmod/data/junkjet_smoke_results.json`.
5. Remove the copied test script when finished. It is never autorun by the shipped addon.

The test assumes default cooldown and live limits, and enough Sandbox prop/SENT quota. It runs through real Garry's Mod APIs, not mocked collision or damage functions.

## Manual release checklist

- Fresh install: find the tool in Fun + Games and run `junkjet_diagnose`; expect no missing defaults.
- Right-click a default prop twice; verify removal then addition in the editor. Remove the last item and verify props-only mode refuses to fire. Restore defaults explicitly.
- Add mixed-case/backslash model paths, duplicates, missing models, unsupported classes, and a valid mounted custom physics model. Verify clear feedback and normalized entries.
- Search, preview, add, remove, empty, restore, and reopen the editor. Check small-window layouts and missing client content.
- Connect two clients; customize their pools independently, reconnect, and restart the server. Verify each retains their own pool and an intentionally empty pool remains empty.
- Try corrupt saved JSON with the server stopped; expect defaults. Unmount a custom model and verify launches skip it while the saved entry remains removable.
- Test sawblade-only at minimum/default/maximum speed and scale, against zombies, players, supported NextBots, thin world walls, and props. Confirm actual zombie torso/leg separation, owner credit, native embedding and gravity-gun release, and server damage protections.
- Verify scale changes physics as well as visuals, plain props use predictable speed, and spread zero is straight. Source physics may cap ordinary prop velocity independently of this tool.
- Test ignition, slippery physics, dissolution, fallback removal, Undo, Junk Jet cleanup, disconnect cleanup.
- Set `sbox_maxjunkjet` to 0, reach the live limit, deny prop/SENT spawn hooks, exhaust normal Sandbox quotas, and test a restricted entity. Confirm no untracked objects remain.
- Inspect client and server consoles for Lua errors, including during hot reload and map cleanup.

## API references

- [Server hull tracing](https://wiki.facepunch.com/gmod/util.TraceHull)
- [Entity model bounds](https://wiki.facepunch.com/gmod/Entity:GetModelBounds)
- [Model and physics scaling](https://wiki.facepunch.com/gmod/Entity:SetModelScale)
- [Sandbox spawn lifecycle](https://github.com/Facepunch/garrysmod/blob/master/garrysmod/gamemodes/sandbox/gamemode/commands.lua)

- [Native gravity-gun launch and embedding code](https://github.com/ValveSoftware/source-sdk-2013/blob/master/src/game/server/props.cpp)
- [Native zombie dismemberment conditions](https://github.com/ValveSoftware/source-sdk-2013/blob/master/src/game/server/hl2/npc_BaseZombie.cpp)
