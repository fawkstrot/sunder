local Core, _, Utils = unpack(select(2, ...))
local log = {}
Core.Components.ConversationLog = log

-- Register conversation events once, independent of which native tabs display them.
local types = {
  public = {"SAY","YELL","EMOTE","TEXT_EMOTE","CHANNEL","COMMUNITIES_CHANNEL",
    "BN_CONVERSATION"},
  guild = {"GUILD","OFFICER"},
  group = {"BATTLEGROUND","BATTLEGROUND_LEADER","PARTY","PARTY_LEADER","RAID","RAID_LEADER","RAID_WARNING","INSTANCE_CHAT","INSTANCE_CHAT_LEADER"},
  private = {"WHISPER","WHISPER_INFORM","BN_WHISPER","BN_WHISPER_INFORM","AFK","DND"},
}
local categories = {}
for category, names in pairs(types) do
  for _, name in ipairs(names) do categories["CHAT_MSG_"..name]=category end
end

local function safe(value)
  return (not canaccessvalue or canaccessvalue(value)) and type(value)=="string" and not value:find("|K",1,true)
end
local function store()
  if not SunderConversationLog then SunderConversationLog={lines={},bytes=0} end
  return SunderConversationLog
end
local function size(line)
  return #line[1]+#(line.peer or "")+64
end
local function append(db,text,receipt,peer)
  local line={text,receivedAt=receipt,peer=peer}
  db.lines[#db.lines+1]=line
  db.bytes=db.bytes+size(line)
end
local function warn(db)
  Utils.warnHistorySize(db.bytes,"Conversation log","Use /sunder history to review or clear this character's log.")
end
local function privateKey(kind,name)
  if kind=="WHISPER" and not name:find("-",1,true) and GetRealmName then
    name=name.."-"..GetRealmName():gsub("%s","")
  end
  return kind..":"..name:lower()
end
function log:Record(event,body,sender,_,channel,_,_,_,_,channelName,_,_,guid,bnID)
  local category=categories[event]
  if not category or not safe(body) or body=="" then return end
  local p=Core.db.profile
  if category=="private" and not p.keepWhisperTabs or category=="guild" and not p.guildChat.remember
    or category=="group" and not p.partyChat.remember then return end
  local name=safe(sender) and sender or ""
  local peer
  if category=="private" then
    if event:find("BN_",1,true) then
      local info=(not canaccessvalue or canaccessvalue(bnID)) and type(bnID)=="number" and C_BattleNet and C_BattleNet.GetAccountInfoByID and C_BattleNet.GetAccountInfoByID(bnID)
      if (canaccessvalue and not canaccessvalue(info)) or not info or not safe(info.battleTag) then return end
      name=info.battleTag
      peer=privateKey("BN_WHISPER",name)
    else
      if name=="" then return end
      peer=privateKey("WHISPER",name)
    end
  end
  local label=event:sub(10):lower():gsub("_"," ")
  if event=="CHAT_MSG_CHANNEL" then
    label=safe(channelName) and channelName~="" and channelName or safe(channel) and channel~="" and channel or label
  end
  local db=store()
  local text
  if event=="CHAT_MSG_WHISPER_INFORM" or event=="CHAT_MSG_BN_WHISPER_INFORM" then
    text="[Whisper to "..name.."] "..body
  else
    label=label:gsub("^%l",string.upper)
    text="["..label.."] "..(name~="" and name..": " or "")..body
  end
  append(db,text,GetServerTime(),peer)
  local wm=Core.Components.WindowManager
  local line=db.lines[#db.lines]
  line.sender=name
  local recipient=event=="CHAT_MSG_WHISPER_INFORM" or event=="CHAT_MSG_BN_WHISPER_INFORM"
  line.classFile=wm and wm.RememberSender and wm:RememberSender(name,not recipient and not event:find("BN_",1,true) and guid or nil)
  warn(db)
end
function log:ForgetPeer(key)
  local kind,name
  if key then kind,name=key:match("^([^:]+):(.+)$");if not kind then return end end
  local match=kind and privateKey(kind,name)
  local db=store()
  local write=1
  for _,line in ipairs(db.lines) do
    if line.peer and (not match or line.peer==match) then
      db.bytes=db.bytes-size(line)
    else
      db.lines[write]=line
      write=write+1
    end
  end
  for i=#db.lines,write,-1 do db.lines[i]=nil end
end
local function importLegacy(db,char)
  local imported={}
  local function add(record,label,peer)
    for _,line in ipairs(record and record.lines or {}) do
      if safe(line[1]) then
        local receipt=type(line.receivedAt)=="number" and line.receivedAt>0 and line.receivedAt or nil
        imported[#imported+1]={text="["..label.."] "..line[1],receipt=receipt,peer=peer,order=#imported+1}
      end
    end
  end
  local seen={}
  for key,record in pairs(char.whisperArchive or {}) do
    local name=record.battleTag or record.target
    if safe(name) then add(record,"Whisper",privateKey(record.kind or "WHISPER",name));seen[key]=true end
  end
  for _,record in ipairs(char.whisperTabs or {}) do
    local name=record.battleTag or record.target
    if safe(name) and not seen[(record.kind or "WHISPER")..":"..name:lower()] then
      add(record,"Whisper",privateKey(record.kind or "WHISPER",name))
    end
  end
  add(char.guildRoomHistory,"Guild")
  local current=char.partyRoomHistory
  local found=false
  for _,record in ipairs(char.partyRoomArchive or {}) do
    add(record,"Group")
    if current and record.key==current.key then found=true end
  end
  if not found then add(current,"Group") end
  table.sort(imported,function(a,b)
    if a.receipt==b.receipt then return a.order<b.order end
    return (a.receipt or 0)<(b.receipt or 0)
  end)
  for _,line in ipairs(imported) do append(db,line.text,line.receipt,line.peer) end
  db.imported=true
end
function log:Start()
  local db=store()
  if not db.imported then importLegacy(db,Core.db.char) end
  if not self.events then
    self.events=CreateFrame("Frame")
    for event in pairs(categories) do pcall(self.events.RegisterEvent,self.events,event) end
    self.events:SetScript("OnEvent",function(_,event,...) self:Record(event,...) end)
  end
  warn(db)
end
function log:Open()
  local db=store()
  Core:GetModule("ChatCopy"):ShowLog(db,function()
    StaticPopupDialogs.SUNDER_CLEAR_CONVERSATION_LOG={
      text="Clear this character's conversation log? Whisper and room histories can be managed separately. Recording will continue.",
      button1="Clear log",button2=CANCEL or "Cancel",timeout=0,whileDead=true,hideOnEscape=true,
      OnAccept=function() db.lines={};db.bytes=0;self:Open() end,
    }
    StaticPopup_Show("SUNDER_CLEAR_CONVERSATION_LOG")
  end)
end
local chatCopy=Core:GetModule("ChatCopy")
function chatCopy:OnEnable() log:Start() end
