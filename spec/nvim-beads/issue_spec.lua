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

    describe('open_issue_buffer', function()
        local original_vim_api_create_buf
        local original_vim_api_set_name
        local original_vim_api_set_lines
        local original_vim_api_set_option_value
        local original_vim_api_set_current_buf
        local original_vim_notify

        -- Mock state
        local created_bufnr
        local buffer_name
        local buffer_lines
        local buffer_options
        local current_buf
        local notifications

        before_each(function()
            -- Clear the module cache
            package.loaded['nvim-beads.issue'] = nil
            package.loaded['nvim-beads.core'] = nil
            issue_module = require('nvim-beads.issue')

            -- Save originals
            original_vim_api_create_buf = vim.api.nvim_create_buf
            original_vim_api_set_name = vim.api.nvim_buf_set_name
            original_vim_api_set_lines = vim.api.nvim_buf_set_lines
            original_vim_api_set_option_value = vim.api.nvim_set_option_value
            original_vim_api_set_current_buf = vim.api.nvim_set_current_buf
            original_vim_notify = vim.notify

            -- Reset mock state
            created_bufnr = 42
            buffer_name = nil
            buffer_lines = nil
            buffer_options = {}
            current_buf = nil
            notifications = {}

            -- Mock vim.api functions
            vim.api.nvim_create_buf = function(listed, scratch)
                return created_bufnr
            end

            vim.api.nvim_buf_set_name = function(bufnr, name)
                buffer_name = name
            end

            vim.api.nvim_buf_set_lines = function(bufnr, start, end_line, strict_indexing, lines)
                buffer_lines = lines
            end

            vim.api.nvim_set_option_value = function(option, value, opts)
                if opts and opts.buf then
                    if not buffer_options[opts.buf] then
                        buffer_options[opts.buf] = {}
                    end
                    buffer_options[opts.buf][option] = value
                end
            end

            vim.api.nvim_set_current_buf = function(bufnr)
                current_buf = bufnr
            end

            vim.notify = function(msg, level)
                table.insert(notifications, { message = msg, level = level })
            end
        end)

        after_each(function()
            -- Restore originals
            vim.api.nvim_create_buf = original_vim_api_create_buf
            vim.api.nvim_buf_set_name = original_vim_api_set_name
            vim.api.nvim_buf_set_lines = original_vim_api_set_lines
            vim.api.nvim_set_option_value = original_vim_api_set_option_value
            vim.api.nvim_set_current_buf = original_vim_api_set_current_buf
            vim.notify = original_vim_notify
        end)

        describe('argument validation', function()
            it('should return false and notify error when issue_id is nil', function()
                local success = issue_module.open_issue_buffer(nil)

                assert.is_false(success)
                assert.equals(1, #notifications)
                assert.matches('Invalid issue ID', notifications[1].message)
                assert.equals(vim.log.levels.ERROR, notifications[1].level)
            end)

            it('should return false and notify error when issue_id is empty string', function()
                local success = issue_module.open_issue_buffer('')

                assert.is_false(success)
                assert.equals(1, #notifications)
                assert.matches('Invalid issue ID', notifications[1].message)
            end)

            it('should return false and notify error when issue_id is not a string', function()
                local success = issue_module.open_issue_buffer(123)

                assert.is_false(success)
                assert.equals(1, #notifications)
                assert.matches('Invalid issue ID', notifications[1].message)
            end)
        end)

        describe('bd command execution', function()
            it('should execute bd show with the correct issue_id', function()
                local executed_args = nil

                -- Mock core.execute_bd
                local core = require('nvim-beads.core')
                local original_execute_bd = core.execute_bd
                core.execute_bd = function(args)
                    executed_args = args
                    return {{
                        id = 'bd-1',
                        title = 'Test',
                        issue_type = 'task',
                        status = 'open',
                        priority = 2,
                        created_at = '2023-10-27T10:00:00Z',
                        updated_at = '2023-10-27T12:00:00Z',
                    }}, nil
                end

                issue_module.open_issue_buffer('bd-1')

                assert.is_not_nil(executed_args)
                assert.equals('show', executed_args[1])
                assert.equals('bd-1', executed_args[2])

                -- Restore
                core.execute_bd = original_execute_bd
            end)

            it('should return false and notify error when bd command fails', function()
                local core = require('nvim-beads.core')
                local original_execute_bd = core.execute_bd
                core.execute_bd = function(args)
                    return nil, 'Command failed: bd not found'
                end

                local success = issue_module.open_issue_buffer('bd-1')

                assert.is_false(success)
                assert.equals(1, #notifications)
                assert.matches('Failed to fetch issue bd%-1', notifications[1].message)
                assert.matches('Command failed', notifications[1].message)
                assert.equals(vim.log.levels.ERROR, notifications[1].level)

                -- Restore
                core.execute_bd = original_execute_bd
            end)

            it('should return false when issue data is invalid', function()
                local core = require('nvim-beads.core')
                local original_execute_bd = core.execute_bd
                core.execute_bd = function(args)
                    return {}, nil  -- Empty array
                end

                local success = issue_module.open_issue_buffer('bd-1')

                assert.is_false(success)
                assert.equals(1, #notifications)
                assert.matches('Invalid issue data', notifications[1].message)

                -- Restore
                core.execute_bd = original_execute_bd
            end)

            it('should return false when result array contains invalid issue', function()
                local core = require('nvim-beads.core')
                local original_execute_bd = core.execute_bd
                core.execute_bd = function(args)
                    return {{}}, nil  -- Array with empty object
                end

                local success = issue_module.open_issue_buffer('bd-1')

                assert.is_false(success)
                assert.equals(1, #notifications)
                assert.matches('Invalid issue data', notifications[1].message)

                -- Restore
                core.execute_bd = original_execute_bd
            end)
        end)

        describe('buffer creation and configuration', function()
            before_each(function()
                -- Mock successful bd execution
                local core = require('nvim-beads.core')
                local original_execute_bd = core.execute_bd
                core.execute_bd = function(args)
                    return {{
                        id = 'bd-1',
                        title = 'Test Issue',
                        issue_type = 'task',
                        status = 'open',
                        priority = 2,
                        created_at = '2023-10-27T10:00:00Z',
                        updated_at = '2023-10-27T12:00:00Z',
                    }}, nil
                end
            end)

            it('should create buffer with correct name', function()
                issue_module.open_issue_buffer('bd-1')

                assert.equals('beads://issue/bd-1', buffer_name)
            end)

            it('should create buffer with correct name for longer issue IDs', function()
                -- Mock bd execution for longer ID
                local core = require('nvim-beads.core')
                core.execute_bd = function(args)
                    return {{
                        id = 'nvim-beads-p69',
                        title = 'Test',
                        issue_type = 'task',
                        status = 'open',
                        priority = 2,
                        created_at = '2023-10-27T10:00:00Z',
                        updated_at = '2023-10-27T12:00:00Z',
                    }}, nil
                end

                issue_module.open_issue_buffer('nvim-beads-p69')

                assert.equals('beads://issue/nvim-beads-p69', buffer_name)
            end)

            it('should set filetype to markdown', function()
                issue_module.open_issue_buffer('bd-1')

                assert.is_not_nil(buffer_options[created_bufnr])
                assert.equals('markdown', buffer_options[created_bufnr].filetype)
            end)

            it('should set buftype to acwrite', function()
                issue_module.open_issue_buffer('bd-1')

                assert.equals('acwrite', buffer_options[created_bufnr].buftype)
            end)

            it('should set bufhidden to hide', function()
                issue_module.open_issue_buffer('bd-1')

                assert.equals('hide', buffer_options[created_bufnr].bufhidden)
            end)

            it('should populate buffer with formatted content', function()
                issue_module.open_issue_buffer('bd-1')

                assert.is_not_nil(buffer_lines)
                assert.is_table(buffer_lines)
                assert.is_true(#buffer_lines > 0)

                -- Check for YAML frontmatter
                local content = table.concat(buffer_lines, '\n')
                assert.matches('---', content)
                assert.matches('id: bd%-1', content)
                assert.matches('title: Test Issue', content)
            end)

            it('should display buffer in current window', function()
                issue_module.open_issue_buffer('bd-1')

                assert.equals(created_bufnr, current_buf)
            end)

            it('should return true on success', function()
                local success = issue_module.open_issue_buffer('bd-1')

                assert.is_true(success)
            end)
        end)

        describe('integration with format_issue_to_markdown', function()
            it('should format complete issue correctly in buffer', function()
                local core = require('nvim-beads.core')
                core.execute_bd = function(args)
                    return {{
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
                                title = 'Blocker',
                                dependency_type = 'blocks'
                            }
                        },
                        description = 'A comprehensive description',
                        acceptance_criteria = 'Must meet all requirements',
                        design = 'Technical design notes',
                        notes = 'Additional information'
                    }}, nil
                end

                issue_module.open_issue_buffer('bd-20')

                assert.is_not_nil(buffer_lines)
                local content = table.concat(buffer_lines, '\n')

                -- Verify all sections are included
                assert.matches('id: bd%-20', content)
                assert.matches('title: Complete Issue', content)
                assert.matches('assignee: jane%.smith', content)
                assert.matches('parent: bd%-100', content)
                assert.matches('  %- bd%-120', content)
                assert.matches('# Description', content)
                assert.matches('# Acceptance Criteria', content)
                assert.matches('# Design', content)
                assert.matches('# Notes', content)
            end)
        end)
    end)
end)
