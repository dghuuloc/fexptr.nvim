-- lua/fexptr/preview.lua
--
-- Opens a read-only preview of a file in the window to the right of the
-- explorer.  Reuses the same window handle so flipping through files is
-- instant (no window creation overhead).

local api   = vim.api
local state = require("fexptr.state")

local M = {}

local MAX_PREVIEW_LINES = 500

---Find the best window to use for preview (any window that isn't the explorer).
---@return number|nil
local function target_win()
    for _, w in ipairs(api.nvim_tabpage_list_wins(0)) do
        if w ~= state.win and api.nvim_win_is_valid(w) then
            return w
        end
    end
    return nil
end

---Open a preview of `node` in the side window.
---@param node ExplorerNode|nil
function M.open(node)
    if not node or node.is_dir then
        M.close()
        return
    end

    local win = target_win()
    if not win then return end

    -- Create a fresh scratch buffer for the preview
    local buf = api.nvim_create_buf(false, true)
    vim.bo[buf].bufhidden  = "wipe"
    vim.bo[buf].modifiable = true

    -- Read up to MAX_PREVIEW_LINES lines
    local lines = {}
    local ok, f = pcall(io.open, node.path, "r")
    if ok and f then
        local count = 0
        for line in f:lines() do
            lines[#lines + 1] = line
            count = count + 1
            if count >= MAX_PREVIEW_LINES then
                lines[#lines + 1] = "... (truncated)"
                break
            end
        end
        f:close()
    else
        lines = { "[Cannot read file]" }
    end

    api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false

    -- Detect and apply filetype for syntax highlighting
    local ft = vim.filetype.match({ filename = node.path, buf = buf })
    if ft then
        vim.bo[buf].filetype = ft
    end

    -- Swap in the new buffer, record handles
    api.nvim_win_set_buf(win, buf)
    api.nvim_win_set_cursor(win, { 1, 0 })

    -- The old buf auto-wiped by bufhidden = "wipe"
    state.preview.win = win
    state.preview.buf = buf
end

---Wipe the current preview (e.g. when cursor is on a directory).
function M.close()
    if state.preview.buf and api.nvim_buf_is_valid(state.preview.buf) then
        api.nvim_buf_delete(state.preview.buf, { force = true })
    end
    state.preview.win = nil
    state.preview.buf = nil
end

return M
