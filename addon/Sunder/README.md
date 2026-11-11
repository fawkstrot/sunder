# Sunder 0.9.11

Sunder is a modular messaging and quality-of-life addon. Open `/sunder` for settings; `/sun` is available if unused. The minimap emblem opens settings, Shift-click opens Whispers, and right-click toggles standalone layout editing. EllesmereUI is optional, including its native Edit UI integration.

Sunder Chat, Whispers and shared Appearance settings are grouped under Sunder Chat. Item Protection has its own section. Favorites live within Whispers; custom groups and detached conversations remain optional.

Existing ROTBOT Forever users: install the upgrade bundle once, which replaces the old executable addon with a data-only loader. Keep that loader enabled for the first Sunder login and successful logout/reload. Settings and history are copied once into SunderDB. Afterward, normal updates need only the Sunder folder. Do not run two real chat replacements together.

Restart the game after adding the new addon folder. Later Lua-only updates can use `/reload`. Primary development/testing targets WoW Forever; other clients need validation. Native item locks currently require unprotecting before moving or using a copy; full sale/trade/destruction coverage is still under validation.

MIT. Original Glassy/Glass contributor and bundled-library notices are retained. See LICENSE and UPSTREAM_README.md.
