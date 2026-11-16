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
assert(f.roomScrollTrack:GetHeight()==200,"rail waited for deferred history layout")
assert(f.state.scrollIndex==7 and f.state.layoutRefreshPending,"geometry update disturbed readback or pending reflow")
nextWidth,nextHeight=720,310;f:RefreshLayoutGeometry()
assert(f:GetWidth()==720 and f.roomScrollTrack:GetHeight()==270 and f.overlay.updated)
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
row:UpdateFrame();assert(row.sunderLayoutWidth==220 and row.text:GetWidth()==204)
owner.widthNow=140;row:UpdateFrame();assert(row.text:GetWidth()==124)
Core.db.profile.bodyPadding=0;row:UpdateFrame();assert(row.text:GetWidth()==134,"room scrollbar clearance lost at zero padding")
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
function renderer:SetSlideOffset()end
renderer.gapBackground=CreateFrame("Frame",nil,renderer)
renderer.overlay=CreateFrame("Frame",nil,renderer);renderer.overlay.UpdateFrame=function()end
renderer:InitializeScrollFrame()
assert(renderer.slider:GetParent()==renderer.viewport and renderer.viewport:GetParent()==renderer)
local row=renderer.messageFramePool:Acquire()
assert(row.sunderRenderer==renderer,"native pool did not bind explicit owner")
row:SetDisplayText("[Party] Player: "..string.rep("A long linked quest message ",15))
Core.db.profile.bodyPadding=8;row:UpdateFrame()
assert(row:GetWidth()==220 and row.text:GetWidth()==204 and row.sunderHeight>12,"actual viewport hierarchy lost wrapping width/height")
assert(row.text.wordWrap and row.text.nonSpaceWrap and row.text.maxLines==0)
renderer.widthNow=140;row:UpdateFrame();assert(row.text:GetWidth()==124 and row.sunderHeight>24)
renderer.messageFramePool:Release(row)
local recycled=renderer.messageFramePool:Acquire();assert(recycled==row and recycled.sunderRenderer==renderer)
assert(not pcall(Core.Components.CreateMessageLinePool,renderer.slider),"ownerless pool silently falls back to General")
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
local wide=rows[1].text:GetWidth();view:SetWidth(140);view:Render()
assert(rows[1].text:GetWidth()<wide,"archive did not reflow on resize")
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
