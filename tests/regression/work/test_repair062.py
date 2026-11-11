exec(open('work/test_feedback061.py',encoding='utf-8').read())
lua.execute('''
cfg.minimizedPreviews=true;cfg.minimizedPreviewUntilRead=true;cfg.previewConversations=10
W:StartPreview();W:RefreshHubStyle()
for i=1,6 do
 W:SetMinimized(true,true)
 assert(W.hubChrome:IsShown() and not W.previewFrame:IsShown())
 assert(W.previewNavigation:GetParent()==W.hubChrome and W.previewNavigation:IsShown())
 assert(#W.minimizedWhispers>0)
 W.previewNavigation.all:GetScript('OnClick')()
 local animate=W.hub:GetScript('OnUpdate');if animate then animate(W.hub,.3) end
 assert(not W.minimized and W.hub:GetHeight()>=220 and W.hubChrome:IsShown())
end
W:SetMinimized(true,true)
local entry=W.minimizedWhispers[1];assert(entry and entry.person.unread>0)
now=GetTime()+100;W:UpdateMinimizedWhispers();assert(#W.minimizedWhispers>0,'waiting whispers unexpectedly expired')
local tray=W.minimizedWhisperTray;local update=tray:GetScript('OnUpdate');if update then update(tray,.3) end
assert(tray:GetParent()==UIParent and tray:IsShown())
tray.rows[1]:GetScript('OnClick')()
local anim=W.hub:GetScript('OnUpdate');if anim then anim(W.hub,.3) end
assert(W.previewConversations[W.previewSelected]==entry.person and not W.minimized)
W:ClearPreviewData();W:SetMinimized(true,true)
W.conversationNavigation.all:GetScript('OnClick')()
local anim=W.hub:GetScript('OnUpdate');if anim then anim(W.hub,.3) end
assert(not W.minimized,'empty count did not restore')
-- Heal a legacy collapsed geometry even if the boolean says expanded.
W.hub:SetHeight(W:HeaderHeight());W.minimized=false;W:SetMinimized(false,true)
assert(W.hub:GetHeight()>=220)
''')
print('Minimize repair checks passed: repeated cycles, body-independent header/preview stack, unread seeding/persistence, correct-row selection, empty-count restore and collapsed-geometry recovery.')

lua.execute('''
W:StartPreview()
for _,scroll in ipairs({W.tabScroll,W.previewTabScroll}) do
 local old=scroll.GetHeight
 function scroll:GetHeight()
  local top,bottom=self.points.TOPLEFT,self.points.BOTTOMLEFT
  if top and bottom and top.relative==W.hub then return math.max(1,W.hub:GetHeight()+top.y-bottom.y) end
  return old(self)
 end
end
W:SetMinimized(true,true)
local item=W.minimizedWhispers[2]
assert(item)
W:OpenMinimizedWhisper(item)
local animate=W.hub:GetScript('OnUpdate');if animate then animate(W.hub,.3) end
local top=(W.previewSelected-1)*W:ConversationRowStep()
local offset=W.previewTabScroll:GetVerticalScroll()
assert(top>=offset and top+W:ConversationRowHeight()<=offset+W.previewTabScroll:GetHeight())
''')
print('Expanded viewport check passed: clicked waiting person is visible after the final animated height is applied.')
