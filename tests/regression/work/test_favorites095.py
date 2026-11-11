exec(open('work/test_084.py',encoding='utf-8').read())
lua.execute('''
W:ClearPreviewData();cfg.enabled=true;cfg.mode="hub";cfg.conversationLayout="list"
local frame=conversation("RetiredFavoritePerson","Saved Favorite")
W:OnWindowOpened(frame);drain()
local legacy=W:GetWorkspace("group2");legacy:OpenMessages()
W:MoveToWorkspace(frame,legacy.hostId)
local id=legacy.hostId
local saved=Core.db.char.messageWorkspaces[id]
Core.db.char.messageWorkspaces[id]=nil;Core.db.char.messageWorkspaces.favorites=saved
W.workspaces[id]=nil;W.workspaces.favorites=legacy;legacy.hostId="favorites"
W.records[frame].workspace="favorites";W.records[frame].favorite=true
Core.db.char.whisperFavorites[W.records[frame].key]=frame.chatTarget
local native=ui:GetChatWindow(frame).slidingMessageFrame
local history={ {text="Keep this real conversation"} };Core.db.char.migrationHistoryFixture=history
Core.db.char.whisperLayouts["old-favorite"]={workspace="favorites",placement="detached",pinned=true}
Core.db.char.messageTabOrders={messages={"main","shared"},favorites={"shared","old"}}
Core.db.char.messageWindowStates.favorites={open=true,minimized=true}
W.pendingWindowStates={favorites={open=true,minimized=true}}
W.managedWorkspace="favorites";cfg.favoritesSeparate=true
W:MigrateFavoritesWorkspace()
assert(not W.workspaces.favorites and not Core.db.char.messageWorkspaces.favorites)
assert(not legacy.hub:IsShown() and W.records[frame].workspace=="messages" and W.hubTabs[frame])
assert(native==ui:GetChatWindow(frame).slidingMessageFrame and native:GetParent()==W.hubContent)
assert(W:IsFavorite(frame) and Core.db.char.whisperFavorites[W.records[frame].key]==frame.chatTarget)
assert(Core.db.char.migrationHistoryFixture==history and history[1].text=="Keep this real conversation")
local layout=Core.db.char.whisperLayouts["old-favorite"]
assert(layout.workspace=="messages" and layout.placement=="detached" and layout.pinned)
local order=Core.db.char.messageTabOrders.messages
assert(table.concat(order,",")=="main,shared,old" and not Core.db.char.messageTabOrders.favorites)
assert(not Core.db.char.messageWindowStates.favorites and not W.pendingWindowStates.favorites and W.pendingWindowStates.messages.open)
assert(W.managedWorkspace=="messages" and cfg.favoritesSeparate==nil)
W:MigrateFavoritesWorkspace();assert(W:GetWorkspace("favorites")==W)
W:MoveToWorkspace(frame,"favorites");assert(W.records[frame].workspace=="messages")
W:ToggleFavorite(frame);assert(W.records[frame].workspace=="messages" and not W:IsFavorite(frame))
W:OpenFavoritesView();assert(W.peopleFilter=="favorites" and not W.workspaces.favorites)
local options=Core.features.whispers.buildOptions()
assert(options.args.workspaces.name=="Windows & groups")
assert(not options.args.workspaces.args.favoritesSeparate and not options.args.workspaces.args.favorites)
assert(not W.RefreshFavoriteRoster)
''')
print('Favorites retirement passed: live native-frame migration, saved layout/order/visibility cleanup, idempotence, preserved contacts/history/detached placement, canonical legacy IDs and removal of separate-window controls/roster.')
