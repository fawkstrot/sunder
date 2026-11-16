exec(open('work/test_history075.py',encoding='utf-8').read())
source=root.joinpath('Modules/TextProcessing.lua').read_text(encoding='utf-8')
style=source[source.index('function TP:RememberChatSender'):source.index('function TP:ProcessText(')]
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


lua.execute("""
ChatTypeInfo.GUILD={id=40};ChatTypeInfo.PARTY={id=41}
local unit=UnitGUID;local name=UnitName
UnitGUID=function()return "my-guid"end;UnitName=function()return "My Player","Forever"end
TP:RememberChatSender(101,"my-guid");TP:RememberChatSender(102,"other-guid")
local frame={chatType="GUILD"}
assert(TP:WhisperReplyStyle(frame,40,nil,"hello",101)==.5)
assert(not TP:WhisperReplyStyle(frame,40,nil,"hello",102))
assert(TP:IsOwnChatLine("|Hplayer:My Player:1|h[My Player]|h: hello",40))
assert(not TP:IsOwnChatLine("|Hplayer:Other Player:1|h[Other]|h: quoted |Hplayer:My Player:1|h[Me]|h",40))
for i=1,300 do TP:RememberChatSender(1000+i,"my-guid")end
assert(#TP.ownLineOrder==256 and TP.ownLineIDs[101]==nil)
UnitGUID=unit;UnitName=name
""")

lua.execute("""
local previous=Core.Components.WindowManager
Core.Components.WindowManager={GetChatRoom=function(_,f)return f.roomId and f end}
CHAT_GUILD_GET="[Guild] %s: ";CHAT_PARTY_GET="[Party] %s: "
CHAT_WHISPER_GET="%s whispers: ";CHAT_WHISPER_INFORM_GET="To %s: "
local sender="|cffabcdef|Hplayer:Some Player:123|h[Some Player]|h|r"
local body="look |Hitem:123|h[Item]|h [Guild] whispers: unchanged"
local whisper={chatType="WHISPER"}
assert(TP:CompactMessageLabels(sender.." whispers: "..body,whisper,ChatTypeInfo.WHISPER.id)==sender:gsub("|h%[","|h"):gsub("%]|h","|h")..": "..body)
assert(TP:CompactMessageLabels("To "..sender..": "..body,whisper,80)==body)
assert(TP:CompactMessageLabels("[Guild] "..sender..": "..body,{roomId="guild"},40)==sender..": "..body)
assert(TP:CompactMessageLabels("[Party] "..sender..": "..body,{roomId="party"},41)==sender..": "..body)
assert(TP:CompactMessageLabels("[Guild] "..sender..": "..body,{},40)=="[Guild] "..sender..": "..body,"General lost channel context")
assert(TP:CompactMessageLabels("system notice",whisper,ChatTypeInfo.WHISPER.id)=="system notice")
CHAT_WHISPER_GET="%s murmure : "
assert(TP:CompactMessageLabels("[Player] murmure : "..body,whisper,ChatTypeInfo.WHISPER.id)=="Player: "..body,"localized sender template failed")
assert(TP:CompactMessageLabels("[Party] [Plain Player]: "..body,{roomId="party"},41)=="[Plain Player]: "..body,"plain native Party header survived")
assert(TP:CompactMessageLabels("|cff40ff40[Guild]|r [Plain Player]: "..body,{roomId="guild"},40)=="|cff40ff40|r [Plain Player]: "..body,"plain colored Guild header survived")
local decorated="|cff40ff40|Hchannel:GUILD|h[Guild]|h|r "..sender..": "..body
local compact=TP:CompactMessageLabels(decorated,{roomId="guild"},40)
assert(not compact:find("|Hchannel:",1,true) and compact:find(sender,1,true) and compact:find(body,1,true),"decorated channel prefix survived")
local flat="|cff40ff40[Guild]|r "..sender..": "..body
compact=TP:CompactMessageLabels(flat,{roomId="guild"},40)
assert(compact=="|cff40ff40|r"..sender..": "..body,"flattened colored prefix survived")
Core.Components.WindowManager=previous
""")
