exec(open('work/test_favorites095.py',encoding='utf-8').read())
lua.execute("""
G={};local oldGet=Core.GetModule
function Core:GetModule(name,...)if name=="GuildChat" then return G end return oldGet(self,name,...)end
local m=getmetatable(UIParent).__index
function m:GetStringWidth()return #(self:GetText() or "")*7 end
function m:GetStringHeight()return math.max(1,math.ceil(#(self:GetText() or "")/math.max(1,self:GetWidth()/7)))*14 end
function m:SetFrameLevel(value)self.frameLevel=value end
function m:GetFrameLevel()return self.frameLevel or 2 end
-- Native width/height setters do not freeze the opposite anchored dimension.
function m:SetWidth(value)local change=self.width~=value;self.width=value;if change and self.scripts.OnSizeChanged then self.scripts.OnSizeChanged(self)end end
function m:SetHeight(value)local change=self.height~=value;self.height=value;if change and self.scripts.OnSizeChanged then self.scripts.OnSizeChanged(self)end end
function m:SetAutoFocus(v)self.autoFocus=v end
function m:SetMaxLetters(v)self.maxLetters=v end
function m:SetTextInsets(...)self.textInsets={...}end
function m:ClearFocus()self.focus=false end
function m:SetChatType(v)self.inputType=v end
function m:SetStickyType(v)self.stickyType=v end
function m:GetID()return self.id end
function m:RegisterEvent(event)self.events=self.events or {};self.events[event]=true end
function m:SetHyperlinksEnabled(v)self.linksEnabled=v end
function m:SetIndentedWordWrap()end
function m:GetNumMessages()return #(self.history or {})end
function m:GetMessageInfo(i)local e=self.history[i];return e.text,e.r or 1,e.g or 1,e.b or 1,e.typeID end
function m:Clear()self.history={}end
function m:BackFillMessage(value,r,g,b,typeID)table.insert(self.history,1,{text=value,r=r,g=g,b=b,typeID=typeID})end
function m:RemoveAllMessageGroups()self.groups={}end
function m:AddMessageGroup(group)self.groups[group]=true end
function m:RemoveAllChannels()self.channels={}end
function ui:CreateDetachedLayout(window)
 local frame=window.chatFrame;local container=CreateFrame("Frame",nil,UIParent)
 function container:GetWidth()return frame:GetWidth()end
 function container:GetHeight()return frame:GetHeight()+Constants.DOCK_HEIGHT end
 local dock=CreateFrame("Frame",nil,container)
 function dock:QuickShow()self:Show()end
 function dock:SetTab(tab)tab:SetParent(self)end
 dock:SetTab(window.tab);window.detachedLayout={container=container,dock=dock};return window.detachedLayout
end
NUM_CHAT_WINDOWS=10;nativeNames={};openCalls=0
function FCF_GetChatWindowInfo(id)return nativeNames[id]end
function FCF_SavePositionAndDimensions()savedGeometry=true end
function FCF_OpenNewWindow(name,noDefaults)
 openCalls=openCalls+1;assert(noDefaults==true)
 local frame,window=conversation("ChatFrame3",name,"GUILD")
 frame.isTemporary=false;frame.id=3;frame.groups={SAY=true};frame.channels={General=true};frame.history={}
 frame.historyBuffer={GetEntryAtIndex=function(_,i)return frame.history[#frame.history-i+1]end}
 nativeNames[3]=name;lastInput=window.editBox
 return frame,3
end
currentGuildName="Test Guild"
function GetGuildInfo()return currentGuildName end
function GetRealmName()return "Forever"end
roster={
 {"Zara Ember","Guild Master",0,60,"Mage","City","Keeps the hearth warm","OFFICER SECRET",true,0,"MAGE"},
 {"Anne Vale","Officer",1,60,"Priest","Forest","Alchemy specialist","OFFICER SECRET",true,1,"PRIEST"},
 {"Bob Stone","Officer",1,60,"Warrior","City","Tank","OFFICER SECRET",true,2,"WARRIOR"},
 {"Offline Leader","Guild Master",0,60,"Mage","City","Away","OFFICER SECRET",false,0,"MAGE"},
 {"Cara Rune","Member",9,60,"Mage","Field","Available for dungeons","OFFICER SECRET",true,0,"MAGE"}}
function GetNumGuildMembers()return #roster end
rosterReads=0
function GetGuildRosterInfo(i)rosterReads=rosterReads+1;return unpack(roster[i])end
function GuildRoster()rosterRequests=(rosterRequests or 0)+1 end
ChatTypeInfo.GUILD={id=40};ChatTypeInfo.OFFICER={id=41}
RAID_CLASS_COLORS={MAGE={r=.3,g=.7,b=.9},PRIEST={r=1,g=1,b=1},WARRIOR={r=.8,g=.6,b=.4}}
""")
lua.execute(root.joinpath('Components/RosterRoom.lua').read_text(encoding='utf-8'),'Sunder',lua.globals().vars)
lua.execute(root.joinpath('Modules/GuildChat.lua').read_text(encoding='utf-8'),'Sunder',lua.globals().vars)
lua.execute(root.joinpath('Modules/GuildInfo.lua').read_text(encoding='utf-8'),'Sunder',lua.globals().vars)
lua.execute("""
Core.db.profile.guildChat=clone(Core.defaults.profile.guildChat);gp=Core.db.profile.guildChat
Core.db.char.guildChat={};W:ClearPreviewData();combat=false
G:Open();drain()
assert(openCalls==1 and G.frame and G.frame.editBox.inputType=="GUILD" and G.frame.editBox.stickyType=="GUILD")
assert(G.frame.groups.GUILD and not G.frame.groups.SAY and not G.frame.channels.General)
assert(not G.frame.isDocked and G.frame:GetWidth()==760 and savedGeometry)
assert(G.onlineCount==4 and G.totalCount==5 and #G.filtered==4)
assert(G.filtered[1].name=="Zara Ember" and G.filtered[2].name=="Anne Vale" and G.filtered[3].name=="Bob Stone")
assert(G.rows[1].rank:GetText()=="Guild Master · Keeps the hearth warm" and G.rows[1].note:GetText()=="Keeps the hearth warm")
for _,member in ipairs(G.members)do assert(not member.officerNote and member.note~="OFFICER SECRET")end
local window=ui:GetChatWindow(G.frame)
assert(window.slidingMessageFrame.layoutWidth==760-G.panel:GetWidth() and G.panel:GetWidth()<=210 and window.editBox:GetParent()==G.column)
assert(window.slidingMessageFrame.sharedFullSurface and window.slidingMessageFrame.keepRoomMessages)
local smf=window.slidingMessageFrame
smf.gapBackground=CreateFrame("Frame",nil,UIParent)
local oldGapDriver=function()end;smf.gapBackground:SetScript("OnUpdate",oldGapDriver)
function smf:UpdateGapBackground()end
ui:RefreshChatFrameLayout(G.frame);assert(not smf.gapBackground:GetScript("OnUpdate"),"guild backdrop kept an idle frame driver")
G.frame.isDocked=true;ui:RefreshChatFrameLayout(G.frame)
assert(not G.frame.isDocked and not smf.gapBackground:GetScript("OnUpdate"),"managed room fell back to the rejected native shell")
G.frame.isDocked=false;ui:RefreshChatFrameLayout(G.frame)
-- The room uses the Whispers header, drag grip and cancelable core collapse.
local h=G.room
assert(h.hubChrome and h.hubGrip and h.minimizeButton and h.hubActionButtons.Maximize)
assert(h.roomStructure and h.roomStructure.divider:IsVisible() and #h.roomStructure.edges==4)
assert(h.roomResize:GetFrameLevel()>h.hubChrome:GetFrameLevel(),"resize corner was covered by native content")
assert(G.searchPlaceholder:GetText()~="" and G.conversationLabel:GetText()~="")
assert(Core.Components.CreateRoomChrome and Core.Components.SetRoomMinimized)
local previousPreview,previousBody=W.previewActive,W.previewBody
W.previewActive=true;W.previewBody=CreateFrame("Frame",nil,UIParent)
local fullHeight=h.hub:GetHeight()
h:SetMinimized(true,true);assert(h.hub:GetHeight()==h:HeaderHeight() and not h.hubContent:IsShown())
assert(not h.roomStructure.body:IsVisible() and not h.roomStructure.divider:IsVisible(),"collapsed room left body structure visible")
h:SetMinimized(false,true);assert(h.hub:GetHeight()==fullHeight and h.hubContent:IsShown())
assert(h.roomStructure.body:IsVisible() and h.roomStructure.divider:IsVisible())
assert(not h.previewActive and W.previewBody:IsShown(),"guild shell inherited or changed Whispers preview state")
W.previewActive=previousPreview;W.previewBody=previousBody
h:SetMinimized(true);local animate=h.hub:GetScript("OnUpdate");animate(h.hub,.08)
h:SetMinimized(false);animate=h.hub:GetScript("OnUpdate");animate(h.hub,.3)
assert(not h.minimized and not h.hub:GetScript("OnUpdate") and h.hub:GetHeight()==fullHeight)
G:ToggleMaximized();assert(h.maximized and h.hub:GetWidth()==math.min(1100,UIParent:GetWidth()-32))
G:ToggleMaximized();assert(not h.maximized and h.hub:GetHeight()==fullHeight and h.hub:GetWidth()==760)
Core.sunderMoverUnlocked=false
h.hubGrip:GetScript("OnMouseDown")(h.hubGrip,"LeftButton");assert(h.hubMoving and h.hub.moving)
h.hubGrip:GetScript("OnMouseUp")(h.hubGrip);assert(not h.hubMoving and not h.hubGrip:GetScript("OnUpdate"))
local toggleLock=h.movementLockButton:GetScript("OnClick")
toggleLock(h.movementLockButton);assert(h:HubSettings().movementLocked)
h.hubChrome:GetScript("OnDragStart")(h.hubChrome);assert(not h.hubMoving,"locked title moved")
h.hubGrip:GetScript("OnMouseDown")(h.hubGrip,"LeftButton");assert(not h.hubMoving,"locked grip moved")
toggleLock(h.movementLockButton);assert(not h:HubSettings().movementLocked)
h.hubChrome:GetScript("OnDragStart")(h.hubChrome);assert(h.hubMoving)
h.hubChrome:GetScript("OnDragStop")(h.hubChrome);assert(not h.hubMoving)
G:AcknowledgeMessages();assert(G.unread==0)
h:SetMinimized(true,true);G:OnGuildMessage("Test Guild Member");G:OnGuildMessage("Test Guild Member")
assert(G.unread==2 and h.unreadBadge:GetText()=="2","minimized guild messages were not counted")
h:SetMinimized(false,true);assert(G.unread==0,"restoring guild did not acknowledge messages")
G:OnGuildMessage("Test Guild Member");assert(G.unread==0,"visible guild generated unread")
h.hub:Hide();G:OnGuildMessage("Test Guild Member");assert(G.unread==1)
h.hub:Show();G:AcknowledgeMessages()
local startingHeight=h.hub:GetHeight()
local oldBounds=h.UpdateTransitionBounds
function h:UpdateTransitionBounds()assert(self.collapseAnimation,"adapter entered layout outside transition guard");oldBounds(self)end
G:CollapseToward("BOTTOM");assert(h.minimized and h:HubSettings().minimizeEdge=="BOTTOM")
assert(h.hub:GetHeight()==startingHeight and h.hub:GetPoint()=="TOPLEFT","collapse moved to bottom anchor before animation")
h.UpdateTransitionBounds=oldBounds
local step=h.hub:GetScript("OnUpdate");step(h.hub,.12)
assert(h.hub:GetHeight()<startingHeight and h.hub:GetHeight()>h:HeaderHeight(),"downward collapse did not interpolate")
assert(h.unreadBadge.icon and h.unreadBadge:GetWidth()==50,"guild indicator omitted icon space")
if h.finishCollapse then h.finishCollapse()end
h:SetMinimized(false,true);h:HubSettings().minimizeEdge="TOP"
assert(G.rowHeight<40,"member rows are still oversized")
local oldWhisper=W.OpenSavedFavorite;guildWhisper=nil
function W:OpenSavedFavorite(contact)guildWhisper=contact end
local row=G.rows[2];local memberKey=row.member.key
row:GetScript("OnClick")(row,"LeftButton")
assert(G.selectedMember==memberKey and row.selected and row.selectedFill:IsShown() and not guildWhisper,"selection opened a whisper or lacked persistent styling")
row:GetScript("OnDoubleClick")(row,"LeftButton");assert(guildWhisper and guildWhisper.key==memberKey)
W.OpenSavedFavorite=oldWhisper
G.query="alchemy";G:FilterRoster();assert(#G.filtered==1 and G.filtered[1].name=="Anne Vale")
G.query="";gp.offline=true;G:FilterRoster();assert(#G.filtered==5 and not G.filtered[5].online)
local whisper=W.OpenSavedFavorite;function W:OpenSavedFavorite(contact)guildWhisper=contact end
G:OpenWhisper(G.filtered[2]);assert(guildWhisper.target=="Anne Vale")
W.OpenSavedFavorite=whisper
local panel=G.panel
local filtered=G.filtered
assert(Core.Components.WindowManager:PeopleSidebarWidth(600)==150,"shared width drifted")
G.room.hub:SetWidth(500);ui:RefreshChatFrameLayout(G.frame)
assert(not G.compact and G.panel:GetWidth()<=190 and window.slidingMessageFrame.layoutWidth==500-G.panel:GetWidth())
G:ToggleRoster();assert(G.compact and not gp.rosterShown)
G:ToggleRoster();assert(not G.compact and gp.rosterShown)
G.room.hub:SetWidth(340);ui:RefreshChatFrameLayout(G.frame)
assert(not G.compact and G.panel:GetWidth()<=120)
G:ToggleRoster();G:ToggleRoster();assert(not G.compact and gp.rosterShown)
G.room.hub:SetWidth(760);ui:RefreshChatFrameLayout(G.frame);assert(not G.compact and G.panel==panel)
local inherit=cfg.hubMatchChat;cfg.hubMatchChat=true;Core.db.profile.tabFontSize=32
G.room.hub:SetHeight(120);ui:RefreshChatFrameLayout(G.frame);assert(G.compact,"short large-font roster inverted its scroll bounds")
G:ToggleRoster();assert(not G.compact and G.room.hub:GetHeight()>120,"show roster did not recover a short room")
G.room.hub:SetHeight(380);ui:RefreshChatFrameLayout(G.frame);assert(not G.compact)
cfg.hubMatchChat=inherit;Core.db.profile.tabFontSize=13;ui:RefreshChatFrameLayout(G.frame)
G.frame.editBox:SetText("keep this draft");G.frame.editBox.inputType="OFFICER";G:Open()
assert(openCalls==1 and G.frame.editBox:GetText()=="keep this draft" and G.frame.editBox.inputType=="OFFICER","reopen rewrote draft/channel")
-- Roster work yields after 100 members; only viewport rows create controls.
roster={};for i=1,1000 do roster[i]={"Member "..i,"Rank",i%10,60,"Mage","City","Public note","SECRET",true,0,"MAGE"}end
rosterReads=0;G:RefreshRoster();assert(rosterReads==100,"roster scan did not yield")
drain();assert(#G.members==1000 and #G.rows<=256)
local originalHeight=UIParent.GetHeight
function UIParent:GetHeight()return 2160 end
G:ToggleMaximized()
assert(G.room.hub:GetHeight()<=720,"expanded reading view exceeded height cap")
G.room.hub:SetHeight(2000);ui:RefreshChatFrameLayout(G.frame)
assert(#G.rows>40 and #G.rows<=256,"maximized roster left a blank viewport after forty rows")
G:ToggleMaximized();UIParent.GetHeight=originalHeight
local shown=0;for _,row in ipairs(G.rows)do if row:IsShown()then shown=shown+1 end end
assert(shown<=math.ceil(G.scroll:GetHeight()/G.rowHeight)+1,"offscreen roster controls remained visible")
G.scroll:SetVerticalScroll(9000);G:RenderRoster();assert(#G.rows<=256 and G.rows[1].member)
assert(G.scroll.scrollRail:IsShown() and G.scroll.scrollRail:GetFrameLevel()>G.scroll:GetFrameLevel(),"overflow rail hidden under roster rows")
G.scroll.scrollRail.writeOffset(G.scroll,100);assert(G.scroll:GetVerticalScroll()==100)
G.scroll:SetVerticalScroll(9000)
G:FilterRoster(false);assert(G.scroll:GetVerticalScroll()==9000,"roster refresh jumped to the top")
rosterReads=0;G:RefreshRoster();currentGuildName="Different Guild";G.members={};G.filtered={};drain()
assert(#G.members==0,"stale guild scan applied after guild change")
currentGuildName="Test Guild";G.currentGuild="Test Guild@Forever"
-- Recent local history excludes officer messages, caps storage, keeps receive times.
local frame=G.frame;frame.history={}
GUILD_MOTD_TEMPLATE="Guild Message of the Day: %s"
frame.history={{text="Guild Message of the Day: old notice",typeID=40}}
G:SaveHistory();assert(#Core.db.char.guildRoomHistory.lines==0,"startup notice persisted")
Core.db.char.guildRoomHistory={key=G.currentGuild,lines={{"Guild Message of the Day: old notice",1,1,1,typeID=40},{"repeated",1,1,1,typeID=40},{"repeated",1,1,1,typeID=40}}}
frame.history={{text="Guild Message of the Day: current notice",typeID=40}}
G.restoredFrame=nil;G:RestoreHistory();drain()
assert(#frame.history==3 and frame.history[1].text=="repeated" and frame.history[2].text=="repeated","MOTD replay or genuine repeat loss")
-- The native buffer has only uptime for one older line and no date for another.
local oldClock=GetServerTime
function GetServerTime()return 1800000000 end
local origin=now;now=20000
frame.history={{text="earlier",typeID=40,timestamp=5600},{text="unknown",typeID=40}}
G:SaveHistory()
local known=1800000000-14400
local lines=Core.db.char.guildRoomHistory.lines
assert(lines[1].receivedAt==known and not lines[2].receivedAt)
frame.history={};G.restoredFrame=nil
local backfill=frame.BackFillMessage
frame.BackFillMessage=function(self,...)
 backfill(self,...);self.history[1].timestamp=now;self.history[1].serverTime=GetServerTime()
end
G:RestoreHistory();drain();G:SaveHistory()
lines=Core.db.char.guildRoomHistory.lines
assert(lines[1].receivedAt==known and not lines[2].receivedAt,"replay time leaked into Guild recall")
frame.BackFillMessage=backfill;now=origin;GetServerTime=oldClock
frame.history={}
for i=1,230 do frame.history[i]={text="guild line "..i,typeID=i%2==0 and 40 or 41,serverTime=1000+i}end
G:SaveHistory();local saved=Core.db.char.guildRoomHistory
assert(saved.key=="Test Guild@Forever" and #saved.lines==100)
for _,line in ipairs(saved.lines)do assert(line.typeID==40)end
frame.history={};G.restoredFrame=nil;G:RestoreHistory();assert(#frame.history==12)
drain();assert(#frame.history==100 and frame.history[1].serverTime==1032)
G:RestoreHistory();drain();assert(#frame.history==100,"guild history replay duplicated")
G.currentGuild="Another@Forever";frame.history={};G.restoredFrame=nil;G:RestoreHistory();assert(#frame.history==0,"history leaked between guilds")
G.currentGuild="Test Guild@Forever"
local roomFrame=G.frame
G.restoredFrame=nil;G:RestoreHistory();assert(#roomFrame.history==12)
roomFrame.history[#roomFrame.history+1]={text="fresh during restore",typeID=40,serverTime=5000}
G:OnWindowClosed(roomFrame)
local closed=Core.db.char.guildRoomHistory.lines
assert(closed[#closed][1]=="fresh during restore" and #closed==101,"close during replay lost fresh messages")
assert(not G.frame and not Core.db.char.guildChat.frameID and not window.slidingMessageFrame.sharedFullSurface and smf.gapBackground:GetScript("OnUpdate")==oldGapDriver)
-- Reuse the exact native slot and shell without creating more roster controls.
local opener=FCF_OpenNewWindow
FCF_OpenNewWindow=function()nativeNames[3]="Guild Chat";roomFrame:Clear();roomFrame.isDocked=true;return roomFrame,3 end
G:Open();drain();assert(G.panel==panel and G.room.hubBackground:IsShown(),"reopening leaked a shell or lost the body surface")
G:OnWindowClosed(roomFrame)
FCF_OpenNewWindow=function()return nil end
G:Open();assert(not G.frame and printMessage:find("slots",1,true))
Core.db.char.guildChat.frameID=3;nativeNames[3]="User's private window"
assert(not G:SavedFrame(),"adopted an unrelated native window")
Core.db.char.guildChat.frameID=nil;FCF_OpenNewWindow=opener
G:OnEnable();combat=true;G:Open();assert(G.pendingOpen and not G.frame)
combat=false;G.events:GetScript("OnEvent")(G.events,"PLAYER_REGEN_ENABLED");drain();assert(G.frame)
""")
print('Guild room passed: isolated native slot/filters, GUILD input, stable draft/channel, rank/note/color model, online/offline counts, searchable virtual roster, bounded/cancelable scans, responsive layout, shell reuse, history isolation/timestamps, slot exhaustion and combat deferral.')
# Execute the real native input-selection path for blank areas and message rows.
lua.execute("""
Core.sunderMoverUnlocked=false;Core.sunderEllesmereEditing=false
local general,generalWindow=conversation("BodyClickGeneral","General","SAY")
local peer,peerWindow=conversation("BodyClickWhisper","Body Peer")
W:OnWindowOpened(peer);drain();W:MoveToWorkspace(peer,"messages")
bodyGeneral=general;bodyPeer=peer;bodyGeneralInput=generalWindow.editBox;bodyPeerInput=peerWindow.editBox
local focus
GetCurrentKeyBoardFocus=function()return focus end
assert(ui:SelectMessageInput(general) and lastInput==generalWindow.editBox)
assert(ui:SelectMessageInput(peer) and lastInput==peerWindow.editBox and W.selected==peer)
assert(ui:SelectMessageInput(G.frame) and lastInput==G.frame.editBox)
focus=generalWindow.editBox;generalWindow.editBox:SetText("preserve general draft")
assert(ui:SelectMessageInput(peer) and lastInput==peerWindow.editBox and generalWindow.editBox:GetText()=="preserve general draft")
focus={};local previous=lastInput
assert(not ui:SelectMessageInput(general) and lastInput==previous)
focus=nil;Core.sunderMoverUnlocked=true;assert(not ui:SelectMessageInput(general));Core.sunderMoverUnlocked=false
""")
source=root.joinpath('Components/MessageLine.lua').read_text(encoding='utf-8')
lua.globals().clickLineMixin=lua.execute(source+'\nreturn MessageLineMixin','Sunder',lua.globals().vars)
lua.execute("""
local row=CreateFrame("Frame",nil,UIParent);row.text=row:CreateFontString()
for k,v in pairs(clickLineMixin)do row[k]=v end
row.UpdateFadeSettings=function()end;row.SetGradientBackground=function()end;row.SetBackgroundCoverage=function()end
row.sunderRenderer={GetLayoutWidth=function()return 500 end};row:Init();row.sourceFrame=bodyGeneral
lastInput=bodyPeerInput;row:GetScript("OnMouseDown")(row,"RightButton");assert(lastInput==bodyPeerInput)
local shift=IsShiftKeyDown;IsShiftKeyDown=function()return true end
row:GetScript("OnMouseDown")(row,"LeftButton");assert(lastInput==bodyPeerInput,"modified link click retargeted input")
IsShiftKeyDown=shift
row:GetScript("OnMouseDown")(row,"LeftButton");assert(lastInput==bodyGeneralInput)
assert(row:GetScript("OnHyperlinkClick") and row.linksEnabled,"message click removed link handling")
""")
native=root.joinpath('Components/SlidingMessageFrameNative.lua').read_text(encoding='utf-8')
viewport=native[native.index('  if self.viewport == nil then'):native.index('  if self.slider == nil then')]
lua.execute('local self={chatFrame=bodyPeer};setmetatable(self,{__index=UIParent});'+viewport+'\nbodyViewport=self.viewport')
lua.execute("""
lastInput=bodyGeneralInput;bodyViewport:GetScript("OnMouseDown")(bodyViewport,"RightButton");assert(lastInput==bodyGeneralInput)
bodyViewport:GetScript("OnMouseDown")(bodyViewport,"LeftButton");assert(lastInput==bodyPeerInput)
assert(not bodyPeerInput:HasFocus(),"message-area click stole focus")
GetCurrentKeyBoardFocus=nil
""")
print('Message-area input passed: actual blank viewport/message-row handlers choose General, Whispers and Guild inputs; drafts, links, unrelated focus, right clicks and edit-mode movement remain intact.')

# The actual room root, not its parked native slot, owns Ellesmere geometry.
lua.execute(root.joinpath('Modules/EllesmereEditMode.lua').read_text(encoding='utf-8'),'Sunder',lua.globals().vars)
lua.execute("""
local registry={}
C_Timer.NewTicker=function(_,callback)return {fn=callback,Cancel=function(self)self.cancelled=true end}end
EllesmereUI={_ELEMENT_SETTINGS_MAP={},RegisterUnlockElements=function(_,list)for _,element in ipairs(list)do registry[element.key]=element end end,
 UnregisterUnlockElement=function(_,key)registry[key]=nil end,
 RegisterUnlockModeListener=function()end,GetPluginModuleKey=function()return "plugin:Sunder:chat" end}
local oldWindows,oldHosts=ui.state.windows,W.workspaces
ui.state.windows={[G.frame:GetName()]=ui:GetChatWindow(G.frame)};W.workspaces={}
eui.editElements={};eui:RefreshEditElements()
assert(registry.Sunder_GuildChat and registry.Sunder_GuildChat.getFrame()==G.room.hub)
assert(not registry["Sunder_"..G.frame:GetName()],"guild room exposed duplicate native mover")
assert(EllesmereUI._ELEMENT_SETTINGS_MAP.Sunder_GuildChat.page=="Guild Chat")
local lockedSettings=G.room:HubSettings();local lockedWidth=G.room.hub:GetWidth()
lockedSettings.movementLocked=true
registry.Sunder_GuildChat.setWidth("Sunder_GuildChat",lockedWidth+100)
assert(G.room.hub:GetWidth()==lockedWidth,"Edit UI bypassed geometry lock")
lockedSettings.movementLocked=false

G.room:SetMinimized(true,true)
local width=G.room.hub:GetWidth()
eui:OnEllesmereEditSession(true);assert(not G.room.minimized)
registry.Sunder_GuildChat.setWidth("Sunder_GuildChat",width+100)
eui:OnEllesmereEditSession(false,"discard")
assert(G.room.minimized and G.room.hub:GetWidth()==width,"discard lost room bounds or minimized state")
G.room:SetMinimized(false,true)
ui.state.windows=oldWindows;W.workspaces=oldHosts
""")
print('Guild shell Edit UI passed: one actual-root mover, Guild settings link, width discard and minimized-state restoration.')

lua.execute("""
local m=getmetatable(UIParent).__index
function m:GetStringWidth()return #(self:GetText() or "")*7 end
function m:GetStringHeight()return math.max(1,math.ceil(#(self:GetText() or "")/math.max(1,self:GetWidth()/7)))*14 end
function m:GetFrameStrata()return self.strata or "MEDIUM"end
function m:SetFrameStrata(value)self.strata=value end
local manager=Core.Components.WindowManager
local root=CreateFrame("Frame",nil,UIParent);root:SetSize(640,360)
local header=CreateFrame("Frame",nil,root);header:SetHeight(24)
header.scrollFrame=CreateFrame("Frame",nil,header);header.scrollFrame:SetFrameLevel(50)
local controls=manager:CreateNativeHeader(header,{settings=function()return manager:Settings("surface-fixture")end,start=function()end,stop=function()end})
manager:RegisterNativeSurface(root,header)
local surface=root.windowSurface
assert(surface and #surface.edges==4 and surface.bodyFrame.fill==surface.fade)
assert(controls.move:GetFrameLevel()>header.scrollFrame:GetFrameLevel(),"native grip covered by scroll strip")
assert(header:GetFrameStrata()==root:GetFrameStrata())
local expected=Core.db.profile.chatBackgroundColor.a
assert(surface.fade.paint.a==expected and surface.fade.paint.fade,"native body did not use shared blended fade")
local same=manager:ApplyNativeSurface(root,header);assert(same==surface,"repaint duplicated the surface")
root:SetSize(480,240);assert(surface.bodyFrame:GetHeight()==216,"native resize did not update shared body")
Core.db.profile.chatBackgroundColor.a=0
manager:ApplyNativeSurface(root,header);assert(surface.fade.paint.a==0 and surface.body.rgba[4]==0)
Core.db.profile.chatBackgroundColor.a=expected
manager:ApplyNativeSurface(root,header)
assert(G.room.hub.windowSurface==G.room.roomStructure,"Guild has a separate surface implementation")
W:ApplyHubAppearance();assert(W.hub.windowSurface==W.roomStructure and W.whisperSurface==W.roomStructure.bodyFrame,"Whispers bypasses shared surface")
""")
print('Shared surfaces passed: native/Guild/Whispers ownership, border/fade contract, zero opacity, resize/reuse, and raised native grip.')

lua.execute("""
local manager=Core.Components.WindowManager
local root=CreateFrame("Frame",nil,UIParent);root:SetSize(600,300)
local header=CreateFrame("Frame",nil,root);header:SetHeight(24)
header.messageSeparator=CreateFrame("Frame",nil,header)
header.messageSeparator.leftBg=header.messageSeparator:CreateTexture()
header.messageSeparator.leftBg:Show()
local paint=Core.Components.PaintGradientTexture;local paints=0;local surface
Core.Components.PaintGradientTexture=function(texture,...)if surface and texture==surface.fade then paints=paints+1 end;return paint(texture,...)end
surface=manager:ApplyNativeSurface(root,header)
assert(not header.messageSeparator.leftBg:IsShown() and header.messageSeparator:GetAlpha()==0,"legacy separator still paints over shared rule")
paints=0
for i=1,20 do manager:ApplyNativeSurface(root,header)end
assert(paints==0,"unchanged surfaces repainted")
local color=Core.db.profile.chatBackgroundColor
local old=color.r;color.r=old+.01
manager:ApplyNativeSurface(root,header);assert(paints==1 and surface.fade.paint.r==color.r,"color mutation skipped cache invalidation")
color.r=old;paints=0
manager:ApplyNativeSurface(root,header);assert(paints==1)
paints=0;root:SetWidth(620);manager:ApplyNativeSurface(root,header);assert(paints==1,"resize skipped repaint")
Core.Components.PaintGradientTexture=paint
local previous=Core.Subscribe;local callback
function Core:Subscribe(_,fn)callback=fn end
local native=CreateFrame("Frame",nil,UIParent);native:SetSize(400,240)
local dock=CreateFrame("Frame",nil,native);dock:SetHeight(24)
manager:RegisterNativeSurface(native,dock)
local nativeSurface=native.windowSurface;local stamp=nativeSurface.paintStamp
color.r=old+.02;callback("emojiDisplay");assert(nativeSurface.paintStamp==stamp,"unrelated setting repainted a window")
callback("chatBackgroundColor");assert(nativeSurface.paintStamp~=stamp,"relevant setting did not repaint")
color.r=old;Core.Subscribe=previous
""")
print('Window audit passed: legacy separator retirement, paint cache invalidation, and filtered native settings updates.')

lua.execute("""
local manager=Core.Components.WindowManager
local root=CreateFrame("Frame",nil,UIParent);root:SetSize(600,200)
local header=CreateFrame("Frame",nil,root);header:SetHeight(24)
local docking=0
local controls=manager:CreateNativeHeader(header,{settings=function()return manager:Settings("combat-fixture")end,
 start=function()end,stop=function()end,dockAction=function()docking=docking+1 end})
assert(not controls.settings,"unmapped settings cog was displayed")
controls.dock:GetScript("OnClick")();assert(docking==1)
manager:RegisterNativeSurface(root,header)
manager:UpdateContentExtent(root,220,24)
assert(root.windowContentExtent==44 and root.windowSurface.bodyFrame:GetHeight()==220)
assert(root.windowSurface.frame.points.BOTTOMRIGHT.y==-44,"outline did not include renderer overflow")
local resize=manager:CreateWindowResizer(root,{minWidth=100,minHeight=100,allowed=function()return true end,begin=function()return root,600,200 end,apply=function(w,h)root:SetSize(w,h)end,finish=function()end})
assert(resize.points.BOTTOMRIGHT.relative==root.windowSurface.frame,"resize grip did not follow visible body")
manager:UpdateContentExtent(root,150,24);assert(root.windowContentExtent==0 and root.windowSurface.bodyFrame:GetHeight()==176)
local nativeDock,nativeSelect,scheduled=FCF_DockFrame,FCF_SelectDockFrame,ui.ScheduleChatFrameLayout
local target=CreateFrame("Frame",nil,UIParent);target.isDocked=false
FCF_DockFrame=function(f)assert(f==target);f.isDocked=true end
FCF_SelectDockFrame=function(f)assert(f==target)end
local called=false;ui.ScheduleChatFrameLayout=function(_,f)assert(f==target);called=true end
ui:DockWindow(target);assert(target.isDocked and called)
FCF_DockFrame,FCF_SelectDockFrame,ui.ScheduleChatFrameLayout=nativeDock,nativeSelect,scheduled
-- Exercise the actual saved-row star instead of only the underlying model setter.
W:ClearPreviewData();cfg.conversationLayout="list";W.peopleFilter="all"
local previousGetModule=Core.GetModule
local history={}
function Core:GetModule(name,...)if name=="WhisperTabs"then return history end;return previousGetModule(self,name,...)end
Core.db.char.whisperArchive=Core.db.char.whisperArchive or {}
function history:ImportArchive()return Core.db.char.whisperArchive end
Core.db.char.whisperArchive["character:star-fixture"]={kind="WHISPER",target="Star Fixture",displayName="Star Fixture",lines={{"Saved message"}},favorite=false,closed=true}
W:LayoutPeopleRows(false)
local row
for _,b in ipairs(W.savedFavoriteRows)do if b.contact and b.contact.archiveKey=="character:star-fixture" then row=b;break end end
assert(row and row.favoriteButton,"archived person has no star action")
row.favoriteButton:GetScript("OnClick")()
assert(Core.db.char.whisperArchive["character:star-fixture"].favorite and Core.db.char.whisperFavorites["star fixture"],"saved-row star did not persist")
W.peopleFilter="favorites";W:LayoutPeopleRows(false)
for _,b in ipairs(W.savedFavoriteRows)do if b.contact and b.contact.archiveKey=="character:star-fixture"then row=b;break end end
row.favoriteButton:GetScript("OnClick")()
assert(not Core.db.char.whisperArchive["character:star-fixture"].favorite and not Core.db.char.whisperFavorites["star fixture"],"unfavorite resurrected archived state")
Core.GetModule=previousGetModule
""")
print('Window controls passed: capability-based settings, dock action, full renderer bounds/grip, native dock dispatch and saved-row favorites.')

lua.execute("""
local wm=Core.Components.WindowManager
local button=wm:CreateAction(UIParent,"favorite","Star",function()end)
wm:SetActionSelected(button,true,"favorite")
assert(button.actionSelected and button.selectedIconKey=="favorite-filled" and button.icon:GetAlpha()==1)
button:GetScript("OnEnter")();assert(button.plate.rgba[4]==0,"selected favorite hover painted a plate");button:GetScript("OnLeave")()
assert(button.actionSelected and button.icon:GetAlpha()==1 and button.plate.rgba[4]==0,"selected favorite retained a background")
wm:SetActionSelected(button,false,"favorite");assert(not button.actionSelected and button.plate.rgba[4]==0)
local cfg={movementLocked=false}
local lock=wm:CreateLock(UIParent,function()return cfg end,function()end)
lock:GetScript("OnClick")();assert(cfg.movementLocked and lock.actionSelected and lock.selectedIconKey=="lock-filled")
lock:GetScript("OnEnter")();lock:GetScript("OnLeave")();assert(lock.actionSelected and lock.icon:GetAlpha()==1)
lock:GetScript("OnClick")();assert(not cfg.movementLocked and not lock.actionSelected and lock.actionKey=="unlock")
assert(W:ConversationRowHeight()>=24 and W:ConversationRowStep()==W:ConversationRowHeight())
""")
print('Shared selection states passed: filled favorites/locks, persistent active hover state, and compact row metrics.')

lua.execute("""
local wm=Core.Components.WindowManager
for _,host in ipairs({W,G.room})do
 host.hub:Show();host:SetMinimized(false,true)
 wm:RefreshRoomActions(host)
 local actions=host.hubActionButtons
 assert(actions.Maximize.actionKey=="maximize" and actions.CollapseTop.actionKey=="collapse-up" and actions.CollapseBottom.actionKey=="collapse-down")
 assert(actions.Settings.points.RIGHT.x>actions.Maximize.points.RIGHT.x and actions.Maximize.points.RIGHT.x>actions.CollapseTop.points.RIGHT.x)
 assert(actions.CollapseTop.points.RIGHT.x>actions.CollapseBottom.points.RIGHT.x and actions.Settings.points.RIGHT.x>host.movementLockButton.points.RIGHT.x and host.movementLockButton.points.RIGHT.x>actions.Maximize.points.RIGHT.x)
 local lock=host.movementLockButton
 local closeX=actions.Close.points.RIGHT.x
 assert(actions.Close:IsShown() and closeX>actions.Settings.points.RIGHT.x)
 lock:GetScript("OnClick")(lock)
 assert(not actions.Close:IsShown() and actions.Settings.points.RIGHT.x==closeX)
 host:LayoutHeaderStrip()
 assert(not actions.Close:IsShown() and lock:IsShown())
 lock:GetScript("OnClick")(lock)
 assert(actions.Close:IsShown() and actions.Settings.points.RIGHT.x<closeX)
 assert(actions.Maximize.windowTooltip=="Maximize window")
 local width,height=host.hub:GetWidth(),host.hub:GetHeight()
 wm:ToggleMaximized(host)
 assert(host.maximized and actions.Maximize.actionKey=="restore-size" and actions.Maximize.windowTooltip=="Restore window size")
 wm:ToggleMaximized(host)
 assert(not host.maximized and host.hub:GetWidth()==width and host.hub:GetHeight()==height,"restore lost original room dimensions")
 wm:CollapseToward(host,"BOTTOM")
 assert(host.hubContent:IsShown(),"collapse blinked body off before its fade")
 if host.finishCollapse then host.finishCollapse()end
 assert(not actions.CollapseTop:IsShown() and actions.CollapseBottom:IsShown() and actions.CollapseBottom.windowTooltip=="Restore window" and actions.CollapseBottom.actionKey=="collapse-up")
 host:SetMinimized(false,true)
end
assert(W.hubActionButtons.Windows.actionKey=="window-menu")
assert(G.room.hubActionButtons.Roster.actionKey=="roster")
local b=wm:CreateAction(UIParent,"pin","Pin",function()end)
wm:SetActionSelected(b,true,"pin");b:Disable();b:GetScript("OnDisable")();b:GetScript("OnEnter")()
assert(b.icon:GetAlpha()==.25 and b.plate.rgba[4]==0,"disabled control regained hover/selected emphasis")
b:Enable();b:GetScript("OnEnable")();b:GetScript("OnLeave")()
assert(b.actionSelected and b.icon:GetAlpha()==1)
b:GetScript("OnMouseDown")();b:Hide();b:Show()
assert(not b.hovered and b.icon.points.CENTER.y==0,"hidden control retained hover or pressed offset")
""")
print('Semantic window capabilities passed: unique icons/commands, shared maximize restore and directional collapse, no initial body blink, disabled and recycled action feedback.')

lua.execute("""
local wm=Core.Components.WindowManager
for _,host in ipairs({W,G.room})do
 host.hub:Show();host:SetMinimized(false,true);host:HubSettings().minimizeEdge="BOTTOM"
 local surface=host.hub.windowSurface
 local full=surface.bodyFrame:GetHeight()
 host:SetMinimized(true)
 local step=host.hub:GetScript("OnUpdate");step(host.hub,.04)
 assert(surface.bodyFrame:GetHeight()<full and surface.bodyFrame:GetHeight()>1,"surface kept full height while room moved")
 assert(surface.bodyFrame:GetAlpha()==1,"surface faded instead of clipping")
 host.finishCollapse();assert(not surface.bodyFrame:IsShown())
 host:SetMinimized(false,true)
 assert(surface.bodyFrame:IsShown() and surface.bodyFrame:GetAlpha()==1)
end
local action=G.room.hubActionButtons.Roster
local original=Core.db.profile.guildChat.rosterShown
Core.db.profile.guildChat.rosterShown=true;wm:RefreshRoomActions(G.room)
action:GetScript("OnClick")(action)
assert(not action.actionSelected and action.windowTooltip=="Show member roster","roster selected state did not refresh after hiding")
action:GetScript("OnClick")(action)
assert(action.actionSelected and action.windowTooltip=="Hide member roster")
Core.db.profile.guildChat.rosterShown=original;wm:RefreshRoomActions(G.room)
G.room:SetMinimized(true,true)
assert(not action.actionSelected and not action.disabled and action.windowTooltip=="Restore window and show members","collapsed roster retained active feedback")
G.room:SetMinimized(false,true);assert(not action.disabled)

local counter=G.room.unreadBadge
assert(counter:GetWidth()==50 and counter.icon.points.LEFT.x==4 and counter:GetFontString().points.LEFT.x==22 and counter:GetFontString().points.RIGHT.x==-4)
local a=CreateFrame("Frame"):CreateTexture();local b=CreateFrame("Frame"):CreateTexture()
wm:StyleTitleIcon(a,false);wm:StyleTitleIcon(b,false)
assert(a:GetAlpha()==b:GetAlpha())
wm:StyleUnreadIndicator(counter,0,.8,.6,.3);assert(counter.icon:GetAlpha()==a:GetAlpha())
wm:StyleUnreadIndicator(counter,2,.8,.6,.3);assert(counter.icon:GetAlpha()==1)
""")
print('Guild parity regressions passed: actual surface intermediate height/alpha for both adapters, roster state after real click, identical counter anchors and shared icon opacity.')

lua.execute("""
local wm=Core.Components.WindowManager
for _,host in ipairs({W,G.room})do
 host.hub:Show();host:SetMinimized(false,true)
 for _,edge in ipairs({"TOP","BOTTOM"})do
  host:HubSettings().minimizeEdge=edge
  for _,minimized in ipairs({true,false})do
   if not minimized then
    host:ApplyHubAppearance() -- style refresh while fully collapsed
    assert(not host.hub.windowSurface.bodyFrame:IsVisible())
   end
   host:SetMinimized(minimized)
   local step=host.hub:GetScript("OnUpdate")
   for tick=1,11 do
    step(host.hub,.02)
    local surface=host.hub.windowSurface
    assert(surface.bodyFrame:IsShown() and surface.bodyFrame:GetAlpha()==1,"body vanished before transition completed")
    assert(surface.body:IsVisible(),"body fill stayed hidden during expansion")
    assert(surface.sidebar:GetWidth()>1 and surface.sidebar:IsVisible() and surface.divider:IsVisible(),"names pane stayed blank during expansion")
    assert(surface.bodyFrame:GetHeight()==math.max(1,host.hub:GetHeight()-surface.bodyTop+(surface.bottomExtent or 0)),"backing escaped the moving bounds")
    assert(host.hubContent:IsShown() and host.hubContent:GetAlpha()==1 and host.hubContent.clipsChildren,"native content was hidden instead of clipped")
    if host==W and host:IsConversationList()then
     local list=host.previewActive and host.previewTabScroll or host.tabScroll
     assert(list:IsShown() and list:GetHeight()==math.max(1,host.hub:GetHeight()-host:HeaderHeight()-host:HeaderGap()-32),"people list collapsed ahead of the window: "..edge.."/"..tostring(minimized).."/"..tick.." shown="..tostring(list:IsShown()).." height="..list:GetHeight().." expected="..math.max(1,host.hub:GetHeight()-host:HeaderHeight()-host:HeaderGap()-32))
    end
   end
   step(host.hub,.03)
   assert(not host.collapseAnimation and not host.hub:GetScript("OnUpdate"))
   assert(host.hub.windowSurface.bodyFrame:IsShown()==not minimized)
  end
 end
end
""")
print('Clipped transition regression passed: both directions and hosts retain opaque body/content/list until completion, follow bounds at every tick, and clean up drivers.')

lua.execute("""
local list=G.filtered
G.filtered={};G:RenderRoster()
assert(not G.scroll.scrollRail.thumb:IsShown() and G.scroll.scrollRail:IsShown(),"fitting roster lost its scroll-area affordance")
G.filtered=list;G:RenderRoster()
local selected=W.selected;W.selected=nil;W:RefreshConversationEmptyState()
assert(W.hubEmpty:GetText()=="No conversation selected.\\n\\nSelect a conversation to view its messages.")
W.selected=selected;W:RefreshConversationEmptyState()
""")

lua.execute("""
local wm=Core.Components.WindowManager
local rail=G.scroll.scrollRail
assert(G.scroll.points.BOTTOMRIGHT.x==0 and rail.points.TOPRIGHT.x==-1)
assert(rail:GetWidth()==wm.SCROLL_RAIL_WIDTH and rail:GetHeight()==G.scroll:GetHeight()-8)
""")

lua.execute("""
G.onlineCount=5;G.totalCount=13;G:LayoutRoomChrome()
local roster=G.room.hubActionButtons.Roster
assert(roster.countLabel:GetText()=="5/13" and roster:GetWidth()>24)
local x=roster.iconOffsetX
roster:GetScript("OnMouseDown")();roster:GetScript("OnMouseUp")()
assert(roster.icon.points.CENTER.x==x,"count icon shifted after clicking")
""")

# A character rename changes AceDB's char key, while native chat windows survive.
lua.execute("""
local frame=G.frame;local before=openCalls
frame:Show();G.room.hub:Hide();G.frame=nil
Core.db.char.guildChat={}
function GetChatWindowMessages(id)if id==frame:GetID()then return "GUILD"end;return "SAY"end
G:RestoreWindow();drain()
assert(G.frame==frame and openCalls==before,"orphaned native Guild slot was not recovered after char-state loss")
assert(G.room.hub:IsShown() and G.panel:IsVisible() and G.room.hubActionButtons.Roster.countLabel,"recovered room lost member pane or header")
""")

lua.execute("""
local frame=G.frame;local native=ui:GetChatWindow(frame);local before=openCalls
local parent=native.slidingMessageFrame:GetParent()
-- The real addon parks the native frame; its visible replacement still proves open.
G.room.hub:Hide();frame:Hide();native.slidingMessageFrame:SetParent(UIParent);native.slidingMessageFrame:Show()
G.frame=nil;Core.db.char.guildChat={}
assert(G:SavedFrame()==frame,"visible replacement renderer was ignored")
local groups=GetChatWindowMessages
GetChatWindowMessages=function(id)if id==frame:GetID()then return "GUILD","SAY"end end
assert(not G:SavedFrame(),"recovery took over a mixed-purpose native tab")
GetChatWindowMessages=groups
G:RestoreWindow();drain()
assert(G.frame==frame and G.room.hub:IsShown() and openCalls==before)
""")
print('Guild recovery passed: missing per-character slot, visible native/replacement windows, dedicated-filter guard, no duplicate window and complete roster/header restoration.')

lua.execute("""
local saved=Core.db.char.guildChat.frameID;Core.db.char.guildChat.frameID=nil
local frame=G.frame;local groups=GetChatWindowMessages
local previous=_G.ChatFrame4;local previousName=nativeNames[4]
local other=CreateFrame("Frame",nil,UIParent);_G.ChatFrame4=other;nativeNames[4]="Guild Chat";other:Show()
GetChatWindowMessages=function(id)if id==frame:GetID() or id==4 then return "GUILD"end end
assert(not G:SavedFrame(),"ambiguous Guild slots were silently adopted")
_G.ChatFrame4=previous;nativeNames[4]=previousName;GetChatWindowMessages=groups
G.closedSlots=G.closedSlots or {};G.closedSlots[frame]=true
assert(not G:SavedFrame(),"closed Guild slot was resurrected")
G.closedSlots[frame]=nil;Core.db.char.guildChat.frameID=saved
""")

lua.execute("""
LOCALIZED_CLASS_NAMES_MALE={MAGE="Mage",WARRIOR="Warrior"}
local wm=Core.Components.WindowManager
local row=CreateFrame("Button",nil,UIParent);row:SetNormalFontObject("SunderChatDockFont")
local label=row:GetFontString();label:SetWidth(64);label:SetPoint("LEFT",25,0)
W:LayoutPersonDetails(row,"Test Mage",{level=34,classFile="MAGE",online=true})
assert(row.personDetails:GetText()=="34 · Mage" and row.personDetails:GetWidth()<=row:GetWidth()-8)
assert(row.personDetails.font[2]<W:InterfaceTextSize() and row.personDetails.textColor[4]<1)
assert(label.points.TOPLEFT.y==0 and label:GetHeight()==W:InterfaceTextSize()+2)
W:LayoutPersonDetails(row,"Test Mage",{level=34,classFile="MAGE",online=false})
assert(label.textColor[4]==.45 and row.personDetails.textColor[4]==.4,"offline whisper identity not dimmed")
W:LayoutPersonDetails(row,"Unknown",{})
assert(label.textColor[4]==1,"recycled unknown inherited offline dimming")
assert(not row.personDetails:IsShown() and label.points.LEFT.y==2,"recycled row retained another character's details")
local api=C_FriendList
C_FriendList={GetNumFriends=function()return 1 end,GetFriendInfoByIndex=function()return {name="Test Friend",level=27,className="Mage",connected=true}end}
W:RefreshPersonMetadata();drain()
assert(W:PersonDetails("Test Friend").level==27 and W:PersonDetails("Test Friend").classFile=="MAGE")
C_FriendList=api
local filtered=G.filtered
G.filtered={{name="Test Mage",level=34,class="Mage",classFile="MAGE",rank="Officer",note="Public note",online=true,key="test mage",guildKey=G.currentGuild}}
G:RenderRoster()
assert(G.rows[1].details:GetText()=="34 · Mage" and G.rows[1].rank:GetText()=="Officer · Public note")
assert(not G.rows[1].rank:IsShown() and G.rows[1].details.points.TOPLEFT.y-G.rows[1].details:GetHeight()>=-G.rowHeight,"compact row detail overflowed")
G.filtered=filtered;G:RenderRoster()
""")
print('Person metadata passed: dim class color/smaller font, level/class formatting, bounded detail width, recycled unknown clearing, passive friend lookup and preserved Guild rank/public notes.')

lua.execute("""
local motd=GetGuildRosterMOTD
GetGuildRosterMOTD=function()return "Welcome home. Tonight: guild dungeon runs."end
G.room.hub:Show();G.room:SetMinimized(false,true);G.room:LayoutHub()
assert(G.motdLabel:IsShown() and G.motdLabel:GetText()==GetGuildRosterMOTD())
assert(G.conversationLabel.font[2]>W:InterfaceTextSize())
assert(G.motdLabel.points.TOPRIGHT and G.captionHelp:GetHeight()>W:InterfaceTextSize()*2)
local cfg=G.room:HubSettings()
if not cfg then cfg={};Core.db.char.guildChat.roomGeometry=cfg end
cfg.movementLocked=true
G.room.roomResize:GetScript("OnMouseDown")(G.room.roomResize,"LeftButton")
G.room.hubResize:GetScript("OnMouseDown")(G.room.hubResize,"LeftButton")
assert(not G.room.roomResize.resizeState and not G.room.hubResize.resizeState,"locked room resize began")
cfg.movementLocked=false;GetGuildRosterMOTD=motd
""")

renderer=root.joinpath('Components/SlidingMessageFrame.lua').read_text(encoding='utf-8')
notices=renderer[renderer.index('local function suppressGuildNotice'):renderer.index('function SlidingMessageFrameMixin:ReloadMessagesFromChatFrame')]
lua.execute('local SlidingMessageFrameMixin={};local TP={IsMessageBlacklisted=function()return false end};local UIManager={QueueFrameForUpdate=function()end};'+notices+"""
local f={state={incomingMessages={},incomingScrollbackMessages={}}};for k,v in pairs(SlidingMessageFrameMixin)do f[k]=v end
local motd=string.format(GUILD_MOTD_TEMPLATE,"Welcome")
f:AddMessageAt(1,G.frame,motd,1,1,1,40);f:BackFillMessageAt(1,G.frame,motd,1,1,1,40)
assert(#f.state.incomingMessages==0 and #f.state.incomingScrollbackMessages==0,"MOTD returned to Guild transcript")
f:AddMessageAt(1,G.frame,"normal guild line",1,1,1,40);assert(#f.state.incomingMessages==1)
""")

lua.execute("""
local members,filtered=G.members,G.filtered
local zone=GetRealZoneText;GetRealZoneText=function()return "City"end
local function member(name,online,where,class)
 return {key=name:lower(),name=name,online=online,zone=where,class=class,classFile="MAGE",level=34,rank="Officer",rankIndex=1,note="Public note",guildKey=G.currentGuild}
end
local a,b,c=member("Alpha",true,"City","Mage"),member("Beta",true,"Forest","Mage"),member("Gamma",false,"City","Mage")
G.members={a,b,c};G.onlineCount=2;G.totalCount=3;G.query="";gp.offline=false
G:SetRosterFilter("all");assert(#G.filtered==2)
assert(G.rowHeight==W:InterfaceTextSize()+Core.Components.WindowManager:PersonDetailSize(W)+9 and G.rows[1].separator:IsShown())
G.rosterFilters.buttons[2]:GetScript("OnClick")();assert(#G.filtered==1 and G.filtered[1]==a)
G:ToggleMemberFavorite(c);G:SetRosterFilter("favorites");assert(#G.filtered==1 and G.filtered[1]==c,"offline favorites disappeared")
G:SetRosterFilter("all");G.room.hub:SetSize(1000,450)
G:ShowGuildInfo();assert(G.infoDrawer:IsShown() and G.infoDrawer.body:GetText():find("Online by class",1,true))
assert(G.column:IsShown() and G.infoDrawer:GetWidth()==280)
assert(G.room.hubActionButtons.Info.actionSelected)
local whisper=W.OpenSavedFavorite;local sent=0;W.OpenSavedFavorite=function()sent=sent+1 end
G:ShowMemberCard(a);assert(sent==0 and G.infoDrawer.title:GetText()=="Alpha")
combat=true;G.events:GetScript("OnEvent")(G.events,"PLAYER_REGEN_DISABLED");assert(G.infoDrawer.whisper.disabled and G.infoDrawer.invite.disabled)
combat=false;G.events:GetScript("OnEvent")(G.events,"PLAYER_REGEN_ENABLED");assert(not G.infoDrawer.whisper.disabled)
assert(G.infoDrawer.body:GetText():find("Public note",1,true) and G.infoDrawer.body:GetText():find("Officer",1,true))
G.infoDrawer.whisper:GetScript("OnClick")();assert(sent==1)
W.OpenSavedFavorite=whisper
local invite=InviteUnit;local group=IsInGroup;local invited
InviteUnit=function(name)invited=name end;IsInGroup=function()return false end
combat=true;G:InviteMember(a);assert(not invited)
combat=false;G:InviteMember(c);assert(not invited)
G:InviteMember(a);assert(invited=="Alpha")
InviteUnit=invite;IsInGroup=group
G.room.hub:SetWidth(500);assert(not G.column:IsShown() and not G.captionHelp:IsShown())
G:CloseGuildInfo();assert(G.column:IsShown() and not G.infoDrawer:IsShown() and not G.room.hubActionButtons.Info.actionSelected)
G.members=members;G.filtered=filtered;GetRealZoneText=zone;G.rosterFilter="all";G:FilterRoster()
""")
print('Guild information passed: compact separators, zone/online/offline-favorite filters, responsive overview/member cards, explicit-only whisper/invite actions, permission guards and clean return to chat.')

lua.execute("""
local wm=Core.Components.WindowManager
local options={person={level=34,classFile="MAGE"},onFavorite=function()end,onPin=function()end,unread=true,unreadCount=3}
local row=CreateFrame("Button");row:SetNormalFontObject("SunderChatDockFont");row:SetText("Person");row:SetWidth(160);row.unread=row:CreateFontString()
for i=1,12 do
 options.selected=i%2==0;wm:LayoutPersonRow(W,row,options)
 assert(row:GetFontString().points.TOPLEFT.y==0 and row:GetFontString():GetHeight()==W:InterfaceTextSize()+2)
 assert(W:ConversationRowStep()==wm:PersonRowHeight(W),"Whispers adds a gap below the shared separator")
 local detailBottom=row:GetFontString():GetHeight()+1+row.personDetails:GetHeight()
 assert(row:GetHeight()-detailBottom==4,"optical separator clearance changed")
 assert(row.favoriteButton.points.RIGHT and row.pinControl.points.RIGHT and row.pinControl:IsShown() and not row.pinControl.disabled)
 assert(row.unread:IsShown() and row:GetFontString():GetWidth()<row:GetWidth()-50)
end
local first=wm:PersonPriority(true,true);assert(first<wm:PersonPriority(true,false) and wm:PersonPriority(true,false)<wm:PersonPriority(false,true) and wm:PersonPriority(false,true)<wm:PersonPriority(false,false))
local original=G.members
local function person(name,index)return {name=name,key=name:lower(),guildKey=G.currentGuild,online=true,class="Mage",classFile="MAGE",level=34,rank="Member",rankIndex=index,note="",zone="City"}end
local normal,fav,pin,both=person("A normal",0),person("B favorite",1),person("C pinned",2),person("D both",3)
G.members={normal,fav,pin,both};G.rosterFilter="all";G.query="";gp.offline=false
if not G:IsMemberFavorite(fav)then G:ToggleMemberFavorite(fav)end
if not G:IsMemberPinned(pin)then G:ToggleMemberPin(pin)end
if not G:IsMemberFavorite(both)then G:ToggleMemberFavorite(both)end
if not G:IsMemberPinned(both)then G:ToggleMemberPin(both)end
G:FilterRoster();assert(G.filtered[1]==both and G.filtered[2]==fav and G.filtered[3]==pin and G.filtered[4]==normal)
assert(G.rows[1].favoriteButton.actionSelected and G.rows[1].pinControl.actionSelected)
G:ShowGuildInfo();gp.rosterShown=false
G.room:SetMinimized(true,true)
local action=G.room.hubActionButtons.Roster;assert(not action.disabled)
action:GetScript("OnClick")(action)
if G.room.finishCollapse then G.room.finishCollapse()end
assert(not G.room.minimized and gp.rosterShown and not G.compact and not G.infoMode,"minimized member counter did not restore the roster")
G.members=original;G:FilterRoster()
W:ClearPreviewData();W:StartPreview();W:SetPeopleFilter("all")
local samples=W.previewConversations
for _,p in ipairs(samples)do p.favorite=false;p.pinned=false end
samples[1].pinned=true;samples[2].favorite=true;samples[3].favorite=true;samples[3].pinned=true
W:LayoutPeopleRows(true)
assert(W.peopleOffsets[3]<W.peopleOffsets[2] and W.peopleOffsets[2]<W.peopleOffsets[1])
local sample=W.previewTabs[1];W.previewSelected=2;W:UpdatePreviewBadges()
assert(sample.pinControl:IsShown() and not sample.pinControl.disabled)
local target=samples[1];local previous=target.pinned;sample.pinControl:GetScript("OnClick")();assert(target.pinned~=previous,"unselected row pin did nothing")
W:ClearPreviewData()
""")
print('Shared people rows passed: right-side independent actions, stable selection geometry, unread clearance, identical priority, filled states, inactive-row pin and minimized Guild roster restore.')

lua.execute("""
local wm=Core.Components.WindowManager;local count=0
local row=CreateFrame("Button");row:SetNormalFontObject("SunderChatDockFont");row:SetText("Person");row:SetWidth(160)
wm:LayoutPersonRow(W,row,{identity="first",onFavorite=function()count=count+1 end,onPin=function()end})
row.favoriteButton:GetScript("OnMouseDown")()
wm:LayoutPersonRow(W,row,{identity="replacement",onFavorite=function()count=count+1 end,onPin=function()end})
row.favoriteButton:GetScript("OnClick")();assert(count==0,"recycled action targeted a replacement person")
local before=Core.db.char.whisperFavorites
Core.db.char.whisperFavorites={closed="Closed Friend"}
local contact={key="closed",target="Closed Friend"}
W:ToggleSavedPin(contact);assert(W:SavedPersonPinned(contact))
W:ToggleSavedPin(contact);assert(not W:SavedPersonPinned(contact))
W:ToggleSavedFavorite(contact);assert(not Core.db.char.whisperFavorites.closed,"favorite without history could not be removed")
Core.db.char.whisperFavorites=before
""")

lua.execute("""
local wm=Core.Components.WindowManager
local root=CreateFrame("Frame");root:SetSize(500,300)
local surface=wm:ApplySurface(root,{sidebarWidth=160,opacity=.5})
assert(surface.fade.points.TOPLEFT.x==160 and surface.sidebar.rgba[4]==.675,"list backing still depends on transcript fade")
root:SetWidth(900);wm:ApplySurface(root,{sidebarWidth=200,opacity=.5})
assert(surface.fade.points.TOPLEFT.x==200 and surface.sidebar.rgba[4]==.675,"resize changed idle list tint")
wm:ApplySurface(root,{sidebarWidth=200,opacity=0})
assert(surface.sidebar.rgba[4]==0,"list backing ignored transparent appearance")
""")

lua.execute("""
local oldCache=Core.db.char.whisperPersonDetails
Core.db.char.whisperPersonDetails={}
W:RememberPersonDetails("Old Contact",{level=35,classFile="MAGE",class="Mage",online=true,note="not saved"})
W.personMetadata={};W.whisperClasses={}
local known=W:PersonDetails("Old Contact")
assert(known.level==35 and known.classFile=="MAGE" and known.online==nil and known.note==nil,"identity was session-only or saved presence")
W:RememberPersonDetails("Old Contact",{level=0,classFile="MAGE"})
assert(W:PersonDetails("Old Contact").level==35,"offline zero erased last known level")
for i=1,220 do W:RememberPersonDetails("Bounded "..i,{classFile="ROGUE"})end
local count=0;for _ in pairs(Core.db.char.whisperPersonDetails)do count=count+1 end
assert(count<=200,"identity cache is unbounded")
Core.db.char.whisperPersonDetails=oldCache
""")

lua.execute("""
local root=CreateFrame("Frame");root:SetSize(680,300)
local surface=Core.Components.WindowManager:ApplySurface(root,{headerHeight=24,bodyTop=24,listTop=56,sidebarWidth=190})
assert(surface.fade.points.TOPLEFT.x==190 and surface.fade.points.TOPLEFT.y==-32,"transcript fade paints only part of full-width filter row")
""")

lua.execute("""
local members,filtered=G.members,G.filtered
local guild=G.currentGuild
local member={name="Shared Favorite",key="shared favorite",guildKey=guild,online=true,level=35,class="Mage",classFile="MAGE",rank="Member",rankIndex=1,note="",zone="City"}
G.members={member};G.filtered={member};G.rosterFilter="all";G.query=""
W:ClearPreviewData();W:OpenMessages();W:SetPeopleFilter("favorites")
local before=0;for _ in pairs(W.records)do before=before+1 end
G:ToggleMemberFavorite(member)
assert(W:IsPersonFavorite(member.key) and G:IsMemberFavorite(member),"Guild star did not create shared favorite")
local after=0;for _ in pairs(W.records)do after=after+1 end
assert(before==after,"favoriting opened a native conversation")
local saved
for _,row in pairs(W.savedFavoriteRows or {})do if row:IsShown() and row.contact and row.contact.key==member.key then saved=row end end
assert(saved and saved.favoriteButton.actionSelected,"Guild favorite absent from Whispers Favorites")
local previousGet=Core.GetModule
local history={ImportArchive=function()Core.db.char.whisperArchive=Core.db.char.whisperArchive or {};return Core.db.char.whisperArchive end}
function Core:GetModule(name,...)if name=="WhisperTabs"then return history end;return previousGet(self,name,...)end
local key="WHISPER:"..member.key
history:ImportArchive()[key]={kind="WHISPER",target=member.name,favorite=true,lines={},closed=true}
Core.db.char.whisperTabs={{kind="WHISPER",target=member.name,favorite=true,lines={}}}
W:ToggleSavedFavorite({key=member.key,target=member.name,archiveKey=key})
assert(not G:IsMemberFavorite(member) and not W:IsPersonFavorite(member.key),"Whispers unstar did not update Guild")
assert(not history:ImportArchive()[key].favorite and not Core.db.char.whisperTabs[1].favorite,"unstar left a stale restored favorite")
local frame=conversation("SharedFavoriteFixture",member.name);W:OnWindowOpened(frame);drain()
W:ToggleFavorite(frame);assert(G:IsMemberFavorite(member) and W:IsFavorite(frame),"open Whispers star did not update Guild")
G:ToggleMemberFavorite(member);assert(not W:IsFavorite(frame) and not W.records[frame].favorite,"Guild unstar left live record stale")
-- Union existing Guild preferences once, without requiring the room to be open.
Core.db.char.guildChat.memberFavorites={['legacy guild favorite']=true}
W:EnsureWorkspaces()
assert(W:IsPersonFavorite("legacy guild favorite") and not Core.db.char.guildChat.memberFavorites,"legacy Guild preferences were lost")
W:SetPersonFavorite("legacy guild favorite","Legacy Guild Favorite",false)
W:EnsureWorkspaces();assert(not W:IsPersonFavorite("legacy guild favorite"),"legacy import resurrected removed favorite")
W:SetPersonFavorite(member.key,member.name,true)
G.currentGuild="Another guild";G:IsMemberPinned(nil)
assert(W:IsPersonFavorite(member.key),"guild change erased personal favorite")
G.currentGuild=guild;G.members=members;G.filtered=filtered;Core.GetModule=previousGet
""")
print('Shared favorites passed: Guild-to-Whispers saved contact without opening chat, reverse star/unstar, live/archive/checkpoint synchronization, one-time migration and guild-change retention.')

lua.execute("""
Core.db.char.sharedPersonFavoritesMigrated=nil
Core.db.char.whisperArchive=Core.db.char.whisperArchive or {}
Core.db.char.whisperArchive['WHISPER:legacy archive favorite']={kind="WHISPER",target="Legacy Archive Favorite",favorite=true,lines={}}
W:EnsureWorkspaces();assert(W:IsPersonFavorite("legacy archive favorite"),"legacy history star not shared")
W:SetPersonFavorite("legacy archive favorite","Legacy Archive Favorite",false)
W:EnsureWorkspaces();assert(not W:IsPersonFavorite("legacy archive favorite"),"archive import resurrected removed favorite")
""")

lua.execute("""
W:ClearPreviewData();W:OpenMessages();W:SetMinimized(false,true)
W:SetPersonFavorite("new guild contact","New Guild Contact",true)
W:SetPeopleFilter("all")
for _,row in pairs(W.savedFavoriteRows or {})do assert(not row:IsShown() or row.contact.key~="new guild contact","Guild star created empty All conversation")end
W:SetPeopleFilter("favorites")
local found=false;for _,row in pairs(W.savedFavoriteRows or {})do if row:IsShown() and row.contact.key=="new guild contact"then found=true end end
assert(found,"new contact absent from Favorites")
local frame=conversation("ContactOnlyFixture","New Guild Contact");frame.history={};W:OnWindowOpened(frame);drain();W:MoveToWorkspace(frame,"messages")
W:SelectConversation(frame,false);assert(W.peopleFilter=="favorites" and W.hubEmpty:IsShown() and W.hubEmpty:GetText():find("No messages yet.",1,true),"selected contact has blank pane")
W:SetPeopleFilter("all");assert(not W.hubTabs[frame]:IsShown(),"empty starred native frame leaked into All")
frame.history={{text="First real message",typeID=ChatTypeInfo.WHISPER.id}}
W:OnNativeMessage(frame,ChatTypeInfo.WHISPER.id);drain();W:SetPeopleFilter("all")
assert(W.hubTabs[frame]:IsShown() and not W.hubEmpty:IsShown(),"first real message did not promote contact to conversation")
""")
