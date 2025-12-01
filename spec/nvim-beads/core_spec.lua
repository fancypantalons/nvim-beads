--- Tests for nvim-beads core module

local core = require('nvim-beads.core')

describe('execute_bd', function()
    it('should execute bd ready command successfully', function()
        local result, err = core.execute_bd({ 'ready' })
        assert.is_nil(err)
        assert.is_not_nil(result)
        assert.is_table(result)
    end)

    it('should execute bd stats command successfully', function()
        local result, err = core.execute_bd({ 'stats' })
        assert.is_nil(err)
        assert.is_not_nil(result)
        assert.is_table(result)
    end)

    it('should return error for invalid command', function()
        local result, err = core.execute_bd({ 'invalid_command_xyz' })
        assert.is_nil(result)
        assert.is_not_nil(err)
        assert.is_string(err)
    end)

    it('should automatically add --json flag if not present', function()
        local result, err = core.execute_bd({ 'ready' })
        assert.is_nil(err)
        assert.is_not_nil(result)
        -- If JSON parsing succeeded, --json was properly added
        assert.is_table(result)
    end)

    it('should not duplicate --json flag if already present', function()
        local result, err = core.execute_bd({ 'ready', '--json' })
        assert.is_nil(err)
        assert.is_not_nil(result)
        assert.is_table(result)
    end)

    it('should return error for invalid arguments type', function()
        local result, err = core.execute_bd('not a table')
        assert.is_nil(result)
        assert.is_not_nil(err)
        assert.matches('args must be a table', err)
    end)
end)
