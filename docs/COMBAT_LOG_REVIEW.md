# Combat Log ownership review — 2026-11-17

Status: research followed by an authorized native content adapter implementation and pointer-ownership correction. User confirmed the resize repair worked in game on 2026-11-18. Validation/deployment results are tracked in CONTEXT.md. No assistant game interaction was performed; this confirmation does not certify every protected-client behavior.

## References checked

Installed Wow.exe file version: **1.60.1.70959**, read from file metadata. The [Forever client-source export](https://github.com/reckhou/WoWBlzCode) identifies the same build. This is a mirror of Blizzard-generated documentation and UI source, not an addon API invented by the mirror author.

- [CombatLog generated API documentation](https://github.com/reckhou/WoWBlzCode/blob/main/Forever/BlizzardInterfaceCode/Interface/AddOns/Blizzard_APIDocumentationGenerated/CombatLogDocumentation.lua): filtering restrictions, refiltering, event enablement and retention.
- [Combat Log implementation](https://github.com/reckhou/WoWBlzCode/blob/main/Forever/BlizzardInterfaceCode/Interface/AddOns/Blizzard_CombatLog/Mainline/Blizzard_CombatLog.lua): OnShow/OnHide, quick filters, dock geometry and driver refills.
- [ScrollingMessageFrame implementation](https://github.com/reckhou/WoWBlzCode/blob/main/Forever/BlizzardInterfaceCode/Interface/AddOns/Blizzard_SharedXML/ScrollingMessageFrame.lua): native offsets/ranges, PageUp/PageDown, fading and scroll notifications.
- [ChatFrameUtil](https://github.com/reckhou/WoWBlzCode/blob/main/Forever/BlizzardInterfaceCode/Interface/AddOns/Blizzard_ChatFrameBase/Shared/ChatFrameUtil.lua): ChatPageUp/ChatPageDown dispatch to SELECTED_CHAT_FRAME.
- [Slider generated API documentation](https://github.com/reckhou/WoWBlzCode/blob/main/Forever/BlizzardInterfaceCode/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleSliderAPIDocumentation.lua): native control methods exist; that alone does not establish integration correctness.

Read installed reference source without enabling any addon:

| Implementation | Combat content owner | Scrolling implication |
| --- | --- | --- |
| Sunder | Native ChatFrame2/filter machinery stays alive, while Sunder displays pooled MessageLine rows and maintains scrollIndex/messageOffset. | Wheel/rail use Sunder state; native APIs own a different offset. Native page post-hooks were recently added, but there is no general bidirectional native-offset synchronization. |
| EllesmereUIChat | EngineUpdateCombatLogHost restores Blizzard's FontStringContainer and scrollbar while Combat Log is selected, hiding its replacement renderer. | Combat Log is deliberately native-hosted. Its ordinary chat replacement also explicitly synchronizes native and replacement offsets. |
| Chattynator | API/CustomTab.lua reparents and anchors ChatFrame2 into a custom tab. | It retains the native Combat Log content engine; this is not the same approach as replacing its rows. |
| Installed Glassy | Custom SlidingMessageFrame adapter with a similar Combat Log special case. | Related implementation lineage, not independent proof that Sunder's current input architecture works. |

## Verified differences

Combat Log show/hide toggles filtered-event delivery; showing applies the current quick filter. Refiltering clears/refills ChatFrame2, and docking updates its top anchor for the quick-button bar. ApplyFilterSettings is marked restricted in the generated API documentation. Preserving these behaviors requires a deliberate native adapter.

Native scrolling uses offset zero at newest, a history-derived maximum and a page amount based on visible lines. Sunder's rail uses top-origin pixel distances derived from its own rows. These are different units and ownership models. Copying a widget or hook without an explicit mapping does not unify them.

Blizzard's ChatPageUp/ChatPageDown call the selected native frame's PageUp/PageDown. Those methods do not automatically move Sunder's independent row pool. A generic keyboard receiver and a native-method bridge are separate integration paths, not evidence that physical key dispatch works in-game.

## Recommended boundary and implementation

Keep WindowManager responsible for shell geometry, header actions, lock/resize, surfaces and scrollbar styling. Host Blizzard's native Combat Log content/filter engine inside that shell. Keep one scroll authority for that content; style or adapt its native scrollbar/range rather than maintaining an independent Combat Log row pool and offset. Preserve native links, refiltering, selected frame, docking and combat restrictions. Ordinary conversation rendering remains unchanged.

A shared scroll interface should expose owner-provided range, offset, page, set-offset and change notification operations. Each adapter explicitly translates units; do not feed native message offsets into pixel-based transcript calculations. Shared appearance does not require identical content engines.

Implemented in NativeCombatLog.lua: preserve ChatFrame2 as docking/geometry owner, host its native FontStringContainer in the shared clipped viewport, and adapt native layout width/visible-line capacity. A shared WindowManager rail writes native offsets; native paging and display notifications keep it synchronized. This deliberately differs from Chattynator's full-frame reparenting because Sunder's detached shell is already anchored to ChatFrame2. The original native hyperlink receiver is retained through forwarding: the [native XML](https://github.com/reckhou/WoWBlzCode/blob/main/Forever/BlizzardInterfaceCode/Interface/AddOns/Blizzard_SharedXML/ScrollingMessageFrame.xml) specifies parent propagation on FontStringContainer. There is no replacement Combat Log message pool or duplicate scroll state.

Validate a narrowly scoped native-host adapter before any cross-window control replacement: docked/detached, filter changes/refill, mouse wheel/track/thumb, keyboard selection and focused editor, resizing with filters above/below, visibility and combat transitions. Existing fixtures should be extended to model native state changes and refresh ordering. Their direct callback calls do not establish real mouse targeting or protected-client behavior.

## Limits

### 2026-11-18 installed Glassy resize/input comparison

Read installed Glassy 1.9.11, still disabled: `SlidingMessageFrameNative:ConfigureNativeLayout` clears native clamp insets, `HookNativeMessages` disables native mouse/wheel input, and `KeepDetachedNativeLayout` leaves undocked geometry alone. Its detached shell follows ChatFrame2's geometry but has no custom detached resize driver; it leaves the stock resize button intact. The [matching native template](https://github.com/reckhou/WoWBlzCode/blob/main/Forever/BlizzardInterfaceCode/Interface/AddOns/Blizzard_ChatFrameBase/Mainline/FloatingChatFrame.xml) uses StartSizing/StopMovingOrSizing and saves position on release.

Sunder's native content adapter instead enabled mouse/wheel on ChatFrame2 while also owning a clipped viewport, shared rail and grip. User confirmed the grip does not brighten, narrowing the current symptom to input targeting rather than evidence of a failing drag calculation. RetireNativeChrome now disables the native geometry owner's click/motion/wheel input on initialization and layout refresh. Only the clipped viewport receives body clicks/wheel/links; the shared grip keeps the existing resize driver. Native clamp insets are zeroed without removing Sunder's intentional screen clamping. This removes a concrete input-ownership divergence; physical hover/drag still requires in-game confirmation.

This review identifies architectural differences and documented contracts. It does not establish the exact cause of the dead thumb or the withdrawn revision's widespread breakage. No displayed Lua error or native input trace was supplied, and no in-game diagnostic was run. A native Slider's existence is not evidence that it caused or would fix either failure.
