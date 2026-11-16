# Sunder — agent working guide

Read [docs/CONTEXT.md](docs/CONTEXT.md) at the start of a fresh session. This file holds durable product and architecture rules; the context file holds dated progress and outstanding work.

## Scope and source of truth
This repository owns Sunder, a modular World of Warcraft addon. Current features are Sunder Chat, unified Whispers, Guild/Party Chat rooms, and per-copy item protection; future quality-of-life modules register through the same platform. The primary development client is WoW Forever. Do not claim untested Retail/Classic compatibility from TOC numbers alone.

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
6. Every implementation task must update `docs/CONTEXT.md`, relevant product/development documentation, and workflow validation results. Record automated checks, installed deployment status, and pending in-game observations separately. Keep this durable requirement in AGENTS.md.
7. Run `package` to create the clean distribution ZIP and manual-upgrade ZIP. Read `docs/RELEASING.md` before publishing. No remote project IDs or URLs should be invented.

Use task branches when appropriate. Do not discard user edits or commit/publish unrelated changes. Ask when an actual product decision is missing; do not ask repeatedly for already-authorized local edits and testing.

## Product and design system
Sunder feels ancient, powerful and crafted for Azeroth, without being limited to combat. Use the split charcoal stone tablet and molten amber rune as the brand emblem. Keep its silhouette readable at 20–32 px; avoid text, tiny ornaments and excessive glow. Use `tools/build_icons.py` for deterministic TGA/PNG derivatives from the master, not a new icon on every task.

The runtime UI is sleek and restrained: compact headers, subtle header/body separation, neutral one-pixel room outlines and column dividers, shared horizontal edge fades, small monochrome action icons with readable tooltips, and thin selection/unread accents. Sidebars must remain visually distinct from transcripts with compact bounded widths and visible scroll affordances. Keep the existing amber/native theme defaults; inherit optional Ellesmere fonts/accent when available while preserving user overrides. Do not turn every window into a branded panel or add bulky icon-only toolbars.

`bodyPadding` is the universal body inset (default 8 px). It covers real chat, Whispers conversations, people lists, sample conversations, editors and notification text. Headers/toolbars have separate compact metrics. Do not reintroduce the removed black top gradient. Avoid double-insetting nested columns. Use original `Media/Icons/` artwork for actions; no text characters pretending to be icons. Keep text within controls at small widths and large font sizes. Full-width filter tabs are All / Unread / Favorites, with an accurate unread counter and a meaningful zero state.

AAA quality means coherent behavior, spacing, accessibility/readability, reliable state, bounded work and visible feedback—not extra decoration. Keep transitions smooth and cancelable; stop per-frame work when idle. Bound history, sample data and notification queues. Reuse shells and controls. Never steal input focus on incoming messages.

## Architecture and invariants
- `Sunder/init.lua`: namespace, defaults, Ace modules and database initialization. `Migration.lua` imports legacy data before AceDB initializes `SunderDB`.
- `Features.lua`: modular settings registry and Chat hierarchy. Chat contains Overview, Chat windows, Whispers, Guild Chat, Party Chat and Appearance; Item Protection remains separate. Layout toggles belong only on Chat pages.
- `Modules/Appearance.lua`: shared body/font/header/surface controls. Preserve one owner for each setting and existing user values.
- `Components/SlidingMessageFrame*` and `MessageLine.lua`: native history-backed smooth renderer and clipping. Keep secure/restricted geometry out of unsafe Lua operations. Reflow correctly on resize and editor growth.
- `GuildChat.lua`: a dedicated native GUILD-only window, event-driven rank-sorted roster, public notes only, and bounded per-character/guild/realm recent recall. Preserve other chat windows and global roster preferences; never include officer notes in the model or saves. Virtualize visible member rows, yield roster scans, cancel stale guild/frame work, reuse native-slot shells, and stop work while hidden. Guild and future chat rooms must use the shared Whispers room chrome and movement/collapse primitives, not a bare detached chat tab as their visible shell. Guild has a separate real room root with always-available header drag, minimize/restore, maximize/restore-size, global edit-mode resize and one Ellesmere mover. Keep the roster compact, scrollable and selectable; selection must not open a whisper automatically. Shell adapters may share methods, never inherit Whispers session/preview state. Record actual visual checks separately from fixture geometry checks.
- `UIManager.lua`, `DetachedChatDock.lua`, `MoverFrame.lua`: editor ownership, dock/undock, movement and resizing. Plain message-row and blank-viewport clicks select the owning native editor for the next Enter without opening/focusing it or changing drafts. Preserve modified link actions, unrelated field focus and edit-mode movement; keep global native input functions intact. Hard screen clamping is intentional; the old 20 px magnetic edge snap is not.
- `Whispers.lua`: routing, unread/notification policy, state and persistence. Workspace/Hub/People/Unified/Feedback/Reply/Preview split presentation and interactions. Preserve native text rendering, links and input routing; do not globally replace Blizzard's secure chat-input selection functions.
- Favorites are a filter/section of the main Whispers window. The separate Favorites workspace and roster were retired. Legacy `favorites` window IDs resolve to the main window only for migration. Do not resurrect separate routing, launchers or extra Favorites geometry. Intentional custom groups and detached conversations remain supported.
- Conversations displayed in any foreground workspace suppress new toasters and retire their queued toasters, including while scrolled back. Select the intended person before expanding a minimized workspace; ordinary selection acknowledges only that person. Clicking a toaster opens the owning conversation and clears that person's queued toasters. Outgoing text is differentiated from incoming text. Character names include last names when available.
- `WhisperTabs.lua` owns per-character durable transcripts (`whisperArchive`) separately from open-tab checkpoints (`whisperTabs`), keyed by stable character/Battle.net identity. Closing archives before native teardown; only confirmed deletion forgets a transcript. Archived favorites remain in the main Favorites section, other closed people in Archived. Preserve early-startup checkpoints until restore consumes them; bound archive size and chunk native replay. Keep timestamps, directions, profiles, favorites and protected-item GUIDs through upgrades. Preview/test scenarios are session-only, never real recipients, and must be clearable without affecting real data.
- `Ellesmere.lua`, `EllesmereOptions.lua`, `EllesmereEditMode.lua`: optional capability-checked integration. Standalone AceConfig/native fonts/minimap controls must work without any Ellesmere addon. Native Edit UI uses registered elements, size/position callbacks and options links; save/discard, minimized state and combat deferral matter. Do not expose unused built-in ChatFrame slots: initialized is not open. Ellesmere's own snapping preferences remain its responsibility.
- `ItemProtection.lua`: desired protection is saved per physical item GUID; session-owned native locks are separate. Never unlock a foreign lock or a replacement item in a stale slot. Ordinary pickup was verified in-game; universal selling/trading/destruction protection remains unverified. Bank-sort compatibility suspends only our backpack locks synchronously around bank cleanup and immediately relocks, even on errors. Never release locks for use/pickup/cursor operations, timed unlock windows, vendor, trade or bulk bag-sort paths. A same-call bag-use/movement exception was live-tested and allowed destruction; it was removed. Native cursor GUID relocking is not a verified disposal barrier. Retain strict locking until a separately verified selective protection mechanism exists.

## Branding, compatibility and migration
Display name and namespace are Sunder; a module may be called Sunder Chat. Primary slash command is `/sunder`; `/sun` registers only when unused. `/rotbot`, `/rotbotforever`, `/rb`, `/gl` and the old protection binding remain intentional aliases.

Keep legacy identifiers only in the migration module, companion loader, compatibility aliases/bindings/import prefixes, migration tests and provenance. Preserve original copyright and third-party attribution. Migrate full database tables by value without rewriting message text. Never overwrite an existing `SunderDB` with old data on later starts. The old folder is a data-only loader after deployment; two real implementations must not run together.

## Validation and release discipline
Run relevant behavior checks after changes, then the standard test command. Do not silently remove coverage to make a test pass. The harness includes renderer/input, resizing, window state, previews, routing, history, favorites migration, item locks, bank sorting, Ellesmere edit registration, standalone fallback and Sunder migration/commands/assets.

Report exactly what was tested. Native protected behavior, new APIs and visual changes need in-game verification; do not imply mocked checks are live validation. Current live testing/deployment is on WoW Forever. CurseForge project ID is 1798860. GitHub origin is https://github.com/fawkstrot/sunder.git; the upload token is stored as a GitHub Actions secret, never locally in source. The user confirmed successful CI and upload; approval/publication status is tracked in docs/CONTEXT.md. See docs/RELEASING.md: curated versioned changelogs, explicit tagged releases, and manual upload only. Never commit tokens or invent supported game-version IDs.

Room title bars and grips both drag the owning window. A per-window title-bar lock prevents movement through either path. Unified Whispers filters occupy their own full-width row; sidebar dividers and scroll content begin below it. Preserve horizontal edge fades above continuous body backing, including native chat windows.



WindowManager.lua owns shared window action construction, position-lock policy and native header adapters; extend it rather than inventing controls for each type. Native undocked tabs (including Combat Log) drag from the header outside edit mode and retain native filters/docking. Main chat can collapse to its native tab bar and maximize/restore through the shared header. Its lock covers the grip, tab dragging, maximize and resizing. Keep native selection, filters, drafts and receiving active while collapsed. Guild unread is incoming-event/session-only, suppressed while its expanded conversation is visible, acknowledged on restore, bounded, and never produces toasters.


Normal header movement must use a visible drag driver under UIParent, never the hidden edit-mode overlay. Move the visible main chat root with the same native engine path as Guild/Whispers, then transfer its final position to the saved anchor. All window headers use the shared left six-dot grip; reserve tab space on both sides. Validate intermediate held-mouse movement, not only release position.


WindowManager:ApplySurface is the single owner of body backing plus horizontal fade, perimeter borders, header fill/separator and sidebar separation for main chat, native detached windows, Whispers and Guild. Adapters supply geometry and preserved appearance overrides, not extra paints. Native headers/tabs/grips inherit the visible root display layer; never force them to LOW beneath the surface. Renderer rows suppress their own background when a shared surface owns the window. Validate opacity zero, collapse, pooling and reflow across all adapters.


Shared-surface cache keys must include scalar color channels, fade proportions, root dimensions/level, body visibility and adapter geometry; do not key only by mutable settings-table identity. Native surface subscriptions should filter relevant appearance keys. Shared drag drivers must stop on target hide and release; reused frames keep one hide hook with the current stop callback. Retire native separators alongside old header fills so only the common rule paints.


All visible window types use WindowManager:CreateWindowResizer; main chat must not require global edit mode for its normal corner grip. Native renderer overflow/reused-editor space is reported to the shared surface, whose outline/body/grip must include that extent. Native toolbar actions are capabilities: show a settings cog only with a valid window destination, and offer undocked windows an explicit return-to-main action. Favorite mutations must update current records and archive/contact metadata; recycled row actions read their current identity.


Toggle action selection belongs to WindowManager:SetActionSelected/RefreshAction: outline when inactive, filled silhouette plus persistent accent when active; hover must not erase state. Stars, pins and position locks share this rule. Header unread numbers must represent unread messages, not open conversation totals; people rows use the shared unread badge component, including samples. Keep selected opacity/readability and reserved label/badge widths at large fonts.

Room collapse/restore transitions belong to WindowManager; adapters must not pre-position or resize a room before the shared transition guard. Header unread indicators share icon/text color policy.


Visible resize geometry (viewport, scrollbar and overlay) must update synchronously through the shared renderer geometry method. Coalesce history/text reflow separately; do not defer visible resize chrome behind the render queue.


Window header commands use WindowManager semantic capability descriptors and shared layout/state refresh. Menu, maximize/restore-size, roster, dock-to-main and directional collapse have distinct icons with stable meanings. Do not repurpose a glyph for another command or recreate per-window state/tooltip rules. Disabled controls stay visually disabled during hover; hidden controls clear pressed/hover state.


Collapse validation must assert intermediate shared-surface height and opacity, not only root geometry/end state. Body surface presentation belongs to WindowManager for every adapter, independent of list layout. Header counters use LayoutUnreadIndicator; idle title glyphs use StyleTitleIcon across native tabs and room headers. Semantic toggle callbacks refresh selected state/tooltips after mutation.

Room collapse is an opaque geometric clip, not a fade-out: keep body backing, native content and active people list visible during the full transition, hide only at completion, and restore editor overflow afterward. Validate actual surface/content/list bounds through both directions, not just root height or end states.

WindowManager owns room body visibility/opacity and sidebar width bounds as well as collapse transitions. Feature adapters supply content measurements and layout, not alternate body lifecycle policies. Responsive compaction must not silently override Show actions; a show command must reveal content or restore sufficient geometry.

People lists share WindowManager:UpdateListScrollIndicator for passive scroll-area feedback. Interactive scrollbar controls must sit above row content; preserve a subtle track when all rows fit. Empty conversation wording describes selection state without assuming routing, newcomers or detached tabs.

Use sentence case and normal punctuation for empty-state messages; do not introduce all-caps headings.

Anchor list rails to the viewport edge through WindowManager:LayoutListScrollRail. Body padding belongs to row content, not an extra gutter between scrollbar and sidebar divider.

MessageLine geometry must use its owning renderer layout width, never the global General width for detached/room rows. Reserve scrollbar clearance within text bounds, including zero body padding. Header metadata counters use shared action layout and remain independent of roster filters/visibility.

Guild recovery must tolerate a missing per-character native slot mapping after a rename/reset: recover only one open, dedicated GUILD-only slot with the expected title, including a visible replacement renderer when the native frame is parked. Never resurrect closed slots or take over mixed/ambiguous windows. Bindings.xml is automatically loaded by WoW and must not appear in the TOC; declare each binding header once.

Person metadata uses shared WindowManager detail formatting/font/color policy: smaller non-wrapping level/class text, muted class color, bounded row width. Preserve Guild rank/public notes separately. Show only available character data; no invented levels, automatic inspect or /who requests. Current friend presence remains session-only/event-driven; last-known class/level persists per character in a bounded 200-contact cache; reused rows must clear unknown details.

Window geometry locks apply to shared resize drivers and Edit UI size callbacks, not only drag. Cancel active resizing when locked; do not allow maximize to bypass the lock. Whispers person labels use explicit top anchors/heights with metadata, and a centered single line when unknown. Own-message tint uses one renderer policy based on native sender/line metadata or structured sender links, never body substring guesses. Guild MOTD belongs to the bounded caption, not duplicated in transcript/history.

Guild roster uses compact two-line identity rows with subtle separators; full rank/public notes live in selected member cards and hover tooltips. GuildInfo is a responsive body drawer, not a separate window or duplicated shell. Actions resolve current roster identity/guild at click time; opening cards never sends messages/invites. Favorites are shared per character across Guild and Whispers through Whispers:SetPersonFavorite. Guild-only legacy favorites migrate once into whisperFavorites; unstar updates live records, archive and startup snapshots. Favoriting never opens a conversation or sends a message. Guild pins remain guild/character scoped. Shared filter/action/inset styling belongs to WindowManager.

## Shared person-list contract
Whispers and Guild use WindowManager:LayoutPersonRow for name/detail geometry, separators, selected/unread accents and right-side favorite/pin actions. Feature adapters supply identity, state and callbacks; selection/style refresh must not restore legacy tab anchors on list rows. Sort by pinned favorites, favorites, pinned, then the normal stable ordering, without extra section groups. Filled icons indicate active state; unselected rows retain usable actions. Guild pins remain current-guild/per-character scoped; favorites are shared per character across all real contact views.

Person-list separator spacing must be judged against visible glyphs, not just FontString bounds. Keep row stride shared (no adapter-only gaps); selection must preserve the shared optical text offset.

Item Protection must expose the established strict lock feature without experimental modes or developer test controls in normal settings. The disposal-preview module/UI were removed at user request. Research does not authorize exposing a test workflow in the product. Keep regressions in the harness; never weaken existing protection based on mock cursor behavior.

Full-width people-filter buttons fill their row height; active underlines share its bottom baseline. Clear hover/pressed state on hide. Transcript fades start below filter/tool rows so the row backing is uniform across columns.

## Reusable roster rooms and Party Chat

RosterRoom.lua owns the shared Guild/Party shell, member-list/transcript layout, native-slot recovery/state restore and bounded recall. WindowManager owns the controller registry; UIManager, native message saves, favorites and Ellesmere resolve it. Future room types extend descriptors/controllers rather than copying shell code. Guild-specific roster/info behavior stays in its feature adapter.

PartyChat.lua opens automatically on joining by default, with an explicit manual-only option, and remembers state. Automatic opening preserves minimized state and full-size geometry; it must not expand the room or claim editor focus. One room follows party/raid/instance channel changes. No input focus on automatic restore/join or incoming messages. Solo/ended sessions are read-only; a different group clears the transcript/draft. Recall is character-local, 200 lines/512 KiB, and only resumed for a matching roster fingerprint; partial startup data must not destroy saved recall. Combat defers native editor/geometry mutations. Event-driven roster/status work is bounded to 40 members; no idle per-frame driver. Shared favorites apply here too, while group pins are separate. Do not add automated group-management actions or test controls.

## Hard transcript geometry contract

Every production MessageLine and message pool must receive an explicit renderer owner at creation. Rows read width/scrollbar clearance only from that owner; never infer an ancestor depth or silently fall back to General's configured width. Ownerless creation must fail immediately. Both visible and detached measurement FontStrings must use the same wrapping/non-space wrapping/unlimited-lines policy. A new room or transcript geometry change must run an integration regression through the actual InitializeScrollFrame -> viewport -> slider -> row pool hierarchy, including narrow widths, multi-line height, pooled reuse and missing-owner rejection. Scalar width checks using a simplified parent tree are insufficient. Record native visual wrapping separately from mocked coverage.

A favorite is a contact, not proof of conversation history. Contact-only favorites appear in Favorites, not All; first real messages promote the conversation into All. Selecting a contact with no messages shows a meaningful empty state. Favoriting never creates a native conversation. Party search is a roster capability enabled for raids only; hiding it removes its reserved space and clears its query.

- Party/Raid duplicate suppression is a side-effect-free per-frame filter while its room is open, including minimized; never rewrite General subscriptions. Player Inspect actions share WindowManager eligibility/identity checks. Closed/read-only rooms release Enter through UIManager without moving drafts. Known-offline names use shared roster dimming; unknown presence stays normal.

- Whispers/Guild/Party expanded people lists must use WindowManager.PeopleSidebarWidth (sole PEOPLE_SIDEBAR_WIDTH=150 px, shared narrow-window reserve); do not reintroduce feature-specific minimums or transcript reserves. Compact/hidden roster modes remain explicit.

- All-window timestamps default on with one shared master off switch; versioned upgrades must never re-enable a later explicit off choice. All-window timestamps are formatted by the shared TextProcessing processor from original receipt times, never embedded into saved text. Preserve opt-out/per-window preferences when global scope is off. Selected favorite/pin actions use filled icons without selected background plates; use the shared action styling and filled favorite toaster badge.

- Compact chat labels belong to shared TextProcessing presentation only: dedicated rooms omit redundant channel tags, incoming Whispers use Name:, outgoing Whispers retain dim styling without To labels. Match localized native prefixes and metadata, preserve original history/link payloads and keep General channel context.

- Late room ownership must invalidate cached transcript text once through shared RosterRoom binding, preserving readback; geometry-only changes do not refresh ownership-dependent message labels. Repeated resize/layout must not reformat all retained rows.

- Native history adapters must preserve message type/access/line metadata alongside RGB and receipt time. Test the actual PushBack/backfill adapter. Retained lines may have plain native channel/name prefixes without player hyperlinks; formatting must cover those while preserving bodies and General context.

- Empty room states must have one explanatory owner: remove duplicate wording without removing established panes or transcript history; retain read-only history distinctly, and avoid enlarging small action artwork into hero illustrations. Shared room descriptors own roster/caption availability; shared action capabilities disable unavailable controls.

- Party/Raid native subscriptions must include ordinary and leader categories, and repair existing saved windows. Archive previous group logs before resetting live sessions; never use the live receiving frame as an archive viewer. Read-only transcripts use the shared MessageLine renderer with explicit ownership, wrapping, timestamps and native links. Disabling recording must preserve existing archives. Keep per-character archive limits documented and tested.

- Release channel must be explicit and agree with the version suffix: alpha.N -> Alpha, beta.N/rc.N -> Beta, bare version -> Release. Reject mismatches/unknown suffixes before upload. GitHub draft/prerelease status does not set the CurseForge file type. Preserve published tags and check for an existing file before retrying an uncertain upload.

- Renderer reflow owns readback preservation. Keep the current message and offset through layout, including unread state. An adapter must never jump to the latest message and reconstruct readback afterward. A detached size notification may update only the renderer currently bound to its container.

- In-game practice uses private session owners for samples, input, geometry and history. Keep them outside native chat registration and saved stores. New practice scenarios share their timeline with the regression harness and must leave the live editor, rooms and real data intact, including real events received during playback.
