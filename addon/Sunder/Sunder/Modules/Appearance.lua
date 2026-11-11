local Core, Constants = unpack(select(2, ...))
Core.AppearanceWhisperKeys = {"headerFont", "headerFontFlags", "headerFontSize", "tabFontSize", "toolbarIconSize",
  "headerPadding", "toolbarSpacing", "conversationTabWidth", "conversationTabHeight", "tabPadding",
  "hubBackgroundColor", "hubBackgroundOpacity", "hubHeaderOpacity", "hubBorderOpacity", "hubUseChatFade", "hubMatchChat", "singleRowHeader", "conversationLayout", "conversationListRatio"}
local function group(name, order, args)
  return {type = "group", name = name, order = order, args = args or {}}
end
local function take(source, keys)
  local result = {}
  for _, key in ipairs(keys) do result[key], source[key] = source[key], nil end
  return result
end
local function explain(text, order) return {type = "description", name = text, order = order or 0} end
local function refresh()
  Core:Dispatch(Constants.ACTIONS.UpdateConfig("font"))
  Core:Dispatch(Constants.ACTIONS.UpdateConfig("chatHeaderStyle"))
  Core:Dispatch(Constants.ACTIONS.UpdateConfig("tabHighlightTextColor"))
  Core:GetModule("Whispers"):RefreshHubStyle()
end
local function field(key, kind, name, order, extra)
  local option = {type = kind, name = name, order = order,
    get = function () return Core.db.profile[key] end,
    set = function (_, value) Core.db.profile[key] = value; refresh() end}
  for k, v in pairs(extra or {}) do option[k] = v end
  return option
end

-- Move the existing controls, preserving saved values and setter behavior.
-- Each setting has one owner, so a shared text change is never presented as whisper-only.
function Core:BuildAppearanceOptions(chat, whispers)
  local message = chat.args.messages.args.section1.args
  local tabs = chat.args.tabs.args.appearance.args
  local general = chat.args.general.args.section2.args
  local editor = chat.args.editBox.args.section1.args
  local windows = whispers.args.appearance
  windows.name, windows.order = "Whisper windows", 4
  windows.args.shared = nil
  windows.args.intro.name = "Whispers and custom groups follow chat by default: compact labels and icons, shared fading surfaces, a subtle header/body gap and no outer border. Unlink below to use separate window typography and surfaces. The default people list uses a 30 / 70 split below the title. Choose tabs below to restore the previous layout. Your previous custom values are retained."
  windows.args.follow = {type = "toggle", name = "Match chat styling (default)", order = 0.1, width = "full",
    desc = "Use shared header fonts, icon sizes, colors, background opacity, edge fades and header/body spacing. Keeps groups, favorites, drag, resize and minimize controls.",
    get = function () return Core:GetModule("Whispers"):UsesChatAppearance() end,
    set = function (_, value) Core.db.profile.whispers.hubMatchChat = value; Core:GetModule("Whispers"):ApplySettings(false, "hubMatchChat") end}
  for key, option in pairs(windows.args) do
    if key ~= "follow" and option.type ~= "description" and option.type ~= "header" then
      option.disabled = function () return Core:GetModule("Whispers"):UsesChatAppearance() end
    end
  end
  windows.args.compact = {type = "toggle", name = "Single-row Whispers header", order = 0.2, width = "full",
    desc = "Place the title, conversation tabs and navigation on one compact row. Right-click a tab or the window title for conversation actions. Turn off for a separate tab row.",
    disabled = function () local w = Core:GetModule("Whispers"); return not w:UsesChatAppearance() or w:IsConversationList() end,
    get = function () return Core.db.profile.whispers.singleRowHeader ~= false end,
    set = function (_, value) Core.db.profile.whispers.singleRowHeader = value; Core:GetModule("Whispers"):ApplySettings(false, "singleRowHeader") end}
  windows.args.layout = {type = "select", name = "Conversation layout", order = 0.15, width = "full",
    values = {list = "People list & conversation (default)", tabs = "Conversation tabs"},
    desc = "A left people list and right conversation pane, or the previous horizontal tabs. Selection, pins and order are preserved when switching.",
    get = function () return Core.db.profile.whispers.conversationLayout or "list" end,
    set = function (_, value) Core.db.profile.whispers.conversationLayout = value; Core:GetModule("Whispers"):ApplySettings(false, "conversationLayout") end}
  windows.args.listWidth = {type = "range", name = "People column width", order = 0.16, min = 25, max = 45, step = 1,
    desc = "Percentage of the window for people. Defaults to a 30 / 70 split, with minimum widths to keep names and the conversation readable.",
    disabled = function () return not Core:GetModule("Whispers"):IsConversationList() end,
    get = function () return Core.db.profile.whispers.conversationListRatio or 30 end,
    set = function (_, value) Core.db.profile.whispers.conversationListRatio = value; Core:GetModule("Whispers"):ApplySettings(false, "conversationListRatio") end}
  local text = group("Chat & conversation text", 1, take(message,
    {"messageFont", "messageFontFlags", "messageFontSize", "messageLeading", "messageLinePadding"}))
  text.inline = true
  local label = group("Shared header labels", 2, take(tabs, {"tabFont", "tabFontFlags", "tabFontSize"})); label.inline = true
  local input = group("Typing / editor", 3, take(editor, {"editBoxFont", "editBoxFontFlags", "editBoxFontSize", "editBoxVerticalPadding"})); input.inline = true
  if general.textLeftPadding then general.textLeftPadding.name = "Header text padding" end
  local inset = group("Header alignment", 4, take(general, {"textLeftPadding"})); inset.inline = true
  local typography = group("Typography", 1, {
    intro = explain("Message fonts, sizes and spacing apply to main chat, undocked chats and all conversations. Chat tab labels and editor text have their own controls. Your existing preferences are preserved."),
    text = text, labels = label, editor = input, inset = inset,
  })
  local surfaces = group("Surfaces & colors", 3, {
    intro = explain("Shared backgrounds style chat, Whispers and custom groups together by default. Compact headers, edge fades and borderless surfaces keep everything in the same visual family. Unlink Whispers on the Whisper windows page to use the custom overrides below."),
    labels = group("Labels & selection accent", 1, take(general, {"tabTextColor", "tabHighlightTextColor"})),
    chat = group("Shared message backgrounds", 2, take(message, {"chatBackgroundColor", "unreadMessageBackgroundColor"})),
    header = group("Shared headers", 3, take(tabs, {"headerBackgroundColor", "tabMessageSeparatorColor"})),
    editor = group("Editor surfaces", 4, take(editor, {"editBoxBackgroundColor", "editBoxMessageSeparatorColor"})),
    windows = whispers.args.visibility.args.appearance,
  })
  surfaces.args.viewport=group("Shared content spacing",2.5,{
    intro=explain("One inset for message bodies, Whispers people lists, samples and notification text. Headers and small toolbar controls retain their compact spacing.",0),
    bodyPadding={type="range",name="Content padding",order=1,min=0,max=32,step=1,
      desc="Distance from content edges in pixels. Default: 12 px. Applies across chat and Whispers.",
      get=function()return Core.db.profile.bodyPadding end,
      set=function(_,value)Core.db.profile.bodyPadding=value;Core:Dispatch(Constants.ACTIONS.UpdateConfig("bodyPadding"))end},
  })
  for _, option in pairs(surfaces.args.windows.args) do option.disabled = function () return Core:GetModule("Whispers"):UsesChatAppearance() end end
  surfaces.args.windows.args.scope = explain("Used only when Match chat styling is off on the Whisper windows page. Shared styling keeps your previous custom values available without applying them.", -1)
  surfaces.args.windows.args.blend = {type = "toggle", name = "Use chat edge fades in Whispers", order = 0,
    desc = "Apply the shared left/right fade distances to Whispers and custom-group backgrounds and headers. Text, icons and controls keep their opacity.",
    get = function () return Core:GetModule("Whispers"):UsesChatAppearance() or Core.db.profile.whispers.hubUseChatFade end,
    disabled = function () return Core:GetModule("Whispers"):UsesChatAppearance() end,
    set = function (_, value) Core.db.profile.whispers.hubUseChatFade = value; Core:GetModule("Whispers"):RefreshHubStyle() end}
  surfaces.args.windows.name, surfaces.args.windows.order = "Custom Whispers surfaces (optional)", 5
  whispers.args.visibility.args.appearance = nil
  local fading = take(general, {"backgroundFadeLeftPercent", "backgroundFadeRightPercent"})
  for key, option in pairs(fading) do surfaces.args.chat.args[key] = option end
  chat.args.general.args.section2.name = "Visibility"
  for _, section in pairs(surfaces.args) do if section.type == "group" then section.inline = true end end
  if surfaces.args.labels.args.tabHighlightTextColor then surfaces.args.labels.args.tabHighlightTextColor.name = "Selection & hover accent" end
  local headers = group("Headers & icons", 2, {
    intro = explain("Header labels, small monochrome icons and fine selection accents style chat and matching Whispers windows together. Existing chat fades and smooth scrolling remain intact. Individual chat icon choices apply only to chat tabs."),
    icons = field("chatTitleIcons", "toggle", "Header title icons", 1),
    size = field("chatTitleIconSize", "range", "Title icon size", 2, {min = 10, max = 18, step = 1}),
    opacity = field("chatTitleIconOpacity", "range", "Idle icon opacity", 3, {min = 0.15, max = 1, step = 0.05, isPercent = true}),
    gap = field("chatTitleIconGap", "range", "Icon / label spacing", 4, {min = 2, max = 12, step = 1}),
    indicator = field("chatSelectionIndicator", "toggle", "Thin selected-tab accent", 5),
    wash = field("chatHoverWash", "toggle", "Subtle hover background", 6),
    spacing = group("Header spacing", 7, take(tabs, {"tabMessageSpacing"})),
    customize = group("Individual chat icons", 8, {
      target = {type = "select", name = "Chat tab", order = 1,
        values = function ()
          local values = {}
          for i = 1, NUM_CHAT_WINDOWS or 10 do
            local frame, tab = _G["ChatFrame"..i], _G["ChatFrame"..i.."Tab"]
            if frame and tab and not frame.isTemporary then values[frame:GetName()] = tab.Text and tab.Text:GetText() or frame:GetName() end
          end
          return values
        end,
        get = function () return Core.appearanceChatTarget or "ChatFrame1" end,
        set = function (_, name) Core.appearanceChatTarget = name end},
      icon = {type = "select", name = "Icon", order = 2,
        values = {auto = "Automatic", none = "None", inbox = "Chat", windows = "Group", read = "Combat / activity", reply = "Conversation", favorite = "Star", pin = "Pin"},
        get = function () return (Core.db.profile.chatTabIconOverrides or {})[Core.appearanceChatTarget or "ChatFrame1"] or "auto" end,
        set = function (_, value)
          Core.db.profile.chatTabIconOverrides = Core.db.profile.chatTabIconOverrides or {}
          Core.db.profile.chatTabIconOverrides[Core.appearanceChatTarget or "ChatFrame1"] = value ~= "auto" and value or nil
          refresh()
        end},
    }),
  })
  headers.args.spacing.inline, headers.args.customize.inline = true, true
  local function shortcut()
    return {type = "execute", name = "Shared appearance", order = 0.1,
      func = function () Core:GetModule("Config"):OpenSettings("appearance") end}
  end
  for _, args in ipairs({message, tabs, general, editor}) do args.appearance = shortcut() end
  chat.args.messages.args.section1.name = "Content & timestamps"
  chat.args.tabs.args.appearance.name = "Tab behavior"
  chat.args.editBox.args.section1.name = "Editor behavior"
  whispers.args.appearance = nil
  whispers.args.visibility.args.appearance = shortcut()
  local design = group("Design & samples", 0, {
    intro = explain("One quiet visual style for chat and conversations: compact headers, borderless backgrounds and shared edge fades. Whispers keeps its groups, favorites and window controls. Appearance is shared by default; custom Whispers styling is optional."),
    scope = explain("Typography: shared message text, chat labels and editors.\nHeaders & icons: shared icon sizing, selection accents and chat icon choices.\nSurfaces & colors: shared message/header backgrounds, opacity and edge fades.\nWhisper windows: shared styling by default, with optional custom overrides.", 1),
    preview = {type = "execute", name = "Generate conversations", order = 2,
      func = function () Core:GetModule("Whispers"):StartPreview() end},
    clear = {type = "execute", name = "Clear sample conversations", order = 3,
      func = function () Core:GetModule("Whispers"):ClearPreviewData() end},
    minimal = {type = "execute", name = "Text-only chat headers", order = 4,
      desc = "Hide added title icons, selection line and hover wash. Keeps your typography, backgrounds, native conversation icons and scrolling settings.",
      func = function ()
        Core.db.profile.chatTitleIcons, Core.db.profile.chatSelectionIndicator, Core.db.profile.chatHoverWash = false, false, false
        refresh()
      end},
    refined = {type = "execute", name = "Refined chat headers", order = 5,
      desc = "Use small, subdued icons and a thin selection line. Keeps your typography, backgrounds and scrolling settings.",
      func = function ()
        Core.db.profile.chatTitleIcons, Core.db.profile.chatSelectionIndicator, Core.db.profile.chatHoverWash = true, true, false
        Core.db.profile.chatTitleIconSize, Core.db.profile.chatTitleIconGap, Core.db.profile.chatTitleIconOpacity = 14, 6, 0.5
        refresh()
      end},
  })
  return {type = "group", name = "Appearance", order = 5, childGroups = "tab",
    args = {design = design, typography = typography, headers = headers, surfaces = surfaces, windows = windows}}
end
