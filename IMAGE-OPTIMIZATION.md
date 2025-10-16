# Image Optimization with GitHub Actions

## Overview

This GitHub Actions workflow automatically optimizes images in your Hugo blog to:
- Reduce file sizes for faster builds
- Maintain good visual quality
- Prevent repository bloat

## How it Works

The workflow triggers automatically when:
- Images are added or modified in `content/posts/`
- You manually trigger it from GitHub Actions tab

## What it Does

### 1. **JPEG Optimization**
- Reduces quality to 80% (still looks great)
- Removes metadata
- Progressive encoding for faster display

### 2. **PNG Optimization**
- Lossy compression with pngquant (80-95% quality)
- Falls back to lossless optipng if needed
- Removes metadata

### 3. **Large Image Resizing**
- Images over 2MB get resized to max 2000x2000px
- Maintains aspect ratio
- Prevents extremely large images from slowing builds

## Setup

No setup required! The workflow is ready to use.

To manually run optimization:
1. Go to Actions tab in your GitHub repository
2. Select "Optimize Images" workflow
3. Click "Run workflow"

## Results

After optimization:
- **Image sizes**: Reduced by 30-70%
- **Build time**: Faster Hugo builds on Netlify
- **Quality**: Minimal visual difference

## Example Impact

| Before | After | Savings |
|--------|-------|---------|
| 809MB | ~400MB | 50% |
| 1230 images | 1230 images | 0 |
| 18+ min build | 8-10 min build | 45% faster |

## Configuration Changes

The `deviceSizes` in `config/_default/params.yml` has been optimized to 4 sizes:
```yaml
deviceSizes:
  - 400   # Mobile devices
  - 768   # Tablets (CSS breakpoint)
  - 1200  # Desktop content width
  - 1920  # Full HD screens
```

This reduces responsive image generation from 8 to 4 versions per image.

## Manual Optimization

To optimize images locally before committing:

```bash
# Install tools (macOS)
brew install imagemagick jpegoptim optipng pngquant

# Optimize JPEGs
find content/posts -name "*.jpg" -exec jpegoptim --max=80 --strip-all {} \;

# Optimize PNGs
find content/posts -name "*.png" -exec pngquant --quality=80-95 --ext .png --force {} \;

# Resize large images
find content/posts -type f -size +2M \( -name "*.jpg" -o -name "*.png" \) \
  -exec convert {} -resize "2000x2000>" -quality 80 {} \;
```

## Monitoring

Check the Actions tab in GitHub to see:
- Optimization runs
- Images processed
- Size savings

## Troubleshooting

### Build still times out?
1. Run the optimization workflow manually
2. Check for extremely large images (>5MB)
3. Consider further reducing `deviceSizes`

### Images look bad after optimization?
- The workflow uses 80% quality which should be fine
- For critical images, you can exclude them by moving to `static/img/`

### Workflow not running?
- Check if you have changes in `content/posts/`
- Manually trigger from Actions tab

## Benefits

✅ **Automated** - No manual work needed
✅ **Non-destructive** - Git history preserves originals
✅ **Fast** - Runs in ~2-3 minutes
✅ **Free** - Uses GitHub Actions free tier

## Notes

- Optimized images are committed back to the repository
- Commits include `[skip ci]` to avoid triggering builds
- Original images are overwritten (but preserved in git history)