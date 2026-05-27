local CursorMatProxy = {}
local function split(ind, wid)
    local d2 = ind % wid
    local d1 = ind // wid
    return d1, d2
end
local function comps(d1, d2, wid)
    return d1 * wid + d2
end

function CursorMatProxy.create(renderer, width, max, index, line, horz)
    if not renderer then error("CursorMatProxy.create: need renderer as argument.") end
    horz = horz~=false
    local rows, cols
    if horz then
        cols = line
        rows = math.ceil(max/ cols)
    else
        rows = line
        cols = math.ceil(max/ rows)
    end
    local mat = {
        renderer = renderer,
        curv = renderer:createCursorV(0, rows, 0),
        curh = renderer:createCursorH(0, cols, 0),
        cur = renderer:createCursorH(width, max, 0),
        last = 0
    }
    mat.curh.isVisible = false; mat.curv.isVisible = false
    --mat.curv.sfxId = -1; mat.curh.sfxId = -1
    mat.cur1 = horz and mat.curv or mat.curh
    mat.cur2 = horz and mat.curh or mat.curv
    mat.cur.isActive = false

    function mat:update()
        local dim2 = self.cur2.max
        local c1, c2 = self.cur1, self.cur2
        local n, ln = comps(c1.index, c2.index, dim2), self.last
        if n>=self.cur.max then
            local d1, d2 = split(n-ln, dim2)
            if d1==0 and d2~=0 then
                c2.index = d2~=dim2-1 and 0 or (self.cur.max-1)%dim2
            else
                c2.index = (self.cur.max-1)%dim2
            end
            n=comps(c1.index, c2.index, dim2)
        end
        self.cur.index = n
        self.last = n
    end
    function mat:getPosition(i)
        return self.cur:getPosition(i)        
    end
    function mat:setPosition(i, x, y)
        return self.cur:setPosition(i, x, y)
    end
    function mat:setGrid(x, y, dx, dy, rx, ry)
        local dim1, dim2 = self.cur1.max, self.cur2.max
        for i=0,dim1-1 do
            for j=0,dim2-1 do
                local ind = comps(i, j, dim2)
                if ind>=max then break end
                self.cur:setPosition(ind, x+j*dx+i*rx, y+j*dy+i*ry)
            end
        end
    end
    function mat:destroy()
        self.renderer:destroy(self.cur, self.curh, self.curv)
        self.cur = nil; self.curh = nil; self.curv = nil
        self.cur1 = nil; self.cur2 = nil
    end

    mat.cur.index = index or 0
    mat.cur1.index, mat.cur2.index = split(index, mat.cur2.max)
    mat:update()
    return setmetatable(mat, {
        __index = function(t, k)
            if k=="index" then
                return t.cur.index
            elseif k=="isActive" then
                return t.cur1.isActive and t.cur2.isActive
            elseif k=="isVisible" then
                return t.cur.isVisible
            elseif k=="sfxId" then
                return t.cur1.sfxId-- t.cur2.sfxId
            end
        end,
        __newindex = function(t, k, v)
            if k=="index" then
                -- t.cur.index = v
                t.cur1.index, t.cur2.index = split(v, t.cur2.max)
                t:update()
            elseif k=="isActive" then
                t.cur1.isActive = v; t.cur2.isActive = v
            elseif k=="isVisible" then
                t.cur.isVisible = v
            elseif k=="sfxId" then
                t.cur1.sfxId = v; t.cur2.sfxId = v
            end
        end,
    })

    
end

return setmetatable(CursorMatProxy, {
    __call = function(_, renderer, width, max, index, line, horz)
        return CursorMatProxy.create(renderer, width, max, index, line, horz)
    end
})