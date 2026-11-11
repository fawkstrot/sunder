local Core, Constants = unpack(select(2, ...))
local W = Core:GetModule("Whispers")
W.CONVERSATION_NAV_WIDTH = 148
local ICONS = "Interface\\AddOns\\Sunder\\Media\\Icons\\"

function W:EnsureWorkspaces()
  if self.workspaces then return end
  self.hostId = "messages"
  self.workspaces = {messages = self}
  Core.db.char.messageWorkspaces = Core.db.char.messageWorkspaces or {}
  Core.db.char.whisperFavorites = Core.db.char.whisperFavorites or {}
  Core.db.char.messageWindowStates = Core.db.char.messageWindowStates or {}
end

function W:HubSettings()
  if self.transientSettings then return self.transientSettings end
  if not self.hostId or self.hostId == "messages" then return W:Settings() end
  local saved = Core.db.char.messageWorkspaces[self.hostId]
  return saved
end

function W:GetWorkspace(id)
  W:EnsureWorkspaces()
  id = id == "favorites" and "messages" or id or "messages"
  if W.workspaces[id] then return W.workspaces[id] end
  local saved = Core.db.char.messageWorkspaces[id]
  if not saved then return W end
  local host = W.retiredWorkspaces and W.retiredWorkspaces[id]
  if host then
    W.retiredWorkspaces[id] = nil
    host.selected, host.lastTitle = nil, nil
    W.workspaces[id] = host
    if host.hub then
      host.hub:SetSize(saved.hubWidth, saved.hubHeight)
      host.hub:ClearAllPoints(); host.hub:SetPoint(saved.hubPoint, UIParent, saved.hubPoint, saved.hubX, saved.hubY)
    end
    host:LayoutHub()
    return host
  end
  host = setmetatable({hostId = id, records = W.records}, {__index = function (_, key)
    -- Window state must never fall through to the default window's fields.
    if type(W[key]) == "function" then return W[key] end
  end})
  host.SelectConversation = function (_, ...) return W:SelectConversation(...) end
  host.Place = function (_, ...) return W:Place(...) end
  W.workspaces[id] = host
  return host
end

function W:HubFor(frame)
  local r = W.records and W.records[frame]
  return W:GetWorkspace(r and r.workspace or "messages")
end

function W:WorkspaceName()
  local name = self:HubSettings().name
  if name and name:match("^Messages ?%d*$") then name = name:gsub("^Messages", "Whispers") end
  return name or "Whispers"
end

function W:CreateWorkspace(name)
  W:EnsureWorkspaces()
  local count = 0
  for _ in pairs(Core.db.char.messageWorkspaces) do count = count + 1 end
  if count >= 8 then Core:GetModule("Config"):Print("You can have up to eight additional whisper groups."); return end
  local index = 1
  while Core.db.char.messageWorkspaces["group"..index] do index = index + 1 end
  local id = "group"..index
  name = type(name) == "string" and name:match("^%s*(.-)%s*$") or ""
  if name == "" then name = "Whispers "..index end
  Core.db.char.messageWorkspaces[id] = {name = name:sub(1, 32), hubWidth = 540, hubHeight = 340,
    hubPoint = "CENTER", hubX = 40 * index, hubY = 60 - 30 * index, keepMessagesOpen = true}
  local host = W:GetWorkspace(id)
  host:OpenMessages()
  return host
end

function W:RemoveWorkspace(id)
  if not id or id == "messages" or id == "favorites" then return end
  local host = W:GetWorkspace(id)
  if host == W then return end
  local states = Core.db.char.messageWindowStates
  local frames = {}
  for frame, r in pairs(W.records or {}) do if r.workspace == id and r.placement == "hub" then frames[#frames + 1] = frame end end
  -- Keep membership intact until protected chat frames can be moved safely.
  if InCombatLockdown() then Core:GetModule("Config"):Print("Finish combat before removing a whisper group."); return end
  for _, frame in ipairs(frames) do W:MoveToWorkspace(frame, "messages") end
  for _, r in pairs(W.records or {}) do if r.workspace == id then r.workspace = "messages" end end
  for _, saved in pairs(Core.db.char.whisperLayouts or {}) do if saved.workspace == id then saved.workspace = "messages" end end
  if host.hub then host.hub:Hide() end
  -- Reuse retired window shells instead of leaking new frames on repeated create/remove.
  W.retiredWorkspaces = W.retiredWorkspaces or {}
  W.retiredWorkspaces[id] = host
  W.workspaces[id], Core.db.char.messageWorkspaces[id], W.managedWorkspace = nil, nil, "messages"
  if states then states[id] = nil end
  if Core.db.char.messageTabOrders then Core.db.char.messageTabOrders[id] = nil end
  W:PreviewSettingsChanged()
end

function W:MoveToWorkspace(frame, id)
  if not frame or not W:Record(frame) then return end
  id = id == "favorites" and "messages" or id or "messages"
  if InCombatLockdown() and frame:IsProtected() then
    W.deferredPlacements = W.deferredPlacements or {}
    W.deferredPlacements[frame] = {destination = "hub", selectIt = true, workspace = id, record = W.records[frame]}
    return
  end
  local r = W.records[frame]
  local old = W:HubFor(frame)
  if r.placement == "hub" and (r.workspace or "messages") ~= id then old:RemoveHubTab(frame) end
  r.workspace = id
  W:Place(frame, "hub", true)
end

function W:IsFavorite(frame)
  local r = W.records and W.records[frame]
  return r and (r.favorite or r.key and Core.db.char.whisperFavorites and Core.db.char.whisperFavorites[r.key]) or false
end

function W:ToggleFavorite(frame)
  W:EnsureWorkspaces()
  local r = W.records and W.records[frame]
  if not r then return end
  local favorite = not W:IsFavorite(frame)
  r.favorite = favorite
  if r.key then Core.db.char.whisperFavorites[r.key] = favorite and frame.chatTarget or nil end
  W:UpdateBadges()
end

function W:StyleWindowIcon(button)
  if not button then return end
  button.iconOpacity = self:UsesChatAppearance() and (Core.db.profile.chatTitleIconOpacity or 0.5) or 1
  local disabled = button.IsEnabled and not button:IsEnabled() or button.disabled
  if button.icon then button.icon:SetAlpha(disabled and 0.25 or button.iconOpacity) end
  if button.plate then button.plate:SetColorTexture(1, 1, 1, self:UsesChatAppearance() and 0 or 0.035) end
  local r, g, b = self:InterfaceAccent()
  local highlight = button:GetHighlightTexture()
  if highlight then highlight:SetVertexColor(r, g, b, self:UsesChatAppearance() and 0.06 or 0.12) end
end

function W:IconButton(parent, key, tooltip, action)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(26, 26)
  local plate = b:CreateTexture(nil, "BACKGROUND")
  plate:SetAllPoints(); plate:SetColorTexture(1, 1, 1, 0.035)
  local icon = b:CreateTexture(nil, "ARTWORK")
  icon:SetSize(19, 19); icon:SetPoint("CENTER")
  icon:SetTexture(ICONS..key..".tga"); icon:SetVertexColor(0.74, 0.8, 0.88)
  b.icon, b.plate = icon, plate
  b:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
  b:GetHighlightTexture():SetVertexColor(0.5, 0.7, 1, 0.12)
  b:SetScript("OnEnter", function ()
    icon:SetVertexColor(1, 1, 1); icon:SetAlpha(1)
    GameTooltip:SetOwner(b, "ANCHOR_TOP")
    GameTooltip:AddLine(tooltip, 1, 1, 1); GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function () icon:SetVertexColor(0.74, 0.8, 0.88); icon:SetAlpha(b.iconOpacity or 1); GameTooltip:Hide() end)
  b:SetScript("OnMouseDown", function () icon:SetPoint("CENTER", 0, -1) end)
  b:SetScript("OnMouseUp", function () icon:SetPoint("CENTER", 0, 0) end)
  b:SetScript("OnDisable", function () icon:SetAlpha(0.25) end)
  b:SetScript("OnEnable", function () icon:SetAlpha(b.iconOpacity or 1) end)
  b:SetScript("OnClick", action)
  self:StyleWindowIcon(b)
  return b
end

function W:InterfaceAccent()
  local color = Core.GetThemeColor and Core:GetThemeColor("tabHighlightTextColor")
  if color then return color.r, color.g, color.b end
  local r, g, b = Core:GetModule("Ellesmere"):GetAccentColor()
  return r or 0.84, g or 0.66, b or 0.38
end

function W:RememberWhisperClass(sender,guid)
  if not GetPlayerInfoByGUID or type(sender)~="string" or type(guid)~="string" then return end
  if _G.canaccessvalue and (not _G.canaccessvalue(sender) or not _G.canaccessvalue(guid)) then return end
  local ok,_,class=pcall(GetPlayerInfoByGUID,guid)
  if not ok or type(class)~="string" or _G.canaccessvalue and not _G.canaccessvalue(class) then return end
  W.whisperClasses=W.whisperClasses or {};W.whisperClasses[string.lower(sender)]=class
end
function W:ConversationLabelColor(selected,person)
  local record=person and W.records[person]
  local token=type(person)=="table" and person.classToken
  if record and W.whisperClasses then token=W.whisperClasses[record.key] end
  local classColor=token and ((_G.CUSTOM_CLASS_COLORS or _G.RAID_CLASS_COLORS or {})[token])
  if classColor then return classColor.r,classColor.g,classColor.b,1 end
  local color = self:UsesChatAppearance() and Core.GetThemeColor and Core:GetThemeColor(selected and "tabHighlightTextColor" or "tabTextColor")
  if color then return color.r, color.g, color.b, color.a or 1 end
  local r, g, b = self:InterfaceAccent()
  return selected and r or 0.72, selected and g or 0.74, selected and b or 0.78, 1
end

function W:SetTabAppearance(tab, selected, unread)
  local r, g, b = self:InterfaceAccent()
  local stamp = tostring(selected)..tostring(unread)..r..g..b..tostring(self:UsesChatAppearance())..tostring(Core.db.profile.chatSelectionIndicator)..tostring(Core.db.profile.chatHoverWash)
  if tab.appearanceStamp == stamp then return end
  tab.appearanceStamp = stamp
  local highlight = tab:GetHighlightTexture()
  if highlight then highlight:SetVertexColor(r, g, b, self:UsesChatAppearance() and (Core.db.profile.chatHoverWash and 0.045 or 0) or 0.12) end
  if not tab.selection then
    tab.selection = tab:CreateTexture(nil, "BACKGROUND")
    tab.selection:SetAllPoints()
    tab.underline = tab:CreateTexture(nil, "OVERLAY")
    tab.underline:SetPoint("BOTTOMLEFT", 4, 0); tab.underline:SetPoint("BOTTOMRIGHT", -4, 0)
    tab.underline:SetHeight(2)
  end
  tab.selection:SetColorTexture(r, g, b, not self:UsesChatAppearance() and (selected and 0.12 or unread and 0.035 or 0) or 0)
  tab.underline:SetHeight(self:UsesChatAppearance() and 1 or 2)
  tab.underline:SetColorTexture(r, g, b, selected and (not self:UsesChatAppearance() or Core.db.profile.chatSelectionIndicator ~= false) and 0.65 or 0)
  -- Own this lightweight tab chrome; optional skins supply fonts and accent only.
end

function W:WorkspaceMenu(owner, frame)
  if self.previewActive then return self:PreviewConversationMenu(owner, self.previewConversations[self.previewSelected or 1]) end
  if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
  W:EnsureWorkspaces()
  MenuUtil.CreateContextMenu(owner, function (_, menu)
    menu:CreateButton("Open Whispers", function () W:OpenMessages() end)
    menu:CreateButton("Rename this window", function () self:PromptWorkspaceName() end)
    menu:CreateButton(self.minimized and "Restore window" or "Minimize window", function () self.hubOpenedAt=GetTime();self.lastUserInteraction=GetTime();self:SetMinimized(not self.minimized) end)
    menu:CreateButton("New whisper group", function ()
      local host = W:CreateWorkspace()
      if host and frame then W:MoveToWorkspace(frame, host.hostId) end
    end)
    for id, saved in pairs(Core.db.char.messageWorkspaces) do
      if id ~= "favorites" then
      local destination = id
      menu:CreateButton(frame and ("Move to "..saved.name) or ("Open "..saved.name), function ()
        if frame then W:MoveToWorkspace(frame, destination) else W:GetWorkspace(destination):OpenMessages() end
      end)
      end
    end
    if frame then menu:CreateButton("Move to Whispers", function () W:MoveToWorkspace(frame, "messages") end) end
    self:AddConversationSortMenu(menu)
    menu:CreateDivider()
    menu:CreateButton("Message settings", function () Core:GetModule("Config"):OpenSettings("whispers") end)
  end)
end


-- Window manipulation is distinct from layout editing: the grip always moves;
-- the blue edit overlay alone permits resizing.
function W:CreateWindowControls(chrome)
  local grip = CreateFrame("Button", nil, chrome)
  grip:SetPoint("TOPLEFT", 8, -6); grip:SetSize(18, 28)
  for row = 0, 2 do for col = 0, 1 do
    local dot = grip:CreateTexture(nil, "OVERLAY")
    dot:SetSize(2, 2); dot:SetPoint("CENTER", col * 5 - 2.5, 4 - row * 4)
    dot:SetColorTexture(0.78, 0.68, 0.48, 0.85)
  end end
  grip:RegisterForDrag("LeftButton")
  grip:SetScript("OnMouseDown", function (_, mouse) if mouse == "LeftButton" then self:BeginHubMove(true) end end)
  grip:SetScript("OnDragStart", function () self:BeginHubMove(true) end)
  grip:SetScript("OnMouseUp", function () self:UpdateHubMove(); self:StopHubMove() end)
  grip:SetScript("OnDragStop", function () self:UpdateHubMove(); self:StopHubMove() end)
  grip:SetScript("OnEnter", function ()
    GameTooltip:SetOwner(grip, "ANCHOR_TOP"); GameTooltip:AddLine("Drag to move this window", 1, 1, 1)
    GameTooltip:AddLine("Resize remains available in unlock mode.", 0.7, 0.75, 0.8); GameTooltip:Show()
  end)
  grip:SetScript("OnLeave", function () GameTooltip:Hide() end)
  self.hubGrip = grip
  local minimize = self:IconButton(chrome, "minimize", "Minimize / restore window", function () self:SetMinimized(not self.minimized) end)
  minimize:SetPoint("TOPRIGHT", self.hub, "TOPRIGHT", -240, -7)
  self.minimizeButton = minimize
  self.hubTitle:ClearAllPoints()
  self.hubTitle:SetPoint("TOPLEFT", chrome, "TOPLEFT", 64, -6)
  self.hubTitle:SetPoint("TOPRIGHT", chrome, "TOPRIGHT", -272, -6)
  local rename = CreateFrame("Button", nil, chrome)
  rename:SetPoint("TOPLEFT", self.hubTitle); rename:SetPoint("BOTTOMRIGHT", self.hubTitle)
  rename:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  rename:SetScript("OnClick", function (_, mouse) self.hubOpenedAt=GetTime();self.lastUserInteraction=GetTime();if mouse == "LeftButton" and self.minimized then self:SetMinimized(false) elseif mouse == "RightButton" then self:WorkspaceMenu(rename) end end)
  rename:SetScript("OnDoubleClick", function (_, mouse) if not mouse or mouse == "LeftButton" then self:PromptWorkspaceName() end end)
  rename:SetScript("OnEnter", function ()
    GameTooltip:SetOwner(rename, "ANCHOR_TOP"); GameTooltip:AddLine(self:WorkspaceName(), 1, 1, 1)
    if self.previewActive then GameTooltip:AddLine("Local sample conversations. No whispers are sent.", 0.7, 0.75, 0.8) end
    GameTooltip:AddLine("Double-click to rename  •  Right-click for window actions", 0.7, 0.75, 0.8); GameTooltip:Show()
  end)
  rename:SetScript("OnLeave", function () GameTooltip:Hide() end)
end

function W:RenameWorkspace(value)
  value = type(value) == "string" and value:match("^%s*(.-)%s*$"):sub(1, 32) or ""
  if value == "" then return end
  self:HubSettings().name = value
  self.lastTitle = nil
  W:UpdateBadges()
end

function W:PromptWorkspaceName()
  if not StaticPopupDialogs.SUNDER_GROUP_NAME then
    StaticPopupDialogs.SUNDER_GROUP_NAME = {
      text = "Name this message window", button1 = ACCEPT, button2 = CANCEL,
      hasEditBox = true, maxLetters = 32, timeout = 0, whileDead = true, hideOnEscape = true,
      OnShow = function (dialog, data) local edit = dialog.GetEditBox and dialog:GetEditBox() or dialog.editBox; edit:SetText(data:WorkspaceName()); edit:HighlightText(); edit:SetFocus() end,
      OnAccept = function (dialog, data) local edit = dialog.GetEditBox and dialog:GetEditBox() or dialog.editBox; data:RenameWorkspace(edit:GetText()) end,
      EditBoxOnEnterPressed = function (edit) local dialog = edit:GetParent(); dialog.data:RenameWorkspace(edit:GetText()); dialog:Hide() end,
    }
  end
  StaticPopup_Show("SUNDER_GROUP_NAME", nil, nil, self)
end

-- The compact header remains interactive while its body is collapsed.
function W:PresentWindowBody(shown, alpha)
  if self.hubBackground then self.hubBackground:SetAlpha(alpha or 1) end
  for _, frame in pairs({self.hubContent, self.previewBody}) do
    frame:SetAlpha(alpha or 1)
    frame:SetShown(shown and (frame == self.hubContent and not self.previewActive or frame == self.previewBody and self.previewActive))
  end

end

function W:PresentCollapsedHeader()
  local inline = self:SingleRowHeader()
  self.tabScroll:SetShown(not self.previewActive and (not self.minimized or inline))
  if self.previewFrame then self.previewFrame:SetShown(not not self.previewActive) end
  if self.previewTabScroll then self.previewTabScroll:SetShown(not self.minimized or inline) end
  self:LayoutConversationStrip(not not self.previewActive)
  local nav = self.previewActive and self.previewNavigation or self.conversationNavigation
  if nav then nav:SetShown(true) end
  if not inline then
    self.hubTitle:SetPoint("RIGHT", self.hubChrome, "RIGHT", -(self.headerActionWidth or 220) - (self.minimized and self:NavigationWidth() or 0), 0)
  end
  self:RefreshConversationNavigation(not not self.previewActive)
end

function W:UpdateTransitionBounds()
  self:LayoutConversationStrip(false)
  self:LayoutConversationStrip(true)
  if self.PositionConversationBody then self:PositionConversationBody() end
  if self.RefreshWorkspaceClipRects then self:RefreshWorkspaceClipRects() end
end

function W:SetMinimized(minimized, instant)
  if not self.hub then return end
  minimized = not not minimized
  if self.minimized == minimized and not self.collapseAnimation then return end
  if minimized then self:SaveHubGeometry() end
  self:StopHubMove()
  self.hubResize:FinishResize()
  self:PresentWindowBody(false,1)
  self.minimized = minimized
  -- The header must never enter a transient root clipping rectangle.
  self.hub:SetClipsChildren(false)
  self:PresentCollapsedHeader()
  local scale = UIParent:GetEffectiveScale() / self.hub:GetEffectiveScale()
  local left = self.hub:GetLeft()
  local edge = self:HubSettings().minimizeEdge or "TOP"
  local anchor = edge == "BOTTOM" and "BOTTOMLEFT" or "TOPLEFT"
  local y = edge == "BOTTOM" and self.hub:GetBottom() - UIParent:GetBottom() * scale
    or self.hub:GetTop() - UIParent:GetTop() * scale
  self.hub:ClearAllPoints()
  self.hub:SetPoint(anchor, UIParent, anchor, left - UIParent:GetLeft() * scale, y)
  local target = minimized and self:HeaderHeight() or self:HubSettings().hubHeight
  local from = self.hub:GetHeight()
  -- Animate only while transitioning; no idle per-frame handler or new frames.
  local elapsed = 0
  local function finish()
    self.hub:SetScript("OnUpdate", nil)
    self.hub:SetHeight(target)
    self.hub:SetClipsChildren(false)
    self.collapseAnimation, self.finishCollapse = nil, nil
    self:UpdateTransitionBounds()
    self:PresentWindowBody(not minimized, 1)
    self:PresentCollapsedHeader()
    self.minimizeButton.icon:SetTexture(ICONS..(minimized and "restore" or "minimize")..".tga")
    if not minimized then
      self:LayoutHub()
      if self.previewActive then self:EnsurePreviewTabVisible(self.previewSelected) else self:EnsureHubTabVisible(self.selected) end
    end
    self:SaveMessageWindowState()
  end
  self.collapseAnimation = true
  self.finishCollapse = finish
  if instant then finish(); return end
  self.hub:SetScript("OnUpdate", function (_, delta)
    elapsed = elapsed + delta
    local t = math.min(1, elapsed / 0.24)
    local eased = t * t * (3 - 2 * t)
    local opacity = minimized and math.max(0, 1 - t * 3) or math.max(0, (t - 0.45) / 0.55)
    opacity = opacity * opacity * (3 - 2 * opacity)
    self.hub:SetHeight(math.max(1,from + (target - from) * eased))
    self:UpdateTransitionBounds()
    self:PresentWindowBody(opacity > 0, opacity)
    if t == 1 then finish() end
  end)
end

function W:TabDropTarget(x, y)
  local best, level
  for _, host in pairs(W.workspaces or {}) do
    if not host.transientSettings and host.hub and host.hub:IsShown() then
      local scale = host.hub:GetEffectiveScale()
      local left, top = host.hub:GetLeft() * scale, host.hub:GetTop() * scale
      local bottom = host.minimized and top - host:HeaderHeight() * scale or top - (host:HeaderHeight() + host:ConversationTabHeight() + 8) * scale
      local z = host.hub:GetFrameLevel()
      if x >= left and x <= left + host.hub:GetWidth() * scale and y <= top and y >= bottom and (not level or z >= level) then best, level = host, z end
    end
  end
  return best
end

-- Native order is saved by stable character identity; samples keep session-only order.
function W:SaveConversationOrder()
  if self.transientSettings then return end
  Core.db.char.messageTabOrders = Core.db.char.messageTabOrders or {}
  local out, seen, known = {}, {}, {}
  for _, r in pairs(W.records or {}) do if r.key then known[r.key] = r.workspace or "messages" end end
  for _, frame in ipairs(self.hubOrder or {}) do
    local r = W.records[frame]
    if r and r.key then out[#out + 1] = r.key; seen[r.key] = true end
  end
  for _, key in ipairs(Core.db.char.messageTabOrders[self.hostId] or {}) do
    if #out < 100 and not seen[key] and (not known[key] or known[key] == self.hostId) then out[#out + 1] = key; seen[key] = true end
  end
  Core.db.char.messageTabOrders[self.hostId] = out
end

function W:RestoreConversationOrder()
  local saved = Core.db.char.messageTabOrders and Core.db.char.messageTabOrders[self.hostId]
  if not saved then return end
  local rank, before = {}, {}
  for i, key in ipairs(saved) do rank[key] = i end
  for i, frame in ipairs(self.hubOrder) do before[frame] = i end
  table.sort(self.hubOrder, function (a, b)
    local ar, br = W.records[a], W.records[b]
    local x, y = ar and rank[ar.key] or 10000, br and rank[br.key] or 10000
    return x == y and before[a] < before[b] or x < y
  end)
end

function W:KeepPinnedFirst(preview)
  local list = preview and self.previewConversations or self.hubOrder
  if not list then return end
  local selected = preview and list[self.previewSelected or 1]
  local ordered = {}
  for _, pinned in ipairs({true, false}) do
    for _, item in ipairs(list) do
      local r = preview and item or W.records[item]
      if (r and not not r.pinned or false) == pinned then ordered[#ordered + 1] = item end
    end
  end
  for i, item in ipairs(ordered) do list[i] = item; if preview and item == selected then self.previewSelected = i end end
end

function W:ReorderConversation(value, gap, preview)
  local list = preview and self.previewConversations or self.hubOrder
  if not list then return end
  local selected = preview and list[self.previewSelected or 1] or self.selected
  local old
  for i, item in ipairs(list) do if item == value then old = i; break end end
  if not old then return end
  gap = math.max(1, math.min(#list + 1, gap or #list + 1))
  table.remove(list, old)
  if gap > old then gap = gap - 1 end
  local pinnedCount = 0
  for _, item in ipairs(list) do local r = preview and item or W.records[item]; if r and r.pinned then pinnedCount = pinnedCount + 1 end end
  local record = preview and value or W.records[value]
  gap = record and record.pinned and math.min(gap, pinnedCount + 1) or math.max(gap, pinnedCount + 1)
  table.insert(list, math.max(1, math.min(#list + 1, gap)), value)
  self:KeepPinnedFirst(preview)
  if preview then
    for i, item in ipairs(list) do if item == selected then self.previewSelected = i end end
    self:RenderPreview()
  else self:SaveConversationOrder(); self:LayoutHubTabs(); self:EnsureHubTabVisible(value) end
end

function W:SortConversationTabs(mode)
  local preview = self.previewActive
  local list = preview and self.previewConversations or self.hubOrder
  if not list then return end
  local selected = preview and list[self.previewSelected or 1] or self.selected
  local before = {}; for i, item in ipairs(list) do before[item] = i end
  local function record(item) return preview and item or W.records[item] or {} end
  local function name(item)
    local r = record(item)
    local value = preview and r.name or r.key
    if not value and not preview then
      local native = _G[item:GetName().."Tab"]
      local text = native and native.Text and native.Text:GetText()
      if (not _G.canaccessvalue or _G.canaccessvalue(text)) and type(text) == "string" then
        value = text:gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
      end
    end
    return (value or item:GetName()):lower()
  end
  table.sort(list, function (a, b)
    local ar, br = record(a), record(b)
    if not not ar.pinned ~= not not br.pinned then return not not ar.pinned end
    if mode == "unread" and (ar.unread or 0) ~= (br.unread or 0) then return (ar.unread or 0) > (br.unread or 0) end
    if mode == "recent" then
      local x = preview and ar.lines[#ar.lines] and ar.lines[#ar.lines].time or ar.lastActivity or 0
      local y = preview and br.lines[#br.lines] and br.lines[#br.lines].time or br.lastActivity or 0
      if x ~= y then return x > y end
    end
    if mode == "pinned" and not not ar.pinned ~= not not br.pinned then return not not ar.pinned end
    if name(a) ~= name(b) then return name(a) < name(b) end
    return before[a] < before[b]
  end)
  if preview then
    for i, item in ipairs(list) do if item == selected then self.previewSelected = i end end
    self:RenderPreview(); self:EnsurePreviewTabVisible(self.previewSelected)
  else self:SaveConversationOrder(); self:LayoutHubTabs(); self:EnsureHubTabVisible(self.selected) end
end

function W:AddConversationSortMenu(menu)
  menu:CreateDivider()
  for _, info in ipairs({{"name", "Sort by name"}, {"unread", "Unread first"}, {"recent", "Recent messages first"}, {"pinned", "Pinned first"}}) do
    local mode = info[1]
    menu:CreateButton(info[2], function () self:SortConversationTabs(mode) end)
  end
end

function W:TabInsertionIndex(preview, x)
  local scroll = preview and (self.previewTabScroll or self.tabScroll) or self.tabScroll
  local list = preview and self.previewConversations or self.hubOrder
  if not scroll then return 1 end
  local localX = x / scroll:GetEffectiveScale() - scroll:GetLeft() + scroll:GetHorizontalScroll()
  return math.max(1, math.min(#(list or {}) + 1, math.floor(localX / self:TabStep() + 0.5) + 1))
end

function W:ShowTabInsertion(preview, index)
  local scroll = preview and (self.previewTabScroll or self.tabScroll) or self.tabScroll
  if not scroll or self.minimized then return end
  if not self.tabInsertion then self.tabInsertion = self.hub:CreateTexture(nil, "OVERLAY"); self.tabInsertion:SetWidth(2) end
  local x = math.max(0, math.min(scroll:GetWidth() - 2, (index - 1) * self:TabStep() - scroll:GetHorizontalScroll()))
  self.tabInsertion:ClearAllPoints(); self.tabInsertion:SetPoint("TOPLEFT", scroll, "TOPLEFT", x, 0)
  self.tabInsertion:SetHeight(self:ConversationTabHeight())
  local r, g, b = self:InterfaceAccent(); self.tabInsertion:SetColorTexture(r, g, b, 1); self.tabInsertion:Show()
end

function W:EnableTabTransfer(tab, frame, preview)
  tab:RegisterForDrag("LeftButton")
  tab:SetScript("OnHide", function () if tab.transferCleanup then tab.transferCleanup(); tab.transferCleanup = nil end end)
  local function targetAt(x, y)
    local scale = self.hub:GetEffectiveScale()
    local top, left = self.hub:GetTop() * scale, self.hub:GetLeft() * scale
    local inside = x >= left and x <= left + self.hub:GetWidth() * scale and y <= top and y >= top - (self:HeaderHeight() + self:ConversationTabHeight() + 8) * scale
    if self.IsConversationList and self:IsConversationList() then inside = self:IsConversationDropArea(x, y) end
    local target = W:TabDropTarget(x, y)
    if inside and (not target or target == self) then target = self end
    return target
  end
  tab:SetScript("OnDragStart", function ()
    if not preview and (self.previewActive or not W.records[frame]) then return end
    GameTooltip:Hide(); tab.suppressClick = true; tab:SetAlpha(0.45)
    local prior
    tab.transferCleanup = function ()
      tab:SetScript("OnUpdate", nil); tab:SetAlpha(1)
      if prior and prior.tabInsertion then prior.tabInsertion:Hide() end
      self.tabDragging = nil
    end
    self.tabDragging = tab
    tab:SetScript("OnUpdate", function (_, elapsed)
      local x, y = GetCursorPosition()
      local target = targetAt(x, y)
      if target ~= prior and prior and prior.tabInsertion then prior.tabInsertion:Hide() end
      if target then
        local scroll = preview and (target.previewTabScroll or target.tabScroll) or target.tabScroll
        if scroll and not target.minimized then
          if target.IsConversationList and target:IsConversationList() then target:ScrollListEdge(preview ~= nil, x, y, elapsed) else
          local localX = x / scroll:GetEffectiveScale() - scroll:GetLeft()
          local delta = localX < 22 and -1 or localX > scroll:GetWidth() - 22 and 1 or 0
          if delta ~= 0 and (not preview or target.previewTabScroll) then
            local child = preview and target.previewTabChild or target.tabChild
            scroll:SetHorizontalScroll(math.max(0, math.min(math.max(0, child:GetWidth() - scroll:GetWidth()), scroll:GetHorizontalScroll() + delta * 260 * math.min(0.05, elapsed or 0.016))))
          end
          end
          target:ShowTabInsertion(preview ~= nil, target:TabInsertionIndex(preview ~= nil, x, y))
        end
      end
      prior = target
    end)
    tab:SetScript("OnDragStop", function ()
      if not tab.transferCleanup then return end
      local x, y = GetCursorPosition(); local target = targetAt(x, y)
      local index = target and target:TabInsertionIndex(preview ~= nil, x, y)
      tab.transferCleanup(); tab.transferCleanup = nil
      if target then
        target:SetMinimized(false, true)
        if target ~= self then
          if preview then W:MovePreviewConversation(preview, target) else W:MoveToWorkspace(frame, target.hostId); self:SaveConversationOrder() end
        end
        target:ReorderConversation(preview or frame, index, preview ~= nil)
      end
      C_Timer.After(0, function () tab.suppressClick = nil end)
    end)
  end)
end


function W:ApplyHubAppearance()
  if not self.hub then return end
  local cfg, profile, unified = W:Settings(), Core.db.profile, self:UsesChatAppearance()
  local color = unified and profile.chatBackgroundColor or cfg.hubBackgroundColor
  color = color or {r = 0.035, g = 0.04, b = 0.05, a = 0.5}
  local headerColor = unified and profile.headerBackgroundColor or color
  headerColor = headerColor or color
  local opacity = unified and (color.a or 0.5) or (cfg.hubBackgroundOpacity == nil and 0.96 or cfg.hubBackgroundOpacity)
  local header = unified and (headerColor.a or 0.5) or (cfg.hubHeaderOpacity == nil and 0.96 or cfg.hubHeaderOpacity)
  local border = unified and 0 or (cfg.hubBorderOpacity == nil and 0.35 or cfg.hubBorderOpacity)
  local r, g, b = self:InterfaceAccent()
  local nativeBody = unified and not self.previewActive and self.selected and self.hubTabs and self.hubTabs[self.selected]
  -- Native conversations already paint chat's scrolling background. Never tint it twice.
  local bodyAlpha = self.minimized and 0 or nativeBody and 0 or opacity
  local bodyTop = self:HeaderHeight() + (unified and (self:SingleRowHeader() and 0 or self:ConversationTabHeight()) + self:HeaderGap() or 0)
  self.hubBackground:ClearAllPoints()
  self.hubBackground:SetPoint("TOPLEFT", self.hub, "TOPLEFT", 0, -bodyTop)
  self.hubBackground:SetPoint("BOTTOMRIGHT", self.hub, "BOTTOMRIGHT")
  local paint = Core.Components.PaintGradientTexture or function (texture, c, alpha) texture:SetColorTexture(c.r, c.g, c.b, alpha) end
  local fade = unified or cfg.hubUseChatFade
  paint(self.hubBackground, color, bodyAlpha, fade)
  paint(self.hubHeaderFill, headerColor, header, fade)
  if not self.tabStripBackground then self.tabStripBackground = self.hub:CreateTexture(nil, "BACKGROUND") end
  self.tabStripBackground:ClearAllPoints()
  local strip = self.previewActive and self.previewTabScroll or self.tabScroll
  if strip then
    self.tabStripBackground:SetPoint("TOPLEFT", strip, "TOPLEFT")
    self.tabStripBackground:SetPoint("TOPRIGHT", self.previewActive and self.previewFrame or self.hubContent, "TOPRIGHT")
  else
    self.tabStripBackground:SetPoint("TOPLEFT", self.hub, "TOPLEFT", 0, -self:HeaderHeight())
    self.tabStripBackground:SetPoint("TOPRIGHT", self.hub, "TOPRIGHT", 0, -self:HeaderHeight())
  end
  self.tabStripBackground:SetHeight(self:ConversationTabHeight())
  paint(self.tabStripBackground, headerColor, unified and not self:SingleRowHeader() and not self.minimized and header or 0, fade)
  self.hubRule:ClearAllPoints()
  self.hubRule:SetPoint("BOTTOMLEFT", unified and not self:SingleRowHeader() and self.tabStripBackground or self.hubChrome, "BOTTOMLEFT")
  self.hubRule:SetPoint("BOTTOMRIGHT", unified and not self:SingleRowHeader() and self.tabStripBackground or self.hubChrome, "BOTTOMRIGHT")
  local separator = unified and Core.GetThemeColor and Core:GetThemeColor("tabMessageSeparatorColor")
  paint(self.hubRule, separator or {r=r,g=g,b=b}, self.minimized and 0 or separator and (separator.a or 0) or border, fade)
  if self.hubMark then
    self.hubMark:SetVertexColor(r, g, b)
    self.hubMark:SetAlpha(unified and (profile.chatTitleIconOpacity or 0.5) or 1)
  end
  if self.hubTitle then self.hubTitle:SetTextColor(r, g, b) end
  if self.hubEmptyIcon then self.hubEmptyIcon:SetVertexColor(r, g, b) end
  for _, line in ipairs(self.hubBorders or {}) do line:SetColorTexture(r, g, b, border) end
  if self.previewBackground then self.previewBackground:SetColorTexture(color.r, color.g, color.b, 0) end
end


-- Navigation lives outside the clipped scroll child so it is always reachable.
function W:CreateConversationNavigation(scroll, child, preview)
  local nav = CreateFrame("Frame", nil, scroll:GetParent())
  nav:SetSize(W.CONVERSATION_NAV_WIDTH, self:ConversationTabHeight()); nav:SetPoint("TOPLEFT", scroll, "TOPRIGHT")
  nav:SetFrameLevel(scroll:GetFrameLevel() + 4)
  nav.scroll, nav.child, nav.preview = scroll, child, preview
  if preview then self.previewNavigation = nav else self.conversationNavigation = nav end
  nav.left = self:IconButton(nav, "left", "Previous conversation tabs", function () self:PageConversationTabs(preview, -1) end)
  nav.left:SetSize(28, 22); nav.left:SetPoint("LEFT", 8, 0); nav.left.icon:SetSize(16, 16)
  nav.right = self:IconButton(nav, "right", "Next conversation tabs", function () self:PageConversationTabs(preview, 1) end)
  nav.right:SetSize(28, 22); nav.right:SetPoint("LEFT", 42, 0); nav.right.icon:SetSize(16, 16)
  local all = CreateFrame("Button", nil, nav)
  all:SetSize(64, 22); all:SetPoint("LEFT", 76, 0)
  all:SetNormalFontObject("SunderChatDockFont"); all:SetText("0")
  local label = all:GetFontString()
  label:ClearAllPoints(); label:SetPoint("LEFT", 30, 0); label:SetPoint("RIGHT", -8, 0); label:SetJustifyH("CENTER")
  local plate = all:CreateTexture(nil, "BACKGROUND")
  plate:SetAllPoints(); plate:SetColorTexture(1, 1, 1, 0.035)
  local icon = all:CreateTexture(nil, "ARTWORK")
  icon:SetSize(16, 16); icon:SetPoint("LEFT", 8, 0); icon:SetTexture(ICONS.."inbox.tga")
  all.icon, all.plate = icon, plate
  local divider = nav:CreateTexture(nil, "BORDER")
  divider:SetSize(1, 18); divider:SetPoint("LEFT", 0, 0); divider:SetColorTexture(1, 1, 1, 0.1)
  nav.divider = divider
  all:SetHighlightTexture("Interface\\Buttons\\WHITE8X8"); all:GetHighlightTexture():SetVertexColor(0.5, 0.7, 1, 0.12)
  for _, control in ipairs({nav.left, nav.right, nav.all}) do
    control:SetHeight(math.min(22, self:ConversationTabHeight())); self:StyleWindowIcon(control)
    local iconSize = self:UsesChatAppearance() and math.min(14, self:ToolbarIconSize()) or 16
    control.icon:SetSize(iconSize, iconSize)
  end
  divider:SetShown(not self:UsesChatAppearance())
  all:SetScript("OnClick", function () self:ShowConversationPicker(preview, all) end)
  all:SetScript("OnEnter", function ()
    GameTooltip:SetOwner(all, "ANCHOR_TOP")
    GameTooltip:AddLine("All conversations ("..(nav.total or 0)..")", 1, 1, 1)
    GameTooltip:AddLine((nav.unreadTotal or 0).." unread messages", 1, 0.75, 0.25)
    GameTooltip:AddLine("Click to search and jump to any person", 0.7, 0.75, 0.8)
    if (nav.hiddenUnread or 0) > 0 then GameTooltip:AddLine(nav.hiddenUnread.." unread conversations outside this view", 1, 0.75, 0.25) end
    GameTooltip:Show()
  end)
  all:SetScript("OnLeave", function () GameTooltip:Hide() end)
  nav.all = all
  scroll:HookScript("OnHide", function () nav:Hide(); if self.conversationPicker then self.conversationPicker:Hide() end end)
  scroll:HookScript("OnShow", function () nav:Show() end)
  scroll:HookScript("OnSizeChanged", function () self:RefreshConversationNavigation(preview) end)
  self:LayoutConversationStrip(preview)
  nav:SetShown(scroll:IsShown())
end

function W:ConversationEntries(preview)
  local out = {}
  if preview then
    for index, c in ipairs(self.previewConversations or {}) do
      out[#out + 1] = {name = c.name, unread = c.unread or 0, favorite = c.favorite, pinned = c.pinned, index = index, value = c}
    end
  else
    for index, frame in ipairs(self.hubOrder or {}) do
      local native = _G[frame:GetName().."Tab"]
      local record = W.records[frame]
      if native and record then out[#out + 1] = {name = W:ConversationName(frame), unread = record.unread or 0,
        favorite = W:IsFavorite(frame), pinned = record.pinned, index = index, value = frame} end
    end
  end
  return out
end

function W:RefreshConversationNavigation(preview)
  local nav = preview and self.previewNavigation or self.conversationNavigation
  if not nav then return end
  local scroll, child = nav.scroll, nav.child
  local width = scroll:GetWidth()
  local maximum = math.max(0, child:GetWidth() - width)
  local position = math.max(0, math.min(maximum, scroll:GetHorizontalScroll()))
  if position ~= scroll:GetHorizontalScroll() then scroll:SetHorizontalScroll(position) end
  nav.left:SetEnabled(position > 0.5); nav.right:SetEnabled(position < maximum - 0.5)
  local hidden, count, unreadTotal = 0, 0, 0
  local entries = preview and self.previewConversations or self.hubOrder
  local step = self:TabStep()
  for index, entry in ipairs(entries or {}) do
    count = count + 1
    local unread = preview and entry.unread or (W.records[entry] and W.records[entry].unread or 0)
    unreadTotal = unreadTotal + unread
    local left = (index - 1) * step
    if unread > 0 and (left < position or left + step > position + width + 1) then hidden = hidden + 1 end
  end
  nav.total, nav.hiddenUnread = count, hidden
  nav.unreadTotal = unreadTotal
  local label = self.minimized and unreadTotal > 0 and (unreadTotal > 99 and "99+" or tostring(unreadTotal)) or tostring(count)
  if label ~= nav.lastLabel then nav.all:SetText(label); nav.lastLabel = label end
  nav.all:GetFontString():SetTextColor(hidden > 0 and 1 or 0.74, hidden > 0 and 0.76 or 0.8, hidden > 0 and 0.28 or 0.88)
  nav.all.icon:SetVertexColor(hidden > 0 and 1 or 0.74, hidden > 0 and 0.76 or 0.8, hidden > 0 and 0.28 or 0.88)
  nav.all:SetEnabled(count > 0)
end

function W:PageConversationTabs(preview, direction)
  local nav = preview and self.previewNavigation or self.conversationNavigation
  if not nav then return end
  local step = self:TabStep()
  local page = math.max(1, math.floor(nav.scroll:GetWidth() / step)) * step
  local maximum = math.max(0, nav.child:GetWidth() - nav.scroll:GetWidth())
  nav.scroll:SetHorizontalScroll(math.max(0, math.min(maximum, nav.scroll:GetHorizontalScroll() + direction * page)))
  self:RefreshConversationNavigation(preview)
end

function W:ShowConversationPicker(preview, owner)
  if not self.conversationPicker then
    local picker = CreateFrame("Frame", nil, self.hub)
    self.conversationPicker = picker
    picker:SetSize(300, 350); picker:SetFrameStrata("DIALOG"); picker:SetClampedToScreen(true); picker:EnableMouse(true)
    local bg = picker:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(0.025, 0.03, 0.045, 0.98)
    local title = picker:CreateFontString(nil, "OVERLAY", "SunderChatDockFont")
    title:SetPoint("TOPLEFT", 12, -10); title:SetText("FIND A CONVERSATION")
    local close = self:IconButton(picker, "close", "Close conversation picker", function () picker:Hide() end)
    close:SetSize(22, 22); close:SetPoint("TOPRIGHT", -6, -4)
    local search = CreateFrame("EditBox", nil, picker, "InputBoxTemplate")
    picker.search = search
    search:SetSize(270, 24); search:SetPoint("TOPLEFT", 15, -34); search:SetAutoFocus(false)
    search:SetMaxLetters(64)
    search:SetScript("OnEscapePressed", function () picker:Hide() end)
    search:SetScript("OnTextChanged", function () picker.offset = 0; self:RefreshConversationPicker() end)
    search:SetScript("OnEnterPressed", function () if picker.matches and picker.matches[1] then self:ChoosePickerConversation(picker.matches[1]) end end)
    picker.rows = {}
    for i = 1, 9 do
      local row = CreateFrame("Button", nil, picker)
      row:SetSize(276, 27); row:SetPoint("TOPLEFT", 12, -66 - (i - 1) * 28)
      row:SetNormalFontObject("SunderChatDockFont"); row:SetText(" "); row:SetText(" ")
      row:GetFontString():SetJustifyH("LEFT"); row:GetFontString():SetWidth(264)
      row:SetHighlightTexture("Interface\\Buttons\\WHITE8X8"); row:GetHighlightTexture():SetVertexColor(0.5, 0.7, 1, 0.12)
      row:SetScript("OnClick", function () if row.entry then self:ChoosePickerConversation(row.entry) end end)
      picker.rows[i] = row
    end
    picker.status = picker:CreateFontString(nil, "OVERLAY", "SunderChatDockFont")
    picker.status:SetPoint("BOTTOMLEFT", 12, 10); picker.status:SetTextColor(0.65, 0.7, 0.8)
    picker:EnableMouseWheel(true)
    picker:SetScript("OnMouseWheel", function (_, delta)
      picker.offset = math.max(0, math.min(math.max(0, #(picker.matches or {}) - 9), (picker.offset or 0) - delta * 3))
      self:RefreshConversationPicker()
    end)
    picker:SetScript("OnHide", function () search:ClearFocus() end)
    local skin = Core:GetModule("Ellesmere").skin
    if skin and skin.EditBox then skin.EditBox(search) end
  end
  local picker = self.conversationPicker
  picker.preview, picker.offset = preview, 0
  picker:ClearAllPoints(); picker:SetPoint("TOPRIGHT", owner, "BOTTOMRIGHT", 0, -4)
  picker.search:SetText(""); picker:Show(); picker.search:SetFocus()
  self:RefreshConversationPicker()
end

function W:RefreshConversationPicker()
  local picker = self.conversationPicker
  if not picker or not picker.status then return end
  local query = (picker.search:GetText() or ""):lower()
  local matches = {}
  for _, entry in ipairs(self:ConversationEntries(picker.preview)) do
    if query == "" or entry.name:lower():find(query, 1, true) then matches[#matches + 1] = entry end
  end
  table.sort(matches, function (a, b)
    if (a.unread > 0) ~= (b.unread > 0) then return a.unread > 0 end
    if not not a.pinned ~= not not b.pinned then return not not a.pinned end
    if not not a.favorite ~= not not b.favorite then return not not a.favorite end
    return a.name < b.name
  end)
  picker.matches = matches
  picker.offset = math.max(0, math.min(picker.offset or 0, math.max(0, #matches - 9)))
  for i, row in ipairs(picker.rows) do
    local entry = matches[picker.offset + i]
    row.entry = entry; row:SetShown(entry ~= nil)
    if entry then
      local flags = (entry.favorite and "|TInterface\\AddOns\\Sunder\\Media\\Icons\\favorite.tga:12|t " or "")
        ..(entry.pinned and "|TInterface\\AddOns\\Sunder\\Media\\Icons\\pin.tga:12|t " or "")
      row:SetText(flags..entry.name..(entry.unread > 0 and "  |cffffcc66("..entry.unread..")|r" or ""))
    end
  end
  picker.status:SetText(#matches == 0 and "No conversations match" or (#matches.." conversations · Scroll for more"))
end

function W:ChoosePickerConversation(entry)
  local picker = self.conversationPicker
  picker:Hide()
  if picker.preview then
    for index, c in ipairs(self.previewConversations or {}) do if c == entry.value then self:SelectPreviewConversation(index); break end end
  elseif W.records[entry.value] then self:SelectConversation(entry.value, false) end
end


function W:SaveMessageWindowState()
  if not self.hubReady or self.transientSettings or W.restoringWindowState or W.windowStateShutdown
    or W.startingSimulation or W.previewSimulation or self.previewActive or not W:Settings().enabled or not UIParent:IsShown() then return end
  Core.db.char.messageWindowStates = Core.db.char.messageWindowStates or {}
  Core.db.char.messageWindowStates[self.hostId or "messages"] = {
    open = self.hub:IsShown(), minimized = not not self.minimized,
  }
end

function W:CloseMessages()
  self.windowManuallyClosed = true
  if self.hub then self.hub:Hide() end
  self:SaveMessageWindowState()
end

function W:BeginMessageWindowRestore()
  W:EnsureWorkspaces()
  W.restoringWindowState = true
  W.pendingWindowStates = {}
  for id, state in pairs(Core.db.char.messageWindowStates) do
    W.pendingWindowStates[id] = {open = state.open, minimized = state.minimized}
  end
end

function W:RestoreMessageWindows()
  local states = W.pendingWindowStates or Core.db.char.messageWindowStates or {}
  if W:Settings().enabled then
    -- Older versions had no visibility record. Keep-open gives Messages a
    -- sensible first-upgrade state, while untouched extra groups stay closed.
    if states.messages == nil then states.messages = {open = not not W:Settings().keepMessagesOpen} end
    for id, state in pairs(states) do
      if id == "messages" or Core.db.char.messageWorkspaces[id] then
        local host = W:GetWorkspace(id)
        host.windowManuallyClosed = not state.open
        if state.open then
          host:OpenMessages()
          host:SetMinimized(not not state.minimized, true)
          host.hubOpenedAt = GetTime()
        elseif host.hub then host.hub:Hide() end
      end
    end
  end
  W.restoringWindowState, W.pendingWindowStates = nil, nil
  for _, host in pairs(W.workspaces or {}) do host:SaveMessageWindowState() end
end

-- One metric source for real chats, previews, minimized shells and drop targets.
local function metric(key, default, low, high)
  return math.max(low, math.min(high, tonumber(W:Settings()[key]) or default))
end
function W:BodyPadding()
  return math.max(0,math.min(32,tonumber(Core.db.profile.bodyPadding) or 12))
end
function W:UsesChatAppearance() return self:Settings().hubMatchChat ~= false end
function W:InterfaceTextSize()
  return self:UsesChatAppearance() and math.max(8, math.min(32, tonumber(Core.db.profile.tabFontSize) or 13)) or metric("tabFontSize", 12, 10, 18)
end
function W:ToolbarIconSize()
  return self:UsesChatAppearance() and math.max(10, math.min(18, tonumber(Core.db.profile.chatTitleIconSize) or 14)) or metric("toolbarIconSize", 19, 12, 22)
end
function W:HeaderPadding()
  return self:UsesChatAppearance() and math.max(4, math.min(12, tonumber(Core.db.profile.textLeftPadding) or 4)) or metric("headerPadding", 7, 4, 16)
end
function W:HeaderGap()
  return self:UsesChatAppearance() and math.max(0, math.min(50, tonumber(Core.db.profile.tabMessageSpacing) or 2)) or 0
end
function W:SingleRowHeader() return self:UsesChatAppearance() and self:Settings().singleRowHeader ~= false end
function W:ContentTop() return self:SingleRowHeader() and math.max(0, self:HeaderHeight() - self:ConversationTabHeight()) or self:HeaderHeight() end
function W:PreviewTop() return self:SingleRowHeader() and 0 or self:HeaderHeight() end
function W:PreviewBodyTop() return (self:SingleRowHeader() and self:HeaderHeight() or self:ConversationTabHeight()) + (self:UsesChatAppearance() and self:HeaderGap() or 8) end
function W:NavigationWidth() return self:SingleRowHeader() and 100 or W.CONVERSATION_NAV_WIDTH end

function W:LayoutConversationStrip(preview)
  local scroll = preview and self.previewTabScroll or self.tabScroll
  local nav = preview and self.previewNavigation or self.conversationNavigation
  if not scroll then return end
  scroll:ClearAllPoints()
  if self:SingleRowHeader() or self.minimized then
    local y = -(self:HeaderHeight() - self:ConversationTabHeight()) / 2
    scroll:SetPoint("TOPLEFT", self.hub, "TOPLEFT", self.headerTitleEnd or 118, y)
    scroll:SetPoint("TOPRIGHT", self.hub, "TOPRIGHT", -(self.headerActionWidth or 92) - self:NavigationWidth(), y)
  elseif preview then
    scroll:SetPoint("TOPLEFT", self.previewFrame, "TOPLEFT")
    scroll:SetPoint("TOPRIGHT", self.previewFrame, "TOPRIGHT", -self:NavigationWidth(), 0)
  else
    scroll:SetPoint("TOPLEFT", self.hubContent, "TOPLEFT")
    scroll:SetPoint("TOPRIGHT", self.hubContent, "TOPRIGHT", -self:NavigationWidth(), 0)
  end
  if nav then
    nav:ClearAllPoints()
    if self.minimized and not self:SingleRowHeader() then nav:SetPoint("RIGHT", self.hubChrome, "RIGHT", -(self.headerActionWidth or 220), 0)
    else nav:SetPoint("TOPLEFT", scroll, "TOPRIGHT") end
    nav:SetWidth(self:NavigationWidth())
    local compact = self:SingleRowHeader()
    nav.left:ClearAllPoints(); nav.left:SetPoint("LEFT", compact and 2 or 8, 0); nav.left:SetWidth(compact and 20 or 28)
    nav.right:ClearAllPoints(); nav.right:SetPoint("LEFT", compact and 24 or 42, 0); nav.right:SetWidth(compact and 20 or 28)
    nav.all:ClearAllPoints(); nav.all:SetPoint("LEFT", compact and 46 or 76, 0); nav.all:SetWidth(compact and 50 or 64)
    nav.all.icon:ClearAllPoints(); nav.all.icon:SetPoint("LEFT", compact and 4 or 8, 0)
    local label = nav.all:GetFontString(); label:ClearAllPoints(); label:SetPoint("LEFT", compact and 22 or 30, 0); label:SetPoint("RIGHT", -4, 0)
  end
end

function W:HeaderHeight()
  -- Match the chat tab row: no extra vertical padding beneath centered labels.
  if self:UsesChatAppearance() then return math.max(self:ConversationTabHeight(), self:ToolbarIconSize() + 6) end
  return math.max(metric("toolbarIconSize", 19, 12, 22) + 7, metric("headerFontSize", 14, 10, 22))
    + metric("headerPadding", 7, 4, 16) * 2
end
function W:ConversationTabHeight()
  if self:UsesChatAppearance() then return math.max(Constants.DOCK_HEIGHT, self:InterfaceTextSize() + 8) end
  return math.max(Constants and Constants.DOCK_HEIGHT or 28, metric("conversationTabHeight", 28, 28, 44))
end
function W:TabWidth() if self:UsesChatAppearance() then return math.max(110, math.min(240, self:InterfaceTextSize() * 10 + 40)) end; return metric("conversationTabWidth", 170, 130, 260) end
function W:TabStep() return self:TabWidth() + 1 end

function W:WorkspaceFont(label, size)
  if not label then return end
  if self:UsesChatAppearance() then
    -- A previous skin can leave an explicit font on this FontString. Copy the
    -- rendered native label face/size as well as its FontObject to clear that difference.
    local native = _G.ChatFrame1Tab and _G.ChatFrame1Tab.Text or _G.SunderChatDockFont
    if native and native.GetFontObjectForAlphabet then native = native:GetFontObjectForAlphabet("roman") end
    label:SetFontObject(native and native.GetFontObject and native:GetFontObject() or _G.SunderChatDockFont or "SunderChatDockFont")
    if native and native.GetFont then
      local path, height, flags = native:GetFont()
      if path and height then label:SetFont(path, height, flags or "") end
      if native.GetShadowColor and label.SetShadowColor then label:SetShadowColor(native:GetShadowColor()) end
      if native.GetShadowOffset and label.SetShadowOffset then label:SetShadowOffset(native:GetShadowOffset()) end
    end
    return
  end
  local integration = Core:GetModule("Ellesmere")
  local selected = self:Settings().headerFont
  local path = selected and selected ~= "INHERIT" and Core.Libs.LSM:Fetch("font", selected, true)
  if not path and integration.GetFontPath then path = integration:GetFontPath() end
  local native = GameFontNormal
  if not path and native and native.GetFont then path = native:GetFont() end
  if path then label:SetFont(path, size, self:Settings().headerFontFlags or "") end
end

function W:ConfigureTabPin(tab, record, action)
  if not tab.pinControl then tab.pinControl = self:IconButton(tab, "pin", "Pin / unpin this conversation", function () end) end
  tab.pinRecord = record
  tab.pinControl:SetScript("OnClick", action)
  tab.pinControl:SetScript("OnLeave", function () self:StyleConversationTab(tab); GameTooltip:Hide() end)
end

function W:ToggleConversationPin(frame)
  local r = W.records and W.records[frame]
  if not r then return end
  r.pinned = not r.pinned
  local host = W:HubFor(frame)
  if r.placement == "hub" then
    if r.pinned then host:ReorderConversation(frame, 1, false) else host:KeepPinnedFirst(false); host:SaveConversationOrder(); host:LayoutHubTabs() end
  end
  W:UpdateBadges(); W:Save()
end

function W:StyleConversationTab(tab)
  local pad = self:UsesChatAppearance() and self:HeaderPadding() or metric("tabPadding", 6, 4, 12)
  local fontSize = self:InterfaceTextSize()
  local icon = self:UsesChatAppearance() and math.max(10, math.min(16, fontSize + 1)) or math.max(15, fontSize)
  tab:SetSize(self:TabWidth(), self:ConversationTabHeight())
  local label = tab:GetFontString()
  if label then
    label:ClearAllPoints(); label:SetPoint("LEFT", pad + (icon + 4) * 2 + 4, 0)
    label:SetWordWrap(false)
    label:SetWidth(math.max(30, self:TabWidth() - pad * 2 - (icon + 4) * 2 - 22))
    self:WorkspaceFont(label, fontSize)
  end
  if tab.unread then self:WorkspaceFont(tab.unread, fontSize) end
  if tab.pinControl then
    local pin = tab.pinControl
    pin:ClearAllPoints(); pin:SetPoint("LEFT", pad + icon + 4, 0)
    pin:SetSize(icon + 4, self:ConversationTabHeight() - 4); pin.icon:SetSize(icon, icon)
    self:StyleWindowIcon(pin)
    local pinned = tab.pinRecord and tab.pinRecord.pinned
    local r, g, b = self:InterfaceAccent()
    pin.icon:SetVertexColor(pinned and r or 0.45, pinned and g or 0.5, pinned and b or 0.6)
    pin.icon:SetAlpha(pinned and 1 or pin.iconOpacity or 0.5)
  end
  if tab.favoriteButton then
    local star = tab.favoriteButton
    star:ClearAllPoints(); star:SetPoint("LEFT", pad, 0)
    star:SetSize(icon + 4, self:ConversationTabHeight() - 4); star.icon:SetSize(icon, icon)
    self:StyleWindowIcon(star)
  end
end

function W:ApplyWorkspaceMetrics()
  if not self.hubChrome then return end
  local pad, icon = self:HeaderPadding(), self:ToolbarIconSize()
  local size = icon + (self:UsesChatAppearance() and 6 or 7)
  local gap, height = self:UsesChatAppearance() and 2 or metric("toolbarSpacing", 3, 2, 8), self:HeaderHeight()
  self.hubChrome:SetHeight(height)
  local right = pad
  self.hubActionButtons.Favorite:Hide(); self.hubActionButtons.Pin:Hide()
  local actions = self:SingleRowHeader() and {"Close", "Settings", "Windows"} or {"Close", "Settings", "Windows", "Detach", "Search", "Reply"}
  for _, name in ipairs({"Detach", "Search", "Reply"}) do self.hubActionButtons[name]:SetShown(not self:SingleRowHeader()) end
  for _, name in ipairs(actions) do
    local b = self.hubActionButtons[name]
    b:ClearAllPoints(); b:SetPoint("RIGHT", self.hubChrome, "RIGHT", -right, 0)
    b:SetSize(size, size); b.icon:SetSize(icon, icon)
    self:StyleWindowIcon(b)
    right = right + size + gap
  end
  for _, nav in pairs({self.conversationNavigation, self.previewNavigation}) do
    local controlHeight = math.min(22, self:ConversationTabHeight())
    for _, control in ipairs({nav.left, nav.right, nav.all}) do control:SetHeight(controlHeight); self:StyleWindowIcon(control) end
    if nav.divider then nav.divider:SetShown(not self:UsesChatAppearance()) end
    self:WorkspaceFont(nav.all:GetFontString(), self:InterfaceTextSize())
    for _, control in ipairs({nav.left, nav.right, nav.all}) do control.icon:SetSize(self:UsesChatAppearance() and math.min(14, self:ToolbarIconSize()) or 16, self:UsesChatAppearance() and math.min(14, self:ToolbarIconSize()) or 16) end
  end
  if self.conversationPicker then
    for _, row in ipairs(self.conversationPicker.rows) do self:WorkspaceFont(row:GetFontString(), metric("tabFontSize", 12, 10, 18)) end
  end
  local minimize = self.minimizeButton
  minimize:ClearAllPoints(); minimize:SetPoint("RIGHT", self.hubChrome, "RIGHT", -right, 0)
  minimize:SetSize(size, size); minimize.icon:SetSize(icon, icon)
  self:StyleWindowIcon(minimize)
  right = right + size + pad
  self.hubGrip:ClearAllPoints(); self.hubGrip:SetPoint("LEFT", self.hubChrome, "LEFT", pad, 0)
  self.hubMark:ClearAllPoints(); self.hubMark:SetPoint("LEFT", self.hubGrip, "RIGHT", pad, 0)
  self.hubGrip:SetHeight(height)
  self.hubMark:SetSize(icon, icon)
  self.hubMark:SetShown(not self:UsesChatAppearance() or Core.db.profile.chatTitleIcons ~= false)
  self.hubTitle:ClearAllPoints(); self.hubTitle:SetPoint("LEFT", self.hubMark, "RIGHT", pad, 0)
  self.headerActionWidth = right
  if self:SingleRowHeader() then
    local titleWidth = math.max(52, math.min(100, self:InterfaceTextSize() * 7))
    self.hubTitle:SetWidth(titleWidth)
    self.headerTitleEnd = pad * 4 + 18 + icon + titleWidth
  else self.hubTitle:SetPoint("RIGHT", self.hubChrome, "RIGHT", -right, 0) end
  self.hubTitle:SetHeight(height - pad * 2)
  self:WorkspaceFont(self.hubTitle, metric("headerFontSize", 14, 10, 22))
  -- Reserve a readable title between the grip and toolbar even with large controls.
  self.minimumWorkspaceWidth = self:SingleRowHeader() and (right + self.headerTitleEnd + self:NavigationWidth() + 120) or (right + pad * 3 + 18 + icon + 3 + 90)
  if self.hub:GetWidth() < self.minimumWorkspaceWidth then self.hub:SetWidth(self.minimumWorkspaceWidth) end
  self.hubRule:ClearAllPoints(); self.hubRule:SetPoint("BOTTOMLEFT", self.hubChrome, "BOTTOMLEFT")
  self.hubRule:SetPoint("BOTTOMRIGHT", self.hubChrome, "BOTTOMRIGHT")
  self.tabScroll:SetHeight(self:ConversationTabHeight()); self.tabChild:SetHeight(self:ConversationTabHeight())
  if self.conversationNavigation then self.conversationNavigation:SetHeight(self:ConversationTabHeight()) end
  if self.previewFrame and self.previewTabScroll and self.previewBody then
    self.previewFrame:ClearAllPoints(); self.previewFrame:SetPoint("TOPLEFT", self.hub, "TOPLEFT", 0, -self:PreviewTop()); self.previewFrame:SetPoint("BOTTOMRIGHT")
    self.previewTabScroll:SetHeight(self:ConversationTabHeight()); self.previewTabChild:SetHeight(self:ConversationTabHeight())
    if self.previewNavigation then self.previewNavigation:SetHeight(self:ConversationTabHeight()) end
    self.previewBody:ClearAllPoints(); self.previewBody:SetPoint("TOPLEFT", self.previewFrame, "TOPLEFT", self:BodyPadding(), -self:PreviewBodyTop()-self:BodyPadding())
    self.previewBody:SetPoint("BOTTOMRIGHT", self.previewFrame, "BOTTOMRIGHT", -self:BodyPadding(), self:BodyPadding())
    if self.previewActive then self:UpdatePreviewBadges() end
  end
  if self.collapseAnimation and self.finishCollapse then self.finishCollapse() end
  if self.minimized then self.hub:SetHeight(height) else self:LayoutHub() end
  self:LayoutConversationStrip(false); self:LayoutConversationStrip(true)
  self:LayoutHubTabs()
  self:ApplyHubAppearance()
  if self.minimized then self:PresentWindowBody(false, 1); self:PresentCollapsedHeader() end
  if self.appliedTabHeight ~= self:ConversationTabHeight() or self.appliedContentTop ~= self:ContentTop() then
    self.appliedContentTop = self:ContentTop()
    self.appliedTabHeight = self:ConversationTabHeight()
    for _, frame in ipairs(self.hubOrder or {}) do
      local window = Core:GetModule("UIManager"):GetChatWindow(frame)
      if window then
        local smf = window.slidingMessageFrame
        local index, offset = smf.state.scrollIndex or 1, smf.state.messageOffset or 0
        smf:RefreshLayout(true)
        if index > 1 or offset ~= 0 then smf:SetScrollPosition(index, offset) end
      end
    end
  end
end

