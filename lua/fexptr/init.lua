local config = require("fexptr.config")
local core = require("fexptr.core")
local did_setup = false

local M = {}

function M.setup(opts)
    if did_setup then
        return
    end
    did_setup = true

    -- apply config
    config.setup(opts)

    -- create commad ONLY after setup
    vim.api.nvim_create_user_command("Fexptr", function()
        core.toggle()
    end, {
    desc = "Toggle Fexptr file explorer",
})
end

return M
