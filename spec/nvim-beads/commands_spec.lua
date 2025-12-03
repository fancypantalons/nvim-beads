--- Unit tests for nvim-beads.issue.diff generate_update_commands function
--- Tests command generation from diff changes to bd CLI commands

describe("nvim-beads.issue.diff", function()
    local diff

    before_each(function()
        -- Clear the module cache to get fresh instance
        package.loaded["nvim-beads.issue.diff"] = nil
        diff = require("nvim-beads.issue.diff")
    end)

    describe("generate_update_commands", function()
        describe("metadata field updates", function()
            it("should generate command for title change", function()
                local changes = {
                    metadata = {
                        title = "New Title",
                    },
                }

                local commands = diff.generate_update_commands("bd-1", changes)

                assert.equals(1, #commands)
                assert.equals("bd update bd-1 --title 'New Title'", commands[1])
            end)

            it("should generate command for priority change", function()
                local changes = {
                    metadata = {
                        priority = 1,
                    },
                }

                local commands = diff.generate_update_commands("bd-1", changes)

                assert.equals(1, #commands)
                assert.equals("bd update bd-1 --priority 1", commands[1])
            end)

            it("should generate command for assignee change", function()
                local changes = {
                    metadata = {
                        assignee = "jane.smith",
                    },
                }

                local commands = diff.generate_update_commands("bd-1", changes)

                assert.equals(1, #commands)
                assert.equals("bd update bd-1 --assignee 'jane.smith'", commands[1])
            end)

            it("should generate command for assignee removal", function()
                -- When assignee is removed, diff_issues uses empty string as sentinel
                local changes = {
                    metadata = {
                        assignee = "", -- Empty string indicates removal
                    },
                }

                local commands = diff.generate_update_commands("bd-1", changes)

                assert.equals(1, #commands)
                assert.equals('bd update bd-1 --assignee ""', commands[1])
            end)

            it("should combine multiple metadata changes into single command", function()
                local changes = {
                    metadata = {
                        title = "Updated Title",
                        priority = 0,
                    },
                }

                local commands = diff.generate_update_commands("bd-1", changes)

                assert.equals(1, #commands)
                assert.is_true(commands[1]:match("bd update bd%-1") ~= nil)
                assert.is_true(commands[1]:match("%-%-title 'Updated Title'") ~= nil)
                assert.is_true(commands[1]:match("%-%-priority 0") ~= nil)
            end)
        end)

        describe("text section updates", function()
            it("should generate command for description change", function()
                local changes = {
                    sections = {
                        description = "New description text",
                    },
                }

                local commands = diff.generate_update_commands("bd-1", changes)

                assert.equals(1, #commands)
                assert.equals("bd update bd-1 --description 'New description text'", commands[1])
            end)

            it("should generate command for acceptance_criteria change", function()
                local changes = {
                    sections = {
                        acceptance_criteria = "Must pass all tests",
                    },
                }

                local commands = diff.generate_update_commands("bd-1", changes)

                assert.equals(1, #commands)
                assert.equals("bd update bd-1 --acceptance 'Must pass all tests'", commands[1])
            end)

            it("should generate command for design change", function()
                local changes = {
                    sections = {
                        design = "Use MVVM pattern",
                    },
                }

                local commands = diff.generate_update_commands("bd-1", changes)

                assert.equals(1, #commands)
                assert.equals("bd update bd-1 --design 'Use MVVM pattern'", commands[1])
            end)

            it("should generate command for notes change", function()
                local changes = {
                    sections = {
                        notes = "Additional implementation notes",
                    },
                }

                local commands = diff.generate_update_commands("bd-1", changes)

                assert.equals(1, #commands)
                assert.equals("bd update bd-1 --notes 'Additional implementation notes'", commands[1])
            end)

            it("should handle empty string for text sections", function()
                local changes = {
                    sections = {
                        description = "",
                    },
                }

                local commands = diff.generate_update_commands("bd-1", changes)

                assert.equals(1, #commands)
                assert.equals("bd update bd-1 --description ''", commands[1])
            end)

            it("should combine multiple section changes into single command", function()
                local changes = {
                    sections = {
                        description = "New desc",
                        design = "New design",
                    },
                }

                local commands = diff.generate_update_commands("bd-1", changes)

                assert.equals(1, #commands)
                assert.is_true(commands[1]:match("bd update bd%-1") ~= nil)
                assert.is_true(commands[1]:match("%-%-description 'New desc'") ~= nil)
                assert.is_true(commands[1]:match("%-%-design 'New design'") ~= nil)
            end)
        end)

        describe("status transitions", function()
            it("should generate update command for in_progress status", function()
                local changes = {
                    status = "in_progress",
                }

                local commands = diff.generate_update_commands("bd-1", changes)

                assert.equals(1, #commands)
                assert.equals("bd update bd-1 --status in_progress", commands[1])
            end)

            it("should generate update command for blocked status", function()
                local changes = {
                    status = "blocked",
                }

                local commands = diff.generate_update_commands("bd-1", changes)

                assert.equals(1, #commands)
                assert.equals("bd update bd-1 --status blocked", commands[1])
            end)

            it("should generate close command for closed status", function()
                local changes = {
                    status = "closed",
                }

                local commands = diff.generate_update_commands("bd-1", changes)

                assert.equals(1, #commands)
                assert.equals("bd close bd-1", commands[1])
            end)

            it("should generate reopen command for open status", function()
                local changes = {
                    status = "open",
                }

                local commands = diff.generate_update_commands("bd-1", changes)

                assert.equals(1, #commands)
                assert.equals("bd reopen bd-1", commands[1])
            end)
        end)

        describe("label operations", function()
            it("should generate commands for label additions", function()
                local changes = {
                    labels = {
                        add = { "ui", "backend" },
                    },
                }

                local commands = diff.generate_update_commands("bd-1", changes)

                assert.equals(2, #commands)
                assert.is_true(vim.tbl_contains(commands, "bd label add bd-1 ui"))
                assert.is_true(vim.tbl_contains(commands, "bd label add bd-1 backend"))
            end)

            it("should generate commands for label removals", function()
                local changes = {
                    labels = {
                        remove = { "old-label", "deprecated" },
                    },
                }

                local commands = diff.generate_update_commands("bd-1", changes)

                assert.equals(2, #commands)
                assert.is_true(vim.tbl_contains(commands, "bd label remove bd-1 old-label"))
                assert.is_true(vim.tbl_contains(commands, "bd label remove bd-1 deprecated"))
            end)

            it("should generate commands for both label additions and removals", function()
                local changes = {
                    labels = {
                        add = { "new-label" },
                        remove = { "old-label" },
                    },
                }

                local commands = diff.generate_update_commands("bd-1", changes)

                assert.equals(2, #commands)
                -- Removals should come before additions
                assert.equals("bd label remove bd-1 old-label", commands[1])
                assert.equals("bd label add bd-1 new-label", commands[2])
            end)
        end)

        describe("dependency operations", function()
            it("should generate commands for dependency additions", function()
                local changes = {
                    dependencies = {
                        add = { "bd-120", "bd-121" },
                    },
                }

                local commands = diff.generate_update_commands("bd-1", changes)

                assert.equals(2, #commands)
                assert.is_true(vim.tbl_contains(commands, "bd dep add bd-1 bd-120 --type blocks"))
                assert.is_true(vim.tbl_contains(commands, "bd dep add bd-1 bd-121 --type blocks"))
            end)

            it("should generate commands for dependency removals", function()
                local changes = {
                    dependencies = {
                        remove = { "bd-100", "bd-101" },
                    },
                }

                local commands = diff.generate_update_commands("bd-1", changes)

                assert.equals(2, #commands)
                assert.is_true(vim.tbl_contains(commands, "bd dep remove bd-1 bd-100"))
                assert.is_true(vim.tbl_contains(commands, "bd dep remove bd-1 bd-101"))
            end)

            it("should generate commands for both dependency additions and removals", function()
                local changes = {
                    dependencies = {
                        add = { "bd-120" },
                        remove = { "bd-100" },
                    },
                }

                local commands = diff.generate_update_commands("bd-1", changes)

                assert.equals(2, #commands)
                -- Removals should come before additions
                assert.equals("bd dep remove bd-1 bd-100", commands[1])
                assert.equals("bd dep add bd-1 bd-120 --type blocks", commands[2])
            end)
        end)

        describe("parent operations", function()
            it("should generate command for parent addition", function()
                local changes = {
                    parent = "bd-50",
                }

                local commands = diff.generate_update_commands("bd-1", changes)

                assert.equals(1, #commands)
                assert.equals("bd dep add bd-1 bd-50 --type parent-child", commands[1])
            end)

            it("should generate placeholder command for parent removal", function()
                local changes = {
                    parent = "", -- Empty string indicates removal
                }

                local commands = diff.generate_update_commands("bd-1", changes)

                assert.equals(1, #commands)
                -- Note: This is a placeholder - actual implementation would need
                -- the original parent ID from the caller
                assert.equals("bd dep remove bd-1 <parent-id>", commands[1])
            end)

            it("should generate command for parent change", function()
                local changes = {
                    parent = "bd-60", -- Changed from bd-50 to bd-60
                }

                local commands = diff.generate_update_commands("bd-1", changes)

                assert.equals(1, #commands)
                -- New parent is added (removal of old parent would be handled separately)
                assert.equals("bd dep add bd-1 bd-60 --type parent-child", commands[1])
            end)
        end)

        describe("special character escaping", function()
            it("should escape single quotes in title", function()
                local changes = {
                    metadata = {
                        title = "Fix user's authentication bug",
                    },
                }

                local commands = diff.generate_update_commands("bd-1", changes)

                assert.equals(1, #commands)
                assert.equals("bd update bd-1 --title 'Fix user'\\''s authentication bug'", commands[1])
            end)

            it("should escape single quotes in description", function()
                local changes = {
                    sections = {
                        description = "The user's session wasn't persisted",
                    },
                }

                local commands = diff.generate_update_commands("bd-1", changes)

                assert.equals(1, #commands)
                assert.equals("bd update bd-1 --description 'The user'\\''s session wasn'\\''t persisted'", commands[1])
            end)

            it("should handle double quotes safely", function()
                local changes = {
                    metadata = {
                        title = 'Add "advanced" search feature',
                    },
                }

                local commands = diff.generate_update_commands("bd-1", changes)

                assert.equals(1, #commands)
                -- Double quotes are safe inside single quotes
                assert.equals("bd update bd-1 --title 'Add \"advanced\" search feature'", commands[1])
            end)

            it("should handle newlines in text sections", function()
                local changes = {
                    sections = {
                        description = "Line 1\nLine 2\nLine 3",
                    },
                }

                local commands = diff.generate_update_commands("bd-1", changes)

                assert.equals(1, #commands)
                -- Newlines should be preserved within single quotes
                assert.equals("bd update bd-1 --description 'Line 1\nLine 2\nLine 3'", commands[1])
            end)

            it("should handle special shell characters", function()
                local changes = {
                    metadata = {
                        title = "Fix: $variable expansion & pipe | redirect >",
                    },
                }

                local commands = diff.generate_update_commands("bd-1", changes)

                assert.equals(1, #commands)
                -- Special chars should be safe inside single quotes
                assert.equals("bd update bd-1 --title 'Fix: $variable expansion & pipe | redirect >'", commands[1])
            end)
        end)

        describe("multiple simultaneous changes", function()
            it("should generate correct command sequence for complex changes", function()
                local changes = {
                    parent = "bd-60",
                    dependencies = {
                        add = { "bd-120" },
                        remove = { "bd-100" },
                    },
                    labels = {
                        add = { "backend" },
                        remove = { "old-label" },
                    },
                    status = "in_progress",
                    metadata = {
                        title = "Updated Title",
                        priority = 1,
                    },
                    sections = {
                        description = "New description",
                    },
                }

                local commands = diff.generate_update_commands("bd-1", changes)

                -- Expected order: parent, deps, labels, status, metadata/sections
                -- Parent: 1 command
                -- Dependencies: 1 remove + 1 add = 2 commands
                -- Labels: 1 remove + 1 add = 2 commands
                -- Status: 1 command
                -- Metadata + sections: 1 combined command
                assert.equals(7, #commands)

                -- Verify order
                assert.is_true(commands[1]:match("bd dep add bd%-1 bd%-60 %-%-type parent%-child") ~= nil)
                assert.is_true(commands[2]:match("bd dep remove bd%-1 bd%-100") ~= nil)
                assert.is_true(commands[3]:match("bd dep add bd%-1 bd%-120 %-%-type blocks") ~= nil)
                assert.is_true(commands[4]:match("bd label remove bd%-1 old%-label") ~= nil)
                assert.is_true(commands[5]:match("bd label add bd%-1 backend") ~= nil)
                assert.is_true(commands[6]:match("bd update bd%-1 %-%-status in_progress") ~= nil)
                assert.is_true(commands[7]:match("bd update bd%-1") ~= nil)
                assert.is_true(commands[7]:match("%-%-title") ~= nil)
                assert.is_true(commands[7]:match("%-%-priority") ~= nil)
                assert.is_true(commands[7]:match("%-%-description") ~= nil)
            end)
        end)

        describe("edge cases", function()
            it("should return empty array for no changes", function()
                local changes = {}

                local commands = diff.generate_update_commands("bd-1", changes)

                assert.is_table(commands)
                assert.equals(0, #commands)
            end)

            it("should not generate update command with no metadata or section changes", function()
                local changes = {
                    status = "in_progress",
                }

                local commands = diff.generate_update_commands("bd-1", changes)

                assert.equals(1, #commands)
                assert.equals("bd update bd-1 --status in_progress", commands[1])
            end)
        end)
    end)
end)
