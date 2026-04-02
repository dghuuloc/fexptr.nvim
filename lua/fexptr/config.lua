-- lua/fexptr/config.lua
local M = {}

M.values = {
    width       = 30,
    show_hidden = false,

    -- Floating window mode
    float = {
        enabled = false,
        width   = 0.5,    -- fraction of editor width
        height  = 0.8,    -- fraction of editor height
        border  = "rounded",
    },

    -- Preview pane (show file content in right window on hover)
    preview = {
        enabled = false,  -- set true to auto-preview on CursorMoved
    },

    -- Git integration
    git = {
        enabled       = true,
        show_untracked = true,
    },

    -- LSP diagnostics integration
    diagnostics = {
        enabled = true,
    },

    -- Trash support (safe delete)
    trash = {
        enabled = true,   -- move to trash instead of hard delete when possible
        cmd     = nil,    -- override: e.g. { "trash-put" }; nil = auto-detect
    },

    icons = {
        folder_closed = "",
        folder_open   = "",
        file          = "󰈙",
        symlink       = "",
        -- Git status indicators (shown as virtual text at end of line)
        git_status = {
            ["M"] = "✗",   -- modified
            ["A"] = "✓",   -- added / staged
            ["D"] = "",   -- deleted
            ["R"] = "➜",   -- renamed
            ["?"] = "★",   -- untracked
            ["U"] = "",   -- unmerged
            ["!"] = "◌",   -- ignored
            ["C"] = "✓",   -- copied
        },
        -- LSP diagnostic icons
        diagnostics = {
            error = "",
            warn  = "",
            hint  = "",
            info  = "",
        },
    },

    -- All keymaps configurable; set any key to false to disable it
    keymaps = {
        open          = { "<CR>", "o" },
        create        = "a",
        rename        = "r",
        delete        = "d",
        copy          = "y",
        cut           = "x",
        paste         = "p",
        quit          = "q",
        toggle_hidden = "H",
        cd            = "C",
        parent        = "-",
        select        = "<Space>",
        select_all    = "A",
        copy_path     = "Y",
        copy_name     = "gn",
        system_open   = "s",
        filter        = "f",
        clear_filter  = "<Esc>",
        refresh       = "R",
        preview       = "P",
    },
}

function M.setup(opts)
    M.values = vim.tbl_deep_extend("force", M.values, opts or {})
end

return M
