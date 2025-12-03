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
                assert.same({"bd", "update", "bd-1", "--title", "New Title"}, commands[1])
            end)

            it("should generate command for priority change", function()
                local changes = {
                    metadata = {
                        priority = 1,
                    },
                }

                local commands = diff.generate_update_commands("bd-1", changes)

                assert.equals(1, #commands)
                assert.same({"bd", "update", "bd-1", "--priority", "1"}, commands[1])
            end)

            it("should generate command for assignee change", function()
                local changes = {
                    metadata = {
                        assignee = "jane.smith",
                    },
                }

                local commands = diff.generate_update_commands("bd-1", changes)

                assert.equals(1, #commands)
                assert.same({"bd", "update", "bd-1", "--assignee", "jane.smith"}, commands[1])
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
                assert.same({"bd", "update", "bd-1", "--assignee", ""}, commands[1])
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
                local cmd = commands[1]
                -- Check that the command has all expected elements
                assert.equals("bd", cmd[1])
                assert.equals("update", cmd[2])
                assert.equals("bd-1", cmd[3])
                -- Find positions of --title and --priority flags
                local has_title = false
                local has_priority = false
                for i = 4, #cmd, 2 do
                    if cmd[i] == "--title" and cmd[i+1] == "Updated Title" then
                        has_title = true
                    elseif cmd[i] == "--priority" and cmd[i+1] == "0" then
                        has_priority = true
                    end
                end
                assert.is_true(has_title)
                assert.is_true(has_priority)
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
                assert.same({"bd", "update", "bd-1", "--description", "New description text"}, commands[1])
            end)

            it("should generate command for acceptance_criteria change", function()
                local changes = {
                    sections = {
                        acceptance_criteria = "Must pass all tests",
                    },
                }

                local commands = diff.generate_update_commands("bd-1", changes)

                assert.equals(1, #commands)
                assert.same({"bd", "update", "bd-1", "--acceptance", "Must pass all tests"}, commands[1])
            end)

            it("should generate command for design change", function()
                local changes = {
                    sections = {
                        design = "Use MVVM pattern",
                    },
                }

                local commands = diff.generate_update_commands("bd-1", changes)

                assert.equals(1, #commands)
                assert.same({"bd", "update", "bd-1", "--design", "Use MVVM pattern"}, commands[1])
            end)

            it("should generate command for notes change", function()
                local changes = {
                    sections = {
                        notes = "Additional implementation notes",
                    },
                }

                local commands = diff.generate_update_commands("bd-1", changes)

                assert.equals(1, #commands)
                assert.same({"bd", "update", "bd-1", "--notes", "Additional implementation notes"}, commands[1])
            end)

            it("should handle empty string for text sections", function()
                local changes = {
                    sections = {
                        description = "",
                    },
                }

                local commands = diff.generate_update_commands("bd-1", changes)

                assert.equals(1, #commands)
                assert.same({"bd", "update", "bd-1", "--description", ""}, commands[1])
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
                local cmd = commands[1]
                -- Check command structure
                assert.equals("bd", cmd[1])
                assert.equals("update", cmd[2])
                assert.equals("bd-1", cmd[3])
                -- Find --description and --design flags
                local has_description = false
                local has_design = false
                for i = 4, #cmd, 2 do
                    if cmd[i] == "--description" and cmd[i+1] == "New desc" then
                        has_description = true
                    elseif cmd[i] == "--design" and cmd[i+1] == "New design" then
                        has_design = true
                    end
                end
                assert.is_true(has_description)
                assert.is_true(has_design)
            end)
        end)

        describe("status transitions", function()
            it("should generate update command for in_progress status", function()
                local changes = {
                    status = "in_progress",
                }

                local commands = diff.generate_update_commands("bd-1", changes)

                assert.equals(1, #commands)
                assert.same({"bd", "update", "bd-1", "--status", "in_progress"}, commands[1])
            end)

            it("should generate update command for blocked status", function()
                local changes = {
                    status = "blocked",
                }

                local commands = diff.generate_update_commands("bd-1", changes)

                assert.equals(1, #commands)
                assert.same({"bd", "update", "bd-1", "--status", "blocked"}, commands[1])
            end)

            it("should generate close command for closed status", function()
                local changes = {
                    status = "closed",
                }

                local commands = diff.generate_update_commands("bd-1", changes)

                assert.equals(1, #commands)
                assert.same({"bd", "close", "bd-1"}, commands[1])
            end)

            it("should generate reopen command for open status", function()
                local changes = {
                    status = "open",
                }

                local commands = diff.generate_update_commands("bd-1", changes)

                assert.equals(1, #commands)
                assert.same({"bd", "reopen", "bd-1"}, commands[1])
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
                assert.same({"bd", "label", "add", "bd-1", "ui"}, commands[1])
                assert.same({"bd", "label", "add", "bd-1", "backend"}, commands[2])
            end)

            it("should generate commands for label removals", function()
                local changes = {
                    labels = {
                        remove = { "old-label", "deprecated" },
                    },
                }

                local commands = diff.generate_update_commands("bd-1", changes)

                assert.equals(2, #commands)
                assert.same({"bd", "label", "remove", "bd-1", "old-label"}, commands[1])
                assert.same({"bd", "label", "remove", "bd-1", "deprecated"}, commands[2])
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
                assert.same({"bd", "label", "remove", "bd-1", "old-label"}, commands[1])
                assert.same({"bd", "label", "add", "bd-1", "new-label"}, commands[2])
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
                assert.same({"bd", "dep", "add", "bd-1", "bd-120", "--type", "blocks"}, commands[1])
                assert.same({"bd", "dep", "add", "bd-1", "bd-121", "--type", "blocks"}, commands[2])
            end)

            it("should generate commands for dependency removals", function()
                local changes = {
                    dependencies = {
                        remove = { "bd-100", "bd-101" },
                    },
                }

                local commands = diff.generate_update_commands("bd-1", changes)

                assert.equals(2, #commands)
                assert.same({"bd", "dep", "remove", "bd-1", "bd-100"}, commands[1])
                assert.same({"bd", "dep", "remove", "bd-1", "bd-101"}, commands[2])
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
                assert.same({"bd", "dep", "remove", "bd-1", "bd-100"}, commands[1])
                assert.same({"bd", "dep", "add", "bd-1", "bd-120", "--type", "blocks"}, commands[2])
            end)
        end)

        describe("parent operations", function()
            it("should generate command for parent addition", function()
                local changes = {
                    parent = "bd-50",
                }

                local commands = diff.generate_update_commands("bd-1", changes)

                assert.equals(1, #commands)
                assert.same({"bd", "dep", "add", "bd-1", "bd-50", "--type", "parent-child"}, commands[1])
            end)

            it("should generate placeholder command for parent removal", function()
                local changes = {
                    parent = "", -- Empty string indicates removal
                }

                local commands = diff.generate_update_commands("bd-1", changes)

                assert.equals(1, #commands)
                -- Note: This is a placeholder - actual implementation would need
                -- the original parent ID from the caller
                assert.same({"bd", "dep", "remove", "bd-1", "<parent-id>"}, commands[1])
            end)

            it("should generate command for parent change", function()
                local changes = {
                    parent = "bd-60", -- Changed from bd-50 to bd-60
                }

                local commands = diff.generate_update_commands("bd-1", changes)

                assert.equals(1, #commands)
                -- New parent is added (removal of old parent would be handled separately)
                assert.same({"bd", "dep", "add", "bd-1", "bd-60", "--type", "parent-child"}, commands[1])
            end)
        end)

        describe("special character escaping", function()
            it("should pass single quotes as-is (no escaping needed with tables)", function()
                local changes = {
                    metadata = {
                        title = "Fix user's authentication bug",
                    },
                }

                local commands = diff.generate_update_commands("bd-1", changes)

                assert.equals(1, #commands)
                -- With command tables, single quotes don't need escaping
                assert.same({"bd", "update", "bd-1", "--title", "Fix user's authentication bug"}, commands[1])
            end)

            it("should pass single quotes in description as-is", function()
                local changes = {
                    sections = {
                        description = "The user's session wasn't persisted",
                    },
                }

                local commands = diff.generate_update_commands("bd-1", changes)

                assert.equals(1, #commands)
                assert.same({"bd", "update", "bd-1", "--description", "The user's session wasn't persisted"}, commands[1])
            end)

            it("should handle double quotes safely", function()
                local changes = {
                    metadata = {
                        title = 'Add "advanced" search feature',
                    },
                }

                local commands = diff.generate_update_commands("bd-1", changes)

                assert.equals(1, #commands)
                -- Double quotes are passed as-is in command tables
                assert.same({"bd", "update", "bd-1", "--title", 'Add "advanced" search feature'}, commands[1])
            end)

            it("should handle newlines in text sections", function()
                local changes = {
                    sections = {
                        description = "Line 1\nLine 2\nLine 3",
                    },
                }

                local commands = diff.generate_update_commands("bd-1", changes)

                assert.equals(1, #commands)
                -- Newlines are preserved as literal \n characters in the string
                assert.same({"bd", "update", "bd-1", "--description", "Line 1\nLine 2\nLine 3"}, commands[1])
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
                assert.same({"bd", "update", "bd-1", "--title", "Fix: $variable expansion & pipe | redirect >"}, commands[1])
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

                -- Verify order using table assertions
                assert.same({"bd", "dep", "add", "bd-1", "bd-60", "--type", "parent-child"}, commands[1])
                assert.same({"bd", "dep", "remove", "bd-1", "bd-100"}, commands[2])
                assert.same({"bd", "dep", "add", "bd-1", "bd-120", "--type", "blocks"}, commands[3])
                assert.same({"bd", "label", "remove", "bd-1", "old-label"}, commands[4])
                assert.same({"bd", "label", "add", "bd-1", "backend"}, commands[5])
                assert.same({"bd", "update", "bd-1", "--status", "in_progress"}, commands[6])

                -- Command 7 is a combined update with multiple flags - check structure
                local cmd7 = commands[7]
                assert.equals("bd", cmd7[1])
                assert.equals("update", cmd7[2])
                assert.equals("bd-1", cmd7[3])
                -- Check for presence of all expected flags
                local has_title = false
                local has_priority = false
                local has_description = false
                for i = 4, #cmd7, 2 do
                    if cmd7[i] == "--title" then has_title = true end
                    if cmd7[i] == "--priority" then has_priority = true end
                    if cmd7[i] == "--description" then has_description = true end
                end
                assert.is_true(has_title)
                assert.is_true(has_priority)
                assert.is_true(has_description)
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
                assert.same({"bd", "update", "bd-1", "--status", "in_progress"}, commands[1])
            end)
        end)
    end)
end)
