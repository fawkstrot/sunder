from pathlib import Path
from lupa.lua51 import LuaRuntime

base = Path(os.environ['SUNDER_ADDON_ROOT'])/'Sunder'
lua = LuaRuntime(unpack_returned_tuples=True)
compile_lua = lua.eval('function(s,n) local f,e=loadstring(s,n); assert(f,e) end')
files = list(base.rglob('*.lua'))
for p in files: compile_lua(p.read_text(encoding='utf-8-sig'), str(p))
lua.execute('''
Core = {Components = {}, db = {profile = {chatAlwaysVisible = true}}}
Constants = {EVENTS = {}}
function CreateFrame(...) return MakeFrame(...) end
alt, combat, down, saves = false, false, true, 0
function IsAltKeyDown() return alt end
function InCombatLockdown() return combat end
function IsMouseButtonDown() return down end
function FCF_SavePositionAndDimensions(f) saves = saves + 1 end
''')
lua.execute(base.joinpath('Components/ResizeHandle.lua').read_text(), 'Sunder', lua.table_from([lua.globals().Core, lua.globals().Constants]))
lua.execute(base.joinpath('Components/DetachedChatDock.lua').read_text(), 'Sunder', lua.table_from([lua.globals().Core, lua.globals().Constants]))
lua.execute('''
local mixin = Core.Components.DetachedChatDockMixin
frame = {isLocked = true, moving = false, movable = false}
function frame:IsProtected() return true end
function frame:IsMovable() return self.movable end
function frame:SetMovable(v) self.movable = v end
function frame:StartMoving() self.moving = true end
function frame:StopMovingOrSizing() self.moving = false end
dock = setmetatable({tab = {chatFrame = frame}, scripts = {}}, {__index = mixin})
function dock:QuickShow() end
function dock:UpdateMoverBounds() end
function dock:SetScript(k,v) self.scripts[k] = v end
dock.moverOverlay = dock
function dock:SetShown(v) self.shown = v end
assert(not dock:StartWindowDrag(), 'locked window moved without Alt')
alt = true
assert(not dock:StartWindowDrag(), 'Alt bypassed edit lock')
dock:SetEditMode(true)
assert(dock.shown, 'edit overlay missing')
assert(dock:StartWindowDrag() and frame.moving)
down = false
dock.scripts.OnUpdate()
assert(not frame.moving and not frame.movable and saves == 1)
dock:StopWindowDrag()
assert(saves == 1, 'double save')
dock:SetEditMode(false)
assert(not dock.shown and not dock:StartWindowDrag())
dock:SetEditMode(true)
combat = true
assert(not dock:StartWindowDrag(), 'protected frame moved in combat')
combat = false
frame.isDocked = true
assert(not dock:StartWindowDrag(), 'docked frame moved')
frame.isDocked = false
frame.isTemporary = true
assert(dock:StartWindowDrag())
dock:StopWindowDrag()
assert(saves == 1, 'temporary window persisted as permanent')
''')
tab_source = base.joinpath('Components/ChatTab.lua').read_text()
handlers = tab_source[tab_source.index('  -- Pooled temporary tabs'):tab_source.index('  -- Override context menu')]
lua.execute('''
nativeStarts, nativeStops, reordered = 0, 0, 0
self = {scripts = {}}
function self:GetScript(k) return self.scripts[k] end
function self:SetScript(k,v) self.scripts[k] = v end
function self:RegisterForDrag() end
function self:GetParent() return self.parent end
self.parent = dock
self.chatFrame = frame
self.scripts.OnDragStart = function() nativeStarts = nativeStarts + 1 end
self.scripts.OnDragStop = function() nativeStops = nativeStops + 1 end
GameTooltip = {IsOwned = function() return false end}
local header = dock
dock = {StartTabDrag = function() return false end,
        StopTabDrag = function() reordered = reordered + 1 end}
''')
lua.execute(handlers)
lua.execute(handlers)  # Reinitialization must not recursively capture wrappers.
lua.execute('''
alt = false
self.scripts.OnDragStart(self, "LeftButton")
self.scripts.OnDragStop(self, "LeftButton")
assert(nativeStarts == 0 and nativeStops == 0, 'detached tab used native dragging')
alt = true
self.scripts.OnDragStart(self, "LeftButton")
self.parent.scripts.OnUpdate() -- Mouse release can be observed before OnDragStop.
self.scripts.OnDragStop(self, "LeftButton")
assert(nativeStops == 0, 'Alt drag called native docking stop')
dock.tabDrag = {tab = self}
self.scripts.OnDragStop(self, "LeftButton")
assert(reordered == 1 and nativeStops == 0)
''')
lua.execute('''
-- Lock while the mouse is still held: stop, save, and remove the overlay.
frame.isTemporary = false
down = true
local header = self.parent
header:SetEditMode(true)
assert(header:StartWindowDrag())
local before = saves
header:SetEditMode(false)
assert(not frame.moving and not header.shown and saves == before + 1)
self.scripts.OnDragStart(self, "LeftButton")
self.scripts.OnDragStop(self, "LeftButton")
assert(not frame.moving and nativeStarts == 0 and nativeStops == 0)

-- Exercise the real overlay constructor with frame/texture stubs.
local function noop() end
function MakeFrame(_, _, parent)
  local o = {scripts = {}, parent = parent}
  setmetatable(o, {__index = function(_, key)
    if key == "resizeState" then return nil end
    if key == "GetFrameLevel" then return function() return 2 end end
    if key == "CreateTexture" then return function() return setmetatable({}, {__index = function() return noop end}) end end
    return noop
  end})
  function o:SetScript(k,v) self.scripts[k] = v end
  function o:Hide() self.shown = false end
  function o:SetShown(v) self.shown = v end
  return o
end

local parent = {GetFrameLevel = function() return 2 end}
local testDock = setmetatable({UpdateMoverBounds = function() end}, {__index = Core.Components.DetachedChatDockMixin})
Core.sunderMoverUnlocked = true
testDock:CreateMoverOverlay(parent)
testDock:SetTab({chatFrame = frame, SetParent = noop, SetFrameStrata = noop,
  ClearAllPoints = noop, SetPoint = noop})
assert(testDock.moverOverlay.shown and testDock.moverOverlay.parent == parent)
testDock:SetEditMode(false)
assert(not testDock.moverOverlay.shown)
''')
print(f'Lua 5.1 syntax passed for {len(files)} files; unified lock, overlays, dragging, and tab lifecycle checks passed.')
