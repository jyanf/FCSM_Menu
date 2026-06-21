local relative = ... and (...):gsub("CharacterPatternMap$", "") or ""
local M = require(relative.."declarator")
require(relative.."CharacterSequenceData")

M.define("map<int, CharacterSequenceData*>", {
    size = 0xC,
    static = {
        key_type = "int",
        value_type = "CharacterSequenceData*",

        -- iterator* find(map* this, iterator* out, int* key)
        _map_find = memory.createfunccall(0x43f2f0, 2, true),
        -- result* map_insert(map* this, result* out, void* kv)
        _map_insert = memory.createfunccall(0x457be0, 2, true),
        --
        _map_erase = memory.createfunccall(0x439e00, 3, true),
    },
    fields = {
        -- head = {offset=0x4, type="ptr"},
        size = {offset=0x8, type="int"},
    },
    methods = {
        _find = function (self, k)
            local pair = M.alloc(8); memory.writebytes(pair, string.rep("\0", 8))
            local key = M.alloc(4); memory.writeint(key, k)
            local out = self._map_find(self.basePtr, pair, key)
            local container, node = memory.readint(pair), memory.readint(pair+0x4)
            
            M.free(pair); M.free(key)
            --handle nullptr or not found (node==head)
            if container==0 or node==memory.readint(container+0x4) or node==0 then return end
            return node
        end,
        find = function (self, k)
            local pnode = self:_find(k)
            local pseq = pnode and memory.readint(pnode+0x10) or nil
            return pseq and M.fromPtr("CharacterSequenceData", pseq) or nil
        end,
        erase = function (self, k)
            local pnode = self:_find(k)
            if pnode then
                self._map_erase(self.basePtr, 0, 0, pnode)
            end
        end,
        _insert = function (self, k, v)
            local out = M.alloc(12); memory.writebytes(out, string.rep("\0", 12))
            local kv = M.alloc(8); memory.writeint(kv, k); memory.writeint(kv+4, v)
            self._map_insert(self.basePtr, out, kv)
            local container, cur, inserted = memory.readint(out), memory.readint(out+4), memory.readbytes(out+8, 1)=="\x01"
            M.free(out); M.free(kv)
            return inserted, cur --success
        end,
        insert = function (self, k, pseq)
            if type(pseq)=="table" and pseq.typeDef.typename=="CharacterSequenceData" then
                pseq = pseq.basePtr
            end
            if type(pseq)=="number" then
                return self:_insert(k, pseq)
            end
            error("insertion failed: no CharacterSequenceData*")
        end,

        remap = function (self, k, pseq)
            if type(pseq)=="table" and pseq.typeDef.typename=="CharacterSequenceData" then
                pseq = pseq.basePtr
            end
            if type(pseq)=="number" then
                local pnode = self:_find(k)
                if pnode then
                    memory.writeint(pnode+0x10, pseq)
                end
            end
        end
    },
    meta = {
        __index = function (self, k)
            if type(k)=="number" then
                return self:find(k)
            else
                return M.default_meta.__index(self, k)
            end
        end,
        __newindex = function (self, k, v)
            if type(k)=="number" then
                self:remap(k, v)
            else
                return M.default_meta.__newindex(self, k, v)
            end
        end
    }
})
return M, M.verbose and print(relative.."CharacterPatternMap")