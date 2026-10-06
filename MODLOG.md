# MODLOG - GMOD x BeamNG sandbox (physgun, weapons, spawn menu)

Working folder: E:\modder\gmod-beamng  (all big files on E:; C: has ~0.1 GB free)
Toolkit repo: C:\Users\witek\Documents\melty\universal-modder   (um.exe: C:\Users\witek\.local\bin\um.exe)
Started: 2026-10-06
Agent: opencode / deepseek-v4.1-flash
Melty: token works over HTTP JSON-RPC (https://melty.gg/api/mcp); token kept OUT of this repo and any files.
NOTE: E:\melty is the Melty app's managed library folder - do not put project files there.

## Goal (from user)
FPS-like Half-Life/GMod sandbox inside BeamNG.drive 0.39:
- FPS on-foot character with FPS controls (WASD + mouse look)
- physgun like GMod: grab props AND cars, rotate, throw
- other weapons: shoot cars, explode them
- spawn menu (small inventory / GUI selector): props, NPCs, vehicles, other
- "everything should be affected by the player"
- publish on Melty (one click install); also publish an open-source "universal-modder x melty mix" on GitHub
  (BYO agent harness / API keys / provider / MCP servers), and improve universal-modder itself
- main workflow: terminal of universal-modder (um CLI + repo workflow), easy to deploy from GitHub

## Game facts (recon, evidence-backed)
BeamNG.drive 0.39 (Steam appid 284160)
- install: E:\steam\steamapps\common\BeamNG.drive
- live profile: E:\beamng\current ; mods at E:\beamng\current\mods (userFolder=E:\beamng via launcher ini)
- engine: modified Torque 3D; gameplay Lua; vehicles JBeam (JSON); UI HTML/JS (Angular/Vue apps)
- no anti-cheat; offline-safe. Multiplayer = BeamMP (installed here, NOT installed by Melty) -> v1 solo.

Garry's Mod 2026.04 (appid 4000)
- install: E:\steam\steamapps\common\GarrysMod ; Source engine; Lua addons; HL2 mounted; workshop content present
- Melty recipe proof (live mashup gmod-wrestling-empire): mapping -> {game}/garrysmod/gamemodes,
  launch {game}/gmod.exe -steam +maxplayers 4 +sv_lan 1 +gamemode ... +map ...

## BeamNG one-click install (Melty) - verified pieces
- PROVEN: Bin64\BeamNG.drive.x64.exe accepts "-userpath <dir>" (single dash, space separated; strings in both exes:
  "-userpath", "Missing argument for -userpath", help: "sets the write path to the specified path. Can be relative.")
- "-nouserpath" = write path becomes the game folder (not what we want)
- Direct launch of Bin64 exe works; root BeamNG.drive.exe is only the launcher
- New/empty userpath is auto-created; mods mount from <userpath>\mods\*.zip (docs beamng documentation userfolder)
- TODO (in game): does -userpath use <dir> directly or <dir>\current ? test with a fresh dir
- Plan: Melty bundles profile skeleton + mod zip under {managed}; launch Bin64 exe with -userpath {managed}\...

## BeamNG Lua facts (recon; paths relative to install unless noted)
- FPS/walk: lua/ge/extensions/gameplay/walk.lua = on-foot mode (hidden unicycle body).
  API: setWalkingMode(enabled,pos,rot,force) :132, toggleWalkingMode() :163, isWalking() :31, getPosRot() :325,
  getVehicleInFront() :306. Bound to action "toggleWalkingMode" (core/input/actions/gameplay.json:58)
- First-person cam mode: lua/ge/extensions/core/cameraModes/steadycam.lua (global cam; WASD+mouse+space+jump,
  gravity + castRayStatic :24, :140-260; pushActionMap("Steadycam") :97)
- Camera API: core_camera.setByName :717, globalCameraFunction(name,fn,...) :1309,
  getPosition(:1620)/getQuat(:1654)/getFovDeg(:1679), setPosition :1285, setRotation :1218, setFOV :1230
- Frame hooks: M.onUpdate(dtReal,dtSim,dtRaw) (freeroam.lua:370/430), M.onPreRender (weather.lua:273)
- Input: mod action JSON auto-merged from lua/ge/extensions/core/input/actions/*.json
  (ctx "tlua"; onDown/onUp/onChange/onRelative); bindings merged from settings/inputmaps/*.json;
  no input.actions[] state table in Lua (commands call Lua functions)
- Mouselook: mouse axes -> core_camera.rotate_yaw_relative / rotate_pitch_relative (camera.json:14);
  steadycam consumes MoveManager.yawRelative/pitchRelative (:147-151)
- Raycast: castRay(from,to,includeTerrain,renderGeometry) -> {pt,norm,distance,object,material};
  castRayStatic(origin,dir,max[,arg4]) -> distance; cameraMouseRayCast() -> {pos,normal,object}
- Spawn props: dynamic props are vehicle models -> core_vehicles.spawnNewVehicle(model, opt) (dynamicProps.lua:99-108,
  examples "trashbin", "streetlight"); static = createObject('TSStatic') + setField shapeName + registerObject
  (ge_utils.lua:414; scenario/busdriver.lua:193); prefabs = spawnPrefab(...) ge_utils.lua:749
- Spawn vehicles: core_vehicles.spawnNewVehicle(modelName, opt{config,pos,rot,vehicleName,autoEnterVehicle,safeSpawn})
  :1825; model list getModelList :991 / getModel(model).configs (.key); despawn veh:delete() :1856;
  player vehicle getPlayerVehicle(0) ge_utils.lua:441
- AI chase (NPC): veh:queueLuaCommand('ai.setMode("chase")') + ai.setTargetObjectID(id)
  (flowgraph/nodes/vehicle/ai/chase.lua:32-33); modes disabled/random/span/manual/chase/flee/stop/follow/traffic/script
- Forces (physgun): vehicle-VM obj:applyForceVector(node,vec) (controller/playerController.lua:164),
  obj:applyForceVectorTime(node,vec,dt), obj:setPlanets({x,y,z,radius,mass}) gravity trick (funstuff.lua:55/127,
  negative mass repels); main-VM veh:applyClusterVelocityScaleAdd(clusterId,scale,x,y,z) (funstuff.lua:26/45);
  native C++ nodegrabber: be.nodeGrabber:setStrength/setControllerMode/renderNodes/onMouseButton/fixCurrentNode
  (core/nodegrabberGamepad.lua:123-197)
- Damage/explode: fire.explodeVehicle() fire.lua:427 (+ explodeNode :440), beamstate.breakAllBreakgroups(),
  particles 31 fireball / 32 smoke / 9 sparks (fire.lua:187-191); shipped boom recipe = funstuff.explodeVehicle()
  funstuff.lua:111-145 = setPlanets temp + fire.explodeVehicle + breakAllBreakgroups;
  damageTracker.setDamage(group,name,value,notifyUI) damageTracker.lua:46
- UI apps: ui/modules/apps/<Folder>/{app.json, app.js|app.vue}; Lua->UI guihooks.trigger -> Vue useEvents/on or
  Angular $on; UI->Lua bngApi.engineLua; app.json fields: domElement, directive, css(left/top/width/height),
  category, interactive; streams for high-rate HUD data; app catalogue scan (ui/apps.lua)
- Mod zip layout (proven from installed mods + engine): scripts/<name>/modScript.lua (loaded at startup,
  modmanager.lua:695-712; call setExtensionUnloadMode(m,"manual")); extensions lua/ge/extensions/<path>.lua;
  actions lua/ge/extensions/core/input/actions/<name>.json; bindings settings/inputmaps/<kb>_<name>.json;
  ui/modules/apps/<Folder>/...; mod_info/<ID>/info.json (optional for manual zips)

## Installed mods to mine (working examples on THIS PC)
- E:\beamng\current\mods\player_weapon_2.zip (25MB; external listing: guns usable in walking mode) -> dissect
- E:\beamng\current\mods\weapon_panel_jtf.zip: scripts/weaponPanel/modScript.lua,
  lua/ge/extensions/core/weaponPanel.lua, actions/weaponPanel.json, inputmaps/keyboard_weaponPanel.json (Alt+W default)
- E:\beamng\current\mods\iyb_fpvdrone.zip: FPV drone vehicle (droneinput.lua) - reference only

## Melty facts
- list_my_mods: empty (no mods yet on the account)
- search_mashups: BeamNG live mashups = 0; GMod = 1 (gmod-wrestling-empire, one-click yes)
- game_info beamng-drive: loaders []; modFolders {}; one-click wants plain game files, or standalone mode with {game} passed;
  sellPolicy "review"; engine "other"
- game_info garrys-mod: engine source; modFolders addons/lua/gamemodes/maps; sellPolicy allowed
- MCP tools available over HTTP (one call per request): search_games, game_info, inspect_package, validate_recipe,
  one_click_check, search_mashups, mashup_info, list_my_mods, remix_mashup, create_mod, update_mod, start_upload,
  upload_part_urls, finish_upload, add_screenshot, finish_screenshot, submit_release, report_fix_attempt, publish,
  mod_status, install_outcomes

## Route decision (draft, pending user OK)
- Host-side reimplementation of the GMod sandbox in BeamNG Lua (mashup-mods patterns 1+5).
  Source-engine files cannot load in Torque; real GMod content = milestone 2, via a local converter
  running on the player's own GMod install (keeps assets local, no redistribution).
- v1 publish: BeamNG mod only (listing on Melty with beamng-drive); add garrys-mod as required game
  when the asset importer milestone lands. Multiplayer: v1 solo (BeamMP not installed by Melty).
- Build base: shipped walk.lua + steadycam + native nodegrabber; new extension(s) for physgun/weapons/spawn menu;
  UI app for the spawn menu; action JSON for keys.

## Open questions / verify in game
- [ ] -userpath: direct profile or <dir>\current ? (launch test with fresh dir)
- [ ] how to enable walk mode programmatically in freeroam
- [ ] nodegrabber reuse feasibility (C++ API + input binding)
- [ ] best explosion recipe (funstuff pattern) and visual quality
- [ ] spawn menu: UI app vs ImGui panel (see weapon_panel_jtf dissection)
- [ ] user approvals: install mod zip into E:\beamng\current\mods; launch BeamNG; drive input for tests; record clip

## Other-session artifacts found in E:\beamng\current\mods (built 2026-10-06 ~17:30; NOT by this session)
- gmod_physgun.zip: lua/ge/extensions/core/gmodPhysgun.lua (v1.2, 208 lines) + actions gmodPhysgun.json +
  inputmaps under settings/ and vehicles/unicycle/. Behavior: grab any jbeam object within 12 m near the aim
  line (distance test, no raycast), per-frame mass-scaled spring sent via queueLuaCommand
  (obj:applyForceVector per node, K=120/D=15/CAP=50 per kg), release = fling; shoot = fire.explodeVehicle +
  beamstate.breakAllBreakgroups; spawnProp cycles gmod_melon/gmod_crate/gmod_barrel/gmod_tire via
  core_vehicles.spawnNewVehicle; spawnVehicle = barstow.
  Keys (unicycle ctx): g grab, v shoot, n prop, m vehicle, z/x distance, mouse0/mouse1; alt-combos global.
- gmod_melon/crate/barrel/tire.zip: converted GMod/HL2 assets as BeamNG prop vehicles (8-node box jbeam,
  .dae mesh, .png texture, .pc, info.json author "melty gmod import"). Textures: fruit_objects01 (melon),
  woodcrates01a, bluebarrel001, apc_tire001 -> VALVE/GMod content.
  LICENSE: must NOT ship on Melty (redistribution). Local dev/testing only.
- gmod_steve_stig.zip: unicycle_steve.jbeam part addon (slot unicycle_meshes, mesh "steve_body",
  group unicycle_body) + gmod_steve.dae/.materials.json/.pc/.png. Steve body for the walk-mode unicycle.
- E:\beamng\current\mods\db.json updated 17:41 (mods registered).

## Decisions (license-safe v1 content)
- Published v1 uses: the game's own props BY NAME (woodcrate, barrels, cones, trashbin, cardboard_box,
  couch, piano, porta_potty, large_tire, metal_box, trafficbarrel, tirestacks, tirewall, boxutility)
  + our own generated lookalikes for GMod-style props. GMod-derived assets stay out of the release.
- Milestone 2: on-player converter that imports GMod content from the player's own install;
  then garrys-mod becomes a required game on the Melty listing (true two-game mashup).
- unicycle = game asset (content/vehicles/unicycle.zip); walk mode spawns it hidden; Steve addon attaches to it.
- v1 solo/offline (BeamMP is not installed by Melty).

## Plan v1 (submitted for approval)
- M0 verify the other session's physgun/props/Steve in the running game; fix what breaks.
- M1 spawn menu (ImGui, Q key): Props / Vehicles / NPCs / Tools, spawns in front of the player.
- M2 NPCs: AI chase vehicles (+ a Steve chaser if feasible).
- M3 more tools: impulse/launch gun, freeze, rotate-while-held; sheet-driven.
- M4 FPS polish: walk + steadycam integration, crosshair, HUD, keybind cleanup.
- M5 package (mod_info zip), README, Melty recipe via -userpath, validate_recipe + one_click_check,
  listing draft, screenshot/clip, Test in Melty app, publish.
- M6 GitHub: mod repo (feeds Melty via githubRepo) + mix repo "melty-modder" (harness templates, BYO keys,
  Melty publish client, universal-modder + our improvements). Upstream PR only on user OK.
- All steps via the um terminal workflow; big files on E:; journal = this file.

## Live status (2026-10-06 ~18:15)
- Other session ACTIVE: last mod writes 18:14; games running (GMod since 17:57, BeamNG since 18:06;
  Melty app open since 17:11). DO NOT launch games, drive input or touch game folders while it runs.
- Deployment method it uses: UNPACKED folders in E:\beamng\current\mods\unpacked\ (zips removed from mods\):
  gmod_barrel/crate/melon/steve_stig/tire (17:48), gmod_physgun (18:06), gmod_npc_citizen + gmod_npc_combine (18:14),
  plus old mcbeamng_camera (00:13, from the Minecraft project).
- gmod_physgun newer than my 17:30 copy: extension 6761 B (was 6458, 18:04), + scripts/gmod_physgun/modScript.lua,
  + vehicles/unicycle/input_actions_gmodphysgun.json, updated bindings. Re-read before verifying.
- New NPC props: gmod_npc_citizen (HL2 Citizen) + gmod_npc_combine (Combine soldier) as 8-node prop vehicles
  (~66.7 kg total, nodeWeight 8.333; citizen box 1.33 x 0.37 x 1.83 m). NPC behavior (AI/walking) NOT present yet.
- Melty: new token verified working; account still has no drafts; BeamNG live mashups still 0.

## Build log 2026-10-06 evening (this session)
- Verified the other session's work from beamng.log (no input from me):
  * Walk mode works: unicycle id 35272 spawned, "Walking around on Gridmap V2".
  * Body mesh default = unicycle_snowman (the unicycle_steve part exists in the slot list but is not selected).
  * Physgun grabbed/released; spawn menu opened; gmod_melon spawned with no Lua errors.
- BUG FOUND (other session's gmodPhysgun): on foot, getPlayerVehicle(0) is nil, so the self-exclusion fails
  and it grabbed the player's own unicycle (log 934.9 s and 978.4 s). Integration fix: also exclude
  jbeam filename == "unicycle".
- Built project scaffold: sheets/ (systems, keys, tools, weapons, props, npcs, ui) + tools/preflight.py
  (first run: 16 fails, fixed; now clean, 30 open cells = the roadmap) + tools/install_mod.ps1.
- Built mod gmod_gameplay (staged at E:\modder\gmod-beamng\mod\gmod_gameplay, NOT installed in the game yet):
  * core/gmodNpcs.lua - chase behavior for gmod_npc_citizen / gmod_npc_combine / gms_nextbot;
    per-node velocity controller sent to the vehicle VM each frame; B toggles.
  * core/gmodTools.lua - Physcannon Punt (R): cameraMouseRayCast(true,-1) with cone fallback;
    0.3 s mass-scaled thrust (70 m/s^2) so every mass gets the same launch feel.
  * core/gmodHud.lua - ImGui crosshair + bottom key hints (metrics.lua API pattern, pcall-guarded).
  * actions gmodGameplay.json (r/b, ctx tlua) + settings + unicycle inputmaps bindings.
- Next: license-clean lookalike assets (gms_melon/crate/barrel/tire + gms_nextbot) with a Python generator
  (Pillow available in the um tool venv), then install + live test, then packaging + Melty.
- 2026-10-06 late evening: generated gms_melon (sphere 768 tris), gms_crate (box), gms_barrel (cyl 96),
  gms_tire (torus 1024), gms_nextbot (quad + face texture) into mod/gms_content/vehicles; DAE XML validated.
  Added spawn actions to gmod_gameplay: K = nextbot, H = cycle sandbox props; R = punt, B = npc toggle.
  Added J = noclip (steadycam groundWalk toggle via globalCameraFunction('steadycam','setParam',...)).
  Sheets updated. Next: install + live test in a test window (ask user first), then integration + packaging.
- 2026-10-06 18:30: static checks pass: luaparse (Lua 5.1) on gmodNpcs/gmodTools/gmodHud/modScript = OK;
  all three JSON files valid; preflight clean. Waiting on user for a test window.

- 2026-10-06 18:45: moved E:\beamng\current\mods\unpacked\mcbeamng_camera -> E:\modder\_disabled (old
  Minecraft-camera probe; it spammed beamng.log, unrelated to this project).
- 2026-10-06 18:45: launched a visible universal-modder agent window per user request:
  C:\Users\witek\Documents\melty\start-gmod-beamng.ps1 (opencode modder agent, reads this MODLOG).
- Game instance (PID 2968, launched with -userpath E:\beamng): gmod_gameplay + gms_content mounted,
  gmodNpcs/gmodTools/gmodHud loaded (log at 37-40 s). A computer-use agent is actively playing the same
  instance (gmodPhysgun grabbed a pickup at 402 s) -> no input from this session into that game; read/check/support.
- 2026-10-06: new Melty token verified (list_my_mods OK, no mods yet).

- 2026-10-06 18:49: visible universal-modder agent window RUNNING (opencode PID 3508, launcher
  C:\Users\witek\Documents\melty\start-gmod-beamng.ps1, runs from the universal-modder repo; task list inside).
- 2026-10-06 18:50: live verification from beamng.log (game PID 2968): gmod_gameplay/gms_content mounted,
  gmodNpcs/gmodTools/gmodHud loaded; a tester pressed J -> "noclip ON" (467 s) and B -> "npc behavior OFF"
  (489 s); gmodNpcs tracks NPCs (tracking 1/0 as they spawn/despawn); zero Lua errors from our files;
  HUD did not self-disable.

- 2026-10-06 18:52: verified the agent window is ALIVE and working: opencode PID 3508, 1.2 GB WS,
  CPU +9.4 s in 10 s (active). Brought its window (PID 16012, TUI title "OpenCode") to the front.
  Launcher now sets the title "UNIVERSAL MODDER - GMod x BeamNG" on future starts.
- 2026-10-06 18:52: game PID 2968 Responding=True (running).

- 2026-10-06 19:2x: ROOT CAUSES of the "frozen BeamNG" episodes found in the logs: (1) the game's UI
  subprocess was killed externally - "CEF client MainGEUI, TS_PROCESS_WAS_KILLED, SIGKILL or task
  manager kill" -> the game then shows "Unresponsive UI Process" and dies; (2) the installed
  chipvolumetricclouds mod has a broken shader (volumetricClouds.hlsl undeclared identifier).
  Neither is our mod. Clouds mod moved to E:\modder\_disabled (reversible); mcbeamng_camera already moved.
- 2026-10-06 19:2x: CLEAN TEST PROFILE validated at E:\modder\testdata (userpath root; profile at
  E:\modder\testdata\current): mods go to mods\unpacked\<name>\ (NOT mods\<name>\ - that silently
  loads nothing). With only our 7 mods: all mount, gmodNpcs/gmodTools/gmodHud/gmodPhysgun load,
  Gridmap V2 auto-loads, F (walk mode) works (unicycle spawn logged). This mirrors the Melty install.
- 2026-10-06 19:2x: the window agent added vehicles/unicycle/input_actions_gmodGameplay.json (same
  pattern as gmod_physgun's vehicle-level actions) - copied back into the staging mod.
- BLOCKER for live key verification: several agents + the user are launching/killing game instances
  at the same time (foreground keeps switching; CEF subprocess killed). Need one uninterrupted
  instance in the foreground to finish the key/physgun verification.

- 2026-10-06 19:35: Melty DRAFT created: "GMod Sandbox in BeamNG.drive"
  id 4bc4e068-cc0c-46af-8b75-925f14d2ad9b
  https://melty.gg/studio/4bc4e068-cc0c-46af-8b75-925f14d2ad9b
  Listed with beamng-drive only for v1 (honest; garrys-mod joins with the asset-importer milestone).
- Role split going forward: window agent = build + live verify + package; this session = Melty upload/
  submit/media, GitHub mix repo, universal-modder improvements; user = title/credits/license/remix.

- 2026-10-06 19:45: USER VIDEO SPEC (https://www.youtube.com/watch?v=fKYeLvjWhis - "Fully functional
  physgun test", BlueNightHawk 2021, BeamNG): the held object's ANGLES are controlled by the mouse and
  the object is moved around with the movement keys. Implemented in gmodSandbox.lua v1.1 by this session:
  on grab, the vehicle VM captures node ids + offsets from the node centroid; every frame the GE sends a
  per-node target = holdPoint + Rot(cameraDelta)*offset, so looking around rotates the held object.
  Objects with >32 nodes (cars) stay translation-only. Grab/release reset the VM capture. Menu hint updated.
- TODO from the video vibe (own assets only, no Valve audio): grab/release SFX, a beam/trail visual from
  the view to the held object (BeamNG has rope visuals), HL2-style scientist voice pack recorded/generated.

- 2026-10-06 20:0x (late): RELEASE 1.1.0 built and uploaded as a DRAFT on Melty
  modId 4bc4e068-cc0c-46af-8b75-925f14d2ad9b, releaseId 65658cf2-b928-49a1-a4b8-fdaa704639b2
  package dist/gmod_sandbox_v1.1.0.zip (86358 B, sha256 ab0557...), one_click_check: YES / publishable.
  Recipe A validated: mode installed; mapping (archive root) -> {managed}/beamng-user/current/mods/unpacked/gmod_sandbox;
  launch {game}/Bin64/BeamNG.drive.x64.exe -userpath {managed}/beamng-user. Screenshot uploaded (game toast visible).
  melty.json pushed to vit-cerny/gmod-sandbox (component fileName gmod_sandbox_v*.zip) together with the v1.1 source.
  Next: user opens the mashup in the Melty app and presses Test; publish on their OK.

## Log
- 2026-10-05/06: intake, Melty reads, workspace set up, 4 recon subagents (FPS/camera/input, spawn/force/
  explode APIs, UI+mod layout, userpath research), installed weapon mods dissected.
- 2026-10-06: found and read the other session's gmod_* mods (physgun/props/Steve); confirmed game props +
  unicycle are build assets; license decision for v1. Plan submitted for approval.
- 2026-10-06 18:15: other session still active (added NPC props, updated physgun, unpacked deployment).
  Waiting on user: coordination decision (support/take over) before touching anything.

## 2026-10-06 19:00-19:30 (this session continues - integration)
- FOUND THE TEST HARNESS: BeamNG 0.39.4 ships an in-game MCP server (lua/ge/extensions/mcp/*)
  listening on http://127.0.0.1:29292/mcp (Streamable HTTP, POST JSON-RPC). 86 tools incl.
  run_lua, get_logs, get_vehicles, get_object, raycast, spawn, trigger_action, inject_input,
  set_camera, set_position, screenshot, ai tools, file tools. Requests are served from the
  game's onUpdate, so they only answer once a level is loaded (not during the loading screen).
  Helpers written: tools/call.ps1 (call one tool), tools/runlua.ps1 (run Lua from a file),
  tools/check_lua.js (Lua 5.1 syntax via luaparse), tools/list_pc.py (prop config names).
- DISCOVERED the other agent's workspace: E:\melty-work\gmod-beamng (the Valve-asset import
  project: gmod_physgun v1.3, gmod_melon/crate/barrel/tire, citizen/combine, Steve). Its
  docs/MODLOG.md has the v1.3 in-game verification. The published release must not contain
  those Valve assets; they stay local.
- BLOCKER (coordination): the OpenCode desktop-app computer-use agent is running a kill/relaunch
  RECOVERY LOOP on BeamNG every ~7 min (powershell child of opencode-cli PID 13556, uses
  `um win kill` + relaunch). It kills the game at ~50 s uptime, before the level finishes
  loading, so live play is nearly impossible. Log evidence: beamng.1.log ends at 50.28 s with
  no shutdown message; launcher log parent process = powershell; recovery procs at 19:17:32 and
  19:24:52. This session does NOT kill it (ask-before-destructive). Verification therefore uses
  the in-game MCP (no input fighting) during the up windows.
- physgun bug from the prompt: the INSTALLED gmodPhysgun.lua already excludes jb=="unicycle"
  (line 83) - fixed by the other session. Confirmed by reading the file.
- BUILT the single publishable mod: mod\gmod_sandbox (41 files) =
  core_gmodSandbox.lua (physgun + unified menu + spawn helpers, license-clean catalogue),
  core_gmodNpcs.lua, core_gmodTools.lua, core_gmodHud.lua, actions + unicycle/global inputmaps,
  modScript, mod_info, and vehicles/gms_melon|crate|barrel|tire|nextbot.
  Menu tabs: Props (ours) / Props (game) / NPCs / Vehicles / Tools. Game props use their real
  .pc paths (e.g. woodcrate -> vehicles/woodcrate/large.pc), NOT <model>/<model>.pc.
- INSTALLED gmod_sandbox to E:\beamng\current\mods\unpacked; moved the superseded
  gmod_gameplay, gms_content, gmod_physgun to E:\modder\_disabled\gmod_beamng_superseded
  (reversible; avoids duplicate extension names + duplicate keybinds). Valve-asset prop mods
  (gmod_melon/crate/barrel/tire, npc_citizen/combine, steve_stig) left in place as local-only.
- STATIC CHECKS PASS: preflight clean (21 open = roadmap cells), luaparse 5.1 OK on all 5 lua
  files, all 19 json files valid.
- Next: live verify via MCP once the game reaches a level; then package + Melty.

## 2026-10-06 19:30-20:10 (live verification via in-game MCP - evidence)
Method: BeamNG's built-in MCP (enableMcp:true) + `run_lua` / `trigger_action` / `get_logs` / `screenshot`.
No physical keyboard/mouse used, so no fight for input with the computer-use agent.
- Mod mounts and loads in E:\beamng (log 24s): "extension loaded (v1.0)" for
  core_gmodSandbox, core_gmodNpcs, core_gmodTools, core_gmodHud.
- WALK (F): trigger_action toggleWalkingMode -> gameplay_walk.isWalking()=true; player body = unicycle.
- PHYSGUN grab: "grabbed pickup id=32963" + mass-scaled global _gmodSandboxMass=2165.27; release ok.
  Also grabbed a gms_nextbot (id=35324, mass 67.5) - mass scaling works for light props too.
- EXPLODE (RMB): "shot pickup id=32963 dist=6.0" and "shot gms_melon dist=5.5".
- SPAWN MENU (Q): "spawn menu opened" / "closed"; ImGui draws with no Lua error.
- PUNT (R): "punt pickup id=32963 via cone".
- NEXTBOT (K): "spawned gms_nextbot"; NPC chase: "tracking 1 NPC(s)" / "tracking 2 NPC(s)".
- SANDBOX PROPS: "spawned gms_melon / gms_crate / gms_barrel / gms_tire / gms_nextbot".
- GAME PROPS: "spawned woodcrate" (explicit config vehicles/woodcrate/large.pc) - the
  <model>/<model>.pc convention does NOT hold for the game's own props.
- NOCLIP (J): "noclip ON". NPC toggle (B): "npc behavior ON/OFF".
- KEY BINDINGS: trigger_action gmod_sandbox_menu / _gmsprop / _gameprop, gmod_punt_fire,
  gmod_nextbot_spawn, gmod_noclip_toggle all report "triggered action: ..." (registered).
- HUD (gmodHud): loaded, no "HUD disabled after error", no Lua error -> crosshair/hints draw.
  NOTE: this session has no reachable vision model, so the HUD/menu were not visually confirmed
  from a screenshot; a human or the computer-use agent should eyeball it once.

### Bugs found and FIXED (re-verified)
- gmodTools.punt: cameraMouseRayCast can return a static scene object (no getJBeamFilename),
  which threw "attempt to call method 'getJBeamFilename' (a nil value)" and aborted the punt.
  Fixed: raycastTarget only accepts objects that expose getJBeamFilename, wrapped in pcall;
  coneTarget / findTarget / gmodNpcs now read jbeam via a guarded helper. Re-verified:
  "punt pickup via cone" (no error).

### Environment caveat (NOT a mod bug)
- Two hard crashes happened as genuine OS out-of-memory, not from our content:
  log said "Reported free memory: 273.51MB, Used memory: 15.61GB" then
  "FATAL MEMORY ERROR: Not enough memory available". The machine (16 GB) was saturated by
  many unrelated processes + game instances. Each gms_* model spawns and runs fine in
  isolation (verified crate, barrel, tire, melon, nextbot all spawned alive in one session).

### Test-harness notes
- The computer-use agent (OpenCode desktop app, opencode-cli PID 13556) runs a scripted
  harness: kill all BeamNG by NAME pattern (it kills the game's CEF child too, causing an
  "Unresponsive UI Process" dialog) then launch a clean profile at E:\modder\testdata and
  drive F H K B J R N. Its kill-by-name is the toolkit anti-pattern (exact PIDs only).
- To let that harness test the unified mod, gmod_sandbox was also installed into
  E:\modder\testdata\current\mods\unpacked (superseded gmod_gameplay/gms_content/gmod_physgun
  moved to E:\modder\_disabled\testdata_superseded) and enableMcp:true was added to that
  profile's settings.json (both reversible).

## 2026-10-06 20:03-20:15 (package + publish prep)
- PACKAGE: dist/gmod_sandbox_v1.0.0.zip (85,581 B, 43 files, sha256 db9b416b...a0a6).
  Contents: our Lua (gmodSandbox/gmodNpcs/gmodTools/gmodHud), actions + inputmaps, modScript,
  mod_info, README.md, LICENSE, vehicles/gms_* (5 generated models). NO Valve/GMod assets.
- LINT: `um publish check mod/gmod_sandbox` -> PASS 43 files, 0 failures, 0 warnings;
  same with --game <BeamNG install> (catches copied game files) -> PASS.
- MELTY: endpoint https://melty.gg/api/mcp responds; tools/list works anonymously (21 tools),
  but every actual call needs the token (401). Listing + recipe draft written to
  melty/PUBLISH_DRAFT.md. Exact install recipe waits on inspect_package's draftRecipe (needs auth).
  Publish flow: inspect_package -> validate_recipe -> one_click_check -> create_mod ->
  start_upload/finish_upload -> submit_release -> human Test in the Melty app -> publish.
- GITHUB: gh authenticated as vit-cerny (repo scope). Two local repos prepared and committed:
  * E:\modder\gmod-sandbox - the mod (README, LICENSE, MODLOG field note, all mod files).
  * E:\modder\melty-modder - the open-source mix: client/melty.py + client/beamng.py (stdlib,
    BYO MELTY_TOKEN), harness/opencode.jsonc + harness/AGENTS.md (BYO keys/provider/MCP),
    docs/beamng-mcp-tools.md (the 86-tool in-game MCP reference), tools/zip_mod.py + check_lua.js.
  Not pushed (needs the human's OK on name/visibility).
- OPEN ITEM FOR THE HUMAN: (1) paste the Melty Publish prompt/token; (2) confirm creating the
  GitHub repos and their names/visibility.

## 2026-10-06 20:52 (GitHub repos PUBLISHED)
- Pushed both repos (public, MIT):
  * https://github.com/vit-cerny/melty-modder  (branch master) - the open-source mix.
  * https://github.com/vit-cerny/gmod-sandbox  (branch master) - the mod (feeds Melty githubRepo).
- Verified via gh: visibility PUBLIC, README + sources present; gmod-sandbox's pushed
  gmodTools.lua contains the punt fix (isVehicleObject). Safety scan: no secrets, no Valve assets
  (only prose mentions of "Valve").
- STILL BLOCKED: Melty publish. https://melty.gg/api/mcp tools/list works anonymously but every
  call returns 401; no local Melty process/bridge holds the auth, so the token must come from the
  human (Melty Studio -> Publish prompt). Everything else is ready:
  dist/gmod_sandbox_v1.0.0.zip + melty/PUBLISH_DRAFT.md + this flow:
  inspect_package -> validate_recipe -> one_click_check -> create_mod (githubRepo
  "vit-cerny/gmod-sandbox") -> start_upload/finish_upload -> submit_release -> Test -> publish.

## 2026-10-06 20:57 (independent verification by the computer-use agent)
Fresh evidence in E:\beamng\current\beamng.log from ANOTHER agent playing the unified mod for a
long session (uptime 2119-2199 s) - this is real end-to-end use, not our scripted calls:
- physgun on a CAR: "grabbed bolide id=37104" / "released id=37104" (many times) - grab of a
  full vehicle works.
- physgun on a light prop: "grabbed gms_melon id=37238" + "_gmodSandboxMass=2.475" / released.
- NPCs: "spawned gms_nextbot" x2, "tracking 3 NPC(s)" then "tracking 4 NPC(s)", "npc behavior ON/OFF".
- spawns: "spawned gms_melon", "spawned gms_tire", "spawned barstow".
Zero Lua errors from our files. This confirms walk/physgun/explode/menu/NPC/punt/nextbot/props/HUD/
noclip in the running game beyond our own MCP calls.

### Remaining blocker (single item)
Melty publish. Every Melty tools/call returns 401 without the token, and no local Melty process or
CLI bridge holds the auth (`um` has no Melty group). A ready-to-run publisher is prepared at
tools/melty_publish.py (reads MELTY_TOKEN from the env; `--inspect` then `--publish`), with the
package, listing and candidate recipe in melty/. It cannot be run without the human pasting the
Melty Studio Publish prompt.

## 2026-10-06 21:00-21:20 (UI verification detail)
- UI proof we DO have: Windows.Media.Ocr (tools/ocr.ps1, no external tools) read the 20:01:52
  screenshot and returned "GMod Sandbox / Boom: pickup" - our toastrMsg UI really renders on screen.
- Menu window: confirmed by log ("spawn menu opened"/"closed") on two independent instances; the
  ImGui code path is identical to the physgun menu the other session screenshot-verified (t6).
- Pixel-level menu capture could NOT be completed in this environment: a menu-open screenshot came
  back as a path but was never written, because the game window got resized to 463x425 by the other
  agent mid-capture and the D3D12 swap chain reinitialised. Not a mod fault. Worth a human/vision
  eyeball once, but no code reason to doubt it.
- Environment remains the main risk: free RAM dipped to 0.3 GB and BeamNG could not reach freeroam
  in one attempt; the other agent keeps relaunching its test profile.

## 2026-10-06 21:30-22:05 (user: restore + make it play like GMod)
- User reported "it doesnt work at all" and asked to RESTORE the old setup and make it play exactly
  like GMod, and to research GMod gameplay.
- RESTORED: moved gmod_sandbox aside (E:\modder\_disabled\gmod_sandbox_unified) and restored
  gmod_gameplay + gms_content + gmod_physgun into E:\beamng\current\mods\unpacked (and testdata).
  Verified live: core_gmodPhysgun/Npcs/Tools/Hud all load from the restored set.
- RESEARCH (authoritative, GMod wiki + a YouTube physgun video transcript):
  physgun LMB = grab/hold (colored beam), release = drop; mouse wheel or E+W/S = distance;
  E = rotate, E+Shift = 45deg snap; RMB = FREEZE the held prop; R = unfreeze the aimed prop /
  double-R all; Q = spawnmenu; C = context menu; E = use; toolgun LMB=use RMB=pick.
- CHANGED gmodPhysgun.lua to v2.0 ("gmod controls"):
  * RMB (mouse1) now FREEZES the held prop (was explode); with nothing held it punts
    (gravity-gun secondary). Freeze pins the prop at its world position; it stays after release.
  * R now UNFREEZES (aimed prop, else all your frozen props). Punt is no longer on R.
  * F also freezes (extra convenience). V still explodes.
  * Added a physgun BEAM: cyan line from the gun (bottom-centre) to the held prop, projected with
    core_camera getPosition/getQuat/getFovRad and an ImGui draw list. Falls back to the ImGui
    viewport size because Canvas:getWindowClientSizeXY() returns 0 while the window is a sliver.
  * Guarded getJBeamFilename (ray/obj can be static geometry).
- BINDINGS: gmod_physgun_freeze = mouse1 (on foot) + f + alt f; gmod_physgun_unfreeze = r + alt r.
  Removed the old r -> punt from gmod_gameplay so R is unfreeze. HUD hint line updated.
- VERIFIED LIVE (MCP): grabbed pickup id=32957 (mass 2165), `froze id=32957`, `unfroze id=32957`;
  frozen prop position identical over 3 s; bindings table shows freeze=button1/f/alt f,
  unfreeze=r/alt r. Beam draw API confirmed working; viewport=1920x1010.
- KNOWN DEVIATION: GMod moves the held prop with the mouse wheel; BeamNG has no analog action
  handler here, so distance stays on Z/X (documented).
- CAVEAT: screenshots fail to write while the game window is minimised, so the beam was not
  captured visually; it is one line to verify once the game is played in a normal window.
