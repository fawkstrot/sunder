exec(open('work/test_0710.py',encoding='utf-8').read())
lua.execute(root.joinpath('Modules/WhisperUnified.lua').read_text(encoding='utf-8'),'Sunder',lua.globals().vars)
lua.execute('''
cfg.favoritesSeparate=false;cfg.singleToasterStack=true;cfg.mode="hub";cfg.enabled=true
W:ClearPreviewData();W:OpenMessages();W:SetMinimized(false,true)
local a=conversation("UnifiedFavorite","Favorite Friend");W:OnWindowOpened(a);drain();W:MoveToWorkspace(a,"messages")
local b=conversation("UnifiedOther","Other Friend");W:OnWindowOpened(b);drain();W:MoveToWorkspace(b,"messages")
W.records[a].favorite=true;W.records[a].unread=2;W.records[b].unread=0
Core.db.char.whisperFavorites={ ["favorite friend"]="Favorite Friend", ["offline friend"]="Offline Friend" }
W:LayoutHub();W:SetPeopleFilter("all")
assert(W.peopleFilters:IsShown() and W.peopleSections.favorites:IsShown())
local ai,bi
for i,f in ipairs(W.hubOrder) do if f==a then ai=i elseif f==b then bi=i end end
assert(W.peopleOffsets[ai]<W.peopleOffsets[bi],"Favorites not displayed first")
local visible=0;for _,row in ipairs(W.savedFavoriteRows) do if row:IsShown() then visible=visible+1;assert(row.contact.target=="Offline Friend") end end;assert(visible==1,"offline contacts missing or active duplicate")
W:SetPeopleFilter("favorites");assert(W.hubTabs[a]:IsShown() and not W.hubTabs[b]:IsShown())
W:SetPeopleFilter("unread");assert(W.hubTabs[a]:IsShown() and not W.hubTabs[b]:IsShown())
W.peopleCollapsed={favorites=true};W:SetPeopleFilter("all");assert(not W.hubTabs[a]:IsShown())
W:SelectConversation(a,false);assert(W.hubTabs[a]:IsShown() and not W.peopleCollapsed.favorites,"selection did not expand favorite section")
-- One queue, correct destination even when the person lives in another window.
cfg.favoritesSeparate=true;W:MoveToWorkspace(a,"group2")
local host=W:GetWorkspace("group2");host:SetMinimized(true,true);W.minimizedWhispers={};host.minimizedWhispers={}
host:QueueMinimizedWhisper(a,false,"A favorite's incoming whisper")
assert(#W.minimizedWhispers==1 and #host.minimizedWhispers==0,"notifications split between hosts")
local entry=W.minimizedWhispers[1];W:OpenMinimizedWhisper(entry)
assert(host.selected==a and not host.minimized and #W.minimizedWhispers==0,"toast did not open owning Favorites window")
-- Legacy IDs now resolve to the main window and cannot create a special workspace.
assert(W:GetWorkspace("favorites")==W and not W.workspaces.favorites)
W:MoveToWorkspace(a,"messages")
W:SetPeopleFilter("favorites");W:SetMinimized(true,true);W:QueueMinimizedWhisper(b,false,"Other person")
entry=W.minimizedWhispers[1];W:OpenMinimizedWhisper(entry)
assert(W.selected==b and W.hubTabs[b]:IsShown() and W.peopleFilter=="all","toast was hidden behind a filter")
-- Preview uses the same integrated list and a cleared sample queue never survives cleanup.
W:ClearPreviewData();W:StartPreview();W:SetMinimized(false,true)
W:PreviewAction("Favorite",W.previewConversations[2]);W:LayoutPeopleRows(true)
assert(W.previewConversations[2].host==W,"starring a sample spawned another window")
W:SetMinimized(true,true);W:QueueMinimizedWhisper(W.previewConversations[2],true,"sample")
W:ClearPreviewData()
for _,e in ipairs(W.minimizedWhispers or {}) do assert(not e.sample,"sample notification leaked") end
''')
print('Unified Whispers checks passed: grouped favorites, deduplicated saved contacts, filters/collapse/reveal, one queue, correct separate-window routing, migration preserving native renderer and sample cleanup.')
lua.execute('''
W:ClearPreviewData();cfg.favoritesSeparate=false;cfg.singleToasterStack=true;cfg.enabled=true
local f=UnifiedOther;W:MoveToWorkspace(f,"messages");W.records[f].unread=0
W:SetPeopleFilter("unread");assert(not W.hubTabs[f]:IsShown())
W.records[f].unread=3;W:UpdateBadges();drain();assert(W.hubTabs[f]:IsShown(),"Unread filter missed a new arrival")
W.records[f].unread=0;W:UpdateBadges();drain();assert(not W.hubTabs[f]:IsShown(),"Unread filter retained a read person")
W:SetPeopleFilter("all");W:SetMinimized(true,true);W.minimizedWhispers={};W:CloseMessages()
W:QueueMinimizedWhisper(f,false,"Window closed, notification still available")
assert(#W.minimizedWhispers==1 and W.minimizedWhisperTray:IsShown(),"shared stack depended on an open window")
cfg.enabled=false;W:UpdateMinimizedWhispers()
local animation=W.minimizedWhisperTray:GetScript("OnUpdate");if animation then animation(W.minimizedWhisperTray,.3) end
assert(not W.minimizedWhisperTray:IsShown(),"notifications survived feature disable")
cfg.enabled=true;W:OpenMessages();W:StartPreview();cfg.previewConversations=30;W:StartPreview()
for cycle=1,6 do
 W:SetMinimized(not W.minimized)
 for tick=1,16 do local fn=W.hub:GetScript("OnUpdate");if fn then fn(W.hub,.016) end;assert(W.previewTabScroll:GetHeight()>=1) end
end
W:ClearPreviewData()
''')
print('Integrated interaction checks passed: live unread filtering, closed-window notifications, disable cleanup, and animated integrated list transitions.')
lua.execute('''
-- Opening saved people is navigation only; it must never send a whisper.
local opened
FCF_OpenTemporaryWindow=function(kind,target) opened={kind,target};return conversation("SavedFavoriteOpened",target) end
W:OpenSavedFavorite({key="offline friend",target="Offline Friend"});drain()
assert(opened[1]=="WHISPER" and opened[2]=="Offline Friend")
assert(W.records[SavedFavoriteOpened].workspace=="messages")
-- Detached destinations are restored directly, without opening an unrelated hub.
local f=UnifiedOther;W:Place(f,"detached",false);ui:GetChatWindow(f).slidingMessageFrame:Hide()
W:SetMinimized(true,true);W.minimizedWhispers={};W:QueueMinimizedWhisper(f,false,"Detached message")
local entry=W.minimizedWhispers[1];assert(entry)
W:OpenMinimizedWhisper(entry)
assert(W.minimized and #W.minimizedWhispers==0 and W.pendingWhisperToast==entry)
-- Retired preferences are removed on every profile load.
cfg.unifiedFavoritesMigrated=nil;cfg.favoritesSeparate=true;W:OnEnable();drain()
assert(cfg.favoritesSeparate==nil and cfg.unifiedFavoritesMigrated==nil)
cfg.favoritesSeparate=true;W:OnEnable();drain();assert(cfg.favoritesSeparate==nil)
''')
print('Navigation/migration checks passed: saved contact opens without sending, detached toast avoids unrelated hub, first-upgrade migration and later separate-window preferences.')
