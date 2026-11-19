local Core = unpack(select(2, ...))
local N = Core:GetModule("Nameplates")
local keys = {
  visible="nameplateShowFriendlyPlayers", names="nameplateShowOnlyNameForFriendlyPlayerUnits",
  nameColor="nameplateUseClassColorForFriendlyPlayerUnitNames", barColor="nameplateShowFriendlyClassColor",
  size="nameplateSize",
}
local function read(key)
  local fn = C_CVar and C_CVar.GetCVar or GetCVar
  if not fn then return end
  local ok, value = pcall(fn, key)
  if ok and value ~= nil then return tostring(value) end
end
local function write(key, value)
  local fn = C_CVar and C_CVar.SetCVar or SetCVar
  if not fn then return false end
  return pcall(fn, key, value)
end
local function combat() return InCombatLockdown and InCombatLockdown() end
local function config() return Core.db.profile.nameplates end
function N:Ledger()
  -- Persist original values across reloads; never capture our own applied value
  -- as the baseline on the next login. Only known keys are ever written.
  Core.db.char.nameplateOverrides = Core.db.char.nameplateOverrides or {}
  return Core.db.char.nameplateOverrides
end
function N:Desired()
  local c = config()
  if self.disabled or not c.enabled then return {} end
  local mode = c.mode
  local _, instance = IsInInstance()
  if (instance == "party" or instance == "raid") and c.instanceMode ~= "inherit" then mode = c.instanceMode end
  local desired = {[keys.visible]=mode == "off" and "0" or "1"}
  if mode ~= "off" then
    desired[keys.names] = mode == "names" and "1" or "0"
    if c.nameColor ~= "keep" then desired[keys.nameColor] = c.nameColor == "class" and "1" or "0" end
    if c.barColor ~= "keep" then desired[keys.barColor] = c.barColor == "class" and "1" or "0" end
    if c.size and c.size > 0 then desired[keys.size] = tostring(c.size) end
  end
  return desired
end
function N:Refresh()
  if combat() then self.pending=true; return end
  self.pending=false
  self.blocked=self.blocked or {}
  self.missing={}; self.failed={}
  local desired, ledger = self:Desired(), self:Ledger()
  self.applying=true
  for _, key in pairs(keys) do
    local current, lease, wanted = read(key), ledger[key], desired[key]
    if lease and current ~= lease.applied then
      -- Another owner wins, including changes made while we were unloaded.
      ledger[key]=nil; lease=nil; self.blocked[key]=true
    end
    if not wanted then
      if lease then
        if current == lease.applied and (not write(key, lease.original) or read(key) ~= lease.original) then
          self.failed[key]=true
        else ledger[key]=nil end
      end
    elseif current == nil then self.missing[key]=true
    elseif not self.blocked[key] then
      if current ~= wanted then
        local original = lease and lease.original or current
        if write(key, wanted) and read(key) == wanted then ledger[key]={original=original, applied=wanted}
        else self.failed[key]=true end
      end
    end
  end
  self.applying=false
end
function N:Reapply()
  -- First reconcile outside edits so they become the new restoration baseline.
  self:Refresh()
  self.blocked={}
  Core.db.char.nameplateYielded=self.blocked
  self:Refresh()
end
function N:OnEvent(event, name)
  if event == "CVAR_UPDATE" then
    if self.applying then return end
    for _, key in pairs(keys) do
      if type(name)=="string" and name:lower()==key:lower() then
        local lease=self:Ledger()[key]
        if lease and read(key) ~= lease.applied then
          self:Ledger()[key]=nil; self.blocked=self.blocked or {}; self.blocked[key]=true
        end
      end
    end
    return
  end
  self:Refresh()
  if self.disabled and not self.pending then self.events:UnregisterAllEvents() end
end
function N:OnEnable()
  self.disabled=false
  Core.db.char.nameplateYielded=Core.db.char.nameplateYielded or {}
  self.blocked=Core.db.char.nameplateYielded
  if not self.events then self.events=CreateFrame("Frame"); self.events:SetScript("OnEvent",function(_,...) self:OnEvent(...) end) end
  for _, event in ipairs({"PLAYER_ENTERING_WORLD","ZONE_CHANGED_NEW_AREA","PLAYER_REGEN_ENABLED","CVAR_UPDATE"}) do self.events:RegisterEvent(event) end
  if not self.profileCallbacks then
    self.profileCallbacks=true
    for _, event in ipairs({"OnProfileChanged","OnProfileCopied","OnProfileReset"}) do
      Core.db.RegisterCallback(self,event,function() self:Refresh() end)
    end
  end
  self:Refresh()
end
function N:OnDisable() self.disabled=true; self:Refresh(); if not self.pending and self.events then self.events:UnregisterAllEvents() end end
function N:Status()
  if self.pending then return "Changes will apply after combat." end
  if self.failed and next(self.failed) then return "Some settings could not be applied or restored. Try again outside combat." end
  if self.missing and next(self.missing) then return "Some nameplate settings are unavailable on this client." end
  if config().enabled and self.blocked and next(self.blocked) then return "A game setting or another addon changed these options. Sunder is leaving those changes in place. Use Apply preferences to take control again." end
  return config().enabled and "Native nameplate preferences active. Dungeon appearance still requires in-game verification." or "Sunder nameplate control is off. Your previous settings are restored where Sunder still owned them."
end
Core:RegisterFeature("nameplates",{name="Nameplates",order=40,buildOptions=function()
  local function get(info) return config()[info[#info]] end
  local function set(info,value) config()[info[#info]]=value; N:Refresh() end
  local function unsupported(key) return function() return not config().enabled or read(keys[key])==nil end end
  return {type="group",args={
    intro={type="description",order=0,name="Make friendly players easier to see using Blizzard's own nameplates, including native dungeon plates. These settings apply to friendly players, not only party members. Health-bar mode may also show native cast bars and auras. Choose one addon to manage these preferences."},
    enabled={type="toggle",name="Manage friendly nameplates",order=1,get=get,set=set},
    status={type="description",order=2,name=function() return N:Status() end},
    mode={type="select",name="Default display",order=3,values={off="Hidden",names="Names only",bars="Names and health bars"},get=get,set=set,disabled=unsupported("visible")},
    instanceMode={type="select",name="Dungeons and raids",order=4,values={inherit="Use default display",off="Hidden",names="Names only",bars="Names and health bars"},get=get,set=set,disabled=unsupported("visible")},
    nameColor={type="select",name="Name color",order=5,values={keep="Keep game setting",class="Class color",native="Native color"},get=get,set=set,disabled=unsupported("nameColor")},
    barColor={type="select",name="Health-bar color",order=6,values={keep="Keep game setting",class="Class color",native="Native color"},get=get,set=set,disabled=unsupported("barColor")},
    size={type="select",name="Overall nameplate size",desc="Changes both friendly and enemy native nameplates. Keep game setting restores Sunder's previous override.",order=7,values=function()
      local e=Enum and Enum.NamePlateSize
      local values={[0]="Keep game setting"}
      if e then for _, pair in ipairs({{"Small","Small"},{"Medium","Medium"},{"Large","Large"},{"ExtraLarge","Extra large"},{"Huge","Huge"}}) do if e[pair[1]] then values[e[pair[1]]]=pair[2] end end end
      return values
    end,get=get,set=set,disabled=function() return unsupported("size")() or not (Enum and Enum.NamePlateSize) end},
    reapply={type="execute",name="Apply preferences",order=8,func=function() N:Reapply() end,disabled=function()return not config().enabled end},
  }}
end})
