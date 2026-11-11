exec(open('work/test_editmode099.py',encoding='utf-8').read())
lua.execute('''
eui.editDisabled=nil
local registry={}
EllesmereUI={_ELEMENT_SETTINGS_MAP={},RegisterUnlockElements=function(_,list)for _,e in ipairs(list)do registry[e.key]=e end end,
 UnregisterUnlockElement=function(_,key)registry[key]=nil end,
 RegisterUnlockModeListener=function()end,GetPluginModuleKey=function()return "plugin:Sunder:chat" end}
local function slot(id)
 local f=CreateFrame("Frame","ChatFrame"..id,UIParent);f.isDocked=false
 return {active=true,chatFrame=f,temporary=false,detachedLayout={container=CreateFrame("Frame",nil,UIParent)}}
end
local unused,real=slot(9),slot(3)
ui.state.windows={ChatFrame9=unused,ChatFrame3=real}
local open=true
FCF_GetChatWindowInfo=function(id)return id==3 and "Guild" or "Chat "..id,12,1,1,1,false,id==3 and open end
assert(not eui:IsDetachedEditWindow(unused),"initialized unused slot treated as open")
assert(eui:IsDetachedEditWindow(real),"configured Guild window lost")
eui:SetupEditModeIntegration()
assert(registry.Sunder_ChatFrame3 and not registry.Sunder_ChatFrame9)
open=false;eui:RefreshEditElements()
assert(not registry.Sunder_ChatFrame3 and not EllesmereUI._ELEMENT_SETTINGS_MAP.Sunder_ChatFrame3,"closed slot left a mover")
local frame=unused.chatFrame;unused.temporary=true;frame.inUse=false
assert(not eui:IsDetachedEditWindow(unused),"retired temporary slot exposed")
frame.inUse=true;assert(eui:IsDetachedEditWindow(unused),"live temporary conversation lost")
W.records[frame]={placement="hub"};assert(not eui:IsDetachedEditWindow(unused),"grouped conversation duplicated as detached mover")
W.records[frame].placement="detached";assert(eui:IsDetachedEditWindow(unused))
frame.inUse=false;assert(not eui:IsDetachedEditWindow(unused))
frame.isDocked=true;frame.inUse=true;assert(not eui:IsDetachedEditWindow(unused))
''')
print('Edit registration filtering passed: unused built-in slots, native open/closed metadata, dynamic mover removal, retired temporary frames, live detached conversations and grouped/docked exclusions.')
