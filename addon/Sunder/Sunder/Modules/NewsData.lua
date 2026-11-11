local Core = unpack(select(2, ...))
Core.NewsEntries = {{name = "0.2.1 (2026-11-09)", items = {[[
+- Messages now stays open by default, including when empty. The new keep-open setting is under Window & visibility.
+- With keep-open disabled, manually opening Messages starts a fresh inactivity timer.
+- New Preview & testing page: seeded dummy conversations, unread badges and test notifications.
+- Samples stay local, are never saved as real history, and cannot be replied to or detached.
+- Real conversation activity ends preview automatically; test sounds do not delay real notification sounds.
+]]}},{name = "0.2.0 (2026-11-09)", items = {[[
+- New Whispers settings: main-dock conversation tabs or a separate Messages window.
+- Unified movers/resizing, unread badges, pins, reply/detach/search/copy actions.
+- Custom chimes, SharedMedia sounds, preview, throttling and DND/combat muting.
+- Inactivity fading, typing/unread protection and independent timestamps.
+- Bounded character history with original timestamps; Battle.net history is never saved.
+- /sunder whispers opens settings; /sunder messages or Shift-clicking the minimap emblem opens Messages.
+]]}},{name = "0.1.1 (2026-11-09)", items = {[[
- Editors appear only while typing and fade away when finished.
- Chat smoothly reclaims the editor space while retaining per-window input routing.
]]}},{name = "0.1.0 (2026-11-09)", items = {[[
Sunder: first release

- Chat foundation based on Glassy 1.9.7.
- Unified lock, move and resize controls for main and detached windows.
- Per-window chat editors and corrected edit-mode outlines.
- Minimap launcher and modular Home / Chat configuration.
- Optional native EllesmereUI settings, window skins and fonts.
- Independent saved settings, copied once from Glassy when available.
]]}}}

table.insert(Core.NewsEntries,1,{name="Sunder 0.9.11 (2026-11-11)",items={[[
- Introducing Sunder: modular messaging and quality-of-life tools.
- New fractured-stone emblem for the minimap, addon list and settings.
- /sunder opens settings; previous commands and existing item-lock bindings remain compatible.
- Existing profiles, messages, favorites, item protection and window layouts migrate once through the data-only legacy loader.
- Development now lives in its own Git repository with checked deployment and release packaging.
]]}})
