exec(open('work/test_navigator070.py',encoding='utf-8').read())
lua.execute("""
W:ClearPreviewData();cfg.enabled=true;cfg.mode='tabs';cfg.keepMessagesOpen=true
local frame=conversation('ChatFrameRoutingReal','Routing-Realm');W:OnWindowOpened(frame);drain()
assert(frame.isDocked and W.records[frame].placement=='main')
W:Save();assert(Core.db.char.whisperLayouts['routing-realm'].placement=='main')
cfg.mode='hub';W:ApplySettings(true,'mode');drain()
assert(not frame.isDocked and W.records[frame].placement=='hub')
local window=Core:GetModule('UIManager'):GetChatWindow(frame)
assert(window.slidingMessageFrame:GetParent()==W.hubContent)
assert(Core.db.char.whisperLayouts['routing-realm'].placement=='hub')
W:OnWindowClosed(frame);W:OnWindowOpened(frame);drain()
assert(W.records[frame].placement=='hub','reopened conversation reverted to legacy main-chat placement')
W:Save();assert(Core.db.char.whisperLayouts['routing-realm'].placement=='hub')
assert(filters.CHAT_MSG_WHISPER(CreateFrame('Frame'),'CHAT_MSG_WHISPER','hello','Routing-Realm'))
assert(not filters.CHAT_MSG_WHISPER(frame,'CHAT_MSG_WHISPER','hello','Routing-Realm'))
""")
print('Real routing checks passed: legacy main tab moves into Whispers, renderer is reparented, destination persists through reopen/save, duplicate main-chat delivery suppressed.')

lua.execute("""
local host=W;host.previewActive=false;local sampleScroll,sampleChild=host.previewTabScroll,host.previewTabChild
host.previewTabScroll,host.previewTabChild=nil,nil
host:LayoutConversationStrip(false);assert(host.tabScroll:IsShown())
host:LayoutConversationStrip(true);assert(host.tabScroll:IsShown(),'missing sample viewport hid the native people list')
host:ApplyWorkspaceMetrics();assert(host.tabScroll:IsShown())
host.previewTabScroll,host.previewTabChild=sampleScroll,sampleChild
""")
print('Fresh-session native list check passed: uncreated sample viewport never aliases or hides the real people list.')
