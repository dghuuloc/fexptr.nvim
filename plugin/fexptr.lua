if vim.g.loaded_fexptr then return end
vim.g.loaded_fexptr = true

vim.api.nvim_create_user_command("FexptrToggle", function()
    require("fexptr").toggle()
end, {})

