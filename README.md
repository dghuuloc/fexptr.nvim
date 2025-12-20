# fexptr.nvim

A minimal, native Neovim file explorer written in Lua.

* plugin structure like this:

```
fexptr/
├── lua/
│   └── fexptr/
│       ├── init.lua           <-- entry point pulbic API 
│       ├── state.lua          <-- shared state
│       ├── core.lua           <-- core functions: window, buffer, open, toggle, render
│       ├── actions.lua        <-- create, rename, delete, copy, paste
│       ├── tree.lua           <-- tree builder, scan directories
│       ├── utils.lua          <-- helpers: fs helpers, path utils
│       ├── ui.lua             <-- icons, formatting
│       └── config.lua         <-- default config and setup function
├── plugin/
│   └── fexptr.lua             <-- auto-load on startup if desired
└── README.md
```

### **Plugin Installation**
fextr.nvim is a plugin. Install it like any other Neovim plugin:

```
git clone https://github.com/dghuuloc/fexptr.nvim.git "$env:LOCALAPPDATA\nvim-data\site\pack\plugins\start\fexptr.nvim"
```

### **User configuration**

```lua
require("fexptr").setup({
    width = 35,
    show_hidden = true,
    icons = { folder_closed = "▶", folder_open = "▼" }
})
```
