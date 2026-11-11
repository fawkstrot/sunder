exec(open('work/test_item_protection090.py',encoding='utf-8').read())
lua.execute('''
C_Item.LockItem=function(loc)locked[C_Item.GetItemGUID(loc)]=true end
P.shuttingDown=nil;Core.db.profile.itemProtection.enabled=true
Core.db.char.protectedItems={};P:Refresh()
local button=CreateFrame("Button");button:Show()
button.GetBagID=function()return 0 end
button.GetID=function()return 1 end
button.GetFrameStrata=function()return "MEDIUM" end
button.GetFrameLevel=function()return 10 end
local hover=true
button.IsMouseOver=function()return hover end
P.badges={};P:AddBadge(button)
local badge=P.badges[button]
badge.IsMouseOver=function()return false end
P:UpdateBadges();assert(badge:IsShown(),"hover quick control missing")
hover=false;P:UpdateBadges();assert(not badge:IsShown(),"unprotected badge stayed visible")
local id=P:ButtonItem(button).guid
P:Protect(id);P:UpdateBadges();assert(badge:IsShown(),"protected badge missing")
local original=button.GetID;button.GetID=function()return 4 end
P:UpdateBadges();assert(not badge:IsShown(),"badge stale after slot reuse")
button.GetID=original
P:Unprotect(id);P:UpdateBadges();assert(not badge:IsShown(),"badge stale after unprotect")
Core.db.profile.itemProtection.bagControls=false;hover=true
P:UpdateBadges();assert(not badge:IsShown(),"hover controls setting ignored")
''')
print('Bag badge checks passed: hover visibility, protected visibility, slot reuse, unprotect and quick-control setting.')

lua.execute('''
local parent=CreateFrame("Frame");EUI_Bags=parent
parent.GetID=function()return 0 end
parent.GetName=function()return "EUI_MainBagFrame" end
local legacy=CreateFrame("ItemButton",nil,parent)
legacy.GetBagID=nil
legacy.GetID=function()return 1 end
legacy.GetParent=function()return parent end
legacy.IsObjectType=function(_,kind)return kind=="ItemButton" end
assert(P:IsBagButton(legacy),"legacy Ellesmere button was skipped")
assert(P:ButtonItem(legacy).guid==items["0:1"].guid,"parent bag ID not resolved")
local forbidden={IsForbidden=function()return true end}
assert(not P:IsBagButton(forbidden),"forbidden frame inspected")
legacy:Show();legacy.IsVisible=function()return false end
P:AddBadge(legacy);P:Protect(P:ButtonItem(legacy).guid);P:UpdateBadges()
assert(not P.badges[legacy]:IsShown(),"hidden ancestor left a ghost badge")
''')
print('Legacy template and hidden-parent checks passed.')
