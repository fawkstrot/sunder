exec(open('work/test_whispers.py',encoding='utf-8').read())
lua.execute('''
GetServerTime=GetServerTime or function()return 1700000000 end
date=date or os.date
time=time or os.time
local m=getmetatable(UIParent).__index
function m:GetFrameStrata()return "MEDIUM" end
function m:EnableKeyboard(value)self.keyboardEnabled=value end
function m:SetPropagateKeyboardInput(value)self.propagates=value end
function m:SetGradient(direction,bottom,top)self.gradient={direction,bottom,top}end
function m:SetIndentedWordWrap()end
function m:GetStringWidth()return #(self:GetText()or "")*7 end
function m:GetLineHeight()return 12 end
function m:GetStringHeight()return 24 end
function m:ClearText()self.text=""end
function CreateColor(r,g,b,a)return {r=r,g=g,b=b,a=a}end
Core.Components.SlidingMessageFrameMixin={UpdatePinnedDate=function()end};Core.Components.SlidingMessageFrameHelpers={getMessageTopInset=function()return 20 end}
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
local extent=Core.Components.WindowManager.UpdateContentExtent;local reported
Core.Components.WindowManager.UpdateContentExtent=function(_,_,height)reported=height end
f.windowSurface=true;f.state.scrollIndex=1;f:UpdateViewportHeight()
assert(reported==100,"animation overflow buffer enlarged visible window bounds")
f.windowSurface=nil;Core.Components.WindowManager.UpdateContentExtent=extent
f.state.scrollAtBottom=false;f:UpdateViewportHeight(24);assert(f:GetHeight()==76 and f.slider:GetHeight()==52)
Core.db.profile.bodyPadding=8;f.state.scrollAtBottom=true;f:UpdateViewportHeight();assert(f.slider:GetHeight()==84 and f.viewport.points.TOPLEFT.y==-8)
Core.db.profile.bodyPadding=32;f.config.height=5;f:UpdateViewportHeight(24);assert(f.slider:GetHeight()==1)
-- Live geometry must not wait for history reflow or reset a scrolled-back reader.
Core.db.profile.bodyPadding=8
f.overlay=CreateFrame("Frame",nil,f)
function f.overlay:UpdateFrame()self.updated=true end
function f:CancelDynamicEditBoxLayout()end
local nextWidth,nextHeight=640,240
function f:GetLayoutWidth()return nextWidth end
function f:GetMessageFrameHeight()return nextHeight end
f.state.scrollAtBottom=false;f.state.scrollIndex=7
f.state.layoutRefreshPending=true
f.windowSurface=true
f:RefreshLayoutGeometry()
assert(f:GetWidth()==640 and f.config.height==240 and f.slider:GetWidth()==640)
assert(f.scrollRail:GetHeight()==208,"rail waited for deferred history layout")
assert(f.state.scrollIndex==7 and f.state.layoutRefreshPending,"geometry update disturbed readback or pending reflow")
nextWidth,nextHeight=720,310;f:RefreshLayoutGeometry()
assert(f:GetWidth()==720 and f.scrollRail:GetHeight()==278 and f.overlay.updated)
f.state.messageOffset=9;f.state.unreadMessages=true
function f:SetScrollPosition(index,offset)
 assert(index==7 and offset==9,"full reflow jumped to newest and acknowledged unread")
end
f.state.messages[1].UpdateFrame=function()end
f:RefreshLayout(false)
f.windowSurface=nil

''')
source=root.joinpath('Components/MessageLine.lua').read_text(encoding='utf-8')
lua.globals().messageMixin=lua.execute(source+'\nreturn MessageLineMixin','Sunder',lua.globals().vars)
lua.execute('''
Core.db.profile.bodyPadding=12;Core.db.profile.frameWidth=500;Core.db.profile.messageLinePadding=.25
Core.db.profile.chatBackgroundColor={r=0,g=0,b=0,a=.3}
local color=Core.db.profile.chatBackgroundColor
local row=CreateFrame("Frame",nil,UIParent);row.text=row:CreateFontString()
row.sunderRenderer={GetLayoutWidth=function()return 500 end}
for k,v in pairs(messageMixin)do row[k]=v end
row.WithTextDetached=function(_,fn)fn()end
row.UpdateFadeSettings=function()end
row.sunderBackgroundWidth=500
row.sunderBackgroundLeftFadeWidth=tonumber(Core.db.profile.backgroundFadeLeftPercent)or 0
row.sunderBackgroundRightFadeWidth=tonumber(Core.db.profile.backgroundFadeRightPercent)or 0
row.sunderBackgroundRed=color.r;row.sunderBackgroundGreen=color.g;row.sunderBackgroundBlue=color.b;row.sunderBackgroundAlpha=color.a
row:UpdateFrame();assert(row.text:GetWidth()==476 and row.text.points.TOPLEFT.x==12)
Core.db.profile.bodyPadding=8
row:UpdateFrame();assert(row.text:GetWidth()==484 and row.text.points.TOPLEFT.x==8)
Core.db.profile.bodyPadding=20
row:UpdateFrame();assert(row.text:GetWidth()==460 and row.text.points.TOPLEFT.x==20)
Core.db.profile.bodyPadding=32;row:UpdateFrame();assert(row.text:GetWidth()==436)
''')
lua.execute("""
local owner=CreateFrame("Frame");owner.widthNow=220;owner.whisperFullSurface=true
function owner:GetLayoutWidth()return self.widthNow end
local viewport=CreateFrame("Frame",nil,owner)
local slider=CreateFrame("Frame",nil,viewport)
local row=CreateFrame("Frame",nil,slider);row.text=row:CreateFontString();row.sunderRenderer=owner
for k,v in pairs(messageMixin)do row[k]=v end
row.WithTextDetached=function(_,fn)fn()end;row.UpdateFadeSettings=function()end;row.SetGradientBackground=function()end;row.SetBackgroundCoverage=function()end
Core.db.profile.bodyPadding=8
row:UpdateFrame();assert(row.sunderLayoutWidth==220 and row.text:GetWidth()==201)
owner.widthNow=140;row:UpdateFrame();assert(row.text:GetWidth()==121)
Core.db.profile.bodyPadding=0;row:UpdateFrame();assert(row.text:GetWidth()==129,"room scrollbar clearance lost at zero padding")
""")
# Exercise the actual native initializer and actual pool through viewport -> slider.
lua.execute("""
function CreateObjectPool(create,reset)
 return {Acquire=function(self)local row=self.saved or create();self.saved=nil;return row end,
 Release=function(self,row)reset(self,row);self.saved=row end}
end
function Mixin(target,...)for _,source in ipairs({...})do for key,value in pairs(source)do target[key]=value end end;return target end
Core.Components.FadingFrameMixin={Init=function(self)self.text=nil end,QuickHide=function(self)self:Hide()end}
Core.Components.GradientBackgroundMixin={Init=function()end,SetGradientBackground=function(self)
 self.centerBg=self:CreateTexture();self.leftBg=self:CreateTexture();self.rightBg=self:CreateTexture()
end}
GetServerTime=GetServerTime or function()return 1700000000 end
date=date or os.date
time=time or os.time
local m=getmetatable(UIParent).__index
function m:GetStringHeight()return math.max(1,math.ceil(#(self:GetText()or "")/math.max(1,self:GetWidth()/7)))*12 end
function m:SetWordWrap(value)self.wordWrap=value end
function m:SetNonSpaceWrap(value)self.nonSpaceWrap=value end
function m:SetMaxLines(value)self.maxLines=value end
function m:EnableDrawLayer()end
function m:DisableDrawLayer()end
function m:SetHyperlinksEnabled()end
""")
lua.globals().actualLine=lua.execute(source+'\nreturn MessageLineMixin','Sunder',lua.globals().vars)
lua.execute('actualLine.UpdateFadeSettings=function()end')
lua.execute(root.joinpath('Components/SlidingMessageFrameNative.lua').read_text(encoding='utf-8'),'Sunder',lua.globals().vars)
lua.execute("""
local renderer=CreateFrame("Frame",nil,UIParent)
for key,value in pairs(Core.Components.SlidingMessageFrameMixin)do renderer[key]=value end
renderer.config={width=220,height=180,overflowHeight=20};renderer.state={messages={},scrollAtBottom=true,scrollIndex=1}
renderer.widthNow=220;renderer.sharedFullSurface=true
function renderer:GetLayoutWidth()return self.widthNow end
function renderer:GetFrameLevel()return 3 end
function renderer:GetFrameStrata()return "MEDIUM"end
function renderer:SetHitRectInsets(_,_,_,bottom)self.hitBottom=bottom end
function renderer:SetSlideOffset()end
renderer.gapBackground=CreateFrame("Frame",nil,renderer)
renderer.overlay=CreateFrame("Frame",nil,renderer);renderer.overlay.UpdateFrame=function()end
renderer:InitializeScrollFrame()
assert(renderer.slider:GetParent()==renderer.viewport and renderer.viewport:GetParent()==renderer)
-- Party directly above General: neither clicks on blank space nor wheel events
-- can extend below the visible transcript into the next window's title bar.
for _,latest in ipairs({true,false,true}) do
 renderer.state.scrollAtBottom=latest;renderer:UpdateViewportHeight(24)
 local visible=latest and 180 or 156
 assert(renderer:GetHeight()-renderer.viewport.points.BOTTOMRIGHT.y==visible,"viewport intercepts neighboring header")
 assert(renderer:GetHeight()-renderer.hitBottom==visible,"wheel target overlaps neighboring header")
end
local row=renderer.messageFramePool:Acquire()
assert(row.sunderRenderer==renderer,"native pool did not bind explicit owner")
row:SetDisplayText("[Party] Player: "..string.rep("A long linked quest message ",15))
Core.db.profile.bodyPadding=8;row:UpdateFrame()
assert(row:GetWidth()==220 and row.text:GetWidth()==201 and row.sunderHeight>12,"actual viewport hierarchy lost wrapping width/height")
assert(row.text.wordWrap and row.text.nonSpaceWrap and row.text.maxLines==0)
renderer.widthNow=140;row:UpdateFrame();assert(row.text:GetWidth()==121 and row.sunderHeight>24)
renderer.messageFramePool:Release(row)
local recycled=renderer.messageFramePool:Acquire();assert(recycled==row and recycled.sunderRenderer==renderer)
renderer.widthNow=126;Core.db.profile.bodyPadding=0
recycled:SetDisplayText(string.rep("X",180));recycled:UpdateFrame()
assert(recycled.text:GetWidth()==115 and recycled.sunderHeight>24)
assert(not pcall(Core.Components.CreateMessageLine,renderer.slider),"row accepted a missing owner")
assert(not pcall(Core.Components.CreateMessageLinePool,renderer.slider),"ownerless pool silently falls back to General")
""")
# Install the production height helper as well as the renderer for editor containment.
height_source=root.joinpath('Components/SlidingMessageFrame.lua').read_text(encoding='utf-8')
lua.execute('local Core,Constants=unpack(select(2,...));local getMessageTopInset=Core.Components.SlidingMessageFrameHelpers.getMessageTopInset\n'+height_source[height_source.index('local function getMessageFrameHeight('):height_source.index('Core.Components.SlidingMessageFrameHelpers =')]+ '\nCore.Components.SlidingMessageFrameHelpers.getMessageFrameHeight=getMessageFrameHeight', 'Sunder', lua.globals().vars)
lua.execute(root.joinpath('Components/SlidingMessageFrameLayout.lua').read_text(encoding='utf-8'),'Sunder',lua.globals().vars)
# Use the installed detached-container resize callback with the actual renderer geometry.
lua.execute("""
Core.Components.CreateDetachedChatDock=function(parent)local dock=CreateFrame("Frame",nil,parent);dock:SetHeight(22);return dock end
function ui.container:AddHoverRegion()end
getmetatable(UIParent).__index.GetFrameStrata=function()return "MEDIUM"end
""")
lua.execute(root.joinpath('Modules/UIManager.lua').read_text(encoding='utf-8'),'Sunder',lua.globals().vars)
lua.execute("""
local native=CreateFrame("Frame",nil,UIParent)
local renderer=CreateFrame("Frame",nil,UIParent)
for k,v in pairs(Core.Components.SlidingMessageFrameMixin)do renderer[k]=v end
renderer.chatFrame=native;renderer.config={width=190,height=120,overflowHeight=0}
renderer.state={messages={},scrollAtBottom=false,scrollIndex=1,messageOffset=8}
renderer.windowSurface=true
function renderer:GetMessageFrameHeight()return self.layoutHeight-20 end
function renderer:CancelDynamicEditBoxLayout()end
function renderer:ScheduleLayoutRefresh()self.widthChanges=(self.widthChanges or 0)+1 end
renderer.viewport=CreateFrame("Frame",nil,renderer);renderer.slider=CreateFrame("Frame",nil,renderer.viewport)
renderer.overlay=CreateFrame("Frame",nil,renderer);renderer.overlay.UpdateFrame=function()end
local layout=ui:CreateDetachedLayout({chatFrame=native,slidingMessageFrame=renderer})
local root=layout.container;renderer.detachedContainer=root;renderer:SetParent(root)
root:SetSize(190,170);root:SetSize(160,150)
assert(renderer.slider:GetWidth()==160 and renderer.scrollRail:GetHeight()==98)
assert(root.windowSurface.bodyFrame:GetHeight()==root:GetHeight()-layout.dock:GetHeight()-Core.Components.WindowManager:HeaderGap())
assert(renderer.widthChanges==1 and renderer.state.messageOffset==8)
root:SetHeight(140);assert(renderer.widthChanges==1,"height-only drag queued a text pass")
-- Exercise real editor/renderer geometry rather than a scalar resize clamp.
renderer.GetMessageFrameHeight=Core.Components.SlidingMessageFrameMixin.GetMessageFrameHeight
local editor={height=32,shown=false}
function editor:GetHeight()return self.height end
function editor:GetReusableMessageHeight()return not self.shown and Core.db.profile.editBoxAnchor.position=="BELOW" and self.height-Core.db.profile.editBoxAnchor.yOfs or 0 end
renderer.layoutEditBox=editor
local oldAnchor=Core.db.profile.editBoxAnchor
Core.db.profile.editBoxAnchor={position="BELOW",yOfs=-2}
for _,padding in ipairs({0,8,19})do
 Core.db.profile.bodyPadding=padding
 for _,height in ipairs({220,240,300})do
  root:SetHeight(height);renderer:SetLayoutSize(root:GetWidth(),height)
  assert(renderer.config.height==height-Core.Components.SlidingMessageFrameHelpers.getMessageTopInset(),"closed editor grew the visible root")
  assert((root.windowContentExtent or 0)==0 and root.windowSurface.bottomExtent==0,"surface still extends beyond the shared minimum")
  editor.shown=true;renderer:RefreshLayoutGeometry()
  assert(renderer.config.height==height-Core.Components.SlidingMessageFrameHelpers.getMessageTopInset()-34,"open editor not reserved inside root")
  editor.height=64;renderer:RefreshLayoutGeometry()
  assert(renderer.config.height==height-Core.Components.SlidingMessageFrameHelpers.getMessageTopInset()-66,"growing editor escaped root")
  editor.shown=false;renderer:RefreshLayoutGeometry()
  assert(root.windowSurface.bottomExtent==0,"closing grown editor expanded surface")
  editor.height=32
 end
end
Core.db.profile.editBoxAnchor={position="ABOVE",yOfs=2};renderer:RefreshLayoutGeometry()
assert(root.windowSurface.bottomExtent==0,"above editor expanded visible bounds")
Core.db.profile.editBoxAnchor=oldAnchor;Core.db.profile.bodyPadding=0
renderer.detachedContainer=nil
root:SetWidth(340);assert(renderer.slider:GetWidth()==160,"parked detached shell reclaimed renderer")
""")
# Read-only archives use actual pooled MessageLine rows and preserve native link handlers.
lua.execute(root.joinpath('Components/ReadOnlyTranscript.lua').read_text(encoding='utf-8'),'Sunder',lua.globals().vars)
lua.execute("""
local old=Core.GetModule;local rows={}
function Core:GetModule(name,...)if name=="TextProcessing"then return {ProcessText=function(_,v)return v end,WhisperReplyStyle=function()end}end;return old(self,name,...)end
local create=Core.Components.CreateMessageLinePool
Core.Components.CreateMessageLinePool=function(parent,owner)
 local pool=create(parent,owner);local acquire=pool.Acquire
 function pool:Acquire()local row=acquire(self);rows[#rows+1]=row;return row end
 function pool:ReleaseAll()for _,row in ipairs(rows)do self:Release(row)end;rows={}end
 return pool
end
local panel=CreateFrame("Frame",nil,UIParent);panel:SetSize(260,140)
local view=Core.Components.CreateReadOnlyTranscript(panel,ChatFrame1);view:SetSize(220,100)
view:SetLines({{string.rep("Long linked message ",20),1,1,1,typeID=3}})
assert(#rows==1 and rows[1].text.wordWrap and rows[1].sunderHeight>24)
assert(rows[1]:GetScript("OnHyperlinkClick") and not rows[1]:GetScript("OnMouseDown"),"archive stole live editor or lost links")
assert(rows[1].text:GetWidth()==209,"archive applied extra horizontal clearance at zero padding")
Core.db.profile.bodyPadding=20
view:SetLines({{string.rep("A",240)}, {string.rep("B",320)}})
local firstHeight=rows[1].sunderHeight
view:SetVerticalScroll(20+firstHeight+3)
view:SetSize(140,80);view:SetSize(130,75)
assert(view:GetScript("OnUpdate") and rows[1].text:GetWidth()==180,"archive rebuilt during every resize event")
view:GetScript("OnUpdate")(view)
assert(rows[1].text:GetWidth()==90 and rows[1].text.points.TOPLEFT.x==20)
assert(view:GetVerticalScroll()==20+rows[1].sunderHeight+3 and not view:GetScript("OnUpdate"))
local first=rows[1];view:SetHeight(2000)
assert(rows[1]==first and not view:GetScript("OnUpdate") and view:GetVerticalScroll()==0)
assert(view.scrollRail:IsShown() and not view.scrollRail.thumb:IsShown())
view:SetHeight(75);assert(view.scrollRail.thumb:IsShown())
view:Hide();assert(not view.scrollRail:IsShown());view:Show();assert(view.scrollRail.thumb:IsShown())
local log={{string.rep("Wrapped practice line ",35)}}
view:ShowAppendedLines(log,ChatFrame1)
assert(view:GetVerticalScroll()>0,"initial practice log did not follow the latest line")
view:SetVerticalScroll(5);local retained=rows[1]
log[2]={"Arrives during readback"};view:ShowAppendedLines(log,ChatFrame1)
assert(rows[1]==retained and #rows==2 and view:GetVerticalScroll()==5,"arrival rebuilt or moved readback")
view:SetLines({{"Roster recorded",groupChange={kind="baseline",joined={{name="Sample",classFile="MAGE"}}}}})
assert(rows[1]:GetScript("OnEnter") and rows[1]:GetScript("OnLeave"),"roster event has no detail tooltip")
view:SetLines({{"Ordinary message"}})
assert(not rows[1]:GetScript("OnEnter") and not rows[1]:GetScript("OnLeave"),"recycled message inherited roster tooltip")
Core.Components.CreateMessageLinePool=create;Core.GetModule=old
""")
print('Shared native spacing passed: equal side insets, top/bottom viewport spacing, bounded tiny layouts, live wrapping updates and no top-shade renderer.')

# Real divider layout through the initialized viewport, slider and row pool.
source=root.joinpath('Components/SlidingMessageFrame.lua').read_text(encoding='utf-8')
pin=source[source.index('function SlidingMessageFrameMixin:UpdatePinnedDate()'):source.index('-- Distance from the pinned message')]
lua.execute('local SlidingMessageFrameMixin=Core.Components.SlidingMessageFrameMixin\n'+pin)
layout=source[source.index('function SlidingMessageFrameMixin:LayoutMessages()'):source.index('function SlidingMessageFrameMixin:UpdatePinnedDate()')]
lua.execute('local SlidingMessageFrameMixin=Core.Components.SlidingMessageFrameMixin\n'+layout)

lua.execute("""
local oldDate,oldClock=date,GetServerTime
date=function(format,value) return os.date("!"..format,value or 1700215200) end
GetServerTime=function()return 1700215200 end
local d=Core.Components.TranscriptDates
local today=1700215200
assert(d:Label(today):find("Today",1,true))
assert(d:Label(today-86400):find("Yesterday",1,true))
assert(d:Label(today-366*86400):find("2022",1,true))
assert(d:Label(nil)=="Date unknown")
assert(d:Boundary(today,today-3599,false)==nil)
assert(d:Boundary(today,today-3600,false)~=nil)
assert(d:Boundary(today,today-86400,false)==d:Label(today))
assert(d:Boundary(nil,nil,false)==nil)
local renderer=CreateFrame("Frame",nil,UIParent)
for key,value in pairs(Core.Components.SlidingMessageFrameMixin)do renderer[key]=value end
renderer.config={width=180,height=100,overflowHeight=0}
renderer.state={messages={},scrollAtBottom=true,scrollIndex=1}
renderer.widthNow=180;renderer.sharedFullSurface=true
function renderer:GetLayoutWidth()return self.widthNow end
renderer.gapBackground=CreateFrame("Frame",nil,renderer)
renderer.overlay=CreateFrame("Frame",nil,renderer);renderer.overlay.UpdateFrame=function()end
renderer:InitializeScrollFrame()
local row=renderer.messageFramePool:Acquire()
row:SetDisplayText(string.rep("wrapped text ",20));row.receivedAt=today
row:SetDateBoundary(today,today-86400,false)
local total=row.sunderHeight
assert(row.dateDivider:IsShown() and row.sunderDateHeight>0)
row:SetDateBoundary(today,today-1,false)
assert(not row.dateDivider:IsShown() and row.sunderHeight<total,"obsolete divider retained spacing")
row:SetDateBoundary(today,today-3600,false)
row:SetChainAnchor(nil,nil,"TOPLEFT")
assert(row.text.points.TOPLEFT.y==-row.sunderTextPadding-row.sunderDateHeight)
local older=renderer.messageFramePool:Acquire()
older:SetDisplayText("previous day");older.receivedAt=today-86400;older:UpdateFrame()
renderer.state.messages={older,row};renderer.state.scrollAtBottom=false
renderer:LayoutMessages()
assert(older.sunderDateLabel==d:Label(today-86400) and row.sunderDateLabel==d:Label(today))

renderer:UpdatePinnedDate()
assert(renderer.datePin:IsShown() and renderer.datePin.label:GetText()==d:Label(today))
renderer.state.scrollAtBottom=true;renderer:UpdatePinnedDate()
assert(not renderer.datePin:IsShown(),"pinned date covered the newest conversation")
renderer.messageFramePool:Release(row)
row=renderer.messageFramePool:Acquire()
assert(not row.sunderDateLabel and not row.dateDivider:IsShown(),"pooled row retained the previous date")
renderer.widthNow=100;row:SetDisplayText("narrow");row:SetDateBoundary(today,nil,true)
assert(row.dateDivider.label:GetWidth()<=row.text:GetWidth()-32)
date,GetServerTime=oldDate,oldClock
""")
print("Transcript dates passed calendar boundaries, one-hour gaps, unknown dates, real pooled row geometry, narrow widths and pinned history dates.")

create_row=source[source.index('function SlidingMessageFrameMixin:CreateMessageFrame('):source.index('function SlidingMessageFrameMixin:AddMessage(')]
lua.execute('local SlidingMessageFrameMixin=Core.Components.SlidingMessageFrameMixin;local TP={ProcessText=function(_,text)return text,text end,WhisperReplyStyle=function()end}\n'+create_row)
lua.execute('''
local renderer=CreateFrame("Frame",nil,UIParent)
for key,value in pairs(Core.Components.SlidingMessageFrameMixin)do renderer[key]=value end
renderer.config={width=180,height=100,overflowHeight=0};renderer.widthNow=180;renderer.sharedFullSurface=true
renderer.state={messages={},scrollAtBottom=true,scrollIndex=1}
function renderer:GetLayoutWidth()return self.widthNow end
renderer.gapBackground=CreateFrame("Frame",nil,renderer)
renderer.overlay=CreateFrame("Frame",nil,renderer);renderer.overlay.UpdateFrame=function()end
renderer:InitializeScrollFrame()
for iteration=1,180 do
 if #renderer.state.messages==24 then renderer.messageFramePool:Release(table.remove(renderer.state.messages,1))end
 renderer.widthNow=iteration%2==0 and 180 or 260
 local args={ChatFrame1,string.rep("wrapped row ",iteration%7+1),1,1,1};args.receivedAt=1700000000+iteration
 local row=renderer:CreateMessageFrame(args)
 assert(not row:IsShown(),"unpositioned incoming row painted at the bottom")
 table.insert(renderer.state.messages,row);renderer:LayoutMessages()
 local top=0
 for index=#renderer.state.messages,1,-1 do
  local line=renderer.state.messages[index]
  assert(line:GetHeight()==line.sunderHeight and line.sunderHeight>0)
  assert(line.text.points.TOPLEFT.relative==line,"readable text determines its own parent's height")
  assert(line.points.BOTTOMLEFT.relative==(renderer.state.messages[index+1]or renderer.slider),"pooled row retained a stale chain")
  local nextTop=top+line:GetHeight();assert(nextTop>top,"incoming rows overlap");top=nextTop
  line:Show()
 end
end
local row=renderer.state.messages[#renderer.state.messages]
local oldSecret=secret;secret="restricted message fixture"
local setWidth=row.text.SetWidth
function row.text:SetWidth(value)
 assert(self:GetText()~=secret,"restricted visible text resized without clearing")
 setWidth(self,value)
end
row:SetDisplayText(secret);row:UpdateFrame()
assert(not row.sunderHeight and row.points.TOPLEFT.relative==row.text)
row:SetDisplayText("Readable after reuse");row:UpdateFrame()
assert(row.sunderHeight and row.text.points.TOPLEFT.relative==row and not row.points.TOPLEFT)
secret=oldSecret
''')

exec(open('work/test_favorites095.py',encoding='utf-8').read())
lua.execute('''
W:ClearPreviewData();cfg.enabled=true;cfg.mode="hub";cfg.conversationLayout="list"
W:OpenMessages();W:SetMinimized(false,true);W:SetPeopleFilter("all");W:StartPreview()
local header=W:HeaderHeight()
for _,padding in ipairs({0,8,12,24}) do
 Core.db.profile.bodyPadding=padding;W:RefreshHubStyle();W:LayoutPeopleRows(true)
 assert(W:BodyPadding()==padding and W:HeaderHeight()==header,"body setting changed headers")
 local top=W:HeaderHeight()+W:HeaderGap()+32
 assert(W.previewBody.points.TOPLEFT.x==W:ConversationBodyLeft()+padding)
 assert(W.previewBody.points.TOPRIGHT.x==-Core.Components.WindowManager:ScrollRightInset(padding))
 assert(W.previewBody.points.TOPLEFT.y==-top-padding)
 assert(W.previewBody:GetHeight()==math.max(1,W.hub:GetHeight()-top-padding*2))
 assert(W.previewTabs[1].points.TOPLEFT.x==padding)
 assert(W.previewTabs[1]:GetWidth()==W:ConversationListWidth()-padding-Core.Components.WindowManager:ScrollRightInset(padding))
 W.minimizedWhispers={};local person=W.previewConversations[2]
 W:SetMinimized(true,true);W:QueueMinimizedWhisper(person,true,"Spacing test")
 local toast=W.minimizedWhisperRows and W.minimizedWhisperRows[1]
 if toast and toast:IsShown() then assert(toast.name.points.TOPLEFT.x==padding and toast.snippet.points.TOPLEFT.x==padding) end
 W:SetMinimized(false,true)
end
W:ClearPreviewData()
''')
print('Shared Whispers spacing passed at 0/8/12/24 px: sample body insets, people-list widths/alignment, resize-safe bounds and unchanged header metrics.')

# Exercise the production one-time profile migration without initializing the UI.
config=root.joinpath('Modules/Config.lua').read_text(encoding='utf-8')
migration=config[config.index('local function migrateSettings()'):config.index('local function normalizeFrameHeight()')]
lua.execute('local CURRENT_SETTINGS_VERSION=9\n'+migration+"\nspacingMigrate=migrateSettings")
lua.execute("""
local original=Core.db.profile
for _,value in ipairs({0,8,12,20,32}) do
 Core.db.profile={settingsVersion=8,bodyPadding=value}
 spacingMigrate()
 assert(Core.db.profile.bodyPadding==(value==12 and 8 or value))
 assert(Core.db.profile.settingsVersion==9)
 Core.db.profile.bodyPadding=12;spacingMigrate()
 assert(Core.db.profile.bodyPadding==12, "migration repeated after user chose 12")
end
Core.db.profile=original
""")
print('Padding migration passed: saved 12 becomes 8 once, other values and later explicit 12 are preserved.')

# Real notifications disappear on ordinary selection and visibility changes.
lua.execute("""
W:ClearPreviewData();cfg.enabled=true;cfg.mode="hub";cfg.minimizedPreviews=true
local first,firstWindow=conversation("ToastVisibilityFirst","First Last")
local second=conversation("ToastVisibilitySecond","Second Last")
W:OnWindowOpened(first);W:OnWindowOpened(second);drain()
W:MoveToWorkspace(first,"messages");W:MoveToWorkspace(second,"messages")
W:SetMinimized(true,true);W.minimizedWhispers={}
W:QueueMinimizedWhisper(first,false,"|cffff8800|Hplayer:First|h[First Last]|h|r whispers: hello: again")
W:QueueMinimizedWhisper(second,false,"Other person's message")
local entry=W.minimizedWhispers[2]
assert(entry.text=="hello: again", "native sender prefix duplicated the toaster heading")
W:SelectConversation(first,false)
assert(#W.minimizedWhispers==1 and W.minimizedWhispers[1].person==second, "queue="..#W.minimizedWhispers.." displayed="..tostring(W:IsConversationDisplayed(first)).." grouped="..tostring(W:IsGrouped(first)).." host="..W:HubFor(first).hostId.." minimized="..tostring(W:HubFor(first).minimized))
firstWindow.slidingMessageFrame.state.scrollAtBottom=false
W.minimizedWhispers[#W.minimizedWhispers+1]=entry;W:UpdateMinimizedWhispers()
assert(#W.minimizedWhispers==1, "visible scrolled-back conversation retained a stale toast")
local fmt=CHAT_WHISPER_GET;CHAT_WHISPER_GET="%s murmure : "
assert(W:WhisperToastText("[First Last] murmure : Bonjour")=="Bonjour")
CHAT_WHISPER_GET=fmt
assert(W:WhisperToastText("A plain message: with a colon")=="A plain message: with a colon")
-- Explicit selection updates native Enter ownership despite General chat focus.
local general,source=conversation("SelectionGeneralEditor","General","SAY")
local focus=source.editBox
GetCurrentKeyBoardFocus=function() return focus end
W:SelectConversation(first,false);assert(lastInput==firstWindow.editBox)
local unrelated={};focus=unrelated;lastInput=source.editBox
W:SelectConversation(first,false);assert(lastInput==source.editBox, "selection interrupted unrelated input")
focus=nil;W:SelectConversation(first,false);assert(lastInput==firstWindow.editBox)
firstWindow.replyEditBox=source.editBox
W:SelectConversation(first,false);assert(lastInput==source.editBox, "borrowed native reply editor was ignored")
firstWindow.replyEditBox=nil
GetCurrentKeyBoardFocus=nil
cfg.showOnIncoming=true;cfg.keepMessagesOpen=true;cfg.singleToasterStack=true;cfg.autoSelect=false
for _,collapsed in ipairs({false,true}) do
 W:OpenMessages();W:SelectConversation(first,false);W:SetMinimized(collapsed,true)
 W:BeginMessageWindowRestore();W.hub:Hide()
 lastInput=source.editBox;W.records[first].unread=3
 W:RestoreMessageWindows()
 assert(W.hub:IsShown() and W.minimized==collapsed and W.selected==first)
 assert(lastInput==source.editBox and W.records[first].unread==3,"startup invoked conversation selection")
 W.hub:Hide();W:SaveMessageWindowState()
 assert(Core.db.char.messageWindowStates.messages.open,"incidental hide erased the open checkpoint")
 W:QueueMinimizedWhisper(second,false,"Background conversation")
 assert(W.hub:IsShown() and W.minimized==collapsed and W.selected==first)
 assert(W.minimizedWhisperTray:IsShown() and W.minimizedWhispers[1].person==second)
end
W:CloseMessages();W:OnNativeMessage(second,ChatTypeInfo.WHISPER.id,{nil,"Closed window"})
assert(not W.hub:IsShown() and not Core.db.char.messageWindowStates.messages.open)
""")
print('Live-conversation regressions passed: selected/visible toast cleanup, other-person retention, localized body-only previews, native chat selection and unrelated input preservation.')


lua.execute("""
W:ClearPreviewData();W:OpenMessages();W:SetMinimized(false,true)
local originalGet=Core.GetModule
local history={ImportArchive=function()return {
 ["WHISPER:archived-ordinary"]={target="Archived-Ordinary",lines={{"Saved ordinary message"}},closed=true},
 ["WHISPER:archived-favorite"]={target="Archived-Favorite",lines={{"Saved favorite message"}},closed=true,favorite=true}}
 end,ArchiveKey=function(_,frame)return type(frame.chatTarget)=="string" and "WHISPER:"..frame.chatTarget:lower() end,
 OpenArchive=function(_,key)openedArchive=key end}
function Core:GetModule(name,...)if name=="WhisperTabs" then return history end return originalGet(self,name,...) end
W:SetPeopleFilter("all")
assert(#W.savedFavoriteRows>0,"closed people are not discoverable in the flat list")
local ordinary,favorite
for _,row in ipairs(W.savedFavoriteRows) do
 if row:IsShown() and row.contact.archiveKey=="WHISPER:archived-ordinary" then ordinary=row end
 if row:IsShown() and row.contact.archiveKey=="WHISPER:archived-favorite" then favorite=row end
end
assert(ordinary and favorite,"archived favorite/ordinary rows missing")
ordinary:GetScript("OnClick")(ordinary,"LeftButton")
assert(openedArchive=="WHISPER:archived-ordinary")
W:SetPeopleFilter("favorites")
assert(not ordinary:IsShown() or ordinary.contact.archiveKey~="WHISPER:archived-ordinary")
local found=false;for _,row in ipairs(W.savedFavoriteRows) do if row:IsShown() and row.contact.archiveKey=="WHISPER:archived-favorite" then found=true end end
assert(found,"closed favorite vanished from Favorites filter")
Core.GetModule=originalGet
""")
print('Archive people UI passed: closed conversations discoverable under Archived, archived favorites stay in Favorites and clicks route by stable identity.')

# Exercise the actual native-history adapter, not a parallel metadata fixture.
native=root.joinpath('Components/SlidingMessageFrameNative.lua').read_text(encoding='utf-8')
a=native.index('    hookMessage(self, self.historyBuffer, "PushBack"')
b=native.index('  self:HookChatFrameVisibility',a)
lua.execute('local captured;local self={historyBuffer={},chatFrame={GetMessageInfo=function()return "native",1,1,1,80,42,99 end}};local getReceivedAt=function()return 1234 end;local hookMessage=function(_,_,_,fn)captured=fn end;function self:BackFillMessageAt(...) nativeBackfill={...}end;'+native[a:b].rsplit('  end',1)[0]+' captured(nil,{message="native",r=1,g=1,b=1});assert(nativeBackfill[7]==80 and nativeBackfill[8]==42 and nativeBackfill[9]==99,"native backfill dropped direction/type metadata")')

# Live inserts without native time acquire one receipt. Reads later retain it.
start=native.index('  if self.historyBuffer and type(self.historyBuffer.PushFront)')
stop=native.index('  if self.historyBuffer and not self.state.isCombatLog',start)
lua.execute('''local captured
local self={historyBuffer={PushFront=function()end}}
local hookMessage=function(_,_,_,fn)captured=fn end
local getReceivedAt=vars[3].getMessageReceipt
local clock=1700000000
local GetServerTime=function()return clock end
'''+native[start:stop]+'''
local entry={}
captured(nil,entry)
clock=clock+14400
assert(getReceivedAt(entry)==1700000000)
local known={serverTime=1234}
captured(nil,known)
assert(getReceivedAt(known)==1234)
''')

lua.execute('''
local f=CreateFrame("Frame",nil,UIParent)
f.sharedFullSurface=true;f.config={height=100,overflowHeight=0}
f.state={scrollAtBottom=true,scrollIndex=1,messages={{sunderHeight=160},{sunderHeight=40},{sunderHeight=80}}}
f.UpdatePinnedDate=function()end
f.RevealScrollHistory=Core.Components.SlidingMessageFrameMixin.RevealScrollHistory
function f:CancelMessageHideTimer(clear)self.clearedFade=clear end
for _,row in ipairs(f.state.messages)do
 row.shown=false
 function row:Show()self.shown=true end
end
f.UpdateViewportHeight=Core.Components.SlidingMessageFrameMixin.UpdateViewportHeight
local wm=Core.Components.WindowManager;local extent=wm.UpdateContentExtent;wm.UpdateContentExtent=function()end
local pad=Core.db.profile.bodyPadding;Core.db.profile.bodyPadding=0
function f:SetScrollPosition(index,offset)
 self.state.scrollIndex=index;self.state.messageOffset=offset
 self.state.scrollAtBottom=index==1 and offset==0
 self:UpdateViewportHeight(20)
end
f.overlay={GetUnreadRowHeight=function()return 20 end}
f:UpdateViewportHeight()
local rail=f.scrollRail
local height,thumb=rail:GetHeight(),rail.thumb:GetHeight()
local function stable()assert(rail:GetHeight()==height and rail.thumb:GetHeight()==thumb and rail.maximum==200,"rail jumped at latest")end
stable();assert(rail.thumbOffset>0)
mouseDown=true;cursorY=rail:GetTop()
rail:GetScript("OnMouseDown")(rail,"LeftButton");rail:GetScript("OnUpdate")(rail)
assert(f.state.scrollIndex==3 and f.state.messageOffset==80,"drag to top missed start of wrapped row")
assert(f.clearedFade,"pointer scrolling did not cancel history fading")
for _,row in ipairs(f.state.messages)do assert(row.shown,"thumb moved but faded history remained invisible")end
cursorY=rail:GetTop()-rail:GetHeight();rail:GetScript("OnUpdate")(rail)
assert(f.state.scrollAtBottom and f.state.messageOffset==0)
stable()
local bottom=rail.thumbOffset
rail:GetScript("OnUpdate")(rail)
assert(rail.thumbOffset==bottom and f.state.scrollAtBottom,"held pointer bounced into readback")
mouseDown=false;rail:GetScript("OnUpdate")(rail);assert(not rail:GetScript("OnUpdate"))
local wheel=Core.Components.SlidingMessageFrameMixin.ScrollTranscriptWheel
wheel(f,1);assert(not f.state.scrollAtBottom)
stable();wheel(f,-1);assert(f.state.scrollAtBottom);stable()
f.state.messages={{sunderHeight=12}};f:UpdateViewportHeight()
wheel(f,1);assert(not rail.thumb:IsShown() and f.state.scrollAtBottom)
wm.UpdateContentExtent=extent;Core.db.profile.bodyPadding=pad
''')

# Exercise a real registered grip and the common layout at unequal UI scales.
lua.execute('''
local wm=Core.Components.WindowManager
local root=CreateFrame("Frame",nil,UIParent);root:SetSize(300,200)
local grip=wm:CreateWindowResizer(root,{})
assert(root.windowResizeGrip==grip)
function grip:GetRect()
 local _,_,_,dx,dy=self:GetPoint()
 return 300+dx-self:GetWidth(),dy,self:GetWidth(),self:GetHeight()
end
local pane=CreateFrame("Frame",nil,root)
local owner=CreateFrame("Frame",nil,pane)
function owner:GetEffectiveScale()return .8 end
local bottom,width=0,375
function owner:GetRect()return 0,bottom,width,200 end
local function refresh()
 return wm:UpdateScrollRail(owner,true,200,600,200,0,function()end)
end
local rail=refresh()
local function railBottom()return (bottom+200-4-rail:GetHeight())*.8 end
local _,gripBottom,_,gripHeight=grip:GetRect()
assert(railBottom()>gripBottom+gripHeight,"rail hit box crosses corner grip")
local available=rail:GetHeight()
refresh();assert(rail:GetHeight()==available)
width=140;refresh();assert(rail:GetHeight()==192,"left member rail lost height")
width=375;bottom=50;refresh();assert(rail:GetHeight()==192,"editor already clears the corner")
''')

lua.execute('''
local wm=Core.Components.WindowManager
local root=CreateFrame("Frame",nil,UIParent);root:SetSize(300,200)
local grip=wm:CreateWindowResizer(root,{})
local surface=wm:ApplySurface(root,{bottomExtent=70})
local _,relative=grip:GetPoint()
assert(relative==surface.frame,"early native grip remained anchored above the extended body")
wm:ApplySurface(root,{bottomExtent=120})
local _,anchor=grip:GetPoint()
assert(anchor==surface.frame and surface.bottomExtent==120,"grip failed to follow editor growth")
''')

lua.execute("""
local wm=Core.Components.WindowManager
local m=getmetatable(UIParent).__index
function m:EnableKeyboard(value)self.keyboardEnabled=value end
function m:SetPropagateKeyboardInput(value)self.propagates=value end
local view=CreateFrame("Frame",nil,UIParent);view:Show()
local pages=0;wm:RegisterTranscriptKeys(view,function(direction)pages=pages+direction end)
local driver=wm.keyboardDriver
function driver:SetPropagateKeyboardInput(value)self.propagates=value end
local oldMouse,oldFocus,oldCombat=MouseIsOver,GetCurrentKeyBoardFocus,InCombatLockdown
MouseIsOver=nil -- Removed native global must not be required.
function view:IsMouseOver()return true end
InCombatLockdown=function()return false end
GetCurrentKeyBoardFocus=function()return nil end
local key=driver:GetScript("OnKeyDown")
local oldRouter=wm.KeyboardTranscript
wm.KeyboardTranscript=function()error("ordinary key entered transcript routing")end
key(driver,"W");assert(driver.propagates,"movement key was swallowed")
wm.KeyboardTranscript=oldRouter
key(driver,"PAGEUP");assert(pages==-1 and not driver.propagates)
key(driver,"PAGEDOWN");assert(pages==0 and not driver.propagates)
GetCurrentKeyBoardFocus=function()return {}end
key(driver,"PAGEUP");assert(pages==0 and driver.propagates,"paging stole a text field key")
GetCurrentKeyBoardFocus=function()return nil end;view:Hide()
key(driver,"PAGEUP");assert(pages==0,"hidden transcript retained keys")
local oldGet=Core.GetModule;wm.keyboardTranscript=nil
function Core:GetModule(name,...)if name=="UIManager"then return {GetSlidingMessageFrame=function()return view end}end;return oldGet(self,name,...)end
view.IsMouseOver=function()return false end;view:Show()
key(driver,"PAGEUP");assert(pages==-1 and not driver.propagates,"native selected chat was not used without hover")
Core.GetModule=oldGet
MouseIsOver,GetCurrentKeyBoardFocus,InCombatLockdown=oldMouse,oldFocus,oldCombat
""")

# Execute the production native adapter against independently interactive children.
native_source=root.joinpath('Components/SlidingMessageFrameNative.lua').read_text(encoding='utf-8')
lua.execute('local Core=unpack(select(2,...));local SlidingMessageFrameMixin=Core.Components.SlidingMessageFrameMixin\n'+native_source[native_source.index('function SlidingMessageFrameMixin:DisableNativeScrollInput'):native_source.index('function SlidingMessageFrameMixin:ConfigureNativeLayout')], 'Sunder',lua.globals().vars)
lua.execute("""
local function control()
 return {click=true,motion=true,wheel=true,
 SetMouseClickEnabled=function(self,v)self.click=v end,
 SetMouseMotionEnabled=function(self,v)self.motion=v end,
 EnableMouse=function(self,v)self.mouse=v end,
 EnableMouseWheel=function(self,v)self.wheel=v end}
end
local native={ScrollBar=control(),ScrollToBottomButton=control(),filters=control()}
native.ScrollBar.Track=control();native.ScrollBar.Track.Thumb=control()
native.ScrollBar.Back=control();native.ScrollBar.Forward=control()
local renderer=CreateFrame("Frame",nil,UIParent);renderer:Show();renderer.chatFrame=native
for k,v in pairs(Core.Components.SlidingMessageFrameMixin)do renderer[k]=v end
renderer:DisableNativeScrollInput(native)
for _,part in ipairs({native.ScrollBar,native.ScrollBar.Track,native.ScrollBar.Track.Thumb,native.ScrollBar.Back,native.ScrollBar.Forward,native.ScrollToBottomButton})do
 assert(part.click==false and part.motion==false and part.mouse==false and part.wheel==false,"invisible native scroll child still receives input")
end
assert(native.filters.click,"native filters were disabled")
native.ScrollBar.Track.Thumb.click=true;renderer:DisableNativeScrollInput(native)
assert(not native.ScrollBar.Track.Thumb.click,"native refresh restored competing input")
local hooks={};function renderer:SecureHook(_,method,callback)hooks[method]=callback end
function native:PageUp()end;function native:PageDown()end
renderer:BridgeNativePaging(native)
local wm=Core.Components.WindowManager;local oldViews,oldActive=wm.keyboardViews,wm.keyboardTranscript
local oldMouse,oldFocus=MouseIsOver,GetCurrentKeyBoardFocus
MouseIsOver=function()return false end;GetCurrentKeyBoardFocus=function()return nil end
local moved=0;wm.keyboardViews={[renderer]=function(direction)moved=moved+direction end};wm.keyboardTranscript=nil
hooks.PageUp();assert(moved==-1,"native page binding did not reach replacement content")
hooks.PageDown();assert(moved==0)
GetCurrentKeyBoardFocus=function()return {}end;hooks.PageUp();assert(moved==0,"native bridge stole editing input")
renderer.chatFrame={};GetCurrentKeyBoardFocus=function()return nil end;hooks.PageUp();assert(moved==0,"recycled renderer accepted old native input")
wm.keyboardViews,wm.keyboardTranscript=oldViews,oldActive;MouseIsOver,GetCurrentKeyBoardFocus=oldMouse,oldFocus
""")

# Combat Log uses native rows/history/offset, through the actual UI factory and
# detached refresh. Model native layout/refilter callbacks, not a second renderer.
lua.execute('''
function Mixin(target,...)for _,source in ipairs({...})do for key,value in pairs(source)do target[key]=value end end;return target end
Core.Libs.AceHook={Embed=function(_,target)
 target.hooks={}
 function target:SecureHook(owner,method,after)
  local original=owner[method]
  owner[method]=function(...)local result=original(...);after(...);return result end
 end
 function target:RawHook(owner,method,replacement)
  self.hooks[owner]=self.hooks[owner]or {};self.hooks[owner][method]=owner[method];owner[method]=replacement
 end
 function target:SecureHookScript(owner,script,after)owner:HookScript(script,after)end
 return target
end}
Core.Components.CreateChatTab=function(renderer,parent)local tab=CreateFrame("Button",nil,parent);tab.chatFrame=renderer.chatFrame;return tab end
Core.Components.CreateDetachedChatDock=function(parent,tab)
 local dock=CreateFrame("Frame",nil,parent);dock:SetHeight(20);dock.tab=tab
 function dock:SetTab(value)self.tab=value end;return dock
end
function ui.container:AddHoverRegion()end
local m=getmetatable(UIParent).__index
function m:SetFrameLevel(value)self.frameLevel=value end
function m:GetFrameStrata()return "MEDIUM" end
function m:GetFrameLevel()return self.frameLevel or 2 end
function m:SetFrameStrata(value)self.frameStrata=value end
function m:GetFrameStrata()return self.frameStrata or "MEDIUM" end
function m:SetMouseClickEnabled(value)self.click=value end
function m:SetMouseMotionEnabled(value)self.motion=value end
function m:SetHyperlinksEnabled(value)self.hyperlinks=value end
function m:EnableMouse(value)self.mouse=value end
function m:EnableMouseWheel(value)self.wheel=value end
function m:GetWidth()
 if self.width then return self.width end
 local p=self.parent and self.parent:GetWidth()or 500
 local t,b=self.points.TOPLEFT,self.points.BOTTOMRIGHT
 return p-(t and t.x or 0)+(b and b.x or 0)
end
nativeConfigListeners={}
function Core:Subscribe(event,callback)nativeConfigListeners[event]=nativeConfigListeners[event]or {};table.insert(nativeConfigListeners[event],callback);return {}end
function sendNativeConfig(event,value)for _,callback in ipairs(nativeConfigListeners[event]or {})do callback(value)end end
Constants.EVENTS.EDIT_BOX_LAYOUT_CHANGED="editor-layout"
Constants.EVENTS.EDIT_BOX_VISIBILITY_CHANGED="editor-visibility"
function nativeCombatFixture()
 local frame=CreateFrame("Frame","ChatFrame2",UIParent);frame:SetSize(460,250)
 frame.FontStringContainer=CreateFrame("Frame",nil,frame)
 frame.ScrollBar=CreateFrame("Frame",nil,frame);frame.ScrollBar.Track=CreateFrame("Frame",nil,frame.ScrollBar)
 frame.ScrollBar.Track.Thumb=CreateFrame("Button",nil,frame.ScrollBar.Track)
 frame.ScrollToBottomButton=CreateFrame("Button",nil,frame)
 frame.count=100;frame.offset=0;frame.visibleLines={};frame.callbacks={};frame.nativeNotifications=0
 function frame:GetMaxScrollRange()return math.max(0,self.count-1)end
 function frame:GetScrollOffset()return self.offset end
 function frame:SetScrollOffset(value)self.offset=math.max(0,math.min(self:GetMaxScrollRange(),value));self.nativeNotifications=self.nativeNotifications+1 end
 function frame:GetPagingScrollAmount()return math.max(1,#self.visibleLines-1)end
 function frame:CalculateLineSpacing()return self.lineSpacing or 12 end
 function frame:CalculateNumVisibleLines()return math.ceil(self:GetHeight()/self:CalculateLineSpacing())+1 end
 function frame:RefreshLayout()
  self.visibleLines={}
  for index=1,self:CalculateNumVisibleLines()do
   local row=self.FontStringContainer:CreateFontString();row:SetWidth(self:GetWidth());row:SetPoint("BOTTOMLEFT",self,"BOTTOMLEFT")
   self.visibleLines[index]=row
  end
  self.layoutPasses=(self.layoutPasses or 0)+1
 end
 function frame:GetInsertMode()return 2 end
 function frame:MarkLayoutDirty()self.dirty=true end
 function frame:ResetAllFadeTimes()self.fadeResets=(self.fadeResets or 0)+1 end
 function frame:AddOnDisplayRefreshedCallback(callback)table.insert(self.callbacks,callback)end
 function frame:Display()if self.dirty then self.dirty=false;self:RefreshLayout()end;for _,callback in ipairs(self.callbacks)do callback()end end
 function frame:ScrollByAmount(delta)self:SetScrollOffset(self.offset+delta);self:ResetAllFadeTimes()end
 function frame:PageUp()self:ScrollByAmount(self:GetPagingScrollAmount())end
 function frame:PageDown()self:ScrollByAmount(-self:GetPagingScrollAmount())end
 function frame:SetFading(value)self.fading=value end
 function frame:SetScrollAllowed(value)self.allowScroll=value end
 function frame:SetClampRectInsets(...)self.clampInsets={...}end
 function frame:SetMaxLines(value)self.maximumLines=value end
 frame.nativeShows=0
 frame:SetScript("OnShow",function(self)self.nativeShows=self.nativeShows+1 end)
 return frame
end
''')
lua.execute(root.joinpath('Components/SlidingMessageFrame.lua').read_text(encoding='utf-8'),'Sunder',lua.globals().vars)
lua.execute(root.joinpath('Components/SlidingMessageFrameNative.lua').read_text(encoding='utf-8'),'Sunder',lua.globals().vars)
lua.execute(root.joinpath('Components/SlidingMessageFrameLayout.lua').read_text(encoding='utf-8'),'Sunder',lua.globals().vars)
lua.execute(root.joinpath('Components/NativeCombatLog.lua').read_text(encoding='utf-8'),'Sunder',lua.globals().vars)
lua.execute(root.joinpath('Modules/UIManager.lua').read_text(encoding='utf-8'),'Sunder',lua.globals().vars)
lua.execute('''
local native=nativeCombatFixture()
ui.state.windows={};ui.slidingMessageFramePool={Acquire=function()error("Combat Log acquired a replacement row pool")end}
Core.db.profile.frameWidth=460;Core.db.profile.frameHeight=270;Core.db.profile.combatLogHidden=false
Core.db.profile.scrollbackLines=500
Core.db.profile.editBoxAnchor={position="BELOW",yOfs=-2}
local window=ui:CreateChatWindow(native,false)
local adapter=window.slidingMessageFrame
assert(adapter.nativeCombatLog and not adapter.messageFramePool and not adapter.slider)
assert(native.FontStringContainer:GetParent()==adapter.viewport and adapter.viewport.clipsChildren)
ui.GetLayoutEditBox=function()return false end
ui:RefreshChatFrameLayout(native)
local root=window.detachedLayout.container
root:SetSize(460,270);native:Display()
assert(native.visibleLines[1].points.BOTTOMLEFT.relative==adapter.viewport,"native glyphs anchored outside viewport")
assert(native.visibleLines[1]:GetWidth()==adapter.viewport:GetWidth())
local liveLine=native.visibleLines[1]
liveLine:SetText("restricted native glyphs")
local nativeSetWidth=liveLine.SetWidth
function liveLine:SetWidth(value)
 assert(self:GetText()~="restricted native glyphs","held resize mutated live restricted text geometry")
 nativeSetWidth(self,value)
end
root:SetWidth(440);native:Display();root:SetWidth(460);native:Display()
assert(adapter.scrollRail:GetFrameLevel()>native:GetFrameLevel(),"native input covers shared rail")
root.windowResizeGrip=CreateFrame("Button",nil,root)
root.windowResizeGrip:SetSize(24,24)
native:SetFrameStrata("DIALOG");native.FontStringContainer:SetFrameLevel(200)
adapter:RefreshLayoutGeometry()
assert(native:GetFrameStrata()==root:GetFrameStrata(),"native frame escaped shell input strata")
assert(root.windowResizeGrip:GetFrameStrata()==native:GetFrameStrata())
assert(root.windowResizeGrip:GetFrameLevel()>native.FontStringContainer:GetFrameLevel(),"native glyph container covers resize grip")
assert(not native.ScrollBar.Track.Thumb.click and native.ScrollBar:GetAlpha()==0)
native.ScrollBar:Show();native.ScrollBar:SetAlpha(1);native.ScrollToBottomButton:Show()
assert(not native.ScrollBar:IsVisible() and not native.ScrollToBottomButton:IsVisible(),"native refresh resurrected retired scrollbar chrome")
assert(native.allowScroll and native:GetAlpha()==1)
assert(not native.mouse and not native.wheel and not native.click and not native.motion,
 "native geometry frame still owns pointer input over the shared grip")
assert(adapter.viewport.mouse and adapter.viewport.wheel and adapter.viewport.hyperlinks,
 "native content lost its bounded input receiver")
for _,inset in ipairs(native.clampInsets)do assert(inset==0,"legacy native clamp inset retained")end
native:EnableMouse(true);native:EnableMouseWheel(true);native:SetMouseClickEnabled(true);native:SetMouseMotionEnabled(true)
adapter:RefreshLayoutGeometry()
assert(not native.mouse and not native.wheel and not native.click and not native.motion,
 "native refresh restored competing whole-frame pointer input")
assert(native.maximumLines==500,"native host ignored saved scrollback preference")
local linkReceiver,linkValue
native:SetScript("OnHyperlinkClick",function(frame,value)linkReceiver,linkValue=frame,value end)
adapter.viewport:GetScript("OnHyperlinkClick")(adapter.viewport,"spell:123","native text","LeftButton")
assert(linkReceiver==native and linkValue=="spell:123","hosted native links lost their receiver")
local thumb=adapter.scrollRail.thumb:GetHeight()
adapter.scrollRail.writeOffset(adapter,0)
assert(native:GetScrollOffset()==99 and native.nativeNotifications>0 and native.fadeResets>0)
native:PageDown();assert(adapter.scrollRail.offset==99-native:GetScrollOffset(),"native binding and rail diverged")
adapter:PageTranscript(-1);assert(native:GetScrollOffset()==99)
adapter:GetScript("OnMouseWheel")(adapter,-3);assert(native:GetScrollOffset()==96)
adapter.viewport:GetScript("OnMouseWheel")(adapter.viewport,-2)
assert(native:GetScrollOffset()==94,"bounded viewport wheel did not reach native scroll state exactly once")
adapter.scrollRail.writeOffset(adapter,99)
assert(native:GetScrollOffset()==0 and adapter.scrollRail.thumb:GetHeight()==thumb,"thumb changed size at newest")
-- Execute real rail press/held-drag/release, not only its write callback.
cursorY=adapter.scrollRail:GetTop()-adapter.scrollRail:GetHeight()/2;mouseDown=true
adapter.scrollRail:GetScript("OnMouseDown")(adapter.scrollRail,"LeftButton")
assert(native:GetScrollOffset()>0 and native:GetScrollOffset()<99)
cursorY=adapter.scrollRail:GetTop()-adapter.scrollRail:GetHeight()
adapter.scrollRail:GetScript("OnUpdate")(adapter.scrollRail)
assert(native:GetScrollOffset()==0)
adapter.scrollRail:GetScript("OnMouseUp")(adapter.scrollRail)
assert(not adapter.scrollRail:GetScript("OnUpdate"))
local editor={height=32,shown=false,GetHeight=function(self)return self.height end,
 SetSunderParent=function(self,parent)self.sunderParent=parent end,
 GetReusableMessageHeight=function(self)return self.shown and 0 or self.height+2 end}
ui.GetLayoutEditBox=function()return editor end
for _,padding in ipairs({0,8,19})do
 Core.db.profile.bodyPadding=padding
 ui:RefreshChatFrameLayout(native)
 root:SetSize(380,220);native:Display()
 assert(adapter.viewport:GetWidth()==380-padding-Core.Components.WindowManager:ScrollRightInset(padding))
 local top=Core.Components.SlidingMessageFrameHelpers.getMessageTopInset(true)
 assert(adapter:GetHeight()==220-top,"closed editor grew native content")
 editor.shown=true;editor.height=55
 sendNativeConfig("editor-layout");native:Display()
 assert(adapter:GetHeight()==220-top-57,"editor grew outside the root")
 native.lineSpacing=24;native:MarkLayoutDirty();native:Display()
 assert(#native.visibleLines==math.ceil(adapter.viewport:GetHeight()/24)+1)
 editor.shown=false
end
-- Refilter changes native history; display callback updates the same rail.
native.count=1;native:SetScrollOffset(0);native:Display()
assert(not adapter.scrollRail.thumb:IsShown() and not adapter.scrollRail.mouse)
native.count=80;native:Display();assert(adapter.scrollRail.thumb:IsShown())
native:Hide();assert(not adapter:IsShown() and not adapter.scrollRail:IsShown())
native:Show();assert(adapter:IsShown() and native.nativeShows==1,"native OnShow replaced or replayed")
-- Return to main, then detach again: no ancestor cycle or stale shell visibility.
native.isDocked=true;ui:RefreshChatFrameLayout(native);native:Display()
assert(not root:IsShown() and adapter:GetParent()==ui.container)
assert(native:GetParent()==UIParent)
native:SetPoint("TOPLEFT",UIParent,"TOPLEFT",999,-999)
assert(native.points.TOPLEFT.relative==ui.container,"native dock refresh displaced hosted content")
native.isDocked=false;ui:RefreshChatFrameLayout(native);native:Display()
assert(root:IsShown() and adapter:GetParent()==root)
Core.db.profile.combatLogHidden=true;adapter:ApplyCombatLogVisibility()
assert(native:IsShown() and not adapter:IsShown(),"visibility setting invoked native filter lifecycle")
Core.db.profile.combatLogHidden=false;adapter:ApplyCombatLogVisibility()
assert(adapter:IsShown() and native.nativeShows==1)
assert(not adapter:GetScript("OnUpdate") and not adapter.scrollRail:GetScript("OnUpdate"),"adapter retained idle frame work")
assert(not Core.Components.CanHostNativeCombatLog(CreateFrame("Frame")),"ordinary chat selected native Combat adapter")
nativeResizeFixture={native=native,root=root,adapter=adapter}
''')

lua.execute(root.joinpath('Components/ResizeHandle.lua').read_text(encoding='utf-8'),'Sunder',lua.globals().vars)
detached_source=root.joinpath('Components/DetachedChatDock.lua').read_text(encoding='utf-8')
resize_callbacks=detached_source[detached_source.index('  local resizeOptions = {'):detached_source.index('  overlay:Hide()',detached_source.index('  local resizeOptions = {'))]
lua.execute('''
local Core,Constants=unpack(select(2,...))
local f=nativeResizeFixture
local parent=f.root;local overlay=CreateFrame("Frame",nil,parent)
overlay:SetFrameStrata("DIALOG")
local settings={}
local self={tab={chatFrame=f.native},StopWindowDrag=function()end,WindowSettings=function()return settings end}
function f.native:IsProtected()return false end
-- Resolve anchored geometry without synthesizing an OnSizeChanged on the shell.
-- This reproduces the missing notification that the old callback-only path relied on.
function parent:GetWidth()return f.native:GetWidth()end
function parent:GetHeight()return f.native:GetHeight()+Constants.DOCK_HEIGHT end
''' + resize_callbacks + '''
f.adapter:RefreshLayoutGeometry()
for _,handle in ipairs({self.roomResize,self.resizeHandle})do
 mouseDown=true;cursorX,cursorY=100,100
 local width,height=f.native:GetWidth(),f.native:GetHeight()
 handle:GetScript("OnMouseDown")(handle,"LeftButton")
 assert(handle.resizeState and handle:GetScript("OnUpdate"),"native host resize never starts")
 cursorX,cursorY=160,60;handle:GetScript("OnUpdate")(handle)
 assert(f.native:GetWidth()==width+60 and f.native:GetHeight()==height+40,"held native size did not change")
 assert(f.adapter:GetWidth()==parent:GetWidth(),"viewport lagged held resize without a shell notification")
 local pad=Core.Components.WindowManager:BodyPadding()
 assert(f.adapter.viewport:GetWidth()==parent:GetWidth()-pad-Core.Components.WindowManager:ScrollRightInset(pad),"clipped display width lagged resize")
 local railHeight=f.adapter.scrollRail:GetHeight();f.adapter:UpdateScrollRail()
 assert(f.adapter.scrollRail:GetHeight()==railHeight and railHeight>0 and railHeight<=f.adapter:GetHeight()-8,"rail needed a later refresh after held resize")
 assert(f.adapter.scrollRail.points.TOPRIGHT.relative==f.adapter,"rail lost its resized content anchor")
 local offset=f.native:GetScrollOffset();f.native:Display();assert(f.native:GetScrollOffset()==offset,"resize lost native readback")
 local layoutWidth=f.adapter.layoutWidth;f.native.isDocked=true
 Core:GetModule("UIManager"):RefreshDetachedLayoutSize(Core:GetModule("UIManager"):GetChatWindow(f.native),123,123)
 assert(f.adapter.layoutWidth==layoutWidth,"stale detached notification resized a docked renderer")
 f.native.isDocked=false
 assert(self.roomResize:GetFrameLevel()>f.native.FontStringContainer:GetFrameLevel())
 handle:GetScript("OnMouseUp")(handle,"LeftButton")
 assert(not handle.resizeState and not handle:GetScript("OnUpdate"))
 settings.movementLocked=true;handle:GetScript("OnMouseDown")(handle,"LeftButton")
 assert(not handle.resizeState,"native resize bypassed geometry lock")
 settings.movementLocked=false
end
''','Sunder',lua.globals().vars)
