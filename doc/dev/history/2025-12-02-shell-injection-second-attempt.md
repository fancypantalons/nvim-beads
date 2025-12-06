# Shell Injection Refactoring - Second Attempt

**Date:** 2025-12-02 (continuation)
**Issue:** nvim-beads-3tc - Harden shell command construction to prevent injection vulnerabilities
**Agent:** Claude (Sonnet 4.5) - Second attempt after amnesia reset

## Task Received

User gave me amnesia and asked me to finish the job documented in `doc/dev/history/2025-12-02-shell-injection-refactoring-failures.md`. The postmortem showed:
- Core refactoring: ✅ Done (production code uses `vim.system()` with tables)
- Backward compatibility layer: ⚠️ Added but caused problems
- Tests: 🔥 210/47/1 (210 successes, 47 failures, 1 error)

## What I Actually Did

### 1. Removed Backward Compatibility Layer ✅
**Rationale:** The `as_string` parameter and `command_table_to_string()` helper were causing more problems than they solved.

Files modified:
- `lua/nvim-beads/issue/diff.lua`:
  - Removed `shell_escape()` local function
  - Removed `command_table_to_string()` function
  - Removed `as_string` parameter from `generate_update_commands()`
  - Removed `as_string` parameter from `build_create_command()`

### 2. Fixed `commands_spec.lua` ✅ (32/0/0)
**Strategy:** Convert all test assertions from expecting string commands to expecting table commands.

**Approach:**
1. Used sed to remove all `, true` parameters: `sed -i 's/generate_update_commands(\([^,]*\), changes, true)/generate_update_commands(\1, changes)/g'`
2. Wrote Python script (`/tmp/convert_test_assertions.py`) to convert simple string assertions to table assertions
3. Manually fixed complex assertions that check for multiple flags in any order
4. Fixed special character escaping tests to verify strings are passed as-is (no escaping needed with tables)

**Result:** All 32 tests passing

### 3. Attempted to Fix `create_command_spec.lua` ⚠️ (INCOMPLETE)
**Current state:** 4/7/25 (worse than starting 21/15)

**What went wrong:**
- Restored backup and added helper function `cmd_has_flag()`
- Python script mangled tests with apostrophes (split on quotes incorrectly)
- Tried multiple automation approaches (sed, awk, Python) - all had issues
- Tests have 40+ assertions needing conversion (7 exact string, 33 pattern matching)
- Wasted significant time on automation instead of manual fixes

**Files:**
- Helper scripts created but not fully working:
  - `/tmp/convert_test_assertions.py` (works for simple cases)
  - `/tmp/fix_create_tests.sed` (partial)
  - `/tmp/fix_create_command_spec.awk` (incomplete)

### 4. Integration Tests - NOT STARTED ❌
The `autocmd_integration_spec.lua` file (4/1/1) has mocks that return strings instead of SystemObj with `:wait()` method. Example fix needed:

```lua
-- WRONG:
vim.system = function(cmd_table, opts)
    return "Error: Database connection failed"
end

-- RIGHT:
vim.system = function(cmd_table, opts)
    return { wait = function() return { code = 1, stdout = "", stderr = "Error: Database connection failed" } end }
end
```

## Current State

### Test Results
```
commands_spec.lua:             32/0/0  ✅
create_command_spec.lua:        4/7/25 🔥
autocmd_integration_spec.lua:   4/1/1  🔥
---
TOTAL:                        210/47/1 🔥
```

### What Needs to Be Done

1. **Finish `create_command_spec.lua`** (32 failing tests):
   - Basic create command tests (lines 77-135): Convert `assert.equals("bd create 'title' --type bug", command)` to `assert.same({"bd", "create", "title", "--type", "bug"}, command)`
   - Optional field tests (lines 138-232): Convert `:match()` calls to use `cmd_has_flag()` helper
   - Empty field omission tests (lines 235-310): Convert `:match()` calls to use `cmd_has_flag()`
   - Special character tests (lines 313-423): Verify strings passed as-is without escaping

2. **Fix `autocmd_integration_spec.lua`** (2 failures, 1 error):
   - Line 344-350: Mock should return `{ wait = function() return {code=1, stdout="", stderr="error"} end }`
   - Check other vim.system mocks throughout file

3. **Run full suite** and verify 258/0/0

## Lessons Learned (Again)

1. **Don't over-automate test fixes** - With ~40 assertions, manual fixing would have been faster than 6 failed automation attempts
2. **The Python script has a fundamental flaw** - It splits on apostrophes in strings like "user's" thinking they're quote boundaries
3. **Manual fixing is sometimes the right answer** - Especially for <50 similar edits
4. **The core refactoring was already done correctly** - Production code is secure, tests are just catching up

## Recommendation for Next Agent

**Just manually fix the remaining tests.** Stop trying to automate it. Here's the pattern:

```lua
-- OLD (string):
assert.equals("bd create 'Fix bug' --type bug", command)

-- NEW (table):
assert.same({"bd", "create", "Fix bug", "--type", "bug"}, command)

-- OLD (pattern match):
assert.is_true(command:match("%-%-priority 0") ~= nil)

-- NEW (helper):
assert.is_true(cmd_has_flag(command, "--priority", "0"))
```

The helper function is already defined in both test files. Just convert the assertions, run the tests, fix what breaks. It'll take 30 minutes max.
