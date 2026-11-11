exec(open('work/test_082.py',encoding='utf-8').read())
preview_source=root.joinpath('Modules/WhisperPreview.lua').read_text(encoding='utf-8')
lua.execute(preview_source[preview_source.index('function W:SimulationWindowAlpha()'):])
lua.execute('''
for _,host in pairs(W.workspaces or {}) do host.pendingWhisperToast=nil end
cfg.enabled=true;cfg.favoritesSeparate=false;cfg.mode="hub";cfg.previewConversations=10
W:ClearPreviewData();W:StartPreview();W:SetMinimized(false,true);W:SetPeopleFilter("all")
local first=W.previewConversations[1]
local section=W.peopleSections.conversations
section:GetScript("OnClick")()
assert(W.peopleCollapsed.conversations)
for i=1,8 do W:RenderPreview();W:LayoutHub();drain() end
assert(W.peopleCollapsed.conversations and not W.previewTabs[1]:IsShown(),"background refresh undid section collapse")
local parent=section:GetParent();local offsets=W.peopleOffsets
W:LayoutPeopleRows(false)
assert(section:GetParent()==parent and W.peopleOffsets==offsets,"inactive native layout stole sample controls")
section:GetScript("OnClick")();assert(not W.peopleCollapsed.conversations and W.previewTabs[1]:IsShown())
-- Read a row using its real click handler while in Unread.
local person=W.previewConversations[3];person.unread=4
W:SetPeopleFilter("unread");local row=W.previewTabs[3]
row:GetScript("OnMouseDown")(row,"LeftButton");row:GetScript("OnClick")(row,"LeftButton")
assert(W.previewConversations[W.previewSelected]==person and person.unread==0 and W.peopleFilter=="all")
-- Mouse-down captures the person even if sorting changes the row binding.
local target=W.previewConversations[4];row=W.previewTabs[4]
row:GetScript("OnMouseDown")(row,"LeftButton")
W:PreviewAction("Pin",target)
row:GetScript("OnClick")(row,"LeftButton")
assert(W.previewConversations[W.previewSelected]==target,"click opened a stale numeric index")
local originalRenderRows=W.previewRenderedRows
local oldHover=W.hub.IsMouseOver;W.hub.IsMouseOver=function()return true end
mouseDown=true;W:RenderPreview();assert(W.previewRenderPending)
mouseDown=false;W:Tick();assert(not W.previewRenderPending)
W.hub.IsMouseOver=oldHover
W.previewSimulation={started=GetTime(),events={},cursor=1}
for _,c in ipairs(W.previewConversations) do c.lastActivity=GetTime()-100;c.pinned=false end
W.hub.IsMouseOver=function() return false end
W:SetPeopleFilter("all")
assert(W:SimulationWindowAlpha()==1,"interaction did not hold the simulation window open")
W.previewSimulation=nil;W:ClearPreviewData()
''')
print('Click/simulation regression checks passed: collapse survives refresh, inactive layouts cannot steal controls, unread row opens by identity, pin-reorder during press, deferred redraw flush and interaction idle reset.')
