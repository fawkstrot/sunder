exec(open('work/test_whispers.py',encoding='utf-8').read())
lua.execute('''
local m=getmetatable(UIParent).__index
function m:SetGradient(direction,bottom,top)self.gradient={direction,bottom,top}end
function m:SetIndentedWordWrap()end
function m:GetLineHeight()return 12 end
function m:GetStringHeight()return 24 end
function m:ClearText()self.text=""end
function CreateColor(r,g,b,a)return {r=r,g=g,b=b,a=a}end
Core.Components.SlidingMessageFrameMixin={};Core.Components.SlidingMessageFrameHelpers={}
Core.db.profile.bodyPadding=12

''')
lua.execute(root.joinpath('Components/SlidingMessageFrameLayout.lua').read_text(encoding='utf-8'),'Sunder',lua.globals().vars)
lua.execute('''
local mixin=Core.Components.SlidingMessageFrameMixin
local f=CreateFrame("Frame",nil,UIParent)
for k,v in pairs(mixin)do f[k]=v end
f.viewport=CreateFrame("Frame",nil,f);f.slider=CreateFrame("Frame",nil,f.viewport)
f.config={height=100,overflowHeight=20};f.state={scrollAtBottom=true,messages={CreateFrame("Frame")}}
f:UpdateViewportHeight();assert(f:GetHeight()==120 and f.slider:GetHeight()==76 and f.viewport.points.TOPLEFT.y==-12)
f.state.scrollAtBottom=false;f:UpdateViewportHeight(24);assert(f:GetHeight()==76 and f.slider:GetHeight()==52)
Core.db.profile.bodyPadding=32;f.config.height=5;f:UpdateViewportHeight(24);assert(f.slider:GetHeight()==1)
''')
source=root.joinpath('Components/MessageLine.lua').read_text(encoding='utf-8')
lua.globals().messageMixin=lua.execute(source+'\nreturn MessageLineMixin','Sunder',lua.globals().vars)
lua.execute('''
Core.db.profile.bodyPadding=12;Core.db.profile.frameWidth=500;Core.db.profile.messageLinePadding=.25
Core.db.profile.chatBackgroundColor={r=0,g=0,b=0,a=.3}
local color=Core.db.profile.chatBackgroundColor
local row=CreateFrame("Frame",nil,UIParent);row.text=row:CreateFontString()
for k,v in pairs(messageMixin)do row[k]=v end
row.WithTextDetached=function(_,fn)fn()end
row.UpdateFadeSettings=function()end
row.sunderBackgroundWidth=500
row.sunderBackgroundLeftFadeWidth=tonumber(Core.db.profile.backgroundFadeLeftPercent)or 0
row.sunderBackgroundRightFadeWidth=tonumber(Core.db.profile.backgroundFadeRightPercent)or 0
row.sunderBackgroundRed=color.r;row.sunderBackgroundGreen=color.g;row.sunderBackgroundBlue=color.b;row.sunderBackgroundAlpha=color.a
row:UpdateFrame();assert(row.text:GetWidth()==476 and row.text.points.BOTTOMLEFT.x==12)
Core.db.profile.bodyPadding=20
row:UpdateFrame();assert(row.text:GetWidth()==460 and row.text.points.BOTTOMLEFT.x==20)
Core.db.profile.bodyPadding=32;row:UpdateFrame();assert(row.text:GetWidth()==436)
''')
print('Shared native spacing passed: equal side insets, top/bottom viewport spacing, bounded tiny layouts, live wrapping updates and no top-shade renderer.')

exec(open('work/test_favorites095.py',encoding='utf-8').read())
lua.execute('''
W:ClearPreviewData();cfg.enabled=true;cfg.mode="hub";cfg.conversationLayout="list"
W:OpenMessages();W:SetMinimized(false,true);W:SetPeopleFilter("all");W:StartPreview()
local header=W:HeaderHeight()
for _,padding in ipairs({0,12,24}) do
 Core.db.profile.bodyPadding=padding;W:RefreshHubStyle();W:LayoutPeopleRows(true)
 assert(W:BodyPadding()==padding and W:HeaderHeight()==header,"body setting changed headers")
 local top=W:HeaderHeight()+W:HeaderGap()+32
 assert(W.previewBody.points.TOPLEFT.x==W:ConversationBodyLeft()+padding)
 assert(W.previewBody.points.TOPRIGHT.x==-padding)
 assert(W.previewBody.points.TOPLEFT.y==-top-padding)
 assert(W.previewBody:GetHeight()==math.max(1,W.hub:GetHeight()-top-padding*2))
 assert(W.previewTabs[1].points.TOPLEFT.x==padding)
 assert(W.previewTabs[1]:GetWidth()==W:ConversationListWidth()-padding*2)
 W.minimizedWhispers={};local person=W.previewConversations[2]
 W:SetMinimized(true,true);W:QueueMinimizedWhisper(person,true,"Spacing test")
 local toast=W.minimizedWhisperRows and W.minimizedWhisperRows[1]
 if toast and toast:IsShown() then assert(toast.name.points.TOPLEFT.x==padding and toast.snippet.points.TOPLEFT.x==padding) end
 W:SetMinimized(false,true)
end
W:ClearPreviewData()
''')
print('Shared Whispers spacing passed at 0/12/24 px: sample body insets, people-list widths/alignment, resize-safe bounds and unchanged header metrics.')
