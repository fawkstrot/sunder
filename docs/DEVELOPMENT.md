# Development workflow

The Git root is the existing Sunder folder. The installable package is `addon/Sunder/`, with `Sunder.toc` directly inside it. Do not move the repository itself into AddOns.

Use Python 3.11+ and the pinned development requirements. The local `.venv` is already prepared on this machine. Windows commands are in the root README; macOS/Linux use `.venv/bin/python`.

## Change → check → deploy → observe

1. Create a task branch from the intended base and inspect existing changes.
2. Edit production code under `addon/Sunder/`, with focused regressions under `tests/`.
3. Run `python tools/sunder.py test`. It checks all shipping Lua under Lua 5.1, manifest/XML resources, assets and the behavior suites. The runner supplies `SUNDER_ADDON_ROOT` and isolates historical fixture paths under `tests/regression/`.
4. Run `python tools/sunder.py deploy --dry-run` to verify the destination. Run `deploy` to install the checked source and migration loader, backing up existing folders before replacement. No test or deployment command reads or rewrites account SavedVariables.
5. Restart WoW for the initial folder rebrand. Later Lua-only changes can use `/reload`. New textures or changed client discovery may require a restart.
6. Observe the actual behavior in-game and record what passed. Do not confuse native-client tests with the mocked regression suite.

## Recovery

`python tools/sunder.py rollback` restores the most recent recorded addon-folder backup. `rollback --backup ".local/backups/<id>"` selects another. This does not roll back saved settings/messages. Keep backups private. A failed deployment automatically restores the affected addon folders.

`python tools/sunder.py package` creates deterministic ZIPs and SHA-256 file hashes under ignored `dist/`. CI tests and builds the same artifacts. Publishing is a separate deliberate step.

## Historical fixtures

The regression suite was ported from the prior development workspace. Numeric suffixes identify feature milestones; tests run against this repository's current code, not historical installed files. Tests must not mutate production code. Native Blizzard UI source fixtures are included only for behavioral compatibility tests, not shipped in the addon ZIP.

## Local UI preview loop

Use the existing backed-up deployment command for each preview. It copies the current working tree, so a commit or release is not required. Run these from the repository root in PowerShell:

```powershell
.venv/Scripts/python.exe tools/sunder.py test
.venv/Scripts/python.exe tools/sunder.py deploy --dry-run
.venv/Scripts/python.exe tools/sunder.py deploy
```

The dry run and actual deployment each rerun the checks. The target is `C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns`. Deployment replaces only Sunder and the legacy metadata loader, backs up both folders, removes stale installed files and verifies source/installed hashes. Keep the installed folders as deployed copies; automatic file watching and direct installed-file edits bypass this checkpoint.

After deployment completes, run `/reload` in game when safe. Game interaction is performed only when authorized and safe; do not interrupt active gameplay. Existing folders with Lua/layout edits normally need only reload; newly discovered addon folders and cached texture changes may require restarting WoW. Use `rollback` followed by reload to restore the previous addon files; saved profile settings remain unchanged.

Content padding is shared by native chat, editors, Whispers conversations, people lists, previews and notification text. Its default and missing-value fallbacks are now 8 px (previously 12); a one-time settings migration changes saved 12 px values to 8 at the user's request. Other saved values are preserved, and later explicit selections of 12 remain valid. Adjust it under `/sunder` > Chat > Appearance > Content padding. Header spacing is controlled separately.

For every implementation task, update the dated context and relevant documentation with actual validation and deployment results. In-game review should check chat wrapping, editor growth, people lists, conversations, samples and notifications at narrow widths and larger fonts. Record live observations only after the user or agent actually sees them.

## Whispers selection and notification validation

Real queued toasters are retired when their conversation is displayed, even while scrolled back. Ordinary people-list selection must clear that person's waiting rows and retain other people's rows; minimizing restores notification eligibility. Select the intended conversation before expanding a minimized workspace so the previous selection does not get acknowledged during transition.

Toasters show the sender once in the heading and the message body beneath it. Preview-only normalization uses the client's localized incoming-whisper prefix and removes native presentation markup; original history, links, message text and exact-message jump tokens remain intact. Synthetic sample text is left as supplied.

An explicit conversation selection chooses its current layout editor (including a borrowed native reply editor) as the next native Enter destination, even when another chat editor owned focus. Non-chat fields keep their focus. Incoming messages never select or focus an editor by this change. No global native input functions are replaced.

Live regression checklist: receive whispers while minimized; click a person rather than a toaster; confirm only their rows clear; receive another while viewing their pane and while scrolled back; check a second visible workspace and detached conversation; switch from General to Whispers and press Enter on the first selection; repeat with a draft, /reply, a borrowed editor, and an unrelated search field. Confirm recipients and drafts before sending. Mocked checks do not prove native focus behavior in WoW Forever.

## Durable message history

See [Whispers history](WHISPER_HISTORY.md) for the archive model, limits, UI actions and live validation checklist. Conversation close now snapshots before native teardown; it is not a history deletion action. The standard test command includes the archive engine/search suite and archive people-list coverage. Keep account SavedVariables private; use synthetic fixtures for all automated history checks.

## Guild room and message-area preview

See [Guild Chat](GUILD_CHAT.md) for native-slot ownership, roster/public-note behavior, local recall limits and the live checklist. After deployment, reload and use `/sunder guild`; Control-left-click on the minimap button is an additional launcher. If the new module is not discovered, the command reports that a client restart is needed. The shared click fix also needs a blank-area/text-row > Enter check in General and Whispers. The CLI now includes the guild room/input suite and checks Guild Chat's standalone/Ellesmere settings paths. Tests use synthetic guild members and messages; never read or commit actual guild conversations, notes or account files for these checks.


Guild room styling correction: shared Whispers chrome is now the visual source of truth for both rooms. Validate the actual header/grip, collapse reversal, maximize/restore-size, compact member selection and scroll retention, plus one Ellesmere mover for the real Guild room root. Source geometry mocks alone did not catch the first version's unacceptable in-game presentation; record a post-reload visual check separately before calling the new appearance validated.

The Guild room visual review confirmed the shared shell in the live client and exposed duplicated startup notices that mocked geometry checks could not reveal. Regression now covers excluding native MOTD notices from recall while retaining repeated player messages; interaction checks must still be distinguished from read-only visual observation.

Room review must include Guild and Whispers together: sidebar/transcript separation, perimeter/header rules, scroll indicators, compact widths, large-font bounds, collapse cancellation and native editor routing. User-authorized game control can exercise reload and local UI controls, but never send test messages to real players. Record live observations separately from mocked coverage.

### Title movement and layered surfaces validation

For Guild and Whispers, drag the title text and blank title bar, toggle the position lock and confirm title/grip/unlock-overlay movement is blocked, then unlock and retry. Reload to check lock persistence. In All/Unread/Favorites, confirm the full-width filter row sits above both columns, with sidebar tint/divider/scroll area below it. Compare native chat, Whispers and Guild at nonzero and zero background opacity: continuous backing plus horizontal edge fades, full-opacity text, no black top gradient. Check minimized/restored windows and large fonts.


Validation: drag Guild and Whispers title text and blank header; toggle position lock and verify grip/title/overlay cannot move it. Reload for lock persistence. Check filter row above both columns, large fonts, minimize/restore, and layered background/fades at zero and nonzero opacity in native chat and both rooms.


### Shared window controls and Guild unread validation

Undock Combat Log and another native chat tab; verify header/title and move-control dragging without global edit mode, per-window lock, corner resize, settings deep link, redocking and repeated undocking without duplicate controls. Preserve combat filters and native tab context menus. Main dock: move/lock/settings, tabs scroll/overflow clear of actions, collapse to header, maximize and exact size/anchor restore. Check protected movement defers/refuses in combat. Guild: collapse upward/downward, repeated restore, locked movement, minimized incoming count and badge-click restoration; expanded visible incoming messages and own messages do not count. Reload retains geometry/locks but resets session unread. Confirm no toasters or focus stealing. Automated fixture checks do not establish native-client visual/protected behavior.


Drag regression follow-up: test header/grip movement with edit mode OFF and its overlay hidden. While holding the mouse, verify the entire header, body, messages and editor track together; release must preserve the position without a jump, and the drag driver must stop. Repeat with main chat, Combat Log, Guild and Whispers, then lock and retry. Check left grip/tab spacing and tab overflow at narrow widths. Main chat uses native movement of its visible root and reattaches to the saved mover anchor only at completion.


### Common window surface contract

Components/WindowManager.lua owns the visual surface, action/grip primitives, lock policy and drag driver. Main and native detached containers register through RegisterNativeSurface; Guild/Whispers provide header/body/sidebar geometry through ApplySurface. No independent body-gradient renderer should be added to a feature module. Native tab/header layers follow the root; the left grip is above the scrolling tab strip.

Check all four window types together after reload: one-pixel outlines, header separation, continuous backing with one full-width fade, matching configured colors, no separate column gradients, left grip always clear of tabs, and right action clearance. Repeat at zero opacity, narrow width, large font, collapse/restore, resize, dock/undock and renderer reuse. Distinguish live visual review from fixtures.


### Window lifecycle and repaint audit

Regression coverage now checks mid-drag hiding (driver and callbacks retired), repeated unchanged surface updates (no gradient repaint), mutable color changes, resize invalidation, irrelevant config events and retirement of legacy separators. Include those cases when extending a new window adapter. Guild supplies sidebar geometry in one shared appearance call; avoid repainting first without a sidebar and then again with one. Native controls refresh styling/lock state on relevant appearance changes. Actual live review of hiding during drag, large-font control layout, client protected behavior and screen-edge geometry remains required.


### Native bounds, resizers and docking

Main and detached native windows use the shared corner-resizer factory; verify resizing outside global edit mode. Native message viewport updates report vertical overflow and closed-editor reusable space to the surface; check both blank and full panes, active/closed editor, scrolling and resizing for text outside the outline. The corner grip follows the extended surface. Undocked native headers provide Return to General/main tabs; verify it redocks and selects without changing combat filters. Unmapped native settings buttons are omitted. Test actual saved-person and active-person favorite buttons, section expansion, Favorites filtering and unfavorite/reload persistence.

2026-11-12 live validation: native return-to-main/dock persistence, General standard resize and restored geometry, body bounds without animation buffer, absent unmapped detached cog, and saved-person favorite/unfavorite section refresh were observed in WoW Forever. Final deployed build was reloaded; no test messages sent.


### Toggle and unread verification

Rebuild selected textures with tools/build_action_states.py; originals remain preserved. Check star/pin/lock outline versus fill before hover, during hover and after leave, including theme refresh and recycled rows. Name rows now have a 24 px/font+10 minimum plus 1 px gap. Verify name text and unread pills do not overlap. Header numbers show unread totals in expanded and minimized state; conversation totals remain in the tooltip. Test zero unread with multiple open conversations, incoming hidden-person counts, selected reading clearing, scrolled-back retention, 99+ overflow, unread filter emptiness and sample/real badge parity. Samples are session-only and must be cleared afterward.

Guild downward-collapse validation: assert full height and stable top anchor before the first tick, intermediate height during animation, final bottom anchoring, interruption/restore and idle-driver cleanup. Compare zero/unread indicator icon and text colors against Whispers.


Guild downward-collapse validation: full height and top anchor before first tick; intermediate height; final bottom anchoring; interruption/restore and idle cleanup. Compare zero/unread icon and text colors with Whispers.


Resize validation: main dimensions arrive through settings broadcasts; detached/room dimensions arrive through SetLayout. Both use RefreshLayoutGeometry. Check repeated width/height changes before draining the render queue, scrollbar bounds, pending reflow retention and unchanged readback position. Geometry is immediate; history reflow remains coalesced.


## Semantic window control audit - 2026-11-12

WindowManager.windowActions owns command icons/default tooltips; CreateWindowAction supplies per-host callbacks, LayoutHeaderActions owns right-to-left order and spacing for native and room headers and RefreshRoomActions reflects current maximize/collapse/toggle state. Guild and Whispers share ToggleMaximized and CollapseToward. Native settings/docking opt into applicable capabilities; main chat exposes collapse and maximize controls. Each symbol has one meaning: menu, maximize, restore size, roster, dock-to-main, collapse up/down. Action feedback clears on hide and honors disabled state. Normal resize hover belongs to the manager.

Validation exercises both room hosts, original-size restoration, directional restore glyphs/tooltips, no pre-fade body blink, disabled hover and recycled pressed state. Existing input, renderer, favorites/history, native docking/edit-mode and resize coverage remains required. Rebuild semantic action artwork with tools/build_action_states.py.


## Surface and header parity validation - 2026-11-12

Standard test now includes the complete test_global_appearance.py entry point (previous settings fixture intentionally used only its schema prefix). Nine behavior entry points cover selected/idle/hover title glyphs, per-tab overrides and native identity, surface fade/clipping geometry, roster click refresh and counter anchors. Collapse regression samples actual bodyFrame height and opacity at 40 ms for both Guild and Whispers before completion. Root-height-only checks missed the Guild-specific stationary full-height surface. Verify native and room idle glyphs side by side and toggle roster off/on without leaving the button.

Opaque-collapse regression (2026-11-12): sample both hosts every 20 ms through top and bottom collapse/restore. Require shown, full-alpha body backing and clipped content, exact moving surface height, active people viewport below the 32 px filter row, and final visibility/driver cleanup. Live acceptance: backing and text remain within the shrinking area throughout; no border-only interval, list disappearance, header jump or idle driver. Automated samples are not a substitute for live smoothness observation.

Opaque-collapse regression (2026-11-12): sample both hosts every 20 ms through top and bottom collapse/restore. Require shown, full-alpha backing and clipped content, exact moving surface height, active people viewport below the 32 px filter row, and final visibility/driver cleanup. Live acceptance: backing and text remain within the shrinking area throughout; no border-only interval, list disappearance or header jump. Automated samples do not establish live smoothness.

Validation (2026-11-13): check Guild at 760, 500 and 340 px widths; roster stays bounded and hide/show works at narrow width. At large font and 120 px height, Show members restores enough height. Verify body presentation is delegated to WindowManager and retain both-host clipped animation regressions. Live acceptance after reload: name-fit roster, readable transcript and working header/strip toggle at small sizes.

2026-11-13 scroll/empty-state validation: regression asserts Guild overflow rail visibility/layer, drag-to-scroll mapping and passive track for fitting roster. Verify live at enough members to overflow, scroll top/bottom, resize until fitting, hide/show roster. Whispers empty body reads No conversation selected / Select a conversation to view its messages; confirm with no selection and after close/archive. Automated checks do not establish live visual appearance.

Empty-state copy correction (2026-11-13): exact copy assertion now requires “No conversation selected.” followed by “Select a conversation to view its messages.” Sentence case and punctuation match ordinary UI copy.

2026-11-13 geometry regression: assert Guild viewport bottom/right insets are zero and compare actual Guild rail anchors/dimensions with the shared layout helper used by Whispers. Live check: fitting and overflowing rosters have no extra strip before the column divider; row text/reply controls stay clear of the rail.

2026-11-13 validation: regression checks 5/13 roster header text, count-aware action width and icon placement after press/release; renderer-owned row widths at 220 and 140 px and scrollbar clearance at zero padding. Existing wrapping/renderer/resize suite retained. Live acceptance: long Guild and Whispers messages rewrap when shrinking, retain links and stay left of scrollbar; roster count remains visible with roster hidden/minimized and updates on guild presence changes.

2026-11-13 recovery validation: simulate empty character Guild state with an existing native Guild window. Assert reuse, shown shell/member pane and no extra native slot. Repeat with native frame hidden but replacement visible; reject mixed filters, ambiguous matches and closed slots. Packaging check now rejects Bindings.xml in TOC and repeated binding headers; package must still include the automatically loaded binding file. After safe reload verify actual roster/actions/count return and XML warnings disappear.

2026-11-13 person-detail checks: verify formatting such as 34 · Mage, smaller explicit font even under native font inheritance, muted alpha/class color, fixed available width, unknown-row recycling, passive friend API lookup and preserved Guild rank/public notes within row height. Standard renderer/history/input suites remain required. Live acceptance: compare both lists at normal/narrow width and large font, saved favorites/archived/live/sample rows, offline dimming, selection/unread controls and scrollbar clearance. No active inspect or /who is requested. Unknown levels remain absent.

2026-11-13 validation: verify larger Guild name and caption MOTD/empty state; live and backfilled MOTD excluded from Guild transcript while ordinary chat remains. Own-line tests cover native line IDs, structured sender links, incoming/quoted-other sender exclusion, protected values, opt-out/color and bounded 256-ID cache. Resize tests cover locked start and lock-during-drag cancellation; real Guild normal/edit handles and Ellesmere registered width callback reject locked changes. Whispers row regression now asserts top anchor and explicit text height, plus recycling to centered unknown state. Conversation-message vertical behavior is unchanged per user clarification. Live acceptance still needs safe reload.

Live read-only review after user reload (2026-11-13): confirmed Guild title/MOTD caption, clean Guild transcript footer and Whispers saved-row name/detail alignment. Member metadata and header count remained present. Own-message tint and locked resize cancellation were not exercised interactively during this review; refer to their regression checks, not this capture, for evidence.

2026-11-13 Guild Info validation: checks two-line row height/separators; Online/Zone/Favorites including offline favorites; overview class summary and selected feedback; member rank/public note; no automatic whisper; explicit whisper/invite routing and combat/offline guards; wide side-by-side drawer and narrow replacement; close restores chat/caption. Existing native renderer, history, input, resize/collapse, character recovery and migration suites remain mandatory. Live acceptance after safe reload: open Info, select/back/close a card, scroll long info, exercise filters, inspect compact separators at normal/narrow/large-font widths. Do not send invites/messages for visual QA.

Live overview review (2026-11-13): user-opened narrow Guild Info showed total/online, guild name/rank, MOTD and class breakdown without visible overlap. Roster was hidden, so row/filter/member-card appearance still requires expanded-roster live review. No player actions were submitted.

2026-11-13 shared person-row validation: standard suite passes selection/unselection geometry, fixed name height, smaller details, right-side inactive controls, filled state, badge clearance, recycled-pointer identity protection and priority ordering. Guild coverage includes scoped favorite/pin sorting and minimized roster-action restore/reveal. Whispers coverage includes mixed live/closed flat ordering, saved-contact actions without archived messages, preview identity/refresh, filter compatibility and selection stability. Existing history, renderer, collapse, input, migration and release checks retained. Live acceptance after safe reload: compare both lists, hover/toggle right actions without selecting first, select different rows, inspect unread clearance and restore Guild through its minimized member count. Automated fixtures do not establish live visual appearance.

Live read-only review after user reload (2026-11-13): both Guild roster and Whispers people list were visible. Confirmed compact two-line name/level-class rows, matching right-side outline pin/star controls on unselected rows, subtle separators and clear list-edge rail separation. Name/details remained together without bottom-alignment overflow. Guild showed five roster members and matching 5/12 header metadata; Whispers showed one contact and a zero unread count. No Lua error dialog visible. No row selection, favorite/pin toggle, unread arrival, overflow scroll or minimized restore was exercised; those remain regression evidence rather than live interaction verification. No game input, messages, invites or personal screenshots saved.

2026-11-13 separator spacing correction: user reported the visible text was closer to the separator above the next row. Previous read-only review did not catch this optical imbalance. Shared person rows now raise the name/detail block by 2 px to compensate native line-box leading and give the lower text more clearance. Unknown single-line names receive the same optical offset. Whispers no longer adds an extra 1 px between rows; both lists use the shared height as their stride. Row height, text size and action geometry remain compact. Regression assertions cover the shared stride, optical offset, lower clearance and selection-cycle stability. Visual balance requires safe reload confirmation. Whispers background-color request was truncated; clarification is pending and no color change is inferred.

User clarified the Whispers idle background is the desired reference for Guild. Both already had identical sidebar tint, but a full-window gradient underneath varied the apparent list color with window/sidebar width. Shared surfaces now keep the fade in the transcript and compose a uniform dark sidebar backing at the existing full-strength fade opacity. Both lists inherit it, with zero-opacity appearance preserved and selected/unread accents unchanged. Regression covers identical sidebar alpha across resize, fade boundary and transparent setting. This replaces the pending background clarification above.

2026-11-14 deployment: dry run and actual deployment passed the full suite; installed hashes verified. Backup .local/backups/20261114T080125126078Z; SavedVariables untouched. Whitespace check passed. Requested safe reload for live optical-spacing/background review. No game input, commit, version change or publication.

2026-11-14 read-only post-reload review: both lists visible with multiple people. Guild and Whispers name/detail blocks now have visually more balanced clearance around the separators; no bottom-aligned text or separator overlap visible. Both idle columns show the shared uniform dark backing, while the transcript retains its fade. Right-side controls remain clear of text/rail. Different world scenery still shows through the intentionally translucent backing, so pixel-identical screen colors are not expected. No Lua error dialog visible. No game input, messages, state toggles or personal capture saved; live resize/unread interactions were not exercised.

2026-11-14 inactive person actions: shared row favorite/pin icons now use 35% idle opacity (previously 70%) in Guild and Whispers. Hover and filled active states retain full emphasis; hit areas and behavior unchanged. Standard validation/deployment follows; this opacity revision has not been observed live.

2026-11-14 dim-icon validation/deployment: full standard suite, dry run and deploy passed; installed hashes verified. Backup .local/backups/20261114T083705590946Z. SavedVariables untouched. Live opacity appearance pending safe /reload. No game input or publication.

## Contact identity persistence and protected bag use/movement — 2026-11-14

Root cause of older Whispers losing level/class: only history persisted, while friend metadata/message class maps were session-only and friend refresh cleared its snapshot. Added bounded 200-contact per-character last-known identity, merging only valid class/level fields; zero/missing values preserve previous data. Fresh guild/friend/message observations teach it, active/closed row name tint now uses the same lookup. No presence/public notes saved; no inspect/who. Already lost unknown details need relearning from client data.

User requested usable/movable protected items. Added capability-checked same-call explicit bag use/pickup adapters: release only involved owned GUIDs, call original, immediately relock source/cursor/placement by physical identity even after an action error. Merchant/trade/mail/auction contexts retain native locks; close those panels before use/move. Missing GUID APIs keep strict mode. Existing bank-only sorting exception remains separate; bulk bag sort never unlocks. New native cursor/use behavior, secure/taint/combat and sale/trade/delete coverage are NOT live verified. Private native references/action-bar use may remain blocked. Tests cover history metadata retention/zero merge/cap, use/error/cursor/placement/foreign locks/context exclusions/returns and public adapter teardown. Initial full suite passed; final validation/deployment follows. No game item interactions or SavedVariables file edits.

2026-11-14 final validation/deployment: full suite passed, followed by passing dry run and deploy-time full suite. Installed hashes verified; backup .local/backups/20261114T180101309194Z. SavedVariables files untouched. Whitespace check passed. Requested safe reload and expendable-item use/move test; actual secure/cursor/disposal behavior remains unverified. No item operations, messages, game input or publication performed.

## Protection regression containment — 2026-11-14

User confirmed experimental movement worked but protected items could also be destroyed. Removed the entire bag use/pickup unlock adapter and its startup/teardown hooks; restored strict-lock tooltip/settings/probe wording. Previous mock success did not establish native cursor protection; this is a live failure, not successful disposal validation. Replaced adapter-specific tests with a regression that GUID API availability must never install use/pickup wrappers. Existing native lock/foreign-owner/stale-slot/bank-sort checks remain. Contact identity persistence is retained. Durable guide now prohibits the rejected cursor-unlock approach. Final full validation/deployment follows. Selective use/move plus disposal protection is unresolved; current priority is restoring strict safety.

2026-11-14 containment deployed: standard suite, dry run and deploy-time full suite passed; installed hashes verified. Backup .local/backups/20261114T180454491998Z. SavedVariables files untouched; whitespace check passed. The unsafe session requires /reload to remove its wrappers. Strict-lock behavior after this reload has not yet been observed live. No game item interactions or publication.

## Alternative disposal protection research and isolated preview — 2026-11-14

User requested investigation beyond native locks. Read GudaBags and JustItemLocker source, Forever Item/Cursor API definitions and native deletion-dialog code. GudaBags uses merchant/spell overlays and delete confirmation cancellation keyed by itemID; JustItemLocker uses blanket native GUID locks. Found C_Cursor.GetCursorItem returning exact ItemLocation and native GUID-based delete dialogs. Research files are ignored .local copies, never executed or shipped. Production implementation is original.

Added ItemProtectionDisposal.lua with explicit per-copy disposal-preview mode; all existing records remain strict without migration or global setting change. It never wraps pickup or unlocks around use. Guards cover exported GUID/cursor delete, native deletion event/popups, vendor/cursor trade/mail paths, targeted use, synchronous context native locks, conservative trade acceptance and missing-hook strict fallback. Required capabilities checked before opting in. Settings add selected-test-copy preview toggle and honest unverified wording. Native secure paths/private references/event order/cursor behavior remain unverified. This is an isolated experiment, not a claimed universal replacement.

Regression covers strict startup with no guard installation, explicit opt-in, native ordinary-use routing/returns, identical-type independent copies, delete APIs/cursor/popup/event, vendor enter/exit locks, targeted-use guard, conservative trade acceptance, lost-hook strict fallback and owned teardown. Full standard suite passed: nine behavior entry points, migration/workflow/seven release tests, Lua/124 resources and binding validation. Deployment follows; no game input, item operations or saved-account-file edits. Actual live testing remains required on an expendable copy.

Final disposal-preview cleanup: opting the last copy back into strict locking or unprotecting it removes owned guards immediately; no preview API wrappers remain installed unnecessarily. Regression asserts opt-out restores original use API and native lock.

2026-11-14 final disposal-preview deployment: full standard suite, final dry run and deploy-time full suite passed (nine behavior entry points, migration/workflow/seven release tests, Lua/124 resources and bindings). Installed hashes verified; backup .local/backups/20261114T182608037898Z. SavedVariables files untouched. Existing records remain strict; no item was opted into preview by the agent. Guard opt-out cleanup and staged-in-bag trade checks included. Live testing requested on one expendable copy; no item operations/game input, commit, version bump or publication performed.

## Filter-tab display correction and experimental-controls removal — 2026-11-14

User screenshots showed differing filter selection/background presentation. Found 26 px filter buttons in a 32 px row (active underline 6 px above baseline), plus the transcript gradient starting beside the sidebar and painting only part of the full-width filter row. Buttons now fill the row, use pixel-aligned thirds and explicit centered label heights; transcript fade starts below the row. Hidden/left/released tabs clear pressed/hover state and restyle through one path. Added geometry/selection/hide-cycle and surface-boundary regressions.

User explicitly requested removing testing features while retaining item locks. Removed ItemProtectionDisposal.lua/TOC entry, its mode handling and settings, and user-facing pickup-test controls. Existing strict per-copy locking, saved intent, quick lock controls and identity/history improvements remain. Retired preview-specific tests with the retired feature; added checks that standard settings remain, developer controls are absent and legacy preview mode markers cannot weaken native locks. Historical research is retained only in documentation. Final standard validation/deployment follows; screenshots supplied by user are pre-fix evidence, not live confirmation of this build.

2026-11-14 final filter/controls deployment: full standard suite, dry run and deploy-time suite passed (nine behavior entry points, migration/workflow/seven release tests, Lua/123 resources plus bindings). Installed hashes verified; backup .local/backups/20261114T210413736923Z. Removed experimental module is absent from install manifest; existing protected GUIDs stay strictly locked, including records with inert old preview markers. SavedVariables files untouched. Whitespace check passed. Live tab appearance requires safe /reload; no game input, test items, screenshots saved, version bump or publication.

## Shared Guild/Whispers favorites — 2026-11-14

User clarified stars represent the same person everywhere. Replaced guild-only favorite ownership with shared per-character whisperFavorites via SetPersonFavorite; live/saved Whispers stars and Guild rows/cards use the same mutation. It updates open records, archive flags and startup snapshots, then refreshes both views without opening a native conversation or changing unread/input. Guild stars teach known member class/level for the saved contact. One-time merge imports existing guild-only favorites before guild-change reset and removes the old preference source; personal favorites survive guild changes. Guild pins, Battle.net identity and session-only sample favorites retain their existing scope.

Regression checks both directions, saved contact display without opening conversation, live record/archive/checkpoint unstar consistency, legacy migration idempotence and guild-change retention. Full standard suite passed all nine behavior entry points plus migration/workflow/seven release tests, Lua/123 resources and binding checks. Final dry run/deployment follows; live star interaction has not been observed for this revision. No game messages/input or SavedVariables file edits.

Migration also unions pre-existing character favorites saved only in archive/open-tab checkpoints once (sharedPersonFavoritesMigrated), before any shared mutation. This prevents an old Whispers-only favorite from remaining invisible to Guild, without repeatedly resurrecting a later unstar. Battle.net checkpoint entries are excluded from character-name contact migration. Added archive-only migration/idempotence regression.

2026-11-14 shared-favorites final validation/deployment: standard suite, final dry run and deploy-time full suite passed (nine behavior entry points, workflow/migration/seven release tests, Lua/123 resources and bindings). Installed hashes verified; backup .local/backups/20261114T211324204554Z. SavedVariables files untouched. Whitespace check passed. Safe /reload activates shared state/migration; no live interaction verification for this revision, game input, messages, version bump or publication.

## Party/Raid room and reusable room controller — 2026-11-14

User requested a party room matching all shared window behavior; confirmed manual opening/remember state and one room following raids. Added PartyChat with manual default, /sunder party and /sunder raid, Chat settings page, compact role/leader/class/level/connectivity roster, passive ready-check/instance caption, shared person favorites/pins, no toasters and matching header unread. Solo/left group is read-only. Different groups get clean transcripts/drafts; bounded recent recall uses roster fingerprints for conservative same-group replay. Native editor/channel/geometry changes defer in combat; automatic opening never owns input.

Extracted actual Guild shell/roster/layout/native recovery/state restoration/recent recall into Components/RosterRoom.lua and registered both controllers through WindowManager. UIManager layout/input/close, renderer saves, cross-view favorites and Ellesmere room movers use registry routing; parked native slots do not get duplicate movers. Shared empty-state creation also serves Whispers. Existing Guild behavior suite passes after extraction. Native room roots now start hidden so settings do not open a manual room.

Added test_party_chat.py to the standard CLI (ten behavior entry points). Regressions cover solo and manual/default/optional auto opening, editor ownership, party/raid/instance routing, offline/role data, virtualized raid rows, shared favorites, unread/own messages, minimized roster restore, new-group isolation, combat deferral, ready checks, bounded replay, partial roster startup, orphan native recovery, closed/minimized restore and actual-root mover registration. Full suite passed through final manual-default/hidden-root refinement; final deployment follows. No game input/messages/group actions, SavedVariables file edits or personal screenshots. Native visual/secure party/raid/instance checks remain pending safe reload. No release/version change requested.

2026-11-14 final Party Chat validation/deployment: standard suite, dry run and deploy-time full suite passed (ten behavior entry points plus migration/workflow/seven release tests, Lua/125 manifest resources and auto-loaded bindings). Installed hashes verified; backup .local/backups/20261114T221419690681Z. SavedVariables files untouched; whitespace check passed. User preferences applied: manual default, remember window state, follow raids. Native Party/raid/instance visual and secure editor review remains pending safe /reload. No game input/messages/invites/group-management actions, personal captures, commit, version bump or publication.

## Automatic Party Chat default and state preservation — 2026-11-14

User clarified automatic joining behavior is desired, with manual-only optional and remembered state. Default autoOpen is now true; settings expose Open manually only. A versioned one-time correction enables automatic behavior for the earlier implicit false default/current party, while an explicit-configured marker preserves future manual-only choices. Automatic Open now captures/reapplies minimized state instead of always expanding, leaves body hidden when collapsed, keeps full-size geometry and avoids editor ownership changes. Explicit /sunder party still restores/opens intentionally. Ordinary roster refresh does not reopen a manually closed current-party room.

Added regressions for default and old-default migration, already-grouped opening, manual-only retention and joining suppression, minimized/body/geometry preservation and no input selection. Standard suite passed all ten behavior entry points plus migration/workflow/seven release tests, Lua/125 resources and bindings. Final dry run/deployment follows; actual in-game auto-open appearance remains pending safe reload. No game input/messages or SavedVariables file edits.

2026-11-14 automatic-default correction deployed: full standard suite, dry run and deploy-time suite passed (ten behavior entry points, migration/workflow/seven release tests, Lua/125 resources and bindings). Installed hashes verified; backup .local/backups/20261114T222205968683Z. SavedVariables files untouched; whitespace check passed. Pending safe /reload to activate the current-party migration and visually confirm automatic/minimized state. No game input, messages or publication.

2026-11-14 live read-only Party Chat review after user reload: expanded room visible with three actual members and matching 3/3 header/3 online roster. Observed compact class/level rows, leader/role caption, aligned shared header actions, sidebar divider/rail, background/fade and native party message lines without visible caption/control overlap. A filled favorite for the same person was visible in Party, Guild and Whispers concurrently. Expanded unread count was zero; no Lua error dialog visible. This observation does not verify automatic opening, minimized state persistence, raid/instance conversion, secure input/Enter, new-group isolation or unread transitions. No game input/messages/group actions, personal saved screenshots or source changes. Recorded in context/development validation only.

## Shared wrapping contract, raid-only search and contact-only favorites — 2026-11-14

User supplied clipped Party quest lines and empty/new favorite screenshots. Root cause: MessageLine used a parent-depth assumption that skipped the native viewport, then fell back to General width. Previous isolated width tests reproduced the wrong two-level tree. Replaced inference/fallback with explicit renderer ownership required at pool/row construction and used for all row geometry/background/clearance. Measurement and visible FontStrings share wrapping/non-space/unlimited line policy. Actual native InitializeScrollFrame plus real row pool integration now covers viewport hierarchy, narrow width/height growth, reuse and rejection of missing owners. Native visual confirmation remains required; the prior live capture did not verify long-message wrapping.

Shared roster descriptor now shows search for raids only in Party, retaining Guild search, reclaiming hidden space and clearing raid query. User clarified contact-only favorites belong only in Favorites until chatting. All excludes empty contacts/archives; first real message promotes them. Empty selected contacts get a meaningful conversation state rather than a blank pane. Known name casing is retained in passive metadata. Established locks and unrelated data remain unchanged. Documentation and durable contract updated; final suite/deployment follows. No actual conversations/account files read by tests, game input/messages or personal captures saved.

Validation note: native row-factory integration required extending the lightweight harness with native draw-layer/font-string methods; production renderer/pool initialization and geometry are exercised, while glyph measurement remains simulated. Full suite passed after these fixture corrections. Live wrapping/clickable-link checks remain separate.

2026-11-14 final wrapping/contact/search deployment: standard suite, dry run and deploy-time full suite passed (ten behavior entry points, migration/workflow/seven release tests, Lua/125 resources and bindings). Installed hashes verified; backup .local/backups/20261114T230746638711Z. SavedVariables files untouched; whitespace check passed. Hard owner contract and actual viewport/pool regression included. User-confirmed contact-only Favorites policy applied. Requested safe reload with narrow Party/long linked messages and Favorites visible for native review; no live verification of this revision yet, game input/messages, personal screenshots saved or publication.

2026-11-14 live read-only wrapping/search/contact review after user reload: narrow Party room visibly wraps both long linked quest messages onto continuation lines within the transcript boundary, with right-edge clearance. Party search is absent and roster rows occupy the reclaimed space; Guild search remains visible. Whispers was on All, where the starred contact without conversation history was absent, and its no-selection state was visible. No Lua error dialog visible. Favorites tab/contact selection and the selected-empty state were not displayed, so those remain automated coverage rather than live verification. No game input was sent during active gameplay; no screenshots saved, messages sent or source changes made. Existing full-suite/deployment results above remain applicable; this update records observation only.


## Party duplication, player actions and input lifecycle - 2026-11-14

General suppresses group-chat copies while the enabled Party/Raid room is actually open, including minimized. This side-effect-free per-frame filter leaves saved subscriptions, dedicated-room delivery, unrelated tabs and unread handling intact; closing/disabling restores General delivery. UIManager input release returns Enter to General when the selected room closes or becomes read-only, clearing only that room's focus and preserving its draft.

WindowManager owns Inspect resolution/availability across Guild/Party roster, active/saved Whispers and Sunder player-link menus. Existing native Inspect entries are retained without duplication. Existing player/target/focus/mouseover/party/raid units are resolved by exact case-insensitive name; range, connectivity, combat and identity are rechecked on click. No targeting or background inspection. Shared name styling dims known-offline Whispers to roster .45 alpha; unknown presence stays normal. Current group presence refreshes visible Whispers through the coalesced metadata path.

Added regressions for expanded/minimized/closed/disabled suppression, unaffected other tabs/dedicated delivery, draft preservation/input fallback, Inspect availability/stale identity and offline/recycled row opacity. Full validation/deployment follows. Native menu interaction, actual event suppression and offline transitions still require safe in-game validation.


2026-11-14 final group-routing/player-action validation and deployment: standard suite, deploy dry run and deploy-time full suite passed (ten behavior entry points, migration/workflow/seven release checks, Lua/125 resources and bindings). Installed files hash-verified; backup .local/backups/20261115T001152459674Z. SavedVariables untouched. Whitespace check passed. General's enabled message subscriptions are unchanged. Live delivery suppression, Inspect menu interaction/range and offline transitions remain pending safe reload; no game input/messages, personal screenshots, commit, version bump or publication.


2026-11-14 post-reload read-only review of group routing/player actions: Party room is expanded with four roster members and matching 4/4 header; linked message wrapping remains within transcript bounds and Party search remains absent. A Whispers identity row visibly uses subdued name/class detail treatment while another retains normal emphasis. No Lua error dialog visible. No player menu or confirmed live offline transition was displayed. Visible Party transcript includes retained history, so absence of matching lines in General does not establish fresh-event suppression. Expanded/minimized/closed routing, Inspect invocation/range and input fallback remain automated-only pending actual interaction/event checks. No game input or messages sent; no screenshots saved. Documentation-only update; existing passing suite/deployment remains applicable.


## Shared people sidebar minimum - 2026-11-14

User requested Guild-sized minimum across Whispers/Party/Guild. Existing SidebarWidth math was shared but callers supplied inconsistent floors (Whispers 140, roster rooms 124), reserves and caps. Added WindowManager.PeopleSidebarWidth as the single expanded-list policy: 190 px minimum matching Guild default, shared 220 px transcript reserve, 220 px default cap. Truly narrow windows may shrink below the floor to preserve message space; explicit hidden/compact rosters remain compact. Existing room maximum preference is honored above the common floor; legacy smaller maxima cannot defeat it. Whispers keeps proportional growth above the floor; rooms retain measured-name growth within their configured maximum. Guild width control now reflects 190-220 valid range without rewriting saved values.

Audit confirmed shared LayoutPersonRow, favorite/pin state controls, offline name/detail styling and list indicator helpers remain in use. Added regressions for minimum, maximum, narrow-window reserve, legacy caps and actual Guild/Party/Whispers adapters. Updated earlier Whispers exact-width expectation for the requested new floor; existing narrow Guild behavior remains covered. Full suite/deployment follows; visual review of this revision pending safe reload.


2026-11-14 shared-sidebar final validation/deployment: full standard suite, deploy dry run and deploy-time suite passed (ten behavior entry points, migration/workflow/seven release checks, Lua/125 resources and bindings). Installed files verified; backup .local/backups/20261115T045434479847Z. SavedVariables untouched; whitespace check passed. Actual feature-adapter checks cover the common floor and narrow reserve. Safe reload required for visual confirmation; no game input/messages, personal captures, version bump or publication.


2026-11-14 post-reload shared-sidebar visual review: expanded Party, Whispers and Guild roots are stacked at comparable widths. All three visible people-list/transcript dividers align horizontally, confirming the common sidebar width in this layout. Names/class details remain inside their rows; right-side pin/favorite controls and subtle list rails are visible. Party/Guild message wrapping remains contained. Guild lower content is partially outside the capture/taskbar; no full-height scrolling or narrow-window interaction was tested. No Lua error dialog visible. Read-only observation only: no game input/messages or screenshots saved. Existing automated/deployment evidence remains applicable; recorded context/workflow validation without source changes.


## Shared people width reduced to 150 px - 2026-11-14

User found 190 too wide. WindowManager.PEOPLE_SIDEBAR_WIDTH=150 is now the sole expanded width for Whispers/Guild/Party, applied by PeopleSidebarWidth. This supersedes the previous minimum/preferred/max policy: proportional or measured-name growth no longer widens individual lists. Narrow roots retain the common 220 px message reserve and explicit compact/hidden roster behavior. Removed misleading per-feature percentage/maximum controls and unused roster-name measurement; old saved values are retained but inert. Updated exact-width and adapter regressions for 150 while retaining narrow-window coverage. Validation/deployment follows; live visual confirmation pending reload.


2026-11-14 shared 150 px width deployed: full standard suite, dry-run suite and deploy-time suite passed (ten behavior entry points, migration/workflow/seven release checks, Lua/125 resources and bindings). Installed hashes verified; backup .local/backups/20261115T062655335287Z. SavedVariables untouched; whitespace check passed. Sole width constant applies across all three lists; removed per-feature defaults/controls no longer compete. Native visual confirmation pending safe reload. No game input/messages, personal screenshots, version bump or publication.


## All-window timestamp option and icon-only person selection - 2026-11-14

Existing timestamps supported 12/24-hour formats but separate Whispers preferences and a native frame allowlist prevented one setting from covering every room/new slot. Added All chat windows (including Whispers) beside Show timestamps in Chat > Chat windows > Messages > Content & timestamps. Enabling it enables the master timestamp option and disables native timestamps to prevent duplicates; the shared processor uses global format/gray default for General, Guild, Party/Raid, Whispers and future slots. Existing per-window/Whispers preferences are retained when this opt-in is off. Global formats explicitly label 12/24-hour choices, with optional seconds. Color overrides remain user-owned; all-window mode still uses subdued gray when color override is off. Original receipt times/history text are preserved. Recognized native prefixes are removed locally before formatting. Sample conversations follow the same global scope/format and refresh on timestampDisplay.

Whisper toaster favorite badge now uses favorite-filled. Bounded visible toaster cache includes favorite state so existing queued rows update after starring. Shared WindowManager star/pin selection uses filled accent icons with no selected plate/native hover background; other actions (including lock) retain their existing treatment. Unselected hover feedback remains. Added real processor regressions for global scope, new Guild/Party slots, Whispers override, dim color, 12/24 format and master-off; toaster filled-state refresh and selected icon/no-plate hover regressions included. Full validation/deployment follows; actual settings/visual checks pending reload.


2026-11-14 timestamps/icon feedback deployed: standard suite, dry run and deploy-time full suite passed (ten behavior entry points, migration/workflow/seven release checks, Lua/125 resources and bindings). Installed hashes verified; backup .local/backups/20261115T063251383020Z. SavedVariables untouched; whitespace check passed. All-window scope is opt-in and existing defaults/preferences remain preserved. Whispers-specific timestamp controls are disabled while the shared all-window policy applies. Native settings/clock appearance/toaster hover verification remains pending safe reload; no game input/messages, screenshots saved, version bump or publication.


## All-chat timestamps active by default - 2026-11-14

User clarified timestamps should be active across all chat, not left as an opt-in. Defaults now enable master timestamps and all-window scope. A versioned one-time normalization applies this requested behavior to existing profiles; later off choices survive reload/profile normalization. The Show timestamps master switch suppresses shared timestamps in Whispers too, even when its older independent toggle is on. Sample view obeys the same master-off policy. Separate Whispers controls remain disabled while all-window scope owns the setting. Global 12/24-hour format and dim default stay unchanged. Added migration/idempotent-off regression and explicit master-off-vs-Whispers-legacy regression. Tests/deployment follow; no game input or SavedVariables file edits.


2026-11-14 all-chat timestamp default correction deployed: standard suite, dry run (including versioned default/off-retention regression) and deploy-time full suite passed: ten behavior entry points, migration/workflow/seven release checks, Lua/125 resources and bindings. Installed hashes verified; backup .local/backups/20261115T064912574440Z. SavedVariables files untouched; whitespace check passed. Safe reload applies the one-time all-window enabled policy; subsequent Show timestamps off persists. Actual native clock appearance remains pending reload observation. No game input/messages, personal captures, version bump or publication.


## Compact room and whisper message labels - 2026-11-14

User requested redundant channel/direction labels removed. TextProcessing.CompactMessageLabels is the single presentation adapter before timestamp/emoji formatting: dedicated Guild/Party/Raid/instance rooms drop their channel prefix, while General and unrelated frames retain context. Incoming character/Battle.net Whispers use clickable Name: message (display brackets removed); outgoing Whispers drop To [Name]: and retain existing native-direction dim reply styling/optional reply marker. Sample outgoing lines no longer prepend You. Native/history strings, sender metadata, receipt timestamps and link payloads remain untouched.

Matching uses anchored localized native CHAT_*_GET templates and native message type/direction plus registered room identity; it does not replace matching words in message bodies or system notices. Unsupported/unrecognized formats fall back unchanged. Regression covers character sender links/class colors, item links/body words, outgoing direction, localized sender wording, Guild/Party adapters, unchanged General channel context and notices. Full standard suite passed; final dry run/deployment follows. Native visual verification pending reload; no messages sent, game input or saved-data edits.


2026-11-14 compact-label deployment complete: full standard suite, dry run and deploy-time full suite passed (ten behavior entry points, migration/workflow/seven release checks, Lua/125 resources and bindings). Installed hashes verified; backup .local/backups/20261115T065542082590Z. SavedVariables files untouched; whitespace check passed. Native localized format/retained-line appearance remains pending safe reload observation; no game input/messages, screenshots saved, commit, version bump or publication.


## Native decorated-label follow-up - 2026-11-15

After user reload, read-only capture still showed channel tags in Party and Guild despite passing plain-template tests. Whispers had no selected conversation, so no whisper-label assertion was possible. Dim timestamps and contained wrapping were visible. The literal CHAT_*_GET matcher was insufficient for decorated/flattened channel headers. Added structured sender-header handling before native-template fallback: channel hyperlinks and recognized localized/plain channel labels are removed only before the first player link in a registered room with matching message type. Color codes, sender payload/display, message links/body and original history remain intact. Added colored hyperlink and flattened-color prefix fixtures; existing General/body/localization checks retained. Full validation/deployment follows; not claiming the revised native result until another reload. No game input/messages or screenshots saved.


2026-11-15 decorated-label revision deployed: standard suite, final dry run and deploy-time full suite passed (ten behavior entry points, migration/workflow/seven release checks, Lua/125 resources and bindings). Installed hashes verified; backup .local/backups/20261115T080229416773Z. SavedVariables untouched; whitespace check passed. Earlier native observation is recorded as a failed visual check, not success. Revised native labels and selected Whispers appearance remain pending another safe reload. No game input/messages, personal captures, version bump or publication.


## Late room binding invalidates cached transcript presentation - 2026-11-15

Second read-only post-reload check still showed Party/Guild tags; do not count decorated-prefix coverage as live success. Whispers again had no selected conversation. Source tracing found shared RosterRoom.SetLayout changed parent/geometry without requesting text reprocessing when an already-rendered native slot became a registered room. Retained rows could therefore keep the pre-registration General-style presentation despite the new formatter.

RosterRoom now records roomLabelOwner and calls RefreshLayout(true) once when binding a renderer to a room, then restores captured readback index/offset. ClearRoomLayout retires that marker. Ordinary repeated layouts/resizes do not reprocess all rows. Added actual Guild/Party adapter regression for late binding, one-time reprocessing, repeat-layout boundedness and scroll restoration; lightweight renderer fixture now supplies the existing native SetScrollPosition capability for non-bottom readback. Full validation/deployment follows. Native rendering remains pending another safe reload; no game input/messages or screenshots saved.


2026-11-15 late-room-binding correction deployed: standard suite, dry run and deploy-time full suite passed (ten behavior entry points, migration/workflow/seven release checks, Lua/125 resources and bindings). Installed files hash-verified; backup .local/backups/20261115T080702182028Z. SavedVariables untouched; whitespace check passed. Verified source SetLayout explicitly calls RefreshLayout(false), confirming geometry alone did not request reformatting. Shared binding now adds the one-time true refresh and restores readback. Native visual confirmation remains pending safe reload; earlier failed captures are not counted as passes. No game input/messages, personal captures, version bump or publication.


## Native plain prefixes and backfill metadata - 2026-11-15

User confirmed incoming Whispers simplified but outgoing and Party still wrong. Live local read-only /run diagnostic (user personally allowed the game's custom-script prompt) confirmed the retained Party type ID matched ChatTypeInfo.PARTY.id and no structured player hyperlink existed. No permission changed by the agent, messages sent to players, or personal text/screenshots saved. Earlier decorated-link fixtures and binding invalidation did not cover this native representation.

Added anchored plain/colored channel-prefix handling without requiring a sender hyperlink, restricted to matching message types in registered rooms. Source audit also found native historyBuffer.PushBack backfill dropped all metadata after RGB, including outgoing whisper type IDs. It now forwards type/access/line metadata from the native oldest-entry GetMessageInfo, with structured-entry fallback. The actual native adapter extraction regression verifies all three reach BackFillMessageAt. Existing formatter/general/body/link tests remain; new plain-native Party/Guild tests pass. Full standard suite passed. Deployment and native rendering recheck follow; do not mark prior failed previews as successes.


2026-11-15 native plain-prefix/metadata correction deployed: standard suite, dry run and deploy-time suite passed (ten behavior entry points, migration/workflow/seven release checks, Lua/125 resources and bindings). Installed files verified; backup .local/backups/20261115T084741203983Z. SavedVariables untouched; whitespace check passed. Live diagnostic established matching native Party ID and absence of a player link; actual post-fix rendered labels/outgoing dimming still require reload verification. Local diagnostic commands printed only local metadata; no player messages, permission changes by the agent, screenshots saved, version bump or publication.


## Restrained solo Party presentation - 2026-11-15

User screenshot showed redundant solo caption/subtitle plus a second empty-state instruction, empty member column and oversized inbox artwork. Party now supplies hasRoster/showCaption capabilities to shared RosterRoom. Solo without history hides the roster/divider/caption and uses the full body for one centered text-only state: Your next group starts here. / Join a party or raid to chat. A prior transcript instead remains visible under Previous group and one read-only explanation. Joining restores roster/caption without rewriting rosterShown or window geometry. Roster header control is disabled/unselected when no roster exists, through a shared per-action enabled callback. Shared surfaces consume zero hidden-sidebar width.

Shared CreateEmptyConversation now supports icon=false and uses a restrained 24 px default icon for other callers instead of 48 px magnification. Party uses text-only states for both solo and grouped-empty view. Tests cover solo suppression of redundant elements/icon, disabled/unselected roster action and normal group restoration; retained-history behavior stays covered. A prior late-binding fixture now restores its injected scroll state so subsequent lifecycle checks remain isolated. Full suite/dry run/deployment follow. Current live capture has Auction House/bags active and obscures Party, so no movement/reload was injected during that interaction; revised visuals not yet observed.


2026-11-15 solo-room polish deployed: standard suite, dry run and deploy-time suite passed (ten behavior entry points, migration/workflow/seven release checks, Lua/125 resources and bindings). Installed hashes verified; backup .local/backups/20261115T100318551798Z. SavedVariables untouched; whitespace check passed. Added full-width solo transcript assertion in final deploy-time suite. Visual review remains pending safe reload with Auction House/bags clear; no character movement or reload interrupted the observed interaction. No game messages, personal screenshots saved, version bump or publication.


## Solo layout correction - 2026-11-15

User rejected hiding the solo member/caption panes. Restored the established two-column layout; only duplicate central wording/artwork is suppressed. Prior session history must remain visible. Added a shared history-save guard and regression: an empty native slot cannot overwrite a nonempty same-session saved transcript. Intentional new-session resets still retire the store explicitly. Agent ran the authorized /reload and observed the rejected full-width state; this is not accepted visual validation. Corrected build validation/deployment and native review follow.

Corrected layout and empty-slot history guard passed the full standard suite, dry run and deploy-time suite. Installed hashes verified; backup .local/backups/20261115T101128794903Z. SavedVariables untouched. Agent issued the authorized local /reload; corrected visual inspection follows. Existing missing historical messages have not been proven recovered.

Native review after agent reload confirmed the normal member column/divider and conversation caption restored, with no duplicate central prompt or enlarged Party icon. The transcript is still empty. Read-only isolated Lua inspection of current SavedVariables and its existing .bak printed counts only: both contain zero Party lines for the current/last saved session. No account files were changed or copied into the repository, and no private message text was printed. Missing earlier messages cannot be claimed recovered; the empty-slot overwrite safeguard is validated by regression, not recovery of those messages.


## Party leader visibility and previous-group archive - 2026-11-15

User reports only other party members visible; current native capture showed local player as leader. Source registered ordinary native groups only. ConfigureFrame now explicitly registers all ordinary/leader party, raid and instance categories and repairs existing slots on configuration. This is a concrete subscription gap; actual native delivery remains to be verified. No sender is filtered from the dedicated transcript; own messages remain excluded only from unread counts.

Added PartyHistory per-character bounded archive: 30 groups, 200 lines/512 KiB per group, 4 MiB total message text. Nonempty legacy recall migrates before any new-session reset. Previous groups header action opens dated member-preview selection and read-only logs; Back to live chat returns to the untouched native receiver. Live incoming messages continue while browsing, with unread accumulation. Disabling recording now preserves saved history. Shared ReadOnlyTranscript uses actual MessageLine pools, links, text formatting, explicit width/reflow and scroll indicators; no second renderer implementation or native slot. New component/module added to manifest.

Full standard tests passed with leader-slot repair, leader/member archive retention, new-group/reload lifecycle, count bound, archive input/unread behavior, browser/return and recording preservation, plus actual shared message-row wrapping/link integration. Existing ten behavior entry points, migration/workflow/seven release checks and Lua/127 resources remain passing. Deployment/actual in-game review follow separately. No external messages, version bump or publication. User stopped Computer Use in the prior turn; no game input has been sent this turn. The latest optional safe-reload preference is pending.

Group archive deployment completed: final dry run and deploy-time full suite passed, including ten behavior entry points, migration/workflow/seven release checks and Lua/127 manifest resources. Installed hashes verified; backup .local/backups/20261115T232849839090Z. SavedVariables untouched. Whitespace check passed. No post-deployment reload or native archive/leader-message delivery observation yet; safe-reload preference remains pending. No chat messages were sent, and no screenshots/account data were stored in the repository.


2026-11-15 native follow-up: user reloaded and paused movement for review. Previous transcript persisted and the archive opened with its saved log. Local metadata-only diagnostic confirmed all seven native categories and CHAT_MSG_PARTY_LEADER registration true. No party messages sent; user currently solo, so actual new leader-message delivery cannot be observed. Visual inspection caught live roster/caption labels bleeding through the translucent archive. Corrected overlay now hides those underlying views while browsing and normal shared layout restores them on exit; regression added. Archive rows without native arrival time fall back to archive save time; exact legacy arrival times are unavailable, and timestamp stability across later saves/reloads is not verified. Validation/deployment follows. No personal screenshots stored.

Archive follow-up also bypasses live layout while its read-only replacement is active. This prevents the hidden roster OnShow callback from scheduling a refresh loop. Regression rejects a live-roster flash during archive layout. Final dry-run full suite passed including this guard; deploy-time suite and corrected native observation follow.

Archive visual correction passed final dry-run and deploy-time full suites, installed hashes verified; backup .local/backups/20261115T233720243335Z. SavedVariables untouched. Agent ran authorized /reload while user paused safely. Final visual result follows.


2026-11-15 final native archive review: after the authorized reload, the saved group record and message remained available. The corrected archive no longer showed live roster/caption labels through its surface. Back to live chat restored the member column, Previous group caption and retained native transcript. No error dialog appeared. All seven native message categories and the leader event registration were confirmed locally; actual new outgoing leader delivery remains pending a grouped observation because the player is solo. Legacy record lacks member snapshots; unavailable metadata is shown honestly. No external messages or screenshots saved. Documentation-only completion follows the passing deployed suite; no additional runtime edits.


## Alpha release preparation — 2026-11-16

User authorized committing all accumulated project work, pushing 0.10.0-alpha.1 to CurseForge as Alpha, and keeping GitHub as a draft. Reviewed tracked/untracked project changes; private machine state, account data, screenshots, backups and generated ZIPs remain excluded. Updated README, current context, branding, Guild/Party/window/history/protection references, CurseForge description/setup and release instructions; dated implementation history is retained as history rather than overwritten.

Both TOCs and in-game news now match 0.10.0-alpha.1, with curated changelog covering the shared window architecture, rooms/history, contact rows/favorites, timestamps/labels/input and strict item protection. Release tooling rejects unknown suffixes or an explicit type mismatch; workflow defaults to Alpha, checks the type before preparation/upload, and marks nonstable GitHub drafts as prereleases. A bare 0.9.11 correctly mapped to Release under the old inferred policy; no prior tag/file is changed.

Local standard suite passed: ten behavior entry points, migration, temporary-target deployment/rollback with untouched saved-data fixture, deterministic clean/upgrade packages, eight release checks, Lua 5.1 and 127 manifest resources/bindings. These temporary-target deployment messages are not a new live-game installation. No new in-game validation is claimed; existing native observations and alpha limits remain recorded. Release package inspection, source commit/tag/push and remote upload results follow separately.

Final pre-release validation passed after whitespace cleanup: standard suite (including eight release checks), explicit Alpha preparation, staged whitespace check and private-path/credential-signature review across 98 project files. Clean ZIP has 227 entries under Sunder only; SHA-256 f67ba4e5756657dcb4514a97ea92fa97b49b10fe3ae55c1c8719c3a386431851. Upgrade ZIP SHA-256 ebb06df87efbe6b1f2767f027277896890a3b0cf7115a4afb53ea4d0cd0b3ab0. GitHub credential access and push permission verified without printing secrets. Source/tag push and one Alpha upload are authorized; results will be recorded in a follow-up documentation commit without moving the release tag.


## Alpha upload completed — 2026-11-16

All accumulated work was committed as `f3332a986a40dbfa08a2efefa5a1a3b471f3516e` and pushed to origin/master with immutable annotated tag `v0.10.0-alpha.1`. Both push-triggered check/package runs passed. Release Sunder run **43922901392** completed successfully: https://github.com/fawkstrot/sunder/actions/runs/43922901392 . Tagged-source validation, preparation, assets, draft creation and CurseForge upload all passed.

CurseForge accepted **file 9652042**, version **0.10.0-alpha.1**, type **Alpha**, resolved game version **1.60.1**. Upload was dispatched exactly once; do not retry it. Approval/public download visibility has not been independently confirmed. GitHub release **447389399** was inspected through the API: **draft=true**, **prerelease=true**, with both ZIPs and release-manifest.json attached; it remains unpublished as requested.

Downloaded draft assets were checked in memory: manifest releaseType is alpha, archive SHA-256 is **30d037767f41aa4556ed6831f643147f189733cc7cb430ce9a8d4b1a63ee1d92**, and its 227 entries match tagged addon contents (LICENSE differs only in platform line endings). CI ZIP checksum supersedes the local Windows package checksum for the uploaded artifact; checkout line endings/ZIP platform metadata can differ. Documentation relative links and staged whitespace checks passed. No account files, credentials, screenshots, deployment backups or generated ZIPs were committed. No new live-game deployment or native behavior validation was performed for this release operation; installed preview and remaining alpha limits are unchanged. This follow-up documentation commit records remote results without moving the release tag.

## Shared window validation

Use the window ownership matrix in [WINDOW_MANAGEMENT.md](WINDOW_MANAGEMENT.md) when changing an adapter. The spacing fixture runs the production native viewport/slider/pool initializer and the read-only transcript widget. It checks wrap flags, retained readback, recycled rows, both zero and custom insets, a detached container resizing after its renderer moved, archive height-only refresh and the end of queued resize work. The Guild, Party and Whispers fixtures cover their controller refresh paths. Inspect native glyphs, mouse tracking, clipping and protected editor behavior in the client separately.

The room transition fixture checks effective visibility of the actual backing, sidebar and divider after a collapsed appearance refresh and during eleven intermediate steps in each direction. Checking only the parent frame can miss a hidden child texture.

The main-window header fixture wires the production UIManager, container, WindowManager and action callbacks to native dock/mover fixtures. It checks action hit layers and overflow clearance, immediate resize cancellation on lock, an intermediate clipped height, restoring from minimized into maximized, original anchor recovery, native selection retention, editor activation, manual resize and combat gating. The tab-handler fixture checks both blocked drag start/stop and unlocked native fallback.

For main dock startup changes, exercise header installation with the bundled AceHook library and its actual calling convention. A plain mock frame masked a startup error when the native dock also owned addon hooks. Keep window initialization ahead of optional header actions. The regression also checks locking the normal and Edit UI grips and resizing again after unlock.

## Chat practice

Use `/sunder practice` to enter or leave the isolated practice room. The same toggle is under Whispers → Samples & testing. Select **All**, **Whispers**, **Groups**, or **Windows**. Pause keeps the remaining delay. Next event advances exactly once and stays paused. Replay restarts the selected chapter. Exit practice closes the room and its detached pane. **Check live UI** takes a read-only snapshot of dock readiness, grip visibility and live room visibility while practice is running.

Try pausing after the first exchange, typing a draft in **Practice reply (local only)**, then stepping to the second sender. Click their toaster and return to the original person. In Groups, step from the previous group's log through a background arrival and back to the current group. In Windows, try the grip, collapse, scrolling and long-word wraps. Native docking, Combat Log filters, protected input and actual server delivery still require the game’s native windows. General and Combat Log practice steps display sample traffic through the shared renderer.

The timeline lives in `Modules/ChatPractice.lua`. Add a delayed event to an existing chapter or register another chapter in the same table. Use private input data and shared production presentation methods. Exercise the same entry in the Party regression with pause, step or the scheduled callback, and assert both the expected observation and isolation. The practice owner stays outside the native controller registry. Its timer runs only when the next event is scheduled. Practice drafts, transcripts, archives, favorites and pins belong to its session. Ordinary WoW chat input continues to work independently.

For a dead header, compare WoW mouse focus at the visible icon and grip. Frame Stack includes decorative regions. GetMouseFoci identifies the receiving frame. The native viewport fixture checks click and wheel bounds at latest, in readback, and after returning to latest. Checking button callbacks alone cannot catch a neighboring transcript covering the dock.

For header changes, exercise both collapse edges, the single opposite-facing restore control, tab clearance after repacking, and the expanded anchor after restore. WindowManager creates and formats the unread indicator. Each room supplies its unread total and click action.

For locked-header regressions, click the real lock, assert Close disappears and Settings moves into its position, refresh the header, and unlock. For Whispers overflow, exercise wheel scrolling, unread counts, searchable selection and reveal with more people than fit.

The standard check also reads packaged Lua, XML, TOC, Markdown and text files as UTF-8. It reports the file and line for damaged punctuation signatures, replacement characters or unexpected C1 control characters. Translated accents and valid Unicode punctuation are supported.

Vertical scroll regression coverage uses the production pointer handlers to grab the thumb, move the cursor in both directions, click the track and release outside. It checks fit/overflow, resize, a wrapped transcript with different row heights, the return-to-latest reserve, wheel input, and a utility widget with a different native range. Live acceptance: compare Guild members, General/Combat Log and a group archive, and confirm links, roster actions and editor focus still work beside the rail.

## Conversation recording

ConversationLog.lua subscribes once to player conversation events. Combat events, practice output and inaccessible text never enter this stream. Public and custom channels, local speech, character and Battle.net Whispers, Guild and group channels use the same arrival clock. Private logging follows each feature's recording preference. WoW writes SunderConversationLog as a per-character SavedVariable on normal logout or UI reload. An initial import copies available room and Whisper history and retains unknown dates. A crash before the next client save can lose the unsaved session.

Open **/sunder history** or **Home → Browse conversation history**. The viewer pages through 50 messages at a time and shows local dates and times. Its confirmed Clear log action clears this character's chronological copy. Whisper and group archive controls manage their respective room copies. Forgetting a Whisper also removes the corresponding private lines in the chronological log. The storage reminder estimates text plus per-line overhead. It does not measure the serialized file. Live and archived transcript presentation uses TextProcessing with a date prefix for earlier local days. Native save adapters use the receipt captured after insertion or an original native timestamp. Replaying an undated line must never assign the replay time.

The date regression exercises the production InitializeScrollFrame hierarchy, shared row pool and anchor layout. It checks calendar boundaries, an exact one-hour pause, pooled reuse, narrow width, divider height and the pinned date's return-to-latest behavior. Date markers are computed during layout or scrolling. The implementation adds no idle per-frame work. TextProcessing accepts a grouped presentation flag so a transcript with dividers retains ordinary per-message time formatting; plain copy/search retains explicit dates.

Archive roster regression coverage exercises complete and incomplete observations, stable-GUID renames, simultaneous departures/joins, offline presence, repeated refreshes, reload baselines, recording gaps, shared Archive action, and class-colored list/summary display. The real ReadOnlyTranscript pool test checks event hover installation and removal on ordinary-row reuse. Sender-color tests preserve native player/item link payloads and message bodies, cover explicit/unknown/custom class colors, and round-trip metadata through native restore and a fresh save. Groups practice includes roster timeline hover details while asserting real saved-data equality on exit. No new idle update driver was introduced.

In-game follow-up: after a safe reload, open Previous groups; compare name colors in list, summary and tooltips. Use /sunder practice → Groups, pause at its archive, and hover the muted roster entries. Resize at large fonts, scroll to date boundaries, return to live, and exit practice. Observe an actual join/leave and a reload to verify native event timing and fonts beyond fixture coverage.

2026-11-17 archive validation: standard tests, deployment dry run, deployment-time suite and both packages passed. WoW Forever installation hash-verified with backup 20261117T175634599074Z; SavedVariables untouched. In-game visual/event verification remains pending. Incomplete roster refreshes preserve the last complete group fingerprint for reload recovery.

Archive self-display coverage exercises actual SelectHistory/RenderHistoryList, repeated refresh/reselection and preview hover, renamed self by GUID, legacy qualified/unqualified names, same-name characters on other realms, self-only empty states and unchanged saved roster/message data.

2026-11-17 archive self-filter validation: full suite, dry run, backed-up/hash-verified preview deployment (20261117T180031541417Z) and both packages passed. SavedVariables preserved. Actual in-game observation remains pending.

Shared design regressions cover zero/nondefault native/room header gaps, actual CombatLogBar below/above anchors, archive surface geometry after style refresh, shared 130 px sidebars, configurable limits during held mouse resize, collapse/restore and Ellesmere paths, and numeric AceConfig bounds. Guild dashboard fixtures exercise a 1,000-member roster, class/location/stat drill-down, presence/search/sort, stale member identity rejection, explicit-only actions, About content, preserved live roster query, bounded pooled controls and idle-driver absence. Earlier geometry assertions now use shared metrics instead of retired widths/gap assumptions.

Native follow-up: compare Party live/archive fades, General and Combat Log header gaps (including below-header filters), zero/nondefault padding and gap, and large fonts. Resize each window through its normal grip and edit controls; verify the new minimum settings, held-mouse chrome and collapse/restore. Open Guild Info, try each tab and filter, scroll/recycle member rows, open a card and return to chat. Validate glyph clipping, tooltip placement and native roster changes after a safe reload.

2026-11-17 shared design/dashboard validation: standard suite, dry run and deployment-time tests passed. Installed WoW Forever preview hash-verified (backup 20261117T215136803641Z), SavedVariables untouched. Both packages rebuilt as 0.10.0-alpha.2 without publishing. Native appearance, held-mouse tracking and protected combat transitions remain pending safe in-game verification.

Guild Info overflow regression checks the real drawer/viewport/scroll ancestry and bottom inset plus explicit wrapping and height for statistic cards. A dedicated viewport clips partially visible pooled controls; ScrollFrame behavior alone is not treated as visual proof. Native follow-up: scroll Overview and Members across both edges, resize, open a member card and return; check two-line counts and clipping after a safe reload.

Guild dashboard subtitle regressions cover MOTD across Overview/Members refresh, changed announcements, newline normalization and empty/stale clearing. Native truncation/readability remains a safe-reload check.

Minimized-tab regressions exercise real Guild/Party/Whispers hosts: shared action presence, saved open/tab state, automatic-show rejection, unread/online updates, Guild and Whispers reload restoration, simulation state restoration, General toaster anchors, narrow wrapping, independent clip parent, combat-deferred restore, exact full-size recovery, close cleanup and no idle script. Native follow-up: minimize all three rooms, move/resize/collapse General, receive real messages, click a toaster, reload safely, and inspect the strip at screen edges. Screen-edge snapping is unchanged.

2026-11-17 minimized tabs validation: full suite, deployment dry run and deployment-time checks passed. Installed preview verified with backup 20261117T221612016206Z, SavedVariables untouched; both packages rebuilt. Native event/visual checks remain pending safe reload.

2026-11-17 live Guild overflow diagnosis: root/panel bottom 531.3319, clip/scroll bottom 523.3318 confirmed outward bottom padding. Tests now resolve viewport height and containment at zero/default/nondefault padding, across Overview/Members/About and member-card footer; do not assert a copied anchor value as evidence of containment. Live inspection established the pre-fix cause only; repaired native rendering awaits safe reload.

Guild dashboard section styling regression verifies a taller heading row and a visible divider above the label, with named spacing owned by GuildDashboard. Ordinary pooled rows reset bottom-rule anchors and opacity. Native readability at small widths/large fonts remains a safe-reload visual check.

Dashboard redesign regressions cover separate summary value/caption bounds, title/subtitle hierarchy without heading rules, wide-column non-overlap, narrow stacking, class presence tracks, class-colored location previews, filtered result counts and existing scrolling/1000-member pooling/containment. Heading-rule assertions were replaced because that visual treatment was explicitly rejected.

Native minimum regression (2026-11-17): a simulated engine starts with a 400 px height floor and clamps SetSize. Exercise actual detached grip callbacks for both normal/edit controls at default and changed shared limits; assert native height plus header equals shared visible height during held resize. Cover both resize-bound APIs and combat mutation guard. Native drag validation remains pending safe reload.

Containment regression (2026-11-17): detached-container integration now uses the production message-height helper with the renderer/viewport/surface path, checking closed, visible and growing editors across multiple heights and padding 0/8/19, plus above-editor placement. Assert windowContentExtent and surface bottomExtent stay zero, rather than checking native height plus header alone. Native glyphs/held-mouse observations remain separate.

2026-11-17 navigation/search regressions: rail click/drag reveals faded rows and cancels fade deadlines; keyboard Page Up/Down routes to visible transcripts and propagates keys for input fields/hidden targets. All-saved search exercises asynchronous 452-record scanning, stale-query cancellation, second-page results, source/date context and saved-data nonmutation. Existing archive UI checks now identify the result control after the new action row. Native input-hit testing and shortcut behavior still require in-game validation.

Native input adapter regression (2026-11-17): independently interactive native scrollbar children must all lose click/motion/wheel input, including on refresh; filters remain enabled. Execute native PageUp/PageDown post-hooks through shared paging, verify focus preservation and stale pooled-owner rejection. Installed EllesmereUIChat source provided a comparison: it explicitly suppresses scrollbar child input and bridges native scrolling. No assumption is made that reference addons are enabled.

Main minimum regression (2026-11-17): execute the actual mover UpdateLayoutBounds with a 64 px editor above/below a contained 220 px root; assert mover height stays 220 and mainTopOffset stays zero. Existing real renderer/surface containment tests now acquire containment from RegisterNativeSurface, the same registration used by General and detached native windows.


2026-11-17 rollback: native Slider/late editor reanchor tests passed mocked execution but did not establish native integration correctness. User reported widespread breakage without a displayed Lua error. That production revision and its dependent fixture changes were reverted; preserve this distinction before attempting another shared-control replacement.

Native Combat Log adapter regression (2026-11-17): exercise UIManager creation → detached shell → native viewport/lines → shared rail. Assert no replacement row pool, native offset synchronization through wheel/page/real rail press/held-drag/release callbacks, stable thumb size at newest, independently disabled stock input, native link receiver, padding 0/8/19, large line spacing, editor growth, held resize geometry, refilter range changes, hide/show and dock/detach refresh. Preserve native OnShow invocation count and scroll notifications; assert no idle adapter/rail driver. These are fixture observations, not physical mouse dispatch or secure-client validation. In game, check track/thumb, Page Up/Down, links, filter changes, dock/undock and editor/resize geometry after safe reload; do not infer a resolved native failure from mock success alone.

Screenshot follow-up: user observed General rows piling up at the bottom and native Combat Log chrome still visible. Regressions now exercise 180 incoming rows through real row creation, pooling and LayoutMessages, with changing widths, positive measured heights, correct neighbor links and hidden unpositioned rows. Native tests execute later Show/SetAlpha calls on stock controls and reject geometry changes on live restricted glyphs during held resize. Screenshot evidence establishes the visible failures, not an undisplayed Lua error or exact original interruption site.

Combat Log resize follow-up: native-host fixture starts with mismatched strata and a high-level glyph container, then asserts shared grip ordering after refresh. Execute the actual DetachedChatDock resize callbacks with CreateResizeHandle for normal/edit grips, including held cursor changes, native/root/viewport size updates, release cleanup and lock rejection. Physical hit-testing remains a separate in-game check.

Glassy comparison regression: assert the native Combat Log geometry frame has click/motion/wheel disabled, including after simulated re-enabling followed by layout refresh. The actual clipped viewport retains hyperlink/mouse/wheel input and advances native scrolling once per wheel callback; legacy clamp insets are cleared. Direct grip callbacks alone do not establish that the physical mouse can reach them. User's absent hover highlight is a reported input observation, not an observed Lua resize failure.

2026-11-18 native result: user confirmed the pointer-ownership repair worked. Record this as user-reported live resize validation, separately from fixture coverage for edit-mode resizing, filters, links and combat restrictions.

## Fishing integration — 2026-11-18

See [FISHING.md](FISHING.md) for module ownership, temporary binding/combat rules, saved defaults, equipment macros, fishing-only auto-loot, client limits and the live checklist. Run the standard CLI suite, which now includes `work/test_fishing.py`. Preview deployment does not authorize a release. The user requests that they perform game input/reload themselves; do not take control of WoW.

Fishing macro follow-up: FishingMacro.lua owns character-local captured gear and exact-body-owned native macro generation. `test_fishing.py` now validates capture/update/ownership/capacity/combat and next-frame refresh. Native gear swapping and macro UI/action-bar behavior remain a user-run check.

Fishing equipment sets supersede individual gear capture. FishingMacro.lua owns character-local set IDs, live dropdown values and native manager guidance; work/fishing_sets.lua extends the fishing CLI fixture with role validation, renamed/deleted sets, retired stale macros and exact-body legacy upgrade. Macro/set UI behavior remains a user-run in-game check.

Fishing macro icon/tooltip now resolve the next destination set’s main-hand item. Equipment-set fixtures cover both directions, item tooltip IDs, icon-only cache refresh and set-icon fallback alongside the existing combat/ownership checks.

User-directed macro policy change: Sunder Fish is managed by name, even after manual edits. Prefer character storage, reuse an account copy otherwise, and create a character copy when absent during configured refresh. Regression covers replacement in place, storage precedence, unrelated-name preservation and recreation. No body-ownership conflict prompt remains.

## Shared typography — 2026-11-18

[Typography](TYPOGRAPHY.md) documents the Ellesmere → saved Sunder role → Sunder base → native cascade, native/custom bubble ownership, scoped menus/settings/tooltips, live refresh and user verification checklist. `Fonts.lua` is the single face resolver; `test_fonts.py` exercises the production helpers through the standard CLI. Never solve font mismatches by overwriting every global game font or by changing stored fallback preferences. Native visual/instance behavior remains a separate in-game check.

Typography validation receipt: final standard/dry-run/deployment suites passed; native installation hash-verified under backup `20261118T223424113030Z`; both local packages rebuilt. No gameplay input or live visual verification occurred. See CONTEXT.md for the separate automated/deployed/pending-native record.

## Native friendly nameplates — 2026-11-18

See [NAMEPLATES.md](NAMEPLATES.md) for CVar ownership, native presentation scope, source provenance and dungeon simulation options. Standard CLI includes test_nameplates.py; optional local-source integration executes the actual Blizzard UpdateShowOnlyName method. This is flag propagation with simulated receivers, not full native protected rendering. WoWless/wow-ui-sim were researched but not installed. User-run real dungeon checks remain required.

Validation completed: standard CLI suite and final-source dry-run/deployment suites passed (13 behavior entry points, 8 release tests, migration/workflow checks and Lua/resource checks). Focused nameplate test explicitly passed actual downloaded Blizzard UpdateShowOnlyName flag propagation with simulated dungeon receivers, plus reload-persistent external ownership yielding. Installed Forever files hash-verified; backup 20261118T223834236391Z; account SavedVariables untouched by deployment. Clean/manual-upgrade packages rebuilt at unchanged 0.10.0-alpha.3. No commit, publication or game interaction. User reload and /sunder nameplates enablement, real dungeon health/color/visibility and combat verification remain pending. Optional font overrides and custom markers are not implemented.

## Compact minimized tabs — 2026-11-18

WindowManager now measures minimized labels and compact unread badges rather than reserving 180 px columns. Standard titles are shortened and Guild online context is retained in the tooltip. The real-room integration regression in test_party_chat.py covers 300 px packing, 900 px non-stretching, narrow/large-font wrapping, long custom names and 99+ badge growth, alongside existing persistence, combat deferral, restore and toaster behavior. See WINDOW_MANAGEMENT.md. Automated, deployment and native-observation results are recorded separately in CONTEXT.md.

Compact-tab validation receipt: final standard/dry-run/deployment suites passed; installed hashes verified, backup `20261118T224547410162Z`; clean/upgrade packages rebuilt. Native visual review remains pending after user reload.

## Resize, tab alignment and minimums — 2026-11-18

The native Combat Log resize regression now resolves anchored shell dimensions without sending a synthetic shell size event. Both real grip callback sets must update viewport width and rail geometry during held movement, retain native readback and reject docked/stale notifications. General/native versus room configured minima are compared in outer-window coordinates. Expanded-list sizing and common room-header calculations replace divergent reserves; people-list mode has no hidden inline-tab allowance. Minimized zero-unread labels must be centered with symmetric insets and no badge placeholder. See WINDOW_MANAGEMENT.md and CONTEXT.md for implementation and validation receipts.

Resize/alignment/minimums receipt: standard/dry-run/deployment suites passed, installed files hash-verified with backup `20261118T225621750851Z`, and both local packages rebuilt. Post-fix native observation is pending; the supplied screenshot records the pre-fix failure.

## Keyboard error regression - 2026-11-18

Transcript keyboard tests run without the retired MouseIsOver global and use frame IsMouseOver. Ordinary gameplay keys propagate without transcript lookup; preserve paging, hidden-view, native fallback and editor focus coverage. Shutdown history saves tolerate unavailable settings without clearing retained history. Local General.log supplied actual repeated keyboard and reload-time history stacks. See CONTEXT.md for automated/deployment receipts; native gameplay verification remains separate.

2026-11-19 alpha.4 release validation: full standard suite and Alpha package preparation passed, including keyboard/shutdown regressions. See CONTEXT.md and RELEASING.md for remote workflow receipts. Native observation remains separate from these automated checks.

Alpha.4 remote validation completed: rehearsal, branch/tag CI and CurseForge upload passed. Both release ZIPs matched tagged source; CurseForge accepted file 9703400. See RELEASING.md for run links and checksum. GitHub remains draft.
