local Core, Constants = unpack(select(2, ...))

local HyperlinkClick = Constants.ACTIONS.HyperlinkClick
local HyperlinkEnter = Constants.ACTIONS.HyperlinkEnter
local HyperlinkLeave = Constants.ACTIONS.HyperlinkLeave

-- WoW provides these globals at runtime, so suppress Luacheck's undefined-global warning while localizing them.
-- luacheck: push ignore 113
local CreateFrame = CreateFrame
local CreateObjectPool = CreateObjectPool
local Mixin = Mixin
local UIParent = UIParent
local canaccessvalue = canaccessvalue
-- luacheck: pop

local MessageLineMixin = {}

local function getLeftTextPadding()
  return math.max(0, math.min(32, tonumber(Core.db.profile.bodyPadding) or 12))
end

local function isAccessible(value)
  return not canaccessvalue or canaccessvalue(value)
end

-- Rows chained above secret text inherit secret geometry, so heights are measured on a detached FontString.
local measureText
local function measureTextHeight(text, width)
  if measureText == nil then
    measureText = UIParent:CreateFontString(nil, "BACKGROUND", "SunderMessageFont")
    measureText:SetPoint("TOPLEFT", UIParent, "TOPLEFT")
    measureText:Hide()
  end
  measureText:SetFontObject("SunderMessageFont")
  measureText:SetWidth(width)
  measureText:SetIndentedWordWrap(Core.db.profile.indentWordWrap)
  local lineHeight = measureText:GetLineHeight()
  if not isAccessible(text) then
    return nil, lineHeight
  end
  measureText:SetText(text)
  local height = measureText:GetStringHeight()
  measureText:ClearText()
  if not isAccessible(height) then
    return nil, lineHeight
  end
  return height, lineHeight
end

local function updateBackground(self)
  local color = Core.db.profile.chatBackgroundColor
  local frameWidth = Core.db.profile.frameWidth
  local leftFadeWidth = tonumber(Core.db.profile.backgroundFadeLeftPercent) or 0
  local rightFadeWidth = tonumber(Core.db.profile.backgroundFadeRightPercent) or 0
  if (
    self.sunderBackgroundWidth == frameWidth and
    self.sunderBackgroundLeftFadeWidth == leftFadeWidth and
    self.sunderBackgroundRightFadeWidth == rightFadeWidth and
    self.sunderBackgroundRed == color.r and
    self.sunderBackgroundGreen == color.g and
    self.sunderBackgroundBlue == color.b and
    self.sunderBackgroundAlpha == color.a
  ) then
    return
  end

  self:SetGradientBackground(color, color.a)
  self.sunderBackgroundWidth = frameWidth
  self.sunderBackgroundLeftFadeWidth = leftFadeWidth
  self.sunderBackgroundRightFadeWidth = rightFadeWidth
  self.sunderBackgroundRed = color.r
  self.sunderBackgroundGreen = color.g
  self.sunderBackgroundBlue = color.b
  self.sunderBackgroundAlpha = color.a
  self.sunderCoverageOpacity = nil
  self:SetBackgroundCoverage(self.sunderBackgroundCoverage or 0)
end

function MessageLineMixin:SetBackgroundCoverage(coverage)
  self.sunderBackgroundCoverage = coverage
  local color = Core.db.profile.chatBackgroundColor
  -- Preserve existing lines without double-fading backgrounds as hidden lines return.
  local messageAlpha = self:GetAlpha()
  local opacity = 0
  if messageAlpha > coverage then
    opacity = color.a * (messageAlpha - coverage) / (messageAlpha * (1 - color.a * coverage))
  end
  if self.sunderCoverageOpacity == opacity then return end
  self.sunderCoverageOpacity = opacity
  if opacity == 0 then
    self:DisableDrawLayer("BACKGROUND")
    return
  end
  self:EnableDrawLayer("BACKGROUND")
  self.centerBg:SetColorTexture(color.r, color.g, color.b, opacity)
  local transparent = CreateColor(color.r, color.g, color.b, 0)
  local opaque = CreateColor(color.r, color.g, color.b, opacity)
  self.leftBg:SetGradient("HORIZONTAL", transparent, opaque)
  self.rightBg:SetGradient("HORIZONTAL", opaque, transparent)
end

function MessageLineMixin:UpdateFadeSettings()
  local fadeInDuration = Core.db.profile.chatFadeInDuration
  local fadeOutDuration = Core.db.profile.chatFadeOutDuration
  local fadeEasing = Core.db.profile.chatFadeEasing
  if self.sunderFadeInDuration ~= fadeInDuration then
    self:SetFadeInDuration(fadeInDuration)
    self.sunderFadeInDuration = fadeInDuration
  end
  if self.sunderFadeOutDuration ~= fadeOutDuration then
    self:SetFadeOutDuration(fadeOutDuration)
    self.sunderFadeOutDuration = fadeOutDuration
  end
  if self.sunderFadeEasing ~= fadeEasing then
    self:SetFadeEasing(fadeEasing)
    self.sunderFadeEasing = fadeEasing
  end
end

function MessageLineMixin:Init()
  self:SetWidth(Core.db.profile.frameWidth)
  self:UpdateFadeSettings()
  updateBackground(self)

  if self.text == nil then
    self.text = self:CreateFontString(nil, "ARTWORK", "SunderMessageFont")
  end
  self.text:SetIndentedWordWrap(Core.db.profile.indentWordWrap)

  -- Hyperlink handling
  self:SetHyperlinksEnabled(true)

  self:SetScript("OnHyperlinkClick", function (_, link, text, button)
    Core:Dispatch(HyperlinkClick({link, text, button, self.sourceFrame}))
  end)

  self:SetScript("OnHyperlinkEnter", function (_, link, text)
    if Core.db.profile.mouseOverTooltips and isAccessible(link) then
      Core:Dispatch(HyperlinkEnter({link, text}))
    end
  end)

  self:SetScript("OnHyperlinkLeave", function (_, link)
    Core:Dispatch(HyperlinkLeave(link))
  end)

end

function MessageLineMixin:SetDisplayText(text)
  -- Match Blizzard's pooled FontString reset so protected text aspects do not leak into later lines.
  self.text:ClearText()
  self.sunderDisplayText = text
  self.sunderSecretText = not isAccessible(text)
  self.text:SetText(text)
end

-- Secret text must be cleared while its FontString is re-anchored, then restored.
function MessageLineMixin:WithTextDetached(callback)
  if self.sunderSecretText then self.text:ClearText() end
  callback()
  if self.sunderSecretText then self.text:SetText(self.sunderDisplayText) end
end

function MessageLineMixin:IsChainedTo(relativeTo, relativePoint, point)
  return self.sunderChained == true and self.sunderChainTarget == relativeTo
    and self.sunderChainPoint == relativePoint and self.sunderChainAnchorPoint == (point or "BOTTOMLEFT")
end

function MessageLineMixin:ClearChainAnchor()
  self:WithTextDetached(function ()
    self.text:ClearAllPoints()
  end)
  self.sunderChained = nil
  self.sunderChainTarget = nil
  self.sunderChainPoint = nil
  self.sunderChainAnchorPoint = nil
end

---
-- Chains this row's point (BOTTOMLEFT above relativeTo, TOPLEFT below it) to relativeTo,
-- or to the bottom of its parent when relativeTo is nil.
-- The text is the chain link and the row sizes itself around it, so Lua never reads secret bounds.
function MessageLineMixin:SetChainAnchor(relativeTo, relativePoint, point)
  point = point or "BOTTOMLEFT"
  self.sunderChained = true
  self.sunderChainTarget = relativeTo
  self.sunderChainPoint = relativePoint
  self.sunderChainAnchorPoint = point
  local padding = self.sunderTextPadding or 0
  self:WithTextDetached(function ()
    self.text:ClearAllPoints()
    self.text:SetPoint(
      point,
      relativeTo or self:GetParent(),
      relativeTo and relativePoint or "BOTTOMLEFT",
      getLeftTextPadding(),
      point == "BOTTOMLEFT" and padding or -padding
    )
  end)
end

---
-- Update layout and the measured height used for slide animations
function MessageLineMixin:UpdateFrame()
  local frameWidth = Core.db.profile.frameWidth
  local leftPadding = getLeftTextPadding()
  local textWidth = math.max(1, frameWidth - leftPadding - getLeftTextPadding())
  self.sunderLayoutWidth = frameWidth
  self:SetWidth(frameWidth)
  self:UpdateFadeSettings()
  self.text:SetWidth(textWidth)
  self.text:SetIndentedWordWrap(Core.db.profile.indentWordWrap)

  local textHeight, lineHeight = measureTextHeight(self.sunderDisplayText, textWidth)
  local padding = lineHeight * Core.db.profile.messageLinePadding
  self.sunderTextPadding = padding
  -- Secret rows still size correctly through anchors, but their height stays unknown to Lua.
  self.sunderHeight = textHeight and textHeight + padding * 2 or nil

  self:WithTextDetached(function ()
    self:ClearAllPoints()
    self:SetPoint("TOPLEFT", self.text, "TOPLEFT", -leftPadding, padding)
    self:SetPoint("BOTTOMLEFT", self.text, "BOTTOMLEFT", -leftPadding, -padding)
  end)
  self:SetChainAnchor(self.sunderChainTarget, self.sunderChainPoint, self.sunderChainAnchorPoint)

  updateBackground(self)
end

---
-- Update texture color based on setting
function MessageLineMixin:UpdateTextures()
  updateBackground(self)
end

local function CreateMessageLine(parent)
  local FadingFrameMixin = Core.Components.FadingFrameMixin
  local GradientBackgroundMixin = Core.Components.GradientBackgroundMixin

  local frame = CreateFrame("Frame", nil, parent)
  local object = Mixin(frame, FadingFrameMixin, GradientBackgroundMixin, MessageLineMixin)

  FadingFrameMixin.Init(object)
  GradientBackgroundMixin.Init(object)
  MessageLineMixin.Init(object)

  return object
end

local function CreateMessageLinePool(parent)
  return CreateObjectPool(
    function () return CreateMessageLine(parent) end,
    function (_, message)
      -- Reset all animations and timers
      message:QuickHide()
      message.text:ClearText()
      message.sunderDisplayText = nil
      message.sunderSecretText = nil
      -- Released rows must not keep links that could close a cycle once the row is reused.
      message:ClearChainAnchor()
      message.sunderHeight = nil
      message.sourceText = nil
      message.sourceFrame = nil
      message.receivedAt = nil
      message.sunderHideAt = nil
      message.sunderPreview = nil
    end
  )
end

Core.Components.CreateMessageLine = CreateMessageLine
Core.Components.CreateMessageLinePool = CreateMessageLinePool
