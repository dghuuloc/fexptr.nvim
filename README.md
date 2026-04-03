# fexptr.nvim

> **A feature-rich, native Neovim file explorer written in pure Lua**

fexptr.nvim is a lightweight, dependency-free file explorer built on Neovim's
native APIs — inspired by the simplicity of **oil.nvim** and the depth of
**nvim-tree**.

---

## ✨ Features

| Category | Feature |
|---|---|
| **Navigation** | Tree-style explorer, expand/collapse, path collapsing (`src/main/java`) |
| **Root control** | `C` to cd into a directory, `-` to go up, root always shown in statusline |
| **Git** | Async `git status` with file *and* directory-level indicators |
| **Diagnostics** | LSP error / warn / hint / info icons via virtual text, directory rollup |
| **Selection** | Multi-select with `<Space>`, select-all with `A`; all fs ops respect selection |
| **File ops** | Create, rename, delete (hard or **trash**), copy, cut, paste |
| **Filter** | Live fuzzy filter with `f`; directories with matching children are kept visible |
| **Preview** | `P` to preview file in the adjacent window (optional auto-preview on hover) |
| **System open** | `s` to open with the OS default application |
| **Clipboard** | `Y` copies absolute path, `gn` copies filename to `+` register |
| **Float mode** | Optional floating window instead of a sidebar |
| **Auto-refresh** | libuv fs_event watcher with 400 ms debounce |
| **Configurable** | Every keymap, icon, colour, and behaviour is customisable |
| **No dependencies** | Pure Neovim Lua, zero external plugins required |

---

## 📦 Requirements

* **Neovim 0.11+**
* *(Optional)* A Nerd Font for icons
* *(Optional)* `trash-put`, `trash`, or `gio` for safe delete

---

## 📥 Installation

### lazy.nvim

```lua
{
    "dghuuloc/fexptr.nvim",
    lazy = false,
    config = function()
        require("fexptr").setup({
            width = 30,
        })
        vim.keymap.set("n", "<leader>e", "<cmd>FexptrToggle<CR>", { silent = true })
        vim.keymap.set("n", "<leader>f", "<cmd>FexptrFind<CR>",   { silent = true })
    end,
}
```

### Native (packpath)

```bash
# Linux / macOS
git clone https://github.com/dghuuloc/fexptr.nvim.git \
  ~/.local/share/nvim/site/pack/plugins/start/fexptr.nvim
```

```powershell
# Windows PowerShell
git clone https://github.com/dghuuloc/fexptr.nvim.git `
  $env:LOCALAPPDATA\nvim-data\site\pack\plugins\start\fexptr.nvim
```

---

## 🚀 Commands

| Command | Description |
|---|---|
| `:FexptrToggle` | Open or close the explorer |
| `:FexptrOpen` | Open the explorer (no-op if already open) |
| `:FexptrClose` | Close the explorer |
| `:FexptrRefresh` | Force refresh (git + diagnostics + filesystem) |
| `:FexptrFind` | Open the explorer and start a live filter |

---

## ⌨️ Default Keymaps

| Key | Action |
|---|---|
| `<CR>` / `o` | Open file / expand directory |
| `a` | Create file or directory |
| `r` | Rename file or directory |
| `d` | Delete / trash |
| `y` | Copy |
| `x` | Cut |
| `p` | Paste |
| `q` | Close explorer |
| `H` | Toggle hidden files |
| `C` | Change root to selected directory |
| `-` | Go up to parent directory |
| `<Space>` | Toggle selection on current node |
| `A` | Select all / deselect all |
| `Y` | Copy absolute path to clipboard |
| `gn` | Copy filename to clipboard |
| `s` | System open (OS default app) |
| `f` | Start live filter |
| `<Esc>` | Clear filter |
| `R` | Refresh |
| `P` | Preview file in adjacent window |

---

## ⚙️ Configuration

Call `setup()` **once** during startup.  All keys are optional.

```lua
require("fexptr").setup({
    width       = 30,          -- sidebar width in columns
    show_hidden = false,       -- show dotfiles by default

    folder_indicators = {
        open = "▾",
        closed = "▸",
    },

    icons = {
        folder_open = "",
        folder_closed = "",
        file = "󰈙",
    },

    -- Optional floating window (replaces the sidebar)
    float = {
        enabled = false,
        width   = 0.5,         -- fraction of editor width
        height  = 0.8,
        border  = "rounded",
    },

    -- File preview in adjacent window
    preview = {
        enabled = false,       -- true = auto-preview on CursorMoved
    },

    -- Git status indicators
    git = {
        enabled        = true,
        show_untracked = true,
    },

    -- LSP diagnostics
    diagnostics = {
        enabled = true,
    },

    -- Trash support (safe delete)
    trash = {
        enabled = true,        -- false = always hard-delete
        cmd     = nil,         -- override, e.g. { "trash-put" }
    },

    icons = {
        folder_closed = "",
        folder_open   = "",
        file          = "󰈙",
        git_status = {
            M = "✗", A = "✓", D = "", R = "➜",
            ["?"] = "★", U = "", ["!"] = "◌",
        },
        diagnostics = {
            error = "", warn = "", hint = "", info = "",
        },
    },

    -- Every key can be a string, a table of strings, or false to disable
    keymaps = {
        open          = { "<CR>", "o" },
        create        = "a",
        rename        = "r",
        delete        = "d",
        copy          = "y",
        cut           = "x",
        paste         = "p",
        quit          = "q",
        toggle_hidden = "H",
        cd            = "C",
        parent        = "-",
        select        = "<Space>",
        select_all    = "A",
        copy_path     = "Y",
        copy_name     = "gn",
        system_open   = "s",
        filter        = "f",
        clear_filter  = "<Esc>",
        refresh       = "R",
        preview       = "P",
    },
})
```

---

## 🎨 Highlight Groups

All groups link to sensible builtins by default and can be overridden:

| Group | Default link |
|---|---|
| `FexptrHeader` | `Title` |
| `FexptrDirIcon` / `FexptrDirName` | `Directory` |
| `FexptrFileIcon` / `FexptrFileName` | `Normal` |
| `FexptrSelected` | `Visual` |
| `FexptrGitModified` | `Changed` |
| `FexptrGitAdded` | `Added` |
| `FexptrGitDeleted` | `Removed` |
| `FexptrGitUntracked` | `Added` |
| `FexptrGitUnmerged` | `DiagnosticError` |
| `FexptrGitIgnored` | `Comment` |
| `FexptrDiagError/Warn/Hint/Info` | `DiagnosticError/Warn/Hint/Info` |

---

## 🏗️ Architecture

```
plugin/fexptr.lua           ← registers :Fexptr* user commands
lua/fexptr/
  init.lua                  ← public API + DiagnosticChanged autocmd
  config.lua                ← defaults + setup() merger
  state.lua                 ← shared mutable runtime state
  highlight.lua             ← nvim_set_hl definitions
  git.lua                   ← async git status (vim.loop.spawn)
  diagnostics.lua           ← vim.diagnostic aggregation
  fs.lua                    ← scandir, copy_recursive, trash
  tree.lua                  ← flat node list builder (filter + collapsing)
  preview.lua               ← read-only file preview in adjacent window
  core.lua                  ← window lifecycle, render(), fs_event watcher
  actions/
    init.lua                ← re-exports nav + fs
    nav.lua                 ← open, cd, parent, select, filter, …
    fs.lua                  ← create, rename, delete, copy, paste
```

---

## 📖 Help

After installing, generate help tags once:

```vim
:helptags ALL
```

Then access docs with:

```vim
:help fexptr
```

---

## License

MIT © dghuuloc
