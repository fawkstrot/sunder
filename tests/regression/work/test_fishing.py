"""Fishing lifecycle contract. Secure snippets run explicitly, not as live engine proof."""
import os
from pathlib import Path
from lupa.lua51 import LuaRuntime
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
F={}; config={key="SPACE",autoPole=false}; callbacks={}; permanent={SPACE="JUMP",F8="ACTIONBUTTON1"}
Core={db={char={},profile={fishing=config},RegisterCallback=function(_,event,fn) callbacks[event]=fn end}}
function Core:GetModule(name) if name=="Fishing" then return F end return {Print=function(_,s) lastNotice=s end,OpenSettings=function()end} end
function Core:RegisterFeature(id,feature) assert(id=="fishing"); self.feature=feature end
combat=false; secure=false; channel=nil; pole=false; unknown=false; conflict=false; learned=true
function InCombatLockdown() return combat end
function CreateFrame(kind,name,parent,template)
 assert(not combat)
 local f={attrs={},bindings={},events={}}
 function f:SetAttribute(k,v) assert(not combat);self.attrs[k]=v end
 function f:RegisterForClicks(...) self.clicks={...} end
 function f:RegisterEvent(e) self.events[e]=true end
 function f:UnregisterAllEvents() self.events={} end
 function f:SetScript(k,v) self[k]=v end
 function f:ClearBindings() assert(secure);self.bindings={} end
 if name then _G[name]=f end
 return f
end
function RegisterStateDriver(f,id,condition) assert(not combat);f.condition=condition end
function ClearOverrideBindings(f) assert(not combat);f.bindings={} end
function SetOverrideBinding(f,priority,key,action) assert(not combat);f.bindings[key]=action end
function SetOverrideBindingClick(f,priority,key,name,button) SetOverrideBinding(f,priority,key,"CLICK "..name..":"..button) end
function SetBinding() error("permanent binding mutation") end
function SaveBindings() error("permanent binding save") end
cvars={SoftTargetInteract="0",SoftTargetInteractArc="0",SoftTargetInteractRange="10",ActionButtonUseKeyDown="1"}
function GetCVar(k) return cvars[k] end
function SetCVar(k,v) assert(not combat);cvars[k]=v end
C_AddOns={IsAddOnLoaded=function()return conflict end}
C_SpellBook={IsSpellKnown=function(id)return learned and id==7731 end}
C_Spell={GetSpellName=function()return "Fishing" end}
function UnitChannelInfo() if channel then return channel,nil,nil,nil,nil,nil,nil,channel=="Fishing" and 7731 or 999 end end
function GetInventoryItemID() return pole and 100 or nil end
C_Item={GetItemInfoInstant=function()if not unknown then return 100,nil,nil,nil,nil,2,20 end end}
function stateCombat()
 combat=true;secure=true
 local fn=assert(loadstring("return function(self,newstate) "..F.owner.attrs["_onstate-combat"].." end"))()
 fn(F.owner,"combat");secure=false
 F:OnEvent("PLAYER_REGEN_DISABLED")
end
function peace() combat=false; F:OnEvent("PLAYER_REGEN_ENABLED") end
function action(key) return F.owner and F.owner.bindings[key] or permanent[key] end
''')
source=(Path(os.environ['SUNDER_ADDON_ROOT'])/'Sunder/Modules/Fishing.lua').read_text(encoding='utf-8-sig')
lua.execute('local chunk=assert(loadstring(...));chunk("Sunder",{Core})',source)
macro_source=(Path(os.environ['SUNDER_ADDON_ROOT'])/'Sunder/Modules/FishingMacro.lua').read_text(encoding='utf-8-sig')
lua.execute('local chunk=assert(loadstring(...));chunk("Sunder",{Core})',macro_source)
lua.execute('''
F:OnEnable();assert(not F.owner and not F.wanted)
F:Command("on");assert(action("SPACE")=="CLICK SunderFishingButton:LeftButton")
assert(F.button.attrs.spell==7731 and F.button.attrs.useOnKeyDown==true)
assert(#F.button.clicks==2 and F.owner.condition=="[combat] combat; peace")
channel="Fishing";F:OnEvent("UNIT_SPELLCAST_CHANNEL_START","target");assert(F.applied=="Cast")
F:OnEvent("UNIT_SPELLCAST_CHANNEL_START","player");assert(action("SPACE")=="INTERACTTARGET" and cvars.SoftTargetInteract=="3")
stateCombat();assert(action("SPACE")=="JUMP")
F:SetKey("F8");F:SetMode(false);assert(action("F8")=="ACTIONBUTTON1")
channel=nil;peace();assert(action("SPACE")=="JUMP" and cvars.SoftTargetInteract=="0")
F:SetMode(true);assert(action("F8"):match("CLICK"));F:SetKey("SHIFT-F");assert(action("F8")=="ACTIONBUTTON1")
for _,k in ipairs({"", "ENTER", "CTRL-ESCAPE", "BUTTON1", "garbage", "CTRL-SHIFT-ENTER"}) do assert(not F:SetKey(k), k) end
assert(F:SetKey("SPACE"));F:Command("toggle");assert(action("SPACE")=="JUMP")
F:Command("auto on");pole=true;F:OnEvent("PLAYER_EQUIPMENT_CHANGED",16);assert(F.wanted)
unknown=true;F:OnEvent("GET_ITEM_INFO_RECEIVED");assert(F.wanted)
unknown=false;pole=false;F:OnEvent("PLAYER_EQUIPMENT_CHANGED",16);assert(not F.wanted)
pole=true;stateCombat();F:OnEvent("PLAYER_EQUIPMENT_CHANGED",16);assert(F.wanted and action("SPACE")=="JUMP")
peace();assert(F.applied=="Cast")
channel="Fishing";F:Refresh();cvars.SoftTargetInteractRange="25";F:SetMode(false)
assert(cvars.SoftTargetInteract=="0" and cvars.SoftTargetInteractRange=="25")
channel="Other";F:SetMode(true);assert(F.applied=="Cast")
channel="Fishing";F:Refresh();channel=nil;F:OnEvent("UNIT_SPELLCAST_CHANNEL_STOP","player");assert(F.applied=="Cast" and cvars.SoftTargetInteract=="0")
conflict=true;F:Refresh();assert(not F.applied and F.problem:match("Better Fishing"));conflict=false
learned=false;F:Refresh();assert(not F.applied);learned=true
local saved=cvars.SoftTargetInteract;cvars.SoftTargetInteract=nil;F:Refresh();assert(not F.applied);cvars.SoftTargetInteract=saved
F:Refresh();stateCombat();F:OnDisable();assert(action("SPACE")=="JUMP")
combat=false;F.events.OnEvent();assert(not next(F.events.events) and not next(F.owner.bindings))
F:OnEnable();assert(F.wanted);callbacks.OnProfileReset();assert(F.wanted)
F:Command("auto off");callbacks.OnProfileChanged();assert(not F.wanted and action("SPACE")=="JUMP")
F:SetMode(true);F:OnEvent("PLAYER_LOGOUT");assert(not F.wanted and action("SPACE")=="JUMP")
local collected={};local fishLoot=true
function IsFishingLoot()return fishLoot end
function GetNumLootItems()return 3 end
function LootSlot(slot)collected[#collected+1]=slot end
F:SetMode(true);F:OnEvent("LOOT_READY");assert(#collected==3 and collected[1]==3 and collected[3]==1)
collected={};fishLoot=false;F:OnEvent("LOOT_READY");assert(#collected==0)
fishLoot=true;config.autoLoot=false;F:LootReady();assert(#collected==0)
config.autoLoot=true;conflict=true;F:LootReady();assert(#collected==0)
conflict=false;stateCombat();F:LootReady();assert(#collected==0);peace()
F:SetMode(false);F:LootReady();assert(#collected==0)
F:SetMode(true);IsFishingLoot=nil;F:LootReady();assert(#collected==0)
F:SetMode(false)
assert(permanent.SPACE=="JUMP" and permanent.F8=="ACTIONBUTTON1")
''')
print('PASS Fishing: cast/interact, combat snippet, deferral, equipment, cleanup, profiles, conflicts and keys')
lua.execute('''
-- Auto means following equipment, not forcing fishing mode on.
pole=false;F:Command("auto on");assert(lastNotice:find("detection on",1,true) and lastNotice:find("equip a fishing pole",1,true))
pole=true;F:Command("auto on");assert(F.applied=="Cast" and lastNotice:find("Fishing Mode on",1,true))
unknown=true;F:OnEvent("PLAYER_EQUIPMENT_CHANGED",16);assert(F.pendingPole and F.wanted)
F.applied=nil;assert(F:Status():find("Waiting",1,true));unknown=false;F:OnEvent("GET_ITEM_INFO_RECEIVED");assert(F.applied=="Cast")
''')
lua.execute(Path('work/fishing_sets.lua').read_text(encoding='utf-8-sig'))
print('PASS Fishing equipment-set macro lifecycle')
