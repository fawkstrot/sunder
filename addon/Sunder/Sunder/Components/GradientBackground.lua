local Core = unpack(select(2, ...))

-- WoW provides these globals at runtime, so suppress Luacheck's undefined-global warning while localizing them.
-- luacheck: push ignore 113
local CreateFrame = CreateFrame
local GetPhysicalScreenSize = GetPhysicalScreenSize
local Mixin = Mixin
-- luacheck: pop

---@class SunderGradientBackground: Frame
---@field leftBg Texture
---@field rightBg Texture
---@field centerBg Texture
local GradientBackgroundMixin = {}

local function getPhysicalPixelHeight(region)
  if type(GetPhysicalScreenSize) == "function" then
    local _, physicalHeight = GetPhysicalScreenSize()
    local effectiveScale = region:GetEffectiveScale()
    if physicalHeight and physicalHeight > 0 and effectiveScale and effectiveScale > 0 then
      return 768 / physicalHeight / effectiveScale
    end
  end
  return 1
end

local function clampColorChannel(value, fallback)
  return math.max(0, math.min(1, tonumber(value) or fallback))
end

function GradientBackgroundMixin:Init()
end

function GradientBackgroundMixin:GetPhysicalPixelHeight()
  return getPhysicalPixelHeight(self)
end

function GradientBackgroundMixin:SetGradientBackground(color, opacity, horizontalInset, bottomInset)
  local red = clampColorChannel(color and color.r, 0)
  local green = clampColorChannel(color and color.g, 0)
  local blue = clampColorChannel(color and color.b, 0)
  local alpha = clampColorChannel(opacity, clampColorChannel(color and color.a, 1))
  horizontalInset = horizontalInset or 0
  bottomInset = bottomInset or 0
  -- Message rows provide their configured width because their own bounds can be secret.
  local availableWidth = math.max(1, (self.sunderLayoutWidth or self:GetWidth()) + horizontalInset * 2)
  local leftWidth = availableWidth * math.max(0, math.min(100, tonumber(Core.db.profile.backgroundFadeLeftPercent) or 0)) / 100
  local rightWidth = availableWidth * math.max(0, math.min(100, tonumber(Core.db.profile.backgroundFadeRightPercent) or 0)) / 100
  local totalWidth = leftWidth + rightWidth
  if totalWidth > availableWidth then
    local scale = availableWidth / totalWidth
    leftWidth = leftWidth * scale
    rightWidth = rightWidth * scale
  end

  if self.leftBg == nil then
    self.leftBg = self:CreateTexture("", "BACKGROUND")
    self.leftBg:SetColorTexture(1, 1, 1, 1)
  end

  self.leftBg:ClearAllPoints()
  self.leftBg:SetPoint("TOPLEFT", self, "TOPLEFT", -horizontalInset, 0)
  self.leftBg:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", -horizontalInset, bottomInset)
  if leftWidth > 0 then
    self.leftBg:SetWidth(leftWidth)
    self.leftBg:SetGradient(
      "HORIZONTAL",
      CreateColor(red, green, blue, 0),
      CreateColor(red, green, blue, alpha)
    )
    self.leftBg:Show()
  else
    self.leftBg:Hide()
  end

  if self.rightBg == nil then
    self.rightBg = self:CreateTexture("", "BACKGROUND")
    self.rightBg:SetColorTexture(1, 1, 1, 1)
  end

  self.rightBg:ClearAllPoints()
  self.rightBg:SetPoint("TOPRIGHT", self, "TOPRIGHT", horizontalInset, 0)
  self.rightBg:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", horizontalInset, bottomInset)
  if rightWidth > 0 then
    self.rightBg:SetWidth(rightWidth)
    self.rightBg:SetGradient(
      "HORIZONTAL",
      CreateColor(red, green, blue, alpha),
      CreateColor(red, green, blue, 0)
    )
    self.rightBg:Show()
  else
    self.rightBg:Hide()
  end

  if self.centerBg == nil then
    self.centerBg = self:CreateTexture("", "BACKGROUND")
  end

  self.centerBg:ClearAllPoints()
  if leftWidth > 0 then
    self.centerBg:SetPoint("TOPLEFT", self.leftBg, "TOPRIGHT")
  else
    self.centerBg:SetPoint("TOPLEFT", self, "TOPLEFT", -horizontalInset, 0)
  end
  if rightWidth > 0 then
    self.centerBg:SetPoint("BOTTOMRIGHT", self.rightBg, "BOTTOMLEFT")
  else
    self.centerBg:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", horizontalInset, bottomInset)
  end
  self.centerBg:SetColorTexture(red, green, blue, alpha)
  if leftWidth + rightWidth >= availableWidth - 0.001 then
    self.centerBg:Hide()
  else
    self.centerBg:Show()
  end
end

function GradientBackgroundMixin:SetSeparatorColor(color, opacityMultiplier)
  local multiplier = clampColorChannel(opacityMultiplier, 1)
  local alpha = clampColorChannel(color and color.a, 0) * multiplier
  self:SetShown(alpha > 0)
  if alpha > 0 then
    self:SetGradientBackground(color, alpha)
  end
end

Core.Components.GradientBackgroundMixin = GradientBackgroundMixin

function Core.Components.CreateSeparatorFrame(parent)
  local frame = CreateFrame("Frame", nil, parent)
  local object = Mixin(frame, GradientBackgroundMixin)
  GradientBackgroundMixin.Init(object)
  object:SetHeight(getPhysicalPixelHeight(object))
  return object
end
-- Paint a bounded surface with the same edge-fade proportions used by chat rows.
-- Text and controls remain on their original layers and keep full opacity.
function Core.Components.PaintGradientTexture(texture, color, opacity, enabled)
  if not enabled then
    texture:SetColorTexture(color.r, color.g, color.b, opacity)
    for _, part in pairs(texture.sunderGradientParts or {}) do part:Hide() end
    return
  end
  if not texture.sunderGradientParts then
    local parent = texture:GetParent()
    texture.sunderGradientParts = {
      left = parent:CreateTexture(nil, "BACKGROUND"),
      center = parent:CreateTexture(nil, "BACKGROUND"),
      right = parent:CreateTexture(nil, "BACKGROUND"),
    }
  end
  local parts = texture.sunderGradientParts
  local width = math.max(1, texture:GetWidth())
  local left = width * math.max(0, math.min(100, tonumber(Core.db.profile.backgroundFadeLeftPercent) or 0)) / 100
  local right = width * math.max(0, math.min(100, tonumber(Core.db.profile.backgroundFadeRightPercent) or 0)) / 100
  if left + right > width then local scale = width / (left + right); left, right = left * scale, right * scale end
  texture:SetColorTexture(color.r, color.g, color.b, 0)
  parts.left:ClearAllPoints(); parts.left:SetPoint("TOPLEFT", texture, "TOPLEFT"); parts.left:SetPoint("BOTTOMLEFT", texture, "BOTTOMLEFT")
  parts.left:SetWidth(math.max(0.001, left)); parts.left:SetColorTexture(1, 1, 1, 1)
  parts.left:SetGradient("HORIZONTAL", CreateColor(color.r, color.g, color.b, 0), CreateColor(color.r, color.g, color.b, opacity))
  parts.left:SetShown(left > 0)
  parts.right:ClearAllPoints(); parts.right:SetPoint("TOPRIGHT", texture, "TOPRIGHT"); parts.right:SetPoint("BOTTOMRIGHT", texture, "BOTTOMRIGHT")
  parts.right:SetWidth(math.max(0.001, right)); parts.right:SetColorTexture(1, 1, 1, 1)
  parts.right:SetGradient("HORIZONTAL", CreateColor(color.r, color.g, color.b, opacity), CreateColor(color.r, color.g, color.b, 0))
  parts.right:SetShown(right > 0)
  parts.center:ClearAllPoints()
  parts.center:SetPoint("TOPLEFT", left > 0 and parts.left or texture, left > 0 and "TOPRIGHT" or "TOPLEFT")
  parts.center:SetPoint("BOTTOMRIGHT", right > 0 and parts.right or texture, right > 0 and "BOTTOMLEFT" or "BOTTOMRIGHT")
  parts.center:SetColorTexture(color.r, color.g, color.b, opacity)
  parts.center:SetShown(left + right < width - 0.001)
end
