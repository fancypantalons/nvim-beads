# nvim-beads Implementation Plan (Iterative with Integrated Testing)

This document outlines an iterative development plan for the `nvim-beads` Neovim plugin. The work is sequenced to deliver functional value at each stage, and testing is integrated into each iteration.

## Key Decisions

1.  **Parsing:** Simple, dependency-free regex and string splitting in Lua will be used for parsing YAML frontmatter and Markdown sections.
2.  **Dependencies:** External Lua dependencies from the original template will be removed. `telescope.nvim` is a required peer dependency.
3.  **Codebase Cleanup:** All placeholder code from the base template will be removed as part of the first iteration.

---

## Iteration 1: List Issues in Telescope

**Goal:** A user can execute `:Beads` and see a list of issue IDs and titles in a Telescope picker.

-   **Task 1.1: Project Scaffolding & Cleanup**
    -   Rename `plugin/plugin_template.lua` to `plugin/nvim-beads.lua`.
    -   Create initial modules: `lua/nvim-beads/core.lua`, `lua/nvim-beads/commands.lua`, and `lua/telescope/_extensions/nvim_beads/init.lua`.
    -   Remove template-specific example code and tests.
    -   Update project documentation (`README.md`, etc.).

-   **Task 1.2: Implement Core `bd` Executor**
    -   In `lua/nvim-beads/core.lua`, create an async function to execute `bd` commands, parse JSON output, and handle errors.

-   **Task 1.3: Implement Basic Telescope Picker**
    -   In `lua/telescope/_extensions/nvim_beads/init.lua`, define the `beads_picker` function.
    -   Implement the `finder` using `finders.new_async` to run `bd list --json`.
    -   The `entry_maker` will transform each issue into an entry table: `{ value = issue, display = issue.id .. ": " .. issue.title, ordinal = issue.title }`.

-   **Task 1.4: Create User Command**
    -   Define the `:Beads` command to call the `beads_picker`.
    -   Document the requirement for users to run `require('telescope').load_extension('nvim_beads')`.

-   **Task 1.5: Unit Testing**
    -   Create a spec file for `core.lua`.
    -   Write a test for the `bd` executor that mocks `vim.system` and verifies correct JSON parsing and error handling.

---

## Iteration 2: Preview Issue Content

**Goal:** When an issue is highlighted in Telescope, the preview pane shows the full, formatted Markdown content.

-   **Task 2.1: Implement Issue Formatter**
    -   Create `lua/nvim-beads/issue.lua` and `lua/nvim-beads/types.lua`.
    -   In `issue.lua`, create `format_issue_to_markdown(issue)` to convert an issue table into a list of strings (YAML frontmatter + Markdown body).

-   **Task 2.2: Implement Telescope Previewer**
    -   Enhance the `beads_picker` with a `previewers.new_buffer_previewer`.
    -   The `define_preview` function will call `bd show --json <id>`, pass the result to `format_issue_to_markdown`, populate the buffer, and apply Markdown highlighting.

-   **Task 2.3: Unit Testing**
    -   Create a spec file for `issue.lua`.
    -   Write a test for `format_issue_to_markdown` that provides a sample issue table and asserts the correctness of the output string list.

---

## Iteration 3: Open Issues in a Buffer

**Goal:** Pressing `<CR>` in Telescope opens the issue content in a new, editable `beads://` buffer.

-   **Task 3.1: Implement Buffer Manager**
    -   In `lua/nvim-beads/issue.lua`, create `open_issue_buffer(issue_id)`. This function will fetch data, format it, and populate a new buffer named `beads://issue/<issue_id>`.

-   **Task 3.2: Implement Telescope Action**
    -   In the `beads_picker`, map `<CR>` to a custom action that calls `open_issue_buffer` with the selected issue's ID and closes the picker.

-   **Task 3.3: Create `:BeadsOpenIssue` Command**
    -   Create the `:BeadsOpenIssue <id>` user command to provide direct access to the buffer manager.

-   **Task 3.4: Testing**
    -   The core logic is covered by tests for the formatter. End-to-end testing for the action itself is deferred in favor of unit testing more complex logic in subsequent iterations.

---

## Iteration 4: Edit and Save Existing Issues

**Goal:** Modifying and saving a `beads://` buffer updates the corresponding issue.

-   **Task 4.1: Implement Content Parser**
    -   In `lua/nvim-beads/issue.lua`, create `parse_markdown_to_issue(buffer_content)` to parse the buffer content back into a Lua table.

-   **Task 4.2: Implement Save Autocommand**
    -   Create `lua/nvim-beads/autocmds.lua`.
    -   Define a `BufWritePost` autocommand for `beads://issue/*`.
    -   The callback will parse the buffer, fetch the original state, compare them, and execute atomic `bd` commands for each detected change.
    -   After a successful save, the buffer is reloaded from the authoritative source.

-   **Task 4.3: Unit Testing**
    -   Write a test for the `parse_markdown_to_issue` function.
    -   Write a test for the "diff and command generation" logic. This test will provide original and modified issue states and assert that the correct `bd` commands are generated.

---

## Iteration 5: Create New Issues

**Goal:** Users can create new issues from a template using `:BeadsCreateIssue`.

-   **Task 5.1: Implement Creation Command and Buffer**
    -   Create the `:BeadsCreateIssue <type>` command.
    -   Implement `open_new_issue_buffer(issue_type)` to fetch a template from `bd template show --json` and populate a buffer named `beads://issue/new?type=<type>`.

-   **Task 5.2: Extend Save Autocommand for Creation**
    -   Modify the `BufWritePost` autocommand to handle the `beads://issue/new*` buffer name.
    -   The create logic will parse the buffer, run `bd create ...`, capture the new ID, rename the buffer, and reload its content.

-   **Task 5.3: Unit Testing**
    -   Write a test for the "create command generation" logic. This test will take a new issue's state from a parsed buffer and assert that the correct `bd create ...` command string is generated.

---

## Iteration 6: Health Check

**Goal:** Provide a diagnostic tool to help users verify their setup.

-   **Task 6.1: Implement Health Check**
    -   Create `lua/nvim-beads/health.lua` with a `check()` function.
    -   The function will verify `bd` is executable, run `bd doctor --json`, and confirm `telescope.nvim` is installed.

-   **Task 6.2: Unit Testing**
    -   Write a test for the health check, mocking the outcomes of `vim.fn.executable`, the `bd doctor` command, and `pcall`.
