local Core = unpack(select(2, ...))
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
local function readLines(chatFrame)
  local lines = {}
  local count = chatFrame:GetNumMessages()
  local cfg = Core.db.profile.whispers
  local limit = cfg and math.max(20, math.min(200, cfg.historyLines or SAVED_LINES)) or SAVED_LINES
  for index = math.max(1, count - limit + 1), count do
    local text, red, green, blue, typeID = chatFrame:GetMessageInfo(index)
    text=storageText(text)
    if text and text ~= "" then
      local line = {text, canAccess(red) and type(red)=="number" and red or 1, canAccess(green) and type(green)=="number" and green or 1, canAccess(blue) and type(blue)=="number" and blue or 1}
      if canAccess(typeID) and type(typeID)=="number" then line.typeID=typeID end
      local entry = chatFrame.historyBuffer and chatFrame.historyBuffer:GetEntryAtIndex(count - index + 1)
      local serverTime = entry and entry.serverTime
      if canAccess(serverTime) and type(serverTime) == "number" then line.receivedAt = serverTime end
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
  local tabs = {}
  if not Core.db.profile.keepWhisperTabs then self.pendingHistory=nil;self.restoreArchive=nil end
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
    for index = 1, math.min(limit, #candidates) do
      local entry = candidates[index]
      local ok,lines=pcall(readLines,entry.frame)
      if not ok or #lines==0 then
        local fallback,rendered=pcall(rendererLines,entry.frame)
        if fallback and #rendered>0 then ok,lines=true,rendered end
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
          layout=layout,favorite=record and record.favorite or false,
          selected=host and host.selected==entry.frame or false,unread=record and record.unread or 0,order=position,
          scrollIndex=state and state.scrollIndex or 1,messageOffset=state and state.messageOffset or 0}
        tabs[#tabs+1]=saved
      end
    end
  end
  if Core.db.profile.keepWhisperTabs then
    local seen={};for _,tab in ipairs(tabs) do seen[identity(tab)]=true end
    for _,tab in ipairs(self.restoreArchive or self.pendingHistory or {}) do
      if not seen[identity(tab)] and #tabs<math.max(5,math.min(50,(Core.db.profile.whispers or {}).historyConversations or 20)) then tabs[#tabs+1]=tab;seen[identity(tab)]=true end
    end
  end
  if Core.db.profile.keepWhisperTabs and self.loggingOut and #tabs==0 and self.liveSnapshot then tabs=self.liveSnapshot end
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
    if type(tab)~="table" then C_Timer.After(0,function() restoreTab(tabIndex+1) end);return end
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
      if not chatFrame.inUse or chatFrame.chatType ~= kind or not canAccess(target)
        or not (target==resolved or kind=="WHISPER" and type(target)=="string" and target:lower()==resolved:lower()) then nextTab(); return end
      -- Bound synchronous native/renderer work to keep login responsive with large histories.
      local last = math.max(1, index - 11)
      for lineIndex = index, last, -1 do
        local line = tab.lines[lineIndex]
        if type(line) == "table" and type(line[1]) == "string" then
          chatFrame:BackFillMessage(line[1], line[2], line[3], line[4], line.typeID)
          if type(line.receivedAt) == "number" then
            local entry = chatFrame.historyBuffer and chatFrame.historyBuffer:GetEntryAtIndex(chatFrame:GetNumMessages())
            if entry and canAccess(entry) then entry.serverTime = line.receivedAt end
            local window = Core:GetModule("UIManager"):GetChatWindow(chatFrame)
            local pending = window and window.slidingMessageFrame and window.slidingMessageFrame.state.incomingScrollbackMessages
            if pending and pending[#pending] then pending[#pending].receivedAt = line.receivedAt end
          end
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
function WhisperTabs:ScheduleSave()
  if self.saveScheduled then return end
  self.saveScheduled=true
  C_Timer.After(.2,function()
    self.saveScheduled=nil
    if not self.restoreInProgress then self:Save() end
  end)
end
function WhisperTabs:OnEnable()
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
