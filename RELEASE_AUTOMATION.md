# BaoBun Release Automation Guide

This document explains how the automated release and sync system works for BaoBun.

## Overview

BaoBun has a fully automated CI/CD pipeline that:

1. Syncs with upstream Bun automatically every 3 days
2. Builds BaoBun binaries for all platforms
3. Creates GitHub releases with proper naming (`baobun-*`)
4. Builds and publishes Docker images
5. Updates the canary release

## Automation Workflows

### 1. Sync Workflow (`.github/workflows/sync-upstream.yml`)

**Schedule:** Every 3 days at 2:00 AM UTC

**What it does:**

- Fetches latest changes from `oven-sh/bun`
- Attempts to merge upstream `main` into BaoBun `main`
- **Auto-resolves** README.md conflicts (keeps BaoBun version)
- If only README.md conflicts: auto-resolves, commits, and pushes
- If other files conflict: creates a PR for manual review
- **Triggers** a canary release build after successful sync

**Success flow:**

1. Check upstream for new commits
2. Attempt merge
3. Auto-resolve README conflicts if needed
4. Push to main
5. Trigger build-release workflow
6. Build Docker images

### 2. Build & Release Workflow (`.github/workflows/build-release.yml`)

**Triggers:**

- On push to `main`
- On tag push (`v*`)
- On manual dispatch
- Called by sync workflow after successful merge

**What it does:**

- Determines version (canary or semantic version)
- Builds BaoBun binaries for:
  - Linux x64 (`baobun-linux-x64.zip`)
  - Linux arm64 (`baobun-linux-arm64.zip`)
  - macOS x64 (`baobun-darwin-x64.zip`)
  - macOS arm64 (`baobun-darwin-arm64.zip`)
  - Windows x64 (`baobun-windows-x64.zip`)
- Creates GitHub release with:
  - All binary artifacts
  - Checksums
  - Installation instructions
- Creates/updates `canary` release tag

**Naming Convention:**
All binaries are named `baobun-<os>-<arch>` to distinguish from upstream Bun:

- `baobun-linux-x64.zip`
- `baobun-darwin-arm64.zip`
- `baobun-windows-x64.zip`

### 3. Docker Build Workflow (`.github/workflows/docker-build.yml`)

**Triggers:**

- On push to `main`
- On tag push
- On release publish
- On manual dispatch

**What it does:**

- Builds multi-arch Docker images (linux/amd64, linux/arm64)
- Publishes to GitHub Container Registry (ghcr.io)
- Tags:
  - `ghcr.io/fullyautonomous/baobun:latest` (main branch)
  - `ghcr.io/fullyautonomous/baobun:v1.0.0` (version tags)
  - `ghcr.io/fullyautonomous/baobun:canary` (canary builds)

## Installation Scripts

### Bash Script (`install.sh`)

Downloads and installs BaoBun from GitHub releases:

```bash
curl -fsSL https://raw.githubusercontent.com/FullyAutonomous/BaoBun/main/install.sh | bash
```

**Features:**

- Auto-detects OS and architecture
- Downloads `baobun-<os>-<arch>.zip`
- Installs to `~/.baobun/bin`
- Adds to PATH
- Verifies installation

### PowerShell Script (`install.ps1`)

Windows installation:

```powershell
irm https://raw.githubusercontent.com/FullyAutonomous/BaoBun/main/install.ps1 | iex
```

**Features:**

- Same as bash script but for Windows
- Installs to `%USERPROFILE%\.baobun\bin`

## Complete Automation Chain

```
Every 3 days:
  ↓
Sync Workflow runs
  ↓
Check upstream Bun for changes
  ↓
Attempt merge
  ↓ (success or auto-resolved README)
Push to main
  ↓
Trigger build-release workflow
  ↓
Build all platform binaries (baobun-*)
  ↓
Create GitHub release with artifacts
  ↓
Update canary tag
  ↓
Trigger docker-build workflow
  ↓
Build multi-arch Docker images
  ↓
Push to GHCR
```

## Manual Operations

### Create a Stable Release

```bash
# Tag a release
git tag v1.0.0
git push origin v1.0.0
```

The build-release workflow will automatically create a release with all binaries.

### Manual Canary Build

Go to GitHub Actions → Build and Release BaoBun → Run workflow

Inputs:

- Version: `canary` or custom
- Release type: `canary` or `stable`

### Force Sync Now

Go to GitHub Actions → Sync with upstream Bun → Run workflow

## Versioning

**Canary builds:**

- Format: `{upstream-version}-baobun-{timestamp}`
- Example: `v1.0.0-baobun-20240113120000`
- Created automatically after sync
- Always available at `canary` tag

**Stable releases:**

- Format: semantic versioning
- Example: `v1.0.0`, `v1.1.0`
- Created manually by pushing tags

## Troubleshooting

### Sync fails with conflicts

- Workflow creates a PR
- Review and resolve manually
- Merge PR to trigger release

### Build fails

- Check build-release workflow logs
- Usually due to missing dependencies
- Can retry manually from Actions tab

### Docker build fails

- Check docker-build workflow logs
- Ensure Dockerfile syntax is valid
- Can retry manually

### Install script fails

- Check that release exists with correct naming
- Verify `baobun-<os>-<arch>.zip` naming
- Test download URL manually

## Maintenance

### Update build targets

Edit `.github/workflows/build-release.yml` and add/modify matrix entries.

### Update install scripts

Edit `install.sh` or `install.ps1` - changes take effect immediately.

### Update Docker configuration

Edit `Dockerfile` or `docker-compose.yml`.

### Modify sync schedule

Edit cron expression in `.github/workflows/sync-upstream.yml`:

- `0 2 */3 * *` = Every 3 days
- `0 2 * * *` = Daily
- `0 0 * * 0` = Weekly on Sunday

## Security Notes

- Binaries are built in GitHub Actions (trusted environment)
- Checksums are generated and attached to releases
- Docker images are signed via GHCR
- Use `bun upgrade` to get latest BaoBun release
- Canary builds are marked as pre-releases
