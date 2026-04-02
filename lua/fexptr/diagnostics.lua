-- lua/fexptr/diagnostics.lua
--
-- Aggregates LSP diagnostics from all open buffers and exposes a
-- per-path severity lookup used by core.render().

local state = require("fexptr.state")

local M = {}

-- Severity rank: lower is worse (ERROR = 1, WARN = 2, HINT = 3, INFO = 4)
local SEVERITY_NAME = {
    [vim.diagnostic.severity.ERROR] = "error",
    [vim.diagnostic.severity.WARN]  = "warn",
    [vim.diagnostic.severity.HINT]  = "hint",
    [vim.diagnostic.severity.INFO]  = "info",
}

---Rebuild state.diagnostics from currently open buffers.
function M.refresh()
    if not require("fexptr.config").values.diagnostics.enabled then
        state.diagnostics = {}
        return
    end

    local diags = {}
    for _, d in ipairs(vim.diagnostic.get(nil)) do
        local name = vim.api.nvim_buf_get_name(d.bufnr)
        if name ~= "" then
            if not diags[name] then
                diags[name] = { errors = 0, warnings = 0, hints = 0, info = 0 }
            end
            local s = d.severity
            if s == vim.diagnostic.severity.ERROR then
                diags[name].errors = diags[name].errors + 1
            elseif s == vim.diagnostic.severity.WARN then
                diags[name].warnings = diags[name].warnings + 1
            elseif s == vim.diagnostic.severity.HINT then
                diags[name].hints = diags[name].hints + 1
            else
                diags[name].info = diags[name].info + 1
            end
        end
    end

    state.diagnostics = diags
end

---Return the worst severity string for `path`, checking children for dirs.
---@param path   string
---@param is_dir boolean
---@return "error"|"warn"|"hint"|"info"|nil
function M.get(path, is_dir)
    if is_dir then
        local prefix = path:sub(-1) == "/" and path or path .. "/"
        local worst  = nil
        for p, counts in pairs(state.diagnostics) do
            if p:sub(1, #prefix) == prefix or p == path then
                if counts.errors   > 0 then return "error" end
                if counts.warnings > 0 then worst = "warn" end
                if counts.hints    > 0 and worst ~= "warn" then worst = "hint" end
            end
        end
        return worst
    else
        local d = state.diagnostics[path]
        if not d then return nil end
        if d.errors   > 0 then return "error" end
        if d.warnings > 0 then return "warn" end
        if d.hints    > 0 then return "hint" end
        if d.info     > 0 then return "info" end
        return nil
    end
end

return M
