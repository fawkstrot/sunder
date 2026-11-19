local Core,_,Utils=unpack(select(2,...))
local P=Core:GetModule("PartyChat")
local function theme()return Core:GetModule("Whispers")end
local function wm()return Core.Components.WindowManager end
local function archive()Core.db.char.partyRoomArchive=Core.db.char.partyRoomArchive or {};return Core.db.char.partyRoomArchive end
local function now()return GetServerTime and GetServerTime() or time()end
local function clean(v)return type(v)=="string" and (not _G.canaccessvalue or canaccessvalue(v)) and not v:find("|K",1,true) and v or ""end
local function stamp(v)return date("%b %d, %I:%M %p",v or now())end
-- Presentation only: retain the complete saved roster for identity/history.
local function otherMembers(record)
  local guid=clean(UnitGUID and UnitGUID("player"))
  local realm=clean(GetRealmName and GetRealmName()):gsub("%s", ""):lower()
  local function identity(name)
    name=clean(name)
    if name=="" then return end
    local base,server=name:match("^(.-)%-(.+)$")
    return (base or name):lower().."-"..(server and server:gsub("%s", ""):lower() or realm)
  end
  local names={}
  local function add(name)local key=identity(name);if key then names[key]=true end end
  if GetUnitName then add(GetUnitName("player",true));add(GetUnitName("player",false)) end
  local unitName=_G.UnitNameUnmodified or _G.UnitName
  if unitName then
    local name,server=unitName("player")
    name,server=clean(name),clean(server)
    add(server~="" and name.."-"..server or name)
  end
  local members={}
  for _,person in ipairs(record.members or {}) do
    local personGUID=clean(person.guid)
    local own
    if guid~="" and personGUID~="" then own=guid==personGUID
    else own=names[identity(person.name)] end
    if not own then members[#members+1]=person end
  end
  return members
end
local function changeBytes(change)
  local bytes=96
  local function person(value)
    return #(value.name or "")+#(value.guid or "")+#(value.classFile or "")+64
  end
  for _,list in ipairs({change.joined or {},change.left or {}}) do
    for _,value in ipairs(list) do bytes=bytes+person(value) end
  end
  for _,value in ipairs(change.renamed or {}) do bytes=bytes+person(value.before)+person(value.after) end
  return bytes
end
local function appendChange(record,change)
  record.changes=record.changes or {}
  if not record.changeBytes then
    record.changeBytes=0
    for _,old in ipairs(record.changes) do record.changeBytes=record.changeBytes+changeBytes(old) end
  end
  record.changes[#record.changes+1]=change
  record.changeBytes=record.changeBytes+changeBytes(change)
end
local function warnArchive(records)
  local total=0
  for _,entry in ipairs(records) do
    if not entry.lineBytes then
      entry.lineBytes=0
      for _,line in ipairs(entry.lines or {}) do entry.lineBytes=entry.lineBytes+#line[1]+64 end
    end
    total=total+entry.lineBytes+(entry.changeBytes or 0)
  end
  Utils.warnHistorySize(total,"Group","Use Party Chat settings to clear group history.")
end
-- Native replay is bounded. Keep the full accumulated group transcript for review.
function P:ArchiveHistory()
  if not Core.db.profile.partyChat.remember then return end
  local saved=Core.db.char.partyRoomHistory
  if not saved or not saved.lines or #saved.lines==0 then return end
  local records=archive();local record
  for _,entry in ipairs(records)do if entry.key==saved.key then record=entry;break end end
  if not record then record={key=saved.key,startedAt=saved.lines[1].receivedAt or now(),members={}};table.insert(records,1,record)end
  local changed=self.archiveSnapshot~=saved or not record.lines
  record.raid=self.raid or record.raid
  if changed then
    self.archiveSnapshot=saved
    record.updatedAt=now()
    record.lines=record.lines or {}
    local added=Utils.appendHistoryTail(record.lines,saved.lines)
    if record.lineBytes then record.lineBytes=record.lineBytes+added end
    warnArchive(records)
  end
  local known={}
  for _,person in ipairs(record.members) do known[person.name]=person end
  for _,person in ipairs(self.members or {}) do
    local name=clean(person.name)
    if name~="" then
      local saved=known[name]
      if not saved then saved={name=name};record.members[#record.members+1]=saved;known[name]=saved end
      for _,field in ipairs({"class","classFile","guid"}) do
        local value=clean(person[field])
        if value~="" then saved[field]=value end
      end
      if type(person.level)=="number" and person.level>0 then saved.level=person.level end
    end
  end
  if self.historyPanel and self.historyPanel:IsShown()then self:RenderHistoryList()end
end
local save=P.SaveHistory
function P:SaveHistory(partial)save(self,partial);self:ArchiveHistory()end
local function memberSnapshot(members)
  local snapshot={}
  for _,person in ipairs(members or {}) do
    local name=clean(person.name)
    if name~="" then
      local guid=clean(person.guid)
      snapshot[guid~="" and guid or name:lower()]={name=name,guid=guid,class=clean(person.class),
        classFile=clean(person.classFile),level=person.level}
    end
  end
  return snapshot
end
local function snapshotList(snapshot)
  local list={}
  for _,person in pairs(snapshot or {}) do list[#list+1]=person end
  table.sort(list,function(a,b)return a.name<b.name end)
  return list
end
function P:RecordRosterChanges(previousKey)
  if self.waitingForRoster or self.rosterComplete==false or not Core.db.profile.partyChat.remember then return end
  local records=archive()
  local old,current
  for _,record in ipairs(records) do
    if record.key==previousKey then old=record end
    if record.key==self.sessionKey then current=record end
  end
  if old and (not self.grouped or previousKey~=self.sessionKey) and not old.endedAt then
    old.endedAt=now()
    appendChange(old,{kind="ended",receivedAt=old.endedAt})
    warnArchive(records)
  end
  if not self.grouped then return end
  if not current then
    current={key=self.sessionKey,startedAt=now(),members={},lines={},changes={},raid=self.raid}
    table.insert(records,1,current)
  end
  local snapshot=memberSnapshot(self.members)
  local before=not self.rosterRecordingReset and current.rosterSnapshot
  self.rosterRecordingReset=nil
  local change={receivedAt=now(),joined={},left={},renamed={}}
  if not before then
    change.kind="baseline"
    change.joined=snapshotList(snapshot)
  else
    for identity,person in pairs(snapshot) do
      local prior=before[identity]
      if not prior then change.joined[#change.joined+1]=person
      elseif prior.name~=person.name then change.renamed[#change.renamed+1]={before=prior,after=person} end
    end
    for identity,person in pairs(before) do
      if not snapshot[identity] then change.left[#change.left+1]=person end
    end
  end
  current.rosterSnapshot=snapshot
  current.changes=current.changes or {}
  if change.kind or #change.joined+#change.left+#change.renamed>0 then
    table.sort(change.joined,function(a,b)return a.name<b.name end)
    table.sort(change.left,function(a,b)return a.name<b.name end)
    appendChange(current,change)
    warnArchive(records)
  end
  -- Historical name versions are retained. Later class observations fill missing metadata.
  local known={}
  for _,person in ipairs(current.members) do known[person.name]=person end
  for _,person in pairs(snapshot) do
    local entry=known[person.name]
    if not entry then current.members[#current.members+1]=person
    elseif not entry.classFile or entry.classFile=="" then entry.classFile=person.classFile;entry.class=person.class end
  end
end
local refresh=P.RefreshRoster
function P:RefreshRoster()
  self:ArchiveHistory() -- migrate legacy recent recall before a new-session reset
  local previousKey=self.sessionKey
  refresh(self)
  self:RecordRosterChanges(previousKey)
  if self.historyMode then self:LayoutHistory()end
end
function P:HistoryRecords()return archive()end
local ARCHIVE_TOOLBAR_HEIGHT=36
function P:RoomSurfaceLayout()
  if self.historyMode then return wm():PeopleSidebarWidth(self.room.hub:GetWidth()),ARCHIVE_TOOLBAR_HEIGHT end
  return self.panel and self.panel:IsShown() and self.panel:GetWidth() or 0,0
end
local function changeLabel(change)
  if change.kind=="ended" then return "Left the group" end
  if change.kind=="baseline" then return "Roster recorded · "..#change.joined.." members" end
  local parts={}
  local function add(people,verb)
    if #people==0 then return end
    local label
    if #people==1 then label=wm():FormatPersonName(people[1].name,people[1])
    else label=#people.." members" end
    parts[#parts+1]=label.." "..verb
  end
  add(change.joined,"joined");add(change.left,"left")
  if #change.renamed>1 then parts[#parts+1]=#change.renamed.." names changed" end
  for _,rename in ipairs(#change.renamed==1 and change.renamed or {}) do
    parts[#parts+1]=wm():FormatPersonName(rename.before.name,rename.before).." is now "..wm():FormatPersonName(rename.after.name,rename.after)
  end
  return table.concat(parts," · ")
end
function P:HistoryTimeline(record)
  local changes=record.changes or {}
  if #changes==0 then return record.lines end
  local cached=self.historyTimeline
  if cached and cached.record==record and cached.messages==#record.lines and cached.changes==#changes then return cached.lines end
  local result={}
  local message,event=1,1
  while message<=#record.lines or event<=#changes do
    local line=record.lines[message]
    local change=changes[event]
    if change and (not line or change.receivedAt<(line.receivedAt or 0)) then
      result[#result+1]={changeLabel(change),.55,.60,.66,receivedAt=change.receivedAt,groupChange=change}
      event=event+1
    else
      result[#result+1]=line
      message=message+1
    end
  end
  self.historyTimeline={record=record,messages=#record.lines,changes=#changes,lines=result}
  return result
end
function P:SelectHistory(key)
  self.historySelected=key;self:RenderHistoryList()
  local record;for _,entry in ipairs(self:HistoryRecords())do if entry.key==key then record=entry;break end end
  local panel=self.historyPanel;if not panel then return end
  panel.older:Hide();panel.newer:Hide()
  if not record then panel.heading:SetText("No group selected.");panel.details:SetText("Select a previous group to read its conversation.");panel.transcript:SetLines({});return end
  local names={};for _,person in ipairs(otherMembers(record))do names[#names+1]=wm():FormatPersonName(person.name,person) end
  panel.heading:SetText((record.raid and "Raid" or "Party").." · "..stamp(record.startedAt))
  panel.details:SetText(tostring(#names).." other names seen · "..#record.lines.." messages · Read-only\n"..(#names>0 and table.concat(names,", ") or (#record.members>0 and "No other members recorded." or "Members unavailable")))
  -- Keep native font strings and link handlers bounded while reviewing a long group.
  local timeline=self:HistoryTimeline(record)
  local pageSize=100
  local function page(last)
    local first=math.max(1,last-pageSize+1)
    local lines=timeline
    if #lines>pageSize then
      lines={}
      for i=first,last do lines[#lines+1]=timeline[i] end
    end
    panel.transcript:SetLines(lines,self.frame)
    panel.older:SetShown(first>1)
    panel.newer:SetShown(last<#timeline)
    panel.older:SetScript("OnClick",function() page(first-1) end)
    panel.newer:SetScript("OnClick",function() page(math.min(#timeline,last+pageSize)) end)
  end
  page(#timeline)
end
function P:RenderHistoryList()
  local panel=self.historyPanel;if not panel then return end
  local records=self:HistoryRecords();local width=panel.list:GetWidth()
  local pad=wm():BodyPadding();local size=theme():InterfaceTextSize()
  local detailSize=wm():PersonDetailSize(theme())
  local height=math.max(48,pad*2+size+4+detailSize)
  local textWidth=math.max(1,width-pad-wm():ScrollRightInset(pad))
  panel.child:SetWidth(math.max(1,width));panel.child:SetHeight(math.max(1,#records*height))
  local offset=math.min(panel.list:GetVerticalScroll(),math.max(0,#records*height-panel.list:GetHeight()))
  local first=math.max(1,math.floor(offset/height)+1)
  local visible=math.ceil(panel.list:GetHeight()/height)+1
  for slot=1,math.max(math.min(#records,visible),#panel.rows)do
    local i=first+slot-1
    local row=panel.rows[slot];local record=slot<=visible and records[i]
    if record then
      if not row then
        row=CreateFrame("Button",nil,panel.child);panel.rows[slot]=row
        row.name=row:CreateFontString(nil,"OVERLAY","SunderChatDockFont");row.detail=row:CreateFontString(nil,"OVERLAY","SunderChatDockFont")
        row.fill=row:CreateTexture(nil,"BACKGROUND");row.fill:SetAllPoints()
        row.rule=row:CreateTexture(nil,"BORDER");row.rule:SetPoint("BOTTOMLEFT",4,0);row.rule:SetPoint("BOTTOMRIGHT",-4,0);row.rule:SetHeight(1);row.rule:SetColorTexture(.7,.75,.8,.065)
        row:SetHighlightTexture("Interface\\Buttons\\WHITE8X8");row:GetHighlightTexture():SetVertexColor(1,1,1,.035)
        row:SetScript("OnClick",function()self:SelectHistory(row.key)end)
        row:SetScript("OnEnter",function()GameTooltip:SetOwner(row,"ANCHOR_RIGHT");GameTooltip:AddLine("Previous group",1,1,1);for _,person in ipairs(otherMembers(row.record))do GameTooltip:AddLine(wm():FormatPersonName(person.name,person),.7,.75,.8)end;Core:GetModule("Fonts"):StyleTooltip(GameTooltip);GameTooltip:Show()end)
        row:SetScript("OnLeave",function()GameTooltip:Hide()end)
      end
      row.key=record.key;row.record=record;row:SetSize(width,height);row:ClearAllPoints();row:SetPoint("TOPLEFT",0,-(i-1)*height)
      for _,label in ipairs({row.name,row.detail})do label:ClearAllPoints();label:SetWidth(textWidth);label:SetJustifyH("LEFT");label:SetWordWrap(false)end
      theme():WorkspaceFont(row.name,theme():InterfaceTextSize());wm():ApplyPersonDetailFont(theme(),row.detail)
      row.name:SetPoint("TOPLEFT",pad,-pad);row.detail:SetPoint("TOPLEFT",pad,-pad-size-4)
      row.name:SetText(stamp(record.startedAt));row.name:SetTextColor(.83,.85,.88)
      local names={};for _,person in ipairs(otherMembers(record))do names[#names+1]=wm():FormatPersonName(person.name,person) end
      row.detail:SetText(#names>0 and table.concat(names,", ") or tostring(#record.lines).." messages");row.detail:SetTextColor(.55,.6,.67)
      local r,g,b=theme():InterfaceAccent();row.fill:SetColorTexture(r,g,b,self.historySelected==record.key and .09 or 0);row:Show()
    elseif row then row:Hide()end
  end
  panel.zero:SetShown(#records==0);wm():UpdateListScrollIndicator(panel.list,panel.child,true)
end
function P:EnsureHistory()
  if self.historyPanel then return end
  local panel=CreateFrame("Frame",nil,self.room.hubContent);self.historyPanel=panel;panel:SetFrameLevel(self.room.hubContent:GetFrameLevel()+15);panel:EnableMouse(true)
  panel.title=panel:CreateFontString(nil,"OVERLAY","SunderChatDockFont");panel.title:SetText("Previous groups")
  panel.back=wm():CreateTextAction(panel,"Back to live chat",function()self:ToggleHistory(false)end)
  panel.list=CreateFrame("ScrollFrame",nil,panel);panel.child=CreateFrame("Frame",nil,panel.list);panel.list:SetScrollChild(panel.child);panel.list:SetClipsChildren(true);panel.rows={}
  panel.zero=panel.list:CreateFontString(nil,"OVERLAY","SunderChatDockFont");panel.zero:SetText("No saved groups yet.");panel.zero:SetTextColor(.6,.65,.7)
  panel.list:SetScript("OnVerticalScroll",function() self:RenderHistoryList() end)
  panel.list:EnableMouseWheel(true);panel.list:SetScript("OnMouseWheel",function(_,delta)panel.list:SetVerticalScroll(math.max(0,math.min(math.max(0,panel.child:GetHeight()-panel.list:GetHeight()),panel.list:GetVerticalScroll()-delta*48)));wm():UpdateListScrollIndicator(panel.list,panel.child,true)end)
  panel.heading=panel:CreateFontString(nil,"OVERLAY","SunderChatDockFont");panel.details=panel:CreateFontString(nil,"OVERLAY","SunderChatDockFont")
  panel.older=wm():CreateTextAction(panel,"Older",function()end)
  panel.newer=wm():CreateTextAction(panel,"Newer",function()end)
  panel.older:Hide();panel.newer:Hide()
  panel.transcript=Core.Components.CreateReadOnlyTranscript(panel,self.frame)
  panel:Hide()
end
function P:LayoutHistory()
  local panel=self.historyPanel;if not panel or not self.room then return end
  panel:SetShown(not not self.historyMode)
  if not self.historyMode then wm():UpdateListScrollIndicator(panel.list,panel.child,false);return end
  local h=self.room;local pad=theme():BodyPadding();local size=theme():InterfaceTextSize();local width,height=wm():ClampWindowSize(h.hub:GetWidth(),h.hub:GetHeight(),h);if width~=h.hub:GetWidth() or height~=h.hub:GetHeight() then h.hub:SetSize(width,height) end;local split=wm():PeopleSidebarWidth(width)
  panel:ClearAllPoints();panel:SetPoint("TOPLEFT",h.hubContent,"TOPLEFT",0,-h:HeaderHeight()-h:HeaderGap());panel:SetPoint("BOTTOMRIGHT",h.hubContent,"BOTTOMRIGHT")
  panel.title:ClearAllPoints();panel.title:SetPoint("TOPLEFT",pad,-pad);theme():WorkspaceFont(panel.title,size+1);panel.title:SetWidth(math.max(1,width-148));panel.title:SetJustifyH("LEFT");panel.title:SetWordWrap(false)
  panel.back:ClearAllPoints();panel.back:SetPoint("TOPRIGHT",-pad,-pad);panel.back:SetSize(116,22)
  h:ApplyRoomStructure(split,ARCHIVE_TOOLBAR_HEIGHT)
  panel.list:ClearAllPoints();panel.list:SetPoint("TOPLEFT",0,-36);panel.list:SetPoint("BOTTOMLEFT",0,pad);panel.list:SetWidth(split)
  panel.zero:ClearAllPoints();panel.zero:SetPoint("TOPLEFT",pad,-pad);panel.zero:SetWidth(math.max(1,split-pad*2))
  panel.heading:ClearAllPoints();panel.heading:SetPoint("TOPLEFT",split+pad,-40);panel.heading:SetWidth(math.max(1,width-split-pad*2));panel.heading:SetJustifyH("LEFT");panel.heading:SetWordWrap(false);theme():WorkspaceFont(panel.heading,size+1)
  panel.details:ClearAllPoints();panel.details:SetPoint("TOPLEFT",split+pad,-62);panel.details:SetWidth(math.max(1,width-split-pad*2));panel.details:SetHeight(48);panel.details:SetJustifyH("LEFT");panel.details:SetJustifyV("TOP");panel.details:SetWordWrap(true);wm():ApplyPersonDetailFont(theme(),panel.details);panel.details:SetTextColor(.6,.65,.72)
  panel.newer:ClearAllPoints();panel.newer:SetSize(52,20);panel.newer:SetPoint("TOPRIGHT",-pad,-92)
  panel.older:ClearAllPoints();panel.older:SetSize(52,20);panel.older:SetPoint("RIGHT",panel.newer,"LEFT",-2,0)
  panel.transcript:ClearAllPoints();panel.transcript:SetPoint("TOPLEFT",split,-116);panel.transcript:SetPoint("BOTTOMRIGHT",0,0)
  self:RenderHistoryList();self.column:Hide()
  self.panel:Hide();self.conversationLabel:Hide();self.motdLabel:Hide();self.captionHelp:Hide()
end
function P:ToggleHistory(value)
  if not self.room then self:Open()end
  if self.room.minimized then self.room:SetMinimized(false,true)end
  if value==nil then value=not self.historyMode end
  self:SaveHistory(true);self.historyMode=value;self:EnsureHistory()
  if value then Core:GetModule("UIManager"):ReleaseMessageInput(self.frame);self:SelectHistory(self.historySelected or archive()[1] and archive()[1].key)end
  self.room:LayoutHub();self:LayoutHistory();wm():RefreshRoomActions(self.room)
end
local layout=P.LayoutWindow
function P:LayoutWindow(window)
  -- Do not briefly show the live roster beneath the archive on every refresh:
  -- its OnShow schedules another roster refresh, which would keep repeating.
  if self:IsRoom(window.chatFrame) and self.historyMode and self.historyPanel then self:LayoutHistory();return true end
  local handled=layout(self,window);if handled and self.historyPanel then self:LayoutHistory()end;return handled
end

local toggleRoster=P.ToggleRoster
function P:ToggleRoster()
  if self.historyMode then self:ToggleHistory(false);Core.db.profile.partyChat.rosterShown=true;self.room:LayoutHub();return end
  return toggleRoster(self)
end
