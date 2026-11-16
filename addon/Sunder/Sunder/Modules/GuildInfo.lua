local Core=unpack(select(2,...))
local G=Core:GetModule("GuildChat")
local function theme()return Core:GetModule("Whispers")end
local function wm()return Core.Components.WindowManager end
local function safe(value,limit)
  if _G.canaccessvalue and not _G.canaccessvalue(value)then return ""end
  return type(value)=="string" and value:sub(1,limit or 1024):gsub("|","||") or ""
end
local function state()
  local s=Core.db.char.guildChat
  theme():MigratePersonFavorites()
  if s.favoriteGuild~=G.currentGuild then s.favoriteGuild=G.currentGuild;s.memberPins={}end
  s.memberPins=s.memberPins or {};return s
end
function G:IsMemberFavorite(member)
  state()
  return member and member.guildKey==self.currentGuild and theme():IsPersonFavorite(member.key)
end
function G:IsMemberPinned(member)
  return member and member.guildKey==self.currentGuild and state().memberPins[member.key]==true
end
function G:ToggleMemberPin(member)
  if not member or member.guildKey~=self.currentGuild then return end
  local pins=state().memberPins
  if pins[member.key]then pins[member.key]=nil else
    local count=0;for _ in pairs(pins)do count=count+1 end
    if count>=200 then self:Report("You can pin up to 200 guild members.");return end
    pins[member.key]=true
  end
  self:FilterRoster(false)
end
function G:ToggleMemberFavorite(member)
  if not member or member.guildKey~=self.currentGuild then return end
  state()
  if theme().RememberPersonDetails then theme():RememberPersonDetails(member.name,member)end
  theme():SetPersonFavorite(member.key,member.name,not self:IsMemberFavorite(member))
end
function G:SetRosterFilter(key)
  if key~="all" and key~="zone" and key~="favorites"then return end
  self.rosterFilter=key;self:FilterRoster()
end
function G:LayoutRosterFilters(top,width)
  if not self.rosterFilters then
    local bar=CreateFrame("Frame",nil,self.panel);self.rosterFilters=bar;bar.buttons={}
    for _,entry in ipairs({{"all","Online","Online members; include offline members in settings."},{"zone","Zone","Online members in your current zone."},{"favorites","","Your favorite guild members, including offline members."}})do
      local key,label,tip=entry[1],entry[2],entry[3]
      local b=CreateFrame("Button",nil,bar);bar.buttons[#bar.buttons+1]=b;b.key=key
      b:SetNormalFontObject("SunderChatDockFont");b:SetText(label~="" and label or " ")
      b.plate=b:CreateTexture(nil,"BACKGROUND");b.plate:SetAllPoints()
      b.indicator=b:CreateTexture(nil,"OVERLAY");b.indicator:SetPoint("BOTTOMLEFT",3,0);b.indicator:SetPoint("BOTTOMRIGHT",-3,0);b.indicator:SetHeight(1)
      b.icon=b:CreateTexture(nil,"ARTWORK");b.icon:SetTexture("Interface\\AddOns\\Sunder\\Media\\Icons\\favorite.tga");b.icon:SetSize(12,12);b.icon:SetPoint("CENTER");b.icon:SetShown(key=="favorites")
      local function style()wm():StyleFilterButton(b,(self.rosterFilter or "all")==key,b.hovered,theme():InterfaceAccent())end
      b:SetScript("OnEnter",function()b.hovered=true;style();GameTooltip:SetOwner(b,"ANCHOR_TOP");GameTooltip:AddLine(key=="favorites" and "Favorite members" or label,1,1,1);GameTooltip:AddLine(tip,.7,.75,.8,true);GameTooltip:Show()end)
      b:SetScript("OnLeave",function()b.hovered=nil;style();GameTooltip:Hide()end)
      b:SetScript("OnClick",function()self:SetRosterFilter(key)end)
    end
  end
  local bar=self.rosterFilters;local pad=theme():BodyPadding();local cell=math.max(1,(width-pad*2)/3)
  bar:ClearAllPoints();bar:SetPoint("TOPLEFT",self.panel,"TOPLEFT",pad,-top);bar:SetSize(math.max(1,width-pad*2),22);bar:SetShown(not self.compact)
  for index,b in ipairs(bar.buttons)do
    b:ClearAllPoints();b:SetPoint("TOPLEFT",(index-1)*cell,0);b:SetSize(cell,22)
    if b.key=="all"then b:SetText(Core.db.profile.guildChat.offline and "All" or "Online")end
    local label=b:GetFontString();wm():ApplyPersonDetailFont(theme(),label);label:ClearAllPoints();label:SetPoint("LEFT",2,0);label:SetPoint("RIGHT",-2,0);label:SetWordWrap(false);label:SetJustifyH("CENTER")
    wm():StyleFilterButton(b,(self.rosterFilter or "all")==b.key,b.hovered,theme():InterfaceAccent())
  end
  return top+26
end
function G:EnsureGuildInfo()
  if self.infoDrawer then return end
  local panel=CreateFrame("Frame",nil,self.room.hubContent);self.infoDrawer=panel
  panel:SetFrameLevel(self.room.hubContent:GetFrameLevel()+12)
  panel:EnableMouse(true);wm():StyleInsetPanel(panel,self.room)
  panel.title=panel:CreateFontString(nil,"OVERLAY","SunderChatDockFont");panel.title:SetJustifyH("LEFT");panel.title:SetWordWrap(false);panel.title:SetTextColor(.84,.87,.91)
  panel.detail=panel:CreateFontString(nil,"OVERLAY","SunderChatDockFont")
  panel.close=theme():IconButton(panel,"close","Close guild information",function()self:CloseGuildInfo()end)
  panel.back=theme():IconButton(panel,"left","Guild overview",function()self:ShowGuildInfo()end)
  local scroll=CreateFrame("ScrollFrame",nil,panel);panel.scroll=scroll;scroll:SetClipsChildren(true)
  local child=CreateFrame("Frame",nil,scroll);panel.child=child;scroll:SetScrollChild(child)
  panel.body=child:CreateFontString(nil,"OVERLAY","SunderChatDockFont");panel.body:SetJustifyH("LEFT");panel.body:SetWordWrap(true);panel.body:SetTextColor(.68,.72,.78)
  scroll:EnableMouseWheel(true)
  scroll:SetScript("OnMouseWheel",function(_,delta)
    scroll:SetVerticalScroll(math.max(0,math.min(math.max(0,child:GetHeight()-scroll:GetHeight()),scroll:GetVerticalScroll()-delta*28)))
    wm():UpdateListScrollIndicator(scroll,child,true)
  end)
  panel.whisper=wm():CreateTextAction(panel,"Whisper",function()self:OpenWhisper(self:CardMember())end)
  panel.invite=wm():CreateTextAction(panel,"Invite",function()self:InviteMember(self:CardMember())end)
  panel.favorite=theme():IconButton(panel,"favorite","Favorite / unfavorite this person",function()self:ToggleMemberFavorite(self:CardMember())end)
  panel:Hide()
end
function G:CardMember()
  if self.infoGuild~=self.currentGuild then return end
  return self.infoMember and self.memberByName and self.memberByName[self.infoMember]
end
function G:CanInviteMember(member)
  if not member or not member.online or member.guildKey~=self.currentGuild or InCombatLockdown()then return false end
  local unit=UnitName and UnitName("player")
  if unit and member.name==unit then return false end
  local invite=C_PartyInfo and C_PartyInfo.InviteUnit or _G.InviteUnit
  if not invite then return false end
  if IsInGroup and IsInGroup()then return UnitIsGroupLeader and UnitIsGroupLeader("player") or UnitIsGroupAssistant and UnitIsGroupAssistant("player") or false end
  return true
end
function G:InviteMember(member)
  if not self:CanInviteMember(member)then return end
  local invite=C_PartyInfo and C_PartyInfo.InviteUnit or _G.InviteUnit
  invite(member.name)
end
function G:ShowGuildInfo()
  if not self.room then return end
  self.infoMode="guild";self.infoMember=nil;self:EnsureGuildInfo();self.infoDrawer.scroll:SetVerticalScroll(0);self.room:LayoutHub();wm():RefreshRoomActions(self.room)
end
function G:ShowMemberCard(member)
  if not member or member.guildKey~=self.currentGuild then return end
  self.infoMode="member";self.infoMember=member.key;self.infoGuild=self.currentGuild;self:EnsureGuildInfo();self.infoDrawer.scroll:SetVerticalScroll(0);self.room:LayoutHub();wm():RefreshRoomActions(self.room)
end
function G:ToggleGuildInfo()
  if self.infoMode=="guild"then self:CloseGuildInfo()else self:ShowGuildInfo()end
end
function G:CloseGuildInfo()
  self.infoMode=nil;self.infoMember=nil
  if self.infoDrawer then self.infoDrawer:Hide()end
  if self.room then self.room:LayoutHub();wm():RefreshRoomActions(self.room)end
end
function G:RefreshGuildInfo()
  if not self.infoMode or not self.infoDrawer then return end
  local p=self.infoDrawer;local person=self:CardMember();local lines={}
  local function section(label,value)
    value=safe(value,4096);if value~=""then lines[#lines+1]="|cffc0c7d0"..label.."|r\n"..value end
  end
  if self.infoMode=="member"then
    p.title:SetText(person and safe(person.name) or "Member unavailable")
    wm():StylePersonDetail(theme(),p.detail,person)
    if person then
      section("Status",person.online and "Online" or "Offline")
      section("Zone",person.zone);section("Guild rank",person.rank)
      if Core.db.profile.guildChat.publicNotes then section("Public note",person.note)end
    else section("Roster changed","This member is no longer in the current guild roster.")end
  else
    local name,rank=GetGuildInfo("player");p.title:SetText("Guild info")
    p.detail:SetText(tostring(self.onlineCount or 0).." online / "..tostring(self.totalCount or 0).." members");p.detail:SetTextColor(.65,.7,.76);p.detail:SetWordWrap(false);p.detail:SetJustifyH("LEFT");p.detail:Show()
    section("Guild",name);section("Your rank",rank)
    local motd=GetGuildRosterMOTD and GetGuildRosterMOTD() or C_GuildInfo and C_GuildInfo.GetMOTD and C_GuildInfo.GetMOTD()
    section("Message of the day",motd)
    local get=GetGuildInfoText or C_GuildInfo and C_GuildInfo.GetGuildInfoText
    if get then local ok,value=pcall(get);if ok then section("Guild information",value)end end
    if self.infoClassSource~=self.members then
      local classes={};for _,member in ipairs(self.members or {})do if member.online and member.class~=""then classes[member.class]=(classes[member.class] or 0)+1 end end
      local sorted={};for class,count in pairs(classes)do sorted[#sorted+1]={class=class,count=count}end
      table.sort(sorted,function(a,b)if a.count~=b.count then return a.count>b.count end;return a.class<b.class end)
      local summary={};for _,entry in ipairs(sorted)do summary[#summary+1]=entry.class.."  ·  "..entry.count end
      self.infoClassSource,self.infoClassSummary=self.members,table.concat(summary,"\n")
    end
    section("Online by class",self.infoClassSummary)
  end
  p.back:SetShown(self.infoMode=="member")
  p.whisper:SetShown(self.infoMode=="member");p.invite:SetShown(self.infoMode=="member");p.favorite:SetShown(self.infoMode=="member")
  p.whisper:SetEnabled(person and person.online and not InCombatLockdown() or false)
  p.invite:SetEnabled(self:CanInviteMember(person))
  p.favorite:SetEnabled(person~=nil);wm():SetActionSelected(p.favorite,self:IsMemberFavorite(person),"favorite")
  p.body:SetText(table.concat(lines,"\n\n"));theme():WorkspaceFont(p.body,theme():InterfaceTextSize())
  local textHeight=p.body:GetStringHeight();p.child:SetHeight(math.max(1,textHeight+8))
  p.scroll:SetVerticalScroll(math.max(0,math.min(p.scroll:GetVerticalScroll(),p.child:GetHeight()-p.scroll:GetHeight())))
  wm():UpdateListScrollIndicator(p.scroll,p.child,true)
end
function G:LayoutGuildInfo(sidebar,top,height)
  if not self.infoMode then if self.infoDrawer then self.infoDrawer:Hide()end;return 0,false end
  self:EnsureGuildInfo()
  local p=self.infoDrawer;wm():StyleInsetPanel(p,self.room);local room=self.room.hub:GetWidth()-sidebar
  local replace=room<520;local width=replace and room or 280
  local pad=theme():BodyPadding();local size=theme():InterfaceTextSize()
  p:ClearAllPoints();p:SetPoint("TOPRIGHT",self.room.hubContent,"TOPRIGHT",0,-top);p:SetSize(math.max(1,width),math.max(1,height-top));p:Show()
  p.close:ClearAllPoints();p.close:SetPoint("TOPRIGHT",-pad,-pad);p.close:SetSize(22,22)
  p.back:ClearAllPoints();p.back:SetPoint("TOPLEFT",pad,-pad);p.back:SetSize(22,22)
  local titleLeft=pad+(self.infoMode=="member" and 26 or 0)
  p.title:ClearAllPoints();p.title:SetPoint("TOPLEFT",titleLeft,-pad);p.title:SetPoint("TOPRIGHT",-pad-26,-pad);p.title:SetHeight(size+4);theme():WorkspaceFont(p.title,size)
  p.detail:ClearAllPoints();p.detail:SetPoint("TOPLEFT",pad,-pad-size-8);p.detail:SetPoint("TOPRIGHT",-pad,-pad-size-8);p.detail:SetHeight(size+3);wm():ApplyPersonDetailFont(theme(),p.detail)
  local footer=self.infoMode=="member" and 38 or pad
  p.scroll:ClearAllPoints();p.scroll:SetPoint("TOPLEFT",pad,-pad-size*2-18);p.scroll:SetPoint("BOTTOMRIGHT",-pad,-footer)
  p.child:SetWidth(math.max(1,width-pad*2));p.body:ClearAllPoints();p.body:SetPoint("TOPLEFT");p.body:SetWidth(math.max(1,width-pad*2-10))
  p.whisper:ClearAllPoints();p.whisper:SetPoint("BOTTOMLEFT",pad,pad);p.whisper:SetSize(math.max(1,(width-pad*2-34)/2),24)
  p.invite:ClearAllPoints();p.invite:SetPoint("LEFT",p.whisper,"RIGHT",4,0);p.invite:SetSize(math.max(1,(width-pad*2-34)/2),24)
  p.favorite:ClearAllPoints();p.favorite:SetPoint("BOTTOMRIGHT",-pad,pad);p.favorite:SetSize(24,24)
  for _,button in ipairs({p.whisper,p.invite})do
    local label=button:GetFontString();theme():WorkspaceFont(label,size);label:ClearAllPoints();label:SetPoint("LEFT",3,0);label:SetPoint("RIGHT",-3,0);label:SetWordWrap(false)
  end
  self:RefreshGuildInfo()
  if p.scroll.UpdateScrollChildRect then p.scroll:UpdateScrollChildRect()end
  return replace and 0 or width,replace
end
