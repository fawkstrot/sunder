# 0.9.10

- Filter Ellesmere detached-chat mover registration using actual configured/open slot metadata, rather than UIManager's initialized flag.
- Exclude unused built-in slots, retired temporary frames, docked tabs and conversations already inside Whispers groups.
- Remove mover registrations and settings links when a window closes. Preserve existing chat tabs and history.

# 0.9.9

- Remove the main chat mover's 20 px magnetic edge snap; retain hard screen boundary clamping.
- Register chat, active detached chat windows and Whispers groups with the optional Ellesmere Edit UI API, including movement, width/height controls and element-options links.
- Use Ellesmere movers during its session without duplicate Sunder overlays, preserving minimized/hidden window state and restoring standalone layout mode afterward.
- Support save/discard, dynamic window registration and deferred combat cleanup. Keep the standalone editor when Ellesmere APIs are absent.

# 0.9.8

- Add a bank-sort compatibility path for native bank cleanup rejecting unrelated backpack protection locks.
- Suspend only Sunder-owned backpack locks during the synchronous bank-sort request and immediately restore them, including on errors. No timed unlock window, bag-sort override or foreign-lock release.
- Preserve native return values and safely remove only our wrappers when the feature is disabled.

# 0.9.7

- Remove the top black gradient and its controls entirely.
- Replace separate message insets with one shared Content padding setting, defaulting to 12 px.
- Apply shared body spacing to chat, native Whispers, sample conversations, people lists, editors and toaster text while preserving compact header metrics.
- Retire saved top-shade and per-chat padding settings on upgrade.

# 0.9.6

- Add independent left/right/bottom message padding, defaulting to 12 px, without shifting chat headers or editors.
- Add a mouse-transparent black top gradient that fades with message content. Height and strength are adjustable or can be set to zero.
- Add controls under Chat → Appearance → Surfaces & colors, shared by native chat and Whispers conversations.

# 0.9.5

- Retire the separate Favorites window, roster, routing toggle and launch actions. Favorites live in the main Whispers filters.
- Migrate legacy window state and order while preserving contacts, conversation history, custom groups and detached conversations.
- Keep `/sunder favorites` as a shortcut to the main window's Favorites filter.
- Update window settings and help to describe the unified behavior.

# 0.6.2

Sunder 0.6.2

Minimized title-bar conversation counts/icons now restore the window directly, including when the list is empty. The expanded-window count retains its conversation picker. Header navigation is parented to the permanent title bar rather than the sample/body panel, so collapsing the body cannot hide or disable restore controls. The minimized title can also be clicked to restore.

Minimizing now includes already-unread conversations in the waiting stack, not just messages arriving after collapse. The stack lives independently above the window and has explicit clickable rows. Each row expands the window, selects its person and reveals that person's selected row after the restore animation. New incoming messages update the same person's row. The stack grows upward with animated height, row position and opacity.

Keep waiting previews until read is enabled by default under Whispers > Window & Visibility. Disable it to use the configured preview duration. Preview enable/disable, row limit and dismiss controls remain available. Reading or dismissing removes the relevant preview; all sample rows are cleaned up with the test, including detached sample hosts. Nothing from sample conversations is saved.

Collapsed list viewports no longer receive inverted top/bottom bounds, and the sample body is explicitly hidden while minimized. Header visibility is restored on every transition. Legacy collapsed geometry is healed on restore, and a minimized height cannot overwrite the saved full window height.

Validation: in-game reproduction of the original thin-strip state, repeated populated/empty minimize and restore actions, three upward waiting rows, click-to-open Torin, and restoring via the unread-count button. Automated checks cover six repeated cycles, body-independent header/tray parents, waiting-row seeding and persistence, correct-person selection, empty-count restore, collapsed-geometry recovery, scrollbar/background/native editor/history regressions. No real whispers were sent.

# 0.6.1

Sunder 0.6.1

Overflow in the people list now reveals a slim, proportional scrollbar with a wider grab area. It supports dragging, wheel input and subtle above/below end indicators. It hides when all people fit, when minimized, or when using the tab layout. Header paging and search remain available.

The Whispers body now paints one full-width, full-height surface across the people and conversation columns. It uses the existing chat background color, opacity and edge-fade proportions without restarting gradients at the column boundary. Column gradient fragments are explicitly retired, and grouped native message rows/gap fillers defer to the common surface. Text and controls retain their opacity.

Minimized incoming previews are now an explicit feature rather than relying on exposed body content. A compact stack grows upward above the minimized bar, with the latest person nearest the bar. Each person gets one row; later whispers update that row. Clicking restores the window, selects and reveals the correct conversation, and uses the existing selection highlight. Each row also has a dismiss button.

Whispers > Window & Visibility includes Show incoming whispers above minimized windows, Maximum minimized whisper previews (1-5, default 3), and Whisper preview duration (5-60 seconds, default 20). Stacks animate height, row movement and opacity, and expire gracefully without marking messages read. Only session references and text are retained; preview content is never saved. Test cleanup includes preview stacks in retired/detached sample hosts. Protected native content uses a generic notification rather than attempting to expose it.

Validation: Lua 5.1 regression checks for proportional thumb geometry/dragging, overflow end cues, no-overflow hiding, continuous surface bounds and native background suppression, bounded upward stacks, duplicate updates, sample/native click-to-restore selection, option off, expiry/unread preservation, detached sample cleanup, redocking background reset, editor bounds, saved real-history limits and the existing conversation/simulation/layout checks. The existing screen was inspected; post-reload visual verification is still pending.

# 0.6.0

Sunder 0.6.0

Whispers now defaults to a two-column workspace below a distinct window title: people on the left (30%) and the selected conversation on the right (70%). Click a person to read their conversation. The native chat renderer, smooth scrolling and individual editor remain in the right pane. Shared chat typography, subtle header gap, borderless fading surfaces and window controls are retained.

The people list scrolls vertically with the mouse wheel or the header's up/down paging controls. The all-conversations button still provides search and jump-to-person. Pinning keeps people first. Name/unread/recent sorting, selected-person reveal, unread badges and inline star/pin controls work vertically. Drag names to reorder or move between regular group lists/headers, with a horizontal insertion marker and top/bottom edge scrolling. Favorites remain excluded from cross-group dragging; use the star to route someone there.

Favorites uses the same conversation list. Active conversations appear first, and saved people without an active conversation appear below without duplicate names. Selecting a saved person opens their native whisper conversation without sending a message.

Appearance > Whisper windows > Conversation layout switches between People list & conversation and the previous Conversation tabs. Selection and manual order are retained. People column width is adjustable from 25% to 45%, with a 30% default and minimum readable widths. Existing custom names and saved conversation data are preserved; old default Messages / Messages N labels display as Whispers / Whispers N. Visible window, menu, minimap and settings labels now use Whispers. Internal saved-variable names and existing shortcuts remain compatible.

Minimized bars retain unread/navigation controls and existing smooth collapse/restore behavior. The five-minute scenario supports the new list: staggered arrivals, two-way conversations, quiet fade periods, Favorites/detached routing, pin behavior, automatic cleanup and the independent countdown.

Validation: Lua 5.1 regression checks for native/sample pane bounds, 30-person vertical lists, paging and selection reveal, sorting/pinning, drag insertion and edge scrolling, real drag transfer between columns, Favorites roster deduplication and offline people, layout round trips, default-name migration, the complete five-minute scenario, editor focus/bounds, appearance schema and shared fades. In-game visual verification remains outstanding.

# 0.5.1

Sunder 0.5.1

The five-minute message test now stages new conversations instead of repeatedly appending random incoming lines to an already-populated inbox. People arrive in three waves, hold coherent two-way exchanges, and return for final replies. At the default 10 people this produces 120 lines: 60 incoming messages and 60 outgoing replies. Larger configured sample counts remain supported. Only incoming messages play notification sounds.

Quiet intervals exercise the temporary 12-second idle timeout and the selected fade duration. New incoming messages reveal faded windows; replies continue in the same person's Favorites/group/detached destination. Pinning, hovering and minimizing retain visibility as before. Explicitly closed windows are respected.

A compact status pill above Messages displays the remaining time, current phase and a thin progress line. It stays visible even when Messages fades and has a stop/clear icon. It does not add height to message-window headers. The tooltip explains the sequence and visibility rules.

All test content and scenario state remain session-only. Stop/clear, five-minute expiry and real incoming whispers clean up the scenario and timer. Previous window states are restored. Reload discards the simulation without resuming it.

Validation: full simulated 300-second timeline, staggered arrivals, all 120 messages, incoming/outgoing balance, three quiet fades/revivals, countdown visibility, Favorites and detached routing, minimized unread totals, pin/unpin behavior, stop control, incoming-only sounds, expiry, saved-state isolation and existing styling/history regression checks. In-game visual verification remains outstanding.

# 0.5.0

Sunder 0.5.0

Minimized Messages and Favorites retain their header controls, unread indicators and conversation navigation. Matching compact headers also retain their person tabs; selecting a conversation restores its window. Custom two-row styling retains a compact conversation counter on the minimized bar.

Collapse and restore animate height with smooth acceleration/deceleration and fade the body independently of the interactive header. Top/bottom collapse anchors and saved full heights are preserved. Animation handlers are removed when complete or interrupted; clipping is limited to the transition so conversation pickers remain usable outside the header.

Whispers > Samples & testing now includes Run five-minute message test and Stop test and clear all samples. The test sends messages among the sample people in 30-second bursts with quiet periods, using a temporary 12-second idle delay and the selected fade duration. Hover, pin, minimize, move, favorite and detach remain available. Test windows reappear on the next generated message unless explicitly closed. The temporary fade rules apply only to sample windows, allowing visibility testing without changing saved preferences.

The scenario clears all sample data after 300 seconds, on explicit clearing, or when a real whisper interrupts it. Sample messages, people, favorites, pins and scenario state remain in memory only. Previous open/minimized window states are restored when testing ends. Reload also discards samples; no test resumes automatically.

Validation: Lua 5.1 regression suite including Favorites minimized counters, header tabs/controls, intermediate animation alpha and height, interrupted transitions, burst/quiet/reveal behavior, expiry, cancellation, window-state restoration, real-whisper interruption, editor focus, saved real history limits, shared styling and surface fades. Live in-game visual verification remains outstanding.

# 0.4.2

Sunder 0.4.2 removes the extra Messages header padding below the centered tab labels. Matching Messages headers now use the chat tab-row height, retaining the shared header/body spacing setting for native conversations and samples. Custom window styling remains unchanged.

# 0.4.1

Sunder 0.4.1 makes pinned conversations move to the front and stay ahead of unpinned tabs through every sort and drag operation. Pinning still prevents inactivity hiding. Pin order and state persist for real character conversations.

Messages, Favorites and custom groups now use a single compact header by default when matching chat styling: title, person tabs, paging, unread count and essential window controls share one row. Shared typography, backgrounds, fades and the subtle body gap remain intact. Right-click a person tab or window title for additional actions. Appearance > Message windows > Single-row Messages header restores the separate tab row if desired.

Validation: Lua 5.1 regression checks for pin ordering, saved order, drag boundaries, sample selection, content insets, compact navigation, fallback layout, editors, window persistence, shared styling and fades.

## 0.4.0 — Conversations you can arrange

- Unified message titles and tab labels with the rendered native chat header font, size, flags and shadow, clearing explicit font overrides left by optional skins.
- Added drag ordering within message groups, an insertion marker and edge scrolling. Cross-group drops insert at the chosen position. Favorites can be arranged internally while remaining excluded from cross-group drag transfers.
- Added one-time sorting by name, unread count, recent activity or pin state to title/tab/window menus and Windows & Favorites settings. Sorting preserves the active conversation and reveals its tab. Native character conversation order is remembered per group across reloads; sample order stays session-only.
- Moved pin controls beside individual names, next to favorite stars. Removed the duplicate pin/favorite controls from the visible header toolbar. Native pin changes are saved immediately.
- Replaced marked test names/messages with 30 distinct names and natural two-way exchanges, including replies from You, quieter outgoing text, shared sender accent, timestamps and an unread boundary when opening unread samples.
- Removed Preview from visible window titles, tab names, conversation text and the footer. Sample provenance remains available through settings and the title tooltip. Samples never create recipients or send whispers.
- Added right-click title actions and long-name tooltips; retained unified borderless styling, native editors, smooth chat scrolling, resizing, minimizing, Favorites and group transfer behavior.
- Validated exact font copy, native order save/restore, sorting, drag insertion/edge scrolling, pins, sample formatting/isolation, editors, history and persistence. Checked inline pin, within-window drag and alphabetical sorting in game.

## 0.3.9 — Chat-matched Messages by default

- Messages, Favorites, custom groups and previews now follow chat styling by default. Existing custom values remain saved and can be restored by disabling Match chat styling under Appearance > Message windows.
- Shared header fonts, icon sizing/opacity, label/accent colors, background/header colors and opacity, edge fades and header/body spacing replace the previous separate default theme.
- Compact headers and conversation tabs, borderless surfaces, unboxed toolbar/navigation buttons and fine selection accents preserve the original chat aesthetic. Grip, minimize, resize, groups, favorites, pins, detaching and tab navigation remain available.
- Removed double background tint behind native conversations: their own scrolling chat backgrounds render directly, while empty/preview/Favorites surfaces use matching shared backgrounds. Headers and conversation strips remain distinct from the message body with shared spacing.
- Added live inheritance for shared font, color, icon and spacing changes. Custom-only controls are clearly disabled while following chat.
- Kept long conversation names on one line and added full-name preview tooltips.
- Validated unified and custom modes, Favorites, background ownership, minimize geometry, preview interactions/navigation, persistence, editors and resize. Inspected compact minimized/expanded and populated preview windows in game.

## 0.3.8 — Unified appearance and quiet chat headers

- Added a global Appearance section with Design & preview, Typography, Chat headers, Surfaces & colors and Message windows pages. Moved shared text controls out of feature-specific pages without changing saved values.
- Added subdued chat title icons, automatic Guild/combat/conversation roles, per-tab icon overrides, adjustable icon spacing/opacity and a fine selected-tab accent. Optional hover wash and text-only/refined header presets preserve existing fonts, geometry and scrolling behavior.
- Decorations belong to the native chat tabs, inheriting their dock, clipping and fading. Native conversation identity icons are preserved. No added scroll animation, title bar or per-frame decoration timer.
- Unified Messages titles, marks, selected conversation tabs and borders with the chat selection accent and optional Ellesmere integration.
- Added opt-in Messages background/header edge fades using the shared chat fade distances, independent background opacity and fully opaque text/controls. Covers Favorites, custom groups and previews, with solid fallback.
- Added /sunder appearance; retained global move/resize controls across settings and shortcuts from Chat/Whispers. Removed the redundant Whispers Appearance page to reduce tab crowding.
- Verified real configuration ownership, saved-setting preservation, shared gradient bounds/opacity, icon states and overrides, editor/resize behavior, preview navigation and window persistence. Inspected the global settings and slim chat headers in game.

## 0.3.7 — Typography and global window layout

- Added Whispers > Appearance: inherited/custom interface fonts, title/tab sizes, outlines, toolbar icon size, header padding, button spacing and conversation tab width/height/padding.
- Exposed shared chat message font, size, outline, line spacing and message padding on the same page. Changes also update local previews.
- Header, minimized height, tab navigation, drag targets and content layout use shared metrics. Larger toolbar controls reserve a readable title area; resizing respects this minimum.
- Removed the conversation subtitle branding and renamed the mover dialog to Window layout.
- Added one shared move/resize toggle throughout settings, including Ellesmere pages and standalone fallback, replacing the old Chat-only action.
- Verified typography fallbacks, high-size layouts, previews, tab navigation, open/minimized restoration, editors, resize and settings schema.

# 0.3.6

- Remember open/closed and minimized state for Messages, Favorites and custom groups per character.
- Restore empty open groups after reload/login.
- Prevent restored conversation tabs from reopening explicitly closed groups.
- Preserve state through shutdown and temporary feature disabling.

# 0.3.5

- Evenly spaced conversation navigation: matching arrow buttons, consistent gaps and outer padding.
- Separate, vertically centered inbox icon and count with a wider hit target.

# 0.3.4

- Permanent conversation paging arrows and count button outside the clipped tab strip.
- Searchable conversation picker with unread/pinned/favorite prioritization.
- Offscreen-unread indicator, selection reveal and bounded scrolling on resize.
- Shared navigation for real and preview conversations.

# 0.3.3

- Clickable favorite stars on each conversation tab.
- Interactive preview pinning, favorites, detaching, group moves and tab dragging.
- Ten distinct sample people by default, with configurable history size.
- Clear all samples across groups and detached sample windows without changing real contacts or conversations.

# 0.3.2

- Balanced header padding with separate grip, icon and title spacing.
- Per-window collapse edge: top/downward expansion or bottom/upward expansion.
- Shared Messages/Favorites/group background color, background opacity, title opacity and border opacity controls.
- Background transparency preserves text and control visibility, with or without Ellesmere.

# 0.3.1

- Direct title renaming for regular message windows, including Messages.
- Drag conversation tabs between regular group headers; Favorites excluded.
- Permanent dotted move grip, independent of resize lock.
- Eased minimize/restore, preserved full size and accurate unread state.

# Sunder changelog

## 0.3.0 — 2026-11-09

- Replace text-character window controls with original antialiased icon artwork,
  tooltips, hover/press feedback and disabled states. Add a dedicated header,
  selected-tab styling, themed underline and illustrated empty states.
- Add independent named message groups with separate selection, editors,
  position, size and visibility, unified move/resize locks and a window switcher.
- Add Favorites with remembered character contacts, an independent window and
  optional automatic routing. Reopen a favorite's conversation without sending
  anything. Battle.net favorites remain session-only; pins remain independent.
- Move conversations between groups, the main chat dock and detached native
  windows while preserving scrollback. Remove groups by returning chats to Messages.
- Add Windows & Favorites settings and /sunder favorites.
- Pool removed window shells and contact rows; cache unchanged tab labels,
  badges, title and styling. Keep automatic sound tests out of chat output.
- Use Ellesmere's supported shell, font and tab styling with standalone fallback.
- Validate group transitions, editor ownership, favorites, geometry, locks,
  protected moves and frame reuse in tests; inspect icons, groups and menus in WoW.

## 0.2.2 — 2026-11-09

- Fix Messages preview's repeated font-rendering errors on the Forever client.
- Generate 12 sample conversations with 40 messages each by default; configure
  up to 30 conversations and 200 messages per conversation.
- Generate incoming batches of 5–200 messages (50 by default), with one sound per batch.
- Add Clear all sample data, clearing rendered text, sample conversations and
  automatic generation without modifying real whisper history.
- Report sound playback success or failure during sound tests.
- Verify rendering, incoming batches, tab switching, scrolling and sample cleanup
  in the running game; add a regression check using Blizzard's font mixin.

## 0.2.1 — 2026-11-09

- Keep Messages window open by default, including when empty, until explicitly closed.
- Start a fresh visibility interval on manual opening when timed fading is selected.
- Add Preview & testing: three seeded local conversations, unread badges, timestamps,
  repeatable reset, test notifications, optional sound and automatic notification intervals.
- Keep preview data outside native whispers and saved history; disable real Reply,
  Pin and Detach controls while previewing and stop on real conversation activity.
- Keep preview sounds separate from real notification cooldowns.


## 0.2.0 — 2026-11-09

- Add the Whispers feature with four settings pages: Conversations, Window &
  visibility, Sounds, and Display & history.
- Route native per-person conversations to main chat tabs or a separate Messages
  window. Support character and Battle.net conversations, individual editors,
  duplicate suppression and GM-message exceptions.
- Keep main/hub/detached transitions, pooled conversation identity, per-window
  sizing/position, unified locks and scroll position consistent.
- Add unread badges, pins, reply/detach/search/copy actions, overflow scrolling,
  mark-all-read and close-read-unpinned controls.
- Add inactivity fading, hover/typing/unread/pin protection, incoming reveal and
  optional automatic selection that doesn't interrupt active text input.
- Bundle two original chimes; add SharedMedia/custom paths, preview, output
  channel, throttling, DND/combat controls and optional native-ping replacement.
- Add independent conversation timestamps and bounded character history with
  original arrival times. Never persist Battle.net conversation identities/text.
- Add /sunder whispers, /sunder messages and a minimap Messages shortcut/unread count.
- Preserve standalone fallback and native Ellesmere configuration/skin integration.

## 0.1.1 — 2026-11-09

- Show editors only while typing, with the existing background and message-space animation.
- Keep native per-window input routing without permanent inactive IM editor boxes.

## 0.1.0 — 2026-11-09

- Fork the customized Glassy 1.9.7 chat foundation into an independent addon.
- Keep main/detached chat movers, resize handles, unified locks and individual editors.
- Correct editor-area overlay coverage and unused Combat Log toolbar padding.
- Add a minimap launcher with saved position, visibility toggle and tooltips.
- Add Home, Chat, addon-wide profiles and About; register future features through
  a shared configuration schema.
- Use native EllesmereUI configuration pages when available, with standalone fallback.
- Retain optional Ellesmere window skin, accent and default-font integration.
- Migrate Glassy settings once without sharing nested data or running both renderers.
- Forward all event payload arguments so editor ownership reaches subscribers.
