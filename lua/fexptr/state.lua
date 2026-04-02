-- lua/fexptr/state.lua

---@class ExplorerNode
---@field name    string   display name (may be "a/b/c" for collapsed dirs)
---@field path    string   absolute path (the deepest collapsed path for dirs)
---@field depth   number   indentation level
---@field is_dir  boolean
---@field icon    string   rendered icon character

---@class Clipboard
---@field paths string[]
---@field cut   boolean

---@type {
---  root:        string,
---  win:         number|nil,
---  buf:         number|nil,
---  tree:        ExplorerNode[],
---  expanded:    table<string, boolean>,
---  clipboard:   Clipboard|nil,
---  cursor:      number[],
---  selection:   table<string, boolean>,
---  filter:      string|nil,
---  git_status:  table<string, string>,
---  diagnostics: table<string, {errors:number,warnings:number,hints:number,info:number}>,
---  preview:     { win: number|nil, buf: number|nil },
---}
return {
    root        = vim.loop.cwd(),
    win         = nil,
    buf         = nil,
    tree        = {},
    expanded    = vim.g.fexptr_expanded or {},
    clipboard   = nil,
    cursor      = { 1, 0 },
    selection   = {},          -- { [abs_path] = true }
    filter      = nil,         -- live filter string or nil
    git_status  = {},          -- { [abs_path] = status_char }
    diagnostics = {},          -- { [abs_path] = { errors, warnings, hints, info } }
    preview     = { win = nil, buf = nil },
}
