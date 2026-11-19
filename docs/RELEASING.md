# Releasing Sunder

CurseForge project: **1798860** (public visibility not independently confirmed). Current uploaded alpha: **0.10.0-alpha.4**. GitHub repository: `fawkstrot/sunder`. Upload credentials are stored in GitHub Actions secrets, never in this repository. Nothing publishes on a normal commit or push.

The user confirmed green CI, a draft GitHub release and a successful CurseForge upload on 2026-11-11. Do not upload 0.9.11 again. See [session context](CONTEXT.md) for remaining launch checks.

## One-time setup (completed; reference for recovery)

1. Create an empty GitHub repository, without an initial README/license/gitignore, to preserve this repository's history. Add its real URL as `origin`, push the existing branch, and make that branch the GitHub default. Set `githubRepository` in `release.json` to the actual `owner/repository`.
2. Enable GitHub Issues. Point CurseForge's Source and Issues links to the repository and its `/issues` page. Local issue forms and the pull-request template become available after pushing the default branch.
3. Create a GitHub Actions environment named `release`. Add a secret there named `CURSEFORGE_API_TOKEN`, using your CurseForge upload token. Never paste it into chat, commit it, or put it in command arguments. Optionally require a reviewer for this environment if your GitHub plan supports it.
4. Confirm actual supported clients in-game. The tested target is WoW Forever 1.60.1. `gameVersionNames` in `release.json` records that selection. During upload, the workflow queries CurseForgeâ€™s live game-version list to resolve the selected names to IDs. It fails on missing or ambiguous names; it never silently selects a newer, untested patch. Numeric IDs remain an optional override. Inherited TOC numbers do not establish Retail/Classic compatibility.
5. Keep CurseForge's separate repository/webhook auto-packaging disabled when using this workflow, so two systems cannot publish the same release.

## Track work

- Open an issue describing a bug or feature; use a small branch and a pull request for its implementation.
- Reference the issue in the PR; `Fixes #123` closes the issue when merged into the default branch. Label issues by feature and use a milestone for a planned release if helpful.
- Add meaningful player-facing changes under `# Unreleased` in `addon/Sunder/CHANGELOG.md`. Link relevant issue/PR numbers. Git commit messages provide implementation history; release notes are curated for players.
- Run `python tools/sunder.py test` and record real in-game checks separately. Automated CI also validates pull requests and builds installable artifacts.

## Cut a release

1. Move Unreleased entries into `# <version> (YYYY-MM-DD)` in the canonical changelog. Update `addon/Sunder/Sunder.toc` and `compat/ROTBOTForever/ROTBOTForever.toc` together; update in-game news where appropriate. Do not reset database schema versions for a normal release.
2. Run `python tools/sunder.py test`, then `python tools/release.py prepare --tag v<version> --release-type alpha` (use the matching `beta` or `release` for those channels). Preparation does not upload anything. It rejects inconsistent versions or project IDs and extracts only that version's changelog section.
3. Inspect `dist/Sunder-<version>.zip` (only `Sunder/`) and `dist/Sunder-<version>-upgrade.zip` (Sunder plus metadata-only ROTBOTForever). Smoke-test the intended client: saved-data reload, slash commands, minimap, standalone settings, optional Ellesmere Edit UI, whisper/reply/history, item protection and bank sorting.
4. Commit reviewed changes, create an annotated `v<version>` tag on that commit, and push the branch and tag. Do not move published version tags; fix mistakes with a new version.
5. In GitHub Actions, run **Release Sunder**, entering the existing tag and matching **release_type**. The type defaults to **alpha**; a mismatch with the version stops before packaging/upload. Leave **publish_curseforge** off for the first rehearsal. It reruns checks, builds both ZIPs and creates a **draft** GitHub release with the curated notes and checksums (also marked prerelease for Alpha/Beta). Review that draft before publishing it on GitHub.
6. For the intended upload run, enable **publish_curseforge** and leave numeric IDs empty and use `1.60.1` in the version-names field. The workflow refreshes an existing draft and refuses to modify a published GitHub release. Current release tooling packages the exact existing tag from a separate checkout, so tooling fixes do not require moving version tags. Never blindly rerun after a possible upload; inspect CurseForge files first to avoid duplicates.
7. CurseForge receives only the clean ZIP, the same curated notes, and explicitly checked alpha/beta/release type derived from the version. CurseForge approval/visibility still applies. GitHub's draft publication is a separate deliberate step.

The release command uploads only from a clean working tree at the matching committed tag. Version tags such as `0.10.0-alpha.1` or `0.10.0-beta.1` are classified appropriately; ordinary versions are releases. Unknown prerelease suffixes are rejected. `-alpha.N` maps to CurseForge Alpha, `-beta.N`/`-rc.N` to Beta; a bare version maps to Release. GitHub draft/prerelease flags do not control CurseForge classification.

The prior 0.9.11 was a full release because it had no prerelease suffix. Use a fresh numbered alpha tag for each upload. Keep the GitHub draft unpublished unless requested.

## Artifacts and migration

`dist/release-notes.md`, `curseforge-metadata.json` and `release-manifest.json` describe the release. ZIPs are deterministic and accompanied by file hashes. Tests, artwork masters, tooling, private backups and account data are excluded.

The first-upgrade bundle is attached to GitHub for manual migration, not sent as the ordinary CurseForge artifact. Existing ROTBOT users must install the upgrade loader once and verify a successful Sunder login/logout before normal addon-manager updates. The clean ZIP cannot import legacy SavedVariables by itself. See [migration](MIGRATION.md).

## Current verification limits

Local tests passed; the user confirmed green GitHub checks and a successful CurseForge upload. CurseForge approval/public availability and publication of the GitHub draft remain unconfirmed. Only WoW Forever is tested; Retail and other Classic flavors remain unverified. Native behavior still needs the in-game smoke checks above.

API reference: [CurseForge Upload API](https://support.curseforge.com/support/solutions/articles/9000197321-curseforge-upload-api).


2026-11-16: **0.10.0-alpha.1** uploaded successfully as **Alpha**, CurseForge file **9652042**, Forever **1.60.1**, through [Release Sunder run 43922901392](https://github.com/fawkstrot/sunder/actions/runs/43922901392). GitHub release is a draft prerelease with checked ZIPs/manifest; it remains unpublished. CurseForge review/public visibility is not yet confirmed. Do not upload this version again. See CONTEXT.md for commit/checksum and native-validation limits.

2026-11-16: CurseForge accepted **0.10.0-alpha.2** as **Alpha** for WoW Forever **1.60.1**, file **9656593**. The [upload run](https://github.com/fawkstrot/sunder/actions/runs/43972843929) used the tagged commit b0c0f4b. Keep the GitHub prerelease in draft. Public visibility on CurseForge has not been independently confirmed.

2026-11-18: CurseForge accepted **0.10.0-alpha.3** as **Alpha** for WoW Forever **1.60.1**, file **9688726**, from tagged commit **e1ad414**. [Rehearsal](https://github.com/fawkstrot/sunder/actions/runs/44370166249), both branch/tag CI runs and the [upload run](https://github.com/fawkstrot/sunder/actions/runs/44370305724) succeeded. Clean and upgrade draft assets were verified byte-for-byte against tagged source; clean ZIP SHA256: `05714be4a5d7a8cfaa1373e6856dc466335c4e37c28f36cb7c9637dd93aec0bb`. GitHub remains a draft prerelease. CurseForge acceptance does not independently establish public visibility. Do not upload this version again.

2026-11-19: Preparing fresh **0.10.0-alpha.4** as Alpha for Forever **1.60.1**, authorized by the user. Local checks and curated release preparation passed. Rehearsal and upload receipts will be recorded after completion; alpha.3 remains immutable. GitHub stays a draft prerelease.

2026-11-19: CurseForge accepted **0.10.0-alpha.4** as **Alpha** for WoW Forever **1.60.1**, file **9703400**, from tagged commit **3d5bf75**. [Rehearsal](https://github.com/fawkstrot/sunder/actions/runs/44581365008), both branch/tag CI runs and [upload](https://github.com/fawkstrot/sunder/actions/runs/44581574216) succeeded. Clean and upgrade draft assets match tagged source byte-for-byte. Clean ZIP SHA256: `0eb73977a0ec9413a2845cea207bac2c077db022c47e1976d0ed4900024766f8`. GitHub remains a draft prerelease; CurseForge public approval/visibility is unconfirmed. Do not upload this version again.
