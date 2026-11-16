local Core, Constants = unpack(select(2,...))
local G=Core:GetModule("GuildChat")
local TITLE="Guild Chat"
local MAX_MEMBERS=10000
local function accessible(v)return not _G.canaccessvalue or _G.canaccessvalue(v)end
local function text(v)return accessible(v) and type(v)=="string" and not v:find("|K",1,true) and v or "" end
local function number(v,fallback)return accessible(v) and type(v)=="number" and v or fallback end
local function profile()return Core.db.profile.guildChat end
local function state()Core.db.char.guildChat=Core.db.char.guildChat or {};return Core.db.char.guildChat end
local function theme()return Core:GetModule("Whispers")end
local function guildName()return GetGuildInfo and text(GetGuildInfo("player")) or "" end
local function guildKey()
  local name=guildName();if name=="" then return end
  return name.."@"..(GetRealmName and text(GetRealmName()) or "")
end
local function native(frame,method,global,...)
  if frame[method] then frame[method](frame,...);return true end
  if _G[global] then _G[global](frame,...);return true end
end
Core.defaults.profile.guildChat={enabled=true,rosterShown=true,publicNotes=true,offline=false,sort="rank",remember=true}
Core.Components.InstallRosterRoom(G,{id="guild",frameName="SunderGuildRoom",editKey="Sunder_GuildChat",settings="guild",nativeTitle="Guild Chat",nativeGroups={GUILD=true},info=true,infoAction=function(g)g:ToggleGuildInfo()end,infoSelected=function(g)return g.infoMode=="guild"end,
  title=function()return "Guild Chat"end,caption=function()return guildName()end,
  subtitle=function()return GetGuildRosterMOTD and text(GetGuildRosterMOTD()) or C_GuildInfo and C_GuildInfo.GetMOTD and text(C_GuildInfo.GetMOTD()) or ""end,
  state=state,profile=profile,scope=guildKey,historyKey="guildRoomHistory",historyTypes={"GUILD"}})


-- Unread is session-only and driven by incoming guild events, never history replay.
function G:UpdateUnread()
  local h=self.room;if not h then return end
  if h.unreadBadge then
    Core.Components.WindowManager:StyleUnreadIndicator(h.unreadBadge,self.unread or 0,h:InterfaceAccent())
  end
end
function G:AcknowledgeMessages()
  self.unread=0;self:UpdateUnread()
end
function G:OnGuildMessage(sender,guid)
  if not profile().enabled then return end
  local own=UnitGUID and UnitGUID("player")
  if accessible(guid) and own and guid==own then return end
  local h=self.room
  if h and h.hub:IsShown() and not h.minimized and not h.collapseAnimation then self:AcknowledgeMessages();return end
  self.unread=math.min(9999,(self.unread or 0)+1);self:UpdateUnread()
end
function G:CollapseToward(edge)
  Core.Components.WindowManager:CollapseToward(self:EnsureRoom(),edge)
end
function G:Report(message)Core:GetModule("Config"):Print(message)end
function G:IsRoom(frame)return self.frame==frame and profile().enabled end
function G:RefreshRoster()
  self.rosterGeneration=(self.rosterGeneration or 0)+1
  local generation=self.rosterGeneration
  self.rosterDirty=nil
  local key=guildKey()
  if not key or not GetGuildRosterInfo or not GetNumGuildMembers then
    self.members={};self.filtered={};self.memberByName={};self.onlineCount=0;self.totalCount=0
    self.rosterStatus=not key and "Join a guild to enter its chat room." or "Guild roster is unavailable on this client."
    self:RenderRoster();return
  end
  local ok,count=pcall(GetNumGuildMembers,true)
  count=ok and math.max(0,math.min(MAX_MEMBERS,number(count,0))) or 0
  local members,seen={},{};local onlineCount=0;local index=1
  local function chunk()
    if generation~=self.rosterGeneration or key~=guildKey() or not self.panel or not self.room or not self.room.hub:IsVisible() then return end
    local last=math.min(count,index+99)
    for i=index,last do
      -- The officer-note return is deliberately ignored; it never enters our model.
      local success,name,rank,rankIndex,level,class,zone,note,_,online,status,classFile=pcall(GetGuildRosterInfo,i)
      name=text(name)
      if success and name~="" and not seen[name:lower()] then
        seen[name:lower()]=true
        local present=accessible(online) and (online==true or online==1) or false
        if present then onlineCount=onlineCount+1 end
        members[#members+1]={name=name,key=name:lower(),guildKey=key,rank=text(rank),rankIndex=number(rankIndex,999),
          level=number(level,0),class=text(class),classFile=text(classFile),zone=text(zone),note=text(note):gsub("[\r\n]"," "),online=present,
          status=accessible(status) and status or nil}
      end
    end
    index=last+1
    if index<=count then C_Timer.After(0,chunk) else
      self.members=members;self.onlineCount=onlineCount;self.totalCount=#members
      self.rosterStatus=#members==0 and "Waiting for the guild roster…" or nil
      self:FilterRoster(false)
    end
  end
  chunk()
end
function G:ScheduleRoster(request)
  self.rosterDirty=true
  if not self.panel or not self.room or not self.room.hub:IsVisible() then return end
  if request and (not self.lastRosterRequest or GetTime()-self.lastRosterRequest>=10) then
    self.lastRosterRequest=GetTime()
    local fetch=C_GuildInfo and C_GuildInfo.GuildRoster or _G.GuildRoster
    if fetch then pcall(fetch) end
  end
  if self.rosterScheduled then return end
  self.rosterScheduled=true
  C_Timer.After(.2,function()self.rosterScheduled=nil;if self.room and self.room.hub:IsVisible() then self:RefreshRoster() end end)
end
function G:FilterRoster(resetScroll)
  local list={};local query=(self.query or ""):lower()
  for _,member in ipairs(self.members or {}) do
    local filter=self.rosterFilter or "all"
    local zone=GetRealZoneText and GetRealZoneText() or GetZoneText and GetZoneText() or ""
    local visible=(filter=="favorites" and self:IsMemberFavorite(member)) or (filter~="favorites" and (profile().offline or member.online))
    if filter=="zone"then visible=member.online and zone~="" and member.zone==zone end
    if visible and (query=="" or
      (member.name.." "..member.rank.." "..(profile().publicNotes and member.note or "")):lower():find(query,1,true)) then list[#list+1]=member end
  end
  table.sort(list,function(a,b)
    local ap=Core.Components.WindowManager:PersonPriority(self:IsMemberFavorite(a),self:IsMemberPinned(a))
    local bp=Core.Components.WindowManager:PersonPriority(self:IsMemberFavorite(b),self:IsMemberPinned(b))
    if ap~=bp then return ap<bp end
    if a.online~=b.online then return a.online end
    if profile().sort=="rank" and a.rankIndex~=b.rankIndex then return a.rankIndex<b.rankIndex end
    return a.key<b.key
  end)
  self.memberByName={}
  for _,member in ipairs(self.members or {})do self.memberByName[member.name:lower()]=member end
  if theme().QueuePersonRefresh then theme():QueuePersonRefresh()end
  self.filtered=list

  if self.scroll and resetScroll~=false then self.scroll:SetVerticalScroll(0) end
  self:RenderRoster()
  if self.room then self:LayoutRoomChrome();self.room:LayoutHub();if self.RefreshGuildInfo then self:RefreshGuildInfo()end end
end
function G:OpenWhisper(member)
  if not member or not member.online or InCombatLockdown() or self.currentGuild~=guildKey() or member.guildKey~=self.currentGuild then return end
  theme():OpenSavedFavorite({key=member.key,target=member.name})
end
function G:ConfigureFrame(frame,created)
  local firstConfiguration=self.configuredFrame~=frame
  if self.closedSlots then self.closedSlots[frame]=nil end
  self.frame=frame;self.currentGuild=guildKey()
  if created then
    if not native(frame,"RemoveAllMessageGroups","ChatFrame_RemoveAllMessageGroups") or
      not native(frame,"AddMessageGroup","ChatFrame_AddMessageGroup","GUILD") then
      self.frame=nil;if FCF_Close then FCF_Close(frame)end;self:Report("This client cannot create a dedicated guild chat window.");return false
    end
    native(frame,"RemoveAllChannels","ChatFrame_RemoveAllChannels")
    frame.chatType="GUILD"
    if frame.isDocked then FCF_UnDockFrame(frame)end
    frame:ClearAllPoints();frame:SetPoint("CENTER",UIParent,"CENTER",80,70);frame:SetSize(760,380)
    if FCF_SavePositionAndDimensions then FCF_SavePositionAndDimensions(frame)end
  end
  frame:SetClampedToScreen(true)
  local ui=Core:GetModule("UIManager")
  local window=ui:GetChatWindow(frame) or ui:CreateChatWindow(frame,false)
  ui:CreateChatEditBox(window)
  local input=window.editBox
  if input and self.configuredFrame~=frame then
    if input.SetChatType then input:SetChatType("GUILD")elseif input.SetAttribute then input:SetAttribute("chatType","GUILD")end
    if input.SetStickyType then input:SetStickyType("GUILD")elseif input.SetAttribute then input:SetAttribute("stickyType","GUILD")end
  end
  self.configuredFrame=frame
  -- The native slot may have rendered its login MOTD before Guild claimed it.
  if firstConfiguration and window.slidingMessageFrame.ReloadMessagesFromChatFrame then window.slidingMessageFrame:ReloadMessagesFromChatFrame()end
  if not frame.sunderGuildHooks then
    frame.sunderGuildHooks=true
    frame:HookScript("OnShow",function()if self.frame==frame then if not self.room then state().open=true end;self:ScheduleRoster(true)end end)
    frame:HookScript("OnHide",function()if self.frame==frame then if not self.room then state().open=false end;self:SaveHistory()end end)
  end
  state().frameID=frame:GetID()
  ui:RefreshChatFrameLayout(frame)
  self:RestoreHistory()
  return true
end
function G:Open()
  if not profile().enabled then self:Report("Enable Guild Chat in Sunder's Chat settings first.");return end
  if not guildKey() then self:Report("Join a guild to open its Guild Chat room.");return end
  local frame=self.frame or self:SavedFrame();local created=false
  if InCombatLockdown() and (not frame or frame:IsProtected()) then self.pendingOpen=true;self:Report("Guild Chat will open after combat.");return end
  if not frame then
    if not FCF_OpenNewWindow then self:Report("Native chat window creation is unavailable.");return end
    frame=FCF_OpenNewWindow(TITLE,true);created=true
    if not frame then self:Report("All native chat slots are in use. Close an unused chat tab and try again.");return end
  end
  if not self:ConfigureFrame(frame,created)then return end
  if frame.isDocked then FCF_UnDockFrame(frame)end
  frame:Show();state().open=true
  local h=self:EnsureRoom();h.windowManuallyClosed=false
  if h.minimized then h:SetMinimized(false,true)end
  h.hub:Show();h.hubContent:Show();self:AcknowledgeMessages()
  Core:GetModule("UIManager"):RefreshChatFrameLayout(frame)
  Core:GetModule("UIManager"):SelectMessageInput(frame)
  self:ScheduleRoster(true)
end
function G:OnWindowClosed(frame)
  if self.frame~=frame then return end
  self.closedSlots=self.closedSlots or {};self.closedSlots[frame]=true
  self.historyGeneration=(self.historyGeneration or 0)+1
  self:SaveHistory(true);self.rosterGeneration=(self.rosterGeneration or 0)+1
  state().open=false;state().frameID=nil
  if self.room then self.room.hub:Hide()end
  if self.panel then self.panel:Hide();self.column:Hide();self.surface:Hide()end
  local window=Core:GetModule("UIManager"):GetChatWindow(frame)
  if window then
    self:ClearRoomLayout(window)
  end
  self.frame=nil;self.panel=nil;self.members=nil;self.restoredFrame=nil;self.configuredFrame=nil;self.roomFrame=nil;self.restoringHistory=nil
end
-- Native MOTD uses the GUILD type too, but is a fresh login notice, not history.
local function startupNotice(value)
  local template=text(GUILD_MOTD_TEMPLATE)
  if template=="" then return false end
  local ok,formatted=pcall(string.format,template,"SUNDER_MOTD_TOKEN")
  if not ok then return false end
  local before,after=formatted:match("^(.-)SUNDER_MOTD_TOKEN(.-)$")
  if not before then return false end
  local function escape(s)return (s:gsub("(%W)","%%%1"))end
  return value:match("^"..escape(before)..".*"..escape(after).."$")~=nil
end
function G:IsStartupNotice(value)return startupNotice(text(value))end
function G:OnEnable()
  local events=CreateFrame("Frame");self.events=events
  for _,event in ipairs({"CHAT_MSG_GUILD","GUILD_ROSTER_UPDATE","PLAYER_GUILD_UPDATE","GUILD_MOTD","PLAYER_ENTERING_WORLD","PLAYER_LOGOUT","PLAYER_REGEN_ENABLED","PLAYER_REGEN_DISABLED","ZONE_CHANGED","ZONE_CHANGED_NEW_AREA","GROUP_ROSTER_UPDATE"})do pcall(events.RegisterEvent,events,event)end
  events:SetScript("OnEvent",function(_,event,unit,...)
    if event=="CHAT_MSG_GUILD" then local sender=select(1,...);local guid=select(11,...);self:OnGuildMessage(sender,guid);return end
    if event=="PLAYER_LOGOUT" then self:SaveHistory();return end
    if event=="PLAYER_REGEN_DISABLED"then if self.RefreshGuildInfo then self:RefreshGuildInfo()end;return end
    if event=="PLAYER_REGEN_ENABLED" then
      if self.pendingRestore then self.pendingRestore=nil;self:RestoreWindow()end
      if self.pendingOpen then self.pendingOpen=nil;self:Open()end
      if self.pendingLayout and self.frame then self.pendingLayout=nil;Core:GetModule("UIManager"):RefreshChatFrameLayout(self.frame)end
      if self.RefreshGuildInfo then self:RefreshGuildInfo()end
      return
    end
    if event=="PLAYER_GUILD_UPDATE" and unit and unit~="player" then return end
    if self.currentGuild~=guildKey() then
      self.historyGeneration=(self.historyGeneration or 0)+1;self.restoringHistory=nil
      self.selectedMember=nil;self.selectedGuild=nil
      self:AcknowledgeMessages()
      self.currentGuild=guildKey();self.members={};self.filtered={};self.memberByName={};self.onlineCount=0;self.totalCount=0;self.rosterGeneration=(self.rosterGeneration or 0)+1
      if self.search then self.search:SetText("")end
      if self.frame then self.frame:Clear();self.restoredFrame=nil end
      self:RenderRoster()
    end
    if event=="GUILD_MOTD" and self.room then self.room:LayoutHub()end
    self:ScheduleRoster(false)
  end)
  Core:Subscribe(Constants.EVENTS.UPDATE_CONFIG,function()
    if self.frame then self:LayoutRoomChrome();Core:GetModule("UIManager"):RefreshChatFrameLayout(self.frame)end
  end)
  Core:Subscribe(Constants.EVENTS.UNLOCK_MOVER,function()if self.room then if self.room.hub:IsShown() and self.room.minimized then self.room:SetMinimized(false,true)end;self.room.hubOverlay:Show()end end)
  Core:Subscribe(Constants.EVENTS.LOCK_MOVER,function()
    if self.room then self.room:StopHubMove();self.room.hubResize:FinishResize();self.room.hubOverlay:Hide()end
  end)
  Core.db.RegisterCallback(self,"OnDatabaseShutdown",function()self:SaveHistory()end)
  C_Timer.After(1,function()self:RestoreWindow()end)
end
Core:RegisterFeature("guildChat",{name="Guild Chat",order=12,buildOptions=function()
  local function refresh()if G.frame then Core:GetModule("UIManager"):RefreshChatFrameLayout(G.frame);G:FilterRoster()end end
  return {type="group",args={
    intro={type="description",order=0,name="A native guild chat room with a live, rank-sorted roster. Player names use class colors; guild rank and public notes are subdued. Officer notes and officer chat are never included."},
    open={type="execute",name="Open Guild Chat room",order=1,func=function()G:Open()end},
    enabled={type="toggle",name="Enable Guild Chat room",order=2,get=function()return profile().enabled end,set=function(_,v)
      profile().enabled=v
      if G.frame then
        if not v then G:CloseRoom();G.frame:Hide();if G.panel then G.panel:Hide();G.column:Hide();G.surface:Hide()end end
        Core:GetModule("UIManager"):RefreshChatFrameLayout(G.frame)
      end
    end},
    collapse={type="select",name="Collapse toward",order=2.5,values={TOP="Top - restore downward",BOTTOM="Bottom - restore upward"},get=function()return G:EnsureRoom():HubSettings().minimizeEdge or "TOP"end,set=function(_,v)
      local h=G:EnsureRoom();if h.finishCollapse then h.finishCollapse()end;if h.minimized then h:SetMinimized(false,true)end;h:HubSettings().minimizeEdge=v
    end},
    roster={type="toggle",name="Show member roster",order=3,get=function()return profile().rosterShown end,set=function(_,v)profile().rosterShown=v;refresh()end},
    notes={type="toggle",name="Show public notes beside rank",order=4,get=function()return profile().publicNotes end,set=function(_,v)profile().publicNotes=v;refresh()end},
    offline={type="toggle",name="Include offline members",order=5,get=function()return profile().offline end,set=function(_,v)profile().offline=v;refresh()end},
    sort={type="select",name="Member order",order=7,values={rank="Guild rank, then name",name="Player name"},get=function()return profile().sort end,set=function(_,v)profile().sort=v;refresh()end},
    remember={type="toggle",name="Remember recent guild messages",order=8,get=function()return profile().remember end,set=function(_,v)profile().remember=v;if not v then Core.db.char.guildRoomHistory=nil;G.historyGeneration=(G.historyGeneration or 0)+1;G.restoringHistory=nil end end},
    help={type="description",order=9,name="Open with /sunder guild or Control-click the minimap button. The room uses one native chat slot and leaves your other chat filters alone. Its header shares Whispers chrome: drag the grip or title anytime; minimize, maximize and restore from the header. Drag the lower-right corner to resize, or use Unlock Sunder windows / Ellesmere Edit UI. Expanded size is capped for readable lines on ultrawide screens. The roster shares the 150 px people-column width and shrinks only in narrow windows. Short windows compact it; Show members restores enough height. Click a member for their detail card, favorite, Whisper and Invite actions; double-click still opens a whisper without sending. Use Guild Info for the overview and roster filters to narrow the list. Roster updates are event-driven and only visible rows create controls. Up to 200 recent guild messages are remembered locally per character (512 KiB text cap), isolated by guild and realm. No offline guild message retrieval is available."},
  }}
end})
