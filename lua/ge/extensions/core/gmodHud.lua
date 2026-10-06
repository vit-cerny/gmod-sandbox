-- gmodHud.lua - crosshair + key hints for the GMod x BeamNG sandbox (melty mashup)
-- Namespace: extensions.core_gmodHud
-- ImGui overlay drawn in onUpdate, following the pattern of shipped metrics.lua.

local M = {}

local logTag = "gmodHud"
local im = ui_imgui
local enabled = true
local broken = false

local pos = nil
local flags = nil

local function dlog(m)
  pcall(log, "I", logTag, m)
end

local function ensure()
  if pos then return end
  pos = im.ImVec2(0, 0)
  flags = im.WindowFlags_NoTitleBar + im.WindowFlags_NoResize + im.WindowFlags_NoMove
        + im.WindowFlags_NoScrollbar + im.WindowFlags_NoScrollWithMouse + im.WindowFlags_NoSavedSettings
        + im.WindowFlags_NoInputs + im.WindowFlags_AlwaysAutoResize
end

local function draw()
  ensure()
  local win = im.GetMainViewport()

  -- crosshair: a small window pinned to the screen centre
  pos.x = win.Pos.x + win.Size.x * 0.5 - 3
  pos.y = win.Pos.y + win.Size.y * 0.5 - 9
  im.SetNextWindowPos(pos, im.ImGuiCond_Always)
  im.Begin("##gmsCrosshair", nil, flags + im.WindowFlags_NoBackground)
  im.Text("+")
  im.End()

  -- key hints: bottom-left, subtle background
  pos.x = win.Pos.x + 14
  pos.y = win.Pos.y + win.Size.y - 34
  im.SetNextWindowPos(pos, im.ImGuiCond_Always)
  im.SetNextWindowBgAlpha(0.35)
  im.Begin("##gmsHints", nil, flags)
  im.Text("GMod: F walk | Q menu | LMB grab | RMB boom | N prop | H sandbox | M car | R punt | K nextbot | B npc | J noclip")
  im.End()
end

function M.onUpdate(dt)
  if not enabled or broken then return end
  local ok, err = pcall(draw)
  if not ok then
    broken = true
    dlog("HUD disabled after error: " .. tostring(err))
  end
end

function M.toggle()
  enabled = not enabled
end

function M.onInit()
  setExtensionUnloadMode(M, "manual")
end

M.logTag = logTag
dlog("extension loaded")
return M
