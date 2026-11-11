local Core, Constants = unpack(select(2, ...))

-- One config provider per feature. New features add a module and register here;
-- the standalone tree and optional Ellesmere pages share the resulting schema.
Core.features = {}

function Core:RegisterFeature(id, feature)
  assert(type(id) == "string" and id:match("^[a-z][a-zA-Z0-9_]*$"), "Invalid feature id")
  assert(not self.features[id], "Feature already registered: "..id)
  assert(type(feature.buildOptions) == "function", "Feature needs buildOptions")
  self.features[id] = feature
end

function Core:BuildOptions()
  local config = self:GetModule("Config")
  local args = {
    home = {
      name = "Home", type = "group", order = 0,
      args = {
        intro = {name = "Sunder", type = "header", order = 1},
        emblem = {type="description",name="",order=0,image="Interface\\AddOns\\Sunder\\Media\\Brand\\SunderSettings",imageWidth=96,imageHeight=96},
        welcome = {type = "description", order = 2, fontSize = "medium",
          name = "Chat brings together chat windows, Whispers and their shared appearance. Item Protection keeps your selected bag items locked. Choose a section below to get started."},
        minimap = {name = "Show minimap button", type = "toggle", order = 5,
          get = function () return not Core.db.global.minimap.hide end,
          set = function (_, value) Core:GetModule("Minimap"):SetHidden(not value) end},
        theme = {type = "description", order = 6, name = function ()
          local eui = Core:GetModule("Ellesmere")
          if eui.optionsRegistered then return "EllesmereUI detected: settings use its native interface and fonts. Standalone settings remain available in WoW Options." end
          return "Standalone interface active. EllesmereUI is optional; its styling is used automatically when available."
        end},
        commands = {type = "description", order = 7,
          name = "/sunder: open settings\n/sunder appearance: shared chat appearance\n/sunder chat: chat settings\n/sunder whispers: conversations & notifications\n/sunder items: bag item protection\n/sunder lock: toggle move/resize mode\n/sunder minimap: show/hide the minimap button"},
      },
    },
    profile = config.Pages.profile(),
    about = {
      name = "About", type = "group", order = 100,
      args = {
        title = {type = "header", name = "Sunder "..Core.Version, order = 1},
        credits = {type = "description", order = 2,
          name = "Chat foundation: Glassy 1.9.7 by Solessfir, based on Glass by Mitchel Cabuloy (mixxorz). Emote art and adapted features by Nelson Abrantes. Original license and bundled-library notices are included.\n\nCustom functionality: unified window locking, dragging and resizing; individual editors; modular configuration; minimap launcher.\n\nThis is an independent fork. EllesmereUI is an optional integration."},
        changes = {type = "execute", name = "What's new", order = 3,
          func = function () Core:Dispatch(Constants.ACTIONS.OpenNews()) end},
      },
    },
  }
  args.profile.name, args.profile.order = "Sunder profiles", 90
  for id, feature in pairs(self.features) do
    assert(not args[id], "Reserved feature id: "..id)
    local group = feature.buildOptions()
    group.name, group.order = feature.name, feature.order or 50
    group.childGroups = "tab"
    -- Keep inherited chat compatibility guidance alongside its controls.
    local help = group.args.about
    if id == "chat" and help and help.type == "group" then
      help.name, help.order = "Help & compatibility", 80
      group.args.help = help
    end
    -- Profiles and addon credits belong to the platform, not the Chat feature.
    group.args.profile, group.args.about = nil, nil
    args[id] = group
    local featureId = id
    args.home.args["feature_"..id] = {
      name = feature.name.." settings", type = "execute", order = 3 + (feature.order or 50) / 100,
      func = function () config:OpenSettings(featureId) end,
    }
  end
  if self.BuildAppearanceOptions and args.chat and args.whispers then
    args.appearance = self:BuildAppearanceOptions(args.chat, args.whispers)
    args.home.args.feature_appearance = {type = "execute", name = "Chat appearance", order = 3.01,
      func = function () config:OpenSettings("appearance") end}
  end
  self.globalLayoutOptions = {type = "group", name = "Window layout", inline = true, order = 0,
    args = {unlock = {type = "toggle", name = "Unlock windows to move / resize", width = "full", order = 1,
      disabled = function()return not not Core.sunderEllesmereEditing end,
      desc = "Applies to main chat, undocked chats and all Whispers groups. Turn off when finished.",
      get = function () return not not Core.sunderMoverUnlocked end,
      set = function (_, value)
        Core:Dispatch(value and Constants.ACTIONS.UnlockMover() or Constants.ACTIONS.LockMover())
        Core.Libs.AceConfigRegistry:NotifyChange("Sunder")
      end}}}
  local function addControls(group)
    local children = {}
    for _, option in pairs(group.args or {}) do
      if option.type == "group" and not option.inline then children[#children + 1] = option end
    end
    group.args.globalLayout = self.globalLayoutOptions
    for _, child in ipairs(children) do addControls(child) end
  end
  -- Layout belongs to chat and conversations, never unrelated features or platform pages.
  if args.chat then addControls(args.chat) end
  if args.whispers then addControls(args.whispers) end
  if args.appearance then addControls(args.appearance) end
  if args.chat and args.whispers then
    local windows, whispers, appearance = args.chat, args.whispers, args.appearance
    windows.name, windows.order = "Chat windows", 2
    whispers.name, whispers.order = "Whispers", 3
    if appearance then appearance.order = 4 end
    local overview = {type = "group", name = "Overview", order = 1, args = {
      intro = {type = "description", order = 1, name = "Chat windows: tabs, editors, scrolling and timestamps.\nWhispers: conversations, notifications and window behavior.\nAppearance: fonts, headers, backgrounds and spacing shared across both."},
      globalLayout = self.globalLayoutOptions,
      ellesmereEdit = {type="execute",name="Open Ellesmere Edit UI",order=2,
        hidden=function()return not (_G.EllesmereUI and _G.EllesmereUI.OpenUnlockMode and _G.EllesmereUI.RegisterUnlockElements and _G.EllesmereUI.RegisterUnlockModeListener)end,
        func=function()local api=_G.EllesmereUI;if api and api.OpenUnlockMode then api:OpenUnlockMode()end end},
    }}
    args.chat = {type = "group", name = "Sunder Chat", order = 10, childGroups = "tree",
      args = {overview = overview, windows = windows, whispers = whispers, appearance = appearance}}
    args.whispers, args.appearance = nil, nil
    args.home.args.feature_whispers, args.home.args.feature_appearance = nil, nil
  end
  local function fitStandalone(group)
    for _, option in pairs(group.args or {}) do
      if option.type == "execute" then option.width = "full"
      elseif option.type == "group" then fitStandalone(option) end
    end
  end
  for _, group in pairs(args) do fitStandalone(group) end
  return {name = self.DisplayName, handler = config, type = "group", childGroups = "tree", args = args}
end

-- Stable entry points for slash commands, launcher buttons and older integrations.
function Core:GetSettingsPath(section)
  if section == "whispers" or section == "appearance" then return {"chat", section} end
  return {section or "home"}
end
