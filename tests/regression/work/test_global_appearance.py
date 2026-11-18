exec(open('work/test_sunder_platform.py',encoding='utf-8').read())
lua.execute('''
function core:Localize(text) return text end
function core.Libs.LSM:HashTable() return {Default="Native.ttf"} end
core.Libs.AceConfigRegistry.NotifyChange=function() end
''')
for component in ['WindowManager','RosterRoom']:
 lua.execute((root/f'Sunder/Components/{component}.lua').read_text(encoding='utf-8'),'Sunder',lua.globals().vars)
for name in ['Config','ConfigChatPages','ConfigMessagePages','Whispers','WhispersOptions','Appearance','GuildChat','PartyChat']:
 lua.execute((root/f'Sunder/Modules/{name}.lua').read_text(encoding='utf-8'),'Sunder',lua.globals().vars)
lua.execute('''
core.db.profile.whispers=copy(core.defaults.profile.whispers)
core.db.profile.guildChat=copy(core.defaults.profile.guildChat)
core.db.profile.partyChat=copy(core.defaults.profile.partyChat)
local c=modules.Config
c.Pages.profile=function() return {type="group",args={}} end
core.features.chat.buildOptions=function()
 return {type="group",args={general=c.Pages.general(),tabs=c.Pages.tabs(),editBox=c.Pages.editBox(),messages=c.Pages.messages()}}
end
local before=copy(core.db.profile)
options=core:BuildOptions()
local chatCategory=options.args.chat
local appearance=chatCategory.args.appearance
assert(appearance.name=="Appearance" and appearance.childGroups=="tab")
assert(appearance.args.typography.args.text.args.messageFontSize)
assert(not chatCategory.args.windows.args.messages.args.section1.args.messageFontSize)
assert(not chatCategory.args.whispers.args.appearance)
assert(appearance.args.surfaces.args.windows.args.opacity)
assert(chatCategory.args.whispers.args.visibility.args.appearance.type=="execute")
assert(appearance.args.headers.args.customize.args.icon)
assert(appearance.args.windows.args.headerFont)
assert(core.db.profile.messageFontSize==before.messageFontSize and core.db.profile.whispers.headerFont==before.whispers.headerFont)
local counts={}
local function walk(t)
 for k,v in pairs(t.args or {}) do counts[k]=(counts[k] or 0)+1;if v.type=="group" then walk(v) end end
end
walk(options)
assert(counts.messageFontSize==1 and counts.editBoxFontSize==1 and counts.hubBackgroundColor==nil)
local modulesList=modules.Ellesmere:BuildOptionModules(options)
local a
for _,m in ipairs(modulesList) do if m.key=="chat" then a=m end end
assert(a and #a.pages==6 and a.onReset==nil)
assert(a.pages[1]=="Overview" and a.pages[2]=="Chat windows" and a.pages[3]=="Whispers" and a.pages[4]=="Guild Chat" and a.pages[5]=="Party Chat" and a.pages[6]=="Appearance")
local design=appearance.args.design.args
core.db.profile.whispers.headerFontSize=19;core.db.profile.whispers.mode="hub"
function modules.Whispers:ApplySettings() end
core.features.whispers.resetOptions()
assert(core.db.profile.whispers.headerFontSize==19 and core.db.profile.whispers.mode==core.defaults.profile.whispers.mode)

core.db.profile.frameWidth=677;core.db.profile.messageFontSize=17;core.db.profile.chatFadeOutDuration=123
-- Test only the settings changed by presentation presets; don't run native rendering here.
function modules.Whispers:RefreshHubStyle() end
function core:Dispatch() end
design.minimal.func();assert(not core.db.profile.chatTitleIcons and not core.db.profile.chatSelectionIndicator)
design.refined.func();assert(core.db.profile.chatTitleIcons and core.db.profile.chatSelectionIndicator)
assert(core.db.profile.messageFontSize==17 and core.db.profile.frameWidth==677 and core.db.profile.chatFadeOutDuration==123)
''')

lua.execute("""
local config=modules.Config;config.options=options
local oldWidth,oldHeight=core.db.profile.windowMinWidth,core.db.profile.windowMinHeight
core.db.profile.windowMinWidth,core.db.profile.windowMinHeight=520,300
config:RefreshWindowSizeOptions()
local found={}
local function inspect(group)
 for key,option in pairs(group.args or {})do
  if option.type=="range"then
   for _,bound in ipairs({"min","max","softMin","softMax","step"})do assert(option[bound]==nil or type(option[bound])=="number","AceConfig requires numeric range bounds: "..key.."."..bound)end
   if key=="frameWidth" or key=="frameHeight"then found[key]=option end
  elseif option.type=="group"then inspect(option)end
 end
end
inspect(options)
assert(found.frameWidth.min==520 and found.frameHeight.min==300)
assert(found.frameWidth.softMin==520 and found.frameWidth.softMax>=520)
assert(options.args.chat.args.appearance.args.headers.args.minimumWidth and options.args.chat.args.appearance.args.headers.args.minimumHeight)
core.db.profile.windowMinWidth,core.db.profile.windowMinHeight=oldWidth,oldHeight
config:RefreshWindowSizeOptions()
""")
print("Shared dimension settings passed: one exposed width/height pair and live numeric AceConfig bounds.")

print('Global appearance schema passed: actual Chat/Whispers options moved once, saved values preserved, nested Chat sections, scope-safe resets and presentation presets preserve text/scrolling/geometry.')
# Use the existing frame mock, then load actual ChatTab methods without initializing native handlers.
exec(open('work/test_whispers.py',encoding='utf-8').read())
lua.execute('''
Core.Libs.AceHook={}
function Core:GetThemeColor() return {r=.2,g=.5,b=.8,a=1} end
Constants.COLORS={apache={r=.8,g=.6,b=.3}}
Constants.TEXT_RIGHT_PADDING=4
''')
source=(Path(os.environ['SUNDER_ADDON_ROOT']+'/Sunder/Components/ChatTab.lua')).read_text(encoding='utf-8')
mixin=lua.execute(source+'\nreturn ChatTabMixin','Sunder',lua.globals().vars)
lua.globals().tabMixin=mixin
lua.execute('''
local methods=getmetatable(UIParent).__index
function methods:SetAlpha(v) assert(type(v)=="number");self.alpha=v end
function methods:SetVertexColor(r,g,b,a) self.vertex={r,g,b,a} end
function methods:SetTexture(v) self.texture=v end
function methods:SetColorTexture(r,g,b,a) self.color={r,g,b,a} end
function methods:GetTextWidth() return 50 end
local function makeTab(frame)
 local tab=CreateFrame("Button",nil,UIParent)
 for k,v in pairs(tabMixin) do tab[k]=v end
 tab.chatFrame=frame;tab.Text=tab:CreateFontString();tab.sunderHooks={hooks={}}
 return tab
end
Core.db.profile.textLeftPadding=4;Core.db.profile.chatTitleIconGap=6
Core.db.profile.chatTitleIconSize=14;Core.db.profile.chatTitleIconOpacity=.5
Core.db.profile.chatTitleIcons=true;Core.db.profile.chatSelectionIndicator=true
ChatFrame1=CreateFrame("Frame","ChatFrame1",UIParent);ChatFrame1.isDocked=true
GENERAL_CHAT_DOCK.selected=ChatFrame1
local tab=makeTab(ChatFrame1);tab:UpdateTextLayout()
assert(tab.titleIcon:IsShown() and tab.titleIcon:GetWidth()==14 and tab:GetIconWidth()==20)
assert(tab.selectionLine:IsShown() and tab.titleIcon.alpha==.5 and tab.titleIcon.vertex[1]==.74)
GENERAL_CHAT_DOCK.selected=nil;tab:UpdateVisualState()
assert(not tab.selectionLine:IsShown() and tab.titleIcon.alpha==.5)
Core.db.profile.chatHoverWash=true;tab.sunderHovered=true;tab:UpdateVisualState()
assert(tab.hoverWash:IsShown() and tab.titleIcon.alpha==.9)
Core.db.profile.chatTabIconOverrides={ChatFrame1="favorite"};tab:UpdateTextLayout()
assert(tab.titleIcon.texture:find("favorite.tga",1,true))
Core.db.profile.chatTabIconOverrides.ChatFrame1="none";tab:UpdateTextLayout();assert(tab:GetIconWidth()==0)
-- Native conversation identity wins, including with custom icons disabled.
Core.db.profile.chatTitleIcons=false;tab.conversationIcon=tab:CreateTexture();tab.conversationIcon:SetSize(16,16)
tab:UpdateTextLayout();assert(not tab.titleIcon:IsShown() and tab:GetIconWidth()==22)
tab.conversationIcon:Hide();tab:UpdateTextLayout();assert(tab:GetIconWidth()==0)
Core.db.profile.chatTitleIcons=true;Core.db.profile.chatTabIconOverrides.ChatFrame1=nil
ChatFrame1.messageTypeList={"SAY","GUILD"};tab:UpdateTextLayout()
assert(tab.titleIcon.texture:find("inbox.tga",1,true))
ChatFrame2=CreateFrame("Frame","ChatFrame2",UIParent)
local combat=makeTab(ChatFrame2);combat:UpdateTextLayout();assert(combat.titleIcon.texture:find("read.tga",1,true))
''')
print('Chat decorations passed: measured icon spacing, accent/idle/hover states, native conversation identity, per-tab overrides, Guild/combat roles and text-only mode.')
# Verify shared edge-fade rendering without touching text or window alpha.
lua.execute('''
local methods=getmetatable(UIParent).__index
function methods:SetGradient(direction,left,right) self.gradient={direction,left,right} end
function CreateColor(r,g,b,a) return {r=r,g=g,b=b,a=a} end
function Mixin(target,source) for k,v in pairs(source) do target[k]=v end;return target end
''')
lua.execute(Path(os.environ['SUNDER_ADDON_ROOT']+'/Sunder/Components/GradientBackground.lua').read_text(encoding='utf-8'),'Sunder',lua.globals().vars)
lua.execute('''
local texture=UIParent:CreateTexture();texture:SetWidth(500)
local color={r=.1,g=.2,b=.3}
Core.db.profile.backgroundFadeLeftPercent=10;Core.db.profile.backgroundFadeRightPercent=60
Core.Components.PaintGradientTexture(texture,color,.6,true)
local p=texture.sunderGradientParts
assert(p.left:GetWidth()==50 and p.right:GetWidth()==300 and p.center:IsShown())
assert(p.left.gradient[2].a==0 and p.left.gradient[3].a==.6)
assert(p.right.gradient[2].a==.6 and p.right.gradient[3].a==0)
assert(texture.color[4]==0 and p.center.color[4]==.6)
Core.db.profile.backgroundFadeLeftPercent=80;Core.db.profile.backgroundFadeRightPercent=80
Core.Components.PaintGradientTexture(texture,color,0,true)
assert(p.left:GetWidth()==250 and p.right:GetWidth()==250 and not p.center:IsShown())
assert(p.right.gradient[2].a==0)
Core.Components.PaintGradientTexture(texture,color,.4,false)
assert(texture.color[4]==.4 and not p.left:IsShown() and not p.right:IsShown() and not p.center:IsShown())
''')
print('Shared surface fade checks passed: left/right proportions, overlapping fades, zero opacity, solid fallback and separate text layers.')

# Wire the production main header and container around a native dock/mover fixture.
lua.execute("strmatch=string.match")
for name in ["LibStub/LibStub.lua","AceHook-3.0/AceHook-3.0.lua"]:
    lua.execute((root.parent/"libs"/name).read_text(encoding="utf-8-sig"))

lua.execute("""
local m=getmetatable(UIParent).__index
function m:GetFrameStrata()return "MEDIUM"end
function m:GetFrameLevel()return self.level or 3 end
function m:SetFrameLevel(v)self.level=v end
function m:StopDragging()end
function m:FinishResize()self.finished=true end
function m:UpdateLayoutBounds()end
function m:AddBoundsRegion()end
function m:CreateStandardResizer(parent)return CreateFrame("Button",nil,parent)end
function m:UpdateTabOrder()end
function m:ScheduleTabOrder()self.tabOrderQueued=true end
function m:UpdateAutomaticVisibility()end
function m:QuickShow()self:Show()end
Core.Components.CreateMoverFrame=function(name,parent)
 local f=CreateFrame("Frame",name,parent);f.resizeHandle=CreateFrame("Button",nil,f);return f
end
Core.Components.CreateChatDock=function(parent)
 local d=CreateFrame("Frame",nil,UIParent);d:SetHeight(24);d.scrollFrame=CreateFrame("Frame",nil,d)
 d.scrollFrame.child=CreateFrame("Frame",nil,d.scrollFrame);d.scrollFrame.child:SetFrameLevel(32)
 d.overflowButton={list=CreateFrame("Frame",nil,d)};LibStub("AceHook-3.0"):Embed(d);return d
end
Core.Components.CreateSlidingMessageFramePool=function()return {}end
local subscribers={}
Constants.EVENTS.EDIT_BOX_VISIBILITY_CHANGED="typing"
function Core:Subscribe(event,fn)subscribers[event]=subscribers[event] or {};table.insert(subscribers[event],fn)end
function Core:Dispatch(event,...)
 for _,fn in ipairs(subscribers[event] or {})do fn(...)end
end
Core.db.profile.positionAnchor={point="BOTTOMLEFT",xOfs=19,yOfs=41}
Core.db.profile.frameWidth=515;Core.db.profile.frameHeight=240
UIParent:SetSize(1600,950)
""")
for name in ["Components/MainContainerFrame.lua","Modules/UIManager.lua"]:
    lua.execute(root.joinpath(name).read_text(encoding="utf-8"),"Sunder",lua.globals().vars)
lua.execute("""
ui:CreateRootFrames()
assert(ui.slidingMessageFramePool and not ui.mainControls)
ui:InstallMainControls()
assert(ui.dock.tabOrderQueued)
local host=ui.mainControls
local root=ui.container
local lock=ui.dock.windowControls.lock
local collapse,maximize=host.hubActionButtons.CollapseTop,host.hubActionButtons.Maximize
local function click(b)b:GetScript("OnClick")(b,"LeftButton")end
assert(lock:GetFrameLevel()>ui.dock.scrollFrame.child:GetFrameLevel()+1)
ui.dock:SetWidth(100);Core.Components.WindowManager:ApplyNativeSurface(root,ui.dock)
assert(ui.dock.windowActionWidth+ui.dock.windowTitleInset+Constants.DOCK_HEIGHT<100 and lock:GetWidth()<=13)
ui.dock:SetWidth(515);Core.Components.WindowManager:ApplyNativeSurface(root,ui.dock);assert(lock:GetWidth()==22)
local actions=host.hubActionButtons
assert(actions.Settings.points.RIGHT.x>maximize.points.RIGHT.x and maximize.points.RIGHT.x>collapse.points.RIGHT.x)
assert(collapse.points.RIGHT.x>actions.CollapseBottom.points.RIGHT.x and actions.Settings.points.RIGHT.x>lock.points.RIGHT.x and lock.points.RIGHT.x>maximize.points.RIGHT.x)
click(lock)
assert(host:HubSettings().movementLocked and lock.actionSelected and maximize.disabled and ui.mainResize.finished)
assert(not ui.mainResize:IsShown() and not ui.moverFrame.resizeHandle:IsShown())
click(maximize);assert(root:GetWidth()==515)
click(lock);assert(not maximize.disabled)
GENERAL_CHAT_DOCK.selected=ChatFrame2
click(collapse);local step=root:GetScript("OnUpdate")
step(root,.12);assert(root:GetHeight()>24 and root:GetHeight()<240 and root.clipsChildren)
step(root,.12);assert(root:GetHeight()==24 and root.mainBodyHidden and not root:GetScript("OnUpdate"))
assert(root.windowSurface.bodyFrame:IsShown()==false and ui.dock:IsShown() and not ui.mainResize:IsShown())
assert(Core.db.profile.frameHeight==240 and GENERAL_CHAT_DOCK.selected==ChatFrame2)
click(maximize)
assert(host.maximized and not host.minimized and root:GetWidth()==1100 and root:GetHeight()==720)
assert(maximize.actionKey=="restore-size" and ui.mainResize:IsShown() and not root.clipsChildren)
click(maximize)
local anchor=Core.db.profile.positionAnchor
assert(root:GetWidth()==515 and root:GetHeight()==240 and anchor.point=="BOTTOMLEFT" and anchor.xOfs==19 and anchor.yOfs==41)
local down=host.hubActionButtons.CollapseBottom
assert(down:IsShown() and collapse:IsShown())
click(down)
local tick=root:GetScript("OnUpdate")
tick(root,.12)
assert(root:GetPoint(1)=="BOTTOMLEFT" and root:GetHeight()>24 and root:GetHeight()<240)
assert(down:IsShown() and down.actionKey=="collapse-up" and not collapse:IsShown())
tick(root,.12)
Core.Components.WindowManager:ApplyNativeSurface(root,ui.dock)
assert(root.mainBodyHidden and not collapse:IsShown())
click(down)
tick=root:GetScript("OnUpdate");tick(root,.12)
assert(root:GetPoint(1)=="BOTTOMLEFT" and root:GetHeight()>24 and root:GetHeight()<240)
tick(root,.12)
assert(root:GetPoint(1)=="TOPLEFT" and down:IsShown() and collapse:IsShown())
click(collapse);Core:Dispatch(Constants.EVENTS.EDIT_BOX_VISIBILITY_CHANGED,true,{sunderParent=root,HasFocus=function()return true end})
assert(not host.minimized and not root:GetScript("OnUpdate") and root:GetHeight()==240)
click(maximize);Core.db.profile.frameWidth=600;Core:Dispatch(Constants.ACTIONS.UpdateConfig("frameWidth"))
assert(not host.maximized and not Core.db.profile.mainChatRestore)
combat=true;root:GetScript("OnEvent")();assert(maximize.disabled and collapse.disabled and down.disabled)
combat=false;root:GetScript("OnEvent")();assert(not maximize.disabled and not collapse.disabled)
""")
print("Main dock controls passed: lock hit layer, collapse midpoints, maximize and exact restore, combat gating and native tab retention.")
