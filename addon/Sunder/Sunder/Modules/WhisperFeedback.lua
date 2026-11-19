local Core = unpack(select(2, ...))
local W = Core:GetModule("Whispers")
local function accessible(value) return not _G.canaccessvalue or _G.canaccessvalue(value) end
local function clamp(value,low,high) return math.max(low,math.min(high,value)) end

local refreshNavigation=W.RefreshConversationNavigation
function W:RefreshConversationNavigation(preview)
  refreshNavigation(self,preview)
  local nav=preview and self.previewNavigation or self.conversationNavigation
  if nav then
    nav:SetParent(self.hubChrome);nav:SetFrameLevel(self.hubChrome:GetFrameLevel()+5)
    nav.all:SetEnabled(self.minimized or (nav.total or 0)>0)
    nav.all:RegisterForClicks("LeftButtonUp")
    if not nav.restoreTooltip then
      nav.restoreTooltip=true
      nav.all:HookScript("OnEnter",function() if self.minimized then GameTooltip:AddLine("Click to expand this window",1,1,1);Core:GetModule("Fonts"):StyleTooltip(GameTooltip);GameTooltip:Show() end end)
    end
    nav.all:SetScript("OnClick",function()
      self.hubOpenedAt=GetTime();self.lastUserInteraction=GetTime()
      GameTooltip:Hide()
      if self.minimized then self:SetMinimized(false) else self:ShowConversationPicker(preview,nav.all) end
    end)
    nav:SetShown(preview and self.previewActive or not preview and not self.previewActive)
  end
  local scroll=preview and self.previewTabScroll or self.tabScroll
  if scroll and not self:IsConversationList() and scroll.scrollRail then scroll.scrollRail:Hide() end
end

-- Queue entries contain session-only references; no message text enters SavedVariables.
function W:LatestWhisperSnippet(frame)
  if not frame or not frame.GetNumMessages or not frame.GetMessageInfo then return "New whisper received." end
  local ok,count=pcall(frame.GetNumMessages,frame)
  if not ok or not accessible(count) or type(count)~="number" or count<1 then return "New whisper received." end
  local success,text=pcall(frame.GetMessageInfo,frame,count)
  if not success or not accessible(text) or type(text)~="string" then return "New whisper received." end
  return text:gsub("|T.-|t",""):gsub("|A.-|a",""):gsub("[\r\n]"," ")
end
-- Preview only: native history and exact-message jump tokens stay unchanged.
function W:WhisperToastText(text)
  local function plain(value)
    return value:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
      :gsub("|H.-|h(.-)|h", "%1"):gsub("|T.-|t", ""):gsub("|A.-|a", "")
  end
  text=plain(text):gsub("[\r\n]", " ")
  local format=plain(_G.CHAT_WHISPER_GET or "%s whispers: ")
  local pattern=format:gsub("%%1%$s", "SUNDERNAME"):gsub("%%s", "SUNDERNAME")
    :gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1"):gsub("SUNDERNAME", ".-")
  return (text:gsub("^"..pattern, "", 1))
end
function W:QueueMinimizedWhisper(person,sample,text,seed,nativeArgs)
  if self:Settings().minimizedPreviews==false then return end
  if not sample and W:IsConversationDisplayed(person) then return end
  if sample and not self.minimized and self.hub and self.hub:IsShown() and self.previewConversations and self.previewConversations[self.previewSelected or 1]==person then return end
  local record=sample and person or W.records[person]
  if not record then return end
  local name=sample and person.name
  if not name then
    local tab=_G[person:GetName().."Tab"]
    local label=W:ConversationName(person)
    name=accessible(label) and type(label)=="string" and label or "Whisper"
  end
  text=accessible(text) and type(text)=="string" and text or self:LatestWhisperSnippet(person)
  self.minimizedWhispers=self.minimizedWhispers or {}
  if seed then for _,entry in ipairs(self.minimizedWhispers) do if entry.person==person then return end end end
  local entry={person=person,record=record,sample=sample,name=name,text=sample and text or self:WhisperToastText(text),received=GetTime(),nativeToken=nativeArgs}
  if sample then
    for i=#(person.lines or {}),1,-1 do local line=person.lines[i];if not line.outgoing and line.text==text then entry.line=line;break end end
  elseif person.GetNumMessages then
    local success,count=pcall(person.GetNumMessages,person)
    if success and accessible(count) and type(count)=="number" then entry.nativeIndex=count end
    local ok,raw=pcall(person.GetMessageInfo,person,entry.nativeIndex or 1)
    if ok and accessible(raw) and type(raw)=="string" then entry.raw=raw end
  end
  if (self.whisperToastOffset or 0)>0 then self.whisperToastOffset=self.whisperToastOffset+1 end
  table.insert(self.minimizedWhispers,1,entry)
  while #self.minimizedWhispers>50 do table.remove(self.minimizedWhispers) end
  self:UpdateMinimizedWhispers()
end
function W:DismissMinimizedWhisper(person,onlyEntry)
  GameTooltip:Hide()
  for i=#(self.minimizedWhispers or {}),1,-1 do if self.minimizedWhispers[i].person==person and (not onlyEntry or self.minimizedWhispers[i]==onlyEntry) then table.remove(self.minimizedWhispers,i) end end
  self:UpdateMinimizedWhispers()
end
function W:OpenMinimizedWhisper(entry)
  GameTooltip:Hide()
  if not entry then return end
  local host=self
  if entry.sample then
    host=entry.person.host
    if not host or not host.previewActive then return self:DismissMinimizedWhisper(entry.person) end
  else
    local record=W.records[entry.person]
    if not record or not entry.person.inUse then return self:DismissMinimizedWhisper(entry.person) end
    if InCombatLockdown() and entry.person:IsProtected() then return end
    host=W:HubFor(entry.person)
  end
  self:UpdateMinimizedWhispers()
  host.windowManuallyClosed=nil;host.hubOpenedAt=GetTime()
  if entry.sample then host:SetMinimized(false) end
  host.hub:Show();host.hub:SetAlpha(1);host:SaveMessageWindowState()
  if entry.sample then
    for i,c in ipairs(host.previewConversations) do if c==entry.person then host:SelectPreviewConversation(i);break end end
  else W:SelectConversation(entry.person,false) end
  host.pendingWhisperToast=entry
  -- Opening a person acknowledges their waiting notifications in every group.
  -- Retain the clicked entry separately so the exact-message jump still works.
  local hosts={[self]=true,[host]=true}
  for _,workspace in pairs(W.workspaces or {}) do hosts[workspace]=true end
  for _,workspace in ipairs(W.previewDetachedHosts or {}) do hosts[workspace]=true end
  for workspace in pairs(hosts) do
    if workspace.minimizedWhispers then workspace:DismissMinimizedWhisper(entry.person) end
  end
end
function W:JumpToWhisperToast(entry)
  if entry.sample then
    if not self.previewBody then return end
    self.previewJumpLine=entry.line;self:RenderPreview()
    for i,line in ipairs(entry.person.lines or {}) do
      if line==entry.line then
        if self.previewBody.SetScrollOffset then
          self.previewBody:SetScrollOffset((self.previewRenderedRows or #entry.person.lines)-(line.renderedRow or i))
          self.previewBody:RefreshScrollRail()
        end
        self:FlashWhisperMessage(self.previewBody)
        return
      end
    end
  else
    local window=Core:GetModule("UIManager"):GetChatWindow(entry.person)
    local smf=window and window.slidingMessageFrame
    if smf and smf.state then
      for i=#smf.state.messages,1,-1 do local message=smf.state.messages[i]
        if message.sourceFrame==entry.person and (entry.nativeToken and message.whisperSourceToken==entry.nativeToken or not entry.nativeToken and message.sourceText==entry.raw and entry.nativeIndex and (#smf.state.messages-i == entry.person:GetNumMessages()-entry.nativeIndex)) then
          smf:SetScrollPosition(#smf.state.messages-i+1,0);self:FlashWhisperMessage(message);return
        end
      end
    end
  end
end
function W:FlashWhisperMessage(parent)
  -- A brief wash confirms navigation without changing the message renderer.
  local flash=parent.whisperJumpFlash
  if not flash then
    flash=CreateFrame("Frame",nil,parent);parent.whisperJumpFlash=flash;flash:SetAllPoints();flash:EnableMouse(false)
    local texture=flash:CreateTexture(nil,"OVERLAY");texture:SetAllPoints();texture:SetColorTexture(1,.78,.22,.08)
  end
  local elapsed=0;flash:SetAlpha(1);flash:Show()
  flash:SetScript("OnUpdate",function(_,dt) elapsed=elapsed+dt;flash:SetAlpha(math.max(0,1-elapsed/.8));if elapsed>=.8 then flash:Hide();flash:SetScript("OnUpdate",nil) end end)
end
function W:PageWhisperToasts(delta)
  self.whisperToastOffset=(self.whisperToastOffset or 0)+delta
  if self.minimizedWhisperTray then self.minimizedWhisperTray.stamp=nil end
  self:UpdateMinimizedWhispers()
end
function W:EnsureMinimizedWhisperTray()
  if self.minimizedWhisperTray then return end
  local tray=CreateFrame("Frame",nil,UIParent)
  self.minimizedWhisperTray=tray;tray.rows={};tray:SetFrameStrata("MEDIUM");tray:SetFrameLevel(self.hub:GetFrameLevel()+30)
  tray:SetPoint("BOTTOMLEFT",self.hub,"TOPLEFT",0,6);tray:SetPoint("BOTTOMRIGHT",self.hub,"TOPRIGHT",0,6)
  tray:SetHeight(1);tray:SetClipsChildren(true);tray:SetClampedToScreen(true)
  tray:SetScript("OnHide",function()
    if tray:GetScript("OnUpdate") then tray:SetScript("OnUpdate",nil);tray.stamp=nil end
  end)
end
function W:UpdateMinimizedWhispers()
  local now=GetTime();local cfg=self:Settings()
  local queue=self.minimizedWhispers or {}
  for i=#queue,1,-1 do
    local entry=queue[i]
    local record=entry.sample and entry.person or W.records[entry.person]
    local expired=cfg.minimizedPreviewUntilRead==false and now-entry.received>=clamp(tonumber(cfg.minimizedPreviewTime) or 20,5,60)
    local displayed=not entry.sample and W:IsConversationDisplayed(entry.person)
    if displayed or expired or not record or entry.record and entry.record~=record or entry.sample and not entry.person.host then table.remove(queue,i) end
  end
  local limit=clamp(tonumber(cfg.minimizedPreviewRows) or 5,1,10)
  self.whisperToastOffset=clamp(self.whisperToastOffset or 0,0,math.max(0,#queue-limit))
  local offset=self.whisperToastOffset
  local count=cfg.enabled and (self.hub:IsShown() or self.tabMinimized and Core.Components.WindowManager:MinimizedToastAnchor(self):IsShown() or not self.tabMinimized and self==W and cfg.singleToasterStack) and cfg.minimizedPreviews~=false and math.min(#queue,limit) or 0
  if count==0 and not self.minimizedWhisperTray then return end
  self:EnsureMinimizedWhisperTray()
  local tray=self.minimizedWhisperTray
  local inset=self.simulationStatus and self.simulationStatus:IsShown() and W.previewSimulation and self.simulationStatus:GetHeight()+12 or 6
  local anchor=Core.Components.WindowManager:MinimizedToastAnchor(self)
  if tray.anchorInset~=inset or tray.anchorWindow~=anchor then
    tray.anchorInset=inset;tray.anchorWindow=anchor;tray:ClearAllPoints()
    tray:SetPoint("BOTTOMLEFT",anchor,"TOPLEFT",0,inset);tray:SetPoint("BOTTOMRIGHT",anchor,"TOPRIGHT",0,inset)
  end
  if not tray.navigation then
    local nav=CreateFrame("Frame",nil,tray);tray.navigation=nav;nav:SetHeight(22);nav:SetPoint("BOTTOMLEFT");nav:SetPoint("BOTTOMRIGHT")
    nav.previous=self:IconButton(nav,"left","Newer whispers",function() self:PageWhisperToasts(-(tonumber(self:Settings().minimizedPreviewRows) or 5)) end);nav.previous:SetPoint("LEFT",4,0)
    nav.next=self:IconButton(nav,"right","Older whispers",function() self:PageWhisperToasts(tonumber(self:Settings().minimizedPreviewRows) or 5) end);nav.next:SetPoint("RIGHT",-4,0)
    nav.label=nav:CreateFontString(nil,"OVERLAY","SunderChatDockFont");nav.label:SetPoint("CENTER");self:WorkspaceFont(nav.label,self:InterfaceTextSize())
    tray.setRailOffset=function(owner,value)
      self.whisperToastOffset=math.floor(owner.scrollRail.maximum-value+.5)
      self:UpdateMinimizedWhispers()
    end
    tray:EnableMouseWheel(true);tray:SetScript("OnMouseWheel",function(_,delta) self:PageWhisperToasts(-delta) end)
  end
  local navHeight=#queue>limit and count>0 and 22 or 0
  tray.navigation:SetShown(navHeight>0)
  tray.navigation.previous:SetEnabled(offset>0);tray.navigation.next:SetEnabled(offset+limit<#queue)
  tray.navigation.label:SetText(string.format("%d–%d / %d",offset+1,offset+count,#queue))
  local bg=Core.db.profile.chatBackgroundColor or {}
  local padding=self:BodyPadding()
  local stamp=tostring(padding)..":"..tostring(bg.r)..tostring(bg.g)..tostring(bg.b)..tostring(bg.a)..tostring(count)..":"..offset..":"..#queue..":"..self:InterfaceTextSize()..":"..anchor:GetWidth()
  for i=1,count do
    local entry=queue[i+offset]
    local starred=entry.sample and entry.person.favorite or not entry.sample and W:IsFavorite(entry.person)
    stamp=stamp..tostring(entry)..entry.received..tostring(starred)
  end
  if tray.stamp==stamp then return end
  tray.stamp=stamp
  local rowHeight=math.max(40,self:InterfaceTextSize()*2+padding*2+8)
  local spacing=4
  local r,g,b=self:InterfaceAccent()
  for i=1,10 do
    local row=tray.rows[i]
    if i<=count then
      if not row then
        row=CreateFrame("Button",nil,tray);tray.rows[i]=row
        row:EnableMouse(true);row:RegisterForClicks("LeftButtonUp")
        row:EnableMouseWheel(true);row:SetScript("OnMouseWheel",function(_,delta) self:PageWhisperToasts(-delta) end)
        row.fill=row:CreateTexture(nil,"BACKGROUND");row.fill:SetAllPoints()
        row.name=row:CreateFontString(nil,"OVERLAY","SunderChatDockFont")
        row.name:SetPoint("TOPLEFT",10,-6);row.name:SetPoint("TOPRIGHT",-30,-6);row.name:SetJustifyH("LEFT");row.name:SetWordWrap(false)
        row.snippet=row:CreateFontString(nil,"OVERLAY","SunderChatDockFont")
        row.snippet:SetPoint("TOPLEFT",10,-22);row.snippet:SetPoint("TOPRIGHT",-12,-22);row.snippet:SetJustifyH("LEFT");row.snippet:SetWordWrap(false)
        row.close=self:IconButton(row,"close","Dismiss this whisper preview",function() if row.entry then self:DismissMinimizedWhisper(row.entry.person,row.entry) end end)
        row.close:SetSize(18,18);row.close.icon:SetSize(10,10);row.close:SetPoint("TOPRIGHT",-3,-3)
        row:SetHighlightTexture("Interface\\Buttons\\WHITE8X8");row:GetHighlightTexture():SetVertexColor(r,g,b,.06)
        row:SetScript("OnClick",function() self:OpenMinimizedWhisper(row.entry) end)
        row:SetScript("OnEnter",function()
          GameTooltip:SetOwner(row,"ANCHOR_RIGHT");GameTooltip:AddLine(Core.Components.WindowManager:FormatPersonName(row.entry and row.entry.name or "Whisper"),1,1,1)
          GameTooltip:AddLine("Click to open this message. Mouse-wheel for older whispers.",.7,.75,.8);Core:GetModule("Fonts"):StyleTooltip(GameTooltip);GameTooltip:Show()
        end)
        row:SetScript("OnLeave",function() GameTooltip:Hide() end)
      end
      local entry=queue[i+offset];local changed=row.entry~=entry
      row.entry=entry;row:SetHeight(rowHeight);row:SetWidth(anchor:GetWidth())
      row.fromY=row.currentY or (i-1)*(rowHeight+spacing);row.targetY=navHeight+(i-1)*(rowHeight+spacing)
      row.fromAlpha=changed and 0 or row:GetAlpha()
      row:SetAlpha(row.fromAlpha);row.retiring=nil;row:Enable()
      local textSize=self:InterfaceTextSize()
      row.name:ClearAllPoints();row.name:SetPoint("TOPLEFT",padding,-padding);row.name:SetPoint("TOPRIGHT",-padding-24,-padding)
      row.name:SetHeight(textSize+2)
      row.snippet:ClearAllPoints();row.snippet:SetPoint("TOPLEFT",padding,-padding-textSize-6);row.snippet:SetPoint("TOPRIGHT",-padding,-padding-textSize-6);row.snippet:SetHeight(textSize+2)
      self:WorkspaceFont(row.name,textSize);row.name:SetTextColor(self:ConversationLabelColor(false,entry.person))
      self:WorkspaceFont(row.snippet,self:InterfaceTextSize());row.snippet:SetTextColor(.78,.81,.84)
      local starred=entry.sample and entry.person.favorite or not entry.sample and W:IsFavorite(entry.person)
      local badge=starred and "|TInterface\\AddOns\\Sunder\\Media\\Icons\\favorite-filled.tga:12:12:0:0|t " or ""
      row.name:SetText(badge..entry.name);row.snippet:SetText(entry.text)
      local color=Core.db.profile.chatBackgroundColor or {r=.035,g=.04,b=.05,a=.25}
      if Core.Components.PaintGradientTexture then Core.Components.PaintGradientTexture(row.fill,color,color.a or .25,true)
      else row.fill:SetColorTexture(color.r,color.g,color.b,color.a or .25) end
      row.close:SetPoint("TOPRIGHT",navHeight>0 and -14 or -3,-3)
      row:Show()
    elseif row then row.retiring=row:IsShown();row.fromAlpha=row:GetAlpha();row.entry=nil;row:Disable() end
  end
  local from=tray:GetHeight();local target=count>0 and count*(rowHeight+spacing)-spacing+navHeight or 1
  local fromAlpha=tray:GetAlpha();local elapsed=0
  Core.Components.WindowManager:UpdateScrollRail(tray,navHeight>0,math.min(from,target)-navHeight,#queue,count,#queue-count-offset,tray.setRailOffset)
  tray:Show()
  tray:SetScript("OnUpdate",function(_,delta)
    elapsed=elapsed+delta;local t=math.min(1,elapsed/.18);local eased=t*t*(3-2*t)
    tray:SetHeight(from+(target-from)*eased)
    if navHeight>0 then Core.Components.WindowManager:UpdateScrollRail(tray,true,tray:GetHeight()-navHeight,#queue,count,#queue-count-offset,tray.setRailOffset) end
    tray:SetAlpha(count>0 and 1 or fromAlpha*(1-eased))
    for i=1,count do
      local row=tray.rows[i];local y=row.fromY+(row.targetY-row.fromY)*eased
      row.currentY=y;row:ClearAllPoints();row:SetPoint("BOTTOMLEFT",tray,"BOTTOMLEFT",0,y);row:SetPoint("BOTTOMRIGHT",tray,"BOTTOMRIGHT",0,y)
      row:SetAlpha(row.fromAlpha+(1-row.fromAlpha)*eased)
    end
    for i=count+1,10 do local row=tray.rows[i];if row and row.retiring then row:SetAlpha(row.fromAlpha*(1-eased)) end end
    if t==1 then
      tray:SetScript("OnUpdate",nil)
      for i=count+1,10 do local row=tray.rows[i];if row then row:Hide();row.retiring=nil;row.name:SetText("");row.snippet:SetText("") end end
      if count==0 then tray:Hide() end
    end
  end)
end
local tick=W.Tick
function W:Tick()
  tick(self)
  for _,host in pairs(W.workspaces or {}) do if host.pendingWhisperToast and not host.collapseAnimation then local entry=host.pendingWhisperToast;host.pendingWhisperToast=nil;host:JumpToWhisperToast(entry) end
    if host.minimizedWhispers or host.minimizedWhisperTray then host:UpdateMinimizedWhispers() end end
end
local minimize=W.SetMinimized
function W:SeedWaitingWhispers()
  local list=self.previewActive and self.previewConversations or self.hubOrder
  local maximum=clamp(tonumber(self:Settings().minimizedPreviewRows) or 5,1,10)
  local waiting={}
  for _,person in ipairs(list or {}) do
    local record=self.previewActive and person or W.records[person]
    if record and (record.unread or 0)>0 then waiting[#waiting+1]=person end
  end
  -- Seed only the visible stack; new messages from any person can replace these rows.
  for i=math.min(#waiting,maximum),1,-1 do
    local person=waiting[i];local text
    if self.previewActive then
      for j=#person.lines,1,-1 do if not person.lines[j].outgoing then text=person.lines[j].text;break end end
    end
    self:QueueMinimizedWhisper(person,not not self.previewActive,text,true)
  end
end
function W:SetMinimized(value,instant)
  local was=self.minimized
  if self.hub then
    local cfg=self:HubSettings();cfg.hubHeight=clamp(tonumber(cfg.hubHeight) or 340,220,1000)
    if not value and not self.collapseAnimation and self.hub:GetHeight()<=self:HeaderHeight()+1 then self.minimized=nil end
  end
  minimize(self,value,instant)
  if value and not was and self:Settings().minimizedPreviews~=false then self:SeedWaitingWhispers() end
  self:UpdateMinimizedWhispers()
end
local stopSamples=W.StopPreview
function W:StopPreview()
  stopSamples(self)
  local hosts={}
  for _,host in pairs(W.workspaces or {}) do hosts[host]=true end
  for _,host in ipairs(W.previewDetachedHosts or {}) do hosts[host]=true end
  for host in pairs(hosts) do
    if host.pendingWhisperToast and host.pendingWhisperToast.sample then host.pendingWhisperToast=nil end
    host.previewJumpLine=nil
    for i=#(host.minimizedWhispers or {}),1,-1 do if host.minimizedWhispers[i].sample then table.remove(host.minimizedWhispers,i) end end
    if host.minimizedWhisperTray then host:UpdateMinimizedWhispers() end
  end
end


-- A session-local sample owner can use the same tray without routing to the live stack.
Core.Components.WhisperToastQueue = W.QueueMinimizedWhisper
Core.Components.UpdateWhisperToastTray = W.UpdateMinimizedWhispers
