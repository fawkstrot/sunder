exec(open('work/test_message_appearance.py', encoding='utf-8').read())
lua.execute('''
W:ClearPreviewData();cfg.previewConversations=10;cfg.previewLines=8;cfg.favoritesSeparate=true
local favoriteCount=0;for _ in pairs(Core.db.char.whisperFavorites) do favoriteCount=favoriteCount+1 end
local recordCount=0;for _ in pairs(W.records) do recordCount=recordCount+1 end
W:StartPreview();local names={}
for _,c in ipairs(W.previewConversations) do assert(not names[c.name]);names[c.name]=true end
assert(#W.previewSamples==10 and #W.previewConversations==10)
local sample=W.previewConversations[1]
W:PreviewAction("Pin",sample);assert(sample.pinned and not W.hubActionButtons.Pin.disabled)
W.previewTabs[1].favoriteButton:GetScript("OnClick")()
local favorites=W
assert(sample.favorite and sample.host==W and #W.previewConversations==10)
assert(#W.previewSamples==10 and #W.previewConversations==10,"moving sample mutated the notification pool")
favorites.previewTabs[1].favoriteButton:GetScript("OnClick")()
assert(not sample.favorite and sample.host==W)
W:PreviewAction("Detach",sample)
local detached=sample.host;assert(detached~=W and detached.transientSettings and detached.hub:IsShown())
assert(detached.previewConversations[1]==sample and detached.hubGrip)
local group=W:CreateWorkspace("Sample group")
W:MovePreviewConversation(sample,group);assert(sample.host==group and #group.previewConversations==1)
W:PreviewAction("Favorite",sample);assert(sample.host==group)
W:PreviewAction("Detach",sample)
assert(sample.host.previewConversations[1]==sample)
local reused=sample.host
W:ClearPreviewData()
assert(not W.previewSamples and not W.previewActive and not favorites.previewActive and not group.previewActive)
assert(not reused.hub:IsShown() and not W.workspaces[reused.hostId])
local afterFavorites=0;for _ in pairs(Core.db.char.whisperFavorites) do afterFavorites=afterFavorites+1 end
local afterRecords=0;for _ in pairs(W.records) do afterRecords=afterRecords+1 end
assert(favoriteCount==afterFavorites and recordCount==afterRecords,"samples changed real contacts or records")
W:StartPreview();W:PreviewAction("Detach",W.previewConversations[1]);assert(#W.previewDetachedHosts==1,"sample detached shells were not reused")
W:ClearPreviewData()
''')
print('Interactive preview passed: 10 distinct people, tab stars, pins, Favorites routing, detach/group transfers, pooled detached shells, full sample cleanup and real-data isolation.')
