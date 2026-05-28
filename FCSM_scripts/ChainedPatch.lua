local patched = false
local targets = {
    [0x426DBD]="\xEB\x5A\x90\x90",
}

local function patch(op)
  if patched==op then return end
  for addr, v in pairs(targets) do
    targets[addr] = memory.readbytes(addr, #v)
    memory.writebytes(addr, v)
  end 
  patched = op
end

local function chainSetAtExit(cb) -- safely set AtExit callback
  if type(cb) ~= "function" then return end
  local _OldAtExit = rawget(_G, "AtExit")
  if type(_OldAtExit) == "function" then
    AtExit = function() _OldAtExit(); cb() end
  else
    AtExit = cb
  end
end

patch(true)
chainSetAtExit(function()
  patch(false)
end)

return targets