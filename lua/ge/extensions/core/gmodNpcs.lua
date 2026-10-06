-- gmodNpcs.lua - NPC behavior for the GMod x BeamNG sandbox (melty mashup)
-- Namespace: extensions.core_gmodNpcs  (loaded by scripts/gmod_gameplay/modScript.lua)
-- Makes spawned NPC prop vehicles chase the player (nextbot style) with a
-- per-node velocity controller applied inside the vehicle VM each frame.

local M = {}

local logTag = "gmodNpcs"
local enabled = true
local SPEED = 6.0          -- m/s chase speed
local GAIN = 5.0           -- velocity controller gain (1/s)
local CHASE_RANGE = 150.0  -- stop chasing beyond this distance (m)
local STOP_AT = 2.0        -- keep this distance from the player (m)
local RESCAN_EVERY = 0.5   -- seconds between object scans

local NPC_MODELS = { gmod_npc_citizen = true, gmod_npc_combine = true, gms_nextbot = true }

local tracked = {}
local scanT = 0
local chaseCount = 0

local function dlog(m)
  pcall(log, "I", logTag, m)
end

local function getPlayerPos()
  local ok, p = pcall(core_camera.getPosition)
  if ok and p then return p end
  local veh = getPlayerVehicle(0)
  if veh then return veh:getPosition() end
  return nil
end

-- The walking body (unicycle) must never be treated as an NPC.
local function jbeam(o)
  if not (o and o.getJBeamFilename) then return "" end
  local ok, jb = pcall(function() return o:getJBeamFilename() end)
  return (ok and jb) or ""
end

local function isPlayerObject(o)
  local veh = getPlayerVehicle(0)
  if veh and o:getID() == veh:getID() then return true end
  return jbeam(o) == "unicycle"
end

local function rescan()
  local n = 0
  tracked = {}
  for i = 0, be:getObjectCount() - 1 do
    local o = be:getObject(i)
    if o then
      local jb = jbeam(o)
      if NPC_MODELS[jb] and not isPlayerObject(o) then
        tracked[o:getID()] = { model = jb }
        n = n + 1
      end
    end
  end
  if n ~= chaseCount then
    dlog("tracking " .. n .. " NPC(s)")
    chaseCount = n
  end
end

local CHASE_CMD = [[
if obj and v and v.data and v.data.nodes then
  local tx, ty, tz = %f, %f, %f
  local speed, gain = %f, %f
  if not _gmsNpcMass then
    local m = 0
    for _, nd in pairs(v.data.nodes) do
      local okm, mm = pcall(obj.getNodeMass, obj, nd.cid)
      if okm and mm then m = m + mm end
    end
    if m < 1 then m = 60 end
    _gmsNpcMass = m
  end
  local n = 0
  for _, nd in pairs(v.data.nodes) do n = n + 1 end
  if n == 0 then return end
  local per = _gmsNpcMass / n
  for _, nd in pairs(v.data.nodes) do
    local p = obj:getNodePosition(nd.cid)
    local fl = vec3(tx - p.x, ty - p.y, 0.0)
    local d = fl:length()
    local desired
    if d > 0.2 then
      desired = fl:normalized() * speed
    else
      desired = vec3(0, 0, 0)
    end
    local vel = obj:getNodeVelocityVector(nd.cid)
    local f = (desired - vec3(vel.x, vel.y, 0)) * (per * gain)
    obj:applyForceVector(nd.cid, f)
  end
end
]]

local function sendChase(o, target)
  o:queueLuaCommand(string.format(CHASE_CMD, target.x, target.y, target.z, SPEED, GAIN))
end

function M.toggle()
  enabled = not enabled
  if enabled then rescan() end
  dlog("npc behavior " .. (enabled and "ON" or "OFF"))
  guihooks.trigger("toastrMsg", {
    type = "info", title = "GMod NPCs",
    msg = enabled and "NPC behavior ON" or "NPC behavior OFF",
    config = { timeOut = 1600 },
  })
end

function M.isEnabled()
  return enabled
end

function M.onUpdate(dt)
  scanT = scanT + dt
  if scanT >= RESCAN_EVERY then
    scanT = 0
    rescan()
  end
  if not enabled then return end
  local target = getPlayerPos()
  if not target then return end
  for id in pairs(tracked) do
    local o = be:getObjectByID(id)
    if o then
      local p = o:getPosition()
      local d = (target - p):length()
      if d > STOP_AT and d < CHASE_RANGE then
        sendChase(o, target)
      end
    end
  end
end

function M.onInit()
  setExtensionUnloadMode(M, "manual")
end

M.logTag = logTag
dlog("extension loaded")
return M
