# Extending Sunder

The addon folder/registration identifier is `Sunder`; the display name is
`Sunder`. The entry manifest is `Sunder.toc`.

## Feature registration

`Sunder/Features.lua` owns the feature registry and root configuration.
The chat configuration currently registers the `chat` feature during Config's
OnEnable, before building the shared schema.

Whispers registers at file load after Features.lua. Whispers.lua owns routing,
notifications, unread state and visibility policy; WhisperHub.lua owns the grouped
window; WhispersOptions.lua supplies four shared configuration pages. It reuses
native temporary chat windows and the existing renderer/editor. UIManager delegates
grouped layout to the feature while all other chat windows retain their normal path.
Optional `resetOptions` on a feature controls its Ellesmere reset action; use it for
nested settings instead of relying on the chat settings-key collector.

For a future feature, add its Lua file after Features.lua in the manifest and
register an options provider at file load:

```lua
local Core = unpack(select(2, ...))
Core:RegisterFeature("example", {
  name = "Example", order = 20,
  buildOptions = function ()
    return {
      type = "group",
      args = {
        display = {
          name = "Display", type = "group", order = 1,
          args = {
            enabled = {
              name = "Enabled", type = "toggle",
              get = function () return Core.db.profile.exampleEnabled end,
              set = function (_, value) Core.db.profile.exampleEnabled = value end,
            },
          },
        },
      },
    }
  end,
})
```

Define defaults in Core.defaults before AceDB initializes. Register a lifecycle
module with `Core:NewModule` before calling `Core:GetModule` for it. Feature ids
must be unique; home, profile, and about are reserved. Direct child option groups
become tabs in AceConfig and separate pages in the optional Ellesmere integration.
Addon-wide profiles and credits stay outside the Chat feature.

## Optional interfaces

Use `Core:GetModule("Config"):OpenSettings(featureId)` for navigation.
It tries the supported Ellesmere OpenPlugin API, then falls back to AceConfig.
Never require EllesmereUI or copy its private objects/assets.

Use the Ellesmere module's SkinWindow for retained utility windows. Do not skin
widgets returned to AceGUI's shared pool; a permanent skin would affect another
addon's controls when reused. Native EUI feature pages already use themed widgets.

The minimap launcher is native and self-contained. Its visibility and angle are
stored in Core.db.global.minimap, independent of chat profiles.

## Saved settings and event ownership

The one-time Glassy import deep-copies the old database only when no Sunder database
exists. Never write settings back to GlassyDB. Old GLASSY1 profile-export strings
remain compatible with the inherited chat profile serializer.

Core:Dispatch forwards every payload argument. Input visibility events include
the originating editor so typing and fading remain scoped to the correct window.

## Validation

This fork was checked with Lua 5.1 parsing and simulated tests for chat dragging,
locking, resize limits and scale, input routing, overlay extents, settings migration,
configuration navigation, feature registration, optional integration and minimap
controls. WoW's secure UI behavior still needs in-game checking after a restart.
