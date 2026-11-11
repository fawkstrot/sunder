exec(open('work/test_people060.py',encoding='utf-8').read())
lua.execute('''
W:ClearPreviewData();cfg.conversationLayout='list';cfg.hubMatchChat=true;cfg.mode='hub';W:OpenMessages();W:RefreshHubStyle()
local a=conversation('ChatFrameVerticalA','VerticalA-Realm')
local b=conversation('ChatFrameVerticalB','VerticalB-Realm')
W:OnWindowOpened(a);W:OnWindowOpened(b);drain();W:MoveToWorkspace(a,'messages');W:MoveToWorkspace(b,'messages')
local target=W:GetWorkspace('sortTest');target:OpenMessages();target:RefreshHubStyle()
function target.hub:GetLeft() return 1000 end
local tab=W.hubTabs[a]
-- Target the name column below the old horizontal strip's hit area.
cursorX=target.hub:GetLeft()+20;cursorY=target.hub:GetTop()-target:HeaderHeight()-100
assert(target:IsConversationDropArea(cursorX,cursorY))
tab:GetScript('OnDragStart')();tab:GetScript('OnUpdate')(tab,.05);assert(target.tabInsertion:IsShown())
tab:GetScript('OnDragStop')();drain();assert(W.records[a].workspace==target.hostId)
assert(target.hubTabs[a] and not W.hubTabs[a])
assert(W:GetWorkspace('favorites')==W)
W:MoveToWorkspace(b,'messages');W:ToggleFavorite(b)
assert(W:IsFavorite(b) and W.records[b].workspace=='messages')
cfg.name='Messages';assert(W:WorkspaceName()=='Whispers')
cfg.name='Messages 3';assert(W:WorkspaceName()=='Whispers 3')
cfg.name='Raid leaders';assert(W:WorkspaceName()=='Raid leaders')
cfg.conversationLayout='tabs';W:RefreshHubStyle();assert(not W.contactPane)
cfg.conversationLayout='list';W:RefreshHubStyle();assert(not W.contactPane)
''')
print('Vertical group transfer, integrated favorite identity and default-name migration passed.')
