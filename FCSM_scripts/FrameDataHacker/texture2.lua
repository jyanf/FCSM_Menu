local relative = ... and (...):gsub("texture2$", "") or ""

local M = require(relative.."vector")
local U = require(relative.."utils")

local Buffer = {}
local listener0 = memory.createcallback(0, function (state)
    Buffer = {
        _loadingf = nil,
        _loadingc = nil,
        _debug = ""
    }
end)
local listener1 = memory.createcallback(0, function (state)
    local fname, cname = U.convert_cstring(state.eax), U.convert_cstring(state.ecx):lower()
    local ind = state.ebp
    cname = cname:gsub("/$", "")
    if not Buffer._loadingc then
        Buffer[cname] = {} --"data/effect/"
    end
    Buffer._loadingf = fname; Buffer._loadingc = cname
    Buffer[cname][fname] = ind
end)
-- local listener2 = memory.createcallback(4, function(state, pret, filename, _, _)
--     local handle, ind = state.eax, state.ebx + (Buffer._existed or 0)
--     if Buffer._loadingc and Buffer._loadingf and Buffer[Buffer._loadingc][Buffer._loadingf] then
--         Buffer[Buffer._loadingc][Buffer._loadingf] = ind
--         --[[
--         Buffer._debug = Buffer._debug..string.format(
--             "%s: %s; hd: %d, ix: %d\n", 
--             Buffer._loadingc, Buffer._loadingf, handle, ind)
--         ]]
--     end
-- end)
memory.hookcall(0x43b518, listener0, 2)
memory.hooktramp(0x43b558, 7, listener1)
-- memory.hooktramp(0x467c4a, 5, listener2)

local function load_texture(vtx, path)
    local pid = M.alloc(4); memory.writeint(pid, 0)
    path = path.."\0"
    local cpath = M.alloc(#path); memory.writebytes(cpath, path)
    U.load_texture(0x89ff08, pid, cpath, 0, 0)
    local id = memory.readint(pid)
    M.free(pid); M.free(cpath)

    local index = vtx:push_back(id)
    if M.verbose then print(string.format("texture \'%s\' loaded; handle:%#08x; index:%04d", path:match("data/([^%s]+)\0$"), id, index)) end
    return index
end

return {
    get_tex_id = function (vtx, cname, fname)
        cname = cname:lower(); --fname = fname:lower()
        if not Buffer[cname] then 
            Buffer[cname] = {}    
        end
        if not Buffer[cname][fname] then -- got problem if cname~=Buffer._loadingc
            Buffer[cname][fname] = load_texture(vtx, string.format("%s/%s", cname, fname))
        end
        return Buffer[cname][fname], M.verbose and print(cname, fname, Buffer[cname][fname])
    end,

}

