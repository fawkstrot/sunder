exec(open('work/test_whispers.py',encoding='utf-8').read())
lua.execute('''
local m=getmetatable(UIParent).__index
function m:SetGradient(direction,bottom,top)self.gradient={direction,bottom,top}end
function m:SetIndentedWordWrap()end
function m:GetLineHeight()return 12 end
function m:GetStringHeight()return 24 end
function m:ClearText()self.text=""end
function CreateColor(r,g,b,a)return {r=r,g=g,b=b,a=a}end
Core.Components.SlidingMessageFrameMixin={};Core.Components.SlidingMessageFrameHelpers={getMessageTopInset=function()return 20 end}
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
row:UpdateFrame();assert(row.text:GetWidth()==476 and row.text.points.BOTTOMLEFT.x==12)
Core.db.profile.bodyPadding=8
row:UpdateFrame();assert(row.text:GetWidth()==484 and row.text.points.BOTTOMLEFT.x==8)
Core.db.profile.bodyPadding=20
row:UpdateFrame();assert(row.text:GetWidth()==460 and row.text.points.BOTTOMLEFT.x==20)
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
assert(root.windowSurface.bodyFrame:GetHeight()==root:GetHeight()-layout.dock:GetHeight())
assert(renderer.widthChanges==1 and renderer.state.messageOffset==8)
root:SetHeight(140);assert(renderer.widthChanges==1,"height-only drag queued a text pass")
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
Core.Components.CreateMessageLinePool=create;Core.GetModule=old
""")
print('Shared native spacing passed: equal side insets, top/bottom viewport spacing, bounded tiny layouts, live wrapping updates and no top-shade renderer.')

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
f.UpdateViewportHeight=Core.Components.SlidingMessageFrameMixin.UpdateViewportHeight
local wm=Core.Components.WindowManager;local extent=wm.UpdateContentExtent;wm.UpdateContentExtent=function()end
local pad=Core.db.profile.bodyPadding;Core.db.profile.bodyPadding=0
function f:SetScrollPosition(index,offset)
 self.state.scrollIndex=index;self.state.messageOffset=offset
 self.state.scrollAtBottom=index==1 and offset==0
 self:UpdateViewportHeight(20)
end
f:UpdateViewportHeight()
local rail=f.scrollRail
assert(rail.maximum==180 and rail.thumbOffset>0)
mouseDown=true;cursorY=rail:GetTop()
rail:GetScript("OnMouseDown")(rail,"LeftButton");rail:GetScript("OnUpdate")(rail)
assert(f.state.scrollIndex==3 and f.state.messageOffset==80,"drag to top missed start of wrapped row")
cursorY=rail:GetTop()-rail:GetHeight();rail:GetScript("OnUpdate")(rail)
assert(f.state.scrollAtBottom and f.state.messageOffset==0)
mouseDown=false;rail:GetScript("OnUpdate")(rail);assert(not rail:GetScript("OnUpdate"))
local wheel=Core.Components.SlidingMessageFrameMixin.ScrollTranscriptWheel
wheel(f,1);assert(not f.state.scrollAtBottom)
wheel(f,-1);assert(f.state.scrollAtBottom)
f.state.messages={{sunderHeight=12}};f:UpdateViewportHeight()
wheel(f,1);assert(not rail.thumb:IsShown() and f.state.scrollAtBottom)
wm.UpdateContentExtent=extent;Core.db.profile.bodyPadding=pad
''')
