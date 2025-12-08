---@class test_utilities.assertions
---Common assertion helpers for test suite
---
---This module provides reusable assertion patterns to eliminate duplication across
---test files. Particularly useful for error notification testing and bd command validation.
---
---Usage:
---  local assertions = require("test_utilities.assertions")
---
---  it("should notify on error", function()
---    assertions.assert_error_notification(function()
---      some_function(nil)
---    end, "required parameter")
---  end)
---
---  it("should build correct command", function()
---    local cmd = build_update_command("bd-123", {title = "New"})
---    assertions.assert_bd_command(cmd, "update", {"bd-123"})
---    assertions.assert_command_has_flags(cmd, {["--title"] = "New"})
---  end)
local M = {}

---Assert that a function triggers vim.notify with expected pattern and level
---
---Mocks vim.notify, calls the function, and verifies notification occurred.
---Returns the captured message for additional assertions if needed.
---
---@param fn function The function to call (should trigger vim.notify)
---@param expected_pattern string Pattern to match in notification message (uses string.match)
---@param expected_level? number Expected vim.log.levels value (default: vim.log.levels.ERROR)
---@return string message The actual notification message that was sent
---
---Example:
---  assertions.assert_error_notification(function()
---    some_function(nil)
---  end, "required parameter", vim.log.levels.ERROR)
function M.assert_error_notification(fn, expected_pattern, expected_level)
    expected_level = expected_level or vim.log.levels.ERROR

    local notified = false
    local notify_msg = nil
    local notify_level = nil

    -- Mock vim.notify
    local original_notify = vim.notify
    vim.notify = function(msg, level)
        notified = true
        notify_msg = msg
        notify_level = level
    end

    -- Call the function
    fn()

    -- Restore original
    vim.notify = original_notify

    -- Assert notification occurred
    assert.is_true(notified, "Expected vim.notify to be called but it was not")

    -- Assert message matches pattern
    assert.is_not_nil(
        string.match(notify_msg, expected_pattern),
        string.format('Expected notification message to match "%s" but got: %s', expected_pattern, notify_msg)
    )

    -- Assert level matches
    assert.equals(
        expected_level,
        notify_level,
        string.format("Expected notification level %s but got %s", expected_level, notify_level)
    )

    return notify_msg
end

---Assert that a function does NOT trigger vim.notify
---
---Useful for testing that successful operations don't produce notifications.
---
---@param fn function The function to call (should NOT trigger vim.notify)
---
---Example:
---  assertions.assert_no_notification(function()
---    successful_operation()
---  end)
function M.assert_no_notification(fn)
    local notified = false

    -- Mock vim.notify
    local original_notify = vim.notify
    vim.notify = function(msg, level)
        notified = true
        error(string.format("Unexpected notification: [%s] %s", level, msg))
    end

    -- Call the function
    fn()

    -- Restore original
    vim.notify = original_notify

    -- Assert no notification occurred
    assert.is_false(notified, "Expected no vim.notify calls but one occurred")
end

---Assert that a command table is a valid bd command
---
---Validates basic structure: {"bd", subcommand, ...}
---Optionally validates positional arguments after the subcommand.
---
---@param cmd table The command table to validate
---@param expected_subcommand string Expected bd subcommand (e.g., "update", "create", "close")
---@param expected_args? table Optional array of expected positional arguments after subcommand
---
---Example:
---  local cmd = {"bd", "update", "bd-123", "--title", "New"}
---  assertions.assert_bd_command(cmd, "update", {"bd-123"})
function M.assert_bd_command(cmd, expected_subcommand, expected_args)
    assert.is_table(cmd, "Command must be a table")
    assert.is_true(#cmd >= 2, "Command must have at least 2 elements")

    assert.equals("bd", cmd[1], "Command must start with 'bd'")
    assert.equals(expected_subcommand, cmd[2], string.format("Expected subcommand '%s'", expected_subcommand))

    -- Validate positional args if provided
    if expected_args then
        for i, expected_arg in ipairs(expected_args) do
            local actual_arg = cmd[2 + i]
            assert.equals(
                expected_arg,
                actual_arg,
                string.format("Expected arg %d to be '%s' but got '%s'", i, expected_arg, actual_arg)
            )
        end
    end
end

---Assert that a command has a specific flag with a specific value
---
---Searches through the command table for flag/value pairs.
---Flags are expected to be in --flag value format.
---
---@param cmd table The command table to search
---@param flag string The flag to find (e.g., "--title")
---@param expected_value string|number The expected value after the flag
---@return boolean found True if flag was found (also asserts, so will error if not found)
---
---Example:
---  local cmd = {"bd", "update", "bd-123", "--title", "New Title", "--priority", "1"}
---  assertions.assert_command_has_flag(cmd, "--title", "New Title")
---  assertions.assert_command_has_flag(cmd, "--priority", "1")
function M.assert_command_has_flag(cmd, flag, expected_value)
    assert.is_table(cmd, "Command must be a table")

    -- Search for flag in command
    for i = 1, #cmd - 1 do
        if cmd[i] == flag then
            local actual_value = cmd[i + 1]
            -- Convert to string for comparison if needed
            local expected_str = tostring(expected_value)
            local actual_str = tostring(actual_value)

            assert.equals(
                expected_str,
                actual_str,
                string.format("Flag %s: expected value '%s' but got '%s'", flag, expected_str, actual_str)
            )
            return true
        end
    end

    -- Flag not found - fail assertion
    error(string.format("Flag '%s' not found in command: %s", flag, vim.inspect(cmd)))
end

---Assert that a command has multiple flags with specific values
---
---Convenience function for checking multiple flags at once.
---Order-independent - flags can appear anywhere in the command.
---
---@param cmd table The command table to search
---@param flags_table table Map of flag names to expected values {["--flag"] = "value"}
---
---Example:
---  local cmd = {"bd", "update", "bd-123", "--title", "New", "--priority", "1"}
---  assertions.assert_command_has_flags(cmd, {
---    ["--title"] = "New",
---    ["--priority"] = "1"
---  })
function M.assert_command_has_flags(cmd, flags_table)
    assert.is_table(cmd, "Command must be a table")
    assert.is_table(flags_table, "Flags must be a table")

    for flag, expected_value in pairs(flags_table) do
        M.assert_command_has_flag(cmd, flag, expected_value)
    end
end

return M
