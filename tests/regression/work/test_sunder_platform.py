from pathlib import Path
from lupa.lua51 import LuaRuntime
import xml.etree.ElementTree as ET

root = Path(os.environ['SUNDER_ADDON_ROOT']).resolve()
lua = LuaRuntime(unpack_returned_tuples=True)
compile_lua = lua.eval('function(s,n) local f,e=loadstring(s,n); assert(f,e) end')
files = list(root.rglob('*.lua'))
for p in files: compile_lua(p.read_text(encoding='utf-8-sig'), str(p))

seen = set()
def verify_file(p):
    assert p.is_file(), p
    if p in seen: return
    seen.add(p)
    if p.suffix == '.xml':
        for el in ET.parse(p).iter():
            if el.get('file'): verify_file(p.parent / el.get('file').replace('\\','/'))
for line in (root/'Sunder.toc').read_text(encoding='utf-8').splitlines():
    if line.strip() and not line.startswith('#'): verify_file(root/line.replace('\\','/'))

lua.execute('''
modules = {}
core = {NewModule = function(self,name) modules[name] = {}; return modules[name] end,
  GetModule = function(self,name) return assert(modules[name],name) end}
function copy(t)
  if type(t) ~= "table" then return t end
  local out = {}; for k,v in pairs(t) do out[k] = copy(v) end; return out
end
libs = {
  ["AceAddon-3.0"] = {NewAddon = function() return core end},
  ["LibSharedMedia-3.0"] = {GetDefault = function() return "Game default" end},
  ["AceDB-3.0"] = {New = function(_,name,defaults)
    _G[name] = _G[name] or {profiles = {Default = copy(defaults.profile)}, global = {}}
    return {profile = _G[name].profiles.Default, global = _G[name].global}
  end},
}
function LibStub(name) return libs[name] or {} end
C_AddOns = {GetAddOnMetadata = function() return "0.1.0" end}
vars = {}
''')
lua.execute((root/'Sunder/init.lua').read_text(encoding='utf-8'), 'Sunder', lua.globals().vars)
lua.execute((root/'Sunder/Migration.lua').read_text(encoding='utf-8'), 'Sunder', lua.globals().vars)
lua.execute((root/'Sunder/constants.lua').read_text(encoding='utf-8'), 'Sunder', lua.globals().vars)
lua.execute('''
GlassyDB = {profiles = {Default = {frameWidth = 559, nested = {value = 1}}},
  global = {version = "1.9.7"}, profileKeys = {Character = "Default"}}
core:OnInitialize()
assert(SunderDB.global.migratedFromGlassy and core.db.profile.frameWidth == 559)
core.db.profile.nested.value = 2
assert(GlassyDB.profiles.Default.nested.value == 1, 'migration shared a nested table')
core.db.profile.frameWidth = 700
core:OnInitialize()
assert(core.db.profile.frameWidth == 700, 'second launch overwrote settings')
local seenOwner
core:Subscribe("input", function(visible, owner) assert(visible); seenOwner = owner end)
local owner = {}
core:Dispatch("input", true, owner)
assert(seenOwner == owner, 'editor ownership dropped by event dispatch')
SunderDB, GlassyDB = nil, nil
core:OnInitialize()
assert(core.db.profile.frameWidth == 600 and core.db.global.minimap.angle == 225)

modules.Config.Pages = {profile = function() return {type = "group", name = "Profiles", args = {}} end}
''')
lua.execute((root/'Sunder/Features.lua').read_text(), 'Sunder', lua.globals().vars)
lua.execute('''
core:RegisterFeature("chat", {name = "Chat", order = 10, buildOptions = function()
  return {type = "group", args = {
    general = {type = "group",name = "General",order = 1,args = {}},
    tabs = {type = "group",name = "Tabs",order = 2,args = {}},
    editor = {type = "group",name = "Editor",order = 3,args = {}},
    messages = {type = "group",name = "Messages",order = 4,args = {}},
    about = {},profile = {},
  }}
end})
options = core:BuildOptions()
assert(options.name == "Sunder" and options.args.home and options.args.chat)
assert(not options.args.chat.args.about and not options.args.chat.args.profile)
assert(options.args.chat.childGroups == "tab")
assert(not pcall(function() core:RegisterFeature("chat", {}) end), 'duplicate feature accepted')
core:RegisterFeature("future", {name = "Future", buildOptions = function() return {type = "group",args = {}} end})
assert(core:BuildOptions().args.future, 'new feature missing from config')
''')

# Test optional skinning on the real integration module, including the absence case.
lua.execute('''
function core:SelectDefaultFont() self.fontRefreshed = true end
''')
lua.execute((root/'Sunder/Modules/Ellesmere.lua').read_text(), 'Sunder', lua.globals().vars)
lua.execute('''
local e = modules.Ellesmere
e:OnInitialize()
assert(not e:IsActive() and e:GetFontPath() == nil)
EllesmereUI = {RegisterSkin = function(name, fn)
  assert(name == "Sunder")
  fn({GetFont = function() return "EUIFont.ttf" end,
      GetAccentColor = function() return 0.2,0.5,0.8 end,
      IsEnabled = function() return true end})
end}
e:OnInitialize()
assert(e:IsActive() and e:GetFontPath() == "EUIFont.ttf" and core.fontRefreshed)
''')

# Native EUI pages retain the same feature schema and separate Chat tabs.
lua.execute('''
core.Libs.AceConfigRegistry = {GetOptionsTable = function() return options end}
''')
lua.execute((root/'Sunder/Modules/EllesmereOptions.lua').read_text(), 'Sunder', lua.globals().vars)
lua.execute('''
local groups = modules.Ellesmere:BuildOptionModules(options)
assert(groups[1].key == "home")
local chat
for _,g in ipairs(groups) do if g.key == "chat" then chat = g end end
assert(chat and #chat.pages == 4 and chat.pages[1] == "General" and chat.pages[4] == "Messages")
EllesmereUI = nil
modules.Ellesmere:RegisterOptions()
assert(not modules.Ellesmere.optionsRegistered, 'absent EUI did not fall back')
''')

# Actual OpenSettings method: native interface, unavailable API, and standalone fallback.
config = (root/'Sunder/Modules/Config.lua').read_text(encoding='utf-8')
opening = config[config.index('function C:OpenSettings'):config.index('local function debugName')]
lua.execute('''
C = modules.Config
Core = core
AceConfigDialog = {Open = function(_,app) openedApp = app end,
  SelectGroup = function(_,app,group) openedGroup = group end}
modules.Ellesmere.skin = nil
''')
lua.execute(opening)
lua.execute('''
C:OpenSettings("chat")
assert(openedApp == "Sunder" and openedGroup == "chat")
modules.Ellesmere.optionsRegistered = true
EllesmereUI = {OpenPlugin = function(id,group) nativeId,nativeGroup = id,group; return true end}
C:OpenSettings()
assert(nativeId == "Sunder" and nativeGroup == "home")
EllesmereUI.OpenPlugin = function() return false end
C:OpenSettings("chat")
assert(openedGroup == "chat")
EllesmereUI.OpenPlugin = function() error("missing native options") end
C:OpenSettings("home")
assert(openedGroup == "home", 'native failure prevented fallback')
''')

# Launcher: settings click, edit-mode click, round/square positioning and persisted drag.
lua.execute('''
function CreateFrame()
  local f = {scripts = {}}
  local noop = function() end
  setmetatable(f, {__index = function(_,k) return noop end})
  function f:CreateTexture() return setmetatable({}, {__index = function() return noop end}) end
  function f:SetScript(k,v) self.scripts[k] = v end
  function f:GetScript(k) return self.scripts[k] end
  function f:SetPoint(_,_,_,x,y) self.x,self.y = x,y end
  function f:SetShown(v) self.shown = v end
  function f:GetParent() return Minimap end
  return f
end
Minimap = {GetWidth = function() return 140 end, GetHeight = function() return 140 end,
  GetCenter = function() return 300,300 end, GetEffectiveScale = function() return 1 end,
  GetFrameLevel = function() return 3 end, HookScript = function() end}
shape = "ROUND"
function GetMinimapShape() return shape end
function GetCursorPosition() return 400,300 end
function IsMouseButtonDown() return true end
C_Timer = {After = function(_,fn) fn() end}
GameTooltip = setmetatable({}, {__index = function() return function() end end})
modules.Config.OpenSettings = function() configClicks = (configClicks or 0) + 1 end
modules.Config.OnSlashCommand = function(_,text) assert(text == "lock"); lockClicks = (lockClicks or 0) + 1 end
''')
lua.execute((root/'Sunder/Modules/Minimap.lua').read_text(), 'Sunder', lua.globals().vars)
lua.execute('''
local launcher = modules.Minimap
launcher:OnEnable()
local b = launcher.button
b.scripts.OnClick(b,"LeftButton")
b.scripts.OnClick(b,"RightButton")
assert(configClicks == 1 and lockClicks == 1)
launcher:SetHidden(true); assert(not b.shown and core.db.global.minimap.hide)
launcher:SetHidden(false); assert(b.shown)
shape = "ROUND"; core.db.global.minimap.angle = 45; launcher:UpdatePosition()
assert(math.abs(b.x*b.x + b.y*b.y - 75*75) < 0.01)
shape = "SQUARE"; launcher:UpdatePosition()
assert(math.abs(b.x - 75) < 0.01 and math.abs(b.y - 75) < 0.01)
b.scripts.OnDragStart()
b.scripts.OnUpdate()
assert(core.db.global.minimap.angle == 0)
b.scripts.OnClick(b,"LeftButton"); assert(configClicks == 1, 'drag opened config')
b.scripts.OnDragStop()
assert(not b.scripts.OnUpdate)
''')
print(f'Platform checks passed: {len(files)} Lua files, {len(seen)} manifest resources, migration, event ownership, feature schema, EUI/fallback navigation, minimap controls.')
