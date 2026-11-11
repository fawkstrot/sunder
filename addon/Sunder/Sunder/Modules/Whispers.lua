local Core, Constants = unpack(select(2, ...))
local W = Core:GetModule("Whispers")

Core.defaults.profile.whispers = {
  idleWhisperAction = "minimize",
  minimizedPreviewUntilRead = true, minimizedPreviews = true, minimizedPreviewRows = 5, minimizedPreviewTime = 20,
  conversationLayout = "list", conversationListRatio = 30, singleRowHeader = false, hubMatchChat = true, hubUseChatFade = true,
  headerFont = "INHERIT", headerFontFlags = "", headerFontSize = 14, tabFontSize = 12,
  toolbarIconSize = 19, headerPadding = 7, toolbarSpacing = 3,
  conversationTabWidth = 170, conversationTabHeight = 28, tabPadding = 6,
  minimizeEdge = "TOP",
  hubBackgroundColor = {r = 0.035, g = 0.04, b = 0.05},
  hubBackgroundOpacity = 0.96, hubHeaderOpacity = 0.96, hubBorderOpacity = 0.35,
  enabled = true, mode = "hub", suppress = true, autoSelect = false,
  visibility = "timer", holdTime = 90, fadeTime = 0.6, keepUnread = true,
  keepMessagesOpen = true, previewSound = true, previewAutoNotify = false, previewInterval = 5,
  previewConversations = 10, previewLines = 40, previewBatchSize = 50,
  showOnIncoming = true, unreadBadges = true, timestamps = true,
  resetOnInteraction = true,
  timestampFormat = "[%H:%M]", soundEnabled = true, sound = "soft",
  customSound = "", soundChannel = "Master", soundCooldown = 2,
  replaceNativeSound = true,
  muteInCombat = false, muteDND = true, soundOnlyUnfocused = false,
  hubWidth = 540, hubHeight = 340, hubPoint = "CENTER", hubX = 0, hubY = 100,
}

local function accessible(value)
  return not _G.canaccessvalue or _G.canaccessvalue(value)
end

function W:Settings() return Core.db.profile.whispers end

function W:IsWhisper(frame)
  return frame and (frame.chatType == "WHISPER" or frame.chatType == "BN_WHISPER")
end

function W:Key(frame)
  local target = frame and frame.chatTarget
  if frame and frame.chatType == "WHISPER" and accessible(target)
    and type(target) == "string" and target ~= "" and not target:find("|K", 1, true) then
    return target:lower()
  end
end

function W:ConversationName(frame)
  if not frame then return "Whisper" end
  local target=frame.chatTarget
  local record=self.records and self.records[frame]
  if frame.chatType=="WHISPER" and accessible(target) and type(target)=="string" and not target:find("|K",1,true) then
    if target:find(" ",1,true) then return target end
    local cached=self.whisperNames and self.whisperNames[target:lower()]
    if cached then return cached end
    local sep=_G.Constants and _G.Constants.CharacterNameSeparatorConsts
    local unitName=_G.UnitNameUnmodified or _G.UnitName
    if sep and unitName then
      local ok,first,last=pcall(unitName,target)
      if ok and accessible(first) and accessible(last) and type(first)=="string" and type(last)=="string" and last~="" then
        local tail=(sep.CHARACTERNAME_SURNAME_SEPARATOR or " ")..last
        local full=first:sub(-#tail)==tail and first or first..tail
        self.whisperNames=self.whisperNames or {};self.whisperNames[target:lower()]=full
        return full
      end
    end
    if record and record.displayName then return record.displayName end
    return target
  end
  local native=frame.GetName and _G[frame:GetName().."Tab"]
  return native and native.Text and native.Text:GetText() or "Whisper"
end

function W:Record(frame)
  if not self:IsWhisper(frame) then return nil end
  self.records = self.records or {}
  local r = self.records[frame]
  if not r then
    local key = self:Key(frame)
    local saved = key and Core.db.char.whisperLayouts and Core.db.char.whisperLayouts[key]
    r = {frame = frame, key = key, unread = 0, lastActivity = GetTime(),
      pinned = saved and saved.pinned or false, saved = saved}
    self.records[frame] = r
  end
  return r
end

function W:IsGrouped(frame)
  local r = self.records and self.records[frame]
  return r and r.placement == "hub"
end

-- Visibility is distinct from read state: scrolling back should not spawn toasts.
function W:IsConversationDisplayed(frame)
  local window=Core:GetModule("UIManager"):GetChatWindow(frame)
  if not window then return false end
  if self:IsGrouped(frame) then
    local host=self:HubFor(frame)
    return not host.previewActive and not host.minimized and host.selected==frame and
      host.hub and host.hub:IsShown() and host.hub:GetAlpha()>0.1
  end
  local smf=window.slidingMessageFrame
  return smf and smf:IsVisible() and (not smf.GetAlpha or smf:GetAlpha()>0.1) and
    (not frame.isDocked or GENERAL_CHAT_DOCK.selected==frame)
end

function W:IsReading(frame)
  local ui = Core:GetModule("UIManager")
  local window = ui:GetChatWindow(frame)
  if not window then return false end
  if self.previewActive and self:IsGrouped(frame) then return false end
  if window.slidingMessageFrame.state and window.slidingMessageFrame.state.scrollAtBottom == false then return false end
  local input=ui:GetLayoutEditBox(window)
  if input and input:HasFocus() then return true end
  if self:IsGrouped(frame) then
    local host = self:HubFor(frame)
    return not host.minimized and host.selected == frame and host.hub and host.hub:IsShown() and host.hub:GetAlpha() > 0.9
  end
  return window.slidingMessageFrame:IsVisible()
    and (not frame.isDocked or GENERAL_CHAT_DOCK.selected == frame)
end

function W:MarkRead(frame)
  local r = self.records and self.records[frame]
  if not r then return end
  r.unread = 0
  local tab = _G[frame:GetName().."Tab"]
  if tab and tab.SetUnreadCount then tab:SetUnreadCount(0) end
end

function W:KeepMessagesVisible(frame)
  local cfg = self:Settings()
  if not cfg.enabled or not self:IsWhisper(frame) then return false end
  local r = self.records and self.records[frame]
  return not frame.isDocked or cfg.visibility == "always"
    or r and (r.pinned or cfg.keepUnread and r.unread > 0)
end

function W:MessageHoldTime(frame)
  return self:Settings().enabled and self:IsWhisper(frame) and self:Settings().holdTime or nil
end

function W:PlayNotification(preview, quiet)
  local cfg = self:Settings()
  local now = GetTime()
  if not preview then
    if not cfg.soundEnabled or self.lastSound and now - self.lastSound < cfg.soundCooldown then return end
    if cfg.muteInCombat and InCombatLockdown() then return end
    if cfg.muteDND and UnitIsDND and UnitIsDND("player") then return end
  end
  local path
  if cfg.sound == "soft" then path = "Interface\\AddOns\\Sunder\\Media\\Sounds\\WhisperSoft.ogg"
  elseif cfg.sound == "bell" then path = "Interface\\AddOns\\Sunder\\Media\\Sounds\\WhisperBell.ogg"
  elseif cfg.sound == "custom" then path = cfg.customSound
  elseif cfg.sound:sub(1, 4) == "lsm:" then path = Core.Libs.LSM:Fetch("sound", cfg.sound:sub(5), true) end
  if path and path ~= "" and path ~= 1 then
    local ok, played = pcall(PlaySoundFile, path, cfg.soundChannel)
    if ok and played and not preview then self.lastSound = now end
    self.lastSoundTest = ok and played and "Sound playback started." or "Unable to play sound. Restart WoW after adding audio files; check audio settings and the selected path."
    if preview and not quiet then Core:GetModule("Config"):Print(self.lastSoundTest) end
  elseif preview and not quiet then
    Core:GetModule("Config"):Print("Choose a sound or enter an installed custom sound file first.")
  end
end

function W:OnNativeMessage(frame, typeID, messageArgs)
  if not self.ready or not self:Settings().enabled or not self:IsWhisper(frame) then return end
  local displayed=self:IsConversationDisplayed(frame)
  local history=Core:GetModule("WhisperTabs",true)
  if history and history.ScheduleSave then history:ScheduleSave() end
  local r = self:Record(frame)
  r.lastActivity = GetTime()
  if self.previewActive then self:StopPreview() end
  local incoming = accessible(typeID) and typeID ~= nil and ChatTypeInfo
    and (typeID == ChatTypeInfo.WHISPER.id or typeID == ChatTypeInfo.BN_WHISPER.id)
  if incoming then
    if not self:IsReading(frame) then r.unread = r.unread + 1 end
    if not self:Settings().soundOnlyUnfocused or not self:IsReading(frame) then self:PlayNotification(false) end
    if self:Settings().showOnIncoming then self:Reveal(frame) end
    if not displayed and self.QueueMinimizedWhisper then self:HubFor(frame):QueueMinimizedWhisper(frame, false, messageArgs and messageArgs[2], nil, messageArgs) end
    if self:Settings().autoSelect and not (GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()) then
      self:SelectConversation(frame, false)
    end
  elseif self:IsReading(frame) then self:MarkRead(frame) end
  self:UpdateBadges()
end

function W:OnWindowOpened(frame)
  if not self.ready or not self:Settings().enabled or not self:IsWhisper(frame) then return end
  local r = self:Record(frame)
  if r.openScheduled then return end
  r.openScheduled = true
  C_Timer.After(0, function ()
    r.openScheduled = nil
    if not frame.inUse or self.records[frame] ~= r or not self:Settings().enabled then return end
    local destination = r.saved and r.saved.placement or (self:Settings().mode == "hub" and "hub" or "main")
    if self:Settings().mode == "inline" then destination = "main" end
    r.workspace = r.saved and r.saved.workspace or "messages"
    self:Place(frame, destination, false)
    local window = Core:GetModule("UIManager"):GetChatWindow(frame)
    local editBox = window and window.editBox
    if editBox and not editBox.sunderWhisperFocusHook then
      editBox.sunderWhisperFocusHook = true
      editBox:HookScript("OnEditFocusGained", function ()
        self:Reveal(frame)
        if self:IsGrouped(frame) then self:SelectConversation(frame, false) end
        if self:IsReading(frame) then self:MarkRead(frame) end
      end)
    end
  end)
end

function W:Place(frame, destination, selectIt)
  if not self:IsWhisper(frame) then return end
  local r = self:Record(frame)
  local ui = Core:GetModule("UIManager")
  local window = ui:GetChatWindow(frame)
  if not window then return end
  if InCombatLockdown() and frame:IsProtected() then
    self.deferredPlacements = self.deferredPlacements or {}
    self.deferredPlacements[frame] = {destination = destination, selectIt = selectIt, record = r}
    return
  end
  local scrollIndex = window.slidingMessageFrame.state.scrollIndex or 1
  local messageOffset = window.slidingMessageFrame.state.messageOffset or 0
  if r.placement == "hub" and destination ~= "hub" then self:RemoveHubTab(frame) end
  r.placement = destination
  window.slidingMessageFrame.whisperDock = nil
  window.slidingMessageFrame.whisperFullSurface = nil
  if destination == "hub" then
    local host = self:HubFor(frame)
    host:EnsureHub()
    if frame.isDocked then FCF_UnDockFrame(frame) end
    host:AddHubTab(frame)
    if not host.selected then host.selected = frame end
    ui:RefreshChatFrameLayout(frame)
    host:RefreshHubSelection()
    if selectIt or not host.windowManuallyClosed and (self:Settings().visibility == "always" or r.unread > 0 and self:Settings().showOnIncoming) then
      host.hub:SetAlpha(1); host.hub:Show()
    end
  else
    if window.detachedLayout then window.detachedLayout.container:SetAlpha(1) end
    if destination == "main" then
      if not frame.isDocked then FCF_DockFrame(frame, #GENERAL_CHAT_DOCK.DOCKED_CHAT_FRAMES + 1, false) end
    else
      if frame.isDocked then FCF_UnDockFrame(frame) end
      frame:ClearAllPoints()
      local saved = r.saved
      frame:SetPoint(saved and saved.point or "CENTER", UIParent, saved and saved.point or "CENTER",
        saved and saved.x or 120, saved and saved.y or 100)
      frame:SetSize(saved and saved.width or 480, saved and saved.height or 260)
      frame:Show()
    end
    ui:RefreshChatFrameLayout(frame)
    if destination == "main" then ui.dock:UpdateTabOrder() end
    if destination == "detached" and not selectIt and not self:Settings().showOnIncoming and window.detachedLayout then
      window.detachedLayout.container:Hide()
    end
  end
  if scrollIndex > 1 or messageOffset ~= 0 then
    window.slidingMessageFrame:SetScrollPosition(scrollIndex, messageOffset)
  end
  if selectIt then self:SelectConversation(frame, false) end
  self:UpdateBadges()
end

function W:OnWindowClosed(frame)
  local history=Core:GetModule("WhisperTabs",true)
  if history and history.ScheduleSave then history:ScheduleSave() end
  if not self.records or not self.records[frame] then return end
  self:RemoveHubTab(frame)
  self.records[frame] = nil
  self:UpdateBadges()
end

function W:SelectConversation(frame, reply)
  local r = self.records and self.records[frame]
  if not r then return end
  if InCombatLockdown() and frame:IsProtected() then return end
  local window = Core:GetModule("UIManager"):GetChatWindow(frame)
  if not window then return end
  if r.placement == "hub" then
    local host = self:HubFor(frame)
    if host.minimized then host:SetMinimized(false) end
    host.selected = frame
    host:RefreshHubSelection()
  elseif frame.isDocked then FCF_SelectDockFrame(frame) end
  self:Reveal(frame)
  if self:IsReading(frame) then self:MarkRead(frame) end
  _G.SELECTED_CHAT_FRAME = frame
  local util = _G.ChatFrameUtil
  if reply then
    local open = util and util.OpenChat or _G.ChatEdit_OpenChat
    if open then open("", frame) end
  else
    local setLast = util and util.SetLastActiveWindow or _G.ChatEdit_SetLastActiveWindow
    if setLast and not (GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()) then setLast(window.editBox) end
  end
  self:UpdateBadges()
end

function W:Reveal(frame)
  local r = self.records and self.records[frame]
  if not r then return end
  if self:Settings().resetOnInteraction then r.lastActivity = GetTime() end
  if r.placement == "hub" then local host = self:HubFor(frame); if host.hub then host.hub:SetAlpha(1); host.hub:Show() end
  elseif r.placement == "detached" then
    local window = Core:GetModule("UIManager"):GetChatWindow(frame)
    if window and window.detachedLayout then
      window.detachedLayout.container:SetAlpha(1)
      window.detachedLayout.container:Show()
    end
  end
end

function W:AlphaFor(records, hovered, typing)
  local cfg = self:Settings()
  if Core.sunderMoverUnlocked or hovered or typing or cfg.visibility == "always" then return 1 end
  local latest = 0
  for _, r in ipairs(records) do
    if r.pinned or cfg.keepUnread and r.unread > 0 then return 1 end
    latest = math.max(latest, r.lastActivity)
  end
  return math.max(0, math.min(1, 1 - (GetTime() - latest - cfg.holdTime) / math.max(0.05, cfg.fadeTime)))
end

function W:Tick()
  if not self:Settings().enabled then return end
  if self.TickMessageSimulation then self:TickMessageSimulation() end
  if not self.previewSimulation and self.previewActive and self:Settings().previewAutoNotify
    and GetTime() - (self.lastPreviewNotification or 0) >= self:Settings().previewInterval then
    self:GeneratePreviewNotification()
  end
  if self.deferredPlacements and not InCombatLockdown() then
    local pending = self.deferredPlacements
    self.deferredPlacements = nil
    for frame, placement in pairs(pending) do
      if frame.inUse and self.records[frame] == placement.record then
        if placement.workspace then self:MoveToWorkspace(frame, placement.workspace)
        else self:Place(frame, placement.destination, placement.selectIt) end
      end
    end
  end
  local grouped, ui = {}, Core:GetModule("UIManager")
  for frame, r in pairs(self.records or {}) do
    local window = ui:GetChatWindow(frame)
    if window and frame.inUse then
      if frame.isDocked and r.placement == "detached" then r.placement = "main" end
      if not frame.isDocked and r.placement == "main" then r.placement = "detached" end
      if r.placement == "hub" then
        local host = self:HubFor(frame)
        grouped[host] = grouped[host] or {}
        grouped[host][#grouped[host] + 1] = r
      elseif r.placement == "detached" and window.detachedLayout then
        local container = window.detachedLayout.container
        local input=ui:GetLayoutEditBox(window)
        local alpha = self:AlphaFor({r}, container:IsMouseOver(), input and input:HasFocus())
        container:SetAlpha(alpha)
        if alpha == 0 then container:Hide() end
      end
      if r.unread > 0 and self:IsReading(frame) then self:MarkRead(frame) end
    end
  end
  for _, host in pairs(self.workspaces or {}) do
    if host.hub and host.hub:IsShown() then
      local selected = host.selected and ui:GetChatWindow(host.selected)
      local input=selected and ui:GetLayoutEditBox(selected)
      local records = grouped[host] or {}
      records[#records + 1] = {lastActivity = host.hubOpenedAt or 0, unread = 0}
      local heldOpen = host.hubMoving or host.minimized or host:HubSettings().keepMessagesOpen or host.previewActive
      local alpha = heldOpen and 1 or self:AlphaFor(records, host.hub:IsMouseOver(),
        input and input:HasFocus())
      if W.previewSimulation and host.previewActive and not host.hubMoving then alpha = host:SimulationWindowAlpha() end
      host.hub:SetAlpha(alpha)
      if alpha < 1 and self:Settings().idleWhisperAction ~= "hide" and not Core.sunderMoverUnlocked then
        if not host.minimized then host:SetMinimized(true) end
        host.hub:SetAlpha(1)
      elseif alpha == 0 and not Core.sunderMoverUnlocked then host.hub:Hide() end
    end
  end
  self:UpdateBadges()
end

function W:Save()
  local layouts = {}
  for frame, r in pairs(self.records or {}) do
    if r.key and frame.inUse then
      local placement = frame.isDocked and "main" or r.placement == "hub" and "hub" or "detached"
      local point, _, _, x, y = frame:GetPoint(1)
      layouts[r.key] = {placement = placement, workspace = r.workspace, pinned = r.pinned,
        point = point, x = x, y = y, width = frame:GetWidth(), height = frame:GetHeight()}
    end
  end
  Core.db.char.whisperLayouts = layouts
end

function W:ApplySettings(relocate, changedKey)
  local cfg = self:Settings()
  if changedKey == "keepMessagesOpen" then
    self.hubOpenedAt = GetTime()
    if cfg.enabled and cfg.keepMessagesOpen then self:OpenMessages() end
  end
  if not cfg.enabled then
    self.deferredPlacements = nil
    for _, host in pairs(self.workspaces or {}) do if host.hub then host.hub:Hide() end end
  end
  if not cfg.enabled and self.previewActive then self:StopPreview() end
  if not cfg.enabled or not cfg.replaceNativeSound or cfg.mode == "inline" then
    for frame, old in pairs(self.nativeSoundTimers or {}) do frame.tellTimer = old.value end
    self.nativeSoundTimers = nil
  end
  local mode = cfg.enabled and cfg.mode ~= "inline" and "popout_and_inline" or "inline"
  local set = C_CVar and C_CVar.SetCVar or SetCVar
  set("whisperMode", cfg.enabled and mode or self.originalMode or "inline")
  for frame, r in pairs(self.records or {}) do
    if not cfg.enabled then
      if r.placement == "hub" then self:Place(frame, "main", false) end
    elseif relocate and r.placement ~= "detached" then
      if cfg.mode == "inline" then self:Place(frame, "main", false)
      elseif r.placement == "hub" and r.workspace and r.workspace ~= "messages" then
        self:HubFor(frame):LayoutHub()
      else self:Place(frame, cfg.mode == "hub" and "hub" or "main", false) end
    end
    local window = Core:GetModule("UIManager"):GetChatWindow(frame)
    if window then
      if not changedKey or changedKey == "timestamps" or changedKey == "timestampFormat" or changedKey == "distinguishReplies" or changedKey == "replyColor" or changedKey == "replyMarker" then
        local state = window.slidingMessageFrame.state
        local index, offset = state.scrollIndex or 1, state.messageOffset or 0
        window.slidingMessageFrame:RefreshLayout(true)
        if index > 1 or offset ~= 0 then window.slidingMessageFrame:SetScrollPosition(index, offset) end
      end
      window.slidingMessageFrame:UpdateAlwaysVisible()
    end
  end
  if changedKey == "mode" then
    -- Keep restored/reopened conversations in the destination just chosen.
    Core.db.char.whisperLayouts = Core.db.char.whisperLayouts or {}
    for frame,r in pairs(self.records or {}) do
      if r.key and frame.inUse and not (self.deferredPlacements and self.deferredPlacements[frame]) then
        local saved=r.saved or Core.db.char.whisperLayouts[r.key] or {}
        saved.placement,saved.workspace,saved.pinned=r.placement,r.workspace,r.pinned
        r.saved=saved;Core.db.char.whisperLayouts[r.key]=saved
      end
    end
    if cfg.enabled and cfg.mode == "hub" and cfg.keepMessagesOpen then self:OpenMessages() end
  end
  if self.hub then
    if not cfg.enabled then self.hub:Hide() end
    if cfg.enabled and not self.windowManuallyClosed and cfg.visibility == "always" and #self.hubOrder > 0 then self.hub:Show(); self.hub:SetAlpha(1) end
    if relocate then
      self.hub:SetSize(cfg.hubWidth, cfg.hubHeight)
      self.hub:ClearAllPoints(); self.hub:SetPoint(cfg.hubPoint, UIParent, cfg.hubPoint, cfg.hubX, cfg.hubY)
      self:LayoutHub()
    end
  end
  self:RefreshHubStyle()
  Core:Dispatch(Constants.ACTIONS.UpdateConfig("whispers"))
  if self.previewActive and (not changedKey or changedKey == "timestamps" or changedKey == "timestampFormat" or changedKey == "distinguishReplies" or changedKey == "replyColor" or changedKey == "replyMarker") then
    self:RenderPreview()
  end
end

function W:OnEnable()
  self:BeginMessageWindowRestore()
  self.records, self.ready = {}, true
  local get = C_CVar and C_CVar.GetCVar or GetCVar
  Core.db.global.whisperModeBeforeSunder = Core.db.global.whisperModeBeforeSunder or get("whisperMode")
  self.originalMode = Core.db.global.whisperModeBeforeSunder
  local util = _G.ChatFrameUtil
  local addFilter = util and util.AddMessageEventFilter or _G.ChatFrame_AddMessageEventFilter
  if addFilter then
    self.messageFilter = function (frame, event, ...)
      local sender, flags, guid = select(2,...), select(6,...), select(12,...)
      if self.RememberWhisperClass then self:RememberWhisperClass(sender,guid) end
      if accessible(flags) and flags == "GM" then return false end
      local cfg = self:Settings()
      if not cfg.enabled or cfg.mode == "inline" then return false end
      if cfg.suppress and not self:IsWhisper(frame) then return true end
      if cfg.replaceNativeSound and (event == "CHAT_MSG_WHISPER" or event == "CHAT_MSG_BN_WHISPER") then
        -- Native chat tests this per-frame deadline after formatting the message.
        -- Suppress only its whisper ping; never replace global sound functions.
        self.nativeSoundTimers = self.nativeSoundTimers or {}
        if not self.nativeSoundTimers[frame] then self.nativeSoundTimers[frame] = {value = frame.tellTimer} end
        frame.tellTimer = GetTime() + 60
      end
      return false
    end
    for _, event in ipairs({"CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM", "CHAT_MSG_BN_WHISPER", "CHAT_MSG_BN_WHISPER_INFORM"}) do
      addFilter(event, self.messageFilter)
    end
  end
  self:ApplySettings(false)
  local ui = Core:GetModule("UIManager")
  for _, window in pairs(ui.state.windows) do
    if window.active then self:OnWindowOpened(window.chatFrame) end
  end
  C_Timer.After(0, function () self:RestoreMessageWindows() end)
  self:SecureHook("FCF_Close", function (frame) self:OnWindowClosed(frame) end)
  self:SecureHook("FCF_SelectDockFrame", function (frame)
    if self.records[frame] then
      if self:IsReading(frame) then self:MarkRead(frame) end
      self:UpdateBadges()
    end
  end)
  Core:Subscribe(Constants.EVENTS.UNLOCK_MOVER, function () self:SetHubEditMode(true) end)
  Core:Subscribe(Constants.EVENTS.LOCK_MOVER, function () self:SetHubEditMode(false) end)
  Core:Subscribe(Constants.EVENTS.UPDATE_CONFIG, function (key)
    if key == "font" or key == "editBoxAnchor" or key == "editBoxVerticalPadding" or key == "editBoxFontSize" then
      for _, host in pairs(self.workspaces or {}) do if host.hub then host:LayoutHub() end end
    end
  end)
  for _, event in ipairs({"OnProfileChanged", "OnProfileCopied", "OnProfileReset"}) do
    Core.db.RegisterCallback(self, event, function () self:ApplySettings(true) end)
  end
  Core.db.RegisterCallback(self, "OnDatabaseShutdown", function () self:Save(); self.windowStateShutdown = true end)
  self.ticker = C_Timer.NewTicker(0.2, function () self:Tick() end)
  if _G.Menu and Menu.ModifyMenu then
    Menu.ModifyMenu("MENU_FCF_TAB", function (owner, root)
      local frame = owner and owner.chatFrame
      if not self:IsWhisper(frame) or not self:Settings().enabled then return end
      root:CreateDivider()
      root:CreateButton(self:IsFavorite(frame) and "Remove from Favorites" or "Add to Favorites", function () self:ToggleFavorite(frame) end)
      root:CreateButton("Move to whisper group", function () self:WorkspaceMenu(owner, frame) end)
      root:CreateButton("Move to Whispers window", function () self:Place(frame, "hub", true) end)
      root:CreateButton("Move to main chat tabs", function () self:Place(frame, "main", true) end)
      root:CreateButton("Detach conversation", function () self:Place(frame, "detached", true) end)
      root:CreateButton("Pin / unpin conversation", function () self:ToggleConversationPin(frame) end)
    end)
  end
end
