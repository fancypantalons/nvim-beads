--- Unit tests for nvim-beads.issue extract_id_from_create_output function
--- Tests ID extraction from bd create --json command output

describe('nvim-beads.issue', function()
  local issue_module

  before_each(function()
    -- Clear the module cache to get fresh instance
    package.loaded['nvim-beads.issue'] = nil
    issue_module = require('nvim-beads.issue')
  end)

  describe('extract_id_from_create_output', function()
    describe('successful extraction', function()
      it('should extract ID from valid JSON output', function()
        local output = '{"id":"nvim-beads-123","title":"Test Issue","status":"open"}'

        local id, err = issue_module.extract_id_from_create_output(output)

        assert.is_nil(err)
        assert.equals('nvim-beads-123', id)
      end)

      it('should extract ID from JSON with many fields', function()
        local output = [[{
  "id": "bd-42",
  "title": "Fix parser bug",
  "issue_type": "bug",
  "status": "open",
  "priority": 1,
  "created_at": "2025-11-30T12:00:00Z",
  "updated_at": "2025-11-30T12:00:00Z"
}]]

        local id, err = issue_module.extract_id_from_create_output(output)

        assert.is_nil(err)
        assert.equals('bd-42', id)
      end)

      it('should handle different ID formats', function()
        local test_cases = {
          'bd-1',
          'nvim-beads-abc',
          'test-123-xyz',
          'proj-456'
        }

        for _, test_id in ipairs(test_cases) do
          local output = string.format('{"id":"%s","title":"Test"}', test_id)
          local id, err = issue_module.extract_id_from_create_output(output)

          assert.is_nil(err)
          assert.equals(test_id, id)
        end
      end)

      it('should handle IDs matching the schema pattern', function()
        -- Schema pattern: ^[a-z0-9]+-[a-f0-9]+(\.[0-9]+)*$
        local test_cases = {
          'bd-a1b2c3d',           -- Basic format
          'nvim-beads-1a2b3c',    -- With project prefix
          'test-abc123',          -- Alphanumeric hex
          'proj-f00d.1',          -- With version suffix
          'issue-deadbeef.1.2.3'  -- Multiple version parts
        }

        for _, test_id in ipairs(test_cases) do
          local output = string.format('{"id":"%s","title":"Test"}', test_id)
          local id, err = issue_module.extract_id_from_create_output(output)

          assert.is_nil(err)
          assert.equals(test_id, id)
        end
      end)

      it('should handle minified JSON', function()
        local output = '{"id":"test-99","title":"T","status":"open","priority":2}'

        local id, err = issue_module.extract_id_from_create_output(output)

        assert.is_nil(err)
        assert.equals('test-99', id)
      end)

      it('should handle pretty-printed JSON with whitespace', function()
        local output = [[
{
  "id"  :  "bd-999"  ,
  "title"  :  "Test"
}
]]

        local id, err = issue_module.extract_id_from_create_output(output)

        assert.is_nil(err)
        assert.equals('bd-999', id)
      end)
    end)

    describe('error handling', function()
      it('should return error when output is nil', function()
        local id, err = issue_module.extract_id_from_create_output(nil)

        assert.is_nil(id)
        assert.equals('Empty output', err)
      end)

      it('should return error when output is empty string', function()
        local id, err = issue_module.extract_id_from_create_output('')

        assert.is_nil(id)
        assert.equals('Empty output', err)
      end)

      it('should return error when output is not valid JSON', function()
        local id, err = issue_module.extract_id_from_create_output('not json at all')

        assert.is_nil(id)
        assert.is_not_nil(err)
        assert.is_true(err:match('Failed to parse JSON') ~= nil)
      end)

      it('should return error when output is incomplete JSON', function()
        local id, err = issue_module.extract_id_from_create_output('{"id":"test-1"')

        assert.is_nil(id)
        assert.is_not_nil(err)
        assert.is_true(err:match('Failed to parse JSON') ~= nil)
      end)

      it('should return error when JSON is an array', function()
        local output = '[{"id":"test-1"}]'

        local id, err = issue_module.extract_id_from_create_output(output)

        assert.is_nil(id)
        assert.is_not_nil(err)
        -- Arrays are tables in Lua, but we expect the id field directly
        assert.is_true(err:match('No id field') ~= nil)
      end)

      it('should return error when JSON is a string', function()
        local output = '"just a string"'

        local id, err = issue_module.extract_id_from_create_output(output)

        assert.is_nil(id)
        assert.equals('JSON output is not a table', err)
      end)

      it('should return error when JSON is a number', function()
        local output = '42'

        local id, err = issue_module.extract_id_from_create_output(output)

        assert.is_nil(id)
        assert.equals('JSON output is not a table', err)
      end)

      it('should return error when id field is missing', function()
        local output = '{"title":"Test Issue","status":"open"}'

        local id, err = issue_module.extract_id_from_create_output(output)

        assert.is_nil(id)
        assert.equals('No id field in JSON output', err)
      end)

      it('should return error when id field is empty string', function()
        local output = '{"id":"","title":"Test"}'

        local id, err = issue_module.extract_id_from_create_output(output)

        assert.is_nil(id)
        assert.equals('No id field in JSON output', err)
      end)

      it('should return error when id field is null', function()
        local output = '{"id":null,"title":"Test"}'

        local id, err = issue_module.extract_id_from_create_output(output)

        assert.is_nil(id)
        assert.equals('No id field in JSON output', err)
      end)
    end)

    describe('edge cases', function()
      it('should handle JSON with escape sequences in other fields', function()
        local output = '{"id":"test-1","title":"Test\\nwith\\nnewlines"}'

        local id, err = issue_module.extract_id_from_create_output(output)

        assert.is_nil(err)
        assert.equals('test-1', id)
      end)

      it('should handle JSON with special characters in other fields', function()
        local output = '{"id":"bd-100","title":"Test \\"quotes\\" & symbols"}'

        local id, err = issue_module.extract_id_from_create_output(output)

        assert.is_nil(err)
        assert.equals('bd-100', id)
      end)

      it('should handle JSON with nested objects', function()
        local output = [[{
  "id": "bd-200",
  "metadata": {
    "author": "test",
    "tags": ["tag1", "tag2"]
  }
}]]

        local id, err = issue_module.extract_id_from_create_output(output)

        assert.is_nil(err)
        assert.equals('bd-200', id)
      end)

      it('should ignore extra whitespace around output', function()
        local output = '\n\n  {"id":"test-1","title":"Test"}  \n\n'

        local id, err = issue_module.extract_id_from_create_output(output)

        assert.is_nil(err)
        assert.equals('test-1', id)
      end)
    end)
  end)
end)
