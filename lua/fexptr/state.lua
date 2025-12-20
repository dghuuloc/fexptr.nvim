local uv = vim.loop

---@type {
---  root: string,
---  win: number|nil,
---  buf: number|nil,
---  tree: ExplorerNode[],
---  expanded: table<string, boolean>,
---  clipboard: Clipboard|nil
---}
return {
  root = uv.cwd(),
  win = nil,
  buf = nil,
  tree = {},
  expanded = vim.g.fexptr_expanded or {},
  clipboard = nil,
  cursor = {1,0},
}
