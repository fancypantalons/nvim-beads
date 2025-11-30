# nvim-beads Detailed Requirements

## 1. Introduction

This document provides a detailed breakdown of the functional and non-functional requirements for the Minimum Viable Product (MVP) of `nvim-beads`. It expands upon the initial `product-concept.md`, incorporating technical details derived from the Neovim Lua development reference and the `beads` command JSON schemas.

The goal of this plugin is to provide a seamless and ergonomic interface for interacting with the `beads` issue tracker from within Neovim, inspired by plugins like `vim-fugitive` and `taskwiki`.

## 2. Core Components

The plugin will be composed of several key components:

-   **Telescope Integration:** A custom Telescope extension for browsing, searching, and selecting issues.
-   **Issue Buffer:** A specialized buffer with a custom URI scheme (`beads://`) for viewing and editing issue details in a structured Markdown format.
-   **Lua Module (`nvim-beads`):** The core plugin logic, responsible for:
    -   Executing `bd` shell commands.
    -   Parsing JSON output from `bd`.
    -   Managing the state and content of the Issue Buffer.
    -   Handling save operations to create or update issues.
-   **User Commands:** A set of Neovim commands to expose plugin functionality, such as `:Beads` (list issues), `:BeadsOpenIssue`, and `:BeadsCreateIssue`.

## 3. Functional Requirements (MVP)

### 3.1. Issue Listing (Telescope Integration)

The plugin will provide a Telescope picker to view and filter all issues.

-   **Invocation:** A user command, `:Beads`, will be created to open the Telescope issue picker.
-   **Data Source:**
    -   The list of issues (left pane) will be populated by executing `bd list --json` and parsing the resulting JSON array, which is expected to conform to `doc/dev/reference/list-command-schema.json`.
    -   The issue preview (right pane) will display detailed information for the currently selected issue, fetched by executing `bd show --json <issue-id>` and parsing the resulting JSON, which is expected to conform to `doc/dev/reference/show-command-schema.json`.
-   **Picker Display:**
    -   **Entry Text:** Each item in the list will be displayed in the format `ID: Title` (e.g., `bd-1: Initial setup`).
    -   **Preview:** When an issue is highlighted, the preview pane on the right will render the issue's content in the exact Markdown format used by the Issue Buffer (see 3.2). This provides a read-only view of the full issue details.
-   **Filtering:** Users can use Telescope's built-in fuzzy search to filter issues based on the entry text (ID and Title).
-   **Actions:**
    -   Pressing `<CR>` (Enter) on a selected issue will open it for editing in a new Issue Buffer.

### 3.2. Issue Viewing and Editing

A dedicated buffer will be used to present issue information in an editable format.

-   **Activation:**
    1.  By selecting an issue in the Telescope picker.
    2.  By directly running the command `:BeadsOpenIssue <id>`, where `<id>` is a valid beads issue ID.
-   **Buffer Identity:** The buffer will be given a unique name using a custom URI scheme to distinguish it from normal files (e.g., `beads://issue/bd-1`). This allows for dedicated autocommands and prevents accidental filesystem writes.
-   **Buffer Content & Format:** The buffer's filetype will be set to `markdown`. The content will consist of a YAML frontmatter block followed by Markdown sections.

    -   **YAML Frontmatter:**
        ```yaml
        ---
        id: bd-1         # Read-only
        title: My Issue Title
        type: feature    # bug | feature | task | epic | chore
        status: open     # open | in_progress | blocked | closed
        priority: 2      # 0-4
        parent: bd-100   # Optional: ID of parent issue
        dependencies:    # List of issue IDs this issue blocks
          - bd-120
          - bd-121
        labels:
          - ui
          - backend
        created_at: 2023-10-27T10:00:00Z # Read-only
        updated_at: 2023-10-27T12:00:00Z # Read-only
        closed_at: null                   # Read-only
        ---
        ```

    -   **Markdown Body:**
        ```markdown
        # Description

        A clear, detailed explanation of the issue.

        # Acceptance Criteria

        A list of criteria that must be met for the issue to be considered complete.

        # Design

        Technical design notes or implementation plan.

        # Notes

        Any other relevant information.
        ```
-   **Save Logic:** An autocommand on `BufWritePost` for `beads://` buffers will trigger the update logic:
    1.  Parse the current buffer's YAML frontmatter and Markdown content.
    2.  Fetch the authoritative state of the issue using `bd show --json <id>`.
    3.  Perform a comparison between the buffer's content and the authoritative state.
    4.  Construct and execute the necessary `bd` commands to apply only the changed fields (e.g., `bd edit <id> --title "..."`, `bd update <id> --status ...`, `bd edit <id> --deps ...`).
    5.  After a successful save, reload the buffer with the updated authoritative data from `beads` to ensure consistency (e.g., for `updated_at` timestamps).

### 3.3. Issue Creation

The plugin will provide a command to create a new issue from a template.

-   **Activation:** A command `:BeadsCreateIssue <type>` will open a new, unsaved Issue Buffer. `<type>` must be one of `bug`, `feature`, `task`, `epic`, or `chore`.
-   **Buffer Identity:** The new buffer will be named `beads://issue/new?type=<type>`.
-   **Content Initialization:**
    1.  The plugin will execute `bd template show --json <type>` to fetch the default template for the given issue type.
    2.  The buffer will be pre-populated using the data from the template, with an empty `title` and a `status` of `open`.
-   **Save Logic:** On the *first* `BufWritePost` of a `new` issue buffer:
    1.  The buffer content is parsed. The `title` field is required; the save will be aborted with an error if it is missing.
    2.  A `bd create "<title>" --type <type> --priority <p> ...` command is constructed and executed.
    3.  The ID of the newly created issue is captured from the command's output.
    4.  If the Markdown sections (Description, etc.) or other fields like `status` were populated, subsequent `bd edit <new-id> ...` and `bd update <new-id> ...` commands are executed to apply them.
    5.  The buffer is renamed to `beads://issue/<new-id>`.
    6.  The buffer content is reloaded from the new authoritative source to ensure consistency.

## 4. Non-Functional Requirements

-   **Performance:** The plugin must not impact Neovim's startup time. All `require` calls for the core logic will be deferred to command invocations or autocommand callbacks, as per Neovim best practices.
-   **Error Handling:** All shell commands to `bd` will be executed safely. Any errors from the `bd` CLI (non-zero exit codes, stderr output) will be caught and reported to the user via `vim.notify`.
-   **Dependencies:**
    -   The `bd` executable must be installed and available in the system's `$PATH`.
    -   The `nvim-telescope/telescope.nvim` plugin is required for issue listing.
-   **Health Check:** A `:checkhealth nvim-beads` command will be implemented. It will:
    -   Verify that the `bd` executable is present and runnable.
    -   Verify that `bd` is set up correctly in the current repository by running `bd doctor --json` and noting any errors or warnings (schema defined in [doctor-command-schema.json](../reference/doctor-command-schema.json))
    -   Confirm that `telescope.nvim` is installed and accessible.

## 5. Out of Scope (Post-MVP)

The following features from the `product-concept.md` are explicitly deferred to a future release:
-   Support for custom template sections.
-   Viewing, adding, or editing issue comments.
-   Editing additional metadata fields (`estimated_minutes`, `external_ref`).
-   Advanced filtering in the Telescope picker (e.g., by status, priority).
-   Generating search rules or reports.

## 6. Resolved Decisions & CLI Mapping

Based on an investigation of the `bd` command-line interface using the `--help` flag for relevant subcommands, the following CLI mapping has been defined to implement the save logic. This resolves the ambiguity in the initial "Open Questions" section.

-   **Creating Issues:** New issues will be created using the `bd create` command. All fields from the buffer will be passed as flags.
    -   **Command:** `bd create "<title>" --type <type> --priority <p> --description "..." --acceptance "..." --design "..." --labels "l1,l2" --parent <id> --deps "id1,id2"`
    -   The `--parent` flag creates a `parent-child` dependency.
    -   The `--deps` flag creates `blocks` dependencies by default.
    -   The text block fields (`description`, `acceptance`, `design`) can be set directly at creation.

-   **Updating Issue Fields:** All modifications to an existing issue will be handled by comparing the buffer state to the previous state and executing focused, atomic commands. The interactive `bd edit` command will not be used.

    -   **Text & Metadata Fields:** Changes to `title`, `priority`, `description`, `acceptance criteria`, `design`, and `notes` will be applied using `bd update <id> --<field> "..."`.
        -   `bd update bd-1 --title "New Title"`
        -   `bd update bd-1 --priority 1`
        -   `bd update bd-1 --description "New description."`

    -   **Status:** Status changes will be applied using `bd update <id> --status <new-status>`. The plugin will also handle mapping `closed` and `open` statuses to the `bd close` and `bd reopen` commands where appropriate.
        -   `bd update bd-1 --status in_progress`
        -   `bd close bd-1`
        -   `bd reopen bd-1`

    -   **Labels:** Label changes will be detected by diffing the list of labels. Additions and removals will be handled atomically.
        -   `bd label add <id> <label-to-add>`
        -   `bd label remove <id> <label-to-remove>`

    -   **Dependencies:** Dependency changes will be detected by diffing the `dependencies` and `parent` fields.
        -   `bd dep add <id> <dependency-id> --type blocks`
        -   `bd dep remove <id> <dependency-id>`
        -   For the `parent` field: `bd dep add <id> <parent-id> --type parent-child`

-   **Conflict Management:** The MVP will retain the "last write wins" strategy. No merge logic will be implemented.

-   **Schema Scope:** The MVP will continue to ignore fields from the `beads` schema that are not explicitly mentioned in the product concept (e.g., `assignee`, `estimated_minutes`).
