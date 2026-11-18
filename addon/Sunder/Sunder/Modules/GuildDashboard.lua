local Core=unpack(select(2,...))
local G=Core:GetModule("GuildChat")
local function wm()return Core.Components.WindowManager end
local function theme()return Core:GetModule("Whispers")end
local NAV_HEIGHT,SEARCH_HEIGHT,SORT_HEIGHT=26,28,24
local SECTION_GAP,SECTION_INSET,COLUMN_GAP=16,10,22
local OVERVIEW_COLUMN_MIN=240
local SUMMARY_GAP=8
local function displayFont(label,size)
  theme():WorkspaceFont(label,size)
  local path,_,flags=label:GetFont()
  if path then label:SetFont(path,size,flags or "")end
end
local function text(value)
  if _G.canaccessvalue and not canaccessvalue(value)then return ""end
  return type(value)=="string" and value:sub(1,4096):gsub("|","||") or ""
end
local columns={{"name","Name",.42},{"level","Level",.12},{"rank","Rank",.22},{"zone","Location",.24}}
local function filterButton(parent,label,callback)
  local b=CreateFrame("Button",nil,parent);b:SetNormalFontObject("SunderChatDockFont");b:SetText(label)
  local label=b:GetFontString();label:ClearAllPoints();label:SetPoint("LEFT",3,0);label:SetPoint("RIGHT",-3,0);label:SetWordWrap(false)
  b.plate=b:CreateTexture(nil,"BACKGROUND");b.plate:SetAllPoints()
  b.indicator=b:CreateTexture(nil,"OVERLAY");b.indicator:SetPoint("BOTTOMLEFT");b.indicator:SetPoint("BOTTOMRIGHT");b.indicator:SetHeight(1)
  function b:Refresh()wm():StyleFilterButton(self,self.selected,self.hovered,theme():InterfaceAccent())end
  b:SetScript("OnClick",callback)
  b:SetScript("OnEnter",function()b.hovered=true;b:Refresh();if b.tip then GameTooltip:SetOwner(b,"ANCHOR_TOP");GameTooltip:AddLine(b.tip, .8,.83,.88,true);GameTooltip:Show()end end)
  b:SetScript("OnLeave",function()b.hovered=nil;b:Refresh();GameTooltip:Hide()end)
  b:SetScript("OnHide",function()b.hovered=nil;b:Refresh()end)
  return b
end
function G:SetGuildDashboardTab(tab)
  self.infoTab=tab;self.infoClass=nil;self.infoZone=nil;self.infoScope=nil
  self.infoDashboardStamp=nil;self.infoDrawer.scroll:SetVerticalScroll(0)
  self.room:LayoutHub()
end
function G:OpenGuildDirectory(class,zone,scope)
  self.infoTab="members";self.infoClass=class;self.infoZone=zone;self.infoScope=scope or "online"
  if scope=="all" then self.infoScope=nil end
  self.infoQuery="";self.infoDrawer.search:SetText("");self.infoDashboardStamp=nil
  self.infoDrawer.scroll:SetVerticalScroll(0);self.room:LayoutHub()
end
function G:EnsureGuildDashboard()
  local p=self.infoDrawer;if p.tabs then return end
  p.tabs={};p.sortButtons={};p.dashboardRows={}
  for i,entry in ipairs({{"overview","Overview"},{"members","Members"},{"about","About"}})do
    local key=entry[1];p.tabs[i]=filterButton(p,entry[2],function()self:SetGuildDashboardTab(key)end);p.tabs[i].key=key
  end
  p.search=CreateFrame("EditBox",nil,p);p.search:SetAutoFocus(false);p.search:SetFontObject("SunderChatDockFont")
  p.search:SetTextInsets(4,4,0,0)
  p.search.fill=p.search:CreateTexture(nil,"BACKGROUND");p.search.fill:SetAllPoints();p.search.fill:SetColorTexture(1,1,1,.035)
  p.search.placeholder=p.search:CreateFontString(nil,"OVERLAY","SunderChatDockFont");p.search.placeholder:SetPoint("LEFT",4,0);p.search.placeholder:SetText("Search members…");p.search.placeholder:SetTextColor(.52,.57,.62);p.search.placeholder:SetWordWrap(false)
  p.search:SetScript("OnTextChanged",function(box)
    self.infoQuery=box:GetText() or "";box.placeholder:SetShown(self.infoQuery=="")
    self.infoDashboardStamp=nil;p.scroll:SetVerticalScroll(0)
    if self.infoMode=="guild" and (self.infoTab or "overview")=="members" then self:RefreshGuildDashboard()end
  end)
  p.search:SetScript("OnEscapePressed",function(box)box:SetText("");box:ClearFocus()end)
  p.search:SetScript("OnEnterPressed",function(box)box:ClearFocus()end)
  p.scope=filterButton(p,"Everyone",function()
    self.infoScope=self.infoScope=="online" and "offline" or self.infoScope=="offline" and nil or "online"
    self.infoDashboardStamp=nil;p.scroll:SetVerticalScroll(0);self:RefreshGuildDashboard()
  end)
  p.scope.tip="Cycle everyone, online and offline members."
  p.directorySummary=p:CreateFontString(nil,"OVERLAY","SunderChatDockFont");p.directorySummary:SetWordWrap(false);p.directorySummary:SetJustifyH("RIGHT")
  p.clearFilter=wm():CreateTextAction(p,"Clear filters",function()
    self.infoClass,self.infoZone,self.infoScope=nil,nil,nil;self.infoQuery="";p.search:SetText("")
    self.infoDashboardStamp=nil;p.scroll:SetVerticalScroll(0);self:RefreshGuildDashboard()
  end)
  for i,column in ipairs(columns)do
    local key=column[1]
    p.sortButtons[i]=filterButton(p,column[2],function()
      if self.infoSort==key then self.infoDescending=not self.infoDescending else self.infoSort=key;self.infoDescending=false end
      self.infoDashboardStamp=nil;p.scroll:SetVerticalScroll(0);self:RefreshGuildDashboard()
    end)
  end
  p.measure=p.child:CreateFontString(nil,"OVERLAY","SunderChatDockFont");p.measure:SetWordWrap(true);p.measure:Hide()
  p.scroll:HookScript("OnVerticalScroll",function()if self.infoMode=="guild" then self:RenderGuildDashboardRows()end end)
  p:HookScript("OnHide",function()p.search:ClearFocus();GameTooltip:Hide()end)
end
function G:HideGuildDashboard()
  local p=self.infoDrawer;if not p or not p.tabs then return end
  for _,list in ipairs({p.tabs,p.sortButtons,p.dashboardRows})do for _,row in ipairs(list)do row:Hide()end end
  p.search:Hide();p.scope:Hide();p.clearFilter:Hide();p.directorySummary:Hide();p.search:ClearFocus()
end
function G:LayoutGuildDashboard(width,pad,size)
  self:EnsureGuildDashboard();local p=self.infoDrawer
  if self.infoMode~="guild" then self.room.minimumContentHeight=nil;self:HideGuildDashboard();return end
  local tab=self.infoTab or "overview";local top=pad+size*2+18
  local available=math.max(1,width-pad*2)
  for i,b in ipairs(p.tabs)do
    b:ClearAllPoints();b:SetPoint("TOPLEFT",pad+(i-1)*available/3,-top);b:SetSize(available/3,NAV_HEIGHT);b:Show()
    b.selected=b.key==tab;b:Refresh();wm():ApplyPersonDetailFont(theme(),b:GetFontString())
  end
  top=top+NAV_HEIGHT+pad
  local members=tab=="members"
  p.search:SetShown(members);p.scope:SetShown(members);p.clearFilter:SetShown(members);p.directorySummary:SetShown(members)
  for _,b in ipairs(p.sortButtons)do b:SetShown(members)end
  if members then
    p.search:ClearAllPoints();p.search:SetPoint("TOPLEFT",pad,-top);p.search:SetSize(math.max(1,available-90),SEARCH_HEIGHT-4)
    p.search.placeholder:SetWidth(math.max(1,available-100))
    p.scope:ClearAllPoints();p.scope:SetPoint("TOPRIGHT",-pad,-top);p.scope:SetSize(86,SEARCH_HEIGHT-4)
    top=top+SEARCH_HEIGHT
    p.clearFilter:ClearAllPoints();p.clearFilter:SetPoint("TOPLEFT",pad,-top);p.clearFilter:SetSize(90,SORT_HEIGHT)
    p.directorySummary:ClearAllPoints();p.directorySummary:SetPoint("TOPRIGHT",-pad,-top-5);p.directorySummary:SetWidth(math.max(1,available-100));p.directorySummary:SetHeight(size+3);wm():ApplyPersonDetailFont(theme(),p.directorySummary);p.directorySummary:SetTextColor(.62,.68,.73)
    top=top+SORT_HEIGHT
    local left=pad
    for i,b in ipairs(p.sortButtons)do
      b:ClearAllPoints();b:SetPoint("TOPLEFT",left,-top);b:SetSize(available*columns[i][3],SORT_HEIGHT);left=left+b:GetWidth()
      wm():ApplyPersonDetailFont(theme(),b:GetFontString())
    end
    top=top+SORT_HEIGHT
  end
  p.viewport:ClearAllPoints();p.viewport:SetPoint("TOPLEFT",pad,-top);p.viewport:SetPoint("BOTTOMRIGHT",-pad,pad)
  p.child:SetWidth(available)
  self.room.minimumContentHeight=self.room:HeaderHeight()+wm():HeaderGap()+top+pad+(size*2+8)*2
end
function G:GuildDashboardModel()
  if self.infoRosterSource==self.members and self.infoRosterModel then return self.infoRosterModel end
  local model={online=0,total=0,classes={},zones={}};local classes,zones={},{}
  for _,person in ipairs(self.members or {})do
    model.total=model.total+1
    local key=(person.classFile or "")~="" and person.classFile or person.class
    if key and key~="" then
      local entry=classes[key]
      if not entry then
        local label=text(person.class)
        if label=="" then label=text((_G.LOCALIZED_CLASS_NAMES_MALE or {})[person.classFile]) end
        entry={key=key,label=label~="" and label or "Unknown class",classFile=person.classFile,count=0,total=0};classes[key]=entry
      end
      entry.total=entry.total+1;if person.online then entry.count=entry.count+1 end
    end
    if person.online then
      model.online=model.online+1
      local zone=(person.zone or "")~="" and person.zone or "Location unavailable"
      local entry=zones[zone]
      if not entry then entry={key=zone,label=text(zone),count=0,people={}};zones[zone]=entry end
      entry.count=entry.count+1
      if #entry.people<3 then entry.people[#entry.people+1]=person end
    end
  end
  for _,entry in pairs(classes)do model.classes[#model.classes+1]=entry end
  for _,entry in pairs(zones)do
    local names={}
    for _,person in ipairs(entry.people)do names[#names+1]=wm():FormatPersonName(text(person.name),person)end
    entry.preview=table.concat(names,", ")..(entry.count>#names and " +"..(entry.count-#names) or "")
    model.zones[#model.zones+1]=entry
  end
  local function sort(a,b)if a.count~=b.count then return a.count>b.count end;return a.label<b.label end
  table.sort(model.classes,sort);table.sort(model.zones,sort)
  self.infoRosterSource,self.infoRosterModel=self.members,model;return model
end
function G:GuildDashboardSpecs()
  local p=self.infoDrawer;local model=self:GuildDashboardModel();local rows={};local tab=self.infoTab or "overview"
  local function add(kind,label,extra)local row=extra or {};row.kind=kind;row.label=label;rows[#rows+1]=row end
  if tab=="overview" then
    add("stats","",{model=model})
    add("heading","Class presence",{section="classes",caption="Online / total members"})
    for _,entry in ipairs(model.classes)do add("class",entry.label,{entry=entry,maximum=math.max(1,entry.total),section="classes"})end
    if #model.classes==0 then add("text","Class information is not available yet.",{section="classes"})end
    add("heading","Where members are",{section="locations",caption="Online members by location"})
    for _,entry in ipairs(model.zones)do add("zone",entry.label,{entry=entry,section="locations"})end
    if #model.zones==0 then add("text","No members are currently online.",{section="locations"})end
  elseif tab=="about" then
    local name,rank=GetGuildInfo("player")
    add("heading",text(name));add("text","Your rank · "..text(rank))
    local motd=GetGuildRosterMOTD and GetGuildRosterMOTD() or C_GuildInfo and C_GuildInfo.GetMOTD and C_GuildInfo.GetMOTD()
    add("heading","Message of the day");add("text",text(motd)~="" and text(motd) or "No message of the day.")
    local get=GetGuildInfoText or C_GuildInfo and C_GuildInfo.GetGuildInfoText
    local value;if get then local ok,result=pcall(get);if ok then value=result end end
    add("heading","Guild information");add("text",text(value)~="" and text(value) or "No guild information has been provided.")
  else
    local members={};local query=(self.infoQuery or ""):lower()
    for _,person in ipairs(self.members or {})do
      local searchable=(person.name.." "..(person.class or "").." "..(person.rank or "").." "..(person.zone or "")):lower()
      if (not self.infoClass or self.infoClass==((person.classFile or "")~="" and person.classFile or person.class))
        and (not self.infoZone or self.infoZone==person.zone or self.infoZone=="Location unavailable" and person.zone=="")
        and (not self.infoScope or self.infoScope=="online" and person.online or self.infoScope=="offline" and not person.online)
        and (query=="" or searchable:find(query,1,true)) then members[#members+1]=person end
    end
    local key=self.infoSort or "name"
    table.sort(members,function(a,b)
      local x,y=a[key],b[key]
      if key=="rank" then x,y=a.rankIndex or 999,b.rankIndex or 999
      elseif key=="level" then x,y=tonumber(x) or 0,tonumber(y) or 0
      else x,y=(x or ""):lower(),(y or ""):lower() end
      if x==y then return a.name<b.name end
      if self.infoDescending then return x>y end;return x<y
    end)
    self.infoResultCount=#members
    for _,person in ipairs(members)do add("member",person.name,{person=person,key=person.key,guild=person.guildKey})end
    if #members==0 then add("text","No members match these filters. Try clearing filters or changing the presence filter.")end
  end
  return rows
end
function G:RefreshGuildDashboard()
  local p=self.infoDrawer;self:EnsureGuildDashboard();p.body:Hide()
  p.back:Hide();p.whisper:Hide();p.invite:Hide();p.favorite:Hide()
  local name=GetGuildInfo("player")
  local motd=GetGuildRosterMOTD and GetGuildRosterMOTD() or C_GuildInfo and C_GuildInfo.GetMOTD and C_GuildInfo.GetMOTD()
  p.title:SetText(text(name)~="" and text(name) or "Guild info");displayFont(p.title,theme():InterfaceTextSize()+2)
  p.detail:SetText(text(motd):gsub("[\r\n]+"," "));p.detail:SetTextColor(.65,.7,.76);p.detail:SetWordWrap(false);p.detail:SetJustifyH("LEFT");p.detail:Show()
  p.scope:SetText(self.infoScope=="online" and "Online" or self.infoScope=="offline" and "Offline" or "Everyone")
  p.scope.selected=self.infoScope~=nil;p.scope:Refresh()
  p.clearFilter:SetEnabled(self.infoClass~=nil or self.infoZone~=nil or self.infoScope~=nil or (self.infoQuery or "")~="")
  for i,b in ipairs(p.sortButtons)do
    b.selected=(self.infoSort or "name")==columns[i][1];b.tip="Sort by "..columns[i][2]:lower()..(b.selected and self.infoDescending and " (descending)" or " (ascending)");b:Refresh()
  end
  local width=math.max(1,p.child:GetWidth()-wm():ScrollRightInset(0));local size=theme():InterfaceTextSize()
  local stamp=table.concat({tostring(self.members),self.infoTab or "overview",self.infoQuery or "",self.infoClass or "",self.infoZone or "",self.infoScope or "",self.infoSort or "",tostring(self.infoDescending),width,size},":")
  if stamp~=self.infoDashboardStamp or self.infoTab=="about" then
    self.infoDashboardStamp=stamp;self.infoDashboardSpecs=self:GuildDashboardSpecs()
    local top=0;theme():WorkspaceFont(p.measure,size)
    local twoColumns=(self.infoTab or "overview")=="overview" and width>=math.max(OVERVIEW_COLUMN_MIN,size*22)*2+COLUMN_GAP
    local columnWidth=twoColumns and (width-COLUMN_GAP)/2 or width
    local sectionTop,sectionBottom={},{}
    for index,row in ipairs(self.infoDashboardSpecs)do
      row.order=index;row.x=twoColumns and row.section=="locations" and columnWidth+COLUMN_GAP or 0
      row.width=row.section and columnWidth or width
      if twoColumns and row.section then
        sectionTop[row.section]=sectionTop[row.section] or top
        row.top=sectionBottom[row.section] or sectionTop[row.section]
      else row.top=top end
      if row.kind=="stats" then row.height=size*3+28
      elseif row.kind=="text" then p.measure:SetWidth(row.width);p.measure:SetText(row.label);row.height=math.max(size+4,p.measure:GetStringHeight())+wm():BodyPadding()
      elseif row.kind=="heading" then row.height=SECTION_GAP+size+(row.caption and size+8 or 4)+SECTION_INSET
      elseif row.kind=="member" then row.height=size*2+8
      else row.height=size*2+14 end
      if twoColumns and row.section then sectionBottom[row.section]=row.top+row.height
      else top=row.top+row.height end
    end
    if twoColumns then top=math.max(top,sectionBottom.classes or 0,sectionBottom.locations or 0)end
    table.sort(self.infoDashboardSpecs,function(a,b)if a.top~=b.top then return a.top<b.top end;return a.order<b.order end)
    local visibleEnd=0
    for _,row in ipairs(self.infoDashboardSpecs)do visibleEnd=math.max(visibleEnd,row.top+row.height);row.visibleEnd=visibleEnd end
    p.child:SetHeight(math.max(1,top))
  end
  p.scroll:SetVerticalScroll(math.max(0,math.min(p.scroll:GetVerticalScroll(),p.child:GetHeight()-p.scroll:GetHeight())))
  if self.infoTab=="members" then
    local context=self.infoZone and text(self.infoZone) or ""
    if context=="" and self.infoClass then
      for _,entry in ipairs(self:GuildDashboardModel().classes)do if entry.key==self.infoClass then context=wm():FormatPersonName(entry.label,entry);break end end
    end
    p.directorySummary:SetText((context~="" and context.." · " or "")..tostring(self.infoResultCount or 0)..(self.infoResultCount==1 and " result" or " results"))
  end
  self:RenderGuildDashboardRows();wm():UpdateListScrollIndicator(p.scroll,p.child,p:IsShown())
end
function G:RenderGuildDashboardRows()
  local p=self.infoDrawer;if not p or self.infoMode~="guild" or not p:IsShown()then return end
  local specs=self.infoDashboardSpecs or {};local offset=p.scroll:GetVerticalScroll();local bottom=offset+p.scroll:GetHeight()
  local lo,hi=1,#specs
  while lo<=hi do local mid=math.floor((lo+hi)/2);if specs[mid].visibleEnd<=offset then lo=mid+1 else hi=mid-1 end end
  local width=math.max(1,p.child:GetWidth()-wm():ScrollRightInset(0));local size=theme():InterfaceTextSize();local slot=0
  for index=lo,#specs do
    local spec=specs[index];if spec.top>=bottom then break end
    if spec.top+spec.height>offset then
    local width=spec.width or width
    slot=slot+1;local row=p.dashboardRows[slot]
    if not row then
      row=CreateFrame("Button",nil,p.child);p.dashboardRows[slot]=row;row.labels={};row.stats={}
      row.fill=row:CreateTexture(nil,"BACKGROUND");row.fill:SetAllPoints()
      row.track=row:CreateTexture(nil,"BACKGROUND");row.track:SetHeight(3);row.track:SetPoint("BOTTOMLEFT",0,7);row.track:SetPoint("BOTTOMRIGHT",0,7);row.track:SetColorTexture(1,1,1,.045)
      row.bar=row:CreateTexture(nil,"BACKGROUND");row.bar:SetPoint("BOTTOMLEFT",0,7);row.bar:SetHeight(3)
      row.rule=row:CreateTexture(nil,"BORDER");row.rule:SetPoint("BOTTOMLEFT");row.rule:SetPoint("BOTTOMRIGHT");row.rule:SetHeight(1);row.rule:SetColorTexture(.65,.7,.75,.08)
      for i=1,4 do row.labels[i]=row:CreateFontString(nil,"OVERLAY","SunderChatDockFont")end
      row.sub=row:CreateFontString(nil,"OVERLAY","SunderChatDockFont")
      for i,label in ipairs({"Online","Offline","Members"})do
        local b=wm():CreateTextAction(row,label,function()self:OpenGuildDirectory(nil,nil,i==1 and "online" or i==2 and "offline" or "all")end)
        b.value=b:CreateFontString(nil,"OVERLAY","SunderChatDockFont");b.value:SetPoint("TOPLEFT",8,-9);b.value:SetPoint("TOPRIGHT",-8,-9);b.value:SetJustifyH("LEFT");b.value:SetWordWrap(false)
        b.caption=b:CreateFontString(nil,"OVERLAY","SunderChatDockFont");b.caption:SetPoint("BOTTOMLEFT",8,9);b.caption:SetPoint("BOTTOMRIGHT",-8,9);b.caption:SetJustifyH("LEFT");b.caption:SetWordWrap(false);b.caption:SetText(label)
        row.stats[i]=b
      end
      row:SetScript("OnClick",function()
        local current=row.spec
        if current.kind=="class" then self:OpenGuildDirectory(current.entry.key,nil,current.entry.count>0 and "online" or "all")
        elseif current.kind=="zone" then self:OpenGuildDirectory(nil,current.entry.key)
        elseif current.kind=="member" then
          local person=self.memberByName and self.memberByName[current.key]
          if person and person.guildKey==current.guild and current.guild==self.currentGuild then self:ShowMemberCard(person)end
        end
      end)
      row:SetScript("OnEnter",function()
        local current=row.spec
        if current.kind=="member" then
          local person=self.memberByName and self.memberByName[current.key]
          if not person or person.guildKey~=self.currentGuild then return end
          GameTooltip:SetOwner(row,"ANCHOR_RIGHT");GameTooltip:AddLine(wm():FormatPersonName(person.name,person),1,1,1)
          GameTooltip:AddLine((person.level and person.level>0 and person.level.." · " or "")..text(person.class),.7,.75,.8)
          GameTooltip:AddLine(text(person.rank).." · "..(person.online and text(person.zone) or "Offline"),.65,.7,.75)
          if Core.db.profile.guildChat.publicNotes and person.note~="" then GameTooltip:AddLine(text(person.note),.65,.7,.75,true)end
          GameTooltip:Show()
        elseif current.kind=="class" or current.kind=="zone" then
          GameTooltip:SetOwner(row,"ANCHOR_RIGHT");GameTooltip:AddLine(current.label,.9,.92,.94);GameTooltip:AddLine(current.kind=="class" and (current.entry.count.." online / "..current.entry.total.." members") or current.entry.preview,.75,.8,.85,true);GameTooltip:AddLine("Click to view members",.65,.7,.75);GameTooltip:Show()
        end
        if current.kind=="member" or current.kind=="class" or current.kind=="zone" then row.fill:SetColorTexture(1,1,1,.04)end
      end)
      row:SetScript("OnLeave",function()row.fill:SetColorTexture(1,1,1,row.baseAlpha or 0);GameTooltip:Hide()end)
      row:SetScript("OnHide",function()row.fill:SetColorTexture(0,0,0,0);row.spec=nil end)
    end
    row.spec=spec;row:ClearAllPoints();row:SetPoint("TOPLEFT",spec.x or 0,-spec.top);row:SetSize(width,spec.height)
    row.baseAlpha=spec.kind=="member" and spec.order%2==0 and .018 or 0
    row.fill:SetColorTexture(1,1,1,row.baseAlpha);row.bar:Hide();row.track:Hide();row.sub:Hide();row.sub:SetAlpha(1);row.sub:SetTextColor(.6,.67,.73)
    row.rule:SetShown(spec.kind=="member");row.rule:ClearAllPoints();row.rule:SetPoint("BOTTOMLEFT");row.rule:SetPoint("BOTTOMRIGHT");row.rule:SetColorTexture(.65,.7,.75,.06)
    for _,b in ipairs(row.stats)do b:Hide()end
    for _,label in ipairs(row.labels)do label:Hide();label:ClearAllPoints();label:SetWordWrap(false);label:SetJustifyH("LEFT");label:SetJustifyV("TOP");label:SetTextColor(.72,.76,.81);theme():WorkspaceFont(label,size)end
    local first=row.labels[1]
    if spec.kind=="stats" then
      local counts={spec.model.online,spec.model.total-spec.model.online,spec.model.total}
      local cell=(width-SUMMARY_GAP*2)/3
      for i,b in ipairs(row.stats)do
        b:ClearAllPoints();b:SetPoint("TOPLEFT",(i-1)*(cell+SUMMARY_GAP),0);b:SetSize(math.max(1,cell),spec.height-6);b:GetFontString():Hide()
        displayFont(b.value,size+7);b.value:SetHeight(size+11);b.value:SetText(counts[i])
        local r,g,blue=theme():InterfaceAccent();b.value:SetTextColor(i==1 and r or .84,i==1 and g or .87,i==1 and blue or .91)
        wm():ApplyPersonDetailFont(theme(),b.caption);b.caption:SetHeight(size+3);b.caption:SetTextColor(.58,.64,.69);b:Show()
      end
    elseif spec.kind=="member" then
      local person=spec.person;local values={wm():FormatPersonName(person.name,person),person.level and person.level>0 and tostring(person.level) or "",text(person.rank),person.online and text(person.zone) or "Offline"};local x=0
      for i,label in ipairs(row.labels)do label:SetPoint("TOPLEFT",x,3-spec.height/2);label:SetWidth(math.max(1,width*columns[i][3]-4));label:SetHeight(size+3);label:SetText(values[i]);label:SetAlpha(person.online and 1 or .45);label:Show();x=x+width*columns[i][3]end
      first:ClearAllPoints();first:SetPoint("TOPLEFT",0,-3)
      row.sub:ClearAllPoints();row.sub:SetPoint("TOPLEFT",0,-size-6);row.sub:SetWidth(math.max(1,width*columns[1][3]-4));row.sub:SetHeight(size+2);row.sub:SetWordWrap(false);wm():StylePersonDetail(theme(),row.sub,{class=person.class,classFile=person.classFile,online=person.online})
    else
      first:SetPoint("TOPLEFT",0,-4);first:SetWidth(width);first:SetText(spec.label);first:SetAlpha(1);first:SetHeight(spec.height-4);first:Show()
      if spec.kind=="text" then first:SetWordWrap(true)
      elseif spec.kind=="heading" then
        first:ClearAllPoints();first:SetPoint("TOPLEFT",0,-SECTION_GAP);first:SetHeight(size+5);displayFont(first,size+2);first:SetTextColor(.88,.86,.78)
        if spec.caption then
          row.sub:ClearAllPoints();row.sub:SetPoint("TOPLEFT",0,-SECTION_GAP-size-7);row.sub:SetWidth(width);row.sub:SetHeight(size+3);row.sub:SetWordWrap(false);wm():ApplyPersonDetailFont(theme(),row.sub);row.sub:SetText(spec.caption);row.sub:SetTextColor(.5,.57,.62);row.sub:SetAlpha(1);row.sub:Show()
        end
      else
        local color=spec.kind=="class" and wm():PersonColor(nil,spec.entry)
        first:SetTextColor(color and color.r or .8,color and color.g or .83,color and color.b or .86)
        first:SetHeight(size+4)
        local count=row.labels[2];count:SetPoint("TOPRIGHT",0,-4);count:SetHeight(size+3);count:SetJustifyH("RIGHT");count:SetAlpha(1)
        count:SetText(spec.kind=="class" and (spec.entry.count.." / "..spec.entry.total) or (spec.entry.count.." online"))
        local countWidth=count:GetStringWidth()+8;count:SetWidth(countWidth);count:Show();first:SetWidth(math.max(1,width-countWidth-8))
        if spec.kind=="class" then
          first:SetAlpha(spec.entry.count>0 and 1 or .5);count:SetAlpha(spec.entry.count>0 and .8 or .4);row.track:Show()
          row.bar:SetWidth(math.max(1,width*spec.entry.count/spec.maximum));row.bar:SetColorTexture(color and color.r or .68,color and color.g or .58,color and color.b or .36,.65);row.bar:SetShown(spec.entry.count>0)
        else
          row.sub:ClearAllPoints();row.sub:SetPoint("TOPLEFT",0,-size-9);row.sub:SetWidth(width);row.sub:SetHeight(size+3);row.sub:SetWordWrap(false);wm():ApplyPersonDetailFont(theme(),row.sub);row.sub:SetText(spec.entry.preview);row.sub:SetAlpha(.75);row.sub:Show()
        end
      end
    end
    row:Show()
    end
  end
  for i=slot+1,#p.dashboardRows do p.dashboardRows[i]:Hide()end
end
