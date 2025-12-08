--- Unit tests for nvim-beads core.execute_bd_async function
--- Tests asynchronous bd command execution with callback-based error handling

describe("nvim-beads.core.execute_bd_async", function()
    local core
    local original_vim_system

    before_each(function()
        -- Clear the module cache to get fresh instance
        package.loaded["nvim-beads.core"] = nil
        core = require("nvim-beads.core")

        -- Save original vim.system
        original_vim_system = vim.system
    end)

    after_each(function()
        -- Restore original vim.system
        vim.system = original_vim_system
    end)

    describe("argument validation", function()
        it("should call callback with error when callback is not a function", function()
            -- This should error before calling vim.system
            local success = pcall(function()
                core.execute_bd_async({ "ready" }, "not a function")
            end)
            local error_caught = not success
            assert.is_true(error_caught)
        end)

        it("should call callback with error when args is not a table", function()
            local callback_result = nil
            local callback_error = nil

            core.execute_bd_async("not a table", function(result, err)
                callback_result = result
                callback_error = err
            end)

            -- vim.schedule should have been called, need to process it
            vim.wait(10)

            assert.is_nil(callback_result)
            assert.is_not_nil(callback_error)
            assert.matches("args must be a table", callback_error)
        end)
    end)

    describe("successful async execution", function()
        it("should parse JSON and call callback with result", function()
            local callback_result = nil
            local callback_error = nil
            local callback_called = false

            vim.system = function(_, _, callback)
                -- Simulate async call
                vim.schedule(function()
                    callback({
                        code = 0,
                        stdout = '{"issues": [{"id": "bd-1", "title": "Async issue"}]}',
                        stderr = "",
                    })
                end)
            end

            core.execute_bd_async({ "ready" }, function(result, err)
                callback_called = true
                callback_result = result
                callback_error = err
            end)

            -- Wait for async callback
            vim.wait(100, function()
                return callback_called
            end)

            assert.is_true(callback_called)
            assert.is_nil(callback_error)
            assert.is_not_nil(callback_result)
            assert.equals("bd-1", callback_result.issues[1].id)
            assert.equals("Async issue", callback_result.issues[1].title)
        end)

        it("should add --json flag automatically", function()
            local cmd_has_json = false

            vim.system = function(cmd, _, callback)
                for _, arg in ipairs(cmd) do
                    if arg == "--json" then
                        cmd_has_json = true
                        break
                    end
                end

                vim.schedule(function()
                    callback({
                        code = 0,
                        stdout = "{}",
                        stderr = "",
                    })
                end)
            end

            local callback_called = false
            core.execute_bd_async({ "ready" }, function()
                callback_called = true
            end)

            vim.wait(100, function()
                return callback_called
            end)

            assert.is_true(cmd_has_json)
        end)
    end)

    describe("async error handling", function()
        it("should call callback with error when command fails", function()
            local callback_result = nil
            local callback_error = nil
            local callback_called = false

            vim.system = function(_, _, callback)
                vim.schedule(function()
                    callback({
                        code = 1,
                        stdout = "",
                        stderr = "Command failed",
                    })
                end)
            end

            core.execute_bd_async({ "failing" }, function(result, err)
                callback_called = true
                callback_result = result
                callback_error = err
            end)

            vim.wait(100, function()
                return callback_called
            end)

            assert.is_true(callback_called)
            assert.is_nil(callback_result)
            assert.is_not_nil(callback_error)
            assert.matches("bd command failed", callback_error)
            assert.matches("Command failed", callback_error)
        end)

        it("should call callback with error when JSON parsing fails", function()
            local callback_result = nil
            local callback_error = nil
            local callback_called = false

            vim.system = function(_, _, callback)
                vim.schedule(function()
                    callback({
                        code = 0,
                        stdout = "Invalid JSON",
                        stderr = "",
                    })
                end)
            end

            core.execute_bd_async({ "ready" }, function(result, err)
                callback_called = true
                callback_result = result
                callback_error = err
            end)

            vim.wait(100, function()
                return callback_called
            end)

            assert.is_true(callback_called)
            assert.is_nil(callback_result)
            assert.is_not_nil(callback_error)
            assert.matches("Failed to parse JSON output", callback_error)
        end)
    end)
end)
