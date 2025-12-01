--- Integration tests for autocmd save workflow
--- Tests the full new issue creation and existing issue update workflows

describe('autocmd save workflow', function()
  local autocmds
  local issue_module
  local core_module
  local original_vim_system
  local original_notify
  local original_vim_fn_system
  local original_vim_v
  local notifications
  local test_bufnr
  local mock_shell_error

  before_each(function()
    -- Clear module cache
    package.loaded['nvim-beads.autocmds'] = nil
    package.loaded['nvim-beads.issue'] = nil
    package.loaded['nvim-beads.core'] = nil

    autocmds = require('nvim-beads.autocmds')
    issue_module = require('nvim-beads.issue')
    core_module = require('nvim-beads.core')

    -- Save original functions
    original_vim_system = vim.system
    original_notify = vim.notify
    original_vim_fn_system = vim.fn.system
    original_vim_v = vim.v

    -- Mock vim.notify to capture notifications
    notifications = {}
    vim.notify = function(msg, level)
      table.insert(notifications, { msg = msg, level = level })
    end

    -- Mock vim.v with writable shell_error
    mock_shell_error = 0
    vim.v = setmetatable({}, {
      __index = function(t, k)
        if k == 'shell_error' then
          return mock_shell_error
        end
        return original_vim_v[k]
      end,
      __newindex = function(t, k, v)
        if k == 'shell_error' then
          mock_shell_error = v
        else
          rawset(t, k, v)
        end
      end
    })

    -- Create a test buffer
    test_bufnr = vim.api.nvim_create_buf(false, false)
  end)

  after_each(function()
    -- Restore original functions
    vim.system = original_vim_system
    vim.notify = original_notify
    vim.fn.system = original_vim_fn_system
    vim.v = original_vim_v

    -- Delete test buffer if it exists
    if vim.api.nvim_buf_is_valid(test_bufnr) then
      vim.api.nvim_buf_delete(test_bufnr, { force = true })
    end
  end)

  describe('new issue creation workflow', function()
    it('should create minimal issue with title only', function()
      -- Set up buffer content (minimal new issue)
      local buffer_content = {
        '---',
        'id: (new)',
        'title: Fix parsing bug',
        'type: bug',
        'status: open',
        'priority: 2',
        'created_at: null',
        'updated_at: null',
        'closed_at: null',
        '---',
        '',
        '# Description',
        '',
        'Parser fails on edge cases',
        ''
      }

      vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, buffer_content)
      vim.api.nvim_buf_set_name(test_bufnr, 'beads://issue/new?type=bug')

      -- Mock vim.fn.system for create command
      local create_output = '{"id":"bd-42","title":"Fix parsing bug","issue_type":"bug"}'
      local system_calls = {}

      vim.fn.system = function(cmd)
        table.insert(system_calls, cmd)
        if cmd:match('bd create') then
          mock_shell_error = 0
          return create_output
        end
        return ''
      end

      -- Mock core.execute_bd for show command
      core_module.execute_bd = function(args)
        if args[1] == 'show' and args[2] == 'bd-42' then
          return {
            {
              id = 'bd-42',
              title = 'Fix parsing bug',
              issue_type = 'bug',
              status = 'open',
              priority = 2,
              created_at = '2025-11-30T12:00:00Z',
              updated_at = '2025-11-30T12:00:00Z',
              closed_at = nil,
              description = 'Parser fails on edge cases',
              labels = {},
              dependencies = {}
            }
          }, nil
        end
        return nil, 'Issue not found'
      end

      -- Call the handler
      autocmds.handle_new_issue_save(test_bufnr, 'beads://issue/new?type=bug')

      -- Verify create command was called
      assert.equals(1, #system_calls)
      assert.is_true(system_calls[1]:match('bd create') ~= nil)
      assert.is_true(system_calls[1]:match('--json') ~= nil)

      -- Verify buffer was renamed
      local new_name = vim.api.nvim_buf_get_name(test_bufnr)
      assert.equals('beads://issue/bd-42', new_name)

      -- Verify success notification
      local found_success = false
      for _, notif in ipairs(notifications) do
        if notif.msg:match('bd%-42 created successfully') then
          found_success = true
          break
        end
      end
      assert.is_true(found_success)
    end)

    it('should create issue with all fields populated', function()
      local buffer_content = {
        '---',
        'id: (new)',
        'title: Add dark mode',
        'type: feature',
        'status: open',
        'priority: 1',
        'parent: bd-100',
        'dependencies:',
        '  - bd-50',
        '  - bd-60',
        'labels:',
        '  - ui',
        '  - frontend',
        'created_at: null',
        'updated_at: null',
        'closed_at: null',
        '---',
        '',
        '# Description',
        '',
        'Add dark mode toggle to settings',
        '',
        '# Acceptance Criteria',
        '',
        '- [ ] Dark mode toggle works',
        '- [ ] Colors are properly themed',
        '',
        '# Design',
        '',
        'Use CSS variables for theming',
        ''
      }

      vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, buffer_content)
      vim.api.nvim_buf_set_name(test_bufnr, 'beads://issue/new?type=feature')

      local create_output = '{"id":"bd-200","title":"Add dark mode","issue_type":"feature"}'
      local system_calls = {}

      vim.fn.system = function(cmd)
        table.insert(system_calls, cmd)
        if cmd:match('bd create') then
          mock_shell_error = 0
          return create_output
        end
        return ''
      end

      core_module.execute_bd = function(args)
        if args[1] == 'show' and args[2] == 'bd-200' then
          return {
            {
              id = 'bd-200',
              title = 'Add dark mode',
              issue_type = 'feature',
              status = 'open',
              priority = 1,
              created_at = '2025-11-30T12:00:00Z',
              updated_at = '2025-11-30T12:00:00Z',
              closed_at = nil,
              description = 'Add dark mode toggle to settings',
              acceptance_criteria = '- [ ] Dark mode toggle works\n- [ ] Colors are properly themed',
              design = 'Use CSS variables for theming',
              labels = {'ui', 'frontend'},
              dependencies = {
                { id = 'bd-50', dependency_type = 'blocks' },
                { id = 'bd-60', dependency_type = 'blocks' },
                { id = 'bd-100', dependency_type = 'parent-child' }
              }
            }
          }, nil
        end
        return nil, 'Issue not found'
      end

      -- Call the handler
      autocmds.handle_new_issue_save(test_bufnr, 'beads://issue/new?type=feature')

      -- Verify create command was called with all fields
      assert.equals(1, #system_calls)
      local cmd = system_calls[1]
      assert.is_true(cmd:match('bd create') ~= nil)
      assert.is_true(cmd:match('Add dark mode') ~= nil)
      assert.is_true(cmd:match('--type feature') ~= nil)
      assert.is_true(cmd:match('--priority 1') ~= nil)
      assert.is_true(cmd:match('--parent bd%-100') ~= nil)
      assert.is_true(cmd:match('--deps') ~= nil)
      assert.is_true(cmd:match('--labels') ~= nil)

      -- Verify buffer was renamed
      local new_name = vim.api.nvim_buf_get_name(test_bufnr)
      assert.equals('beads://issue/bd-200', new_name)
    end)

    it('should show error when title is missing', function()
      local buffer_content = {
        '---',
        'id: (new)',
        'title: ',
        'type: task',
        'status: open',
        'priority: 2',
        'created_at: null',
        'updated_at: null',
        'closed_at: null',
        '---',
      }

      vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, buffer_content)
      vim.api.nvim_buf_set_name(test_bufnr, 'beads://issue/new?type=task')

      -- Call the handler
      autocmds.handle_new_issue_save(test_bufnr, 'beads://issue/new?type=task')

      -- Verify error notification
      local found_error = false
      for _, notif in ipairs(notifications) do
        if notif.msg:match('Title is required') and notif.level == vim.log.levels.ERROR then
          found_error = true
          break
        end
      end
      assert.is_true(found_error)

      -- Verify buffer name was not changed
      local name = vim.api.nvim_buf_get_name(test_bufnr)
      assert.is_true(name:match('beads://issue/new') ~= nil)
    end)

    it('should show error when title is still (new)', function()
      local buffer_content = {
        '---',
        'id: (new)',
        'title: (new)',
        'type: task',
        'status: open',
        'priority: 2',
        'created_at: null',
        'updated_at: null',
        'closed_at: null',
        '---',
      }

      vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, buffer_content)
      vim.api.nvim_buf_set_name(test_bufnr, 'beads://issue/new?type=task')

      -- Call the handler
      autocmds.handle_new_issue_save(test_bufnr, 'beads://issue/new?type=task')

      -- Verify error notification
      local found_error = false
      for _, notif in ipairs(notifications) do
        if notif.msg:match('Title is required') and notif.level == vim.log.levels.ERROR then
          found_error = true
          break
        end
      end
      assert.is_true(found_error)
    end)

    it('should show error when bd create command fails', function()
      local buffer_content = {
        '---',
        'id: (new)',
        'title: Test issue',
        'type: bug',
        'status: open',
        'priority: 2',
        'created_at: null',
        'updated_at: null',
        'closed_at: null',
        '---',
      }

      vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, buffer_content)
      vim.api.nvim_buf_set_name(test_bufnr, 'beads://issue/new?type=bug')

      -- Mock failing system call
      vim.fn.system = function(cmd)
        if cmd:match('bd create') then
          mock_shell_error = 1
          return 'Error: Database connection failed'
        end
        return ''
      end

      -- Call the handler
      autocmds.handle_new_issue_save(test_bufnr, 'beads://issue/new?type=bug')

      -- Verify error notification
      local found_error = false
      for _, notif in ipairs(notifications) do
        if notif.msg:match('Failed to create issue') and notif.level == vim.log.levels.ERROR then
          found_error = true
          break
        end
      end
      assert.is_true(found_error)

      -- Verify buffer name was not changed
      local name = vim.api.nvim_buf_get_name(test_bufnr)
      assert.is_true(name:match('beads://issue/new') ~= nil)
    end)

    it('should reload buffer with authoritative data after creation', function()
      local buffer_content = {
        '---',
        'id: (new)',
        'title: New feature',
        'type: feature',
        'status: open',
        'priority: 2',
        'created_at: null',
        'updated_at: null',
        'closed_at: null',
        '---',
      }

      vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, buffer_content)
      vim.api.nvim_buf_set_name(test_bufnr, 'beads://issue/new?type=feature')

      local create_output = '{"id":"bd-999","title":"New feature","issue_type":"feature"}'

      vim.fn.system = function(cmd)
        if cmd:match('bd create') then
          mock_shell_error = 0
          return create_output
        end
        return ''
      end

      core_module.execute_bd = function(args)
        if args[1] == 'show' and args[2] == 'bd-999' then
          return {
            {
              id = 'bd-999',
              title = 'New feature',
              issue_type = 'feature',
              status = 'open',
              priority = 2,
              created_at = '2025-11-30T15:30:00Z',
              updated_at = '2025-11-30T15:30:00Z',
              closed_at = nil,
              labels = {},
              dependencies = {}
            }
          }, nil
        end
        return nil, 'Issue not found'
      end

      -- Call the handler
      autocmds.handle_new_issue_save(test_bufnr, 'beads://issue/new?type=feature')

      -- Verify buffer content was reloaded
      local lines = vim.api.nvim_buf_get_lines(test_bufnr, 0, -1, false)

      -- Check that timestamps are now present (not null)
      local found_timestamp = false
      for _, line in ipairs(lines) do
        if line:match('created_at: 2025') then
          found_timestamp = true
          break
        end
      end
      assert.is_true(found_timestamp)

      -- Verify modified flag was cleared
      local modified = vim.api.nvim_get_option_value('modified', { buf = test_bufnr })
      assert.is_false(modified)
    end)
  end)
end)
