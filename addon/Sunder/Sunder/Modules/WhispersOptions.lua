local Core, Constants = unpack(select(2, ...))
local W = Core:GetModule("Whispers")

local function settings() return Core.db.profile.whispers end
local function field(key, kind, name, order, extra)
  local option = {type = kind, name = name, order = order,
    get = function () return settings()[key] end,
    set = function (_, value)
      settings()[key] = value
      W:ApplySettings(key == "mode", key)
    end}
  for k, value in pairs(extra or {}) do option[k] = value end
  return option
end

local function sounds()
  local values = {soft = "Sunder — Soft chime", bell = "Sunder — Bell", custom = "Custom file path"}
  for name, path in pairs(Core.Libs.LSM:HashTable("sound")) do
    if path ~= 1 then values["lsm:"..name] = name end
  end
  return values
end

Core:RegisterFeature("whispers", {name = "Whispers", order = 20,
  resetOptions = function ()
    local function copy(value)
      if type(value) ~= "table" then return value end
      local out = {}; for key, item in pairs(value) do out[key] = copy(item) end; return out
    end
    local appearance = {}
    for _, key in ipairs(Core.AppearanceWhisperKeys or {}) do appearance[key] = copy(settings()[key]) end
    Core.db.profile.whispers = copy(Core.defaults.profile.whispers)
    for key, value in pairs(appearance) do Core.db.profile.whispers[key] = value end
    W:ApplySettings(true)
  end,
  buildOptions = function ()
  return {type = "group", args = {
    appearance = {name = "Appearance", type = "group", order = 2.5, args = {
      intro = {type = "description", order = 0, name = "Live styling for Whispers and custom groups, including preview windows. Fonts inherit EllesmereUI when available, with a native fallback. Chat message text and editors use the shared controls under Chat."},
      shared = {type = "group", name = "Message text (shared with Chat)", inline = true, order = 0.5,
        args = (function ()
          local page = Core:GetModule("Config").Pages.messages()
          local source, result = page.args.section1.args, {}
          for _, key in ipairs({"messageFont", "messageFontFlags", "messageFontSize", "messageLeading", "messageLinePadding"}) do result[key] = source[key] end
          return result
        end)()},
      header = {type = "header", name = "Header & toolbar", order = 1},
      headerFont = field("headerFont", "select", "Interface font", 2, {values = function ()
        local fonts = {INHERIT = "Automatic — Ellesmere / native"}
        for name in pairs(Core.Libs.LSM:HashTable("font")) do fonts[name] = name end
        return fonts
      end}),
      headerFontFlags = field("headerFontFlags", "select", "Interface text outline", 2.5,
        {values = {[""] = "None", OUTLINE = "Thin outline", THICKOUTLINE = "Thick outline"}}),
      headerFontSize = field("headerFontSize", "range", "Title font size", 3, {min = 10, max = 22, step = 1}),
      tabFontSize = field("tabFontSize", "range", "Conversation tab font size", 4, {min = 10, max = 18, step = 1}),
      toolbarIconSize = field("toolbarIconSize", "range", "Toolbar icon size", 5, {min = 12, max = 22, step = 1}),
      headerPadding = field("headerPadding", "range", "Header padding", 6, {min = 4, max = 16, step = 1}),
      toolbarSpacing = field("toolbarSpacing", "range", "Toolbar button spacing", 7, {min = 2, max = 8, step = 1}),
      tabs = {type = "header", name = "Conversation strip", order = 8},
      conversationTabWidth = field("conversationTabWidth", "range", "Tab width", 9, {min = 130, max = 260, step = 5}),
      conversationTabHeight = field("conversationTabHeight", "range", "Tab height", 10, {min = 28, max = 44, step = 1}),
      tabPadding = field("tabPadding", "range", "Tab content padding", 11, {min = 4, max = 12, step = 1}),
      reset = {type = "execute", name = "Reset typography & spacing", order = 12, func = function ()
        for _, key in ipairs({"headerFont", "headerFontSize", "tabFontSize", "headerFontFlags", "toolbarIconSize", "headerPadding", "toolbarSpacing", "conversationTabWidth", "conversationTabHeight", "tabPadding"}) do
          settings()[key] = Core.defaults.profile.whispers[key]
        end
        W:ApplySettings(false, "appearance")
      end},
    }},
    routing = {name = "Conversations", type = "group", order = 1, args = {
      enabled = field("enabled", "toggle", "Enable whisper manager", 1),
      mode = field("mode", "select", "Conversation destination", 2, {values = {
        tabs = "Tabs in main chat", hub = "Separate Whispers window", inline = "Native inline chat"},
        desc = "Separate Whispers window uses the people list and conversation body. Tabs in main chat uses the original chat tab strip. Changing this moves existing managed conversations too; individually detached windows keep their position."}),
      suppress = field("suppress", "toggle", "Suppress whispers in other chat windows", 3,
        {desc = "Display incoming and outgoing whispers only in their dedicated conversation. Does not suppress GM messages. Inline mode always leaves normal chat delivery unchanged."}),
      autoSelect = field("autoSelect", "toggle", "Select incoming conversations automatically", 4,
        {desc = "Off by default: new whispers do not switch away from the conversation you are reading. Automatic selection never interrupts an active text field."}),
      showOnIncoming = field("showOnIncoming", "toggle", "Reveal window on new incoming message", 5),
      open = {type = "execute", name = "Open Whispers window", order = 6, func = function () W:OpenMessages() end},
      read = {type = "execute", name = "Mark all conversations read", order = 7, func = function ()
        for frame in pairs(W.records or {}) do W:MarkRead(frame) end; W:UpdateBadges()
      end},
      closeRead = {type = "execute", name = "Close read, unpinned conversations", order = 8, confirm = true,
        func = function ()
          local close = {}
          for frame, r in pairs(W.records or {}) do if r.unread == 0 and not r.pinned then close[#close + 1] = frame end end
          for _, frame in ipairs(close) do FCF_Close(frame) end
        end},
      tips = {type = "description", order = 9,
        name = "Each conversation uses native WoW chat: replies, links, scrolling and search work normally. Right-click a main chat whisper tab for placement options. In Whispers, right-click a person or tab for reply, pin, detach, search/copy and close. Shift-click pins; middle-click closes. Character and Battle.net whispers are supported."},
    }},
    workspaces = {name = "Windows & groups", type = "group", order = 1.5, args = {
      name = {type = "input", name = "Group name", order = 3,
        get = function () return W.newWorkspaceName or "" end,
        set = function (_, value) W.newWorkspaceName = value end},
      create = {type = "execute", name = "Create whisper group", order = 4,
        func = function () W:CreateWorkspace(W.newWorkspaceName); W.newWorkspaceName = nil; W:PreviewSettingsChanged() end},
      selected = {type = "select", name = "Manage window", order = 5,
        values = function ()
          W:EnsureWorkspaces(); local names = {messages = W:WorkspaceName()}
          for id, saved in pairs(Core.db.char.messageWorkspaces) do if id~="favorites" then names[id] = saved.name end end
          return names
        end,
        get = function () return W.managedWorkspace or "messages" end,
        set = function (_, id) W.managedWorkspace = id end},
      open = {type = "execute", name = "Open selected window", order = 6,
        func = function () W:GetWorkspace(W.managedWorkspace):OpenMessages() end},
      keep = {type = "toggle", name = "Keep selected window visible", order = 7,
        get = function () return W:GetWorkspace(W.managedWorkspace):HubSettings().keepMessagesOpen end,
        set = function (_, value) local host = W:GetWorkspace(W.managedWorkspace); host:HubSettings().keepMessagesOpen = value; host.hubOpenedAt = GetTime() end},
      rename = {type = "input", name = "Rename selected group", order = 8,
        get = function () return W:GetWorkspace(W.managedWorkspace):WorkspaceName() end,
        set = function (_, value)
          value = value:match("^%s*(.-)%s*$"):sub(1, 32)
          W:GetWorkspace(W.managedWorkspace):RenameWorkspace(value)
        end},
      minimizeEdge = {type = "select", name = "Selected window: collapse toward", order = 8.3,
        values = {TOP = "Top — restore downward", BOTTOM = "Bottom — restore upward"},
        get = function () return W:GetWorkspace(W.managedWorkspace):HubSettings().minimizeEdge or "TOP" end,
        set = function (_, value)
          local host = W:GetWorkspace(W.managedWorkspace)
          if host.collapseAnimation and host.finishCollapse then host.finishCollapse() end
          -- Expand using the old edge before changing direction to preserve the full window rectangle.
          if host.minimized then host:SetMinimized(false, true) end
          host:HubSettings().minimizeEdge = value
        end},
      remove = {type = "execute", name = "Remove group and return its chats to Whispers", order = 8.5, confirm = true,
        disabled = function () return not W.managedWorkspace or W.managedWorkspace == "messages" end,
        func = function () W:RemoveWorkspace(W.managedWorkspace) end},
      arrange = {type = "select", name = "Arrange tabs in selected window", order = 8.6,
        values = {name = "Name", unread = "Unread first", recent = "Recent messages first", pinned = "Pinned first"},
        get = function () return W.pendingTabSort or "name" end,
        set = function (_, value) W.pendingTabSort = value end},
      sort = {type = "execute", name = "Sort selected window", order = 8.7,
        func = function () W:GetWorkspace(W.managedWorkspace):SortConversationTabs(W.pendingTabSort or "name") end,
        desc = "Sort once, then drag tabs to fine-tune their order. Character conversation order is remembered across reloads."},
      help = {type = "description", order = 9,
        name = "Whispers is the default window. Favorites live in its All / Unread / Favorites filters; starring a person never moves their conversation to another window. Saved favorites can reopen conversations without sending a message. Optional named groups and detached conversations keep their own position, size and visibility. Use a conversation's menu to move it between groups, or drag it onto another group's header. Drag names to reorder them; the window menu can also sort by name, unread, recent messages or pins. Double-click a window title to rename it. Use the dotted grip to move, the minus button to minimize, and Chat's layout toggle to resize."},
    }},
    visibility = {name = "Window & visibility", type = "group", order = 2, args = {
      minimizedPreviews = field("minimizedPreviews", "toggle", "Show recent whisper navigator", 0.1,
        {desc = "Recent individual whispers stay above expanded and minimized windows. Click to jump to a message; wheel or page through up to 50 session-only messages."}),
      minimizedPreviewUntilRead = field("minimizedPreviewUntilRead", "toggle", "Keep recent whispers until dismissed", 0.15,
        {desc = "Keep recent message rows after opening a conversation. Turn off to expire each row after the chosen duration. Closing the window hides its navigator; clearing test data removes all test rows."}),
      minimizedPreviewRows = field("minimizedPreviewRows", "range", "Visible whisper navigator rows", 0.2, {min=1,max=10,step=1}),
      minimizedPreviewTime = field("minimizedPreviewTime", "range", "Toast duration (when not kept)", 0.3, {min=5,max=60,step=1}),
      idleWhisperAction = field("idleWhisperAction", "select", "After inactivity", 0.4,
        {values={minimize="Collapse to header and whisper navigator",hide="Fade window away"}}),
      keepMessagesOpen = field("keepMessagesOpen", "toggle", "Keep Whispers window open", 0.5,
        {desc = "Enabled by default. Keeps the Whispers window visible, including when empty, until you close it. Turn off to use the inactivity timer. Detached conversations retain their own visibility policy."}),
      visibility = field("visibility", "select", "Visibility policy", 2,
        {values = {always = "Stay visible", timer = "Fade after inactivity"}}),
      holdTime = field("holdTime", "range", "Seconds after last message", 3, {min = 5, max = 1800, step = 5}),
      fadeTime = field("fadeTime", "range", "Fade duration", 4, {min = 0.1, max = 3, step = 0.1}),
      resetOnInteraction = field("resetOnInteraction", "toggle", "Restart timer when opening / selecting a conversation", 4.5,
        {desc = "Turn off to measure inactivity strictly from the last message. Hovering and typing still keep the window visible."}),
      keepUnread = field("keepUnread", "toggle", "Keep unread conversations visible", 5),
      hubWidth = field("hubWidth", "range", "Whispers window width", 6, {min = 420, max = 1600, step = 5,
        set = function (_, value) settings().hubWidth = value; if W.hub then W.hub:SetWidth(value); W:LayoutHub() end end}),
      hubHeight = field("hubHeight", "range", "Whispers window height", 7, {min = 180, max = 1000, step = 5,
        set = function (_, value) settings().hubHeight = value; if W.hub then W.hub:SetHeight(value); W:LayoutHub() end end}),
      reset = {type = "execute", name = "Reset Whispers window position", order = 8, func = function ()
        settings().hubPoint, settings().hubX, settings().hubY = "CENTER", 0, 100
        if W.hub then W.hub:ClearAllPoints(); W.hub:SetPoint("CENTER", UIParent, "CENTER", 0, 100); W:SaveHubGeometry() end
        W:OpenMessages()
      end},
      appearance = {type = "group", name = "Message window appearance", inline = true, order = 8.5, args = {
        color = {type = "color", name = "Background color", order = 1,
          get = function () local c = settings().hubBackgroundColor; return c.r, c.g, c.b end,
          set = function (_, r, g, b) settings().hubBackgroundColor = {r = r, g = g, b = b}; W:RefreshHubStyle() end},
        opacity = field("hubBackgroundOpacity", "range", "Background opacity", 2,
          {min = 0, max = 1, step = 0.01, isPercent = true}),
        headerOpacity = field("hubHeaderOpacity", "range", "Title bar opacity", 3,
          {min = 0, max = 1, step = 0.01, isPercent = true}),
        borderOpacity = field("hubBorderOpacity", "range", "Border opacity", 4,
          {min = 0, max = 1, step = 0.01, isPercent = true}),
        help = {type = "description", order = 5,
          name = "Applies to Whispers and custom whisper groups, including previews. Text and controls stay readable as the background becomes transparent. Choose each window's collapse direction under Windows & groups."},
      }},
      tips = {type = "description", order = 9,
        name = "Unlocked windows have blue move/resize overlays. Locking ends and saves an active drag or resize. Keep Whispers window open overrides the timer for Whispers only; turn it off to use timed fading. Detached conversations retain their own timer; main-dock tabs follow that dock's visibility. Hovering, typing, pins, and (optionally) unread messages prevent timeout. Manually opening Whispers starts a fresh timer even when empty."},
    }},
    notifications = {name = "Sounds", type = "group", order = 3, args = {
      soundEnabled = field("soundEnabled", "toggle", "Play incoming-message sound", 1),
      replaceNativeSound = field("replaceNativeSound", "toggle", "Replace WoW's default whisper ping", 1.5,
        {desc = "Prevents double sounds and lets Sunder's mute/cooldown settings control whisper notifications. Off leaves WoW's native ping active alongside any custom sound. Native inline mode is unchanged."}),
      sound = field("sound", "select", "Notification sound", 2, {values = sounds}),
      preview = {type = "execute", name = "Preview sound", order = 3, func = function () W:PlayNotification(true) end},
      customSound = field("customSound", "input", "Custom sound file", 4, {
        width = "full", disabled = function () return settings().sound ~= "custom" end,
        desc = "Example: Interface\\AddOns\\SharedMedia\\sound\\my-whisper.ogg. Choose an installed SharedMedia sound above, or enter an .ogg/.mp3/.wav path inside Interface. Restart WoW after adding a new file.",
        validate = function (_, value)
          if value == "" then return true end
          local ext = value:lower():match("%.([a-z0-9]+)$")
          return value:match("^Interface[\\/]") and (ext == "ogg" or ext == "mp3" or ext == "wav")
            and true or "Enter an Interface\\... path ending in .ogg, .mp3 or .wav."
        end}),
      soundChannel = field("soundChannel", "select", "Sound channel", 5,
        {values = {Master = "Master", SFX = "Sound effects", Dialog = "Dialogue"}}),
      soundCooldown = field("soundCooldown", "range", "Minimum seconds between sounds", 6, {min = 0, max = 30, step = 0.5}),
      soundOnlyUnfocused = field("soundOnlyUnfocused", "toggle", "Sound only when conversation is not being read", 7),
      muteDND = field("muteDND", "toggle", "Mute while Do Not Disturb is active", 8),
      muteInCombat = field("muteInCombat", "toggle", "Mute in combat", 9),
      help = {type = "description", order = 10,
        name = "Sounds play for new incoming messages, once per event, with throttling. Outgoing replies and restored history stay silent. Preview bypasses notification suppression so you can test your selection. Normal WoW audio settings still apply."},
    }},
    display = {name = "Display & history", type = "group", order = 4, args = {
      distinguishReplies = field("distinguishReplies", "toggle", "Different color for my replies", 0.1),
      replyColor = {type="color",name="My reply color",order=0.2,hasAlpha=false,
        get=function() return unpack(settings().replyColor or {0.70,0.73,0.78}) end,
        set=function(_,r,g,b) settings().replyColor={r,g,b};W:ApplySettings(false,"replyColor") end},
      replyMarker = field("replyMarker", "toggle", "Show reply chevron", 0.3),
      unreadBadges = field("unreadBadges", "toggle", "Unread count badges", 1),
      timestamps = field("timestamps", "toggle", "Conversation timestamps", 2),
      timestampFormat = field("timestampFormat", "select", "Timestamp format", 3,
        {values = {["[%H:%M]"] = "24-hour", ["[%H:%M:%S]"] = "24-hour with seconds", ["[%I:%M %p]"] = "12-hour"}}),
      keepHistory = {type = "toggle", name = "Remember conversations across reloads", order = 4,
        get = function () return Core.db.profile.keepWhisperTabs end,
        set = function (_, value) Core.db.profile.keepWhisperTabs = value end},
      historyLines = field("historyLines", "range", "Saved lines per conversation", 5,
        {min = 20, max = 200, step = 10}),
      historyConversations = field("historyConversations", "range", "Maximum saved conversations", 5.5,
        {min = 5, max = 50, step = 1}),
      clear = {type = "execute", name = "Forget saved conversation history", order = 6, confirm = true,
        func = function ()
          Core.db.char.whisperTabs, Core.db.char.whisperLayouts, Core.db.char.messageTabOrders = nil, nil, nil
          local history=Core:GetModule("WhisperTabs",true)
          if history then history.pendingHistory=nil;history.restoreArchive=nil;history.restoreGeneration=(history.restoreGeneration or 0)+1 end
          Core.db.profile.keepWhisperTabs = false
        end},
      help = {type = "description", order = 7,
        name = "Pins keep conversations visible until you unpin or close them. Read state does not clear while you are scrolled back. Saved history is local to this character and capped per conversation. Battle.net history uses stable BattleTags and waits for the friend list before restoring. Session-only name tokens are replaced before saving. Protected message content is left to native chat rendering. Forget disables future history saving and clears the saved snapshot; currently open session messages remain available until closed."},
    }},
    preview = {name = "Samples & testing", type = "group", order = 5, args = {
      simulation = {type = "execute", name = "Run five-minute message test", order = 0.1,
        func = function () W:StartMessageSimulation() end},
      simulationStatus = {type = "description", order = 0.2,
        name = function () return W.previewSimulation and "Five-minute test running. New people arrive in waves with two-way exchanges, quiet fade periods and final replies. The countdown above Whispers shows the phase. It clears automatically when finished." or "The five-minute test uses a 12-second idle delay and your fade duration. Hover or pin to keep a window visible; minimized bars stay visible. Only sample windows use these temporary rules. No sample messages or test state are saved." end},
      cancelSimulation = {type = "execute", name = "Stop test and clear all samples", order = 0.3,
        func = function () W:ClearPreviewData() end},
      active = {type = "toggle", name = "Show sample conversations", order = 1,
        get = function () return not not W.previewActive end,
        set = function (_, value) if value then W:StartPreview() else W:StopPreview() end end},
      seed = {type = "execute", name = "Generate / reset sample conversations", order = 2,
        func = function () W:StartPreview() end},
      notify = {type = "execute", name = "Generate incoming message batch", order = 3,
        func = function () W:GeneratePreviewBatch() end},
      previewSound = field("previewSound", "toggle", "Play sound for preview notifications", 4),
      previewAutoNotify = field("previewAutoNotify", "toggle", "Generate notifications automatically during preview", 5),
      previewInterval = field("previewInterval", "range", "Seconds between preview notifications", 6,
        {min = 2, max = 30, step = 1}),
      previewConversations = field("previewConversations", "range", "Sample conversations", 1.1, {min = 3, max = 30, step = 1}),
      previewLines = field("previewLines", "range", "Whispers per sample conversation", 1.2, {min = 5, max = 200, step = 5}),
      previewBatchSize = field("previewBatchSize", "range", "Incoming messages per batch", 2.5, {min = 5, max = 200, step = 5}),
      stop = {type = "execute", name = "Clear all sample data", order = 7, func = function () W:ClearPreviewData() end},
      help = {type = "description", order = 8,
        name = "Generates 10 distinct sample people with 40 messages each by default (up to 30 conversations and 200 messages each). Adjust counts, then Generate / reset. Incoming batches add 50 messages by default across tabs, with one sound per batch. Mouse-wheel over the people list or tabs to browse. Clear all sample data removes samples and disables automatic generation, preserving real conversations. Select tabs or generate incoming samples to test sounds and layout. Move/resize works normally in unlock mode. Samples never create real whisper recipients, sends messages, or saves sample history or favorites. Star individual people, use the pin next to a name (or shift-click), detach with the toolbar, and drag names between regular group lists or headers to test organization. Reply and search remain disabled. Clear all sample data also clears samples from all groups and detached sample windows. A real incoming whisper stops the samples so it cannot hide real messages. Preview sounds use the selected sound and bypass normal notification muting/cooldowns, just like Sound Preview."},
    }},
  }}
end})

Core.defaults.profile.whispers.historyLines = 100
Core.defaults.profile.whispers.historyConversations = 20

Core.defaults.profile.whispers.distinguishReplies = true
Core.defaults.profile.whispers.replyColor = {0.70,0.73,0.78}
Core.defaults.profile.whispers.replyMarker = false
