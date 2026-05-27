local M = {
    alloc = memory.new,
    free = memory.delete,
    memcpy = function (dst, src, n)
        if n<=0 then return end
        memory.writebytes(dst, memory.readbytes(src, n))
    end,
    
    -- verbose = true
}
function M.realloc(addr, n)
    local new_ptr = n>0 and M.alloc(n)
    if addr and addr~=0 then
        M.memcpy(new_ptr, addr, n)
        M.free(addr)
    end
    return new_ptr
end

local relative = ... and (...):gsub("declarator$", "") or ""
local merge_table = require(relative.."utils").merge_table

local Primitive = {
    int     = { size = 4,   reader = memory.readint,    writer = memory.writeint },
    uint    = { size = 4,   reader = memory.readint,    writer = memory.writeint },
    short   = { size = 2,   reader = memory.readshort,  writer = memory.writeshort },
    ushort  = { size = 2,   reader = memory.readshort,  writer = memory.writeshort },
    float   = { size = 4,   reader = memory.readfloat,  writer = memory.writefloat },
    double  = { size = 8,   reader = memory.readdouble, writer = memory.writedouble },
    char    = { size = 1,
                reader = function(p) return string.unpack("<b", memory.readbytes(p, 1)) end,
                writer = function(p,v) memory.writebytes(p, string.pack("<b", v)) end
            },
    uchar   = { size = 1,
                reader = function(p) return string.unpack("<B", memory.readbytes(p, 1)) end,
                writer = function(p,v) memory.writebytes(p, string.pack("<B", v)) end
            },
    bool    = { size = 1,
                reader = function(p) return memory.readbytes(p, 1) ~= "\x00" end,
                writer = function(p,v) memory.writebytes(p, v==true and "\x01" or "\x00") end
            },
    ptr     = { size = 4,   reader = memory.readint,    writer = memory.writeint },

    -- Vector2f= { size = 8,
    --             reader = soku.Vector2f.fromPtr,
    --             writer = function (p, v) memory.writefloat(p, v.x); memory.writefloat(p+0x4, v.y) end,
    -- }

}

local Templates = { }
function M.template(typename, def_generator)
    -- if type(def_generator)=="table" then
    --     def_generator = function ()
    --         return def_generator
    --     end
    -- end
    Templates[typename] = setmetatable({
        generator = def_generator,
    },{
        __call = function (t, ...)
            return t.generator(...)
        end
    })
    return def_generator
end
function M.get_template(tpname)
    return Templates[tpname]
end

local Classes = {
    Vector2s = {
        size = 0x4,
        fields = {
            x = {offset=0, type="short"},
            y = {offset=2, type="short"},
        }
    },
    Vector2f = {
        size = 0x8,
        fields = {
            x = {offset=0, type="float"},
            y = {offset=4, type="float"},
        }
    },
    Vector2i = {
        size = 0x8,
        fields = {
            x = {offset=0, type="int"},
            y = {offset=4, type="int"},
        }
    },
}
function M.define(typename, def)
    Classes[typename] = def
    Classes[typename].typename = typename
    return def
end
function M.derive(basename, typename, def_override)
    if not Classes[basename] then
        error("Deriving failed, base type not defined")
    end
    Classes[typename] = merge_table(def_override, Classes[basename], true)
    Classes[typename].typename = typename
    return Classes[typename]
end
function M.get_define(typename)
    return Classes[typename] or Primitive[typename]
end
function M.isDefined(typename)
    return M.get_define(typename)~=nil
end

function M.sizeof(typename)
    return Classes[typename] and Classes[typename].size or Primitive[typename] and Primitive[typename].size
end

M.default_meta = {}
local function create_instance(typeDef, basePtr)
    if not typeDef or not basePtr or basePtr==0 then
        return nil
    end
    local inst = {
        basePtr = basePtr,
        typeDef = typeDef
    }
    return setmetatable(inst, merge_table(typeDef.meta, M.default_meta))
end
M.default_meta = {
    __index = function(self, key)
        local typeDef = rawget(self, "typeDef")
        local basePtr = rawget(self, "basePtr")
        local methods = typeDef.methods
        if methods and methods[key] then
            return methods[key]
        end
        
        local f = typeDef.fields[key]
        if not f then 
            if typeDef.static and typeDef.static[key] then -- static
                return typeDef.static[key]
            end
            error(string.format("type '%s': do not has field '%s'", typeDef.typename, key), 0)
        end
        
        local addr = basePtr + f.offset
        local t = f.type
        
        -- 基础类型
        if Primitive[t] then
            return Primitive[t].reader(addr)
        end
        
        -- 指针
        if f.isPtr then
            local p = Primitive.ptr.reader(addr)
            if p == 0 then return nil end
            return create_instance(Classes[t], p)
        end
        
        -- struct
        return create_instance(Classes[t], addr)
    end,
    __newindex = function(self, key, value)
        local typeDef = rawget(self, "typeDef")
        local basePtr = rawget(self, "basePtr")
        local f = typeDef.fields[key]
        if not f then 
            if typeDef.static[key] then -- static
                typeDef.static[key] = value
            end
            return
        end

        local addr = basePtr + f.offset
        local t = f.type

        if Primitive[t] then
            return Primitive[t].writer(addr, value)
        elseif f.isPtr then
            if type(value)=="number" then
                return Primitive.ptr.writer(addr, value)
            elseif not value then
                return Primitive.ptr.writer(addr, 0)
            elseif type(value)=="table" and value.typeDef then
                if value.typeDef.typename~=f.type then
                    error("instance type mismatch")
                end
                return Primitive.ptr.writer(addr, value.basePtr)
            end
        end
        
        error("cannot assign struct directly: "..key)
    end
}

M.default_init = function (self)
    memory.writebytes(self.basePtr, string.rep("\0", self.typeDef.size))
end

function M.fromPtr(name, ptr)
    if Classes[name] then
        return create_instance(Classes[name], ptr)
    elseif Primitive[name] and Primitive[name].reader then
        return Primitive[name].reader(ptr)
    end
end

return M, M.verbose and print(relative.."declarator")