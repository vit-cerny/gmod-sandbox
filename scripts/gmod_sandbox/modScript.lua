-- modScript.lua - auto-load the gmod_sandbox extensions.
-- Extension name core_gmodX maps to lua/ge/extensions/core/gmodX.lua.
local exts = { "core_gmodSandbox", "core_gmodNpcs", "core_gmodTools", "core_gmodHud" }
for _, name in ipairs(exts) do
  local ok, err = pcall(function()
    if extensions and extensions.load then
      extensions.load(name)
    end
  end)
  if not ok then
    print("[gmod_sandbox] failed to load " .. name .. ": " .. tostring(err))
  end
end
