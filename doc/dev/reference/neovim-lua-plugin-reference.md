# Neovim Lua Plugin Development Reference

> Condensed reference for AI coding assistants. Based on official Neovim docs and community best practices.

---

## 1. Core Concepts

### Lua Version
- Neovim uses **Lua 5.1 API** (typically LuaJIT). Avoid LuaJIT-only extensions (`ffi`, `jit`) unless gated:
```lua
if jit then ... end
```
- `bit` module always available via `require("bit")`.

### Module System
```lua
require("mymodule")           -- lua/mymodule.lua or lua/mymodule/init.lua
require("dir.submod")         -- lua/dir/submod.lua (. = /)
require("dir")                -- lua/dir/init.lua
```
- **Caching**: `require` caches; reload with `package.loaded['mod'] = nil`
- Search paths: all `lua/` dirs in `runtimepath`

### Runtime Directories
```
plugin/*.lua      -- Auto-executed at startup (keep lightweight!)
ftplugin/{ft}.lua -- Executed when filetype detected
lua/              -- Modules loaded via require()
after/            -- Loaded after default runtime files
```

---

## 2. Vim Namespace (`vim.*`)

### Core Modules
```lua
vim.api.nvim_*         -- Neovim API functions
vim.fn.*               -- Vimscript functions; vim.fn['auto#func']() for autoload
vim.cmd("ex command")  -- Execute Ex commands; also vim.cmd.echo('"hi"')
vim.uv                 -- libuv bindings (async I/O, timers, fs, networking)
vim.schedule(fn)       -- Defer fn to main event loop (REQUIRED in vim.uv callbacks)
vim.schedule_wrap(fn)  -- Returns function safe for async callbacks
vim.notify(msg, level) -- Show notification; level = vim.log.levels.*
vim.print(...)         -- Pretty-print (uses vim.inspect)
vim.inspect(tbl)       -- Returns string representation of table
```

### Variables
```lua
vim.g.var = val        -- g:var (global)
vim.b[bufnr].var       -- b:var (buffer); bufnr optional, 0 = current
vim.w[winid].var       -- w:var (window)
vim.t[tabid].var       -- t:var (tab)
vim.env.VAR            -- Environment variable
vim.v.var              -- v:var (Vim special variables)
```
**Gotcha**: Nested table updates require full reassignment:
```lua
local t = vim.g.mytbl; t.key = val; vim.g.mytbl = t
```

### Options
```lua
vim.o.opt = val              -- :set (global/local depending on option)
vim.go.opt = val             -- Global only
vim.bo[bufnr].opt = val      -- Buffer-local (:setlocal)
vim.wo[winid][bufnr].opt     -- Window-local
vim.opt.opt = val            -- Rich wrapper with methods
vim.opt.opt:append(val)      -- :set opt+=val
vim.opt.opt:prepend(val)     -- :set opt^=val
vim.opt.opt:remove(val)      -- :set opt-=val
vim.opt.opt:get()            -- Get actual value (not Option object)
```
`vim.opt` accepts tables for list/map options:
```lua
vim.opt.wildignore = {'*.o', '*.a'}
vim.opt.listchars = {space = '_', tab = '>~'}
```

---

## 3. Keymaps

```lua
vim.keymap.set(mode, lhs, rhs, opts)
vim.keymap.del(mode, lhs, opts)
```
- `mode`: `'n'`, `'i'`, `'v'`, `'x'`, `'s'`, `'o'`, `'t'`, `'c'`, `''` (all), or table `{'n','v'}`
- `rhs`: string (Ex command) or Lua function
- `opts`:
  - `buffer = 0|bufnr|true` — buffer-local
  - `silent = true` — suppress output
  - `expr = true` — rhs is expression, return value used
  - `desc = "..."` — description (shows in `:map`)
  - `remap = true` — allow recursive mapping (default false)

### `<Plug>` Mappings (Best Practice)
```lua
-- Plugin defines (handles mode-specific behavior):
vim.keymap.set('n', '<Plug>(MyAction)', function() print('normal') end)
vim.keymap.set('v', '<Plug>(MyAction)', function() print('visual') end)

-- User maps (won't error if plugin missing):
vim.keymap.set({'n','v'}, '<leader>a', '<Plug>(MyAction)')
```
Benefits: enforces `expr`, handles modes, detectable via `hasmapto()`.

---

## 4. Autocommands

```lua
local group = vim.api.nvim_create_augroup('MyPlugin', { clear = true })

vim.api.nvim_create_autocmd({'BufEnter', 'BufWinEnter'}, {
  group = group,
  pattern = {'*.lua', '*.vim'},  -- or buffer = bufnr
  callback = function(args)
    -- args.buf, args.file, args.match, args.data, args.event
  end,
  -- OR: command = 'echo "hi"',
  desc = 'Description',
})

-- Clear autocommands
vim.api.nvim_clear_autocmds({ group = 'MyPlugin' })
vim.api.nvim_clear_autocmds({ event = 'BufEnter', buffer = 0 })
```

---

## 5. User Commands

```lua
vim.api.nvim_create_user_command('MyCmd', function(opts)
  -- opts.args (string), opts.fargs (table), opts.bang, opts.line1, opts.line2
  -- opts.range, opts.count, opts.smods (modifiers)
end, {
  nargs = '*',  -- 0, 1, ?, *, +
  range = true, -- or '%', N
  bang = true,
  complete = function(arglead, cmdline, cursorpos)
    return {'opt1', 'opt2'}  -- or 'file', 'buffer', etc.
  end,
  desc = 'Description',
})

-- Buffer-local command
vim.api.nvim_buf_create_user_command(bufnr, 'BufCmd', fn, opts)

-- Delete commands
vim.api.nvim_del_user_command('MyCmd')
vim.api.nvim_buf_del_user_command(bufnr, 'BufCmd')
```

### Subcommand Pattern (Best Practice)
```lua
---@class Subcommand
---@field impl fun(args: string[], opts: table)
---@field complete? fun(subcmd_arg_lead: string): string[]

---@type table<string, Subcommand>
local subcommands = {
  install = {
    impl = function(args, opts) --[[ ... ]] end,
    complete = function(lead)
      return vim.tbl_filter(function(x) return x:find(lead) end, {'pkg1', 'pkg2'})
    end,
  },
  update = { impl = function(args, opts) --[[ ... ]] end },
}

vim.api.nvim_create_user_command('Rocks', function(opts)
  local subcmd = subcommands[opts.fargs[1]]
  if not subcmd then
    vim.notify('Unknown subcommand: ' .. opts.fargs[1], vim.log.levels.ERROR)
    return
  end
  subcmd.impl(vim.list_slice(opts.fargs, 2, #opts.fargs), opts)
end, {
  nargs = '+',
  complete = function(lead, cmdline, _)
    local subcmd, subcmd_lead = cmdline:match("^['<,'>]*Rocks[!]*%s+(%S+)%s+(.*)$")
    if subcmd and subcommands[subcmd] and subcommands[subcmd].complete then
      return subcommands[subcmd].complete(subcmd_lead)
    end
    if cmdline:match("^['<,'>]*Rocks[!]*%s+%w*$") then
      return vim.tbl_filter(function(k) return k:find(lead) end, vim.tbl_keys(subcommands))
    end
  end,
})
```

---

## 6. Plugin Structure & Lazy Loading

### Directory Layout
```
myplugin/
├── plugin/
│   └── myplugin.lua     -- Entry point: commands, keymaps ONLY (no heavy require!)
├── lua/
│   └── myplugin/
│       ├── init.lua     -- Main module (lazy-loaded)
│       ├── config.lua   -- Configuration
│       └── health.lua   -- :checkhealth support
├── ftplugin/
│   └── rust.lua         -- Filetype-specific (auto-loaded)
├── after/               -- Overrides
└── doc/
    └── myplugin.txt     -- Vimdoc
```

### Lazy Loading Pattern (Critical!)
**DON'T** eagerly `require` in `plugin/*.lua`:
```lua
-- BAD: loads entire module at startup
local myplugin = require('myplugin')
vim.api.nvim_create_user_command('MyCmd', myplugin.action, {})
```

**DO** defer `require` to command/mapping execution:
```lua
-- GOOD: only loads when command is used
vim.api.nvim_create_user_command('MyCmd', function(opts)
  require('myplugin').action(opts)
end, { nargs = '*' })

vim.keymap.set('n', '<Plug>(MyAction)', function()
  require('myplugin').action()
end)
```

### Filetype Plugins
```lua
-- ftplugin/rust.lua
if vim.g.loaded_my_rust_plugin then return end
vim.g.loaded_my_rust_plugin = true

local bufnr = vim.api.nvim_get_current_buf()
vim.keymap.set('n', '<Plug>(MyRustAction)', function()
  require('myplugin.rust').action()
end, { buffer = bufnr })
```

---

## 7. Configuration Best Practices

### Separate Config Types (for Type Safety)
```lua
-- lua/myplugin/config.lua

---@class myplugin.Config  -- User-facing (optional fields)
---@field enabled? boolean
---@field strategy? 'fast'|'safe'

---@class myplugin.InternalConfig  -- Internal (all fields required)
local defaults = {
  enabled = true,
  strategy = 'fast',
}

-- Support both vim.g and setup() patterns
---@type myplugin.Config|fun():myplugin.Config|nil
vim.g.myplugin = vim.g.myplugin

local M = {}

function M.get()
  local user = type(vim.g.myplugin) == 'function' and vim.g.myplugin() or vim.g.myplugin or {}
  return vim.tbl_deep_extend('force', defaults, user)
end

return M
```

### Validation
```lua
vim.validate('enabled', config.enabled, 'boolean')
vim.validate('strategy', config.strategy, {'string', 'nil'})
-- Or with custom validator:
vim.validate('count', config.count, function(v) return v > 0 end, 'positive number')
```

---

## 8. Health Checks

```lua
-- lua/myplugin/health.lua
local M = {}

function M.check()
  vim.health.start('myplugin')
  
  if vim.fn.executable('rg') == 1 then
    vim.health.ok('ripgrep found')
  else
    vim.health.warn('ripgrep not found', {'Install ripgrep for better performance'})
  end
  
  local ok, err = pcall(require, 'plenary')
  if ok then
    vim.health.ok('plenary.nvim installed')
  else
    vim.health.error('plenary.nvim required', {'Install nvim-lua/plenary.nvim'})
  end
end

return M
```

---

## 9. Async & vim.uv

```lua
-- Timer example
local timer = vim.uv.new_timer()
timer:start(1000, 0, vim.schedule_wrap(function()
  vim.notify('Timer fired!')
  timer:close()  -- Always close handles!
end))

-- File watcher
local watcher = vim.uv.new_fs_event()
watcher:start('/path/to/file', {}, vim.schedule_wrap(function(err, fname, status)
  if err then return end
  vim.cmd('checktime')
end))

-- System commands (vim.system is simpler for most cases)
vim.system({'ls', '-la'}, { text = true }, function(obj)
  print(obj.stdout)
end)

-- Synchronous version
local result = vim.system({'git', 'status'}, { text = true }):wait()
```

**Critical**: `vim.api.*` calls MUST be wrapped with `vim.schedule` or `vim.schedule_wrap` in async callbacks!

---

## 10. Utility Functions

### Table Functions
```lua
vim.tbl_deep_extend('force', t1, t2)  -- Deep merge, t2 wins
vim.tbl_extend('keep', t1, t2)        -- Shallow merge, t1 wins
vim.tbl_keys(t)                        -- Get keys
vim.tbl_values(t)                      -- Get values
vim.tbl_contains(t, val)               -- Check if value exists
vim.tbl_isempty(t)                     -- Check if empty
vim.tbl_count(t)                       -- Count entries
vim.tbl_filter(fn, t)                  -- Filter by predicate
vim.tbl_map(fn, t)                     -- Transform values
vim.tbl_get(t, 'a', 'b', 'c')         -- Safe nested access (nil if missing)
vim.deepcopy(t)                        -- Deep copy
vim.deep_equal(a, b)                   -- Deep equality
vim.islist(t)                          -- Check if contiguous 1-indexed array
vim.isarray(t)                         -- Check if integer-indexed (may have holes)
```

### String Functions
```lua
vim.split(s, sep, {plain=true, trimempty=true})
vim.gsplit(s, sep, opts)               -- Iterator version
vim.startswith(s, prefix)
vim.endswith(s, suffix)
vim.trim(s)                            -- Trim whitespace
vim.pesc(s)                            -- Escape for Lua pattern
```

### List Functions
```lua
vim.list_extend(dst, src, start, finish)  -- Append src to dst
vim.list_slice(t, start, finish)          -- Extract slice
vim.list_contains(t, val)                 -- Check membership
```

### Iterators (vim.iter)
```lua
vim.iter({1,2,3,4,5})
  :map(function(v) return v * 2 end)
  :filter(function(v) return v > 4 end)
  :totable()  -- {6, 8, 10}

vim.iter(pairs(t)):map(fn):totable()  -- Works with pairs/ipairs
vim.iter(t):enumerate()               -- Add indices
vim.iter(t):fold(init, fn)            -- Reduce
vim.iter(t):any(pred)                 -- Any match?
vim.iter(t):all(pred)                 -- All match?
vim.iter(t):find(pred)                -- First match
vim.iter(t):skip(n):take(n)           -- Slice
```

### Filesystem (vim.fs)
```lua
vim.fs.basename(path)
vim.fs.dirname(path)
vim.fs.normalize(path)                 -- Normalize separators, expand ~/$VAR
vim.fs.joinpath(a, b, ...)
vim.fs.find({'Cargo.toml'}, {upward=true, path=vim.fn.getcwd()})
vim.fs.parents(path)                   -- Iterator over parent dirs
vim.fs.root(bufnr, {'.git', 'Cargo.toml'})  -- Find project root
vim.fs.dir(path, {depth=2})            -- Iterate directory
```

---

## 11. Anti-Patterns to Avoid

### ❌ DON'T: Require `setup()` for Basic Functionality
```lua
-- BAD: Plugin does nothing without setup()
-- Users get errors if plugin not installed
require('myplugin').setup({})
```

### ✅ DO: Work Out of Box, Optional Configuration
```lua
-- GOOD: Plugin works immediately, setup() only for overrides
vim.g.myplugin = { option = 'value' }  -- Optional
```

### ❌ DON'T: Create Many Top-Level Commands
```lua
-- BAD: Pollutes command namespace
:PluginInstall, :PluginUpdate, :PluginClean, :PluginStatus
```

### ✅ DO: Use Subcommands
```lua
-- GOOD: Single namespace with completions
:Plugin install, :Plugin update, :Plugin clean
```

### ❌ DON'T: Auto-Create Controversial Keymaps
```lua
-- BAD: May conflict with user mappings
vim.keymap.set('n', '<leader>f', ...)
```

### ✅ DO: Provide `<Plug>` Mappings
```lua
-- GOOD: User chooses their mapping
vim.keymap.set('n', '<Plug>(MyFind)', ...)
```

### ❌ DON'T: Use 0ver or No Versioning
### ✅ DO: Use SemVer, `vim.deprecate()` for Breaking Changes

---

## 12. Type Annotations (LuaCATS)

```lua
---@class MyClass
---@field name string
---@field count integer
---@field opts? MyOpts  -- Optional field

---@alias MyCallback fun(err?: string, result?: any): boolean

---@param name string
---@param opts? {silent?: boolean, buffer?: integer}
---@return boolean success
---@return string? error
function M.action(name, opts)
  -- ...
end

---@type table<string, MyClass>
local registry = {}

---@generic T
---@param list T[]
---@param fn fun(item: T): boolean
---@return T?
function M.find(list, fn) ... end
```

---

## 13. Testing

Use **busted** (not plenary.test):
```lua
-- spec/myplugin_spec.lua
describe('myplugin', function()
  it('does something', function()
    local result = require('myplugin').action()
    assert.equals('expected', result)
  end)
end)
```

Run with `nlua` or `nvim -l` + busted.

---

## 14. Quick Reference: Common Patterns

```lua
-- Get current buffer/window
local buf = vim.api.nvim_get_current_buf()
local win = vim.api.nvim_get_current_win()

-- Get/set lines
local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
vim.api.nvim_buf_set_lines(buf, 0, -1, false, {'new', 'lines'})

-- Get cursor position (1-indexed row, 0-indexed col)
local pos = vim.api.nvim_win_get_cursor(win)  -- {row, col}

-- Create namespace for extmarks/highlights
local ns = vim.api.nvim_create_namespace('myplugin')

-- Add highlight
vim.api.nvim_buf_add_highlight(buf, ns, 'WarningMsg', line, col_start, col_end)

-- Clear namespace highlights
vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

-- Floating window
local buf = vim.api.nvim_create_buf(false, true)
local win = vim.api.nvim_open_win(buf, true, {
  relative = 'cursor', row = 1, col = 0,
  width = 40, height = 10,
  style = 'minimal', border = 'rounded',
})

-- Defer execution
vim.defer_fn(function() ... end, 100)  -- ms

-- Safe require
local ok, mod = pcall(require, 'optional_dep')
if ok then mod.setup() end
```

---

## 15. v:lua Bridge (Vimscript ↔ Lua)

```lua
-- Call Lua from Vimscript options
function _G.my_omnifunc(findstart, base)
  if findstart == 1 then return 0 end
  return {'completion1', 'completion2'}
end
vim.bo.omnifunc = 'v:lua.my_omnifunc'

-- Or use require
vim.bo.omnifunc = "v:lua.require'myplugin'.omnifunc"
```

---

*Sources: neovim.io/doc/user/lua.html, lua-guide.html, lua-plugin.html, nvim-best-practices*