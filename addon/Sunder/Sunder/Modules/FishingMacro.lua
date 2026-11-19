local Core = unpack(select(2, ...))
local F = Core:GetModule("Fishing")
local macroName = "Sunder Fish"
local function gear()
  Core.db.char.fishingGear = Core.db.char.fishingGear or {}
  return Core.db.char.fishingGear
end
function F:EquipmentSetsAvailable()
  return C_EquipmentSet and C_EquipmentSet.GetEquipmentSetIDs and C_EquipmentSet.GetEquipmentSetInfo
    and (not C_EquipmentSet.CanUseEquipmentSets or C_EquipmentSet.CanUseEquipmentSets())
end
function F:FishingSetChoices(role)
  local values = {["none"]="Choose an equipment set"}
  if self:EquipmentSetsAvailable() then
    for _, id in ipairs(C_EquipmentSet.GetEquipmentSetIDs()) do
      local name = C_EquipmentSet.GetEquipmentSetInfo(id)
      if name then values[tostring(id)] = name end
    end
  else values.none="Equipment sets unavailable on this client" end
  local selected = gear()[role]
  if selected ~= nil and not values[tostring(selected)] then values[tostring(selected)]="Missing equipment set — choose another" end
  return values
end
function F:GetFishingSet(role) return gear()[role] ~= nil and tostring(gear()[role]) or "none" end
function F:SetFishingSet(role, value)
  if role ~= "fishingSet" and role ~= "normalSet" then return end
  if InCombatLockdown() then self:Notify("Change fishing equipment sets after combat."); return end
  local id = tonumber(value)
  if id ~= nil and (not self:EquipmentSetsAvailable() or not C_EquipmentSet.GetEquipmentSetInfo(id)) then
    self:Notify("That equipment set is no longer available."); return
  end
  gear()[role] = id; self.macroProblem=nil
  self:ScheduleFishingMacro()
end
function F:SelectedFishingSets()
  if not self:EquipmentSetsAvailable() then return nil, "Equipment sets are unavailable on this client. Manual Fishing Mode still works." end
  local g = gear()
  if g.fishingSet == nil or g.normalSet == nil then return nil, "Choose both Fishing equipment set and Normal equipment set below." end
  if g.fishingSet == g.normalSet then return nil, "Choose two different equipment sets." end
  local fishing = C_EquipmentSet.GetEquipmentSetInfo(g.fishingSet)
  local normal = C_EquipmentSet.GetEquipmentSetInfo(g.normalSet)
  if not fishing or not normal then return nil, "A selected equipment set was deleted. Choose its replacement below." end
  for _, name in ipairs({fishing, normal}) do
    if name:find("[%c;%[%]]") or name:match("^%s") or name:match("%s$") then
      return nil, "Rename the equipment set without brackets, semicolons or surrounding spaces so /equipset can use it safely."
    end
  end
  if fishing == normal then return nil, "Give the two equipment sets different names." end
  if C_EquipmentSet.GetItemIDs then
    local instant = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
    for _, entry in ipairs({{g.fishingSet,true,"Fishing"},{g.normalSet,false,"Normal"}}) do
      local ignored = C_EquipmentSet.GetIgnoredSlots and C_EquipmentSet.GetIgnoredSlots(entry[1])
      if ignored and ignored[16] then return nil, entry[3].." set ignores its main-hand slot. Include that slot in Equipment Manager." end
      local items = C_EquipmentSet.GetItemIDs(entry[1])
      local id = items and items[16]
      if not id or id <= 0 then return nil, entry[3].." set must include its main-hand item; do not ignore that slot." end
      if instant then
        local _, _, _, _, _, class, subclass = instant(id)
        if class == nil or subclass == nil then return nil, "Waiting for equipment-set item information. Try again shortly." end
        local pole = class == 2 and subclass == (Enum and Enum.ItemWeaponSubclass and Enum.ItemWeaponSubclass.Fishingpole or 20)
        if pole ~= entry[2] then return nil, entry[3]..(entry[2] and " set must contain a fishing pole." or " set must contain normal weapons, not a fishing pole.") end
      end
    end
  end
  return {fishing=fishing, normal=normal}
end
function F:FishingGearStatus()
  local sets, problem = self:SelectedFishingSets()
  if not sets then return problem end
  return "Fishing: "..sets.fishing.."\nNormal: "..sets.normal.."\nUpdate gear in Equipment Manager; Sunder follows the saved sets, including renames."..
    (self.macroProblem and ("\n"..self.macroProblem) or "")
end
function F:OpenFishingEquipmentManager()
  if InCombatLockdown() then self:Notify("Open Equipment Manager after combat."); return end
  if not self:EquipmentSetsAvailable() or not ToggleCharacter then
    self:Notify("Open your Character window and choose Equipment Manager to create or update your sets."); return
  end
  if not PaperDollFrame or not PaperDollFrame:IsShown() or (CharacterFrame and not CharacterFrame:IsShown()) then ToggleCharacter("PaperDollFrame") end
  if PaperDollFrame and PaperDollFrame.EquipmentManagerPane and GetPaperDollSideBarFrame and PaperDollFrame_SetSidebar then
    for i = 1, #(PAPERDOLL_SIDEBARS or {}) do
      if GetPaperDollSideBarFrame(i) == PaperDollFrame.EquipmentManagerPane then
        PaperDollFrame_SetSidebar(PaperDollSidebarTabs, i); return
      end
    end
  end
  self:Notify("Choose Equipment Manager in your Character window to create or update your sets.")
end
function F:BuildFishingMacro()
  local sets, problem = self:SelectedFishingSets()
  if not sets then return nil, problem end
  local pole = self:PoleEquipped()
  if pole == nil then return nil, "Waiting for main-hand item information before updating the macro." end
  local target = pole and sets.normal or sets.fishing
  local targetID = pole and gear().normalSet or gear().fishingSet
  local items = C_EquipmentSet.GetItemIDs and C_EquipmentSet.GetItemIDs(targetID)
  local itemID = items and items[16]
  local iconGetter = C_Item and C_Item.GetItemIconByID or GetItemIcon
  local icon = itemID and iconGetter and iconGetter(itemID)
  if not icon then
    local instant = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
    if itemID and instant then icon = select(5, instant(itemID)) end
  end
  icon = icon or select(2, C_EquipmentSet.GetEquipmentSetInfo(targetID)) or 136245
  local tooltip = itemID and itemID > 0 and ("#showtooltip item:"..itemID) or "#showtooltip"
  local body = tooltip.."\n/stopmacro [combat]\n/equipset "..target.."\n/sunder fish auto on"
  if #body > 255 then return nil, "Shorten the equipment-set names to fit the macro length limit." end
  return body, nil, icon
end
function F:FindFishingMacro()
  local base = MAX_ACCOUNT_MACROS or 120
  local accountCount, characterCount = GetNumMacros()
  -- The user designates this name as Sunder-managed. Reuse its current index
  -- even when its body was edited; prefer this character's copy if both exist.
  for index = base + 1, base + characterCount do
    if GetMacroInfo(index) == macroName then return index end
  end
  for index = 1, accountCount do
    if GetMacroInfo(index) == macroName then return index end
  end
end
function F:WriteFishingMacro(explicit)
  if self.disabled then return end
  if InCombatLockdown() then
    if explicit then self:Notify("Create or update the fishing macro after combat.") end
    return
  end
  if not (CreateMacro and EditMacro and GetMacroInfo and GetNumMacros) then
    if explicit then self:Notify("Macro creation is unavailable on this client.") end
    return
  end
  local body, problem, icon = self:BuildFishingMacro()
  icon = icon or 136245
  local setupProblem = problem
  -- Retire stale owned gear/name commands if selections become invalid. The
  -- harmless replacement opens setup; never leave a deleted set's name active.
  if not body then body = "/stopmacro [combat]\n/sunder fish options" end
  local index; index, problem = self:FindFishingMacro()
  if problem then self.macroProblem=problem; if explicit then self:Notify(problem) end; return end
  if not index and setupProblem then self.macroProblem=setupProblem; if explicit then self:Notify(setupProblem) end; return end
  local g = gear()
  local ok, result
  if index then
    local _, currentIcon, current = GetMacroInfo(index)
    if current == body and currentIcon == icon then ok=true; result=index
    else ok, result = pcall(EditMacro, index, macroName, icon, body) end
  else
    local _, count = GetNumMacros()
    if count >= (MAX_CHARACTER_MACROS or 18) then self:Notify("Your character macro slots are full. Free one slot, then try again."); return end
    ok, result = pcall(CreateMacro, macroName, icon, body, true)
  end
  if not ok or not result or select(3, GetMacroInfo(result)) ~= body then
    self.macroProblem="The client could not save the fishing macro. Check available character macro slots."
    if explicit then self:Notify(self.macroProblem) end
    return
  end
  g.macroBody=body; self.macroProblem=setupProblem
  if setupProblem then if explicit then self:Notify(setupProblem) end; return end
  if explicit then self:Notify("Sunder Fish macro ready. Drag it from /macro to your action bar; use a different key from "..Core.db.profile.fishing.key..". It follows your selected equipment sets and enables automatic pole detection when used.") end
end
function F:RefreshFishingOptions()
  local registry = Core.Libs and Core.Libs.AceConfigRegistry
  if registry and registry.NotifyChange then registry:NotifyChange("Sunder") end
end
function F:ScheduleFishingMacro()
  local g = gear()
  if self.macroScheduled or self.disabled or (not g.macroBody and (g.fishingSet == nil or g.normalSet == nil)) then return end
  self.macroScheduled=true
  -- Equipment events can fire inside a running macro. Update only on the next
  -- frame, after all its native equipment commands have finished executing.
  C_Timer.After(0, function()
    self.macroScheduled=nil
    if not self.disabled then self:WriteFishingMacro(false); self:RefreshFishingOptions() end
  end)
end
