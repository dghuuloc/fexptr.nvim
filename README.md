# fexptr.nvim

> **A minimal, native Neovim file explorer written in pure Lua**

fexptr.nvim is a lightweight, dependency-free file explorer built on Neovim’s native APIs.
It is designed to be simple, understandable, and hackable, while still providing the core features expected from a modern file explorer.

---
### ✨ Features
* 📁 Tree-style file explorer
* 🔄 Expand / collapse directories
* 🗂 Show files and folders recursively
* 🧠 State-aware (expanded folders are tracked)
* ⚡ Fast filesystem access using vim.loop
* 🪟 Opens files in a right-side split
* 🧼 No dependencies (pure Neovim Lua)
* 🧩 Modular, readable codebase (great for learning)

---
### 📦 Requirements
* **Neovim 0.11+**
* No external plugins required

---
### 📥 Installation
#### 🔹 Lazy.nvim

```lua
{
    "dghuuloc/fexptr.nvim",
    lazy = false, -- load immediately
    config = function()
        require("fexptr").setup({
            width = 30,
            show_hidden = false,
        })
    end,
}
```

or if you prefer manual keymaps:

```lua
{
    "dghuuloc/fexptr.nvim",
    lazy = false,
    config = function()
        require("fexptr").setup()
    end,
}
```

Then in your `init.lua`

```lua
vim.keymap.set("n", "<leader>e", "<cmd>FexptrToggle<CR>", { silent = true })
```

#### 🔹 Native Neovim (packpath)

* Linux/macOS

```bash
git clone https://github.com/dghuuloc/fexptr.nvim.git \
  $HOME/.local/share/nvim/site/pack/plugins/start/fexptr.nvim
```

* On Windows (PowerShell)
```powershell
git clone https://github.com/dghuuloc/fexptr.nvim.git `
  $env:LOCALAPPDATA\nvim-data\site\pack\plugins\start\fexptr.nvim

```

Restart Neovim after installation

### 🚀 Usage
**Toggle the explorer**

```vim
:FexptrToggle
```

### ⚙️ Configuration
Call `setup()` **once** during startup:

```lua
require("fexptr").setup({
    width = 35,
    show_hidden = true,
    icons = {
        folder_closed = "",
        folder_open   = "",
        file          = "",
    },
})
```

**Default configuration**
```lua
{
    width = 30,
    show_hidden = false,
    icons = {
        folder_closed = "",
        folder_open   = "",
        file          = "󰈙",
    },
}
```

### Default Keymaps
- `<CR>` / `o` – open
- `a` – create
- `r` – rename
- `d` – delete
- `y` – copy
- `x` – cut
- `p` – paste
- `q` – quit

