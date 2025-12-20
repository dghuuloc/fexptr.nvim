-- lua/fextr/config.lua
local M = {}

M.defaults = {
    width = 30,
    -- side = "left",  -- left | right | float
    -- show_hidden = false,

    icons = {
        folder_closed = "",
        folder_open   = "",
        file          = "󰈙",
    },

    -- mappings = {
    --     open   = "<CR>",
    --     create = "a",
    --     rename = "r",
    --     delete = "d",
    --     copy   = "y",
    --     cut    = "x",
    --     paste  = "p",
    --     quit   = "q",
    -- },

    -- filters = {
    --     dotfiles = false,
    --     custom = {},
    -- },
}

-- M.options = {}
M.options = vim.deepcopy(M.defaults)

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", M.defaults, opts or {})
end

return M
