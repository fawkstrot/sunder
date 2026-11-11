exec(open('work/test_whispers.py',encoding='utf-8').read())
lua.execute('''
Core.db.profile.frameWidth=600;Core.db.profile.frameHeight=300
Core.db.profile.positionAnchor={point="BOTTOMLEFT",xOfs=40,yOfs=30}
Constants.ACTIONS.LockMover=function()return "lock"end
Constants.ACTIONS.UnlockMover=function()return "unlock"end
function Core:Dispatch(event)if event=="lock"then self.sunderMoverUnlocked=false elseif event=="unlock"then self.sunderMoverUnlocked=true end end
local methods=getmetatable(UIParent).__index
function methods:RegisterEvent()end
function methods:UnregisterAllEvents()end
function C_Timer.NewTicker(_,fn)return {fn=fn,Cancel=function(self)self.cancelled=true end}end
ui.moverFrame=CreateFrame("Frame",nil,UIParent);ui.moverFrame:SetSize(600,335);ui.moverFrame:Hide()
ui.moverFrame.boundsFrame=CreateFrame("Frame",nil,ui.moverFrame)
function ui.moverFrame:UpdateLayoutBounds()self:SetSize(Core.db.profile.frameWidth,Core.db.profile.frameHeight+35)end
''')
lua.execute(root.joinpath('Modules/EllesmereEditMode.lua').read_text(encoding='utf-8'),'Sunder',lua.globals().vars)
lua.execute('''
EllesmereUI=nil;assert(not eui:SetupEditModeIntegration() and not eui.editSession,"absent EUI changed standalone state")
local registry,listeners={},{}
EllesmereUI={_ELEMENT_SETTINGS_MAP={},
 RegisterUnlockElements=function(_,elements)for _,e in ipairs(elements)do registry[e.key]=e end end,
 UnregisterUnlockElement=function(_,key)registry[key]=nil end,
 RegisterUnlockModeListener=function(_,owner,listener)listeners[owner]=listener end,
 UnregisterUnlockModeListener=function(_,owner)listeners[owner]=nil end,
 GetPluginModuleKey=function(id,key)return "plugin:"..id..":"..key end}
assert(eui:SetupEditModeIntegration() and listeners.Sunder)
local main=registry.Sunder_Chat
assert(main and main.setWidth and main.setHeight and main.ownsPosition)
assert(EllesmereUI._ELEMENT_SETTINGS_MAP.Sunder_Chat.page=="Chat windows")
Core.db.profile.whispers.enabled=true;Core.db.profile.whispers.mode="hub"
W:OpenMessages();W:SetMinimized(true,true)
local beforeWidth=ui.moverFrame:GetWidth()
listeners.Sunder(true)
assert(eui.editSession and Core.sunderEllesmereEditing and ui.moverFrame:IsShown() and not ui.moverFrame.boundsFrame:IsShown())
assert(not W.minimized and not W.hubOverlay:IsShown() and W.restoringWindowState)
main=registry.Sunder_Chat
main.setWidth(main.key,700);main.setHeight(main.key,435)
assert(Core.db.profile.frameWidth==700 and Core.db.profile.frameHeight==400 and ui.moverFrame:GetHeight()==435)
main.setHeight(main.key,455);assert(Core.db.profile.frameHeight==420,"height drifted between updates")
main.savePosition(main.key,"CENTER","CENTER",20,25)
assert(Core.db.profile.positionAnchor.point=="BOTTOMLEFT")
local whispers=registry.Sunder_Whispers_messages
assert(whispers and EllesmereUI._ELEMENT_SETTINGS_MAP[whispers.key].page=="Whispers")
whispers.setWidth(whispers.key,800);whispers.setHeight(whispers.key,500)
assert(W:HubSettings().hubWidth==800 and W:HubSettings().hubHeight==500)
listeners.Sunder(false,"discard")
assert(not eui.editSession and not Core.sunderEllesmereEditing and not ui.moverFrame:IsShown())
assert(ui.moverFrame:GetWidth()==beforeWidth and Core.db.profile.frameHeight==300)
assert(W.minimized and not W.restoringWindowState)
listeners.Sunder(true);main=registry.Sunder_Chat
main.setWidth(main.key,720);listeners.Sunder(false,"save")
assert(Core.db.profile.frameWidth==720 and W.minimized)
Core.sunderMoverUnlocked=true;listeners.Sunder(true)
assert(not Core.sunderMoverUnlocked)
listeners.Sunder(false,"exit");assert(Core.sunderMoverUnlocked,"standalone edit state lost")
Core.sunderMoverUnlocked=false
listeners.Sunder(true);combat=true;listeners.Sunder(false,"discard")
assert(eui.pendingEditClose and eui.editSession)
combat=false;eui:SetupEditModeIntegration();assert(not eui.editSession and not eui.pendingEditClose)
eui:OnDisable();assert(not listeners.Sunder and not next(registry),"registration leaked")
''')
# Check exact free positioning at the old magnetic threshold and hard boundaries.
source=root.joinpath('Components/MoverFrame.lua').read_text(encoding='utf-8')
a=source.index('function MoverFrameMixin:SetDragPosition');b=source.index('function MoverFrameMixin:UpdateDragPosition',a)
lua.execute('MoverFrameMixin={};'+source[a:b])
lua.execute('''
local parent=CreateFrame("Frame")
function parent:GetLeft()return 0 end;function parent:GetRight()return 1000 end
function parent:GetBottom()return 0 end;function parent:GetTop()return 800 end
function parent:GetCenter()return 500,400 end
local f=CreateFrame("Frame",nil,parent);f:SetSize(300,200)
MoverFrameMixin.SetDragPosition(f,7,9)
local _,_,_,x,y=f:GetPoint();assert(x==7 and y==9,"near-edge position snapped")
MoverFrameMixin.SetDragPosition(f,-30,-20)
_,_,_,x,y=f:GetPoint();assert(x==0 and y==0,"negative edge escaped screen")
MoverFrameMixin.SetDragPosition(f,740,650)
_,_,_,x,y=f:GetPoint();assert(x==0 and y==0,"far edge escaped screen")
''')
print('Edit mode checks passed: optional API fallback, registration/options links, scoped native movement/resize, exact geometry, discard/save, minimized-state preservation, standalone-state restoration, combat deferral, teardown and non-magnetic screen clamping.')
