local function split_chars(str)
    local result = {}
    for k = 1, #str do
        result[k] = string.byte(str, k)
    end
    return result
end
local function merge_chars(arr)
    return string.char(table.unpack(arr))
end
local function xor_decrypt(bytes)
    local src=split_chars(bytes)
    local out={}
    local sz=#src
    for i=1,sz do
        out[i]= src[sz-i+1] ~ ((i-1)*7) & 0xFF
    end
    return merge_chars(out)
end
local _decompress= memory.createfunccall(0x409ab0, 4, false)
local Decompress = function (sourceBytes, bufferSize)
    sourceBytes = xor_decrypt(sourceBytes)
	bufferSize= bufferSize or 0x80000
    local pt, ps = memory.new(bufferSize), memory.new(bufferSize)
    memory.writebytes(ps, sourceBytes)
	local targetBytes= _decompress(ps, #sourceBytes, pt, bufferSize)
    local result=nil
    if targetBytes>0 then
        result= memory.readbytes(pt, targetBytes)
    end
    memory.delete(pt); memory.delete(ps)
    return result
end

local function xor_encrypt(bytes)
    local src=split_chars(bytes)
    local out={}
    local sz=#src
    for i=1,sz do
        out[sz-i+1]= src[i] ~ (((i-1)*7)&0xFF)
    end
    return merge_chars(out)

end
local _compress=memory.createfunccall(0x409a10, 4, false)
local Compress=function(sourceBytes, bufferSize)
    bufferSize=bufferSize or 0x80000
    local pt, ps = memory.new(bufferSize), memory.new(bufferSize)
    memory.writebytes(ps, sourceBytes)
    local compressedBytes= _compress(ps, #sourceBytes, pt, bufferSize)
    local result=nil
    if compressedBytes>0 then
        result=memory.readbytes(pt, compressedBytes)
        result=xor_encrypt(result)
    end
    memory.delete(ps)
    memory.delete(pt)
    return result
end

return {
    FromFile= function (name)
        local f = io.open(name, "rb")
        if not f then return end
        local raw = f:read("a"); f:close()
        print("FromFile: raw data size", #raw)
        return Decompress(raw)
    end,
    ToFile= function (name, d)
        local raw = Compress(d)
        local f = io.open(name, "wb")
        if not f then return end
        print("ToFile: raw size", #raw)
        f:write(raw); f:close()
    end
}
