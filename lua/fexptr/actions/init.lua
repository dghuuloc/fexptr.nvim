-- lua/fexptr/actions/init.lua
-- Re-export every action under a single namespace for convenience.

local nav = require("fexptr.actions.nav")
local fs  = require("fexptr.actions.fs")

return {
    -- Navigation
    open          = nav.open,
    cd            = nav.cd,
    parent        = nav.parent,
    select        = nav.select,
    select_all    = nav.select_all,
    toggle_hidden = nav.toggle_hidden,
    copy_path     = nav.copy_path,
    copy_name     = nav.copy_name,
    system_open   = nav.system_open,
    filter        = nav.filter,
    clear_filter  = nav.clear_filter,
    preview       = nav.preview,
    refresh       = nav.refresh,
    get_node      = nav.get_node,

    -- Filesystem mutations
    create        = fs.create,
    rename        = fs.rename,
    delete        = fs.delete,
    copy          = fs.copy,
    paste         = fs.paste,
}
