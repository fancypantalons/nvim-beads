--- Unit tests for nvim-beads.issue build_create_command function
--- Tests command generation for creating new issues

describe('nvim-beads.issue', function()
  local issue_module

  before_each(function()
    -- Clear the module cache to get fresh instance
    package.loaded['nvim-beads.issue'] = nil
    issue_module = require('nvim-beads.issue')
  end)

  describe('build_create_command', function()
    describe('validation', function()
      it('should return error when title is missing', function()
        local parsed_issue = {
          issue_type = 'task'
        }

        local command, err = issue_module.build_create_command(parsed_issue)

        assert.is_nil(command)
        assert.equals('Title is required', err)
      end)

      it('should return error when title is empty string', function()
        local parsed_issue = {
          title = '',
          issue_type = 'task'
        }

        local command, err = issue_module.build_create_command(parsed_issue)

        assert.is_nil(command)
        assert.equals('Title is required', err)
      end)

      it('should return error when issue_type is missing', function()
        local parsed_issue = {
          title = 'Test Issue'
        }

        local command, err = issue_module.build_create_command(parsed_issue)

        assert.is_nil(command)
        assert.equals('Issue type is required', err)
      end)

      it('should return error when issue_type is empty string', function()
        local parsed_issue = {
          title = 'Test Issue',
          issue_type = ''
        }

        local command, err = issue_module.build_create_command(parsed_issue)

        assert.is_nil(command)
        assert.equals('Issue type is required', err)
      end)
    end)

    describe('minimal issue (title + type only)', function()
      it('should generate correct command with just title and type', function()
        local parsed_issue = {
          title = 'Fix bug in parser',
          issue_type = 'bug'
        }

        local command, err = issue_module.build_create_command(parsed_issue)

        assert.is_nil(err)
        assert.equals("bd create 'Fix bug in parser' --type bug", command)
      end)

      it('should work with task type', function()
        local parsed_issue = {
          title = 'Update documentation',
          issue_type = 'task'
        }

        local command, err = issue_module.build_create_command(parsed_issue)

        assert.is_nil(err)
        assert.equals("bd create 'Update documentation' --type task", command)
      end)

      it('should work with feature type', function()
        local parsed_issue = {
          title = 'Add dark mode',
          issue_type = 'feature'
        }

        local command, err = issue_module.build_create_command(parsed_issue)

        assert.is_nil(err)
        assert.equals("bd create 'Add dark mode' --type feature", command)
      end)

      it('should work with epic type', function()
        local parsed_issue = {
          title = 'User authentication system',
          issue_type = 'epic'
        }

        local command, err = issue_module.build_create_command(parsed_issue)

        assert.is_nil(err)
        assert.equals("bd create 'User authentication system' --type epic", command)
      end)

      it('should work with chore type', function()
        local parsed_issue = {
          title = 'Update dependencies',
          issue_type = 'chore'
        }

        local command, err = issue_module.build_create_command(parsed_issue)

        assert.is_nil(err)
        assert.equals("bd create 'Update dependencies' --type chore", command)
      end)
    end)

    describe('optional field inclusion', function()
      it('should include priority when provided', function()
        local parsed_issue = {
          title = 'Critical bug',
          issue_type = 'bug',
          priority = 0
        }

        local command, err = issue_module.build_create_command(parsed_issue)

        assert.is_nil(err)
        assert.is_true(command:match("bd create 'Critical bug' %-%-type bug %-%-priority 0") ~= nil)
      end)

      it('should include description when provided', function()
        local parsed_issue = {
          title = 'Fix parser',
          issue_type = 'bug',
          description = 'The parser fails on edge cases'
        }

        local command, err = issue_module.build_create_command(parsed_issue)

        assert.is_nil(err)
        assert.is_true(command:match("%-%-description 'The parser fails on edge cases'") ~= nil)
      end)

      it('should include acceptance criteria when provided', function()
        local parsed_issue = {
          title = 'Add feature',
          issue_type = 'feature',
          acceptance_criteria = 'Must pass all tests'
        }

        local command, err = issue_module.build_create_command(parsed_issue)

        assert.is_nil(err)
        assert.is_true(command:match("%-%-acceptance 'Must pass all tests'") ~= nil)
      end)

      it('should include design when provided', function()
        local parsed_issue = {
          title = 'Refactor module',
          issue_type = 'task',
          design = 'Use MVC pattern'
        }

        local command, err = issue_module.build_create_command(parsed_issue)

        assert.is_nil(err)
        assert.is_true(command:match("%-%-design 'Use MVC pattern'") ~= nil)
      end)

      it('should include labels when provided', function()
        local parsed_issue = {
          title = 'Fix UI bug',
          issue_type = 'bug',
          labels = {'ui', 'frontend', 'critical'}
        }

        local command, err = issue_module.build_create_command(parsed_issue)

        assert.is_nil(err)
        assert.is_true(command:match("%-%-labels 'ui,frontend,critical'") ~= nil)
      end)

      it('should include parent when provided', function()
        local parsed_issue = {
          title = 'Subtask',
          issue_type = 'task',
          parent = 'bd-50'
        }

        local command, err = issue_module.build_create_command(parsed_issue)

        assert.is_nil(err)
        assert.is_true(command:match("%-%-parent bd%-50") ~= nil)
      end)

      it('should include dependencies when provided', function()
        local parsed_issue = {
          title = 'Task with deps',
          issue_type = 'task',
          dependencies = {'bd-10', 'bd-20'}
        }

        local command, err = issue_module.build_create_command(parsed_issue)

        assert.is_nil(err)
        assert.is_true(command:match("%-%-deps 'blocks:bd%-10,blocks:bd%-20'") ~= nil)
      end)
    end)

    describe('empty optional fields omission', function()
      it('should omit description when empty string', function()
        local parsed_issue = {
          title = 'Task',
          issue_type = 'task',
          description = ''
        }

        local command, err = issue_module.build_create_command(parsed_issue)

        assert.is_nil(err)
        assert.is_false(command:match("%-%-description") ~= nil)
      end)

      it('should omit acceptance criteria when empty string', function()
        local parsed_issue = {
          title = 'Task',
          issue_type = 'task',
          acceptance_criteria = ''
        }

        local command, err = issue_module.build_create_command(parsed_issue)

        assert.is_nil(err)
        assert.is_false(command:match("%-%-acceptance") ~= nil)
      end)

      it('should omit design when empty string', function()
        local parsed_issue = {
          title = 'Task',
          issue_type = 'task',
          design = ''
        }

        local command, err = issue_module.build_create_command(parsed_issue)

        assert.is_nil(err)
        assert.is_false(command:match("%-%-design") ~= nil)
      end)

      it('should omit labels when empty array', function()
        local parsed_issue = {
          title = 'Task',
          issue_type = 'task',
          labels = {}
        }

        local command, err = issue_module.build_create_command(parsed_issue)

        assert.is_nil(err)
        assert.is_false(command:match("%-%-labels") ~= nil)
      end)

      it('should omit parent when empty string', function()
        local parsed_issue = {
          title = 'Task',
          issue_type = 'task',
          parent = ''
        }

        local command, err = issue_module.build_create_command(parsed_issue)

        assert.is_nil(err)
        assert.is_false(command:match("%-%-parent") ~= nil)
      end)

      it('should omit dependencies when empty array', function()
        local parsed_issue = {
          title = 'Task',
          issue_type = 'task',
          dependencies = {}
        }

        local command, err = issue_module.build_create_command(parsed_issue)

        assert.is_nil(err)
        assert.is_false(command:match("%-%-deps") ~= nil)
      end)
    end)

    describe('special character escaping', function()
      it('should escape single quotes in title', function()
        local parsed_issue = {
          title = "Fix user's authentication",
          issue_type = 'bug'
        }

        local command, err = issue_module.build_create_command(parsed_issue)

        assert.is_nil(err)
        assert.equals("bd create 'Fix user'\\''s authentication' --type bug", command)
      end)

      it('should handle double quotes in title', function()
        local parsed_issue = {
          title = 'Add "advanced" search',
          issue_type = 'feature'
        }

        local command, err = issue_module.build_create_command(parsed_issue)

        assert.is_nil(err)
        assert.equals("bd create 'Add \"advanced\" search' --type feature", command)
      end)

      it('should escape single quotes in description', function()
        local parsed_issue = {
          title = 'Fix bug',
          issue_type = 'bug',
          description = "The user's session wasn't saved"
        }

        local command, err = issue_module.build_create_command(parsed_issue)

        assert.is_nil(err)
        assert.is_true(command:match("%-%-description 'The user'\\''s session wasn'\\''t saved'") ~= nil)
      end)

      it('should handle newlines in description', function()
        local parsed_issue = {
          title = 'Multi-line bug',
          issue_type = 'bug',
          description = 'Line 1\nLine 2\nLine 3'
        }

        local command, err = issue_module.build_create_command(parsed_issue)

        assert.is_nil(err)
        assert.is_true(command:match("%-%-description 'Line 1\nLine 2\nLine 3'") ~= nil)
      end)

      it('should handle special shell characters', function()
        local parsed_issue = {
          title = 'Fix: $var & pipe | redirect >',
          issue_type = 'bug'
        }

        local command, err = issue_module.build_create_command(parsed_issue)

        assert.is_nil(err)
        assert.is_true(command:match("'Fix: %$var & pipe | redirect >'") ~= nil)
      end)

      it('should escape single quotes in acceptance criteria', function()
        local parsed_issue = {
          title = 'Task',
          issue_type = 'task',
          acceptance_criteria = "User's can login successfully"
        }

        local command, err = issue_module.build_create_command(parsed_issue)

        assert.is_nil(err)
        assert.is_true(command:match("%-%-acceptance 'User'\\''s can login successfully'") ~= nil)
      end)

      it('should escape single quotes in design', function()
        local parsed_issue = {
          title = 'Task',
          issue_type = 'task',
          design = "Use the system's default config"
        }

        local command, err = issue_module.build_create_command(parsed_issue)

        assert.is_nil(err)
        assert.is_true(command:match("%-%-design 'Use the system'\\''s default config'") ~= nil)
      end)

      it('should escape single quotes in labels', function()
        local parsed_issue = {
          title = 'Task',
          issue_type = 'task',
          labels = {"user's-bug", 'frontend'}
        }

        local command, err = issue_module.build_create_command(parsed_issue)

        assert.is_nil(err)
        assert.is_true(command:match("%-%-labels 'user'\\''s%-bug,frontend'") ~= nil)
      end)
    end)

    describe('issue with all fields populated', function()
      it('should generate command with all fields when provided', function()
        local parsed_issue = {
          title = 'Comprehensive issue',
          issue_type = 'feature',
          priority = 1,
          description = 'This is a detailed description',
          acceptance_criteria = 'Must meet all criteria',
          design = 'Follow MVC pattern',
          labels = {'backend', 'api', 'critical'},
          parent = 'bd-100',
          dependencies = {'bd-50', 'bd-60'}
        }

        local command, err = issue_module.build_create_command(parsed_issue)

        assert.is_nil(err)
        assert.is_not_nil(command)

        -- Verify all components are present
        assert.is_true(command:match("bd create 'Comprehensive issue'") ~= nil)
        assert.is_true(command:match("%-%-type feature") ~= nil)
        assert.is_true(command:match("%-%-priority 1") ~= nil)
        assert.is_true(command:match("%-%-description 'This is a detailed description'") ~= nil)
        assert.is_true(command:match("%-%-acceptance 'Must meet all criteria'") ~= nil)
        assert.is_true(command:match("%-%-design 'Follow MVC pattern'") ~= nil)
        assert.is_true(command:match("%-%-labels 'backend,api,critical'") ~= nil)
        assert.is_true(command:match("%-%-parent bd%-100") ~= nil)
        assert.is_true(command:match("%-%-deps 'blocks:bd%-50,blocks:bd%-60'") ~= nil)
      end)
    end)

    describe('different priority values', function()
      it('should handle priority 0 (critical)', function()
        local parsed_issue = {
          title = 'Critical issue',
          issue_type = 'bug',
          priority = 0
        }

        local command, err = issue_module.build_create_command(parsed_issue)

        assert.is_nil(err)
        assert.is_true(command:match("%-%-priority 0") ~= nil)
      end)

      it('should handle priority 1 (high)', function()
        local parsed_issue = {
          title = 'High priority',
          issue_type = 'bug',
          priority = 1
        }

        local command, err = issue_module.build_create_command(parsed_issue)

        assert.is_nil(err)
        assert.is_true(command:match("%-%-priority 1") ~= nil)
      end)

      it('should handle priority 2 (medium/default)', function()
        local parsed_issue = {
          title = 'Medium priority',
          issue_type = 'task',
          priority = 2
        }

        local command, err = issue_module.build_create_command(parsed_issue)

        assert.is_nil(err)
        assert.is_true(command:match("%-%-priority 2") ~= nil)
      end)

      it('should handle priority 3 (low)', function()
        local parsed_issue = {
          title = 'Low priority',
          issue_type = 'task',
          priority = 3
        }

        local command, err = issue_module.build_create_command(parsed_issue)

        assert.is_nil(err)
        assert.is_true(command:match("%-%-priority 3") ~= nil)
      end)

      it('should handle priority 4 (backlog)', function()
        local parsed_issue = {
          title = 'Backlog item',
          issue_type = 'task',
          priority = 4
        }

        local command, err = issue_module.build_create_command(parsed_issue)

        assert.is_nil(err)
        assert.is_true(command:match("%-%-priority 4") ~= nil)
      end)
    end)
  end)
end)
