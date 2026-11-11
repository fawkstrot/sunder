local Core = unpack(select(2, ...))
local Launcher = Core:GetModule("Minimap")

-- Standalone native button: no broker, minimap library, or Ellesmere dependency.
-- Corner masks follow the standard WoW minimap-shape convention.
local shapes = {
  ROUND = {true, true, true, true}, SQUARE = {false, false, false, false},
  ["CORNER-TOPLEFT"] = {false, false, false, true},
  ["CORNER-TOPRIGHT"] = {false, false, true, false},
  ["CORNER-BOTTOMLEFT"] = {false, true, false, false},
  ["CORNER-BOTTOMRIGHT"] = {true, false, false, false},
  ["SIDE-LEFT"] = {false, true, false, true},
  ["SIDE-RIGHT"] = {true, false, true, false},
  ["SIDE-TOP"] = {false, false, true, true},
  ["SIDE-BOTTOM"] = {true, true, false, false},
  ["TRICORNER-TOPLEFT"] = {false, true, true, true},
  ["TRICORNER-TOPRIGHT"] = {true, false, true, true},
  ["TRICORNER-BOTTOMLEFT"] = {true, true, false, true},
  ["TRICORNER-BOTTOMRIGHT"] = {true, true, true, false},
}

function Launcher:UpdatePosition()
  if not self.button then return end
  -- Minimap-button collectors may own the button's placement in their flyout.
  if self.button:GetParent() ~= Minimap then return end
  local angle = math.rad(Core.db.global.minimap.angle or 225)
  local x, y = math.cos(angle), math.sin(angle)
  local quadrant = (x < 0 and 1 or 0) + (y > 0 and 2 or 0) + 1
  local shape = _G.GetMinimapShape and _G.GetMinimapShape() or "ROUND"
  local rounded = (shapes[shape] or shapes.ROUND)[quadrant]
  if not rounded then
    local edge = math.max(math.abs(x), math.abs(y))
    x, y = x / edge, y / edge
  end
  local rx, ry = Minimap:GetWidth() / 2 + 5, Minimap:GetHeight() / 2 + 5
  self.button:ClearAllPoints()
  self.button:SetPoint("CENTER", Minimap, "CENTER", x * rx, y * ry)
end

function Launcher:SetHidden(hidden)
  Core.db.global.minimap.hide = not not hidden
  if self.button then self.button:SetShown(not hidden) end
end

function Launcher:OnEnable()
  if self.button then return end
  local button = CreateFrame("Button", "SunderMinimapButton", Minimap)
  self.button = button
  button:SetSize(32, 32)
  button:SetFrameStrata("MEDIUM")
  button:SetFrameLevel(Minimap:GetFrameLevel() + 5)
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  button:RegisterForDrag("LeftButton")
  local icon = button:CreateTexture(nil, "BACKGROUND")
  button.icon = icon
  icon:SetSize(20, 20)
  icon:SetPoint("CENTER")
  icon:SetTexture("Interface\\AddOns\\Sunder\\Media\\Brand\\SunderMinimap")
  local border = button:CreateTexture(nil, "OVERLAY")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  border:SetSize(54, 54)
  border:SetPoint("TOPLEFT")
  button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  button:SetScript("OnClick", function (_, mouseButton)
    if self.suppressClick then self.suppressClick = nil; return end
    if mouseButton == "RightButton" then
      Core:GetModule("Config"):OnSlashCommand("lock")
    elseif IsShiftKeyDown and IsShiftKeyDown() then
      local whispers = Core:GetModule("Whispers", true)
      if whispers and whispers.OpenMessages then whispers:OpenMessages() end
    else
      Core:GetModule("Config"):OpenSettings()
    end
  end)
  button:SetScript("OnDragStart", function ()
    if button:GetParent() ~= Minimap then return end
    self.suppressClick = true
    GameTooltip:Hide()
    button:SetScript("OnUpdate", function ()
      if not IsMouseButtonDown("LeftButton") then button:GetScript("OnDragStop")(); return end
      local cx, cy = Minimap:GetCenter()
      local x, y = GetCursorPosition()
      local scale = Minimap:GetEffectiveScale()
      Core.db.global.minimap.angle = math.deg(math.atan2(y / scale - cy, x / scale - cx)) % 360
      self:UpdatePosition()
    end)
  end)
  button:SetScript("OnDragStop", function ()
    button:SetScript("OnUpdate", nil)
    -- Dragging should not open settings; clear suppression after this mouse event.
    C_Timer.After(0, function () self.suppressClick = nil end)
  end)
  button:SetScript("OnHide", function () button:SetScript("OnUpdate", nil) end)
  button:SetScript("OnShow", function () self:UpdatePosition() end)
  button:SetScript("OnEnter", function ()
    GameTooltip:SetOwner(button, "ANCHOR_LEFT")
    GameTooltip:AddLine(Core.DisplayName, 1, 0.82, 0)
    GameTooltip:AddLine("Left-click: settings", 1, 1, 1)
    GameTooltip:AddLine("Shift-left-click: Whispers window", 1, 1, 1)
    GameTooltip:AddLine("Right-click: lock/unlock chat windows", 1, 1, 1)
    GameTooltip:AddLine("Drag: move this button", 0.7, 0.7, 0.7)
    local whispers = Core:GetModule("Whispers", true)
    if whispers and whispers.ready then
      local unread = 0
      for _, record in pairs(whispers.records or {}) do unread = unread + record.unread end
      GameTooltip:AddLine("Unread whispers: "..unread, 1, 0.82, 0)
    end
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function () GameTooltip:Hide() end)
  Minimap:HookScript("OnSizeChanged", function () self:UpdatePosition() end)
  self:UpdatePosition()
  self:SetHidden(Core.db.global.minimap.hide)
end
