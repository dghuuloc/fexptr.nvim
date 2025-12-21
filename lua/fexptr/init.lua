-- lua/fexptr/init.lua
local core = require("fexptr.core")

local did_setup = false
local M = {}

function M.setup(opts)
    if did_setup then return end
    did_setup = true
    require("fexptr.config").setup(opts)
end

function M.toggle()
    require("fexptr.core").toggle()
end

return M
