local Core, Constants = unpack(select(2, ...))
local WM = Core.Components.WindowManager
local Helpers = Core.Components.SlidingMessageFrameHelpers
local Adapter = {}

function Adapter:RetireNativeChrome()
  local native = self.chatFrame
  -- The geometry owner spans the entire detached body, including its grip.
  -- Like Glassy's native adapter, leave pointer ownership to visible content
  -- and shared chrome rather than enabling the underlying chat frame.
  native:EnableMouse(false)
  native:EnableMouseWheel(false)
  if native.SetMouseClickEnabled then native:SetMouseClickEnabled(false) end
  if native.SetMouseMotionEnabled then native:SetMouseMotionEnabled(false) end
  -- Stock update/fade handlers can undo Hide/SetAlpha. Retire their parents,
  -- while leaving their callbacks and the native filter bar untouched.
  if not self.retiredChrome then
    self.retiredChrome = CreateFrame("Frame", nil, UIParent)
    self.retiredChrome:Hide()
  end
  for _, key in ipairs({"ScrollBar", "scrollBar", "ScrollToBottomButton", "ResizeButton", "resizeButton", "buttonFrame"}) do
    local control = native[key]
    if control and control.SetParent then control:SetParent(self.retiredChrome) end
  end
  for _, suffix in ipairs({"ButtonFrame", "ResizeButton"}) do
    local control = _G[native:GetName()..suffix]
    if control then control:SetParent(self.retiredChrome) end
  end
  for _, suffix in ipairs({"Background", "TopLeftTexture", "TopRightTexture", "BottomLeftTexture", "BottomRightTexture",
    "LeftTexture", "RightTexture", "TopTexture", "BottomTexture"}) do
    local texture = _G[native:GetName()..suffix]
    if texture then texture:SetTexture(nil) end
  end
end

-- ChatFrame2 remains the native docking/geometry/event owner. Only its visual
-- children live in this clipped viewport: reparenting ChatFrame2 into the
-- detached shell would create a dependency cycle (the shell follows that frame).
function Adapter:LayoutNativeLines()
  local native = self.chatFrame
  local lines = native.visibleLines or {}
  for index, line in ipairs(lines) do
    line:SetWidth(self.viewport:GetWidth())
    if index == 1 then
      line:ClearAllPoints()
      local edge = native:GetInsertMode() == 1 and "TOPLEFT" or "BOTTOMLEFT"
      line:SetPoint(edge, self.viewport, edge)
    end
  end
end

function Adapter:UpdateScrollRail()
  local native = self.chatFrame
  local maximum = native:GetMaxScrollRange()
  local page = math.max(1, native:GetPagingScrollAmount())
  self.state.scrollAtBottom = native:GetScrollOffset() == 0
  -- Native offsets count messages from newest; shared rails count from the top.
  -- Never use retained-message pixel heights or change range at offset zero.
  WM:UpdateScrollRail(self, self:IsShown(), self:GetHeight(), maximum + page, page,
    maximum - native:GetScrollOffset(), function(_, value)
      native:SetScrollOffset(math.floor(math.max(0, native:GetMaxScrollRange() - value) + .5))
      native:ResetAllFadeTimes()
    end)
end

function Adapter:PageTranscript(direction)
  if direction < 0 then self.chatFrame:PageUp() else self.chatFrame:PageDown() end
end

function Adapter:ApplyCombatLogVisibility()
  local shown = self.chatFrame:IsShown() and not Core.db.profile.combatLogHidden
  self:SetShown(shown)
  if self.detachedContainer then self.detachedContainer:SetShown(shown) end
  -- Do not hide/re-show the native frame: that executes its restricted filter lifecycle.
  if self.chatFrame.FontStringContainer then self.chatFrame.FontStringContainer:SetShown(shown) end
  self:UpdateScrollRail()
end

function Adapter:RefreshLayoutGeometry()
  if self.applyingLayout or not self.layoutReady then return end
  self.applyingLayout = true
  local native, root = self.chatFrame, self:GetParent()
  local width = self.layoutWidth or Core.db.profile.frameWidth
  local top = Helpers.getMessageTopInset(true)
  local editorTop = WM:ContainedEditorSpace(root, self.layoutEditBox)
  local bodyHeight = Core.Components.SlidingMessageFrameMixin.GetMessageFrameHeight(self)
  self.config.width, self.config.height = width, bodyHeight
  self:ClearAllPoints()
  self:SetPoint("TOPLEFT", root, "TOPLEFT", 0, -top-editorTop)
  self:SetSize(width, bodyHeight)
  self:SetFrameStrata(root:GetFrameStrata())
  -- Surface below native links; shared rail above both. No transparent native
  -- scrolling child may cover the rail's independent hit rectangle.
  native:SetFrameStrata(root:GetFrameStrata())
  native:SetFrameLevel(root:GetFrameLevel()+1)
  self:SetFrameLevel(root:GetFrameLevel()+2)
  self.viewport:SetFrameLevel(self:GetFrameLevel()+1)
  native.FontStringContainer:SetFrameLevel(self.viewport:GetFrameLevel()+1)
  WM:RaiseWindowResizer(root,{native,self.viewport,native.FontStringContainer})
  self:RetireNativeChrome()
  Core.Components.SlidingMessageFrameMixin.DisableNativeScrollInput(self, native)
  if native.ScrollBar then native.ScrollBar:SetAlpha(0) end
  if native.ScrollToBottomButton then native.ScrollToBottomButton:SetAlpha(0) end
  local padding = WM:BodyPadding()
  self.viewport:ClearAllPoints()
  self.viewport:SetPoint("TOPLEFT", self, "TOPLEFT", padding, -padding)
  self.viewport:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -WM:ScrollRightInset(padding), padding)
  if native.isDocked then
    native:ClearAllPoints()
    native:SetPoint("TOPLEFT", root, "TOPLEFT", 0, -top)
    native:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT")
  end
  local font = _G.SunderMessageFont
  if font then native:SetFontObject(font) end
  native:SetFading(not Core.db.profile.chatAlwaysVisible)
  if native.SetTimeVisible and Core.db.profile.chatHoldTime then native:SetTimeVisible(Core.db.profile.chatHoldTime) end
  if native.SetFadeDuration and Core.db.profile.chatFadeOutDuration then native:SetFadeDuration(Core.db.profile.chatFadeOutDuration) end
  WM:UpdateContentExtent(root, bodyHeight, top+editorTop)
  -- Native RefreshLayout clears pooled text before our geometry hook runs.
  -- Do not resize/re-anchor live restricted FontStrings here during a drag.
  native:MarkLayoutDirty()
  self:UpdateScrollRail()
  self.applyingLayout = false
end

function Adapter:GetLayoutHeight()
  return self.layoutHeight or Core.db.profile.frameHeight
end

function Adapter:SetLayoutSize(width, height)
  self.layoutWidth, self.layoutHeight = width, height
  self:RefreshLayoutGeometry()
end

function Adapter:SetLayout(parent, width, height, editor, detached)
  local oldDetached = self.detachedContainer
  self.layoutEditBox, self.detachedContainer = editor, detached
  self:SetParent(parent)
  self.layoutReady = true
  self:SetLayoutSize(width, height)
  if oldDetached and oldDetached ~= detached then oldDetached:Hide() end
  self:ApplyCombatLogVisibility()
end

-- Capability gate: older clients retain the established renderer, rather than
-- reaching into an incompatible native message-frame implementation.
function Core.Components.CanHostNativeCombatLog(frame)
  return frame == _G.ChatFrame2 and frame.FontStringContainer
    and type(frame.CalculateNumVisibleLines) == "function"
    and type(frame.RefreshLayout) == "function"
    and type(frame.AddOnDisplayRefreshedCallback) == "function"
    and type(frame.GetScrollOffset) == "function"
    and type(frame.SetScrollOffset) == "function"
    and type(frame.GetMaxScrollRange) == "function"
end

function Core.Components.CreateNativeCombatLog(parent, native)
  local self = CreateFrame("Frame", nil, parent)
  Mixin(self, Adapter)
  Core.Libs.AceHook:Embed(self)
  self.nativeCombatLog = true
  self.chatFrame = native
  self.state = {isCombatLog=true, messages={}, scrollAtBottom=true}
  self.config = {}
  self.viewport = CreateFrame("Frame", nil, self)
  self.viewport:SetClipsChildren(true)
  self.viewport:EnableMouse(true)
  self.viewport:EnableMouseWheel(true)
  self.viewport:SetScript("OnMouseWheel", function(_, delta) native:ScrollByAmount(delta) end)
  self.viewport:SetScript("OnMouseDown", function(_, button)
    if button == "LeftButton" then Core:GetModule("UIManager"):SelectMessageInput(native, true) end
  end)
  -- Native FontStringContainer propagates hyperlinks to its parent. Preserve
  -- the original receiver after hosting it under the clipped shared viewport.
  self.viewport:SetHyperlinksEnabled(true)
  for _, event in ipairs({"OnHyperlinkClick", "OnHyperlinkEnter", "OnHyperlinkLeave"}) do
    self.viewport:SetScript(event, function(_, ...)
      local handler = native:GetScript(event)
      if handler then handler(native, ...) end
    end)
  end
  native.FontStringContainer:SetParent(self.viewport)
  native.FontStringContainer:ClearAllPoints()
  native.FontStringContainer:SetAllPoints(self.viewport)
  native.FontStringContainer:SetAlpha(1)
  native:SetAlpha(1)
  native:SetClampRectInsets(0,0,0,0)
  native:SetScrollAllowed(true)
  native:SetMaxLines(Helpers.getScrollbackLimit())
  self:RetireNativeChrome()
  local buttons = _G[native:GetName().."ButtonFrame"]
  if buttons then buttons:Hide() end
  -- Native controls continue receiving their own update callbacks, but only the
  -- shared rail is interactive. Never replace the native onScrollChanged callback.
  Core.Components.SlidingMessageFrameMixin.DisableNativeScrollInput(self, native)
  if native.ScrollBar then native.ScrollBar:SetAlpha(0) end
  if native.ScrollToBottomButton then native.ScrollToBottomButton:SetAlpha(0) end
  self:SetScript("OnMouseWheel", function(_, delta) native:ScrollByAmount(delta) end)
  self:EnableMouse(false)
  self:EnableMouseWheel(true)
  self:RawHook(native, "CalculateNumVisibleLines", function(frame)
    if not self.layoutReady then return self.hooks[frame].CalculateNumVisibleLines(frame) end
    local spacing = frame:CalculateLineSpacing()
    return spacing > 0 and math.ceil(self.viewport:GetHeight()/spacing)+1 or 0
  end, true)
  self:SecureHook(native, "RefreshLayout", function() self:LayoutNativeLines();self:UpdateScrollRail() end)
  self:SecureHook(native, "SetScrollOffset", function() self:UpdateScrollRail() end)
  native:AddOnDisplayRefreshedCallback(function() self:UpdateScrollRail() end)
  self:SecureHookScript(native, "OnShow", function() self:ApplyCombatLogVisibility() end)
  self:SecureHookScript(native, "OnHide", function() self:ApplyCombatLogVisibility() end)
  -- Dock/filter code may re-anchor ChatFrame2 after the shared shell refresh.
  self:SecureHook(native, "SetPoint", function()
    if native.isDocked then self:RefreshLayoutGeometry() end
  end)
  WM:RegisterTranscriptKeys(self, function(direction) self:PageTranscript(direction) end)
  self.subscriptions = {
    Core:Subscribe(Constants.EVENTS.EDIT_BOX_LAYOUT_CHANGED, function() self:RefreshLayoutGeometry() end),
    Core:Subscribe(Constants.EVENTS.EDIT_BOX_VISIBILITY_CHANGED, function() self:RefreshLayoutGeometry() end),
    Core:Subscribe(Constants.EVENTS.UPDATE_CONFIG, function(key)
      if key == "combatLogVisibility" then self:ApplyCombatLogVisibility()
      elseif key == "scrollbackLines" then native:SetMaxLines(Helpers.getScrollbackLimit())
      elseif key == "frameWidth" or key == "frameHeight" or key == "bodyPadding"
        or key == "tabMessageSpacing" or key == "combatLogBarLayout" or key == "font"
        or key == "messageFontSize" or key == "messageLeading" or key == "chatAlwaysVisible"
        or key == "chatHoldTime" or key == "chatFadeOutDuration" then
        self:RefreshLayoutGeometry()
      end
    end),
  }
  self:ApplyCombatLogVisibility()
  return self
end
