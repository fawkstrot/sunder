# Sunder — agent working guide

Read [docs/CONTEXT.md](docs/CONTEXT.md) at the start of a fresh session. This file holds durable product and architecture rules; the context file holds dated progress and outstanding work.

## Scope and source of truth
This repository owns Sunder, a modular World of Warcraft addon. Current features are Sunder Chat, unified Whispers, and per-copy item protection; future quality-of-life modules register through the same platform. The primary development client is WoW Forever. Do not claim untested Retail/Classic compatibility from TOC numbers alone.

- `addon/Sunder/` is the installable addon and the only production source of truth.
- `addon/Sunder/Sunder/` contains first-party Lua, components, locales and feature modules.
- `addon/Sunder/libs/` contains vendored libraries; preserve licenses and avoid casual edits.
- `compat/ROTBOTForever/` is metadata-only. Its folder and SavedVariables names are deliberately legacy identifiers so WoW loads the previous account data. Never put executable chat code there.
- `assets/branding/` holds the original Sunder emblem and publishing PNG. Shipping TGA textures live in `addon/Sunder/Media/Brand/`.
- `tests/regression/` contains the ported Lua 5.1 harness and native UI fixtures. Historical test filenames are implementation history, not product branding. Run through the CLI so paths and globals are initialized correctly.
- `tools/sunder.py` checks, tests, packages, deploys and rolls back. `.local/` is private, ignored machine state; `dist/` contains generated ZIPs.

Never make normal changes in the installed WoW addon directory or the former Codex output copy. Edit here, validate, then deploy. Never commit WTF data, real conversations, account files, credentials, personal screenshots or deployment backups.

## Working workflow
1. Read this file and the relevant modules. Check Git status and preserve unrelated edits.
2. Make the smallest complete change in `addon/Sunder/`. Preserve the feature registry and shared settings schema.
3. Run `.venv/Scripts/python.exe tools/sunder.py test` (Windows), or `.venv/bin/python tools/sunder.py test` elsewhere. `check` is a quick manifest/Lua/asset check.
4. Use `.venv/Scripts/python.exe tools/sunder.py deploy --dry-run` to inspect the target, then `deploy` to install. Deployment reruns tests, backs up both affected addon folders, verifies hashes, and never edits SavedVariables.
5. Later Lua changes use `/reload`; new addon folder discovery requires restarting the client. Do not interrupt active gameplay. Distinguish automated checks from actual in-game observation.
6. Run `package` to create the clean distribution ZIP and manual-upgrade ZIP. Read `docs/RELEASING.md` before publishing. No remote project IDs or URLs should be invented.

Use task branches when appropriate. Do not discard user edits or commit/publish unrelated changes. Ask when an actual product decision is missing; do not ask repeatedly for already-authorized local edits and testing.

## Product and design system
Sunder feels ancient, powerful and crafted for Azeroth, without being limited to combat. Use the split charcoal stone tablet and molten amber rune as the brand emblem. Keep its silhouette readable at 20–32 px; avoid text, tiny ornaments and excessive glow. Use `tools/build_icons.py` for deterministic TGA/PNG derivatives from the master, not a new icon on every task.

The runtime UI is sleek and restrained: compact headers, subtle header/body separation, borderless surfaces, shared horizontal edge fades, small monochrome action icons with readable tooltips, and thin selection/unread accents. Keep the existing amber/native theme defaults; inherit optional Ellesmere fonts/accent when available while preserving user overrides. Do not turn every window into a branded panel or add bulky icon-only toolbars.

`bodyPadding` is the universal body inset (default 12 px). It covers real chat, Whispers conversations, people lists, sample conversations, editors and notification text. Headers/toolbars have separate compact metrics. Do not reintroduce the removed black top gradient. Avoid double-insetting nested columns. Use original `Media/Icons/` artwork for actions; no text characters pretending to be icons. Keep text within controls at small widths and large font sizes. Full-width filter tabs are All / Unread / Favorites, with an accurate unread counter and a meaningful zero state.

AAA quality means coherent behavior, spacing, accessibility/readability, reliable state, bounded work and visible feedback—not extra decoration. Keep transitions smooth and cancelable; stop per-frame work when idle. Bound history, sample data and notification queues. Reuse shells and controls. Never steal input focus on incoming messages.

## Architecture and invariants
- `Sunder/init.lua`: namespace, defaults, Ace modules and database initialization. `Migration.lua` imports legacy data before AceDB initializes `SunderDB`.
- `Features.lua`: modular settings registry and Chat hierarchy. Chat contains Overview, Chat windows, Whispers and Appearance; Item Protection remains separate. Layout toggles belong only on Chat pages.
- `Modules/Appearance.lua`: shared body/font/header/surface controls. Preserve one owner for each setting and existing user values.
- `Components/SlidingMessageFrame*` and `MessageLine.lua`: native history-backed smooth renderer and clipping. Keep secure/restricted geometry out of unsafe Lua operations. Reflow correctly on resize and editor growth.
- `UIManager.lua`, `DetachedChatDock.lua`, `MoverFrame.lua`: editor ownership, dock/undock, movement and resizing. Hard screen clamping is intentional; the old 20 px magnetic edge snap is not.
- `Whispers.lua`: routing, unread/notification policy, state and persistence. Workspace/Hub/People/Unified/Feedback/Reply/Preview split presentation and interactions. Preserve native text rendering, links and input routing; do not globally replace Blizzard's secure chat-input selection functions.
- Favorites are a filter/section of the main Whispers window. The separate Favorites workspace and roster were retired. Legacy `favorites` window IDs resolve to the main window only for migration. Do not resurrect separate routing, launchers or extra Favorites geometry. Intentional custom groups and detached conversations remain supported.
- Read conversations that are displayed in any foreground workspace suppress their own toasters. Clicking a toaster opens the owning conversation and clears that person's queued toasters. Outgoing text is differentiated from incoming text. Character names include last names when available.
- `WhisperTabs.lua` persists conversations/history by stable character/Battle.net identity. Keep timestamps, directions, profiles, favorites and protected-item GUIDs through upgrades. Preview/test scenarios are session-only, never real recipients, and must be clearable without affecting real data.
- `Ellesmere.lua`, `EllesmereOptions.lua`, `EllesmereEditMode.lua`: optional capability-checked integration. Standalone AceConfig/native fonts/minimap controls must work without any Ellesmere addon. Native Edit UI uses registered elements, size/position callbacks and options links; save/discard, minimized state and combat deferral matter. Do not expose unused built-in ChatFrame slots: initialized is not open. Ellesmere's own snapping preferences remain its responsibility.
- `ItemProtection.lua`: desired protection is saved per physical item GUID; session-owned native locks are separate. Never unlock a foreign lock or a replacement item in a stale slot. Ordinary pickup was verified in-game; universal selling/trading/destruction protection remains unverified. Bank-sort compatibility suspends only our backpack locks synchronously around bank cleanup and immediately relocks, even on errors. Never extend this to timed unlock windows, vendor, trade or bag-sort paths.

## Branding, compatibility and migration
Display name and namespace are Sunder; a module may be called Sunder Chat. Primary slash command is `/sunder`; `/sun` registers only when unused. `/rotbot`, `/rotbotforever`, `/rb`, `/gl` and the old protection binding remain intentional aliases.

Keep legacy identifiers only in the migration module, companion loader, compatibility aliases/bindings/import prefixes, migration tests and provenance. Preserve original copyright and third-party attribution. Migrate full database tables by value without rewriting message text. Never overwrite an existing `SunderDB` with old data on later starts. The old folder is a data-only loader after deployment; two real implementations must not run together.

## Validation and release discipline
Run relevant behavior checks after changes, then the standard test command. Do not silently remove coverage to make a test pass. The harness includes renderer/input, resizing, window state, previews, routing, history, favorites migration, item locks, bank sorting, Ellesmere edit registration, standalone fallback and Sunder migration/commands/assets.

Report exactly what was tested. Native protected behavior, new APIs and visual changes need in-game verification; do not imply mocked checks are live validation. Current live testing/deployment is on WoW Forever. CurseForge project ID is 1798860. GitHub origin is https://github.com/fawkstrot/sunder.git; the upload token is stored as a GitHub Actions secret, never locally in source. The user confirmed successful CI and upload; approval/publication status is tracked in docs/CONTEXT.md. See docs/RELEASING.md: curated versioned changelogs, explicit tagged releases, and manual upload only. Never commit tokens or invent supported game-version IDs.
