exec(open('work/test_replies076.py',encoding='utf-8').read())
lua.execute('''
-- Real addon records remain authoritative without native temporary flags/list.
BNHistory.isTemporary=nil;CHAT_FRAMES={};History:Save()
assert(#Core.db.char.whisperTabs==1,"unlisted live conversation was dropped")
History.loggingOut=true;BNHistory.inUse=false;History:Save()
assert(#Core.db.char.whisperTabs==1,"logout retired frame erased checkpoint")
History.loggingOut=nil;BNHistory.inUse=true
local f=BNHistory
f.chatType="WHISPER";f.chatTarget="Superhead"
Constants={CharacterNameSeparatorConsts={CHARACTERNAME_SURNAME_SEPARATOR=" "}}
UnitNameUnmodified=function(unit) if unit=="Superhead" then return "Superhead","Storm" end end
assert(W:ConversationName(f)=="Superhead Storm")
UnitNameUnmodified=nil
assert(W:ConversationName(f)=="Superhead Storm","surname lookup was not cached")
''')
print('Client compatibility checks passed: missing native flags/list, logout retirement checkpoint, full character names and name cache.')
exec(open('work/test_toast_ack074.py',encoding='utf-8').read())
lua.execute('''
W:ClearPreviewData();cfg.enabled=true;cfg.mode="hub"
local a=conversation("VisiblePersonA","First Last");W:OnWindowOpened(a);drain();W:MoveToWorkspace(a,"messages")
W:SetMinimized(false,true);W:SelectConversation(a,false);W.hub:Show();W.hub:SetAlpha(1)
W.minimizedWhispers={}
assert(W:IsConversationDisplayed(a))
local smf=ui:GetChatWindow(a).slidingMessageFrame
smf.state.scrollAtBottom=false
assert(W:IsConversationDisplayed(a) and not W:IsReading(a))
W:QueueMinimizedWhisper(a,false,"Already visible")
assert(#W.minimizedWhispers==0,"visible conversation produced toast")
local host=W:GetWorkspace("group2")
local b=conversation("VisiblePersonB","Other Person");W:OnWindowOpened(b);drain();W:MoveToWorkspace(b,host.hostId)
host:SetMinimized(false,true);host:SelectConversation(b,false);host.hub:Show();host.hub:SetAlpha(1)
assert(W:IsConversationDisplayed(a) and W:IsConversationDisplayed(b),"multiple visible conversations not recognized")
host.minimizedWhispers={};host:QueueMinimizedWhisper(b,false,"Already visible too");assert(#host.minimizedWhispers==0)
host.minimized=true;host:QueueMinimizedWhisper(b,false,"Now waiting");assert(#host.minimizedWhispers==1)
''')
print('Visible-conversation checks passed: scrolled-back conversation, independent simultaneous groups, minimized notifications.')


