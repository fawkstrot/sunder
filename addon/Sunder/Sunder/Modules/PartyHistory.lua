local Core=unpack(select(2,...))
local P=Core:GetModule("PartyChat")
local function theme()return Core:GetModule("Whispers")end
local function wm()return Core.Components.WindowManager end
local function archive()Core.db.char.partyRoomArchive=Core.db.char.partyRoomArchive or {};return Core.db.char.partyRoomArchive end
local function now()return GetServerTime and GetServerTime() or time()end
local function clean(v)return type(v)=="string" and (not _G.canaccessvalue or canaccessvalue(v)) and not v:find("|K",1,true) and v or ""end
local function stamp(v)return date("%b %d, %I:%M %p",v or now())end
-- Bounded per-character archive. Keep the existing native recent-recall store intact.
function P:ArchiveHistory()
  if not Core.db.profile.partyChat.remember then return end
  local saved=Core.db.char.partyRoomHistory
  if not saved or not saved.lines or #saved.lines==0 then return end
  local records=archive();local record
  for _,entry in ipairs(records)do if entry.key==saved.key then record=entry;break end end
  if not record then record={key=saved.key,startedAt=now(),members={}};table.insert(records,1,record)end
  local changed=self.archiveSnapshot~=saved
  record.raid=self.raid or record.raid
  if changed then
  self.archiveSnapshot=saved;record.updatedAt=now();record.lines={}
  for _,line in ipairs(saved.lines)do
    record.lines[#record.lines+1]={line[1],line[2],line[3],line[4],typeID=line.typeID,receivedAt=line.receivedAt,own=line.own}
  end
  end
  local known={};for _,person in ipairs(record.members)do known[person.name]=true end
  for _,person in ipairs(self.members or {})do
    local name=clean(person.name)
    if name~="" and not known[name] and #record.members<40 then record.members[#record.members+1]={name=name,class=clean(person.class),classFile=clean(person.classFile),level=person.level};known[name]=true end
  end
  local bytes=0
  for i=#records,1,-1 do if #records[i].lines==0 then table.remove(records,i)end end
  for i=1,#records do
    for _,line in ipairs(records[i].lines)do bytes=bytes+#line[1]end
    if i>30 or bytes>4*1024*1024 then for j=#records,i,-1 do table.remove(records,j)end;break end
  end
  if self.historyPanel and self.historyPanel:IsShown()then self:RenderHistoryList()end
end
local save=P.SaveHistory
function P:SaveHistory(partial)save(self,partial);self:ArchiveHistory()end
local refresh=P.RefreshRoster
function P:RefreshRoster()
  self:ArchiveHistory() -- migrate legacy recent recall before a new-session reset
  refresh(self)
  if self.historyMode then self:LayoutHistory()end
end
function P:HistoryRecords()return archive()end
function P:SelectHistory(key)
  self.historySelected=key;self:RenderHistoryList()
  local record;for _,entry in ipairs(self:HistoryRecords())do if entry.key==key then record=entry;break end end
  local panel=self.historyPanel;if not panel then return end
  if not record then panel.heading:SetText("No group selected.");panel.details:SetText("Select a previous group to read its conversation.");panel.transcript:SetLines({});return end
  local names={};for _,person in ipairs(record.members)do names[#names+1]=person.name end
  panel.heading:SetText((record.raid and "Raid" or "Party").." · "..stamp(record.startedAt))
  panel.details:SetText(tostring(#names).." members · "..#record.lines.." messages · Read-only\n"..(#names>0 and table.concat(names,", ") or "Members unavailable"))
  panel.transcript:SetLines(record.lines,self.frame)
end
function P:RenderHistoryList()
  local panel=self.historyPanel;if not panel then return end
  local records=self:HistoryRecords();local width=panel.list:GetWidth()
  local pad=wm():BodyPadding();local size=theme():InterfaceTextSize()
  local detailSize=wm():PersonDetailSize(theme())
  local height=math.max(48,pad*2+size+4+detailSize)
  local textWidth=math.max(1,width-pad-wm():ScrollRightInset(pad))
  panel.child:SetWidth(math.max(1,width));panel.child:SetHeight(math.max(1,#records*height))
  for i=1,math.max(#records,#panel.rows)do
    local row=panel.rows[i];local record=records[i]
    if record then
      if not row then
        row=CreateFrame("Button",nil,panel.child);panel.rows[i]=row
        row.name=row:CreateFontString(nil,"OVERLAY","SunderChatDockFont");row.detail=row:CreateFontString(nil,"OVERLAY","SunderChatDockFont")
        row.fill=row:CreateTexture(nil,"BACKGROUND");row.fill:SetAllPoints()
        row.rule=row:CreateTexture(nil,"BORDER");row.rule:SetPoint("BOTTOMLEFT",4,0);row.rule:SetPoint("BOTTOMRIGHT",-4,0);row.rule:SetHeight(1);row.rule:SetColorTexture(.7,.75,.8,.065)
        row:SetHighlightTexture("Interface\\Buttons\\WHITE8X8");row:GetHighlightTexture():SetVertexColor(1,1,1,.035)
        row:SetScript("OnClick",function()self:SelectHistory(row.key)end)
        row:SetScript("OnEnter",function()GameTooltip:SetOwner(row,"ANCHOR_RIGHT");GameTooltip:AddLine("Previous group",1,1,1);for _,person in ipairs(row.record.members)do GameTooltip:AddLine(person.name,.7,.75,.8)end;GameTooltip:Show()end)
        row:SetScript("OnLeave",function()GameTooltip:Hide()end)
      end
      row.key=record.key;row.record=record;row:SetSize(width,height);row:ClearAllPoints();row:SetPoint("TOPLEFT",0,-(i-1)*height)
      for _,label in ipairs({row.name,row.detail})do label:ClearAllPoints();label:SetWidth(textWidth);label:SetJustifyH("LEFT");label:SetWordWrap(false)end
      theme():WorkspaceFont(row.name,theme():InterfaceTextSize());wm():ApplyPersonDetailFont(theme(),row.detail)
      row.name:SetPoint("TOPLEFT",pad,-pad);row.detail:SetPoint("TOPLEFT",pad,-pad-size-4)
      row.name:SetText(stamp(record.startedAt));row.name:SetTextColor(.83,.85,.88)
      local names={};for _,person in ipairs(record.members)do names[#names+1]=person.name end
      row.detail:SetText(#names>0 and table.concat(names,", ") or tostring(#record.lines).." messages");row.detail:SetTextColor(.55,.6,.67)
      local r,g,b=theme():InterfaceAccent();row.fill:SetColorTexture(r,g,b,self.historySelected==record.key and .09 or 0);row:Show()
    elseif row then row:Hide()end
  end
  panel.zero:SetShown(#records==0);wm():UpdateListScrollIndicator(panel.list,panel.child,true)
end
function P:EnsureHistory()
  if self.historyPanel then return end
  local panel=CreateFrame("Frame",nil,self.room.hubContent);self.historyPanel=panel;panel:SetFrameLevel(self.room.hubContent:GetFrameLevel()+15);panel:EnableMouse(true);wm():StyleInsetPanel(panel,self.room)
  panel.divider=panel:CreateTexture(nil,"BORDER");panel.divider:SetWidth(1);panel.divider:SetColorTexture(.7,.75,.8,.13)
  panel.title=panel:CreateFontString(nil,"OVERLAY","SunderChatDockFont");panel.title:SetText("Previous groups")
  panel.back=wm():CreateTextAction(panel,"Back to live chat",function()self:ToggleHistory(false)end)
  panel.list=CreateFrame("ScrollFrame",nil,panel);panel.child=CreateFrame("Frame",nil,panel.list);panel.list:SetScrollChild(panel.child);panel.list:SetClipsChildren(true);panel.rows={}
  panel.zero=panel.list:CreateFontString(nil,"OVERLAY","SunderChatDockFont");panel.zero:SetText("No saved groups yet.");panel.zero:SetTextColor(.6,.65,.7)
  panel.list:EnableMouseWheel(true);panel.list:SetScript("OnMouseWheel",function(_,delta)panel.list:SetVerticalScroll(math.max(0,math.min(math.max(0,panel.child:GetHeight()-panel.list:GetHeight()),panel.list:GetVerticalScroll()-delta*48)));wm():UpdateListScrollIndicator(panel.list,panel.child,true)end)
  panel.heading=panel:CreateFontString(nil,"OVERLAY","SunderChatDockFont");panel.details=panel:CreateFontString(nil,"OVERLAY","SunderChatDockFont")
  panel.transcript=Core.Components.CreateReadOnlyTranscript(panel,self.frame)
  panel:Hide()
end
function P:LayoutHistory()
  local panel=self.historyPanel;if not panel or not self.room then return end
  panel:SetShown(not not self.historyMode)
  if not self.historyMode then wm():UpdateListScrollIndicator(panel.list,panel.child,false);return end
  local h=self.room;local pad=theme():BodyPadding();local size=theme():InterfaceTextSize();local width=h.hub:GetWidth();local split=wm():PeopleSidebarWidth(width)
  panel:ClearAllPoints();panel:SetPoint("TOPLEFT",h.hubContent,"TOPLEFT",0,-h:HeaderHeight()-h:HeaderGap());panel:SetPoint("BOTTOMRIGHT",h.hubContent,"BOTTOMRIGHT")
  panel.title:ClearAllPoints();panel.title:SetPoint("TOPLEFT",pad,-pad);theme():WorkspaceFont(panel.title,size+1);panel.title:SetWidth(math.max(1,width-148));panel.title:SetJustifyH("LEFT");panel.title:SetWordWrap(false)
  panel.back:ClearAllPoints();panel.back:SetPoint("TOPRIGHT",-pad,-pad);panel.back:SetSize(116,22)
  panel.divider:ClearAllPoints();panel.divider:SetPoint("TOPLEFT",split,-36);panel.divider:SetPoint("BOTTOMLEFT",split,pad)
  panel.list:ClearAllPoints();panel.list:SetPoint("TOPLEFT",0,-36);panel.list:SetPoint("BOTTOMLEFT",0,pad);panel.list:SetWidth(split)
  panel.zero:ClearAllPoints();panel.zero:SetPoint("TOPLEFT",pad,-pad);panel.zero:SetWidth(math.max(1,split-pad*2))
  panel.heading:ClearAllPoints();panel.heading:SetPoint("TOPLEFT",split+pad,-40);panel.heading:SetWidth(math.max(1,width-split-pad*2));panel.heading:SetJustifyH("LEFT");panel.heading:SetWordWrap(false);theme():WorkspaceFont(panel.heading,size+1)
  panel.details:ClearAllPoints();panel.details:SetPoint("TOPLEFT",split+pad,-62);panel.details:SetWidth(math.max(1,width-split-pad*2));panel.details:SetHeight(48);panel.details:SetJustifyH("LEFT");panel.details:SetJustifyV("TOP");panel.details:SetWordWrap(true);wm():ApplyPersonDetailFont(theme(),panel.details);panel.details:SetTextColor(.6,.65,.72)
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
