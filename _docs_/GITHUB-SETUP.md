# GitHub Configuration for Image Optimization Workflow

This document describes how the image optimization workflow integrates with DecapCMS and Netlify.

## Overview

The workflow uses **Netlify build filtering** to ensure images are optimized **before** deployment:
1. Content manager clicks "Publish" in DecapCMS
2. DecapCMS merges PR to `main` with unoptimized images
3. GitHub Actions runs and optimizes images
4. GitHub Actions commits optimized images back to `main`
5. **Netlify skips the first deploy** (unoptimized) and deploys only the second commit (optimized)

---

## How It Works: Netlify Build Decision Logic

### The Problem
When DecapCMS publishes content, two commits happen in quick succession:
1. **DecapCMS commit**: Contains unoptimized images
2. **github-actions commit**: Contains optimized images (30-60 seconds later)

Without filtering, Netlify would deploy twice - first with large images, then with optimized ones.

### The Solution: `netlify-build-decision.sh`

This script runs before every Netlify build and decides whether to continue or skip:

```bash
# Logic:
# 1. Commit has images + author ≠ github-actions → SKIP (wait for optimization)
# 2. Commit has images + author = github-actions → DEPLOY (optimized!)
# 3. Commit has NO images → DEPLOY (developer fixes)
```

**Configuration in `netlify.toml`:**
```toml
[build]
  ignore = "bash netlify-build-decision.sh"
```

---

## No GitHub Configuration Required

Unlike the previous approach with Branch Protection Rules, this workflow requires **NO special GitHub settings**.

The workflow is fully automated and requires no manual intervention.

---

## Workflow Timeline

### DecapCMS Publish Flow

```
Content Manager clicks "Publish" in DecapCMS
  ↓
DecapCMS merges PR to main (commit by content manager)
  ↓ (immediately)
GitHub Actions: "Optimize Images" workflow starts
  ↓
Netlify: netlify-build-decision.sh runs
  → Detects: commit has images + author ≠ github-actions
  → Decision: SKIP BUILD ⏭️
  ↓ (30-60 seconds)
GitHub Actions: Optimizes images, commits to main (commit by github-actions[bot])
  ↓ (immediately)
Netlify: netlify-build-decision.sh runs
  → Detects: commit has images + author = github-actions
  → Decision: CONTINUE BUILD ✅
  ↓
Netlify deploys site with optimized images 🚀
```

### Developer Direct Commit Flow

When a developer pushes fixes directly to `main`:

**Scenario A: Commit with NO images**
```
Developer pushes to main (code fixes, config changes, etc.)
  ↓
Netlify: netlify-build-decision.sh runs
  → Detects: commit has NO images
  → Decision: CONTINUE BUILD ✅
  ↓
Netlify deploys immediately 🚀
```

**Scenario B: Commit with images**
```
Developer pushes to main (with new images)
  ↓
GitHub Actions: "Optimize Images" workflow starts
  ↓
Netlify: netlify-build-decision.sh runs
  → Detects: commit has images + author ≠ github-actions
  → Decision: SKIP BUILD ⏭️
  ↓ (30-60 seconds)
GitHub Actions: Optimizes images, commits to main
  ↓
Netlify: netlify-build-decision.sh runs
  → Decision: CONTINUE BUILD ✅
  ↓
Netlify deploys with optimized images 🚀
```

---

## Testing the Workflow

### Test with DecapCMS:

1. In DecapCMS, create a test post with an image larger than 1920px
2. Click **"Publish"**
3. Go to GitHub → Actions → "Optimize Images" should be running
4. Go to Netlify → Deploys → you should see:
   - First build: **Skipped** (reason: waiting for optimization)
   - Second build: **Building** or **Published** (after ~1 minute)

### Expected timeline:
- **0:00** - DecapCMS "Publish" clicked → PR merged to `main`
- **0:05** - GitHub Actions "Optimize Images" starts
- **0:05** - Netlify build #1 triggered → **SKIPPED** by decision script
- **0:45** - GitHub Actions completes → commits optimized images to `main`
- **0:50** - Netlify build #2 triggered → **CONTINUES** → deploys

---

## Troubleshooting

### Netlify deploys unoptimized images

**Check:**
1. `netlify-build-decision.sh` exists in repo root
2. `netlify-build-decision.sh` is executable (`chmod +x`)
3. `netlify.toml` has `ignore = "bash netlify-build-decision.sh"`
4. Check Netlify build logs for decision script output

### GitHub Actions runs twice on same commit

**Check:**
1. Workflow file has condition: `!contains(github.event.head_commit.message, '🖼️ Resize images')`
2. This prevents workflow from running on its own commits

### Developer commit triggers optimization but Netlify still deploys first

**Expected behavior:** This is correct! Decision script will skip the first deploy and wait for optimized version.

---

## DecapCMS Configuration Reference

DecapCMS is configured in `static/admin/config.yml`:

```yaml
backend:
  name: git-gateway
  branch: main  # Target branch for merges
  squash_merges: true  # Squash commits when merging

publish_mode: editorial_workflow  # Enable PR-based workflow
```

With `editorial_workflow`, DecapCMS creates PRs:
- **"Save Draft"** → creates/updates PR with label `decap-cms/draft`
- **"Set to Ready"** → changes label to `decap-cms/pending_publish`
- **"Publish"** → merges PR to `main` → triggers optimization workflow

---

## Important Files

### `netlify-build-decision.sh`
Decision script that runs before each Netlify build to determine if deployment should proceed.

**Must be executable:** `chmod +x netlify-build-decision.sh`

### `netlify.toml`
Netlify configuration with build decision logic:
```toml
[build]
  ignore = "bash netlify-build-decision.sh"
```

### `.github/workflows/optimize-images.yml`
GitHub Actions workflow that:
1. Triggers on push to `main` with image changes
2. Skips if commit is its own (prevents infinite loop)
3. Optimizes images using libvips
4. Commits back to `main`

---

## Maintenance

### Quarterly checks:
- Test end-to-end flow with a test post (verify Netlify skips first build)
- Check GitHub Actions usage/limits
- Review Netlify deploy logs for decision script output

### Monitoring:
- Run `image-stats.sh` to check image sizes
- Monitor Netlify build times (should be consistent after optimization)
- Check for any failed "Optimize Images" workflows in GitHub Actions

---

## References

- [Netlify Ignore Builds Documentation](https://docs.netlify.com/build/configure-builds/ignore-builds/)
- [DecapCMS Editorial Workflow](https://decapcms.org/docs/configuration-options/#publish-mode)
- [libvips Documentation](https://www.libvips.org/)
