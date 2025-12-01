# Telescope Finders Reference

> Guide for choosing the correct Telescope finder type for different data sources

---

## Overview

Telescope.nvim provides multiple finder types for different data loading patterns. Choosing the correct finder is critical for performance and correct behavior.

## Finder Types

### `finders.new_table`

**Use when:** You have pre-computed data or complete command output

**Best for:**
- Commands that output complete JSON arrays
- Pre-fetched API responses
- In-memory data structures
- Results that fit comfortably in memory

**Example:**
```lua
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")

-- Execute command and get complete output
local result = vim.system({ "bd", "list", "--json" }, { text = true }):wait()
local issues = vim.json.decode(result.stdout)

-- Create picker with new_table
pickers.new({}, {
  finder = finders.new_table({
    results = issues,
    entry_maker = function(issue)
      return {
        value = issue,
        display = issue.id .. ": " .. issue.title,
        ordinal = issue.title,
      }
    end,
  }),
  sorter = conf.generic_sorter({}),
}):find()
```

**Pros:**
- Simple and straightforward
- No streaming complexity
- Easy to debug

**Cons:**
- Synchronous data loading (blocks until complete)
- Must load all data into memory at once

---

### `finders.new_oneshot_job` / `finders.new_async_job`

**Use when:** Command outputs line-by-line results

**Best for:**
- `find` command output (one file per line)
- `grep` / `rg` output (one match per line)
- `git log --oneline` (one commit per line)
- Streaming data sources
- Large result sets that benefit from progressive rendering

**How it works:**
```lua
-- Internally, Telescope does:
for line in stdout:iter(false) do
  local entry = entry_maker(line)
  -- Process each line individually
end
```

**Example:**
```lua
finders.new_async_job({
  command_generator = function()
    return { "rg", "--line-number", "pattern" }
  end,
  entry_maker = function(line)
    -- Called once per line of output
    local filename, lnum, text = line:match("([^:]+):(%d+):(.*)")
    return {
      value = line,
      display = filename .. ":" .. lnum .. ": " .. text,
      ordinal = text,
    }
  end,
})
```

**Pros:**
- Asynchronous processing
- Progressive UI updates
- Memory efficient for large result sets

**Cons:**
- Only works with line-delimited output
- More complex error handling
- Not suitable for JSON arrays or structured formats

---

### `finders.new_async`

**Use when:** You need custom async logic with a writer interface

**Best for:**
- Custom data sources with complex async logic
- When you need fine-grained control over the async process
- Advanced use cases not covered by other finders

**Rarely needed:** Most plugins use `new_table` or `new_oneshot_job`

---

## Decision Guide

### JSON Array Output (like `bd list --json`)

**Problem:** Command outputs a single JSON array, not line-by-line JSON objects

**Wrong approach:** ❌ `new_async_job`
- Would treat entire JSON array as a single line
- Entry maker would need to parse and return only one entry
- Defeats the purpose of streaming

**Correct approach:** ✅ `new_table`
```lua
local result = vim.system({ "bd", "list", "--json" }, { text = true }):wait()
local issues = vim.json.decode(result.stdout)

finder = finders.new_table({
  results = issues,
  entry_maker = entry_maker,
})
```

### Line-Delimited Output

**Example:** Command outputs one item per line
```
file1.lua
file2.lua
file3.lua
```

**Correct approach:** ✅ `new_oneshot_job` or `new_async_job`
```lua
finder = finders.new_async_job({
  command_generator = function()
    return { "find", ".", "-name", "*.lua" }
  end,
  entry_maker = function(line)
    return { value = line, display = line, ordinal = line }
  end,
})
```

### Pre-Computed Data

**Example:** You already have data in Lua tables

**Correct approach:** ✅ `new_table`
```lua
local items = { "item1", "item2", "item3" }

finder = finders.new_table({
  results = items,
  entry_maker = function(item)
    return { value = item, display = item, ordinal = item }
  end,
})
```

---

## Real-World Examples

### octo.nvim (GitHub Integration)

Uses `new_table` for API responses:
```lua
-- Fetch complete JSON from GitHub API
local output = gh.api.graphql(query)
local decoded = vim.json.decode(output)

-- Use new_table for display
finder = finders.new_table({
  results = decoded.data.repository.issues.nodes,
  entry_maker = entry_maker.gen_from_issue(max_number),
})
```

### telescope-github.nvim

Uses `new_table` for GitHub API:
```lua
local issues = api.get_issues(opts)
finder = finders.new_table({
  results = issues,
  entry_maker = make_entry.gen_from_github_issues(opts),
})
```

### telescope.nvim (builtin.find_files)

Uses `new_oneshot_job` for `find` command:
```lua
finder = finders.new_oneshot_job({
  "find", ".", "-type", "f"
}, opts)
```

---

## Common Misconceptions

### "Async is always better"

**False.** The benefit of async finders comes from **progressive rendering** of streaming results, not from async execution itself.

- If your command completes in <100ms with all results, `new_table` is simpler
- If your command streams thousands of results, `new_async_job` provides better UX
- Telescope's UI rendering is async regardless of finder type

### "new_async_job can handle any command output"

**False.** `new_async_job` is specifically designed for **line-delimited** output.

- It calls `entry_maker` once per line
- Cannot parse multi-line structures like JSON arrays
- Use `new_table` for structured formats

### "new_table blocks the UI"

**Partially true.** While data loading is synchronous, Telescope still provides async UI responsiveness:

- The picker UI renders asynchronously
- User can start typing immediately
- Filtering and sorting remain responsive
- Only the initial data fetch is synchronous

---

## Best Practices

1. **Start with `new_table`** unless you have a specific reason for async
2. **Use `new_async_job`** for commands with line-delimited output and large result sets
3. **Match your finder to your data format**, not to perceived performance benefits
4. **Test with realistic data sizes** before optimizing
5. **Prefer simplicity** over premature optimization

---

## Error Handling

### With `new_table`

```lua
local result = vim.system({ "bd", "list", "--json" }, { text = true }):wait()

if result.code ~= 0 then
  vim.notify("Command failed: " .. (result.stderr or ""), vim.log.levels.ERROR)
  return
end

local ok, data = pcall(vim.json.decode, result.stdout)
if not ok then
  vim.notify("Failed to parse JSON", vim.log.levels.ERROR)
  return
end
```

### With `new_async_job`

```lua
finder = finders.new_async_job({
  command_generator = function()
    return { "command", "args" }
  end,
  entry_maker = function(line)
    -- Validate each line
    if not line or line == "" then
      return nil
    end
    return { value = line, display = line, ordinal = line }
  end,
})
```

---

## References

- [Telescope.nvim GitHub Repository](https://github.com/nvim-telescope/telescope.nvim)
- [Telescope Developers Guide](https://github.com/nvim-telescope/telescope.nvim/blob/master/developers.md)
- [async_oneshot_finder.lua source](https://github.com/nvim-telescope/telescope.nvim/blob/master/lua/telescope/finders/async_oneshot_finder.lua)
- [octo.nvim Telescope integration](https://github.com/pwntester/octo.nvim/blob/master/lua/octo/pickers/telescope/provider.lua)
- [telescope-github.nvim](https://github.com/nvim-telescope/telescope-github.nvim)

---

*Last updated: 2025-11-30*
