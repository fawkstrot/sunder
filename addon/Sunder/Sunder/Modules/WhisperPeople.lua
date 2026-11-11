local Core, Constants = unpack(select(2, ...))
local W = Core:GetModule("Whispers")

-- One set of person controls serves both layouts; real chat renderers/editors stay native.
function W:IsConversationList() return self:Settings().conversationLayout ~= "tabs" end
function W:ConversationListWidth()
  local width = self.hub and self.hub:GetWidth() or self:HubSettings().hubWidth or 540
  local ratio = math.max(25, math.min(45, tonumber(self:Settings().conversationListRatio) or 30)) / 100
  return math.max(140, math.min(width - 240, math.floor(width * ratio)))
end
function W:ConversationBodyLeft() return self:ConversationListWidth() + self:HeaderGap() end
function W:ConversationRowHeight() return math.max(30, self:InterfaceTextSize() + 16, self:ConversationTabHeight() + 6) end
function W:ConversationRowStep() return self:ConversationRowHeight() + 2 end
local function scrollFor(host, preview)
  if preview then return host.previewTabScroll,host.previewTabChild end
  return host.tabScroll,host.tabChild
end
local function listFor(host, preview) return preview and host.previewConversations or host.hubOrder end
local function verticalMaximum(scroll, child) return math.max(0, child:GetHeight() - scroll:GetHeight()) end

local singleRow, contentTop, previewTop, previewBodyTop, tabWidth, navWidth = W.SingleRowHeader, W.ContentTop, W.PreviewTop, W.PreviewBodyTop, W.TabWidth, W.NavigationWidth
function W:SingleRowHeader() return not self:IsConversationList() and singleRow(self) end
function W:ContentTop() return self:IsConversationList() and 0 or contentTop(self) end
function W:PreviewTop() return self:IsConversationList() and 0 or previewTop(self) end
function W:PreviewBodyTop() return self:IsConversationList() and self:HeaderHeight() + self:HeaderGap() or previewBodyTop(self) end
function W:TabWidth() return self:IsConversationList() and self:ConversationListWidth() - self:BodyPadding() * 2 or tabWidth(self) end
function W:NavigationWidth() return self:IsConversationList() and 100 or navWidth(self) end

local strip = W.LayoutConversationStrip
function W:LayoutConversationStrip(preview)
  if not self:IsConversationList() then return strip(self, preview) end
  local scroll = scrollFor(self, preview)
  if not scroll then return end
  scroll:ClearAllPoints()
  scroll:SetPoint("TOPLEFT", self.hub, "TOPLEFT", 0, -self:HeaderHeight() - self:HeaderGap())
  -- A collapsed root is shorter than these insets. Never anchor a ScrollFrame
  -- across that inverted rectangle, including the first frames of restoration.
  scroll:SetHeight(self.minimized and 1 or math.max(1,self.hub:GetHeight()-self:HeaderHeight()-self:HeaderGap()))
  scroll:SetWidth(self:ConversationListWidth())
  scroll:SetShown(not self.minimized and (preview and self.previewActive or not preview and not self.previewActive))
  -- Paging/search stays in the title bar, never adds a second row above the body.
  local nav = preview and self.previewNavigation or self.conversationNavigation
  if nav then
    nav:ClearAllPoints(); nav:SetPoint("RIGHT", self.hubChrome, "RIGHT", -(self.headerActionWidth or 160), 0)
    nav:SetSize(100, self:HeaderHeight())
    for _, item in ipairs({{nav.left,2},{nav.right,24},{nav.all,46}}) do
      item[1]:ClearAllPoints(); item[1]:SetPoint("LEFT", item[2], 0); item[1]:SetWidth(item[1] == nav.all and 50 or 20)
    end
    nav.all.icon:ClearAllPoints(); nav.all.icon:SetPoint("LEFT", 4, 0)
    local label = nav.all:GetFontString(); label:ClearAllPoints(); label:SetPoint("LEFT", 22, 0); label:SetPoint("RIGHT", -4, 0)
    nav.left.icon:SetRotation(-math.pi / 2); nav.right.icon:SetRotation(-math.pi / 2)
    nav:SetShown(preview and self.previewActive or not preview and not self.previewActive)
  end
  scroll:SetScript("OnMouseWheel", function (_, delta)
    if not self:IsConversationList() then
      local _, child = scrollFor(self, preview)
      scroll:SetHorizontalScroll(math.max(0, math.min(math.max(0, child:GetWidth()-scroll:GetWidth()), scroll:GetHorizontalScroll()-delta*self:TabStep())))
    else
      local _, child = scrollFor(self, preview)
      scroll:SetVerticalScroll(math.max(0, math.min(verticalMaximum(scroll, child), scroll:GetVerticalScroll()-delta*self:ConversationRowStep()*2)))
    end
    self:RefreshConversationNavigation(preview)
  end)
end

local styleTab, tabAppearance = W.StyleConversationTab, W.SetTabAppearance
function W:StyleConversationTab(tab)
  styleTab(self, tab)
  if not self:IsConversationList() then return end
  tab:SetHeight(self:ConversationRowHeight())
  if tab.underline then
    tab.underline:ClearAllPoints(); tab.underline:SetPoint("TOPLEFT", 0, -4); tab.underline:SetPoint("BOTTOMLEFT", 0, 4); tab.underline:SetWidth(1)
  end
end
function W:SetTabAppearance(tab, selected, unread)
  tabAppearance(self, tab, selected, unread)
  if self:IsConversationList() and tab.selection then
    local r,g,b = self:InterfaceAccent()
    if selected then tab.selection:SetColorTexture(.22,.55,1,.09)
    else tab.selection:SetColorTexture(1,.78,.22,unread and .045 or 0) end
    tab.underline:SetColorTexture(selected and .22 or 1,selected and .55 or .78,selected and 1 or .22,(selected or unread) and .85 or 0)
    tab.underline:SetShown(selected or not not unread)
    tab.underline:ClearAllPoints(); tab.underline:SetPoint("TOPLEFT", 0, -4); tab.underline:SetPoint("BOTTOMLEFT", 0, 4); tab.underline:SetWidth(1)
  end
end

function W:LayoutPeopleRows(preview)
  if not self:IsConversationList() then return end
  local scroll, child = scrollFor(self, preview)
  if not child then return end
  local list = listFor(self, preview) or {}
  local pad, step = self:BodyPadding(), self:ConversationRowStep()
  for i, value in ipairs(list) do
    local tab = preview and self.previewTabs[i] or self.hubTabs[value]
    if tab then
      tab:ClearAllPoints(); tab:SetPoint("TOPLEFT", child, "TOPLEFT", pad, -pad-(i-1)*step)
      self:StyleConversationTab(tab)
    end
  end
  local rows = #list
  child:SetSize(self:ConversationListWidth(), math.max(1, rows*step+pad*2))
  scroll:SetHorizontalScroll(0)
  scroll:SetVerticalScroll(math.max(0, math.min(verticalMaximum(scroll,child), scroll:GetVerticalScroll())))
end
local layoutTabs, previewBadges = W.LayoutHubTabs, W.UpdatePreviewBadges
function W:LayoutHubTabs()
  layoutTabs(self)
  if self:IsConversationList() then self:LayoutPeopleRows(false); self:RefreshConversationNavigation(false) end
end
function W:UpdatePreviewBadges()
  previewBadges(self)
  if self:IsConversationList() and self.previewActive then self:PositionConversationBody(); self:LayoutConversationStrip(true); self:LayoutPeopleRows(true); self:RefreshConversationNavigation(true) end
end

local navigation, page, revealNative, revealSample = W.RefreshConversationNavigation, W.PageConversationTabs, W.EnsureHubTabVisible, W.EnsurePreviewTabVisible
function W:RefreshConversationNavigation(preview)
  if not self:IsConversationList() then return navigation(self, preview) end
  local nav = preview and self.previewNavigation or self.conversationNavigation
  if not nav then return end
  local scroll, child = scrollFor(self, preview)
  local pos = math.max(0, math.min(verticalMaximum(scroll,child), scroll:GetVerticalScroll()))
  scroll:SetVerticalScroll(pos)
  nav.left:SetEnabled(not self.minimized and pos > .5); nav.right:SetEnabled(not self.minimized and pos < verticalMaximum(scroll,child)-.5)
  local count, unread, hidden = 0,0,0
  for i, item in ipairs(listFor(self,preview) or {}) do
    local record = preview and item or W.records[item]
    local n = record and record.unread or 0
    count=count+1; unread=unread+n
    local top=(i-1)*self:ConversationRowStep()
    if n>0 and (self.minimized or top<pos or top+self:ConversationRowHeight()>pos+scroll:GetHeight()) then hidden=hidden+1 end
  end
  nav.total,nav.unreadTotal,nav.hiddenUnread=count,unread,hidden
  local label = self.minimized and unread>0 and (unread>99 and "99+" or tostring(unread)) or tostring(count)
  if nav.lastLabel~=label then nav.all:SetText(label);nav.lastLabel=label end
  local r,g,b=self:InterfaceAccent()
  nav.all:GetFontString():SetTextColor(unread>0 and r or .74,unread>0 and g or .8,unread>0 and b or .88)
  nav.all:SetEnabled(count>0)
end
function W:PageConversationTabs(preview,direction)
  if not self:IsConversationList() then return page(self,preview,direction) end
  local scroll,child=scrollFor(self,preview);if not scroll then return end
  local size=math.max(self:ConversationRowStep(),math.floor(scroll:GetHeight()/self:ConversationRowStep())*self:ConversationRowStep())
  scroll:SetVerticalScroll(math.max(0,math.min(verticalMaximum(scroll,child),scroll:GetVerticalScroll()+direction*size)))
  self:RefreshConversationNavigation(preview)
end
function W:RevealPerson(preview,index)
  local scroll=scrollFor(self,preview);if not scroll or not index then return end
  local top=(index-1)*self:ConversationRowStep();local position=scroll:GetVerticalScroll()
  if top<position then scroll:SetVerticalScroll(top)
  elseif top+self:ConversationRowHeight()>position+scroll:GetHeight() then scroll:SetVerticalScroll(math.max(0,top+self:ConversationRowHeight()-scroll:GetHeight())) end
  self:RefreshConversationNavigation(preview)
end
function W:EnsureHubTabVisible(frame)
  if not self:IsConversationList() then return revealNative(self,frame) end
  for i,item in ipairs(self.hubOrder or {}) do if item==frame then self:RevealPerson(false,i);break end end
end
function W:EnsurePreviewTabVisible(index)
  if not self:IsConversationList() then return revealSample(self,index) end
  self:RevealPerson(true,index)
end

local insertionIndex,insertionMark,dropTarget=W.TabInsertionIndex,W.ShowTabInsertion,W.TabDropTarget
function W:IsConversationDropArea(x,y)
  if not self.hub or not self.hub:IsShown() then return false end
  local scale=self.hub:GetEffectiveScale();local left,top=self.hub:GetLeft()*scale,self.hub:GetTop()*scale
  return x>=left and x<=left+self.hub:GetWidth()*scale and y<=top and
    (y>=top-self:HeaderHeight()*scale or not self.minimized and x<=left+self:ConversationListWidth()*scale and y>=top-self.hub:GetHeight()*scale)
end
function W:TabDropTarget(x,y)
  local best,level
  for _,host in pairs(W.workspaces or {}) do
    if not host.transientSettings and host.hub and host.hub:IsShown() then
      if host:IsConversationList() and host:IsConversationDropArea(x,y) then
        local z=host.hub:GetFrameLevel();if not level or z>=level then best,level=host,z end
      end
    end
  end
  if self:IsConversationList() then return best end
  return best or dropTarget(self,x,y)
end
function W:TabInsertionIndex(preview,x,y)
  if not self:IsConversationList() then return insertionIndex(self,preview,x) end
  local scroll=scrollFor(self,preview);if not scroll then return 1 end
  if not y then local _,cursorY=GetCursorPosition();y=cursorY end
  local offset=scroll:GetTop()-y/scroll:GetEffectiveScale()+scroll:GetVerticalScroll()
  return math.max(1,math.min(#(listFor(self,preview) or {})+1,math.floor(offset/self:ConversationRowStep()+.5)+1))
end
function W:ShowTabInsertion(preview,index)
  if not self:IsConversationList() then return insertionMark(self,preview,index) end
  local scroll=scrollFor(self,preview);if not scroll or self.minimized then return end
  if not self.tabInsertion then self.tabInsertion=self.hub:CreateTexture(nil,"OVERLAY") end
  local y=math.max(0,math.min(scroll:GetHeight()-2,(index-1)*self:ConversationRowStep()-scroll:GetVerticalScroll()))
  self.tabInsertion:ClearAllPoints();self.tabInsertion:SetPoint("TOPLEFT",scroll,"TOPLEFT",self:HeaderPadding(),-y)
  self.tabInsertion:SetSize(self:TabWidth(),1)
  local r,g,b=self:InterfaceAccent();self.tabInsertion:SetColorTexture(r,g,b,.9);self.tabInsertion:Show()
end
function W:ScrollListEdge(preview,x,y,elapsed)
  local scroll,child=scrollFor(self,preview);if not scroll then return end
  local offset=scroll:GetTop()-y/scroll:GetEffectiveScale()
  local delta=offset<22 and -1 or offset>scroll:GetHeight()-22 and 1 or 0
  if delta~=0 then scroll:SetVerticalScroll(math.max(0,math.min(verticalMaximum(scroll,child),scroll:GetVerticalScroll()+delta*260*math.min(.05,elapsed or .016)))) end
end

local applyAppearance,metrics,layout,collapsed,body=W.ApplyHubAppearance,W.ApplyWorkspaceMetrics,W.LayoutHub,W.PresentCollapsedHeader,W.PresentWindowBody
function W:ApplyHubAppearance()
  applyAppearance(self)
  if not self:IsConversationList() or not self.hub then
    if self.peopleBackground then self.peopleBackground:Hide() end
    if self.whisperSurface then self.whisperSurface:Hide() end
    return
  end
  -- Gradient parts are sibling textures; retire both column paints explicitly.
  local transparent={r=0,g=0,b=0,a=0}
  for _, old in pairs({self.hubBackground,self.peopleBackground}) do
    if Core.Components.PaintGradientTexture then Core.Components.PaintGradientTexture(old,transparent,0,false) else old:SetAlpha(0) end
  end
  self.tabStripBackground:SetAlpha(0)
  if self.tabStripBackground.sunderGradientParts then for _, part in pairs(self.tabStripBackground.sunderGradientParts) do part:Hide() end end
  self.hubRule:ClearAllPoints();self.hubRule:SetPoint("BOTTOMLEFT",self.hubChrome,"BOTTOMLEFT");self.hubRule:SetPoint("BOTTOMRIGHT",self.hubChrome,"BOTTOMRIGHT")
  if not self.whisperSurface then
    local surface=CreateFrame("Frame",nil,self.hub)
    self.whisperSurface=surface;surface:SetFrameLevel(self.hub:GetFrameLevel())
    surface.fill=surface:CreateTexture(nil,"BACKGROUND");surface.fill:SetAllPoints()
  end
  local surface=self.whisperSurface
  surface:ClearAllPoints();surface:SetPoint("TOPLEFT",self.hub,"TOPLEFT",0,-self:HeaderHeight()-self:HeaderGap());surface:SetPoint("TOPRIGHT",self.hub,"TOPRIGHT",0,-self:HeaderHeight()-self:HeaderGap());surface:SetHeight(math.max(1,self.hub:GetHeight()-self:HeaderHeight()-self:HeaderGap()))
  local cfg=self:Settings();local color=self:UsesChatAppearance() and Core.db.profile.chatBackgroundColor or cfg.hubBackgroundColor
  local alpha=self:UsesChatAppearance() and color and color.a or cfg.hubBackgroundOpacity
  if Core.Components.PaintGradientTexture then Core.Components.PaintGradientTexture(surface.fill,color or {r=.035,g=.04,b=.05},alpha or .25,self:UsesChatAppearance() or cfg.hubUseChatFade)
  else surface.fill:SetColorTexture(.035,.04,.05,alpha or .25) end
  surface:SetShown(not self.minimized or self.collapseAnimation)

end
function W:PositionConversationBody()
  if not self.previewBody or not self:IsConversationList() then return end
  if self.minimized then
    self.previewBody:Hide()
    return
  end
  self.previewFrame:ClearAllPoints();self.previewFrame:SetPoint("TOPLEFT",self.hub,"TOPLEFT");self.previewFrame:SetPoint("BOTTOMRIGHT",self.hub,"BOTTOMRIGHT")
  self.previewBody:ClearAllPoints();self.previewBody:SetPoint("TOPLEFT",self.hub,"TOPLEFT",self:ConversationBodyLeft()+self:BodyPadding(),-self:HeaderHeight()-self:HeaderGap()-self:BodyPadding())
  self.previewBody:SetPoint("TOPRIGHT",self.hub,"TOPRIGHT",-self:BodyPadding(),-self:HeaderHeight()-self:HeaderGap()-self:BodyPadding())
  self.previewBody:SetHeight(math.max(1,self.hub:GetHeight()-self:HeaderHeight()-self:HeaderGap()-self:BodyPadding()*2))
end
function W:ApplyWorkspaceMetrics()
  metrics(self)
  if self:IsConversationList() then
    self.hubTitle:SetPoint("RIGHT",self.hubChrome,"RIGHT",-(self.headerActionWidth or 160)-100-self:HeaderPadding(),0)
    self:PositionConversationBody();self:LayoutConversationStrip(false);self:LayoutConversationStrip(true)
    self:LayoutPeopleRows(not not self.previewActive)
  else
    for _,nav in pairs({self.conversationNavigation,self.previewNavigation}) do nav.left.icon:SetRotation(0);nav.right.icon:SetRotation(0) end
    for _,tab in pairs(self.hubTabs or {}) do if tab.underline then tab.appearanceStamp=nil;tab.underline:ClearAllPoints();tab.underline:SetPoint("BOTTOMLEFT",4,0);tab.underline:SetPoint("BOTTOMRIGHT",-4,0) end end
    for _,tab in ipairs(self.previewTabs or {}) do if tab.underline then tab.appearanceStamp=nil;tab.underline:ClearAllPoints();tab.underline:SetPoint("BOTTOMLEFT",4,0);tab.underline:SetPoint("BOTTOMRIGHT",-4,0) end end
    self.tabScroll:SetVerticalScroll(0);if self.previewTabScroll then self.previewTabScroll:SetVerticalScroll(0) end
  end
end
function W:LayoutHub()
  layout(self)
  if self:IsConversationList() and self.hub and not self.collapseAnimation then
    self:PositionConversationBody();self:LayoutConversationStrip(not not self.previewActive);self:LayoutPeopleRows(not not self.previewActive)
  end
end
function W:PresentCollapsedHeader()
  collapsed(self)
  if self:IsConversationList() then
    self:LayoutConversationStrip(not not self.previewActive)
    self.hubChrome:Show();self.hubChrome:SetAlpha(1)
    if self.previewFrame then self.previewFrame:SetShown(self.previewActive and not self.minimized) end
    if self.minimized and not self.collapseAnimation then self.hubContent:Hide();if self.previewBody then self.previewBody:Hide() end end
    self.hubTitle:SetPoint("RIGHT",self.hubChrome,"RIGHT",-(self.headerActionWidth or 160)-100-self:HeaderPadding(),0)
  end
end
function W:PresentWindowBody(shown,alpha)
  body(self,shown,alpha)
  if self:IsConversationList() then
    if self.whisperSurface then self.whisperSurface:SetShown(shown);self.whisperSurface:SetAlpha(alpha or 1) end
    local scroll=scrollFor(self,not not self.previewActive)
    if scroll then scroll:SetShown(shown);scroll:SetAlpha(alpha or 1) end
    -- Hiding the list must not hide the independent header navigation.
    local nav=self.previewActive and self.previewNavigation or self.conversationNavigation
    if nav then nav:Show() end
  end
end
