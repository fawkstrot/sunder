exec(open('work/test_whisper_history.py',encoding='utf-8').read())
lua.execute('''
CHAT_FRAMES={};W.records={};Core.db.profile.keepWhisperTabs=true;cfg.enabled=true;cfg.mode="tabs"
local available=true
local account={battleTag="Friend#1234",accountName="|Kq9|k",bnetAccountID=42}
BNGetNumFriends=function() return available and 1 or 0 end
C_BattleNet={GetFriendAccountInfo=function() return account end,GetAccountInfoByID=function(id) if id==account.bnetAccountID then return account end end}
local f,w=conversation("BNHistory",42,"BN_WHISPER")
CHAT_FRAMES={f:GetName()};f.history={}
function f:GetNumMessages() return #self.history end
function f:GetMessageInfo(i) return self.history[i].message,0,1,1 end
f.historyBuffer={GetEntryAtIndex=function(_,i) return f.history[i] end}
function f:BackFillMessage(text) table.insert(self.history,{message=text}) end
f.history={{message="|HBNplayer:Friend:42|h|Kq9|k|h: Hello",serverTime=1234}}
W:Record(f)
History.pendingHistory=nil;History.restoreArchive=nil
History:Save()
local saved=clone(Core.db.char.whisperTabs)
assert(#saved==1 and saved[1].battleTag=="Friend#1234" and not saved[1].target)
assert(saved[1].lines[1][1]=="Friend#1234: Hello",saved[1].lines[1][1])
available=false;f.inUse=false;f.history={}
History:Restore();drain()
assert(#History.pendingHistory==1,"unavailable roster lost history")
History:Save();assert(#Core.db.char.whisperTabs==1,"pending history lost on reload")
available=true;account.bnetAccountID=99;f.inUse=true;f.chatTarget=99
History:RetryPendingHistory();drain()
assert(#f.history==1 and f.history[1].message=="Friend#1234: Hello","changed session ID did not restore")
assert(#History.pendingHistory==0)
History:Save();assert(Core.db.char.whisperTabs[1].battleTag=="Friend#1234")
local snapshot=Core.db.char.whisperTabs
cfg.enabled=false;History:Restore();assert(Core.db.char.whisperTabs==snapshot,"disabled feature erased history")
cfg.enabled=true
''')
print('Battle.net reload checks passed: stable identity, changed session ID, safe text, delayed roster, pending saves, disabled retention.')
