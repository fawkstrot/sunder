local Core, Constants = unpack(select(2, ...))
local W = Core:GetModule("Whispers")

-- Local-only conversation scripts: distinct people, realistic turns and replies.
local samples = {
  {"Hey, are you free for Deadmines tonight?", "Yeah, I can heal. What time are you thinking?", "Around eight. We still need one more.", "I can ask a friend to bring their mage.", "Perfect. I'll grab the quests first.", "Same here. Meet at Sentinel Hill?", "Sounds good. I'll bring extra water.", "Great, see you there."},
  {"Did you find the quest item near the bridge?", "Not yet. Is it on the north side?", "South side, tucked behind the fallen tree.", "Found it! That was easy to miss.", "I spent ages looking for it yesterday.", "Thanks for saving me the search.", "Want to finish the next part together?", "Absolutely. Give me a minute to turn this in."},
  {"Thanks again for helping with that elite.", "Any time. That last pull got a little close.", "I thought we were done when the second one joined.", "Same. Good thing you had that potion.", "I picked up a nice upgrade from the reward.", "Nice! Was it the staff?", "Yeah, finally replaced the old one.", "That's a good upgrade. Grats!"},
  {"Can you make a couple of bags?", "Sure. What size do you need?", "Ten slots would be great. My bank is a mess.", "I can do two now. Do you have the cloth?", "Yep. I'll bring it over.", "I'm by the Stormwind mailbox.", "On my way. Thanks!", "No problem. I'll have them ready."},
  {"Are you still looking for that shield?", "I am. Have you seen one on the auction house?", "There's one up now, but the price is a bit much.", "I'll wait. The dungeon drop should last a while.", "Probably the right call.", "Let me know if you run it again.", "Will do. We're going tomorrow.", "Count me in."},
  {"Want to take the boat together?", "Yes, just running down from the flight master.", "It left a minute ago, so we've got time.", "Good. I always arrive just as it leaves.", "Same here. I'll wait by the dock.", "I'm here. Need any food before we go?", "I've got enough, thanks.", "All right, let's go."},
  {"Do you have a spare mana potion?", "I've got a few. How many do you need?", "Just two for the boss.", "Take four. Better to have a couple left over.", "Thank you! I'll replace them after the run.", "Don't worry about it.", "Ready when you are.", "One second, then we're good."},
  {"How's the leveling going?", "Almost there. About two bars left.", "Nice, you're catching up quickly.", "Those quests you suggested helped a lot.", "There's a good chain near the lighthouse too.", "I'll head there after this turn-in.", "I can come along if you want.", "That would be great."},
  {"Did you get your profession recipe?", "Finally! It dropped on the last attempt.", "Grats! Can you make the enchant now?", "Yes. I just need the materials.", "I'll check my bank when I'm back in town.", "Thanks. No rush.", "I think I have most of them already.", "Perfect. I'll send you the list."},
  {"Are we meeting at the inn?", "Yep, upstairs by the table.", "I'll be there in a few minutes.", "Take your time. We're still sorting out the group.", "Should I bring my tank instead?", "Your healer would be better tonight.", "Works for me. I'll swap over.", "See you in a bit."},
}
local followups = {
  "Just got back. Are you still around?", "Yep, I'm here.", "I'm nearly ready.", "No rush. I'm finishing something up.",
  "Want to meet in town first?", "Sure. I'll head over now.", "I'm by the flight master.", "I see you. Give me a second.",
  "Anything else we need before we leave?", "I think we're all set.", "I picked up a little extra food.", "Good idea. I brought some water too.",
  "That worked out better than I expected.", "It did! That was fun.", "Thanks for coming along.", "Of course. Happy to help.",
  "I'm going to take a quick break.", "Same. I'll be back in ten.", "Back now. How's it going?", "Good timing. I just sat down.",
  "Want to do another one later?", "I'd be up for that.", "I'll check who's online.", "Let me know what you find.",
  "Looks like a few friends are around.", "Nice. We should have enough people.", "I'll start getting everyone together.", "I'll be ready when you are.",
  "Thanks again for tonight.", "Any time. See you tomorrow!", "Have a good night.", "You too!",
}
local generated = {"Are you still around?", "Ready when you are.", "I'm on my way.", "We found one more person.", "That was a good run!", "Want to go again tomorrow?", "I'll meet you by the bank.", "Thanks for the help!"}

function W:PreviewSettingsChanged()
  local registry = Core.Libs.AceConfigRegistry
  if not registry or not registry.NotifyChange or self.previewSettingsPending then return end
  self.previewSettingsPending = true
  C_Timer.After(0, function ()
    self.previewSettingsPending = nil
    registry:NotifyChange("Sunder")
  end)
end

function W:EnsurePreviewFrame()
  if self.previewFrame then return end
  local panel = CreateFrame("Frame", nil, self.hub)
  self.previewFrame = panel
  panel:SetPoint("TOPLEFT", self.hub, "TOPLEFT", 0, -self:PreviewTop())
  panel:SetPoint("BOTTOMRIGHT", self.hub, "BOTTOMRIGHT")
  panel:SetFrameLevel(self.hub:GetFrameLevel() + 12)
  local bg = panel:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints(); bg:SetColorTexture(0.035, 0.04, 0.05, 0)
  self.previewBackground = bg
  local tabs = CreateFrame("ScrollFrame", nil, panel)
  self.previewTabScroll = tabs
  tabs:SetPoint("TOPLEFT"); tabs:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -W.CONVERSATION_NAV_WIDTH, 0); tabs:SetHeight(self:ConversationTabHeight())
  tabs:EnableMouseWheel(true)
  local child = CreateFrame("Frame", nil, tabs)
  self.previewTabChild = child
  child:SetSize(510, self:ConversationTabHeight()); tabs:SetScrollChild(child)
  tabs:SetScript("OnMouseWheel", function (_, delta)
    tabs:SetHorizontalScroll(math.max(0, math.min(math.max(0, child:GetWidth() - tabs:GetWidth()), tabs:GetHorizontalScroll() - delta * self:TabStep())))
    self:RefreshConversationNavigation(true)
  end)
  self.previewTabs = {}
  self:CreateConversationNavigation(tabs, child, true)
  local body = CreateFrame("ScrollingMessageFrame", nil, panel)
  self.previewBody = body
  body:SetPoint("TOPLEFT", panel, "TOPLEFT", self:BodyPadding(), -self:PreviewBodyTop()-self:BodyPadding())
  body:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -self:BodyPadding(), self:BodyPadding())
  self:ApplyPreviewFont(body)
  body:SetJustifyH("LEFT")
  body:SetFading(false)
  body:SetMaxLines(200)
  body:EnableMouseWheel(true)
  body:SetScript("OnMouseWheel", function (_, delta)
    if delta > 0 then body:ScrollUp() else body:ScrollDown() end
  end)
  local help = panel:CreateFontString(nil, "OVERLAY", "SunderChatDockFont")
  help:SetPoint("BOTTOMLEFT", 8, 6)
  help:SetPoint("BOTTOMRIGHT", -8, 6)
  help:SetText(""); help:Hide()
  help:SetTextColor(0.7, 0.73, 0.78)
  panel:Hide()
end

function W:StartPreview()
  if not self:Settings().enabled then
    Core:GetModule("Config"):Print("Enable the whisper manager before starting its preview.")
    return
  end
  self:StopPreview()
  self:EnsureHub()
  self:EnsurePreviewFrame()
  self:SetMinimized(false, true)
  self.previewConversations = {}
  local cfg = self:Settings()
  local count = math.max(3, math.min(30, tonumber(cfg.previewConversations) or 10))
  if count == 12 then count = 10; cfg.previewConversations = 10 end
  local names = {"Elowen", "Mira", "Torin", "Kaelen", "Sera", "Bram", "Nyra", "Orin", "Lyra", "Dorian", "Alaric", "Bryn", "Celia", "Dara", "Eamon", "Freya", "Galen", "Hana", "Isla", "Joren", "Kira", "Lenn", "Maeve", "Nolan", "Oriana", "Perrin", "Quinn", "Rhea", "Silas", "Talia"}
  local lines = math.max(5, math.min(200, tonumber(cfg.previewLines) or 40))
  local time = GetServerTime() - lines * 47 - 120
  for i = 1, count do
    local sample = samples[(i - 1) % #samples + 1]
    local conversation = {name = names[(i - 1) % #names + 1], unread = i == 1 and 0 or i % 8 + 1, lines = {}}
    for index = 1, lines do
      local text = index <= #sample and sample[index] or followups[(index - #sample - 1) % #followups + 1]
      conversation.lines[index] = {text = text, outgoing = index % 2 == 0, time = time + index * 47 + i}
    end
    self.previewConversations[i] = conversation
    if not self.previewTabs[i] then
      local tab = CreateFrame("Button", nil, self.previewTabChild)
      tab:SetSize(self:TabWidth(), self:ConversationTabHeight())
      tab:SetPoint("TOPLEFT", self.previewTabChild, "TOPLEFT", (i - 1) * self:TabStep(), 0)
      tab:SetNormalFontObject("SunderChatDockFont")
      tab:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
      tab:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.1)
      local index = i
      tab:SetScript("OnClick", function () self:SelectPreviewConversation(index) end)
      self.previewTabs[i] = tab
    end
  end
  W.previewSamples = {}
  for _, c in ipairs(self.previewConversations) do c.host = self; W.previewSamples[#W.previewSamples + 1] = c end
  for i, tab in ipairs(self.previewTabs) do tab:SetShown(i <= count) end
  self.previewTabChild:SetWidth(count * self:TabStep())
  self.previewTabScroll:SetHorizontalScroll(0)
  self.previewSelected, self.previewSeed, self.previewNotificationCount = 1, 42, 0
  self.previewActive, self.lastPreviewNotification = true, GetTime()
  self.hubOpenedAt = GetTime()
  self.hubContent:Hide(); self.tabScroll:Hide()
  self.hubActionButtons.Reply:Disable(); self.hubActionButtons.Search:Disable()
  self.previewFrame:Show()
  self.hub:Show(); self.hub:SetAlpha(1)
  self:RenderPreview()
  self:PreviewSettingsChanged()
end

function W:StopPreview()
  if not self.previewActive then return end
  self.previewActive = nil
  self.lastTitle = nil
  self.previewConversations = nil
  if self.previewBody then self.previewBody:Clear() end
  self.previewNotificationCount = 0
  self.previewFrame:Hide()
  self.hubContent:SetShown(not self.minimized); self.tabScroll:SetShown(not self.minimized)
  for _, key in ipairs({"Reply", "Pin", "Detach", "Favorite", "Search"}) do self.hubActionButtons[key]:Enable() end
  self.hubOpenedAt = GetTime()
  self:LayoutHub()
  self:UpdateBadges()
  self:ApplyHubAppearance()
  self:PreviewSettingsChanged()
end

function W:EnsurePreviewTabVisible(index)
  if not self.previewTabScroll or not index then return end
  local left, scroll, width = (index - 1) * self:TabStep(), self.previewTabScroll:GetHorizontalScroll(), self.previewTabScroll:GetWidth()
  if left < scroll then self.previewTabScroll:SetHorizontalScroll(left)
  elseif left + self:TabWidth() > scroll + width then self.previewTabScroll:SetHorizontalScroll(math.max(0, left + self:TabWidth() - width)) end
  self:RefreshConversationNavigation(true)
end

function W:SelectPreviewConversation(index)
  self.hubOpenedAt=GetTime();self.lastUserInteraction=GetTime()
  if self.minimized then self:SetMinimized(false) end
  if not self.previewActive or not self.previewConversations[index] then return end
  self.previewSelected = index
  local c = self.previewConversations[index]
  c.readMarker = c.unread > 0 and math.max(1, #c.lines - c.unread + 1) or nil
  c.unread = 0
  self:EnsurePreviewTabVisible(index)
  self:RenderPreview()
end

function W:RenderPreview()
  if not self.previewActive then return end
  if IsMouseButtonDown and IsMouseButtonDown("LeftButton") and self.hub:IsMouseOver() then
    self.previewRenderPending=true;return
  end
  self.previewRenderPending=nil
  local cfg = self:Settings()
  if self.previewBody then self.previewBody:Clear() end
  self:ApplyPreviewFont(self.previewBody)
  local selected = self.previewConversations[self.previewSelected or 1]
  local r, g, b = self:InterfaceAccent()
  local hex = string.format("%02x%02x%02x", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
  self.previewRenderedRows=0
  for index, line in ipairs(selected and selected.lines or {}) do
    if selected.readMarker == index then self.previewBody:AddMessage("|cff8c98a8— New messages —|r", 0.55, 0.6, 0.66) end
    self.previewRenderedRows=self.previewRenderedRows+1+(selected.readMarker==index and 1 or 0);line.renderedRow=self.previewRenderedRows
    local stamp = cfg.timestamps and ("|cff89939e"..date(cfg.timestampFormat, line.time).."|r ") or ""
    local sender = line.outgoing and "|cffbac3ceYou|r" or ("|cff"..hex..selected.name.."|r")
    local replyColor=self:Settings().replyColor or {0.70,0.73,0.78}
    local differentiate=line.outgoing and self:Settings().distinguishReplies~=false
    local marker=differentiate and self:Settings().replyMarker and "› " or ""
    self.previewBody:AddMessage(marker..(line==self.previewJumpLine and "|cffffc738›|r " or "")..stamp..sender..": "..line.text, differentiate and replyColor[1] or 0.94, differentiate and replyColor[2] or 0.9, differentiate and replyColor[3] or 0.95)
  end
  self:UpdatePreviewBadges()
end

function W:UpdatePreviewBadges()
  if not self.previewActive then return end
  self:KeepPinnedFirst(true)
  local total = 0
  for index, conversation in ipairs(self.previewConversations) do
    total = total + conversation.unread
    local suffix = self:Settings().unreadBadges and conversation.unread > 0 and (" ("..conversation.unread..")") or ""
    conversation.classToken=conversation.classToken or ({"MAGE","WARRIOR","PRIEST","DRUID","ROGUE","HUNTER","PALADIN","WARLOCK","SHAMAN"})[(index-1)%9+1]
    local label = conversation.name..suffix
    if self.previewTabs[index].lastPreviewLabel ~= label then
      self.previewTabs[index]:SetText(label); self.previewTabs[index].lastPreviewLabel = label
    end
    self:SetTabAppearance(self.previewTabs[index], index == self.previewSelected, conversation.unread > 0)
    self:ConfigurePreviewTab(self.previewTabs[index], conversation, index)
    self.previewTabs[index]:GetFontString():SetTextColor(self:ConversationLabelColor(index == self.previewSelected, conversation))
  end
  for i = #self.previewConversations + 1, #self.previewTabs do self.previewTabs[i]:Hide() end
  self.previewTabChild:SetWidth(math.max(1, #self.previewConversations * self:TabStep()))
  self.hubTitle:SetText(self:WorkspaceName()..(self.minimized and total > 0 and ("  ·  "..total) or ""))
  self:UpdatePreviewActions()
  self:RefreshConversationNavigation(true)
  self:ApplyHubAppearance()
end

function W:GeneratePreviewNotification(silent)
  if not W.previewActive then W:StartPreview() end
  local pool = W.previewSamples
  if not pool or #pool == 0 then return end
  W.previewSeed = ((W.previewSeed or 42) * 48271) % 2147483647
  local active = {}
  for _, c in ipairs(pool) do if c.host and c.host.previewActive then active[#active + 1] = c end end
  if #active == 0 then return end
  local conversation = active[W.previewSeed % #active + 1]
  local host = conversation.host
  conversation.lastActivity = GetTime()
  if W.previewSimulation and not host.windowManuallyClosed then host.hub:Show(); host.hub:SetAlpha(1) end
  W.previewNotificationCount = (W.previewNotificationCount or 0) + 1
  conversation.lines[#conversation.lines + 1] = {text = generated[(W.previewNotificationCount - 1) % #generated + 1], outgoing = false, time = GetServerTime()}
  if #conversation.lines > 200 then table.remove(conversation.lines, 1) end
  if host.minimized or host.previewConversations[host.previewSelected] ~= conversation then conversation.unread = conversation.unread + 1 end
  W.lastPreviewNotification = GetTime()
  if not silent and W:Settings().previewSound then W:PlayNotification(true, true) end
  if host.QueueMinimizedWhisper then host:QueueMinimizedWhisper(conversation, true, conversation.lines[#conversation.lines].text) end
  host:RenderPreview()
end

-- Current clients expect a Font object here, rather than its global name.
-- Resolve the Roman face of our chat FontFamily before handing it to the mixin.
function W:ApplyPreviewFont(body)
  local source = _G.SunderMessageFont or _G.ChatFontNormal or _G.GameFontNormal
  if source and source.GetFontObjectForAlphabet then source = source:GetFontObjectForAlphabet("roman") end
  if not self.previewFont then self.previewFont = CreateFont("SunderPreviewFont") end
  self.previewFont:CopyFontObject(source)
  body:SetFontObject(self.previewFont)
end

function W:GeneratePreviewBatch()
  if not self.previewActive then self:StartPreview() end
  if not self.previewActive then return end
  local count = math.max(1, math.min(200, tonumber(self:Settings().previewBatchSize) or 50))
  for _ = 1, count do self:GeneratePreviewNotification(true) end
  if self:Settings().previewSound then self:PlayNotification(true) end
  self:RenderPreview()
  self:PreviewSettingsChanged()
end

function W:ClearPreviewData()
  self:Settings().previewAutoNotify = false
  self:StopPreview()
  self.previewConversations, self.previewSelected, self.previewSeed = nil, nil, nil
  self.previewNotificationCount = 0
  if self.previewBody then self.previewBody:Clear() end
  if self.previewTabs then for _, tab in ipairs(self.previewTabs) do tab:Hide() end end
  self:PreviewSettingsChanged()
end


function W:UpdatePreviewActions()
  local c = self.previewConversations and self.previewConversations[self.previewSelected or 1]
  for _, key in ipairs({"Pin", "Detach", "Favorite"}) do self.hubActionButtons[key]:SetEnabled(c ~= nil) end
  self.hubActionButtons.Reply:Disable(); self.hubActionButtons.Search:Disable()
  self.pinButton.plate:SetColorTexture(0.84, 0.66, 0.38, c and c.pinned and 0.25 or (self:UsesChatAppearance() and 0 or 0.035))
  self.hubActionButtons.Favorite.icon:SetVertexColor(c and c.favorite and 1 or 0.74, c and c.favorite and 0.76 or 0.8, c and c.favorite and 0.28 or 0.88)
end

function W:ConfigurePreviewTab(tab, c, index)
  if tab.favoriteButton then tab.favoriteButton.icon:SetVertexColor(c.favorite and 1 or 0.45, c.favorite and 0.76 or 0.5, c.favorite and 0.28 or 0.6) end
  self:StyleConversationTab(tab)
  if tab.previewBound == c and tab.previewIndex == index then tab:Show(); return end
  tab.previewBound, tab.previewIndex = c, index
  tab:ClearAllPoints(); tab:SetPoint("TOPLEFT", self.previewTabChild, "TOPLEFT", (index - 1) * self:TabStep(), 0)
  tab:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  tab:SetScript("OnEnter", function ()
    GameTooltip:SetOwner(tab, "ANCHOR_TOPLEFT"); GameTooltip:AddLine(c.name, 1, 1, 1)
    GameTooltip:AddLine("Right-click: conversation actions  •  Drag: move to another group", 0.75, 0.75, 0.75)
    GameTooltip:Show()
  end)
  tab:SetScript("OnLeave", function () GameTooltip:Hide() end)
  tab:SetScript("OnMouseDown",function(button,mouse)
    if mouse=="LeftButton" or mouse=="RightButton" then button.pressedConversation=button.previewBound end
  end)
  tab:SetScript("OnClick", function (button, mouse)
    local person=button.pressedConversation or button.previewBound
    button.pressedConversation=nil
    if button.suppressClick or not person then return end
    local host=person.host
    if not host or not host.previewActive then return end
    host.hubOpenedAt=GetTime();host.lastUserInteraction=GetTime()
    if mouse == "RightButton" then host:PreviewConversationMenu(button,person)
    elseif IsShiftKeyDown() then host:PreviewAction("Pin",person)
    else
      for i,item in ipairs(host.previewConversations or {}) do if item==person then host:SelectPreviewConversation(i);break end end
    end
  end)
  local label = tab:GetFontString()
  label:ClearAllPoints(); label:SetPoint("LEFT", 27, 0); label:SetWidth(157); label:SetJustifyH("LEFT")
  if not tab.favoriteButton then
    tab.favoriteButton = self:IconButton(tab, "favorite", "Favorite / unfavorite this person", function () end)
    tab.favoriteButton:SetSize(20, 22); tab.favoriteButton.icon:SetSize(15, 15); tab.favoriteButton:SetPoint("LEFT", 3, 0)
  end
  tab.favoriteButton:SetScript("OnClick", function () self:PreviewAction("Favorite", c) end)
  tab.favoriteButton:SetScript("OnLeave", function () self:UpdatePreviewBadges(); GameTooltip:Hide() end)
  tab.favoriteButton.icon:SetVertexColor(c.favorite and 1 or 0.45, c.favorite and 0.76 or 0.5, c.favorite and 0.28 or 0.6)
  self:StyleConversationTab(tab)
  self:ConfigureTabPin(tab, c, function () self:PreviewAction("Pin", c) end)
  self:StyleConversationTab(tab)
  self:EnableTabTransfer(tab, nil, c)
  tab:Show()
end

function W:ActivatePreviewHost()
  self:EnsureHub(); self:EnsurePreviewFrame(); self:SetMinimized(false, true)
  self.previewActive = true
  self.previewConversations = self.previewConversations or {}
  self.previewSelected = self.previewSelected or 1
  self.hubContent:Hide(); self.tabScroll:Hide(); self.previewFrame:Show(); self.hub:Show(); self.hub:SetAlpha(1)
end

function W:MovePreviewConversation(c, host)
  local old = c and c.host
  if not old or old == host then return end
  host:ActivatePreviewHost()
  for i, item in ipairs(old.previewConversations) do if item == c then table.remove(old.previewConversations, i); break end end
  old.previewSelected = math.max(1, math.min(old.previewSelected or 1, #old.previewConversations))
  c.host = host
  host.previewConversations[#host.previewConversations + 1] = c
  host.previewSelected = #host.previewConversations
  for i = 1, #host.previewConversations do
    if not host.previewTabs[i] then
      local tab = CreateFrame("Button", nil, host.previewTabChild)
      tab:SetSize(self:TabWidth(), self:ConversationTabHeight()); tab:SetNormalFontObject("SunderChatDockFont")
      host.previewTabs[i] = tab
    end
  end
  old:RenderPreview(); host:RenderPreview()
end

function W:PreviewAction(action, c)
  c = c or self.previewConversations and self.previewConversations[self.previewSelected or 1]
  if not c then return end
  if action == "Pin" then
    c.pinned = not c.pinned
    if c.host then
      if c.pinned then c.host:ReorderConversation(c, 1, true) else c.host:KeepPinnedFirst(true) end
    end
  elseif action == "Favorite" then
    c.favorite = not c.favorite
  elseif action == "Detach" then
    W.previewDetachedHosts = W.previewDetachedHosts or {}
    local id
    for i, host in ipairs(W.previewDetachedHosts) do if not host.previewActive or not host.previewConversations or #host.previewConversations == 0 then id = i; break end end
    id = id or #W.previewDetachedHosts + 1
    local host = W.previewDetachedHosts[id]
    if not host then
      host = setmetatable({hostId = "previewDetached"..id, records = W.records,
        transientSettings = {name = c.name, hubWidth = 540, hubHeight = 340, hubPoint = "CENTER", hubX = 60 * id, hubY = 0, keepMessagesOpen = true}},
        {__index = function (_, key) if type(W[key]) == "function" then return W[key] end end})
      W.previewDetachedHosts[id] = host
    end
    host.transientSettings.name = c.name
    W.workspaces[host.hostId] = host
    W:MovePreviewConversation(c, host)
  end
  if c.host then c.host:UpdatePreviewBadges() end
end

function W:PreviewConversationMenu(owner, c)
  if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
  MenuUtil.CreateContextMenu(owner, function (_, menu)
    menu:CreateTitle(c and c.name or "Sample conversations")
    if c then
      menu:CreateButton(c.favorite and "Unfavorite person" or "Favorite person", function () self:PreviewAction("Favorite", c) end)
      menu:CreateButton(c.pinned and "Unpin conversation" or "Pin conversation", function () self:PreviewAction("Pin", c) end)
      menu:CreateButton("Detach sample conversation", function () self:PreviewAction("Detach", c) end)
      menu:CreateButton("Move to Whispers", function () W:MovePreviewConversation(c, W) end)
      for id, saved in pairs(Core.db.char.messageWorkspaces or {}) do if id ~= "favorites" then
        local destination = id
        menu:CreateButton("Move to "..saved.name, function () W:MovePreviewConversation(c, W:GetWorkspace(destination)) end)
      end end
      menu:CreateButton("New group with this sample", function () local host = W:CreateWorkspace(); if host then W:MovePreviewConversation(c, host) end end)
    end
    self:AddConversationSortMenu(menu)
    menu:CreateButton("Clear all sample data", function () W:ClearPreviewData() end)
  end)
end

local stopOnePreview = W.StopPreview
function W:StopPreview()
  local simulation = self == W and W.previewSimulation
  if self == W then
    W.previewSimulation = nil
    if W.simulationStatus then W.simulationStatus:Hide() end
  end
  if self == W and not W.clearingPreviews then
    W.clearingPreviews = true
    for _, host in pairs(W.workspaces or {}) do if host ~= W and host.previewActive then stopOnePreview(host) end end
    for _, host in ipairs(W.previewDetachedHosts or {}) do
      if host.hub then host.hub:Hide() end
      if W.workspaces then W.workspaces[host.hostId] = nil end
    end
    W.previewSamples = nil
    W.clearingPreviews = nil
  end
  stopOnePreview(self)
  if simulation then
    for id, host in pairs(W.workspaces or {}) do
      local state = simulation.windows[id]
      if host.hub then
        host:SetMinimized(state and state.minimized or false, true)
        host.hub:SetAlpha(state and state.alpha or 1)
        host.hub:SetShown(state and state.open or false)
        host.windowManuallyClosed = state and state.closed or nil
      end
    end
  end
end

-- Five-minute scenario state is never attached to a saved profile or character table.
function W:StartMessageSimulation()
  for _,host in pairs(W.workspaces or {}) do host.lastUserInteraction=GetTime() end
  for _,host in ipairs(W.previewDetachedHosts or {}) do host.lastUserInteraction=GetTime() end
  W:ClearPreviewData()
  local windows = {}
  for id, host in pairs(W.workspaces or {}) do
    windows[id] = {open = host.hub and host.hub:IsShown() or false, minimized = not not host.minimized,
      alpha = host.hub and host.hub:GetAlpha() or 1, closed = host.windowManuallyClosed}
  end
  W.startingSimulation = true
  W:StartPreview()
  W.startingSimulation = nil
  if not W.previewActive then return end
  local sim = {started = GetTime(), sent = 0, incoming = 0, outgoing = 0, windows = windows, events = {}, cursor = 1}
  W.previewSimulation = sim
  local pool = W.previewSamples
  local count = #pool
  W.previewConversations, W.previewSelected = {}, 1
  for i, c in ipairs(pool) do
    c.lines, c.unread, c.host = {}, 0, nil
    local wave = math.min(2, math.floor((i - 1) * 3 / count))
    local first = math.ceil(wave * count / 3) + 1
    local groupSize = math.max(1, math.ceil((wave + 1) * count / 3) - first + 1)
    local arrival = wave * 90 + (i - first) * 18 / math.max(1, groupSize - 1)
    local script = samples[(i - 1) % #samples + 1]
    for j, line in ipairs(script) do
      sim.events[#sim.events + 1] = {at = arrival + (j - 1) * 3, person = c, text = line, outgoing = j % 2 == 0}
    end
    -- A later exchange follows the same person even after moving/favoriting/detaching.
    for j = 1, 4 do
      sim.events[#sim.events + 1] = {at = 270 + ((i - 1) % 4) * 2 + (j - 1) * 3,
        person = c, text = followups[j], outgoing = j % 2 == 0}
    end
  end
  for i, event in ipairs(sim.events) do event.sequence = i end
  table.sort(sim.events, function (a, b) return a.at == b.at and a.sequence < b.sequence or a.at < b.at end)
  W:RenderPreview()
  W:TickMessageSimulation()
  W:PreviewSettingsChanged()
end

function W:EnsureSimulationStatus()
  if self.simulationStatus then return end
  local bar = CreateFrame("Frame", nil, UIParent)
  self.simulationStatus = bar
  bar:SetSize(300, 24); bar:SetFrameStrata("DIALOG"); bar:SetClampedToScreen(true)
  bar:SetPoint("BOTTOMLEFT", self.hub, "TOPLEFT", 0, 6)
  local background = bar:CreateTexture(nil, "BACKGROUND")
  background:SetAllPoints(); background:SetColorTexture(.025, .03, .04, .88)
  local label = bar:CreateFontString(nil, "OVERLAY", "SunderChatDockFont")
  label:SetPoint("LEFT", 9, 0); label:SetPoint("RIGHT", -28, 0); label:SetJustifyH("LEFT")
  self:WorkspaceFont(label, self:InterfaceTextSize())
  local progress = bar:CreateTexture(nil, "ARTWORK")
  progress:SetPoint("BOTTOMLEFT"); progress:SetHeight(1)
  local r,g,b = self:InterfaceAccent(); progress:SetColorTexture(r,g,b,.8)
  local stop = self:IconButton(bar, "close", "Stop test and clear all samples", function () W:ClearPreviewData() end)
  stop:SetPoint("RIGHT", -3, 0); stop:SetSize(20, 20); stop.icon:SetSize(12,12)
  self:StyleWindowIcon(stop)
  bar.label, bar.progress, bar.stop = label, progress, stop
  bar:EnableMouse(true)
  bar:SetScript("OnEnter", function ()
    GameTooltip:SetOwner(bar, "ANCHOR_TOP")
    GameTooltip:AddLine("Five-minute message test", 1, 1, 1)
    GameTooltip:AddLine("New people arrive in three waves, with natural two-way conversations.", .7,.75,.8)
    GameTooltip:AddLine("Quiet periods exercise the temporary 12-second fade timeout.", .7,.75,.8)
    GameTooltip:AddLine("Try minimizing, pinning, favoriting or detaching. Later messages follow that person.", .7,.75,.8)
    GameTooltip:AddLine("Automatically clears at 0:00. Nothing from the test is saved.", .7,.75,.8)
    GameTooltip:Show()
  end)
  bar:SetScript("OnLeave", function () GameTooltip:Hide() end)
end

function W:UpdateSimulationStatus(elapsed)
  self:EnsureSimulationStatus()
  local sim, bar = W.previewSimulation, self.simulationStatus
  if not sim then bar:Hide(); return end
  local remaining = math.max(0, math.ceil(300 - elapsed))
  if sim.lastStatusSecond ~= remaining then
    sim.lastStatusSecond = remaining
    local phase = elapsed >= 270 and "Final replies" or elapsed % 90 < 42 and "Arrivals & replies" or "Quiet · fade timeout"
    bar.label:SetText(string.format("Test · %d:%02d · %s", math.floor(remaining / 60), remaining % 60, phase))
    bar.progress:SetWidth(math.max(1, 300 * remaining / 300))
  end
  bar:Show()
end

function W:PlaySimulationEvent(event)
  local sim, c = W.previewSimulation, event.person
  if not sim then return end
  if not c.host then
    c.host = W
    W.previewConversations[#W.previewConversations + 1] = c
  end
  local host = c.host
  if not host.previewActive then return end
  c.lastActivity = sim.started + event.at
  c.lines[#c.lines + 1] = {text = event.text, outgoing = event.outgoing, time = GetServerTime() - math.max(0, GetTime() - c.lastActivity)}
  if #c.lines > 200 then table.remove(c.lines, 1) end
  sim.sent = sim.sent + 1
  if event.outgoing then sim.outgoing = sim.outgoing + 1
  else
    sim.incoming = sim.incoming + 1
    if host.minimized or not host.hub:IsShown() or host.previewConversations[host.previewSelected] ~= c then c.unread = c.unread + 1 end
    if host.QueueMinimizedWhisper then host:QueueMinimizedWhisper(c, true, event.text) end
    if not host.windowManuallyClosed then host.hub:Show(); host.hub:SetAlpha(1) end
    if W:Settings().previewSound and GetTime() - c.lastActivity < 2 then W:PlayNotification(true, true) end
  end
  host:RenderPreview()
end

function W:TickMessageSimulation()
  local sim = W.previewSimulation
  if not sim then return end
  local elapsed = GetTime() - sim.started
  if elapsed >= 300 then W:ClearPreviewData(); return end
  -- Catch up chronologically, bounded by the finite scenario (at most 360 lines).
  while sim.events[sim.cursor] and sim.events[sim.cursor].at <= elapsed do
    W:PlaySimulationEvent(sim.events[sim.cursor])
    sim.cursor = sim.cursor + 1
  end
  W:UpdateSimulationStatus(elapsed)
end

function W:SimulationWindowAlpha()
  local latest, pinned = self.hubOpenedAt or 0, false
  for _, c in ipairs(self.previewConversations or {}) do
    latest = math.max(latest, c.lastActivity or 0); pinned = pinned or c.pinned
  end
  latest=math.max(latest,self.lastUserInteraction or 0)
  if self.minimized or pinned or self.hubMoving or self.hub:IsMouseOver() then return 1 end
  return math.max(0, math.min(1, 1 - (GetTime() - latest - 12) / math.max(.05, W:Settings().fadeTime)))
end
