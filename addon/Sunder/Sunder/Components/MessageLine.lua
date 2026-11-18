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

-- Calendar boundaries are presentation only. Native line IDs and saved text stay intact.
local Dates={}
Core.Components.TranscriptDates=Dates
function Dates:Day(receipt)
  return type(receipt)=="number" and receipt>0 and date("%Y-%m-%d",receipt) or nil
end
function Dates:Label(receipt)
  local day=self:Day(receipt)
  if not day then return "Date unknown" end
  local now=GetServerTime()
  local today=date("%Y-%m-%d",now)
  local calendar=date("*t",now)
  local yesterday=now-86400
  if type(calendar)=="table" then
    yesterday=time({year=calendar.year,month=calendar.month,day=calendar.day-1,hour=12})
  end
  local suffix=date("%b %d",receipt)
  if day==today then return "Today · "..suffix end
  if day==date("%Y-%m-%d",yesterday) then return "Yesterday · "..suffix end
  if date("%Y",receipt)~=date("%Y",now) then return date("%b %d, %Y",receipt) end
  return date("%a, %b %d",receipt)
end
function Dates:Boundary(receipt,previous,first,frame)
  if first or self:Day(receipt)~=self:Day(previous) then return self:Label(receipt) end
  if type(receipt)=="number" and type(previous)=="number" and receipt-previous>=3600 then
    local profile=Core.db.profile
    local format=profile.timestampFormat
    if frame and (frame.chatType=="WHISPER" or frame.chatType=="BN_WHISPER")
      and not profile.timestampAllWindows and profile.whispers then format=profile.whispers.timestampFormat end
    return date(format or "[%H:%M]",receipt)
  end
end
function Dates:Create(parent,pinned)
  local marker=CreateFrame("Frame",nil,parent)
  marker:EnableMouse(false)
  marker.label=marker:CreateFontString(nil,"OVERLAY","SunderMessageFont")
  marker.label:SetPoint("CENTER")
  marker.label:SetJustifyH("CENTER")
  marker.label:SetWordWrap(false)
  marker.label:SetTextColor(.46,.50,.55,1)
  marker.left=marker:CreateTexture(nil,"ARTWORK")
  marker.right=marker:CreateTexture(nil,"ARTWORK")
  for _,rule in ipairs({marker.left,marker.right}) do rule:SetHeight(1);rule:SetColorTexture(.6,.65,.7,.17) end
  marker.left:SetPoint("LEFT",marker,"LEFT")
  marker.left:SetPoint("RIGHT",marker.label,"LEFT",-7,0)
  marker.right:SetPoint("LEFT",marker.label,"RIGHT",7,0)
  marker.right:SetPoint("RIGHT",marker,"RIGHT")
  if pinned then
    marker:SetFrameLevel(parent:GetFrameLevel()+20)
    marker.backing=marker:CreateTexture(nil,"BACKGROUND")
    marker.backing:SetAllPoints()
    marker.backing:SetColorTexture(.025,.03,.04,.95)
  end
  function marker:Present(label,width)
    self:SetShown(label~=nil)
    if not label then return 0 end
    self.label:SetFontObject("SunderMessageFont")
    local font,size,flags=self.label:GetFont()
    size=math.max(9,(size or 12)*.78)
    if font then self.label:SetFont(font,size,flags) end
    self:SetWidth(math.max(1,width))
    self.left:SetShown(width>=64);self.right:SetShown(width>=64)
    self.label:SetWidth(math.max(1,width-32))
    self.label:SetText(label)
    local glyphWidth=self.label:GetStringWidth()
    if type(glyphWidth)=="number" then self.label:SetWidth(math.min(math.max(1,width-32),glyphWidth)) end
    local height=math.ceil(size+14)
    self:SetHeight(height)
    return height
  end
  marker:Hide()
  return marker
end
function Dates:Pinned(owner,parent,receipt,visible,width)
  if not owner.datePin and not visible then return end
  if not owner.datePin then
    owner.datePin=self:Create(parent,true)
    owner.datePin:SetPoint("TOPLEFT",parent,"TOPLEFT",Core.Components.WindowManager:BodyPadding(),0)
  end
  local pad=Core.Components.WindowManager:BodyPadding()
  owner.datePin:ClearAllPoints()
  owner.datePin:SetPoint("TOPLEFT",parent,"TOPLEFT",pad,0)
  owner.datePin:Present(visible and self:Label(receipt) or nil,
    math.max(1,width-pad-Core.Components.WindowManager:ScrollRightInset(pad)))
end

local MessageLineMixin = {}


local function applyWrap(text)
  text:SetWordWrap(true)
  if text.SetNonSpaceWrap then text:SetNonSpaceWrap(true) end
  if text.SetMaxLines then text:SetMaxLines(0) end
  text:SetIndentedWordWrap(Core.db.profile.indentWordWrap)
end

-- Every row is explicitly bound to its renderer. The clipping viewport is an
-- implementation detail, never a source of width or a reason to borrow General.
local function layoutMetrics(row)
  local owner=assert(row.sunderRenderer,"Message row requires its owning renderer")
  local width=owner:GetLayoutWidth()
  local clearance=(owner.windowSurface or owner.whisperFullSurface or owner.sharedFullSurface) and Core.Components.WindowManager:ScrollRightInset(0) or 0
  return width,clearance
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
  applyWrap(measureText)
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
  local frameWidth = layoutMetrics(self)
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
  local width=layoutMetrics(self)
  self:SetWidth(width)
  self:UpdateFadeSettings()
  updateBackground(self)

  if self.text == nil then
    self.text = self:CreateFontString(nil, "ARTWORK", "SunderMessageFont")
  end
  self.text:SetIndentedWordWrap(Core.db.profile.indentWordWrap)

  -- Hyperlink handling
  self:SetHyperlinksEnabled(true)
  self:EnableMouse(true)
  self:SetScript("OnMouseDown",function(_,button)
    if button=="LeftButton" then Core:GetModule("UIManager"):SelectMessageInput(self.sourceFrame,true) end
  end)

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
    self:ClearAllPoints()
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
    self:ClearAllPoints()
    self.text:ClearAllPoints()
    if self.sunderHeight then
      -- Readable rows have a measured height. Anchor the row itself, then its
      -- text inside it; do not make the parent's bounds depend on its child.
      self:SetHeight(self.sunderHeight)
      self:SetPoint(point, relativeTo or self:GetParent(), relativeTo and relativePoint or "BOTTOMLEFT")
      self.text:SetPoint("TOPLEFT", self, "TOPLEFT", Core.Components.WindowManager:BodyPadding(),
        -padding-(self.sunderDateHeight or 0))
      return
    end
    -- Restricted text cannot be measured in Lua. Retain its native geometry
    -- chain, clearing both sides before switching a recycled row's mode.
    local left = Core.Components.WindowManager:BodyPadding()
    self:SetPoint("TOPLEFT", self.text, "TOPLEFT", -left, padding+(self.sunderDateHeight or 0))
    self:SetPoint("BOTTOMLEFT", self.text, "BOTTOMLEFT", -left, -padding)
    self.text:SetPoint(
      point,
      relativeTo or self:GetParent(),
      relativeTo and relativePoint or "BOTTOMLEFT",
      Core.Components.WindowManager:BodyPadding(),
      point == "BOTTOMLEFT" and padding or -padding-(self.sunderDateHeight or 0)
    )
  end)
end

---
-- Update layout and the measured height used for slide animations
function MessageLineMixin:SetDateBoundary(receipt,previous,first)
  local label=Dates:Boundary(receipt,previous,first,self.sourceFrame)
  if self.sunderDateLabel==label then return end
  self.sunderDateLabel=label
  self:UpdateFrame()
end

function MessageLineMixin:UpdateFrame()
  local frameWidth,clearance = layoutMetrics(self)
  local leftPadding = Core.Components.WindowManager:BodyPadding()
  local textWidth = math.max(1, frameWidth - leftPadding - math.max(leftPadding,clearance))
  self.sunderLayoutWidth = frameWidth
  self:UpdateFadeSettings()
  self:WithTextDetached(function ()
    self:SetWidth(frameWidth)
    self.text:SetWidth(textWidth)
    applyWrap(self.text)
  end)

  local textHeight, lineHeight = measureTextHeight(self.sunderDisplayText, textWidth)
  local padding = lineHeight * Core.db.profile.messageLinePadding
  self.sunderTextPadding = padding
  -- Secret rows still size correctly through anchors, but their height stays unknown to Lua.
  local dateHeight=0
  if self.sunderDateLabel or self.dateDivider then
    if not self.dateDivider then
      self.dateDivider=Dates:Create(self)
      self.dateDivider:SetPoint("TOPLEFT",self,"TOPLEFT",leftPadding,0)
    end
    self.dateDivider:ClearAllPoints()
    self.dateDivider:SetPoint("TOPLEFT",self,"TOPLEFT",leftPadding,0)
    dateHeight=self.dateDivider:Present(self.sunderDateLabel,textWidth)
  end
  self.sunderDateHeight=dateHeight
  self.sunderHeight = textHeight and textHeight + padding * 2 + dateHeight or nil

  self:SetChainAnchor(self.sunderChainTarget, self.sunderChainPoint, self.sunderChainAnchorPoint)

  updateBackground(self)
end

---
-- Update texture color based on setting
function MessageLineMixin:UpdateTextures()
  updateBackground(self)
end

local function CreateMessageLine(parent,renderer)
  assert(renderer and renderer.GetLayoutWidth,"Message rows must be created by a renderer")
  local FadingFrameMixin = Core.Components.FadingFrameMixin
  local GradientBackgroundMixin = Core.Components.GradientBackgroundMixin

  local frame = CreateFrame("Frame", nil, parent)
  local object = Mixin(frame, FadingFrameMixin, GradientBackgroundMixin, MessageLineMixin)

  object.sunderRenderer=renderer
  FadingFrameMixin.Init(object)
  GradientBackgroundMixin.Init(object)
  MessageLineMixin.Init(object)

  return object
end

local function CreateMessageLinePool(parent,renderer)
  assert(renderer and renderer.GetLayoutWidth,"Message pools require an explicit renderer owner")
  return CreateObjectPool(
    function () return CreateMessageLine(parent,renderer) end,
    function (_, message)
      -- Reset all animations and timers
      message:QuickHide()
      message:SetScript("OnEnter",nil);message:SetScript("OnLeave",nil)
      message.text:ClearText()
      message.sunderDisplayText = nil
      message.sunderSecretText = nil
      -- Released rows must not keep links that could close a cycle once the row is reused.
      message:ClearChainAnchor()
      message.sunderHeight = nil
      message.sourceText = nil
      message.sourceFrame = nil
      message.sourceLineID=nil;message.sunderOwnMessage=nil
      message.receivedAt = nil
      message.sunderDateLabel=nil;message.sunderDateHeight=0
      if message.dateDivider then message.dateDivider:Hide() end
      message.sunderHideAt = nil
      message.sunderPreview = nil
    end
  )
end

Core.Components.CreateMessageLine = CreateMessageLine
Core.Components.CreateMessageLinePool = CreateMessageLinePool
