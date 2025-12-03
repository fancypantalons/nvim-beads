--- Unit tests for nvim-beads.issue.diff build_create_command function
--- Tests command generation for creating new issues

describe("nvim-beads.issue.diff", function()
    local diff

    -- Helper function to check if a command table contains a flag with value
    local function cmd_has_flag(cmd, flag, value)
        for i = 1, #cmd do
            if cmd[i] == flag then
                if value == nil then
                    return true
                elseif i + 1 <= #cmd and cmd[i + 1] == tostring(value) then
                    return true
                end
            end
        end
        return false
    end

    before_each(function()
        -- Clear the module cache to get fresh instance
        package.loaded["nvim-beads.issue.diff"] = nil
        diff = require("nvim-beads.issue.diff")
    end)

    describe("build_create_command", function()
        describe("validation", function()
            it("should return error when title is missing", function()
                local parsed_issue = {
                    issue_type = "task",
                }

                local command, err = diff.build_create_command(parsed_issue)

                assert.is_nil(command)
                assert.equals("Title is required", err)
            end)

            it("should return error when title is empty string", function()
                local parsed_issue = {
                    title = "",
                    issue_type = "task",
                }

                local command, err = diff.build_create_command(parsed_issue)

                assert.is_nil(command)
                assert.equals("Title is required", err)
            end)

            it("should return error when issue_type is missing", function()
                local parsed_issue = {
                    title = "Test Issue",
                }

                local command, err = diff.build_create_command(parsed_issue)

                assert.is_nil(command)
                assert.equals("Issue type is required", err)
            end)

            it("should return error when issue_type is empty string", function()
                local parsed_issue = {
                    title = "Test Issue",
                    issue_type = "",
                }

                local command, err = diff.build_create_command(parsed_issue)

                assert.is_nil(command)
                assert.equals("Issue type is required", err)
            end)
        end)

        describe("minimal issue (title + type only)", function()
            local minimal_issue_test_cases = {
                {
                    name = "bug type",
                    parsed_issue = { title = "Fix bug in parser", issue_type = "bug" },
                    expected_command = { "bd", "create", "Fix bug in parser", "--type", "bug" },
                },
                {
                    name = "task type",
                    parsed_issue = { title = "Update documentation", issue_type = "task" },
                    expected_command = { "bd", "create", "Update documentation", "--type", "task" },
                },
                {
                    name = "feature type",
                    parsed_issue = { title = "Add dark mode", issue_type = "feature" },
                    expected_command = { "bd", "create", "Add dark mode", "--type", "feature" },
                },
                {
                    name = "epic type",
                    parsed_issue = { title = "User authentication system", issue_type = "epic" },
                    expected_command = { "bd", "create", "User authentication system", "--type", "epic" },
                },
                {
                    name = "chore type",
                    parsed_issue = { title = "Update dependencies", issue_type = "chore" },
                    expected_command = { "bd", "create", "Update dependencies", "--type", "chore" },
                },
            }

            for _, test_case in ipairs(minimal_issue_test_cases) do
                it("should generate correct command with " .. test_case.name, function()
                    local command, err = diff.build_create_command(test_case.parsed_issue)

                    assert.is_nil(err)
                    assert.same(test_case.expected_command, command)
                end)
            end
        end)

        describe("optional field inclusion", function()
            local optional_field_inclusion_test_cases = {
                {
                    name = "priority",
                    parsed_issue = { title = "Critical bug", issue_type = "bug", priority = 0 },
                    expected_flag = "--priority",
                    expected_value = 0,
                },
                {
                    name = "description",
                    parsed_issue = { title = "Fix parser", issue_type = "bug", description = "The parser fails on edge cases" },
                    expected_flag = "--description",
                    expected_value = "The parser fails on edge cases",
                },
                {
                    name = "acceptance criteria",
                    parsed_issue = { title = "Add feature", issue_type = "feature", acceptance_criteria = "Must pass all tests" },
                    expected_flag = "--acceptance",
                    expected_value = "Must pass all tests",
                },
                {
                    name = "design",
                    parsed_issue = { title = "Refactor module", issue_type = "task", design = "Use MVC pattern" },
                    expected_flag = "--design",
                    expected_value = "Use MVC pattern",
                },
                {
                    name = "labels",
                    parsed_issue = { title = "Fix UI bug", issue_type = "bug", labels = { "ui", "frontend", "critical" } },
                    expected_flag = "--labels",
                    expected_value = "ui,frontend,critical",
                },
                {
                    name = "parent",
                    parsed_issue = { title = "Subtask", issue_type = "task", parent = "bd-50" },
                    expected_flag = "--parent",
                    expected_value = "bd-50",
                },
                {
                    name = "dependencies",
                    parsed_issue = { title = "Task with deps", issue_type = "task", dependencies = { "bd-10", "bd-20" } },
                    expected_flag = "--deps",
                    expected_value = "blocks:bd-10,blocks:bd-20",
                },
            }

            for _, test_case in ipairs(optional_field_inclusion_test_cases) do
                it("should include " .. test_case.name .. " when provided", function()
                    local command, err = diff.build_create_command(test_case.parsed_issue)

                    assert.is_nil(err)
                    assert.is_true(cmd_has_flag(command, test_case.expected_flag, test_case.expected_value))
                end)
            end        end)

        describe("empty optional fields omission", function()
            local empty_optional_fields_omission_test_cases = {
                {
                    name = "description when empty string",
                    parsed_issue = { title = "Task", issue_type = "task", description = "" },
                    omitted_flag = "--description",
                },
                {
                    name = "acceptance criteria when empty string",
                    parsed_issue = { title = "Task", issue_type = "task", acceptance_criteria = "" },
                    omitted_flag = "--acceptance",
                },
                {
                    name = "design when empty string",
                    parsed_issue = { title = "Task", issue_type = "task", design = "" },
                    omitted_flag = "--design",
                },
                {
                    name = "labels when empty array",
                    parsed_issue = { title = "Task", issue_type = "task", labels = {} },
                    omitted_flag = "--labels",
                },
                {
                    name = "parent when empty string",
                    parsed_issue = { title = "Task", issue_type = "task", parent = "" },
                    omitted_flag = "--parent",
                },
                {
                    name = "dependencies when empty array",
                    parsed_issue = { title = "Task", issue_type = "task", dependencies = {} },
                    omitted_flag = "--deps",
                },
            }

            for _, test_case in ipairs(empty_optional_fields_omission_test_cases) do
                it("should omit " .. test_case.name, function()
                    local command, err = diff.build_create_command(test_case.parsed_issue)

                    assert.is_nil(err)
                    assert.is_false(cmd_has_flag(command, test_case.omitted_flag))
                end)
            end        end)

        describe("special character handling (no escaping needed)", function()
            it("should handle single quotes in title", function()
                local parsed_issue = {
                    title = "Fix user's authentication",
                    issue_type = "bug",
                }

                local command, err = diff.build_create_command(parsed_issue)

                assert.is_nil(err)
                assert.same({ "bd", "create", "Fix user's authentication", "--type", "bug" }, command)
            end)

            it("should handle double quotes in title", function()
                local parsed_issue = {
                    title = 'Add "advanced" search',
                    issue_type = "feature",
                }

                local command, err = diff.build_create_command(parsed_issue)

                assert.is_nil(err)
                assert.same({ "bd", "create", 'Add "advanced" search', "--type", "feature" }, command)
            end)

            it("should handle single quotes in description", function()
                local parsed_issue = {
                    title = "Fix bug",
                    issue_type = "bug",
                    description = "The user's session wasn't saved",
                }

                local command, err = diff.build_create_command(parsed_issue)

                assert.is_nil(err)
                assert.is_true(cmd_has_flag(command, "--description", "The user's session wasn't saved"))
            end)

            it("should handle newlines in description", function()
                local parsed_issue = {
                    title = "Multi-line bug",
                    issue_type = "bug",
                    description = "Line 1\nLine 2\nLine 3",
                }

                local command, err = diff.build_create_command(parsed_issue)

                assert.is_nil(err)
                assert.is_true(cmd_has_flag(command, "--description", "Line 1\nLine 2\nLine 3"))
            end)

            it("should handle special shell characters in arguments", function()
                local parsed_issue = {
                    title = "Fix: $var & pipe | redirect >",
                    issue_type = "bug",
                }

                local command, err = diff.build_create_command(parsed_issue)

                assert.is_nil(err)
                assert.same({ "bd", "create", "Fix: $var & pipe | redirect >", "--type", "bug" }, command)
            end)

            it("should handle single quotes in acceptance criteria", function()
                local parsed_issue = {
                    title = "Task",
                    issue_type = "task",
                    acceptance_criteria = "User's can login successfully",
                }

                local command, err = diff.build_create_command(parsed_issue)

                assert.is_nil(err)
                assert.is_true(cmd_has_flag(command, "--acceptance", "User's can login successfully"))
            end)

            it("should handle single quotes in design", function()
                local parsed_issue = {
                    title = "Task",
                    issue_type = "task",
                    design = "Use the system's default config",
                }

                local command, err = diff.build_create_command(parsed_issue)

                assert.is_nil(err)
                assert.is_true(cmd_has_flag(command, "--design", "Use the system's default config"))
            end)

            it("should handle single quotes in labels", function()
                local parsed_issue = {
                    title = "Task",
                    issue_type = "task",
                    labels = { "user's-bug", "frontend" },
                }

                local command, err = diff.build_create_command(parsed_issue)

                assert.is_nil(err)
                assert.is_true(cmd_has_flag(command, "--labels", "user's-bug,frontend"))
            end)
        end)

        describe("issue with all fields populated", function()
            it("should generate command with all fields when provided", function()
                local parsed_issue = {
                    title = "Comprehensive issue",
                    issue_type = "feature",
                    priority = 1,
                    description = "This is a detailed description",
                    acceptance_criteria = "Must meet all criteria",
                    design = "Follow MVC pattern",
                    labels = { "backend", "api", "critical" },
                    parent = "bd-100",
                    dependencies = { "bd-50", "bd-60" },
                }

                local command, err = diff.build_create_command(parsed_issue)

                assert.is_nil(err)
                assert.is_not_nil(command)

                -- Verify all components are present
                assert.same("bd", command[1])
                assert.same("create", command[2])
                assert.same("Comprehensive issue", command[3])
                assert.is_true(cmd_has_flag(command, "--type", "feature"))
                assert.is_true(cmd_has_flag(command, "--priority", 1))
                assert.is_true(cmd_has_flag(command, "--description", "This is a detailed description"))
                assert.is_true(cmd_has_flag(command, "--acceptance", "Must meet all criteria"))
                assert.is_true(cmd_has_flag(command, "--design", "Follow MVC pattern"))
                assert.is_true(cmd_has_flag(command, "--labels", "backend,api,critical"))
                assert.is_true(cmd_has_flag(command, "--parent", "bd-100"))
                assert.is_true(cmd_has_flag(command, "--deps", "blocks:bd-50,blocks:bd-60"))
            end)
        end)

        describe("different priority values", function()
            local priority_test_cases = {
                {
                    name = "priority 0 (critical)",
                    parsed_issue = { title = "Critical issue", issue_type = "bug", priority = 0 },
                    expected_value = 0,
                },
                {
                    name = "priority 1 (high)",
                    parsed_issue = { title = "High priority", issue_type = "bug", priority = 1 },
                    expected_value = 1,
                },
                {
                    name = "priority 2 (medium/default)",
                    parsed_issue = { title = "Medium priority", issue_type = "task", priority = 2 },
                    expected_value = 2,
                },
                {
                    name = "priority 3 (low)",
                    parsed_issue = { title = "Low priority", issue_type = "task", priority = 3 },
                    expected_value = 3,
                },
                {
                    name = "priority 4 (backlog)",
                    parsed_issue = { title = "Backlog item", issue_type = "task", priority = 4 },
                    expected_value = 4,
                },
            }

            for _, test_case in ipairs(priority_test_cases) do
                it("should handle " .. test_case.name, function()
                    local command, err = diff.build_create_command(test_case.parsed_issue)

                    assert.is_nil(err)
                    assert.is_true(cmd_has_flag(command, "--priority", test_case.expected_value))
                end)
            end        end)
    end)
end)
