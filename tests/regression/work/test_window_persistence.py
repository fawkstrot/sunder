exec(open('work/test_tab_navigation.py', encoding='utf-8').read())
lua.execute('''
W:ClearPreviewData();cfg.enabled=true;cfg.keepMessagesOpen=true;cfg.visibility="always"
local group=W:GetWorkspace("group1")
local favorite=W:GetWorkspace("group2")
W:OpenMessages();favorite:OpenMessages()
W:MoveToWorkspace(bob,group.hostId);group:CloseMessages()
favorite:SetMinimized(true,true)
local states=Core.db.char.messageWindowStates
assert(states.messages.open and states.group2.open and states.group2.minimized)
assert(not states[group.hostId].open)
W:BeginMessageWindowRestore()
W.hub:Hide();group.hub:Show();favorite:SetMinimized(false,true)
assert(W.pendingWindowStates.messages.open and not W.pendingWindowStates[group.hostId].open)
W:RestoreMessageWindows()
assert(W.hub:IsShown() and favorite.hub:IsShown() and favorite.minimized)
assert(not group.hub:IsShown() and group.windowManuallyClosed)
W:Place(bob,"hub",false)
assert(not group.hub:IsShown(),"restoring a late conversation reopened a closed group")
group:OpenMessages();assert(states[group.hostId].open)
group:CloseMessages();assert(not states[group.hostId].open)
W:CloseMessages();W:BeginMessageWindowRestore();W.hub:Show();W:RestoreMessageWindows()
assert(not W.hub:IsShown(),"closed Messages reopened on restore")
favorite:OpenMessages();local saved=states.group2
W.windowStateShutdown=true;favorite.hub:Hide();assert(states.group2==saved and saved.open)
W.windowStateShutdown=nil
cfg.enabled=false;W:BeginMessageWindowRestore();W:RestoreMessageWindows()
assert(states.group2.open,"disabled feature erased remembered open state")
cfg.enabled=true
Core.db.char.messageWindowStates.messages=nil
W:BeginMessageWindowRestore();W:RestoreMessageWindows();assert(W.hub:IsShown(),"first-upgrade keep-open migration failed")
''')
print('Window persistence passed: independent open/closed/minimized state, startup snapshot, late tab restoration, explicit close/open, shutdown protection, feature disable and first-upgrade fallback.')
