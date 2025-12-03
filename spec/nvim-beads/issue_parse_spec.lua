--- Unit tests for nvim-beads.issue.parser parse_markdown_to_issue function
--- Tests the reverse operation of format_issue_to_markdown

describe("nvim-beads.issue.parser", function()
    local parser

    before_each(function()
        -- Clear the module cache to get fresh instance
        package.loaded["nvim-beads.issue.parser"] = nil
        parser = require("nvim-beads.issue.parser")
    end)

    describe("parse_markdown_to_issue", function()
        it("should parse minimal issue with only required fields", function()
            local buffer_lines = {
                "---",
                "id: bd-1",
                "title: Test Issue",
                "type: task",
                "status: open",
                "priority: 2",
                "created_at: 2023-10-27T10:00:00Z",
                "updated_at: 2023-10-27T12:00:00Z",
                "closed_at: null",
                "---",
                "",
            }

            local issue = parser.parse_markdown_to_issue(buffer_lines)

            assert.is_table(issue)
            assert.equals("bd-1", issue.id)
            assert.equals("Test Issue", issue.title)
            assert.equals("task", issue.issue_type)
            assert.equals("open", issue.status)
            assert.equals(2, issue.priority)
            assert.equals("2023-10-27T10:00:00Z", issue.created_at)
            assert.equals("2023-10-27T12:00:00Z", issue.updated_at)
            assert.is_nil(issue.closed_at)
        end)

        it("should map type to issue_type when parsing", function()
            local buffer_lines = {
                "---",
                "id: bd-2",
                "title: Bug Fix",
                "type: bug",
                "status: open",
                "priority: 1",
                "created_at: 2023-10-27T10:00:00Z",
                "updated_at: 2023-10-27T12:00:00Z",
                "closed_at: null",
                "---",
                "",
            }

            local issue = parser.parse_markdown_to_issue(buffer_lines)

            assert.equals("bug", issue.issue_type)
        end)

        it("should parse parent field when present", function()
            local buffer_lines = {
                "---",
                "id: bd-5",
                "title: Child Issue",
                "type: task",
                "status: open",
                "priority: 2",
                "parent: bd-100",
                "created_at: 2023-10-27T10:00:00Z",
                "updated_at: 2023-10-27T12:00:00Z",
                "closed_at: null",
                "---",
                "",
            }

            local issue = parser.parse_markdown_to_issue(buffer_lines)

            assert.equals("bd-100", issue.parent)
        end)

        it("should parse dependencies array", function()
            local buffer_lines = {
                "---",
                "id: bd-7",
                "title: Issue with dependencies",
                "type: feature",
                "status: blocked",
                "priority: 1",
                "dependencies:",
                "  - bd-120",
                "  - bd-121",
                "created_at: 2023-10-27T10:00:00Z",
                "updated_at: 2023-10-27T12:00:00Z",
                "closed_at: null",
                "---",
                "",
            }

            local issue = parser.parse_markdown_to_issue(buffer_lines)

            assert.is_table(issue.dependencies)
            assert.equals(2, #issue.dependencies)
            assert.equals("bd-120", issue.dependencies[1])
            assert.equals("bd-121", issue.dependencies[2])
        end)

        it("should parse labels array when present", function()
            local buffer_lines = {
                "---",
                "id: bd-9",
                "title: Labeled Issue",
                "type: feature",
                "status: open",
                "priority: 2",
                "labels:",
                "  - ui",
                "  - backend",
                "  - urgent",
                "created_at: 2023-10-27T10:00:00Z",
                "updated_at: 2023-10-27T12:00:00Z",
                "closed_at: null",
                "---",
                "",
            }

            local issue = parser.parse_markdown_to_issue(buffer_lines)

            assert.is_table(issue.labels)
            assert.equals(3, #issue.labels)
            assert.equals("ui", issue.labels[1])
            assert.equals("backend", issue.labels[2])
            assert.equals("urgent", issue.labels[3])
        end)

        it("should handle empty labels array", function()
            local buffer_lines = {
                "---",
                "id: bd-10",
                "title: No Labels",
                "type: task",
                "status: open",
                "priority: 2",
                "created_at: 2023-10-27T10:00:00Z",
                "updated_at: 2023-10-27T12:00:00Z",
                "closed_at: null",
                "---",
                "",
            }

            local issue = parser.parse_markdown_to_issue(buffer_lines)

            assert.is_table(issue.labels)
            assert.equals(0, #issue.labels)
        end)

        it("should parse assignee when present", function()
            local buffer_lines = {
                "---",
                "id: bd-11",
                "title: Assigned Issue",
                "type: bug",
                "status: in_progress",
                "priority: 1",
                "assignee: john.doe",
                "created_at: 2023-10-27T10:00:00Z",
                "updated_at: 2023-10-27T12:00:00Z",
                "closed_at: null",
                "---",
                "",
            }

            local issue = parser.parse_markdown_to_issue(buffer_lines)

            assert.equals("john.doe", issue.assignee)
        end)

        it("should parse single-line description section", function()
            local buffer_lines = {
                "---",
                "id: bd-12",
                "title: Issue with Description",
                "type: feature",
                "status: open",
                "priority: 2",
                "created_at: 2023-10-27T10:00:00Z",
                "updated_at: 2023-10-27T12:00:00Z",
                "closed_at: null",
                "---",
                "",
                "# Description",
                "",
                "This is a detailed description of the issue.",
                "",
            }

            local issue = parser.parse_markdown_to_issue(buffer_lines)

            assert.equals("This is a detailed description of the issue.", issue.description)
        end)

        it("should parse multi-line description section", function()
            local buffer_lines = {
                "---",
                "id: bd-13",
                "title: Multi-line Description",
                "type: feature",
                "status: open",
                "priority: 2",
                "created_at: 2023-10-27T10:00:00Z",
                "updated_at: 2023-10-27T12:00:00Z",
                "closed_at: null",
                "---",
                "",
                "# Description",
                "",
                "Line 1 of description",
                "Line 2 of description",
                "Line 3 of description",
                "",
            }

            local issue = parser.parse_markdown_to_issue(buffer_lines)

            assert.equals("Line 1 of description\nLine 2 of description\nLine 3 of description", issue.description)
        end)

        it("should parse acceptance_criteria section", function()
            local buffer_lines = {
                "---",
                "id: bd-14",
                "title: Issue with Acceptance Criteria",
                "type: feature",
                "status: open",
                "priority: 2",
                "created_at: 2023-10-27T10:00:00Z",
                "updated_at: 2023-10-27T12:00:00Z",
                "closed_at: null",
                "---",
                "",
                "# Acceptance Criteria",
                "",
                "Must pass all tests",
                "Must work on all browsers",
                "",
            }

            local issue = parser.parse_markdown_to_issue(buffer_lines)

            assert.equals("Must pass all tests\nMust work on all browsers", issue.acceptance_criteria)
        end)

        it("should parse design section", function()
            local buffer_lines = {
                "---",
                "id: bd-15",
                "title: Issue with Design",
                "type: feature",
                "status: open",
                "priority: 2",
                "created_at: 2023-10-27T10:00:00Z",
                "updated_at: 2023-10-27T12:00:00Z",
                "closed_at: null",
                "---",
                "",
                "# Design",
                "",
                "Use MVC pattern",
                "Implement with React",
                "",
            }

            local issue = parser.parse_markdown_to_issue(buffer_lines)

            assert.equals("Use MVC pattern\nImplement with React", issue.design)
        end)

        it("should parse notes section", function()
            local buffer_lines = {
                "---",
                "id: bd-16",
                "title: Issue with Notes",
                "type: bug",
                "status: open",
                "priority: 2",
                "created_at: 2023-10-27T10:00:00Z",
                "updated_at: 2023-10-27T12:00:00Z",
                "closed_at: null",
                "---",
                "",
                "# Notes",
                "",
                "Remember to update documentation",
                "",
            }

            local issue = parser.parse_markdown_to_issue(buffer_lines)

            assert.equals("Remember to update documentation", issue.notes)
        end)

        it("should handle empty sections", function()
            local buffer_lines = {
                "---",
                "id: bd-17",
                "title: Issue with empty sections",
                "type: task",
                "status: open",
                "priority: 2",
                "created_at: 2023-10-27T10:00:00Z",
                "updated_at: 2023-10-27T12:00:00Z",
                "closed_at: null",
                "---",
                "",
                "# Description",
                "",
                "",
                "# Acceptance Criteria",
                "",
                "",
            }

            local issue = parser.parse_markdown_to_issue(buffer_lines)

            assert.equals("", issue.description)
            assert.equals("", issue.acceptance_criteria)
        end)

        it("should handle missing optional sections", function()
            local buffer_lines = {
                "---",
                "id: bd-18",
                "title: Minimal Issue",
                "type: task",
                "status: open",
                "priority: 2",
                "created_at: 2023-10-27T10:00:00Z",
                "updated_at: 2023-10-27T12:00:00Z",
                "closed_at: null",
                "---",
                "",
            }

            local issue = parser.parse_markdown_to_issue(buffer_lines)

            assert.is_nil(issue.description)
            assert.is_nil(issue.acceptance_criteria)
            assert.is_nil(issue.design)
            assert.is_nil(issue.notes)
        end)

        it("should parse closed_at timestamp when present", function()
            local buffer_lines = {
                "---",
                "id: bd-19",
                "title: Closed Issue",
                "type: bug",
                "status: closed",
                "priority: 1",
                "created_at: 2023-10-27T10:00:00Z",
                "updated_at: 2023-10-27T12:00:00Z",
                "closed_at: 2023-10-27T14:00:00Z",
                "---",
                "",
            }

            local issue = parser.parse_markdown_to_issue(buffer_lines)

            assert.equals("2023-10-27T14:00:00Z", issue.closed_at)
        end)

        it("should parse complete issue with all fields and sections", function()
            local buffer_lines = {
                "---",
                "id: bd-20",
                "title: Complete Issue",
                "type: feature",
                "status: in_progress",
                "priority: 1",
                "parent: bd-100",
                "dependencies:",
                "  - bd-120",
                "  - bd-121",
                "labels:",
                "  - ui",
                "  - backend",
                "assignee: jane.smith",
                "created_at: 2023-10-27T10:00:00Z",
                "updated_at: 2023-10-27T12:00:00Z",
                "closed_at: null",
                "---",
                "",
                "# Description",
                "",
                "A comprehensive description",
                "",
                "# Acceptance Criteria",
                "",
                "Must meet all requirements",
                "",
                "# Design",
                "",
                "Technical design notes",
                "",
                "# Notes",
                "",
                "Additional information",
                "",
            }

            local issue = parser.parse_markdown_to_issue(buffer_lines)

            -- Check frontmatter fields
            assert.equals("bd-20", issue.id)
            assert.equals("Complete Issue", issue.title)
            assert.equals("feature", issue.issue_type)
            assert.equals("in_progress", issue.status)
            assert.equals(1, issue.priority)
            assert.equals("bd-100", issue.parent)
            assert.is_table(issue.dependencies)
            assert.equals(2, #issue.dependencies)
            assert.equals("bd-120", issue.dependencies[1])
            assert.equals("bd-121", issue.dependencies[2])
            assert.is_table(issue.labels)
            assert.equals(2, #issue.labels)
            assert.equals("ui", issue.labels[1])
            assert.equals("backend", issue.labels[2])
            assert.equals("jane.smith", issue.assignee)

            -- Check markdown sections
            assert.equals("A comprehensive description", issue.description)
            assert.equals("Must meet all requirements", issue.acceptance_criteria)
            assert.equals("Technical design notes", issue.design)
            assert.equals("Additional information", issue.notes)
        end)

        it("should handle sections with complex multi-line content", function()
            local buffer_lines = {
                "---",
                "id: bd-21",
                "title: Complex Content",
                "type: task",
                "status: open",
                "priority: 2",
                "created_at: 2023-10-27T10:00:00Z",
                "updated_at: 2023-10-27T12:00:00Z",
                "closed_at: null",
                "---",
                "",
                "# Description",
                "",
                "First paragraph of description.",
                "",
                "Second paragraph with multiple lines",
                "that continue here.",
                "",
                "# Design",
                "",
                "## Subsection",
                "",
                "Some design notes with **bold** and *italic*.",
                "- Bullet point 1",
                "- Bullet point 2",
                "",
            }

            local issue = parser.parse_markdown_to_issue(buffer_lines)

            assert.is_not_nil(issue.description)
            assert.matches("First paragraph", issue.description)
            assert.matches("Second paragraph", issue.description)

            assert.is_not_nil(issue.design)
            assert.matches("## Subsection", issue.design)
            assert.matches("Bullet point", issue.design)
        end)
    end)
end)
