local Core=unpack(select(2,...))
local P=Core:GetModule("ItemProtection")
Core.defaults.profile.itemProtection={enabled=true,tooltip=true}
_G.BINDING_HEADER_SUNDER="Sunder"
_G.BINDING_NAME_ROTBOT_FOREVER_PROTECT_ITEM="Sunder: protect item (legacy binding)"
_G.BINDING_NAME_SUNDER_PROTECT_ITEM="Protect / unprotect the bag item under the mouse"

local function accessible(value) return not _G.canaccessvalue or _G.canaccessvalue(value) end
local function guid(value) return accessible(value) and type(value)=="string" and value~="" and not value:find("|",1,true) end
local function cfg() return Core.db.profile.itemProtection end
function P:Records()
  Core.db.char.protectedItems=Core.db.char.protectedItems or {}
  return Core.db.char.protectedItems
end
function P:Available()
  return C_Item and C_Item.GetItemGUID and C_Item.LockItem and C_Item.UnlockItem and C_Item.IsLocked
    and ItemLocation and ItemLocation.CreateFromBagAndSlot and C_Container and C_Container.GetContainerItemInfo and C_Container.GetContainerNumSlots
end
function P:Notify(text)
  Core:GetModule("Config"):Print(text)
end
function P:Slot(bag,slot)
  if not self:Available() or type(bag)~="number" or type(slot)~="number" or bag<0 or bag>5 or slot<1 then return end
  local info=C_Container.GetContainerItemInfo(bag,slot)
  if not accessible(info) or type(info)~="table" or not accessible(info.itemID) or not info.itemID then return end
  local location=ItemLocation:CreateFromBagAndSlot(bag,slot)
  local ok,id=pcall(C_Item.GetItemGUID,location)
  if not ok or not guid(id) then return end
  return {guid=id,bag=bag,slot=slot,location=location,info=info}
end
function P:Inventory()
  local out={}
  if not self:Available() then return out end
  for bag=0,5 do
    local count=C_Container.GetContainerNumSlots(bag) or 0
    for slot=1,count do
      local ok,item=pcall(self.Slot,self,bag,slot)
      if ok and item then out[item.guid]=item end
    end
  end
  return out
end
function P:IsLocked(location)
  local ok,locked=pcall(C_Item.IsLocked,location)
  return ok and accessible(locked) and locked==true
end
function P:Release(id)
  local owned=self.owned and self.owned[id]
  if not owned then return true end
  -- Never unlock an unrelated item that has since occupied this slot.
  local ok,current=pcall(C_Item.GetItemGUID,owned.location)
  if ok and accessible(current) and current==id then
    local released,err=pcall(C_Item.UnlockItem,owned.location)
    if not released then self.errors[id]="Could not release native lock: "..tostring(err);return false end
  elseif C_Item.UnlockItemByGUID then
    local released,err=pcall(C_Item.UnlockItemByGUID,id)
    if not released then self.errors[id]="Could not release native lock: "..tostring(err);return false end
  end
  self.owned[id]=nil;self.errors[id]=nil
  return true
end
function P:Refresh()
  if not Core.db then return end
  self.owned=self.owned or {};self.errors=self.errors or {};self.status=self.status or {}
  if self.refreshing then return end
  self.refreshing=true
  local records=self:Records()
  if not cfg().enabled or not self:Available() then
    for id in pairs(self.owned) do self:Release(id) end
    self.refreshing=nil;return
  end
  local inventory=self:Inventory();self.inventory=inventory
  for id in pairs(self.owned) do if not records[id] then self:Release(id) end end
  for id,record in pairs(records) do
    local item=inventory[id]
    if item then
      if accessible(item.info.hyperlink) and type(item.info.hyperlink)=="string" then record.link=item.info.hyperlink end
      local locked=self:IsLocked(item.location)
      if self.owned[id] then
        self.owned[id]=item
        if not locked then
          local ok,err=pcall(C_Item.LockItem,item.location)
          if not ok then self.errors[id]=tostring(err) end
        end
      elseif not locked then
        local ok,err=pcall(C_Item.LockItem,item.location)
        if ok and self:IsLocked(item.location) then self.owned[id]=item;self.errors[id]=nil
        else self.errors[id]=ok and "Client did not apply the native lock." or tostring(err) end
      end
      self.status[id]=self.owned[id] and self:IsLocked(item.location) and "Native lock active" or locked and "Item busy; waiting for our lock" or "NOT LOCKED"
    else
      self.status[id]="Not currently in your bags"
    end
  end
  self.refreshing=nil
end
function P:Schedule()
  if self.scheduled or self.shuttingDown then return end
  self.scheduled=true
  C_Timer.After(.15,function()
    self.scheduled=nil
    local ok,err=pcall(self.Refresh,self)
    if not ok then self.lastError=tostring(err) end
    self:DiscoverButtons();self:UpdateBadges()
  end)
end
function P:Protect(id)
  if not cfg().enabled then return self:Notify("Enable Item Protection first.") end
  if not self:Available() then return self:Notify("This client does not expose the required native item-lock APIs.") end
  if InCombatLockdown() then return self:Notify("Change item protection after combat.") end
  if not guid(id) then return end
  local item=self:Inventory()[id]
  if not item then return self:Notify("That item is no longer in your bags. Select it again.") end
  local record={itemID=item.info.itemID}
  if accessible(item.info.hyperlink) and type(item.info.hyperlink)=="string" then record.link=item.info.hyperlink end
  self:Records()[id]=record
  self:Refresh()
  if self.owned[id] then self:Notify("Native lock applied. Unprotect this copy before moving or using it.")
  else self:Notify("Item saved, but not locked yet: "..(self.errors[id] or self.status[id] or "item busy")) end
end
function P:Unprotect(id)
  if InCombatLockdown() then return self:Notify("Change item protection after combat.") end
  self.errors=self.errors or {};self.owned=self.owned or {}
  if not self:Release(id) then return self:Notify("Native lock could not be released. Protection remains saved.") end
  self:Records()[id]=nil
  if self.status then self.status[id]=nil end
  self:Notify("Item protection removed.")
end
function P:Toggle(id)
  if self:Records()[id] then self:Unprotect(id) else self:Protect(id) end
end
function P:Hovered()
  local hover=self.hover
  if not hover or not GameTooltip or not GameTooltip:IsShown() then return end
  local owner=GameTooltip:GetOwner()
  if not owner or not owner.IsMouseOver or not owner:IsMouseOver() then return end
  local item=self:Slot(hover.bag,hover.slot)
  if item and item.guid==hover.guid then return item.guid end
end
function P:ToggleHovered()
  local id=self:Hovered()
  if not id then return self:Notify("Hover a bag item, then use the Sunder item-protection key binding. You can also select an item in /sunder items.") end
  self:Toggle(id)
end
_G.SunderToggleHoveredItem=function() P:ToggleHovered() end
function P:OnTooltip(tooltip,bag,slot)
  if tooltip~=GameTooltip then return end
  local owner=tooltip:GetOwner()
  if not InCombatLockdown() and owner and self:IsBagButton(owner) and not (self.badges and self.badges[owner]) then
    self.badges=self.badges or {};self:AddBadge(owner)
  end
  local ok,item=pcall(self.Slot,self,bag,slot)
  self.hover=ok and item and {bag=bag,slot=slot,guid=item.guid} or nil
  if not ok or not item or not cfg().tooltip or not self:Records()[item.guid] then return end
  tooltip:AddLine(" ")
  if self.pickupChecks and self.pickupChecks[item.guid]==false then
    tooltip:AddLine("Sunder: Pickup bypassed this native lock",1,.35,.2)
    tooltip:AddLine("Do not rely on this lock for disposal protection.",1,.6,.4)
  elseif cfg().enabled and self.owned[item.guid] and self:IsLocked(item.location) then
    tooltip:AddLine("Sunder: Native item lock active",1,.8,.35)
    tooltip:AddLine("Unprotect before moving or using this copy.",.72,.76,.82)
  else tooltip:AddLine("Sunder: Saved for protection — lock not active",1,.45,.25) end
  tooltip:Show()
end
function P:Candidates()
  local values={__choose="Choose an item…"}
  for id,item in pairs(self:Inventory()) do
    if not self:Records()[id] then
      local name=accessible(item.info.hyperlink) and item.info.hyperlink or ("Item "..tostring(item.info.itemID))
      values[id]=name.."  (bag "..item.bag..", slot "..item.slot..")"
    end
  end
  return values
end
function P:SavedValues()
  local values={}
  for id,record in pairs(self:Records()) do
    local item=self.inventory and self.inventory[id]
    local where=item and ("  (bag "..item.bag..", slot "..item.slot..")") or ""
    local state=self.pickupChecks and self.pickupChecks[id]==false and "PICKUP CHECK FAILED" or cfg().enabled and (self.status and self.status[id] or "Checking native lock") or "Protection disabled"
    values[id]=(record.link or ("Item "..tostring(record.itemID)))..where.." — "..state
  end
  return values
end
function P:TestPickup()
  if not CursorHasItem or not ClearCursor or not C_Container or not C_Container.PickupContainerItem then return self:Notify("This client cannot run the pickup check.") end
  if InCombatLockdown() or not self.selectedTest then return end
  if CursorHasItem and CursorHasItem() then return self:Notify("Clear your cursor first.") end
  self:Refresh()
  local item=self.inventory and self.inventory[self.selectedTest]
  if not item or not self.owned[item.guid] or not self:IsLocked(item.location) then return self:Notify("Select a currently native-locked item first.") end
  -- No sale, trade or destruction. ClearCursor returns a picked-up item to its original slot.
  local ok,err=pcall(C_Container.PickupContainerItem,item.bag,item.slot)
  self.pickupChecks=self.pickupChecks or {}
  if CursorHasItem and CursorHasItem() then
    self.pickupChecks[item.guid]=false
    local returned=pcall(ClearCursor)
    self.pickupCheck=returned and not CursorHasItem() and "FAILED: the client allowed pickup despite the native lock. Do not rely on it for disposal protection." or "FAILED: pickup succeeded. The item is still on your cursor; return it to its bag slot."
  elseif ok then self.pickupChecks[item.guid]=true;self.pickupCheck="PASS: ordinary bag pickup was blocked. Selling, trading and destroying still require separate live verification."
  else self.pickupCheck="INCONCLUSIVE: "..tostring(err) end
  self:Notify(self.pickupCheck)
end
-- Independent controls: never replace or modify a secure bag button's click scripts.
function P:IsBagButton(button)
  if not button or button.IsForbidden and button:IsForbidden() or not button.GetID then return false end
  if type(button.GetBagID)=="function" then return true end
  -- Forever/Ellesmere also uses legacy container templates: bag ID on the parent.
  if not button.IsObjectType or not button:IsObjectType("ItemButton") then return false end
  local parent=button:GetParent()
  for i=1,5 do
    if not parent then break end
    local name=parent:GetName()
    if parent==_G.EUI_Bags or parent==_G.EUI_BagsReagent or name and (name:match("^ContainerFrame") or name=="EUI_MainBagFrame" or name=="EUI_ReagentBagFrame") then return true end
    parent=parent:GetParent()
  end
  return false
end
function P:ButtonItem(button)
  if not button or not button.GetID then return end
  local ok,bag
  if type(button.GetBagID)=="function" then ok,bag=pcall(button.GetBagID,button)
  else
    local parent=button:GetParent()
    if parent and parent.GetID then ok,bag=pcall(parent.GetID,parent) end
  end
  local good,slot=pcall(button.GetID,button)
  if ok and good then return self:Slot(bag,slot) end
end
function P:DiscoverButtons()
  if not EnumerateFrames or InCombatLockdown() then return end
  self.badges=self.badges or {}
  -- Collect first: creating new frames while enumerating can invalidate traversal.
  local pending={};local button=EnumerateFrames()
  while button do
    local ok,isBag=pcall(self.IsBagButton,self,button)
    if ok and isBag and not self.badges[button] then pending[#pending+1]=button end
    button=EnumerateFrames(button)
  end
  for _,candidate in ipairs(pending) do
    local ok,err=pcall(self.AddBadge,self,candidate)
    if not ok then self.lastError="Bag control: "..tostring(err) end
  end
end
function P:AddBadge(itemButton)
  local badge=CreateFrame("Button",nil,itemButton:GetParent())
  badge:SetSize(16,16)
  badge:SetPoint("TOPRIGHT",itemButton,"TOPRIGHT",-1,-1)
  badge:EnableMouse(true)
  if badge.SetPropagateMouseClicks then badge:SetPropagateMouseClicks(false) end
  badge:RegisterForClicks("LeftButtonUp")
  local icon=badge:CreateTexture(nil,"OVERLAY")
  icon:SetAllPoints();badge.icon=icon
  badge:SetScript("OnMouseDown",function(_,mouseButton)
    if mouseButton~="LeftButton" then badge.pressedGUID=nil;return end
    local item=self:ButtonItem(itemButton);badge.pressedGUID=item and item.guid
  end)
  badge:SetScript("OnClick",function(_,mouseButton)
    if mouseButton~="LeftButton" then return end
    local item=self:ButtonItem(itemButton)
    if item and item.guid==badge.pressedGUID then
      if CursorHasItem and CursorHasItem() then self:Notify("Clear your cursor before changing item protection.")
      else self:Toggle(item.guid) end
    end
    badge.pressedGUID=nil
    GameTooltip:Hide();self:UpdateBadges()
  end)
  badge:SetScript("OnEnter",function()
    local item=self:ButtonItem(itemButton)
    if not item then return end
    GameTooltip:SetOwner(badge,"ANCHOR_RIGHT")
    local saved=self:Records()[item.guid]
    GameTooltip:AddLine(saved and "Unprotect item" or "Protect item",1,.82,.4)
    GameTooltip:AddLine(saved and "Click to remove this copy's lock." or "Click to lock this copy in your bags.",.8,.82,.86)
    if saved and not (self.owned and self.owned[item.guid] and self:IsLocked(item.location)) then
      GameTooltip:AddLine("Protection saved; native lock is not active.",1,.45,.2)
    end
    GameTooltip:Show()
  end)
  badge:SetScript("OnLeave",function()GameTooltip:Hide()end)
  badge:Hide();self.badges[itemButton]=badge
end
function P:UpdateBadges()
  for button,badge in pairs(self.badges or {}) do
    local item=(button.IsVisible and button:IsVisible() or not button.IsVisible and button:IsShown()) and self:ButtonItem(button)
    local saved=item and self:Records()[item.guid]
    local visible=cfg().enabled and not self.shuttingDown and not InCombatLockdown() and item
      and (saved or cfg().bagControls~=false and (cfg().alwaysShowControls or button:IsMouseOver() or badge:IsMouseOver()))
    if visible then
      local active=saved and self.owned and self.owned[item.guid] and self:IsLocked(item.location)
      badge.icon:SetTexture("Interface\\AddOns\\Sunder\\Media\\"..(saved and "ItemLocked" or "ItemUnlocked"))
      badge.icon:SetVertexColor(1,active and .82 or saved and .42 or .85,active and .32 or saved and .15 or .9)
      badge:SetFrameStrata(button:GetFrameStrata())
      badge:SetFrameLevel(button:GetFrameLevel()+30)
      badge:Show()
    else badge:Hide() end
  end
end
-- Native bank cleanup can reject an unrelated client-side backpack lock.
-- Keep this exception synchronous and bank-only; never suspend locks for bag sort,
-- vendor, trade, pickup, or for the duration of an asynchronous operation.
function P:WithBankSortLocks(sort,...)
  local bankVisible=self.bankOpen or BankFrame and BankFrame:IsShown() or _G.EUI_Bank and _G.EUI_Bank:IsShown()
  if self.bankSortInProgress or self.refreshing or self.shuttingDown or not cfg().enabled or not self:Available()
    or not bankVisible or InCombatLockdown() or CursorHasItem and CursorHasItem() then return sort(...) end
  local inventory=self:Inventory()
  local release={}
  for id in pairs(self.owned or {}) do
    local item=inventory[id]
    if item and self:Records()[id] and self:IsLocked(item.location) then release[#release+1]=item end
  end
  if #release==0 then return sort(...) end
  self.bankSortInProgress=true
  local function pack(...)return {n=select("#",...),...}end
  local args=pack(...)
  local result=pack(pcall(function()
    for _,item in ipairs(release) do
      -- Refresh the owned location by GUID; stale slot numbers never identify a lock.
      self.owned[item.guid]=item
      if not self:Release(item.guid) or self:IsLocked(item.location) then
        self:Notify("Bank sort paused: an item lock could not be released.")
        return
      end
    end
    return sort(unpack(args,1,args.n))
  end))
  -- Finally: restore saved protection before returning to the UI, even if sort throws.
  -- Restore directly first, so a failure in the broader refresh cannot strand a lock.
  for _,item in ipairs(release) do
    if cfg().enabled and not self.shuttingDown and self:Records()[item.guid] then
      local ok,current=pcall(self.Slot,self,item.bag,item.slot)
      if not ok or not current or current.guid~=item.guid then
        local scanned,all=pcall(self.Inventory,self);current=scanned and all[item.guid] or nil
      end
      if current and not self:IsLocked(current.location) then
        local locked=pcall(C_Item.LockItem,current.location)
        if locked and self:IsLocked(current.location) then self.owned[item.guid]=current end
      end
    end
  end
  local restored,err=pcall(self.Refresh,self)
  self.bankSortInProgress=nil
  if not restored then
    self.refreshing=nil
    self.lastError="Restoring item locks after bank sort: "..tostring(err)
    self:Notify(self.lastError);self:Schedule()
  else
    for _,item in ipairs(release) do
      if self:Records()[item.guid] and not self.owned[item.guid] then
        self:Notify("An item could not be relocked after bank sort. Check Item Protection status.");break
      end
    end
  end
  if not result[1] then error(result[2],0) end
  return unpack(result,2,result.n)
end
function P:InstallBankSortCompatibility()
  self.bankSortHooks=self.bankSortHooks or {}
  for _,name in ipairs({"SortBank","SortBankBags","SortAccountBankBags"}) do
    if not self.bankSortHooks[name] and C_Container and type(C_Container[name])=="function" then
      local original=C_Container[name]
      local wrapper=function(...)
        -- Unknown/secret bank-type arguments retain the native path without unlocking.
        if name=="SortBank" then
          local kind=select(1,...);local types=Enum and Enum.BankType
          if not accessible(kind) or type(kind)~="number" or not types or kind~=types.Character and kind~=types.Account then return original(...) end
        end
        return self:WithBankSortLocks(original,...)
      end
      self.bankSortHooks[name]={original=original,wrapper=wrapper}
      C_Container[name]=wrapper
    end
  end
end
function P:RemoveBankSortCompatibility()
  for name,hook in pairs(self.bankSortHooks or {}) do
    if C_Container and C_Container[name]==hook.wrapper then C_Container[name]=hook.original end
  end
  self.bankSortHooks=nil;self.bankOpen=nil
end
function P:OnEnable()
  self.shuttingDown=nil;self:InstallBankSortCompatibility();self.owned={};self.errors={};self.status={};self.pickupChecks={}
  local events=CreateFrame("Frame");self.events=events
  for _,event in ipairs({"BAG_UPDATE_DELAYED","ITEM_LOCK_CHANGED","PLAYER_ENTERING_WORLD","PLAYER_REGEN_ENABLED","MERCHANT_SHOW","TRADE_SHOW","ADDON_LOADED","BANKFRAME_OPENED","BANKFRAME_CLOSED"}) do events:RegisterEvent(event) end
  events:RegisterEvent("PLAYER_LOGOUT")
  events:SetScript("OnEvent",function(_,event)
    if event=="BANKFRAME_OPENED" then self.bankOpen=true
    elseif event=="BANKFRAME_CLOSED" then self.bankOpen=nil
    elseif event=="PLAYER_LOGOUT" then
      self.shuttingDown=true
      for id in pairs(self.owned) do self:Release(id) end
    else self:Schedule();self:DiscoverButtons() end
  end)
  if GameTooltip and GameTooltip.SetBagItem then hooksecurefunc(GameTooltip,"SetBagItem",function(tooltip,bag,slot) self:OnTooltip(tooltip,bag,slot) end) end
  Core.db.RegisterCallback(self,"OnDatabaseShutdown",function() for id in pairs(self.owned) do self:Release(id) end end)
  for _,event in ipairs({"OnProfileChanged","OnProfileCopied","OnProfileReset"}) do
    Core.db.RegisterCallback(self,event,function() self:Refresh() end)
  end
  if not self.bagOpenHooks then
    self.bagOpenHooks=true
    for _,name in ipairs({"OpenAllBags","ToggleAllBags","ToggleBag","OpenBag"}) do
      if type(_G[name])=="function" then hooksecurefunc(name,function()self:Schedule()end) end
    end
  end
  if not self.badgeDriver then
    self.badgeDriver=CreateFrame("Frame")
    local elapsed=0
    self.badgeDriver:SetScript("OnUpdate",function(_,dt)
      elapsed=elapsed+dt
      if elapsed<.1 then return end
      elapsed=0;local ok,err=pcall(self.UpdateBadges,self);if not ok then self.lastError="Bag control: "..tostring(err) end
    end)
  end
  self.badgeDriver:Show()
  self:Schedule()
end
function P:OnDisable()
  self.shuttingDown=true
  self:RemoveBankSortCompatibility()
  if self.badgeDriver then self.badgeDriver:Hide() end
  for _,badge in pairs(self.badges or {}) do badge:Hide() end
  if self.events then self.events:UnregisterAllEvents() end
  for id in pairs(self.owned or {}) do self:Release(id) end
end
Core:RegisterFeature("itemProtection",{name="Item Protection",order=30,resetOptions=function()
  Core.db.profile.itemProtection={enabled=true,tooltip=true};P:Refresh()
end,buildOptions=function()
  return {type="group",args={
    overview={type="description",order=1,name="Strict native item locking, independent of your bag addon. Protects the selected physical copy, not every item of that type. Unprotect before moving, sorting that item, equipping or using it. Ellesmere pins remain separate. Other addons that honor the native item-lock state can recognize these locks."},
    verification={type="description",order=2,name="Compatibility status: native lock application is checked per item. Ordinary pickup can be tested below. Manual sale, automated sale, trade and destruction have NOT yet been verified on this Forever client; this release must not be treated as a proven guarantee against disposal."},
    enabled={type="toggle",name="Enable native item locks",order=3,get=function()return cfg().enabled end,set=function(_,value)
      if InCombatLockdown() then P:Notify("Change item protection after combat.");return end
      cfg().enabled=value;P:Refresh()
    end},
    status={type="description",order=4,name=function()
      if not P:Available() then return "Unavailable: required native APIs are missing." end
      return P.lastError and ("Last error: "..P.lastError) or "Native APIs detected. Assign the Sunder item-protection action in WoW Key Bindings, then hover a bag item and press that key. You can also click the small padlock at the upper-right of a bag item to protect or unprotect it. /sunder items opens this page."
    end},
    bagStatus={type="description",order=4.5,name=function()
      local count=0;for _ in pairs(P.badges or {}) do count=count+1 end
      return "Bag controls: "..count.." item buttons detected. Hover an item, then click the small padlock in its upper-right corner. Controls are unavailable during combat."
    end},
    protect={type="select",name="Protect an item in your bags",order=5,values=function()return P:Candidates() end,get=function()return "__choose" end,set=function(_,id)if id~="__choose" then P:Protect(id)end end,disabled=function()return not cfg().enabled or not P:Available()end},
    saved={type="multiselect",name="Saved items — uncheck to unprotect",order=6,values=function()return P:SavedValues()end,get=function(_,id)return not not P:Records()[id]end,set=function(_,id,value)if not value then P:Unprotect(id)end end},
    tooltip={type="toggle",name="Show protection status in item tooltips",order=7,get=function()return cfg().tooltip end,set=function(_,value)cfg().tooltip=value end},
    bagControls={type="toggle",name="Show quick-lock controls when hovering bag items",order=7.5,get=function()return cfg().bagControls~=false end,set=function(_,value)cfg().bagControls=value end},
    alwaysShowControls={type="toggle",name="Always show bag lock controls",desc="Show a clickable open padlock on every bag item, even without hovering. Protected items always show their badge.",order=7.6,get=function()return not not cfg().alwaysShowControls end,set=function(_,value)cfg().alwaysShowControls=value end,disabled=function()return cfg().bagControls==false end},
    testHeader={type="header",name="Non-destructive compatibility check",order=8},
    testItem={type="select",name="Locked item to check",order=9,values=function()local values=P:SavedValues();values.__choose="Choose a locked item…";return values end,get=function()return P.selectedTest or "__choose" end,set=function(_,id)P.selectedTest=id~="__choose" and id or nil end},
    test={type="execute",name="Check ordinary pickup blocking",order=10,confirm="This attempts an ordinary pickup of the selected locked item. If pickup succeeds, it immediately returns the item. It does not sell, trade or destroy anything. Continue?",func=function()P:TestPickup()end},
    result={type="description",order=11,name=function()return P.pickupCheck or "No pickup check run this session. Use an expendable test item."end},
  }}
end})
