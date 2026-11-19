exec(open('work/sunder-tests/test_glassy.py', encoding='utf-8').read())
lua.execute('''
cursorX, cursorY, down = 100, 100, true
function GetCursorPosition() return cursorX, cursorY end
UIParent = {GetEffectiveScale = function() return 1 end,
  GetLeft = function() return 0 end, GetTop = function() return 1080 end}
local overlay = {GetFrameLevel = function() return 5 end}
target = {width = 600, height = 250, scale = 0.5}
function target:GetEffectiveScale() return self.scale end
function target:GetLeft() return 100 end
function target:GetTop() return 800 end
function target:ClearAllPoints() end
function target:SetPoint(point, parent, relative, x, y)
  self.point, self.relative, self.x, self.y = point, relative, x, y
end
allowed, finishes = true, 0;resizeSettings={}
handle = Core.Components.CreateResizeHandle(overlay, {
  minWidth = 100, minHeight = 100,settings=function()return resizeSettings end,
  allowed = function() return allowed end,
  begin = function() return target, target.width, target.height end,
  apply = function(w,h) target.width, target.height = w,h end,
  finish = function() finishes = finishes + 1 end,
})
handle.scripts.OnMouseDown(handle, "LeftButton")
assert(target.point == "TOPLEFT" and target.relative == "TOPLEFT")
assert(target.x == 100 and target.y == -1360, 'scaled anchor offset incorrect')
cursorX, cursorY = 150, 75
handle:UpdateResize()
assert(target.width == 700 and target.height == 300, 'scaled resize delta incorrect')
cursorX, cursorY = -10000, 10000
handle:UpdateResize()
local minWidth,minHeight=Core.Components.WindowManager:MinimumWindowSize()
assert(target.width == minWidth and target.height == minHeight, 'minimum dimensions ignored')
Core.db.profile.windowMinWidth,Core.db.profile.windowMinHeight=520,340
handle:UpdateResize()
assert(target.width==520 and target.height==340,"held resize did not pick up the shared settings")
Core.db.profile.windowMinWidth,Core.db.profile.windowMinHeight=nil,nil

cursorX, cursorY = 10000, -10000
handle:UpdateResize()
assert(target.width == 9999 and target.height == 9999)
allowed = false
handle:UpdateResize()
assert(not handle.resizeState and finishes == 1)
handle:FinishResize()
assert(finishes == 1, 'resize saved twice')
handle.scripts.OnMouseDown(handle, "LeftButton")
assert(not handle.resizeState, 'locked resize started')
allowed = true
handle.scripts.OnMouseDown(handle, "LeftButton")
down = false
handle:UpdateResize()
assert(not handle.resizeState and finishes == 2, 'release failed to save')
cursorX,cursorY,down=100,100,true
target.width,target.height=600,250
handle.scripts.OnMouseDown(handle,"LeftButton")
cursorX,cursorY,down=140,80,false
handle.scripts.OnMouseUp(handle,"LeftButton")
assert(target.width==680 and target.height==290 and not handle.resizeState and finishes==3,'fast drag lost its final cursor delta')
resizeSettings.movementLocked=true;down=true
handle.scripts.OnMouseDown(handle,"LeftButton");assert(not handle.resizeState,"position lock did not block resizing")
resizeSettings.movementLocked=false;handle.scripts.OnMouseDown(handle,"LeftButton")
resizeSettings.movementLocked=true;cursorX=300;handle:UpdateResize()
assert(not handle.resizeState and finishes==4 and target.width==680,"locking mid-resize did not cancel driver")
resizeSettings.movementLocked=false

''')

# Exercise the main window's actual callbacks, including settings broadcasts and position save.
src = base.joinpath('Components/MoverFrame.lua').read_text()
callbacks = src[src.index('  self.resizeOptions ='):src.index('  self:Hide()\n\n  self.boundsFrame:RegisterForDrag')]
lua.execute('''
Constants.ACTIONS = {
  UpdateConfig = function(key) return "update", key end,
  SaveFramePosition = function(pos) return "save", pos end,
}
SaveFramePosition = Constants.ACTIONS.SaveFramePosition
updates, saved = {}, nil
function Core:Dispatch(event, value)
  if event == "update" then updates[value] = true else saved = value end
end
Core.db.profile.frameWidth, Core.db.profile.frameHeight = 600, 250
Core.sunderMoverUnlocked = true
self = target
self.boundsFrame = {GetFrameLevel = function() return 5 end}
function self:IsShown() return true end
function self:StopDragging() end
function self:UpdateLayoutBounds() self.layoutUpdated = true end
function self:UpdateBounds() self.boundsUpdated = true end
function self:GetPoint() return self.point, UIParent, self.relative, self.x, self.y end
down, cursorX, cursorY = true, 100, 100
''')
lua.execute(callbacks)
lua.execute('''
self.resizeHandle.scripts.OnMouseDown(self.resizeHandle, "LeftButton")
cursorX, cursorY = 150, 75
self.resizeHandle:UpdateResize()
assert(Core.db.profile.frameWidth == 700 and Core.db.profile.frameHeight == 300)
assert(updates.frameWidth and updates.frameHeight and self.layoutUpdated and self.boundsUpdated)
self.resizeHandle:FinishResize()
assert(saved.point == "TOPLEFT" and saved.yOfs == -1360, 'main anchor not saved')
''')
print('Resize checks passed: scale, anchor persistence, limits, lock, release, main settings and layout updates.')

# Exercise normal header movement with the edit overlay hidden.
lua.execute('MoverFrameMixin = {}')
lua.execute(src[src.index('function MoverFrameMixin:StartDragging()'):src.index('function MoverFrameMixin:ScheduleBoundsUpdate()')])
lua.execute("""
local moving={left=140,top=700}
function moving:HookScript(key,fn)self.hooks=self.hooks or {};self.hooks[key]=fn end
function moving:SetMovable(v)self.movable=v end
function moving:SetClampedToScreen(v)self.clamped=v end
function moving:StartMoving()self.moving=true end
function moving:StopMovingOrSizing()self.moving=false end
function moving:GetLeft()return self.left end
function moving:GetTop()return self.top end
function moving:ClearAllPoints()end
function moving:SetPoint(...)self.anchor={...}end
local mover=setmetatable({layoutContainer=moving},{__index=MoverFrameMixin})
function mover:GetHeight()return 300 end
function mover:SetDragPosition(x,y)self.left=x;self.bottom=y end
function mover:GetPoint()return "TOPLEFT",UIParent,"TOPLEFT",self.left,self.bottom end
Core.Components.WindowManager:Settings("main").movementLocked=false
down=true;mover:StartDragging()
assert(moving.moving and mover.windowMoveDriver.scripts.OnUpdate,"normal header has no running driver")
assert(mover.windowMoveDriver.parent==UIParent,"driver is parented to a hidden overlay")
moving.left=200;moving.top=640
mover.windowMoveDriver.scripts.OnUpdate();assert(moving.moving,"movement stopped before release")
down=false;mover.windowMoveDriver.scripts.OnUpdate()
assert(not moving.moving and mover.left==200 and mover.bottom==340)
assert(not mover.nativeDragTarget and not mover.windowMoveDriver.scripts.OnUpdate)
assert(moving.anchor[1]=="TOPLEFT" and moving.anchor[2]==mover,"root did not rejoin saved anchor")
Core.Components.WindowManager:Settings("main").movementLocked=true
mover:StartDragging();assert(not moving.moving,"position lock allowed root movement")
Core.Components.WindowManager:Settings("main").movementLocked=false
down=true;mover:StartDragging();assert(moving.moving)
moving.hooks.OnHide()
assert(not moving.moving and not mover.windowMoveDriver.scripts.OnUpdate and not mover.windowMoveTarget,"hidden window leaked a movement driver")
""")

lua.execute(src[src.index('function MoverFrameMixin:CreateStandardResizer('):src.index('function MoverFrameMixin:Init()')])
lua.execute("""
local normal=MakeFrame("Frame",nil,UIParent)
function normal:IsShown()return true end
Core.sunderMoverUnlocked=false
local handle=MoverFrameMixin.CreateStandardResizer(self,normal)
down=true;cursorX=100;cursorY=100
handle.scripts.OnMouseDown(handle,"LeftButton")
assert(handle.resizeState,"main resize still requires edit mode")
cursorX=120;cursorY=80;handle:UpdateResize()
assert(Core.db.profile.frameWidth>700 and Core.db.profile.frameHeight>300,"standard resize did not update main dimensions")
local locked=Core.Components.WindowManager:Settings("main")
local width,height=Core.db.profile.frameWidth,Core.db.profile.frameHeight
locked.movementLocked=true;cursorX=240;handle:UpdateResize()
assert(not handle.resizeState and not handle.scripts.OnUpdate and Core.db.profile.frameWidth==width)
handle.scripts.OnMouseDown(handle,"LeftButton");assert(not handle.resizeState and Core.db.profile.frameHeight==height)
locked.movementLocked=false
handle.scripts.OnMouseDown(handle,"LeftButton");assert(handle.resizeState);handle:FinishResize()
Core.sunderMoverUnlocked=true
""")

# Detached native frames must honor the same visible minimum as Whispers,
# even when the client starts with a larger engine-level minimum.
native_src = base.joinpath('Components/DetachedChatDock.lua').read_text()
native_callbacks = native_src[native_src.index('  local resizeOptions = {'):native_src.index('  overlay:Hide()', native_src.index('  local resizeOptions = {'))]
lua.execute("""
Constants.DOCK_HEIGHT=24
local manager=Core.Components.WindowManager
combat=false;down=true;cursorX,cursorY=100,100
nativeTarget=target;nativeTarget.width,nativeTarget.height=600,400
nativeTarget.engineWidth,nativeTarget.engineHeight=400,400
function nativeTarget:GetWidth()return self.width end
function nativeTarget:GetHeight()return self.height end
function nativeTarget:SetMinResize(w,h)self.engineWidth,self.engineHeight=w,h end
function nativeTarget:SetSize(w,h)self.width=math.max(w,self.engineWidth);self.height=math.max(h,self.engineHeight)end
function nativeTarget:IsProtected()return true end
function nativeTarget:GetName()return 'ChatFrame2' end
nativeTarget.isDocked=false
resizePreviousGetModule=Core.GetModule
local ui={GetChatWindow=function(_,frame)return {chatFrame=frame}end,
 RefreshDetachedLayoutSize=function(_,window,w,h)assert(window.chatFrame==nativeTarget and w==nativeTarget.width and h==nativeTarget.height+Constants.DOCK_HEIGHT);nativeTarget.contentSynced=true end}
function Core:GetModule(name)if name=="UIManager"then return ui end;return resizePreviousGetModule(self,name)end
self={tab={chatFrame=nativeTarget},StopWindowDrag=function()end,WindowSettings=function()return {}end}
overlay=MakeFrame();parent=MakeFrame()
""")
lua.execute(native_callbacks)
lua.execute("""
for _,handle in ipairs({self.resizeHandle,self.roomResize})do
  for _,limits in ipairs({{360,220},{480,300}})do
    Core.db.profile.windowMinWidth,Core.db.profile.windowMinHeight=unpack(limits)
    cursorX,cursorY=100,100
    handle.scripts.OnMouseDown(handle,'LeftButton')
    cursorX,cursorY=-10000,10000;handle:UpdateResize()
    assert(nativeTarget.width==limits[1] and nativeTarget.height+Constants.DOCK_HEIGHT==limits[2], 'native held resize differs from shared visible bounds')
    assert(nativeTarget.engineHeight==limits[2]-Constants.DOCK_HEIGHT,'stale native engine minimum')
    assert(nativeTarget.contentSynced,'resize did not notify the content owner');nativeTarget.contentSynced=nil
    handle:FinishResize()
  end
end
local modern={SetResizeBounds=function(self,w,h)self.width,self.height=w,h end}
Core.Components.WindowManager:ApplyNativeWindowMinimums(modern)
assert(modern.width==480 and modern.height==276,'modern engine bounds not synchronized')
combat=true;modern.height=999;Core.Components.WindowManager:ApplyNativeWindowMinimums(modern)
assert(modern.height==999,'engine minimum changed in combat')
combat=false
Core.db.profile.windowMinWidth,Core.db.profile.windowMinHeight=nil,nil
""")
lua.execute('Core.GetModule=resizePreviousGetModule;resizePreviousGetModule=nil')
print('Native minimum regression passed: legacy/modern engine limits, both held grips, shared settings and combat guard.')

# Main mover consumes the same complete root height as detached/Whispers shells.
lua.execute(src[src.index('function MoverFrameMixin:UpdateLayoutBounds()'):src.index('function MoverFrameMixin:ScheduleLayoutBoundsUpdate()')])
lua.execute("""
local wm=Core.Components.WindowManager;local oldAnchor=wm.AnchorMainContainer
wm.AnchorMainContainer=function()end
local mover={layoutContainer={containsChatEditor=true},layoutEditBox={GetHeight=function()return 64 end},
 SetHeight=function(self,h)self.height=h end,ScheduleBoundsUpdate=function()end}
local anchor=Core.db.profile.editBoxAnchor;local height=Core.db.profile.frameHeight
Core.db.profile.frameHeight=220
for _,position in ipairs({"ABOVE","BELOW"})do
 Core.db.profile.editBoxAnchor={position=position,yOfs=-2}
 MoverFrameMixin.UpdateLayoutBounds(mover)
 assert(mover.height==220 and mover.layoutContainer.mainTopOffset==0,"main mover added external editor height")
end
Core.db.profile.editBoxAnchor=anchor;Core.db.profile.frameHeight=height;wm.AnchorMainContainer=oldAnchor
""")
