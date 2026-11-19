"""Actual shared typography: cascade, families, native menu pools and bubble ownership."""
import os
from pathlib import Path
from lupa.lua51 import LuaRuntime
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute(r'''
F={};E={}; subscriptions={};timers={};hooks={}
profile={font="Saved",messageFont="Message",tabFont="",editBoxFont="",messageFontSize=13,tabFontSize=13,editBoxFontSize=13,messageLeading=2,bubbleFontSize=15}
media={Saved="saved.ttf",Message="message.ttf",Menu="menu.ttf",Bubble="bubble.ttf"}
Core={db={profile=profile},Libs={LSM={Fetch=function(_,_,name) return media[name] end}}}
function Core:GetModule(name) if name=="Fonts" then return F elseif name=="Ellesmere" then return E else return {RefreshHubStyle=function()end} end end
function Core:GetThemeColor() return {r=1,g=1,b=1} end
function Core:Subscribe(_,fn) subscriptions[#subscriptions+1]=fn end
function Core:SelectDefaultFont() for _,fn in ipairs(subscriptions) do fn("font") end end
Constants={EVENTS={UPDATE_CONFIG="config"},ACTIONS={UpdateConfig=function()end},COLORS={apache={r=1,g=1,b=1}}};vars={Core,Constants}
function font(path,size)
 local f={path=path,size=size or 12,flags="",color={.2,.3,.4,1},h="RIGHT",v="TOP"}
 function f:GetFont()return self.path,self.size,self.flags end
 function f:SetFont(p,s,flags) if p=="bad.ttf" then self.path=nil;return false end self.path=p;self.size=s;self.flags=flags;return true end
 function f:SetFontObject(o) self.object=o; self.h="LEFT";self.v="MIDDLE" end
 function f:GetFontObject()return self.object end
 function f:SetTextColor(...)self.color={...}end
 function f:GetTextColor()return unpack(self.color)end
 function f:SetShadowColor(...)self.shadow={...}end
 function f:SetShadowOffset(...)self.offset={...}end
 function f:SetJustifyH(h)self.h=h end;function f:GetJustifyH()return self.h end
 function f:SetJustifyV(v)self.v=v end;function f:GetJustifyV()return self.v end
 function f:SetSpacing(s)self.spacing=s end
 return f
end
function CreateFont(name) local f=font("native.ttf");_G[name]=f;return f end
function family(members)
 local f=font("native.ttf");f.members=members
 function f:GetFontObjectForAlphabet(a)return self.members[a]end
 return f
end
local members={}
for _,a in ipairs({"roman","korean","simplifiedchinese","traditionalchinese","russian"})do members[a]=font(a..".ttf")end
ChatFontNormal=family(members);GameFontNormal=font("native.ttf")
function CreateFontFamily(name,spec)
 local members={};for _,m in ipairs(spec)do members[m.alphabet]=font(m.file,m.height)end
 local f=family(members);_G[name]=f;return f
end
function CreateFrame()
 local f={events={},scripts={}}
 function f:RegisterEvent(e)self.events[e]=true end
 function f:UnregisterAllEvents()self.events={}end
 function f:SetScript(e,fn)self.scripts[e]=fn end
 function f:HookScript(e,fn)self.scripts[e]=fn end
 return f
end
C_Timer={After=function(_,fn)timers[#timers+1]=fn end}
function drain()local q=timers;timers={};for _,fn in ipairs(q)do fn()end end
function hooksecurefunc(t,k,fn)hooks[k]=fn end
function IsInInstance()return instance end
bubbles={};C_ChatBubbles={GetAllChatBubbles=function()return bubbles end}
function face(f) return f:GetFontObjectForAlphabet("roman"):GetFont() end
''')
root=Path(os.environ['SUNDER_ADDON_ROOT'])/'Sunder'
lua.execute((root/'Modules/Ellesmere.lua').read_text(encoding='utf-8'),'Sunder',lua.globals().vars)
lua.execute((root/'Modules/Fonts.lua').read_text(encoding='utf-8'),'Sunder',lua.globals().vars)
lua.execute(r'''
assert(F:ResolvePath("messageFont")=="message.ttf")
assert(F:ResolvePath("tabFont")=="saved.ttf")
EllesmereUI={GetFontPath=function()return "external-unregistered.ttf"end,InvalidateFontCache=function()end}
assert(not E:IsActive() and F:ResolvePath("messageFont")=="external-unregistered.ttf")
assert(profile.messageFont=="Message" and profile.font=="Saved")
profile.followEllesmereFont=false;assert(F:ResolvePath("messageFont")=="message.ttf")
profile.followEllesmereFont=true
profile.tabTextColor={r=1,g=1,b=1};profile.tabHighlightTextColor={r=1,g=1,b=1}
F:OnInitialize();F:OnEnable()
assert(face(F.fonts.SunderMessageFont)=="external-unregistered.ttf")
assert(F.fonts.SunderMessageFont:GetFont()=="external-unregistered.ttf")
assert(F.fonts.SunderMessageFont:GetFontObjectForAlphabet("russian"):GetFont()=="russian.ttf")
EllesmereUI.GetFontPath=function()return "bad.ttf"end
Core:SelectDefaultFont();assert(face(F.fonts.SunderMessageFont)=="message.ttf")
EllesmereUI.GetFontPath=function()error("optional provider failed")end
assert(F:ResolvePath("messageFont")=="message.ttf")
EllesmereUI=nil;media.Message="bad.ttf";Core:SelectDefaultFont();assert(face(F.fonts.SunderMessageFont)=="saved.ttf");media.Message="message.ttf"
profile.messageFont="Missing";assert(F:ResolvePath("messageFont")=="saved.ttf")
profile.font="Missing";assert(F:ResolvePath("messageFont")=="native.ttf")
profile.font="Saved";profile.messageFont="Message"
-- Settings changes update shared objects, retaining role sizes and non-Roman members.
local label=font("old.ttf",18);F:ApplyLabel(label,18,"interfaceFont")
profile.whispers={headerFont="Message",headerFontFlags="OUTLINE"}
local header=font("old.ttf",20);F:ApplyLabel(header,20,"headerFont");assert(face(header.object)=="message.ttf")
local applied=label.object;assert(face(applied)=="saved.ttf" and label.h=="RIGHT" and label.v=="TOP" and label.color[1]==.2)
media.Saved="changed.ttf";Core:SelectDefaultFont();assert(label.object==applied and face(applied)=="changed.ttf")
-- Actual wrapper styles every submenu after the generator; native pool resets remain native.
function description()
 local d={children={},initializers={}}
 function d:AddInitializer(fn)self.initializers[#self.initializers+1]=fn end
 function d:EnumerateElementDescriptions()return ipairs(self.children)end
 return d
end
MenuUtil={CreateContextMenu=function(owner,fn) lastMenu=description();fn(owner,lastMenu);return lastMenu end}
profile.menuFont="Menu"
local menu=F:CreateContextMenu({},function(_,root)local sub=description();root.children[1]=sub;sub.children[1]=description()end)
local button=CreateFrame();button.fontString=font("stock.ttf",12)
function button:GetRegions()return self.fontString end
for _,fn in ipairs(menu.children[1].children[1].initializers)do fn(button)end
assert(face(button.fontString.object)=="menu.ttf")
button.fontString:SetFontObject(GameFontNormal);assert(button.fontString.object==GameFontNormal)
-- Bubble reuse, bounded event scheduling, restricted frames, external ownership and disable restore.
local bubble=CreateFrame();local text=font("bubble-native.ttf",12);text.object=GameFontNormal
function bubble:GetRegions()return text end
bubbles={bubble};profile.bubbleFont="Bubble";F:RefreshBubbles()
assert(face(text.object)=="bubble.ttf" and text.object:GetFontObjectForAlphabet("roman").size==15)
assert(bubble.scripts.OnShow and not bubble.scripts.OnUpdate)
instance=true;text.object=GameFontNormal;bubble.scripts.OnShow(bubble);assert(text.object==GameFontNormal)
instance=false;function bubble:IsForbidden()return true end
F:ScanBubbles();assert(text.object==GameFontNormal)
function bubble:IsForbidden()return false end
F:ScanBubbles();profile.styleBubbleFonts=false;F:RefreshBubbles()
assert(text.object==GameFontNormal and text.path=="bubble-native.ttf" and next(F.bubbleEvents.events)==nil)
profile.styleBubbleFonts=true;EllesmereUI={ChatBubbles={DB=function()return {enabled=true}end}}
F:RefreshBubbles();assert(text.object==GameFontNormal and next(F.bubbleEvents.events)==nil)
local cfg={enabled=true,font="__global",fontSize=12,outline="__global"}
local refreshed=0
EllesmereUI.ChatBubbles.DB=function()return cfg end
EllesmereUI.ChatBubbles.RefreshStyle=function()refreshed=refreshed+1 end
EllesmereUI.BuildFontDropdownData=function()return {Face={text="Display face",font="face.ttf"}}end
assert(F:ExternalBubbleFonts().Face=="Display face")
F:SetExternalBubbleSetting("font","Face");F:SetExternalBubbleSetting("fontSize",18)
assert(cfg.font=="Face" and cfg.fontSize==18 and refreshed==2 and profile.bubbleFont=="Bubble")
EllesmereUI=nil;F:RefreshBubbles()
local n=#timers;F.bubbleEvents.scripts.OnEvent();F.bubbleEvents.scripts.OnEvent();assert(#timers==n+2)
drain()
-- Shared tooltip restoration is exact and cannot repaint a different owner's font.
local tip=CreateFrame();local tipText=font("tooltip-native.ttf",11);tipText.object=GameFontNormal
function tip:GetRegions()return tipText end
F:StyleTooltip(tip);assert(face(tipText.object)=="changed.ttf")
tip.scripts.OnHide();assert(tipText.object==GameFontNormal and tipText.path=="tooltip-native.ttf")
F:StyleTooltip(tip);tipText.object=ChatFontNormal;tip.scripts.OnHide();assert(tipText.object==ChatFontNormal)
-- Late provider hookup and coalesced refresh; no idle driver.
EllesmereUI={GetFontPath=function()return "late.ttf"end,InvalidateFontCache=function()end}
F:WatchEllesmere();hooks.InvalidateFontCache();hooks.InvalidateFontCache();assert(#timers==1)
drain();assert(face(F.fonts.SunderMessageFont)=="late.ttf")
assert(profile.font=="Saved" and profile.messageFont=="Message" and not F.typographyEvents.scripts.OnUpdate)
''')
print('Typography passed: cascade, unregistered/missing/broken provider, family glyph fallback, live refresh, nested pooled menus, scoped tooltip restore, bubble restrictions/reuse/ownership and bounded events.')
