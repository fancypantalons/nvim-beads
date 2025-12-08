# Test Deduplication Audit: execute_with_ui

**Date:** 2025-12-07
**Issue:** nvim-beads-y08
**Files Analyzed:** `spec/nvim-beads/commands_spec.lua`, `spec/nvim-beads/init_spec.lua`

## Architecture Understanding

Two layers of `execute_with_ui`:
1. **Public API** (`lua/nvim-beads/init.lua:168-179`) - validates args, calls core
2. **Core** (`lua/nvim-beads/core.lua:186-206`) - validates args, routes to Telescope or terminal

Both layers validate inputs defensively.

## Test Categorization

### commands_spec.lua execute_with_ui tests (lines 695-948)

**Telescope routing (729-799): ~70 lines** - Unit tests
- Routes list/search/blocked/ready to show_issues ✅ KEEP
- Passes filter table correctly ✅ KEEP
- Passes bd_args with multiple arguments ✅ KEEP

**Terminal routing (801-868): ~68 lines** - Unit tests
- Routes show/create/update to terminal ✅ KEEP
- Routes unknown commands to terminal ✅ KEEP
- Handles commands with no args ✅ KEEP

**Error handling (870-909): ~40 lines** - **DUPLICATED**
- Tests empty args, nil args, not-a-table args
- Duplicates init_spec.lua validation tests
- ❌ REMOVE - public API layer should handle this

**Command/args splitting (911-944): ~34 lines** - Unit tests
- Tests command name extraction ✅ KEEP
- Tests args slicing for terminal ✅ KEEP
- Tests args preservation for telescope ✅ KEEP

### init_spec.lua execute_with_ui tests (lines 359-445)

**Pass-through tests (360-395): ~36 lines** - Integration tests
- Line 360-372: Verifies core called with args ✅ KEEP
- Line 374-384: Verifies empty opts passed ❌ REMOVE (redundant with 360-372)
- Line 386-395: Verifies opts passed through ✅ KEEP

**Error handling (397-416): ~20 lines** - Integration tests
- Tests nil/non-table/empty args at public API
- ✅ KEEP but SIMPLIFY using assertion helpers (~12 line savings)

**Routing verification (418-444): ~27 lines** - **DUPLICATED**
- Line 418-430: Tests 'list' command works
- Line 432-444: Tests 'show' command works
- Both verify same behavior as lines 360-372
- "Whitelisted" distinction is core concern, not API concern
- ❌ REMOVE both tests

## Duplication Analysis

| Category | commands_spec | init_spec | Decision |
|----------|---------------|-----------|----------|
| Error handling | Lines 870-909 (40 lines) | Lines 397-416 (20 lines) | Remove from commands_spec, simplify in init_spec |
| Basic pass-through | N/A | Lines 374-384 (11 lines) | Remove redundant test |
| Routing verification | Lines 729-868 (138 lines) | Lines 418-444 (27 lines) | Remove from init_spec (core concern) |

## Changes to Implement

### 1. commands_spec.lua
- **Remove lines 870-909** (error handling describe block) = **40 lines removed**

### 2. init_spec.lua
- **Simplify lines 397-416** using `assertions.assert_error_notification` = **~12 lines saved**
- **Remove lines 374-384** (redundant empty opts test) = **11 lines removed**
- **Remove lines 418-444** (redundant routing tests) = **27 lines removed**

**Total Expected Savings: ~90 lines**

## Remaining Test Coverage

### Unit Tests (commands_spec.lua)
- ✅ Telescope routing logic (6 tests)
- ✅ Terminal routing logic (5 tests)
- ✅ Command/args splitting (3 tests)
- **Removed:** Error handling (3 tests) - covered by integration tests

### Integration Tests (init_spec.lua)
- ✅ Public API validates inputs (3 tests - simplified)
- ✅ Public API passes args to core (1 test)
- ✅ Public API passes opts to core (1 test)
- **Removed:** Empty opts test (redundant)
- **Removed:** Routing verification tests (core concern)

## Rationale

**Separation of Concerns:**
- **Unit tests** verify internal routing logic and command parsing in core
- **Integration tests** verify public API validation and correct delegation to core
- **No need** to verify routing behavior at both layers - that's core's job

**Defensive Programming:**
- Public API validates inputs first (tested in init_spec)
- Core validates defensively in case called directly (not tested - trust implementation)
- One layer of explicit error testing is sufficient

**DRY Principle:**
- Testing the same error messages at both layers violates DRY
- Testing that core is called with correct args doesn't need routing verification
