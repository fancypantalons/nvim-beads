--- Unit tests for nvim-beads.issue diff_issues function
--- Tests the comparison logic to detect changes between original and modified issue states

describe('nvim-beads.issue', function()
    local issue_module

    before_each(function()
        -- Clear the module cache to get fresh instance
        package.loaded['nvim-beads.issue'] = nil
        issue_module = require('nvim-beads.issue')
    end)

    describe('diff_issues', function()
        it('should detect no changes when states are identical', function()
            local original = {
                id = 'bd-1',
                title = 'Test Issue',
                issue_type = 'task',
                status = 'open',
                priority = 2,
                labels = {},
                dependencies = {},
                description = 'Test description',
                created_at = '2023-10-27T10:00:00Z',
                updated_at = '2023-10-27T12:00:00Z'
            }

            local modified = {
                id = 'bd-1',
                title = 'Test Issue',
                issue_type = 'task',
                status = 'open',
                priority = 2,
                labels = {},
                dependencies = {},
                description = 'Test description',
                created_at = '2023-10-27T10:00:00Z',
                updated_at = '2023-10-27T12:00:00Z'
            }

            local changes = issue_module.diff_issues(original, modified)

            assert.is_table(changes)
            assert.is_nil(changes.metadata)
            assert.is_nil(changes.status)
            assert.is_nil(changes.labels)
            assert.is_nil(changes.dependencies)
            assert.is_nil(changes.parent)
            assert.is_nil(changes.sections)
        end)

        it('should detect title change in metadata', function()
            local original = {
                id = 'bd-1',
                title = 'Original Title',
                priority = 2
            }

            local modified = {
                id = 'bd-1',
                title = 'Modified Title',
                priority = 2
            }

            local changes = issue_module.diff_issues(original, modified)

            assert.is_table(changes.metadata)
            assert.equals('Modified Title', changes.metadata.title)
            assert.is_nil(changes.metadata.priority)
        end)

        it('should detect priority change in metadata', function()
            local original = {
                id = 'bd-1',
                title = 'Test',
                priority = 2
            }

            local modified = {
                id = 'bd-1',
                title = 'Test',
                priority = 1
            }

            local changes = issue_module.diff_issues(original, modified)

            assert.is_table(changes.metadata)
            assert.equals(1, changes.metadata.priority)
            assert.is_nil(changes.metadata.title)
        end)

        it('should detect assignee change in metadata', function()
            local original = {
                id = 'bd-1',
                assignee = 'john.doe'
            }

            local modified = {
                id = 'bd-1',
                assignee = 'jane.smith'
            }

            local changes = issue_module.diff_issues(original, modified)

            assert.is_table(changes.metadata)
            assert.equals('jane.smith', changes.metadata.assignee)
        end)

        it('should detect assignee being added', function()
            local original = {
                id = 'bd-1'
            }

            local modified = {
                id = 'bd-1',
                assignee = 'john.doe'
            }

            local changes = issue_module.diff_issues(original, modified)

            assert.is_table(changes.metadata)
            assert.equals('john.doe', changes.metadata.assignee)
        end)

        it('should detect assignee being removed', function()
            local original = {
                id = 'bd-1',
                assignee = 'john.doe'
            }

            local modified = {
                id = 'bd-1'
            }

            local changes = issue_module.diff_issues(original, modified)

            assert.is_table(changes.metadata)
            assert.equals('', changes.metadata.assignee)
        end)

        it('should detect status change', function()
            local original = {
                id = 'bd-1',
                status = 'open'
            }

            local modified = {
                id = 'bd-1',
                status = 'in_progress'
            }

            local changes = issue_module.diff_issues(original, modified)

            assert.equals('in_progress', changes.status)
        end)

        it('should detect label additions', function()
            local original = {
                id = 'bd-1',
                labels = {}
            }

            local modified = {
                id = 'bd-1',
                labels = {'ui', 'backend'}
            }

            local changes = issue_module.diff_issues(original, modified)

            assert.is_table(changes.labels)
            assert.is_table(changes.labels.add)
            assert.equals(2, #changes.labels.add)
            assert.True(vim.tbl_contains(changes.labels.add, 'ui'))
            assert.True(vim.tbl_contains(changes.labels.add, 'backend'))
            assert.is_nil(changes.labels.remove)
        end)

        it('should detect label removals', function()
            local original = {
                id = 'bd-1',
                labels = {'ui', 'backend', 'urgent'}
            }

            local modified = {
                id = 'bd-1',
                labels = {'ui'}
            }

            local changes = issue_module.diff_issues(original, modified)

            assert.is_table(changes.labels)
            assert.is_table(changes.labels.remove)
            assert.equals(2, #changes.labels.remove)
            assert.True(vim.tbl_contains(changes.labels.remove, 'backend'))
            assert.True(vim.tbl_contains(changes.labels.remove, 'urgent'))
            assert.is_nil(changes.labels.add)
        end)

        it('should detect both label additions and removals', function()
            local original = {
                id = 'bd-1',
                labels = {'ui', 'old-label'}
            }

            local modified = {
                id = 'bd-1',
                labels = {'ui', 'backend', 'new-label'}
            }

            local changes = issue_module.diff_issues(original, modified)

            assert.is_table(changes.labels)
            assert.is_table(changes.labels.add)
            assert.equals(2, #changes.labels.add)
            assert.True(vim.tbl_contains(changes.labels.add, 'backend'))
            assert.True(vim.tbl_contains(changes.labels.add, 'new-label'))
            assert.is_table(changes.labels.remove)
            assert.equals(1, #changes.labels.remove)
            assert.True(vim.tbl_contains(changes.labels.remove, 'old-label'))
        end)

        it('should detect dependency additions', function()
            local original = {
                id = 'bd-1',
                dependencies = {}
            }

            local modified = {
                id = 'bd-1',
                dependencies = {'bd-120', 'bd-121'}
            }

            local changes = issue_module.diff_issues(original, modified)

            assert.is_table(changes.dependencies)
            assert.is_table(changes.dependencies.add)
            assert.equals(2, #changes.dependencies.add)
            assert.True(vim.tbl_contains(changes.dependencies.add, 'bd-120'))
            assert.True(vim.tbl_contains(changes.dependencies.add, 'bd-121'))
            assert.is_nil(changes.dependencies.remove)
        end)

        it('should detect dependency removals', function()
            local original = {
                id = 'bd-1',
                dependencies = {'bd-100', 'bd-101', 'bd-102'}
            }

            local modified = {
                id = 'bd-1',
                dependencies = {'bd-100'}
            }

            local changes = issue_module.diff_issues(original, modified)

            assert.is_table(changes.dependencies)
            assert.is_table(changes.dependencies.remove)
            assert.equals(2, #changes.dependencies.remove)
            assert.True(vim.tbl_contains(changes.dependencies.remove, 'bd-101'))
            assert.True(vim.tbl_contains(changes.dependencies.remove, 'bd-102'))
            assert.is_nil(changes.dependencies.add)
        end)

        it('should detect both dependency additions and removals', function()
            local original = {
                id = 'bd-1',
                dependencies = {'bd-100', 'bd-101'}
            }

            local modified = {
                id = 'bd-1',
                dependencies = {'bd-100', 'bd-120', 'bd-121'}
            }

            local changes = issue_module.diff_issues(original, modified)

            assert.is_table(changes.dependencies)
            assert.is_table(changes.dependencies.add)
            assert.equals(2, #changes.dependencies.add)
            assert.True(vim.tbl_contains(changes.dependencies.add, 'bd-120'))
            assert.True(vim.tbl_contains(changes.dependencies.add, 'bd-121'))
            assert.is_table(changes.dependencies.remove)
            assert.equals(1, #changes.dependencies.remove)
            assert.True(vim.tbl_contains(changes.dependencies.remove, 'bd-101'))
        end)

        it('should detect parent being added', function()
            local original = {
                id = 'bd-1'
            }

            local modified = {
                id = 'bd-1',
                parent = 'bd-50'
            }

            local changes = issue_module.diff_issues(original, modified)

            assert.equals('bd-50', changes.parent)
        end)

        it('should detect parent being removed', function()
            local original = {
                id = 'bd-1',
                parent = 'bd-50'
            }

            local modified = {
                id = 'bd-1'
            }

            local changes = issue_module.diff_issues(original, modified)

            -- Special marker for removal
            assert.equals('', changes.parent)
        end)

        it('should detect parent being changed', function()
            local original = {
                id = 'bd-1',
                parent = 'bd-50'
            }

            local modified = {
                id = 'bd-1',
                parent = 'bd-60'
            }

            local changes = issue_module.diff_issues(original, modified)

            assert.equals('bd-60', changes.parent)
        end)

        it('should detect description change', function()
            local original = {
                id = 'bd-1',
                description = 'Original description'
            }

            local modified = {
                id = 'bd-1',
                description = 'Modified description'
            }

            local changes = issue_module.diff_issues(original, modified)

            assert.is_table(changes.sections)
            assert.equals('Modified description', changes.sections.description)
        end)

        it('should detect description being added', function()
            local original = {
                id = 'bd-1'
            }

            local modified = {
                id = 'bd-1',
                description = 'New description'
            }

            local changes = issue_module.diff_issues(original, modified)

            assert.is_table(changes.sections)
            assert.equals('New description', changes.sections.description)
        end)

        it('should detect description being removed', function()
            local original = {
                id = 'bd-1',
                description = 'Original description'
            }

            local modified = {
                id = 'bd-1',
                description = ''
            }

            local changes = issue_module.diff_issues(original, modified)

            assert.is_table(changes.sections)
            assert.equals('', changes.sections.description)
        end)

        it('should detect acceptance_criteria change', function()
            local original = {
                id = 'bd-1',
                acceptance_criteria = 'Must pass tests'
            }

            local modified = {
                id = 'bd-1',
                acceptance_criteria = 'Must pass all tests and linting'
            }

            local changes = issue_module.diff_issues(original, modified)

            assert.is_table(changes.sections)
            assert.equals('Must pass all tests and linting', changes.sections.acceptance_criteria)
        end)

        it('should detect design change', function()
            local original = {
                id = 'bd-1',
                design = 'Use MVC'
            }

            local modified = {
                id = 'bd-1',
                design = 'Use MVVM'
            }

            local changes = issue_module.diff_issues(original, modified)

            assert.is_table(changes.sections)
            assert.equals('Use MVVM', changes.sections.design)
        end)

        it('should detect notes change', function()
            local original = {
                id = 'bd-1',
                notes = 'Original notes'
            }

            local modified = {
                id = 'bd-1',
                notes = 'Updated notes'
            }

            local changes = issue_module.diff_issues(original, modified)

            assert.is_table(changes.sections)
            assert.equals('Updated notes', changes.sections.notes)
        end)

        it('should detect multiple simultaneous changes', function()
            local original = {
                id = 'bd-1',
                title = 'Original Title',
                status = 'open',
                priority = 2,
                labels = {'ui'},
                dependencies = {'bd-100'},
                parent = 'bd-50',
                description = 'Original description',
                acceptance_criteria = 'Must work'
            }

            local modified = {
                id = 'bd-1',
                title = 'Modified Title',
                status = 'in_progress',
                priority = 1,
                labels = {'ui', 'backend'},
                dependencies = {'bd-120'},
                parent = 'bd-60',
                description = 'Modified description',
                design = 'New design notes'
            }

            local changes = issue_module.diff_issues(original, modified)

            -- Metadata changes
            assert.is_table(changes.metadata)
            assert.equals('Modified Title', changes.metadata.title)
            assert.equals(1, changes.metadata.priority)

            -- Status change
            assert.equals('in_progress', changes.status)

            -- Label changes
            assert.is_table(changes.labels)
            assert.is_table(changes.labels.add)
            assert.True(vim.tbl_contains(changes.labels.add, 'backend'))

            -- Dependency changes
            assert.is_table(changes.dependencies)
            assert.is_table(changes.dependencies.add)
            assert.True(vim.tbl_contains(changes.dependencies.add, 'bd-120'))
            assert.is_table(changes.dependencies.remove)
            assert.True(vim.tbl_contains(changes.dependencies.remove, 'bd-100'))

            -- Parent change
            assert.equals('bd-60', changes.parent)

            -- Section changes
            assert.is_table(changes.sections)
            assert.equals('Modified description', changes.sections.description)
            assert.equals('New design notes', changes.sections.design)
            -- acceptance_criteria was removed (in original but not in modified)
            assert.equals('', changes.sections.acceptance_criteria)
        end)

        it('should ignore read-only fields', function()
            local original = {
                id = 'bd-1',
                title = 'Test',
                created_at = '2023-10-27T10:00:00Z',
                updated_at = '2023-10-27T12:00:00Z'
            }

            local modified = {
                id = 'bd-2',  -- Changed ID (should be ignored)
                title = 'Test',
                created_at = '2023-10-27T11:00:00Z',  -- Changed timestamp (should be ignored)
                updated_at = '2023-10-27T13:00:00Z'   -- Changed timestamp (should be ignored)
            }

            local changes = issue_module.diff_issues(original, modified)

            -- No changes should be detected
            assert.is_nil(changes.metadata)
            assert.is_nil(changes.status)
            assert.is_nil(changes.labels)
            assert.is_nil(changes.dependencies)
            assert.is_nil(changes.parent)
            assert.is_nil(changes.sections)
        end)

        it('should handle nil values correctly', function()
            local original = {
                id = 'bd-1',
                title = 'Test',
                description = nil,
                labels = {},
                dependencies = {}
            }

            local modified = {
                id = 'bd-1',
                title = 'Test',
                description = nil,
                labels = {},
                dependencies = {}
            }

            local changes = issue_module.diff_issues(original, modified)

            -- No changes should be detected
            assert.is_nil(changes.sections)
        end)

        it('should treat empty string and nil as different for sections', function()
            local original = {
                id = 'bd-1',
                description = nil
            }

            local modified = {
                id = 'bd-1',
                description = ''
            }

            local changes = issue_module.diff_issues(original, modified)

            assert.is_table(changes.sections)
            assert.equals('', changes.sections.description)
        end)
    end)
end)
