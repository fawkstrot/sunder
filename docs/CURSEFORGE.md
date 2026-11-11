# CurseForge project setup

Project **1798860** is configured. The user confirmed its first upload succeeded on 2026-11-11; the file was under review at the last report. Approval and public visibility remain to be checked. Follow [Releasing Sunder](RELEASING.md) for GitHub setup, issue tracking, changelogs, credentials and manual publishing.

## Project checklist

1. Use existing project **1798860** in the Authors dashboard. Do not create a duplicate.
2. The listing is named **Sunder Forever**; runtime/repository branding remains **Sunder**. Suggested short summary: **Smooth chat, unified Whispers, item protection, and modular quality-of-life tools.**
3. Upload `assets/branding/Sunder-project-icon.png` (512×512 PNG). It satisfies the published minimum 400×400 project-icon guidance.
4. Start with the Chat & Communication category, and choose other offered categories only when the project actually implements them. Select MIT as the license; bundled notices remain included.
5. Use `docs/CURSEFORGE_DESCRIPTION.md` as the initial long description, then add real in-game screenshots after the rebrand is validated.
6. Source: `https://github.com/fawkstrot/sunder`. External issues: `https://github.com/fawkstrot/sunder/issues` (saved). Leave CurseForge issue tags/templates empty; GitHub owns them.
7. Target **WoW Forever 1.60.1**. The manual GitHub workflow resolves that selected name against the live CurseForge version API. Do not re-upload the successful 0.9.11 release or claim untested Retail/Classic support.
8. Project ID **1798860** is configured for release automation. The repository currently uses its own packaging tool; CurseForge Automatic Packaging must remain disabled because GitHub Actions already builds and uploads the package. Do not upload the entire Git repository as an addon ZIP.

For existing ROTBOT installations, provide the separate manual upgrade bundle and migration instructions through the first transition. The ordinary clean ZIP contains only Sunder; it cannot load an old SavedVariables file by itself. Subsequent addon-manager updates work from Sunder's own database.

## Prepared files

- Runtime and TOC: `addon/Sunder/`.
- Project icon: `assets/branding/Sunder-project-icon.png`.
- Description: `docs/CURSEFORGE_DESCRIPTION.md`.
- Clean release ZIP: `dist/Sunder-0.9.11.zip`.
- First-upgrade bundle: `dist/Sunder-0.9.11-upgrade.zip`.
- Checks/build artifacts: `.github/workflows/ci.yml`.
- Manual tagged releases: `.github/workflows/release.yml`.
- Canonical release notes: `addon/Sunder/CHANGELOG.md`.
- Project and supported-version configuration: `release.json`.

## Reference

[Creating and submitting a project](https://support.curseforge.com/support/solutions/articles/9000197241), [submission guidance and icon dimensions](https://support.curseforge.com/support/solutions/articles/9000199552), [file types and approval](https://support.curseforge.com/support/solutions/articles/9000197242-file-types-and-additional-fields), and [ZIP structure troubleshooting](https://support.curseforge.com/support/solutions/articles/9000196615).

Review live project forms at submission time; no credentials, project IDs or remote URLs have been fabricated.
