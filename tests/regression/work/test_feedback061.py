exec(open('work/test_interactions060.py',encoding='utf-8').read())
lua.execute('''
local m=getmetatable(UIParent).__index
function m:SetOrientation(v) self.orientation=v end
function m:SetValueStep(v) self.step=v end
function m:SetObeyStepOnDrag(v) end
function m:SetThumbTexture(v) self.thumb=self:CreateTexture() end
function m:GetThumbTexture() return self.thumb end
function m:SetMinMaxValues(a,b) self.minimum,self.maximum=a,b end
function m:SetValue(v) self.value=v;if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self,v) end end
''')
lua.execute(Path(os.environ['SUNDER_ADDON_ROOT']+'/Sunder/Modules/WhisperFeedback.lua').read_text(encoding='utf-8'),'Sunder',lua.globals().vars)
lua.execute('''
cfg.minimizedPreviewUntilRead=false;cfg.conversationLayout='list';cfg.minimizedPreviews=true;cfg.minimizedPreviewRows=3;cfg.minimizedPreviewTime=20
cfg.previewConversations=30;W:StartPreview();W:RefreshHubStyle()
W.previewTabScroll:SetHeight(180);W:RefreshConversationNavigation(true)
local rail=W.previewTabScroll.peopleScrollbar
assert(rail:IsShown() and rail.orientation=='VERTICAL' and rail:GetThumbTexture():GetHeight()>=18)
rail:SetValue(120);assert(W.previewTabScroll:GetVerticalScroll()==120)
assert(rail.above:IsShown() and rail.below:IsShown())
W.previewTabScroll:SetHeight(2000);W:RefreshConversationNavigation(true);assert(not rail:IsShown())
W.previewTabScroll:SetHeight(180);W:RefreshConversationNavigation(true);assert(rail:IsShown())
-- One full-width surface, with no restarted column gradients.
assert(W.whisperSurface and W.whisperSurface:IsShown())
assert(W.whisperSurface.points.TOPLEFT.x==0 and W.whisperSurface.points.TOPRIGHT.relative==W.hub and W.whisperSurface:GetHeight()>=1)
assert(W.whisperSurface.fill.paint.a==Core.db.profile.chatBackgroundColor.a)
assert(W.hubBackground.paint.a==0)
W:SetMinimized(true,true);assert(not W.whisperSurface:IsShown() and not rail:IsShown())
local first,second,third,fourth=unpack(W.previewConversations)
first.unread=1
for _,c in ipairs({first,second,third,fourth}) do W:QueueMinimizedWhisper(c,true,'A whisper from '..c.name) end
local tray=W.minimizedWhisperTray
local animate=tray:GetScript('OnUpdate');assert(animate);animate(tray,.2)
assert(tray.rows[1].entry.person==fourth and tray.rows[3].entry.person==second)
assert(not tray.rows[4] or not tray.rows[4]:IsShown())
assert(tray:GetHeight()>100 and not tray:GetScript('OnUpdate'))
local original=#W.minimizedWhispers
W:QueueMinimizedWhisper(fourth,true,'Updated whisper');assert(#W.minimizedWhispers==original+1)
assert(tray.rows[1].snippet:GetText()=='Updated whisper')
local remaining=0;for _,entry in ipairs(W.minimizedWhispers) do if entry.person~=fourth then remaining=remaining+1 end end
tray.rows[2]:GetScript('OnClick')()
assert(not W.minimized and W.previewConversations[W.previewSelected]==fourth)
local finish=W.hub:GetScript('OnUpdate');if finish then finish(W.hub,.3) end
assert(#W.minimizedWhispers==remaining and W.previewTabs[W.previewSelected].pinRecord==fourth)
-- Toggle off means no tray; expiry does not clear unread counts.
W.minimizedWhispers={};cfg.minimizedPreviews=false;W:SetMinimized(true,true);W:QueueMinimizedWhisper(first,true,'hidden');assert(#W.minimizedWhispers==0)
cfg.minimizedPreviews=true;first.unread=7;W:QueueMinimizedWhisper(first,true,'expires');now=GetTime()+21;W:UpdateMinimizedWhispers()
assert(#W.minimizedWhispers==0 and first.unread==7)
-- The detached sample queues clear alongside all test content.
W:PreviewAction('Detach',second);local detached=second.host;detached:SetMinimized(true,true)
detached:QueueMinimizedWhisper(second,true,'detached test');assert(#detached.minimizedWhispers>=1)
W:ClearPreviewData();assert(#detached.minimizedWhispers==0)
-- Native previews restore the selected real conversation, with the native renderer/editor.
W:OpenMessages();local real=conversation('ChatFramePreviewReal','PreviewReal-Realm')
W:OnWindowOpened(real);drain();W:MoveToWorkspace(real,'messages');W:SetMinimized(true,true)
W.records[real].unread=1;W:QueueMinimizedWhisper(real,false,'A real incoming whisper')
local row=W.minimizedWhisperTray.rows[1];row:GetScript('OnClick')()
assert(not W.minimized and W.selected==real)
for _,entry in ipairs(W.minimizedWhispers) do assert(entry.person~=real) end
local f=W.hub:GetScript('OnUpdate');if f then f(W.hub,.3) end
local window=Core:GetModule('UIManager'):GetChatWindow(real)
assert(window.slidingMessageFrame.whisperFullSurface and window.slidingMessageFrame:GetParent()==W.hubContent)
W:Place(real,'main',false);assert(not window.slidingMessageFrame.whisperFullSurface)
''')
print('Whisper feedback checks passed: proportional draggable overflow scrollbar, end cues, full-width gradient, bounded upward previews, deduplication, click-to-restore/select, option off, expiry/unread preservation, detached test cleanup and native renderer reset on redock.')


lua.execute("Core.Components.SlidingMessageFrameMixin={};Core.Components.SlidingMessageFrameHelpers={}")
lua.execute(Path(os.environ['SUNDER_ADDON_ROOT']+'/Sunder/Components/SlidingMessageFrameLayout.lua').read_text(encoding='utf-8'),'Sunder',lua.globals().vars)
lua.execute('''
local line={SetBackgroundCoverage=function(self,n) self.coverage=n end}
local frame={whisperFullSurface=true,state={messages={line}},gapBackground=CreateFrame('Frame')}
Core.Components.SlidingMessageFrameMixin.UpdateGapBackground(frame)
assert(line.coverage==1 and frame.gapBackground:GetAlpha()==0)
''')
print('Native background integration passed: grouped rows and gap filler defer to the shared full-width surface.')

