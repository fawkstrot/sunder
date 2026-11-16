exec(open('work/test_item_badges091.py',encoding='utf-8').read())
lua.execute('''
Core.db.profile.itemProtection.bagControls=true
Core.db.char.protectedItems={};P:Refresh()
local button=CreateFrame("Button");button:Show()
button.GetBagID=function()return 0 end;button.GetID=function()return 1 end
button.GetFrameStrata=function()return "MEDIUM" end;button.GetFrameLevel=function()return 1 end
button.IsMouseOver=function()return false end
P.badges={};P:AddBadge(button)
local badge=P.badges[button];badge.IsMouseOver=function()return false end
local id=P:ButtonItem(button).guid
local function click()
 badge:GetScript("OnMouseDown")(badge,"LeftButton")
 badge:GetScript("OnClick")(badge,"LeftButton")
end
click();assert(P:Records()[id] and P.owned[id] and locked[id],"badge click did not protect")
click();assert(not P:Records()[id] and not locked[id],"badge click did not unprotect")
badge:GetScript("OnMouseDown")(badge,"LeftButton")
button.GetID=function()return 2 end
badge:GetScript("OnClick")(badge,"LeftButton")
assert(not next(P:Records()),"pooled slot changed during click and locked the wrong copy")
button.GetID=function()return 1 end
local oldCursor=CursorHasItem;CursorHasItem=function()return true end
click();assert(not next(P:Records()),"changed protection while holding an item")
CursorHasItem=oldCursor
local oldCombat=InCombatLockdown;InCombatLockdown=function()return true end
click();assert(not next(P:Records()),"changed protection during combat")
InCombatLockdown=oldCombat
Core.db.profile.itemProtection.alwaysShowControls=true
P:UpdateBadges();assert(badge:IsShown(),"always-visible quick control missing")
Core.db.profile.itemProtection.alwaysShowControls=false
P:UpdateBadges();assert(not badge:IsShown(),"always-visible setting did not turn off")
''')
print('Click controls passed: protect, unprotect, changed-slot rejection, occupied cursor, combat and always-visible mode.')

lua.execute('''
-- Even with GUID lock APIs available, startup must not wrap bag use/pickup
-- or introduce a path that releases locks for a cursor operation.
local use=function()end;local pickup=function()end
C_Container.UseContainerItem=use;C_Container.PickupContainerItem=pickup
C_Item.LockItemByGUID=function(id)locked[id]=true end
P:OnDisable();P:OnEnable();drain()
assert(C_Container.UseContainerItem==use and C_Container.PickupContainerItem==pickup,"unsafe use/pickup adapter installed")
assert(not P.WithBagAction and not P.InstallBagActions,"cursor unlock exception returned")
''')
print('Strict-lock regression passed: GUID API availability never installs use/pickup unlock exceptions.')

lua.execute('''
local options=Core.features.itemProtection.buildOptions().args
assert(options.protect and options.saved and options.enabled,"established item locks removed")
assert(not options.previewMode and not options.previewHeader and not options.testItem and not options.test,"developer testing controls exposed")
-- Any saved experiment marker is inert: its protected GUID still acquires a strict lock.
Core.db.char.protectedItems["Item-A"]={itemID=100,mode="disposal-preview"}
items["0:1"]={guid="Item-A",itemID=100};P:Refresh()
assert(locked["Item-A"] and P.owned["Item-A"],"legacy experiment marker bypassed strict lock")
''')
