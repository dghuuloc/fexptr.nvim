-- lua/fextr/core.lua

local api = vim.api
local fn = vim.fn

local config = require("fexptr.config")
local state = require("fexptr.state")
local tree = require("fexptr.tree")
local actions = require("fexptr.actions")

local M = {}

function M.render()
    if not state.buf then return end

    state.cursor = api.nvim_win_get_cursor(state.win)
    state.tree = tree.build(state.root)

    local lines = {"~ " .. fn.fnamemodify(state.root, ":t"):upper()}

    for _, node in ipairs(state.tree) do
        local indent = string.rep("  ", node.depth)
        local icon = node.is_dir
            and (state.expanded[node.path] and config.values.icons.folder_open or config.values.icons.folder_closed)
            or config.values.icons.file

        lines[#lines+1] = indent .. icon .. " " .. node.name
    end

    api.nvim_buf_set_option(state.buf, "modifiable", true)
    api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
    api.nvim_buf_set_option(state.buf, "modifiable", false)

    pcall(api.nvim_win_set_cursor, state.win, state.cursor)
end

function M.toggle()
    if state.win and api.nvim_win_is_valid(state.win) then
        api.nvim_win_close(state.win, true)
        state.win, state.buf = nil, nil
        return
    end

    state.buf = api.nvim_create_buf(false, true)
    vim.bo[state.buf].buftype = "nofile"
    vim.bo[state.buf].bufhidden = "wipe"
    vim.bo[state.buf].swapfile = false

    vim.cmd("topleft " .. config.values.width .. "vsplit")
    state.win = api.nvim_get_current_win()
    api.nvim_win_set_buf(state.win, state.buf)
    vim.wo[state.win].number = false
    vim.wo[state.win].relativenumber = false
    vim.wo[state.win].signcolumn = "no"

    local map = function(lhs, rhs)
        vim.keymap.set("n", lhs, rhs, { buffer = state.buf, silent = true })
    end

    map("<CR>", actions.open)
    map("o", actions.open)
    map("a", actions.create_)
    map("r", actions.rename_)
    map("d", actions.delete_)
    map("y", function() actions.copy_(false) end)
    map("x", function() actions.copy_(true) end)
    map("p", actions.paste_)
    map("q", M.toggle)

    M.render()
end

return M
