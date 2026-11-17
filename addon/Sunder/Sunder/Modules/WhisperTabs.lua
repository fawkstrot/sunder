local Core, Constants, Utils = unpack(select(2, ...))
local WhisperTabs = Core:GetModule("WhisperTabs")

-- WoW provides these globals at runtime, so suppress Luacheck's undefined-global warning while localizing them.
-- luacheck: push ignore 113
local C_Timer = C_Timer
-- luacheck: pop

local SAVED_LINES = 100
-- Restore after the client has rebuilt its own chat windows.
local RESTORE_DELAY = 2

local function canAccess(value)
  return not _G.canaccessvalue or _G.canaccessvalue(value)
end

local function safeString(v) return canAccess(v) and type(v)=="string" and v~="" and not v:find("|K",1,true) end
local function accountByID(id)
  if not canAccess(id) or type(id)~="number" or not C_BattleNet or not C_BattleNet.GetAccountInfoByID then return end
  local ok,info=pcall(C_BattleNet.GetAccountInfoByID,id)
  if ok and canAccess(info) and type(info)=="table" and safeString(info.battleTag) then return info end
end
local function friends()
  local list={}
  if not BNGetNumFriends or not C_BattleNet or not C_BattleNet.GetFriendAccountInfo then return list end
  local ok,count=pcall(BNGetNumFriends)
  if not ok or not canAccess(count) or type(count)~="number" then return list end
  for i=1,count do
    local success,info=pcall(C_BattleNet.GetFriendAccountInfo,i)
    if success and canAccess(info) and type(info)=="table" and safeString(info.battleTag) then list[#list+1]=info end
  end
  return list
end
local function identity(tab)
  local target=tab.battleTag or tab.target
  return tostring(tab.kind or "WHISPER")..":"..(type(target)=="string" and target:lower() or "")
end
local function eachWhisperFrame(callback)
  local seen={}
  local function visit(frame)
    if not frame or seen[frame] or not frame.inUse then return end
    seen[frame]=true
    local target=frame.chatTarget
    if frame.chatType=="WHISPER" and safeString(target) then callback(frame,target,"WHISPER")
    elseif frame.chatType=="BN_WHISPER" then
      local info=accountByID(target)
      if info then callback(frame,target,"BN_WHISPER",info.battleTag) end
    end
  end
  -- Custom clients do not consistently expose Blizzard's isTemporary flag/list.
  local whispers=Core:GetModule("Whispers",true)
  for frame in pairs(whispers and whispers.records or {}) do visit(frame) end
  for _,name in ipairs(_G.CHAT_FRAMES or {}) do visit(type(name)=="string" and _G[name] or name) end
end
local function storageText(text)
  if not canAccess(text) or type(text)~="string" then return end
  -- Session-scoped name tokens and BN hyperlink IDs must never be replayed.
  if text:find("|K",1,true) then
    for _,info in ipairs(friends()) do
      local token=info.accountName
      if canAccess(token) and type(token)=="string" and token:find("|K",1,true) then
        text=text:gsub(token:gsub("(%W)","%%%1"),function() return info.battleTag end)
      end
    end
    text=text:gsub("|K.-|k","[Battle.net]")
    if text:find("|K",1,true) then return end
  end
  return text:gsub("|HBNplayer:.-|h(.-)|h","%1")
end
local function readLines(chatFrame,archive)
  local lines = {}
  local count = chatFrame:GetNumMessages()
  local cfg = Core.db.profile.whispers
  local limit = archive and math.max(20,math.min(1000,cfg and cfg.archiveLines or 500)) or cfg and math.max(20, math.min(200, cfg.historyLines or SAVED_LINES)) or SAVED_LINES
  for index = math.max(1, count - limit + 1), count do
    local text, red, green, blue, typeID = chatFrame:GetMessageInfo(index)
    text=storageText(text)
    if text and text ~= "" then
      local line = {text, canAccess(red) and type(red)=="number" and red or 1, canAccess(green) and type(green)=="number" and green or 1, canAccess(blue) and type(blue)=="number" and blue or 1}
      if canAccess(typeID) and type(typeID)=="number" then line.typeID=typeID end
      local entry = chatFrame.historyBuffer and chatFrame.historyBuffer:GetEntryAtIndex(count - index + 1)
      line.receivedAt=Utils.getMessageReceipt(entry)
      lines[#lines + 1] = line
    end
  end
  return lines
end

local function rendererLines(frame)
  local ui=Core:GetModule("UIManager")
  local window=ui:GetChatWindow(frame)
  local state=window and window.slidingMessageFrame and window.slidingMessageFrame.state
  local lines={}
  local limit=math.max(20,math.min(200,(Core.db.profile.whispers or {}).historyLines or SAVED_LINES))
  for i=math.min(limit,#(state and state.messages or {})),1,-1 do
    local message=state.messages[i]
    local text=storageText(message.sourceText)
    if text then
      local color=message.sourceColor or {1,1,1}
      local line={text,color[1],color[2],color[3],receivedAt=message.receivedAt,typeID=message.sourceTypeID}
      lines[#lines+1]=line
    end
  end
  return lines
end

function WhisperTabs:Save()
  -- Native window setup can emit messages before our delayed restore. Never
  -- replace the persisted checkpoint with those empty/partial startup windows.
  if self.awaitingRestore and Core.db.profile.keepWhisperTabs then return end
  local tabs,archiveTabs = {},{}
  if not Core.db.profile.keepWhisperTabs then self.pendingHistory=nil;self.restoreArchive=nil;self.awaitingRestore=nil end
  if Core.db.profile.keepWhisperTabs then
    local candidates = {}
    local whispers = Core:GetModule("Whispers", true)
    eachWhisperFrame(function (chatFrame, target, kind, battleTag)
      local record = whispers and whispers.records and whispers.records[chatFrame]
      candidates[#candidates + 1] = {frame = chatFrame, target = target, kind=kind, battleTag=battleTag, record=record, lastActivity = record and record.lastActivity or 0}
    end)
    table.sort(candidates, function (a, b) return a.lastActivity > b.lastActivity end)
    local cfg = Core.db.profile.whispers
    local limit = cfg and math.max(5, math.min(50, cfg.historyConversations or 20)) or 20
    for index = 1, math.min(200,#candidates) do
      local entry = candidates[index]
      local ok,lines=pcall(readLines,entry.frame)
      if not ok or #lines==0 then
        local fallback,rendered=pcall(rendererLines,entry.frame)
        if fallback and #rendered>0 then ok,lines=true,rendered end
      end
      if not ok or #lines==0 then
        local previous=self:ImportArchive()[identity(entry)]
        if previous and #previous.lines>0 then
          lines={};local keep=math.max(20,math.min(200,cfg and cfg.historyLines or SAVED_LINES))
          for i=math.max(1,#previous.lines-keep+1),#previous.lines do lines[#lines+1]=previous.lines[i] end
          ok=true
        end
      end
      if ok then
        local record=entry.record
        local host=record and whispers:HubFor(entry.frame)
        local window=Core:GetModule("UIManager"):GetChatWindow(entry.frame)
        local state=window and window.slidingMessageFrame and window.slidingMessageFrame.state
        local position
        for i,frame in ipairs(host and host.hubOrder or {}) do if frame==entry.frame then position=i;break end end
        local layout
        if record and record.placement then
          layout={placement=record.placement,workspace=record.workspace,pinned=record.pinned}
          if record.placement=="detached" then
            local point,_,_,x,y=entry.frame:GetPoint()
            layout.point=point;layout.x=x;layout.y=y;layout.width=entry.frame:GetWidth();layout.height=entry.frame:GetHeight()
          end
        end
        local saved={displayName=entry.kind=="WHISPER" and whispers:ConversationName(entry.frame) or nil,kind=entry.kind,battleTag=entry.battleTag,target=entry.kind=="WHISPER" and entry.target or nil,lines=lines,
          layout=layout,favorite=record and whispers:IsFavorite(entry.frame) or false,
          selected=host and host.selected==entry.frame or false,unread=record and record.unread or 0,order=position,
          scrollIndex=state and state.scrollIndex or 1,messageOffset=state and state.messageOffset or 0}
        if index<=limit then tabs[#tabs+1]=saved end
        local archiveEntry={};for k,v in pairs(saved) do archiveEntry[k]=v end
        self.archiveCaptured=self.archiveCaptured or {}
        local changed=self.archiveCaptured[entry.frame]~=identity(saved) or self.archiveDirty and self.archiveDirty[entry.frame]
        if changed then
          local captured,archiveLines=pcall(readLines,entry.frame,true)
          if captured and #archiveLines>0 then archiveEntry.lines=archiveLines end
          self.archiveCaptured[entry.frame]=identity(saved)
          if self.archiveDirty then self.archiveDirty[entry.frame]=nil end
        else archiveEntry.unchanged=true end
        archiveTabs[#archiveTabs+1]=archiveEntry
      end
    end
  end
  if Core.db.profile.keepWhisperTabs then
    local seen={};for _,tab in ipairs(tabs) do seen[identity(tab)]=true end
    for _,tab in ipairs(self.restoreArchive or self.pendingHistory or {}) do
      if not (self.deletedHistory and self.deletedHistory[identity(tab)]) and not seen[identity(tab)] and #tabs<math.max(5,math.min(50,(Core.db.profile.whispers or {}).historyConversations or 20)) then tabs[#tabs+1]=tab;seen[identity(tab)]=true end
    end
  end
  if Core.db.profile.keepWhisperTabs and self.loggingOut and #tabs==0 and self.liveSnapshot then tabs=self.liveSnapshot end
  self:UpdateArchive(archiveTabs)
  Core.db.char.whisperTabs = tabs
  if not self.loggingOut then self.liveSnapshot=tabs end
  Core.db.char.whisperHistoryError=nil
end

local function findWhisperFrame(target,kind)
  local found
  eachWhisperFrame(function (chatFrame, frameTarget,frameKind)
    if frameKind==(kind or "WHISPER") and (frameTarget==target or type(frameTarget)=="string" and type(target)=="string" and frameTarget:lower()==target:lower()) then found = found or chatFrame end
  end)
  return found
end

function WhisperTabs:Restore()
  local tabs = Core.db.char.whisperTabs
  if not Core.db.profile.keepWhisperTabs or type(tabs) ~= "table" or not _G.FCF_OpenTemporaryWindow
    or Core.db.profile.whispers and (not Core.db.profile.whispers.enabled or Core.db.profile.whispers.mode == "inline") then return end

  self.awaitingRestore=nil
  Core.db.char.whisperTabs = nil
  self.restoreArchive=tabs
  self.restoreInProgress=true
  self.restoreGeneration = (self.restoreGeneration or 0) + 1
  self.pendingHistory={}
  local generation = self.restoreGeneration
  local function stillEnabled()
    local cfg = Core.db.profile.whispers
    return self.restoreGeneration == generation and Core.db.profile.keepWhisperTabs
      and (not cfg or cfg.enabled and cfg.mode ~= "inline")
  end
  local restoreTab
  restoreTab = function (tabIndex)
    if not stillEnabled() then self.restoreInProgress=nil;return end
    local tab = tabs[tabIndex]
    if not tab then
      self.restoreArchive=nil;self.restoreInProgress=nil
      if self.retryAfterRestore then self.retryAfterRestore=nil;self:RetryPendingHistory() end
      return
    end
    if type(tab)~="table" or self.deletedHistory and self.deletedHistory[identity(tab)] then C_Timer.After(0,function() restoreTab(tabIndex+1) end);return end
    local function nextTab() C_Timer.After(0, function () restoreTab(tabIndex + 1) end) end
    local kind=tab.kind or "WHISPER"
    local resolved=tab.target
    if kind=="BN_WHISPER" then
      resolved=nil
      if safeString(tab.battleTag) then for _,info in ipairs(friends()) do
        if info.battleTag:lower()==tab.battleTag:lower() and canAccess(info.bnetAccountID) and type(info.bnetAccountID)=="number" and info.bnetAccountID>0 then resolved=info.bnetAccountID;break end
      end end
      if not resolved then self.pendingHistory[#self.pendingHistory+1]=tab;nextTab();return end
    elseif kind~="WHISPER" or not safeString(resolved) then nextTab();return end
    -- Native events may already have reopened this conversation; older lines go above them.
    local chatFrame = findWhisperFrame(resolved,kind)
    if not chatFrame then
      local ok, opened = pcall(_G.FCF_OpenTemporaryWindow, kind, resolved, nil, false)
      chatFrame = ok and opened or findWhisperFrame(resolved,kind)
    end
    if not chatFrame or type(tab.lines) ~= "table" then self.pendingHistory[#self.pendingHistory+1]=tab;nextTab(); return end
    local whispers=Core:GetModule("Whispers",true)
    local record=whispers and whispers:Record(chatFrame)
    if record and safeString(tab.displayName) then record.displayName=tab.displayName end
    if record and type(tab.layout)=="table" then record.saved=tab.layout;record.workspace=tab.layout.workspace;record.pinned=tab.layout.pinned;record.favorite=tab.favorite or false end
    local function restoreState()
      self.loadedArchiveFrames=self.loadedArchiveFrames or {};self.loadedArchiveFrames[chatFrame]=self:ArchiveKey(chatFrame)
      C_Timer.After(0,function ()
        if not stillEnabled() or not chatFrame.inUse then return end
        if record and type(tab.layout)=="table" then
          whispers:Place(chatFrame,tab.layout.placement or "hub",false)
          local host=whispers:HubFor(chatFrame)
          if record.placement=="hub" then
            if tab.selected then host.selected=chatFrame;host:RefreshHubSelection() end
            if tab.order then host.restoredHistoryOrder=host.restoredHistoryOrder or {};host.restoredHistoryOrder[chatFrame]=tab.order
              table.sort(host.hubOrder,function(a,b) return (host.restoredHistoryOrder[a] or 1000)<(host.restoredHistoryOrder[b] or 1000) end);host:LayoutHubTabs() end
          end
          record.unread=tonumber(tab.unread) or 0
        end
        local window=Core:GetModule("UIManager"):GetChatWindow(chatFrame)
        if window and (tonumber(tab.scrollIndex) or 1)>1 then window.slidingMessageFrame:SetScrollPosition(tab.scrollIndex,tonumber(tab.messageOffset) or 0) end
      end)
      nextTab()
    end
    local index = #tab.lines
    local function restoreChunk()
      if not stillEnabled() then return end
      local target = chatFrame.chatTarget
      if not chatFrame.inUse or record and whispers.records[chatFrame]~=record or chatFrame.chatType ~= kind or not canAccess(target)
        or not (target==resolved or kind=="WHISPER" and type(target)=="string" and target:lower()==resolved:lower()) then nextTab(); return end
      -- Bound synchronous native/renderer work to keep login responsive with large histories.
      local last = math.max(1, index - 11)
      for lineIndex = index, last, -1 do
        local line = tab.lines[lineIndex]
        if type(line) == "table" and type(line[1]) == "string" then
          Utils.restoreChatLine(chatFrame,line)
        end
      end
      index = last - 1
      if index > 0 then C_Timer.After(0, restoreChunk) else restoreState() end
    end
    if index > 0 then restoreChunk() else restoreState() end
  end
  restoreTab(1)
end

function WhisperTabs:RetryPendingHistory()
  if self.restoreInProgress then self.retryAfterRestore=true;return end
  if self.historyRetryScheduled or not self.pendingHistory or #self.pendingHistory==0 then return end
  self.historyRetryScheduled=true
  C_Timer.After(.5,function ()
    self.historyRetryScheduled=nil
    if not self.pendingHistory or #self.pendingHistory==0 then return end
    Core.db.char.whisperTabs=self.pendingHistory;self:Restore()
  end)
end
function WhisperTabs:ScheduleSave(frame)
  if frame then self.archiveDirty=self.archiveDirty or {};self.archiveDirty[frame]=true end
  if self.saveScheduled then return end
  self.saveScheduled=true
  C_Timer.After(.2,function()
    self.saveScheduled=nil
    if not self.restoreInProgress then self:Save() end
  end)
end
function WhisperTabs:OnEnable()
  self:ImportArchive()
  self.awaitingRestore=Core.db.profile.keepWhisperTabs and type(Core.db.char.whisperTabs)=="table"
    and #Core.db.char.whisperTabs>0 or nil
  local events=CreateFrame("Frame")
  for _,event in ipairs({"BN_CONNECTED","BN_FRIEND_INFO_CHANGED","BN_FRIEND_LIST_SIZE_CHANGED"}) do pcall(events.RegisterEvent,events,event) end
  events:RegisterEvent("PLAYER_LOGOUT")
  events:SetScript("OnEvent",function (_,event)
    if event=="PLAYER_LOGOUT" then
      self.loggingOut=true
      local ok,err=pcall(self.Save,self)
      if not ok then Core.db.char.whisperHistoryError=tostring(err) end
    else self:RetryPendingHistory() end
  end)
  self.historyEvents=events
  if C_Timer.NewTicker then self.checkpointTicker=C_Timer.NewTicker(10,function()
    if not self.restoreInProgress and not self.loggingOut then self:Save() end
  end) end
  -- AceDB fires this on logout and reload while the profile can still be read.
  Core.db.RegisterCallback(self, "OnDatabaseShutdown", function ()
    if self.loggingOut then return end
    local ok,err=pcall(self.Save,self)
    if not ok then Core.db.char.whisperHistoryError=tostring(err) end
  end)
  C_Timer.After(RESTORE_DELAY, function ()
    self:Restore()
  end)
end

-- Durable storage is independent of native window lifetimes. Open tabs remain
-- a small restore checkpoint; archived entries are loaded only when requested.
local function copy(value)
  if type(value)~="table" then return value end
  local out={};for k,v in pairs(value) do out[k]=copy(v) end;return out
end
function WhisperTabs:ImportArchive()
  local char=Core.db.char
  if type(char.whisperArchive)~="table" then
    char.whisperArchive={}
    for _,tab in ipairs(char.whisperTabs or {}) do
      if type(tab)=="table" and type(tab.lines)=="table" then char.whisperArchive[identity(tab)]=copy(tab) end
    end
  end
  return char.whisperArchive
end
function WhisperTabs:ArchiveKey(frame)
  if not frame then return end
  if frame.chatType=="WHISPER" and safeString(frame.chatTarget) then
    return identity({kind="WHISPER",target=frame.chatTarget})
  elseif frame.chatType=="BN_WHISPER" then
    local info=accountByID(frame.chatTarget)
    if info then return identity({kind="BN_WHISPER",battleTag=info.battleTag}) end
  end
end
local function sameLine(a,b)
  return a and b and a[1]==b[1] and a.receivedAt==b.receivedAt and a.typeID==b.typeID
end
local function mergeLines(old,new)
  if #old==0 then return copy(new) end
  local overlap=0
  for count=math.min(#old,#new),1,-1 do
    local match=true
    for i=1,count do if not sameLine(old[#old-count+i],new[i]) then match=false;break end end
    if match then overlap=count;break end
  end
  local lines=copy(old)
  for i=overlap+1,#new do lines[#lines+1]=copy(new[i]) end
  return lines
end
function WhisperTabs:UpdateArchive(tabs)
  if not Core.db.profile.keepWhisperTabs then return end
  local archive=self:ImportArchive()
  local now=GetServerTime and GetServerTime() or _G.time and _G.time() or GetTime()
  for _,tab in ipairs(tabs) do
    local key=identity(tab);local old=archive[key]
    if not (self.deletedHistory and self.deletedHistory[key]) and (not self.loadingArchive or not self.loadingArchive[key]) then
      -- Empty native windows must not erase a durable transcript.
      if #tab.lines>0 or not old then
        local entry=copy(tab);entry.closed=false;entry.updatedAt=now
        entry.unchanged=nil
        if old then
          entry.lines=tab.unchanged and old.lines or mergeLines(old.lines or {},tab.lines)
          entry.lineBytes=tab.unchanged and old.lineBytes or nil
          if #entry.lines==#old.lines and sameLine(entry.lines[#entry.lines],old.lines[#old.lines]) then entry.updatedAt=old.updatedAt or now end
        end
        archive[key]=entry
      elseif old then old.closed=false end
    end
  end
  -- Hard budgets include all archived text. Favorites are retained before
  -- ordinary entries; oldest messages/conversations are trimmed visibly.
  local entries={};local bytes=0
  local cfg=Core.db.profile.whispers or {}
  local lineLimit=math.max(20,math.min(1000,tonumber(cfg.archiveLines) or 500))
  local conversationLimit=math.max(5,math.min(200,tonumber(cfg.archiveConversations) or 100))
  for key,entry in pairs(archive) do
    entry.lines=entry.lines or {}
    while #entry.lines>lineLimit do table.remove(entry.lines,1);entry.lineBytes=nil;self.trimmedArchive=true end
    local size=entry.lineBytes
    if not size then
      size=0;for _,line in ipairs(entry.lines) do size=size+#(line[1] or "")+64 end
      entry.lineBytes=size
    end
    bytes=bytes+size;entries[#entries+1]={key=key,entry=entry,bytes=size}
  end
  table.sort(entries,function(a,b)
    if not not a.entry.favorite~=not not b.entry.favorite then return not not a.entry.favorite end
    return (a.entry.updatedAt or 0)>(b.entry.updatedAt or 0)
  end)
  for i=#entries,1,-1 do
    if i>conversationLimit or bytes>8*1024*1024 then
      local item=entries[i];archive[item.key]=nil;bytes=bytes-item.bytes;self.trimmedArchive=true
    end
  end
  Core.db.char.whisperArchiveTrimmed=Core.db.char.whisperArchiveTrimmed or self.trimmedArchive or nil
  self.archiveBytes=bytes
end
function WhisperTabs:BeforeClose(frame)
  if not Core.db.profile.keepWhisperTabs then return end
  local key=self:ArchiveKey(frame)
  if not key then return end
  self.archiveDirty=self.archiveDirty or {};self.archiveDirty[frame]=true
  self:Save()
  local entry=self:ImportArchive()[key]
  if entry then entry.closed=true end
  if self.loadedArchiveFrames then self.loadedArchiveFrames[frame]=nil end
  if self.archiveCaptured then self.archiveCaptured[frame]=nil end
  self.frameArchiveGenerations=self.frameArchiveGenerations or {}
  self.frameArchiveGenerations[frame]=(self.frameArchiveGenerations[frame] or 0)+1
  if self.loadingArchive then self.loadingArchive[key]=nil end
end
function WhisperTabs:OnConversationOpened(frame)
  if self.awaitingRestore or self.restoreInProgress or not Core.db.profile.keepWhisperTabs then return end
  local key=self:ArchiveKey(frame)
  local entry=key and self:ImportArchive()[key]
  if not entry or self.loadedArchiveFrames and self.loadedArchiveFrames[frame]==key then return end
  self.loadingArchive=self.loadingArchive or {}
  if self.loadingArchive[key] then return end
  local token={}
  self.loadingArchive[key]=token
  local frameGeneration=self.frameArchiveGenerations and self.frameArchiveGenerations[frame] or 0
  local function release()
    if self.loadingArchive[key]==token then self.loadingArchive[key]=nil end
  end
  local generation=self.archiveGeneration or 0
  local target=frame.chatTarget;local index=#entry.lines
  local floorIndex=math.max(1,index-math.max(20,math.min(200,(Core.db.profile.whispers or {}).historyLines or SAVED_LINES))+1)
  local function finishArchive()
    entry.closed=false;release()
    self.loadedArchiveFrames=self.loadedArchiveFrames or {};self.loadedArchiveFrames[frame]=key
    local whispers=Core:GetModule("Whispers")
    local record=whispers:Record(frame)
    if record then record.favorite=entry.favorite or false;record.displayName=entry.displayName;record.pinned=entry.layout and entry.layout.pinned or false end
    self:ScheduleSave()
  end
  local function chunk()
    if generation~=(self.archiveGeneration or 0) or not Core.db.profile.keepWhisperTabs
      or not frame.inUse or not canAccess(frame.chatTarget) or frame.chatTarget~=target
      or frameGeneration~=(self.frameArchiveGenerations and self.frameArchiveGenerations[frame] or 0) then release();return end
    local last=math.max(floorIndex,index-11)
    for i=index,last,-1 do
      local line=entry.lines[i]
      Utils.restoreChatLine(frame,line)
    end
    index=last-1
    if index>=floorIndex then C_Timer.After(0,chunk) else
      finishArchive()
    end
  end
  if index>0 then chunk() else finishArchive()end
end
function WhisperTabs:ShowArchive(key)
  local entry=self:ImportArchive()[key]
  if entry then Core:GetModule("ChatCopy"):ShowArchive(entry) end
end
function WhisperTabs:OpenArchive(key)
  local entry=self:ImportArchive()[key]
  if not entry or InCombatLockdown() then return end
  local target=entry.target;local kind=entry.kind or "WHISPER"
  if kind=="BN_WHISPER" then
    target=nil
    for _,info in ipairs(friends()) do if info.battleTag:lower()==entry.battleTag:lower() then target=info.bnetAccountID;break end end
  end
  if not target then Core:GetModule("Config"):Print("This Battle.net contact is unavailable. Their saved history is retained.");return end
  local frame=findWhisperFrame(target,kind)
  if not frame then local ok,result=pcall(FCF_OpenTemporaryWindow,kind,target,nil,false);if ok then frame=result end end
  if frame then C_Timer.After(0,function()
    if frame.inUse and self:ArchiveKey(frame)==key then
      local whispers=Core:GetModule("Whispers");whispers:MoveToWorkspace(frame,"messages")
      self:OnConversationOpened(frame);whispers:SelectConversation(frame,false)
    end
  end) end
end
function WhisperTabs:RequestDelete(key)
  if not self:ImportArchive()[key] then return end
  StaticPopupDialogs.SUNDER_DELETE_HISTORY={text="Delete this conversation and its saved message history? This cannot be undone.",
    button1=DELETE or "Delete",button2=CANCEL or "Cancel",timeout=0,whileDead=true,hideOnEscape=true,
    OnAccept=function(_,archiveKey)
      self.deletedHistory=self.deletedHistory or {};self.deletedHistory[archiveKey]=true
      local close={};local whispers=Core:GetModule("Whispers")
      for frame in pairs(whispers.records or {}) do if self:ArchiveKey(frame)==archiveKey then close[#close+1]=frame end end
      for _,frame in ipairs(close) do FCF_Close(frame) end
      self:ImportArchive()[archiveKey]=nil
      for i=#(Core.db.char.whisperTabs or {}),1,-1 do
        if identity(Core.db.char.whisperTabs[i])==archiveKey then table.remove(Core.db.char.whisperTabs,i) end
      end
      self.liveSnapshot=nil
      for _,host in pairs(whispers.workspaces or {}) do if host.hub then host:LayoutHubTabs() end end
    end}
  StaticPopup_Show("SUNDER_DELETE_HISTORY",nil,nil,key)
end
