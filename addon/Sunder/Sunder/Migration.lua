local Core=unpack(select(2,...))
-- Only this module knows legacy saved-variable and media identifiers.
local legacyNames={"ROTBOTForeverDB","RunestoneDB","GlassyDB"}
local function copy(value,seen)
  if type(value)~="table" then return value end
  seen=seen or {};if seen[value]then return seen[value]end
  local result={};seen[value]=result
  for key,item in pairs(value)do result[copy(key,seen)]=copy(item,seen)end
  return result
end
local function migrateMedia(value)
  if type(value)~="table"then return end
  for key,item in pairs(value)do
    if type(item)=="table"then migrateMedia(item)
    elseif type(item)=="string"then
      for _,old in ipairs({"ROTBOTForever","Runestone"})do
        local prefix="Interface\\AddOns\\"..old.."\\"
        if item:sub(1,#prefix)==prefix then
          local suffix=item:sub(#prefix+1)
          if suffix:sub(1,#old+1)==old.."\\"then suffix="Sunder\\"..suffix:sub(#old+2)end
          value[key]="Interface\\AddOns\\Sunder\\"..suffix
        end
        if item==old..": Game default"then value[key]="Sunder: Game default"end
      end
    end
  end
end
function Core:MigrateSavedVariables()
  if type(_G.SunderDB)~="table" or _G.SunderDB.global and _G.SunderDB.global.sunderMigrationPending then
    for _,name in ipairs(legacyNames)do
      if type(_G[name])=="table"then
        _G.SunderDB=copy(_G[name])
        _G.SunderDB.global=_G.SunderDB.global or {}
        _G.SunderDB.global.migratedFrom=name
        _G.SunderDB.global.sunderMigrationVersion=1
        _G.SunderDB.global.sunderMigrationPending=nil
        _G.SunderDB.global.version=nil
        if name=="GlassyDB"then _G.SunderDB.global.migratedFromGlassy=true end
        break
      end
    end
  end
  local db=_G.SunderDB
  if type(db)=="table"then
    if db.global and db.global.whisperModeBeforeSunder==nil then db.global.whisperModeBeforeSunder=db.global.whisperModeBeforeRotbot end
    for _,profile in pairs(db.profiles or {})do migrateMedia(profile)end
  end
end

function Core:CheckLegacyImplementation()
  for _,name in ipairs({"ROTBOTForever","Runestone"})do
    if type(_G[name])=="table" and _G[name]~=self then
      self:SetEnabledState(false)
      if _G.DEFAULT_CHAT_FRAME then _G.DEFAULT_CHAT_FRAME:AddMessage("Sunder: install the upgrade data loader to replace the old addon before enabling Sunder. Existing data is preserved.")end
      return false
    end
  end
  return true
end
