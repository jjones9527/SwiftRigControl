# v1.1.0 Branch Update Instructions
**Date:** 2025-11-21

## What Was Done

The v1.0.1 fixes have been successfully merged into the v1.1.0 code and pushed to GitHub.

## Branch Locations

| Branch | Status | Contents |
|--------|--------|----------|
| `claude/swiftrigcontrol-v1-1-0-01TX3DJymw35RzAuSjaM9yUV` | Original v1.1.0 | Features only (pre-fixes) |
| `claude/v1-1-0-with-fixes-01HeJWYVWCfWZ3AWQy7WnXA9` | ✅ **NEW - PUSHED** | Features + all v1.0.1 fixes |

## What's in the New Branch

The new branch `claude/v1-1-0-with-fixes-01HeJWYVWCfWZ3AWQy7WnXA9` contains:

### v1.0.1 Fixes ✅
- XPCProtocol symbol visibility (public)
- XPCServer actor isolation (Task/await)
- RigCapabilities Codable conformance (FrequencyRange struct)
- Protocol model type alias fixes

### v1.1.0 Features ✅
- S-meter signal strength reading
- Performance caching layer (RadioStateCache)
- Batch configuration API
- Multi-byte CI-V command support

### Merge Details
- **No conflicts** - clean auto-merge
- 10 files modified
- 1,827 insertions, 90 deletions
- All changes verified manually

## Commit History

```
* 3fb71f5 Merge v1.0.1 fixes into v1.1.0 branch
|\
| * e0a537a (origin/main) Merge pull request #5 (build fixes)
| * 17a30fd Fix symbol visibility
| * 99ad5f0 Fix actor isolation errors
| * e045d09 Fix Codable conformance
| * 1aacaf1 Fix self-referential type aliases
| |
* | eb89ecf Add v1.1.0 features: S-meter reading, performance caching, and batch configuration
|/
```

## How to Use This Branch

### Option 1: Use as New v1.1.0 Branch (Recommended)
This is now your official v1.1.0 development branch:

```bash
# Pull the new branch
git fetch origin
git checkout claude/v1-1-0-with-fixes-01HeJWYVWCfWZ3AWQy7WnXA9

# Build and test in Xcode
# If successful, create PR to main
```

### Option 2: Update Original Branch Manually on GitHub
Since I cannot push directly to the old branch, you can:

1. Go to GitHub
2. Create a pull request:
   - **Base:** `claude/swiftrigcontrol-v1-1-0-01TX3DJymw35RzAuSjaM9yUV`
   - **Head:** `claude/v1-1-0-with-fixes-01HeJWYVWCfWZ3AWQy7WnXA9`
3. Merge the PR (this updates the old branch with the fixes)

### Option 3: Archive Old Branch, Use New One
```bash
# Tag the old branch for history
git tag archive/v1.1.0-pre-fixes origin/claude/swiftrigcontrol-v1-1-0-01TX3DJymw35RzAuSjaM9yUV
git push origin archive/v1.1.0-pre-fixes

# Delete old branch (optional)
git push origin --delete claude/swiftrigcontrol-v1-1-0-01TX3DJymw35RzAuSjaM9yUV

# Use new branch as official v1.1.0
```

## Recommended Workflow

**For continuity and development, I recommend Option 1:**

1. **Test the new branch:**
   ```bash
   git checkout claude/v1-1-0-with-fixes-01HeJWYVWCfWZ3AWQy7WnXA9
   # Build in Xcode - should succeed
   # Test S-meter functionality
   # Test caching performance
   ```

2. **If tests pass, merge to main:**
   - Create PR: `claude/v1-1-0-with-fixes-01HeJWYVWCfWZ3AWQy7WnXA9` → `main`
   - Tag as v1.1.0 when merged

3. **Clean up old branches:**
   - Archive or delete the pre-fix v1.1.0 branch
   - Delete all the fully-merged feature branches

## Why Two v1.1.0 Branches?

- **Old branch** (`claude/swiftrigcontrol-v1-1-0-01TX3DJymw35RzAuSjaM9yUV`):
  - Created before v1.0.1 fixes
  - Has v1.1.0 features but won't build

- **New branch** (`claude/v1-1-0-with-fixes-01HeJWYVWCfWZ3AWQy7WnXA9`):
  - Has v1.1.0 features AND v1.0.1 fixes
  - Should build correctly
  - **This is the one to use going forward**

## Next Steps

1. ✅ New branch pushed to GitHub
2. ⏭️ Test build in Xcode
3. ⏭️ If successful, create PR to main
4. ⏭️ Tag as v1.1.0 when merged
5. ⏭️ Clean up old branches

## GitHub Links

- **New v1.1.0 branch (use this):** `claude/v1-1-0-with-fixes-01HeJWYVWCfWZ3AWQy7WnXA9`
- **Old v1.1.0 branch (archive):** `claude/swiftrigcontrol-v1-1-0-01TX3DJymw35RzAuSjaM9yUV`
- **Analysis branch:** `claude/analyze-branch-differences-01HeJWYVWCfWZ3AWQy7WnXA9`
