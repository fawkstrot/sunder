from pathlib import Path
from lupa.lua51 import LuaRuntime
root=Path(os.environ['SUNDER_ADDON_ROOT'])/'Sunder'
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
now, mouseDown, cursorX, cursorY = 10, true, 100, 100
function GetTime() return now end
function GetCursorPosition() return cursorX,cursorY end
function IsMouseButtonDown() return mouseDown end
function IsShiftKeyDown() return false end
function InCombatLockdown() return combat or false end
function UnitIsDND() return dnd or false end
function canaccessvalue(v) return v ~= secret end
function clone(t) if type(t) ~= "table" then return t end local o={};for k,v in pairs(t) do o[k]=clone(v) end;return o end
local methods={}
local function noop() end
for _,k in ipairs({"SetFrameStrata","SetFrameLevel","SetClampedToScreen","SetMovable","EnableMouse",
"RegisterForClicks","RegisterForDrag","SetNormalFontObject","SetNormalTexture","SetPushedTexture",
"SetHighlightTexture","SetColorTexture","SetVertexColor","SetTextColor","SetJustifyH","SetFontObject",
"SetTexture","EnableMouseWheel","AddLine","SetOwner"}) do methods[k]=noop end
function object(kind,name,parent)
  local o={kind=kind,name=name,parent=parent,shown=true,alpha=1,points={},scripts={},text=""}
  setmetatable(o,{__index=methods});return o
end
function CreateFrame(kind,name,parent) local f=object(kind,name,parent); if name then _G[name]=f end; return f end
function methods:GetName() return self.name end
function methods:SetToplevel() end
function methods:SetWordWrap() end
function methods:SetEnabled(value) self.disabled=not value;local f=self.scripts[value and "OnEnable" or "OnDisable"];if f then f(self) end end
function methods:Enable() self:SetEnabled(true) end
function methods:Disable() self:SetEnabled(false) end
function methods:SetVerticalScroll(value) self.verticalScroll=value end
function methods:GetVerticalScroll() return self.verticalScroll or 0 end
function methods:GetObjectType() return self.kind end
function methods:GetChildren() return end
function methods:GetParent() return self.parent end
function methods:SetParent(p) self.parent=p end
function methods:SetScript(k,fn) self.scripts[k]=fn end
function methods:GetScript(k) return self.scripts[k] end
function methods:HookScript(k,fn) local old=self.scripts[k];self.scripts[k]=function(...) if old then old(...) end;fn(...) end end
function methods:Show() local changed=not self.shown;self.shown=true;if changed and self.scripts.OnShow then self.scripts.OnShow(self) end end
function methods:Hide() local changed=self.shown;self.shown=false;if changed and self.scripts.OnHide then self.scripts.OnHide(self) end end
function methods:SetShown(v) if v then self:Show() else self:Hide() end end
function methods:IsShown() return self.shown end
function methods:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
function methods:SetAlpha(v) self.alpha=v end
function methods:GetAlpha() return self.alpha end
function methods:IsMouseOver() return self.hovered or false end
function methods:GetFrameLevel() return 2 end
function methods:GetEffectiveScale() return 1 end
function methods:SetSize(w,h) local change=w~=self.width or h~=self.height;self.width,self.height=w,h;if change and self.scripts.OnSizeChanged then self.scripts.OnSizeChanged(self) end end
function methods:SetWidth(w) self:SetSize(w,self:GetHeight()) end
function methods:SetHeight(h) self:SetSize(self:GetWidth(),h) end
function methods:GetWidth() return self.width or (self.parent and self.parent:GetWidth()) or 500 end
function methods:GetHeight()
  if self.height then return self.height end
  local parent=self.parent and self.parent:GetHeight() or 300
  local t,b=self.points.TOPLEFT,self.points.BOTTOMRIGHT
  return math.max(1,parent+(t and t.y or 0)-(b and b.y or 0))
end
function methods:SetClipsChildren(value) self.clipsChildren=value end
function methods:ClearAllPoints() self.points={} end
function methods:SetPoint(point,relative,rpoint,x,y)
  if type(relative)=="number" then x,y=relative,rpoint;relative=self.parent;rpoint=point end
  self.points[point]={relative=relative,rpoint=rpoint or point,x=x or 0,y=y or 0};self.firstPoint=point
end
function methods:GetPoint() local p=self.points[self.firstPoint] or {};return self.firstPoint or "CENTER",p.relative,p.rpoint or "CENTER",p.x or 0,p.y or 0 end
function methods:SetAllPoints(p) self.parent=p or self.parent end
function methods:GetLeft() return 100 end
function methods:GetTop() return 800 end
function methods:GetBottom() return self:GetTop()-self:GetHeight() end
function methods:GetRect() return self:GetLeft(),self:GetBottom(),self:GetWidth(),self:GetHeight() end
function methods:GetCenter() return 350,500 end
function methods:CreateTexture() return object("Texture",nil,self) end
function methods:CreateFontString() return object("FontString",nil,self) end
function methods:GetFontString() if not self.fs then self.fs=self:CreateFontString() end;return self.fs end
function methods:SetText(t) self.text=t;if self.kind=="Button" then self:GetFontString():SetText(t) end end
function methods:GetText() return self.text end
function methods:GetHighlightTexture() return self:CreateTexture() end
function methods:SetScrollChild(child) self.child=child end
function methods:SetHorizontalScroll(x) self.scroll=x end
function methods:GetHorizontalScroll() return self.scroll or 0 end
function methods:StartMoving() self.moving=true end
function methods:StopMovingOrSizing() self.moving=false end
function methods:HasFocus() return self.focus or false end
function methods:IsProtected() return false end
UIParent=CreateFrame("Frame","UIParent");UIParent:SetSize(1920,1080)
GameTooltip=CreateFrame("GameTooltip")
timers={}
C_Timer={After=function(_,fn) timers[#timers+1]=fn end,NewTicker=function(_,fn) return {fn=fn} end}
function drain() local safety=0;while #timers>0 do local q=timers;timers={};for _,fn in ipairs(q) do fn() end;safety=safety+1;assert(safety<20,"timer cycle") end end
W={hooks={}}
function W:SecureHook(name,fn) self.hooks[name]=fn end
ui={state={windows={}},dock={UpdateTabOrder=function() end}}
config={Print=function(_,text) printMessage=text end}
eui={SkinWindow=function() end,IsActive=function() return false end,GetAccentColor=function() end}
Core={defaults={profile={}},Components={},features={},Libs={LSM={HashTable=function() return {} end,
Fetch=function(_,_,name) return name end}}, db={profile={editBoxAnchor={position="BELOW",yOfs=-2}},char={},global={}}}
function Core:GetModule(name) return ({Whispers=W,UIManager=ui,Config=config,Ellesmere=eui})[name] end
callbacks={}
function Core.db.RegisterCallback(_,event,fn) callbacks[event]=fn end
function Core:RegisterFeature(id,spec) self.features[id]=spec end
function Core:Subscribe() end
function Core:Dispatch() end
Constants={DOCK_HEIGHT=20,EVENTS={UNLOCK_MOVER="unlock",LOCK_MOVER="lock",UPDATE_CONFIG="config"},
  ACTIONS={UpdateConfig=function(key) return "config",key end}}
vars={Core,Constants,{}}
ChatTypeInfo={WHISPER={id=1},BN_WHISPER={id=2},WHISPER_INFORM={id=3}}
filters={}
ChatFrameUtil={AddMessageEventFilter=function(event,fn) filters[event]=fn end,
SetLastActiveWindow=function(box) lastInput=box end,OpenChat=function(_,frame) repliedTo=frame end}
cvars={whisperMode="inline"}
C_CVar={GetCVar=function(k) return cvars[k] end,SetCVar=function(k,v) cvars[k]=v end}
function PlaySoundFile(path,channel) soundsPlayed=(soundsPlayed or 0)+1;lastSoundPath=path;return true end
GENERAL_CHAT_DOCK={DOCKED_CHAT_FRAMES={},selected={}}
function FCF_UnDockFrame(frame)
  frame.isDocked=false
  for i=#GENERAL_CHAT_DOCK.DOCKED_CHAT_FRAMES,1,-1 do if GENERAL_CHAT_DOCK.DOCKED_CHAT_FRAMES[i]==frame then table.remove(GENERAL_CHAT_DOCK.DOCKED_CHAT_FRAMES,i) end end
end
function FCF_DockFrame(frame,_,selected)
  frame.isDocked=true;GENERAL_CHAT_DOCK.DOCKED_CHAT_FRAMES[#GENERAL_CHAT_DOCK.DOCKED_CHAT_FRAMES+1]=frame
  if selected then GENERAL_CHAT_DOCK.selected=frame end
end
function FCF_SelectDockFrame(frame) GENERAL_CHAT_DOCK.selected=frame end
function FCF_Close(frame)
  FCF_UnDockFrame(frame);frame.inUse=false
  ui.state.windows[frame:GetName()].active=false
  if W.hooks.FCF_Close then W.hooks.FCF_Close(frame) end
end
ui.container=CreateFrame("Frame",nil,UIParent);ui.container:SetSize(600,250)
''')
lua.execute('Core:GetModule("Config").Pages={messages=function() return {args={section1={args={}}}} end}')
for name in ['Components/ResizeHandle.lua','Modules/Whispers.lua','Modules/WhisperWorkspace.lua','Modules/WhisperHub.lua','Modules/WhispersOptions.lua','Modules/UIManager.lua']:
    lua.execute(root.joinpath(name).read_text(encoding='utf-8'), 'Sunder', lua.globals().vars)
lua.execute('''
Core.db.profile.whispers=clone(Core.defaults.profile.whispers)
cfg=Core.db.profile.whispers
assert(cfg.mode=="hub", "fresh profiles must use the Whispers window")
assert(cfg.favoritesSeparate==nil,"retired separate Favorites setting returned")

cfg.mode="tabs" -- Exercise the explicitly selected legacy routing below.
cfg.idleWhisperAction="hide";cfg.hubMatchChat=false;cfg.singleRowHeader=false
function ui:CreateDetachedLayout(window)
  local c=CreateFrame("Frame",nil,UIParent);c:SetSize(480,280)
  local dock=CreateFrame("Frame",nil,c)
  function dock:SetTab(tab) tab:SetParent(self) end
  dock:SetTab(window.tab)
  window.detachedLayout={container=c,dock=dock};return window.detachedLayout
end
function conversation(name,target,chatType)
  local frame=CreateFrame("ScrollingMessageFrame",name,UIParent)
  frame.inUse,frame.isTemporary,frame.isDocked,frame.chatType,frame.chatTarget=true,true,true,chatType or "WHISPER",target
  frame:SetSize(480,260)
  local tab=CreateFrame("Button",name.."Tab",ui.container)
  tab.Text=tab:GetFontString();tab.Text:SetText(target)
  function tab:SetUnreadCount(n) self.count=n end
  local edit=CreateFrame("EditBox",name.."EditBox",ui.container);edit:SetHeight(24)
  function edit:SetSunderParent(parent) self:SetParent(parent);self.sunderParent=parent end
  local smf=CreateFrame("Frame",nil,ui.container);smf.state={scrollAtBottom=true}
  function smf:SetLayout(parent,width,height,editBox) self:SetParent(parent);self.input=editBox;self.layoutWidth=width;self.layoutHeight=height end
  function smf:RefreshLayout() end
  function smf:UpdateAlwaysVisible() end
  frame.editBox=edit
  local window={active=true,chatFrame=frame,tab=tab,editBox=edit,slidingMessageFrame=smf}
  ui.state.windows[name]=window
  GENERAL_CHAT_DOCK.DOCKED_CHAT_FRAMES[#GENERAL_CHAT_DOCK.DOCKED_CHAT_FRAMES+1]=frame
  return frame,window
end
W:OnEnable()
assert(cvars.whisperMode=="popout_and_inline")
local normal={}
assert(filters.CHAT_MSG_WHISPER(normal,"CHAT_MSG_WHISPER","text","sender"))
assert(not filters.CHAT_MSG_WHISPER({chatType="WHISPER"},"CHAT_MSG_WHISPER","text","sender"))
local nativeSoundFrame={chatType="WHISPER"}
filters.CHAT_MSG_WHISPER(nativeSoundFrame,"CHAT_MSG_WHISPER","text","sender")
assert(nativeSoundFrame.tellTimer>now,"native ping was not suppressed")
cfg.replaceNativeSound=false;W:ApplySettings(false,"replaceNativeSound")
assert(nativeSoundFrame.tellTimer==nil,"native ping timer was not restored")
cfg.replaceNativeSound=true
assert(not filters.CHAT_MSG_WHISPER(normal,"CHAT_MSG_WHISPER","text","sender","","","","GM"))
cfg.suppress=false;assert(not filters.CHAT_MSG_WHISPER(normal));cfg.suppress=true
alice,aw=conversation("ChatFrame11","Alice-Realm")
W:OnWindowOpened(alice)
W:OnNativeMessage(alice,1)
drain()
assert(alice.isDocked and W.records[alice].placement=="main")
assert(W.records[alice].unread==1 and aw.tab.count==1 and soundsPlayed==1)
assert(GENERAL_CHAT_DOCK.selected~=alice,"incoming whisper stole selection")
W:OnNativeMessage(alice,1);assert(soundsPlayed==1,"notification cooldown failed")
W:OnNativeMessage(alice,3);assert(soundsPlayed==1,"outgoing reply played a sound")
now=13;W:OnNativeMessage(alice,1);assert(soundsPlayed==2)
cfg.muteInCombat=true;combat=true;now=20;W:OnNativeMessage(alice,1);assert(soundsPlayed==2);combat=false
cfg.muteDND=true;dnd=true;now=25;W:OnNativeMessage(alice,1);assert(soundsPlayed==2);dnd=false
cfg.mode="hub"
bob,bw=conversation("ChatFrame12","Bob-Realm")
W:OnWindowOpened(bob);W:OnNativeMessage(bob,1);drain()
assert(W.hub:IsShown() and W.records[bob].placement=="hub" and not bob.isDocked)
assert(bw.editBox:GetParent()==W.hubContent and bw.tab:GetParent()==W.parking)
assert(W.selected==bob and bw.slidingMessageFrame:GetParent()==W.hubContent)
cara,cw=conversation("ChatFrame13","Cara-Realm")
W:OnWindowOpened(cara);W:OnNativeMessage(cara,1);drain()
assert(W.selected==bob and not cw.slidingMessageFrame:IsShown(),"new conversation replaced current reading")
assert(W.records[cara].unread==1)
W:SelectConversation(cara,false)
assert(W.selected==cara and cw.slidingMessageFrame:IsShown() and not bw.slidingMessageFrame:IsShown())
assert(W.records[cara].unread==0 and lastInput==cw.editBox)
W:SelectConversation(cara,true);assert(repliedTo==cara)
W:Place(cara,"detached",true);drain()
assert(W.records[cara].placement=="detached" and cw.slidingMessageFrame:GetParent()==cw.detachedLayout.container)
W:Place(cara,"hub",true);drain()
assert(cw.editBox:GetParent()==W.hubContent and not cw.detachedLayout.container:IsShown())
Core.sunderMoverUnlocked=true;W:SetHubEditMode(true)
local handle=W.hubResize
handle.scripts.OnMouseDown(handle,"LeftButton")
cursorX,cursorY=200,50;handle:UpdateResize();handle:FinishResize();drain()
assert(cfg.hubWidth==640 and cfg.hubHeight==390,"hub resize did not save")
Core.sunderMoverUnlocked=false;W:SetHubEditMode(false)
W.hubOverlay.scripts.OnDragStart();assert(not W.hubMoving,"locked hub moved")
cfg.keepMessagesOpen=false;cfg.keepUnread=false;cfg.holdTime=5;cfg.fadeTime=0.5
now=200;W:Tick();assert(not W.hub:IsShown(),"inactive group did not hide")
W:OnNativeMessage(bob,1);assert(W.hub:IsShown() and W.selected==cara,"incoming reveal stole active conversation")
cfg.keepUnread=true;now=500;W:Tick();assert(W.hub:IsShown(),"unread conversation faded away")
W:MarkRead(bob);W:MarkRead(cara)
cw.slidingMessageFrame.state.scrollAtBottom=false
W:OnNativeMessage(cara,1);W:Tick();assert(W.records[cara].unread==1,"reading history cleared new unread messages")
cw.slidingMessageFrame.state.scrollAtBottom=true
W:Tick();assert(W.records[cara].unread==0)
local oldTab=W.hubTabs[cara]
FCF_Close(cara);assert(not W.records[cara] and not W.hubTabs[cara])
cara.inUse=true;cara.chatTarget="Dora-Realm";cw.active=true;cw.tab.Text:SetText("Dora-Realm")
W:OnWindowOpened(cara);drain()
assert(W.hubTabs[cara]==oldTab and W.records[cara].key=="dora-realm","pooled conversation retained old identity or leaked a new tab")
secret={}
bn,bnw=conversation("ChatFrame14",secret,"BN_WHISPER")
W:OnWindowOpened(bn);drain();assert(W.records[bn].key==nil)
W:Save();assert(Core.db.char.whisperLayouts["dora-realm"] and not Core.db.char.whisperLayouts[secret])
cfg.enabled=false;W:ApplySettings(false);drain()
assert(cvars.whisperMode=="inline" and not filters.CHAT_MSG_WHISPER(normal),"disable did not restore native delivery")
assert(bob.isDocked and cara.isDocked and bn.isDocked)
local schema=Core.features.whispers.buildOptions()
assert(schema.args.routing and schema.args.visibility and schema.args.notifications and schema.args.display)
assert(schema.args.notifications.args.customSound.validate(nil,"Interface\\\\AddOns\\\\Mine\\\\ping.ogg")==true)
assert(type(schema.args.notifications.args.customSound.validate(nil,"C:/bad.exe"))=="string")
cfg.enabled=true;cfg.mode="hub"
erin,ew=conversation("ChatFrame15","Erin-Realm")
function erin:IsProtected() return true end
combat=true;W:OnWindowOpened(erin);drain()
assert(erin.isDocked and W.deferredPlacements[erin],"protected placement was not deferred")
combat=false;W:Tick();drain()
assert(W.records[erin].placement=="hub" and not erin.isDocked,"placement did not resume after combat")
local pooled,pw=conversation("ChatFrame16","Old-Realm")
Core.db.char.whisperLayouts["old-realm"]={placement="detached"}
W:OnWindowOpened(pooled)
FCF_Close(pooled)
pooled.inUse=true;pooled.chatTarget="New-Realm";pw.active=true
W:OnWindowOpened(pooled)
local originalPlace=W.Place
local placements=0
function W:Place(frame,...)
  if frame==pooled then placements=placements+1 end
  return originalPlace(self,frame,...)
end
drain()
assert(placements==1 and W.records[pooled].key=="new-realm","stale deferred callback acted on a reused frame")
''')
print('Whisper checks passed: native filters/GM exceptions, sounds/throttling/mutes, no focus stealing, main/hub/detached transitions, individual inputs, hub resizing/lock, inactivity/unread/readback, frame pooling, restricted identities, persistence and feature disable.')
