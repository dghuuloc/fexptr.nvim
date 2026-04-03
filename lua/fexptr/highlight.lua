-- lua/fexptr/highlight.lua
local M = {}

local groups = {
    -- Structure
    { "FexptrHeader",      "Title" },
    { "FexptrIndent",      "Comment" },

    -- Directory
    { "FexptrDirIcon",     "Directory" },
    { "FexptrDirName",     "Directory" },

    -- File
    { "FexptrFileIcon",    "Normal" },
    { "FexptrFileName",    "Normal" },

    -- Selection
    { "FexptrSelected",    "Visual" },

    -- Indent lines and connectors
    { "FexptrIndentLine",  "Comment" },
    { "FexptrConnector",   "Comment" },

    -- Parent entry (..)
    { "FexptrParent",      "Special" },

    -- Symlink
    { "FexptrSymlink",     "Constant" },

    -- Git status
    { "FexptrGitModified",  "Changed" },
    { "FexptrGitAdded",     "Added" },
    { "FexptrGitDeleted",   "Removed" },
    { "FexptrGitRenamed",   "Changed" },
    { "FexptrGitUntracked", "Added" },
    { "FexptrGitUnmerged",  "DiagnosticError" },
    { "FexptrGitIgnored",   "Comment" },

    -- Diagnostics (name colour + virtual icon)
    { "FexptrDiagError",   "DiagnosticError" },
    { "FexptrDiagWarn",    "DiagnosticWarn" },
    { "FexptrDiagHint",    "DiagnosticHint" },
    { "FexptrDiagInfo",    "DiagnosticInfo" },

    -- Filter prompt
    { "FexptrFilterPrompt", "Question" },
    { "FexptrFilterMatch",  "Search" },
}

function M.setup()
    for _, g in ipairs(groups) do
        vim.api.nvim_set_hl(0, g[1], { link = g[2], default = true })
    end
end

-- Map git status char → highlight group
M.git_hl = {
    M = "FexptrGitModified",
    A = "FexptrGitAdded",
    D = "FexptrGitDeleted",
    R = "FexptrGitRenamed",
    ["?"] = "FexptrGitUntracked",
    U = "FexptrGitUnmerged",
    ["!"] = "FexptrGitIgnored",
    C = "FexptrGitAdded",
}

-- Map severity string → highlight group
M.diag_hl = {
    error = "FexptrDiagError",
    warn  = "FexptrDiagWarn",
    hint  = "FexptrDiagHint",
    info  = "FexptrDiagInfo",
}

return M
