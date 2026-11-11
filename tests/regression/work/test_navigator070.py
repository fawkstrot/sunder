exec(open('work/test_repair062.py',encoding='utf-8').read())
lua.execute('''
local m=getmetatable(UIParent).__index
function m:SetScrollOffset(n) self.scrollOffset=n end
cfg.minimizedPreviewUntilRead=true;cfg.minimizedPreviewRows=5;cfg.minimizedPreviews=true
W:ClearPreviewData();W:StartPreview();W:SetMinimized(false,true);W.minimizedWhispers={};W.whisperToastOffset=0
local c=W.previewConversations[2]
for i=1,60 do
 local line={text='Individual message '..i,outgoing=false,time=GetServerTime()};c.lines[#c.lines+1]=line
 W:QueueMinimizedWhisper(c,true,line.text)
end
assert(#W.minimizedWhispers==50 and W.minimizedWhispers[1].text=='Individual message 60')
local tray=W.minimizedWhisperTray;local anim=tray:GetScript('OnUpdate');if anim then anim(tray,.3) end
assert(tray:IsShown() and tray.rows[5]:IsShown() and (not tray.rows[6] or not tray.rows[6]:IsShown()) and tray.navigation:IsShown())
W:PageWhisperToasts(5);assert(W.whisperToastOffset==5 and tray.rows[1].entry.text=='Individual message 55')
local target=tray.rows[3].entry;local retained=#W.minimizedWhispers
for i,person in ipairs(W.previewConversations) do if person==c then W:SelectPreviewConversation(i);break end end;W:JumpToWhisperToast(target)
assert(W.previewConversations[W.previewSelected]==c and W.previewJumpLine==target.line)
assert(W.previewBody.scrollOffset==W.previewRenderedRows-target.line.renderedRow and #W.minimizedWhispers==retained)
local old=tray.rows[1].entry
W.minimized=true;c.lines[#c.lines+1]={text='arriving while browsing',outgoing=false,time=GetServerTime()};W:QueueMinimizedWhisper(c,true,'arriving while browsing')
assert(tray.rows[1].entry==old and W.whisperToastOffset==6)
W:DismissMinimizedWhisper(c,target);assert(#W.minimizedWhispers==49)
for _,entry in ipairs(W.minimizedWhispers) do assert(entry~=target) end
cfg.minimizedPreviewRows=10;W:PageWhisperToasts(-100);assert(tray.rows[10].entry and W.whisperToastOffset==0)
c.unread=0;now=GetTime()+1000;W:UpdateMinimizedWhispers();assert(#W.minimizedWhispers==49)
cfg.minimizedPreviewUntilRead=false;W:UpdateMinimizedWhispers();assert(#W.minimizedWhispers==0)
-- Class colors use normal whisper metadata; unknown classes retain theme text.
RAID_CLASS_COLORS={MAGE={r=.25,g=.78,b=.92}}
function GetPlayerInfoByGUID(guid) return 'Mage','MAGE' end
W:RememberWhisperClass('Example-Realm','Player-1')
local real=conversation('ChatFrameNavigatorTest','Example-Realm');W:OnWindowOpened(real);drain()
W.records[real].key='example-realm'
local r,g,b=W:ConversationLabelColor(false,real);assert(r==.25 and g==.78 and b==.92)
W:ClearPreviewData();cfg.idleWhisperAction='minimize';cfg.visibility='timer';cfg.holdTime=5;cfg.fadeTime=1
W:OpenMessages();W:MoveToWorkspace(real,'messages');W:SetMinimized(false,true)
W:HubSettings().keepMessagesOpen=false;W.records[real].unread=0;W.records[real].lastActivity=GetTime()-50;W.hubOpenedAt=GetTime()-50
W.hub.IsMouseOver=function() return false end
Core.sunderMoverUnlocked=false;cfg.keepUnread=false;for _,record in pairs(W.records) do record.pinned=false;record.unread=0;record.lastActivity=GetTime()-50 end
now=GetTime()+2;W:Tick();assert(W.minimized and W.hub:IsShown() and W.hub:GetAlpha()==1)
''')
print('0.7 navigator checks passed: 50 individual entries, five expanded rows, 1–10 row limits, paging, exact sample target, retained read history, stable browsing on arrivals, individual dismissal, expiry, class metadata and idle collapse.')

lua.execute("""
local frame=conversation('ChatFramePreciseToast','Precise-Realm');W:OnWindowOpened(frame);drain();W:MoveToWorkspace(frame,'messages')
local window=Core:GetModule('UIManager'):GetChatWindow(frame);local smf=window.slidingMessageFrame
function frame:GetNumMessages() return self.nativeCount or 2 end
function frame:GetMessageInfo(i) return 'Repeated text' end
W.minimized=true;W:QueueMinimizedWhisper(frame,false)
local target=W.minimizedWhispers[1];assert(target.nativeIndex==2 and target.raw=='Repeated text')
frame.nativeCount=3;smf.state={messages={}}
for i=1,3 do local line=CreateFrame('Frame',nil,smf);line.sourceText='Repeated text';line.sourceFrame=frame;smf.state.messages[i]=line end
function smf:SetScrollPosition(index,offset) self.testScrollIndex=index end
W:JumpToWhisperToast(target)
assert(smf.testScrollIndex==2 and smf.state.messages[2].whisperJumpFlash,'matched the wrong repeated message')
-- Pooled native frames must not expose the previous recipient's toast.
W.records[frame]={unread=0};W:UpdateMinimizedWhispers()
for _,entry in ipairs(W.minimizedWhispers) do assert(entry~=target) end
""")
print('Native target checks passed: repeated text resolves by exact position; recycled chat frames retire stale rows.')

lua.execute("""
local frame=conversation('ChatFrameQueuedToast','Queued-Realm');W:OnWindowOpened(frame);drain();W:MoveToWorkspace(frame,'messages')
W.minimized=true
local args={frame,'This is the arriving message'}
W:QueueMinimizedWhisper(frame,false,args[2],nil,args)
local entry=W.minimizedWhispers[1];assert(entry.text==args[2])
local smf=Core:GetModule('UIManager'):GetChatWindow(frame).slidingMessageFrame
local line=CreateFrame('Frame',nil,smf);line.sourceFrame=frame;line.whisperSourceToken=args
smf.state={messages={line}};function smf:SetScrollPosition(i) self.queuedTarget=i end
W:JumpToWhisperToast(entry);assert(smf.queuedTarget==1 and line.whisperJumpFlash)
""")
print('Native pre-hook integration passed: toast uses the arriving message and follows its renderer token, independent of native-history timing.')

lua.execute("""
W:ClearPreviewData();W:StartPreview();W:SetMinimized(false,true)
W.previewSimulation={};W.SimulationWindowAlpha=function() return .1 end
local oldTick=W.TickMessageSimulation;W.TickMessageSimulation=function() end
W.simulationStatus:Show();W:Tick();assert(W.minimized and W.collapseAnimation)
assert(W.minimizedWhisperTray.anchorInset==W.simulationStatus:GetHeight()+12)
local animation=W.hub:GetScript('OnUpdate');animation(W.hub,.2)
now=GetTime()+1;W:Tick();assert(W.hub:GetScript('OnUpdate')==animation,'idle tick restarted collapse animation')
animation(W.hub,.1);assert(not W.collapseAnimation and W.hub:IsShown())
W.previewSimulation=nil;W.TickMessageSimulation=oldTick;W:ClearPreviewData()
""")
print('Idle animation check passed: repeated simulation fade ticks do not restart an active collapse.')

