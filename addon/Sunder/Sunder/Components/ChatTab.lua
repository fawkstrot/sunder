local Core, Constants, Utils = unpack(select(2, ...))

local AceHook = Core.Libs.AceHook

local UnlockMover = Constants.ACTIONS.UnlockMover
local L = function(text) return Core:Localize(text) end

local Colors = Constants.COLORS

local UPDATE_CONFIG = Constants.EVENTS.UPDATE_CONFIG

-- WoW provides these globals at runtime, so suppress Luacheck's undefined-global warning while localizing them.
-- luacheck: push ignore 113
local CHAT_CHANNELS = CHAT_CHANNELS
local CHAT_CONFIGURATION = CHAT_CONFIGURATION
local CLOSE_CHAT_WINDOW = CLOSE_CHAT_WINDOW
local ChatConfigFrame = ChatConfigFrame
local DEFAULT_CHAT_FRAME = DEFAULT_CHAT_FRAME
local DISPLAY = DISPLAY
local FCF_GetNumActiveChatFrames = FCF_GetNumActiveChatFrames
local FCF_MinimizeFrame = FCF_MinimizeFrame
local FCF_NewChatWindow = FCF_NewChatWindow
local FCF_PopInWindow = FCF_PopInWindow
local FCF_RenameChatWindow_Popup = FCF_RenameChatWindow_Popup
local FCF_StopAlertFlash = FCF_StopAlertFlash
local FILTERS = FILTERS
local GameTooltip = GameTooltip
local IsCombatLog = IsCombatLog
local IsShiftKeyDown = IsShiftKeyDown
local Menu = Menu
local MenuUtil = MenuUtil
local MINIMIZE = MINIMIZE or "Minimize Window"
local Mixin = Mixin
local NEW_CHAT_WINDOW = NEW_CHAT_WINDOW
local NUM_CHAT_WINDOWS = NUM_CHAT_WINDOWS
local RENAME_CHAT_WINDOW = RENAME_CHAT_WINDOW
local ShowUIPanel = ShowUIPanel
local ToggleChannelFrame = ToggleChannelFrame
local UIDropDownMenu_AddButton = UIDropDownMenu_AddButton
local UIDropDownMenu_CreateInfo = UIDropDownMenu_CreateInfo
local UIDropDownMenu_Initialize = UIDropDownMenu_Initialize
local UNLOCK_WINDOW = UNLOCK_WINDOW
-- luacheck: pop

local tabTexs = {
  '',
  'Selected',
  'Highlight'
}

local retailTabTexs = {"Left", "Middle", "Right", "ActiveLeft", "ActiveMiddle", "ActiveRight", "HighlightLeft", "HighlightMiddle", "HighlightRight"}

---@class SunderChatTab: Button
---@field Text FontString
---@field glow Texture
---@field conversationIcon Texture?
---@field sunderHooks AceHook-3.0
local ChatTabMixin = {}

if Menu and Menu.ModifyMenu and MenuUtil and ToggleChannelFrame then
  Menu.ModifyMenu("MENU_FCF_TAB", function (owner, rootDescription)
    if owner and owner.slidingMessageFrame then
      local function insertBefore(text, button)
        local insertionIndex
        for index, description in rootDescription:EnumerateElementDescriptions() do
          if MenuUtil.GetElementText(description) == text then
            insertionIndex = index
            break
          end
        end
        rootDescription:Insert(button, insertionIndex)
      end

      local chatFrameName = owner:GetName():gsub("Tab$", "")
      local chatFrame = _G[chatFrameName]
      if chatFrame and not chatFrame.isDocked and FCF_MinimizeFrame then
        insertBefore(DISPLAY, MenuUtil.CreateButton(MINIMIZE, function ()
          FCF_MinimizeFrame(chatFrame, string.upper(chatFrame.buttonSide or "right"))
        end))
      end

      insertBefore(CHAT_CONFIGURATION, MenuUtil.CreateButton(CHAT_CHANNELS, function ()
        ToggleChannelFrame()
      end))

      if chatFrame and chatFrame ~= _G.ChatFrame2 then
        insertBefore(CHAT_CONFIGURATION, MenuUtil.CreateButton(L("Search messages"), function ()
          Core:GetModule("ChatCopy"):ShowSearch(chatFrame)
        end))
      end
    end
  end)
end

local function getLeftTextPadding()
  return math.max(0, tonumber(Core.db.profile.textLeftPadding) or Core.defaults.profile.textLeftPadding)
end

local UNREAD_COUNT_GAP = 4
local CONVERSATION_ICON_GAP = 6
local TITLE_ICONS = {inbox=true, windows=true, read=true, reply=true, favorite=true, pin=true}

-- Whisper tabs carry Blizzard's conversation icon; it takes room before the name.
function ChatTabMixin:GetIconWidth()
  local icon = self.conversationIcon
  if not (icon and icon:IsShown()) then icon = self.titleIcon end
  local gap = math.max(2, math.min(12, tonumber(Core.db.profile.chatTitleIconGap) or CONVERSATION_ICON_GAP))
  return icon and icon:IsShown() and icon:GetWidth() + gap or 0
end

-- Decoration belongs to the native tab: it inherits docking, clipping and fade.
-- No additional window or per-frame animation is needed.
function ChatTabMixin:UpdateTitleDecoration()
  local profile = Core.db.profile
  local native = self.conversationIcon and self.conversationIcon:IsShown()
  local override = (profile.chatTabIconOverrides or {})[self.chatFrame:GetName()]
  local enabled = profile.chatTitleIcons ~= false and override ~= "none" and not native
  if enabled and not self.titleIcon then self.titleIcon = self:CreateTexture(nil, "ARTWORK") end
  local selected, hovered = self:IsSelected(), self.sunderHovered
  local accent = Core:GetThemeColor("tabHighlightTextColor") or Colors.apache
  if self.titleIcon then
    local key = override
    if not key or key == "auto" then
      local types = self.chatFrame.messageTypeList or {}
      local guild = false
      for _, kind in pairs(types) do if kind == "GUILD" or kind == "OFFICER" then guild = true end end
      key = self.chatFrame == _G.ChatFrame2 and "read" or self.chatFrame.isTemporary and "reply" or guild and "windows" or "inbox"
    end
    if not TITLE_ICONS[key] then key = "inbox" end
    local icon = self.titleIcon
    if icon.sunderTitleKey ~= key then
      icon:SetTexture("Interface\\AddOns\\Sunder\\Media\\Icons\\"..key..".tga")
      icon.sunderTitleKey = key
    end
    local size = math.max(10, math.min(18, tonumber(profile.chatTitleIconSize) or 14))
    icon:SetSize(size, size); icon:ClearAllPoints(); icon:SetPoint("LEFT", getLeftTextPadding(), 0)
    if selected or hovered then icon:SetVertexColor(accent.r, accent.g, accent.b)
    else icon:SetVertexColor(0.74, 0.8, 0.88) end
    icon:SetAlpha((selected or hovered) and 0.9 or math.max(0.15, math.min(1, tonumber(profile.chatTitleIconOpacity) or 0.5)))
    icon:SetShown(enabled)
  end
  if not self.selectionLine then
    self.selectionLine = self:CreateTexture(nil, "OVERLAY")
    self.selectionLine:SetHeight(1)
    self.selectionLine:SetPoint("BOTTOMLEFT", getLeftTextPadding(), 0)
    self.selectionLine:SetPoint("BOTTOMRIGHT", -Constants.TEXT_RIGHT_PADDING, 0)
    self.hoverWash = self:CreateTexture(nil, "BACKGROUND"); self.hoverWash:SetAllPoints()
  end
  self.selectionLine:ClearAllPoints()
  self.selectionLine:SetPoint("BOTTOMLEFT", getLeftTextPadding(), 0)
  self.selectionLine:SetPoint("BOTTOMRIGHT", -Constants.TEXT_RIGHT_PADDING, 0)
  self.selectionLine:SetColorTexture(accent.r, accent.g, accent.b, 0.65)
  self.selectionLine:SetShown(profile.chatSelectionIndicator ~= false and selected)
  self.hoverWash:SetColorTexture(accent.r, accent.g, accent.b, 0.045)
  self.hoverWash:SetShown(profile.chatHoverWash and hovered or false)
end

function ChatTabMixin:GetLayoutWidth()
  local width = self:GetIconWidth() + self:GetTextWidth() + getLeftTextPadding() + Constants.TEXT_RIGHT_PADDING
  if self.unreadText and self.unreadText:IsShown() then
    width = width + UNREAD_COUNT_GAP + self.unreadText:GetStringWidth()
  end
  return width
end

-- Blizzard anchors the icon to its own tab art and label offsets, which leaves it low beside Sunder's label.
function ChatTabMixin:AnchorConversationIcon()
  local icon = self.conversationIcon
  if not icon then return end
  local hooks = self.sunderHooks.hooks[icon]
  local setPoint = hooks and hooks.SetPoint or icon.SetPoint
  icon:ClearAllPoints()
  setPoint(icon, "LEFT", self, "LEFT", getLeftTextPadding(), 0)
end

function ChatTabMixin:UpdateTextLayout()
  local leftPadding = getLeftTextPadding()
  self:AnchorConversationIcon()
  self:UpdateTitleDecoration()
  self.Text:ClearAllPoints()
  self.Text:SetPoint("LEFT", leftPadding + self:GetIconWidth(), 0)
  -- Blizzard insets the alert glow for its own tab art; span Sunder's icon, name, and count instead.
  if self.glow then
    self.glow:ClearAllPoints()
    self.glow:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", leftPadding, -2)
    self.glow:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -Constants.TEXT_RIGHT_PADDING, -2)
  end
  self:SetWidth(self:GetLayoutWidth())
end

-- Counts messages that arrive while a docked tab is not selected; selecting it clears the count.
function ChatTabMixin:AddUnreadMessage()
  if self.sunderWhisperManaged then return end
  if not (Core.db.profile.tabUnreadCount or self.sunderWhisperBadge) or not self.chatFrame.isDocked or self:IsSelected() then return end
  self:SetUnreadCount((self.sunderUnreadCount or 0) + 1)
end

function ChatTabMixin:SetUnreadCount(count)
  self.sunderUnreadCount = count
  local badgesEnabled = self.sunderWhisperManaged and self.sunderWhisperBadge
    or not self.sunderWhisperManaged and Core.db.profile.tabUnreadCount
  local shown = count > 0 and badgesEnabled
  if not shown and not self.unreadText then return end
  if not self.unreadText then
    self.unreadText = self:CreateFontString(nil, "OVERLAY", "SunderChatDockFont")
    -- Blizzard's tab resize widens the label past its text, so the count sits in the room added at the tab's right.
    self.unreadText:SetPoint("RIGHT", self, "RIGHT", -Constants.TEXT_RIGHT_PADDING, 0)
  end
  local color = Core:GetThemeColor("tabHighlightTextColor") or Colors.apache
  self.unreadText:SetTextColor(color.r, color.g, color.b, color.a or 1)
  self.unreadText:SetText(shown and (count > 99 and "99+" or tostring(count)) or "")
  self.unreadText:SetShown(shown)

  -- Only re-lay out the dock when the tab actually grows or shrinks.
  local width = self:GetLayoutWidth()
  if width ~= self.sunderLayoutWidth then
    self.sunderLayoutWidth = width
    self:UpdateTextLayout()
    if self.sunderDock then self.sunderDock:ScheduleTabOrder() end
  end
end

function ChatTabMixin:IsSelected()
  local dock = _G.GENERAL_CHAT_DOCK
  if dock and self.chatFrame.isDocked then
    return dock.selected == self.chatFrame
  end
  return _G.SELECTED_CHAT_FRAME == self.chatFrame
end

function ChatTabMixin:UpdateVisualState()
  self:UpdateTitleDecoration()
  -- Whisper tabs keep their own colors below, but their unread count still clears once they are read.
  if not self.sunderWhisperManaged and (self.sunderUnreadCount or 0) > 0 and self:IsSelected() then self:SetUnreadCount(0) end
  if self.chatFrame.isTemporary or self.sunderHooks.hooks[self.Text] == nil then
    return
  end

  local color = Core:GetThemeColor("tabTextColor") or Colors.apache
  if self:IsSelected() then
    color = Core:GetThemeColor("tabHighlightTextColor") or Colors.apache
  end
  if self.sunderHovered then
    color = Core:GetThemeColor("tabHighlightTextColor") or Colors.apache
  end

  self.sunderHooks.hooks[self.Text].SetTextColor(
    self.Text,
    color.r,
    color.g,
    color.b,
    1
  )
  self.Text:SetAlpha(color.a or 1)
end

function ChatTabMixin:ClearBackgroundTextures()
  for _, texName in ipairs(tabTexs) do
    for _, side in ipairs({"Left", "Middle", "Right"}) do
      local texture = _G[self:GetName()..texName..side]
      if texture then texture:SetTexture(nil) end
    end
  end
  for _, key in ipairs(retailTabTexs) do
    local texture = self[key]
    if texture then texture:SetTexture(nil) end
  end
end

function ChatTabMixin:Init(slidingMessageFrame, dock)
  self.sunderWhisperManaged, self.sunderWhisperBadge = false, nil
  self.slidingMessageFrame = slidingMessageFrame
  self.chatFrame = slidingMessageFrame.chatFrame
  self.sunderDock = dock
  local dropDown = _G[self.chatFrame:GetName().."TabDropDown"]

  self:ClearBackgroundTextures()

  self:SetHeight(Constants.DOCK_HEIGHT)
  self:SetNormalFontObject("SunderChatDockFont")
  -- A press shifts the label, and a layout while the tab is held would leave it shifted after release.
  self:SetPushedTextOffset(0, 0)
  -- Blizzard re-anchors the icon whenever a whisper tab is reused or changes type.
  if self.conversationIcon and not self.sunderHooks:IsHooked(self.conversationIcon, "SetPoint") then
    Utils.hookPresentation(self.sunderHooks, self.conversationIcon, "SetPoint", function ()
      self:UpdateTextLayout()
    end, true)
  end
  self:UpdateTextLayout()

  if not self.sunderHooks:IsHooked(self, "SetAlpha") then
    Utils.hookPresentation(self.sunderHooks, self, "SetAlpha", function (alpha)
      self.sunderHooks.hooks[self].SetAlpha(self, 1)
    end, true)
  end
  self:SetAlpha(1)

  if self.chatFrame == _G.ChatFrame2 and not self.sunderHooks:IsHooked(self, "Show") then
    Utils.hookPresentation(self.sunderHooks, self, "Show", function (tab)
      if Core.db.profile.combatLogHidden then
        tab:Hide()
      else
        self.sunderHooks.hooks[self].Show(tab)
      end
    end, true)
  end

  -- Set width dynamically based on text width
  if not self.sunderHooks:IsHooked(self, "SetWidth") then
    Utils.hookPresentation(self.sunderHooks, self, "SetWidth", function ()
      self.sunderHooks.hooks[self].SetWidth(self, self:GetLayoutWidth())
    end, true)
  end

  if not self.sunderHooks:IsHooked(self.Text, "SetTextColor") then
    Utils.hookPresentation(self.sunderHooks, self.Text, "SetTextColor", function (...)
      -- Temporary chat frames retain their color
      if self.chatFrame.isTemporary then
        self.sunderHooks.hooks[self.Text].SetTextColor(...)
      else
        self:UpdateVisualState()
      end
    end, true)
  end
  self:UpdateVisualState()

  if not self.sunderOnEnterInstalled then
    self.sunderOnEnterInstalled = true
    self:SetScript("OnEnter", function ()
      self.sunderHovered = true
      self:UpdateVisualState()
      if Core.db.profile.chatTabTooltips then
        GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
        GameTooltip:SetText(self.Text:GetText() or self.chatFrame:GetName(), 1, 1, 1)
        GameTooltip:AddLine(L("Click to select"), 0.8, 0.8, 0.8)
        GameTooltip:AddLine(L("Drag to reorder"), 0.8, 0.8, 0.8)
        GameTooltip:AddLine(L("Shift-click to copy"), 0.8, 0.8, 0.8)
        GameTooltip:AddLine(L("Right-click for chat options"), 0.8, 0.8, 0.8)
        GameTooltip:Show()
      end
    end)
  end
  if not self.sunderHooks:IsHooked(self, "OnLeave") then
    self.sunderHooks:SecureHookScript(self, "OnLeave", function ()
      self.sunderHovered = false
      self:UpdateVisualState()
      if GameTooltip:IsOwned(self) then
        GameTooltip:Hide()
      end
    end)
  end

  -- Don't highlight when frame is already visible
  if not self.sunderHooks:IsHooked(self.glow, "Show") then
    Utils.hookPresentation(self.sunderHooks, self.glow, "Show", function ()
      if not self.slidingMessageFrame:IsVisible() then
        self.sunderHooks.hooks[self.glow].Show(self.glow)
      elseif Constants.ENV == "retail" then
        self.glow:Hide()
      end
    end, true)
  end

  -- Let Blizzard select the tab in secure code before running Sunder's click actions.
  if not self.sunderHooks:IsHooked(self, "OnClick") then
    self.sunderHooks:SecureHookScript(self, "OnClick", function (_, button)
      FCF_StopAlertFlash(self.chatFrame)

      if button == "LeftButton" then
        dock:SaveSelectedTab(self.chatFrame)
      end

      if button == "LeftButton" and IsShiftKeyDown() then
        Core:GetModule("ChatCopy"):Show(self.chatFrame)
      end
    end)
  end

  -- Pooled temporary tabs can be initialized again; retain native handlers once.
  if not self.sunderDragHandlersSaved then
    self.sunderDragHandlersSaved = true
    self.sunderOriginalDragStart = self:GetScript("OnDragStart")
    self.sunderOriginalDragStop = self:GetScript("OnDragStop")
  end
  local originalOnDragStart = self.sunderOriginalDragStart
  local originalOnDragStop = self.sunderOriginalDragStop
  self:RegisterForDrag("LeftButton")
  self:SetScript("OnDragStart", function (tab, button)
    if GameTooltip:IsOwned(tab) then
      GameTooltip:Hide()
    end
    local parent = tab:GetParent()
    if not tab.chatFrame.isDocked then
      -- Always consume detached drags: native handlers bypass Sunder's lock.
      tab.sunderWindowDrag = true
      if parent.StartWindowDrag then parent:StartWindowDrag() end
      return
    end
    if not dock:StartTabDrag(tab, button) and originalOnDragStart then
      originalOnDragStart(tab, button)
    end
  end)
  self:SetScript("OnDragStop", function (tab, button)
    local parent = tab:GetParent()
    if tab.sunderWindowDrag then
      tab.sunderWindowDrag = nil
      if parent.StopWindowDrag then parent:StopWindowDrag() end
    elseif dock.tabDrag and dock.tabDrag.tab == tab then
      dock:StopTabDrag(tab)
    elseif originalOnDragStop then
      originalOnDragStop(tab, button)
    end
  end)

  -- Override context menu
  -- UIDropDownMenu_Initialize(dropDown, function ()
  --   local info = UIDropDownMenu_CreateInfo()

  --   if self.chatFrame == DEFAULT_CHAT_FRAME then
  --     -- Unlock chat window
  --     info = UIDropDownMenu_CreateInfo()
  --     info.text = UNLOCK_WINDOW
  --     info.notCheckable = 1
  --     info.func = function()
  --       Core:Dispatch(UnlockMover())
  --     end
  --     UIDropDownMenu_AddButton(info)

  --     -- Create new chat window
  --     info = UIDropDownMenu_CreateInfo()
  --     info.text = NEW_CHAT_WINDOW
  --     info.func = FCF_NewChatWindow
  --     info.notCheckable = 1
  --     if FCF_GetNumActiveChatFrames() == NUM_CHAT_WINDOWS then
  --       info.disabled = 1
  --     end
  --     UIDropDownMenu_AddButton(info)
  --   end

  --   -- Rename window
  --   info.text = RENAME_CHAT_WINDOW
  --   info.func = FCF_RenameChatWindow_Popup
  --   info.notCheckable = 1
  --   UIDropDownMenu_AddButton(info)

  --   -- Close chat window
  --   if self.chatFrame ~= DEFAULT_CHAT_FRAME and not IsCombatLog(self.chatFrame) then
  --     info = UIDropDownMenu_CreateInfo()
  --     info.text = CLOSE_CHAT_WINDOW
  --     info.func = FCF_PopInWindow
  --     info.arg1 = self.chatFrame
  --     info.notCheckable = 1
  --     UIDropDownMenu_AddButton(info)
  --   end

  --   -- Filter header
  --   info = UIDropDownMenu_CreateInfo()
  --   info.text = FILTERS
  --   info.isTitle = 1
  --   info.notCheckable = 1
  --   UIDropDownMenu_AddButton(info)

  --   -- Configure settings
  --   info = UIDropDownMenu_CreateInfo()
  --   info.text = CHAT_CONFIGURATION
  --   info.func = function() ShowUIPanel(ChatConfigFrame) end
  --   info.notCheckable = 1
  --   UIDropDownMenu_AddButton(info)
  -- end, "MENU")

  -- Listeners
  if self.subscriptions == nil then
    self.subscriptions = {
      Core:Subscribe(UPDATE_CONFIG, function (key)
        if (
          key == "frameWidth" or
          key == "frameHeight" or
          key == "font" or
          key == "tabFontSize" or
          key == "textLeftPadding" or key == "chatHeaderStyle"
        ) then
          self:UpdateTextLayout()
          dock:UpdateTabOrder()
        end

        if key == "tabTextColor" or key == "tabHighlightTextColor" then
          self:UpdateVisualState()
        end

        if key == "tabUnreadCount" or key == "tabHighlightTextColor" then
          self:SetUnreadCount(Core.db.profile.tabUnreadCount and self.sunderUnreadCount or 0)
        end

        if key == "chatTabTooltips" and not Core.db.profile.chatTabTooltips and GameTooltip:IsOwned(self) then
          GameTooltip:Hide()
        end
      end)
    }
  end

  dock:UpdateTabOrder()
end

Core.Components.CreateChatTab = function (slidingMessageFrame, dock)
  local frame = _G[slidingMessageFrame.chatFrame:GetName().."Tab"]
  local object = Mixin(frame, ChatTabMixin)
  object.sunderHooks = object.sunderHooks or AceHook:Embed({})
  object:Init(slidingMessageFrame, dock)
  return object
end
