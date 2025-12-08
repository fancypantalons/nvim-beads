--- Tests for search, list, and ready command filter extraction

local env = require("test_utilities.env")
local assertions = require("test_utilities.assertions")

describe("command filter extraction", function()
    local commands
    local mock_beads
    local mock_constants

    before_each(function()
        env.setup_mock_env()

        -- Mock constants
        mock_constants = {
            STATUSES = {
                open = true,
                closed = true,
                in_progress = true,
                blocked = true,
            },
            ISSUE_TYPES = {
                bug = true,
                feature = true,
                task = true,
                epic = true,
                chore = true,
            },
            PLURAL_MAP = {
                bugs = "bug",
                features = "feature",
                tasks = "task",
                epics = "epic",
                chores = "chore",
            },
        }

        -- Mock beads module
        mock_beads = {
            execute_with_ui = function() end,
        }

        package.loaded["nvim-beads.constants"] = mock_constants
        package.loaded["nvim-beads"] = mock_beads

        -- Load commands module
        package.loaded["nvim-beads.commands"] = nil
        commands = require("nvim-beads.commands")
    end)

    after_each(function()
        env.teardown_mock_env()
    end)

    -- Shared helper function for filter extraction testing
    local function assert_filter_extraction(input_args, expected_bd_args, expected_filter)
        local called_with_bd_args
        local called_with_filter
        mock_beads.execute_with_ui = function(bd_args, filter)
            called_with_bd_args = bd_args
            called_with_filter = filter
        end

        commands.execute({ fargs = input_args })

        assert.same(expected_bd_args, called_with_bd_args)
        assert.same(expected_filter, called_with_filter)
    end

    describe("filter extraction patterns", function()
        local filter_test_cases = {
            -- Search command cases
            {
                name = "search: query without filters",
                input = { "search", "foo", "bar" },
                expected_bd_args = { "search", "foo", "bar" },
                expected_filter = {},
            },
            {
                name = "search: status filter extraction",
                input = { "search", "open", "foo" },
                expected_bd_args = { "search", "foo" },
                expected_filter = { status = "open" },
            },
            {
                name = "search: type filter extraction",
                input = { "search", "bugs", "foo" },
                expected_bd_args = { "search", "foo" },
                expected_filter = { type = "bug" },
            },
            {
                name = "search: plural forms via PLURAL_MAP",
                input = { "search", "features", "authentication" },
                expected_bd_args = { "search", "authentication" },
                expected_filter = { type = "feature" },
            },
            {
                name = "search: combined filters",
                input = { "search", "open", "bugs", "foo" },
                expected_bd_args = { "search", "foo" },
                expected_filter = { status = "open", type = "bug" },
            },
            {
                name = "search: filters in any order",
                input = { "search", "bugs", "open", "foo" },
                expected_bd_args = { "search", "foo" },
                expected_filter = { status = "open", type = "bug" },
            },
            {
                name = "search: invalid filter treated as query term",
                input = { "search", "invalid", "foo" },
                expected_bd_args = { "search", "invalid", "foo" },
                expected_filter = {},
            },
            -- List command cases
            {
                name = "list: no filters",
                input = { "list" },
                expected_bd_args = { "list" },
                expected_filter = {},
            },
            {
                name = "list: status filter",
                input = { "list", "open" },
                expected_bd_args = { "list" },
                expected_filter = { status = "open" },
            },
            {
                name = "list: type filter",
                input = { "list", "bugs" },
                expected_bd_args = { "list" },
                expected_filter = { type = "bug" },
            },
            {
                name = "list: status and type filters",
                input = { "list", "open", "bugs" },
                expected_bd_args = { "list" },
                expected_filter = { status = "open", type = "bug" },
            },
            -- Ready command cases
            {
                name = "ready: no filters",
                input = { "ready" },
                expected_bd_args = { "ready" },
                expected_filter = {},
            },
            {
                name = "ready: type filter",
                input = { "ready", "features" },
                expected_bd_args = { "ready" },
                expected_filter = { type = "feature" },
            },
        }

        for _, test_case in ipairs(filter_test_cases) do
            it(test_case.name, function()
                assert_filter_extraction(test_case.input, test_case.expected_bd_args, test_case.expected_filter)
            end)
        end
    end)

    describe("search command error handling", function()
        it("errors when no query provided", function()
            assertions.assert_error_notification(function()
                commands.execute({ fargs = { "search" } })
            end, "query required")
        end)

        it("errors when only status filter provided", function()
            assertions.assert_error_notification(function()
                commands.execute({ fargs = { "search", "open" } })
            end, "query required")
        end)

        it("errors when only type filter provided", function()
            assertions.assert_error_notification(function()
                commands.execute({ fargs = { "search", "bugs" } })
            end, "query required")
        end)
    end)
end)
