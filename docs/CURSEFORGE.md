# CurseForge project setup

The source layout and release artifacts are ready; no project has been created or published automatically.

## Create the project

1. Open [Create a Project](https://authors.curseforge.com/#/projects/create/choose-game), sign in yourself, and select World of Warcraft / Addons.
2. Use **Sunder** as the project name. Suggested short summary: **Smooth chat, unified Whispers, item protection, and modular quality-of-life tools.**
3. Upload `assets/branding/Sunder-project-icon.png` (512×512 PNG). It satisfies the published minimum 400×400 project-icon guidance.
4. Start with the Chat & Communication category, and choose other offered categories only when the project actually implements them. Select MIT as the license; bundled notices remain included.
5. Use `docs/CURSEFORGE_DESCRIPTION.md` as the initial long description, then add real in-game screenshots after the rebrand is validated.
6. Provide the real source/issue links once the Git repository is hosted. Do not send Sunder bugs to the upstream Glassy tracker.
7. Upload the tested clean `dist/Sunder-0.9.11.zip` with the matching client/game version tags. Before public submission, confirm which official WoW versions have actually been tested: this project was developed on WoW Forever, and its inherited Interface metadata is not proof of Retail/Classic compatibility. Do not invent a Forever game-version tag or claim client support merely to satisfy the upload form.
8. Save the assigned project ID for later release automation. The repository currently uses its own packaging tool; `.pkgmeta` auto-packaging is intentionally not enabled for this source-root layout. Do not upload the entire Git repository as an addon ZIP.

For existing ROTBOT installations, provide the separate manual upgrade bundle and migration instructions through the first transition. The ordinary clean ZIP contains only Sunder; it cannot load an old SavedVariables file by itself. Subsequent addon-manager updates work from Sunder's own database.

## Prepared files

- Runtime and TOC: `addon/Sunder/`.
- Project icon: `assets/branding/Sunder-project-icon.png`.
- Description: `docs/CURSEFORGE_DESCRIPTION.md`.
- Clean release ZIP: `dist/Sunder-0.9.11.zip`.
- First-upgrade bundle: `dist/Sunder-0.9.11-upgrade.zip`.
- Checks/build artifacts: `.github/workflows/ci.yml`.

## Reference

[Creating and submitting a project](https://support.curseforge.com/support/solutions/articles/9000197241), [submission guidance and icon dimensions](https://support.curseforge.com/support/solutions/articles/9000199552), [file types and approval](https://support.curseforge.com/support/solutions/articles/9000197242-file-types-and-additional-fields), and [ZIP structure troubleshooting](https://support.curseforge.com/support/solutions/articles/9000196615).

Review live project forms at submission time; no credentials, project IDs or remote URLs have been fabricated.
