exec(open('work/test_item_protection090.py',encoding='utf-8').read())
lua.execute('''
C_Item.LockItem=function(loc)local id=C_Item.GetItemGUID(loc);locked[id]=true end
items={ ["0:1"]={guid="Item-A",itemID=100,hyperlink="[Protected item]"},["0:2"]={guid="Item-B",itemID=101,hyperlink="[Busy item]"} }
locked={};Core.db.char.protectedItems={};Core.db.profile.itemProtection.enabled=true
Enum={BankType={Character=0,Account=2}}
local calls=0;local active=false;local fail=false;local relocate=false
local function native(...)
 calls=calls+1
 if active then assert(not locked["Item-A"],"our backpack lock blocked bank cleanup")
 else assert(locked["Item-A"],"lock released outside bank context") end
 assert(locked["Item-B"],"foreign lock released")
 if relocate then items["0:3"]=items["0:1"];items["0:1"]=nil end
 if fail then error("native sort failed") end
 return "bank-only",nil,42
end
C_Container.SortBank=native;C_Container.SortBankBags=native;C_Container.SortAccountBankBags=native
local bags=function()end;C_Container.SortBags=bags
P:OnEnable();drain();P:Protect("Item-A");locked["Item-B"]=true
local function pack(...)return {n=select("#",...),...}end
local result=pack(C_Container.SortBank(Enum.BankType.Character))
assert(result.n==3 and result[1]=="bank-only" and result[2]==nil and result[3]==42)
P.bankOpen=true;active=true
result=pack(C_Container.SortBank(Enum.BankType.Character))
assert(result.n==3 and locked["Item-A"] and P.owned["Item-A"] and P:Records()["Item-A"])
assert(C_Container.SortBags==bags,"bag sorting was patched")
C_Container.SortBank(Enum.BankType.Account);assert(locked["Item-A"])
C_Container.SortBankBags();assert(locked["Item-A"])
C_Container.SortAccountBankBags();assert(locked["Item-A"])
fail=true;local ok,err=pcall(C_Container.SortBank,Enum.BankType.Character)
assert(not ok and tostring(err):find("native sort failed",1,true) and locked["Item-A"] and not P.bankSortInProgress)
fail=false;relocate=true;C_Container.SortBank(Enum.BankType.Character)
assert(locked["Item-A"] and P.owned["Item-A"].slot==3,"relock followed stale slot")
relocate=false
local refresh=P.Refresh;P.Refresh=function()error("refresh fault")end
C_Container.SortBank(Enum.BankType.Character)
assert(locked["Item-A"] and not P.bankSortInProgress,"refresh failure stranded an unlocked item")
P.Refresh=refresh;drain()
active=false
combat=true;C_Container.SortBank(Enum.BankType.Character);assert(locked["Item-A"]);combat=false
local cursor=CursorHasItem;CursorHasItem=function()return true end
C_Container.SortBank(Enum.BankType.Character);assert(locked["Item-A"]);CursorHasItem=cursor
C_Container.SortBank(999);assert(locked["Item-A"],"unknown bank type suspended protection")
local other=function()end;C_Container.SortBankBags=other
P:OnDisable()
assert(C_Container.SortBank==native and C_Container.SortAccountBankBags==native and C_Container.SortBankBags==other,"hook teardown clobbered another addon")
''')
print('Bank-sort compatibility passed: bank-only scope, same-call relocking, foreign-lock preservation, bank types/legacy APIs, native errors, slot changes, refresh failure, combat/cursor bypass, return values and respectful hook teardown.')
