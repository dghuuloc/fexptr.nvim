-- lua/fexptr/git.lua
--
-- Runs `git status --porcelain` asynchronously via vim.loop.spawn.
-- Propagates file-level status up to parent directories so folder icons
-- also get a status indicator.

local uv    = vim.loop
local state = require("fexptr.state")

local M = {}

---Parse one line of `git status --porcelain` output into (abs_path, status_char).
---Returns nil, nil when the line should be skipped.
---@param line   string
---@param root   string  absolute path of the repo root (state.root)
---@return string|nil, string|nil
local function parse_line(line, root)
    if #line < 4 then return nil, nil end

    local xy   = line:sub(1, 2)
    local path = line:sub(4)

    -- git quotes paths that contain special characters
    path = path:gsub('^"', ""):gsub('"$', "")

    -- Renamed entries look like "old -> new"; keep the new name only
    path = path:gsub(" %-> .+$", "")

    local x = xy:sub(1, 1)
    local y = xy:sub(2, 2)

    local status
    if x ~= " " and x ~= "?" then
        status = x
    elseif y == "?" then
        status = "?"
    elseif y ~= " " then
        status = y
    end

    if not status then return nil, nil end

    local full = root .. "/" .. path
    return full, status
end

---Propagate file statuses to their parent directories inside `root`.
---@param file_status table<string, string>
---@param root        string
---@return table<string, string>  merged table (files + dirs)
local function propagate(file_status, root)
    local result = vim.deepcopy(file_status)

    -- Priority order for directory status: U > M > D > R > A > C > ? > !
    local priority = { U=8, M=7, D=6, R=5, A=4, C=3, ["?"]=2, ["!"]=1 }

    for path, status in pairs(file_status) do
        local parent = vim.fn.fnamemodify(path, ":h")
        while parent and #parent > #root and parent ~= root do
            local cur = result[parent]
            if not cur or (priority[status] or 0) > (priority[cur] or 0) then
                result[parent] = status
            end
            parent = vim.fn.fnamemodify(parent, ":h")
        end
    end

    return result
end

---Run `git status --porcelain` asynchronously in state.root.
---Calls `callback()` (scheduled on the main loop) when done.
---@param callback fun()|nil
function M.refresh(callback)
    local cfg = require("fexptr.config").values
    if not cfg.git.enabled then
        if callback then vim.schedule(callback) end
        return
    end

    local stdout = uv.new_pipe(false)
    local stderr = uv.new_pipe(false)
    local output = {}

    local args = { "status", "--porcelain" }
    if cfg.git.show_untracked then
        table.insert(args, "-u")
    end

    local handle
    handle = uv.spawn("git", {
        args  = args,
        cwd   = state.root,
        stdio = { nil, stdout, stderr },
    }, function(code)
        stdout:close()
        stderr:close()
        handle:close()

        local file_status = {}
        if code == 0 then
            for _, line in ipairs(output) do
                for l in line:gmatch("[^\n]+") do
                    local full, status = parse_line(l, state.root)
                    if full then file_status[full] = status end
                end
            end
        end

        vim.schedule(function()
            state.git_status = propagate(file_status, state.root)
            if callback then callback() end
        end)
    end)

    -- git not found or not a repo
    if not handle then
        vim.schedule(function()
            state.git_status = {}
            if callback then callback() end
        end)
        return
    end

    stdout:read_start(function(_, data)
        if data then table.insert(output, data) end
    end)
    stderr:read_start(function() end) -- discard
end

return M
