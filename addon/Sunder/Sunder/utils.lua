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
  if pending and #pending>count then pending[#pending].receivedAt=receipt end
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
