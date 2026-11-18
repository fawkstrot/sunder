local Core = unpack(select(2, ...))
local C = Core.Components
local Practice = {}
C.ChatPractice = Practice

-- Each delay is relative to the preceding event. The fixture plays this exact script.
local chapters = {
  {name="Whispers", events={
    {0,"room","Whispers",2}, {1,"select","Elowen"},
    {2,"message","Elowen","The lift is here. I'll wait at the top."},
    {4,"reply","Elowen","On my way."},
    {12,"message","Mira","I found another entrance. Can you see my message?"},
    {4,"collapse"}, {3,"message","Elowen","Still here when you're ready."},
    {4,"expand"}, {4,"detach","Mira"}, {3,"message","Mira","This reply follows the detached conversation."},
    {5,"attach","Mira"},
  }},
  {name="Groups", events={
    {0,"room","Guild",8}, {1,"message","Elowen","Welcome back. The next guild run starts at dusk."},
    {5,"room","Party",3}, {1,"message","Elowen","Leader here. Meet us by the bridge."},
    {3,"message","Mira","Ready when you are."}, {5,"leave"},
    {4,"room","Party",2}, {1,"message","Mira","We're the new group."},
    {3,"archive"}, {8,"message","Elowen","This arrived while the previous group was on screen."},
    {4,"live"}, {4,"channel","Raid",40}, {2,"message","Elowen","Raid warning: move away from the door."},
    {4,"offline","Mira"}, {4,"channel","Instance",5}, {3,"message","Mira","Everyone is inside."}, {4,"leave"},
  }},
  {name="Windows", events={
    {0,"room","General",0}, {1,"message","Elowen","[General] Has anyone seen the caravan today?"},
    {3,"burst"}, {8,"room","Combat Log",0}, {1,"message","Training dummy","Practice strike hits for 42."},
    {3,"collapse"}, {4,"expand"}, {4,"room","Detached chat",0},
    {2,"message","Mira","Resize the window while reading this line: "..string.rep("Moonstone",18)},
  }},
}
Practice.chapters = chapters

local function action(parent,label,callback,width)
  local button=C.WindowManager:CreateTextAction(parent,label,callback)
  button:SetSize(width,24)
  return button
end

local function createRoom()
  local state,profile={}, {rosterShown=true}
  local r={kind="General",members={},filtered={},records={},log={},archives={},profile=profile}
  C.InstallRosterRoom(r,{
    id="chatPractice", isolated=true, frameName="SunderChatPracticeRoom", settings="whispers",
    title=function()return "Practice · "..r.kind end,
    caption=function()return r.caption or r.kind end, subtitle=function()return "" end,
    hasRoster=function()return #r.members>0 end, showSearch=function()return r.kind=="Raid" end,
    info=true, infoActionID="Archive", infoTooltip="Practice group history", infoAction=function()r:ToggleHistory(not r.historyMode)end,
    infoSelected=function()return r.historyMode end, state=function()return state end, profile=function()return profile end,
  })
  local party=Core:GetModule("PartyChat")
  for _,key in ipairs({"EnsureHistory","RenderHistoryList","LayoutHistory","SelectHistory","HistoryTimeline","RoomSurfaceLayout"}) do r[key]=party[key] end
  function r:HistoryRecords()return self.archives end
  function r:UpdateUnread()
    local unread=0
    for _,person in ipairs(self.members) do unread=unread+person.unread end
    if self.room and self.room.unreadBadge then
      C.WindowManager:StyleUnreadIndicator(self.room.unreadBadge,unread,self.room:InterfaceAccent())
    end
  end
  function r:AcknowledgeMessages()self:UpdateUnread()end
  function r:IsRoom(frame)return self.frame and frame==self.frame end
  function r:ScheduleRoster()end
  function r:CanSend()return false end
  function r:CloseRoom()Practice:Stop()end
  function r:SelectInput()end
  function r:IsMemberFavorite(p)return p.favorite end
  function r:IsMemberPinned(p)return p.pinned end
  function r:ToggleMemberFavorite(p)p.favorite=not p.favorite;self:FilterRoster()end
  function r:ToggleMemberPin(p)p.pinned=not p.pinned;self:FilterRoster()end
  function r:FilterRoster()
    self.filtered={}
    for _,p in ipairs(self.members) do
      if p~=Practice.detachedPerson and p.name:lower():find((self.query or ""):lower(),1,true) then
        self.filtered[#self.filtered+1]=p
      end
    end
    table.sort(self.filtered,function(a,b)
      local x=C.WindowManager:PersonPriority(a.favorite,a.pinned)
      local y=C.WindowManager:PersonPriority(b.favorite,b.pinned)
      if x~=y then return x<y end
      return a.index<b.index
    end)
    self:RenderRoster()
  end
  function r:ShowMemberCard(p)
    self.selectedMember,self.selectedGuild=p.key,p.guildKey
    if self.kind=="Whispers" then
      p.unread=0;self.caption=p.name
      self.room:DismissMinimizedWhisper(p)
      self.window.readOnlyTranscript:SetLines(p.lines,self.frame)
    end
    self:UpdateUnread()
    self.room:LayoutHub()
    Practice:RefreshDraft()
  end
  function r:OpenWhisper(p)self:ShowMemberCard(p)end
  function r:ToggleHistory(open)
    self.historyMode=open and #self.archives>0
    if self.historyMode then
      self:EnsureHistory()
      self:SelectHistory(self.archives[1].key)
    end
    self.room:LayoutHub()
    Practice:RefreshDraft()
  end
  local h=r:EnsureRoom()
  local saveState=h.SaveMessageWindowState
  function h:SaveMessageWindowState()
    saveState(self)
    Practice:RefreshDraft()
  end
  r.frame=CreateFrame("Frame",nil,h.parking)
  r.window={chatFrame=r.frame,tab=CreateFrame("Frame",nil,h.parking),
    readOnlyTranscript=C.CreateReadOnlyTranscript(h.hubContent,r.frame)}
  function h:LayoutHub()
    if self.minimized or self.collapseAnimation then return end
    if not r.historyMode then r:LayoutWindow(r.window) end
    if r.historyPanel then r:LayoutHistory() end
  end
  h.hubActionButtons.Archive.windowEnabled=function()return #r.archives>0 and not h.minimized end
  -- Only sample entries reach this private tray. Clicks resolve inside the practice roster.
  h.UpdateMinimizedWhispers=C.UpdateWhisperToastTray
  h.QueueMinimizedWhisper=C.WhisperToastQueue
  function h:OpenMinimizedWhisper(entry)
    if Practice.active and entry and r.records[entry.person.name]==entry.person then
      self:SetMinimized(false,true);r:ShowMemberCard(entry.person)
    end
  end
  function h:WorkspaceMenu()end
  for _,key in ipairs({"Windows","Settings"}) do
    h.hubActionButtons[key]:Hide();h.hubActionButtons[key]=nil
  end
  return r
end

local function resetRoom(r,kind,count,keepGroup)
  local h=r.room
  h.minimizedWhispers={};h:UpdateMinimizedWhispers()
  r.kind,r.caption,r.historyMode=kind,kind,false
  r.members,r.records={},{}
  if not keepGroup then r.log,r.draft={},nil end
  r.selectedMember,r.selectedGuild=nil,nil
  r.frame.chatType=kind=="Whispers" and "WHISPER" or nil
  for i=1,count do
    local name=({"Elowen","Mira","Torin","Sera","Bram"})[i] or ("Scout "..i)
    local p={name=name,key=name,index=i,guildKey="practice",online=true,class="Mage",classFile="MAGE",
      level=35,rank=i==1 and "Leader" or "Member",note="",zone="",lines={},unread=0,host=h}
    r.members[i]=p;r.records[name]=p
  end
  r.onlineCount,r.totalCount=count,count
  r.query=""
  if r.search then r.search:SetText("") end
  h:SetMinimized(false,true)
  h.hub:Show();h:LayoutHub()
  r.window.readOnlyTranscript:SetLines(r.log,r.frame)
  r:FilterRoster();r:LayoutRoomChrome()
end

local function message(r,name,body,outgoing,receipt)
  local p=r.records[name]
  local whisper=r.kind=="Whispers" and p
  local text=whisper and (outgoing and "To "..name..": " or name.." whispers: ")..body or name..": "..body
  local category=({Guild="GUILD",Party="PARTY",Raid="RAID",Instance="INSTANCE_CHAT",Whispers=outgoing and "WHISPER_INFORM" or "WHISPER"})[r.kind]
  local info=category and ChatTypeInfo and ChatTypeInfo[category]
  local line={text,.88,.85,.82,receivedAt=receipt,own=outgoing,typeID=info and info.id,text=body}
  local lines=whisper and p.lines or r.log
  lines[#lines+1]=line
  if whisper and p==Practice.detachedPerson then
    Practice.detachedTranscript:ShowAppendedLines(lines,r.frame)
  elseif whisper and not outgoing then
    local displayed=p.key==r.selectedMember and not r.room.minimized and r.room.hub:IsShown()
    C.DeliverSampleWhisper(r.room,p,body,displayed)
    r:UpdateUnread()
  end
  if not r.historyMode and (not whisper or p.key==r.selectedMember) then r.window.readOnlyTranscript:ShowAppendedLines(lines,r.frame) end
end

function Practice:RefreshDraft()
  if not self.active then return end
  local r,box=self.owner,self.controls.draft
  local owner=r
  if r.kind=="Whispers" then owner=r.records[r.selectedMember] end
  local available=owner~=nil and not r.historyMode and not r.room.minimized and r.kind~="Previous group" and r.kind~="Combat Log"
  self.draftOwner=available and owner or nil
  box:SetShown(available)
  local value=available and owner.draft or ""
  if value~=box:GetText() then box:SetText(value) end
end

function Practice:SetDetached(person)
  local previous=self.detachedPerson
  self.detachedPerson=person
  if not person then
    if self.detached then self.detached:Hide();self.detachedTranscript:SetLines({}) end
    if previous and self.active then self.owner:FilterRoster() end
    return
  end
  if not self.detached then
    local f=CreateFrame("Frame",nil,UIParent);self.detached=f
    f:SetSize(C.WindowManager:ClampWindowSize(370,190));f:SetPoint("RIGHT",UIParent,"RIGHT",-16,-130);f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true);f:EnableMouse(true);f:SetMovable(true);f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart",function()f:StartMoving()end);f:SetScript("OnDragStop",function()f:StopMovingOrSizing()end)
    C.WindowManager:ApplySurface(f,{headerHeight=24})
    C.WindowManager:CreateWindowResizer(f,{

      allowed=function()return Practice.active and f:IsShown()end,
      begin=function()return f,f:GetWidth(),f:GetHeight()end,
      apply=function(width,height)f:SetSize(width,height)end,
    })
    f:SetScript("OnSizeChanged",function()C.WindowManager:ApplySurface(f,{headerHeight=24})end)
    f.title=f:CreateFontString(nil,"OVERLAY","SunderChatDockFont");f.title:SetPoint("TOPLEFT",8,-5)
    local attach=action(f,"Return",function()self:SetDetached(nil)end,60)
    attach:SetPoint("TOPRIGHT",-3,0)
    self.detachedTranscript=C.CreateReadOnlyTranscript(f,self.owner.frame)
    self.detachedTranscript:SetPoint("TOPLEFT",0,-24);self.detachedTranscript:SetPoint("BOTTOMRIGHT")
  end
  self.detached:SetSize(C.WindowManager:ClampWindowSize(self.detached:GetWidth(),self.detached:GetHeight()))
  self.detached:Show()
  person.unread=0
  self.owner.room:DismissMinimizedWhisper(person)
  self.owner:UpdateUnread()
  self.owner:FilterRoster()
  if self.owner.selectedMember==person.key then
    for _,other in ipairs(self.owner.members) do
      if other~=person then self.owner:ShowMemberCard(other);break end
    end
  end
  self.detached.title:SetText("Practice · "..C.WindowManager:FormatPersonName(person.name,person))
  self.detachedTranscript:SetLines(person.lines,self.owner.frame)
end

function Practice:Apply(event)
  local r,h=self.owner,self.owner.room
  local op,a,b=event[2],event[3],event[4]
  if op=="room" or op=="channel" then self:SetDetached(nil);resetRoom(r,a,b,op=="channel")
  elseif op=="select" then r:ShowMemberCard(r.records[a])
  elseif op=="message" or op=="reply" then message(r,a,b,op=="reply",self.epoch+self.position)
  elseif op=="collapse" then h:SetMinimized(true)
  elseif op=="expand" then h:SetMinimized(false)
  elseif op=="archive" then r:ToggleHistory(true)
  elseif op=="live" then r:ToggleHistory(false)
  elseif op=="detach" then self:SetDetached(r.records[a])
  elseif op=="attach" then self:SetDetached(nil)
  elseif op=="offline" then r.records[a].online=false;r.onlineCount=r.onlineCount-1;r:FilterRoster();r:LayoutRoomChrome()
  elseif op=="leave" then
    table.insert(r.archives,1,{key="practice"..self.index,startedAt=self.epoch+self.position,
      lines=r.log,members=r.members,raid=r.kind=="Raid",changes={
        {kind="baseline",receivedAt=self.epoch+self.position-8,joined=r.members,left={},renamed={}},
        {receivedAt=self.epoch+self.position-2,joined={},left={r.members[#r.members]},renamed={}},
        {kind="ended",receivedAt=self.epoch+self.position},
      }})
    resetRoom(r,"Previous group",0);r:ToggleHistory(true)
  elseif op=="burst" then
    for i=1,32 do message(r,"Caravan","Dispatch "..i.." from the northern road.",false,self.epoch+self.position) end
  else error("Unknown chat practice event: "..tostring(op)) end
  self.lastEvent=op
  self:RefreshDraft()
end

function Practice:EnsureControls()
  if self.controls then return end
  local bar=CreateFrame("Frame",nil,UIParent);self.controls=bar
  bar:SetSize(510,102);bar:SetPoint("TOP",UIParent,"TOP",0,-36);bar:SetClampedToScreen(true);bar:SetFrameStrata("DIALOG")
  bar:EnableMouse(true);bar:SetMovable(true);bar:RegisterForDrag("LeftButton")
  bar:SetScript("OnDragStart",function()bar:StartMoving()end);bar:SetScript("OnDragStop",function()bar:StopMovingOrSizing()end)
  local fill=bar:CreateTexture(nil,"BACKGROUND");fill:SetAllPoints();fill:SetColorTexture(.035,.04,.05,.98)
  bar.status=bar:CreateFontString(nil,"OVERLAY","SunderChatDockFont");bar.status:SetPoint("TOPLEFT",8,-5)
  local names={"All","Whispers","Groups","Windows"}
  for i,name in ipairs(names) do
    local button=action(bar,name,function()self:Start(name)end,84)
    button:SetPoint("TOPLEFT",8+(i-1)*90,-23)
  end
  local live=action(bar,"Check live UI",function()
    local ui=Core:GetModule("UIManager")
    local w=Core:GetModule("Whispers")
    local function visibility(root)
      if not root then return "unbuilt" end
      return root:IsVisible() and "visible" or "hidden"
    end
    local dock=ui.mainControls and ui.slidingMessageFramePool and "ready" or "incomplete"
    local summary={"General dock "..dock,"grip "..visibility(ui.mainResize),"Whispers "..visibility(w.hub)}
    for _,module in ipairs({"GuildChat","PartyChat"}) do
      local room=Core:GetModule(module).room
      summary[#summary+1]=module:gsub("Chat","").." "..visibility(room and room.hub)
    end
    bar.inspection:SetText(table.concat(summary," · "));bar.inspection:Show()
  end,118)
  live:SetPoint("TOPRIGHT",-8,-23)
  bar.inspection=bar:CreateFontString(nil,"OVERLAY","SunderChatDockFont")
  bar.inspection:SetPoint("TOPLEFT",bar,"BOTTOMLEFT",2,-4);bar.inspection:Hide()
  bar.pause=action(bar,"Pause",function()self:Pause(not self.paused)end,80)
  bar.pause:SetPoint("TOPLEFT",8,-49)
  bar.step=action(bar,"Next event",function()self:Step()end,100);bar.step:SetPoint("LEFT",bar.pause,"RIGHT",4,0)
  local replay=action(bar,"Replay",function()self:Start(self.chapter)end,74);replay:SetPoint("LEFT",bar.step,"RIGHT",4,0)
  local exit=action(bar,"Exit practice",function()self:Stop()end,110);exit:SetPoint("LEFT",replay,"RIGHT",4,0)
  local box=CreateFrame("EditBox",nil,bar);bar.draft=box
  box:SetPoint("BOTTOMLEFT",8,4);box:SetPoint("BOTTOMRIGHT",-8,4);box:SetHeight(21)
  box:SetAutoFocus(false);box:SetMaxLetters(255);box:SetFontObject("SunderChatDockFont");box:SetTextInsets(5,5,0,0)
  local plate=box:CreateTexture(nil,"BACKGROUND");plate:SetAllPoints();plate:SetColorTexture(1,1,1,.07)
  local hint=box:CreateFontString(nil,"OVERLAY","SunderChatDockFont");hint:SetPoint("LEFT",5,0)
  hint:SetText("Practice reply (local only)");hint:SetTextColor(.65,.68,.72)
  box:SetScript("OnTextChanged",function()
    local value=box:GetText()
    if self.draftOwner then self.draftOwner.draft=value end
    hint:SetShown(value=="")
  end)
  box:SetScript("OnEscapePressed",function()box:ClearFocus()end)
  box:SetScript("OnHide",function()box:ClearFocus()end)
  box:SetScript("OnEnterPressed",function()
    local value=box:GetText()
    if not self.active or not self.draftOwner or value=="" or self.owner.historyMode or self.owner.room.minimized then return end
    -- Bound manual input independently of the finite scripted events.
    if self.replies>=100 then Core:GetModule("Config"):Print("Replay the scenario to start a fresh practice log.");return end
    self.replies=self.replies+1
    message(self.owner,self.owner.kind=="Whispers" and self.owner.selectedMember or "You",value:gsub("|","||"),true,GetServerTime())
    box:SetText("")
  end)
end

function Practice:Status()
  local nextEvent=self.events[self.index+1]
  local state=not nextEvent and "Complete" or self.paused and "Paused" or "Playing"
  local nextLabel=nextEvent and (" · Next: "..nextEvent[2].." ("..math.ceil(self.remaining).."s gap)") or ""
  self.controls.status:SetText(string.format("Practice · %s · %s · %d/%d%s",self.chapter,state,self.index,#self.events,nextLabel))
  self.controls.pause:SetText(self.paused and "Resume" or "Pause")
  self.controls.pause:SetEnabled(nextEvent~=nil);self.controls.step:SetEnabled(nextEvent~=nil)
end

function Practice:CancelTimer()
  if self.timer then self.timer:Cancel();self.timer=nil end
end
function Practice:Schedule()
  self:CancelTimer()
  if not self.active then return end
  if not self.paused and self.events[self.index+1] then
    self.deadline=GetTime()+self.remaining
    local timer
    timer=C_Timer.NewTimer(self.remaining,function()
      if self.timer~=timer then return end
      self.timer=nil;self:Advance()
    end)
    self.timer=timer
  end
  self:Status()
end
function Practice:Advance()
  if not self.active or not self.events[self.index+1] then return end
  self.index=self.index+1
  local e=self.events[self.index]
  self.position=self.position+e[1]
  self:Apply(e)
  self.remaining=self.events[self.index+1] and self.events[self.index+1][1] or 0
  self:Schedule()
end
function Practice:Pause(value)
  if not self.active or self.paused==value or not self.events[self.index+1] then return end
  if value then self.remaining=math.max(0,self.deadline-GetTime()) end
  self.paused=value;self:Schedule()
end
function Practice:Step()
  if not self.active then return end
  self:CancelTimer();self.paused=true;self:Advance()
end
function Practice:Start(chapter)
  self:Stop()
  self.chapter=chapter or "All"
  self.events={}
  for _,group in ipairs(chapters) do
    if self.chapter=="All" or self.chapter==group.name then
      for _,event in ipairs(group.events) do self.events[#self.events+1]=event end
    end
  end
  if #self.events==0 then return end
  self:EnsureControls()
  self.owner=self.owner or createRoom()
  self.active,self.index,self.position,self.paused,self.epoch,self.replies=true,0,0,false,GetServerTime(),0
  self.controls:Show();self:Advance()
end
function Practice:Stop()
  self:CancelTimer()
  self.active=false
  self.draftOwner=nil
  if self.controls then self.controls.draft:SetText("") end
  if self.controls then self.controls:Hide() end
  if self.controls then self.controls.inspection:Hide() end
  self:SetDetached(nil)
  local r=self.owner
  if r then
    local h=r.room
    h.hub:Hide();h.minimizedWhispers={}
    if h.minimizedWhisperTray then
      h:UpdateMinimizedWhispers();h.minimizedWhisperTray:Hide();h.minimizedWhisperTray.stamp=nil
    end
    r.window.readOnlyTranscript:SetLines({})
    if r.historyPanel then r.historyPanel.transcript:SetLines({});r.historyPanel:Hide() end
    r.members,r.records,r.log,r.filtered,r.archives={},{},{},{},{}
    r.draft,r.selectedMember,r.selectedGuild=nil,nil,nil
    if r.historyPanel then r:RenderHistoryList() end
    r.historyMode=false
  end
end
function Practice:Toggle()
  if self.active then self:Stop() else self:Start("All") end
end
