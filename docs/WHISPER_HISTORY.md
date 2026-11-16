# Whispers history

## Behavior

History belongs to the current character. Closing a conversation hides its pane and keeps its transcript. Closed conversations with retained messages remain discoverable in the flat All list; contact-only favorites remain in Favorites until real messages exist. Reopening does not send a message or focus an editor automatically. New incoming whispers can reopen their existing archived transcript.

Right-click a person for **Browse / search saved history** or **Delete saved history…**. Deletion asks for confirmation and closes an open conversation before removing its transcript. A later new conversation with that person starts new history. Favorites/contact membership is separate from deleting message history.

The existing search/copy shell browses the newest saved messages when the query is empty and searches the full retained transcript when a query is entered. It creates no native whisper recipient. Results are limited to 200 lines and 60,000 bytes. Original stored text, links, timestamps, directions and colors are retained; the search surface renders safe, selectable text.

## Retention and performance

The open-tab checkpoint and durable archive have different limits:

| Store | Default | Configurable bounds |
| --- | --- | --- |
| Recent lines loaded into a reopened native pane | 100 per person | 20–200 |
| Conversations reopened after reload | 20 | 5–50 |
| Retained archive lines | 500 per person | 20–1,000 |
| Retained archived people, including open people | 100 | 5–200 |

Archive accounting has an 8 MiB budget for text plus a fixed per-line allowance. This is a storage budget, not a measurement of exact Lua heap usage. Older lines are trimmed at the per-person cap; older ordinary conversations are evicted before favorites when the people or byte budget is reached. Favorites are prioritized, not exempt from all limits. A persistent notice in Whispers history settings reports that trimming occurred. These are durable bounded transcripts, not unlimited permanent storage.

The renderer remains unchanged: only recently reopened panes create native/rendered messages. Closed transcripts are plain saved tables. Replay yields after at most 12 messages. Message-driven saves are coalesced over 0.2 seconds; the larger transcript is reread only for dirty/new native frames and unchanged transcript byte counts are cached, with an additional 10-second checkpoint and shutdown save. Archive merge preserves overlapping message sequences and genuine repeated messages. Original receive time and direction distinguish otherwise identical lines where the client supplies metadata.

WoW writes SavedVariables on normal reload/logout. Checkpoints update the in-memory database; they cannot force the client to flush account files to disk during gameplay. A client crash can still lose changes since its last successful write. This change cannot reconstruct messages already erased before installation.

## Architecture and migration

- `db.char.whisperTabs`: small open-window restore checkpoint, preserving placement, selection and scroll state.
- `db.char.whisperArchive`: durable transcripts indexed by kind plus lowercased character target or stable BattleTag. Imported by value from the existing checkpoint once; no account files are read by development tools.
- `UIManager` captures history before calling native `FCF_Close`; saving only after close would miss released/cleared native buffers.
- `WhisperTabs` guards the delayed startup restore from early native saves. Missing/offline Battle.net contacts retain their archive; browsing works without resolving a current account ID. Opening waits for an available native contact.
- Ordinary open/reopen lazily replays recent archived lines. Frame identity checks, cancellation on opt-out/forget, and per-frame replay guards prevent stale recipient reuse and double replay.
- Confirmed delete removes saved checkpoints and suppresses stale pending snapshots; the global Forget action clears both stores and disables future saving. Samples remain session-only and never enter either store.

## Validation

The CLI runs `tests/regression/work/test_archive.py` for startup-save ordering, timestamp restore, close/reopen, replay idempotence, separate archive/checkpoint limits, overlapping/repeated messages, confirmed deletion, favorite-first trimming, byte bounds and saved-history search. People-list coverage checks closed-person discovery, Favorites retention and identity-based reopening. Existing native input, routing, Battle.net, renderer and migration coverage remains enabled.

Live WoW Forever verification is still required: exchange messages, reload twice, close and reopen ordinary and favorite people, browse older saved messages, receive a new whisper from a closed person, and cancel/accept deletion. Repeat with detached/grouped and Battle.net conversations. Check that restored history neither generates toasters nor sends/focuses chat, timestamps and directions remain correct, and login/gameplay stays responsive. Automated mocks do not prove those native-client outcomes.

### Local validation result — 2026-11-11

The full standard suite passed, including seven behavior entry points, migration checks, temporary deploy/rollback/package checks and seven release tests. Native close-hook integration now verifies capture before release and preservation of the pane if capture fails. Replay coverage includes reuse of the same frame for the same peer while an older chunk is pending.

A synthetic Lua 5.1 archive of 100 people × 500 messages averaged **0.83 ms** for one transcript merge plus budget enforcement over ten passes on this development machine. The benchmark reused cached sizes for unchanged transcripts and merged a 100-line recent tail into one 500-line transcript. This measures that storage pass only, not full saving, client serialization, rendering, login time or in-game FPS. The original uncached pass measured about 6.67 ms and prompted the cache change. Both behavior checks and storage budgets passed afterward; native-client performance remains to be observed.

### User-reported live result — 2026-11-11

User reported “Worked great!” after the durable-history deployment and requested reload/close/reopen check. Record this as successful user-reported in-game validation on WoW Forever. The user did not enumerate individual scenarios; Battle.net, deletion, storage-limit and extended performance checks are not separately confirmed.

### Room presentation follow-up — 2026-11-11

Whispers now shares the Guild room's neutral one-pixel outline, darker compact people column, inset divider and passive scroll affordances. Rows have a font-aware 26 px minimum and selection follows the configured accent. A lower-right corner handle resizes the room directly; collapse and native scroll/editor easing remain cancelable. These presentation changes do not alter archive storage or retention policy.


Whispers title text and empty headers now drag like Guild Chat, with a persistent per-window position lock. All / Unread / Favorites occupy a separate full-width row above both columns. Horizontal edge fades paint above body backing. Archive behavior is unchanged.


### Reusable window theming

Whispers now uses the same WindowManager surface as Guild and native chat. Its former separate whisperSurface rendering path is retired; the internal alias points to the common body frame for transition compatibility. Common code owns blended backgrounds, outlines, header fill and sidebar divider. Explicit custom appearance overrides remain supported. History, favorites and archive behavior are unaffected.


Saved/archived people now have a real star button beside the name. Favorite actions update archive metadata and saved contacts together, expand Favorites on addition and refresh the people list. Open-conversation stars also refresh after state changes and rebind their current frame callback on reuse; unfavoriting clears archived metadata so it cannot resurrect the favorite.


Whispers header numbers now consistently show unread messages; open-person counts remain available in the navigation tooltip. Each unread open-person row has a dedicated numeric badge with reserved width and dark amber backing. Read rows hide it. Favorites and pins use shared filled selected artwork and remain highlighted after hover. Name row spacing is slightly tighter; durable history/archive behavior is unchanged.


Whispers header window controls use shared WindowManager command definitions: separate window menu, maximize/restore size, collapse upward/downward and position lock. Double-clicking the title maximizes/restores; Rename remains in the window menu. The General / Combat Log dock has its own collapse and maximize actions. Favorite/pin and unread behavior remain unchanged.

## People-list presentation — 2026-11-13

All, Unread and Favorites remain filters over one flat list. Live and closed contacts share the Guild row component, with right-side filled favorite/pin controls and real per-conversation unread badges. Ordering is pinned favorites, favorites, pinned, then the existing normal order. Legacy collapsed section flags no longer hide contacts. Closed contacts can be pinned or unfavorited before reopening; pin state follows reopen/restore even with an empty archive. Opening, pinning and favoriting remain separate actions; organizing a row does not mark its messages read.

## Last-known player identity — 2026-11-14

Character-local whisperPersonDetails retains up to 200 learned contact class/level records across reloads. Fresh friend/guild/message data updates known fields; missing/offline level zero does not erase useful identity. Presence and guild public notes are not retained here. Closed and live rows share class-name tint and details. No fabricated levels, active inspect or /who. Details lost before this change cannot be reconstructed from plain transcript text; they return when the client supplies them again.

## Shared person favorites — 2026-11-14

whisperFavorites is the shared per-character contact store used by both Whispers and Guild member stars/cards. SetPersonFavorite synchronizes open records, archived favorite flags and startup snapshots before refreshing all real views. Guild-only legacy favorites merge once without replacing existing contacts; deleting the old preference table prevents later unstar resurrection. Guild changes do not erase personal favorites. A Guild star adds a saved Whispers contact without creating a native conversation, sending messages or marking anything read. Battle.net identities and session-only preview favorites remain separate from character-name contacts.

Migration also unions pre-existing character favorites saved only in archive/open-tab checkpoints once (sharedPersonFavoritesMigrated), before any shared mutation. This prevents an old Whispers-only favorite from remaining invisible to Guild, without repeatedly resurrecting a later unstar. Battle.net checkpoint entries are excluded from character-name contact migration. Added archive-only migration/idempotence regression.

2026-11-14 contact/conversation distinction: starring in Guild/Party adds a saved contact only to Favorites when no messages exist. All excludes empty favorite archives and active empty favorite contacts. First real incoming/outgoing text promotes it to All. Selecting an empty favorite keeps the Favorites filter and shows “No messages yet.” with Enter guidance; it does not send/focus automatically. Known display-name casing is retained with class/level metadata, avoiding lowercase legacy contact labels when native names are available.


Known-offline names retain class color with shared .45 roster opacity; unknown presence stays normal. Presence is session-only and passive from current group, Guild or friends. Active and saved contact menus share eligibility-checked Inspect.


Shared timestamps: Chat > Chat windows > Messages > Content & timestamps > All chat windows (including Whispers) enables a common global 12/24-hour format across new/retained messages and room types. Existing per-conversation timestamp preferences resume when global scope is off. Receipt timestamps and saved message contents remain unchanged; gray is the default display color.


All-chat timestamps are enabled by default, including existing profiles through a one-time policy upgrade. Show timestamps is the shared on/off switch, including Whispers; off remains off after reload. All-window scope retains the common 12/24-hour format.


Rendered Whispers use Name: message for incoming lines and message-only dim styling for outgoing lines. Shared TextProcessing owns this presentation; original native/history strings and identity/link payloads remain unchanged. Localized native templates and recorded directions determine labels, never body substring guesses.

WhisperWorkspace owns the open/minimized checkpoint for each workspace. Startup shows the remembered shell before applying collapse geometry and leaves the active native editor and conversation acknowledgement alone. Explicit Close records a closed window. A temporary hide of an open shell retains its checkpoint so a notification can show it in the same state when incoming visibility or keep-open is enabled. The shared tray still supports notifications above a closed workspace and acknowledges the sender when clicked.

Use `/sunder practice` and choose Whispers for a short, repeatable two-person exchange with quiet intervals, a background toaster, collapse and detachment. Use the labeled practice reply field for local drafts. The separate five-minute Whispers stress test remains in Samples & testing.
