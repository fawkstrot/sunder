# Session handoff — 2026-11-11

Read AGENTS.md first. Update this dated handoff when work changes; remote status below must be rechecked when relevant.

## Source and workflow

- Canonical repository: `C:/Users/fawks/Documents/Projects/World of Warcraft/Sunder`.
- GitHub: https://github.com/fawkstrot/sunder ; branch `master`.
- Installable source: `addon/Sunder/`. `compat/ROTBOTForever/` is a metadata-only migration loader.
- Current version/tag: **0.9.11 / v0.9.11**. Do not move this tag.
- Last implementation commit before this documentation cleanup: `8f32789`.
- Edit here, test, deploy to the installed addon, then observe in-game. The former Codex output folder and installed addon are not development source.
- No unfinished feature implementation is pending from this session. The remaining work concerns launch verification.

## Release status — reported by user

- GitHub check/package workflow passed after the dependency-cache filename fix.
- GitHub draft release exists with ZIPs and curated notes. Publishing that draft has not been confirmed.
- CurseForge project ID: **1798860**. Its display name in the user's screenshot is **Sunder Forever**; runtime/repository branding remains **Sunder**.
- User configured `CURSEFORGE_API_TOKEN` as a GitHub Actions secret. Never request it in chat or store it in source.
- The manual workflow's first CurseForge upload succeeded. The file was under review at the last report; approval/public visibility remains unconfirmed.
- Source link points to GitHub. External issue URL was saved as https://github.com/fawkstrot/sunder/issues . GitHub owns issue forms, tags and templates.
- Leave CurseForge Automatic Packaging disabled. GitHub Actions owns packaging and upload. Normal pushes only check and build artifacts.
- Do not rerun the successful 0.9.11 upload: duplicate prevention is procedural, not an API-backed deduplication guarantee.

## Release mechanics

`release.json` selects **Forever 1.60.1** by name. Upload resolves selected names against CurseForge's live game-version list. Missing or ambiguous versions stop the upload. New patches are not automatically claimed as supported. Only WoW Forever has been tested.

Current release tooling and tagged addon source have separate checkouts. The workflow refreshes an existing draft and refuses to modify a published GitHub release. Curated notes come from the tagged version's section in `addon/Sunder/CHANGELOG.md`. The clean ZIP goes to CurseForge; the manual first-upgrade bundle is also attached to GitHub.

GitHub publication and CurseForge review are independent. Publishing the draft does not upload again; CurseForge approval does not publish the draft. Suggested coordinated launch: confirm CurseForge approval, then publish the GitHub draft.

## Remaining launch checks

1. Check CurseForge Files for approval/public download of 0.9.11, Forever 1.60.1.
2. Confirm description, icon, license and source/issue links on the listing.
3. Review and publish the GitHub draft when the user is ready. Do not assume setup authorized future publication.
4. Smoke-test the actual downloaded artifact and migration with private SavedVariables backed up. Never overwrite or commit account/conversation data.
5. Other clients and universal native sell/trade/destroy protection remain unverified; preserve the specific limits in AGENTS.md.

## Validation and local environment

Run `.venv/Scripts/python.exe tools/sunder.py test`. The last full run passed, including seven release tests. The user subsequently reported successful GitHub execution and upload. Mocked tests are not live UI verification.

Default deployment target: `C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns`. Deployment backs up addon folders under ignored `.local/backups/`, verifies files and never edits SavedVariables. Use `deploy --dry-run` first. Folder changes require restarting the client; later Lua changes normally use `/reload`. Release-tooling changes did not require redeploying the live game.

Keep this repository-only documentation cleanup out of the existing release tag. No addon version bump is needed. Commit/push documentation normally when requested.
