local relative = ... and (...):gsub("texture$", "") or ""

local M = require(relative.."vector")

local convert_cstring = require(relative.."utils").convert_cstring

local Buffer = {}
local listener0 = memory.createcallback(2, function (state, total)
    local existed = state.esi
    -- print(existed, "tex exsited,", total, "in total")
    -- Buffer._existed = existed
    -- Buffer._loadingf = nil
    -- Buffer._loadingc = nil
    -- Buffer._debug = ""
    Buffer = {
        _existed = existed,
        _loadingf = nil,
        _loadingc = nil,
        _debug = ""
    }
end)
local listener1 = memory.createcallback(0, function (state)
    local fname, cname = convert_cstring(state.eax), convert_cstring(state.ebp)
    if not Buffer._loadingc then
        Buffer[cname] = {}
    end
    -- print(cname, fname)
    Buffer._loadingf = fname; Buffer._loadingc = cname
    Buffer[cname][fname] = true
end)
local listener2 = memory.createcallback(4, function(state, pret, filename, _, _)
    local handle, ind = state.eax, state.ebx + (Buffer._existed or 0)
    if Buffer._loadingc and Buffer._loadingf and Buffer[Buffer._loadingc][Buffer._loadingf] then
        Buffer[Buffer._loadingc][Buffer._loadingf] = ind
        --[[
        Buffer._debug = Buffer._debug..string.format(
            "%s: %s; hd: %d, ix: %d\n", 
            Buffer._loadingc, Buffer._loadingf, handle, ind)
        ]]
    end
end)
memory.hookcall(0x467ad5, listener0)
memory.hooktramp(0x467bc8, 5, listener1)
memory.hooktramp(0x467c4a, 5, listener2)

--int* __thiscall CHandleManager<IDirect3DTexture9*>::LoadTexture (CHandleManager<IDirect3DTexture9*>* this, int* pId, char* pathInDat, uint* param_4, uint* param_5)
local _load_texture = memory.createfunccall(0x405030, 4, true) -- lower img loader already hooked by shady
local function load_texture(vtx, path)
    local pid = M.alloc(4); memory.writeint(pid, 0)
    path = path.."\0"
    local cpath = M.alloc(#path); memory.writebytes(cpath, path)
    _load_texture(0x89ff08, pid, cpath, 0, 0)
    local id = memory.readint(pid)
    M.free(pid); M.free(cpath)

    local index = vtx:push_back(id)
    if M.verbose then print(string.format("texture \'%s\' loaded; handle:%#08x; index:%04d", path:match("data/character/([^%s]+)\0$"), id, index)) end
    return index
end

return {
    get_tex_id = function (vtx, cname, fname)
        if not Buffer[cname] then 
            Buffer[cname] = {}    
        end
        if not Buffer[cname][fname] then -- got problem if cname~=Buffer._loadingc
            Buffer[cname][fname] = load_texture(vtx, string.format("data/character/%s/%s", cname, fname))
        end
        return Buffer[cname][fname], M.verbose and print(cname, fname, Buffer[cname][fname])
    end,

}

