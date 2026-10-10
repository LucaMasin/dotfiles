# Optional Brew migration plan

Status: proposed, not implemented. No Brew installer, Brewfile, package ownership changes, or migration command ships with the `dot` interface.

## Scope and ownership

The proposed setup uses Brew for shared developer CLI tools and native package managers for system dependencies. It does not introduce a general `dot package` interface.

| Tools | Proposed owner | Decision required |
| --- | --- | --- |
| fzf, ripgrep, btop, zoxide, starship, tokei, yazi, gh, tmux | Brew | Verify formulae and bottles on x86_64 and ARM64. |
| Neovim | Brew candidate | Confirm that stable formula releases can replace source builds. |
| Node and npm | Brew candidate, separate migration | Inventory npm globals, prefixes, scripts, and service paths first. |
| Git and zsh | Native initially | Keep bootstrap and login shell independent of Brew. |
| Desktop components, systemd, Playwright system libraries, bootstrap build tools | apt or Omarchy | Preserve OS integration. |
| OpenCode, Herdr, browser-control, Bun, pnpm, Poetry, uv | Existing installers initially | Migrate only with a separate availability and dependency check. |

Final ownership is chosen once per tool, not by whichever installer happens to be available. Normal setup must not silently fall back to a second manager.

## Platform gate

Homebrew supports Linux, WSL2, x86_64, and ARM64. Architecture support does not mean every distribution or formula has the same support level.

Test Ubuntu, Omarchy, and 64-bit Raspberry Pi OS Trixie independently. Record OS version, architecture, glibc, Brew prefix, and bottle availability. Current Homebrew Tier 1 Linux requirements include qualifying Ubuntu releases and glibc 2.39 or newer. Omarchy and Raspberry Pi OS do not qualify merely by being Linux.

Use the default Linux prefix `/home/linuxbrew/.linuxbrew` initially. Do not assume installing under an arbitrary home-directory prefix has the same bottle support. Document bootstrap dependencies, permissions, disk use, and any source-build exceptions before approving each platform.

If a platform cannot pass the gate, keep its native setup and consolidate shared script logic instead. Do not silently opt it into an untested Brew path.

## Existing installations

Brew does not adopt apt, Snap, Cargo, npm, or source-built packages. Installing a formula usually adds another copy. PATH decides which executable runs; old packages retain their original owners.

Before migrating, inventory all executable paths, not just `command -v`. Include package-manager ownership, version, symlink targets, npm global prefix, login shell, and absolute paths in services and scripts. An unknown owner blocks automatic removal.

The inventory report must distinguish:

- Fresh installations with no existing copy.
- Native packages required by the OS or other packages.
- Standalone user installations safe to replace after validation.
- Unknown or customized installations requiring manual review.

Do not treat `command -v tool` as a Brew ownership check. Use Brew's installed formula state when checking Brew-managed tools.

## Proposed implementation sequence

1. Build a read-only inventory and migration preview. Store a dated report outside the repo, including executable paths, owners, versions, and proposed actions. No passwords or credentials belong in the report.
2. Verify the candidate formulae and platform gates in disposable environments. Approve a small initial tool set; defer Node and Neovim if their checks need more work.
3. Add an explicit opt-in backend, tentatively `dot init --tools brew`. Preserve existing native setup as the default. Validate prerequisites before installing anything.
4. Add a shared Brewfile for approved CLI tools. Remove those tools from native installation lists only for the opted-in backend. Keep native system dependencies and exceptional installers separate.
5. Implement a separately approved `dot migrate --dry-run` and `dot migrate`. The actual interface is not available yet. Migration installs and verifies replacements before changing command resolution; it never automatically removes old installations.
6. Introduce Brew shell initialization only for opted-in machines. Test the full PATH change because Brew dependencies can expose additional commands such as Python or Node. Capture the prior PATH configuration for rollback.
7. Add optional, separately confirmed cleanup guidance per original owner. Check reverse dependencies before apt removal, Snap ownership before Snap removal, and installed file lists before source-install cleanup. Never run broad `apt autoremove`, recursive deletion, or `brew bundle cleanup --force` as migration.
8. Add doctor ownership checks and migration documentation. Run repeated setup and interrupted-migration recovery checks before recommending the backend.

## Upgrade policy

Keep `dot update` config-only for both backends. Brew setup uses `brew bundle install --no-upgrade` for missing tools, not implicit upgrades. Formula dependency installation can still change the Brew environment and must appear in the preview.

Choose a separate explicit upgrade operation before implementation. A Brewfile is a desired package list, not a lock file for reproducible versions.

## Acceptance checks

- Fresh setup installs the chosen tool set on each approved platform.
- Existing-machine preview reports apt, Snap, Cargo, npm, source, and unknown installations accurately.
- Migration leaves old installations intact until cleanup is separately approved.
- Interactive Bash and zsh, noninteractive scripts, and service commands resolve the intended executables.
- Neovim uses the matching runtime, Node uses the intended npm prefix, and existing global packages still run.
- Desktop settings, native libraries, browser automation, and login shell behavior remain unchanged.
- Repeated and interrupted runs converge without duplicate shell initialization or lost inventory.
- Dry-runs change no files, packages, PATH configuration, or services.

## Rollback

Before cleanup, restore the prior PATH configuration and verify that the original executables run. Keep the original tools until this rollback is proven. Remove only the migration's own managed shell block or setting.

After cleanup, rollback requires reinstalling through the original manager; the captured inventory is not a guarantee that older versions remain available. Warn about this before cleanup.

## Sources

Checked when drafting this plan:

- [Homebrew on Linux](https://docs.brew.sh/Homebrew-on-Linux)
- [Support tiers](https://docs.brew.sh/Support-Tiers#linux)
- [Brew Bundle behavior and no-upgrade option](https://docs.brew.sh/Brew-Bundle-and-Brewfile)

Recheck requirements and formula availability when implementation is approved.
