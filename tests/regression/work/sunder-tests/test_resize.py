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
allowed, finishes = true, 0
handle = Core.Components.CreateResizeHandle(overlay, {
  minWidth = 100, minHeight = 100,
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
assert(target.width == 100 and target.height == 100, 'minimum dimensions ignored')
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
''')

# Exercise the main window's actual callbacks, including settings broadcasts and position save.
src = base.joinpath('Components/MoverFrame.lua').read_text()
callbacks = src[src.index('  self.resizeHandle ='):src.index('  self:Hide()\n\n  self.boundsFrame:RegisterForDrag')]
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
