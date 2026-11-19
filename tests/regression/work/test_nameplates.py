"""Native nameplate preference lifecycle; source-backed presentation check when reference is present."""
import os
import re
from pathlib import Path
from lupa.lua51 import LuaRuntime

root = Path(os.environ['SUNDER_ADDON_ROOT'])
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
N={}; callbacks={}; combat=false; instance="none"; writes=0
config={enabled=false,mode="bars",instanceMode="inherit",nameColor="class",barColor="class",size=0}
Core={db={char={},profile={nameplates=config},RegisterCallback=function(_,e,f) callbacks[e]=f end}}
function Core:GetModule()return N end
function Core:RegisterFeature(id,f)assert(id=="nameplates");feature=f end
function InCombatLockdown()return combat end
function IsInInstance()return instance~="none",instance end
function CreateFrame()
 local f={events={}}
 function f:SetScript(k,v)self[k]=v end
 function f:RegisterEvent(e)self.events[e]=true end
 function f:UnregisterAllEvents()self.events={} end
 return f
end
Enum={NamePlateSize={Small=1,Medium=2,Large=3,ExtraLarge=4,Huge=5}}
v="nameplateShowFriendlyPlayers"; n="nameplateShowOnlyNameForFriendlyPlayerUnits"
nc="nameplateUseClassColorForFriendlyPlayerUnitNames"; bc="nameplateShowFriendlyClassColor"; sz="nameplateSize"
cvars={[v]="0",[n]="1",[nc]="0",[bc]="0",[sz]="2",nameplateShowEnemies="1"}
function GetCVar(k)return cvars[k] end
function SetCVar(k,value)
 assert(not combat,"CVar mutation in combat");assert(cvars[k]~=nil,"unsupported CVar write")
 if failKey==k then error("rejected") end
 cvars[k]=tostring(value);writes=writes+1
 if N.events then N.events.OnEvent(N.events,"CVAR_UPDATE",k,value) end
end
''')
source = (root/'Sunder/Modules/Nameplates.lua').read_text(encoding='utf-8-sig')
lua.execute('assert(loadstring(...))("Sunder",{Core})', source)
lua.execute('''
N:OnEnable();assert(writes==0 and not next(N:Ledger()))
config.enabled=true;N:Refresh();assert(cvars[v]=="1" and cvars[n]=="0" and cvars[nc]=="1" and cvars[bc]=="1")
assert(cvars.nameplateShowEnemies=="1" and cvars[sz]=="2")
local count=writes;N:Refresh();assert(writes==count)
-- Reload/login retains the original baseline rather than capturing our own values.
N:OnEnable();assert(N:Ledger()[v].original=="0" and writes==count)
config.instanceMode="names";instance="party";combat=true;N:OnEvent("PLAYER_ENTERING_WORLD")
assert(N.pending and cvars[n]=="0" and writes==count)
instance="raid";config.instanceMode="bars";N:Refresh();combat=false;N:OnEvent("PLAYER_REGEN_ENABLED")
assert(not N.pending and cvars[n]=="0")
config.instanceMode="names";N:Refresh();assert(cvars[n]=="1")
instance="none";N:OnEvent("ZONE_CHANGED_NEW_AREA");assert(cvars[n]=="0")
instance="pvp";N:Refresh();assert(cvars[n]=="0")
-- Native size is opt-in, reversible, and includes every native enum choice.
config.size=4;N:Refresh();assert(cvars[sz]=="4");config.size=0;N:Refresh();assert(cvars[sz]=="2")
assert(feature.buildOptions().args.size.values()[4]=="Extra large")
-- External ownership, no automatic reassertion loops, explicit reacquisition.
SetCVar(nc,"0");N:Refresh();assert(cvars[nc]=="0" and N.blocked[nc] and not N:Ledger()[nc])
N.blocked=nil;N:OnEnable();assert(cvars[nc]=="0" and N.blocked[nc])
assert(N:Status():match("another addon"));N:Reapply();assert(cvars[nc]=="1" and N:Ledger()[nc].original=="0")
config.nameColor="keep";N:Refresh();assert(cvars[nc]=="0")
-- Disable in combat restores only owned settings when combat ends.
combat=true;config.enabled=false;N:Refresh();assert(cvars[v]=="1")
combat=false;N:OnEvent("PLAYER_REGEN_ENABLED");assert(cvars[v]=="0" and cvars[n]=="1" and cvars[bc]=="0")
assert(not next(N:Ledger()))
-- Unsupported clients and write errors are visible and do not crash startup.
config.enabled=true;cvars[bc]=nil;failKey=n;N:Refresh();assert(N.missing[bc] and N.failed[n])
failKey=nil;cvars[bc]="0";N:Refresh();assert(cvars[n]=="0")
config.enabled=false;failKey=v;N:Refresh();assert(N.failed[v] and N:Ledger()[v])
failKey=nil;N:Refresh();assert(cvars[v]=="0" and not N:Ledger()[v])
-- Profile resets release old overrides, while changes made during unload survive.
config.enabled=true;N:Refresh();cvars[v]="0";callbacks.OnProfileChanged();assert(cvars[v]=="0" and N.blocked[v])
config.enabled=false;callbacks.OnProfileReset();assert(cvars[v]=="0")
config.enabled=true;N:Reapply();combat=true;N:OnDisable();assert(N.pending)
combat=false;N:OnEvent("PLAYER_REGEN_ENABLED");assert(not next(N.events.events) and cvars[v]=="0")
N:OnEnable();assert(cvars[v]=="1")
config.mode="off";N:Refresh();assert(cvars[v]=="0" and cvars[n]=="1" and cvars[bc]=="0")
''')

# Execute Blizzard's actual method, without importing its entire UI or claiming
# engine simulation. A fresh CI checkout does not require a network download.
reference = root.parents[1]/'.local/references/wow-ui-source-forever/Interface/AddOns/Blizzard_NamePlates/Blizzard_NamePlateUnitFrame.lua'
if reference.exists():
    native = re.search(r'function NamePlateUnitFrameMixin:UpdateShowOnlyName\(\).*?\nend', reference.read_text(encoding='utf-8'), re.S).group()
    lua.execute('''
    NamePlateUnitFrameMixin={};NamePlateConstants={SHOW_ONLY_NAME_FOR_FRIENDLY_PLAYER_UNITS_CVAR=n}
    CVarCallbackRegistry={GetCVarValueBool=function(_,k)return cvars[k]=="1" end}
    function CompactUnitFrame_UpdatePlayerLevelDiff()end
    function part()return {SetShowOnlyName=function(self,v)self.namesOnly=v end}end
    nativePlate={HealthBarsContainer={healthBar=part()},CastBarsContainer={castBar=part()},AurasFrame=part(),ClassificationFrame=part(),RaidTargetFrame=part(),
      IsFriend=function()return true end,IsPlayer=function()return true end,UpdateAnchors=function()end,UpdateHitTestArea=function()end}
    ''')
    lua.execute(native)
    lua.execute('''
    instance="party";config.mode="bars";config.instanceMode="bars";N:Reapply()
    NamePlateUnitFrameMixin.UpdateShowOnlyName(nativePlate);assert(nativePlate.HealthBarsContainer.healthBar.namesOnly==false)
    config.instanceMode="names";N:Refresh();NamePlateUnitFrameMixin.UpdateShowOnlyName(nativePlate)
    assert(nativePlate.HealthBarsContainer.healthBar.namesOnly==true and nativePlate.CastBarsContainer.castBar.namesOnly==true)
    ''')
    print('PASS actual downloaded Blizzard UpdateShowOnlyName with simulated dungeon preferences (not engine validation)')
else:
    print('SKIP optional Blizzard source integration: local reference not downloaded')
print('PASS nameplate ownership, restoration, combat, location, profile, unsupported API and settings workflows')
