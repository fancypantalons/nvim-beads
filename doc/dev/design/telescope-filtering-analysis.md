# Feasibility Analysis: Toggleable Filters in Telescope

This document analyzes the feasibility of implementing toggleable filters within the `nvim-beads` Telescope picker, based on the project's reference documentation.

## 1. Summary

**Conclusion:** Yes, it is entirely feasible to implement toggleable filters in the Telescope list view for properties like issue status (`open`, `ready`, `blocked`), priority, or type.

The architecture of Telescope is highly extensible, and the data format provided by the `bd` CLI tool is ideally suited for this kind of dynamic, client-side filtering.

## 2. Detailed Analysis

### 2.1. Data Source and In-Memory Filtering

The key to this functionality lies in how data is sourced and handled by Telescope.

-   **Data Source**: The `doc/dev/reference/list-command-schema.json` schema shows that the `bd list --json` command outputs a complete JSON array of all issues. Each issue object in this array contains filterable fields, including `status`, `priority`, and `issue_type`.

-   **Telescope Finder**: As recommended in `doc/dev/reference/telescope-finders-reference.md` for complete JSON outputs, the plugin would use `finders.new_table`. This finder type loads the entire dataset into memory at once.

This in-memory availability of all issues is what makes it possible to apply filters dynamically within Lua without needing to re-run the external `bd list` command for every change.

### 2.2. Proposed Implementation Strategy

The feature can be implemented by leveraging Telescope's standard customization patterns, as described in `doc/dev/reference/telescope.txt`.

1.  **Custom Actions**: The core logic will be encapsulated in custom [Telescope actions](https://github.com/nvim-telescope/telescope.nvim/blob/master/doc/telescope.txt#L1439). Separate Lua functions will be created to manage the filter state. For example, a `toggle_status_filter('open')` action would be created.

2.  **State Management**: A Lua table can be used within the Telescope picker's scope to keep track of the currently active filters (e.g., `{ status = 'open', priority = 1 }`).

3.  **Key Mappings**: The custom actions will be bound to key presses (e.g., `<C-o>`, `<C-b>`) inside the picker. This is achieved using the `attach_mappings` function, which is the highest-priority method for adding picker-specific mappings.

### 2.3. Methods for Refreshing the Picker View

When a filter is toggled, the list of results in the picker needs to be updated. There are several potential ways to implement this refresh logic:

#### Method A: Custom Entry Maker (Recommended)

A custom `entry_maker` function can be written that closes over the `active_filters` state table. For each issue processed from the original in-memory list, this function would:
1.  Check if the issue matches the active filters.
2.  If it matches, create and return the display entry table.
3.  If it does not match, return `nil`.

Telescope will then ignore the `nil` results, effectively hiding them. The `new_async_job` example in `telescope-finders-reference.md` establishes a precedent for `entry_maker` returning `nil` to skip items. The custom action would simply update the filter state and trigger a refresh of the picker, causing the `entry_maker` to be re-evaluated for all original items.

#### Method B: Replacing the Finder

The custom action could take a more direct approach:
1.  Apply the active filters to the original list of issues to create a new, smaller list.
2.  Create an entirely new `finders.new_table` instance with this filtered list.
3.  Replace the picker's current finder with the new one and restart the find process.

This is a robust but potentially heavier approach.

#### Method C: Custom Sorter

A custom sorter could be implemented. Sorters are responsible for scoring each entry. The custom sorter would check an entry against the active filters. If it doesn't match, the sorter would return a score of `-1` or `nil`, causing Telescope to sort it out of the visible results.

## 3. Conclusion

The Telescope framework is explicitly designed to support the level of dynamic customization required for this feature. The combination of in-memory data from `finders.new_table` and the power of custom actions and mappings makes implementing toggleable filters a standard and achievable task.

## 4. Relevant Documentation

-   `doc/dev/reference/list-command-schema.json`
-   `doc/dev/reference/telescope-finders-reference.md`
-   `doc/dev/reference/telescope.txt`
-   `doc/dev/reference/neovim-lua-plugin-reference.md`
