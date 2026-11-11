local Core, Constants, Utils = unpack(select(2, ...))

local super = Utils.super
local EditBoxMixin = Core.Components.EditBoxMixin
local Helpers = Core.Components.EditBoxHelpers
local getVerticalPadding = Helpers.getVerticalPadding
local hasVisibleBackground = Helpers.hasVisibleBackground

local EditBoxVisibilityChanged = Constants.ACTIONS.EditBoxVisibilityChanged
local UPDATE_CONFIG = Constants.EVENTS.UPDATE_CONFIG
local CreateSeparatorFrame = Core.Components.CreateSeparatorFrame

-- WoW provides these globals at runtime, so suppress Luacheck's undefined-global warning while localizing them.
-- luacheck: push ignore 113
local C_ChatInfo = C_ChatInfo
local C_Timer = C_Timer
local CreateFrame = CreateFrame
local GetCurrentKeyBoardFocus = GetCurrentKeyBoardFocus
local InCombatLockdown = InCombatLockdown
local IsAltKeyDown = IsAltKeyDown
local IsControlKeyDown = IsControlKeyDown
-- luacheck: pop

local EDIT_BOX_RIGHT_PADDING = 8

local function isChatMessagingLocked()
  return C_ChatInfo and
    C_ChatInfo.InChatMessagingLockdown and
    C_ChatInfo.InChatMessagingLockdown()
end

local function setPropagateKeyboardInput(editBox, propagate)
  if InCombatLockdown() then
    return false
  end
  editBox:SetPropagateKeyboardInput(propagate)
  return true
end

local function getLeftTextPadding()
  return math.max(0, math.min(32, tonumber(Core.db.profile.bodyPadding) or 12))
end


local function hideExternalBackgrounds(editBox)
  local name = editBox:GetName()
  for _, suffix in ipairs({"Left", "Mid", "Right", "FocusLeft", "FocusMid", "FocusRight"}) do
    local region = _G[name..suffix]
    if region then
      region:Hide()
    end
  end

  -- Prat places its own backdrop inside Blizzard's edit box, so keep it hidden while Sunder supplies the styling.
  if editBox.pratFrame then
    editBox.pratFrame:Hide()
  end
end

-- Classic hides the box only after its background fades out.
function EditBoxMixin:HookClassicVisibility()
  self.sunderHooks:RawHook(self, "Show", function (frame)
    local wasVisible = frame:IsVisible()
    self.sunderHooks.hooks[frame].Show(frame)
    hideExternalBackgrounds(frame)
    if wasVisible and not self.sunderEntryVisible then
      self:ShowEntry(true)
    end
  end, true)

  self.sunderHooks:RawHook(self, "Hide", function (frame)
    if frame.sunderClearingFocus then
      return
    end

    if not frame:IsVisible() then
      self.sunderHooks.hooks[frame].Hide(frame)
      return
    end

    local messageAreaChanged = self.sunderEntryVisible
    if messageAreaChanged then
      self.sunderEntryVisible = false
      Core:Dispatch(EditBoxVisibilityChanged(false, self))
    end
    self.header:Hide()
    if self.headerSuffix then
      self.headerSuffix:Hide()
    end
    if frame:HasFocus() then
      frame.sunderClearingFocus = true
      frame:ClearFocus()
      frame.sunderClearingFocus = nil
    end
    self:AnimateBackgroundAlpha(0, function ()
      if not self.sunderEntryVisible then
        self.sunderHooks.hooks[frame].Hide(frame)
      end
    end)
    if messageAreaChanged then
      self:UpdateDynamicMessageArea()
    end
  end, true)
end

-- IM mode selects the correct native editor, but leaves its inactive box shown.
-- Change presentation only: do not Hide/Show it from secure activation hooks.
function EditBoxMixin:SyncTypingPresentation()
  if self.sunderClearingFocus then return end
  -- Closed input space is reused by messages; let their links receive clicks.
  self:EnableMouse(self:HasFocus())
  if self:HasFocus() then
    self.sunderInactiveFading = nil
    self:SetAlpha(1)
    self:ShowEntry(false)
  elseif self.sunderEntryVisible then
    local whispers=Core:GetModule("Whispers",true)
    if whispers and whispers.ReleaseReplyEditor then whispers:ReleaseReplyEditor(self) end
    self.sunderEntryVisible = false
    Core:Dispatch(EditBoxVisibilityChanged(false, self))
    self:UpdateDynamicMessageArea()
    self.sunderInactiveFading = true
    self:SetAlpha(1)
    self:AnimateBackgroundAlpha(0, function ()
      if not self:HasFocus() and not self.sunderClearingFocus then
        self.sunderInactiveFading = nil
        self:SetAlpha(0)
      end
    end)
  elseif not self.sunderInactiveFading then
    self:SetAlpha(0)
  end
end

function EditBoxMixin:Init(parent, useParentWidth)
  -- Hide default styling
  hideExternalBackgrounds(self)

  -- Blizzard chat edit boxes default to requiring Alt for cursor movement.
  -- Sunder owns the visible edit box, so use standard arrow-key behavior.
  self:SetAltArrowKeyMode(false)

  for _, suffix in ipairs({"Left", "Mid", "Right"}) do
    Utils.hookPresentation(self.sunderHooks, _G[self:GetName()..suffix], "Show", function (texture)
      texture:Hide()
    end, true)
  end

  -- Retail shows these focus textures again after Show(), using SetShown().
  for _, key in ipairs({"focusLeft", "focusMid", "focusRight"}) do
    local texture = self[key]
    if texture then texture:SetAlpha(0) end
  end

  -- New styling
  self.sunderParent = parent
  self.sunderUseParentWidth = useParentWidth == true
  self:UpdateAnchor()

  self:SetFontObject("SunderEditBoxFont")
  self:SetWidth(self:GetLayoutWidth())
  self.header:SetFontObject("SunderEditBoxFont")

  local function updateHeaderAnchor()
    self.header:ClearAllPoints()
    self.header:SetPoint("LEFT", getLeftTextPadding(), 0)
  end
  updateHeaderAnchor()

  self.sunderBackgroundAlpha = 1
  self:UpdateSunderBackground()

  if self.messageSeparator == nil then
    self.messageSeparator = CreateSeparatorFrame(self)
  end
  self:UpdateMessageSeparator()

  local Ypadding = self.header:GetLineHeight() * getVerticalPadding()
  self:SetHeight(self.header:GetLineHeight() + Ypadding * 2)

  local function applyTextInsets()
    Ypadding = self.header:GetLineHeight() * getVerticalPadding()
    self.sunderHooks.hooks[self].SetTextInsets(
      self,
      self.header:GetStringWidth() + getLeftTextPadding(),
      getLeftTextPadding(), Ypadding, Ypadding
    )
  end
  Utils.hookPresentation(self.sunderHooks, self, "SetTextInsets", applyTextInsets, true)
  applyTextInsets()

  if self.dynamicMessageArea == nil then
    self.dynamicMessageArea = CreateFrame("Frame", nil, self.sunderParent)
    self.dynamicMessageArea:SetPoint("TOPLEFT", self.sunderParent, "BOTTOMLEFT")
  end

  -- Workaround for editbox being open on login
  self.sunderInitialized = false

  super(self).HookScript(self, "OnShow", function ()
    hideExternalBackgrounds(self)
    if Constants.ENV == "retail" then self:SyncTypingPresentation()
    else self:ShowEntry(false) end
  end)

  super(self).HookScript(self,"OnAttributeChanged",function (_,attribute)
    if (attribute=="chatType" or attribute=="tellTarget") and self:HasFocus() and not self.sunderReplyRoutePending then
      self.sunderReplyRoutePending=true
      C_Timer.After(0,function ()
        self.sunderReplyRoutePending=nil
        local whispers=Core:GetModule("Whispers",true)
        if whispers and whispers.RouteReplyEditor then whispers:RouteReplyEditor(self) end
      end)
    end
  end)
  local altInputWatcher = CreateFrame("Frame")
  altInputWatcher:Hide()
  altInputWatcher:SetScript("OnUpdate", function (watcher)
    if IsAltKeyDown() or not setPropagateKeyboardInput(self, false) then
      return
    end
    watcher:Hide()
    if self:IsVisible() and not GetCurrentKeyBoardFocus() then
      self:SetFocus()
    end
  end)

  super(self).HookScript(self, "OnKeyDown", function (editBox, key)
    setPropagateKeyboardInput(editBox, false)
    if IsAltKeyDown() and not IsControlKeyDown() then
      -- Leave native history navigation and modifier presses with the edit box.
      if key ~= "UP" and key ~= "DOWN" and key ~= "LEFT" and key ~= "RIGHT"
        and key ~= "LALT" and key ~= "RALT" and key ~= "LSHIFT" and key ~= "RSHIFT"
        and setPropagateKeyboardInput(editBox, true)
      then
        -- Release text focus before the printable character arrives.
        -- WoW handles the actual binding; the draft never needs SetText.
        editBox.sunderClearingFocus = true
        editBox:ClearFocus()
        editBox.sunderClearingFocus = nil
        altInputWatcher:Show()
      end
      return
    end

    if not IsControlKeyDown() or IsAltKeyDown() then
      return
    end

    if isChatMessagingLocked() and (key == "U" or key == "K" or key == "Y") then
      return
    end

    if key == "E" then
      editBox:SetCursorPosition(editBox:GetNumLetters())
    elseif key == "U" then
      local text = editBox:GetText()
      local cursorPosition = editBox:GetCursorPosition()
      local killedText = text:sub(1, cursorPosition)
      if killedText ~= "" then
        editBox.sunderKillBuffer = killedText
      end
      editBox:SetText(text:sub(cursorPosition + 1))
      editBox:SetCursorPosition(0)
    elseif key == "K" then
      local text = editBox:GetText()
      local cursorPosition = editBox:GetCursorPosition()
      local killedText = text:sub(cursorPosition + 1)
      if killedText ~= "" then
        editBox.sunderKillBuffer = killedText
      end
      editBox:SetText(text:sub(1, cursorPosition))
      editBox:SetCursorPosition(cursorPosition)
    elseif key == "Y" and editBox.sunderKillBuffer then
      local text = editBox:GetText()
      local cursorPosition = editBox:GetCursorPosition()
      local newText = text:sub(1, cursorPosition)
        .. editBox.sunderKillBuffer
        .. text:sub(cursorPosition + 1)
      editBox:SetText(newText)
      editBox:SetCursorPosition(math.min(
        cursorPosition + #editBox.sunderKillBuffer,
        #editBox:GetText()
      ))
    end
  end)

  super(self).HookScript(self, "OnHide", function ()
    -- Retail closes the box when Alt-key bindings take focus; the Hide post-hook reopens it.
    if self.sunderClearingFocus then return end
    local whispers=Core:GetModule("Whispers",true)
    if whispers and whispers.ReleaseReplyEditor then whispers:ReleaseReplyEditor(self) end
    self.sunderInactiveFading = nil
    self:StopBackgroundAlphaTransition()
    self:SetBackgroundAlpha(1)
    if self.sunderEntryVisible then
      self.sunderEntryVisible = false
      Core:Dispatch(EditBoxVisibilityChanged(false, self))
      self:UpdateDynamicMessageArea()
    end
  end)

  if Constants.ENV == "retail" then
    super(self).HookScript(self, "OnEditFocusGained", function () self:SyncTypingPresentation() end)
    super(self).HookScript(self, "OnEditFocusLost", function () self:SyncTypingPresentation() end)
    -- Native IM deactivation sets alpha to 0.35. Keep inactive boxes transparent,
    -- or fully opaque only while their custom background is fading out.
    self.sunderHooks:SecureHook(self, "SetAlpha", function (frame, alpha)
      if frame.sunderApplyingAlpha or frame.sunderClearingFocus or frame:HasFocus() then return end
      local target = frame.sunderInactiveFading and 1 or 0
      if alpha ~= target then
        frame.sunderApplyingAlpha = true
        frame:SetAlpha(target)
        frame.sunderApplyingAlpha = nil
      end
    end)
    -- Blizzard's secure chat code shows and hides this box. Replacing those methods taints that code
    -- (for example Shift-clicking map pins), so Retail closes with the native Hide and skips the fade-out.
    self.sunderHooks:SecureHook(self, "Show", hideExternalBackgrounds)
    self.sunderHooks:SecureHook(self, "Hide", function (frame)
      if frame.sunderClearingFocus then frame:Show() end
    end)
  else
    self:HookClassicVisibility()
  end

  Core:Subscribe(UPDATE_CONFIG, function (key)
    if key == "font" or key == "editBoxFontSize" or key == "editBoxVerticalPadding" then
      Ypadding = self.header:GetLineHeight() * getVerticalPadding()
      self:SetHeight(self.header:GetLineHeight() + Ypadding * 2)
      applyTextInsets()
    end

    if key == "frameWidth" then
      self:SetWidth(self:GetLayoutWidth())
      self:UpdateSunderBackground()
      self:UpdateMessageSeparator()
    end

    if key == "bodyPadding" then
      updateHeaderAnchor()
      applyTextInsets()
    end

    if key == "editBoxBackgroundColor" or key == "backgroundFade" then
      self:UpdateSunderBackground()
      if key == "backgroundFade" then
        self:UpdateMessageSeparator()
      end
      if not hasVisibleBackground() then
        self:StopBackgroundAlphaTransition()
        self:SetBackgroundAlpha(1)
        -- Only Classic keeps a closed box visible while its background fades.
        if Constants.ENV ~= "retail" and not self.sunderEntryVisible and self:IsVisible() then
          self.sunderHooks.hooks[self].Hide(self)
        end
      end
    end

    if key == "editBoxAnchor" then
      self:UpdateAnchor()
      self:UpdateMessageSeparator()
    end

    if key == "editBoxMessageSeparatorColor" then
      self:UpdateMessageSeparator()
    end

    if (
      key == "font" or
      key == "frameWidth" or
      key == "editBoxFontSize" or
      key == "editBoxVerticalPadding" or
      key == "editBoxAnchor"
    ) then
      self:UpdateDynamicMessageArea()
    end
  end)

  self.sunderEntryVisible = Constants.ENV == "retail" and self:HasFocus()
    or Constants.ENV ~= "retail" and self:IsShown()
  if Constants.ENV == "retail" then self:SyncTypingPresentation() end
  Core:Dispatch(EditBoxVisibilityChanged(self.sunderEntryVisible, self))
  self:UpdateDynamicMessageArea()
  C_Timer.After(0, function ()
    self.sunderInitialized = true
  end)
end
