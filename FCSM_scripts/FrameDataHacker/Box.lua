local relative = ... and (...):gsub("Box$", "") or ""
local M = require(relative.."declarator")
require(relative.."vector")

M.define("Box", {
    size = 0x10,
    fields = {
        left = {offset=0x0, type="int"},
        top = {offset=0x4, type="int"},
        right = {offset=0x8, type="int"},
        bottom = {offset=0xC, type="int"}
    },
    methods = {
        init = M.default_init
    }
})

M.define("vector<Box>", M.get_template("vector<>")("Box"))

M.derive("vector<int>", "vector<Box*>", {})

return M