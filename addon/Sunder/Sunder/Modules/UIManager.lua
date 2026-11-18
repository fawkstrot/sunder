local Core, Constants, Utils = unpack(select(2, ...))
local UIManager = Core:GetModule("UIManager")

local CreateChatDock = Core.Components.CreateChatDock
local CreateChatTab = Core.Components.CreateChatTab
local CreateCombatLogBar = Core.Components.CreateCombatLogBar
local CreateDetachedChatDock = Core.Components.CreateDetachedChatDock
local CreateEditBox = Core.Components.CreateEditBox
local CreateMainContainerFrame = Core.Components.CreateMainContainerFrame
local CreateMoverFrame = Core.Components.CreateMoverFrame
local CreateSlidingMessageFramePool = Core.Components.CreateSlidingMessageFramePool

-- WoW provides these globals at runtime, so suppress Luacheck's undefined-global warning while localizing them.
-- luacheck: push ignore 113
local BNToastFrame = BNToastFrame
local ChatAlertFrame = ChatAlertFrame
local ChatFrameChannelButton = ChatFrameChannelButton
local ChatFrameMenuButton = ChatFrameMenuButton
local C_Timer = C_Timer
local CreateFrame = CreateFrame
local GetCVar = C_CVar and C_CVar.GetCVar or GetCVar
local NUM_CHAT_WINDOWS = NUM_CHAT_WINDOWS
local QuickJoinToastButton = QuickJoinToastButton
local SetCVar = C_CVar and C_CVar.SetCVar or SetCVar
local UIParent = UIParent
-- luacheck: pop

----
-- UIManager Module
function UIManager:OnInitialize()
  self.state = {windows = {}}
  self.pendingFrames = {}
  self.renderScheduled = false
end

function UIManager:GetChatWindow(chatFrame)
  local window = chatFrame and self.state.windows[chatFrame:GetName()] or nil
  return window and window.active and window or nil
end

function UIManager:GetSlidingMessageFrame(chatFrame)
  local window = self:GetChatWindow(chatFrame)
  return window and window.slidingMessageFrame or nil
end

function UIManager:GetVisibleSlidingMessageFrame(preferredChatFrame)
  local preferred = self:GetSlidingMessageFrame(preferredChatFrame)
  if preferred and preferred.PreviewAnimations and preferred:IsShown() then
    return preferred
  end

  for _, window in pairs(self.state.windows) do
    if window.active and window.slidingMessageFrame.PreviewAnimations and window.slidingMessageFrame:IsShown() then
      return window.slidingMessageFrame
    end
  end
end

-- Explicit surface clicks select the next native Enter destination. They never
-- open an editor, rewrite a draft, or take focus from non-chat controls.
function UIManager:SelectMessageInput(chatFrame,plainClick)
  if plainClick and ((IsShiftKeyDown and IsShiftKeyDown()) or (IsControlKeyDown and IsControlKeyDown()) or (IsAltKeyDown and IsAltKeyDown())) then return false end
  if Core.sunderMoverUnlocked or Core.sunderEllesmereEditing then return false end
  local window=self:GetChatWindow(chatFrame)
  if not window then return false end
  local room=Core.Components.WindowManager:GetChatRoom(chatFrame)
  if room and room.CanSend and not room:CanSend()then return false end
  local focus=GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
  if focus then
    local chatFocus=false
    for _,candidate in pairs(self.state.windows) do if candidate.editBox==focus then chatFocus=true;break end end
    if not chatFocus then return false end
  end
  local whispers=Core:GetModule("Whispers",true)
  if whispers and whispers.IsWhisper and whispers:IsWhisper(chatFrame) then
    whispers:SelectConversation(chatFrame,false)
    return true
  end
  local input=self:GetLayoutEditBox(window)
  if not input then return false end
  local util=_G.ChatFrameUtil
  local selectInput=util and util.SetLastActiveWindow or _G.ChatEdit_SetLastActiveWindow
  if not selectInput then return false end
  _G.SELECTED_CHAT_FRAME=chatFrame
  selectInput(input)
  return true
end

-- Retire an unavailable room as the next Enter destination without moving drafts.
function UIManager:ReleaseMessageInput(frame)
  if _G.SELECTED_CHAT_FRAME~=frame then return end
  local window=self:GetChatWindow(frame)
  local input=window and self:GetLayoutEditBox(window)
  if input and input.ClearFocus then input:ClearFocus()end
  if _G.ChatFrame1 and frame~=ChatFrame1 then self:SelectMessageInput(ChatFrame1)end
end

function UIManager:DockWindow(frame)
  if not frame or frame.isDocked then return end
  if InCombatLockdown() and frame:IsProtected()then
    Core:GetModule("Config"):Print("Return this window to General after combat.");return
  end
  if not FCF_DockFrame then Core:GetModule("Config"):Print("This client cannot dock this window.");return end
  FCF_DockFrame(frame)
  if FCF_SelectDockFrame then FCF_SelectDockFrame(frame)end
  self:ScheduleChatFrameLayout(frame)
end

function UIManager:CreateChatWindow(chatFrame, temporary)
  local existing = self:GetChatWindow(chatFrame)
  if existing then
    return existing
  end

  local slidingMessageFrame
  if Core.Components.CanHostNativeCombatLog and Core.Components.CanHostNativeCombatLog(chatFrame) then
    slidingMessageFrame = Core.Components.CreateNativeCombatLog(self.container, chatFrame)
  else
    slidingMessageFrame = self.slidingMessageFramePool:Acquire()
    slidingMessageFrame:Init(chatFrame)
  end
  local window = self.state.windows[chatFrame:GetName()] or {}
  window.active = true
  window.chatFrame = chatFrame
  window.slidingMessageFrame = slidingMessageFrame
  window.tab = CreateChatTab(slidingMessageFrame, self.dock)
  window.editBox = nil
  window.temporary = not not temporary
  self.state.windows[chatFrame:GetName()] = window
  return window
end

function UIManager:CreateChatEditBox(window)
  if window == nil or window.editBox then
    return window and window.editBox or nil
  end
  local nativeEditBox = window.chatFrame.editBox or _G[window.chatFrame:GetName().."EditBox"]
  if not nativeEditBox then return nil end

  local editBox = CreateEditBox(self.container, nativeEditBox, false)
  window.editBox = editBox
  if self.moverFrame and window.chatFrame ~= _G.ChatFrame1 then
    self.moverFrame:AddBoundsRegion(editBox, function ()
      return window.active and window.chatFrame.isDocked and editBox.sunderEntryVisible
    end)
  end
  self.container:AddHoverRegion(editBox)
  self.container:AddHoverRegion(editBox.dynamicMessageArea)
  return editBox
end

function UIManager:ReleaseChatWindow(chatFrame)
  local window = self:GetChatWindow(chatFrame)
  if window == nil or not window.temporary then
    return false
  end

  local slidingMessageFrame = window.slidingMessageFrame
  self.pendingFrames[slidingMessageFrame] = nil
  self.slidingMessageFramePool:Release(slidingMessageFrame)
  if window.detachedLayout then
    window.detachedLayout.container:Hide()
  end
  window.active = false
  window.slidingMessageFrame = nil
  window.tab = nil
  window.editBox = nil
  return true
end

function UIManager:CreateDetachedLayout(window)
  local chatFrame = window.chatFrame
  local container = CreateFrame("Frame", nil, UIParent)
  container:SetPoint("TOPLEFT", chatFrame, "TOPLEFT", 0, Constants.DOCK_HEIGHT)
  container:SetPoint("BOTTOMRIGHT", chatFrame, "BOTTOMRIGHT")
  container:SetFrameStrata(chatFrame:GetFrameStrata())
  container:SetFrameLevel(chatFrame:GetFrameLevel() + 1)

  local layout = {
    chatFrame = chatFrame,
    container = container,
    dock = CreateDetachedChatDock(container, window.tab),
  }
  window.detachedLayout = layout
  self.container:AddHoverRegion(container)

  container:SetScript("OnSizeChanged", function ()
    local renderer = window.slidingMessageFrame
    if chatFrame.isDocked or not renderer or renderer.chatFrame ~= chatFrame
      or renderer.detachedContainer ~= container then return end

    renderer:SetLayoutSize(container:GetWidth(), container:GetHeight())
    if self.combatLogBar and self.combatLogBar.slidingMessageFrame == renderer then
      self.combatLogBar:UpdateLayout()
    end
  end)
  Core.Components.WindowManager:RegisterNativeSurface(container,layout.dock)
  return layout
end

function UIManager:RefreshChatFrameLayout(chatFrame)
  local window = self:GetChatWindow(chatFrame)
  if window == nil then
    return
  end

  if window.slidingMessageFrame.DisableNativeScrollInput then window.slidingMessageFrame:DisableNativeScrollInput(chatFrame)end
  local room=Core.Components.WindowManager:GetChatRoom(chatFrame)
  if room and room.LayoutWindow and room:LayoutWindow(window) then return end
  local whispers = Core:GetModule("Whispers", true)
  if whispers and whispers.LayoutWindow and whispers:LayoutWindow(window) then return end
  local slidingMessageFrame = window.slidingMessageFrame
  local editBox = self:GetLayoutEditBox(window)
  local layout = window.detachedLayout
  if chatFrame.isDocked then
    if editBox then
      editBox:SetSunderParent(self.container, false)
    end
    slidingMessageFrame:SetLayout(self.container, nil, nil, editBox, nil)
    if self.combatLogBar and self.combatLogBar.slidingMessageFrame == slidingMessageFrame then
      self.combatLogBar:SetSunderParent(self.container, false, self.dock)
    end
    self.dock:UpdateTabOrder()
    return
  end

  if not InCombatLockdown() then
    Core.Components.WindowManager:ApplyNativeWindowMinimums(chatFrame)
    local width,height=Core.Components.WindowManager:ClampNativeWindowSize(chatFrame:GetWidth(),chatFrame:GetHeight())
    if width~=chatFrame:GetWidth() or height~=chatFrame:GetHeight() then chatFrame:SetSize(width,height) end
  end
  if layout == nil then
    layout = self:CreateDetachedLayout(window)
  else
    layout.dock:SetTab(window.tab)
  end

  if chatFrame.buttonFrame and chatFrame.buttonFrame.minimizeButton then
    chatFrame.buttonFrame.minimizeButton:Hide()
  end

  if editBox then
    editBox:SetSunderParent(layout.container, true)
  end

  slidingMessageFrame:SetLayout(
    layout.container,
    layout.container:GetWidth(),
    layout.container:GetHeight(),
    editBox or false,
    layout.container
  )
  if self.combatLogBar and self.combatLogBar.slidingMessageFrame == slidingMessageFrame then
    self.combatLogBar:SetSunderParent(layout.container, true, layout.dock)
  end
  self.dock:UpdateTabOrder()
end

function UIManager:ScheduleChatFrameLayout(chatFrame)
  if chatFrame == nil or self.layoutUpdates[chatFrame] then
    return
  end

  self.layoutUpdates[chatFrame] = true
  C_Timer.After(0, function ()
    self.layoutUpdates[chatFrame] = nil
    self:RefreshChatFrameLayout(chatFrame)
  end)
end

function UIManager:QueueFrameForUpdate(slidingMessageFrame)
  if slidingMessageFrame == nil or self.renderFrame == nil then
    return
  end

  self.pendingFrames[slidingMessageFrame] = true
  if not self.renderScheduled then
    self.renderScheduled = true
    self.renderFrame:SetScript("OnUpdate", self.renderOnUpdate)
  end
end

function UIManager:ProcessPendingFrames()
  self.renderScheduled = false
  self.renderFrame:SetScript("OnUpdate", nil)

  local pendingFrames = self.pendingFrames
  self.pendingFrames = {}
  for slidingMessageFrame in pairs(pendingFrames) do
    if slidingMessageFrame.chatFrame then
      slidingMessageFrame:OnFrame()
    end
  end

  if next(self.pendingFrames) and not self.renderScheduled then
    self.renderScheduled = true
    self.renderFrame:SetScript("OnUpdate", self.renderOnUpdate)
  end
end

-- The native dock owns selection and filters. Only its presentation changes.
function UIManager:RefreshMainResizeGrips()
  local movable = Core.Components.WindowManager:CanMove(self.mainControls:HubSettings())
  local visible = movable and not self.container.mainBodyClipped
  self.mainResize:SetShown(visible)
  self.moverFrame.resizeHandle:SetShown(visible)
end

function UIManager:SetMainMinimized(minimized, instant, edge)
  local root, dock, host = self.container, self.dock, self.mainControls
  local wm = Core.Components.WindowManager
  local expandedHeight = Core.db.profile.frameHeight
  local target = minimized and dock:GetHeight() or expandedHeight
  local from = root:GetHeight()
  root:SetScript("OnUpdate", nil)
  self.mainResize:FinishResize()
  self.moverFrame.resizeHandle:FinishResize()
  self.moverFrame:StopDragging()
  local settings=host:HubSettings()
  if minimized and edge then settings.minimizeEdge=edge end
  root.mainBottomAnchored=(minimized or root.mainBodyClipped) and settings.minimizeEdge=="BOTTOM"
  wm:AnchorMainContainer(root,self.moverFrame)
  if host.minimized~=minimized then dock:ScheduleTabOrder() end
  host.minimized = minimized
  host:HubSettings().minimized = minimized
  if minimized then
    local focus = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
    if focus and focus.sunderParent == root and focus.ClearFocus then focus:ClearFocus() end
  end
  dock.mainMinimized = minimized
  dock:QuickShow()
  root.mainBodyHidden = false
  root.mainBodyClipped = true
  root:SetClipsChildren(true)
  self:RefreshMainResizeGrips()
  if self.combatLogBar then self.combatLogBar:UpdateVisibility() end
  wm:ApplyNativeSurface(root, dock)
  wm:RefreshRoomActions(host)
  local function finish()
    root.mainBodyClipped = minimized
    root.mainBodyHidden = minimized
    root:SetHeight(minimized and dock:GetHeight() or Core.db.profile.frameHeight)
    if not minimized and root.mainBottomAnchored then
      root.mainBottomAnchored=false
      wm:AnchorMainContainer(root,self.moverFrame)
    end
    root:SetClipsChildren(minimized)
    self:RefreshMainResizeGrips()
    if self.combatLogBar then self.combatLogBar:UpdateVisibility() end
    wm:ApplyNativeSurface(root, dock)
    if not minimized then dock:UpdateAutomaticVisibility() end
  end
  if instant or from == target then finish(); return end
  wm:AnimateHeight(root, from, target, function(height) root:SetHeight(height) end, finish)
end

function UIManager:ToggleMainMaximized()
  local wm, profile = Core.Components.WindowManager, Core.db.profile
  local host = self.mainControls
  if InCombatLockdown() or not wm:CanMove(host:HubSettings()) then return end
  self:SetMainMinimized(false, true)
  local restore = profile.mainChatRestore
  if restore then
    profile.frameWidth, profile.frameHeight = restore.width, restore.height
    profile.positionAnchor = restore.anchor
    profile.mainChatRestore = nil
  else
    local width, height = wm:MaximizedSize(100)
    local anchor = profile.positionAnchor
    profile.mainChatRestore = {width=profile.frameWidth, height=profile.frameHeight,
      anchor={point=anchor.point,xOfs=anchor.xOfs,yOfs=anchor.yOfs},
      maximizedWidth=width, maximizedHeight=height}
    profile.frameWidth, profile.frameHeight = width, height
    profile.positionAnchor = {point="CENTER", xOfs=0, yOfs=0}
  end
  for _,key in ipairs({"frameWidth","frameHeight","framePosition"}) do
    Core:Dispatch(Constants.ACTIONS.UpdateConfig(key))
  end
  self.moverFrame:UpdateLayoutBounds()
  self.dock:UpdateTabOrder()
  host.maximized = profile.mainChatRestore ~= nil
  wm:RefreshRoomActions(host)
end

function UIManager:CreateRootFrames()
  self.renderFrame = CreateFrame("Frame", "SunderUpdaterFrame", UIParent)
  self.renderOnUpdate = function ()
    self:ProcessPendingFrames()
  end

  self.moverFrame = CreateMoverFrame("SunderMoverFrame", UIParent)
  self.container = CreateMainContainerFrame("SunderFrame", UIParent)
  self.container:SetPoint("TOPLEFT", self.moverFrame)
  self.moverFrame:AddBoundsRegion(self.container)
  self.dock = CreateChatDock(self.container)
  local wm=Core.Components.WindowManager
  wm:RegisterNativeSurface(self.container,self.dock)
  self.container:AddHoverRegion(self.dock.overflowButton.list)
  self.slidingMessageFramePool = CreateSlidingMessageFramePool(self.container)
end

function UIManager:InstallMainControls()
  local wm=Core.Components.WindowManager
  self.mainResize=self.moverFrame:CreateStandardResizer(self.container)
  local host = {maximized=Core.db.profile.mainChatRestore ~= nil}
  function host:HubSettings() return wm:Settings("main") end
  self.mainControls = host
  wm:CreateNativeHeader(self.dock,{
    host=host,
    collapse=function(edge)if not InCombatLockdown() then self:SetMainMinimized(not host.minimized,false,edge) end end,
    maximize=function()self:ToggleMainMaximized()end,
    onLockChanged=function()
      self.moverFrame:StopDragging()
      self.moverFrame.resizeHandle:FinishResize()
      self.mainResize:FinishResize()
      self:RefreshMainResizeGrips()
      wm:RefreshRoomActions(host)
    end,
    settings=function()return wm:Settings("main")end,
    settingsAction=function()Core:GetModule("Config"):OpenSettings("windows")end,
    start=function()if wm:CanMove(wm:Settings("main"))then self.moverFrame:StartDragging()end end,
    stop=function()self.moverFrame:StopDragging()end,
  })
  self:RefreshMainResizeGrips()
  host.hubActionButtons.Maximize.windowEnabled=function()return not InCombatLockdown() and wm:CanMove(host:HubSettings())end
  host.hubActionButtons.CollapseTop.windowEnabled=function()return not InCombatLockdown()end
  host.hubActionButtons.CollapseBottom.windowEnabled=host.hubActionButtons.CollapseTop.windowEnabled
  self.container:RegisterEvent("PLAYER_REGEN_DISABLED")
  self.container:RegisterEvent("PLAYER_REGEN_ENABLED")
  self.container:SetScript("OnEvent",function()wm:RefreshRoomActions(host)end)
  wm:RefreshRoomActions(host)
  Core:Subscribe(Constants.EVENTS.UPDATE_CONFIG,function(key)
    if key ~= "frameWidth" and key ~= "frameHeight" then return end
    local profile=Core.db.profile
    local restore=profile.mainChatRestore
    if restore and (restore.maximizedWidth~=profile.frameWidth or restore.maximizedHeight~=profile.frameHeight) then
      profile.mainChatRestore=nil
    end
    host.maximized=profile.mainChatRestore~=nil
    wm:RefreshRoomActions(host)
  end)
  Core:Subscribe(Constants.EVENTS.EDIT_BOX_VISIBILITY_CHANGED,function(visible,box)
    if visible and box and box.sunderParent==self.container and box:HasFocus() and host.minimized then
      self:SetMainMinimized(false,true)
    end
  end)
  self.dock:ScheduleTabOrder()
end

function UIManager:InitializeChatWindows()
  local initiallyShownChatFrame

  for i=1, NUM_CHAT_WINDOWS do
    local chatFrame = _G["ChatFrame"..i]
    if chatFrame:IsShown() and chatFrame.isDocked then
      initiallyShownChatFrame = chatFrame
    end

    self:CreateChatWindow(chatFrame, false)
  end

  for i=1, NUM_CHAT_WINDOWS do
    self:CreateChatEditBox(self:GetChatWindow(_G["ChatFrame"..i]))
  end

  for i=1, NUM_CHAT_WINDOWS do
    self:RefreshChatFrameLayout(_G["ChatFrame"..i])
  end

  self.dock:RestoreSelectedTab(initiallyShownChatFrame)
  -- Restoring Blizzard's selected chat window can show the dock again. Reapply the configured persistent state without waiting for the normal hide delay.
  if Core.db.profile.chatAlwaysVisible then
    self.dock:QuickShow()
  else
    self.dock:QuickHide()
  end
end

function UIManager:TryInitializeCombatLogBar()
  if self.combatLogBar then
    return true
  end

  local slidingMessageFrame = self:GetSlidingMessageFrame(_G.ChatFrame2)
  self.combatLogBar = CreateCombatLogBar(self.container, slidingMessageFrame)
  if self.combatLogBar then
    self:RefreshChatFrameLayout(_G.ChatFrame2)
    self.container:AddHoverRegion(self.combatLogBar)
    self.moverFrame:AddBoundsRegion(self.combatLogBar, function ()
      return
        _G.ChatFrame2.isDocked and
        slidingMessageFrame:IsShown() and
        not Core.db.profile.combatLogHidden and
        Core.db.profile.combatLogBarPosition ~= "HIDDEN"
    end)
  end
  if self.combatLogBar and Core.db.profile.combatLogHidden then
    slidingMessageFrame:ApplyCombatLogVisibility()
  end
  return self.combatLogBar ~= nil
end

function UIManager:InitializeCombatLog()
  if not self:TryInitializeCombatLogBar() then
    self.combatLogLoader = CreateFrame("Frame", nil, UIParent)
    self.combatLogLoader:RegisterEvent("ADDON_LOADED")
    self.combatLogLoader:SetScript("OnEvent", function (_, _, addonName)
      if addonName == "Blizzard_CombatLog" and self:TryInitializeCombatLogBar() then
        self.combatLogLoader:UnregisterAllEvents()
      end
    end)
  end
end

function UIManager:ConfigureNativeChat()
  local mainWindow = self:GetChatWindow(_G.ChatFrame1)
  self.editBox = mainWindow and mainWindow.editBox or CreateEditBox(self.container)
  self.moverFrame:AddBoundsRegion(self.editBox)
  self.moverFrame:SetLayoutRegions(self.container, self.editBox)

  -- Fix Battle.net Toast frame position
  if ChatAlertFrame then
    ChatAlertFrame:ClearAllPoints()
    ChatAlertFrame:SetPoint("BOTTOMLEFT", self.container, "TOPLEFT", 15, 10)
    if BNToastFrame then
      BNToastFrame:ClearAllPoints()
      BNToastFrame:SetPoint("BOTTOMLEFT", ChatAlertFrame, "BOTTOMLEFT", 0, 0)
    end
  end

  -- Hide other chat elements
  if Constants.ENV == "retail" and QuickJoinToastButton then
    QuickJoinToastButton:Hide()
  end

  if ChatFrameChannelButton then ChatFrameChannelButton:Hide() end
  if ChatFrameMenuButton then ChatFrameMenuButton:Hide() end

  -- New version alert
  --@non-debug@
  if Core.db.global.version == nil or Utils.versionGreaterThan(Core.Version, Core.db.global.version) then
    Utils.notify("Sunder has just been updated. |cFFFFFF00|Hgarrmission:Sunder:opennews|h[See what's new]|h|r")
    Core.db.global.version = Core.Version
  end
  --@end-non-debug@--

  -- Native per-window inputs require IM mode; Classic always chooses ChatFrame1.
  -- Keep Blizzard's secure input-selection functions intact.
  if GetCVar("chatStyle") ~= "im" then
    SetCVar("chatStyle", "im")
  end
end

function UIManager:HookChatWindowLifecycle()
  self:RawHook("FCF_OpenTemporaryWindow", function (...)
    local chatFrame = self.hooks["FCF_OpenTemporaryWindow"](...)
    if chatFrame == nil then
      return nil
    end

    local window = self:GetChatWindow(chatFrame)
    if window == nil then
      window = self:CreateChatWindow(chatFrame, true)
      self:CreateChatEditBox(window)
      self:RefreshChatFrameLayout(chatFrame)
    end

    -- Blizzard copies the conversation into the new window before Sunder renders it, and removes it from
    -- the source window, so both show their native history again.
    -- Demo mode keeps showing sample chat and reloads real history itself when it ends.
    local function reload(frame)
      if frame and frame.state and not frame.state.demo then frame:ReloadMessagesFromChatFrame() end
    end
    local sourceChatFrame = select(3, ...)
    if sourceChatFrame then
      reload(window.slidingMessageFrame)
      local sourceWindow = self:GetChatWindow(sourceChatFrame)
      reload(sourceWindow and sourceWindow.slidingMessageFrame)
    end

    local whispers = Core:GetModule("Whispers", true)
    if whispers and whispers.OnWindowOpened then whispers:OnWindowOpened(chatFrame) end
    return chatFrame
  end, true)

  -- Close window
  self:RawHook("FCF_Close", function (chatFrame)
    local history=Core:GetModule("WhisperTabs",true)
    if history and history.BeforeClose then
      local ok,err=pcall(history.BeforeClose,history,chatFrame)
      if not ok then
        Core.db.char.whisperHistoryError=tostring(err)
        Core:GetModule("Config"):Print("Unable to save this conversation. It has been kept open; try again after reloading.")
        return
      end
    end
    local room=Core.Components.WindowManager:GetChatRoom(chatFrame)
    if room and room.OnWindowClosed then
      local ok,err=pcall(room.OnWindowClosed,room,chatFrame)
      if not ok then
        Core.db.char.guildRoomHistoryError=tostring(err)
        Core:GetModule("Config"):Print("Unable to save this chat room. The window has been kept open; try again after reloading.")
        return
      end
    end
    self.hooks["FCF_Close"](chatFrame)
    self:ReleaseChatWindow(chatFrame)
  end, true)

  local function hookLayoutChange(functionName)
    if type(_G[functionName]) == "function" and not self:IsHooked(functionName) then
      self:SecureHook(functionName, function (chatFrame)
        self:ScheduleChatFrameLayout(chatFrame)
      end)
    end
  end
  hookLayoutChange("FCF_DockFrame")
  hookLayoutChange("FCF_UnDockFrame")
  hookLayoutChange("FCF_StopDragging")
end

function UIManager:OnEnable()
  self.layoutUpdates = {}
  self:CreateRootFrames()
  self:InitializeChatWindows()
  self:InitializeCombatLog()
  self:ConfigureNativeChat()
  self:HookChatWindowLifecycle()

  -- Poll hover state at a low rate. Message queues use the work-driven render frame above.
  self.mouseoverTicker = C_Timer.NewTicker(0.05, function ()
    self.container:OnFrame()
    if Core.sunderMoverUnlocked then
      self.moverFrame:UpdateBounds()
      for _, window in pairs(self.state.windows) do
        if window.active and window.detachedLayout and not window.chatFrame.isDocked then
          window.detachedLayout.dock:UpdateMoverBounds()
        end
      end
    end
  end)
  self:InstallMainControls()
  if self.mainControls:HubSettings().minimized then self:SetMainMinimized(true,true) end
end

function UIManager:GetLayoutEditBox(window)
  local whispers=Core:GetModule("Whispers",true)
  if whispers and whispers.LayoutEditBox then return whispers:LayoutEditBox(window) end
  return window.editBox
end
