# Repository Guidelines

## Project Structure & Module Organization

This repository packages PassWall for OpenWrt/LuCI. The package definition and
version live in `luci-app-passwall/Makefile`. LuCI controllers, models, and
templates are under `luci-app-passwall/luasrc/`; browser assets are in
`luci-app-passwall/htdocs/`. Runtime shell scripts and default configuration
files are installed from `luci-app-passwall/root/`. Translations belong in
`luci-app-passwall/po/`. GitHub SDK builds and releases are defined in
`.github/workflows/Auto compile with openwrt sdk.yml`.

## Build, Test, and Development Commands

There is no standalone local application runner or automated test suite. Use an
OpenWrt SDK checkout with this repository installed as a feed, then run:

```sh
make package/luci-app-passwall/{clean,compile} -j$(nproc) V=s
```

This is the same package build used by CI. For shell changes, run syntax checks
before building, for example:

```sh
sh -n luci-app-passwall/root/usr/share/passwall/app.sh
git diff --check
```

Use `gh workflow run "Auto compile with openwrt sdk.yml" --ref main` only when a
remote build/release is intended.

## Coding Style & Naming Conventions

Preserve the surrounding style and make the smallest focused change. Shell and
Lua use tabs for indentation. Quote shell paths and values unless deliberate
word splitting is required; validate with BusyBox/POSIX `sh` compatibility in
mind. Keep LuCI template JavaScript dependency-free and render log or user data
with `textContent`, not `innerHTML`. Use lower-case, underscore-separated shell
variables and functions such as `trim_core_log`.

## Testing Guidelines

Test the affected runtime path on an OpenWrt device or SDK build. For changes to
core startup, verify Sing-Box and Xray configuration validation, monitor-driven
restart, and log output. For LuCI changes, check both desktop and narrow-screen
layouts, polling, and clear actions. Add focused regression coverage when the
project gains a test harness; do not claim unrun device tests as passed.

## Commit & Pull Request Guidelines

Follow the existing Conventional Commit style: `fix: recover stale log rotation
locks`, `feat: add core log viewer`, or `ci: resolve latest snapshot SDK dynamically`.
Keep each commit limited to one behavior change. Describe the user impact,
validation commands, OpenWrt versions tested, and screenshots for LuCI UI changes.
Do not mix release/version bumps with unrelated functional changes.
