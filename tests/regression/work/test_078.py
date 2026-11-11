exec(open('work/test_077.py',encoding='utf-8').read())
source=root.joinpath('Components/SlidingMessageFrameNative.lua').read_text(encoding='utf-8')
method=source[source.index('function SlidingMessageFrameMixin:SyncNativeChatVisibility()'):source.index('function SlidingMessageFrameMixin:HookChatFrameVisibility')]
lua.execute('SlidingMessageFrameMixin={};isCombatLogHidden=function() return false end')
lua.execute(method)
lua.execute('''
local favorite=W:GetWorkspace("group2")
local frame=VisiblePersonB
favorite.minimized=false;favorite.previewActive=false;favorite.selected=frame
frame:Show()
local smf=ui:GetChatWindow(frame).slidingMessageFrame
smf.chatFrame=frame
function smf:ApplyPendingDynamicEditBoxLayout() end
function smf:SetSunderShown(value) self.nativeVisible=value end
SlidingMessageFrameMixin.SyncNativeChatVisibility(smf)
assert(smf.nativeVisible,"Favorites renderer followed main window selection")
favorite.selected=nil
SlidingMessageFrameMixin.SyncNativeChatVisibility(smf)
assert(not smf.nativeVisible,"background conversation leaked into empty host")
favorite.selected=frame
-- The same movement lifecycle serves Favorites and the main window.
for _,host in ipairs({W,favorite}) do
 host:OpenMessages();host:SetMinimized(false,true)
 local index=ui:GetChatWindow(host.selected).slidingMessageFrame.state.scrollIndex or 1
 host:SetMinimized(true);assert(host.collapseAnimation)
 host:BeginHubMove(true)
 assert(not host.collapseAnimation and not host.finishCollapse,"drag retained a clipping animation")
 assert(host.hubMoving and host.hub:GetAlpha()==1)
 host:UpdateHubMove();host:StopHubMove()
 assert(not host.hubMoving and not host.hubGrip:GetScript("OnUpdate"))
 host:SetMinimized(false,true)
 assert(host.hubContent:IsShown() and host.tabScroll:IsShown())
 if host.contactPane then assert(not host.contactPane:IsShown() and not host.contactScroll:IsShown(),"legacy Favorites layer resurfaced") end
 local window=ui:GetChatWindow(host.selected)
 assert(window.slidingMessageFrame:GetParent()==host.hubContent)
 assert((window.slidingMessageFrame.state.scrollIndex or 1)==index,"moving reset scrollback")
end
favorite:PresentWindowBody(true,1)
assert(not favorite.contactPane and not favorite.contactScroll)
''')
print('Shared window regression checks passed: native Favorites ownership, no renderer in empty host, drag during collapse, minimize/restore, independent parents, scroll preservation and retired contact layers.')

