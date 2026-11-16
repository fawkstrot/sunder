exec(open('work/test_guild_chat.py',encoding='utf-8').read())
lua.execute("""
Party={};local previous=Core.GetModule
function Core:GetModule(name,...)if name=="PartyChat"then return Party end;return previous(self,name,...)end
partyActive=false;partyRaid=false;instanceParty=false
units={player={name="Local Hero",guid="LocalGUID",role="DAMAGER",leader=true},party1={name="Party Tank",guid="TankGUID",role="TANK"},party2={name="Offline Mage",guid="OfflineGUID",online=false}}
LE_PARTY_CATEGORY_INSTANCE=2
IsInGroup=function(category)if category==2 then return partyActive and instanceParty end;return partyActive end
IsInRaid=function()return partyRaid end
GetNumGroupMembers=function()if not partyActive then return 0 end;return partyRaid and 40 or 3 end
GetUnitName=function(unit)return units[unit] and units[unit].name end
UnitGUID=function(unit)return units[unit] and units[unit].guid end
UnitClass=function()return "Mage","MAGE"end
UnitLevel=function()return 35 end
UnitGroupRolesAssigned=function(unit)return units[unit] and units[unit].role or "NONE"end
UnitIsGroupLeader=function(unit)return units[unit] and units[unit].leader or false end
UnitIsConnected=function(unit)return units[unit] and units[unit].online~=false end
GetInstanceInfo=function()return "The Deadmines","party",1,"Normal"end
GetReadyCheckStatus=function()return "ready"end
ChatTypeInfo.PARTY={id=50};ChatTypeInfo.PARTY_LEADER={id=51};ChatTypeInfo.RAID={id=52};ChatTypeInfo.RAID_WARNING={id=53};ChatTypeInfo.INSTANCE_CHAT={id=54}
partyOpens=0;partyFilters={}
ChatFrame_AddMessageEventFilter=function(event,callback)partyFilters[event]=callback end
FCF_OpenNewWindow=function(name,noDefaults)
 assert(name=="Party Chat" and noDefaults);partyOpens=partyOpens+1
 local frame,window=conversation("ChatFrame4",name,"PARTY")
 frame.isTemporary=false;frame.id=4;frame.history={};frame.groups={SAY=true};frame.channels={General=true}
 frame.historyBuffer={GetEntryAtIndex=function(_,i)return frame.history[#frame.history-i+1]end}
 nativeNames[4]=name;return frame,4
end
""")
lua.execute(root.joinpath('Modules/PartyChat.lua').read_text(encoding='utf-8'),'Sunder',lua.globals().vars)
lua.execute("""
Core.db.profile.partyChat=clone(Core.defaults.profile.partyChat);local cfg=Core.db.profile.partyChat
assert(cfg.autoOpen,"automatic opening is not the default")
cfg.autoOpen=false;cfg.autoOpenConfigured=true;Core.db.char.partyChat={};combat=false
Party:OnEnable();drain();assert(not Party.grouped and partyOpens==0 and not cfg.autoOpen)
Core.features.partyChat.buildOptions().args.collapse.get()
assert(not Party.room.hub:IsShown() and partyOpens==0,"viewing settings opened a manual room")
Party:Open();drain()
local frame=Party.frame;local h=Party.room;local window=ui:GetChatWindow(frame)
assert(frame and h.hub:IsShown() and not Party:CanSend() and not window.editBox:IsShown())
assert(not ui:SelectMessageInput(frame),"solo room accepted message input")
assert(h.hubActionButtons.CollapseTop and h.hubActionButtons.CollapseBottom and h.roomResize and h.hubActionButtons.Info)
assert(Core.Components.WindowManager:GetChatRoom(frame)==Party and Core.Components.WindowManager:GetChatRoom(G.frame)==G)
Party:CloseRoom();cfg.autoOpen=true
local selected=SELECTED_CHAT_FRAME
partyActive=true;Party:RefreshRoster();drain()
assert(Party.grouped and Party.totalCount==3 and Party.onlineCount==2 and Party:CanSend())
assert(Party.room.hub:IsShown() and partyOpens==1 and SELECTED_CHAT_FRAME==selected,"automatic opening stole editor ownership or created another native slot")
assert(window.editBox.inputType=="PARTY" and Party.conversationLabel:GetText():find("The Deadmines",1,true))
assert(Party.filtered[1].name=="Local Hero" and Party.filtered[2].rank=="Tank")
assert(frame.groups.PARTY_LEADER and frame.groups.RAID_LEADER and frame.groups.INSTANCE_CHAT_LEADER)
frame.groups.PARTY_LEADER=nil;Party:ConfigureFrame(frame,false);assert(frame.groups.PARTY_LEADER,"saved slot not repaired")
assert(frame.groups.PARTY and frame.groups.RAID and not frame.groups.GUILD and not frame.groups.SAY and not frame.channels.General)
Party:OnGroupMessage("CHAT_MSG_PARTY","TankGUID");assert(Party.unread==0)
h:SetMinimized(true,true);Party:OnGroupMessage("CHAT_MSG_PARTY","TankGUID");assert(Party.unread==1)
Party:OnGroupMessage("CHAT_MSG_PARTY","LocalGUID");Party:OnGroupMessage("CHAT_MSG_RAID","Other");assert(Party.unread==1)
h.hubActionButtons.Roster:GetScript("OnClick")();drain();for i=1,30 do local tick=h.hub:GetScript("OnUpdate");if tick then tick(h.hub,.02)end end;assert(not h.minimized and cfg.rosterShown and Party.unread==0)
Party:ToggleMemberFavorite(Party.members[2]);assert(W:IsPersonFavorite("party tank"))
W:SetPersonFavorite("party tank","Party Tank",false);assert(not Party:IsMemberFavorite(Party.members[2]))
Party.frame.history={{text="Prior group message",typeID=50}};Party:SaveHistory()
assert(#Core.db.char.partyRoomHistory.lines==1)
local retained=Party.frame.history;Party.frame.history={};Party:SaveHistory(true)
assert(#Core.db.char.partyRoomHistory.lines==1,"empty native slot erased retained transcript")
Party.frame.history=retained
local session=Party.sessionKey
partyRaid=true
for i=1,40 do units["raid"..i]={name="Raid Member "..i,guid="RaidGUID"..i,role="DAMAGER",leader=i==1}end
Party:RefreshRoster();drain()
assert(Party.sessionKey==session and Party.room:WorkspaceName()=="Raid Chat" and Party.configuredType=="RAID")
assert(Party.totalCount==40 and #Party.rows<40,"raid roster is not virtualized")
assert(partyFilters.CHAT_MSG_PARTY(frame,"CHAT_MSG_PARTY") and not partyFilters.CHAT_MSG_RAID(frame,"CHAT_MSG_RAID"))
assert(partyFilters.CHAT_MSG_PARTY(ChatFrame1,"CHAT_MSG_PARTY"),"open room leaked group chat to General")
instanceParty=true;Party:RefreshRoster();assert(window.editBox.inputType=="INSTANCE_CHAT")
instanceParty=false;partyRaid=false;partyActive=false
Party:RefreshRoster();drain();assert(not Party:CanSend() and not window.editBox:IsShown() and Party.totalCount==0)
assert(Party.conversationLabel:GetText()=="Previous group" and #Core.db.char.partyRoomHistory.lines==1, "left caption="..tostring(Party.conversationLabel:GetText()).." history="..#Core.db.char.partyRoomHistory.lines)
window.editBox:SetText("Old draft");partyActive=true;units.party1.name="Different Party Member"
Party:RefreshRoster();drain()
assert(Party.sessionKey~=session and frame:GetNumMessages()==0 and window.editBox:GetText()=="","new group inherited previous messages/draft")
Party:CloseRoom();Party:RefreshRoster();assert(not h.hub:IsShown(),"roster refresh reopened a manually closed room")
Party:Open();combat=true;Party:CloseRoom();Party:Open()
assert(Party.pendingOpen and not h.hub:IsShown())
combat=false;Party.events:GetScript("OnEvent")(Party.events,"PLAYER_REGEN_ENABLED");drain();assert(h.hub:IsShown())
local history={{text="Same session after reload",typeID=50}};frame.history=history;Party:SaveHistory()
local current=Party.sessionKey
Party.groupInitialized=nil;Party.sessionKey=nil;Party.currentGuild=nil
Party:RefreshRoster();assert(Party.sessionKey==current and frame:GetNumMessages()==1,"same-group reload discarded history")
Party.readyCheck=nil;Party.events:GetScript("OnEvent")(Party.events,"READY_CHECK");drain();assert(Party.readyCheck)
Party.events:GetScript("OnEvent")(Party.events,"READY_CHECK_FINISHED");drain();assert(not Party.readyCheck)
local E=Core:GetModule("Ellesmere");assert(not E:IsDetachedEditWindow(window),"party native slot registered as a duplicate mover")
""")
print('Party room passed: shared shell and routing, no-party read-only state, auto/manual open without focus theft, roles/offline roster, virtualization, shared favorites, unread/own filtering, instance/raid conversion, isolated bounded recall, new-group reset, combat deferral and ready-check state.')

lua.execute("""
-- Closed native slots still bind to their room controller on restore, never a bare detached shell.
Party:CloseRoom();local oldFrame=Party.frame;Party.frame=nil
Party:RestoreWindow();assert(Party.frame==oldFrame and not Party.room.hub:IsShown(),"closed party room became a native fallback window")
Party:Open();Party.room:SetMinimized(true,true)
Party.frame=nil;Party:RestoreWindow();assert(Party.room.minimized and Party.room.hub:IsShown(),"minimized restore lost room state")
Party.room:SetMinimized(false,true)
-- Late roster information must not discard a saved transcript prematurely.
Party:SaveHistory();local retained=Core.db.char.partyRoomHistory
Party.groupInitialized=nil;local getName=GetUnitName;GetUnitName=function(unit)if unit=="player"then return getName(unit)end end
Party:RefreshRoster();assert(Party.waitingForRoster and Core.db.char.partyRoomHistory==retained,"partial startup roster erased history")
GetUnitName=getName;Party:RefreshRoster();assert(not Party.waitingForRoster)
""")

lua.execute("""
-- Shared history budgets and identity survive a real room replay path.
frame=Party.frame;frame.history={}
for i=1,230 do frame.history[i]={text=tostring(i)..string.rep("x",3000),typeID=50}end
Party:SaveHistory();local saved=Core.db.char.partyRoomHistory
local bytes=0;for _,line in ipairs(saved.lines)do bytes=bytes+#line[1]end
assert(#saved.lines<=200 and bytes<=512*1024,"party history exceeds shared budgets")
frame:Clear();Party.restoredFrame=nil;Party:RestoreHistory();drain()
assert(frame:GetNumMessages()==#saved.lines and not Party.restoringHistory,"bounded party replay incomplete")
-- A dedicated orphan native slot is recovered without allocating a new one.
local info=GetChatWindowMessages
GetChatWindowMessages=function(id)if id==4 then return "PARTY","RAID","RAID_WARNING","INSTANCE_CHAT"end;return info and info(id)end
Core.db.char.partyChat.frameID=nil
local recovered,orphan=Party:SavedFrame();assert(recovered==frame and orphan,"orphan party native slot was not recovered")
GetChatWindowMessages=info
-- One actual room mover uses the right settings page; the borrowed native frame is excluded.
local E=Core:GetModule("Ellesmere");E:SetupEditModeIntegration()
assert(E.editElements.Sunder_PartyChat and E.editElements.Sunder_PartyChat.frame==Party.room.hub,"party mover did not use the actual shared root")
assert(not E:IsDetachedEditWindow(ui:GetChatWindow(frame)))
""")

lua.execute("""
local cfg=Core.db.profile.partyChat;local h=Party.room
h:SetMinimized(true,true);local geometry=clone(h:HubSettings());local selected=SELECTED_CHAT_FRAME
cfg.autoOpen=false;cfg.autoOpenConfigured=nil;cfg.autoOpenPolicyVersion=nil
Party:InitializeOpenPolicy();assert(cfg.autoOpen and Party.openOnPolicyUpgrade,"old manual default was not migrated")
Party:RefreshRoster();drain()
assert(h.hub:IsShown() and h.minimized and not h.hubContent:IsShown(),"automatic policy upgrade discarded minimized state")
assert(h:HubSettings().hubWidth==geometry.hubWidth and h:HubSettings().hubHeight==geometry.hubHeight,"automatic opening rewrote full-size geometry")
assert(SELECTED_CHAT_FRAME==selected,"automatic policy upgrade stole input")
local option=Core.features.partyChat.buildOptions().args.automatic
assert(not option.get(),"manual-only option is on by default")
option.set(nil,true);assert(not cfg.autoOpen and cfg.autoOpenConfigured)
cfg.autoOpenPolicyVersion=nil;Party:InitializeOpenPolicy();assert(not cfg.autoOpen,"explicit manual preference overwritten")
Party:CloseRoom();partyActive=false;Party:RefreshRoster();partyActive=true;Party:RefreshRoster();drain()
assert(not h.hub:IsShown(),"manual-only option opened on joining")
option.set(nil,false);drain();assert(h.hub:IsShown() and h.minimized,"enabling automatic opening lost saved minimized state")
""")
print('Automatic state policy passed: default/old-default migration, current-party opening, manual-only override, geometry/minimized preservation and no editor ownership changes.')

lua.execute("""
partyActive=true;partyRaid=false;Party:RefreshRoster();Party:Open();assert(not Party.search:IsShown(),"party search retained")
local partyTop=Party.scroll.points.TOPLEFT.y
partyRaid=true;Party:RefreshRoster();assert(Party.search:IsShown() and Party.scroll.points.TOPLEFT.y<partyTop,"raid search did not reserve its own space")
Party.search:SetText("no match");Party.search:GetScript("OnTextChanged")(Party.search);partyRaid=false;Party:RefreshRoster()
assert(not Party.search:IsShown() and Party.query=="" and #Party.filtered==3,"hidden party search still filters members: shown="..tostring(Party.search:IsShown()).." query="..tostring(Party.query).." count="..#Party.filtered.." members="..#Party.members.." minimized="..tostring(Party.room.minimized))
""")

lua.execute("""
local filter=partyFilters.CHAT_MSG_PARTY;local frame=Party.frame;local h=Party.room
Party:Open();partyActive=true;partyRaid=false;Party:RefreshRoster()
assert(filter(ChatFrame1,"CHAT_MSG_PARTY") and not filter(frame,"CHAT_MSG_PARTY"))
assert(not filter(CreateFrame("Frame"),"CHAT_MSG_PARTY"),"unrelated tab suppressed")
h:SetMinimized(true,true);assert(filter(ChatFrame1,"CHAT_MSG_PARTY"),"minimized room leaked chat")
Party:CloseRoom();assert(not filter(ChatFrame1,"CHAT_MSG_PARTY"),"closed room suppressed General")
Party:Open();Core.db.profile.partyChat.enabled=false;assert(not filter(ChatFrame1,"CHAT_MSG_PARTY"))
Core.db.profile.partyChat.enabled=true
local oldGeneral=ChatFrame1;ChatFrame1=bodyGeneral
local window=ui:GetChatWindow(frame);window.editBox:SetText("Retain draft")
ui:SelectMessageInput(frame);assert(SELECTED_CHAT_FRAME==frame)
Party:CloseRoom();assert(SELECTED_CHAT_FRAME==ChatFrame1 and window.editBox:GetText()=="Retain draft","closed input lost draft or destination")
ChatFrame1=oldGeneral
local wm=Core.Components.WindowManager
local oldInspect,oldCan,oldDistance=InspectUnit,CanInspect,CheckInteractDistance
local inspected;InspectUnit=function(unit)inspected=unit end;CanInspect=function(unit)return unit=="party1"end
CheckInteractDistance=function()return true end
local entries={};local menu={CreateButton=function(_,name,fn)local b={name=name,fn=fn,SetEnabled=function(self,v)self.enabled=v end};entries[#entries+1]=b;return b end}
wm:AddInspectAction(menu,units.party1.name);assert(entries[1].enabled);entries[1].fn();assert(inspected=="party1")
units.party1.name="Replacement";inspected=nil;entries[1].fn();assert(not inspected,"stale menu inspected replacement")
wm:AddInspectAction(menu,"Unknown Player");assert(not entries[2].enabled)
InspectUnit,CanInspect,CheckInteractDistance=oldInspect,oldCan,oldDistance
""")

lua.execute("""
local wm=Core.Components.WindowManager
assert(wm:PeopleSidebarWidth(600,100)==150 and wm:PeopleSidebarWidth(600,300)==150)
assert(wm:PeopleSidebarWidth(340,190)==120,"narrow sidebar consumed conversation reserve")
assert(wm:PeopleSidebarWidth(600,100,170)==150,"legacy maximum defeated shared minimum")
partyActive=true;partyRaid=false;Party:RefreshRoster();Party:Open()
local oldWidth=W.hub:GetWidth();W.hub:SetWidth(600)
for _,room in ipairs({Party,G})do
 room.room.hub:SetWidth(600);room.room.hub:SetHeight(400)
 local options=Core.db.profile[room==Party and "partyChat" or "guildChat"]
 options.rosterShown=true;room:LayoutWindow(ui:GetChatWindow(room.frame))
 assert(room.panel:GetWidth()==150,"room bypassed shared list minimum")
end
assert(W:ConversationListWidth()==150,"Whispers bypassed Guild-sized minimum")
W.hub:SetWidth(oldWidth)
""")

lua.execute("""
for _,room in ipairs({Party,G})do
 local smf=ui:GetChatWindow(room.frame).slidingMessageFrame
 local original=smf.RefreshLayout;local reprocessed=0
 local oldScroll=smf.SetScrollPosition;local oldIndex,oldOffset=smf.state.scrollIndex,smf.state.messageOffset;local restoredIndex,restoredOffset
 smf.SetScrollPosition=function(_,index,offset)restoredIndex,restoredOffset=index,offset end
 smf.RefreshLayout=function(self,reprocess)if reprocess then reprocessed=reprocessed+1 end end
 room.room:SetMinimized(false,true);smf.roomLabelOwner=nil
 smf.state.scrollIndex=3;smf.state.messageOffset=7
 room:LayoutWindow(ui:GetChatWindow(room.frame))
 assert(reprocessed==1 and smf.roomLabelOwner==room,"late room binding retained General-formatted rows")
 assert(smf.state.scrollIndex==3 and smf.state.messageOffset==7 and restoredIndex==nil,"late binding lost readback position")
 room:LayoutWindow(ui:GetChatWindow(room.frame));assert(reprocessed==1,"ordinary room layout reformatted all rows")
 smf.RefreshLayout=original;smf.SetScrollPosition=oldScroll;smf.state.scrollIndex,smf.state.messageOffset=oldIndex,oldOffset
end
""")

lua.execute("""
partyActive=false;Party:RefreshRoster();Party:Open();Party.hasRecentHistory=false;Party.frame:Clear()
local window=ui:GetChatWindow(Party.frame);Party:LayoutWindow(window)
assert(Party.panel:IsShown() and Party.conversationLabel:IsShown() and Party.motdLabel:IsShown(),"solo layout lost its roster or caption")
assert(not Party.conversationEmpty:IsShown() and not Party.conversationEmptyIcon:IsShown(),"solo caption repeated an empty-state instruction")
assert(window.slidingMessageFrame.layoutWidth<Party.room.hub:GetWidth(),"solo layout lost its member column")
assert(Party.conversationEmpty:GetText():find("Your next group starts here.",1,true) and Party.conversationEmpty:GetText():find("Join a party or raid to chat.",1,true))
Core.Components.WindowManager:RefreshRoomActions(Party.room)
assert(not Party.room.hubActionButtons.Roster.actionDisabled)
partyActive=true;Party:RefreshRoster();Party:LayoutWindow(window)
assert(Party.panel:IsShown() and Party.conversationLabel:IsShown(),"joining did not restore normal chrome")
Core.Components.WindowManager:RefreshRoomActions(Party.room);assert(not Party.room.hubActionButtons.Roster.actionDisabled)
""")

# Archive service tests use the actual adapter; no game messages or saved account data.
lua.execute(root.joinpath('Modules/PartyHistory.lua').read_text(encoding='utf-8'),'Sunder',lua.globals().vars)
lua.execute("""
Core.db.char.partyRoomArchive=nil
Party.frame.history={{text="Leader line",typeID=51},{text="Member line",typeID=50}}
Party:SaveHistory()
local records=Party:HistoryRecords();assert(#records==1 and #records[1].lines==2)
local oldKey=records[1].key
partyActive=false;Party:RefreshRoster();partyActive=true;Party:RefreshRoster()
assert(#records==1 and records[1].key==oldKey and #records[1].lines==2,"new party erased archive")
Party.frame.history={{text="New group",typeID=50}};Party:SaveHistory()
assert(#records==2 and records[1].key~=oldKey and #records[2].lines==2)
Party.groupInitialized=nil;Party:RefreshRoster();assert(#records==2,"reload duplicated archived session")
for i=1,40 do Party.currentGuild="bounded:"..i;Party.sessionKey=Party.currentGuild;Party.frame.history={{text="Bounded",typeID=51}};Party:SaveHistory()end
assert(#records==30,"archive record cap failed")
Party.historyMode=true;assert(not Party:CanSend(),"archive allowed live input")
Party.room.hub:Show();Party.room.minimized=false;Party.unread=0
Party:OnGroupMessage("CHAT_MSG_PARTY","OtherGUID");assert(Party.unread==1,"archive browsing acknowledged live messages")
Party.historyMode=nil
""")

lua.execute("""
-- Browse through the real shared room/controller while isolating only the transcript widget.
local m=getmetatable(UIParent).__index
function m:GetFrameLevel()return self.frameLevel or 1 end
Core.Components.CreateReadOnlyTranscript=function(parent)
 local f=CreateFrame("Frame",nil,parent)
 function f:SetLines(lines)self.lines=lines end
 f.ShowAppendedLines=f.SetLines
 function f:Render()end
 return f
end
Party:ToggleHistory(true)
assert(Party.historyPanel.transcript.points.BOTTOMRIGHT.x==0 and Party.historyPanel.transcript.points.BOTTOMRIGHT.y==0)
assert(Party.historyPanel:IsShown() and not Party.column:IsShown() and not Party:CanSend())
assert(not Party.panel:IsShown() and not Party.conversationLabel:IsShown() and not Party.motdLabel:IsShown(),"live labels bleed through archive")
assert(Party.historyPanel.transcript.lines and #Party.historyPanel.transcript.lines==1)
local show=Party.panel:GetScript("OnShow")
Party.panel:SetScript("OnShow",function()error("archive refresh flashed live roster and rescheduled work")end)
Party:LayoutWindow(ui:GetChatWindow(Party.frame));Party.panel:SetScript("OnShow",show)
local oldPad=Core.db.profile.bodyPadding
for _,pad in ipairs({0,19})do
 Core.db.profile.bodyPadding=pad
 Party:LayoutWindow(ui:GetChatWindow(Party.frame))
 assert(Party.historyPanel.list.points.TOPLEFT.x==0 and Party.historyPanel.rows[1].name.points.TOPLEFT.x==pad)
end
Core.db.profile.bodyPadding=oldPad
Party:ToggleHistory(false)
assert(not Party.historyPanel:IsShown() and Party.column:IsShown() and Party:CanSend())
local savedArchive=Core.db.char.partyRoomArchive
Core.features.partyChat.buildOptions().args.remember.set(nil,false)
assert(Core.db.char.partyRoomArchive==savedArchive,"turning off recording deleted archive")
""")

# Drive the same practice script that the client schedules. Keep real rooms active.
lua.execute(root.joinpath("Modules/ChatPractice.lua").read_text(encoding="utf-8-sig"),"Sunder",lua.globals().vars)
lua.execute("""
local practice=Core.Components.ChatPractice
local function equal(a,b)
 if type(a)~="table" then return a==b end
 if type(b)~="table" then return false end
 for k,v in pairs(a) do if not equal(v,b[k]) then return false end end
 for k in pairs(b) do if a[k]==nil then return false end end
 return true
end
local char,profile=clone(Core.db.char),clone(Core.db.profile)
local realSelected,realFrame,realArchive,realUnread=W.selected,Party.frame,Party:HistoryRecords(),Party.unread
local routes=partyOpens
local liveEditor=ui:GetChatWindow(Party.frame).editBox
liveEditor:SetText("An unrelated live draft")
local liveFocus=SELECTED_CHAT_FRAME
local liveSend=SendChatMessage
SendChatMessage=function()error("practice attempted to send chat")end
C_Timer.NewTimer=function(delay,callback)
 return {delay=delay,fn=callback,Cancel=function(self)self.cancelled=true end}
end
practice:Toggle()
local r=practice.owner
assert(practice.active and practice.timer and r.kind=="Whispers")
local stale=practice.timer
now=GetTime()+0.5
practice:Pause(true);assert(stale.cancelled and not practice.timer)
assert(math.abs(practice.remaining-0.5)<.001,"pause lost the remaining quiet interval")
now=GetTime()+10;practice:Pause(false)
assert(math.abs(practice.timer.delay-0.5)<.001)
practice:Pause(true)
stale.fn();assert(practice.index==1)
practice:Step();assert(r.selectedMember=="Elowen" and not practice.timer)
local editor=practice.controls.draft
editor:SetText("Unsent practice draft");editor:GetScript("OnTextChanged")(editor)
practice:Pause(false);local timer=practice.timer;timer.fn();assert(practice.index==3)
while practice.index<#practice.events do
 practice:Step()
 if practice.lastEvent=="message" and r.kind=="Whispers" and practice.index==5 then
   assert(r.selectedMember=="Elowen" and r.records.Mira.unread==1 and r.room.minimizedWhispers[1].person==r.records.Mira)
   r.room:OpenMinimizedWhisper(r.room.minimizedWhispers[1]);assert(r.selectedMember=="Mira" and r.records.Mira.unread==0)
   editor:SetText("Local reply");editor:GetScript("OnTextChanged")(editor);editor:GetScript("OnEnterPressed")(editor)
   assert(r.records.Mira.lines[#r.records.Mira.lines].own)
   r:ShowMemberCard(r.records.Elowen);assert(editor:GetText()=="Unsent practice draft")
 elseif practice.lastEvent=="archive" then assert(r.historyMode and r.historyPanel:IsShown())
 elseif practice.lastEvent=="message" and r.historyMode then
   assert(#r.log==2 and #r.archives[1].lines==2 and r.historyPanel.transcript.lines==r.archives[1].lines)
 elseif practice.lastEvent=="offline" then assert(#r.members==40 and r.onlineCount==39 and #r.log==3)
 elseif practice.lastEvent=="burst" then assert(#r.log==33)
 end
end
assert(not practice.timer and practice.controls.step.disabled)
-- A real incoming group event still belongs to the real controller during practice.
Party.room.minimized=true;Party:OnGroupMessage("CHAT_MSG_PARTY","OtherGUID")
assert(Party.unread==realUnread+1)
practice:Start("Groups");local interrupted=practice.timer;practice:Toggle();interrupted.fn()
assert(not practice.active and not practice.timer and not r.room.hub:IsShown() and #r.archives==0)
assert(equal(Core.db.char,char),"sample state leaked into character data")
assert(equal(Core.db.profile,profile),"practice changed real settings")
assert(W.selected==realSelected and Party.frame==realFrame and Party:HistoryRecords()==realArchive and Party.unread==realUnread+1)
assert(partyOpens==routes and not Core.Components.WindowManager.chatRooms.chatPractice)
assert(SELECTED_CHAT_FRAME==liveFocus and liveEditor:GetText()=="An unrelated live draft")
SendChatMessage=liveSend
""")
print("Chat practice passed: complete timed script, single-step, stale timers, isolated toast selection, background group log, raid roster, burst, exit and SavedVariables equality.")
