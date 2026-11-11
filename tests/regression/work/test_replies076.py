exec(open('work/test_history075.py',encoding='utf-8').read())
source=root.joinpath('Modules/TextProcessing.lua').read_text(encoding='utf-8')
style=source[source.index('function TP:WhisperReplyStyle'):source.index('function TP:ProcessText(')]
lua.execute('TP={};canaccessvalue=_G.canaccessvalue;ChatTypeInfo.WHISPER_INFORM={id=80};ChatTypeInfo.BN_WHISPER_INFORM={id=81}')
lua.execute(style)
lua.execute('''
cfg.enabled=true;cfg.distinguishReplies=true;cfg.replyColor={.70,.73,.78}
local f={chatType="WHISPER"}
local r,g,b=TP:WhisperReplyStyle(f,80)
assert(r==.70 and g==.73 and b==.78)
assert(TP:WhisperReplyStyle(f,ChatTypeInfo.WHISPER.id)==nil)
f.chatType="BN_WHISPER";assert(TP:WhisperReplyStyle(f,81)==.70)
assert(TP:WhisperReplyStyle(f,secret)==nil)
f.chatType="SAY";assert(TP:WhisperReplyStyle(f,80)==nil)
f.chatType="WHISPER";cfg.distinguishReplies=false;assert(TP:WhisperReplyStyle(f,80)==nil)
cfg.distinguishReplies=true;cfg.replyColor={.5,.6,.7};assert(TP:WhisperReplyStyle(f,80)==.5)
-- Native metadata must survive history save/restore, including Battle.net replies.
local f=BNHistory
function f:GetMessageInfo(i) return self.history[i].message,0,1,1,81 end
local restoredType
function f:BackFillMessage(text,r,g,b,typeID) restoredType=typeID;table.insert(self.history,{message=text}) end
History:Save();assert(Core.db.char.whisperTabs[1].lines[1].typeID==81)
f.history={};History:Restore();drain();assert(restoredType==81)
''')
print('Reply styling checks passed: character/Battle.net direction, incoming and ordinary chat unchanged, restricted IDs, custom color, opt-out, history metadata.')

