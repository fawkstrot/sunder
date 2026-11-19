local Core, Constants = unpack(select(2, ...))
local Fonts = Core:GetModule("Fonts")

local LSM = Core.Libs.LSM

local UPDATE_CONFIG = Constants.EVENTS.UPDATE_CONFIG

-- WoW provides these globals at runtime, so suppress Luacheck's undefined-global warning while localizing them.
-- luacheck: push ignore 113
local CreateFont = CreateFont
local CreateFontFamily = CreateFontFamily
local ChatFontNormal = ChatFontNormal
local GameFontNormal = GameFontNormal
-- luacheck: pop

-- Custom fonts usually lack CJK and Cyrillic glyphs, so only the roman member uses the
-- selected font while the other alphabets keep the client's native chat fonts.
local ALPHABETS = {"roman", "korean", "simplifiedchinese", "traditionalchinese", "russian"}
local nativeMembers
local nativeFontPaths = {}

local function initNativeFonts()
  if nativeMembers ~= nil then return end
  nativeMembers = false
  if not CreateFontFamily or not ChatFontNormal or not ChatFontNormal.GetFontObjectForAlphabet then return end
  local members = {}
  for _, alphabet in ipairs(ALPHABETS) do
    local native = ChatFontNormal:GetFontObjectForAlphabet(alphabet)
    if not native then return end
    local path, size, flags = native:GetFont()
    if not path then return end
    nativeFontPaths[alphabet] = path
    members[#members + 1] = {alphabet = alphabet, file = path, height = size, flags = flags or ""}
  end
  nativeMembers = members
end

local function createChatFont(name)
  initNativeFonts()
  if nativeMembers then return CreateFontFamily(name, nativeMembers) end
  return CreateFont(name)
end

-- Applies a setter to every alphabet member of a font family, or to a plain font.
local function eachMember(fontObject, callback)
  if not nativeMembers or not fontObject.GetFontObjectForAlphabet then
    callback(fontObject)
    return
  end
  for _, alphabet in ipairs(ALPHABETS) do
    local member = fontObject:GetFontObjectForAlphabet(alphabet)
    if member then callback(member, alphabet) end
  end
end

local function setFont(fontObject, size, setting)
  local defaultFontPath = GameFontNormal and GameFontNormal:GetFont()
  local settings = setting == "headerFont" and Core.db.profile.whispers or Core.db.profile
  local flags = setting and settings and settings[setting.."Flags"]
  if not flags or flags == "INHERIT" then flags = "" end
  local shadow = false
  if flags and flags:sub(1, 6) == "SHADOW" then
    shadow = true
    flags = flags:sub(7)
  end
  local selectedPath = Fonts:ResolvePath(setting)

  local function apply(member, alphabet)
    local fallbackPath = alphabet and nativeFontPaths[alphabet] or defaultFontPath
    local fontPath = (alphabet == nil or alphabet == "roman") and selectedPath or fallbackPath
    fontPath = fontPath or fallbackPath
    if fontPath == nil then
      return
    end
    local ok, applied = pcall(
      member.SetFont,
      member,
      fontPath,
      size,
      flags
    )

    if not ok or applied == false then
      local savedPath = (alphabet == nil or alphabet == "roman") and Fonts:ResolvePath(setting, nil, true) or fallbackPath
      local recovered, result = pcall(member.SetFont, member, savedPath or fallbackPath, size, flags)
      if (not recovered or result == false) and (alphabet == nil or alphabet == "roman") then
        local basePath = Fonts:ResolvePath(nil, nil, true)
        recovered, result = pcall(member.SetFont, member, basePath or fallbackPath, size, flags)
      end
      if (not recovered or result == false) and fallbackPath then member:SetFont(fallbackPath, size, flags) end
    end
    member:SetShadowColor(0, 0, 0, shadow and 1 or 0)
    member:SetShadowOffset(shadow and 1 or 0, shadow and -1 or 0)
  end
  eachMember(fontObject, apply)
  -- GetFont() on the family itself feeds native labels/measurement copies. Keep
  -- that face synchronized too; changing it does not replace alphabet members.
  if nativeMembers and fontObject.GetFontObjectForAlphabet then apply(fontObject, "roman") end
end

local function setTextColor(fontObject, color)
  eachMember(fontObject, function (member)
    member:SetTextColor(color.r, color.g, color.b, 1)
  end)
end

local function setSpacing(fontObject, spacing)
  eachMember(fontObject, function (member)
    member:SetSpacing(spacing)
  end)
end

local function setJustify(fontObject)
  fontObject:SetJustifyH("LEFT")
  fontObject:SetJustifyV("MIDDLE")
  eachMember(fontObject, function (member)
    member:SetJustifyH("LEFT")
    member:SetJustifyV("MIDDLE")
  end)
end

local function setCombatLogHighlightColor(fontObject)
  setTextColor(fontObject, Core:GetThemeColor("tabHighlightTextColor") or Constants.COLORS.apache)
end

function Fonts:OnInitialize()
  self.fonts = {}
end

function Fonts:OnEnable()
  self:EnableTypography()

  -- SunderMessageFont
  self.fonts.SunderMessageFont = createChatFont("SunderMessageFont")
  setFont(self.fonts.SunderMessageFont, Core.db.profile.messageFontSize, "messageFont")
  setJustify(self.fonts.SunderMessageFont)
  setSpacing(self.fonts.SunderMessageFont, Core.db.profile.messageLeading)

  -- SunderChatDockFont
  self.fonts.SunderChatDockFont = createChatFont("SunderChatDockFont")
  setFont(self.fonts.SunderChatDockFont, Core.db.profile.tabFontSize, "tabFont")
  setJustify(self.fonts.SunderChatDockFont)
  setSpacing(self.fonts.SunderChatDockFont, 3)

  -- Combat Log filter buttons
  self.fonts.SunderCombatLogNormalFont = createChatFont("SunderCombatLogNormalFont")
  setFont(self.fonts.SunderCombatLogNormalFont, Core.db.profile.tabFontSize, "tabFont")
  setTextColor(self.fonts.SunderCombatLogNormalFont, Core:GetThemeColor("tabTextColor"))
  setJustify(self.fonts.SunderCombatLogNormalFont)

  self.fonts.SunderCombatLogHighlightFont = createChatFont("SunderCombatLogHighlightFont")
  setFont(self.fonts.SunderCombatLogHighlightFont, Core.db.profile.tabFontSize, "tabFont")
  setCombatLogHighlightColor(self.fonts.SunderCombatLogHighlightFont)
  setJustify(self.fonts.SunderCombatLogHighlightFont)

  self.fonts.SunderCombatLogActiveFont = createChatFont("SunderCombatLogActiveFont")
  setFont(self.fonts.SunderCombatLogActiveFont, Core.db.profile.tabFontSize, "tabFont")
  setCombatLogHighlightColor(self.fonts.SunderCombatLogActiveFont)
  setJustify(self.fonts.SunderCombatLogActiveFont)

  -- SunderEditBoxFont
  self.fonts.SunderEditBoxFont = createChatFont("SunderEditBoxFont")
  setFont(self.fonts.SunderEditBoxFont, Core.db.profile.editBoxFontSize, "editBoxFont")
  setJustify(self.fonts.SunderEditBoxFont)
  setSpacing(self.fonts.SunderEditBoxFont, 3)

  Core:Subscribe(UPDATE_CONFIG, function (key)
    if key == "font" then self:RefreshTypography() end
    if key == "font" or key == "messageFontSize" then
      setFont(self.fonts.SunderMessageFont, Core.db.profile.messageFontSize, "messageFont")
    end

    if key == "messageLeading" then
      setSpacing(self.fonts.SunderMessageFont, Core.db.profile.messageLeading)
    end

    if key == "font" or key == "tabFontSize" then
      setFont(self.fonts.SunderChatDockFont, Core.db.profile.tabFontSize, "tabFont")
      setFont(self.fonts.SunderCombatLogNormalFont, Core.db.profile.tabFontSize, "tabFont")
      setFont(self.fonts.SunderCombatLogHighlightFont, Core.db.profile.tabFontSize, "tabFont")
      setFont(self.fonts.SunderCombatLogActiveFont, Core.db.profile.tabFontSize, "tabFont")
    end

    if key == "tabTextColor" then
      setTextColor(self.fonts.SunderCombatLogNormalFont, Core:GetThemeColor("tabTextColor"))
    end

    if key == "tabHighlightTextColor" then
      setCombatLogHighlightColor(self.fonts.SunderCombatLogActiveFont)
    end

    if key == "tabHighlightTextColor" then
      setCombatLogHighlightColor(self.fonts.SunderCombatLogHighlightFont)
    end

    if key == "font" or key == "messageFontSize" or key == "messageLeading" or key == "tabHighlightTextColor" or key == "backgroundFade" or key == "headerBackgroundColor" or key == "chatBackgroundColor"
      or key == "tabMessageSpacing" or key == "tabFontSize" or key == "textLeftPadding" or key == "bodyPadding" or key == "chatHeaderStyle" or key == "tabMessageSeparatorColor" then
      local whispers = Core:GetModule("Whispers")
      local function refresh(host)
        if host.previewBody then host:ApplyPreviewFont(host.previewBody) end
      end
      refresh(whispers)
      for _, host in pairs(whispers.workspaces or {}) do if host ~= whispers then refresh(host) end end
      whispers:RefreshHubStyle()
    end
    if key == "font" or key == "editBoxFontSize" then
      setFont(self.fonts.SunderEditBoxFont, Core.db.profile.editBoxFontSize, "editBoxFont")
    end
  end)
end


-- One face cascade for transcripts, chrome, menus and native bubbles. Sizes and
-- outlines remain role-specific. Never persist the resolved Ellesmere path.
function Fonts:ResolvePath(setting, selected, standalone)
  local profile = Core.db.profile
  if not standalone and profile.followEllesmereFont ~= false then
    local path = Core:GetModule("Ellesmere"):GetFontPath()
    if path then return path, "Ellesmere" end
  end
  local settings = setting == "headerFont" and profile.whispers or profile
  selected = selected or (setting and settings and settings[setting])
  if selected and selected ~= "" and selected ~= "INHERIT" then
    local path = LSM:Fetch("font", selected, true)
    if path then return path, "Sunder" end
  end
  local path = LSM:Fetch("font", profile.font, true)
  if path then return path, "Sunder" end
  return GameFontNormal and GameFontNormal:GetFont() or _G.STANDARD_TEXT_FONT, "Game"
end

function Fonts:ApplyLabel(label, size, setting)
  if not label or not label.GetFont or not label.SetFontObject then return end
  setting = setting or "interfaceFont"
  local _, oldSize = label:GetFont()
  size = math.max(6, math.min(100, tonumber(size or oldSize) or 13))
  size = math.floor(size * 2 + .5) / 2
  self.roleFonts = self.roleFonts or {}
  local key = setting .. ":" .. size
  local entry = self.roleFonts[key]
  if not entry then
    self.roleFontCount = (self.roleFontCount or 0) + 1
    entry = {font = createChatFont("SunderRoleFont" .. self.roleFontCount), size = size, setting = setting}
    self.roleFonts[key] = entry
    setFont(entry.font, size, setting)
  end
  -- Font objects carry the face without overwriting label color/alignment/wrapping.
  local r,g,b,a
  if label.GetTextColor then r,g,b,a = label:GetTextColor() end
  local h = label.GetJustifyH and label:GetJustifyH()
  local v = label.GetJustifyV and label:GetJustifyV()
  label:SetFontObject(entry.font)
  if type(h)=="string" then label:SetJustifyH(h) end
  if type(v)=="string" then label:SetJustifyV(v) end
  if type(r)=="number" and label.SetTextColor then label:SetTextColor(r,g,b,a) end
end

-- Only explicitly owned UI trees. Never enumerate UIParent or change GameFontNormal.
function Fonts:StyleTree(root, setting, depth)
  if not root then return end
  depth = depth or 0
  if depth > 8 or (root.IsForbidden and root:IsForbidden()) then return end
  if root.GetFont and root.SetFontObject then self:ApplyLabel(root, nil, setting) end
  if root.GetRegions then
    for _, region in ipairs({root:GetRegions()}) do
      if region.GetFont and region.SetFontObject then self:ApplyLabel(region, nil, setting) end
    end
  end
  if root.GetChildren then
    for _, child in ipairs({root:GetChildren()}) do self:StyleTree(child, setting, depth + 1) end
  end
end

function Fonts:StyleMenu(description, depth)
  if not description then return end
  depth = depth or 0
  if depth > 8 then return end
  if description.AddInitializer then
    description:AddInitializer(function(button)
      self:StyleTree(button, "menuFont")
      local label=button.fontString
      if label and label.SetTextToFit and label.GetText then
        local text=label:GetText()
        if not _G.canaccessvalue or _G.canaccessvalue(text) then label:SetTextToFit(text) end
      end
    end)
  end
  if description.EnumerateElementDescriptions then
    for _, child in description:EnumerateElementDescriptions() do self:StyleMenu(child, depth + 1) end
  end
end

function Fonts:CreateContextMenu(owner, generator)
  if not (_G.MenuUtil and _G.MenuUtil.CreateContextMenu) then return end
  return _G.MenuUtil.CreateContextMenu(owner, function(frame, description, ...)
    generator(frame, description, ...)
    self:StyleMenu(description)
  end)
end

function Fonts:RefreshTypography()
  for _, entry in pairs(self.roleFonts or {}) do setFont(entry.font, entry.size, entry.setting) end
  self:RefreshBubbles()
end

function Fonts:QueueRefresh()
  if self.refreshQueued or not Core.db then return end
  self.refreshQueued = true
  _G.C_Timer.After(0, function()
    self.refreshQueued = nil
    Core:SelectDefaultFont()
  end)
end

function Fonts:SetExternalBubbleSetting(key, value)
  local owner, cfg = self:BubbleOwner()
  if not owner then return end
  cfg[key] = value
  if owner.RefreshStyle then owner.RefreshStyle() end
end

function Fonts:ExternalBubbleFonts()
  local ui = _G.EllesmereUI
  local values = {__global="Inherit Ellesmere global font"}
  if ui and ui.BuildFontDropdownData then
    local ok, data = pcall(ui.BuildFontDropdownData)
    if ok and type(data)=="table" then
      for key, entry in pairs(data) do
        if key ~= "---" then values[key] = type(entry)=="table" and entry.text or tostring(entry) end
      end
    end
  end
  return values
end

function Fonts:WatchEllesmere()
  local ui = _G.EllesmereUI
  if not ui or not _G.hooksecurefunc then return end
  self.fontHooks = self.fontHooks or setmetatable({}, {__mode="k"})
  local bubbles=ui.ChatBubbles
  if bubbles and not self.fontHooks[bubbles] and type(bubbles.Refresh)=="function" then
    self.fontHooks[bubbles]=true
    _G.hooksecurefunc(bubbles,"Refresh",function()self:QueueRefresh()end)
  end
  if self.fontHooks[ui] then return end
  if type(ui.InvalidateFontCache) == "function" then
    self.fontHooks[ui] = true
    _G.hooksecurefunc(ui, "InvalidateFontCache", function() self:QueueRefresh() end)
  end
end

function Fonts:EnableTypography()
  self:WatchEllesmere()
  local dialog = Core.Libs.AceConfigDialog
  if not self.optionsHook and dialog and dialog.FeedGroup and _G.hooksecurefunc then
    self.optionsHook=true
    _G.hooksecurefunc(dialog,"FeedGroup",function(_,appName,_,container)
      if appName=="Sunder" and container then self:StyleTree(container.frame) end
    end)
  end
  if not self.typographyEvents then
    local frame = _G.CreateFrame("Frame")
    self.typographyEvents = frame
    frame:RegisterEvent("ADDON_LOADED")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:SetScript("OnEvent", function(_, event, name)
      if event ~= "ADDON_LOADED" or (type(name)=="string" and name:find("Ellesmere",1,true)) then
        self:WatchEllesmere(); self:QueueRefresh()
      end
    end)
    if LSM.RegisterCallback then
      LSM.RegisterCallback(self, "LibSharedMedia_Registered", function(_, kind)
        if kind == "font" then self:QueueRefresh() end
      end)
    end
  end
  self:RefreshBubbles()
end


-- Native bubble text is a restricted surface in instances. No text reads, CVar
-- changes, replacement bubbles or per-frame polling. Work follows chat/show events.
local bubbleEvents = {"CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
  "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER",
  "CHAT_MSG_MONSTER_SAY", "CHAT_MSG_MONSTER_YELL", "CHAT_MSG_MONSTER_PARTY", "CHAT_MSG_EMOTE"}
function Fonts:BubbleOwner()
  local ui = _G.EllesmereUI
  local bubbles = ui and ui.ChatBubbles
  if bubbles and bubbles.DB then
    local ok, cfg = pcall(bubbles.DB, false)
    if ok and cfg and cfg.enabled then return bubbles, cfg end
  end
end

function Fonts:RestoreBubble(label, original)
  -- Do not alter a reused label another renderer has already restyled.
  if label.GetFontObject and label:GetFontObject() == original.applied then
    if original.object then label:SetFontObject(original.object) end
    if original.path then label:SetFont(original.path, original.size, original.flags) end
  end
end

function Fonts:StyleBubble(outer)
  if Core.db.profile.styleBubbleFonts == false or self:BubbleOwner() then return end
  if _G.IsInInstance and _G.IsInInstance() then return end
  if not outer or (outer.IsForbidden and outer:IsForbidden()) then return end
  local function visit(frame, depth)
    if depth > 3 or (frame.IsForbidden and frame:IsForbidden()) then return end
    if frame.GetRegions then
      for _, label in ipairs({frame:GetRegions()}) do
        if label.GetFont and label.SetFontObject then
          local original = self.bubbleLabels[label]
          if not original then
            local path, size, flags = label:GetFont()
            original = {object=label:GetFontObject(),path=path,size=size,flags=flags or ""}
            self.bubbleLabels[label] = original
          end
          self:ApplyLabel(label, Core.db.profile.bubbleFontSize or 13, "bubbleFont")
          original.applied = label:GetFontObject()
        end
      end
    end
    if frame.GetChildren then for _, child in ipairs({frame:GetChildren()}) do visit(child, depth+1) end end
  end
  visit(outer, 0)
end

function Fonts:ScanBubbles()
  if not (_G.C_ChatBubbles and _G.C_ChatBubbles.GetAllChatBubbles) then return end
  if _G.IsInInstance and _G.IsInInstance() then return end
  local ok, bubbles = pcall(_G.C_ChatBubbles.GetAllChatBubbles)
  if not ok or type(bubbles) ~= "table" then return end
  self.bubbleHooks = self.bubbleHooks or setmetatable({}, {__mode="k"})
  for i=1, math.min(#bubbles,64) do
    local outer = bubbles[i]
    pcall(function()
      if outer.IsForbidden and outer:IsForbidden() then return end
      if not self.bubbleHooks[outer] and outer.HookScript then
        self.bubbleHooks[outer] = true
        outer:HookScript("OnShow", function(frame) pcall(self.StyleBubble,self,frame) end)
      end
      self:StyleBubble(outer)
    end)
  end
end

function Fonts:RefreshBubbles()
  self.bubbleLabels = self.bubbleLabels or setmetatable({}, {__mode="k"})
  local enabled = Core.db.profile.styleBubbleFonts ~= false and not self:BubbleOwner()
  if not enabled then
    for label, original in pairs(self.bubbleLabels) do pcall(self.RestoreBubble,self,label,original) end
    self.bubbleLabels = setmetatable({}, {__mode="k"})
  end
  if not self.bubbleEvents then
    self.bubbleEvents = _G.CreateFrame("Frame")
    self.bubbleEvents:SetScript("OnEvent", function()
      if self.bubbleScanQueued then return end
      self.bubbleScanQueued = true
      -- Two bounded passes cover native creation after the chat event.
      _G.C_Timer.After(0, function() self:ScanBubbles() end)
      _G.C_Timer.After(.1, function() self.bubbleScanQueued=nil; self:ScanBubbles() end)
    end)
  end
  self.bubbleEvents:UnregisterAllEvents()
  if enabled then
    for _, event in ipairs(bubbleEvents) do self.bubbleEvents:RegisterEvent(event) end
    self:ScanBubbles()
  end
end

-- GameTooltip is shared and pooled. Scope our font to this Sunder presentation,
-- then restore its exact prior face before another addon uses it.
function Fonts:StyleTooltip(tooltip)
  if not tooltip or not tooltip.GetRegions or not tooltip.HookScript then return end
  self.tooltipState = self.tooltipState or setmetatable({}, {__mode="k"})
  local state=self.tooltipState[tooltip]
  if not state then
    state={};self.tooltipState[tooltip]=state
    tooltip:HookScript("OnHide",function()
      for label,original in pairs(state) do
        pcall(self.RestoreBubble,self,label,original)
        state[label]=nil
      end
    end)
  end
  for _,label in ipairs({tooltip:GetRegions()}) do
    if label.GetFont and label.SetFontObject then
      if not state[label] then
        local path,size,flags=label:GetFont()
        state[label]={object=label:GetFontObject(),path=path,size=size,flags=flags or ""}
      end
      self:ApplyLabel(label,nil,"interfaceFont")
      state[label].applied=label:GetFontObject()
    end
  end
end
