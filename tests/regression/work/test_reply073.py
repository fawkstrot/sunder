exec(open('work/test_routing072.py',encoding='utf-8').read())
lua.execute(Path(os.environ['SUNDER_ADDON_ROOT']+'/Sunder/Modules/WhisperReply.lua').read_text(encoding='utf-8'),'Sunder',lua.globals().vars)
lua.execute("""
cfg.mode='hub';cfg.enabled=true
local frame,target=conversation('ChatFrameReplyTarget','ReplyTarget-Realm');W:OnWindowOpened(frame);drain()
local otherFrame,source=conversation('ChatFrameReplySource','General','SAY')
local box=source.editBox;box.focus=true;box.draft='keep my draft';box.recipient='ReplyTarget-Realm';box.kind='WHISPER'
function box:GetChatType() return self.kind end
function box:GetTellTarget() return self.recipient end
function source.slidingMessageFrame:SetTyping(v) self.typing=v end
W:RouteReplyEditor(box)
assert(W:LayoutEditBox(target)==box and W:LayoutEditBox(source)==false)
assert(target.slidingMessageFrame.input==box and box:GetParent()==W.hubContent)
assert(source.slidingMessageFrame.input==false and source.slidingMessageFrame.typing==false)
assert(W.selected==frame and box.draft=='keep my draft' and box.recipient=='ReplyTarget-Realm')
W:ReleaseReplyEditor(box);W:RouteReplyEditor(box);drain()
assert(target.replyEditBox==box,'stale fade callback detached an active reply')
box.focus=false;W:ReleaseReplyEditor(box);drain()
assert(not target.replyEditBox and W:LayoutEditBox(source)==box and box:GetParent()==ui.container)
assert(target.slidingMessageFrame.input==target.editBox)
-- General chat and restricted targets retain native ownership.
box.focus=true;box.kind='SAY';W:RouteReplyEditor(box);assert(not target.replyEditBox)
box.kind='WHISPER';box.recipient=secret;W:RouteReplyEditor(box);assert(not target.replyEditBox)
box.recipient='ReplyTarget-Realm';W:RouteReplyEditor(box);assert(target.replyEditBox==box)
W:OnWindowClosed(frame);assert(not target.replyEditBox and not W.replyEditors[box])
""")
print('Reply ownership checks passed: borrowed native editor follows recipient, only conversation area resizes, drafts/recipient preserved, late fades cancelled, focus-loss return, ordinary chat/restricted target exclusion and close cleanup.')

lua.execute("""
local frame,target=conversation('ChatFrameReplyGroup','GroupReply-Realm');W:OnWindowOpened(frame);drain();W:MoveToWorkspace(frame,'favorites')
local owner,source=conversation('ChatFrameReplyGeneral2','General','SAY');local box=source.editBox
box.focus=true;function box:GetChatType() return 'WHISPER' end;function box:GetTellTarget() return 'GroupReply-Realm' end
function source.slidingMessageFrame:SetTyping(v) self.typing=v end
W:RouteReplyEditor(box)
assert(box:GetParent()==W:GetWorkspace('favorites').hubContent and W:IsReading(frame))
W:ReleaseReplyEditor(box,true);W:Place(frame,'detached',true);W:RouteReplyEditor(box)
assert(box:GetParent()==target.detachedLayout.container)
cfg.enabled=false;W:ApplySettings(false);assert(not W.replyEditors[box] and box:GetParent()==ui.container)
cfg.enabled=true;W:ApplySettings(false)
""")
print('Reply group checks passed: Favorites, detached containers, active draft reading state and feature-disable return to native ownership.')
