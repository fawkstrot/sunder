# Releasing Sunder

Current version: **0.9.11**. No GitHub remote or CurseForge project ID is configured yet.

1. Review changes and run `python tools/sunder.py test`.
2. Update `addon/Sunder/Sunder.toc`, the metadata-only loader version, changelog and in-game news when appropriate. Never reset user database versions merely for branding.
3. Run `python tools/sunder.py package`.
4. Inspect `dist/Sunder-<version>.zip`: its only root is `Sunder/`, containing `Sunder.toc`, `Sunder/`, `Media/`, libraries and notices. This is the normal distribution artifact.
5. Inspect `dist/Sunder-<version>-upgrade.zip`: roots are `Sunder/` and the data-only `ROTBOTForever/`. This is the manual first-upgrade bundle for previous installations; local deployment uses the same two folders.
6. Smoke-test the intended client, including real saved-data reload, slash commands, minimap icon, standalone settings, optional Ellesmere Edit UI, a real whisper/reply/history reload, item locking and bank sorting.
7. Commit the reviewed change, tag `v<version>` if desired, and publish deliberately. CI attaches tested ZIP artifacts to its run; it does not publish to CurseForge or create projects.

Artifacts are deterministic (sorted files/fixed ZIP timestamps) and accompanied by a SHA-256 file manifest. Development tests, artwork masters, deployment scripts, private backups and account data do not go in release ZIPs.

The GitHub workflow is prepared for a future remote. Add it with `git remote add origin <your-repository-url>` only after that repository exists. No CurseForge upload token or secret belongs in this repository. Add the actual project ID and automation integration only after project creation and first-file approval.

A normal distribution ZIP is deliberately a single addon root. Existing pre-Sunder users should run the upgrade bundle once and verify a successful Sunder login/logout before using ordinary addon-manager updates. Do not advertise the clean ZIP as importing old SavedVariables without a loader.
