---@class nvim-beads.issue.diff
local M = {}

---Compare two issue states and return structured changes
---@param original table The original issue state (from bd show --json)
---@param modified table The modified issue state (from parse_markdown_to_issue)
---@return table changes Structured table of changes by field type
function M.diff_issues(original, modified)
    local changes = {}

    -- Helper function to convert array to set for efficient lookup
    local function to_set(arr)
        local set = {}
        if arr then
            for _, v in ipairs(arr) do
                set[v] = true
            end
        end
        return set
    end

    -- Helper function to compute set difference (items in a but not in b)
    local function set_difference(a, b)
        local a_set = to_set(a)
        local b_set = to_set(b)
        local diff = {}

        for item, _ in pairs(a_set) do
            if not b_set[item] then
                table.insert(diff, item)
            end
        end

        return #diff > 0 and diff or nil
    end

    -- Helper function to normalize nil and empty string
    local function normalize(value)
        if value == nil or value == "" then
            return nil
        end
        return value
    end

    -- Compare metadata fields (title, priority, assignee)
    local metadata = {}
    local has_metadata_changes = false

    if original.title ~= modified.title then
        metadata.title = modified.title
        has_metadata_changes = true
    end

    if original.priority ~= modified.priority then
        metadata.priority = modified.priority
        has_metadata_changes = true
    end

    -- Handle assignee (can be added, removed, or changed)
    local orig_assignee = normalize(original.assignee)
    local mod_assignee = normalize(modified.assignee)

    if orig_assignee ~= mod_assignee then
        -- Use empty string to indicate removal (since nil means "no change")
        if mod_assignee == nil then
            metadata.assignee = ""
        else
            metadata.assignee = mod_assignee
        end
        has_metadata_changes = true
    end

    if has_metadata_changes then
        changes.metadata = metadata
    end

    -- Compare status
    if original.status ~= modified.status then
        changes.status = modified.status
    end

    -- Compare labels (set-based comparison)
    local orig_labels = original.labels or {}
    local mod_labels = modified.labels or {}

    local labels_added = set_difference(mod_labels, orig_labels)
    local labels_removed = set_difference(orig_labels, mod_labels)

    if labels_added or labels_removed then
        changes.labels = {}
        if labels_added then
            changes.labels.add = labels_added
        end
        if labels_removed then
            changes.labels.remove = labels_removed
        end
    end

    -- Compare dependencies (set-based comparison)
    -- Extract dependency IDs from original (bd show returns objects with id, title, dependency_type)
    -- but parser returns just strings (IDs), and we only want to compare "blocks" type dependencies
    local orig_deps_raw = original.dependencies or {}
    local orig_dep_ids = {}
    for _, dep in ipairs(orig_deps_raw) do
        if type(dep) == "table" then
            -- From bd show --json: filter for "blocks" type only
            if dep.dependency_type == "blocks" then
                table.insert(orig_dep_ids, dep.id)
            end
        else
            -- From tests or other sources: already a string ID
            table.insert(orig_dep_ids, dep)
        end
    end

    local mod_deps = modified.dependencies or {}

    local deps_added = set_difference(mod_deps, orig_dep_ids)
    local deps_removed = set_difference(orig_dep_ids, mod_deps)

    if deps_added or deps_removed then
        changes.dependencies = {}
        if deps_added then
            changes.dependencies.add = deps_added
        end
        if deps_removed then
            changes.dependencies.remove = deps_removed
        end
    end

    -- Compare parent field
    local orig_parent = normalize(original.parent)
    local mod_parent = normalize(modified.parent)

    if orig_parent ~= mod_parent then
        -- Use empty string to indicate removal (since nil means "no change")
        if mod_parent == nil then
            changes.parent = ""
        else
            changes.parent = mod_parent
        end
    end

    -- Compare text sections (description, acceptance_criteria, design, notes)
    local sections = {}
    local section_fields = { "description", "acceptance_criteria", "design", "notes" }

    for _, field in ipairs(section_fields) do
        local orig_value = normalize(original[field])
        local mod_value = modified[field] -- Don't normalize modified value to detect nil -> ''

        -- Detect changes, including nil -> '' and vice versa
        if orig_value ~= mod_value then
            -- Store the modified value (could be '', which is different from nil)
            sections[field] = mod_value or ""
        end
    end

    if next(sections) then
        changes.sections = sections
    end

    return changes
end

---Generate bd CLI commands to apply changes from diff_issues
---@param issue_id string The issue ID (e.g., "bd-1")
---@param changes table The changes table from diff_issues()
---@param original_parent_id string|nil The ID of the parent before the change, if any
---@return table[] commands List of bd command tables
function M.generate_update_commands(issue_id, changes, original_parent_id)
    local commands = {}

    -- Helper to add a command
    local function add_cmd(cmd_table)
        table.insert(commands, cmd_table)
    end

    -- Process in order: parent/deps first, then labels, then status, then metadata/text

    -- 1. Handle parent changes
    if changes.parent ~= nil then
        if changes.parent == "" then
            -- Parent removed. The caller must provide the original parent ID.
            if original_parent_id then
                add_cmd({ "bd", "dep", "remove", issue_id, original_parent_id })
            end
        else
            -- Parent added or changed
            add_cmd({ "bd", "dep", "add", issue_id, changes.parent, "--type", "parent-child" })
        end
    end

    -- 2. Handle dependency changes
    if changes.dependencies then
        -- Remove dependencies first
        if changes.dependencies.remove then
            for _, dep_id in ipairs(changes.dependencies.remove) do
                add_cmd({ "bd", "dep", "remove", issue_id, dep_id })
            end
        end
        -- Then add new dependencies
        if changes.dependencies.add then
            for _, dep_id in ipairs(changes.dependencies.add) do
                add_cmd({ "bd", "dep", "add", issue_id, dep_id, "--type", "blocks" })
            end
        end
    end

    -- 3. Handle label changes
    if changes.labels then
        -- Remove labels first
        if changes.labels.remove then
            for _, label in ipairs(changes.labels.remove) do
                add_cmd({ "bd", "label", "remove", issue_id, label })
            end
        end
        -- Then add new labels
        if changes.labels.add then
            for _, label in ipairs(changes.labels.add) do
                add_cmd({ "bd", "label", "add", issue_id, label })
            end
        end
    end

    -- 4. Handle status changes
    if changes.status then
        if changes.status == "closed" then
            add_cmd({ "bd", "close", issue_id })
        elseif changes.status == "open" then
            add_cmd({ "bd", "reopen", issue_id })
        else
            -- in_progress or blocked
            add_cmd({ "bd", "update", issue_id, "--status", changes.status })
        end
    end

    -- 5. Handle metadata and text section changes
    -- We can combine these into a single bd update command with multiple flags
    local update_cmd = { "bd", "update", issue_id }
    local has_updates = false

    if changes.metadata then
        if changes.metadata.title then
            table.insert(update_cmd, "--title")
            table.insert(update_cmd, changes.metadata.title)
            has_updates = true
        end
        if changes.metadata.priority then
            table.insert(update_cmd, "--priority")
            table.insert(update_cmd, tostring(changes.metadata.priority))
            has_updates = true
        end
        if changes.metadata.assignee ~= nil then
            table.insert(update_cmd, "--assignee")
            -- Empty string means removal
            table.insert(update_cmd, changes.metadata.assignee)
            has_updates = true
        end
    end

    if changes.sections then
        if changes.sections.description ~= nil then
            table.insert(update_cmd, "--description")
            table.insert(update_cmd, changes.sections.description)
            has_updates = true
        end
        if changes.sections.acceptance_criteria ~= nil then
            table.insert(update_cmd, "--acceptance")
            table.insert(update_cmd, changes.sections.acceptance_criteria)
            has_updates = true
        end
        if changes.sections.design ~= nil then
            table.insert(update_cmd, "--design")
            table.insert(update_cmd, changes.sections.design)
            has_updates = true
        end
        if changes.sections.notes ~= nil then
            table.insert(update_cmd, "--notes")
            table.insert(update_cmd, changes.sections.notes)
            has_updates = true
        end
    end

    -- Only add the update command if there are actual updates
    if has_updates then
        add_cmd(update_cmd)
    end

    return commands
end

---Build bd create command from parsed issue data
---@param parsed_issue table The parsed issue from parse_markdown_to_issue
---@return table|nil command The bd create command table or nil if validation fails
---@return string|nil error Error message if validation fails
function M.build_create_command(parsed_issue)
    -- Validate required fields
    if not parsed_issue.title or parsed_issue.title == "" then
        return nil, "Title is required"
    end

    if not parsed_issue.issue_type or parsed_issue.issue_type == "" then
        return nil, "Issue type is required"
    end

    -- Start building the command
    local cmd = { "bd", "create" }

    -- Add title (required, positional argument)
    table.insert(cmd, parsed_issue.title)

    -- Add type (required flag)
    table.insert(cmd, "--type")
    table.insert(cmd, parsed_issue.issue_type)

    -- Add optional fields only if populated

    -- Priority
    if parsed_issue.priority then
        table.insert(cmd, "--priority")
        table.insert(cmd, tostring(parsed_issue.priority))
    end

    -- Description
    if parsed_issue.description and parsed_issue.description ~= "" then
        table.insert(cmd, "--description")
        table.insert(cmd, parsed_issue.description)
    end

    -- Acceptance criteria
    if parsed_issue.acceptance_criteria and parsed_issue.acceptance_criteria ~= "" then
        table.insert(cmd, "--acceptance")
        table.insert(cmd, parsed_issue.acceptance_criteria)
    end

    -- Design
    if parsed_issue.design and parsed_issue.design ~= "" then
        table.insert(cmd, "--design")
        table.insert(cmd, parsed_issue.design)
    end

    -- Labels (comma-separated)
    if parsed_issue.labels and #parsed_issue.labels > 0 then
        local labels_str = table.concat(parsed_issue.labels, ",")
        table.insert(cmd, "--labels")
        table.insert(cmd, labels_str)
    end

    -- Parent
    if parsed_issue.parent and parsed_issue.parent ~= "" then
        table.insert(cmd, "--parent")
        table.insert(cmd, parsed_issue.parent)
    end

    -- Dependencies (comma-separated with type prefix)
    if parsed_issue.dependencies and #parsed_issue.dependencies > 0 then
        -- Format as 'blocks:id1,blocks:id2' since these are blocking dependencies
        local deps = {}
        for _, dep_id in ipairs(parsed_issue.dependencies) do
            table.insert(deps, "blocks:" .. dep_id)
        end
        local deps_str = table.concat(deps, ",")
        table.insert(cmd, "--deps")
        table.insert(cmd, deps_str)
    end

    -- Add --json flag for programmatic output (required for parsing the result)
    table.insert(cmd, "--json")

    return cmd, nil
end

---Extract issue ID from bd create command JSON output
---@param output string The stdout from bd create --json command
---@return string|nil id The extracted issue ID or nil if extraction fails
---@return string|nil error Error message if extraction fails
function M.extract_id_from_create_output(output)
    -- Validate input
    if not output or output == "" then
        return nil, "Empty output"
    end

    -- Try to decode JSON
    local ok, result = pcall(vim.json.decode, output)
    if not ok then
        return nil, "Failed to parse JSON: " .. tostring(result)
    end

    -- Check if result is a table with id field
    if type(result) ~= "table" then
        return nil, "JSON output is not a table"
    end

    -- Handle vim.NIL (JSON null)
    local id = result.id
    if id == vim.NIL then
        id = nil
    end

    if not id or id == "" then
        return nil, "No id field in JSON output"
    end

    return id, nil
end

return M
