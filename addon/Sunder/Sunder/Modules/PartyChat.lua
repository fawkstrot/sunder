local Core,Constants=unpack(select(2,...))
local P=Core:GetModule("PartyChat")
local function safe(v)return not _G.canaccessvalue or _G.canaccessvalue(v)end
local function text(v)return safe(v) and type(v)=="string" and not v:find("|K",1,true) and v or ""end
local function cfg()return Core.db.profile.partyChat end
local function state()Core.db.char.partyChat=Core.db.char.partyChat or {};return Core.db.char.partyChat end
local function theme()return Core:GetModule("Whispers")end
local GROUP_TYPES={"PARTY","PARTY_LEADER","RAID","RAID_LEADER","RAID_WARNING","INSTANCE_CHAT","INSTANCE_CHAT_LEADER"}
local function title()return P.raid and "Raid Chat" or "Party Chat"end
local function grouped()
  return IsInGroup and IsInGroup() and (cfg().followRaid or not (IsInRaid and IsInRaid())) or false
end
local function channel()
  if IsInGroup and LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE)then return "INSTANCE_CHAT"end
  return IsInRaid and IsInRaid() and "RAID" or "PARTY"
end
local function subtitle()
  if not P.grouped then return "Join a party or raid to chat."end
  local parts={}
  if P.leader then parts[#parts+1]="Leader: "..P.leader end
  if P.roles then for _,entry in ipairs({{"TANK","tank"},{"HEALER","healer"},{"DAMAGER","damage"}})do local n=P.roles[entry[1]]or 0;if n>0 then parts[#parts+1]=n.." "..entry[2]end end end
  if P.readyCheck then parts[#parts+1]=tostring(P.readyCount or 0).."/"..tostring(P.totalCount or 0).." ready"end
  return table.concat(parts," · ")
end
local function caption()
  if not P.grouped then return P.hasRecentHistory and "Previous group" or "Not in a party."end
  local name,kind,difficulty
  if GetInstanceInfo then local ignored;name,kind,ignored,difficulty=GetInstanceInfo()end
  if text(name)~="" and kind~="none"then return text(name)..(text(difficulty)~="" and " · "..difficulty or "")end
  return (P.raid and "Raid" or "Party").." · "..tostring(P.totalCount or 0).." members"
end
Core.defaults.profile.partyChat={enabled=true,autoOpen=true,followRaid=true,rosterShown=true,remember=true}
Core.Components.InstallRosterRoom(P,{id="party",frameName="SunderPartyRoom",editKey="Sunder_PartyChat",settings="party",showSearch=function(p)return p.raid end,nativeTitle="Party Chat",info=true,infoTooltip="Previous groups",infoAction=function(p)p:ToggleHistory()end,infoSelected=function(p)return p.historyMode end,nativeGroups={PARTY=true,PARTY_LEADER=true,RAID=true,RAID_LEADER=true,RAID_WARNING=true,INSTANCE_CHAT=true,INSTANCE_CHAT_LEADER=true},title=title,caption=caption,subtitle=subtitle,
  state=state,profile=cfg,scope=function()return P.sessionKey end,historyKey="partyRoomHistory",
  historyTypes={"PARTY","PARTY_LEADER","RAID","RAID_LEADER","RAID_WARNING","INSTANCE_CHAT","INSTANCE_CHAT_LEADER"}})
function P:IsRoom(frame)return cfg().enabled and frame~=nil and frame==self.frame end
function P:CanSend()return self.grouped and not self.historyMode and not self.pendingConfigure and self.configuredType==self.channel end
function P:Report(message)Core:GetModule("Config"):Print(message)end
function P:CollapseToward(edge)Core.Components.WindowManager:CollapseToward(self:EnsureRoom(),edge)end
function P:UpdateUnread()
  local h=self.room;if not h or not h.unreadBadge then return end
  Core.Components.WindowManager:StyleUnreadIndicator(h.unreadBadge,self.unread or 0,h:InterfaceAccent())
end
function P:AcknowledgeMessages()self.unread=0;self:UpdateUnread()end
function P:IsMemberFavorite(member)return member and theme():IsPersonFavorite(member.key)end
function P:ToggleMemberFavorite(member)
  if not member or member.guildKey~=self.sessionKey then return end
  theme():RememberPersonDetails(member.name,member)
  theme():SetPersonFavorite(member.key,member.name,not self:IsMemberFavorite(member))
end
function P:IsMemberPinned(member)return member and (state().pins or {})[member.key]end
function P:ToggleMemberPin(member)
  if not member or member.guildKey~=self.sessionKey then return end
  local pins=state().pins or {};state().pins=pins
  if not pins[member.key]then local count=0;for _ in pairs(pins)do count=count+1 end;if count>=200 then return self:Report("You can pin up to 200 group members.")end end
  pins[member.key]=not pins[member.key] or nil;self:FilterRoster(false)
end
function P:OpenWhisper(member)
  if member and member.online and member.guildKey==self.sessionKey and not InCombatLockdown()then theme():OpenSavedFavorite({key=member.key,target=member.name})end
end
function P:ShowMemberCard(member)
  -- Selection stays in this room. Hover/context menu expose member details;
  -- only explicit double-click/Whisper opens another conversation.
  self.selectedMember=member.key;self.selectedGuild=member.guildKey
end
function P:FilterRoster(reset)
  local list={};local query=(self.query or ""):lower()
  for _,member in ipairs(self.members or {})do
    if query=="" or (member.name.." "..member.rank.." "..member.class):lower():find(query,1,true)then list[#list+1]=member end
  end
  table.sort(list,function(a,b)
    local wm=Core.Components.WindowManager
    local x,y=wm:PersonPriority(self:IsMemberFavorite(a),self:IsMemberPinned(a)),wm:PersonPriority(self:IsMemberFavorite(b),self:IsMemberPinned(b))
    if x~=y then return x<y end
    if a.online~=b.online then return a.online end
    if a.rankIndex~=b.rankIndex then return a.rankIndex<b.rankIndex end
    return a.key<b.key
  end)
  self.filtered=list
  if self.scroll and reset~=false then self.scroll:SetVerticalScroll(0)end
  self:RenderRoster()
  if self.room then self:LayoutRoomChrome();self.room:LayoutHub()end
end
function P:RefreshRoster()
  local active=grouped();local raid=active and IsInRaid and IsInRaid() or false
  local list,identities={},{};local online,ready=0,0;local leader;local roles={}
  local count=active and GetNumGroupMembers and GetNumGroupMembers() or 0
  if not safe(count) or type(count)~="number"then count=0 end
  if active and count==0 then count=(GetNumSubgroupMembers and GetNumSubgroupMembers() or 0)+1 end
  count=math.min(raid and 40 or 5,math.max(0,count))
  for i=1,count do
    local unit=raid and "raid"..i or i==1 and "player" or "party"..(i-1)
    local name=GetUnitName and GetUnitName(unit,true) or UnitName and UnitName(unit)
    name=text(name)
    if name~=""then
      local class,token;if UnitClass then class,token=UnitClass(unit)end
      local level=UnitLevel and UnitLevel(unit);if not safe(level) or type(level)~="number"or level<1 then level=nil end
      local role=UnitGroupRolesAssigned and text(UnitGroupRolesAssigned(unit)) or ""
      local isLeader=UnitIsGroupLeader and UnitIsGroupLeader(unit)
      local connected=not UnitIsConnected or UnitIsConnected(unit);connected=safe(connected) and connected==true
      local status=GetReadyCheckStatus and text(GetReadyCheckStatus(unit))or ""
      if status=="ready"then ready=ready+1 end
      status=({ready="Ready",notready="Not ready",waiting="Waiting"})[status] or status
      local rank=isLeader and (raid and "Raid leader" or "Party leader") or role=="TANK" and "Tank" or role=="HEALER" and "Healer" or role=="DAMAGER" and "Damage" or "Member"
      if not connected then rank=rank.." · Offline"elseif self.readyCheck and status~=""then rank=rank.." · "..status end
      if isLeader then leader=name end
      roles[role]=(roles[role]or 0)+1
      if connected then online=online+1 end
      local guid=UnitGUID and text(UnitGUID(unit))or ""
      identities[#identities+1]=guid~="" and guid or name:lower()
      list[#list+1]={name=name,key=name:lower(),unit=unit,online=connected,class=text(class),classFile=text(token),level=level,
        rank=rank,rankIndex=isLeader and 0 or role=="TANK" and 1 or role=="HEALER" and 2 or 3,note="",zone="",status=status}
    end
  end
  if active and not self.groupInitialized and #list<count and Core.db.char.partyRoomHistory then
    self.waitingForRoster=true;self.rosterStatus="Waiting for party members…";return
  end
  self.waitingForRoster=nil
  table.sort(identities);local fingerprint=table.concat(identities,";")
  local saved=state();local initial=not self.groupInitialized
  local new=active and (self.leftSinceRefresh or self.groupInitialized and not self.grouped or initial and saved.fingerprint~=fingerprint)
  if self.grouped and not active then self:SaveHistory(true)end
  if new then
    self:SaveHistory(true)
    saved.serial=(saved.serial or 0)+1;self.sessionKey="party:"..tostring(saved.serial)
    saved.lastSessionKey=self.sessionKey;self.currentGuild=self.sessionKey
    self.restoredFrame=nil;self.historyGeneration=(self.historyGeneration or 0)+1;self.restoringHistory=nil
    Core.db.char.partyRoomHistory=nil;self.hasRecentHistory=false;self.selectedMember=nil;self.selectedGuild=nil
    if self.frame then
      self.frame:Clear()
      local w=Core:GetModule("UIManager"):GetChatWindow(self.frame)
      if w and w.editBox then w.editBox:SetText("")end
      if w and w.slidingMessageFrame.ReloadMessagesFromChatFrame then w.slidingMessageFrame:ReloadMessagesFromChatFrame()end
    end
    self:AcknowledgeMessages()
  elseif initial then self.sessionKey=saved.lastSessionKey or "party:0";self.currentGuild=self.sessionKey end
  self.groupInitialized=true;self.leftSinceRefresh=nil;self.grouped=active;self.raid=raid;self.channel=channel()
  self.members=list;self.totalCount=#list;self.onlineCount=online;self.leader=leader;self.roles=roles;self.readyCount=ready
  for _,member in ipairs(list)do member.guildKey=self.sessionKey;theme():RememberPersonDetails(member.name,member)end
  theme():QueuePersonRefresh()
  saved.fingerprint=active and fingerprint or nil
  self.hasRecentHistory=self.hasRecentHistory or Core.db.char.partyRoomHistory and #(Core.db.char.partyRoomHistory.lines or {})>0
  self.rosterStatus=active and "No matching members." or "No party members."
  if self.frame then
    if InCombatLockdown() and self.configuredType~=self.channel then self.pendingConfigure=true
    elseif self.configuredType~=self.channel then self:ConfigureFrame(self.frame,false)end
    if not self:CanSend() and _G.SELECTED_CHAT_FRAME==self.frame and _G.ChatFrame1 then Core:GetModule("UIManager"):ReleaseMessageInput(self.frame)end
  end
  self:FilterRoster(false)
  if (new or self.openOnPolicyUpgrade) and active and cfg().autoOpen and cfg().enabled then self.openOnPolicyUpgrade=nil;self:Open(true)end
end
function P:ScheduleRoster()
  if self.rosterScheduled then return end
  self.rosterScheduled=true
  C_Timer.After(.1,function()
    self.rosterScheduled=nil;self:RefreshRoster()
    if not self.waitingForRoster and self.pendingRestore and not InCombatLockdown()then self.pendingRestore=nil;self:RestoreWindow()end
    if not self.waitingForRoster and self.pendingOpen and not InCombatLockdown()then local automatic=self.pendingAutomatic;self.pendingOpen=nil;self:Open(automatic)end
  end)
end
function P:ConfigureFrame(frame,created)
  self.frame=frame
  if self.closedSlots then self.closedSlots[frame]=nil end
  if created then
    if not (frame.RemoveAllMessageGroups or ChatFrame_RemoveAllMessageGroups) or not (frame.AddMessageGroup or ChatFrame_AddMessageGroup)then
      self.frame=nil;if FCF_Close then FCF_Close(frame)end;self:Report("Dedicated group chat is unavailable on this client.");return false
    end
    if frame.RemoveAllMessageGroups then frame:RemoveAllMessageGroups()else ChatFrame_RemoveAllMessageGroups(frame)end
    for _,kind in ipairs(GROUP_TYPES)do
      if frame.AddMessageGroup then frame:AddMessageGroup(kind)else ChatFrame_AddMessageGroup(frame,kind)end
    end
    if frame.RemoveAllChannels then frame:RemoveAllChannels()end
    frame.chatType=self.channel
  end
  -- Repair saved native slots too; leader traffic is a separate native category.
  for _,kind in ipairs(GROUP_TYPES)do
    if frame.AddMessageGroup then frame:AddMessageGroup(kind)elseif ChatFrame_AddMessageGroup then ChatFrame_AddMessageGroup(frame,kind)end
  end
  if frame.isDocked then FCF_UnDockFrame(frame)end
  local ui=Core:GetModule("UIManager");local window=ui:GetChatWindow(frame) or ui:CreateChatWindow(frame,false)
  ui:CreateChatEditBox(window)
  local input=window.editBox
  if input and self.configuredType~=self.channel then
    if input.SetChatType then input:SetChatType(self.channel)else input:SetAttribute("chatType",self.channel)end
    if input.SetStickyType then input:SetStickyType(self.channel)else input:SetAttribute("stickyType",self.channel)end
  end
  frame.chatType=self.channel;self.configuredType=self.channel;self.pendingConfigure=nil
  state().frameID=frame:GetID()
  self:RestoreHistory();ui:RefreshChatFrameLayout(frame)
  return true
end
local layout=P.LayoutWindow
function P:LayoutWindow(window)
  local handled=layout(self,window)
  if handled and self.column then
    if not self.conversationEmpty then self.conversationEmpty,self.conversationEmptyIcon=Core.Components.WindowManager:CreateEmptyConversation(self.column,"",{icon=false})end
    local empty=window.chatFrame:GetNumMessages()==0
    self.conversationEmpty:SetText(self.grouped and "No messages yet.\n\nGroup messages will appear here." or "Your next group starts here.\n\nJoin a party or raid to chat.")
    theme():WorkspaceFont(self.conversationEmpty,theme():InterfaceTextSize())
    self.conversationEmpty:SetWidth(math.max(1,self.column:GetWidth()-theme():BodyPadding()*2));self.conversationEmpty:SetWordWrap(true)
    self.conversationEmpty:SetShown(empty and self.grouped);self.conversationEmptyIcon:Hide()
    local input=Core:GetModule("UIManager"):GetLayoutEditBox(window)
    if input and not self:CanSend()then if input.ClearFocus then input:ClearFocus()end;input:Hide()end
  end
  return handled
end
local restoreWindow=P.RestoreWindow
function P:RestoreWindow()
  if self.waitingForRoster or InCombatLockdown()then self.pendingRestore=true;return end
  return restoreWindow(self)
end
function P:Open(automatic)
  if not cfg().enabled or automatic==true and not self.grouped then return end
  if not self.groupInitialized then self:RefreshRoster()end
  if self.waitingForRoster then self.pendingOpen=true;self.pendingAutomatic=automatic;return end
  local minimized=false
  if automatic then if self.room then minimized=not not self.room.minimized else minimized=not not state().minimized end end
  local frame=self.frame or self:SavedFrame()
  if InCombatLockdown()then self.pendingOpen=true;self.pendingAutomatic=automatic;if not automatic then self:Report("Party Chat will open after combat.")end;return end
  local created=false
  if not frame and FCF_OpenNewWindow then frame=FCF_OpenNewWindow("Party Chat",true);created=true end
  if not frame then self:Report("No native chat slot is available for Party Chat.");return end
  if not self:ConfigureFrame(frame,created)then return end;frame:Show()
  local h=self:EnsureRoom();h.windowManuallyClosed=false;h.hub:Show()
  if automatic then h:SetMinimized(minimized,true)elseif h.minimized then h:SetMinimized(false,true)end
  if not h.minimized then h.hubContent:Show();self:AcknowledgeMessages()end
  h:LayoutHub()
  if not automatic and self:CanSend()then Core:GetModule("UIManager"):SelectMessageInput(frame)end
  self:SaveRoomState()
end
function P:FilterMessage(frame,event)
  if frame==self.frame and cfg().enabled then return not self.grouped or not self:AcceptEvent(event)end
  -- Presentation-only suppression: leave native subscriptions and other tabs intact.
  local h=self.room
  return frame==_G.ChatFrame1 and self.frame~=nil and self.grouped and cfg().enabled and h~=nil and h.hub:IsShown() or false
end
function P:OnWindowClosed(frame)
  if self.frame~=frame then return end
  Core:GetModule("UIManager"):ReleaseMessageInput(frame)
  self:SaveHistory(true);self.historyGeneration=(self.historyGeneration or 0)+1
  self.closedSlots=self.closedSlots or {};self.closedSlots[frame]=true
  state().frameID=nil;state().open=false
  if self.room then self.room.hub:Hide()end
  local window=Core:GetModule("UIManager"):GetChatWindow(frame);if window then self:ClearRoomLayout(window)end
  self.frame=nil;self.roomFrame=nil;self.configuredType=nil
end
local saveNative=P.OnNativeMessage
function P:OnNativeMessage(frame)
  saveNative(self,frame)
  if self:IsRoom(frame) and self.conversationEmpty then self.conversationEmpty:Hide();self.conversationEmptyIcon:Hide()end
end
function P:OnGroupMessage(event,guid)
  if not cfg().enabled or not self.grouped then return end
  if not self:AcceptEvent(event)then return end
  local own=UnitGUID and UnitGUID("player")
  if safe(guid) and guid and own and guid==own then return end
  local h=self.room
  if h and h.hub:IsShown() and not self.historyMode and not h.minimized and not h.collapseAnimation then self:AcknowledgeMessages();return end
  self.unread=math.min(9999,(self.unread or 0)+1);self:UpdateUnread()
end
function P:AcceptEvent(event)
  if self.channel=="INSTANCE_CHAT"then return event=="CHAT_MSG_INSTANCE_CHAT" or event=="CHAT_MSG_INSTANCE_CHAT_LEADER"end
  if self.channel=="RAID"then return event=="CHAT_MSG_RAID" or event=="CHAT_MSG_RAID_LEADER" or event=="CHAT_MSG_RAID_WARNING"end
  return event=="CHAT_MSG_PARTY" or event=="CHAT_MSG_PARTY_LEADER"
end
function P:InitializeOpenPolicy()
  local options=cfg()
  if not options.autoOpenPolicyVersion then
    if not options.autoOpenConfigured then options.autoOpen=true;self.openOnPolicyUpgrade=true end
    options.autoOpenPolicyVersion=1
  end
end
function P:OnEnable()
  self:InitializeOpenPolicy()
  local events=CreateFrame("Frame");self.events=events
  for _,event in ipairs({"GROUP_ROSTER_UPDATE","GROUP_JOINED","GROUP_LEFT","PLAYER_ENTERING_WORLD","PLAYER_LOGOUT","PLAYER_REGEN_ENABLED","UNIT_CONNECTION","UNIT_LEVEL","UNIT_NAME_UPDATE","PLAYER_ROLES_ASSIGNED","READY_CHECK","READY_CHECK_CONFIRM","READY_CHECK_FINISHED","ZONE_CHANGED_NEW_AREA","CHAT_MSG_PARTY","CHAT_MSG_PARTY_LEADER","CHAT_MSG_RAID","CHAT_MSG_RAID_LEADER","CHAT_MSG_RAID_WARNING","CHAT_MSG_INSTANCE_CHAT","CHAT_MSG_INSTANCE_CHAT_LEADER"})do pcall(events.RegisterEvent,events,event)end
  events:SetScript("OnEvent",function(_,event,...)
    if event:find("^CHAT_MSG_")then self:OnGroupMessage(event,select(12,...));return end
    if event=="PLAYER_LOGOUT"then self:SaveHistory();return end
    if event=="READY_CHECK"then self.readyCheck=true elseif event=="READY_CHECK_FINISHED"then self.readyCheck=nil end
    if event=="GROUP_LEFT"then self.leftSinceRefresh=true end
    if event=="PLAYER_REGEN_ENABLED"then
      if self.pendingRestore then self.pendingRestore=nil;self:RestoreWindow()end
      if self.pendingOpen then local automatic=self.pendingAutomatic;self.pendingOpen=nil;self:Open(automatic)end
      if self.pendingConfigure and self.frame then self:ConfigureFrame(self.frame,false)end
      if self.pendingLayout and self.frame then self.pendingLayout=nil;Core:GetModule("UIManager"):RefreshChatFrameLayout(self.frame)end
    end
    self:ScheduleRoster()
  end)
  if ChatFrame_AddMessageEventFilter then
    self.messageFilter=self.messageFilter or function(frame,event)return self:FilterMessage(frame,event)end
    for _,event in ipairs({"CHAT_MSG_PARTY","CHAT_MSG_PARTY_LEADER","CHAT_MSG_RAID","CHAT_MSG_RAID_LEADER","CHAT_MSG_RAID_WARNING","CHAT_MSG_INSTANCE_CHAT","CHAT_MSG_INSTANCE_CHAT_LEADER"})do ChatFrame_AddMessageEventFilter(event,self.messageFilter)end
  end
  Core:Subscribe(Constants.EVENTS.UPDATE_CONFIG,function()if self.room then self:LayoutRoomChrome();self.room:LayoutHub()end end)
  Core:Subscribe(Constants.EVENTS.UNLOCK_MOVER,function()if self.room then if self.room.minimized then self.room:SetMinimized(false,true)end;self.room.hubOverlay:Show()end end)
  Core:Subscribe(Constants.EVENTS.LOCK_MOVER,function()if self.room then self.room:StopHubMove();self.room.hubResize:FinishResize();self.room.hubOverlay:Hide()end end)
  Core.db.RegisterCallback(self,"OnDatabaseShutdown",function()self:SaveHistory()end)
  C_Timer.After(1,function()
    self:RefreshRoster()
    self:RestoreWindow()
  end)
end
Core:RegisterFeature("partyChat",{name="Party Chat",order=13,buildOptions=function()
  return {type="group",args={
    intro={type="description",order=0,name="A shared party/raid room with compact members, class/level, leader and role information. Previous groups remain available with member previews and read-only chat logs. Header unread counts have no toasters."},
    open={type="execute",name="Open Party Chat",order=1,func=function()P:Open()end},
    history={type="execute",name="Previous groups",order=1.5,func=function()P:Open();P:ToggleHistory(true)end},
    enabled={type="toggle",name="Enable Party Chat",order=2,get=function()return cfg().enabled end,set=function(_,v)cfg().enabled=v;if not v and P.room then P:CloseRoom();if P.frame then P.frame:Hide()end end end},
    automatic={type="toggle",name="Open manually only",desc="Turn off automatic opening when joining a party. Window geometry and minimized state are still remembered.",order=3,get=function()return not cfg().autoOpen end,set=function(_,v)cfg().autoOpen=not v;cfg().autoOpenConfigured=true;if not v and P.grouped then P:Open(true)end end},
    raids={type="toggle",name="Follow the group into raids",order=4,get=function()return cfg().followRaid end,set=function(_,v)cfg().followRaid=v;P:ScheduleRoster()end},
    roster={type="toggle",name="Show members",order=5,get=function()return cfg().rosterShown end,set=function(_,v)cfg().rosterShown=v;if P.room then P.room:LayoutHub()end end},
    collapse={type="select",name="Collapse toward",order=6,values={TOP="Top - restore downward",BOTTOM="Bottom - restore upward"},get=function()return P:EnsureRoom():HubSettings().minimizeEdge or "TOP"end,set=function(_,v)local h=P:EnsureRoom();if h.finishCollapse then h.finishCollapse()end;if h.minimized then h:SetMinimized(false,true)end;h:HubSettings().minimizeEdge=v end},
    remember={type="toggle",name="Save group conversations",order=7,get=function()return cfg().remember end,set=function(_,v)cfg().remember=v;if not v then P.historyGeneration=(P.historyGeneration or 0)+1;P.restoringHistory=nil end end},
  }}
end})
