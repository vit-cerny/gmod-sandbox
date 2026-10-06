-- gmodTools.lua - extra weapons/tools for the GMod x BeamNG sandbox (melty mashup)
-- Namespace: extensions.core_gmodTools
-- Physcannon Punt (R): precise raycast from the crosshair, strong shove.
-- The push runs for PUNT_TIME seconds so it works with the vehicle VM's
-- force-per-frame model (no impulse setter exists in 0.39).

local M = {}

local logTag = "gmodTools"
local PUNT_ACCEL = 70.0    -- m/s^2 while thrusting (mass-independent by design)
local PUNT_TIME = 0.30     -- seconds of thrust
local PUNT_RANGE = 60.0    -- fallback cone scan range (m)
local PUNT_DOT = 0.80

local punts = {}           -- [objectId] = seconds of thrust left

local function dlog(m)
  pcall(log, "I", logTag, m)
end

local function toast(t, msg)
  guihooks.trigger("toastrMsg", {
    type = t, title = "Physcannon Physgun", msg = msg,
    config = { timeOut = 1400 },
  })
end

local function aim()
  local ok1, p = pcall(core_camera.getPosition)
  local ok2, f = pcall(core_camera.getForward)
  if ok1 and ok2 and p and f then return p, f end
  local veh = getPlayerVehicle(0)
  if veh then return veh:getPosition() + vec3(0, 0, 1.2), veh:getDirectionVector() end
  return nil, nil
end

local function raycastTarget()
  local ok, r = pcall(cameraMouseRayCast, true, -1)
  if ok and type(r) == "table" then
    local obj = r.object
    -- The ray can hit static scene geometry; only vehicles have getJBeamFilename.
    if obj and obj.getID and obj.getJBeamFilename then
      local okjb, jb = pcall(function() return obj:getJBeamFilename() end)
      if okjb and jb and jb ~= "" then return obj end
    end
  end
  return nil
end

local function isVehicleObject(o)
  if not (o and o.getID and o.getJBeamFilename) then return false end
  local ok, jb = pcall(function() return o:getJBeamFilename() end)
  return ok and jb and jb ~= ""
end

local function coneTarget(pos, fwd)
  local best, bestD = nil, math.huge
  local veh = getPlayerVehicle(0)
  local pid = veh and veh:getID() or -1
  for i = 0, be:getObjectCount() - 1 do
    local o = be:getObject(i)
    if o and o:getID() ~= pid and isVehicleObject(o) then
      local jb = o:getJBeamFilename()
      if jb ~= "unicycle" then
        local to = o:getPosition() - pos
        local d = to:length()
        if d > 0.5 and d < PUNT_RANGE and to:normalized():dot(fwd) > PUNT_DOT and d < bestD then
          best, bestD = o, d
        end
      end
    end
  end
  return best
end

function M.punt()
  local pos, fwd = aim()
  if not pos or not fwd then return end
  local target = raycastTarget()
  local via = "ray"
  if not target then
    target = coneTarget(pos, fwd)
    via = "cone"
  end
  if not target then
    toast("warning", "Nothing in the crosshair.")
    return
  end
  local id = target:getID()
  punts[id] = PUNT_TIME
  dlog(string.format("punt %s id=%d via %s", tostring(target:getJBeamFilename()), id, via))
  toast("success", "Punt " .. tostring(target:getJBeamFilename()))
end

local THRUST_CMD = [[
if obj and v and v.data and v.data.nodes then
  local dx, dy, dz = %f, %f, %f
  local accel = %f
  if not _gmsPuntMass then
    local m = 0
    for _, nd in pairs(v.data.nodes) do
      local okm, mm = pcall(obj.getNodeMass, obj, nd.cid)
      if okm and mm then m = m + mm end
    end
    if m < 1 then m = 60 end
    _gmsPuntMass = m
  end
  local n = 0
  for _, nd in pairs(v.data.nodes) do n = n + 1 end
  if n == 0 then return end
  local per = _gmsPuntMass / n
  local f = vec3(dx, dy, dz) * (per * accel)
  for _, nd in pairs(v.data.nodes) do
    obj:applyForceVector(nd.cid, f)
  end
end
]]

function M.onUpdate(dt)
  local _, fwd = aim()
  for id, t in pairs(punts) do
    local rem = t - dt
    if rem <= 0 or not fwd then
      punts[id] = nil
    else
      punts[id] = rem
      local o = be:getObjectByID(id)
      if o then
        o:queueLuaCommand(string.format(THRUST_CMD, fwd.x, fwd.y, fwd.z, PUNT_ACCEL))
      else
        punts[id] = nil
      end
    end
  end
end

-- Spawn helpers for the license-clean sandbox content (gms_*).
local GMS_PROPS = { "gms_melon", "gms_crate", "gms_barrel", "gms_tire" }
local gmsIndex = 0

local function spawnModelAtAim(model)
  local pos, fwd = aim()
  if not pos or not fwd then return end
  local p = pos + fwd * 4.0 + vec3(0, 0, 0.8)
  local ok, err = pcall(function()
    core_vehicles.spawnNewVehicle(model, {
      config = "vehicles/" .. model .. "/" .. model .. ".pc",
      pos = p,
      rot = quat(0, 0, 0, 1),
    })
  end)
  if ok then
    dlog("spawned " .. model)
    toast("success", "Spawned " .. model)
  else
    dlog("spawn failed " .. model .. ": " .. tostring(err))
    toast("error", "Spawn failed: " .. tostring(err))
  end
end

function M.spawnPropGms()
  gmsIndex = gmsIndex + 1
  if gmsIndex > #GMS_PROPS then gmsIndex = 1 end
  spawnModelAtAim(GMS_PROPS[gmsIndex])
end

function M.spawnNextbot()
  spawnModelAtAim("gms_nextbot")
end

-- Noclip: toggles the steadycam between grounded walking and free flight.
local noclip = false

function M.toggleNoclip()
  noclip = not noclip
  local ok, err = pcall(function()
    core_camera.globalCameraFunction('steadycam', 'setParam', 'groundWalk', not noclip)
  end)
  if ok then
    dlog("noclip " .. (noclip and "ON" or "OFF"))
    toast("info", noclip and "Noclip ON (free fly)" or "Noclip OFF (walk)")
  else
    noclip = not noclip
    dlog("noclip failed: " .. tostring(err))
    toast("error", "Noclip unavailable here")
  end
end

function M.onInit()
  setExtensionUnloadMode(M, "manual")
end

M.logTag = logTag
dlog("extension loaded")
return M
