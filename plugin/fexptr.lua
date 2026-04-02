-- plugin/fexptr.lua
if vim.g.loaded_fexptr then return end
vim.g.loaded_fexptr = true

vim.api.nvim_create_user_command("FexptrToggle",  function() require("fexptr").toggle()     end, {})
vim.api.nvim_create_user_command("FexptrOpen",    function() require("fexptr").open()       end, {})
vim.api.nvim_create_user_command("FexptrClose",   function() require("fexptr").close()      end, {})
vim.api.nvim_create_user_command("FexptrRefresh", function() require("fexptr").refresh()    end, {})
vim.api.nvim_create_user_command("FexptrFind",    function() require("fexptr").find_file()  end, {})
