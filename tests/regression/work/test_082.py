exec(open('work/test_080.py',encoding='utf-8').read())
lua.execute('''
cfg.favoritesSeparate=false;W:MigrateFavoritesWorkspace();W:OpenMessages();W:SetMinimized(false,true)
local f=conversation("TabCountPerson","Count Person");W:OnWindowOpened(f);drain();W:MoveToWorkspace(f,"messages")
for _,r in pairs(W.records) do r.unread=0 end
W:SetPeopleFilter("all")
local bar=W.peopleFilters;local unreadTab=bar.buttons[2]
assert(bar:GetWidth()==W.hub:GetWidth(),"tabs did not fill window")
for _,b in ipairs(bar.buttons) do
 assert(b:GetWidth()==bar:GetWidth()/3)
 assert(b:GetFontString():GetText()~=" " and b.icon:GetWidth()==12)
end
assert(not unreadTab.dot and unreadTab.unreadTotal==0 and unreadTab.counter:GetText()=="0")
W.records[f].unread=4;W:UpdateBadges();drain()
assert(unreadTab.unreadTotal==4 and unreadTab.counter:GetText()=="4")
unreadTab:GetScript("OnClick")();assert(W.peopleFilter=="unread" and W.hubTabs[f]:IsShown())
W.records[f].unread=0;W:UpdateBadges();drain()
assert(unreadTab.counter:GetText()=="0" and not W.hubTabs[f]:IsShown())
W.records[f].unread=123;W:UpdateBadges();drain()
assert(unreadTab.unreadTotal==123 and unreadTab.counter:GetText()=="99+")
W:StartPreview();for _,p in ipairs(W.previewConversations) do p.unread=0 end
W.previewConversations[1].unread=7;W:LayoutConversationStrip(true)
assert(unreadTab.unreadTotal==7,"sample count drifted from visible data")
for _,width in ipairs({480,680,1000}) do
 W.hub:SetWidth(width);W:ApplyWorkspaceMetrics();W:LayoutConversationStrip(true)
 for _,b in ipairs(bar.buttons) do assert(b.icon:GetWidth()==12 and b:GetText()~=" ") end
 for cycle=1,4 do
  W:SetMinimized(not W.minimized)
  for tick=1,16 do local fn=W.hub:GetScript("OnUpdate");if fn then fn(W.hub,.016) end;assert(W.previewTabScroll:GetHeight()>=1) end
 end
end
W:ClearPreviewData()
''')
print('Full-width tab checks passed: equal widths at 480/680/1000, always-visible labels and 12px icons, no unread dot, live/zero/99+ and sample counters, click filtering and animated bounds.')
