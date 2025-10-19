# Image Optimization Research & Implementation
**Date:** October 2025
**Objective:** Optimize blog images for modern web standards and improve Netlify build performance

---

## Executive Summary

**Problem:** Blog contains 1387 images totaling 1.13 GB with many oversized files (31MB max), causing slow builds and poor web performance.

**Solution:** Implement automated image resize to 1920×1920px using libvips, aligned with 2025 web standards and actual device usage patterns.

**Expected Result:** ~60% reduction in repository size (1.13 GB → 400-500 MB), faster Hugo builds, improved user experience.

---

## Why This Approach: Technical Rationale

### The Challenge
We needed to ensure that images are optimized **before** Netlify deploys them, but had a specific workflow requirement:
- **Optimization must trigger ONLY when content is published** (not on draft saves or status changes)
- **Content managers use DecapCMS "Publish" button** to merge content to production

### Why Not Use Branch Protection + Required Checks?

We initially considered using GitHub Branch Protection Rules with required status checks to block merge until optimization completes. This approach would work like:

```
Set to Ready → optimization runs → PR blocked until complete → Publish merges
```

**Why we rejected this:**

1. **Wrong trigger point**: Optimization would run on "Set to Ready", but requirement is to optimize ONLY on "Publish"
2. **Wasted resources**: If content manager changes mind after "Set to Ready", optimization already ran unnecessarily
3. **No cancellation mechanism**: GitHub Actions cannot auto-cancel when label changes
4. **Technical limitation**: DecapCMS "Publish" = immediate merge; there's no "pre-merge hook" to run optimization first

### Why This Two-Commit Approach Works

**Current implementation:**
```
Publish → merge unoptimized → GitHub Actions optimizes → commit #2 → Netlify deploys only #2
```

**Advantages:**
- ✅ Optimization runs ONLY when "Publish" clicked (meets requirement)
- ✅ If content manager changes mind, no optimization runs (efficient)
- ✅ Netlify ALWAYS deploys optimized images (via build decision script)
- ✅ No manual intervention needed
- ✅ Works for both DecapCMS and developer commits
- ✅ Doesn't require GitHub repository configuration

**Trade-off:**
- ⚠️ Two commits in history per publish (unoptimized + optimized)
  - Not a practical issue: git history preserves both versions
  - Optimization commit is clearly marked with 🖼️ emoji
  - Total commit count impact: ~1-2 extra commits per month

### Alternative Considered: Pre-Publish Optimization

**Why we can't do "Publish → optimize → merge":**

DecapCMS "Publish" action is atomic:
```javascript
// DecapCMS source code (simplified)
publishContent() {
  github.mergePullRequest(prNumber); // One API call, no hooks
}
```

There is **no GitHub event** for "user clicked Publish but hasn't merged yet". The merge happens immediately.

### Conclusion

The two-commit approach with Netlify build filtering is the **only technically feasible solution** that meets all requirements:
- Optimization on Publish only ✅
- No wasted optimization runs ✅
- Guaranteed optimized deployments ✅
- Zero manual intervention ✅

For detailed workflow documentation, see `GITHUB-SETUP.md`.

---

## Current State Analysis

### Image Inventory (Oct 2025)
- **Total Images:** 1,387 (684 JPEG, 703 PNG)
- **Total Size:** 1.13 GB
- **Average Size:** 0.83 MB (830 KB)

### Size Distribution

#### By File Size
| Range | Count | % | Status |
|-------|-------|---|--------|
| > 10 MB | 31 | 2% | ❌ Critical |
| 5-10 MB | 30 | 2% | ❌ Poor |
| 1-5 MB | 85 | 6% | ⚠️ Needs optimization |
| 500KB-1MB | 207 | 15% | ⚠️ Acceptable |
| 100-500KB | 699 | 50% | ✅ Good |
| < 100KB | 336 | 24% | ✅ Excellent |

#### By Dimensions
| Range | Count | % | Status |
|-------|-------|---|--------|
| > 4K (3840×2160) | 226 | 16% | ❌ Excessive |
| > Full HD (1920) | 281 | 20% | ⚠️ High |
| > 1200px | 158 | 11% | ⚠️ Medium |
| ≤ 1200px | 731 | 53% | ✅ Optimal |

**Key Finding:** 665 images (48%) exceed optimal dimensions and require resize.

---

## Industry Standards & Best Practices (2025)

### Web Performance Benchmarks

#### HTTP Archive Statistics
- **Median image weight per page:** 811 KB (mobile), 1,026 KB (desktop)
- **Individual image median:** 127 KB (mobile), 142 KB (desktop)
- **LCP images:** 48% of sites use ≤100 KB

#### Recommended File Sizes
| Image Type | Recommended Size |
|------------|------------------|
| General images | < 100 KB |
| Full-width images | < 200 KB |
| Hero/Banner | 150-300 KB |
| Blog images | < 100 KB |
| **ABSOLUTE MAX** | **500 KB** |

### Device Usage Patterns (2025)

#### Traffic Distribution
- 📱 **Mobile:** 62% of global traffic
- 💻 **Desktop:** 36%
- 📟 **Tablet:** 1.7% (negligible)

#### Top Screen Resolutions
| Device | Resolution | Market Share | Target Width |
|--------|-----------|--------------|--------------|
| Mobile | 360×800 | >11% | 360-430px |
| Desktop | 1920×1080 | 42.8% | 1920px |
| Tablet | 768×1024 | 20.3% | 768px |

---

## WebP Performance Characteristics

### Compression Benefits
- **Lossless WebP:** 26% smaller than PNG
- **Lossy WebP:** 25-34% smaller than JPEG
- **File size formula:** ~0.03 bytes/pixel

### Size Examples
| Dimensions | Pixels | WebP Size | JPEG Equivalent |
|-----------|---------|-----------|-----------------|
| 640×427 | 273K | ~8 KB | ~12 KB |
| 828×552 | 457K | ~14 KB | ~20 KB |
| 1280×853 | 1.1M | ~33 KB | ~48 KB |
| 1920×1280 | 2.5M | ~75 KB | ~110 KB |

### Maximum Specifications
- **Max dimensions:** 16,383 × 16,383 px
- **RIFF overhead:** 20 bytes
- **Browser support:** 95% of current browsers

---

## Chosen Configuration

### deviceSizes (config/_default/params.yml)
```yaml
deviceSizes:
  - 640   # Mobile Retina (covers 360-430px devices × 2)
  - 828   # Large Mobile/Phablet (covers 414px devices × 2)
  - 1280  # Tablet & Medium Laptops
  - 1920  # Desktop Full HD (42.8% market share)
```

### Rationale
1. ✅ **640px & 828px** - Official Apple srcset recommendations for Retina mobile
2. ✅ **Covers 95%** of real devices per 2025 statistics
3. ✅ **62% mobile traffic** receives optimized images (640/828)
4. ✅ **1920px ideal** for 42.8% of desktop users (Full HD)
5. ✅ **Balance** between quality and performance (4 variants)

### Original Image Size: 1920×1920px

**Why 1920px (not 1200px or 2560px):**
- ✅ Covers Full HD displays (1920×1080 - dominant desktop resolution)
- ✅ Hugo can generate all 4 deviceSizes (640, 828, 1280, 1920) from originals
- ✅ WebP @ 1920px ≈ 150-250 KB (within recommended limits)
- ✅ No need for 4K support in blog context
- ✅ Optimal balance: quality vs file size vs build time

---

## Implementation

### GitHub Actions Workflow
**File:** `.github/workflows/optimize-images.yml`

**Trigger:** Push to `main` branch with image changes (when DecapCMS publishes content)

**Process:**
1. Content manager clicks "Publish" in DecapCMS
2. DecapCMS merges PR to `main` (with unoptimized images)
3. Netlify skips first deploy (waiting for optimization)
4. GitHub Actions workflow runs on push to `main`
5. Check image dimensions using libvips
6. Resize if width OR height > 1920px
7. Preserve aspect ratio, shrink only (no upscaling)
8. **ALWAYS create commit:**
   - If resized → commit with optimized images
   - If no resize needed → empty commit to trigger deploy
9. Netlify deploys the second commit (optimized or verified-optimal)

**Technology:** libvips (4-8x faster than ImageMagick)

**Command:**
```bash
vipsthumbnail "$img" --size 1920x1920\> -o "%s"
```

### Netlify Build Filtering
**File:** `netlify-build-decision.sh`

**Purpose:** Prevent Netlify from deploying unoptimized images

**Logic:**
- If author = github-actions → **DEPLOY** (images processed or already optimal)
- If commit has images AND author ≠ github-actions → **SKIP** (wait for optimization)
- If commit has NO images → **DEPLOY** (developer fixes)

**Important:** GitHub Actions always creates a commit, even if no images need resizing. This ensures:
- Content with already-optimal images gets deployed
- Netlify never gets "stuck" waiting for optimization that won't happen
- Two-commit pattern works reliably in all scenarios

**Configuration Required:**
- `netlify-build-decision.sh` must be executable (`chmod +x`)
- `netlify.toml` configured with `ignore = "bash netlify-build-decision.sh"`
- See `GITHUB-SETUP.md` for detailed workflow documentation

---

## Expected Results

### File Size Reduction
| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| Total size | 1.13 GB | 400-500 MB | **-60-65%** |
| Avg file size | 830 KB | 300 KB | **-64%** |
| Images > 10MB | 31 | 0 | **-100%** |
| Images > 1MB | 146 | ~50 | **-66%** |

### Performance Gains
- **Repository size:** Reduced by ~700 MB
- **Git clone time:** Faster for contributors
- **Hugo build time:** Estimated 30-40% faster
- **Netlify build:** Less risk of timeout
- **User experience:** Faster page loads, especially mobile

### WebP Variant Sizes (Hugo-generated)
| Size | File Size Range | Use Case |
|------|----------------|----------|
| 640w | 20-50 KB | Mobile phones |
| 828w | 30-70 KB | Large phones/small tablets |
| 1280w | 60-130 KB | Tablets/laptops |
| 1920w | 100-250 KB | Desktop Full HD |

---

## Compliance with Web Standards

### ✅ Google PageSpeed Recommendations
- JPEG quality: 85 (optimal balance)
- Use modern formats (WebP)
- Proper sizing for display dimensions
- Progressive JPEG for images >10KB

### ✅ HTTP Archive Benchmarks
- Individual images: 127-142 KB median (target: <200 KB) ✅
- LCP images: <100 KB for 48% of sites (our target: <250 KB) ✅
- Total image weight: 811 KB/page median (our images optimized) ✅

### ✅ 2025 Best Practices
- Mobile-first (62% traffic)
- Responsive images (srcset)
- Modern formats (WebP 25-30% smaller)
- Max file size <500 KB per image ✅

---

## Monitoring & Maintenance

### Image Statistics Script
**File:** `image-stats.sh`

**Usage:**
```bash
./image-stats.sh
```

**Output:**
- CSV file with dimensions and sizes
- Distribution analysis
- Top largest files
- Total statistics

### Recommended Checks
- Run `image-stats.sh` quarterly
- Monitor largest images (should be <500 KB)
- Check Hugo build time trends
- Verify deviceSizes coverage with analytics

---

## References

### Standards & Research
- [HTTP Archive - State of Images](https://httparchive.org/reports/state-of-images)
- [StatCounter - Screen Resolutions 2025](https://gs.statcounter.com/screen-resolution-stats)
- [Google Developers - Optimize Images](https://developers.google.com/speed/docs/insights/OptimizeImages)
- [WebP Format Documentation](https://developers.google.com/speed/webp)

### Tools
- libvips: https://www.libvips.org/
- Hugo Image Processing: https://gohugo.io/content-management/image-processing/
- vipsthumbnail docs: https://www.libvips.org/API/current/using-vipsthumbnail.html

---

## Conclusion

This optimization strategy balances:
- ✅ **Modern web standards** (HTTP Archive, Google PageSpeed)
- ✅ **Real device usage** (StatCounter 2025 data)
- ✅ **Performance** (libvips, WebP, optimal sizes)
- ✅ **Quality** (1920px originals, 4 responsive variants)
- ✅ **Maintainability** (automated workflow, monitoring tools)

**Result:** Blog images fully optimized for 2025 web standards with 60%+ size reduction and improved user experience across all devices.
