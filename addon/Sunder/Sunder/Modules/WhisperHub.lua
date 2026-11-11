local Core, Constants = unpack(select(2, ...))
local W = Core:GetModule("Whispers")

local function button(parent, text, width, action)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(width, 22)
  b:SetNormalFontObject("SunderChatDockFont")
  b:SetText(text ~= "" and text or " ")
  local bg = b:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints(); bg:SetColorTexture(1, 1, 1, 0.06)
  b:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
  b:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.12)
  b:SetScript("OnClick", action)
  return b
end

function W:EnsureHub()
  if self.hub then return end
  W:EnsureWorkspaces()
  local cfg = self:HubSettings()
  local hub = CreateFrame("Frame", "SunderMessagesFrame_"..self.hostId, UIParent)
  self.hub, self.hubTabs, self.hubOrder = hub, {}, {}
  hub:SetSize(cfg.hubWidth, cfg.hubHeight)
  hub:SetPoint(cfg.hubPoint, UIParent, cfg.hubPoint, cfg.hubX, cfg.hubY)
  hub:SetFrameStrata("MEDIUM")
  hub:SetToplevel(true)
  hub:SetClampedToScreen(true)
  hub:SetMovable(true)
  hub:EnableMouse(true)
  local bg = hub:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints(); bg:SetColorTexture(0.035, 0.04, 0.05, 0.96)
  self.hubBackground = bg
  local chrome = CreateFrame("Frame", nil, hub)
  chrome:SetPoint("TOPLEFT"); chrome:SetPoint("TOPRIGHT"); chrome:SetHeight(self:HeaderHeight())
  chrome:SetFrameLevel(hub:GetFrameLevel() + 3)
  local headerFill = chrome:CreateTexture(nil, "BACKGROUND")
  headerFill:SetAllPoints(); headerFill:SetColorTexture(0.025, 0.03, 0.04, 0.96)
  local title = chrome:CreateFontString(nil, "OVERLAY", "SunderChatDockFont")
  title:SetPoint("TOPLEFT", 64, -6); title:SetText(self:WorkspaceName())
  title:SetPoint("TOPRIGHT", chrome, "TOPRIGHT", -272, -6); title:SetHeight(16); title:SetJustifyH("LEFT")
  title:SetWordWrap(false)
  title:SetFontObject("SunderChatDockFont")
  local mark = chrome:CreateTexture(nil, "ARTWORK")
  mark:SetSize(22, 22); mark:SetPoint("TOPLEFT", 34, -9)
  mark:SetTexture("Interface\\AddOns\\Sunder\\Media\\Icons\\".."inbox"..".tga")
  mark:SetVertexColor(0.84, 0.66, 0.38)
  self.hubChrome, self.hubMark = chrome, mark
  local rule = chrome:CreateTexture(nil, "BORDER")
  rule:SetPoint("TOPLEFT", 0, -self:HeaderHeight() + 1); rule:SetPoint("TOPRIGHT", 0, -self:HeaderHeight() + 1); rule:SetHeight(1)
  rule:SetColorTexture(0.84, 0.66, 0.38, 0.35)
  self.hubHeaderFill, self.hubRule = headerFill, rule
  self.hubTitle = title
  self:CreateWindowControls(chrome)
  local actions = {
    {"Close", "close", "Close this window", function () self:CloseMessages() end},
    {"Settings", "settings", "Whisper settings", function () Core:GetModule("Config"):OpenSettings("whispers") end},
    {"Windows", "windows", "Windows and conversation destinations", function (owner) self:WorkspaceMenu(owner, not self.previewActive and self.selected or nil) end},
    {"Detach", "detach", "Detach selected conversation", function () if self.previewActive then self:PreviewAction("Detach") elseif self.selected then W:Place(self.selected, "detached", true) end end},
    {"Favorite", "favorite", "Favorite / unfavorite this person", function () if self.previewActive then self:PreviewAction("Favorite") else W:ToggleFavorite(self.selected) end end},
    {"Pin", "pin", "Keep this conversation visible", function ()
      if self.previewActive then self:PreviewAction("Pin"); return end
      local r = self.selected and W.records[self.selected]
      if r then W:ToggleConversationPin(self.selected) end
    end},
    {"Search", "search", "Search or copy this conversation", function () if not self.previewActive and self.selected then Core:GetModule("ChatCopy"):ShowSearch(self.selected) end end},
    {"Reply", "reply", "Reply to this person", function () if not self.previewActive and self.selected then W:SelectConversation(self.selected, true) end end},
  }
  local right = -8
  self.hubActionButtons = {}
  for _, info in ipairs(actions) do
    local b = self:IconButton(chrome, info[2], info[3], info[4])
    b:SetPoint("TOPRIGHT", hub, "TOPRIGHT", right, -7)
    right = right - 29
    self.hubActionButtons[info[1]] = b
    if info[1] == "Pin" then self.pinButton = b end
  end
  local scroll = CreateFrame("ScrollFrame", nil, hub)
  self.tabScroll = scroll
  scroll:SetFrameLevel(chrome:GetFrameLevel() + 1)
  scroll:SetHeight(self:ConversationTabHeight())
  scroll:SetPoint("TOPLEFT", hub, "TOPLEFT", 0, -self:HeaderHeight())
  scroll:SetPoint("TOPRIGHT", hub, "TOPRIGHT", -W.CONVERSATION_NAV_WIDTH, -self:HeaderHeight())
  scroll:EnableMouseWheel(true)
  local child = CreateFrame("Frame", nil, scroll)
  child:SetSize(1, self:ConversationTabHeight())
  scroll:SetScrollChild(child)
  self.tabChild = child
  self:CreateConversationNavigation(scroll, child, false)
  scroll:SetScript("OnMouseWheel", function (_, delta)
    scroll:SetHorizontalScroll(math.max(0, math.min(math.max(0, child:GetWidth() - scroll:GetWidth()),
      scroll:GetHorizontalScroll() - delta * self:TabStep())))
    self:RefreshConversationNavigation(false)
  end)
  local content = CreateFrame("Frame", nil, hub)
  self.hubContent = content
  content:SetPoint("TOPLEFT", hub, "TOPLEFT", 0, -self:HeaderHeight())
  content:SetPoint("BOTTOMRIGHT", hub, "BOTTOMRIGHT")
  self.parking = CreateFrame("Frame", nil, UIParent)
  self.parking:Hide()
  local empty = content:CreateFontString(nil, "OVERLAY", "SunderChatDockFont")
  empty:SetPoint("CENTER", 0, -20); empty:SetText("ROOM FOR A CONVERSATION\n\nNew whispers can arrive here automatically.\nMove a conversation here from its tab menu.")
  local emptyIcon = content:CreateTexture(nil, "ARTWORK")
  emptyIcon:SetSize(48, 48); emptyIcon:SetPoint("CENTER", 0, 48)
  emptyIcon:SetTexture("Interface\\AddOns\\Sunder\\Media\\Icons\\".."inbox"..".tga")
  emptyIcon:SetVertexColor(0.84, 0.66, 0.38, 0.55)
  self.hubEmptyIcon = emptyIcon
  empty:SetTextColor(0.65, 0.68, 0.72)
  self.hubEmpty = empty
  self:CreateHubOverlay()
  hub:SetScript("OnSizeChanged", function () if self.hubReady then self:ApplyHubAppearance() end; self:ScheduleHubLayout() end)
  hub:SetScript("OnShow", function ()
    if not W.restoringWindowState then self.windowManuallyClosed = false end
    self:SaveMessageWindowState()
  end)
  hub:SetScript("OnHide", function ()
    self:StopHubMove(); self.hubResize:FinishResize()
    if self.finishCollapse then self.finishCollapse() end
    if self.previewActive and (not W.previewSimulation or self.windowManuallyClosed) then self:StopPreview() end
    self:SaveMessageWindowState()
  end)
  hub:Hide()
  -- Own the surfaces so opacity controls affect only backgrounds, never text.
  -- Ellesmere still supplies fonts, accent colors and tab styling.
  self.hubBorders = {}
  for _, edge in ipairs({"TOP", "BOTTOM", "LEFT", "RIGHT"}) do
    local line = chrome:CreateTexture(nil, "OVERLAY")
    if edge == "TOP" or edge == "BOTTOM" then
      line:SetPoint(edge.."LEFT", hub, edge.."LEFT"); line:SetPoint(edge.."RIGHT", hub, edge.."RIGHT"); line:SetHeight(1)
    else
      line:SetPoint("TOP"..edge, hub, "TOP"..edge); line:SetPoint("BOTTOM"..edge, hub, "BOTTOM"..edge); line:SetWidth(1)
    end
    self.hubBorders[#self.hubBorders + 1] = line
  end
  self:RefreshHubStyle()
  self.hubReady = true
end

function W:CreateHubOverlay()
  local overlay = CreateFrame("Frame", nil, self.hub)
  self.hubOverlay = overlay
  overlay:SetAllPoints(self.hub)
  overlay:SetFrameLevel(self.hub:GetFrameLevel() + 40)
  overlay:EnableMouse(true)
  overlay:RegisterForDrag("LeftButton")
  local fill = overlay:CreateTexture(nil, "BACKGROUND")
  fill:SetAllPoints(); fill:SetColorTexture(0.22, 0.62, 0.78, 0.35)
  for _, edge in ipairs({"TOP", "BOTTOM", "LEFT", "RIGHT"}) do
    local line = overlay:CreateTexture(nil, "BORDER")
    if edge == "TOP" or edge == "BOTTOM" then
      line:SetPoint(edge.."LEFT"); line:SetPoint(edge.."RIGHT"); line:SetHeight(2)
    else line:SetPoint("TOP"..edge); line:SetPoint("BOTTOM"..edge); line:SetWidth(2) end
    line:SetColorTexture(0.22, 0.62, 0.78, 1)
  end
  overlay:SetScript("OnMouseDown", function (_, mouse) if mouse == "LeftButton" then self:BeginHubMove() end end)
  overlay:SetScript("OnDragStart", function () self:BeginHubMove() end)
  overlay:SetScript("OnMouseUp", function () self:UpdateHubMove(); self:StopHubMove() end)
  overlay:SetScript("OnDragStop", function () self:UpdateHubMove(); self:StopHubMove() end)
  overlay:SetScript("OnHide", function () self:StopHubMove() end)
  self.hubResize = Core.Components.CreateResizeHandle(overlay, {
    minWidth = 480, minHeight = 220,
    allowed = function () return Core.sunderMoverUnlocked and self.hub:IsShown() end,
    begin = function () self:StopHubMove(); return self.hub, self.hub:GetWidth(), self.hub:GetHeight() end,
    apply = function (width, height) self.hub:SetSize(math.max(width, self.minimumWorkspaceWidth or 480), height); self:LayoutHub() end,
    finish = function () self:SaveHubGeometry() end,
  })
  overlay:SetShown(not not Core.sunderMoverUnlocked)
end

function W:BeginHubMove(always)
  if (not always and not Core.sunderMoverUnlocked) or self.hubMoving then return end
  if self.finishCollapse then self.finishCollapse() end
  self.hub:SetClipsChildren(false)
  self.hub:SetAlpha(1)
  self.hubOpenedAt=GetTime();self.lastUserInteraction=GetTime()
  local x, y = GetCursorPosition()
  local scale = self.hub:GetEffectiveScale()
  self.hubMoving = {x = x, y = y, left = self.hub:GetLeft(), top = self.hub:GetTop(), scale = scale, always = always}
  -- Let the engine move the whole frame tree and invalidate its clipping regions.
  -- Reanchoring the root every tick leaves stale child scissors on this client.
  if self.hub.StartMoving and self.hub.StopMovingOrSizing then
    self.hubMoving.native=true
    self.hub:StartMoving()
  end
  local driver = always and self.hubGrip or self.hubOverlay
  self.hubMoveDriver = driver
  driver:SetScript("OnUpdate", function ()
    self:UpdateHubMove()
    if not IsMouseButtonDown("LeftButton") then self:StopHubMove() end
  end)
end

function W:UpdateHubMove()
  local state = self.hubMoving
  if not state then return end
  if not state.always and not Core.sunderMoverUnlocked then self:StopHubMove(); return end
  if state.native then
    self:RefreshWorkspaceClipRects()
    return
  end
  local x, y = GetCursorPosition()
  if state.lastX == x and state.lastY == y then return end
  state.lastX, state.lastY = x, y
  local parentScale = UIParent:GetEffectiveScale() / state.scale
  self.hub:ClearAllPoints()
  self.hub:SetPoint("TOPLEFT", UIParent, "TOPLEFT",
    state.left + (x - state.x) / state.scale - UIParent:GetLeft() * parentScale,
    state.top + (y - state.y) / state.scale - UIParent:GetTop() * parentScale)
end

function W:StopHubMove()
  if not self.hubMoving then return end
  if self.hubMoving.native then self.hub:StopMovingOrSizing() end
  self.hubMoving = nil
  if self.hubMoveDriver then self.hubMoveDriver:SetScript("OnUpdate", nil); self.hubMoveDriver = nil end
  self.hubOpenedAt=GetTime();self.lastUserInteraction=GetTime()
  self:SaveHubGeometry()
  self:SyncWorkspacePresentation()
end

function W:RefreshWorkspaceClipRects()
  -- ScrollFrames cache screen-space rectangles independently of their anchors.
  for _,scroll in pairs({self.tabScroll,self.previewTabScroll}) do
    if scroll.UpdateScrollChildRect then scroll:UpdateScrollChildRect() end
  end
end

function W:SyncWorkspacePresentation()
  if not self.hub or self.collapseAnimation then return end
  self.hub:SetClipsChildren(false)
  self:PresentWindowBody(not self.minimized,1)
  self:PresentCollapsedHeader()
  self:LayoutHub()
  self:EnsureHubTabVisible(self.selected)
  self:ApplyHubAppearance()
  self:RefreshWorkspaceClipRects()
end

function W:SaveHubGeometry()
  if not self.hub then return end
  local cfg = self:HubSettings()
  local point, _, _, x, y = self.hub:GetPoint(1)
  cfg.hubPoint, cfg.hubX, cfg.hubY = point, x, y
  if not self.minimized and not self.collapseAnimation then
    cfg.hubWidth = self.hub:GetWidth()
    if self.hub:GetHeight() >= 220 then cfg.hubHeight = self.hub:GetHeight() end
  end
end

function W:SetHubEditMode(enabled)
  if enabled and not self:Settings().enabled then return end
  if enabled then
    for frame, r in pairs(self.records or {}) do
      if r.placement == "detached" then self:Reveal(frame) end
    end
  end
  if not self.hub and enabled and self:Settings().enabled and self:Settings().mode == "hub" then self:EnsureHub() end
  if self == W then
    for _, host in pairs(self.workspaces or {}) do if host ~= self then host:SetHubEditMode(enabled) end end
  end
  if not self.hub then return end
  if not enabled then self:StopHubMove(); self.hubResize:FinishResize() end
  self.hubOverlay:SetShown(enabled)
  if enabled then self:SetMinimized(false, true); self.hub:Show(); self.hub:SetAlpha(1) end
end

function W:RefreshHubStyle()
  if self == W then for _, host in pairs(self.workspaces or {}) do if host ~= self then host:RefreshHubStyle() end end end
  if not self.hub then return end
  self:ApplyHubAppearance()
  local integration = Core:GetModule("Ellesmere")
  if not self:UsesChatAppearance() and integration:IsActive() and integration.skin.Font then integration.skin.Font(self.hubTitle) end
  self:ApplyWorkspaceMetrics()
end

function W:AddHubTab(frame)
  self:EnsureHub()
  if self.hubTabs[frame] then return end
  local tab = self.retiredHubTabs and self.retiredHubTabs[frame]
    or button(self.tabChild, "", self:TabWidth(), function () self:SelectConversation(frame, false) end)
  if self.retiredHubTabs then self.retiredHubTabs[frame] = nil end
  tab:Show()
  tab:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
  self:EnableTabTransfer(tab, frame)
  tab:SetHeight(self:ConversationTabHeight())
  self:SetTabAppearance(tab, self.selected == frame, false)
  local label = tab:GetFontString()
  label:ClearAllPoints(); label:SetPoint("LEFT", 27, 0); label:SetWidth(88); label:SetJustifyH("LEFT")
  if not tab.favoriteButton then
    tab.favoriteButton = self:IconButton(tab, "favorite", "Favorite / unfavorite this person", function () W:ToggleFavorite(frame) end)
    tab.favoriteButton:SetSize(20, 22); tab.favoriteButton.icon:SetSize(15, 15); tab.favoriteButton:SetPoint("LEFT", 3, 0)
  end
  tab.favoriteButton:SetScript("OnLeave", function () W:UpdateBadges(); GameTooltip:Hide() end)
  self:ConfigureTabPin(tab, W.records[frame], function () W:ToggleConversationPin(frame) end)
  local nativeTab = _G[frame:GetName().."Tab"]
  label:SetText(W:ConversationName(frame))
  local unread = tab.unread or tab:CreateFontString(nil, "OVERLAY", "SunderChatDockFont")
  unread:SetPoint("RIGHT", -5, 0); unread:SetTextColor(1, 0.82, 0)
  tab.unread, tab.label = unread, label
  tab:SetScript("OnClick", function (_, mouse)
    if tab.suppressClick then tab.suppressClick = nil; return end
    if mouse == "MiddleButton" then FCF_Close(frame)
    elseif mouse == "RightButton" then self:ConversationMenu(frame, tab)
    elseif IsShiftKeyDown() then W:ToggleConversationPin(frame)
    else self:SelectConversation(frame, false) end
  end)
  tab:SetScript("OnEnter", function ()
    GameTooltip:SetOwner(tab, "ANCHOR_TOPLEFT")
    GameTooltip:AddLine(W:ConversationName(frame), 1, 1, 1)
    GameTooltip:AddLine("Click: read  •  Right-click: conversation actions", 0.75, 0.75, 0.75)
    GameTooltip:AddLine("Shift-click: pin  •  Middle-click: close", 0.75, 0.75, 0.75)
    GameTooltip:Show()
  end)
  tab:SetScript("OnLeave", function () GameTooltip:Hide() end)
  self.hubTabs[frame] = tab
  self.hubOrder[#self.hubOrder + 1] = frame
  self:RestoreConversationOrder()
  self:LayoutHubTabs()
end

function W:RemoveHubTab(frame)
  local host = W:HubFor(frame)
  if host ~= self then return host:RemoveHubTab(frame) end
  if not self.hubTabs or not self.hubTabs[frame] then return end
  local window=Core:GetModule("UIManager"):GetChatWindow(frame)
  if window then window.slidingMessageFrame:Hide() end
  self.retiredHubTabs = self.retiredHubTabs or {}
  self.retiredHubTabs[frame] = self.hubTabs[frame]
  self.hubTabs[frame]:Hide()
  self.hubTabs[frame] = nil
  for i = #self.hubOrder, 1, -1 do if self.hubOrder[i] == frame then table.remove(self.hubOrder, i) end end
  if self.selected == frame then self.selected = self.hubOrder[1] end
  self:LayoutHubTabs()
  self:RefreshHubSelection()
end

function W:ConversationMenu(frame, owner)
  if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
  MenuUtil.CreateContextMenu(owner, function (_, menu)
    menu:CreateButton(W:IsFavorite(frame) and "Remove from Favorites" or "Add to Favorites", function () W:ToggleFavorite(frame) end)
    menu:CreateButton("Move to another whisper group", function () self:WorkspaceMenu(owner, frame) end)
    menu:CreateButton("New group for this conversation", function () local host = W:CreateWorkspace(); if host then W:MoveToWorkspace(frame, host.hostId) end end)
    menu:CreateButton("Reply", function () self:SelectConversation(frame, true) end)
    menu:CreateButton("Pin / unpin", function () W:ToggleConversationPin(frame) end)
    menu:CreateButton("Detach conversation", function () self:Place(frame, "detached", true) end)
    menu:CreateButton("Move to main chat tabs", function () self:Place(frame, "main", true) end)
    menu:CreateButton("Search / copy messages", function () Core:GetModule("ChatCopy"):ShowSearch(frame) end)
    menu:CreateButton("Mark as read", function () self:MarkRead(frame); self:UpdateBadges() end)
    menu:CreateButton("Close conversation", function () FCF_Close(frame) end)
    self:AddConversationSortMenu(menu)
  end)
end

function W:LayoutHubTabs()
  if not self.hub then return end
  self:KeepPinnedFirst(false)
  local x = 0
  for _, frame in ipairs(self.hubOrder) do
    local tab = self.hubTabs[frame]
    tab:ClearAllPoints(); tab:SetPoint("TOPLEFT", self.tabChild, "TOPLEFT", x, 0)
    local record = W.records and W.records[frame]
    self:SetTabAppearance(tab, self.selected == frame, record and record.unread > 0)
    self:StyleConversationTab(tab)
    tab:GetFontString():SetTextColor(self:ConversationLabelColor(self.selected == frame, frame))
    x = x + self:TabStep()
  end
  self.tabChild:SetWidth(math.max(1, x))
  self.tabScroll:SetHorizontalScroll(math.max(0, math.min(self.tabScroll:GetHorizontalScroll(), x - self.tabScroll:GetWidth())))
  self.hubEmpty:SetShown(#self.hubOrder == 0)
  self.hubEmptyIcon:SetShown(#self.hubOrder == 0)
  self:RefreshConversationNavigation(false)
end

function W:ScheduleHubLayout()
  if self.hubLayoutPending then return end
  self.hubLayoutPending = true
  C_Timer.After(0, function () self.hubLayoutPending = nil; self:LayoutHub() end)
end

function W:LayoutHub()
  if not self.hub or self.minimized or self.collapseAnimation then return end
  local ui = Core:GetModule("UIManager")
  local height = 0
  local selected = self.selected and ui:GetChatWindow(self.selected)
  local selectedBox=selected and ui:GetLayoutEditBox(selected)
  if selectedBox then height = selectedBox:GetHeight() end
  local anchor = Core.db.profile.editBoxAnchor
  local extent = math.max(0, height + (anchor.position == "ABOVE" and anchor.yOfs or -anchor.yOfs))
  self.hubContent:ClearAllPoints()
  local contentLeft = self.IsConversationList and self:IsConversationList() and self:ConversationBodyLeft() or 0
  self.hubContent:SetPoint("TOPLEFT", self.hub, "TOPLEFT", contentLeft, -self:ContentTop() - (anchor.position == "ABOVE" and extent or 0))
  self.hubContent:SetPoint("BOTTOMRIGHT", self.hub, "BOTTOMRIGHT", 0, anchor.position == "BELOW" and extent or 0)
  self:LayoutConversationStrip(false)
  for _, frame in ipairs(self.hubOrder) do
    local window = ui:GetChatWindow(frame)
    if window then self:LayoutWindow(window) end
  end
  self:LayoutHubTabs()
end

function W:LayoutWindow(window)
  local frame = window.chatFrame
  if not self:IsGrouped(frame) then return false end
  local host = W:HubFor(frame)
  host:EnsureHub()
  local smf, editBox = window.slidingMessageFrame, Core:GetModule("UIManager"):GetLayoutEditBox(window)
  window.tab:SetParent(host.parking)
  if editBox then editBox:SetSunderParent(host.hubContent, true) end
  smf.whisperFullSurface = host.IsConversationList and host:IsConversationList() or nil
  smf.whisperDock = host.IsConversationList and host:IsConversationList() and host.hubChrome or host.tabScroll
  local width, height = host.hubContent:GetWidth(), host.hubContent:GetHeight()
  if smf:GetParent() ~= host.hubContent or smf.layoutWidth ~= width or smf.layoutHeight ~= height
    or smf.layoutEditBox ~= (editBox or false) then
    local index, offset = smf.state.scrollIndex or 1, smf.state.messageOffset or 0
    smf:SetLayout(host.hubContent, width, height, editBox or false, nil)
    if index > 1 or offset ~= 0 then smf:SetScrollPosition(index, offset) end
  end
  if window.detachedLayout then window.detachedLayout.container:Hide() end
  smf:SetShown(host.selected == frame)
  return true
end

function W:RefreshHubSelection()
  if not self.hub then return end
  for _, frame in ipairs(self.hubOrder) do
    local window = Core:GetModule("UIManager"):GetChatWindow(frame)
    if window then
      local selected = self.selected == frame
      frame:SetShown(selected)
      window.slidingMessageFrame:SetShown(selected)
      if not selected and window.editBox then window.editBox:Hide() end
      self:SetTabAppearance(self.hubTabs[frame], selected, W.records[frame].unread > 0)
      self.hubTabs[frame].label:SetTextColor(self:ConversationLabelColor(selected, frame))
    end
  end
  self:LayoutHub()
  self:EnsureHubTabVisible(self.selected)
  self:ApplyHubAppearance()
end

function W:EnsureHubTabVisible(frame)
  if not self.tabScroll then return end
  for index, entry in ipairs(self.hubOrder) do
    if entry == frame then
      local left, current, width = (index - 1) * self:TabStep(), self.tabScroll:GetHorizontalScroll(), self.tabScroll:GetWidth()
      if left < current then self.tabScroll:SetHorizontalScroll(left)
      elseif left + self:TabWidth() > current + width then self.tabScroll:SetHorizontalScroll(math.max(0, left + self:TabWidth() - width)) end
      self:RefreshConversationNavigation(false)
      return
    end
  end
end

function W:UpdateBadges()
  local total = 0
  for frame, r in pairs(self.records or {}) do
    if r.placement == "hub" then total = total + r.unread end
    local window = Core:GetModule("UIManager"):GetChatWindow(frame)
    if window and window.tab.SetUnreadCount then
      window.tab.sunderWhisperManaged = self:Settings().enabled
      window.tab.sunderWhisperBadge = self:Settings().enabled and self:Settings().unreadBadges
      window.tab:SetUnreadCount(r.unread)
    end
    local host = W:HubFor(frame)
    local tab = r.placement == "hub" and host.hubTabs and host.hubTabs[frame]
    if tab then
      local text = W:ConversationName(frame)
      if tab.lastLabel ~= text then tab.label:SetText(text); tab.lastLabel = text end
      local badge = (self:Settings().unreadBadges and r.unread > 0
        and (r.unread > 99 and "99+" or tostring(r.unread)) or "")
      if tab.lastBadge ~= badge then tab.unread:SetText(badge); tab.lastBadge = badge end
      tab.unread:SetShown(self:Settings().unreadBadges and r.unread > 0)
      tab.favoriteButton.icon:SetVertexColor(W:IsFavorite(frame) and 1 or 0.45, W:IsFavorite(frame) and 0.76 or 0.5, W:IsFavorite(frame) and 0.28 or 0.6)
      host:SetTabAppearance(tab, host.selected == frame, r.unread > 0)
      host:StyleConversationTab(tab)
    end
  end
  for _, host in pairs(W.workspaces or {}) do
    if host.hubTitle then
      if host.previewActive then host:UpdatePreviewBadges()
      else
        local unread = 0
        for _, frame in ipairs(host.hubOrder) do unread = unread + (W.records[frame] and W.records[frame].unread or 0) end
        local title = host:WorkspaceName()..(unread > 0 and ("  ·  "..unread) or "")
        if host.lastTitle ~= title then host.hubTitle:SetText(title); host.lastTitle = title end
      end
      local r = host.selected and W.records[host.selected]
      for _, key in ipairs({"Reply", "Pin", "Detach", "Favorite", "Search"}) do
        local b = host.hubActionButtons[key]
        b:SetEnabled(not host.previewActive and r ~= nil)
      end
      host.hubActionButtons.Favorite.icon:SetVertexColor(W:IsFavorite(host.selected) and 1 or 0.74,
        W:IsFavorite(host.selected) and 0.76 or 0.8, W:IsFavorite(host.selected) and 0.28 or 0.88)
      host.pinButton.plate:SetColorTexture(0.84, 0.66, 0.38, r and r.pinned and 0.25 or (host:UsesChatAppearance() and 0 or 0.035))
      if host.previewActive then host:UpdatePreviewActions() else host:RefreshConversationNavigation(false) end
    end
  end
end

function W:OpenMessages()
  if not W:Settings().enabled then return end
  self:EnsureHub()
  self:SetMinimized(false, true)
  self.windowManuallyClosed = false
  self.hubOpenedAt = GetTime()
  self:LayoutHub()
  self.hub:Show(); self.hub:SetAlpha(1)
  if self.selected and not self.previewActive then self:SelectConversation(self.selected, false) end
  self:SaveMessageWindowState()
end
