exec(open('work/test_whispers.py', encoding='utf-8').read())
lua.execute('''
History = {}
local oldGet = Core.GetModule
function Core:GetModule(name,...) if name == "WhisperTabs" then return History end return oldGet(self,name,...) end
Core.db.profile.keepWhisperTabs=true
cfg.enabled=true;cfg.mode="tabs";cfg.historyLines=20;cfg.historyConversations=5
CHAT_FRAMES={};W.records={}
for index=1,7 do
  local frame,window=conversation("HistoryFrame"..index,"Person"..index.."-Realm")
  frame.history={}
  for i=1,25 do frame.history[i]={message="message "..(26-i),serverTime=1000+(26-i)} end
  function frame:GetNumMessages() return #self.history end
  function frame:GetMessageInfo(i) local entry=self.history[#self.history-i+1];return entry.message,1,0.5,1 end
  frame.historyBuffer={GetEntryAtIndex=function(_,i) return frame.history[i] end}
  window.slidingMessageFrame.state.incomingScrollbackMessages={}
  function frame:BackFillMessage(text,r,g,b)
    local entry={message=text,serverTime=9999};table.insert(self.history,entry)
    local pending=window.slidingMessageFrame.state.incomingScrollbackMessages
    pending[#pending+1]={receivedAt=9999}
  end
  CHAT_FRAMES[#CHAT_FRAMES+1]=frame:GetName()
  local rec=W:Record(frame);rec.lastActivity=index
end
local protected,window=conversation("ProtectedHistory",secret,"BN_WHISPER")
CHAT_FRAMES[#CHAT_FRAMES+1]=protected:GetName()
function FCF_OpenTemporaryWindow() error("existing conversations should be reused") end
''')
lua.execute(root.joinpath('Modules/WhisperTabs.lua').read_text(encoding='utf-8'), 'Sunder', lua.globals().vars)
lua.execute('''
History:Save()
local saved=Core.db.char.whisperTabs
savedSnapshot=clone(saved[1])
assert(#saved==5 and saved[1].target=="Person7-Realm", "history conversation cap/recency failed")
assert(#saved[1].lines==20 and saved[1].lines[1][1]=="message 6")
assert(saved[1].lines[1].receivedAt==1006,"original timestamp was lost on save")
for _,tab in ipairs(saved) do
  for _,name in ipairs(CHAT_FRAMES) do
    local frame=_G[name]
    if frame.chatTarget==tab.target then frame.history={} end
  end
end
History:Restore();drain()
assert(Core.db.char.whisperTabs==nil)
assert(HistoryFrame7:GetNumMessages()==20)
assert(HistoryFrame7.history[20].message=="message 6" and HistoryFrame7.history[20].serverTime==1006)
local pending=ui:GetChatWindow(HistoryFrame7).slidingMessageFrame.state.incomingScrollbackMessages
assert(pending[#pending].receivedAt==1006,"restored renderer timestamp incorrect")
Core.db.profile.keepWhisperTabs=false
History:Save();assert(#Core.db.char.whisperTabs==0,"history opt-out ignored")
''')

# Exercise the real timestamp processor with whisper-specific options.
tp=root.joinpath('Modules/TextProcessing.lua').read_text(encoding='utf-8')
processor=tp[tp.index('local function timestampProcessor'):tp.index('local function processSafely')]
lua.execute('''
function date(fmt,time) return fmt..":"..tostring(time) end
function getTimestampColorHex() return "ffffff" end
''')
lua.execute(processor+'\ntimestampTest = timestampProcessor')
lua.execute('''
cfg.timestamps=true;cfg.timestampFormat="[%H:%M]"
local text=timestampTest("hello",HistoryFrame7,1006)
assert(text:find("1006",1,true) and text:find("hello",1,true))
cfg.timestamps=false;assert(timestampTest("hello",HistoryFrame7,1006)=="hello")
cfg.timestamps=true
ChatFrameUtil.GetTimestampFormat=function() return "native" end
local replaced=timestampTest(date("native",1006).."hello",HistoryFrame7,1006)
assert(not replaced:find("native",1,true) and replaced:find("hello",1,true),"native timestamp was doubled")
Core.db.profile.keepWhisperTabs=true
Core.db.char.whisperTabs={savedSnapshot};HistoryFrame7.history={}
History:Restore()
assert(HistoryFrame7:GetNumMessages()==12,"restore work was not bounded per callback")
Core.db.profile.keepWhisperTabs=false;drain()
assert(HistoryFrame7:GetNumMessages()==12,"history restore continued after opt-out")
Core.db.profile.keepWhisperTabs=true
Core.db.char.whisperTabs={savedSnapshot};HistoryFrame7.history={}
History:Restore()
HistoryFrame7.history={};HistoryFrame7.chatTarget="Different-Realm"
drain()
assert(HistoryFrame7:GetNumMessages()==0,"old history leaked into a reused conversation")
''')
print('Whisper history checks passed: per-conversation/total caps, newest-first persistence, original arrival times, renderer restore, opt-out and independent timestamps.')
