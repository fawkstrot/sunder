local Core = unpack(select(2,...))
local W = Core:GetModule("Whispers")
Core.defaults.profile.whispers.singleToasterStack=true

function W:UsesUnifiedPeople()
  return self.hostId=="messages" and self:IsConversationList()
end
local function data(host,preview)
  if preview then return host.previewConversations or {},host.previewTabs or {},host.previewTabScroll,host.previewTabChild end
  return host.hubOrder or {},host.hubTabs or {},host.tabScroll,host.tabChild
end
local function favorite(item,preview) return preview and item.favorite or not preview and W:IsFavorite(item) end
local function unread(item,preview) return preview and (item.unread or 0) or (W.records[item] or {}).unread or 0 end

local tabWidth=W.TabWidth
function W:TabWidth()
  if self:UsesUnifiedPeople() then return self:ConversationListWidth()-self:BodyPadding()*2 end
  return tabWidth(self)
end

function W:OpenFavoritesView()
  W:OpenMessages();W:SetPeopleFilter("favorites")
end
function W:SetPeopleFilter(value)
  self.hubOpenedAt=GetTime();self.lastUserInteraction=GetTime()
  self.peopleFilter=value or "all"
  local preview=not not self.previewActive
  local _,_,scroll=data(self,preview)
  if scroll then scroll:SetVerticalScroll(0) end
  self:LayoutConversationStrip(preview)
  self:LayoutPeopleRows(preview);self:RefreshConversationNavigation(preview)
end
local ICONS="Interface\\AddOns\\Sunder\\Media\\Icons\\"
function W:StylePeopleFilter(button)
  local active=(self.peopleFilter or "all")==button.key
  local hover=button.hovered
  local r,g,b=self:InterfaceAccent()
  button.plate:SetColorTexture(active and r or 1,active and g or 1,active and b or 1,active and .075 or hover and .035 or 0)
  button.indicator:SetColorTexture(r,g,b,active and .8 or 0)
  button.icon:SetVertexColor(active and r or hover and .9 or .58,active and g or hover and .92 or .63,active and b or hover and .96 or .70)
  button:GetFontString():SetTextColor(active and .97 or .68,active and .88 or .72,active and .67 or .78)
  if button.counter then
    local hasUnread=(button.unreadTotal or 0)>0
    button.counter:SetTextColor(hasUnread and 1 or .45,hasUnread and .80 or .50,hasUnread and .30 or .57)
  end
end
function W:EnsurePeopleFilters()
  if self.peopleFilters then return end
  local bar=CreateFrame("Frame",nil,self.hub);self.peopleFilters=bar
  bar:SetHeight(26)
  local track=bar:CreateTexture(nil,"BACKGROUND");track:SetAllPoints();track:SetColorTexture(0,0,0,0)
  bar.buttons={}
  for index,item in ipairs({{"all","All whispers","inbox"},{"unread","Unread whispers","read"},{"favorites","Favorites","favorite"}}) do
    local key,label,icon=item[1],item[2],item[3]
    local b=CreateFrame("Button",nil,bar);bar.buttons[index]=b
    b.key=key;b.accessibleLabel=label
    b:SetNormalFontObject("SunderChatDockFont");b:SetText(" ");b:GetFontString():SetWordWrap(false)
    b.plate=b:CreateTexture(nil,"BACKGROUND");b.plate:SetAllPoints()
    b.indicator=b:CreateTexture(nil,"OVERLAY");b.indicator:SetPoint("BOTTOMLEFT",8,0);b.indicator:SetPoint("BOTTOMRIGHT",-8,0);b.indicator:SetHeight(1)
    b.icon=b:CreateTexture(nil,"ARTWORK");b.icon:SetTexture(ICONS..icon..".tga");b.icon:SetSize(12,12)
    if key=="unread" then
      b.counter=b:CreateFontString(nil,"OVERLAY","SunderChatDockFont")
      b.counter:SetText("0");b.counter:SetJustifyH("LEFT")
    end
    b:SetScript("OnClick",function() self:SetPeopleFilter(key) end)
    b:SetScript("OnEnter",function()
      b.hovered=true;self:StylePeopleFilter(b)
      GameTooltip:SetOwner(b,"ANCHOR_TOP");GameTooltip:AddLine(label,1,1,1)
      if key=="unread" then GameTooltip:AddLine((b.unreadTotal or 0).." unread messages",1,.8,.35) end
      GameTooltip:AddLine(key=="all" and "Every conversation, with favorites first." or key=="unread" and "People with messages you have not read." or "Starred people and saved contacts.",.7,.75,.8);GameTooltip:Show()
    end)
    b:SetScript("OnLeave",function() b.hovered=nil;self:StylePeopleFilter(b);GameTooltip:Hide() end)
    b:SetScript("OnMouseDown",function() b.icon:SetAlpha(.65) end)
    b:SetScript("OnMouseUp",function() b.icon:SetAlpha(1) end)
  end
end
function W:RefreshPeopleFilterCounts()
  if not self.peopleFilters then return end
  local list=data(self,not not self.previewActive)
  local total=0
  for _,person in ipairs(list) do total=total+unread(person,not not self.previewActive) end
  for _,button in ipairs(self.peopleFilters.buttons) do
    if button.counter then
      button.unreadTotal=total
      button.counter:SetText(total>99 and "99+" or tostring(total))
      self:StylePeopleFilter(button)
    end
  end
end
local contentTop=W.ContentTop
function W:ContentTop() return contentTop(self)+(self:UsesUnifiedPeople() and 32 or 0) end
local positionBody=W.PositionConversationBody
function W:PositionConversationBody()
  positionBody(self)
  if not self:UsesUnifiedPeople() or not self.previewBody or self.minimized then return end
  local top=self:HeaderHeight()+self:HeaderGap()+32
  self.previewBody:ClearAllPoints()
  self.previewBody:SetPoint("TOPLEFT",self.hub,"TOPLEFT",self:ConversationBodyLeft()+self:BodyPadding(),-top-self:BodyPadding())
  self.previewBody:SetPoint("TOPRIGHT",self.hub,"TOPRIGHT",-self:BodyPadding(),-top-self:BodyPadding())
  self.previewBody:SetHeight(math.max(1,self.hub:GetHeight()-top-self:BodyPadding()*2))
end
local paint=W.ApplyHubAppearance
function W:ApplyHubAppearance()
  paint(self)
  if self:UsesUnifiedPeople() and self.whisperSurface then
    local top=self:HeaderHeight()+self:HeaderGap()
    self.whisperSurface:ClearAllPoints();self.whisperSurface:SetPoint("TOPLEFT",self.hub,"TOPLEFT",0,-top)
    self.whisperSurface:SetPoint("TOPRIGHT",self.hub,"TOPRIGHT",0,-top)
    self.whisperSurface:SetHeight(math.max(1,self.hub:GetHeight()-top))
  end
end
local strip=W.LayoutConversationStrip
function W:LayoutConversationStrip(preview)
  strip(self,preview)
  if not self.hub then return end
  if not self:UsesUnifiedPeople() then if self.peopleFilters then self.peopleFilters:Hide() end;return end
  self:EnsurePeopleFilters()
  local bar=self.peopleFilters
  local top=self:HeaderHeight()+self:HeaderGap()
  bar:ClearAllPoints();bar:SetPoint("TOPLEFT",self.hub,"TOPLEFT",0,-top);bar:SetWidth(math.max(1,self.hub:GetWidth()))
  bar:SetShown(not self.minimized)
  self:RefreshPeopleFilterCounts()
  local width=bar:GetWidth()/3
  for i,b in ipairs(bar.buttons) do
    b:ClearAllPoints();b:SetPoint("TOPLEFT",(i-1)*width,0);b:SetSize(width,26)
    local size=math.max(10,self:InterfaceTextSize()-1)
    local text=b:GetFontString()
    self:WorkspaceFont(text,size)
    b:SetText(b.key=="all" and "All" or b.key=="unread" and "Unread" or "Favorites")
    local labelWidth=text.GetUnboundedStringWidth and text:GetUnboundedStringWidth() or text.GetStringWidth and text:GetStringWidth() or #text:GetText()*size*.55
    local counterWidth=0
    if b.counter then
      self:WorkspaceFont(b.counter,size-1)
      counterWidth=(b.counter.GetStringWidth and b.counter:GetStringWidth() or #b.counter:GetText()*(size-1)*.55)+6
    end
    local total=12+5+labelWidth+counterWidth
    b.icon:ClearAllPoints();b.icon:SetPoint("LEFT",b,"CENTER",-total/2,0)
    text:ClearAllPoints();text:SetPoint("LEFT",b.icon,"RIGHT",5,0);text:SetWidth(labelWidth+1);text:SetJustifyH("LEFT")
    if b.counter then b.counter:ClearAllPoints();b.counter:SetPoint("LEFT",text,"RIGHT",5,0) end
    self:StylePeopleFilter(b)
  end
  local _,_,scroll=data(self,preview)
  if scroll then
    scroll:ClearAllPoints();scroll:SetPoint("TOPLEFT",self.hub,"TOPLEFT",0,-top-32)
    scroll:SetHeight(math.max(1,self.hub:GetHeight()-top-32))
  end
end
local function section(host,child,key,label,y,count,new)
  host.peopleSections=host.peopleSections or {}
  local b=host.peopleSections[key]
  if not b then
    b=CreateFrame("Button",nil,child);host.peopleSections[key]=b
    b:SetNormalFontObject("SunderChatDockFont")
    b.icon=b:CreateTexture(nil,"ARTWORK");b.icon:SetSize(12,12);b.icon:SetPoint("LEFT",2,0)
    b.chevron=b:CreateTexture(nil,"ARTWORK");b.chevron:SetTexture(ICONS.."right.tga");b.chevron:SetSize(10,10);b.chevron:SetPoint("RIGHT",-2,0)
    b.count=b:CreateFontString(nil,"OVERLAY","SunderChatDockFont");b.count:SetPoint("RIGHT",b.chevron,"LEFT",-8,0)
    b.count:SetJustifyH("RIGHT")
    b:SetHighlightTexture("Interface\\Buttons\\WHITE8X8");b:GetHighlightTexture():SetVertexColor(1,1,1,.035)
    b:SetScript("OnClick",function()
      host.hubOpenedAt=GetTime();host.lastUserInteraction=GetTime()
      host.peopleCollapsed=host.peopleCollapsed or {};host.peopleCollapsed[key]=not host.peopleCollapsed[key]
      host:LayoutPeopleRows(not not host.previewActive);host:RefreshConversationNavigation(not not host.previewActive)
    end)
    b:SetScript("OnEnter",function()
      GameTooltip:SetOwner(b,"ANCHOR_RIGHT");GameTooltip:AddLine(label,1,1,1)
      GameTooltip:AddLine((b.peopleCount or 0).." people · "..(b.unreadCount or 0).." unread messages",.7,.75,.8)
      GameTooltip:AddLine("Click to collapse or expand",.7,.75,.8);GameTooltip:Show()
    end)
    b:SetScript("OnLeave",function() GameTooltip:Hide() end)
  end
  b.peopleCount=count;b.unreadCount=new
  local pad=host:BodyPadding()
  b:SetParent(child);b:ClearAllPoints();b:SetPoint("TOPLEFT",pad,-y)
  b:SetSize(host:ConversationListWidth()-pad*2,24);b:SetText(label)
  b.icon:SetTexture(ICONS..(key=="favorites" and "favorite" or "inbox")..".tga");b.icon:SetVertexColor(.68,.63,.49)
  b.chevron:SetRotation(host.peopleCollapsed and host.peopleCollapsed[key] and 0 or -math.pi/2);b.chevron:SetVertexColor(.55,.59,.66)
  local text=b:GetFontString();text:ClearAllPoints();text:SetPoint("LEFT",b.icon,"RIGHT",6,0);text:SetPoint("RIGHT",b.count,"LEFT",-8,0);text:SetJustifyH("LEFT");text:SetWordWrap(false)
  text:SetTextColor(.68,.71,.77)
  b.count:SetText(new>0 and tostring(new) or tostring(count));b.count:SetTextColor(new>0 and 1 or .44,new>0 and .80 or .49,new>0 and .30 or .57)
  host:WorkspaceFont(text,math.max(10,host:InterfaceTextSize()-1));host:WorkspaceFont(b.count,math.max(10,host:InterfaceTextSize()-2));b:Show()
  return y+30
end
function W:OpenSavedFavorite(contact)
  for frame,r in pairs(W.records or {}) do
    if frame.inUse and r.key==contact.key then W:SelectConversation(frame,false);return end
  end
  if InCombatLockdown() or not FCF_OpenTemporaryWindow then return end
  local ok,frame=pcall(FCF_OpenTemporaryWindow,"WHISPER",contact.target,nil,false)
  if ok and frame then C_Timer.After(0,function()
    if frame.inUse and W:Key(frame)==contact.key then W:MoveToWorkspace(frame,"messages") end
  end) end
end
local layout=W.LayoutPeopleRows
function W:LayoutPeopleRows(preview)
  if self:UsesUnifiedPeople() and not not preview~=not not self.previewActive then return end
  layout(self,preview)
  if not self:UsesUnifiedPeople() then
    for _,b in pairs(self.peopleSections or {}) do b:Hide() end
    if self.peopleEmpty then self.peopleEmpty:Hide() end
    for _,b in ipairs(self.savedFavoriteRows or {}) do b:Hide() end
    return
  end
  local list,tabs,scroll,child=data(self,preview)
  self:RefreshPeopleFilterCounts()
  if not child then return end
  local pad=self:BodyPadding()
  local groups={favorites={},conversations={}};local active={}
  local filter=self.peopleFilter or "all"
  for i,item in ipairs(list) do
    local tab=preview and tabs[i] or tabs[item]
    if tab then tab:Hide() end
    local r=not preview and W.records[item]
    if r and r.key then active[r.key]=true end
    local fav=favorite(item,preview)
    if filter=="all" or filter=="unread" and unread(item,preview)>0 or filter=="favorites" and fav then
      local group=groups[fav and "favorites" or "conversations"]
      group[#group+1]={item=item,index=i,tab=tab}
    end
  end
  local contacts={}
  if not preview and filter~="unread" then
    for key,target in pairs(Core.db.char.whisperFavorites or {}) do
      if type(target)=="string" and not active[key] then contacts[#contacts+1]={key=key,target=target} end
    end
    table.sort(contacts,function(a,b)return a.target:lower()<b.target:lower() end)
  end
  self.peopleOffsets={};self.peopleVisualOrder={};self.savedFavoriteRows=self.savedFavoriteRows or {}
  for _,b in pairs(self.peopleSections or {}) do b:Hide() end
  for _,b in ipairs(self.savedFavoriteRows) do b:Hide() end
  local y,step=pad,self:ConversationRowStep()
  for _,key in ipairs({"favorites","conversations"}) do
    local group=groups[key];local count=#group+(key=="favorites" and #contacts or 0)
    if count>0 then
      if y>pad then y=y+10 end
      local new=0;for _,entry in ipairs(group) do new=new+unread(entry.item,preview) end
      y=section(self,child,key,key=="favorites" and "Favorites" or "Conversations",y,count,new)
      if not (self.peopleCollapsed and self.peopleCollapsed[key]) then
        for _,entry in ipairs(group) do
          self.peopleOffsets[entry.index]=y
          self.peopleVisualOrder[#self.peopleVisualOrder+1]={index=entry.index,y=y}
          if entry.tab then
            entry.tab:ClearAllPoints();entry.tab:SetPoint("TOPLEFT",child,"TOPLEFT",pad,-y);entry.tab:Show()
          end
          y=y+step
        end
        if key=="favorites" then for i,contact in ipairs(contacts) do
          local b=self.savedFavoriteRows[i]
          if not b then
            b=CreateFrame("Button",nil,child);self.savedFavoriteRows[i]=b
            b:SetNormalFontObject("SunderChatDockFont")
            b:SetHighlightTexture("Interface\\Buttons\\WHITE8X8");b:GetHighlightTexture():SetVertexColor(1,1,1,.06)
            b:SetScript("OnClick",function(button) W:OpenSavedFavorite(button.contact) end)
            b:SetScript("OnEnter",function(button)
              GameTooltip:SetOwner(button,"ANCHOR_RIGHT");GameTooltip:AddLine(button.contact.target,1,1,1)
              GameTooltip:AddLine("Open conversation — no message is sent",.7,.75,.8);GameTooltip:Show()
            end)
            b:SetScript("OnLeave",function()GameTooltip:Hide()end)
          end
          b.contact=contact;b:ClearAllPoints();b:SetPoint("TOPLEFT",child,"TOPLEFT",pad,-y)
          b:SetSize(self:TabWidth(),self:ConversationRowHeight());b:SetText("|TInterface\\AddOns\\Sunder\\Media\\Icons\\favorite.tga:12:12:0:0|t "..(W.whisperNames and W.whisperNames[contact.key] or contact.target))
          b:GetFontString():SetJustifyH("LEFT");b:GetFontString():SetTextColor(.62,.65,.70)
          self:WorkspaceFont(b:GetFontString(),self:InterfaceTextSize());b:Show();y=y+step
        end end
      end
    end
  end
  if not self.peopleEmpty then self.peopleEmpty=child:CreateFontString(nil,"OVERLAY","SunderChatDockFont") end
  local empty=self.peopleEmpty;empty:SetParent(child);empty:ClearAllPoints();empty:SetPoint("TOPLEFT",pad,-pad)
  empty:SetWidth(self:TabWidth());empty:SetJustifyH("LEFT");empty:SetTextColor(.48,.53,.61)
  self:WorkspaceFont(empty,math.max(10,self:InterfaceTextSize()-1))
  empty:SetText(filter=="unread" and "No unread whispers" or filter=="favorites" and "No favorites yet.\nStar a conversation to save it here." or "Your conversations appear here.")
  empty:SetShown(y==pad)
  child:SetHeight(math.max(y==pad and 60 or 1,y+pad))
  scroll:SetVerticalScroll(math.max(0,math.min(scroll:GetVerticalScroll(),y+pad-scroll:GetHeight())))
end
local reveal=W.RevealPerson
function W:RevealPerson(preview,index)
  if not self:UsesUnifiedPeople() then return reveal(self,preview,index) end
  local list,_,scroll=data(self,preview);local person=list[index]
  if not person or not scroll then return end
  local key=favorite(person,preview) and "favorites" or "conversations"
  if not self.peopleOffsets or self.peopleOffsets[index]==nil then
    if not self.explicitPeopleNavigation then return end
    self.peopleFilter="all";self.peopleCollapsed=self.peopleCollapsed or {};self.peopleCollapsed[key]=nil
    self:LayoutConversationStrip(preview)
    self:LayoutPeopleRows(preview)
  end
  local y=self.peopleOffsets[index]
  if not y then return end
  local position=scroll:GetVerticalScroll()
  if y<position then scroll:SetVerticalScroll(y)
  elseif y+self:ConversationRowHeight()>position+scroll:GetHeight() then scroll:SetVerticalScroll(math.max(0,y+self:ConversationRowHeight()-scroll:GetHeight())) end
  self:RefreshConversationNavigation(preview)
end
local insertion=W.TabInsertionIndex
function W:TabInsertionIndex(preview,x,y)
  if not self:UsesUnifiedPeople() then return insertion(self,preview,x,y) end
  local list,_,scroll=data(self,preview)
  if not y then local cursorX;cursorX,y=GetCursorPosition() end
  local offset=scroll:GetTop()-y/scroll:GetEffectiveScale()+scroll:GetVerticalScroll()
  for _,entry in ipairs(self.peopleVisualOrder or {}) do
    if offset<entry.y+self:ConversationRowHeight()/2 then return entry.index end
  end
  return #list+1
end
local marker=W.ShowTabInsertion
function W:ShowTabInsertion(preview,index)
  marker(self,preview,index)
  if self:UsesUnifiedPeople() and self.tabInsertion and self.peopleOffsets and self.peopleOffsets[index] then
    local _,_,scroll=data(self,preview)
    self.tabInsertion:ClearAllPoints();self.tabInsertion:SetPoint("TOPLEFT",scroll,"TOPLEFT",self:HeaderPadding(),-math.max(0,math.min(scroll:GetHeight()-2,self.peopleOffsets[index]-scroll:GetVerticalScroll())))
  end
end

-- One notification owner; entries still point to their actual conversation/window.
local queue=W.QueueMinimizedWhisper
function W:QueueMinimizedWhisper(person,sample,...)
  if sample then
    local host=person.host
    if host and not host.minimized and host.hub and host.hub:IsShown() and host.previewConversations and host.previewConversations[host.previewSelected or 1]==person then return end
  elseif W:IsConversationDisplayed(person) then return end
  W:EnsureHub()
  return queue(W,person,sample,...)
end
local updateToasts=W.UpdateMinimizedWhispers
function W:UpdateMinimizedWhispers()
  if self~=W then
    if self.minimizedWhisperTray then self.minimizedWhisperTray:Hide() end
    if self.minimizedWhispers and #self.minimizedWhispers>0 then
      W.minimizedWhispers=W.minimizedWhispers or {}
      for _,entry in ipairs(self.minimizedWhispers) do W.minimizedWhispers[#W.minimizedWhispers+1]=entry end
      self.minimizedWhispers={}
      table.sort(W.minimizedWhispers,function(a,b)return a.received>b.received end)
      while #W.minimizedWhispers>50 do table.remove(W.minimizedWhispers) end
    end
    return
  end
  if self.hub then updateToasts(self) end
end
-- Retire the old standalone Favorites workspace without discarding people or history.
-- Runs before windows restore; legacy callers are canonicalized by GetWorkspace.
function W:MigrateFavoritesWorkspace()
  local char=Core.db.char
  self:Settings().favoritesSeparate=nil
  self:Settings().unifiedFavoritesMigrated=nil
  for _,saved in pairs(char.whisperLayouts or {}) do
    if saved.workspace=="favorites" then saved.workspace="messages" end
  end
  local orders=char.messageTabOrders
  if orders and orders.favorites then
    local merged,seen={},{}
    for _,list in ipairs({orders.messages or {},orders.favorites}) do
      for _,key in ipairs(list) do if not seen[key] then merged[#merged+1]=key;seen[key]=true end end
    end
    orders.messages=merged;orders.favorites=nil
  end
  for _,states in pairs({char.messageWindowStates or {},W.pendingWindowStates or {}}) do
    local old=states.favorites
    if old and old.open and not states.messages then states.messages={open=true,minimized=false} end
    states.favorites=nil
  end
  if W.managedWorkspace=="favorites" then W.managedWorkspace="messages" end
  local previous=W.workspaces and W.workspaces.favorites
  local reopen=previous and previous.hub and previous.hub:IsShown()
  local move={}
  for frame,r in pairs(W.records or {}) do
    if r.workspace=="favorites" then move[#move+1]=frame end
  end
  -- Layout changes are deferred in combat; saved state is already canonical.
  if #move>0 and InCombatLockdown() then
    if not W.favoritesMigrationEvent then
      W.favoritesMigrationEvent=CreateFrame("Frame")
      W.favoritesMigrationEvent:SetScript("OnEvent",function(frame)
        frame:UnregisterAllEvents();W:MigrateFavoritesWorkspace()
      end)
    end
    W.favoritesMigrationEvent:RegisterEvent("PLAYER_REGEN_ENABLED")
    return
  end
  for _,frame in ipairs(move) do
    local r=W.records[frame]
    if previous and previous.hubTabs and previous.hubTabs[frame] then
      previous.hubTabs[frame]:Hide();previous.hubTabs[frame]=nil
      for i=#(previous.hubOrder or {}),1,-1 do if previous.hubOrder[i]==frame then table.remove(previous.hubOrder,i) end end
      if previous.selected==frame then previous.selected=nil end
    end
    r.workspace="messages";if r.saved then r.saved.workspace="messages" end
    if r.placement=="hub" then W:Place(frame,"hub",false) end
  end
  if previous and previous.hub then previous.windowManuallyClosed=true;previous.hub:Hide() end
  -- OnHide checkpoints visibility; discard the legacy checkpoint after hiding it.
  if char.messageWindowStates then char.messageWindowStates.favorites=nil end
  if W.pendingWindowStates then W.pendingWindowStates.favorites=nil end
  if char.messageWorkspaces then char.messageWorkspaces.favorites=nil end
  if W.workspaces then W.workspaces.favorites=nil end
  if W.retiredWorkspaces then W.retiredWorkspaces.favorites=nil end
  if reopen then W:OpenMessages() end
end
local apply=W.ApplySettings
function W:ApplySettings(relocate,key)
  if not key then W:MigrateFavoritesWorkspace() end
  apply(self,relocate,key)
end
local enable=W.OnEnable
function W:OnEnable()
  W:MigrateFavoritesWorkspace()
  enable(self)
end
local badges=W.UpdateBadges
function W:UpdateBadges()
  badges(self)
  if not W.hub or not W:UsesUnifiedPeople() or W.previewActive then return end
  local parts={W.peopleFilter or "all"}
  for _,frame in ipairs(W.hubOrder or {}) do
    local r=W.records[frame] or {}
    parts[#parts+1]=tostring(frame)..":"..tostring(r.unread or 0)..":"..tostring(not not W:IsFavorite(frame))
  end
  for key,name in pairs(Core.db.char.whisperFavorites or {}) do parts[#parts+1]=key..":"..tostring(name) end
  local stamp=table.concat(parts,";")
  if W.unifiedPeopleStamp==stamp or W.unifiedPeopleRefreshPending then return end
  W.unifiedPeopleStamp=stamp;W.unifiedPeopleRefreshPending=true
  C_Timer.After(0,function()
    W.unifiedPeopleRefreshPending=nil
    if W:UsesUnifiedPeople() and not W.previewActive then W:LayoutPeopleRows(false);W:RefreshConversationNavigation(false) end
  end)
end

local openToast=W.OpenMinimizedWhisper
function W:OpenMinimizedWhisper(entry)
  local r=entry and not entry.sample and W.records[entry.person]
  if r and r.placement~="hub" and entry.person.inUse then
    if InCombatLockdown() and entry.person:IsProtected() then return end
    W:SelectConversation(entry.person,false)
    W.pendingWhisperToast=entry
    for _,host in pairs(W.workspaces or {}) do if host.minimizedWhispers then host:DismissMinimizedWhisper(entry.person) end end
    return
  end
  return openToast(self,entry)
end

local presentBody=W.PresentWindowBody
function W:PresentWindowBody(shown,alpha)
  presentBody(self,shown,alpha)
  if self.peopleFilters and self:UsesUnifiedPeople() then
    self.peopleFilters:SetAlpha(alpha or 1)
    self.peopleFilters:SetShown(shown and not self.minimized)
  end
end

local tick=W.Tick
function W:Tick()
  tick(self)
  if not IsMouseButtonDown or not IsMouseButtonDown("LeftButton") then
    for _,host in pairs(W.workspaces or {}) do
      if host.previewRenderPending and host.previewActive then host:RenderPreview() end
    end
    for _,host in ipairs(W.previewDetachedHosts or {}) do
      if host.previewRenderPending and host.previewActive then host:RenderPreview() end
    end
  end
end

local choosePreview=W.SelectPreviewConversation
function W:SelectPreviewConversation(index)
  self.explicitPeopleNavigation=true
  if self:UsesUnifiedPeople() and self.peopleFilter=="unread" then self:SetPeopleFilter("all") end
  local result=choosePreview(self,index)
  self.explicitPeopleNavigation=nil
  return result
end
local chooseConversation=W.SelectConversation
function W:SelectConversation(frame,reply)
  local host=W:HubFor(frame)
  host.explicitPeopleNavigation=true
  host.hubOpenedAt=GetTime();host.lastUserInteraction=GetTime()
  if host:UsesUnifiedPeople() and host.peopleFilter=="unread" then host:SetPeopleFilter("all") end
  local result=chooseConversation(self,frame,reply)
  host.explicitPeopleNavigation=nil
  return result
end
