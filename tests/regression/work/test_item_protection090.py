exec(open('work/test_whispers.py',encoding='utf-8').read())
lua.execute('''
local m=getmetatable(UIParent).__index
function m:RegisterEvent(event) self.events=self.events or {};self.events[event]=true end
function m:UnregisterAllEvents() self.events={} end
P={};local get=Core.GetModule
function Core:GetModule(name,...) if name=="ItemProtection" then return P end return get(self,name,...) end
Core.features=Core.features or {}
function Core:RegisterFeature(id,feature) Core.features[id]=feature end
items={ ["0:1"]={guid="Item-A",itemID=100,hyperlink="[Useful sword]"},["0:2"]={guid="Item-B",itemID=100,hyperlink="[Another sword]"} }
locked={};unlockCalls={};lockCalls=0
C_Container={GetContainerNumSlots=function(bag)return bag==0 and 4 or 0 end,
 GetContainerItemInfo=function(bag,slot)return items[bag..":"..slot] end}
ItemLocation={CreateFromBagAndSlot=function(_,bag,slot)return {key=bag..":"..slot}end}
C_Item={GetItemGUID=function(loc)return items[loc.key] and items[loc.key].guid end,
 LockItem=function(loc)local id=C_Item.GetItemGUID(loc);locked[id]=true;lockCalls=lockCalls+1 end,
 UnlockItem=function(loc)local id=C_Item.GetItemGUID(loc);unlockCalls[#unlockCalls+1]=id;locked[id]=nil end,
 UnlockItemByGUID=function(id)unlockCalls[#unlockCalls+1]=id;locked[id]=nil end,
 IsLocked=function(loc)return locked[C_Item.GetItemGUID(loc)] or false end}
''')
lua.execute(root.joinpath('Modules/ItemProtection.lua').read_text(encoding='utf-8'),'Sunder',lua.globals().vars)
lua.execute('''
Core.db.profile.itemProtection=clone(Core.defaults.profile.itemProtection)
P:OnEnable();drain()
P:Protect("Item-A")
assert(P:Records()["Item-A"] and P.owned["Item-A"] and locked["Item-A"])
assert(not P:Records()["Item-B"] and not locked["Item-B"],"protection spread to another copy")
local temp=items["0:1"];items["0:1"]=items["0:2"];items["0:2"]=temp
P:Refresh();assert(P.owned["Item-A"].slot==2,"protection followed the slot instead of GUID")
P:Unprotect("Item-A");assert(not locked["Item-A"] and unlockCalls[#unlockCalls]=="Item-A" and not P:Records()["Item-A"])
-- Foreign locks must never be adopted or released.
locked["Item-B"]=true;P:Protect("Item-B")
assert(not P.owned["Item-B"] and P.status["Item-B"]=="Item busy; waiting for our lock")
local count=#unlockCalls;P:Unprotect("Item-B");assert(#unlockCalls==count and locked["Item-B"])
-- Deferred acquisition and relocking after an external unlock.
P:Protect("Item-B");locked["Item-B"]=nil;P:Refresh();assert(P.owned["Item-B"])
locked["Item-B"]=nil;P:Refresh();assert(locked["Item-B"])
-- Disable releases only our locks and preserves saved intent; enable reapplies.
Core.db.profile.itemProtection.enabled=false;P:Refresh()
assert(not locked["Item-B"] and P:Records()["Item-B"])
Core.db.profile.itemProtection.enabled=true;P:Refresh();assert(locked["Item-B"])
-- A stale tooltip must never toggle another item that replaced the hovered copy.
GameTooltip.GetOwner=function()return {IsMouseOver=function()return true end}end
GameTooltip:Show();P.hover={bag=0,slot=1,guid="Item-B"}
assert(P:Hovered()=="Item-B")
items["0:1"]={guid="Item-C",itemID=200,hyperlink="[Replacement]"}
assert(P:Hovered()==nil)
P:Unprotect("Item-B");assert(unlockCalls[#unlockCalls]=="Item-B" and not locked["Item-C"])
-- Failed native lock is displayed honestly, never reported as active.
local lock=C_Item.LockItem;C_Item.LockItem=function()end
P:Protect("Item-C");assert(not P.owned["Item-C"] and P.status["Item-C"]=="NOT LOCKED")
C_Item.LockItem=lock;P:Refresh();assert(P.owned["Item-C"])
-- Non-destructive pickup probe reports both blocked and bypassed locks.
local cursor=false;CursorHasItem=function()return cursor end;ClearCursor=function()cursor=false end
P.selectedTest="Item-C";C_Container.PickupContainerItem=function()end
P:TestPickup();assert(P.pickupCheck:find("PASS:",1,true))
C_Container.PickupContainerItem=function()cursor=true end
P:TestPickup();assert(not cursor and P.pickupCheck:find("FAILED:",1,true))
-- Saved identity survives a reload; native ownership is reacquired.
local snapshot=clone(Core.db.char.protectedItems)
P.events:GetScript("OnEvent")(P.events,"PLAYER_LOGOUT")
assert(not locked["Item-C"] and snapshot["Item-C"] and Core.db.char.protectedItems["Item-C"])
P.shuttingDown=nil;P:OnEnable();drain();assert(locked["Item-C"] and P.owned["Item-C"])
P:OnDisable();assert(not locked["Item-C"])
-- Missing API degrades cleanly without creating fake protections.
C_Item.LockItem=nil;assert(not P:Available());P:Refresh()
assert(Core.features.itemProtection.buildOptions().args.verification.name:find("NOT yet been verified",1,true))
''')
print('Item protection checks passed: exact-copy GUID persistence, slot reuse/sorting, native lock readback/failure, foreign ownership, deferred acquisition/relock, disable/re-enable/logout/reload, stale tooltip rejection, and non-destructive pickup probe pass/fail.')
