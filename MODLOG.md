# GMod Sandbox for BeamNG.drive - field note

BeamNG.drive 0.39.4.0 (Steam appid 284160). Mod type: gameplay Lua + generated vehicle props.
Single-player / offline.

## What it is
A Half-Life/GMod style sandbox on foot inside BeamNG freeroam: physgun grab/throw/explode,
a spawn menu (props ours/game, NPCs, vehicles, tools), chasing nextbots, physcannon punt,
noclip and a HUD. Ships as one mod folder / zip.

## How it works (engine facts, verified in game)
- On-foot = walk.lua's hidden unicycle body; action "toggleWalkingMode" (F).
- Physgun: per-node spring forces via veh:queueLuaCommand on the vehicle VM, mass-scaled.
- Explode: queueLuaCommand("fire.explodeVehicle()") + beamstate.breakAllBreakgroups().
- Spawn: core_vehicles.spawnNewVehicle(model, {config=...}). The game's own props do NOT follow
  <model>/<model>.pc - each needs its real config (e.g. woodcrate -> vehicles/woodcrate/large.pc).
  Our generated props do follow <model>/<model>.pc.
- Input: vehicle-scoped actions in vehicles/unicycle/input_actions_*.json + inputmaps; global
  alt-layer in settings/inputmaps/. Actions run Lua via ctx "tlua".
- UI: ui_imgui Begin/Button in the GE onUpdate.
- Mod loading: scripts/<mod>/modScript.lua calling extensions.load("core_<name>"); the extension
  lives at lua/ge/extensions/core/<name>.lua.

## Verification
Verified live through BeamNG's own in-game MCP server (run_lua / trigger_action / get_logs):
walk, grab (mass-scaled), release, explode, spawn menu, punt, nextbot, NPC chase tracking,
sandbox + game prop spawns, noclip. Static: luaparse 5.1 OK, `um publish check` PASS.

## Gotchas
- cameraMouseRayCast can return static scene geometry; calling getJBeamFilename on it throws.
  Only accept objects that expose getJBeamFilename.
- The game's MCP server is only answered from onUpdate: it is silent during the loading screen.
- Never ship Garry's Mod / Half-Life / Valve assets. Only our own CC0 art + the game's props by name.

## Licence
Code MIT; generated art CC0-1.0.
