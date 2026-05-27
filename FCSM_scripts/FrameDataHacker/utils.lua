local function merge_table(src, dst, deep)
    if type(dst) ~= "table" then return dst end
    if type(src) ~= "table" then return dst end
    deep = deep or false

    local result = {}
    for k, v in pairs(dst) do
        if deep and type(v) == "table" then
            -- 深拷贝子表
            result[k] = merge_table({}, v, true)
        else
            result[k] = v
        end
    end
    for k, v in pairs(src) do
        if deep and type(v) == "table" and type(result[k]) == "table" then
            result[k] = merge_table(v, result[k], true)
        else
            if deep and type(v) == "table" then
                result[k] = merge_table({}, v, true)
            else
                result[k] = v
            end
        end
    end
    return result
end

local function read_name_string_simple(addr, max_len)
    max_len = max_len or 128
    local data = memory.readbytes(addr, max_len)
    local zero_pos = data:find("\0", 1, true)
    if zero_pos then
        return data:sub(1, zero_pos - 1)
    end
    error("No null terminator found for name string")
end


return {
    merge_table = merge_table,
    convert_cstring = read_name_string_simple,
}