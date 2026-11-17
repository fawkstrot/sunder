local Core, Constants = unpack(select(2, ...))
local W = Core:GetModule("Whispers")

-- One set of person controls serves both layouts; real chat renderers/editors stay native.
function W:IsConversationList() return self:Settings().conversationLayout ~= "tabs" end
function W:ConversationListWidth()
  local width = self.hub and self.hub:GetWidth() or self:HubSettings().hubWidth or 540
  return Core.Components.WindowManager:PeopleSidebarWidth(width)
end
function W:ConversationBodyLeft() return self:ConversationListWidth() + self:HeaderGap() end
function W:ConversationRowHeight() return Core.Components.WindowManager:PersonRowHeight(self) end
function W:ConversationRowStep() return self:ConversationRowHeight() end
local function scrollFor(host, preview)
  if preview then return host.previewTabScroll,host.previewTabChild end
  return host.tabScroll,host.tabChild
end
local function listFor(host, preview) return preview and host.previewConversations or host.hubOrder end
local function verticalMaximum(scroll, child) return math.max(0, child:GetHeight() - scroll:GetHeight()) end

local singleRow, contentTop, previewTop, previewBodyTop, tabWidth = W.SingleRowHeader, W.ContentTop, W.PreviewTop, W.PreviewBodyTop, W.TabWidth
function W:SingleRowHeader() return not self:IsConversationList() and singleRow(self) end
function W:ContentTop() return self:IsConversationList() and 0 or contentTop(self) end
function W:PreviewTop() return self:IsConversationList() and 0 or previewTop(self) end
function W:PreviewBodyTop() return self:IsConversationList() and self:HeaderHeight() + self:HeaderGap() or previewBodyTop(self) end
function W:TabWidth() return self:IsConversationList() and self:ConversationListWidth() - self:BodyPadding() - Core.Components.WindowManager:ScrollRightInset(self:BodyPadding()) or tabWidth(self) end

local strip = W.LayoutConversationStrip
function W:LayoutConversationStrip(preview)
  if not self:IsConversationList() then return strip(self, preview) end
  local scroll = scrollFor(self, preview)
  if not scroll then return end
  scroll:ClearAllPoints()
  local top = self:HeaderHeight() + self:HeaderGap() + (self.PeopleFilterHeight and self:PeopleFilterHeight() or 0)
  scroll:SetPoint("TOPLEFT", self.hub, "TOPLEFT", 0, -top)
  -- A collapsed root is shorter than these insets. Never anchor a ScrollFrame
  -- across that inverted rectangle, including the first frames of restoration.
  scroll:SetHeight(self.minimized and not self.collapseAnimation and 1 or math.max(1,self.hub:GetHeight()-top))
  scroll:SetWidth(self:ConversationListWidth())
  scroll:SetShown((not self.minimized or self.collapseAnimation) and (preview and self.previewActive or not preview and not self.previewActive))
  -- The unread counter and picker stay in the title bar, never adds a second row above the body.
  local nav = preview and self.previewNavigation or self.conversationNavigation
  if nav then
    nav:ClearAllPoints(); nav:SetPoint("RIGHT", self.hubChrome, "RIGHT", -(self.headerActionWidth or 160), 0)
    nav:SetSize(self:NavigationWidth(),self:HeaderHeight())
    nav.all:ClearAllPoints();nav.all:SetPoint("CENTER",nav,"CENTER")
    Core.Components.WindowManager:LayoutUnreadIndicator(nav.all,self:NavigationWidth(),self:HeaderHeight(),math.min(14,self:ToolbarIconSize()))
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
  if not self:IsConversationList()then
    if tab.personDetails then tab.personDetails:Hide()end;if tab.separator then tab.separator:Hide()end
    if tab.unread then tab.unread:ClearAllPoints();tab.unread:SetPoint("RIGHT",tab,"RIGHT",-5,0)end
    return styleTab(self,tab)
  end
  tab:SetWidth(self:TabWidth())
  self:LayoutPersonDetails(tab)
end
function W:SetTabAppearance(tab,selected,unread)
  if not self:IsConversationList()then return tabAppearance(self,tab,selected,unread)end
  tab.rowSelected=not not selected;tab.rowUnread=not not unread
  self:StyleConversationTab(tab)
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
      if self.LayoutPersonDetails then
        local record=tab.pinRecord
        self:LayoutPersonDetails(tab,record and (record.target or record.key),preview and tab.previewBound or nil)
      end
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

local navigation, revealNative, revealSample = W.RefreshConversationNavigation, W.EnsureHubTabVisible, W.EnsurePreviewTabVisible
function W:RefreshConversationNavigation(preview)
  if not self:IsConversationList() then return navigation(self, preview) end
  local nav = preview and self.previewNavigation or self.conversationNavigation
  if not nav then return end
  local scroll, child = scrollFor(self, preview)
  local pos = math.max(0, math.min(verticalMaximum(scroll,child), scroll:GetVerticalScroll()))
  self:UpdatePeopleScrollIndicator(scroll,child)
  scroll:SetVerticalScroll(pos)
  local count, unread, hidden = 0,0,0
  for i, item in ipairs(listFor(self,preview) or {}) do
    local record = preview and item or W.records[item]
    local n = record and record.unread or 0
    count=count+1; unread=unread+n
    local top=(i-1)*self:ConversationRowStep()
    if n>0 and (self.minimized or top<pos or top+self:ConversationRowHeight()>pos+scroll:GetHeight()) then hidden=hidden+1 end
  end
  nav.total,nav.unreadTotal,nav.hiddenUnread=count,unread,hidden
  local r,g,b=self:InterfaceAccent()
  Core.Components.WindowManager:StyleUnreadIndicator(nav.all,unread,r,g,b)
  nav.all:SetEnabled(count>0)
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
    return
  end

end
function W:PositionConversationBody()
  if not self.previewBody or not self:IsConversationList() then return end
  if self.minimized and not self.collapseAnimation then
    self.previewBody:Hide()
    return
  end
  self.previewFrame:ClearAllPoints();self.previewFrame:SetPoint("TOPLEFT",self.hub,"TOPLEFT");self.previewFrame:SetPoint("BOTTOMRIGHT",self.hub,"BOTTOMRIGHT")
  local top=self:HeaderHeight()+self:HeaderGap()+(self.PeopleFilterHeight and self:PeopleFilterHeight() or 0)
  self.previewBody:ClearAllPoints();self.previewBody:SetPoint("TOPLEFT",self.hub,"TOPLEFT",self:ConversationBodyLeft()+self:BodyPadding(),-top-self:BodyPadding())
  self.previewBody:SetPoint("TOPRIGHT",self.hub,"TOPRIGHT",-Core.Components.WindowManager:ScrollRightInset(self:BodyPadding()),-top-self:BodyPadding())
  self.previewBody:SetHeight(math.max(1,self.hub:GetHeight()-top-self:BodyPadding()*2))
end
function W:ApplyWorkspaceMetrics()
  metrics(self)
  if self:IsConversationList() then
    self.hubTitle:SetPoint("RIGHT",self.hubChrome,"RIGHT",-(self.headerActionWidth or 160)-self:NavigationWidth()-self:HeaderPadding(),0)
    self:PositionConversationBody();self:LayoutConversationStrip(false);self:LayoutConversationStrip(true)
    self:LayoutPeopleRows(not not self.previewActive)
  else
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
    if self.previewFrame then self.previewFrame:SetShown(self.previewActive and (not self.minimized or self.collapseAnimation)) end
    if self.minimized and not self.collapseAnimation then self.hubContent:Hide();if self.previewBody then self.previewBody:Hide() end end
    self.hubTitle:SetPoint("RIGHT",self.hubChrome,"RIGHT",-(self.headerActionWidth or 160)-self:NavigationWidth()-self:HeaderPadding(),0)
  end
end
function W:PresentWindowBody(shown,alpha)
  body(self,shown,alpha)
  if self:IsConversationList() then
    local scroll=scrollFor(self,not not self.previewActive)
    if scroll then scroll:SetShown(shown);scroll:SetAlpha(alpha or 1) end
    -- Hiding the list must not hide the independent header navigation.
    local nav=self.previewActive and self.previewNavigation or self.conversationNavigation
    if nav then nav:Show() end
  end
end

local function plain(value)return type(value)=="string" and (not _G.canaccessvalue or _G.canaccessvalue(value)) and value or nil end
-- Retain only bounded last-known identity, never roster presence or public notes.
function W:RememberPersonDetails(name,person)
  name=plain(name);if not name or not person or not Core.db then return end
  local key=name:lower();local token=plain(person.classFile);local class=plain(person.class)
  local level=person.level
  if _G.canaccessvalue and not _G.canaccessvalue(level)then level=nil end
  if type(level)~="number" or level<=0 or level>1000 then level=nil end
  if not level and not token and not class then return end
  local cache=Core.db.char.whisperPersonDetails or {};Core.db.char.whisperPersonDetails=cache
  local old=cache[key]or {}
  if old.level==(level or old.level) and old.classFile==(token and token~="" and token or old.classFile) and old.class==(class and class~="" and class or old.class) and old.name==name then return end
  cache[key]={name=name,level=level or old.level,classFile=token and token~="" and token or old.classFile,class=class and class~="" and class or old.class,
    updated=(_G.time and time())or 0}
  local count=0;local oldest,stamp
  for id,entry in pairs(cache)do count=count+1;if id~=key and (not stamp or (entry.updated or 0)<stamp)then oldest,stamp=id,entry.updated or 0 end end
  if count>200 and oldest then cache[oldest]=nil end
end
function W:PersonDetails(name)
  name=plain(name);if not name then return end
  local key=name:lower()
  local party=Core:GetModule("PartyChat",true)
  if party and party.grouped then
    for _,member in ipairs(party.members or {})do
      if member.key==key then return member end
    end
  end
  local guild=Core:GetModule("GuildChat",true)
  if guild and guild.memberByName and guild.memberByName[key]then
    local member=guild.memberByName[key];self:RememberPersonDetails(member.name or name,member)
    local saved=Core.db.char.whisperPersonDetails and Core.db.char.whisperPersonDetails[key]
    return {name=member.name,level=member.level and member.level>0 and member.level or saved and saved.level,classFile=plain(member.classFile) and member.classFile~="" and member.classFile or saved and saved.classFile,class=member.class,online=member.online}
  end
  local known=W.personMetadata and W.personMetadata[key]
  if known then return known end
  local saved=Core.db.char.whisperPersonDetails and Core.db.char.whisperPersonDetails[key]
  if saved then return saved end
  local token=W.whisperClasses and W.whisperClasses[key]
  if token then return {classFile=token,class=(_G.LOCALIZED_CLASS_NAMES_MALE or {})[token] or token}end
end
function W:LayoutPersonDetails(row,name,person)
  local record=row.pinRecord
  local preview=row.previewBound
  name=name or record and (record.target or record.key)
  local frame=record and record.frame
  local favorite
  if preview then favorite=preview.favorite elseif frame then favorite=W:IsFavorite(frame)else favorite=row.savedFavorite end
  local onFavorite=preview and function()self:PreviewAction("Favorite",preview)end or frame and function()W:ToggleFavorite(frame)end or row.savedFavoriteAction
  local onPin=preview and function()self:PreviewAction("Pin",preview)end or frame and function()W:ToggleConversationPin(frame)end or row.savedPinAction
  person=person or preview or self:PersonDetails(name)
  local label=row:GetFontString()
  local token=person and (person.classFile or person.classToken)
  local color=token and ((_G.CUSTOM_CLASS_COLORS or _G.RAID_CLASS_COLORS or {})[token])
  if label then
    local r,g,b=self:ConversationLabelColor(row.rowSelected,frame or preview)
    Core.Components.WindowManager:StylePersonName(label,color and color.r or r,color and color.g or g,color and color.b or b,person and person.online)
  end
  Core.Components.WindowManager:LayoutPersonRow(self,row,{identity=preview or frame or row.contact and (row.contact.archiveKey or row.contact.key),person=person,selected=row.rowSelected,unread=row.rowUnread,
    unreadCount=self:Settings().unreadBadges and ((preview or record or {}).unread or 0) or 0,
    favorite=favorite,pinned=(preview or record or {}).pinned or row.savedPinned,onFavorite=onFavorite,onPin=onPin})
end
function W:RefreshPersonMetadata()
  W.personMetadata={}
  local api=_G.C_FriendList
  local count=api and api.GetNumFriends or _G.GetNumFriends
  local get=api and api.GetFriendInfoByIndex
  if count then
    local ok,n=pcall(count)
    if ok and type(n)=="number" then for i=1,math.min(200,n)do
      local name,level,class,online
      if get then
        local success,info=pcall(get,i)
        if success and type(info)=="table"then name,level,class,online=info.name,info.level,info.className,info.connected end
      elseif _G.GetFriendInfo then
        local success,a,b,c,_,e=pcall(GetFriendInfo,i)
        if success then name,level,class,online=a,b,c,e end
      end
      name,class=plain(name),plain(class)
      if name then
        local token
        for _,names in ipairs({_G.LOCALIZED_CLASS_NAMES_MALE or {},_G.LOCALIZED_CLASS_NAMES_FEMALE or {}})do
          for id,localized in pairs(names)do if localized==class then token=id;break end end
        end
        local accessible=not _G.canaccessvalue or _G.canaccessvalue(level)
        local connected
        if (not _G.canaccessvalue or _G.canaccessvalue(online)) and type(online)=="boolean"then connected=online end
        self:RememberPersonDetails(name,{level=accessible and type(level)=="number" and level or nil,class=class,classFile=token})
        local saved=Core.db.char.whisperPersonDetails and Core.db.char.whisperPersonDetails[name:lower()] or {}
        W.personMetadata[name:lower()]={level=saved.level,class=saved.class,classFile=saved.classFile,online=connected}
      end
    end end
  end
  self:QueuePersonRefresh()
end
function W:QueuePersonRefresh()
  if W.personRefreshPending then return end
  W.personRefreshPending=true
  C_Timer.After(0,function()
    W.personRefreshPending=nil
    for _,host in pairs(W.workspaces or {W})do if host.hub and host.hub:IsShown()then host:LayoutPeopleRows(not not host.previewActive)end end
  end)
end
function W:EnablePersonMetadata()
  if self.personMetadataEvents then return end
  local events=CreateFrame("Frame");self.personMetadataEvents=events
  events:RegisterEvent("FRIENDLIST_UPDATE")
  events:SetScript("OnEvent",function()W:RefreshPersonMetadata()end)
  self:RefreshPersonMetadata()
end
