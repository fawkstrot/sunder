# Party Chat

Open with `/sunder party` (or `/sunder raid`) or Chat > Party Chat > Open Party Chat. Automatic opening on joining is the default. Open/closed/minimized state and geometry are remembered per character. Enable **Open manually only** in Chat > Party Chat to suppress automatic joining behavior. Automatic opening preserves the saved minimized state and never selects/focuses an editor. `/sunder party` explicitly opens/restores the room. A room closed during the same party stays closed on ordinary roster refresh/reload; a new party opens it again unless manual-only is enabled.

## Group lifecycle

| State | Presentation and behavior |
| --- | --- |
| Solo, no messages | Neutral empty state, no members and no active party editor. |
| Solo, previous conversation | Last group transcript remains read-only. |
| In a party | Native party channel, compact member roster, leader/role summary and available instance/difficulty caption. |
| Converted to raid | Same room, geometry and session; title becomes Raid Chat and roster expands up to 40 members. |
| Instance group | Native instance-chat channel is selected where the client exposes that category. |
| A different group | Archive the former session before starting the new live transcript; unsent draft is cleared to prevent cross-party bleed. |
| Reload in same group | Recall resumes when the saved roster fingerprint matches. Ambiguous/changed membership starts a separate live session after archiving the previous conversation. Partial startup rosters do not erase the saved transcript. |
| Combat channel/layout changes | Native editor/geometry changes defer; unavailable party input is not selected and no draft is sent automatically. |

Member rows use the shared compact person component: class-colored name, muted smaller level/class, balanced separators, right-side dim inactive favorite/pin actions, selection accent and common scrollbar rail. Favorite changes use the same per-character contact store as Guild and Whispers. Group pins persist per character, capped at 200. Normal order puts the leader first, then available assigned roles and name, after the shared favorite/pin tiers. Missing roles/levels are not guessed.

Connection and ready-check status are passive native observations. Role/leader/ready details appear in hover text; a ready-check summary appears in the caption while active. Search appears in raids only and includes names, class and role/status; party rosters have no search field or reserved gap. Selection stays in the room; an explicit Whisper action or double-click opens a whisper without sending a message. There are no automatic invites, ready checks or other group actions.

## Shared architecture

`Components/RosterRoom.lua` is the actual shared controller implementation used by Guild and Party for shell/chrome composition, roster viewport and virtualization, transcript/input layout, native-slot recovery, window-state restore and bounded recent recall. It delegates movement, collapse, maximize, position lock, normal/edit resizing, surfaces, action semantics and typography to WindowManager and the existing Whispers room primitives. Party supplies group lifecycle, roster data and native channel adapters.

WindowManager registers room controllers. UIManager, native renderer saves, favorite refresh and Ellesmere movers resolve that registry rather than hard-coding separate Guild/Party routes. Each real room root has one mover; its parked native frame is not a duplicate edit target. Settings links point to Chat > Party Chat, including when the visible title is Raid Chat.

## Unread and history

Header unread uses the same icon/count geometry and idle/unread colors as Whispers/Guild. It counts live incoming messages while hidden/minimized, excludes the player's GUID and irrelevant group channels, clears on expanded viewing/restore, caps at 9,999 and displays 99+. There are no party toasters. General and other windows retain their own filters and input routing.

The recent native-recall store retains up to 200 lines / 512 KiB for the current session. PartyHistory accumulates older groups until the player confirms clearing group room histories in settings. An estimated 4 MiB triggers a review reminder. The group browser pages long transcripts and recycles visible group rows. /sunder history separately records delivered group conversation events even with the room closed. Previous groups are available through the header info button, with dates, member previews, hover member lists, message counts and a read-only transcript. Back to live chat returns to the untouched live conversation. The archive never replaces the native receiving frame; incoming messages continue and accumulate unread while browsing. Disabling recording keeps existing saved conversations. The archive migrates any nonempty legacy recent history on refresh; messages already absent from both saved files cannot be recovered.

## Validation

The CLI includes `test_party_chat.py` plus existing Guild/shared regressions. Coverage includes solo/manual state, settings not opening a room, optional automatic opening without editor ownership change, group/raid/instance routing, roster virtualization, favorites, own/incoming unread, minimized roster restore, leave/read-only state, different-group draft/transcript reset, combat deferral, ready-check events, same-group recall and byte/line bounds, partial startup data, orphan-slot recovery, closed/minimized restoration and actual-root mover registration. Existing Guild, Whispers, renderer, lock, history, migration and standalone settings suites remain required.

Live acceptance after a safe `/reload`: open `/sunder party`; inspect solo or current-party layout and Enter routing, shrink/resize/lock/minimize both directions, toggle roster/favorites, compare class/level/role/count with actual group, observe an incoming message while minimized, leave/read prior transcript, join another group and confirm clean history. Party-to-raid conversion, instance category and actual secure editor behavior require native-client verification. No group messages or group-management actions are automated during visual review.

2026-11-14 policy correction: the previous implicit manual default migrates once to automatic opening, including the current party. Explicit manual-only choices made with the new setting are retained. The migration does not reset geometry or minimized state.

2026-11-14 transcript correction: message rows now bind explicitly to their renderer, including the native clipping viewport hierarchy, so text wraps to the actual conversation column and respects scrollbar clearance. This shared fix applies to ordinary/Guild/Party/Whispers rendering, not a Party-only override.


Open Party/Raid Chat (including minimized) filters group copies from General without changing saved subscriptions. Closing/disabling restores General; other tabs remain unaffected. A selected room releases Enter to General on close/leave while retaining drafts.


Current expanded people-column width is 150 px, owned solely by WindowManager.PEOPLE_SIDEBAR_WIDTH and applied through PeopleSidebarWidth. This supersedes measured-name, saved maximum and percentage sizing; narrow windows still preserve transcript space.


The shared TextProcessing label adapter removes the redundant native channel label only inside this registered room, retaining sender links and message text. General/other tabs keep their channel context. Saved history remains original native text.


Solo retains the normal member pane and conversation layout. The caption owns the single join instruction; no duplicate central message or enlarged icon is shown. A retained conversation stays visible under Previous group. Empty native slots during initialization cannot overwrite a nonempty saved transcript for the same session.


## Group archive and leader registration - 2026-11-15

Every dedicated slot explicitly subscribes to PARTY/PARTY_LEADER, RAID/RAID_LEADER/RAID_WARNING and INSTANCE_CHAT/INSTANCE_CHAT_LEADER, including repair of existing saved slots. No own-sender filter hides local messages; own messages are excluded only from unread counts. Presentation remains compact and uses the existing reply tint.

ReadOnlyTranscript is a shared component using the production MessageLine pool, explicit renderer width, native hyperlinks, TextProcessing timestamps/labels, body padding, wrapping and WindowManager scroll indicators. It removes editor-selection behavior only for read-only archive rows. Party supplies the archive browser and group lifecycle. Archive metadata copies member identity/class/level, and stores native message text separately from formatting; it never sends chat, targets members or alters group membership.

Regression coverage includes repaired leader subscriptions, archived leader/member lines, new-party retention, reload deduplication, retention beyond the former group limit, read-only input and unread policy, actual shared row reflow/link handlers, browser open/return and recording-disabled preservation. Live sender/category rendering still needs native observation after deployment; mocks do not establish native registration delivery.

Native follow-up confirmed archive selection/log rendering and all seven native subscription categories, including leader event registration. The archive replaces underlying roster/caption visibility while open, without altering native receiving history. Its layout skips live roster OnShow refresh scheduling, so it remains idle when nothing changes. Actual new leader-message delivery remains pending a grouped native observation.


Native review on 2026-11-15 confirmed archive persistence after reload, corrected separation from the hidden live roster/caption, and return to the retained live transcript. Leader subscription is registered; new grouped leader-message delivery still needs observation. Legacy logs can lack member snapshots and arrival timestamps; missing timestamps use archive save time, not a recovered original arrival time.

Previous groups uses the full transcript column and the same horizontal inset and wrap rules as live group chat. Changing width keeps the visible archive message in view where possible. Changing height updates the scroll track and clamps its offset without rebuilding the log. The archive list uses the configured body inset for its labels.

The Groups chapter of `/sunder practice` runs solo. It includes a previous group, a second group receiving a message while its archive is displayed, conversion to a 40-person raid, an offline member and instance chat. Practice uses a private archive provider and never opens a native group slot.

## Archive roster timeline

The header uses a dedicated archive-box action. Archived names use their observed class colors in the group list, selected group summary, hover lists and roster-change entries, including offline players. Unknown legacy classes remain neutral; class tokens are captured going forward without changing old message text. Historical name versions remain visible.

PartyHistory saves a timestamped roster baseline and compact join/leave/name-change observations. Simultaneous changes become one muted transcript entry, such as “2 members joined · 1 member left”; hover for class-colored names and rename details. Leaving the group adds an end marker. Repeated refreshes, online/offline presence changes and incomplete roster updates do not create departures. GUIDs distinguish a rename from a replacement player. Earlier roster changes cannot be reconstructed; enabling recording again starts a new baseline. No officer/private profile information is collected.

The archive merges messages and roster entries chronologically, caches the merged view, and renders at most 100 entries per page through the existing read-only transcript. Live group reception continues behind the archive. The advisory 4 MiB warning includes recorded roster events; nothing is automatically deleted. The Groups practice chapter includes baseline, departure and end entries with hover details using isolated session data.

Archive member previews, selected-group summaries and preview tooltips omit the viewing character. Display counts include only other names seen. GUID matching also hides the player’s former names; legacy records fall back to realm-aware exact character names. Saved rosters, messages and chronological roster events remain complete. Self-only snapshots show “No other members recorded.”

Archive surfaces inherit the Party root’s body backing and edge fade. PartyHistory supplies archive sidebar/toolbar geometry through RoomSurfaceLayout, including later appearance refreshes; the archive toolbar remains above the transcript fade. Its member preview uses the shared 130 px people-pane target. The header gap and expanded-window minimums follow the same WindowManager preferences as General, Combat Log, Guild and Whispers.

The minus action minimizes Party/Raid into a shared tab above General, with a nonzero unread badge. The receiver, group transitions, history and duplicate suppression remain active while tabbed. Automatic joins preserve this state; click the tab to restore. Directional collapse remains available separately.
