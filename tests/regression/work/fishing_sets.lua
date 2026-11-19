local sets={[0]={name="Fishing outfit",item=100},[7]={name="Normal outfit",item=200}}
local inv=200
local ignored=false
function GetInventoryItemID(_,slot)if slot==16 then return inv end end
C_Item.GetItemInfoInstant=function(id)if not unknown then return id,nil,nil,nil,nil,2,id==100 and 20 or 7 end end
local iconOffset=1000
C_Item.GetItemIconByID=function(id)return id+iconOffset end
local available=true
C_EquipmentSet={
 CanUseEquipmentSets=function()return available end,
 GetEquipmentSetIDs=function()local ids={};for id in pairs(sets)do ids[#ids+1]=id end;return ids end,
 GetEquipmentSetInfo=function(id)local s=sets[id];if s then return s.name,1,id,false end end,
 GetIgnoredSlots=function()return {[16]=ignored} end,
 GetItemIDs=function(id)return {[16]=sets[id].item} end,
 UseEquipmentSet=function()error("events must not equip")end,
 CreateEquipmentSet=function()error("must not overwrite/create user sets")end,
}
local timers={};C_Timer={After=function(_,fn)timers[#timers+1]=fn end}
local function drain()local t=timers;timers={};for _,fn in ipairs(t)do fn()end end
assert(F:FishingSetChoices("fishingSet")["0"]=="Fishing outfit")
local body,reason=F:BuildFishingMacro();assert(not body and reason:find("Choose both",1,true))
F:SetFishingSet("fishingSet","0");F:SetFishingSet("normalSet","7")
assert(Core.db.char.fishingGear.fishingSet==0 and F:GetFishingSet("fishingSet")=="0")
assert(F:BuildFishingMacro():find("/equipset Fishing outfit",1,true))
F:SetFishingSet("normalSet","0");body,reason=F:BuildFishingMacro();assert(not body and reason:find("different",1,true));F:SetFishingSet("normalSet","7")
sets[0].item=200;body,reason=F:BuildFishingMacro();assert(not body and reason:find("must contain a fishing pole",1,true));sets[0].item=100
sets[7].item=100;body,reason=F:BuildFishingMacro();assert(not body and reason:find("normal weapons",1,true));sets[7].item=-1
body,reason=F:BuildFishingMacro();assert(not body and reason:find("main-hand",1,true));sets[7].item=200
unknown=true;body,reason=F:BuildFishingMacro();assert(not body and reason:find("Waiting",1,true));unknown=false
ignored=true;body,reason=F:BuildFishingMacro();assert(not body and reason:find("ignores",1,true));ignored=false
local options=Core.feature.buildOptions().args
assert(options.fishingSet and options.normalSet and options.equipment and not options.savePole and not options.saveWeapons)
drain() -- Initial selection may schedule creation, but macro APIs are not installed yet.
local macros={};local creates,edits=0,0;local full=false;MAX_ACCOUNT_MACROS=120;MAX_CHARACTER_MACROS=18
function GetNumMacros()local n,a=0,0;for k in pairs(macros)do if k>120 then n=n+1 else a=a+1 end end;return a,full and 18 or n end
function GetMacroInfo(i)local m=macros[i];if m then return m.name,m.icon or 136245,m.body end end
function CreateMacro(name,icon,body,char)assert(not combat and char and #body<=255);creates=creates+1;macros[121]={name=name,body=body,icon=icon};return 121 end
function EditMacro(i,name,icon,body)assert(not combat);edits=edits+1;macros[i]={name=name,body=body,icon=icon};return i end
F:WriteFishingMacro(true);assert(creates==1 and edits==0)
assert(macros[121].icon==1100 and macros[121].body:find("#showtooltip item:100",1,true))
assert(macros[121].body:find("/equipset Fishing outfit",1,true) and not macros[121].body:find("/equipslot",1,true))
F:WriteFishingMacro(true);assert(creates==1 and edits==0)
inv=100;F:OnEvent("PLAYER_EQUIPMENT_CHANGED",16);F:OnEvent("EQUIPMENT_SWAP_FINISHED",true)
assert(edits==0 and #timers==1);drain();assert(edits==1 and macros[121].body:find("/equipset Normal outfit",1,true))
assert(macros[121].icon==1200 and macros[121].body:find("#showtooltip item:200",1,true))
-- Rename follows the ID; upgrading gear needs no individual item capture.
sets[7].name="New normal outfit";sets[7].item=400;F:OnEvent("EQUIPMENT_SETS_CHANGED");drain()
assert(macros[121].body:find("/equipset New normal outfit",1,true) and Core.db.char.fishingGear.normalSet==7)
sets[7]=nil;F:OnEvent("EQUIPMENT_SETS_CHANGED");drain()
assert(F:FishingSetChoices("normalSet")["7"]:find("Missing",1,true))
assert(macros[121].body=="/stopmacro [combat]\n/sunder fish options")
sets[8]={name="New normal outfit",item=200};F:OnEvent("EQUIPMENT_SETS_CHANGED");drain();assert(Core.db.char.fishingGear.normalSet==7)
F:SetFishingSet("normalSet","8");drain();assert(macros[121].body:find("/equipset New normal outfit",1,true))
-- Icon-only changes refresh the same macro even if its body is unchanged.
local priorEdits=edits;local priorBody=macros[121].body;iconOffset=2000
F:OnEvent("GET_ITEM_INFO_RECEIVED");drain()
assert(edits==priorEdits+1 and macros[121].body==priorBody and macros[121].icon==2200)
local getter=C_Item.GetItemIconByID;C_Item.GetItemIconByID=nil
local _,_,fallbackIcon=F:BuildFishingMacro();assert(fallbackIcon==1)
C_Item.GetItemIconByID=getter
-- Parser delimiters cannot inject commands/conditions. Localized names remain exact.
for _,name in ipairs({"Bad;name","[bad]"," bad","bad ","bad\n/run evil"})do
 sets[8].name=name;body,reason=F:BuildFishingMacro();assert(not body and reason:find("Rename",1,true))
end
sets[8].name="Équipement normal";assert(F:BuildFishingMacro():find("Équipement normal",1,true))
sets[8].name=string.rep("x",240);body,reason=F:BuildFishingMacro();assert(not body and reason:find("Shorten",1,true));sets[8].name="Normal"
F:WriteFishingMacro(false)
macros[121].body="/say my own macro";local before=edits
F:WriteFishingMacro(true);assert(edits==before+1 and macros[121].body:find("/equipset",1,true))
macros[121]=nil;F:WriteFishingMacro(false);assert(creates==2)
-- Reuse an account macro when no character copy exists; keep its action-bar index.
macros[1]=macros[121];macros[121]=nil;macros[1].body="/old custom body"
F:WriteFishingMacro(true);assert(creates==2 and macros[1].body:find("/equipset",1,true) and not macros[121])
-- Prefer character copy; leave other macro names and the account duplicate alone.
macros[121]={name="Sunder Fish",body="/old character body"};macros[2]={name="Other",body="/other"}
macros[1].body="/account duplicate";F:WriteFishingMacro(true)
assert(macros[121].body:find("/equipset",1,true) and macros[1].body=="/account duplicate" and macros[2].body=="/other")
macros[1]=nil;macros[2]=nil;macros[121]=nil
full=true;F:WriteFishingMacro(true);assert(creates==2 and lastNotice:find("full",1,true));full=false
local create=CreateMacro;CreateMacro=function()return nil end
F:WriteFishingMacro(true);assert(lastNotice:find("could not save",1,true));CreateMacro=create
F:WriteFishingMacro(true);assert(creates==3)
-- Upgrade the named previous item-based macro regardless of checkpoint; legacy captures are unused.
macros[121].body="/equipslot 16 item:100";Core.db.char.fishingGear.macroBody=macros[121].body
Core.db.char.fishingGear.pole={item="item:100"};F:WriteFishingMacro(false)
assert(not macros[121].body:find("equipslot",1,true))
stateCombat();before=edits;sets[8].name="Renamed during combat"
F:OnEvent("EQUIPMENT_SETS_CHANGED");drain();F:SetFishingSet("normalSet","none");F:WriteFishingMacro(true)
assert(edits==before and Core.db.char.fishingGear.normalSet==8)
peace();drain();assert(edits==before+1 and macros[121].body:find("Renamed during combat",1,true))
available=false;F:WriteFishingMacro(false);assert(macros[121].body:find("fish options",1,true));available=true;F:WriteFishingMacro(false)
-- Locate the native manager's actual sidebar instead of guessing its index.
local pane={};local opened,tab=0,nil
PaperDollFrame={EquipmentManagerPane=pane,IsShown=function()return opened>0 end}
function ToggleCharacter(which)assert(which=="PaperDollFrame");opened=opened+1 end
PAPERDOLL_SIDEBARS={{},{},{}};function GetPaperDollSideBarFrame(i)if i==2 then return pane end end
function PaperDollFrame_SetSidebar(_,i)tab=i end
F:OpenFishingEquipmentManager();assert(opened==1 and tab==2)
F:OpenFishingEquipmentManager();assert(opened==1)
CharacterFrame={IsShown=function()return false end}
F:OpenFishingEquipmentManager();assert(opened==2)
F:SetMode(false)
