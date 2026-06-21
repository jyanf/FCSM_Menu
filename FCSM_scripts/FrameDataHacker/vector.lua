local relative = ... and (...):gsub("vector$", "") or ""
local M = require(relative.."declarator")

local function vector_define (value_type)
    return {
        -- abstract = true,
        size = 0x10,
        static = {
            value_type = value_type,
            element_size = M.sizeof(value_type),
            --mmReserveTexturesVector(std::vector *this,uint count,int mmAssignValue)
            -- _resize = memory.createfunccall(0x4667d0, 2, true), --vector<int>::resize
        },
        fields = {
            first = {offset=0x4, type="ptr"},
            last = {offset=0x8, type="ptr"},
            _end = {offset=0xC, type="ptr"}
        },
        methods = {
            size = function (self)
                if self.first==0 then return 0 end
                return (self.last-self.first)//self.element_size
            end,
            capacity = function (self)
                if self.first==0 then return 0 end
                return (self._end-self.first)//self.element_size
            end,
            at = function (self, i)
                local count = self:size()
                if count>=0 then
                    if i>=0 and i<count then
                        return M.fromPtr(self.value_type, self.first+self.element_size*i)
                    elseif i<0 and -i<=count then
                        return M.fromPtr(self.value_type, self.last+i*self.element_size)
                    end
                end
                -- error(string.format("invalid index %d on size %d vecotr.", i, count))
            end,

            _realloc = function (self, N)
                local new_bytes = N * self.element_size
                local csize = self:size()
                local new_ptr = M.realloc(self.first, new_bytes)

                self.first = new_ptr
                self.last  = new_ptr + csize * self.element_size
                self._end = new_ptr + new_bytes
            end,
            reserve = function (self, N)
                local cap = self:capacity()
                if N <= cap then
                    return
                end
                -- 智能增长
                local new_cap
                if cap == 0 then
                    new_cap = math.max(N, 1)
                else
                    local grown = math.floor(cap * 1.5)
                    new_cap = math.max(N, grown)
                end
                
                self:_realloc(new_cap)
            end,
            resize = function (self, N, initer)
                -- self._resize(self.basePtr, N*math.ceil(self.element_size/0x4), 0)
                ---[[
                local old_size = self:size()
                self:reserve(N)
                self.last = self.first + self.element_size*N
                local def = M.get_define(self.value_type)
                if def.writer then
                    initer = initer or 0
                    for i=old_size,N-1 do    
                        self[i] = initer
                    end
                elseif def.typename then--class
                    initer = initer or def.methods.init or M.default_init
                    for i=old_size,N-1 do
                        initer(self[i])
                    end
                end
                --]]
            end,
            
            push_back = function (self, value)
                local count = self:size()
                self:resize(count + 1)
                self[-1] = value
                return count
            end,
            erase = function (self, index)
                if not self[index] then return end
                local esize, first, last = self.element_size, self.first, self.last
                local target = self.first+index*esize
                local next = target + esize
                local move_size = last - next
                if move_size > 0 then
                    M.memcpy(target, next, move_size)
                end
                self.last = last - esize
                return true
            end,
            clear = function (self)
                self.last = self.first
            end
        },
        meta = {
            __index = function (self, k)
                if type(k)=="number" then
                    return self:at(k)
                else
                    return M.default_meta.__index(self, k)
                end
            end,
            __newindex = function (self, k, v)
            if type(k)=="number" then
                local count = self:size()
                local def = M.get_define(self.value_type)
                if def.writer then--primtive
                    if k>=0 and k<count then
                        def.writer(self.first+self.element_size*k, v)
                    elseif k<0 and -k<=count then
                        def.writer(self.last+k*self.element_size, v)
                    end
                end
            else
                return M.default_meta.__newindex(self, k, v)
            end
        end
        }
    }
end

M.template("vector<>", vector_define)

M.define("vector<int>", M.get_template("vector<>")("int"))
-- M.derive("vector<int>", "vector<int>", {
--     -- specified template instantiation
--     meta = {
--         __newindex = function (self, k, v)
--             if type(k)=="number" then
--                 local count = self:size()
--                 if k>=0 and k<count then
--                     M.get_define("int").writer(self.first+self.element_size*k, v)
--                 elseif k<0 and -k<=count then
--                     M.get_define("int").writer(self.last+k*self.element_size, v)
--                 end
--             else
--                 return M.default_meta.__newindex(self, k, v)
--             end
--         end
--     }
-- })

return M, M.verbose and print(relative.."vector")