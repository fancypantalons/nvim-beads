--- Unit tests for nvim-beads core.fetch_template function
--- Tests template fetching for different issue types

local assertions = require("test_utilities.assertions")

describe("nvim-beads.core.fetch_template", function()
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

    describe("issue type validation", function()
        local valid_type_test_cases = {
            { type = "bug" },
            { type = "feature" },
            { type = "task" },
            { type = "epic" },
            { type = "chore" },
        }

        for _, test_case in ipairs(valid_type_test_cases) do
            it("should accept valid issue type: " .. test_case.type, function()
                vim.system = function(_, _)
                    return {
                        wait = function()
                            return {
                                code = 0,
                                stdout = '{"title": "", "type": "' .. test_case.type .. '"}',
                                stderr = "",
                            }
                        end,
                    }
                end

                local result, err = core.fetch_template(test_case.type)
                assert.is_nil(err)
                assert.is_not_nil(result)
            end)
        end

        local invalid_type_test_cases = {
            {
                name = "invalid issue type",
                input = "invalid",
                expected_error = "Invalid issue type 'invalid'",
                additional_match = "bug, feature, task, epic, chore",
            },
            {
                name = "empty string issue type",
                input = "",
                expected_error = "Invalid issue type",
            },
            {
                name = "nil issue type",
                input = nil,
                expected_error = "Invalid issue type",
            },
        }

        for _, test_case in ipairs(invalid_type_test_cases) do
            it("should reject " .. test_case.name, function()
                local result, err = core.fetch_template(test_case.input)
                assert.is_nil(result)
                assert.is_not_nil(err)
                assert.matches(test_case.expected_error, err)
                if test_case.additional_match then
                    assert.matches(test_case.additional_match, err)
                end
            end)
        end
    end)

    describe("command construction", function()
        it("should execute correct bd command with type", function()
            local executed_cmd = nil

            vim.system = function(cmd, _)
                executed_cmd = cmd

                return {
                    wait = function()
                        return {
                            code = 0,
                            stdout = '{"title": "", "type": "task"}',
                            stderr = "",
                        }
                    end,
                }
            end

            local _, err = core.fetch_template("task")
            assert.is_nil(err)
            assert.is_not_nil(executed_cmd)
            assertions.assert_bd_command(executed_cmd, "template", { "show", "task" })
        end)

        it("should include --json flag in command", function()
            local executed_cmd = nil

            vim.system = function(cmd, _)
                executed_cmd = cmd

                return {
                    wait = function()
                        return {
                            code = 0,
                            stdout = '{"title": "", "type": "bug"}',
                            stderr = "",
                        }
                    end,
                }
            end

            local _, err = core.fetch_template("bug")
            assert.is_nil(err)
            assert.is_not_nil(executed_cmd)

            -- Check for --json flag presence
            assert.is_true(vim.tbl_contains(executed_cmd, "--json"))
        end)
    end)

    describe("template parsing", function()
        it("should parse template JSON correctly", function()
            vim.system = function(_, _)
                return {
                    wait = function()
                        return {
                            code = 0,
                            stdout = '{"title": "Test Title", "type": "task", '
                                .. '"priority": 2, "description": "Test description"}',
                            stderr = "",
                        }
                    end,
                }
            end

            local result, err = core.fetch_template("task")
            assert.is_nil(err)
            assert.is_not_nil(result)
            assert.equals("Test Title", result.title)
            assert.equals("task", result.type)
            assert.equals(2, result.priority)
            assert.equals("Test description", result.description)
        end)

        it("should handle template with all fields", function()
            vim.system = function(_, _)
                return {
                    wait = function()
                        return {
                            code = 0,
                            stdout = '{"title": "", "type": "feature", '
                                .. '"priority": 1, "description": "Desc", '
                                .. '"design": "Design", "acceptance_criteria": "AC", '
                                .. '"labels": ["label1"], "parent": null, "dependencies": []}',
                            stderr = "",
                        }
                    end,
                }
            end

            local result, err = core.fetch_template("feature")
            assert.is_nil(err)
            assert.is_not_nil(result)
            assert.equals("feature", result.type)
            assert.equals(1, result.priority)
            assert.equals("Desc", result.description)
            assert.equals("Design", result.design)
            assert.equals("AC", result.acceptance_criteria)
        end)
    end)

    describe("error handling", function()
        it("should return default template when bd command fails (no template found)", function()
            vim.system = function(_, _)
                return {
                    wait = function()
                        return {
                            code = 1,
                            stdout = "",
                            stderr = "Template not found",
                        }
                    end,
                }
            end

            local result, err = core.fetch_template("task")
            assert.is_nil(err)
            assert.is_not_nil(result)
            assert.equals("", result.title)
            assert.equals("task", result.type)
            assert.equals(2, result.priority)
            assert.equals("", result.description)
            assert.equals("", result.acceptance_criteria)
            assert.equals("", result.design)
        end)

        it("should return default template with correct type for bug", function()
            vim.system = function(_, _)
                return {
                    wait = function()
                        return {
                            code = 1,
                            stdout = "",
                            stderr = "Template not found",
                        }
                    end,
                }
            end

            local result, err = core.fetch_template("bug")
            assert.is_nil(err)
            assert.is_not_nil(result)
            assert.equals("bug", result.type)
        end)

        it("should return default template with correct type for feature", function()
            vim.system = function(_, _)
                return {
                    wait = function()
                        return {
                            code = 1,
                            stdout = "",
                            stderr = "Template not found",
                        }
                    end,
                }
            end

            local result, err = core.fetch_template("feature")
            assert.is_nil(err)
            assert.is_not_nil(result)
            assert.equals("feature", result.type)
        end)

        it("should return error when JSON parsing fails", function()
            vim.system = function(_, _)
                return {
                    wait = function()
                        return {
                            code = 0,
                            stdout = "Invalid JSON",
                            stderr = "",
                        }
                    end,
                }
            end

            local result, err = core.fetch_template("task")
            assert.is_nil(result)
            assert.is_not_nil(err)
            assert.matches("Failed to parse JSON output", err)
        end)
    end)
end)
