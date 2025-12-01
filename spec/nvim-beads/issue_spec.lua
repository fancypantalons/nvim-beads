--- Unit tests for nvim-beads.issue module
--- Tests the format_issue_to_markdown function

describe('nvim-beads.issue', function()
    local issue_module

    before_each(function()
        -- Clear the module cache to get fresh instance
        package.loaded['nvim-beads.issue'] = nil
        issue_module = require('nvim-beads.issue')
    end)

    describe('format_issue_to_markdown', function()
        it('should format minimal issue with only required fields', function()
            local issue = {
                id = 'bd-1',
                title = 'Test Issue',
                issue_type = 'task',
                status = 'open',
                priority = 2,
                created_at = '2023-10-27T10:00:00Z',
                updated_at = '2023-10-27T12:00:00Z',
                closed_at = nil,
            }

            local lines = issue_module.format_issue_to_markdown(issue)

            assert.is_table(lines)
            assert.equals('---', lines[1])
            assert.equals('id: bd-1', lines[2])
            assert.equals('title: Test Issue', lines[3])
            assert.equals('type: task', lines[4])
            assert.equals('status: open', lines[5])
            assert.equals('priority: 2', lines[6])
            assert.equals('created_at: 2023-10-27T10:00:00Z', lines[7])
            assert.equals('updated_at: 2023-10-27T12:00:00Z', lines[8])
            assert.equals('closed_at: null', lines[9])
            assert.equals('---', lines[10])
            assert.equals('', lines[11])
        end)

        it('should map issue_type to type in frontmatter', function()
            local issue = {
                id = 'bd-1',
                title = 'Bug Fix',
                issue_type = 'bug',
                status = 'open',
                priority = 1,
                created_at = '2023-10-27T10:00:00Z',
                updated_at = '2023-10-27T12:00:00Z',
            }

            local lines = issue_module.format_issue_to_markdown(issue)

            -- Find the type line
            local found_type = false
            for _, line in ipairs(lines) do
                if line:match('^type:') then
                    assert.equals('type: bug', line)
                    found_type = true
                    break
                end
            end
            assert.is_true(found_type, 'Should have type field in frontmatter')
        end)

        it('should include parent field when parent-child dependency exists', function()
            local issue = {
                id = 'bd-5',
                title = 'Child Issue',
                issue_type = 'task',
                status = 'open',
                priority = 2,
                created_at = '2023-10-27T10:00:00Z',
                updated_at = '2023-10-27T12:00:00Z',
                dependencies = {
                    {
                        id = 'bd-100',
                        title = 'Parent Issue',
                        dependency_type = 'parent-child'
                    }
                }
            }

            local lines = issue_module.format_issue_to_markdown(issue)

            -- Find the parent line
            local found_parent = false
            for _, line in ipairs(lines) do
                if line:match('^parent:') then
                    assert.equals('parent: bd-100', line)
                    found_parent = true
                    break
                end
            end
            assert.is_true(found_parent, 'Should have parent field when parent-child dependency exists')
        end)

        it('should include dependencies list for blocks type', function()
            local issue = {
                id = 'bd-7',
                title = 'Issue with dependencies',
                issue_type = 'feature',
                status = 'blocked',
                priority = 1,
                created_at = '2023-10-27T10:00:00Z',
                updated_at = '2023-10-27T12:00:00Z',
                dependencies = {
                    {
                        id = 'bd-120',
                        title = 'First Blocker',
                        dependency_type = 'blocks'
                    },
                    {
                        id = 'bd-121',
                        title = 'Second Blocker',
                        dependency_type = 'blocks'
                    }
                }
            }

            local lines = issue_module.format_issue_to_markdown(issue)

            -- Convert to string for easier searching
            local content = table.concat(lines, '\n')

            assert.matches('dependencies:', content)
            assert.matches('  %- bd%-120', content)
            assert.matches('  %- bd%-121', content)
        end)

        it('should exclude parent-child from dependencies list', function()
            local issue = {
                id = 'bd-8',
                title = 'Issue with mixed dependencies',
                issue_type = 'task',
                status = 'open',
                priority = 2,
                created_at = '2023-10-27T10:00:00Z',
                updated_at = '2023-10-27T12:00:00Z',
                dependencies = {
                    {
                        id = 'bd-100',
                        title = 'Parent',
                        dependency_type = 'parent-child'
                    },
                    {
                        id = 'bd-121',
                        title = 'Blocker',
                        dependency_type = 'blocks'
                    }
                }
            }

            local lines = issue_module.format_issue_to_markdown(issue)
            local content = table.concat(lines, '\n')

            -- Should have parent field
            assert.matches('parent: bd%-100', content)

            -- Should have dependencies with only the blocker
            assert.matches('dependencies:', content)
            assert.matches('  %- bd%-121', content)

            -- Parent should not appear in dependencies list
            local deps_section = content:match('dependencies:(.-)created_at:')
            assert.is_not_nil(deps_section)
            assert.is_nil(deps_section:match('bd%-100'))
        end)

        it('should include labels when present', function()
            local issue = {
                id = 'bd-9',
                title = 'Labeled Issue',
                issue_type = 'feature',
                status = 'open',
                priority = 2,
                created_at = '2023-10-27T10:00:00Z',
                updated_at = '2023-10-27T12:00:00Z',
                labels = { 'ui', 'backend', 'urgent' }
            }

            local lines = issue_module.format_issue_to_markdown(issue)
            local content = table.concat(lines, '\n')

            assert.matches('labels:', content)
            assert.matches('  %- ui', content)
            assert.matches('  %- backend', content)
            assert.matches('  %- urgent', content)
        end)

        it('should omit labels when empty array', function()
            local issue = {
                id = 'bd-10',
                title = 'No Labels',
                issue_type = 'task',
                status = 'open',
                priority = 2,
                created_at = '2023-10-27T10:00:00Z',
                updated_at = '2023-10-27T12:00:00Z',
                labels = {}
            }

            local lines = issue_module.format_issue_to_markdown(issue)
            local content = table.concat(lines, '\n')

            assert.is_nil(content:match('labels:'))
        end)

        it('should include assignee when present', function()
            local issue = {
                id = 'bd-11',
                title = 'Assigned Issue',
                issue_type = 'bug',
                status = 'in_progress',
                priority = 1,
                created_at = '2023-10-27T10:00:00Z',
                updated_at = '2023-10-27T12:00:00Z',
                assignee = 'john.doe'
            }

            local lines = issue_module.format_issue_to_markdown(issue)
            local content = table.concat(lines, '\n')

            assert.matches('assignee: john%.doe', content)
        end)

        it('should include description section when present', function()
            local issue = {
                id = 'bd-12',
                title = 'Issue with Description',
                issue_type = 'feature',
                status = 'open',
                priority = 2,
                created_at = '2023-10-27T10:00:00Z',
                updated_at = '2023-10-27T12:00:00Z',
                description = 'This is a detailed description of the issue.'
            }

            local lines = issue_module.format_issue_to_markdown(issue)
            local content = table.concat(lines, '\n')

            assert.matches('# Description', content)
            assert.matches('This is a detailed description of the issue%.', content)
        end)

        it('should use single # for section headings', function()
            local issue = {
                id = 'bd-13',
                title = 'Check Heading Levels',
                issue_type = 'task',
                status = 'open',
                priority = 2,
                created_at = '2023-10-27T10:00:00Z',
                updated_at = '2023-10-27T12:00:00Z',
                description = 'Test description',
                acceptance_criteria = 'Test criteria',
                design = 'Test design',
                notes = 'Test notes'
            }

            local lines = issue_module.format_issue_to_markdown(issue)

            -- Find all heading lines
            local headings = {}
            for _, line in ipairs(lines) do
                if line:match('^#%s') then
                    table.insert(headings, line)
                end
            end

            -- Should have exactly 4 headings
            assert.equals(4, #headings)

            -- All should use single #
            for _, heading in ipairs(headings) do
                assert.is_not_nil(heading:match('^# %w'))
                assert.is_nil(heading:match('^## '))
            end
        end)

        it('should include acceptance_criteria section when present', function()
            local issue = {
                id = 'bd-14',
                title = 'Issue with Acceptance Criteria',
                issue_type = 'feature',
                status = 'open',
                priority = 2,
                created_at = '2023-10-27T10:00:00Z',
                updated_at = '2023-10-27T12:00:00Z',
                acceptance_criteria = 'Must pass all tests\nMust work on all browsers'
            }

            local lines = issue_module.format_issue_to_markdown(issue)
            local content = table.concat(lines, '\n')

            assert.matches('# Acceptance Criteria', content)
            assert.matches('Must pass all tests', content)
        end)

        it('should include design section when present', function()
            local issue = {
                id = 'bd-15',
                title = 'Issue with Design',
                issue_type = 'feature',
                status = 'open',
                priority = 2,
                created_at = '2023-10-27T10:00:00Z',
                updated_at = '2023-10-27T12:00:00Z',
                design = 'Use MVC pattern\nImplement with React'
            }

            local lines = issue_module.format_issue_to_markdown(issue)
            local content = table.concat(lines, '\n')

            assert.matches('# Design', content)
            assert.matches('Use MVC pattern', content)
        end)

        it('should include notes section when present', function()
            local issue = {
                id = 'bd-16',
                title = 'Issue with Notes',
                issue_type = 'bug',
                status = 'open',
                priority = 2,
                created_at = '2023-10-27T10:00:00Z',
                updated_at = '2023-10-27T12:00:00Z',
                notes = 'Remember to update documentation'
            }

            local lines = issue_module.format_issue_to_markdown(issue)
            local content = table.concat(lines, '\n')

            assert.matches('# Notes', content)
            assert.matches('Remember to update documentation', content)
        end)

        it('should omit empty description section', function()
            local issue = {
                id = 'bd-17',
                title = 'Issue without Description',
                issue_type = 'task',
                status = 'open',
                priority = 2,
                created_at = '2023-10-27T10:00:00Z',
                updated_at = '2023-10-27T12:00:00Z',
                description = ''
            }

            local lines = issue_module.format_issue_to_markdown(issue)
            local content = table.concat(lines, '\n')

            assert.is_nil(content:match('# Description'))
        end)

        it('should omit nil sections', function()
            local issue = {
                id = 'bd-18',
                title = 'Issue with nil sections',
                issue_type = 'task',
                status = 'open',
                priority = 2,
                created_at = '2023-10-27T10:00:00Z',
                updated_at = '2023-10-27T12:00:00Z',
                description = nil,
                acceptance_criteria = nil,
                design = nil,
                notes = nil
            }

            local lines = issue_module.format_issue_to_markdown(issue)
            local content = table.concat(lines, '\n')

            assert.is_nil(content:match('# Description'))
            assert.is_nil(content:match('# Acceptance Criteria'))
            assert.is_nil(content:match('# Design'))
            assert.is_nil(content:match('# Notes'))
        end)

        it('should show closed_at timestamp when present', function()
            local issue = {
                id = 'bd-19',
                title = 'Closed Issue',
                issue_type = 'bug',
                status = 'closed',
                priority = 1,
                created_at = '2023-10-27T10:00:00Z',
                updated_at = '2023-10-27T12:00:00Z',
                closed_at = '2023-10-27T14:00:00Z'
            }

            local lines = issue_module.format_issue_to_markdown(issue)
            local content = table.concat(lines, '\n')

            assert.matches('closed_at: 2023%-10%-27T14:00:00Z', content)
        end)

        it('should format complete issue with all fields', function()
            local issue = {
                id = 'bd-20',
                title = 'Complete Issue',
                issue_type = 'feature',
                status = 'in_progress',
                priority = 1,
                created_at = '2023-10-27T10:00:00Z',
                updated_at = '2023-10-27T12:00:00Z',
                closed_at = nil,
                assignee = 'jane.smith',
                labels = { 'ui', 'backend' },
                dependencies = {
                    {
                        id = 'bd-100',
                        title = 'Parent',
                        dependency_type = 'parent-child'
                    },
                    {
                        id = 'bd-120',
                        title = 'Blocker 1',
                        dependency_type = 'blocks'
                    },
                    {
                        id = 'bd-121',
                        title = 'Blocker 2',
                        dependency_type = 'blocks'
                    }
                },
                description = 'A comprehensive description',
                acceptance_criteria = 'Must meet all requirements',
                design = 'Technical design notes',
                notes = 'Additional information'
            }

            local lines = issue_module.format_issue_to_markdown(issue)
            local content = table.concat(lines, '\n')

            -- Check frontmatter fields
            assert.matches('id: bd%-20', content)
            assert.matches('title: Complete Issue', content)
            assert.matches('type: feature', content)
            assert.matches('status: in_progress', content)
            assert.matches('priority: 1', content)
            assert.matches('parent: bd%-100', content)
            assert.matches('dependencies:', content)
            assert.matches('  %- bd%-120', content)
            assert.matches('  %- bd%-121', content)
            assert.matches('labels:', content)
            assert.matches('  %- ui', content)
            assert.matches('  %- backend', content)
            assert.matches('assignee: jane%.smith', content)

            -- Check markdown sections
            assert.matches('# Description', content)
            assert.matches('A comprehensive description', content)
            assert.matches('# Acceptance Criteria', content)
            assert.matches('Must meet all requirements', content)
            assert.matches('# Design', content)
            assert.matches('Technical design notes', content)
            assert.matches('# Notes', content)
            assert.matches('Additional information', content)
        end)
    end)
end)
