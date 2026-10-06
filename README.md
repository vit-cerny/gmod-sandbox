# GMod Sandbox for BeamNG.drive

Play Half-Life / Garry's Mod style sandbox inside BeamNG.drive: a first-person character with a
physgun, an explosion shot, a spawn menu, chasing nextbots, a punt tool, noclip and an on-screen HUD.

Built for BeamNG.drive 0.39 (offline / single-player). Everything in this release is our own code
plus our own generated art; it contains no Garry's Mod, Half-Life or Valve assets. The props it
spawns by name are the game's own props.

## Install

Copy `gmod_sandbox/` into your BeamNG user folder's `mods/` directory:

    <userfolder>/mods/gmod_sandbox/

or drop the zip (`gmod_sandbox_v1.1.0.zip`) into `<userfolder>/mods/`. The game scans the mods
folder on startup.

## Controls (on foot - press F to enter walking mode)

| Key            | Action                                              |
|----------------|-----------------------------------------------------|
| F              | enter / leave walking mode (BeamNG default)         |
| Q              | open / close the spawn menu                         |
| Left mouse     | physgun grab (hold) / drop or fling (release)       |
| Right mouse    | explode whatever is in the crosshair                |
| Mouse look     | while holding: rotate the held object (GMod feel)   |
| Z / X          | pull the held object closer / push it farther       |
| N              | cycle and spawn one of the game's own props         |
| H              | cycle and spawn our sandbox props (melon/crate/...) |
| M              | cycle and spawn a vehicle                           |
| R              | physcannon punt (shove whatever you look at)        |
| K              | spawn a nextbot (it hunts you)                      |
| B              | toggle the NPC chase behaviour                      |
| J              | noclip (free flight on foot)                        |

The same actions are also bound on the Alt layer (Alt+Q, Alt+R, ...) so they work while driving.

## Spawn menu

Props (ours), Props (game), NPCs, Vehicles and Tools. Everything spawns about 4 m in front of you.

- Our sandbox props: melon, crate, barrel, tire (generated art, CC0).
- NPC: nextbot (generated art, CC0) - turns and chases you when NPC chase is on.
- Vehicles: a small selection of the game's own vehicles.
- Tools: punt, nextbot, NPC chase, noclip - the same as the keys above.

## Credits and licence

- Code: MIT (see LICENSE).
- Generated art (gms_melon, gms_crate, gms_barrel, gms_tire, gms_nextbot): CC0-1.0 (public domain).
- No Garry's Mod / Half-Life / Valve content is included or required.
- Built with the universal-modder toolkit and AI assistance (opencode "modder" agent).
