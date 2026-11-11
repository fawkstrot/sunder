local Core, Constants = unpack(select(2, ...))

local CreateSeparatorFrame = Core.Components.CreateSeparatorFrame

local MOUSE_ENTER = Constants.EVENTS.MOUSE_ENTER
local MOUSE_LEAVE = Constants.EVENTS.MOUSE_LEAVE
local EDIT_BOX_VISIBILITY_CHANGED = Constants.EVENTS.EDIT_BOX_VISIBILITY_CHANGED
local UPDATE_CONFIG = Constants.EVENTS.UPDATE_CONFIG

-- WoW provides these globals at runtime, so suppress Luacheck's undefined-global warning while localizing them.
-- luacheck: push ignore 113
local CreateFrame = CreateFrame
local Mixin = Mixin
-- luacheck: pop

local DetachedChatDockMixin = {}
Core.Components.DetachedChatDockMixin = DetachedChatDockMixin

function DetachedChatDockMixin:UpdateFadeSettings()
  self:SetFadeInDuration(Core.db.profile.chatFadeInDuration)
  self:SetFadeOutDuration(Core.db.profile.chatFadeOutDuration)
  self:SetFadeEasing(Core.db.profile.chatFadeEasing)
end

function DetachedChatDockMixin:UpdateAutomaticVisibility()
  if Core.db.profile.chatAlwaysVisible or self.typing then
    self:QuickShow()
  else
    self:HideDelay(Core.db.profile.chatHoldTime)
  end
end

function DetachedChatDockMixin:SetTyping(visible)
  self.editBoxVisible = not not visible
  local typing = self.editBoxVisible and Core.db.profile.chatShowWhileTyping or false
  if self.typing == typing then
    return
  end

  self.typing = typing
  if typing then
    self:Show()
  elseif not self.mouseOver then
    self:UpdateAutomaticVisibility()
  end
end

function DetachedChatDockMixin:UpdateStyle()
  local backgroundColor = Core.db.profile.headerBackgroundColor
  self:SetGradientBackground(backgroundColor, backgroundColor.a)
  self.messageSeparator:SetSeparatorColor(Core:GetThemeColor("tabMessageSeparatorColor"))
end

-- Move the native frame: Sunder's detached layout is anchored to it.
-- All detached movement follows Sunder edit mode, including locked native tabs.
function DetachedChatDockMixin:StartWindowDrag()
  local frame = self.tab and self.tab.chatFrame
  if not self.editMode or not frame or frame.isDocked then
    return false
  end
  if InCombatLockdown() and frame:IsProtected() then
    return false
  end
  if self.dragFrame then return true end
  self.dragFrame = frame
  self.dragWasMovable = frame:IsMovable()
  frame:SetMovable(true)
  frame:StartMoving()
  self:QuickShow()
  self.moverOverlay:SetScript("OnUpdate", function ()
    if not IsMouseButtonDown("LeftButton") then self:StopWindowDrag() end
  end)
  return true
end

function DetachedChatDockMixin:StopWindowDrag()
  local frame = self.dragFrame
  if not frame then return end
  self.dragFrame = nil
  self.moverOverlay:SetScript("OnUpdate", nil)
  frame:StopMovingOrSizing()
  frame:SetMovable(self.dragWasMovable)
  self.dragWasMovable = nil
  if not frame.isDocked and not frame.isTemporary and FCF_SavePositionAndDimensions then
    FCF_SavePositionAndDimensions(frame)
  end
  self:UpdateAutomaticVisibility()
end

function DetachedChatDockMixin:UpdateMoverBounds()
  local parent = self:GetParent()
  local left, bottom, width, height = parent:GetRect()
  if not (left and bottom and width and height) then return end
  local top, right = bottom + height, left + width
  local scale = parent:GetEffectiveScale()
  local function include(region)
    if not region then return end
    local l, b, w, h = region:GetRect()
    if not (l and b and w and h) then return end
    local ratio = region:GetEffectiveScale() / scale
    l, b, w, h = l * ratio, b * ratio, w * ratio, h * ratio
    left, bottom = math.min(left, l), math.min(bottom, b)
    right, top = math.max(right, l + w), math.max(top, b + h)
  end
  local frame = self.tab and self.tab.chatFrame
  local manager = Core:GetModule("UIManager")
  local window = frame and manager:GetChatWindow(frame)
  local editBox = window and window.editBox
  -- Below-chat input space is reused by messages while the input is closed.
  -- Above-chat input should only expand the outline while it is visible.
  if editBox and editBox.sunderParent == parent and (Core.db.profile.editBoxAnchor.position == "BELOW" or editBox.sunderEntryVisible) then
    include(editBox)
  end
  if frame == _G.ChatFrame2 and window and window.slidingMessageFrame:IsShown()
    and Core.db.profile.combatLogBarPosition ~= "HIDDEN" then
    include(manager.combatLogBar)
  end
  local parentLeft, parentBottom, _, parentHeight = parent:GetRect()
  local topOffset = top - (parentBottom + parentHeight)
  local bottomOffset = bottom - parentBottom
  local bounds = self.moverBounds
  if bounds and bounds.left == left and bounds.right == right
    and bounds.top == top and bounds.bottom == bottom then return end
  self.moverBounds = {left = left, right = right, top = top, bottom = bottom}
  self.moverOverlay:ClearAllPoints()
  self.moverOverlay:SetPoint("TOPLEFT", parent, "TOPLEFT", left - parentLeft, topOffset)
  self.moverOverlay:SetPoint("BOTTOMRIGHT", parent, "BOTTOMLEFT", right - parentLeft, bottomOffset)
end

function DetachedChatDockMixin:SetEditMode(unlocked)
  self.editMode = not not unlocked
  if not self.editMode then
    self:StopWindowDrag()
    if self.resizeHandle then self.resizeHandle:FinishResize() end
  end
  local frame = self.tab and self.tab.chatFrame
  self.moverOverlay:SetShown(self.editMode and frame ~= nil and not frame.isDocked)
  if self.editMode and frame and not frame.isDocked then self:UpdateMoverBounds() end
end

function DetachedChatDockMixin:CreateMoverOverlay(parent)
  -- Parent to the layout, not the fading header, so edit handles remain visible.
  local overlay = CreateFrame("Frame", nil, parent)
  self.moverOverlay = overlay
  overlay:SetAllPoints(parent)
  overlay:SetFrameStrata("DIALOG")
  overlay:SetFrameLevel(parent:GetFrameLevel() + 20)
  overlay:EnableMouse(true)
  overlay:RegisterForDrag("LeftButton")
  local fill = overlay:CreateTexture(nil, "BACKGROUND")
  fill:SetAllPoints()
  fill:SetColorTexture(0.22, 0.62, 0.78, 0.35)
  for _, side in ipairs({"TOP", "BOTTOM", "LEFT", "RIGHT"}) do
    local border = overlay:CreateTexture(nil, "BORDER")
    if side == "TOP" or side == "BOTTOM" then
      border:SetPoint(side.."LEFT")
      border:SetPoint(side.."RIGHT")
      border:SetHeight(2)
    else
      border:SetPoint("TOP"..side)
      border:SetPoint("BOTTOM"..side)
      border:SetWidth(2)
    end
    border:SetColorTexture(0.22, 0.62, 0.78, 1)
  end
  overlay:SetScript("OnEnter", function () fill:SetColorTexture(0.22, 0.62, 0.78, 0.5) end)
  overlay:SetScript("OnLeave", function () fill:SetColorTexture(0.22, 0.62, 0.78, 0.35) end)
  overlay:SetScript("OnDragStart", function () self:StartWindowDrag() end)
  overlay:SetScript("OnDragStop", function () self:StopWindowDrag() end)
  overlay:SetScript("OnHide", function () self:StopWindowDrag() end)
  self.resizeHandle = Core.Components.CreateResizeHandle(overlay, {
    minWidth = 296, minHeight = 120,
    allowed = function ()
      local frame = self.tab and self.tab.chatFrame
      return self.editMode and frame and not frame.isDocked
        and not (InCombatLockdown() and frame:IsProtected())
    end,
    begin = function ()
      self:StopWindowDrag()
      local frame = self.tab.chatFrame
      return frame, frame:GetWidth(), frame:GetHeight()
    end,
    apply = function (width, height) self.tab.chatFrame:SetSize(width, height) end,
    finish = function ()
      local frame = self.tab and self.tab.chatFrame
      if frame and not frame.isDocked and not frame.isTemporary and FCF_SavePositionAndDimensions then
        FCF_SavePositionAndDimensions(frame)
      end
    end,
  })
  overlay:Hide()
  self.editMode = not not Core.sunderMoverUnlocked
end

function DetachedChatDockMixin:SetTab(tab)
  if tab == nil then
    return
  end
  self.tab = tab
  self:SetEditMode(self.editMode)
  tab:SetParent(self)
  tab:SetFrameStrata("LOW")
  tab:ClearAllPoints()
  tab:SetPoint("LEFT", self, "LEFT", 0, 0)
  if tab.UpdateVisualState then
    tab:UpdateVisualState()
  end
end

function DetachedChatDockMixin:Init(parent)
  self.editBoxVisible = false
  self.mouseOver = false
  self.typing = false
  self:SetHeight(Constants.DOCK_HEIGHT)
  self:SetPoint("TOPLEFT", parent, "TOPLEFT")
  self:SetPoint("TOPRIGHT", parent, "TOPRIGHT")
  self:UpdateFadeSettings()
  self:EnableMouse(true)
  self:RegisterForDrag("LeftButton")
  self:SetScript("OnDragStart", function () self:StartWindowDrag() end)
  self:SetScript("OnDragStop", function () self:StopWindowDrag() end)
  self:CreateMoverOverlay(parent)

  self.messageSeparator = CreateSeparatorFrame(self)
  self.messageSeparator:SetPoint("BOTTOMLEFT")
  self.messageSeparator:SetPoint("BOTTOMRIGHT")
  self:UpdateStyle()
  self:SetScript("OnSizeChanged", function () self:UpdateStyle() end)

  self.subscriptions = {
    Core:Subscribe(Constants.EVENTS.LOCK_MOVER, function () self:SetEditMode(false) end),
    Core:Subscribe(Constants.EVENTS.UNLOCK_MOVER, function () self:SetEditMode(true) end),
    Core:Subscribe(MOUSE_ENTER, function ()
      self.mouseOver = true
      self:Show()
    end),
    Core:Subscribe(MOUSE_LEAVE, function ()
      self.mouseOver = false
      self:UpdateAutomaticVisibility()
    end),
    Core:Subscribe(EDIT_BOX_VISIBILITY_CHANGED, function (visible, editBox)
      if not editBox or editBox.sunderParent == self:GetParent() then self:SetTyping(visible) end
    end),
    Core:Subscribe(UPDATE_CONFIG, function (key)
      if key == "headerBackgroundColor" or key == "tabMessageSeparatorColor" or key == "backgroundFade" then
        self:UpdateStyle()
      elseif key == "chatFadeInDuration" or key == "chatFadeOutDuration" or key == "chatFadeEasing" then
        self:UpdateFadeSettings()
      elseif key == "chatAlwaysVisible" and (Core.db.profile.chatAlwaysVisible or not self.mouseOver) then
        self:UpdateAutomaticVisibility()
      elseif key == "chatShowWhileTyping" then
        self:SetTyping(self.editBoxVisible)
      end
    end),
  }

  if Core.db.profile.chatAlwaysVisible then
    self:QuickShow()
  else
    self:QuickHide()
  end
end

Core.Components.CreateDetachedChatDock = function (parent, tab)
  local FadingFrameMixin = Core.Components.FadingFrameMixin
  local GradientBackgroundMixin = Core.Components.GradientBackgroundMixin
  local frame = CreateFrame("Frame", nil, parent)
  local object = Mixin(frame, FadingFrameMixin, GradientBackgroundMixin, DetachedChatDockMixin)
  FadingFrameMixin.Init(object)
  GradientBackgroundMixin.Init(object)
  object:Init(parent)
  object:SetTab(tab)
  return object
end
