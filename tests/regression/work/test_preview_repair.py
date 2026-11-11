from pathlib import Path
s=Path('work/test_whisper_preview.py').read_text(encoding='utf-8')
s=s.replace("lua.execute(root.joinpath('Modules/WhisperPreview.lua')", """lua.execute(Path('work/FontableFrameMixin.lua').read_text(encoding='utf-8'))
lua.execute('''
local methods=getmetatable(UIParent).__index
function CreateFont()
 return {CopyFontObject=function(self,source) assert(type(source)=="table");self.copied=true end,
 GetTextColor=function() return 1,1,1,1 end, SetJustifyH=function() end}
end
SunderMessageFont={GetFontObjectForAlphabet=function() return CreateFont() end}
local original=CreateFrame
function CreateFrame(kind,...)
 local frame=original(kind,...)
 if kind=="ScrollingMessageFrame" then
  for key,value in pairs(FontableFrameMixin) do frame[key]=value end
  frame.OnFontObjectUpdated=function(self) self:GetTextColor() end
 end
 return frame
end
''')
lua.execute(root.joinpath('Modules/WhisperPreview.lua')""")
s=s.replace('#W.previewConversations==3','#W.previewConversations==10').replace('#W.previewBody.rows==3','#W.previewBody.rows==40')
s=s.replace('W.hubActionButtons.Detach.disabled and W.hubActionButtons.Pin.disabled', 'not W.hubActionButtons.Detach.disabled and not W.hubActionButtons.Pin.disabled')
s=s.replace('local sounds=soundsPlayed','local beforeUnread=0;for _,c in ipairs(W.previewConversations) do beforeUnread=beforeUnread+c.unread end\nlocal sounds=soundsPlayed')
s=s.replace('unread==4','unread==beforeUnread+1').replace('#c.lines<=50','#c.lines<=200').replace('#W.previewConversations[1].lines==3','#W.previewConversations[1].lines==40')
s=s.replace('W:StopPreview()\nassert(not W.previewActive', '''cfg.previewSound=true;local beforeSounds=soundsPlayed
W:GeneratePreviewBatch()
assert(W.previewNotificationCount==50 and soundsPlayed==beforeSounds+1,"batch did not create 50 messages with a single sound")
assert(W.previewBody:GetTextColor()==1,"real FontableFrameMixin failed to render preview font")
cfg.previewConversations=30;cfg.previewLines=200;W:StartPreview()
assert(#W.previewConversations==30 and #W.previewConversations[30].lines==200)
cfg.previewConversations=3;cfg.previewLines=5;W:StartPreview()
assert(not W.previewTabs[4]:IsShown(),"pooled sample tabs leaked after reset")
W:ClearPreviewData()
assert(#W.previewBody.rows==0 and not cfg.previewAutoNotify,"clear left sample text or auto generation")
assert(not W.previewActive''')
exec(compile(s,'preview_repair','exec'))
