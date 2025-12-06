### Design Plan: Argument-Based Filtering for the "Beads list" Command

This document outlines a plan to extend the `Beads list` command to support optional filtering by issue state and type directly from the command line.

#### 1. High-Level Goal

The objective is to modify the `Beads list` command to accept zero, one, or two optional arguments corresponding to `[state]` and `[type]`. The Telescope window will then display only the issues that match the specified criteria.

**Command Signature:** `Beads list [state] [type]`

**Examples:**
*   `Beads list open bugs` (Filters for open bugs)
*   `Beads list ready` (Filters for issues in the 'ready' state)
*   `Beads list features` (Filters for issues of type 'feature')
*   `Beads list` (Shows all issues, current behavior)

#### 2. Implementation Plan

The implementation can be broken down into three main phases: updating the command definition, parsing the arguments, and applying the filters.

##### **Phase 1: Update Command Definition**

The existing Neovim user command for `Beads list` needs to be updated to accept arguments.

1.  **File to Modify:** `lua/nvim-beads/commands.lua` (or equivalent location where user commands are registered).
2.  **Change:** The `vim.api.nvim_create_user_command` definition for the `list` subcommand should be modified to accept multiple arguments. The `nargs` property should be set to `'*'`.
3.  **Forwarding:** The arguments, available in the command's function via the `opts.fargs` table, will be passed to the core function that launches the Telescope picker.

##### **Phase 2: Argument Parsing Logic**

A dedicated parser function must be created to interpret the free-form arguments.

1.  **New Function:** Create a new helper function, e.g., `parse_list_filters(fargs)`, probably within `lua/nvim-beads/core.lua`.
2.  **Inputs:** The function will take the `fargs` table from the command (e.g., `{'open', 'bugs'}`).
3.  **Logic:**
    *   Define canonical lists of valid `states` and `types` based on `list-command-schema.json` and project conventions (e.g., `states = {'open', 'ready', ...}`, `types = {'bug', 'feature', ...}`).
    *   The parser should handle **optional** pluralization (e.g., map "bugs" to "bug").
    *   It will iterate through the input arguments and attempt to classify each one as either a `state` or a `type`. Given the specified order `[state] [type]`, the first argument would be checked against states first, and the second against types.
    *   The special keyword `all` will be treated as a wildcard, resulting in no filter for that category.
4.  **Output:** The function will return a structured table representing the parsed filters, e.g., `{ state = 'open', type = 'bug' }`. Unspecified filters will be `nil`.

##### **Phase 3: Filter Application**

The logic that populates the Telescope picker needs to be modified to use the parsed filters.

1.  **File to Modify:** `lua/telescope/_extensions/nvim_beads/init.lua` (or wherever the picker is launched).
2.  **Data Fetching:** The function will continue to fetch the complete list of issues by executing `bd list --json`.
3.  **Filtering:**
    *   After decoding the JSON into a Lua table of issues, but *before* creating the `finders.new_table`, iterate over the list of all issues.
    *   Apply the filters from the parsed filter table. An issue will be kept only if it matches all specified filters (e.g., `issue.status == filters.state` and `issue.issue_type == filters.type`).
    *   If a filter is `nil` or `'all'`, that check is skipped.
4.  **Picker Creation:** The final, pre-filtered list of issues is then passed to `finders.new_table`'s `results` option. The rest of the Telescope logic remains unchanged.

#### 3. Key Design Decisions

Based on the initial plan, the following key decisions have been made:

1.  **Filtering Strategy:** Filtering will be implemented entirely in Lua within the `nvim-beads` plugin. The `bd` CLI tool cannot be modified, so the plugin will fetch the complete issue list via `bd list --json` and perform filtering client-side. For the special `ready` state, the `bd ready --json` command will be used as a direct data source, and any `[type]` filter will be applied in Lua afterwards.

2.  **Argument Order:** A strict positional argument order of `[state] [type]` will be enforced. The parser will not attempt to handle reversed or out-of-order arguments. This simplifies implementation while aligning with natural language phrasing.

3.  **State and Type Handling:**
    *   The canonical lists of states and types will be derived from the `list-command-schema.json`.
    *   The parser will handle plural forms of types (e.g., "bugs", "features").
    *   The keyword `all` will be treated as a wildcard, resulting in no filter for that category.

4.  **Error Handling:** If a user provides an invalid state or type (e.g., `Beads list pending foobar`), the plugin will show an explicit error message via `vim.notify`. It will not fail silently by showing an empty list.
