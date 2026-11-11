exec(open('work/test_whispers.py', encoding='utf-8').read())
lua.execute('''
local methods=getmetatable(UIParent).__index
function methods:Disable() self.disabled=true end
function methods:Enable() self.disabled=false end
function methods:SetFading(value) self.fading=value end
function methods:SetMaxLines(value) self.maxLines=value end
function methods:Clear() self.rows={} end
function methods:AddMessage(text) self.rows=self.rows or {};self.rows[#self.rows+1]=text end
function methods:ScrollUp() end
function methods:ScrollDown() end
function GetServerTime() return 100000+now end
function date(_,time) return "["..time.."]" end
''')
lua.execute(root.joinpath('Modules/WhisperPreview.lua').read_text(encoding='utf-8'), 'Sunder', lua.globals().vars)
lua.execute('''
local realRecords,realOrder,realTabs,realSelected=W.records,W.hubOrder,W.hubTabs,W.selected
W.records,W.hubOrder,W.hubTabs,W.selected={},{},{},nil
cfg.enabled=true;cfg.visibility="timer";cfg.keepMessagesOpen=false;cfg.keepUnread=false;cfg.holdTime=5
now=10000;W:OpenMessages();W:Tick()
assert(W.hub:IsShown() and W.hub:GetAlpha()==1,"empty manual opening expired immediately")
now=10004;W:Tick();assert(W.hub:IsShown())
now=10006;W:Tick();assert(not W.hub:IsShown(),"timer option did not expire")
cfg.keepMessagesOpen=true;W:OpenMessages();now=20000;W:Tick()
assert(W.hub:IsShown() and W.hub:GetAlpha()==1,"keep-open setting failed for empty hub")
W.hub:Hide();W:Tick();assert(not W.hub:IsShown(),"keep-open overrode explicit close")
W.records,W.hubOrder,W.hubTabs,W.selected=realRecords,realOrder,realTabs,realSelected
local selectedRecord=W.records[realSelected]
selectedRecord.unread=7
local recordCount=0;for _ in pairs(W.records) do recordCount=recordCount+1 end
local lastRealSound=W.lastSound
local realReply=repliedTo
cfg.previewAutoNotify=false;cfg.previewSound=true;cfg.keepMessagesOpen=false
W:StartPreview()
assert(W.previewActive and #W.previewConversations==3 and W.previewSelected==1)
assert(#W.previewBody.rows==3 and W.previewBody.rows[1]:find("Elowen",1,true))
assert(not W.hubContent:IsShown() and not W.tabScroll:IsShown())
assert(W.hubActionButtons.Reply.disabled and W.hubActionButtons.Detach.disabled and W.hubActionButtons.Pin.disabled)
W.hubActionButtons.Reply.scripts.OnClick()
assert(repliedTo==realReply,"preview reply reached a real recipient")
now=50000;W:Tick()
assert(W.hub:IsShown() and selectedRecord.unread==7,"preview hid or cleared real unread state")
local sounds=soundsPlayed
W:GeneratePreviewNotification()
assert(W.previewNotificationCount==1 and soundsPlayed==sounds+1)
assert(W.lastSound==lastRealSound,"preview delayed real notifications through shared cooldown")
local unread=0;for _,c in ipairs(W.previewConversations) do unread=unread+c.unread end
assert(unread==4 and W.previewSelected==1,"sample notification did not update badge or stole preview selection")
W:SelectPreviewConversation(2);assert(W.previewConversations[2].unread==0)
cfg.previewSound=false
local silentSounds=soundsPlayed
for _=1,120 do W:GeneratePreviewNotification() end
assert(soundsPlayed==silentSounds)
for _,c in ipairs(W.previewConversations) do assert(#c.lines<=50,"preview message buffer grew without limit") end
cfg.previewAutoNotify=true;cfg.previewInterval=2
local count=W.previewNotificationCount
now=now+3;W:Tick();assert(W.previewNotificationCount==count+1)
local afterCount=0;for _ in pairs(W.records) do afterCount=afterCount+1 end
assert(afterCount==recordCount and selectedRecord.unread==7,"sample data leaked into real conversations")
W:StartPreview();assert(W.previewNotificationCount==0 and #W.previewConversations[1].lines==3,"seed reset was not repeatable")
W:StopPreview()
assert(not W.previewActive and not W.previewFrame:IsShown() and W.hubContent:IsShown() and W.tabScroll:IsShown())
assert(not W.hubActionButtons.Reply.disabled and W.previewConversations==nil)
W:StartPreview();W:OnNativeMessage(realSelected,1)
assert(not W.previewActive,"real incoming whisper did not exit preview")
W:StartPreview();W.hub:Hide()
assert(not W.previewActive and not W.previewFrame:IsShown(),"closing hub left automatic preview running")
local schema=Core.features.whispers.buildOptions()
assert(schema.args.visibility.args.keepMessagesOpen and schema.args.preview.args.notify and schema.args.preview.args.active)
''')
print('Messages checks passed: empty-window timer, keep-open/manual close, seeded preview, unread/sound simulation, real-data isolation, no reply recipients, bounded samples, repeatable reset, auto notifications and cleanup.')
