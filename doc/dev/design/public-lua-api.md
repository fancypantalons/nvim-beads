# Public Lua API Design

## Problem

Currently, nvim-beads only exposes functionality through Vim commands (`:Beads list`, `:Beads show`, etc.) and `<Plug>` mappings. Users who want to invoke operations programmatically from Lua have no clean API.

The standard pattern in Neovim plugins is to expose a public Lua API like `require("plugin-name").operation(opts)` that both users and the plugin's own Vim commands can call. This eliminates duplication and provides a better developer experience.

## Proposed API Surface

Since nvim-beads has a relatively simple command surface (unlike telescope with its dozens of builtin pickers), we don't need namespacing. All functions live directly on the main module.

### Core Functions

```lua
-- List issues with optional filters
require("nvim-beads").list(opts)

-- Show a specific issue by ID
require("nvim-beads").show(issue_id, opts)

-- Create a new issue (opens buffer)
require("nvim-beads").create(opts)

-- Show ready (unblocked) issues
require("nvim-beads").ready(opts)

-- Low-level: execute arbitrary bd command
require("nvim-beads").execute(args, opts)
```

### Options Tables

**`list(opts)`**
- `opts.status` (string): Filter by status - "open", "in_progress", "blocked", "closed"
- `opts.type` (string): Filter by type - "bug", "feature", "task", "epic", "chore"
- `opts.priority` (number): Filter by priority - 0-4
- `opts.assignee` (string): Filter by assignee

**`show(issue_id, opts)`**
- `issue_id` (string): Issue ID to show
- `opts` (table, optional): Reserved for future options

**`create(opts)`**
- `opts.type` (string): Issue type - "bug", "feature", "task", "epic", "chore" (default: "task")
- `opts.template` (table, optional): Pre-populated template data

**`ready(opts)`**
- Same options as `list()` - filters the ready issues

**`execute(args, opts)`**
- `args` (table): Array of bd command arguments (e.g., `{"show", "bd-123"}`)
- `opts.async` (boolean): If true, execute asynchronously (default: false)
- `opts.callback` (function): Callback for async execution: `function(result, error)`

Returns: Parsed JSON result (sync) or nil (async)

## Implementation Strategy

### 1. Create `lua/nvim-beads/init.lua` as Public API

This becomes the canonical public interface. It should be clean, well-documented, and stable.

```lua
local M = {}

-- Expose core operations as public API
function M.list(opts)
  opts = opts or {}
  local core = require("nvim-beads.core")
  core.show_list(opts)
end

function M.show(issue_id, opts)
  opts = opts or {}
  local buffer = require("nvim-beads.buffer")
  buffer.open_issue_buffer(issue_id)
end

function M.create(opts)
  opts = opts or {}
  local issue_type = opts.type or "task"
  local template = opts.template
  local buffer = require("nvim-beads.buffer")
  buffer.open_new_issue_buffer(issue_type, template)
end

function M.ready(opts)
  opts = opts or {}
  local core = require("nvim-beads.core")
  core.show_ready(opts)
end

function M.execute(args, opts)
  opts = opts or {}
  local core = require("nvim-beads.core")

  if opts.async then
    if not opts.callback then
      error("callback required for async execution")
    end
    core.execute_bd_async(args, opts.callback)
    return nil
  else
    return core.execute_bd(args, opts)
  end
end

return M
```

### 2. Refactor `lua/nvim-beads/core.lua`

Update `show_list()` and `show_ready()` to accept and properly handle `opts` tables with filters.

**Current signature:**
```lua
M.show_list(fargs)  -- takes array of filter args from command line
```

**New signature:**
```lua
M.show_list(opts)   -- takes structured options table
```

This means refactoring the argument parsing:
- Move `parse_list_filters(fargs)` logic into the Vim command handler
- Have `show_list()` accept already-parsed options
- Command handler converts `fargs` → `opts`, then calls `show_list(opts)`

### 3. Update `lua/nvim-beads/commands.lua`

Refactor command implementations to be thin wrappers around the public API:

**Before (current):**
```lua
subcommands.list = {
  impl = function(args)
    local core = require("nvim-beads.core")
    core.show_list(args)
  end,
  complete = function() ... end,
}
```

**After:**
```lua
subcommands.list = {
  impl = function(args)
    local beads = require("nvim-beads")
    local opts = parse_command_args(args) -- convert fargs to opts table
    beads.list(opts)
  end,
  complete = function() ... end,
}
```

This creates a single source of truth: the public API functions become the canonical implementations, and the Vim commands just handle argument parsing and dispatch.

### 4. Handle the Passthrough Commands

Commands like `compact`, `cleanup`, `sync`, `daemon` currently open a terminal split and run bd directly. These shouldn't be in the public API because they're basically just shell passthroughs with no plugin-specific logic.

**Options:**
1. **Don't expose them** - Users can run `bd compact` themselves
2. **Add utility function** - `require("nvim-beads.util").run_bd_in_terminal(args)`
3. **Add generic execute_in_split()** - `require("nvim-beads").execute_in_split(args)`

**Recommendation:** Don't expose them in the public API. They add no value over running bd directly, and we shouldn't clutter the API with passthroughs.

If users really want programmatic access, they can use:
```lua
require("nvim-beads").execute({"compact"}, {})
```

### 5. Update Telescope Extension

The telescope extension should use the public API where possible:

**Current:**
```lua
-- In telescope extension's attach_mappings
actions.select_default:replace(function()
  local buffer = require("nvim-beads.buffer")
  buffer.open_issue_buffer(selected_issue.id)
end)
```

**After:**
```lua
-- In telescope extension's attach_mappings
actions.select_default:replace(function()
  require("nvim-beads").show(selected_issue.id)
end)
```

This keeps the telescope extension decoupled from internal implementation details.

### 6. Remove `<Plug>` Mappings

The existing `<Plug>(BeadsList)` and `<Plug>(BeadsReady)` mappings are redundant now that we have a public Lua API. Users can bind directly to the API functions or use `<cmd>` with the Vim commands:

```lua
-- Direct API binding
vim.keymap.set("n", "<leader>bl", function()
  require("nvim-beads").list()
end)

-- Or via Vim command
vim.keymap.set("n", "<leader>bl", "<cmd>Beads list<cr>")
```

No need to maintain three different ways to invoke the same operations.

## File Changes Summary

| File | Change Type | Description |
|------|-------------|-------------|
| `lua/nvim-beads/init.lua` | Create | New public API module |
| `lua/nvim-beads/core.lua` | Refactor | Accept `opts` tables instead of `fargs` arrays |
| `lua/nvim-beads/commands.lua` | Refactor | Convert to thin wrappers that parse args and call public API |
| `plugin/nvim-beads.lua` | Update | Remove `<Plug>` mappings (redundant with public API) |
| `lua/telescope/_extensions/nvim_beads/init.lua` | Update | Use public API instead of internal modules |

## Benefits

1. **Single Source of Truth**: Vim commands and programmatic usage share the same code path
2. **Better DX**: Users can call `require("nvim-beads").show("bd-123")` from their config
3. **Testability**: Public API is easier to test than Vim commands
4. **Maintainability**: Changes to behavior only need to happen in one place
5. **Extensibility**: Users can build their own tooling on top of the API
6. **Standard Pattern**: Follows established Neovim plugin conventions

## Migration Path

1. Create `init.lua` with public API
2. Refactor `core.lua` to accept `opts` (backward compatible - can support both for now)
3. Update command handlers to use public API
4. Update telescope extension to use public API
5. Remove `<Plug>` mappings from `plugin/nvim-beads.lua`
6. Document the public API in help docs
7. Eventually remove old code paths (breaking change, major version bump)

## Example Usage

```lua
-- In user's init.lua or a custom command
vim.keymap.set("n", "<leader>bb", function()
  require("nvim-beads").list({ status = "in_progress" })
end)

vim.keymap.set("n", "<leader>br", function()
  require("nvim-beads").ready()
end)

vim.api.nvim_create_user_command("BeadsMyBugs", function()
  require("nvim-beads").list({
    type = "bug",
    assignee = "myusername",
    status = "open"
  })
end, {})

-- Low-level access for power users
local result = require("nvim-beads").execute({"stats"})
vim.notify(string.format("Total issues: %d", result.total))
```

## Open Questions

1. **Should `create()` return the new issue ID?** Currently it just opens a buffer.
  * Answer: For now, that's totally fine. We're not created a generic Vim API wrapper for beads, right now we're creating an API for interacting with this plugin specifically.
2. **Do we want `M.update(issue_id, changes)` and `M.close(issue_id, reason)`?** Or is that too low-level?
  * Answer: No, too low level. See previous answer for more context.
3. **Should `list()` and `ready()` support a `callback` option for async execution?** Or is sync-only fine for UI operations?
  * Answer: Sync should be fine for now.
4. **Do we expose buffer operations like `M.reload_current_buffer()`?** Probably not needed.
  * Answer: Nope.

## Non-Goals

- **Backward compatibility during initial implementation**: Since we haven't released 1.0, we can make breaking changes
- **Exposing every internal function**: Only expose user-facing operations
- **Async-first API**: Sync is fine for most operations; add async only where needed
- **Telescope integration in main API**: Keep telescope as a separate extension
- **Maintaining redundant APIs**: No need for `<Plug>` mappings when users can bind directly to Lua functions or use `<cmd>` with Vim commands
