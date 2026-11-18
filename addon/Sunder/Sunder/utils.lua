local Core, Constants, Utils = unpack(select(2, ...))

-- Retail must retain native methods used by the secure chat and Combat Log handlers.
function Utils.hookPresentation(owner, object, method, handler)
  if Constants.ENV ~= "retail" then
    owner:RawHook(object, method, handler, true)
    return
  end

  local original = object[method]
  local updating = false
  owner:SecureHook(object, method, function (...)
    if updating then return end
    updating = true
    local ok, err = pcall(handler, ...)
    updating = false
    if not ok then error(err, 0) end
  end)
  -- Existing styling callbacks use this reference to apply Sunder's final layout or color.
  owner.hooks[object][method] = original
end

-- Native buffers may expose either wall time or seconds on the client clock.
-- A backfilled entry's new native timestamp describes replay, not receipt.
local function readable(value)
  return not canaccessvalue or canaccessvalue(value)
end

function Utils.getMessageReceipt(entry)
  if not readable(entry) or not entry or entry.sunderUndated then return end
  local stamp=entry.serverTime
  if readable(stamp) and type(stamp)=="number" and stamp>0 then return stamp end
  stamp=entry.timestamp
  if readable(stamp) and type(stamp)=="number" and stamp>=0 then
    local age=GetTime()-stamp
    if age>=0 then return GetServerTime()-math.floor(age) end
  end
end

-- Keep the receipt alongside the native position even on clients without a readable historyBuffer.
local frameReceipts=setmetatable({}, {__mode="k"})
function Utils.clearFrameReceipts(frame)
  frameReceipts[frame]=nil
end
function Utils.trackReceipt(frame, value, receipt, oldest, person)
  local count=frame:GetNumMessages()
  if count<1 then return end
  local state=frameReceipts[frame]
  if not state then state={head=0,first=1,lines={}};frameReceipts[frame]=state end
  if not oldest then state.head=state.head+1 end
  local index=oldest and state.head-count+1 or state.head
  state.lines[index]=readable(value) and type(value)=="string" and {value,receipt,person} or nil
  if oldest then state.first=math.min(state.first,index) end
  local first=state.head-count+1
  while state.first<first do state.lines[state.first]=nil;state.first=state.first+1 end
end
function Utils.frameReceipt(frame,index,count,value)
  local state=frameReceipts[frame]
  local item=state and state.lines[state.head-count+index]
  if item and readable(value) and item[1]==value then return item[2] end
  local buffer=frame.historyBuffer
  return Utils.getMessageReceipt(buffer and buffer:GetEntryAtIndex(count-index+1))
end

function Utils.framePerson(frame,index,count,value)
  local state=frameReceipts[frame]
  local item=state and state.lines[state.head-count+index]
  if item and readable(value) and item[1]==value then return item[3] end
end

function Utils.restoreChatLine(frame,line)
  local buffer=frame.historyBuffer
  local before=frame:GetNumMessages()
  local previous=buffer and before>0 and buffer:GetEntryAtIndex(before)
  local window=Core:GetModule("UIManager"):GetChatWindow(frame)
  local smf=window and window.slidingMessageFrame
  local pending=smf and smf.state.incomingScrollbackMessages
  local count=pending and #pending
  frame:BackFillMessage(line[1],line[2],line[3],line[4],line.typeID)
  local receipt=type(line.receivedAt)=="number" and line.receivedAt>0 and line.receivedAt or nil
  local after=frame:GetNumMessages()
  local entry=buffer and after>0 and buffer:GetEntryAtIndex(after)
  if readable(entry) and entry and entry~=previous then
    entry.serverTime=receipt
    entry.sunderUndated=not receipt or nil
  end
  if after>before or entry and entry~=previous then Utils.trackReceipt(frame,line[1],receipt,true,{sender=line.sender,classFile=line.classFile}) end
  if pending and #pending>count then
    pending[#pending].receivedAt=receipt
    pending[#pending].sender,pending[#pending].classFile=line.sender,line.classFile
  end
end

-- A reminder is advisory and appears at most once per store per login.
local warned={}
local reviewOffered=false
function Utils.warnHistorySize(bytes,store,help)
  if bytes<4*1024*1024 or warned[store] or not DEFAULT_CHAT_FRAME then return end
  warned[store]=true
  DEFAULT_CHAT_FRAME:AddMessage("Sunder: "..store.." history is about 4 MiB or larger. "..help.." Recording continues.")
  if reviewOffered or not StaticPopup_Show or not StaticPopupDialogs then return end
  reviewOffered=true
  local function offerReview()
    StaticPopupDialogs.SUNDER_HISTORY_SIZE={
      text="%s history is about 4 MiB or larger. Review it now or keep recording?",
      button1="Review history",button2="Keep recording",timeout=0,whileDead=true,hideOnEscape=true,
      OnAccept=function()
        if store=="Group" then Core:GetModule("Config"):OpenSettings("party")
        elseif store=="Whispers" then Core:GetModule("Config"):OpenSettings("whispers")
        else Core.Components.ConversationLog:Open() end
      end,
    }
    StaticPopup_Show("SUNDER_HISTORY_SIZE",store)
  end
  if InCombatLockdown and InCombatLockdown() then
    local wait=CreateFrame("Frame")
    wait:RegisterEvent("PLAYER_REGEN_ENABLED")
    wait:SetScript("OnEvent",function(frame)
      frame:UnregisterAllEvents()
      frame:SetScript("OnEvent",nil)
      offerReview()
    end)
  else offerReview() end
end

-- Extend a durable transcript with a chronologically ordered native window.
-- Only compare its tail. Identical text at different receipt times remains distinct.
function Utils.appendHistoryTail(lines,recent)
  local overlap=math.min(#lines,#recent)
  while overlap>0 do
    local matches=true
    for i=1,overlap do
      local a,b=lines[#lines-overlap+i],recent[i]
      if a[1]~=b[1] or a.typeID~=b.typeID or a.receivedAt~=b.receivedAt then matches=false;break end
    end
    if matches then break end
    overlap=overlap-1
  end
  local bytes=0
  for i=overlap+1,#recent do
    lines[#lines+1]=recent[i]
    bytes=bytes+#recent[i][1]+64
  end
  return bytes
end

-- Utility functions
Utils.super = function (obj)
  return getmetatable(obj).__index
end

---
-- Print to VDT
Utils.print = function (str, t)
  if _G.ViragDevTool_AddData then
    _G.ViragDevTool_AddData(t, str)
  else
    -- Buffer print messages until ViragDevTool loads
    table.insert(Core.printBuffer, {str, t})
  end
end

---
-- Prints Sunder' notification messages
Utils.notify = function (message)
  print("|c00DFBA69Sunder|r: ", message)
end

local function parseVersion(version)
  if type(version) ~= "string" then
    return nil
  end

  local major, minor, patch, suffix = version:match("^(%d+)%.(%d+)%.(%d+)(.*)$")
  if major == nil or (suffix ~= "" and suffix:sub(1, 1) ~= "-") then
    return nil
  end

  return {
    tonumber(major),
    tonumber(minor),
    tonumber(patch),
    prerelease = suffix ~= ""
  }
end

---
-- Returns true if version is newer
Utils.versionGreaterThan = function (current, previous)
  local cur = parseVersion(current)
  local prev = parseVersion(previous)

  if cur == nil or prev == nil then
    return tostring(current) ~= tostring(previous)
  end

  for index = 1, 3 do
    if cur[index] ~= prev[index] then
      return cur[index] > prev[index]
    end
  end

  -- A stable release is newer than a prerelease with the same numbers.
  return prev.prerelease and not cur.prerelease
end
