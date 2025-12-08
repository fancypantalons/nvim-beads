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
        it("should accept valid issue type: bug", function()
            vim.system = function(_, _)
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

            local result, err = core.fetch_template("bug")
            assert.is_nil(err)
            assert.is_not_nil(result)
        end)

        it("should accept valid issue type: feature", function()
            vim.system = function(_, _)
                return {
                    wait = function()
                        return {
                            code = 0,
                            stdout = '{"title": "", "type": "feature"}',
                            stderr = "",
                        }
                    end,
                }
            end

            local result, err = core.fetch_template("feature")
            assert.is_nil(err)
            assert.is_not_nil(result)
        end)

        it("should accept valid issue type: task", function()
            vim.system = function(_, _)
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

            local result, err = core.fetch_template("task")
            assert.is_nil(err)
            assert.is_not_nil(result)
        end)

        it("should accept valid issue type: epic", function()
            vim.system = function(_, _)
                return {
                    wait = function()
                        return {
                            code = 0,
                            stdout = '{"title": "", "type": "epic"}',
                            stderr = "",
                        }
                    end,
                }
            end

            local result, err = core.fetch_template("epic")
            assert.is_nil(err)
            assert.is_not_nil(result)
        end)

        it("should accept valid issue type: chore", function()
            vim.system = function(_, _)
                return {
                    wait = function()
                        return {
                            code = 0,
                            stdout = '{"title": "", "type": "chore"}',
                            stderr = "",
                        }
                    end,
                }
            end

            local result, err = core.fetch_template("chore")
            assert.is_nil(err)
            assert.is_not_nil(result)
        end)

        it("should reject invalid issue type", function()
            local result, err = core.fetch_template("invalid")
            assert.is_nil(result)
            assert.is_not_nil(err)
            assert.matches("Invalid issue type 'invalid'", err)
            assert.matches("bug, feature, task, epic, chore", err)
        end)

        it("should reject empty string issue type", function()
            local result, err = core.fetch_template("")
            assert.is_nil(result)
            assert.is_not_nil(err)
            assert.matches("Invalid issue type", err)
        end)

        it("should reject nil issue type", function()
            local result, err = core.fetch_template(nil)
            assert.is_nil(result)
            assert.is_not_nil(err)
            assert.matches("Invalid issue type", err)
        end)
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

            -- Check for --json flag (value doesn't matter, just presence)
            local has_json = false
            for _, arg in ipairs(executed_cmd) do
                if arg == "--json" then
                    has_json = true
                    break
                end
            end
            assert.is_true(has_json)
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
