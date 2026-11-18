exec(open('work/test_whisper_history.py',encoding='utf-8').read())
lua.execute("""
Core.db.profile.keepWhisperTabs=true;cfg.enabled=true;cfg.mode="hub"
CHAT_FRAMES={};W.records={};Core.db.char.whisperArchive=nil
History.pendingHistory=nil;History.restoreArchive=nil;History.loggingOut=nil;History.liveSnapshot=nil
local frame=conversation("ArchiveRace","Archive-Realm")
frame.history={}
function frame:GetNumMessages() return #self.history end
function frame:GetMessageInfo(i) local e=self.history[i];return e.message,1,1,1,e.typeID end
frame.historyBuffer={GetEntryAtIndex=function(_,i)return frame.history[#frame.history-i+1] end}
function frame:BackFillMessage(text,r,g,b,typeID) table.insert(self.history,1,{message=text,typeID=typeID}) end
CHAT_FRAMES={frame:GetName()};W:Record(frame)
local checkpoint={{kind="WHISPER",target="Archive-Realm",lines={{"saved before reload",1,1,1,receivedAt=100}}}}
Core.db.char.whisperTabs=checkpoint
getmetatable(UIParent).__index.RegisterEvent=function(self,event) self.events=self.events or {};self.events[event]=true end
History:OnEnable();History:Save()
assert(Core.db.char.whisperTabs==checkpoint,"early save erased startup history")
drain()
assert(frame.history[1].message=="saved before reload" and frame.history[1].serverTime==100)
History:Save()
local key=History:ArchiveKey(frame)
assert(Core.db.char.whisperArchive[key].lines[1][1]=="saved before reload")
-- Capture before native close releases/clears the frame.
History:BeforeClose(frame);FCF_Close(frame);frame.history={};History:Save()
assert(Core.db.char.whisperArchive[key].closed and #Core.db.char.whisperArchive[key].lines==1)
frame.inUse=true;W:OnWindowOpened(frame);drain()
assert(frame.history[1].message=="saved before reload","archive did not restore on reopen")
History:OnConversationOpened(frame);drain();assert(#frame.history==1,"archive replay duplicated")
-- Preserve messages older than the small open-tab restore checkpoint.
frame.history={}
for i=1,80 do frame.history[i]={message="line "..i,serverTime=100+i} end
cfg.historyLines=20;cfg.archiveLines=100
History:ScheduleSave(frame);History:Save()
assert(#Core.db.char.whisperTabs[1].lines==20)
assert(#Core.db.char.whisperArchive[key].lines==81,"archive incorrectly used open-tab line cap")
History:Save();assert(#Core.db.char.whisperArchive[key].lines==81,"unchanged save duplicated lines")
frame.history[#frame.history+1]={message="line 80",serverTime=181}
History:ScheduleSave(frame);History:Save();assert(#Core.db.char.whisperArchive[key].lines==82,"repeated genuine message collapsed")
-- Separate confirmed deletion cannot be resurrected by a later checkpoint.
StaticPopupDialogs={};StaticPopup_Show=function(_,_,_,data) popupData=data end
History:RequestDelete(key);assert(Core.db.char.whisperArchive[key],"delete ran before confirmation")
StaticPopupDialogs.SUNDER_DELETE_HISTORY.OnAccept(nil,popupData)
History:Save();assert(not Core.db.char.whisperArchive[key],"deleted archive resurrected")
-- Former count and byte limits must never evict saved people or messages.
Core.db.char.whisperArchive={};cfg.archiveConversations=5;cfg.archiveLines=20
local tabs={}
for n=1,6 do
 local lines={};for i=1,25 do lines[i]={"person "..n.." line "..i,1,1,1} end
 tabs[n]={kind="WHISPER",target="Budget"..n,lines=lines,favorite=n==1}
end
History:UpdateArchive(tabs)
local count=0;for _,entry in pairs(Core.db.char.whisperArchive) do count=count+1;assert(#entry.lines==25) end
assert(count==6 and Core.db.char.whisperArchive["WHISPER:budget1"] and not Core.db.char.whisperArchiveTrimmed)
History:UpdateArchive({{kind="WHISPER",target="Oversized",lines={{string.rep("x",8*1024*1024+1),1,1,1}}}})
assert(History.archiveBytes>8*1024*1024 and Core.db.char.whisperArchive["WHISPER:oversized"],"large archive was silently deleted")
""")
print('Durable archive passed: startup race, close/reopen, replay idempotence, separate checkpoint/archive limits, repeated messages, confirmed deletion and retention beyond former size limits.')

# Exercise the actual archive search/copy adapter without native chat windows.
lua.execute("""
local oldGet=Core.GetModule
copyModule={};widgets={}
local methods={}
function methods:SetText(text)self.text=text end
function methods:GetText()return self.text end
function methods:SetLabel(text)self.label=text end
function methods:SetTitle(text)self.title=text end
function methods:SetCallback(event,callback)self[event]=callback end
local noop=function()end
Core.Libs.AceGUI={Create=function(_,kind)
 local widget=setmetatable({}, {__index=function(_,key)return methods[key] or noop end})
 widgets[#widgets+1]=widget;return widget end}
function Core:Localize(text)return text end
function Core:GetModule(name,...)
 if name=="ChatCopy" then return copyModule end
 if name=="TextProcessing" then return {IsMessageBlacklisted=function()return false end} end
 if name=="Ellesmere" then return {SkinWindow=function()end} end
 return oldGet(self,name,...)
end
""")
lua.execute(root.joinpath('Modules/ChatCopy.lua').read_text(encoding='utf-8'),'Sunder',lua.globals().vars)
lua.execute("""
local lines={};for i=1,500 do lines[i]={"history line "..i,1,1,1} end
copyModule:ShowArchive({target="Read-only archive",lines=lines})
assert(widgets[6].text:find("history line 500",1,true))
assert(not widgets[6].text:find("history line 1|",1,true))
widgets[2]:SetText("history line 1");widgets[2].OnTextChanged()
assert(widgets[6].text:find("history line 1|",1,true),"older archived messages are not searchable")
assert(#widgets[6].text<=60000)
""")
print('Archive search passed: bounded recent browse and access to older saved lines without creating native recipients.')

# Browse all chronological pages, including the short oldest page.
lua.execute("""
local db={lines={}}
for i=1,104 do db.lines[i]={"journal "..i,receivedAt=1000+i} end
local start=#widgets
copyModule:ShowLog(db,function() clearRequested=true end)
local older,newer,clear,view=widgets[start+2],widgets[start+3],widgets[start+4],widgets[start+5]
assert(view.text:find("journal 104",1,true))
older.OnClick();assert(view.text:find("journal 5",1,true))
older.OnClick();assert(view.text:find("journal 1",1,true) and not view.text:find("journal 5",1,true))
newer.OnClick();assert(view.text:find("journal 54",1,true))
clear.OnClick();assert(clearRequested and #db.lines==104)
""")

# Invoke the production close wrapper: capture must precede native data release.
ui_source=root.joinpath('Modules/UIManager.lua').read_text(encoding='utf-8')
close_hook=ui_source[ui_source.index('  -- Close window'):ui_source.index('\n  local function hookLayoutChange')]
lua.execute("""
closeManager={hooks={},ReleaseChatWindow=function()released=true end}
function closeManager:RawHook(_,callback) closeCallback=callback end
local frame=conversation("CloseOrderFrame","CloseOrder-Realm")
frame.history={{message="kept before native release"}}
function frame:GetNumMessages()return #self.history end
function frame:GetMessageInfo(i)return self.history[i].message,1,1,1 end
W:Record(frame);closeOrderFrame=frame
closeManager.hooks.FCF_Close=function(f)
 local saved=Core.db.char.whisperArchive[History:ArchiveKey(f)]
 assert(saved and saved.closed and saved.lines[1][1]=="kept before native release")
 nativeClosed=true;f.inUse=false;f.history={}
end
""")
lua.execute('local self=closeManager\n'+close_hook)
lua.execute("""
closeCallback(closeOrderFrame);assert(nativeClosed and released)
local original=History.BeforeClose;History.BeforeClose=function()error("synthetic capture failure")end
nativeClosed=false;released=false;closeOrderFrame.inUse=true
closeCallback(closeOrderFrame)
assert(not nativeClosed and not released and Core.db.char.whisperHistoryError)
History.BeforeClose=original
-- Cancel an old replay before reusing the same native frame for the same peer.
drain();Core.db.char.whisperArchive={};History.loadedArchiveFrames={};History.loadingArchive={}
local frame=closeOrderFrame;frame.chatTarget="ReplayReuse-Realm";frame.history={}
function frame:BackFillMessage(text,r,g,b,typeID)table.insert(self.history,1,{message=text}) end
local lines={};for i=1,40 do lines[i]={"replay "..i,1,1,1} end
local key=History:ArchiveKey(frame)
Core.db.char.whisperArchive[key]={kind="WHISPER",target=frame.chatTarget,lines=lines,closed=true}
History:OnConversationOpened(frame);assert(#frame.history==12)
History:BeforeClose(frame);frame.history={};frame.inUse=true
History:OnConversationOpened(frame);drain()
assert(#frame.history==20,"stale replay duplicated history after same-peer frame reuse")
""")
print('Native close/replay lifecycle passed: pre-release capture, failed capture keeps pane open, and same-peer frame reuse cancels stale replay.')

# Two isolated Lua sessions share only serialized SavedVariables from the first session.
from lupa.lua51 import LuaRuntime
def journal_session():
    vm=LuaRuntime(unpack_returned_tuples=True)
    vm.execute("""
        Copy={}; Core={Components={},db={char={},profile={keepWhisperTabs=true,guildChat={remember=true},partyChat={remember=true}}}}
        function Core:GetModule() return Copy end
        vars={Core,{},{}}
        function GetRealmName() return "Realm" end
        clock=1700000000
        function GetServerTime() return clock end
        function CreateFrame() return {registered={},RegisterEvent=function(s,e)s.registered[e]=true end,
          SetScript=function(s,k,v)s[k]=v end} end
        StaticPopupDialogs={};popups=0
        function StaticPopup_Show(key) popups=popups+1;lastPopup=key end
        DEFAULT_CHAT_FRAME={AddMessage=function() end}
        function Copy:ShowLog(db,clear) rendered=db;requestClear=clear end
    """)
    for name in ('utils.lua','Modules/ConversationLog.lua'):
        vm.execute(root.joinpath(name).read_text(encoding='utf-8'),'Sunder',vm.globals().vars)
    return vm
vm=journal_session()
vm.execute("""
Core.db.char.guildRoomHistory={lines={{"legacy undated"}}}
Copy:OnEnable();log=Core.Components.ConversationLog;local f=log.events
assert(f.registered.CHAT_MSG_CHANNEL and not f.registered.COMBAT_LOG_EVENT_UNFILTERED)
local function emit(event,...) f:OnEvent(event,...) end
emit("CHAT_MSG_CHANNEL","repeat","Speaker",nil,"Trade")
clock=clock+86400
emit("CHAT_MSG_CHANNEL","repeat","Speaker",nil,"Trade")
emit("CHAT_MSG_WHISPER_INFORM","outgoing","Friend")
emit("CHAT_MSG_GUILD","guild","Speaker")
emit("CHAT_MSG_RAID_LEADER","raid","Speaker")
emit("COMBAT_LOG_EVENT_UNFILTERED","attack","Creature")
emit("CHAT_MSG_CHANNEL","|Ktoken|k","Speaker")
Core.db.profile.guildChat.remember=false
emit("CHAT_MSG_GUILD","private opt-out","Speaker")
local db=SunderConversationLog
assert(#db.lines==6 and db.lines[1].receivedAt==nil and db.lines[3].receivedAt-db.lines[2].receivedAt==86400)
log:ForgetPeer("WHISPER:friend-realm");assert(#db.lines==5)
db.bytes=4*1024*1024
emit("CHAT_MSG_SAY","still recording","Speaker");emit("CHAT_MSG_YELL","again","Speaker")
assert(#db.lines==7 and popups==1 and lastPopup=="SUNDER_HISTORY_SIZE")
-- Produce the plain table literal WoW can restore. No runtime globals survive.
function serialize(value)
 if type(value)=="string" then return string.format("%q",value) end
 if type(value)~="table" then return tostring(value) end
 local fields={}
 for k,v in pairs(value) do fields[#fields+1]="["..serialize(k).."]="..serialize(v) end
 return "{"..table.concat(fields,",").."}"
end
""")
saved=vm.eval('serialize(SunderConversationLog)')
vm=journal_session()
vm.execute('SunderConversationLog='+saved)
vm.execute("""
Copy:OnEnable();local log=Core.Components.ConversationLog
log:Open();assert(#rendered.lines==7 and rendered.lines[2].receivedAt==1700000000 and rendered.lines[3].receivedAt==1700086400)
requestClear();assert(#rendered.lines==7)
StaticPopupDialogs.SUNDER_CLEAR_CONVERSATION_LOG.OnAccept();assert(#rendered.lines==0 and rendered.bytes==0)
log:Record("CHAT_MSG_SAY","after clearing","Speaker");assert(#rendered.lines==1)
-- Two identical native lines without any readable native history buffer.
local u=vars[3];local f={count=1,GetNumMessages=function(s)return s.count end}
u.trackReceipt(f,"repeat",100);f.count=2;u.trackReceipt(f,"repeat",200)
assert(u.frameReceipt(f,1,2,"repeat")==100 and u.frameReceipt(f,2,2,"repeat")==200)
f.count=3;u.trackReceipt(f,"undated",nil,true)
assert(not u.frameReceipt(f,1,3,"undated") and u.frameReceipt(f,2,3,"repeat")==100)
u.clearFrameReceipts(f);assert(not u.frameReceipt(f,2,3,"repeat"))
""")
print('Conversation log passed independent-session restore, date rollover, legacy unknown date, native receipt tracking, combat exclusion, recording preferences, soft warning, scoped deletion and confirmed clearing.')

# Global search yields between batches and cancels stale queries without altering saves.
lua.execute("""
local oldCombat=ChatFrame2;ChatFrame2=nil
local oldChar=Core.db.char;local oldLog=SunderConversationLog;local oldAfter=C_Timer.After
local queue={};C_Timer.After=function(_,fn)queue[#queue+1]=fn end
Core.db.char={whisperArchive={a={target="Fixture friend",lines={{"needle private",receivedAt=100}}}},partyRoomArchive={{lines={{"needle group",receivedAt=200}}}}}
SunderConversationLog={lines={}}
for i=1,450 do SunderConversationLog.lines[i]={"needle public "..i,receivedAt=300+i} end
local stale=false;local result,count
copyModule:SearchSaved("discarded",1,function()stale=true end)
copyModule:SearchSaved("needle",2,function(lines,n)result,count=lines,n end)
assert(result==nil,"global search blocked the input callback")
while #queue>0 do local fn=table.remove(queue,1);fn()end
assert(not stale and count==452 and #result==200,"global scope, pagination or cancellation failed")
copyModule:SearchSaved("private",1,function(lines,n)result,count=lines,n end)
while #queue>0 do local fn=table.remove(queue,1);fn()end
assert(count==1 and result[1]:find("Fixture friend",1,true) and result[1]:find(date("%Y-%m-%d %H:%M",100),1,true),"result lost conversation/date context")
assert(#SunderConversationLog.lines==450 and Core.db.char.whisperArchive.a.lines[1][1]=="needle private","search mutated saved history")
Core.db.char=oldChar;SunderConversationLog=oldLog;ChatFrame2=oldCombat;C_Timer.After=oldAfter
""")
