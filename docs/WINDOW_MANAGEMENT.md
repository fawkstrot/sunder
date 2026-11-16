# Shared window management

WindowManager owns surfaces, action feedback, semantic window commands, room action placement, movement drivers, normal resize affordances, collapse/restore and room maximize/restore. Adapters retain native chat frames, editor ownership and persistence hooks.

| Capability | Main native chat | Detached native chat | Whispers/groups | Guild / Party room |
| --- | --- | --- | --- | --- |
| Title/grip drag and position lock | Yes | Yes | Yes | Yes |
| Normal corner resize | Yes | Yes | Yes | Yes |
| Shared backing, fade and outline | Yes | Yes | Yes | Yes |
| Settings | Chat windows | Only when mapped | Whispers | Matching room settings |
| Return to main | Already docked | Yes | Conversation destination menu | Own room |
| Collapse up/down | Omitted intentionally | Omitted | Yes | Yes |
| Maximize/restore size | Native size controls | Native size controls | Yes | Yes |
| Window menu | Native tabs | Native tabs | Yes | Yes |

## Commands and visual meanings

Semantic IDs choose a stable icon and default tooltip through `windowActions` and `CreateWindowAction`. Callbacks supply behavior. `LayoutRoomActions` places supported controls in the same order from the right: close, settings, maximize, collapse up, collapse down, lock, menu, then type-specific controls. Guild and Party add roster; Party also provides Previous groups; Whispers people-list conversation actions stay in person menus rather than a redundant header toolbar.

- Square: maximize; overlapping squares: restore size.
- Three lines: window/conversation menu.
- Member/list symbol: roster visibility, with selected plate and state-specific tooltip.
- Arrow into tabbed frame: return native chat to General/main.
- Chevron up/down: collapse toward that edge; while collapsed, both restore in the actual opening direction.
- Filled padlock: position locked; outline open padlock: movable.
- Chat bubble/count: unread messages. Zero is neutral blue-gray; unread uses the shared accent.

The legacy `minimizeButton` field aliases the upward capability; no extra hidden button is created. Main native chat intentionally omits collapse. Font/appearance overrides remain adapter inputs.

## Interaction and work bounds

Actions retain selected feedback across hover/style refresh, stay dim when disabled, and clear hover/pressed offsets when hidden. Resize grips use a 24 px hit area with 16 px artwork. Resize geometry updates immediately; history/text reflow is coalesced. Movement and transition drivers stop on completion/hide and do no idle per-frame work. Room maximize preserves original geometry; manual resize exits maximized state. Title double-click maximizes/restores, while Rename is a menu action.

Shared tests cover both room hosts, original dimensions after maximize, both collapse directions and interruptions, initial body continuity, disabled/recycled control feedback, native capabilities, resize geometry, surfaces, input ownership and persistence. Live observations and limitations are recorded by task in CONTEXT.md; mocked checks are not visual or protected-client verification.


## Surface/counter ownership correction - 2026-11-12

PresentRoomSurface and UpdateRoomSurfaceGeometry own background height/visibility/opacity during every room transition. PresentWindowBody delegates there even for adapters without people lists; per-list code only handles list content. Toggle actions refresh their selected state and tooltip after invocation. LayoutUnreadIndicator fixes icon/label anchors (4 px icon inset, label at 22 px, right inset 4 px, centered count) for both header types. StyleTitleIcon supplies neutral idle tint/opacity for native tabs and room marks; selection remains indicated by text/underline, with hover emphasis on native tabs. Auto ordinary/Guild chat title glyph is the common chat bubble; explicit tab overrides and native conversation identity are preserved.

Collapse presentation is geometric, with alpha fixed at 1 until completion. WindowManager clips native content and preview bodies only during transitions; the active people ScrollFrame retains its changing viewport (including filter-row inset), and preview parents remain shown. Completion hides collapsed bodies, removes temporary clipping and stops OnUpdate. Do not fade backing out ahead of the moving border.

Shared ownership update (2026-11-13): PresentRoomBody owns backing and active body visibility/alpha; Whispers delegates and Guild inherits the same delegate. SidebarWidth bounds desired widths against transcript reserve for both people lists. Guild supplies cached name measurements, with its saved roster width acting as a maximum. Feature-specific rendering and roster scans remain adapters; main chat intentionally has no collapse capability.

List scroll feedback: WindowManager:UpdateListScrollIndicator owns passive track/thumb geometry used by Whispers and Guild. Guild uses its draggable rail when overflowing, above the roster row layer; fitting lists retain the passive track without a false thumb. Compacted lists hide both treatments.

List-rail geometry correction (2026-11-13): LayoutListScrollRail supplies the same 10 px hit width, right-edge inset, vertical insets and raised layer to Whispers and Guild. Guild viewport reaches its sidebar boundary; row content reserves rail clearance internally. Passive indicators now share the same viewport boundary instead of inheriting an extra padded gutter.

Header count capability (2026-11-13): windowCount supplies optional inline metadata beside an action icon. LayoutRoomActions reserves measured label width; icon press/release/hide retains its offset. Guild roster supplies online/total. Shared MessageLine uses slider owner GetLayoutWidth for row/background width and measures wrapped text within body insets and a minimum 6 px room-scrollbar clearance.

Person detail component (2026-11-13): PersonDetailSize, ApplyPersonDetailFont and StylePersonDetail supply compact level/class formatting, inherited font face with explicitly smaller size, muted class tint and offline dimming. Whispers aligns detail width to the name label; Guild exposes rank/public notes in its member card and tooltip. Metadata clears on recycled rows and never pushes into action or scrollbar space.

Geometry lock update (2026-11-13): resize options supply their owning settings to the shared driver, which checks movementLocked at start and each resize tick; room lock clicks finish active drivers. Main/detached/room normal and edit handles share this gate. Ellesmere user size/position callbacks honor locks; restore/discard application remains available. Locked room maximize is disabled/guarded. Person name text now has explicit height and a top anchor above its detail line, avoiding inherited Button FontString bottom alignment.

Guild Info adds an Info semantic capability with dedicated deterministic circle-info artwork. WindowManager now owns shared StyleFilterButton, StyleInsetPanel and CreateTextAction primitives; Whispers and Guild filter tint/selection follow the same helper. Internal drawers inherit body color/opacity without duplicating full window chrome. Guild supplies drawer data and responsive geometry only.

## Shared person rows — 2026-11-13

LayoutPersonRow owns both lists: typography-derived two-line height, balanced 2 px outer text padding, subtle separators, selection/unread accents and right-aligned favorite/pin actions. Unknown metadata centers the name. Unread badges reserve their measured width before the actions. State refresh cannot change the label geometry. Real tab presentation remains separate and clears person-only decorations. Pointer identity is captured on press and checked on click to reject recycled-row actions. PersonPriority orders pinned favorites, favorites, pinned, ordinary people; normal order is stable within each tier. Guild supplies scoped persistent preferences; Whispers supplies active, sample and saved-contact adapters. No extra idle update driver.

The roster header action remains enabled while minimized: it restores through the common collapse transition, ensures sufficient room height, reveals members and dismisses an overlapping information drawer. Selected feedback still reflects actual roster visibility.

2026-11-13 separator spacing correction: user reported the visible text was closer to the separator above the next row. Previous read-only review did not catch this optical imbalance. Shared person rows now raise the name/detail block by 2 px to compensate native line-box leading and give the lower text more clearance. Unknown single-line names receive the same optical offset. Whispers no longer adds an extra 1 px between rows; both lists use the shared height as their stride. Row height, text size and action geometry remain compact. Regression assertions cover the shared stride, optical offset, lower clearance and selection-cycle stability. Visual balance requires safe reload confirmation. Whispers background-color request was truncated; clarification is pending and no color change is inferred.

User clarified the Whispers idle background is the desired reference for Guild. Both already had identical sidebar tint, but a full-window gradient underneath varied the apparent list color with window/sidebar width. Shared surfaces now keep the fade in the transcript and compose a uniform dark sidebar backing at the existing full-strength fade opacity. Both lists inherit it, with zero-opacity appearance preserved and selected/unread accents unchanged. Regression covers identical sidebar alpha across resize, fade boundary and transparent setting. This replaces the pending background clarification above.

2026-11-14 inactive person actions: shared row favorite/pin icons now use 35% idle opacity (previously 70%) in Guild and Whispers. Hover and filled active states retain full emphasis; hit areas and behavior unchanged. Standard validation/deployment follows; this opacity revision has not been observed live.

## Filter-tab display correction and experimental-controls removal — 2026-11-14

User screenshots showed differing filter selection/background presentation. Found 26 px filter buttons in a 32 px row (active underline 6 px above baseline), plus the transcript gradient starting beside the sidebar and painting only part of the full-width filter row. Buttons now fill the row, use pixel-aligned thirds and explicit centered label heights; transcript fade starts below the row. Hidden/left/released tabs clear pressed/hover state and restyle through one path. Added geometry/selection/hide-cycle and surface-boundary regressions.

User explicitly requested removing testing features while retaining item locks. Removed ItemProtectionDisposal.lua/TOC entry, its mode handling and settings, and user-facing pickup-test controls. Existing strict per-copy locking, saved intent, quick lock controls and identity/history improvements remain. Retired preview-specific tests with the retired feature; added checks that standard settings remain, developer controls are absent and legacy preview mode markers cannot weaken native locks. Historical research is retained only in documentation. Final standard validation/deployment follows; screenshots supplied by user are pre-fix evidence, not live confirmation of this build.

2026-11-14 favorite action ownership: row/card stars in Guild and Whispers delegate to the shared per-character person favorite mutation in WhisperWorkspace. Features supply identity, not separate favorite databases. One mutation refreshes visible real views and archive/checkpoint state; pin scope remains unchanged. Legacy Guild favorites migrate once through the shared owner before any guild-state reset.

## Roster-room controller extraction — 2026-11-14

Guild and Party use InstallRosterRoom descriptors instead of parallel shell implementations. The shared controller owns EnsureRoom, chrome/header counter layout, member viewport/rows, body/input geometry, roster show/restore, state save/restore, dedicated native slot recovery and recent history. Room roots start hidden, so reading settings cannot open a manual room. Optional Info commands are descriptor capabilities; Party has no nonfunctional Guild Info control. Room descriptors carry stable edit keys/settings labels independent of dynamic Party/Raid titles.

WindowManager's room registry routes native layout, message persistence, close handling, cross-view favorites and actual-root edit registration. The existing movement/resize/collapse/surface methods remain the single implementation. CreateEmptyConversation now supplies both Whispers and Party empty-state artwork/copy layout. Guild's existing geometry and recovery regressions remain intact after extraction.

## Renderer ownership correction — 2026-11-14

The renderer was shared, but MessageLine incorrectly assumed row -> slider -> renderer. Actual native construction inserts a viewport: row -> slider -> viewport -> renderer. The lookup reached the viewport, found no layout method and silently borrowed General's width. The earlier regression mirrored the wrong simplified hierarchy, so it missed clipping despite apparently correct isolated widths. This affected every narrow owner using that shared code; component reuse alone could not enforce a broken ownership contract.

CreateMessageLinePool and CreateMessageLine now require the renderer explicitly, bound as sunderRenderer before row initialization. Ownerless creation asserts; row initialization, background, text width and scrollbar clearance all use the bound owner. Measurement and visible text enable word/non-space wrapping and unlimited lines. The regression calls actual native InitializeScrollFrame and actual pool construction/acquire/release through the viewport, rather than hand-wiring a two-level parent mock. It checks narrow/recycled rows, measured multi-line growth and ownerless rejection. Native glyph/link wrapping still requires a post-reload observation.

Roster search is a shared showSearch descriptor capability. Guild retains search; Party supplies raid state, hiding and reclaiming the field's height in parties and clearing any stale raid query.


WindowManager owns shared Inspect actions: resolve existing units, check eligibility/range/combat, recheck identity on click. Never target players or send background inspections. UIManager.ReleaseMessageInput retires closed/read-only selected rooms without moving or clearing drafts.


Expanded people lists use WindowManager.PeopleSidebarWidth: one PEOPLE_SIDEBAR_WIDTH=150 px value and 220 px conversation reserve. Only narrow windows shrink below this width; hidden/compact roster modes remain explicit. Features do not supply competing width policies. Rows/actions/scroll indicators remain shared.


Current people width: WindowManager.PEOPLE_SIDEBAR_WIDTH=150 is the one source of truth for all expanded lists. PeopleSidebarWidth applies it with narrow-window fallback. This replaces the older 190 px minimum and feature-specific preferred/max/percentage rules; removed width controls cannot override it.


Selected person star/pin actions use filled accent artwork alone, without a selected plate or native hover background. WindowManager.RefreshAction owns this policy across all adapters; other action types retain their own feedback. Toaster favorite badges use the filled star and include favorite state in their bounded visible-row cache.


Transcript-label regressions must include decorated/flattened native channel headers, not just plain CHAT_*_GET strings. Compact labels may edit only the structured pre-sender header in the registered room; body/link payloads and General context stay intact.


When a renderer binds to a registered room after native history has already rendered, RosterRoom invalidates transcript presentation once via roomLabelOwner/RefreshLayout(true), preserving readback. Geometry-only layout is insufficient for ownership-dependent formatting. Never repeat whole-history formatting on ordinary resize; clear the marker on release.


Forever native retained lines can have no structured player link. Compact-prefix tests include colored/plain headers in addition to hyperlink forms. Native PushBack/backfill forwards type/access/line metadata from GetMessageInfo; direction styling depends on it. An actual adapter regression prevents RGB-only replay from silently dropping semantic metadata.
