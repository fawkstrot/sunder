exec(open('work/sunder-tests/test_resize.py', encoding='utf-8').read())

ui_source = base.joinpath('Modules/UIManager.lua').read_text()
chat_source = Path('work/Blizzard-ChatFrameUtil.lua').read_text()
choose = chat_source[chat_source.index('function ChatFrameUtil.ChooseBoxForSend'):chat_source.index('function ChatFrameUtil.SetLastActiveWindow')]
mode = ui_source[ui_source.index('  -- Native per-window inputs'):ui_source.index('\nend\n\nfunction UIManager:HookChatWindowLifecycle')]
lua.execute('''
chatStyle = "classic"
function GetCVar() return chatStyle end
function SetCVar(_, value) chatStyle = value end
ChatFrameUtil = {GetLastActiveWindow = function() return lastInput end}
function IsVoiceTranscription() return false end
mainBox, guildBox = {chatFrame = {}}, {chatFrame = {}}
function mainBox:GetParent() return {IsShown = function() return true end} end
function guildBox:GetParent() return {IsShown = function() return true end} end
DEFAULT_CHAT_FRAME = {editBox = mainBox}
lastInput = guildBox
''')
lua.execute(choose)
lua.execute('assert(ChatFrameUtil.ChooseBoxForSend() == mainBox)')
lua.execute(mode)
lua.execute('''
assert(chatStyle == "im" and ChatFrameUtil.ChooseBoxForSend() == guildBox)
lastInput = mainBox
assert(ChatFrameUtil.ChooseBoxForSend() == mainBox)
''')

lua.execute('''
manager = {state = {windows = {}}}
function Core:GetModule() return manager end
Core.Components.CreateEditBox = function(parent, native)
  native.createdParent = parent
  return native
end
''')
lua.execute(ui_source, 'Sunder', lua.table_from([lua.globals().Core, lua.globals().Constants]))
lua.execute('''
local function container(w,h)
  return {GetWidth = function() return w end, GetHeight = function() return h end,
    AddHoverRegion = function() end}
end
manager.container = container(600,250)
manager.dock = {UpdateTabOrder = function() end}
local function editBox()
  return {SetSunderParent = function(self,parent,ownWidth) self.sunderParent = parent; self.ownWidth = ownWidth end}
end
mainBox, guildBox = editBox(), editBox()
ChatFrame1 = {isDocked = true, editBox = mainBox, GetName = function() return "ChatFrame1" end}
guild = {isDocked = false, GetName = function() return "ChatFrame4" end}
ChatFrame4EditBox = guildBox -- Exercise clients exposing the named edit box only.
local function smf()
  return {SetLayout = function(self,parent,w,h,input,detached)
    self.parent, self.input, self.detached = parent,input,detached
  end}
end
mainWindow = {active = true, chatFrame = ChatFrame1, slidingMessageFrame = smf()}
guildWindow = {active = true, chatFrame = guild, slidingMessageFrame = smf(),
  detachedLayout = {container = container(420,220), dock = {SetTab = function() end}}}
manager.state.windows.ChatFrame1, manager.state.windows.ChatFrame4 = mainWindow,guildWindow
manager:CreateChatEditBox(mainWindow)
manager:CreateChatEditBox(guildWindow)
manager:RefreshChatFrameLayout(ChatFrame1)
manager:RefreshChatFrameLayout(guild)
assert(mainWindow.slidingMessageFrame.input == mainBox)
assert(guildWindow.slidingMessageFrame.input == guildBox)
assert(guildBox.sunderParent == guildWindow.detachedLayout.container and guildBox.ownWidth)
guild.isDocked = true
manager:RefreshChatFrameLayout(guild)
assert(guildWindow.slidingMessageFrame.input == guildBox, 'docked tab lost its own input')
assert(guildBox.sunderParent == manager.container and not guildBox.ownWidth)
guild.isDocked = false
manager:RefreshChatFrameLayout(guild)
assert(guildBox.sunderParent == guildWindow.detachedLayout.container)

local function region(l,b,w,h)
  return {GetRect = function() return l,b,w,h end, GetEffectiveScale = function() return 1 end}
end
local parent = region(10,100,600,300)
local overlay = {points = {}, ClearAllPoints = function(self) self.points = {} end,
  SetPoint = function(self,point,relative,rpoint,x,y) self.points[point] = {x=x,y=y} end}
local dock = setmetatable({tab = {chatFrame = guild}, moverOverlay = overlay,
  GetParent = function() return parent end}, {__index = Core.Components.DetachedChatDockMixin})
guildWindow.editBox = region(10,68,600,30)
guildWindow.editBox.sunderParent = parent
Core.db.profile.editBoxAnchor = {position = "BELOW"}
dock:UpdateMoverBounds()
assert(overlay.points.TOPLEFT.y == 0 and overlay.points.BOTTOMRIGHT.y == -32,
  'closed below-input message area not covered')
Core.db.profile.editBoxAnchor.position = "ABOVE"
guildWindow.editBox = region(10,402,600,30)
guildWindow.editBox.sunderParent = parent
dock:UpdateMoverBounds()
assert(overlay.points.TOPLEFT.y == 0 and overlay.points.BOTTOMRIGHT.y == 0,
  'hidden above-input added empty padding')
guildWindow.editBox.sunderEntryVisible = true
dock:UpdateMoverBounds()
assert(overlay.points.TOPLEFT.y == 32, 'visible above-input omitted')
''')
print('Editor/layout checks passed: native Enter routing, distinct inputs, dock/undock transitions, and overlay editor extents.')
