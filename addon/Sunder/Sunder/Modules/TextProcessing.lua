local _G = _G
local canaccessvalue = _G.canaccessvalue

local Core = unpack(select(2, ...))
local TP = Core:GetModule("TextProcessing")

local EMOTE_PATH = "Interface\\AddOns\\Sunder\\Sunder\\Assets\\Emotes\\"
-- Faces render slightly taller than the message text.
local EMOTE_SCALE = 1.15

-- Smileys typed as their own word. A typed "|" arrives doubled because it starts WoW's text codes.
local SMILEYS = {
  [":)"] = "smile", [":-)"] = "smile",
  [":("] = "sad", [":-("] = "sad",
  [":D"] = "grin", [":-D"] = "grin",
  [";)"] = "wink", [";-)"] = "wink",
  [":P"] = "tongue", [":p"] = "tongue", [":-P"] = "tongue", [":-p"] = "tongue",
  [":O"] = "wow", [":o"] = "wow", [":-O"] = "wow", [":-o"] = "wow",
  [":||"] = "neutral", [":-||"] = "neutral",
  [":/"] = "meh", [":-/"] = "meh",
  ["xD"] = "laugh", ["XD"] = "laugh",
  ["<3"] = "heart",
  ["</3"] = "brokenheart",
  ["D:"] = "horror",
  [":S"] = "confused", [":s"] = "confused", [":-S"] = "confused", [":-s"] = "confused",
  [":*"] = "kiss", [":-*"] = "kiss",
  ["B)"] = "cool", ["B-)"] = "cool",
  [":'("] = "cry",
  [">:("] = "angry", [">:-("] = "angry",
  ["^^"] = "joy", ["^_^"] = "joy",
  ["-_-"] = "unamused",
  ["o.O"] = "wtf", ["O.o"] = "wtf",
  [":3"] = "cat",
  ["T_T"] = "sob",
  [":$"] = "blush",
}

-- Shortcodes such as :smile:, including the common names earlier versions accepted.
local SHORTCODES = {
  angry = "angry", blush = "blush", brokenheart = "brokenheart", broken_heart = "brokenheart", cat = "cat",
  confused = "confused", cool = "cool", sunglasses = "cool", cry = "cry", grin = "grin", heart = "heart",
  horror = "horror", scream = "horror", joy = "joy", kiss = "kiss", laugh = "laugh", meh = "meh",
  neutral = "neutral", rage = "angry", sad = "sad", slight_frown = "sad", smile = "smile", slight_smile = "smile",
  sob = "sob", tongue = "tongue", stuck_out_tongue = "tongue", stuck_out_tongue_closed_eyes = "tongue",
  unamused = "unamused", wink = "wink", wow = "wow", open_mouth = "wow", wtf = "wtf",
}

-- WoW provides these globals at runtime, so suppress Luacheck's undefined-global warning while localizing them.
-- luacheck: push ignore 113
local strjoin = strjoin
local strsplit = strsplit
local strfind = strfind
local strlen = strlen
local strsub = strsub
local date = date
-- luacheck: pop

---
--Takes a texture escape string and adjusts its yOffset
local function adjustTextureYOffset(texture)
  -- Texture has 14 parts
  -- path, height, width, offsetX, offsetY,
  -- texWidth, texHeight
  -- leftTex, topTex, rightTex, bottomText,
  -- rColor, gColor, bColor

  -- Strip escape characters
  -- Split into parts
  local parts = {strsplit(':', strsub(texture, 3, -3))}
  local yOffset = Core.db.profile.iconTextureYOffset

  if #parts < 5 then
    -- Pad out ommitted attributes
    for i=1, 5 do
      if parts[i] == nil then
        if i == 3 then
          -- If width is not specified, the width should equal the height
          parts[i] = parts[2]
        else
          parts[i] = '0'
        end
      end
    end
  end

  -- Adjust yOffset by configured amount
  parts[5] = tostring((tonumber(parts[5]) or 0) - yOffset)

  -- Rejoin string and readd escape codes
  return '|T'..strjoin(':', unpack(parts))..'|t'
end


---
-- Gets all inline textures found in the string and adjusts their yOffset
local function textureProcessor(text)
  local cursor = 1
  local origLen = strlen(text)

  local parts = {}

  while cursor <= origLen do
    local mStart, mEnd = strfind(text, '%|T.-%|t', cursor)

    if mStart then
      table.insert(parts, strsub(text, cursor, mStart - 1))
      table.insert(parts, adjustTextureYOffset(strsub(text, mStart, mEnd)))
      cursor = mEnd + 1
    else
      -- No more matches
      table.insert(parts, strsub(text, cursor, origLen))
      cursor = origLen + 1
    end
  end

  return strjoin("", unpack(parts))
end

local emoteMarkupCache = {}

local function toByte(value)
  return math.floor(math.max(0, math.min(1, value)) * 255 + 0.5)
end

-- The Sunder set is drawn in white and tinted gold, or EllesmereUI's accent; the Classic set keeps its own colors.
local function getEmoteMarkup(name)
  local profile = Core.db.profile
  local style = profile.emoteStyle == "classic" and "classic" or "glass"
  local size = math.floor((tonumber(profile.messageFontSize) or 13) * EMOTE_SCALE + 0.5)
  local tint = ""
  if style == "glass" then
    local accent = Core:GetModule("Ellesmere"):GetActiveAccent()
    tint = accent and (":"..toByte(accent.r)..":"..toByte(accent.g)..":"..toByte(accent.b)) or ":223:186:105"
  end
  local key = style..name..size..tint
  if not emoteMarkupCache[key] then
    emoteMarkupCache[key] = "|T"..EMOTE_PATH..style.."_"..name..":"..size..":"..size..":0:0:32:32:0:32:0:32"..tint.."|t"
  end
  return emoteMarkupCache[key]
end

local function emoteWord(word)
  local name = SMILEYS[word]
  if name then return getEmoteMarkup(name) end
  -- Smileys that end a sentence, such as ":)." or "<3!!"
  local smiley, trail = word:match("^(.-)([%.,!%?]+)$")
  name = smiley and SMILEYS[smiley]
  if name then return getEmoteMarkup(name)..trail end
end

local function emoteSegment(segment)
  segment = segment:gsub(":([%l_]+):", function (shortcode)
    local name = SHORTCODES[shortcode]
    return name and getEmoteMarkup(name)
  end)
  return (segment:gsub("%S+", emoteWord))
end

-- Links, textures, atlases, and protected names keep their escape sequences untouched.
local PROTECTED_SEQUENCES = {"|H.-|h.-|h", "|T.-|t", "|A.-|a", "|K.-|k"}

local function findProtectedSequence(text, cursor)
  local firstStart, firstEnd
  for _, pattern in ipairs(PROTECTED_SEQUENCES) do
    local sequenceStart, sequenceEnd = strfind(text, pattern, cursor)
    if sequenceStart and (firstStart == nil or sequenceStart < firstStart) then
      firstStart, firstEnd = sequenceStart, sequenceEnd
    end
  end
  return firstStart, firstEnd
end

local function emojiProcessor(text)
  local parts = {}
  local cursor = 1
  while true do
    local sequenceStart, sequenceEnd = findProtectedSequence(text, cursor)
    if not sequenceStart then
      parts[#parts + 1] = emoteSegment(strsub(text, cursor))
      break
    end
    parts[#parts + 1] = emoteSegment(strsub(text, cursor, sequenceStart - 1))
    parts[#parts + 1] = strsub(text, sequenceStart, sequenceEnd)
    cursor = sequenceEnd + 1
  end
  return table.concat(parts)
end

local cachedTimestampRed
local cachedTimestampGreen
local cachedTimestampBlue
local cachedTimestampHex
local cachedBlacklistSource
local cachedBlacklistPhrases = {}

local function normalizeBlacklistText(text)
  text = text:gsub("|K.-|k", "")
  text = text:gsub("|H.-|h(.-)|h", "%1")
  text = text:gsub("|A.-|a", " ")
  text = text:gsub("|T.-|t", " ")
  text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
  text = text:gsub("|r", "")
  text = text:gsub("||", "|")
  return text:lower():gsub("%s+", " "):match("^%s*(.-)%s*$")
end

local function getBlacklistPhrases()
  local source = Core.db.profile.messageBlacklist or ""
  if source == cachedBlacklistSource then
    return cachedBlacklistPhrases
  end

  cachedBlacklistSource = source
  cachedBlacklistPhrases = {}
  for line in source:gmatch("[^\r\n]+") do
    local phrase = normalizeBlacklistText(line)
    if phrase ~= "" then
      cachedBlacklistPhrases[#cachedBlacklistPhrases + 1] = phrase
    end
  end
  return cachedBlacklistPhrases
end

local function getTimestampColorHex(color)
  if (
    cachedTimestampHex and
    cachedTimestampRed == color.r and
    cachedTimestampGreen == color.g and
    cachedTimestampBlue == color.b
  ) then
    return cachedTimestampHex
  end

  local red = math.floor(math.max(0, math.min(1, color.r or 1)) * 255 + 0.5)
  local green = math.floor(math.max(0, math.min(1, color.g or 1)) * 255 + 0.5)
  local blue = math.floor(math.max(0, math.min(1, color.b or 1)) * 255 + 0.5)
  cachedTimestampRed = color.r
  cachedTimestampGreen = color.g
  cachedTimestampBlue = color.b
  cachedTimestampHex = string.format("%02x%02x%02x", red, green, blue)
  return cachedTimestampHex
end

local function timestampProcessor(text, frame, receivedAt)
  if type(text)~="string" or type(receivedAt)~="number" or receivedAt<=0 then return text end
  local profile=Core.db.profile
  if profile.timestampAllWindows==true and not profile.timestampsEnabled then return text end
  local whisper=profile.whispers
  local all=profile.timestampsEnabled and profile.timestampAllWindows==true
  local isWhisper=whisper and whisper.enabled and frame and (frame.chatType=="WHISPER" or frame.chatType=="BN_WHISPER")
  local whisperOnly=isWhisper and not all
  if whisperOnly and not whisper.timestamps then return text end
  if not whisperOnly then
    local frameName=frame and frame.GetName and frame:GetName()
    if not profile.timestampsEnabled or not all and (not frameName or not profile.timestampFrames or not profile.timestampFrames[frameName])then return text end
  end
  -- Strip only the recognized native prefix, never arbitrary message content.
  local util=_G.ChatFrameUtil
  local nativeFormat=util and util.GetTimestampFormat and util.GetTimestampFormat()
  if nativeFormat then
    local formatDate=_G.TimeUtil and _G.TimeUtil.BetterDate or date
    local prefix=formatDate(nativeFormat,receivedAt)
    if text:sub(1,#prefix)==prefix then text=text:sub(#prefix+1)end
  end
  local format=whisperOnly and whisper.timestampFormat or profile.timestampFormat
  local stamp=date(format,receivedAt)
  if whisperOnly then return "|cff999999"..stamp.."|r "..text end
  -- The all-window option is deliberately subdued even without a color override.
  if not profile.timestampColorEnabled then return (all and "|cff999999"..stamp.."|r" or stamp).." "..text end
  return "|cff"..getTimestampColorHex(profile.timestampColor)..stamp.."|r "..text
end

local function processSafely(processor, text, ...)
  local ok, result = pcall(processor, text, ...)
  if ok and type(result) == "string" then
    return result
  end

  return text
end

function TP:ProcessTextures(text)
  if canaccessvalue and not canaccessvalue(text) then return text end
  if type(text) ~= "string" or not strfind(text, "|T", 1, true) then
    return text
  end
  return processSafely(textureProcessor, text)
end

function TP:IsMessageBlacklisted(text)
  if not Core.db.profile.messageBlacklistEnabled then
    return false
  end
  if canaccessvalue and not canaccessvalue(text) then
    return false
  end
  if type(text) ~= "string" or text == "" then
    return false
  end

  local normalized = normalizeBlacklistText(text)
  for _, phrase in ipairs(getBlacklistPhrases()) do
    if normalized:find(phrase, 1, true) then
      return true
    end
  end
  return false
end

-- Sender line IDs come from native chat filters. History may retain a structured
-- sender player-link instead; never infer authorship from message body substrings.
function TP:RememberChatSender(lineID,guid)
  if canaccessvalue and (not canaccessvalue(lineID) or not canaccessvalue(guid))then return end
  if type(lineID)~="number" or lineID<=0 or not UnitGUID then return end
  self.ownLineIDs=self.ownLineIDs or {};self.ownLineOrder=self.ownLineOrder or {}
  if self.ownLineIDs[lineID]==nil then table.insert(self.ownLineOrder,lineID)end
  self.ownLineIDs[lineID]=guid==UnitGUID("player")
  if #self.ownLineOrder>256 then self.ownLineIDs[table.remove(self.ownLineOrder,1)]=nil end
end
function TP:IsOwnChatLine(text,typeID,lineID)
  if canaccessvalue and (not canaccessvalue(text) or not canaccessvalue(typeID) or not canaccessvalue(lineID))then return false end
  if self.ownLineIDs and lineID and self.ownLineIDs[lineID]~=nil then return self.ownLineIDs[lineID]end
  local supported=false
  for _,kind in ipairs({"SAY","YELL","EMOTE","TEXT_EMOTE","GUILD","OFFICER","PARTY","PARTY_LEADER","RAID","RAID_LEADER","RAID_WARNING","INSTANCE_CHAT","INSTANCE_CHAT_LEADER","CHANNEL"})do
    local info=ChatTypeInfo and ChatTypeInfo[kind];if info and info.id==typeID then supported=true;break end
  end
  if not supported or type(text)~="string"then return false end
  local sender=text:match("|Hplayer:([^:|]+)")
  local unitName=_G.UnitNameUnmodified or _G.UnitName
  if not sender or not unitName then return false end
  local name,realm=unitName("player")
  if canaccessvalue and (not canaccessvalue(name) or not canaccessvalue(realm))then return false end
  if type(name)~="string"then return false end
  realm=realm or (GetRealmName and GetRealmName())
  return sender:lower()==name:lower() or type(realm)=="string" and sender:lower()==(name.."-"..realm):lower()
end
function TP:WhisperReplyStyle(frame,typeID,outgoing,text,lineID)
  local cfg=Core.db.profile.whispers
  if not cfg or not cfg.enabled or cfg.distinguishReplies==false or not frame then return end
  if canaccessvalue and not canaccessvalue(typeID)then return end
  local info=_G.ChatTypeInfo
  if not outgoing and info and (frame.chatType=="WHISPER" or frame.chatType=="BN_WHISPER") then
    outgoing=(info.WHISPER_INFORM and typeID==info.WHISPER_INFORM.id) or (info.BN_WHISPER_INFORM and typeID==info.BN_WHISPER_INFORM.id)
  end
  outgoing=outgoing or self:IsOwnChatLine(text,typeID,lineID)
  if not outgoing then return end
  local color=cfg.replyColor or {0.70,0.73,0.78}
  return color[1],color[2],color[3]
end
function TP:OnEnable()
  local util=_G.ChatFrameUtil
  local add=util and util.AddMessageEventFilter or _G.ChatFrame_AddMessageEventFilter
  if not add or self.senderFilter then return end
  self.senderFilter=function(_,_,...)self:RememberChatSender(select(11,...),select(12,...))end
  for _,kind in ipairs({"SAY","YELL","EMOTE","TEXT_EMOTE","GUILD","OFFICER","PARTY","PARTY_LEADER","RAID","RAID_LEADER","RAID_WARNING","INSTANCE_CHAT","INSTANCE_CHAT_LEADER","CHANNEL"})do
    add("CHAT_MSG_"..kind,self.senderFilter)
  end
end

-- Presentation only: native/history text and player/item hyperlink payloads stay intact.
function TP:CompactMessageLabels(text,frame,typeID,own)
  if type(text)~="string" or not frame or canaccessvalue and (not canaccessvalue(text) or not canaccessvalue(typeID))then return text end
  local function escape(value)return (value:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])","%%%1"))end
  local function split(format)
    if type(format)~="string"then return end
    format=format:gsub("%%1%$s","%%s")
    local first,last=format:find("%%s")
    if not first then return end
    local prefix,suffix=format:sub(1,first-1),format:sub(last+1)
    if suffix=="" or suffix:find("%%s")then return end
    local sender,body=text:match("^"..escape(prefix).."(.-)"..escape(suffix).."(.*)$")
    return sender,body,suffix
  end
  local whisper=frame.chatType=="WHISPER" or frame.chatType=="BN_WHISPER"
  if whisper then
    local info=ChatTypeInfo or {}
    local outgoing=own==true or info.WHISPER_INFORM and typeID==info.WHISPER_INFORM.id or info.BN_WHISPER_INFORM and typeID==info.BN_WHISPER_INFORM.id
    local format=outgoing and (_G.CHAT_WHISPER_INFORM_GET or "To %s: ") or (_G.CHAT_WHISPER_GET or "%s whispers: ")
    if frame.chatType=="BN_WHISPER"then format=outgoing and (_G.CHAT_BN_WHISPER_INFORM_GET or format) or (_G.CHAT_BN_WHISPER_GET or format)end
    local sender,body=split(format)
    if not sender then return text end
    if outgoing then return body end
    -- Remove display brackets only; clickable identity and class color survive.
    sender=sender:gsub("|h%[","|h"):gsub("%]|h","|h"):gsub("^%[(.-)%]$","%1")
    return sender..": "..body
  end
  local manager=Core.Components and Core.Components.WindowManager
  local room=manager and manager:GetChatRoom(frame)
  if not room then return text end
  for _,kind in ipairs(room.roomId=="guild" and {"GUILD","OFFICER"} or room.roomId=="party" and {"PARTY","PARTY_LEADER","RAID","RAID_LEADER","RAID_WARNING","INSTANCE_CHAT","INSTANCE_CHAT_LEADER"} or {})do
    local info=ChatTypeInfo and ChatTypeInfo[kind]
    if info and info.id==typeID then
      -- Native/client formatters can wrap or flatten the channel hyperlink,
      -- so the localized format string is not necessarily a literal prefix.
      -- Only edit the header before its first structured sender link.
      local start=text:find("|Hplayer:",1,true) or text:find("|HBNplayer:",1,true)
      if start then
        local header=text:sub(1,start-1)
        local changed=false
        header=header:gsub("|Hchannel:[^|]-|h.-|h",function()changed=true;return ""end)
        local labels={_G["CHAT_MSG_"..kind],_G[kind],({GUILD="Guild",OFFICER="Officer",PARTY="Party",PARTY_LEADER="Party Leader",RAID="Raid",RAID_LEADER="Raid Leader",RAID_WARNING="Raid Warning",INSTANCE_CHAT="Instance",INSTANCE_CHAT_LEADER="Instance Leader"})[kind]}
        for _,label in pairs(labels)do
          if type(label)=="string"then
            local count;header,count=header:gsub("%["..escape(label).."%]","")
            if count>0 then changed=true end
          end
        end
        if changed then return header:gsub("^%s+",""):gsub("%s+$",""):gsub("(|r)%s+","%1")..text:sub(start)end
      end
      -- Retained native lines can be flattened to colored plain text, with
      -- no sender hyperlink at all. Match only the channel at the start.
      for _,label in pairs({_G["CHAT_MSG_"..kind],_G[kind],({GUILD="Guild",OFFICER="Officer",PARTY="Party",PARTY_LEADER="Party Leader",RAID="Raid",RAID_LEADER="Raid Leader",RAID_WARNING="Raid Warning",INSTANCE_CHAT="Instance",INSTANCE_CHAT_LEADER="Instance Leader"})[kind]})do
        if type(label)=="string"then
          local lead,rest=text:match("^(.-)%["..escape(label).."%]%s*(.*)$")
          if lead and lead:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r",""):match("^%s*$")then return lead..rest end
        end
      end
      local sender,body,suffix=split(_G["CHAT_"..kind.."_GET"])
      if sender then return sender..suffix..body end
      return text
    end
  end
  return text
end

function TP:ProcessText(text, frame, receivedAt, typeID, lineID, own)
  -- Retail can supply protected text. Pass it directly to the native FontString without parsing it.
  if canaccessvalue and not canaccessvalue(text) then return text, text end
  local processedText = self:CompactMessageLabels(text,frame,typeID,own)
  if frame and (frame.chatType=="WHISPER" or frame.chatType=="BN_WHISPER") and self:WhisperReplyStyle(frame,typeID,own,text,lineID) and Core.db.profile.whispers.replyMarker then
    processedText="› "..processedText
  end
  if Core.db.profile.timestampsEnabled or Core.db.profile.whispers and Core.db.profile.whispers.enabled then
    processedText = processSafely(timestampProcessor, processedText, frame, receivedAt)
  end
  if Core.db.profile.emojisEnabled then
    processedText = processSafely(emojiProcessor, processedText)
  end
  return self:ProcessTextures(processedText), text
end
