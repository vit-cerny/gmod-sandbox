-- gmodSandbox.lua - GMod-style sandbox for BeamNG.drive (melty "gmod x beamng" mashup, v1.1)
-- Namespace: extensions.core_gmodSandbox (loaded by scripts/gmod_sandbox/modScript.lua).
-- One extension owns the physgun, the spawn menu and the spawn helpers, so the whole
-- sandbox ships as a single mod. Extra tools live in gmodTools, NPC AI in gmodNpcs,
-- the overlay in gmodHud.
--
-- Physgun: aim with the camera, hold LMB/G to grab ANY object (props, cars), release to
-- drop/fling. Forces are mass-scaled. RMB/V explodes the target. Q opens the spawn menu.
-- The published menu only lists content that may ship: the game's own props BY NAME and
-- our generated lookalikes (gms_*). GMod/Valve imports stay in separate local-only mods.

local M = {}

local logTag = "gmodSandbox"
local grabbedId = nil
local holdDist = 3.5
local grabRange = 12.0
local K_PER_KG = 120.0
local D_PER_KG = 15.0
local CAP_PER_KG = 50.0
local spawnIndex = 0
local vehicleIndex = 0
local im = ui_imgui
local showMenu = im.BoolPtr(false)

-- ---------------------------------------------------------------------------
-- Spawn catalogue (license-clean). Each entry: { label, model, config|nil }.
-- config is the exact .pc path; the game's own props do not follow the
-- <model>/<model>.pc convention, so it is spelled out here.
-- ---------------------------------------------------------------------------
local GAME_PROPS = {
  { "Wood Crate",    "woodcrate",     "vehicles/woodcrate/large.pc" },
  { "Barrels",       "barrels",       "vehicles/barrels/empty.pc" },
  { "Traffic Barrel","trafficbarrel", "vehicles/trafficbarrel/standard.pc" },
  { "Cones",         "cones",         "vehicles/cones/large.pc" },
  { "Trash Bin",     "trashbin",      "vehicles/trashbin/default.pc" },
  { "Cardboard Box", "cardboard_box", "vehicles/cardboard_box/large.pc" },
  { "Couch",         "couch",         "vehicles/couch/couch_free.pc" },
  { "Piano",         "piano",         "vehicles/piano/standard.pc" },
  { "Porta Potty",   "porta_potty",   "vehicles/porta_potty/default.pc" },
  { "Large Tire",    "large_tire",    "vehicles/large_tire/tire_loader.pc" },
  { "Metal Box",     "metal_box",     "vehicles/metal_box/empty.pc" },
  { "Tire Stack",    "tirestacks",    "vehicles/tirestacks/6tires.pc" },
}

local GMS_PROPS = {
  { "Sandbox Melon", "gms_melon",  "vehicles/gms_melon/gms_melon.pc" },
  { "Sandbox Crate", "gms_crate",  "vehicles/gms_crate/gms_crate.pc" },
  { "Sandbox Barrel","gms_barrel", "vehicles/gms_barrel/gms_barrel.pc" },
  { "Sandbox Tire",  "gms_tire",   "vehicles/gms_tire/gms_tire.pc" },
}

local NPC_ITEMS = {
  { "Nextbot", "gms_nextbot", "vehicles/gms_nextbot/gms_nextbot.pc" },
}

local VEHICLES = { "barstow", "bolide", "bx", "citybus", "pickup", "etk800",
                   "covet", "roamer", "van", "midsize", "pessima", "wendover" }

local function dlog(msg) pcall(log, "I", logTag, msg) end

local function toast(t, msg)
  guihooks.trigger("toastrMsg", {
    type = t, title = "GMod Sandbox", msg = msg,
    config = { timeOut = 2200, extendedTimeOut = 800 },
  })
end

local function getAim()
  local pos, fwd = nil, nil
  local ok1, p = pcall(core_camera.getPosition)
  if ok1 and p then pos = p end
  local ok2, f = pcall(core_camera.getForward)
  if ok2 and f then fwd = f end
  if not (pos and fwd) then
    local veh = getPlayerVehicle(0)
    if veh then
      pos = pos or (veh:getPosition() + vec3(0, 0, 1.2))
      fwd = fwd or veh:getDirectionVector()
    end
  end
  return pos, fwd
end

local function playerId()
  local veh = getPlayerVehicle(0)
  if veh then return veh:getID() end
  return -1
end

-- The walking body (unicycle) is the player, never a target.
local function jbeam(o)
  if not (o and o.getJBeamFilename) then return "" end
  local ok, jb = pcall(function() return o:getJBeamFilename() end)
  return (ok and jb) or ""
end

local function isPlayerObject(o)
  if o:getID() == playerId() then return true end
  return jbeam(o) == "unicycle"
end

local function findTarget(range, minDot)
  local pos, fwd = getAim()
  if not (pos and fwd) then return nil, nil end
  local best, bestDist = nil, math.huge
  for i = 0, be:getObjectCount() - 1 do
    local o = be:getObject(i)
    if o and not isPlayerObject(o) then
      local jb = jbeam(o)
      if jb ~= "" then
        local to = o:getPosition() - pos
        local dist = to:length()
        if dist > 0.3 and dist < range and to:normalized():dot(fwd) > minDot and dist < bestDist then
          best, bestDist = o, dist
        end
      end
    end
  end
  return best, bestDist
end

-- Hold command, v1.1: the object is captured once (node ids + offsets from the
-- node centroid); afterwards every node is sprung toward holdPoint + Rot(delta)*offset.
-- The rotation delta is taken from the camera, so the held object's angles follow
-- the mouse (the GMod physgun feel from the reference video). Objects with many
-- nodes (cars) fall back to translation-only so the per-frame command stays small.
local HOLD_CMD = [[
if obj and v and v.data and v.data.nodes then
  if not _gmodSandboxInit then
    _gmodSandboxInit = true
    _gmodSandboxIds, _gmodSandboxOffs = {}, {}
    local n, cx, cy, cz, m = 0, 0, 0, 0, 0
    for _, nd in pairs(v.data.nodes) do
      local okp, p = pcall(obj.getNodePosition, obj, nd.cid)
      local okm, mm = pcall(obj.getNodeMass, obj, nd.cid)
      if okp and p then
        _gmodSandboxIds[#_gmodSandboxIds + 1] = nd.cid
        _gmodSandboxOffs[#_gmodSandboxOffs + 1] = p.x
        _gmodSandboxOffs[#_gmodSandboxOffs + 1] = p.y
        _gmodSandboxOffs[#_gmodSandboxOffs + 1] = p.z
        cx = cx + p.x; cy = cy + p.y; cz = cz + p.z; n = n + 1
      end
      if okm and mm then m = m + mm end
    end
    if n < 1 then return end
    _gmodSandboxN = n
    _gmodSandboxMass = (m > 1) and m or 500
    _gmodSandboxRot = (n <= 32)
    for i = 1, n do
      _gmodSandboxOffs[3 * i - 2] = _gmodSandboxOffs[3 * i - 2] - cx / n
      _gmodSandboxOffs[3 * i - 1] = _gmodSandboxOffs[3 * i - 1] - cy / n
      _gmodSandboxOffs[3 * i]     = _gmodSandboxOffs[3 * i]     - cz / n
    end
  end
  local n = _gmodSandboxN or 0
  if n > 0 then
    local hp = vec3(%f, %f, %f)
    local k = %f * _gmodSandboxMass / n
    local d = %f * _gmodSandboxMass / n
    local cap = %f * _gmodSandboxMass / n
    local qx, qy, qz, qw = %f, %f, %f, %f
    for i = 1, n do
      local cid = _gmodSandboxIds[i]
      local ox = _gmodSandboxOffs[3 * i - 2]
      local oy = _gmodSandboxOffs[3 * i - 1]
      local oz = _gmodSandboxOffs[3 * i]
      if _gmodSandboxRot then
        local tx = 2 * (qy * oz - qz * oy + qw * ox)
        local ty = 2 * (qz * ox - qx * oz + qw * oy)
        local tz = 2 * (qx * oy - qy * ox + qw * oz)
        local rx = ox + qw * tx + (qy * tz - qz * ty)
        local ry = oy + qw * ty + (qz * tx - qx * tz)
        local rz = oz + qw * tz + (qx * ty - qy * tx)
        ox, oy, oz = rx, ry, rz
      end
      local p = obj:getNodePosition(cid)
      local vel = obj:getNodeVelocityVector(cid)
      local force = vec3(hp.x + ox - p.x, hp.y + oy - p.y, hp.z + oz - p.z) * k - vel * d
      local mm = force:length()
      if mm > cap then force = force:normalized() * cap end
      obj:applyForceVector(cid, force)
    end
  end
end
]]

local GRAB_CAM_QUAT = nil

local function camQuat()
  local ok, q = pcall(core_camera.getQuat)
  if ok and q then return q end
  return quat(0, 0, 0, 1)
end

local function conj(q)
  return quat(-q.x, -q.y, -q.z, q.w)
end

local VM_RESET = "_gmodSandboxInit=nil; _gmodSandboxMass=nil; _gmodSandboxIds=nil; " ..
                 "_gmodSandboxOffs=nil; _gmodSandboxN=nil; _gmodSandboxRot=nil"

local function sendHold(o, hp)
  local q = camQuat()
  local dq = q * conj(GRAB_CAM_QUAT or q)
  o:queueLuaCommand(string.format(HOLD_CMD, hp.x, hp.y, hp.z, K_PER_KG, D_PER_KG, CAP_PER_KG,
                                  dq.x, dq.y, dq.z, dq.w))
end

-- Spawn a model in front of the view. config may be nil (vehicles pick a default).
function M.spawn(model, config)
  local pos, fwd = getAim()
  if not (pos and fwd) then
    toast("warning", "No spawn position.")
    return
  end
  local p = pos + fwd * 4.0 + vec3(0, 0, 0.8)
  local opt = { pos = p, rot = quat(0, 0, 0, 1) }
  if config then opt.config = config end
  local ok, err = pcall(function()
    core_vehicles.spawnNewVehicle(model, opt)
  end)
  if ok then
    dlog("spawned " .. model)
    toast("success", "Spawned " .. model)
  else
    dlog("spawn failed " .. model .. ": " .. tostring(err))
    toast("error", "Spawn failed: " .. tostring(err))
  end
end

function M.grab()
  if grabbedId then return end
  local t = findTarget(grabRange, 0.5)
  if not t then
    toast("warning", "Nothing to grab in front - spawn something with Q.")
    return
  end
  grabbedId = t:getID()
  GRAB_CAM_QUAT = camQuat()
  pcall(function() t:queueLuaCommand(VM_RESET) end)
  dlog("grabbed " .. tostring(t:getJBeamFilename()) .. " id=" .. tostring(grabbedId))
  toast("success", "Grabbed " .. tostring(t:getJBeamFilename()))
end

function M.release()
  if not grabbedId then return end
  local o = be:getObjectByID(grabbedId)
  if o then pcall(function() o:queueLuaCommand(VM_RESET) end) end
  dlog("released id=" .. tostring(grabbedId))
  grabbedId = nil
  toast("success", "Released")
end

function M.distance(delta)
  holdDist = math.max(1.5, math.min(12.0, holdDist + delta))
  toast("info", string.format("Physgun distance: %.1f m", holdDist))
end

function M.shoot()
  local t, dist = findTarget(80.0, 0.85)
  if not t then
    toast("warning", "Nothing in your crosshair.")
    return
  end
  t:queueLuaCommand("fire.explodeVehicle()")
  t:queueLuaCommand("beamstate.breakAllBreakgroups()")
  dlog("shot " .. tostring(t:getJBeamFilename()) .. " id=" .. tostring(t:getID()) ..
       " dist=" .. string.format("%.1f", dist or -1))
  toast("success", "Boom: " .. tostring(t:getJBeamFilename()))
end

function M.spawnGameProp()
  spawnIndex = spawnIndex + 1
  if spawnIndex > #GAME_PROPS then spawnIndex = 1 end
  local it = GAME_PROPS[spawnIndex]
  M.spawn(it[2], it[3])
end

function M.spawnGmsProp()
  spawnIndex = spawnIndex + 1
  if spawnIndex > #GMS_PROPS then spawnIndex = 1 end
  local it = GMS_PROPS[spawnIndex]
  M.spawn(it[2], it[3])
end

function M.spawnNextbot()
  M.spawn(NPC_ITEMS[1][2], NPC_ITEMS[1][3])
end

function M.spawnVehicle()
  vehicleIndex = vehicleIndex + 1
  if vehicleIndex > #VEHICLES then vehicleIndex = 1 end
  M.spawn(VEHICLES[vehicleIndex], nil)
end

-- Tools delegate to the other extensions when they are loaded.
local function callExt(name, fn)
  local ext = extensions[name]
  if ext and ext[fn] then
    local ok, err = pcall(ext[fn])
    if not ok then dlog("tool " .. name .. "." .. fn .. " failed: " .. tostring(err)) end
  end
end

function M.punt() callExt("core_gmodTools", "punt") end
function M.toggleNoclip() callExt("core_gmodTools", "toggleNoclip") end
function M.toggleNpcs() callExt("core_gmodNpcs", "toggle") end

function M.toggleMenu()
  showMenu[0] = not showMenu[0]
  dlog("spawn menu " .. (showMenu[0] and "opened" or "closed"))
end

-- ---------------------------------------------------------------------------
-- ImGui spawn menu: Props / NPCs / Vehicles / Tools
-- ---------------------------------------------------------------------------
local function drawItems(items, perRow)
  for i, it in ipairs(items) do
    if (i - 1) % perRow ~= 0 then im.SameLine() end
    if im.Button(it[1]) then M.spawn(it[2], it[3]) end
  end
end

local function drawMenu()
  if not showMenu[0] then return end
  im.Begin("GMod Spawn Menu", showMenu, im.WindowFlags_AlwaysAutoResize)

  im.Text("Props (ours)")
  drawItems(GMS_PROPS, 4)
  im.Separator()
  im.Text("Props (game)")
  drawItems(GAME_PROPS, 4)
  im.Separator()
  im.Text("NPCs")
  drawItems(NPC_ITEMS, 4)
  im.Separator()
  im.Text("Vehicles")
  for i, model in ipairs(VEHICLES) do
    if (i - 1) % 4 ~= 0 then im.SameLine() end
    if im.Button(model) then M.spawn(model, nil) end
  end
  im.Separator()
  im.Text("Tools")
  if im.Button("Punt (R)") then M.punt() end
  im.SameLine()
  if im.Button("Nextbot (K)") then M.spawnNextbot() end
  im.SameLine()
  if im.Button("NPC chase (B)") then M.toggleNpcs() end
  im.SameLine()
  if im.Button("Noclip (J)") then M.toggleNoclip() end
  im.Separator()
  im.Text("Q close | LMB grab | RMB boom | look rotates held | N prop | H sandbox | M car | Z/X dist")
  im.End()
end

function M.onUpdate(dt)
  drawMenu()
  if not grabbedId then return end
  local o = be:getObjectByID(grabbedId)
  if not o then
    grabbedId = nil
    return
  end
  local pos, fwd = getAim()
  if not (pos and fwd) then return end
  sendHold(o, pos + fwd * holdDist)
end

M.logTag = logTag
dlog("extension loaded (v1.1)")
return M
