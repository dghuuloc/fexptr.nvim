-- lua/fexptr/init.lua
-- Public API.  This is the only module users should require directly.

local M          = {}
local did_setup  = false

function M.setup(opts)
    if did_setup then return end
    did_setup = true

    require("fexptr.config").setup(opts)
    require("fexptr.highlight").setup()

    -- Re-render whenever LSP diagnostics change
    vim.api.nvim_create_autocmd("DiagnosticChanged", {
        callback = function()
            local state = require("fexptr.state")
            if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
                require("fexptr.diagnostics").refresh()
                require("fexptr.core").render_deferred()
            end
        end,
    })
end

function M.toggle()
    require("fexptr.core").toggle()
end

function M.open()
    local state = require("fexptr.state")
    if not (state.win and vim.api.nvim_win_is_valid(state.win)) then
        require("fexptr.core").toggle()
    end
end

function M.close()
    local state = require("fexptr.state")
    if state.win and vim.api.nvim_win_is_valid(state.win) then
        require("fexptr.core").toggle()
    end
end

function M.refresh()
    require("fexptr.git").refresh(function()
        require("fexptr.diagnostics").refresh()
        require("fexptr.core").render()
    end)
end

---Open the explorer (if closed) and start a live filter.
function M.find_file()
    M.open()
    local state = require("fexptr.state")
    if state.win then
        vim.api.nvim_set_current_win(state.win)
        require("fexptr.actions.nav").filter()
    end
end

return M
