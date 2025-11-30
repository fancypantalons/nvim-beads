# Product Concept

The `nvim-beads` project is a Neovim plugin that provides a convenient, easy-to-use interface, right within Neovim, for interacting with the [beads](https://github.com/steveyegge/beads) issue tracking tool.

Beads is described as:

> a lightweight memory system for coding agents, using a graph-based issue tracker. Four kinds of dependencies work to chain your issues together like beads, making them easy for agents to follow for long distances, and reliably perform complex task streams in the right order.

While this is a very AI-first description of the project, beads can more broadly be thought of as a issue/issue tracking tool where the issues themselves sit alongside the code rather than being stored in a separate repository. For maintainers this is enormously valuable as it allows independence from tools like GitHub (thus enabling project portability), while also making the data more available/accessible to LLM-based coding patterns since all the data is resident locally rather than being trapped in technical silos.

As the beads FAQ points out, it is to issue tracking what Taskwarrior is to personal task tracking:

> Absolutely! bd is a great CLI issue tracker for humans too. The `bd ready` command is useful for anyone managing dependencies. Think of it as "Taskwarrior meets git."

Like Taskwarrior, beads is primarily a command-line tool, which, as a user interface, leaves a lot to be desired if one needs to view or manipulate issues. Thus, inspired by [taskwiki](https://github.com/tools-life/taskwiki), nvim-beads is intended to provide a more easy-to-use and convenient interface that integrates right into the Neovim experience.

# High-level Requirements

## MVP Scope

The initial MVP of `nvim-beads` will support the following base features:

### View list of issues

The ability to view a list of issues stored in beads via an integration with `vim-telescope`.

* The list is presented via an integration with vim-telescope, thereby providing
  * A list of issues on the left
  * A preview of the issue on the right that matches the contents of the edit buffer that would be displayed if the issue is opened (see below)
* The list will include the following fields from the issue:
  * ID
  * Title
* In the MVP, the telescope integration will allow the user to enter a search string to filter by issue title

### View/edit an existing issue

Selecting an issue in `vim-telescope` by pressing the <enter> key while selecting a issue opens the issue for editing in a special buffer:

* This will work similar to vim-fugitive in that the buffer name will have a custom URL (e.g. `nvim-beads://issue/[id]` or similar)
* The buffer will contain markdown with YAML frontmatter
* The YAML frontmatter will include:
  * Title
  * Type (epic, feature, task, bug, chore)
  * Status
  * Priority
  * Created at (read only)
  * Updated at (read only)
  * Closed at (read only)
  * Parent issue ID (if applicable)
  * Dependencies (an array of IDs of issues this issue depends on)
  * Labels (an array of strings)
* The Markdown section will contain top-level headers for each of the major content sections:
    * Description
    * Acceptance Criteria
    * Design
    * Notes
* The buffer will have its filetype set to `markdown` for easy editing
* Upon saving the buffer, the plugin will compare the contents of the buffer to the current contents of the issue and apply any necessary changes using the `bd edit` command.
* A new command `BeadsOpenIssue` will also be exported by the plugin. The function will take a single issue ID as an argument and open the view/edit buffer as described above.

### Creating an issue

A new command `BeadsCreateIssue` will be exported by the plugin. The function will take the issue type as an argument and will open a new buffer with a custom URL (e.g. `nvim-beads://issue/create` or similar), with the buffer contents initialized based on the template provided by `bd show template --json [issue type]`

* The YAML frontmatter will include:
  * Title
  * Type (epic, feature, task, bug, chore)
  * Status
  * Priority
  * Parent issue ID (if applicable)
  * Dependencies (an array of IDs of issues this issue depends on)
  * Labels (an array of strings)
* And the markdown will contain the standard sections as top-level headers:
    * Description
    * Acceptance Criteria
    * Design
    * Notes
* Upon saving the buffer, a new issue will be created and the issue ID displayed as a message.
  * If notes are populated, they will be appended to the issue after its create using `bd edit`
  * If the status is set to something other than 'open', the issue will be modified after creation to set the status using `bd close` or equivalent as needed
  * The buffer will then be refreshed to point to `nvim-beads://issue/[id]` so it contains the newly created issue with the current issue contents in the buffer as per the edit workflow described in the previous section

## Phase 2 Scope

There's a lot of features in beads and we can't support them all immediately, so some features that will come later include:

* Support for custom template sections
* Support for viewing, adding, or editing comments
* Support for other metadata like
  * Estimation
  * External references
* Support for additional filtering options within the telescope issue list (e.g. open/closed issues only)
* The ability to generate search rules or reports as text/buffers
