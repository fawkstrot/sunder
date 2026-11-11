## Arrangement and natural samples in 0.4.0

Within a group, drag a tab name toward the insertion marker. Holding near either edge scrolls the strip. Regular groups accept tabs at the chosen position; Favorites supports internal ordering. Right-click the title or a tab for name/unread/recent/pinned sorting. Sorting keeps the conversation being read selected and visible. Character order is saved per group; Battle.net and sample identities are not persisted in the order store.

Pin and favorite controls are beside each person's name. Pins keep conversations visible; stars preserve people in Favorites. Header duplicates are hidden. Native pins save immediately.

Samples use 30 distinct names, natural exchanges with replies from You, shared incoming sender accents, quieter outgoing text, timestamps and an unread boundary. Preview labels and numbered test lines are gone from the conversation surface. Samples remain isolated and session-only; Reply never targets a sample person. The title tooltip and Samples & testing page identify the local sample session. Clear all sample data also stops automatic sample notifications.

## Shared styling in 0.3.9

**Match chat styling** is on by default under Appearance > Message windows. It inherits shared chat label fonts, icon size/opacity, label/accent colors, header/message backgrounds and opacity, edge fades and header/body spacing. Windows have compact headers and conversation strips without outer borders or filled button tiles. Native conversation backgrounds render directly without an extra shell tint. Previews and empty/contact surfaces use the same background settings.

Disable Match chat styling to use the previously saved independent Messages appearance. Custom-only controls are disabled while following chat; values are retained. Geometry, Favorites, grouping, tab transfers, pinning, detaching, resizing and minimize behavior remain independent of this presentation choice.

## Appearance location in 0.3.8
Visual settings now live under **Appearance**, available with `/sunder appearance`. Shared text belongs to **Typography**; Messages title/toolbar/tab sizing belongs to **Message windows**; backgrounds and shared edge-fade blending belong to **Surfaces & colors**. These locations supersede older Whispers > Appearance instructions below. Existing settings retain their values.

# Whispers

Open `/sunder whispers`, or use the minimap emblem → Whispers.

## Choose a layout

**Tabs in main chat** is the default. Incoming and outgoing character/Battle.net
conversations get a native per-person tab. New incoming messages leave your
current tab selected. Unread badges identify conversations you haven't read.

**Separate Messages window** groups conversations into a movable, resizable
window. Choose this in Conversations → New conversation layout. Open or recover
it with `/sunder messages` or Shift-left-click the minimap emblem.

**Native inline chat** stops automatic creation of new conversation tabs and
leaves ordinary native delivery and sound behavior intact. Existing conversation
windows aren't closed or erased when changing modes.

Suppress whispers in other chat windows controls duplicate incoming and outgoing
delivery for the two conversation layouts. It never suppresses GM messages.

## Read, reply, pin and detach

- Click a conversation to read it; use Reply or Enter to type in its own editor.
- New messages don't interrupt an active text field, even with automatic selection enabled.
- Right-click a Messages tab for Reply, Pin, Detach, move to main chat, Search/copy,
  Mark read and Close. Shift-click pins; middle-click closes.
- Main-dock whisper tabs have placement and pin options in their native right-click menu.
- Detach makes a normal Sunder chat window. `/sunder lock` reveals its blue mover
  and bottom-right resize handle, along with the main chat and Messages movers.
- Pinning keeps a conversation's window visible. Unpin or close it to release it.
- Unread state remains while scrolled back. Switching conversations and changing
  layouts preserve your scroll position. Selected tabs scroll into view automatically.

Locking ends and saves an active move/resize. The Messages window has a reset
position button and size controls. Character conversation placement and pins are
remembered separately from message history. Protected-frame layout changes are
deferred until combat ends.

## Visibility

**Keep Messages window open** is enabled by default under Window & visibility.
Messages stays visible even without conversations, until you close it. Turn that
setting off to use timed fading. Manually opening it starts a fresh interval,
including when it is empty, so it no longer disappears immediately.

The timed Messages window and individual detached conversations can stay visible or
fade after a configurable interval (default 90 seconds, then a 0.6-second fade).
Hovering, typing, editing the layout, pinned conversations, and optionally unread
messages keep them visible. New incoming messages can reveal them again.

Opening/selecting a conversation normally restarts the timer. Disable that option
to measure strictly from the last message. Main-dock tabs continue to share the
main dock's visibility; their message fading uses the whisper hold-time setting.

## Message groups and Favorites

Use **Windows & groups** to create named groups, rename them, open them, and
choose whether each stays visible. The overlapping-windows icon opens the window
switcher. A conversation's right-click menu can move it to any group or create a
new group for it. The arrow-out icon detaches the selected conversation into its
own native chat window. Each group has an independent selected conversation,
editor area, position and dimensions. The dotted grip moves a window; Chat layout mode enables resizing.
Removing a custom group returns its chats to Whispers.

The star marks a person as a favorite within Whispers. Use All, Unread and Favorites
to filter the same people list. Starring or un-starring never moves a conversation
between windows. Saved favorite contacts can reopen a conversation without sending
a message. Pins separately keep conversations from fading. `/sunder favorites`
opens the Favorites filter; there is no standalone Favorites window.

Upgrading merges the retired Favorites window into Whispers, preserving contacts,
conversation history and saved order. Its old window settings are removed. Custom
groups and intentionally detached conversations remain available.

Window groups and favorite contacts are saved per character. Keep-history settings
still control saved message text independently. Window shells and contact buttons
are reused, and unchanged labels/badges are cached instead of recreated each tick.

## Sounds

The two bundled choices are Soft chime and Bell. Installed SharedMedia sounds
also appear in the list. Preview checks the selected sound without waiting for a whisper.

For a custom file, select Custom file path and enter a path such as
`Interface\AddOns\SharedMedia\sound\my-whisper.ogg`. Files must be installed
under WoW's Interface folder; restart WoW after adding a new file. OGG, MP3 and
WAV paths are accepted. No separate sound library is required.

Choose Master, Sound effects, or Dialogue output, a minimum interval between
sounds, DND/combat muting, and whether to alert only for conversations not being
read. Outgoing replies and restored history stay silent. Replace WoW's default
whisper ping prevents double sounds and lets these notification settings control
the native ping too. Turning replacement off leaves the native ping active;
other addons' notification sounds remain controlled by those addons.

## Preview & testing

Open Whispers → Preview & testing, then enable **Preview sample conversations**
or click **Generate / reset sample conversations**. By default this creates 10 distinct people in
clearly labeled conversations with 40 messages each. Adjust the counts before
generating, up to 30 conversations with 200 messages each. Select tabs to read
them and mouse-wheel over the tab strip to browse additional conversations.
Reset gives the same seeded starting state each time.

**Generate incoming message batch** distributes 50 incoming messages across
preview conversations across all sample windows by default. The batch size is adjustable from 5 to 200.
Each batch plays the selected notification sound once. Preview sound can be
disabled separately. Automatic test notifications can run every 2–30 seconds
while preview is active. Their sounds bypass ordinary mute/cooldown controls for
testing, but never alter the cooldown for real notifications.

The preview holds the Messages window open and supports the normal move/resize
overlay. Star individual tabs to favorite sample people, shift-click or use the toolbar to pin, detach into separate sample windows, or drag tabs between regular groups. Reply and search stay disabled. Samples do not create
native whisper recipients, change the chosen conversation layout, send messages,
or enter saved conversation history. Real conversation activity ends preview so
live messages are not obscured. **Clear all sample data** removes the sample
conversations from Messages, Favorites, groups and detached sample windows, stops automatic generation, and restores the
real conversation view. Closing Messages also ends the preview. Preview never starts itself
after login or reload.

## Timestamps and history

Conversation timestamps have independent 12/24-hour and seconds choices. A
recognized native timestamp is replaced locally, without changing other windows'
native timestamp setting.

Remember character conversations is optional and preserves your existing
saved-history choice. Its limits default to 20 conversations and 100 lines each;
the newest active conversations are prioritized. Original arrival timestamps
are retained across reloads. Forget saved conversation history clears the saved
snapshot and disables further text-history saving; live session messages and
separately saved placement/pin preferences remain available.
Restoration runs in small batches to keep login responsive and stops if the
conversation is closed/reused or history saving is turned off.

Battle.net identities and conversation text are never written into the saved
history. WoW handles restricted names and message rendering; Sunder does not
attempt to decode protected content.

## Integration and testing

Whispers uses the same shared settings schema as Chat: native EllesmereUI pages
when available, standalone AceConfig when it isn't. No Ellesmere dependency is required.

The implementation was checked with Lua 5.1 parsing and simulated native chat/UI
tests for routing, duplicate suppression, GM exceptions, incoming-only sounds,
cooldowns/muting, frame reuse, visibility policies, individual editors, layout
transitions, locks/resizing, protected identities, history limits and timestamps.
Actual client rendering, audio levels and secure UI behavior require in-game verification.

## Window interaction

Double-click a regular window title to rename it, or use Rename this window in the windows menu. Drag a conversation tab onto another regular window header or tab strip to transfer it; the destination highlights blue. Favorites does not accept or initiate tab dragging.

The dotted grip always moves the window, even while resize is locked. Unlock mode enables resizing. The minus icon smoothly collapses to the header; click restore to expand. Full dimensions are preserved, unread counts stay visible, and hidden conversations are not marked read.

### Appearance and expansion direction

Under Windows & groups, select a window and choose **Selected window: collapse toward**. Top keeps the top edge fixed and restores downward. Bottom keeps the bottom edge fixed and restores upward. Each group keeps its own choice.

Under Window & visibility > Message window appearance, adjust background color, background opacity, title bar opacity and border opacity. These apply to Messages, Favorites, all custom groups and previews, independently of text opacity and inactivity fading.

### Many conversations

The tab strip reserves space for permanent previous/next page arrows and an all-conversations count button. Mouse-wheel scrolling also works. A gold count signals unread conversations outside the visible strip. Click the count to search every person in this window; unread, pinned and favorite conversations appear first. Scroll the results when there are more than nine. Clicking a result (or Enter on the first result) selects that conversation and reveals its tab. The window keeps its chosen size. This works identically for real and sample conversations.

Use `/sunder preview` to generate/reset samples directly.

### Remembering open windows

Messages, Favorites and custom message groups remember their open/closed and minimized states per character across reloads and logins. Explicitly closing a group keeps it closed when its conversation tabs restore. Manually opening it or revealing it for a new incoming message updates the remembered state. Timed inactivity can still hide an open window; Keep selected window visible prevents that. Samples and detached sample windows remain temporary.


### Appearance (0.3.7)
Whispers > Appearance controls interface font (automatic Ellesmere/native or any registered font), title/tab font sizes and outlines, toolbar icon size, header padding, button spacing, and conversation tab width, height and content padding. These settings are shared across Messages, Favorites, custom groups and preview shells. Header height follows the chosen padding and control size, including while minimized. Windows reserve room for the title when larger controls require it.

Message text controls on this page are shared with Chat: font, outline, size, wrapped-line spacing and message padding. Reset typography & spacing restores the interface controls without changing message routing or shared chat text preferences. The Window layout toggle at the top of settings pages controls all main/undocked chats and message groups. The dotted Messages grip remains available for everyday movement while locked; resizing requires unlock mode.

## Compact headers and pin order

Sunder 0.4.1 makes pinned conversations move to the front and stay ahead of unpinned tabs through every sort and drag operation. Pinning still prevents inactivity hiding. Pin order and state persist for real character conversations.

Messages, Favorites and custom groups now use a single compact header by default when matching chat styling: title, person tabs, paging, unread count and essential window controls share one row. Shared typography, backgrounds, fades and the subtle body gap remain intact. Right-click a person tab or window title for additional actions. Appearance > Message windows > Single-row Messages header restores the separate tab row if desired.

Validation: Lua 5.1 regression checks for pin ordering, saved order, drag boundaries, sample selection, content insets, compact navigation, fallback layout, editors, window persistence, shared styling and fades.

## Minimized controls and five-minute test

Sunder 0.5.0

Minimized Messages and Favorites retain their header controls, unread indicators and conversation navigation. Matching compact headers also retain their person tabs; selecting a conversation restores its window. Custom two-row styling retains a compact conversation counter on the minimized bar.

Collapse and restore animate height with smooth acceleration/deceleration and fade the body independently of the interactive header. Top/bottom collapse anchors and saved full heights are preserved. Animation handlers are removed when complete or interrupted; clipping is limited to the transition so conversation pickers remain usable outside the header.

Whispers > Samples & testing now includes Run five-minute message test and Stop test and clear all samples. The test sends messages among the sample people in 30-second bursts with quiet periods, using a temporary 12-second idle delay and the selected fade duration. Hover, pin, minimize, move, favorite and detach remain available. Test windows reappear on the next generated message unless explicitly closed. The temporary fade rules apply only to sample windows, allowing visibility testing without changing saved preferences.

The scenario clears all sample data after 300 seconds, on explicit clearing, or when a real whisper interrupts it. Sample messages, people, favorites, pins and scenario state remain in memory only. Previous open/minimized window states are restored when testing ends. Reload also discards samples; no test resumes automatically.

Validation: Lua 5.1 regression suite including Favorites minimized counters, header tabs/controls, intermediate animation alpha and height, interrupted transitions, burst/quiet/reveal behavior, expiry, cancellation, window-state restoration, real-whisper interruption, editor focus, saved real history limits, shared styling and surface fades. Live in-game visual verification remains outstanding.

## Scripted conversations and countdown

Sunder 0.5.1

The five-minute message test now stages new conversations instead of repeatedly appending random incoming lines to an already-populated inbox. People arrive in three waves, hold coherent two-way exchanges, and return for final replies. At the default 10 people this produces 120 lines: 60 incoming messages and 60 outgoing replies. Larger configured sample counts remain supported. Only incoming messages play notification sounds.

Quiet intervals exercise the temporary 12-second idle timeout and the selected fade duration. New incoming messages reveal faded windows; replies continue in the same person's Favorites/group/detached destination. Pinning, hovering and minimizing retain visibility as before. Explicitly closed windows are respected.

A compact status pill above Messages displays the remaining time, current phase and a thin progress line. It stays visible even when Messages fades and has a stop/clear icon. It does not add height to message-window headers. The tooltip explains the sequence and visibility rules.

All test content and scenario state remain session-only. Stop/clear, five-minute expiry and real incoming whispers clean up the scenario and timer. Previous window states are restored. Reload discards the simulation without resuming it.

Validation: full simulated 300-second timeline, staggered arrivals, all 120 messages, incoming/outgoing balance, three quiet fades/revivals, countdown visibility, Favorites and detached routing, minimized unread totals, pin/unpin behavior, stop control, incoming-only sounds, expiry, saved-state isolation and existing styling/history regression checks. In-game visual verification remains outstanding.

## People list and conversation layout

Sunder 0.6.0

Whispers now defaults to a two-column workspace below a distinct window title: people on the left (30%) and the selected conversation on the right (70%). Click a person to read their conversation. The native chat renderer, smooth scrolling and individual editor remain in the right pane. Shared chat typography, subtle header gap, borderless fading surfaces and window controls are retained.

The people list scrolls vertically with the mouse wheel or the header's up/down paging controls. The all-conversations button still provides search and jump-to-person. Pinning keeps people first. Name/unread/recent sorting, selected-person reveal, unread badges and inline star/pin controls work vertically. Drag names to reorder or move between regular group lists/headers, with a horizontal insertion marker and top/bottom edge scrolling. Favorites remain excluded from cross-group dragging; use the star to route someone there.

Favorites uses the same conversation list. Active conversations appear first, and saved people without an active conversation appear below without duplicate names. Selecting a saved person opens their native whisper conversation without sending a message.

Appearance > Whisper windows > Conversation layout switches between People list & conversation and the previous Conversation tabs. Selection and manual order are retained. People column width is adjustable from 25% to 45%, with a 30% default and minimum readable widths. Existing custom names and saved conversation data are preserved; old default Messages / Messages N labels display as Whispers / Whispers N. Visible window, menu, minimap and settings labels now use Whispers. Internal saved-variable names and existing shortcuts remain compatible.

Minimized bars retain unread/navigation controls and existing smooth collapse/restore behavior. The five-minute scenario supports the new list: staggered arrivals, two-way conversations, quiet fade periods, Favorites/detached routing, pin behavior, automatic cleanup and the independent countdown.

Validation: Lua 5.1 regression checks for native/sample pane bounds, 30-person vertical lists, paging and selection reveal, sorting/pinning, drag insertion and edge scrolling, real drag transfer between columns, Favorites roster deduplication and offline people, layout round trips, default-name migration, the complete five-minute scenario, editor focus/bounds, appearance schema and shared fades. In-game visual verification remains outstanding.

## Overflow feedback and minimized whisper previews

Sunder 0.6.1

Overflow in the people list now reveals a slim, proportional scrollbar with a wider grab area. It supports dragging, wheel input and subtle above/below end indicators. It hides when all people fit, when minimized, or when using the tab layout. Header paging and search remain available.

The Whispers body now paints one full-width, full-height surface across the people and conversation columns. It uses the existing chat background color, opacity and edge-fade proportions without restarting gradients at the column boundary. Column gradient fragments are explicitly retired, and grouped native message rows/gap fillers defer to the common surface. Text and controls retain their opacity.

Minimized incoming previews are now an explicit feature rather than relying on exposed body content. A compact stack grows upward above the minimized bar, with the latest person nearest the bar. Each person gets one row; later whispers update that row. Clicking restores the window, selects and reveals the correct conversation, and uses the existing selection highlight. Each row also has a dismiss button.

Whispers > Window & Visibility includes Show incoming whispers above minimized windows, Maximum minimized whisper previews (1-5, default 3), and Whisper preview duration (5-60 seconds, default 20). Stacks animate height, row movement and opacity, and expire gracefully without marking messages read. Only session references and text are retained; preview content is never saved. Test cleanup includes preview stacks in retired/detached sample hosts. Protected native content uses a generic notification rather than attempting to expose it.

Validation: Lua 5.1 regression checks for proportional thumb geometry/dragging, overflow end cues, no-overflow hiding, continuous surface bounds and native background suppression, bounded upward stacks, duplicate updates, sample/native click-to-restore selection, option off, expiry/unread preservation, detached sample cleanup, redocking background reset, editor bounds, saved real-history limits and the existing conversation/simulation/layout checks. The existing screen was inspected; post-reload visual verification is still pending.

## Stable minimized controls and waiting rows

Sunder 0.6.2

Minimized title-bar conversation counts/icons now restore the window directly, including when the list is empty. The expanded-window count retains its conversation picker. Header navigation is parented to the permanent title bar rather than the sample/body panel, so collapsing the body cannot hide or disable restore controls. The minimized title can also be clicked to restore.

Minimizing now includes already-unread conversations in the waiting stack, not just messages arriving after collapse. The stack lives independently above the window and has explicit clickable rows. Each row expands the window, selects its person and reveals that person's selected row after the restore animation. New incoming messages update the same person's row. The stack grows upward with animated height, row position and opacity.

Keep waiting previews until read is enabled by default under Whispers > Window & Visibility. Disable it to use the configured preview duration. Preview enable/disable, row limit and dismiss controls remain available. Reading or dismissing removes the relevant preview; all sample rows are cleaned up with the test, including detached sample hosts. Nothing from sample conversations is saved.

Collapsed list viewports no longer receive inverted top/bottom bounds, and the sample body is explicitly hidden while minimized. Header visibility is restored on every transition. Legacy collapsed geometry is healed on restore, and a minimized height cannot overwrite the saved full window height.

Validation: in-game reproduction of the original thin-strip state, repeated populated/empty minimize and restore actions, three upward waiting rows, click-to-open Torin, and restoring via the unread-count button. Automated checks cover six repeated cycles, body-independent header/tray parents, waiting-row seeding and persistence, correct-person selection, empty-count restore, collapsed-geometry recovery, scrollbar/background/native editor/history regressions. No real whispers were sent.
