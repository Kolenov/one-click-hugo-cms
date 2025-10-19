#!/bin/bash

# Netlify build decision script
# Returns exit 0 to SKIP build, exit 1 to CONTINUE build
#
# Logic:
# 1. If commit has image changes AND author is NOT github-actions → SKIP (wait for optimization)
# 2. If commit author IS github-actions → CONTINUE (deploy - images processed or already optimal)
# 3. If commit has NO image changes → CONTINUE (developer fixes, no optimization needed)

set -e

# Get commit author
AUTHOR=$(git log -1 --pretty=%an)

# Check if author is github-actions (always deploy these commits)
if echo "$AUTHOR" | grep -q "github-actions"; then
  echo "✅ Author is github-actions[bot]"
  echo "→ CONTINUE BUILD (images are processed)"
  exit 1  # Continue build
fi

# Check if commit contains image changes
if git diff-tree --no-commit-id --name-only -r HEAD | grep -qE 'content/posts/.*\.(jpg|jpeg|png)$|static/img/.*\.(jpg|jpeg|png)$'; then
  echo "📷 Commit contains image changes"
  echo "⏳ Author is '$AUTHOR' (not github-actions)"
  echo "→ SKIP BUILD (waiting for image optimization)"
  exit 0  # Skip build - wait for GitHub Actions to optimize
else
  echo "📝 Commit has no image changes"
  echo "✅ Author is '$AUTHOR'"
  echo "→ CONTINUE BUILD"
  exit 1  # Continue build
fi
