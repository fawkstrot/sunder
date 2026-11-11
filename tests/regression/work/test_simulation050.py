exec(open('work/test_pinned_inline.py',encoding='utf-8').read())
lua.execute('''
W:ClearPreviewData(); cfg.enabled=true; cfg.singleRowHeader=true; cfg.hubMatchChat=true
W:OpenMessages();W:StartPreview()
local favorite=W
W:PreviewAction('Favorite',W.previewConversations[2])
favorite:RefreshHubStyle();favorite:SetMinimized(true,true)
assert(favorite.previewNavigation:IsShown() and favorite.previewTabScroll:IsShown())
assert(not favorite.previewBody:IsShown() and not favorite.hubContent:IsShown())
local sum=0;for _,c in ipairs(favorite.previewConversations) do sum=sum+c.unread end
assert(favorite.previewNavigation.unreadTotal==sum)
assert(favorite.previewNavigation.all:GetText()~=nil)
assert(favorite.hubActionButtons.Settings:IsShown() and favorite.minimizeButton:IsShown())
favorite:SetMinimized(false,true)
-- Header stays interactive, body opacity and size interpolate, no idle animation handler.
W:SetMinimized(true)
local update=W.hub:GetScript('OnUpdate');assert(update)
update(W.hub,.04);assert(W.previewBody:GetAlpha()>0 and W.previewBody:GetAlpha()<1)
assert(W.previewNavigation:IsShown() and W.previewTabScroll:IsShown())
update(W.hub,.25);assert(not W.previewBody:IsShown() and not W.hub:GetScript('OnUpdate'))
W:SetMinimized(false)
update=W.hub:GetScript('OnUpdate');update(W.hub,.16)
assert(W.previewBody:GetAlpha()>0 and W.previewBody:GetAlpha()<1)
update(W.hub,.2);assert(W.previewBody:IsShown() and W.previewBody:GetAlpha()==1 and not W.hub:GetScript('OnUpdate'))
W:ClearPreviewData();W:SetMinimized(false,true);W.hub:Show()
local wasOpen=W.hub:IsShown();local wasMin=W.minimized
now=1000;W:StartMessageSimulation();assert(W.previewSimulation and #W.previewSamples>=10)
local start=now
for i=0,29 do now=start+i;W:Tick() end
local sent=W.previewSimulation.sent;assert(sent>10)
-- Quiet period fades without destroying the scenario; a later burst reveals it again.
now=start+60;W:Tick();assert(W.previewSimulation and W.previewActive and W.hub:GetAlpha()==0 and not W.hub:IsShown())
sent=W.previewSimulation.sent
now=start+90;W:Tick();assert(W.previewSimulation.sent==sent+1 and W.hub:IsShown() and W.hub:GetAlpha()==1)
local before=Core.db.char.messageWindowStates.messages
W:SaveMessageWindowState();assert(Core.db.char.messageWindowStates.messages==before)
now=start+300;W:Tick()
assert(not W.previewSimulation and not W.previewSamples and not W.previewConversations and not W.previewActive)
assert(W.hub:IsShown()==wasOpen and W.minimized==wasMin)
-- Explicit clear cancels future emissions. Repeat runs do not duplicate session data.
now=2000;W:StartMessageSimulation();W:GeneratePreviewNotification();W:ClearPreviewData()
local count=W.previewNotificationCount;now=2200;W:Tick();assert(not W.previewSimulation and W.previewNotificationCount==count)
assert(not W.previewSamples)
-- Real incoming messages cancel the scenario and expose real conversations.
W:StartMessageSimulation();W:OnNativeMessage(bob,1)
assert(not W.previewSimulation and not W.previewActive and not W.previewSamples)
''')
print('Minimize/simulation checks passed: visible Favorites counters and tabs, interpolated body alpha/height, completed animation cleanup, burst/quiet/reveal, 300-second expiry, cancellation, window-state restoration and real-whisper interruption.')
