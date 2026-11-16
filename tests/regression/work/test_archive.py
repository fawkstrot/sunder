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
-- Storage budgets retain favorites first and report trimming.
Core.db.char.whisperArchive={};cfg.archiveConversations=5;cfg.archiveLines=20
local tabs={}
for n=1,6 do
 local lines={};for i=1,25 do lines[i]={"person "..n.." line "..i,1,1,1} end
 tabs[n]={kind="WHISPER",target="Budget"..n,lines=lines,favorite=n==1}
end
History:UpdateArchive(tabs)
local count=0;for _,entry in pairs(Core.db.char.whisperArchive) do count=count+1;assert(#entry.lines==20) end
assert(count==5 and Core.db.char.whisperArchive["WHISPER:budget1"] and Core.db.char.whisperArchiveTrimmed)
History:UpdateArchive({{kind="WHISPER",target="Oversized",lines={{string.rep("x",8*1024*1024+1),1,1,1}}}})
assert(History.archiveBytes<=8*1024*1024,"archive byte budget exceeded")
""")
print('Durable archive passed: startup race, close/reopen, replay idempotence, separate checkpoint/archive limits, repeated messages, confirmed deletion and favorite-first bounded storage.')

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
assert(widgets[3].text:find("history line 500",1,true))
assert(not widgets[3].text:find("history line 1|",1,true))
widgets[2]:SetText("history line 1");widgets[2].OnTextChanged()
assert(widgets[3].text:find("history line 1|",1,true),"older archived messages are not searchable")
assert(#widgets[3].text<=60000)
""")
print('Archive search passed: bounded recent browse and access to older saved lines without creating native recipients.')

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
