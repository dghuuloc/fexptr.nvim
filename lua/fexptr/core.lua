-- lua/fexptr/core.lua
local api = vim.api
local fn = vim.fn

local state = require("fexptr.state")
local tree  = require("fexptr.tree")
local ui    = require("fexptr.ui")
local config = require("fexptr.config")

local M = {}

----------------------------------------------------------------
-- Helpers
----------------------------------------------------------------
local function buf_map(buf, lhs, rhs)
    api.nvim_buf_set_keymap(buf, "n", lhs, "", {
        callback = rhs,
        noremap = true,
        silent = true,
    })
end

----------------------------------------------------------------
-- Buffer + window setup
----------------------------------------------------------------
local function setup_buffer()
    api.nvim_buf_set_option(state.buf, "buftype", "nofile")
    api.nvim_buf_set_option(state.buf, "bufhidden", "wipe")
    api.nvim_buf_set_option(state.buf, "swapfile", false)
    api.nvim_buf_set_option(state.buf, "modifiable", false)
    api.nvim_buf_set_option(state.buf, "filetype", "fexptr")
end

----------------------------------------------------------------
-- Mappings
----------------------------------------------------------------
function M.apply_mappings()
    local actions = require("fexptr.actions")
    local m = config.options.mappings

    buf_map(state.buf, m.open,   actions.open)
    buf_map(state.buf, m.rename, actions.rename)
    buf_map(state.buf, m.delete, actions.delete)
    buf_map(state.buf, m.copy,   actions.copy)
    buf_map(state.buf, m.cut,    actions.cut)
    buf_map(state.buf, m.paste,  actions.paste)

    buf_map(state.buf, m.quit, function()
        if state.win and api.nvim_win_is_valid(state.win) then
            api.nvim_win_close(state.win, true)
        end
    end)
end

----------------------------------------------------------------
-- Render
----------------------------------------------------------------
function M.render()
    state.tree = tree.build(state.root)

    local lines = { ui.root_label(state.root) }

    for _, node in ipairs(state.tree) do
        lines[#lines+1] = ui.render_node(node)
    end

    api.nvim_buf_set_option(state.buf, "modifiable", true)
    api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
    api.nvim_buf_set_option(state.buf, "modifiable", false)
end

----------------------------------------------------------------
-- Cursor → node
----------------------------------------------------------------
function M.get_node()
    if not state.flat then return nil end
    local line = api.nvim_win_get_cursor(0)[1]
    return state.flat[line]
end

----------------------------------------------------------------
-- Open split window
----------------------------------------------------------------
-- function M.open_split()
--     vim.cmd("vsplit")
-- 
--     state.win = api.nvim_get_current_win()
--     state.buf = api.nvim_create_buf(false, true)
--     api.nvim_win_set_buf(state.win, state.buf)
-- 
--     setup_buffer()
--     M.render()
--     M.apply_mappings()
-- end

----------------------------------------------------------------
-- Open floating window
----------------------------------------------------------------
-- function M.open_float()
--     local width  = math.floor(vim.o.columns * 0.6)
--     local height = math.floor(vim.o.lines * 0.6)
-- 
--     state.buf = api.nvim_create_buf(false, true)
-- 
--     state.win = api.nvim_open_win(state.buf, true, {
--         relative = "editor",
--         width = width,
--         height = height,
--         row = math.floor((vim.o.lines - height) / 2),
--         col = math.floor((vim.o.columns - width) / 2),
--         style = "minimal",
--         border = "rounded",
--     })
-- 
--     setup_buffer()
--     M.render()
--     M.apply_mappings()
-- end

----------------------------------------------------------------
-- Public entry
----------------------------------------------------------------
-- function M.open()
--     if config.options.side == "float" then
--         M.open_float()
--     else
--         M.open_split()
--     end
-- end
-- 
return M
