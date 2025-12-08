--- Unit tests for nvim-beads core.execute_bd function
--- Tests synchronous bd command execution with JSON parsing and error handling

describe("nvim-beads.core.execute_bd", function()
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
        local invalid_args_test_cases = {
            { name = "not a table", input = "not a table" },
            { name = "nil", input = nil },
            { name = "a number", input = 42 },
        }

        for _, test_case in ipairs(invalid_args_test_cases) do
            it("should return error when args is " .. test_case.name, function()
                local result, err = core.execute_bd(test_case.input)
                assert.is_nil(result)
                assert.is_not_nil(err)
                assert.matches("args must be a table", err)
            end)
        end
    end)

    describe("successful command execution", function()
        it("should parse JSON output correctly", function()
            -- Mock successful command execution
            vim.system = function(_, _)
                return {
                    wait = function()
                        return {
                            code = 0,
                            stdout = '{"result": [{"id": "bd-1", "title": "Test issue"}]}',
                            stderr = "",
                        }
                    end,
                }
            end

            local result, err = core.execute_bd({ "ready" })
            assert.is_nil(err)
            assert.is_not_nil(result)
            assert.is_table(result)
            assert.is_table(result.result)
            assert.equals("bd-1", result.result[1].id)
            assert.equals("Test issue", result.result[1].title)
        end)

        it("should automatically add --json flag if not present", function()
            local called_with_json = false

            vim.system = function(cmd, _)
                -- Check if --json flag is present
                for _, arg in ipairs(cmd) do
                    if arg == "--json" then
                        called_with_json = true
                        break
                    end
                end

                return {
                    wait = function()
                        return {
                            code = 0,
                            stdout = '{"result": []}',
                            stderr = "",
                        }
                    end,
                }
            end

            local _, err = core.execute_bd({ "ready" })
            assert.is_nil(err)
            assert.is_true(called_with_json)
        end)

        it("should not duplicate --json flag if already present", function()
            local json_count = 0

            vim.system = function(cmd, _)
                -- Count how many times --json appears
                for _, arg in ipairs(cmd) do
                    if arg == "--json" then
                        json_count = json_count + 1
                    end
                end

                return {
                    wait = function()
                        return {
                            code = 0,
                            stdout = '{"result": []}',
                            stderr = "",
                        }
                    end,
                }
            end

            local _, err = core.execute_bd({ "ready", "--json" })
            assert.is_nil(err)
            assert.equals(1, json_count)
        end)

        it("should pass text=true option to vim.system", function()
            local received_opts = nil

            vim.system = function(_, opts)
                received_opts = opts

                return {
                    wait = function()
                        return {
                            code = 0,
                            stdout = '{"result": []}',
                            stderr = "",
                        }
                    end,
                }
            end

            local _, err = core.execute_bd({ "ready" })
            assert.is_nil(err)
            assert.is_not_nil(received_opts)
            assert.is_true(received_opts.text)
        end)

        it("should allow custom options to override defaults", function()
            local received_opts = nil

            vim.system = function(_, opts)
                received_opts = opts

                return {
                    wait = function()
                        return {
                            code = 0,
                            stdout = '{"result": []}',
                            stderr = "",
                        }
                    end,
                }
            end

            local _, err = core.execute_bd({ "ready" }, { timeout = 5000 })
            assert.is_nil(err)
            assert.is_not_nil(received_opts)
            assert.equals(5000, received_opts.timeout)
            assert.is_true(received_opts.text) -- Default should still be there
        end)
    end)

    describe("command failure handling", function()
        local failure_test_cases = {
            {
                name = "command fails with non-zero exit code",
                code = 1,
                stderr = "Command not found",
                expected_matches = { "bd command failed", "exit code 1", "Command not found" },
            },
            {
                name = "empty stderr in error message",
                code = 127,
                stderr = "",
                expected_matches = { "exit code 127", "no error output" },
            },
            {
                name = "nil stderr in error message",
                code = 1,
                stderr = nil,
                expected_matches = { "no error output" },
            },
        }

        for _, test_case in ipairs(failure_test_cases) do
            it("should handle " .. test_case.name, function()
                vim.system = function(_, _)
                    return {
                        wait = function()
                            return {
                                code = test_case.code,
                                stdout = "",
                                stderr = test_case.stderr,
                            }
                        end,
                    }
                end

                local result, err = core.execute_bd({ "test_command" })
                assert.is_nil(result)
                assert.is_not_nil(err)
                for _, pattern in ipairs(test_case.expected_matches) do
                    assert.matches(pattern, err)
                end
            end)
        end
    end)

    describe("JSON parsing error handling", function()
        local json_error_test_cases = {
            { name = "not valid JSON", stdout = "This is not JSON" },
            { name = "incomplete", stdout = '{"result": [' },
            { name = "empty string", stdout = "" },
        }

        for _, test_case in ipairs(json_error_test_cases) do
            it("should return error when output is " .. test_case.name, function()
                vim.system = function(_, _)
                    return {
                        wait = function()
                            return {
                                code = 0,
                                stdout = test_case.stdout,
                                stderr = "",
                            }
                        end,
                    }
                end

                local result, err = core.execute_bd({ "ready" })
                assert.is_nil(result)
                assert.is_not_nil(err)
                assert.matches("Failed to parse JSON output", err)
            end)
        end
    end)

    describe("complex JSON structures", function()
        it("should parse nested objects correctly", function()
            vim.system = function(_, _)
                return {
                    wait = function()
                        return {
                            code = 0,
                            stdout = '{"result": {"nested": {"deep": "value"}}}',
                            stderr = "",
                        }
                    end,
                }
            end

            local result, err = core.execute_bd({ "ready" })
            assert.is_nil(err)
            assert.is_not_nil(result)
            assert.equals("value", result.result.nested.deep)
        end)

        it("should parse arrays with multiple elements", function()
            vim.system = function(_, _)
                return {
                    wait = function()
                        return {
                            code = 0,
                            stdout = '{"issues": [{"id": "bd-1"}, {"id": "bd-2"}, {"id": "bd-3"}]}',
                            stderr = "",
                        }
                    end,
                }
            end

            local result, err = core.execute_bd({ "list" })
            assert.is_nil(err)
            assert.is_not_nil(result)
            assert.equals(3, #result.issues)
            assert.equals("bd-1", result.issues[1].id)
            assert.equals("bd-2", result.issues[2].id)
            assert.equals("bd-3", result.issues[3].id)
        end)

        it("should handle null values in JSON", function()
            vim.system = function(_, _)
                return {
                    wait = function()
                        return {
                            code = 0,
                            stdout = '{"result": null}',
                            stderr = "",
                        }
                    end,
                }
            end

            local result, err = core.execute_bd({ "ready" })
            assert.is_nil(err)
            assert.is_not_nil(result)
            assert.is_table(result)
        end)
    end)
end)
