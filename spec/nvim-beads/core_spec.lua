--- Unit tests for nvim-beads core module
--- Tests use mocked vim.system to verify JSON parsing and error handling

describe('nvim-beads.core', function()
    local core
    local original_vim_system

    before_each(function()
        -- Clear the module cache to get fresh instance
        package.loaded['nvim-beads.core'] = nil
        core = require('nvim-beads.core')

        -- Save original vim.system
        original_vim_system = vim.system
    end)

    after_each(function()
        -- Restore original vim.system
        vim.system = original_vim_system
    end)

    describe('execute_bd', function()
        describe('argument validation', function()
            it('should return error when args is not a table', function()
                local result, err = core.execute_bd('not a table')
                assert.is_nil(result)
                assert.is_not_nil(err)
                assert.matches('args must be a table', err)
            end)

            it('should return error when args is nil', function()
                local result, err = core.execute_bd(nil)
                assert.is_nil(result)
                assert.is_not_nil(err)
                assert.matches('args must be a table', err)
            end)

            it('should return error when args is a number', function()
                local result, err = core.execute_bd(42)
                assert.is_nil(result)
                assert.is_not_nil(err)
                assert.matches('args must be a table', err)
            end)
        end)

        describe('successful command execution', function()
            it('should parse JSON output correctly', function()
                -- Mock successful command execution
                vim.system = function(cmd, opts)
                    return {
                        wait = function()
                            return {
                                code = 0,
                                stdout = '{"result": [{"id": "bd-1", "title": "Test issue"}]}',
                                stderr = ''
                            }
                        end
                    }
                end

                local result, err = core.execute_bd({ 'ready' })
                assert.is_nil(err)
                assert.is_not_nil(result)
                assert.is_table(result)
                assert.is_table(result.result)
                assert.equals('bd-1', result.result[1].id)
                assert.equals('Test issue', result.result[1].title)
            end)

            it('should automatically add --json flag if not present', function()
                local called_with_json = false

                vim.system = function(cmd, opts)
                    -- Check if --json flag is present
                    for _, arg in ipairs(cmd) do
                        if arg == '--json' then
                            called_with_json = true
                            break
                        end
                    end

                    return {
                        wait = function()
                            return {
                                code = 0,
                                stdout = '{"result": []}',
                                stderr = ''
                            }
                        end
                    }
                end

                local result, err = core.execute_bd({ 'ready' })
                assert.is_nil(err)
                assert.is_true(called_with_json)
            end)

            it('should not duplicate --json flag if already present', function()
                local json_count = 0

                vim.system = function(cmd, opts)
                    -- Count how many times --json appears
                    for _, arg in ipairs(cmd) do
                        if arg == '--json' then
                            json_count = json_count + 1
                        end
                    end

                    return {
                        wait = function()
                            return {
                                code = 0,
                                stdout = '{"result": []}',
                                stderr = ''
                            }
                        end
                    }
                end

                local result, err = core.execute_bd({ 'ready', '--json' })
                assert.is_nil(err)
                assert.equals(1, json_count)
            end)

            it('should pass text=true option to vim.system', function()
                local received_opts = nil

                vim.system = function(cmd, opts)
                    received_opts = opts

                    return {
                        wait = function()
                            return {
                                code = 0,
                                stdout = '{"result": []}',
                                stderr = ''
                            }
                        end
                    }
                end

                local result, err = core.execute_bd({ 'ready' })
                assert.is_nil(err)
                assert.is_not_nil(received_opts)
                assert.is_true(received_opts.text)
            end)

            it('should allow custom options to override defaults', function()
                local received_opts = nil

                vim.system = function(cmd, opts)
                    received_opts = opts

                    return {
                        wait = function()
                            return {
                                code = 0,
                                stdout = '{"result": []}',
                                stderr = ''
                            }
                        end
                    }
                end

                local result, err = core.execute_bd({ 'ready' }, { timeout = 5000 })
                assert.is_nil(err)
                assert.is_not_nil(received_opts)
                assert.equals(5000, received_opts.timeout)
                assert.is_true(received_opts.text) -- Default should still be there
            end)
        end)

        describe('command failure handling', function()
            it('should return error when command fails with non-zero exit code', function()
                vim.system = function(cmd, opts)
                    return {
                        wait = function()
                            return {
                                code = 1,
                                stdout = '',
                                stderr = 'Command not found'
                            }
                        end
                    }
                end

                local result, err = core.execute_bd({ 'invalid_command' })
                assert.is_nil(result)
                assert.is_not_nil(err)
                assert.matches('bd command failed', err)
                assert.matches('exit code 1', err)
                assert.matches('Command not found', err)
            end)

            it('should handle empty stderr in error message', function()
                vim.system = function(cmd, opts)
                    return {
                        wait = function()
                            return {
                                code = 127,
                                stdout = '',
                                stderr = ''
                            }
                        end
                    }
                end

                local result, err = core.execute_bd({ 'missing_command' })
                assert.is_nil(result)
                assert.is_not_nil(err)
                assert.matches('exit code 127', err)
                assert.matches('no error output', err)
            end)

            it('should handle nil stderr in error message', function()
                vim.system = function(cmd, opts)
                    return {
                        wait = function()
                            return {
                                code = 1,
                                stdout = '',
                                stderr = nil
                            }
                        end
                    }
                end

                local result, err = core.execute_bd({ 'failing_command' })
                assert.is_nil(result)
                assert.is_not_nil(err)
                assert.matches('no error output', err)
            end)
        end)

        describe('JSON parsing error handling', function()
            it('should return error when output is not valid JSON', function()
                vim.system = function(cmd, opts)
                    return {
                        wait = function()
                            return {
                                code = 0,
                                stdout = 'This is not JSON',
                                stderr = ''
                            }
                        end
                    }
                end

                local result, err = core.execute_bd({ 'ready' })
                assert.is_nil(result)
                assert.is_not_nil(err)
                assert.matches('Failed to parse JSON output', err)
            end)

            it('should return error when JSON is incomplete', function()
                vim.system = function(cmd, opts)
                    return {
                        wait = function()
                            return {
                                code = 0,
                                stdout = '{"result": [',
                                stderr = ''
                            }
                        end
                    }
                end

                local result, err = core.execute_bd({ 'ready' })
                assert.is_nil(result)
                assert.is_not_nil(err)
                assert.matches('Failed to parse JSON output', err)
            end)

            it('should return error when JSON is empty string', function()
                vim.system = function(cmd, opts)
                    return {
                        wait = function()
                            return {
                                code = 0,
                                stdout = '',
                                stderr = ''
                            }
                        end
                    }
                end

                local result, err = core.execute_bd({ 'ready' })
                assert.is_nil(result)
                assert.is_not_nil(err)
                assert.matches('Failed to parse JSON output', err)
            end)
        end)

        describe('complex JSON structures', function()
            it('should parse nested objects correctly', function()
                vim.system = function(cmd, opts)
                    return {
                        wait = function()
                            return {
                                code = 0,
                                stdout = '{"result": {"nested": {"deep": "value"}}}',
                                stderr = ''
                            }
                        end
                    }
                end

                local result, err = core.execute_bd({ 'ready' })
                assert.is_nil(err)
                assert.is_not_nil(result)
                assert.equals('value', result.result.nested.deep)
            end)

            it('should parse arrays with multiple elements', function()
                vim.system = function(cmd, opts)
                    return {
                        wait = function()
                            return {
                                code = 0,
                                stdout = '{"issues": [{"id": "bd-1"}, {"id": "bd-2"}, {"id": "bd-3"}]}',
                                stderr = ''
                            }
                        end
                    }
                end

                local result, err = core.execute_bd({ 'list' })
                assert.is_nil(err)
                assert.is_not_nil(result)
                assert.equals(3, #result.issues)
                assert.equals('bd-1', result.issues[1].id)
                assert.equals('bd-2', result.issues[2].id)
                assert.equals('bd-3', result.issues[3].id)
            end)

            it('should handle null values in JSON', function()
                vim.system = function(cmd, opts)
                    return {
                        wait = function()
                            return {
                                code = 0,
                                stdout = '{"result": null}',
                                stderr = ''
                            }
                        end
                    }
                end

                local result, err = core.execute_bd({ 'ready' })
                assert.is_nil(err)
                assert.is_not_nil(result)
                assert.is_table(result)
            end)
        end)
    end)
end)
