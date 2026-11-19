local Core = unpack(select(2, ...))
local F = Core:GetModule("Fishing")
local fishingIDs = {7620,7731,7732,18248,33095,51294,88868,110410,131474,131490,131476}
local interactCVars = {SoftTargetInteract="3", SoftTargetInteractArc="2", SoftTargetInteractRange="60"}
local function cfg() return Core.db.profile.fishing end
local function loaded(name)
  local fn = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
  return fn and fn(name)
end
function F:Notify(text) Core:GetModule("Config"):Print(text) end
function F:FishingSpell()
  local known = C_SpellBook and C_SpellBook.IsSpellKnown or IsSpellKnown
  for _, id in ipairs(fishingIDs) do if known and known(id) then return id end end
end
function F:IsFishing()
  local name, _, _, _, _, _, _, id = UnitChannelInfo("player")
  if not name then return false end
  for _, candidate in ipairs(fishingIDs) do if id == candidate then return true end end
  local localized = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(7620)
    or GetSpellInfo and GetSpellInfo(7620)
  return localized ~= nil and name == localized
end
function F:PoleEquipped()
  local item = GetInventoryItemID("player", 16)
  if not item then return false end
  local instant = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
  if not instant then return nil end
  local _, _, _, _, _, class, subclass = instant(item)
  if class == nil or subclass == nil then return nil end
  local pole = Enum and Enum.ItemWeaponSubclass and Enum.ItemWeaponSubclass.Fishingpole or 20
  return class == 2 and subclass == pole
end
function F:Unavailable()
  if loaded("BetterFishing") then return "Disable Better Fishing in AddOns and reload before enabling Sunder Fishing." end
  if not (RegisterStateDriver and SetOverrideBindingClick and SetOverrideBinding and ClearOverrideBindings
    and GetCVar and SetCVar and GetCVar("SoftTargetInteract") ~= nil
    and GetCVar("SoftTargetInteractArc") ~= nil and GetCVar("SoftTargetInteractRange") ~= nil) then
    return "Fishing requires secure state drivers and soft interaction; this client is not supported."
  end
  if not self:FishingSpell() then return "Learn Fishing before enabling Fishing Mode." end
end
function F:RestoreCVars()
  if InCombatLockdown() then return end
  for name, old in pairs(self.cvars or {}) do
    -- Do not overwrite a user's or another addon's later change.
    if GetCVar(name) == interactCVars[name] then SetCVar(name, old) end
  end
  self.cvars = nil
end
function F:ApplyCVars()
  self.cvars = self.cvars or {}
  for name, value in pairs(interactCVars) do
    if self.cvars[name] == nil then self.cvars[name] = GetCVar(name) end
    SetCVar(name, value)
  end
end
function F:EnsureButton()
  if self.owner then return end
  self.owner = CreateFrame("Frame", "SunderFishingFrame", UIParent, "SecureHandlerStateTemplate")
  -- Installed out of combat. The restricted handler clears this exact owner's
  -- overrides in combat; insecure PLAYER_REGEN_DISABLED code must never do so.
  self.owner:SetAttribute("_onstate-combat", [[
    if newstate == "combat" then self:ClearBindings() end
  ]])
  RegisterStateDriver(self.owner, "combat", "[combat] combat; peace")
  self.button = CreateFrame("Button", "SunderFishingButton", UIParent, "SecureActionButtonTemplate")
  self.button:RegisterForClicks("AnyDown", "AnyUp")
  self.button:SetAttribute("type", "spell")
end
function F:Refresh()
  if InCombatLockdown() then return end
  if self.owner then ClearOverrideBindings(self.owner) end
  self.applied = nil
  self:RestoreCVars()
  self.problem = self.wanted and self:Unavailable() or nil
  if not self.wanted or self.problem or self.disabled then return end
  self:EnsureButton()
  self.button:SetAttribute("spell", self:FishingSpell())
  self.button:SetAttribute("useOnKeyDown", GetCVar("ActionButtonUseKeyDown") == "1")
  if self:IsFishing() then
    self:ApplyCVars()
    SetOverrideBinding(self.owner, true, cfg().key, "INTERACTTARGET")
    self.applied = "Interact"
  else
    SetOverrideBindingClick(self.owner, true, cfg().key, "SunderFishingButton", "LeftButton")
    self.applied = "Cast"
  end
end
function F:SetMode(value)
  self.wanted = not not value
  self:Refresh()
end
function F:Status()
  local auto = cfg().autoPole and "Automatic pole detection on. " or "Automatic pole detection off. "
  if InCombatLockdown() then return auto.."Fishing suspended in combat; requested mode: "..(self.wanted and "on." or "off.") end
  if self.problem then return auto..self.problem end
  if self.applied then return auto.."Fishing Mode on: "..cfg().key.." — "..self.applied.."." end
  if cfg().autoPole then
    local pole = self:PoleEquipped()
    if pole == nil then return auto.."Waiting for main-hand item information." end
    if not pole then return auto.."Fishing Mode off: equip a fishing pole in your main hand." end
    return auto.."Fishing Mode manually off; use /sunder fish on or re-equip your pole."
  end
  return auto.."Fishing Mode off."
end
function F:SetKey(key)
  key = tostring(key or ""):upper():gsub("%s+", "")
  -- Keep chat/escape and primary mouse input available. Native binding tokens,
  -- modifiers and punctuation keys are accepted; reject commands/macro text.
  local base = key
  for _ = 1, 3 do base = base:gsub("^ALT%-", ""):gsub("^CTRL%-", ""):gsub("^SHIFT%-", "") end
  local named = {SPACE=true,TAB=true,BACKSPACE=true,INSERT=true,DELETE=true,HOME=true,END=true,
    PAGEUP=true,PAGEDOWN=true,UP=true,DOWN=true,LEFT=true,RIGHT=true,MOUSEWHEELUP=true,MOUSEWHEELDOWN=true,
    NUMPADPLUS=true,NUMPADMINUS=true,NUMPADMULTIPLY=true,NUMPADDIVIDE=true,NUMPADDECIMAL=true}
  local fkey = tonumber(base:match("^F(%d+)$"))
  local mouse = tonumber(base:match("^BUTTON(%d+)$"))
  if #key > 40 or not (named[base] or (#base == 1 and base:match("[%w%p]"))
    or base:match("^NUMPAD%d$") or (fkey and fkey >= 1 and fkey <= 24)
    or (mouse and mouse >= 3 and mouse <= 31)) then return false end
  cfg().key = key; self:Refresh(); return true
end
function F:EquipmentChanged()
  if not cfg().autoPole then self.pendingPole = nil; return end
  local pole = self:PoleEquipped()
  self.pendingPole = pole == nil
  if pole ~= nil then self:SetMode(pole) end
end
function F:LootReady()
  -- LOOT_READY precedes the ordinary loot window. Only the native fishing-loot
  -- flag authorizes collection; never use a timer to guess the loot source.
  if not self.wanted or self.disabled or cfg().autoLoot == false or loaded("BetterFishing")
    or InCombatLockdown() or not (IsFishingLoot and GetNumLootItems and LootSlot)
    or not IsFishingLoot() then return end
  for slot = math.min(GetNumLootItems(), 50), 1, -1 do LootSlot(slot) end
end
function F:Command(input)
  input = (input or "toggle"):lower():match("^%s*(.-)%s*$")
  if input == "save pole" or input == "save weapons" then self:Notify("Choose your two equipment sets in /sunder fish options; saving individual gear has been replaced."); return
  elseif input == "equipment" then self:OpenFishingEquipmentManager(); return
  elseif input == "macro" then self:WriteFishingMacro(true); return
  elseif input == "options" then Core:GetModule("Config"):OpenSettings("fishing"); return
  elseif input == "toggle" or input == "" then self:SetMode(not self.wanted)
  elseif input == "on" then self:SetMode(true)
  elseif input == "off" then self:SetMode(false)
  elseif input:match("^key%s+") then
    if not self:SetKey(input:match("^key%s+(.+)$")) then self:Notify("Use a key such as SPACE, F8 or SHIFT-F. Enter, Escape and primary mouse buttons are reserved."); return end
  elseif input == "auto on" or input == "auto off" then
    cfg().autoPole = input == "auto on"; self:EquipmentChanged()
  elseif input ~= "status" then
    self:Notify("/sunder fish [toggle|on|off|status|options|key SPACE|auto on|auto off|equipment|macro]"); return
  end
  self:Notify(self:Status())
end
function F:OnEvent(event, unit)
  if event == "EQUIPMENT_SETS_CHANGED" and self.RefreshFishingOptions then self:RefreshFishingOptions() end
  if self.ScheduleFishingMacro and (event == "PLAYER_EQUIPMENT_CHANGED" or event == "PLAYER_ENTERING_WORLD"
    or event == "PLAYER_REGEN_ENABLED" or event == "GET_ITEM_INFO_RECEIVED"
    or event == "EQUIPMENT_SETS_CHANGED" or event == "EQUIPMENT_SWAP_FINISHED") then self:ScheduleFishingMacro() end
  if event == "LOOT_READY" then self:LootReady()
  elseif event == "PLAYER_LOGOUT" then self:SetMode(false)
  elseif event == "PLAYER_REGEN_DISABLED" then
    self.applied = nil -- Secure state driver releases bindings, not this event.
  elseif event == "PLAYER_EQUIPMENT_CHANGED" then
    if unit == 16 then self:EquipmentChanged() end
  elseif event == "GET_ITEM_INFO_RECEIVED" then if self.pendingPole then self:EquipmentChanged() end
  elseif event == "PLAYER_ENTERING_WORLD" then self:EquipmentChanged(); self:Refresh()
  elseif event:match("^UNIT_") then
    if unit == "player" then self:Refresh() end
  elseif event == "CVAR_UPDATE" then
    if unit and unit:lower() == "actionbuttonusekeydown" then self:Refresh() end
  else self:Refresh() end
end
function F:OnEnable()
  self.disabled = nil; self.wanted = false
  self.events = self.events or CreateFrame("Frame")
  for _, event in ipairs({"PLAYER_ENTERING_WORLD","PLAYER_EQUIPMENT_CHANGED","GET_ITEM_INFO_RECEIVED",
    "PLAYER_REGEN_DISABLED","PLAYER_REGEN_ENABLED","UNIT_SPELLCAST_CHANNEL_START","UNIT_SPELLCAST_CHANNEL_STOP",
    "UNIT_SPELLCAST_CHANNEL_UPDATE","SPELLS_CHANGED","CVAR_UPDATE","ADDON_LOADED","PLAYER_LOGOUT","LOOT_READY","EQUIPMENT_SETS_CHANGED","EQUIPMENT_SWAP_FINISHED"}) do self.events:RegisterEvent(event) end
  self.events:SetScript("OnEvent", function(_, ...) self:OnEvent(...) end)
  if not self.profileCallbacks then
    self.profileCallbacks = true
    for _, event in ipairs({"OnProfileChanged","OnProfileCopied","OnProfileReset"}) do
      Core.db.RegisterCallback(self, event, function() self:SetMode(false); self:EquipmentChanged() end)
    end
  end
  self:EquipmentChanged()
end
function F:OnDisable()
  self.disabled = true; self:SetMode(false)
  if self.events then
    self.events:UnregisterAllEvents()
    -- Keep one cleanup event if disabling during lockdown.
    if InCombatLockdown() then
      self.events:RegisterEvent("PLAYER_REGEN_ENABLED")
      self.events:SetScript("OnEvent", function() self:Refresh(); self.events:UnregisterAllEvents() end)
    end
  end
end
Core:RegisterFeature("fishing", {name="Fishing", order=40, resetOptions=function()
  cfg().key="SPACE"; cfg().autoPole=false; cfg().autoLoot=true; F:SetMode(false)
end, buildOptions=function() return {type="group", args={
  intro={type="description",order=1,name="One key casts Fishing, then interacts while channeling. Press again when the bobber splashes. Overrides are temporary and suspend in combat. Disable Better Fishing and reload first. Mode is session-only; pole detection can enable it at login."},
  mode={type="toggle",name="Fishing Mode",order=2,get=function() return not not F.wanted end,set=function(_,v) F:SetMode(v); F:Notify(F:Status()) end},
  key={type="input",name="Fishing key",order=3,get=function() return cfg().key end,set=function(_,v) if not F:SetKey(v) then F:Notify("That key is reserved or invalid.") end end},
  autoPole={type="toggle",name="Follow equipped fishing pole",order=4,get=function() return cfg().autoPole end,set=function(_,v) cfg().autoPole=v; F:EquipmentChanged() end},
  autoLoot={type="toggle",name="Auto-loot fishing catches",desc="Collect fishing loot before the loot window opens while Fishing Mode is on. Other loot and global auto-loot settings are unchanged. Full bags and required confirmations still follow native rules.",order=4.5,get=function() return cfg().autoLoot ~= false end,set=function(_,v) cfg().autoLoot=v end},
  status={type="description",order=5,name=function() return F:Status() end},
  gearHelp={type="description",order=6,name="Choose your existing Fishing and Normal equipment sets below. To create them, open Equipment Manager, equip your fishing pole and save a set, then equip normal weapons and save another. Include the main-hand slot in both; you can ignore other slots for a weapons-only swap. Update these sets when upgrading gear. Create Sunder Fish and drag it from /macro to your action bar. Use a different key from the Fishing cast/retrieve key."},
  gearStatus={type="description",order=7,name=function() return F:FishingGearStatus() end},
  fishingSet={type="select",name="Fishing equipment set",order=8,values=function() return F:FishingSetChoices("fishingSet") end,get=function() return F:GetFishingSet("fishingSet") end,set=function(_,v) F:SetFishingSet("fishingSet",v) end,disabled=function() return InCombatLockdown() or not F:EquipmentSetsAvailable() end},
  normalSet={type="select",name="Normal equipment set",order=9,values=function() return F:FishingSetChoices("normalSet") end,get=function() return F:GetFishingSet("normalSet") end,set=function(_,v) F:SetFishingSet("normalSet",v) end,disabled=function() return InCombatLockdown() or not F:EquipmentSetsAvailable() end},
  equipment={type="execute",name="Open Equipment Manager",order=9.5,func=function() F:OpenFishingEquipmentManager() end,disabled=InCombatLockdown},
  macro={type="execute",name="Create / update Sunder Fish macro",order=10,func=function() F:WriteFishingMacro(true) end,disabled=InCombatLockdown},
}} end})
