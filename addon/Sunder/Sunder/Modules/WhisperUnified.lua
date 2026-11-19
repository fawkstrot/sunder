local Core = unpack(select(2,...))
local W = Core:GetModule("Whispers")
Core.defaults.profile.whispers.singleToasterStack=true

function W:UsesUnifiedPeople()
  return self.hostId=="messages" and self:IsConversationList()
end
local FILTER_HEIGHT = 32
function W:PeopleFilterHeight()
  return self:UsesUnifiedPeople() and FILTER_HEIGHT or 0
end
local function data(host,preview)
  if preview then return host.previewConversations or {},host.previewTabs or {},host.previewTabScroll,host.previewTabChild end
  return host.hubOrder or {},host.hubTabs or {},host.tabScroll,host.tabChild
end
local function favorite(item,preview) return preview and item.favorite or not preview and W:IsFavorite(item) end
local function unread(item,preview) return preview and (item.unread or 0) or (W.records[item] or {}).unread or 0 end

local tabWidth=W.TabWidth
function W:TabWidth()
  if self:UsesUnifiedPeople() then return self:ConversationListWidth()-self:BodyPadding()-Core.Components.WindowManager:ScrollRightInset(self:BodyPadding()) end
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
  Core.Components.WindowManager:StyleFilterButton(button,active,hover,r,g,b)
  button.icon:SetAlpha(button.pressed and .65 or 1)
  if button.counter then
    local hasUnread=(button.unreadTotal or 0)>0
    button.counter:SetTextColor(hasUnread and 1 or .45,hasUnread and .80 or .50,hasUnread and .30 or .57)
  end
end
function W:EnsurePeopleFilters()
  if self.peopleFilters then return end
  local bar=CreateFrame("Frame",nil,self.hub);self.peopleFilters=bar
  bar:SetHeight(FILTER_HEIGHT)
  bar.rule=bar:CreateTexture(nil,"BORDER");bar.rule:SetPoint("BOTTOMLEFT",1,0);bar.rule:SetPoint("BOTTOMRIGHT",-1,0);bar.rule:SetHeight(1);bar.rule:SetColorTexture(.64,.69,.76,.14)
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
      GameTooltip:AddLine(key=="all" and "Every conversation, with favorites first." or key=="unread" and "People with messages you have not read." or "Starred people and saved contacts.",.7,.75,.8);Core:GetModule("Fonts"):StyleTooltip(GameTooltip);GameTooltip:Show()
    end)
    b:SetScript("OnLeave",function() b.hovered=nil;b.pressed=nil;self:StylePeopleFilter(b);GameTooltip:Hide() end)
    b:SetScript("OnMouseDown",function() b.pressed=true;self:StylePeopleFilter(b) end)
    b:SetScript("OnMouseUp",function() b.pressed=nil;self:StylePeopleFilter(b) end)
    b:SetScript("OnHide",function() b.hovered=nil;b.pressed=nil;self:StylePeopleFilter(b) end)
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
function W:ContentTop() return contentTop(self)+self:PeopleFilterHeight() end
local strip=W.LayoutConversationStrip
function W:LayoutConversationStrip(preview)
  strip(self,preview)
  if not self.hub then return end
  if not self:UsesUnifiedPeople() then if self.peopleFilters then self.peopleFilters:Hide() end;return end
  self:EnsurePeopleFilters()
  local bar=self.peopleFilters
  local top=self:HeaderHeight()+self:HeaderGap()
  bar:ClearAllPoints();bar:SetPoint("TOPLEFT",self.hub,"TOPLEFT",0,-top);bar:SetWidth(math.max(1,self.hub:GetWidth()))
  bar:SetFrameLevel(self.hubChrome:GetFrameLevel()+1)
  bar:SetShown(not self.minimized)
  self:RefreshPeopleFilterCounts()
  local width=bar:GetWidth()/3
  for i,b in ipairs(bar.buttons) do
    local left=math.floor((i-1)*width);local right=i==3 and bar:GetWidth() or math.floor(i*width)
    b:ClearAllPoints();b:SetPoint("TOPLEFT",left,0);b:SetSize(right-left,bar:GetHeight())
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
    text:ClearAllPoints();text:SetPoint("LEFT",b.icon,"RIGHT",5,0);text:SetWidth(labelWidth+1);text:SetHeight(size+2);text:SetJustifyH("LEFT");text:SetJustifyV("MIDDLE")
    if b.counter then b.counter:ClearAllPoints();b.counter:SetPoint("LEFT",text,"RIGHT",5,0) end
    self:StylePeopleFilter(b)
  end
end
function W:SavedPersonPinned(contact)
  local history=Core:GetModule("WhisperTabs",true)
  local entry=contact.archiveKey and history and history:ImportArchive()[contact.archiveKey]
  return entry and entry.layout and entry.layout.pinned or Core.db.char.whisperPeoplePins and Core.db.char.whisperPeoplePins[contact.key or contact.archiveKey] or false
end
function W:ToggleSavedPin(contact)
  local key=contact.key or contact.archiveKey;if not key then return end
  Core.db.char.whisperPeoplePins=Core.db.char.whisperPeoplePins or {}
  local pins=Core.db.char.whisperPeoplePins;local pinned=not self:SavedPersonPinned(contact)
  local count=0;for _ in pairs(pins)do count=count+1 end
  if pinned and count>=200 then return end
  pins[key]=pinned or nil
  if contact.key and Core.db.char.whisperLayouts and Core.db.char.whisperLayouts[contact.key]then Core.db.char.whisperLayouts[contact.key].pinned=pinned end
  local history=Core:GetModule("WhisperTabs",true)
  local entry=contact.archiveKey and history and history:ImportArchive()[contact.archiveKey]
  if entry then entry.layout=entry.layout or {};entry.layout.pinned=pinned end
  self:LayoutPeopleRows(false)
end
function W:ToggleSavedFavorite(contact)
  local history=Core:GetModule("WhisperTabs",true)
  local entry=contact.archiveKey and history and history:ImportArchive()[contact.archiveKey]
  local favorite=not (entry and entry.favorite or contact.key and Core.db.char.whisperFavorites[contact.key])
  if contact.key then return W:SetPersonFavorite(contact.key,entry and entry.target or contact.target,favorite)end
  if entry then entry.favorite=favorite end
  W:RefreshPersonFavorites()
end
function W:OpenSavedFavorite(contact)
  if contact.archiveKey then
    local history=Core:GetModule("WhisperTabs",true)
    if history then history:OpenArchive(contact.archiveKey) end
    return
  end
  for frame,r in pairs(W.records or {}) do
    if frame.inUse and r.key==contact.key then W:SelectConversation(frame,false);return end
  end
  if InCombatLockdown() or not FCF_OpenTemporaryWindow then return end
  local ok,frame=pcall(FCF_OpenTemporaryWindow,"WHISPER",contact.target,nil,false)
  if ok and frame then C_Timer.After(0,function()
    if frame.inUse and W:Key(frame)==contact.key then
      W:MoveToWorkspace(frame,"messages")
    end
  end) end
end
function W:RenderSavedPersonRow(contact,child,y,savedRowIndex,isFavorite)
  local pad=self:BodyPadding()
  local b=self.savedFavoriteRows[savedRowIndex]
  if not b then
    b=CreateFrame("Button",nil,child);self.savedFavoriteRows[savedRowIndex]=b
    b:SetNormalFontObject("SunderChatDockFont")
    b.favoriteButton=self:IconButton(b,"favorite","Favorite / unfavorite saved conversation",function()self:ToggleSavedFavorite(b.contact)end)
    b:SetHighlightTexture("Interface\\Buttons\\WHITE8X8");b:GetHighlightTexture():SetVertexColor(1,1,1,.06)
    b:RegisterForClicks("LeftButtonUp","RightButtonUp")
    b:SetScript("OnClick",function(button,mouse)
      if mouse=="RightButton" then
        local history=Core:GetModule("WhisperTabs",true)
        if MenuUtil and MenuUtil.CreateContextMenu then
          Core:GetModule("Fonts"):CreateContextMenu(button,function(_,menu)
            menu:CreateButton("Open conversation",function() W:OpenSavedFavorite(button.contact) end)
            Core.Components.WindowManager:AddInspectAction(menu,button.contact.target or button.contact.key)
            if history and button.contact.archiveKey then
            menu:CreateButton("Browse / search saved history",function() history:ShowArchive(button.contact.archiveKey) end)
            menu:CreateButton("Delete saved history…",function() history:RequestDelete(button.contact.archiveKey) end)
            end
          end)
        end
      else W:OpenSavedFavorite(button.contact) end
    end)
    b:SetScript("OnEnter",function(button)
      GameTooltip:SetOwner(button,"ANCHOR_RIGHT");GameTooltip:AddLine(Core.Components.WindowManager:FormatPersonName(button.contact.target,button.contact),1,1,1)
      GameTooltip:AddLine("Click to open this conversation without sending a message.",.7,.75,.8)
      if button.contact.archiveKey then GameTooltip:AddLine("Right-click for saved history, search or confirmed deletion.",.7,.75,.8) end
      Core:GetModule("Fonts"):StyleTooltip(GameTooltip);GameTooltip:Show()
    end)
    b:SetScript("OnLeave",function()GameTooltip:Hide()end)
  end
  b.contact=contact;b:ClearAllPoints();b:SetPoint("TOPLEFT",child,"TOPLEFT",pad,-y)
  b:SetSize(self:TabWidth(),self:ConversationRowHeight());local person=W:PersonDetails(contact.key or contact.target)
  b:SetText(W.whisperNames and W.whisperNames[contact.key] or person and person.name or contact.target)
  b.savedFavorite=isFavorite
  Core.Components.WindowManager:SetActionSelected(b.favoriteButton,isFavorite,"favorite")
  b:GetFontString():SetTextColor(.62,.65,.70)
  b.savedFavoriteAction=function()self:ToggleSavedFavorite(b.contact)end
  b.savedPinAction=function()self:ToggleSavedPin(b.contact)end;b.savedPinned=self:SavedPersonPinned(contact)
  self:LayoutPersonDetails(b,contact.key or contact.target);b:Show();return b

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
  local groups={favorites={},conversations={},archived={}};local active={};local activeArchive={}
  local filter=self.peopleFilter or "all"
  for i,item in ipairs(list) do
    local tab=preview and tabs[i] or tabs[item]
    if tab then tab:Hide() end
    local r=not preview and W.records[item]
    if r and r.key then active[r.key]=true end
    local history=not preview and Core:GetModule("WhisperTabs",true)
    local archiveKey=history and history.ArchiveKey and history:ArchiveKey(item)
    if archiveKey then activeArchive[archiveKey]=true end
    local fav=favorite(item,preview)
    if filter=="all" and (preview or not fav or W:HasConversationHistory(item)) or filter=="unread" and unread(item,preview)>0 or filter=="favorites" and fav then
      local group=groups[fav and "favorites" or "conversations"]
      group[#group+1]={item=item,index=i,tab=tab}
    end
  end
  local contacts={}
  if not preview and filter=="favorites" then
    for key,target in pairs(Core.db.char.whisperFavorites or {}) do
      if type(target)=="string" and not active[key] then contacts[#contacts+1]={key=key,target=target} end
    end
    table.sort(contacts,function(a,b)return a.target:lower()<b.target:lower() end)
  end
  local archived={}
  if not preview then
    local history=Core:GetModule("WhisperTabs",true)
    for frame in pairs(W.records or {}) do
      local archiveKey=frame.inUse and history and history.ArchiveKey and history:ArchiveKey(frame)
      if archiveKey then activeArchive[archiveKey]=true end
    end
  end
  if not preview and filter~="unread" then
    local history=Core:GetModule("WhisperTabs",true)
    for archiveKey,entry in pairs(history and history.ImportArchive and history:ImportArchive() or {}) do
      if not activeArchive[archiveKey] and (filter=="favorites" and entry.favorite or #(entry.lines or {})>0 or filter=="favorites" and entry.target and W:IsPersonFavorite(entry.target)) then
        local key=entry.target and entry.target:lower()
        local fav=entry.favorite or key and Core.db.char.whisperFavorites and Core.db.char.whisperFavorites[key]
        local contact={key=key,target=entry.displayName or entry.target or entry.battleTag or "Whisper",archiveKey=archiveKey}
        if fav then
          local found=false
          for _,existing in ipairs(contacts) do if existing.key==key and key then existing.archiveKey=archiveKey;found=true;break end end
          if not found then contacts[#contacts+1]=contact end
        elseif filter=="all" then archived[#archived+1]=contact end
      end
    end
    table.sort(archived,function(a,b)return a.target:lower()<b.target:lower() end)
  end
  self.peopleOffsets={};self.peopleVisualOrder={};self.savedFavoriteRows=self.savedFavoriteRows or {}
  for _,b in pairs(self.peopleSections or {})do b:Hide()end
  for _,b in ipairs(self.savedFavoriteRows)do b:Hide()end
  local visible={}
  for _,key in ipairs({"favorites","conversations"})do
    for _,entry in ipairs(groups[key])do
      local record=preview and entry.item or W.records[entry.item] or {}
      entry.favorite=key=="favorites";entry.pinned=record.pinned;entry.order=entry.index;visible[#visible+1]=entry
    end
  end
  for _,collection in ipairs({contacts,archived})do for _,contact in ipairs(collection)do
    visible[#visible+1]={contact=contact,favorite=collection==contacts,pinned=self:SavedPersonPinned(contact),order=#list+#visible+1}
  end end
  table.sort(visible,function(a,b)
    local x=Core.Components.WindowManager:PersonPriority(a.favorite,a.pinned);local y=Core.Components.WindowManager:PersonPriority(b.favorite,b.pinned)
    if x~=y then return x<y end;return a.order<b.order
  end)
  local y,step=pad,self:ConversationRowStep();local savedRowIndex=0
  for i,entry in ipairs(visible)do
    local row=entry.tab
    if entry.contact then
      savedRowIndex=savedRowIndex+1;row=self:RenderSavedPersonRow(entry.contact,child,y,savedRowIndex,entry.favorite)
    else
      self.peopleOffsets[entry.index]=y;self.peopleVisualOrder[#self.peopleVisualOrder+1]={index=entry.index,y=y}
      if row then
        row:ClearAllPoints();row:SetPoint("TOPLEFT",child,"TOPLEFT",pad,-y);row:Show()
        local record=not preview and W.records[entry.item]
        self:LayoutPersonDetails(row,preview and entry.item.name or record and (record.target or record.key),preview and entry.item or nil)
      end
    end
    if row and row.separator then row.separator:SetShown(i<#visible)end
    y=y+step
  end
  if not self.peopleEmpty then self.peopleEmpty=child:CreateFontString(nil,"OVERLAY","SunderChatDockFont") end
  local empty=self.peopleEmpty;empty:SetParent(child);empty:ClearAllPoints();empty:SetPoint("TOPLEFT",pad,-pad)
  empty:SetWidth(self:TabWidth());empty:SetJustifyH("LEFT");empty:SetTextColor(.48,.53,.61)
  self:WorkspaceFont(empty,math.max(10,self:InterfaceTextSize()-1))
  empty:SetText(filter=="unread" and "No unread whispers" or filter=="favorites" and "No favorites yet.\nStar a conversation to save it here." or "Your conversations appear here.")
  empty:SetShown(y==pad)
  child:SetHeight(math.max(y==pad and 60 or 1,y+pad))
  scroll:SetVerticalScroll(math.max(0,math.min(scroll:GetVerticalScroll(),y+pad-scroll:GetHeight())))
  self:UpdatePeopleScrollIndicator(scroll,child)
end
local reveal=W.RevealPerson
function W:RevealPerson(preview,index)
  if not self:UsesUnifiedPeople() then return reveal(self,preview,index) end
  local list,_,scroll=data(self,preview);local person=list[index]
  if not person or not scroll then return end
  if not self.peopleOffsets or self.peopleOffsets[index]==nil then
    if not self.explicitPeopleNavigation then return end
    self.peopleFilter="all"
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
function W:QueueMinimizedWhisper(person,sample,text,seed,nativeArgs)
  if sample then
    local host=person.host
    if host and not host.minimized and host.hub and host.hub:IsShown() and host.previewConversations and host.previewConversations[host.previewSelected or 1]==person then return end
  elseif W:IsConversationDisplayed(person) then return end
  W:EnsureHub()
  if not sample and not seed and not W.hub:IsShown() and not W.windowManuallyClosed then
    local states=W.pendingWindowStates or Core.db.char.messageWindowStates
    local state=states and states.messages
    if state and state.open and (W:Settings().keepMessagesOpen or W:Settings().showOnIncoming) then
      W:ShowRememberedWindow(state.minimized)
    end
  end
  return queue(W,person,sample,text,seed,nativeArgs)
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
  for _,host in pairs(W.workspaces or {W})do if host.hub then host:RefreshConversationEmptyState()end end
  if not W.hub or not W:UsesUnifiedPeople() or W.previewActive then return end
  local parts={W.peopleFilter or "all"}
  for _,frame in ipairs(W.hubOrder or {}) do
    local r=W.records[frame] or {}
    parts[#parts+1]=tostring(frame)..":"..tostring(r.unread or 0)..":"..tostring(not not W:IsFavorite(frame))..":"..tostring(r.hasMessages or false)
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
