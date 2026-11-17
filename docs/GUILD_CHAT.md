# Guild Chat room

Open with `/sunder guild`, Control-left-click on the Sunder minimap button, or Chat > Guild Chat > Open Guild Chat room. Run `/reload` after development deployment. If the command reports that the new module has not loaded, restart the client once; subsequent edits use the ordinary local preview loop. No new addon folder is installed.

## The room

The room owns one native chat slot, named Guild Chat. Its initial filters include GUILD only; existing General, guild and other addon windows are not adopted or reconfigured. Native rendering, hyperlinks, commands and sending remain in charge. The room prepares its own editor for GUILD when first attached, then preserves drafts and explicit channel changes when reopened. Creating a new slot or attaching protected geometry waits for combat to finish; opening an existing unprotected room is allowed. Exhausted slots and unavailable capabilities produce feedback instead of taking another window.

The visible shell is a dedicated room root using the **same shared header primitives as Whispers**, not the parked native chat tab. Drag the header grip or title at any time. Header controls close the view, open settings, show/hide members, minimize/restore, and maximize/restore the previous size. Collapse uses WindowManager's shared cancelable geometric clip and preserves the expanded geometry. The shared corner resize handle is available outside global edit mode; a window lock prevents both movement and resizing, including maximize. The room is hard-clamped to screen. Ellesmere Edit UI registers this actual room root once, with size/position save/discard, minimized-state restoration and a Guild Chat settings link; the hidden native slot is excluded from duplicate movers. Shared fonts, accent, horizontal background fades and the 8 px body inset apply. Header metrics remain separate. One continuous body surface spans the message and roster columns; there is no second column fade or added top gradient.

The header close button hides the room while retaining its native recipient/history source; opening the launcher restores the view. Minimize retains an interactive header; maximize is separate and restores the previous size on its next click. Room position, expanded size, minimized/maximized status and restore geometry are stored per character. The native tab is parked out of the visible dock. If the managed source is externally docked, layout returns it to the room; it is not an alternate visible shell. Do not rename/reuse the managed native slot for unrelated chat: startup verifies its saved slot ID and Guild Chat name before attaching.

## A living roster

- Compact two-line rows show class-colored full names with smaller muted level/class details. Rank and optional public notes appear in the selected member card and tooltip, not a taller default row. Shared person-row metrics, separators, idle backgrounds and right-side pin/star controls match Whispers and Party.
- Sort priority is pinned favorites, favorites, pinned, then the configured stable rank/name order. Favorites are shared per character across real contact views; Guild pins are current-guild/per-character scoped. Filters do not change the header's online/total count.
- The caption shows a slightly larger guild name with the bounded message of the day beneath it. The MOTD is excluded from the dedicated transcript/recall. Guild Info opens a responsive body drawer, sharing the window shell.
- Search matches names, ranks and permitted public notes. Enter leaves search; Escape clears it. Offline inclusion is optional and never changes the native guild roster's global preference.
- Left-click selects a member/card without opening a whisper. Double-click or an explicit Whisper action opens the recipient without sending. Context actions include identity-checked Inspect when a nearby unit is available. Invite or other explicit actions resolve the current identity when clicked; opening a card performs none of them.
- All expanded people lists use the single WindowManager 150 px target and shared narrow-window reserve. Short layouts compact the roster; Show members restores enough room instead of silently doing nothing. Clicking the member count while minimized restores the room and reveals the roster.

Officer notes are discarded at the API boundary and never stored. Roster/note caches are session-only. No automatic roster editing, invitations, inspect requests or messages occur.

## Recent recall and bounded work

Guild recall is independent from Whispers archives. Up to 200 recent GUILD messages and 512 KiB of text are remembered per character for the latest guild/realm identity. Officer message types, inaccessible text and session-name tokens are excluded. Original timestamps and colors are retained. Replay yields after 12 lines; reopening the same active frame does not replay twice. Native-slot reuse and guild changes cancel old callbacks. Closing during replay merges newly arrived messages with the prior snapshot before native teardown. Opting out clears the guild checkpoint and cancels replay.

This is recent local recall, not retrieval of guild messages sent while offline. WoW writes the in-memory database to SavedVariables on normal reload/logout; it is not a crash-proof disk journal.

Roster events are coalesced over 0.2 seconds, native refresh requests are throttled to ten seconds, and scans yield after 100 members. The scan cap is 10,000 members. Sorting/filtering use the completed cache; only the visible row pool is rendered (a hard cap of 256 controls, with only viewport rows shown; maximized/tall layouts can display more than forty rows). One room shell and roster pool are reused across native-slot replacement. Hidden rosters stop scanning, and there is no roster polling ticker or idle roster OnUpdate. The dedicated continuous backdrop also parks the legacy gap-background frame driver; it is restored when the window returns to ordinary chat layout or its renderer is reused. New room rows receive full-surface coverage on creation. Existing Sunder rendering and movement animations retain their own bounded lifecycle.

## Message-area clicks

Plain left-clicking a real message row or blank message viewport now selects that native window's current layout editor for the next Enter. This applies to General, other native tabs, Whispers (including borrowed reply editors) and Guild Chat. It uses the normal native last-active input API. It does not open an editor, call SetFocus, rewrite text or replace secure selection functions. Non-chat input focus, right-click behavior, modifier-based link actions and layout editing remain intact. Hyperlink callbacks and mouse-wheel scrolling remain attached to the existing renderer.

## Validation and live preview

`tools/sunder.py test` includes `test_guild_chat.py`: native slot/filter isolation, editor default and draft preservation, online counts/rank/note model, search/offline behavior, 1,000-member scanning/virtualization and tall maximized coverage, stale guild cancellation, narrow/short/32 px-font layouts, shared chrome, always-available grip movement, cancelable collapse/reversal, maximize/restore, compact selection/no-send behavior, shell reuse, history identity/timestamps/partial-close handling, full-slot feedback, combat deferral and production message-area handlers. Settings tests include registered Chat pages and standalone/Ellesmere Guild Chat deep links. Existing archive, renderer, input, protection, migration, workflow and release coverage remains enabled.

Live WoW Forever checks remain necessary:

1. Reload and open the room with `/sunder guild`. Compare online count, rank order, class colors and public notes with the native guild roster; confirm full names, search and tooltip truncation handling.
2. Click a member and confirm selection/card only; use explicit Whisper or double-click to open the recipient without sending. Verify shared favorite/pin states and absence of officer notes.
3. Check that the header grip and title drag without unlock mode; minimize and restore repeatedly, then maximize/restore size. Click blank space and message text in General, Whispers and Guild Chat, then press Enter. Check the owning editor and channel before sending. Repeat with a General draft, borrowed `/reply` input, player/item links, Shift-click, search focus and scrolling.
4. Resize in Sunder layout mode and move/resize in Ellesmere with save/discard; check large fonts, narrow/short bounds, compact roster/Show restoration, header controls and reopening.
5. Exchange guild messages, reload twice, and close/reopen. Check recall, timestamps and no duplicate replay. Review guild changes and combat transitions when naturally available; do not interrupt gameplay to force them.

## Historical visual iteration notes

The following dated observations preserve past failures and subsequent fixes; the behavior above is the current contract.

The initial visible layout was rejected by the user. A read-only game capture confirmed its missing room chrome and sparse roster; no game input or personal screenshot file was stored. The replacement requires an actual post-reload visual check. Automated fixtures do not prove final appearance or native input behavior.

API shapes were checked against extracted client source: [native chat window creation](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_ChatFrameBase/Mainline/FloatingChatFrame.lua), [guild roster request API](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/GuildInfoDocumentation.lua), and the [legacy roster return-value call site](https://github.com/goldpaw/WoW_UI_Source_Cata/blob/master/FrameXML/StaticPopup.lua). Capability checks and WoW Forever verification still govern actual support.

Guild login notices (localized native MOTD template) are transient: they are excluded from saved recall and stripped from older checkpoints before replay. Repeated player messages are preserved. The shared header, left roster and continuous background were observed in game on 2026-11-11; interactive controls still require user live checks.

Both room types now share subtle neutral perimeter/header rules, a distinct sidebar backing and inset column divider. The configured body opacity still controls visibility; shared horizontal chat fades remain above the bounded room backing. Expanded Guild roster is 170–210 px; Whispers sidebar caps at 220 px. Font-aware rows, visible search prompt, guild transcript caption and shared draggable scrollbars improve navigation without adding idle work. Transcript progress uses measured row heights when available.

Drag the subtle lower-right corner of either room to resize without entering unlock mode. Guild expanded view caps at 1100 × 720 UI units for readable ultrawide layouts; normal saved bounds restore afterward. Scroll tracks remain subtle and thumbs only appear with overflow. Existing global unlock/Ellesmere workflows remain available.

The title text, empty title bar and grip support dragging. The title-bar lock stores a per-room movement preference and prevents title/grip movement; resizing remains separate. The continuous room backing is painted beneath the shared horizontal edge fade.


Title text, empty header and grip support dragging. The title-bar lock saves a per-room position preference; resizing remains separate. Shared edge fades paint above continuous body backing.


### Quiet minimized Guild activity

The header offers upward and downward collapse actions, sharing the same cancelable transition and saved collapse edge as Whispers. A bounded session unread counter tracks incoming guild messages while the room is closed or minimized. Expanded visible conversation messages are acknowledged; restoring or clicking the badge clears the count. Own messages are excluded when native sender GUID is available. The badge tooltip also shows the current online count. No Guild toasters, incoming focus changes, message previews or polling animations are added. Counter state resets on reload or guild change.

Common action rendering and position-lock policy now come from Components/WindowManager.lua. Native chat adapters preserve native tabs and combat filters; Guild extends the common controls with roster, collapse direction, expanded view and unread behavior.


### Shared visual surface

Guild no longer owns a separate body treatment. Main chat, detached native chat, Whispers and Guild use WindowManager:ApplySurface for backing/fade layering, perimeter and header separation. Guild supplies roster width and body geometry, while its existing functional controls extend the shared header primitives. Appearance changes in the common component apply to all window types.


The window audit removed the duplicate Guild surface application: roster width is supplied through its geometry adapter in the initial shared update. Stable surface updates reuse a scalar appearance/geometry cache; resized or changed-color surfaces repaint. Native legacy separator paints are retired so their rule cannot overlap the shared header rule.

Collapse/restore uses the WindowManager transition shared with Whispers. Downward collapse interpolates header position and room height together before retaining the bottom anchor. The header chat icon and count share Whispers colors: neutral blue-gray at zero, theme amber when unread.


Collapse/restore uses the WindowManager transition shared with Whispers. Downward collapse interpolates position and height together before retaining the bottom anchor. The header chat icon/count share Whispers colors: blue-gray at zero, theme accent when unread.


Guild and Whispers now use the same semantic header command set and transition/maximize implementation. Square means maximize; overlapping squares mean restore size; chevrons collapse up/down or restore the collapsed window; member-list icon toggles roster; menu icon opens window actions; the return-to-main icon is reserved for native docking. Roster visibility has persistent selected feedback and a state-specific tooltip.


The message indicator uses the exact Whispers header icon/label geometry and idle/unread opacity policy. Roster selected feedback refreshes immediately after hide/show. Guild body backing shrinks through WindowManager with opaque, clipped content; it hides only at collapse completion.

Roster highlight reflects actual visibility, including automatic compact mode. While Guild Chat is collapsed the roster command restores the window and shows members through the shared transition.

Roster sizing (2026-11-13): width fits the longest displayed member name plus controls/insets, bounded by the saved maximum and available transcript space. Names determine width, not long public notes. Measurements are cached until roster/filter or font size changes. Width alone no longer auto-hides members. Show members at short heights expands the room sufficiently; header and compact-strip actions share ToggleRoster and refresh selected feedback.

Member scroll feedback: fitting rosters retain a subtle track; overflow shows a proportional draggable thumb above the member row layer. Mouse wheel and rail dragging update the same roster position. Compact/hidden rosters do not retain stray indicators.

Scrollbar placement follows Whispers: viewport reaches the member/transcript divider; the rail sits at its right edge. Row content retains internal clearance without a second outer gutter. Search and member headings keep their normal inset.

Guild member header now shows online/total beside the roster icon, independent of search and offline filtering. Event-driven bounded scans continue while the room header is visible, including minimized mode; hidden rooms remain idle. Guild messages wrap against their actual renderer column width using the common message-row policy.

Character-rename recovery (2026-11-13): Guild can reconnect a unique, open native Guild Chat slot when its per-character frameID is missing/stale. Recovery requires the expected title and GUILD-only native filters; it recognizes a visible Sunder renderer even when its native frame is hidden. Mixed-purpose, closed and ambiguous slots are excluded. Recovered rooms rebuild the normal member pane/header without allocating another native slot or rewriting another character’s saved data.

Player identity details: rows show name and a smaller muted class-colored level/class line; rank/public notes are in member cards and tooltips. Rank and note remain available in full in the tooltip. Row height and visible-row virtualization use the combined typography metrics; narrow rows truncate instead of wrapping into adjacent controls. Guild metadata comes from the existing bounded roster model; its name index also supplies matching Whispers contacts.

Caption hierarchy: guild name uses the inherited face at body size +2 px and a brighter neutral tint. MOTD appears directly below in a subdued single line; hover shows full text. Empty MOTD removes the extra caption row. Caption space is reserved before the transcript. New/history MOTD notices are excluded from Guild rendering; first connection rebuilds already-rendered native rows so the login notice does not remain at the bottom. Original native history is not deleted.

## Guild information and member cards

Guild Info (circle-info header icon) opens an overview with online/total, your rank, MOTD, available public guild information and a cached online class breakdown. Clicking a member opens a card with level/class, status, zone, rank/public note and explicit Whisper/Invite/Favorite actions. The back arrow returns to the overview; close returns to chat. Cards resolve current roster data, reject stale guild identities, disable offline/combat actions and check party permissions before invite. No action sends on card open.

The drawer shares the existing body: at wide widths it reserves 280 px beside the transcript; below 520 px of conversation space it temporarily replaces the conversation view. Closing restores chat, draft and readback. Caption and controls do not overlap the drawer. Drawer content scrolls with the shared list affordance.

Member rows now use name plus level/class only, with subtle 1 px separators. Rank/public notes remain in cards and hover tooltips. Compact Online (All when offline display is enabled), Zone and Favorites filters combine with search; Favorites includes offline favorites. Favorites share the per-character Whispers contact store; starring or unstarring here updates Whispers and vice versa, including people without an open conversation. Zone uses native local zone information, not location queries. Filters/drawer state are session-only.

## Shared people-list behavior — 2026-11-13

Guild and Whispers now use the same compact row component and balanced vertical spacing. Favorite and pin actions remain visible on the right even when the row is not selected; active states use filled artwork. Guild pins persist per character/current guild, capped at 200; favorites persist in the shared per-character contact store. Ordering is pinned favorites, favorites, other pinned members, then the usual online/rank/name order; filters/search still apply and no extra groups are inserted. Clicking actions does not open a card or send anything. Header member count remains available while minimized and restores the room with the member list visible, closing a covering Info drawer.

2026-11-14 people-list polish: Guild and Whispers share uniform idle backing independent of transcript edge-fade width, with selection/unread treatment retained. Shared text uses a 2 px optical lift for balanced visible separator clearance; both lists use the same row stride. No font/row-height increase.

2026-11-14 shared favorites: Guild stars and Whispers stars now refer to the same saved person. Marking a guild member creates a saved Whispers favorite without opening chat, generating history or focusing input. Unstarring in either view refreshes both. Existing guild-only favorites migrate once before guild-change cleanup and remain personal favorites after leaving/changing guild. Pins remain independent of this change.

2026-11-14 architecture: Guild shell, roster/transcript geometry, native-slot recovery/state restore and bounded recall moved into Components/RosterRoom.lua, shared with Party Chat. Guild retains native filters, guild lifecycle, roster/public notes and Info adapter. Existing user geometry/history and behaviors are preserved; all Guild regressions remain required.


Current expanded people-column width is 150 px, owned solely by WindowManager.PEOPLE_SIDEBAR_WIDTH and applied through PeopleSidebarWidth. This supersedes measured-name, saved maximum and percentage sizing; narrow windows still preserve transcript space.


The shared TextProcessing label adapter removes the redundant native channel label only inside this registered room, retaining sender links and message text. General/other tabs keep their channel context. Saved history remains original native text.

Guild recall stores each available original receipt time. Native entries with a client-clock timestamp are converted to wall time using their age. Reopening, reflowing or saving a room again preserves that time. Older records with no recoverable receipt time show their text without an added timestamp.
