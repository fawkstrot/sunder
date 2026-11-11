exec(open('work/test_conversation_polish.py',encoding='utf-8').read())
lua.execute('''
-- New default: one shared header surface, bounded navigation and no second row.
cfg.singleRowHeader=true; cfg.hubMatchChat=true
W:RefreshHubStyle()
assert(W:SingleRowHeader() and W:PreviewTop()==0)
assert(W:PreviewBodyTop()==W:HeaderHeight()+W:HeaderGap())
assert(W:ContentTop()+W:ConversationTabHeight()==W:HeaderHeight())
assert(W.previewTabScroll.points.TOPLEFT.relative==W.hub)
assert(W.previewTabScroll.points.TOPRIGHT.x==-W.headerActionWidth-100)
assert(W.previewBody.points.TOPLEFT.y==-W:HeaderHeight()-W:HeaderGap()-W:BodyPadding())
assert(not W.hubActionButtons.Detach:IsShown() and not W.hubActionButtons.Search:IsShown())
assert(W.hubActionButtons.Windows:IsShown() and W.minimizeButton:IsShown())
assert(W.minimumWorkspaceWidth>=W.headerTitleEnd+W.headerActionWidth+100+120)
local active=W.previewConversations[W.previewSelected]
local last=W.previewConversations[#W.previewConversations]
W:PreviewAction('Pin',last)
assert(W.previewConversations[1]==last and last.pinned)
assert(W.previewConversations[W.previewSelected]==active)
for _,mode in ipairs({'name','unread','recent'}) do
 W:SortConversationTabs(mode)
 local unpinned=false
 for _,c in ipairs(W.previewConversations) do
  if not c.pinned then unpinned=true else assert(not unpinned,'sort moved pin behind unpinned') end
 end
end
W:ReorderConversation(last,31,true)
local pinCount=0;for _,c in ipairs(W.previewConversations) do if c.pinned then pinCount=pinCount+1 end end
assert(W.previewConversations[pinCount]==last)
local unpinned=W.previewConversations[pinCount+1]
W:ReorderConversation(unpinned,1,true)
assert(W.previewConversations[pinCount+1]==unpinned)
W:PreviewAction('Pin',last);assert(not last.pinned)
local host=W:GetWorkspace('sortTest')
local frame=conversation('ChatFramePinCheck','PinCheck-Realm')
W:OnWindowOpened(frame);W:MoveToWorkspace(frame,'sortTest')
if W.records[frame].pinned then W:ToggleConversationPin(frame) end
W:ToggleConversationPin(frame)
assert(host.hubOrder[1]==frame and Core.db.char.messageTabOrders.sortTest[1]==W.records[frame].key)
host:SortConversationTabs('name');assert(W.records[host.hubOrder[1]].pinned)
host:ReorderConversation(frame,50,false);assert(W.records[host.hubOrder[1]].pinned)
-- Native and sample geometry can return to two rows without losing settings.
cfg.singleRowHeader=false;W:RefreshHubStyle()
assert(W:PreviewTop()==W:HeaderHeight())
assert(W:NavigationWidth()==W.CONVERSATION_NAV_WIDTH)
assert(W.hubActionButtons.Detach:IsShown())
cfg.singleRowHeader=true;W:RefreshHubStyle()
''')
print('Pinned-first and single-row header checks passed: all sorts, drag boundaries, native persistence, sample identity, exact content insets, bounded controls and two-row fallback.')
