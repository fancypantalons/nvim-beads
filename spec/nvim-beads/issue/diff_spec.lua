--- Unit tests for nvim-beads.issue diff_issues function
--- Tests the comparison logic to detect changes between original and modified issue states

describe("nvim-beads.issue.diff", function()
    local diff_module

    before_each(function()
        -- Clear the module cache to get fresh instance
        package.loaded["nvim-beads.issue.diff"] = nil
        diff_module = require("nvim-beads.issue.diff")
    end)

    describe("diff_issues", function()
        it("should detect no changes when states are identical", function()
            local original = {
                id = "bd-1",
                title = "Test Issue",
                issue_type = "task",
                status = "open",
                priority = 2,
                labels = {},
                dependencies = {},
                description = "Test description",
                created_at = "2023-10-27T10:00:00Z",
                updated_at = "2023-10-27T12:00:00Z",
            }

            local modified = {
                id = "bd-1",
                title = "Test Issue",
                issue_type = "task",
                status = "open",
                priority = 2,
                labels = {},
                dependencies = {},
                description = "Test description",
                created_at = "2023-10-27T10:00:00Z",
                updated_at = "2023-10-27T12:00:00Z",
            }

            local changes = diff_module.diff_issues(original, modified)

            assert.is_table(changes)
            assert.is_nil(changes.metadata)
            assert.is_nil(changes.status)
            assert.is_nil(changes.labels)
            assert.is_nil(changes.dependencies)
            assert.is_nil(changes.parent)
            assert.is_nil(changes.sections)
        end)

        local metadata_diff_test_cases = {
            {
                name = "title change",
                original = { id = "bd-1", title = "Original Title", priority = 2 },
                modified = { id = "bd-1", title = "Modified Title", priority = 2 },
                expected_changes = { metadata = { title = "Modified Title" } },
            },
            {
                name = "priority change",
                original = { id = "bd-1", title = "Test", priority = 2 },
                modified = { id = "bd-1", title = "Test", priority = 1 },
                expected_changes = { metadata = { priority = 1 } },
            },
            {
                name = "assignee change",
                original = { id = "bd-1", assignee = "john.doe" },
                modified = { id = "bd-1", assignee = "jane.smith" },
                expected_changes = { metadata = { assignee = "jane.smith" } },
            },
            {
                name = "assignee being added",
                original = { id = "bd-1" },
                modified = { id = "bd-1", assignee = "john.doe" },
                expected_changes = { metadata = { assignee = "john.doe" } },
            },
            {
                name = "assignee being removed",
                original = { id = "bd-1", assignee = "john.doe" },
                modified = { id = "bd-1" },
                expected_changes = { metadata = { assignee = "" } },
            },
        }

        for _, test_case in ipairs(metadata_diff_test_cases) do
            it("should detect " .. test_case.name, function()
                local changes = diff_module.diff_issues(test_case.original, test_case.modified)

                if test_case.expected_changes.metadata then
                    assert.is_table(changes.metadata)
                    for key, value in pairs(test_case.expected_changes.metadata) do
                        assert.equals(value, changes.metadata[key])
                    end
                else
                    assert.is_nil(changes.metadata)
                end
                -- Ensure no unexpected metadata changes are present
                for key, value in pairs(changes.metadata or {}) do
                    if not test_case.expected_changes.metadata or not test_case.expected_changes.metadata[key] then
                        assert.is_nil(value, "Unexpected metadata change for: " .. key)
                    end
                end
            end)
        end

        it("should detect status change", function()
            local original = {
                id = "bd-1",
                status = "open",
            }

            local modified = {
                id = "bd-1",
                status = "in_progress",
            }

            local changes = diff_module.diff_issues(original, modified)

            assert.equals("in_progress", changes.status)
        end)

        local label_diff_test_cases = {
            {
                name = "label additions",
                original = { id = "bd-1", labels = {} },
                modified = { id = "bd-1", labels = { "ui", "backend" } },
                expected_add = { "ui", "backend" },
                expected_remove = nil,
            },
            {
                name = "label removals",
                original = { id = "bd-1", labels = { "ui", "backend", "urgent" } },
                modified = { id = "bd-1", labels = { "ui" } },
                expected_add = nil,
                expected_remove = { "backend", "urgent" },
            },
            {
                name = "both label additions and removals",
                original = { id = "bd-1", labels = { "ui", "old-label" } },
                modified = { id = "bd-1", labels = { "ui", "backend", "new-label" } },
                expected_add = { "backend", "new-label" },
                expected_remove = { "old-label" },
            },
        }

        for _, test_case in ipairs(label_diff_test_cases) do
            it("should detect " .. test_case.name, function()
                local changes = diff_module.diff_issues(test_case.original, test_case.modified)

                assert.is_table(changes.labels)

                if test_case.expected_add then
                    assert.is_table(changes.labels.add)
                    assert.equals(#test_case.expected_add, #changes.labels.add)
                    for _, label in ipairs(test_case.expected_add) do
                        assert.True(vim.tbl_contains(changes.labels.add, label))
                    end
                else
                    assert.is_nil(changes.labels.add)
                end

                if test_case.expected_remove then
                    assert.is_table(changes.labels.remove)
                    assert.equals(#test_case.expected_remove, #changes.labels.remove)
                    for _, label in ipairs(test_case.expected_remove) do
                        assert.True(vim.tbl_contains(changes.labels.remove, label))
                    end
                else
                    assert.is_nil(changes.labels.remove)
                end
            end)
        end

        local dependency_diff_test_cases = {
            {
                name = "dependency additions",
                original = { id = "bd-1", dependencies = {} },
                modified = { id = "bd-1", dependencies = { "bd-120", "bd-121" } },
                expected_add = { "bd-120", "bd-121" },
                expected_remove = nil,
            },
            {
                name = "dependency removals",
                original = { id = "bd-1", dependencies = { "bd-100", "bd-101", "bd-102" } },
                modified = { id = "bd-1", dependencies = { "bd-100" } },
                expected_add = nil,
                expected_remove = { "bd-101", "bd-102" },
            },
            {
                name = "both dependency additions and removals",
                original = { id = "bd-1", dependencies = { "bd-100", "bd-101" } },
                modified = { id = "bd-1", dependencies = { "bd-100", "bd-120", "bd-121" } },
                expected_add = { "bd-120", "bd-121" },
                expected_remove = { "bd-101" },
            },
        }

        for _, test_case in ipairs(dependency_diff_test_cases) do
            it("should detect " .. test_case.name, function()
                local changes = diff_module.diff_issues(test_case.original, test_case.modified)

                assert.is_table(changes.dependencies)

                if test_case.expected_add then
                    assert.is_table(changes.dependencies.add)
                    assert.equals(#test_case.expected_add, #changes.dependencies.add)
                    for _, dep in ipairs(test_case.expected_add) do
                        assert.True(vim.tbl_contains(changes.dependencies.add, dep))
                    end
                else
                    assert.is_nil(changes.dependencies.add)
                end

                if test_case.expected_remove then
                    assert.is_table(changes.dependencies.remove)
                    assert.equals(#test_case.expected_remove, #changes.dependencies.remove)
                    for _, dep in ipairs(test_case.expected_remove) do
                        assert.True(vim.tbl_contains(changes.dependencies.remove, dep))
                    end
                else
                    assert.is_nil(changes.dependencies.remove)
                end
            end)
        end

        local parent_diff_test_cases = {
            {
                name = "parent being added",
                original = { id = "bd-1" },
                modified = { id = "bd-1", parent = "bd-50" },
                expected_parent_change = "bd-50",
            },
            {
                name = "parent being removed",
                original = { id = "bd-1", parent = "bd-50" },
                modified = { id = "bd-1" },
                expected_parent_change = "",
            },
            {
                name = "parent being changed",
                original = { id = "bd-1", parent = "bd-50" },
                modified = { id = "bd-1", parent = "bd-60" },
                expected_parent_change = "bd-60",
            },
        }

        for _, test_case in ipairs(parent_diff_test_cases) do
            it("should detect " .. test_case.name, function()
                local changes = diff_module.diff_issues(test_case.original, test_case.modified)

                assert.equals(test_case.expected_parent_change, changes.parent)
            end)
        end

        local section_diff_test_cases = {
            {
                name = "description change",
                original = { id = "bd-1", description = "Original description" },
                modified = { id = "bd-1", description = "Modified description" },
                expected_field = "description",
                expected_value = "Modified description",
            },
            {
                name = "description being added",
                original = { id = "bd-1" },
                modified = { id = "bd-1", description = "New description" },
                expected_field = "description",
                expected_value = "New description",
            },
            {
                name = "description being removed",
                original = { id = "bd-1", description = "Original description" },
                modified = { id = "bd-1", description = "" },
                expected_field = "description",
                expected_value = "",
            },
            {
                name = "acceptance_criteria change",
                original = { id = "bd-1", acceptance_criteria = "Must pass tests" },
                modified = { id = "bd-1", acceptance_criteria = "Must pass all tests and linting" },
                expected_field = "acceptance_criteria",
                expected_value = "Must pass all tests and linting",
            },
            {
                name = "design change",
                original = { id = "bd-1", design = "Use MVC" },
                modified = { id = "bd-1", design = "Use MVVM" },
                expected_field = "design",
                expected_value = "Use MVVM",
            },
            {
                name = "notes change",
                original = { id = "bd-1", notes = "Original notes" },
                modified = { id = "bd-1", notes = "Updated notes" },
                expected_field = "notes",
                expected_value = "Updated notes",
            },
        }

        for _, test_case in ipairs(section_diff_test_cases) do
            it("should detect " .. test_case.name, function()
                local changes = diff_module.diff_issues(test_case.original, test_case.modified)

                assert.is_table(changes.sections)
                assert.equals(test_case.expected_value, changes.sections[test_case.expected_field])
            end)
        end

        it("should detect multiple simultaneous changes", function()
            local original = {
                id = "bd-1",
                title = "Original Title",
                status = "open",
                priority = 2,
                labels = { "ui" },
                dependencies = { "bd-100" },
                parent = "bd-50",
                description = "Original description",
                acceptance_criteria = "Must work",
            }

            local modified = {
                id = "bd-1",
                title = "Modified Title",
                status = "in_progress",
                priority = 1,
                labels = { "ui", "backend" },
                dependencies = { "bd-120" },
                parent = "bd-60",
                description = "Modified description",
                design = "New design notes",
            }

            local changes = diff_module.diff_issues(original, modified)

            -- Metadata changes
            assert.is_table(changes.metadata)
            assert.equals("Modified Title", changes.metadata.title)
            assert.equals(1, changes.metadata.priority)

            -- Status change
            assert.equals("in_progress", changes.status)

            -- Label changes
            assert.is_table(changes.labels)
            assert.is_table(changes.labels.add)
            assert.True(vim.tbl_contains(changes.labels.add, "backend"))

            -- Dependency changes
            assert.is_table(changes.dependencies)
            assert.is_table(changes.dependencies.add)
            assert.True(vim.tbl_contains(changes.dependencies.add, "bd-120"))
            assert.is_table(changes.dependencies.remove)
            assert.True(vim.tbl_contains(changes.dependencies.remove, "bd-100"))

            -- Parent change
            assert.equals("bd-60", changes.parent)

            -- Section changes
            assert.is_table(changes.sections)
            assert.equals("Modified description", changes.sections.description)
            assert.equals("New design notes", changes.sections.design)
            -- acceptance_criteria was removed (in original but not in modified)
            assert.equals("", changes.sections.acceptance_criteria)
        end)

        it("should ignore read-only fields", function()
            local original = {
                id = "bd-1",
                title = "Test",
                created_at = "2023-10-27T10:00:00Z",
                updated_at = "2023-10-27T12:00:00Z",
            }

            local modified = {
                id = "bd-2", -- Changed ID (should be ignored)
                title = "Test",
                created_at = "2023-10-27T11:00:00Z", -- Changed timestamp (should be ignored)
                updated_at = "2023-10-27T13:00:00Z", -- Changed timestamp (should be ignored)
            }

            local changes = diff_module.diff_issues(original, modified)

            -- No changes should be detected
            assert.is_nil(changes.metadata)
            assert.is_nil(changes.status)
            assert.is_nil(changes.labels)
            assert.is_nil(changes.dependencies)
            assert.is_nil(changes.parent)
            assert.is_nil(changes.sections)
        end)

        it("should handle nil values correctly", function()
            local original = {
                id = "bd-1",
                title = "Test",
                description = nil,
                labels = {},
                dependencies = {},
            }

            local modified = {
                id = "bd-1",
                title = "Test",
                description = nil,
                labels = {},
                dependencies = {},
            }

            local changes = diff_module.diff_issues(original, modified)

            -- No changes should be detected
            assert.is_nil(changes.sections)
        end)

        it("should treat empty string and nil as different for sections", function()
            local original = {
                id = "bd-1",
                description = nil,
            }

            local modified = {
                id = "bd-1",
                description = "",
            }

            local changes = diff_module.diff_issues(original, modified)

            assert.is_table(changes.sections)
            assert.equals("", changes.sections.description)
        end)
    end)
end)
