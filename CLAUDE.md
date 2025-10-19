# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# Anadea Blog - Hugo Site

## Overview

Corporate blog built with Hugo static site generator, using DecapCMS for content management, deployed on Netlify. Features automated image optimization via GitHub Actions and custom Anadea theme.

## Common Commands

**Development:**
- `npm run dev` - Start Hugo server (port 1313) + DecapCMS backend (port 8081)
- `docker compose up` - Start via Docker (after `docker compose build`)
- `hugo server --bind 0.0.0.0 -v --gc --minify` - Hugo server with optimizations

**Build:**
- `hugo --gc --minify` - Production build
- `npm run stylelint` - Fix SCSS linting issues

**Monitoring:**
- `./tools/image-stats.sh` - Generate image statistics report (CSV format)

**Quality:**
- Pre-commit hooks run automatically via Husky (Prettier, ESLint, Stylelint, ls-lint)

## Quick Start

### Development (Docker)
```bash
docker compose build
docker compose up
```
Access at http://localhost:1313/blog/

### Development (No Docker)
```bash
npm install          # Install dependencies
npm run dev          # Start Hugo + DecapCMS local server
```

**Requirements:**
- Hugo v0.123.8+ (extended version)
- Dart Sass v1.72.0+
- Node.js 20.x
- Go 1.22+

## Architecture

### Directory Structure
```
blog-anadea-gohugo/
├── config/_default/        # Hugo configuration (split into multiple files)
│   ├── hugo.yml           # Base config (baseURL, timeout, publishDir)
│   ├── params.yml         # Custom params (deviceSizes, taxonomies)
│   ├── imaging.yml        # Image processing settings (quality: 75, Lanczos filter)
│   ├── module.yml         # Theme imports (min Hugo v0.123.8)
│   ├── markup.yml         # Markdown rendering config
│   ├── permalinks.yml     # URL structure
│   └── related.yml        # Related content settings
├── content/
│   ├── posts/             # Blog posts (334+ posts, each in own folder)
│   │   └── {slug}/
│   │       ├── index.md   # Post content with frontmatter
│   │       └── *.{jpg,png} # Post images (co-located)
│   ├── authors/           # Author taxonomy pages
│   ├── categories/        # Category taxonomy pages
│   └── industries/        # Industry taxonomy pages
├── themes/anadea/         # Custom theme (imported via module.yml)
│   ├── layouts/           # Template files
│   │   ├── _default/      # Base templates (single, list, baseof)
│   │   ├── partials/      # Reusable components
│   │   └── shortcodes/    # Custom shortcodes
│   ├── assets/            # SCSS, JS (processed by Hugo Pipes)
│   └── static/            # Static assets
├── layouts/               # Layout overrides for theme
│   ├── _default/
│   ├── partials/
│   └── shortcodes/
├── data/                  # Structured data (JSON files)
│   ├── authors/           # Author profiles
│   ├── categories/        # Category definitions
│   ├── industries/        # Industry definitions
│   └── sales/             # Sales team info
├── static/
│   ├── admin/             # DecapCMS admin interface
│   │   ├── config.yml     # CMS configuration
│   │   ├── decap-cms.js   # CMS bundle
│   │   └── custom-snippets.js
│   ├── img/               # Global images
│   └── fonts/             # Web fonts
├── .github/workflows/
│   └── optimize-images.yml # Automated image resize (libvips)
├── tools/
│   └── image-stats.sh     # Image statistics monitoring
├── _docs_/
│   ├── IMAGE-OPTIMIZATION-RESEARCH.md # Full technical analysis
│   └── GITHUB-SETUP.md    # Workflow setup guide
├── netlify.toml           # Netlify build & deploy config
├── netlify-build-decision.sh # Netlify build filtering script
├── Dockerfile             # Dev environment (Hugo + Dart Sass + Node)
└── package.json           # npm scripts & linting tools
```

### Hugo Configuration

**Version:** Hugo v0.130.0 (production), v0.123.8+ (local dev)

**Key Settings:**
- `baseURL`: https://anadea.info/blog
- `publishDir`: public/blog (subdirectory deployment)
- `timeout`: 10m (long timeout for image processing)
- `paginate`: 12 posts per page

**Image Processing:**
- Quality: 75%
- Resample Filter: Lanczos (high quality)
- Background: #ffffff
- Hint: photo (optimize for photographs)
- Device Sizes: [640, 828, 1280, 1920]px (mobile-first responsive)

### Custom Theme: Anadea

Theme imported as Hugo module (not Git submodule). Located in `themes/anadea/`.

**Theme Overrides:** Root `/layouts/` directory can override any theme template.

**Asset Pipeline:**
- SCSS compiled via Dart Sass (embedded protocol)
- JS bundled via Hugo Pipes
- Source: `themes/anadea/assets/`
- Output: Auto-generated during build

## Content Management

### DecapCMS (Netlify CMS)

**Admin Access:** https://anadea.info/blog/admin/

**Configuration:** `/static/admin/config.yml`

**Content Workflow:**
1. Editorial Workflow enabled (draft → review → publish)
2. Git Gateway backend (GitHub authentication)
3. Branch: `main` (content branch)
4. Squash merges enabled
5. Media folder: `content/posts/{{slug}}/` (co-located with posts)

**Collections:**
- **Posts**: `/content/posts/{slug}/index.md`
  - Media stored alongside post
  - Frontmatter: title, ceoTitle, publishDate, image, description, authors, categories, industries, draft, top, promote
- **Authors**: `/data/authors/{slug}.json`
- **Categories**: `/data/categories/{slug}.json`
- **Industries**: `/data/industries/{slug}.json`
- **Sales**: `/data/sales/{slug}.json`
- **Site Settings**: `/config/_default/params.yml` (indexing flag)

**Local Development:**
```bash
npm run dev  # Starts DecapCMS local backend on port 8081
```
Access local CMS at http://localhost:1313/blog/admin/

### Publishing Flow

1. Author creates/edits content in DecapCMS admin
2. Content saved as PR in GitHub (editorial workflow)
3. Author moves to "Ready" status (adds `decap-cms/pending_publish` label)
4. Author clicks "Publish" in DecapCMS
5. CMS merges PR to `main` branch (with unoptimized images)
6. **GitHub Actions triggered** (optimize-images.yml)
7. Images resized to 1920x1920px max (if larger)
8. Optimized images committed back to `main` by github-actions[bot]
9. **Netlify build decision:** First commit (unoptimized) → SKIPPED
10. **Netlify build decision:** Second commit (optimized) → DEPLOYED
11. Site deployed to production with optimized images

## Image Optimization

### Automated Resize Workflow

**File:** `.github/workflows/optimize-images.yml`

**Trigger:**
- Push to `main` branch with image changes in:
  - `content/posts/**/*.{jpg,jpeg,png}`
  - `static/img/**/*.{jpg,jpeg,png}`
- Manual trigger via workflow_dispatch
- Skips if commit is from github-actions[bot] (prevents infinite loop)

**Process:**
1. Install libvips-tools (4-8x faster than ImageMagick)
2. Find all images in content/posts and static/img
3. Check dimensions using `vips im_header_int`
4. Resize if width OR height > 1920px
5. Command: `vipsthumbnail "$img" --size 1920x1920\> -o "%s"`
   - Preserves aspect ratio
   - Shrink only (no upscaling)
   - In-place replacement
6. **ALWAYS create commit:**
   - If resized → commit with optimized images
   - If no resize needed → empty commit (ensures Netlify deploys)
7. Push to `main`

### Netlify Build Filtering

**File:** `netlify-build-decision.sh`

**Purpose:** Ensure Netlify deploys only optimized images

**Logic:**
- If author = github-actions → **DEPLOY** (images processed or already optimal)
- If commit has images + author ≠ github-actions → **SKIP BUILD** (wait for optimization)
- If commit has NO images → **DEPLOY** (developer fixes)

**Important:** GitHub Actions always creates a commit to trigger Netlify deploy, preventing content from getting stuck when images are already optimal.

**Configuration:** `netlify.toml` includes `ignore = "bash netlify-build-decision.sh"`

**Expected Results:**
- 60-65% reduction in repository size (1.13 GB → 400-500 MB)
- Faster Hugo builds (30-40% improvement)
- Reduced Netlify build timeouts
- Better web performance (especially mobile)
- Netlify ALWAYS deploys optimized images

**Details:** See `./_docs_/IMAGE-OPTIMIZATION-RESEARCH.md` for full analysis and technical rationale

### Responsive Images

Hugo generates multiple WebP variants from source images:
- 640w: Mobile phones (20-50 KB)
- 828w: Large phones/tablets (30-70 KB)
- 1280w: Tablets/laptops (60-130 KB)
- 1920w: Desktop Full HD (100-250 KB)

Source images should be max 1920x1920px (enforced by GitHub Actions).

### Monitoring

**Script:** `./tools/image-stats.sh`

Generates CSV report with:
- Image dimensions and file sizes
- Distribution analysis
- Top largest files
- Total statistics

Run quarterly to monitor image health.

## Build & Deployment

### Netlify Configuration

**File:** `netlify.toml`

**Build Decision Logic:**
```toml
[build]
  ignore = "bash netlify-build-decision.sh"
```
This script ensures Netlify skips builds for unoptimized images and deploys only after GitHub Actions optimizes them.

**Production Build:**
```bash
# Install Dart Sass
curl -LJO https://github.com/sass/dart-sass/releases/download/${DART_SASS_VERSION}/dart-sass-${DART_SASS_VERSION}-linux-x64.tar.gz
tar -xf dart-sass-${DART_SASS_VERSION}-linux-x64.tar.gz
export PATH=/opt/build/repo/dart-sass:$PATH

# Build site
hugo --gc --minify

# Copy redirects
cp _redirects public/_redirects
```

**Environment Variables:**
- `HUGO_VERSION`: 0.130.0
- `DART_SASS_VERSION`: 1.77.8
- `HUGO_RESOURCEDIR`: /opt/build/cache/hugo_cache (caching processed images)
- `HUGO_ENV`: production (in production context)
- `HUGO_ENABLEGITINFO`: true (enables Git metadata)

**Deploy Previews:**
- Uses `--buildFuture` flag
- Dynamic base URL: `$DEPLOY_PRIME_URL`

**Plugin:** netlify-plugin-hugo-cache-resources (cache Hugo resources between builds)

### Docker Environment

**Image:** golang:1.22.5-bookworm

**Includes:**
- Hugo v0.130.0 (extended)
- Dart Sass v1.77.8
- Node.js 20.x
- npm dependencies

**Ports:**
- 1313: Hugo server
- 8081: DecapCMS local backend

## Development Workflow

### Code Quality

**Pre-commit Hooks (Husky):**
- Prettier (JS, CSS, SCSS formatting)
- ESLint (JS linting)
- Stylelint (SCSS linting)
- ls-lint (file/directory naming conventions)

**Configuration:**
- `.prettierrc`: Code formatting rules
- `.eslintrc`: JavaScript linting
- `.stylelintrc.json`: SCSS linting (Codeguide, RECESS order)
- `.ls-lint.yml`: File naming conventions
- `.lintstagedrc.json`: Staged files only

**Linting Commands:**
```bash
npm run stylelint  # Fix SCSS issues
```

### Git Workflow

**Main Branch:** `dev` (default development branch)
**Content Branch:** `main` (DecapCMS publishes here)

**Important:** When creating PRs, base them on `dev`, not `main`.

### File Naming

VSCode workspace settings excluded from Git (except `.vscode/settings.json`, tasks, launch config).

`.DS_Store` files ignored globally.

## Key Technical Details

### Performance Optimizations

1. **Image Processing:**
   - libvips (fast C library, 4-8x faster than ImageMagick)
   - WebP conversion via Hugo (25-30% smaller than JPEG)
   - Lazy loading and responsive srcset
   - Netlify CDN caching

2. **Build Optimizations:**
   - Hugo resource caching (`HUGO_RESOURCEDIR`)
   - `--gc` flag (garbage collection)
   - `--minify` flag (HTML, CSS, JS minification)
   - Dart Sass (faster than libsass)

3. **Bundle Size:**
   - Hugo Pipes for asset bundling
   - Tree shaking (only import what's used)
   - Fuse.js for search (lightweight alternative)

### Search Functionality

**Library:** Fuse.js v7.0.0 (fuzzy search)

**Index:** `/index.json` (generated by Hugo)

**Template:** `themes/anadea/layouts/index.json`

### Taxonomies

Custom taxonomies defined:
- Categories (e.g., "Mobile Development", "Web Development")
- Industries (e.g., "Healthcare", "E-commerce")

Authors managed as data files (not taxonomy) with relations to posts.

### Redirects

**File:** `/_redirects` (root directory)

**Deployment:** Copied to `public/_redirects` during Netlify build

**Format:** Netlify redirect syntax
```
/old-path  /new-path  301
```

**Testing:** Use [Redirects Playground](https://redirects-playground.netlify.app/)

## Troubleshooting

### Common Issues

**Build timeout on Netlify:**
- Check image sizes (should be <500 KB each)
- Run `./tools/image-stats.sh` to identify large images
- Verify GitHub Actions workflow ran successfully
- Check `HUGO_RESOURCEDIR` cache is working

**DecapCMS not loading locally:**
- Ensure `npm run dev` started both Hugo server AND Decap server
- Check ports 1313 (Hugo) and 8081 (Decap backend) are available
- Verify `static/admin/config.yml` has `local_backend: true`

**Sass compilation errors:**
- Verify Dart Sass is installed: `sass --embedded --version`
- Check version matches: 1.72.0+ (not libsass)
- Ensure Hugo extended version is used

**Images not optimizing:**
- Verify GitHub Actions workflow completed
- Check workflow logs in `.github/workflows/` runs
- Ensure images were pushed to `main` branch (not `dev`)
- Confirm libvips-tools installed in workflow

## Important Constraints

1. **Hugo Version:** Minimum v0.123.8 (extended) required
2. **Branch Strategy:** Content pushed to `main`, development on `dev`
3. **Image Size:** Max 1920x1920px (enforced by GitHub Actions)
4. **Build Time:** 10-minute timeout configured
5. **Dart Sass:** Required for theme compilation (not libsass)
6. **Module System:** Theme imported as Hugo module (not git submodule)

## Resources

- [Hugo Documentation](https://gohugo.io/documentation/)
- [DecapCMS Documentation](https://decapcms.org/docs/)
- [Netlify Documentation](https://docs.netlify.com/)
- [libvips Documentation](https://www.libvips.org/)
- [Redirects Playground](https://redirects-playground.netlify.app/)
- [Image Optimization Research](./_docs_/IMAGE-OPTIMIZATION-RESEARCH.md) - Full analysis and technical rationale
- [GitHub Setup Guide](./_docs_/GITHUB-SETUP.md) - Workflow configuration and testing

## Docker Usage Policy

**IMPORTANT:** Always use Docker for development and command execution in this project.

- **Development:** Use `docker compose up` to start the development environment
- **Command Execution:** All Hugo, npm, and system commands must be run inside Docker containers using `docker compose exec`
- **Never run commands directly on the host machine** - this ensures environment consistency

**Examples:**
```bash
# Run Hugo commands
docker compose exec web hugo version

# Run npm commands
docker compose exec web npm run stylelint

# Access shell
docker compose exec web bash
```
