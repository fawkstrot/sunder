local Core, Constants = unpack(select(2,...))
-- Shared chrome policy; adapters keep native input, rendering and geometry ownership.
local Manager={}
Core.Components.WindowManager=Manager

function Manager:BodyPadding()
  return math.max(0, math.min(32, tonumber(Core.db.profile.bodyPadding) or 8))
end
local ICONS="Interface\\AddOns\\Sunder\\Media\\Icons\\"
-- One surface implementation for every chat type. Adapters supply geometry only.
function Manager:ApplySurface(root,options)
  options=options or {}
  local t=root.windowSurface
  if not t then
    local panel=CreateFrame("Frame",nil,root);panel:SetAllPoints();panel:SetFrameLevel(root:GetFrameLevel())
    t={frame=panel,edges={}};root.windowSurface=t
    t.bodyFrame=CreateFrame("Frame",nil,panel);t.bodyFrame:SetFrameLevel(panel:GetFrameLevel())
    t.body=t.bodyFrame:CreateTexture(nil,"BACKGROUND",nil,-2);t.body:SetAllPoints()
    t.fade=t.bodyFrame:CreateTexture(nil,"BACKGROUND");t.fade:SetAllPoints();t.bodyFrame.fill=t.fade
    t.sidebar=t.bodyFrame:CreateTexture(nil,"ARTWORK")
    t.divider=t.bodyFrame:CreateTexture(nil,"OVERLAY")
    t.header=panel:CreateTexture(nil,"BACKGROUND");t.headerRule=panel:CreateTexture(nil,"BORDER")
    for _,edge in ipairs({"TOP","BOTTOM","LEFT","RIGHT"})do
      local line=panel:CreateTexture(nil,"OVERLAY");t.edges[#t.edges+1]=line
      if edge=="TOP" or edge=="BOTTOM" then line:SetPoint(edge.."LEFT");line:SetPoint(edge.."RIGHT");line:SetHeight(1)
      else line:SetPoint("TOP"..edge);line:SetPoint("BOTTOM"..edge);line:SetWidth(1)end
    end
  end
  local profile=Core.db.profile
  local color=options.color or profile.chatBackgroundColor or {r=.035,g=.04,b=.05,a=.5}
  local header=options.headerColor or profile.headerBackgroundColor or color
  local alpha=math.max(0,math.min(1,options.opacity or color.a or .5))
  local headerAlpha=math.max(0,math.min(1,options.headerOpacity or header.a or alpha))
  local height=options.headerHeight or Constants.DOCK_HEIGHT or 24
  local top=options.bodyTop or height
  local sidebar=options.sidebarWidth or 0
  local listTop=options.listTop or top
  local extent=options.bottomExtent or 0
  local visible=options.bodyVisible~=false
  local stamp=table.concat({root:GetWidth(),root:GetHeight(),root:GetFrameLevel(),height,top,listTop,sidebar,extent,
    color.r,color.g,color.b,alpha,header.r,header.g,header.b,headerAlpha,
    options.borderOpacity or (alpha>0 and .16 or 0),tostring(visible),tostring(options.fade~=false),
    profile.backgroundFadeLeftPercent or 0,profile.backgroundFadeRightPercent or 0},":")
  if t.paintStamp==stamp then return t end
  t.paintStamp=stamp
  t.bodyTop=top;t.bottomExtent=extent
  t.frame:ClearAllPoints();t.frame:SetPoint("TOPLEFT",root,"TOPLEFT");t.frame:SetPoint("BOTTOMRIGHT",root,"BOTTOMRIGHT",0,-extent)
  t.frame:SetFrameLevel(root:GetFrameLevel());t.bodyFrame:SetFrameLevel(t.frame:GetFrameLevel())
  t.bodyFrame:ClearAllPoints();t.bodyFrame:SetPoint("TOPLEFT",root,"TOPLEFT",0,-top);t.bodyFrame:SetPoint("TOPRIGHT",root,"TOPRIGHT",0,-top)
  t.bodyFrame:SetHeight(math.max(1,root:GetHeight()-top+extent));t.bodyFrame:SetShown(visible)
  -- The animated body frame gates all its paints, including on the first restore tick.
  t.body:SetColorTexture(color.r,color.g,color.b,alpha*.85)
  -- The fade always overlays the backing, never a second independent column paint.
  local paint=Core.Components.PaintGradientTexture or function(texture,c,a)texture:SetColorTexture(c.r,c.g,c.b,a)end
  -- Keep people columns neutral and uniform; transcript edge fades must not
  -- change the apparent list color as room/sidebar widths change.
  t.fade:ClearAllPoints();t.fade:SetPoint("TOPLEFT",t.bodyFrame,"TOPLEFT",sidebar,-math.max(0,listTop-top));t.fade:SetPoint("BOTTOMRIGHT",t.bodyFrame,"BOTTOMRIGHT")
  paint(t.fade,color,alpha,options.fade~=false)
  t.sidebar:ClearAllPoints();t.sidebar:SetPoint("TOPLEFT",root,"TOPLEFT",1,-listTop);t.sidebar:SetPoint("BOTTOMLEFT",root,"BOTTOMLEFT",1,1);t.sidebar:SetWidth(math.max(1,sidebar-1))
  t.sidebar:SetColorTexture(.025,.03,.04,alpha+(1-alpha)*math.min(.4,alpha*.7));t.sidebar:SetShown(sidebar>0)
  t.divider:ClearAllPoints();t.divider:SetPoint("TOPLEFT",root,"TOPLEFT",sidebar,-listTop-6);t.divider:SetPoint("BOTTOMLEFT",root,"BOTTOMLEFT",sidebar,7);t.divider:SetWidth(1)
  t.divider:SetColorTexture(.64,.69,.76,alpha>0 and .18 or 0);t.divider:SetShown(sidebar>0)
  t.header:ClearAllPoints();t.header:SetPoint("TOPLEFT");t.header:SetPoint("TOPRIGHT");t.header:SetHeight(height)
  t.header:SetColorTexture(header.r,header.g,header.b,headerAlpha)
  t.headerRule:ClearAllPoints();t.headerRule:SetPoint("TOPLEFT",root,"TOPLEFT",1,-height);t.headerRule:SetPoint("TOPRIGHT",root,"TOPRIGHT",-1,-height);t.headerRule:SetHeight(1)
  t.headerRule:SetColorTexture(.64,.69,.76,alpha>0 and .16 or 0)
  for _,line in ipairs(t.edges)do line:SetColorTexture(.64,.69,.76,options.borderOpacity or (alpha>0 and .16 or 0))end
  return t
end
function Manager:RetirePaint(region)
  if not region then return end
  for _,part in pairs(region.sunderGradientParts or {})do part:Hide()end
  for _,key in ipairs({"leftBg","centerBg","rightBg","bodyBase"})do if region[key]then region[key]:Hide()end end
  if region.SetColorTexture then
    if Core.Components.PaintGradientTexture then Core.Components.PaintGradientTexture(region,{r=0,g=0,b=0},0,false)else region:SetColorTexture(0,0,0,0)end
  end
end
function Manager:ApplyNativeSurface(root,header)
  header:SetFrameStrata(root:GetFrameStrata());header:SetFrameLevel(root:GetFrameLevel()+3)
  if header.scrollFrame then header.scrollFrame:SetFrameStrata(header:GetFrameStrata());header.scrollFrame:SetFrameLevel(header:GetFrameLevel()+1)end
  if header.windowControls then
    self:RaiseNativeActions(header)
    header.windowControls.move:SetFrameLevel(math.max(header:GetFrameLevel(),header.scrollFrame and header.scrollFrame:GetFrameLevel() or 0)+10)
  end
  if header.tab then header.tab:SetFrameStrata(header:GetFrameStrata());header.tab:SetFrameLevel(header:GetFrameLevel()+2)end
  self:RetirePaint(header)
  self:RetirePaint(header.messageSeparator)
  if header.messageSeparator then header.messageSeparator:SetAlpha(0)end
  if header.windowControls then
    for _,button in ipairs(header.windowControls.buttons) do
      header.windowControls.style(button)
    end
    if header.windowControls.fitMainActions then header.windowControls.fitMainActions() end
    header.windowControls.lock:Refresh()
  end
  return self:ApplySurface(root,{headerHeight=header:GetHeight(),bottomExtent=not root.mainBodyClipped and root.windowContentExtent,bodyVisible=not root.mainBodyHidden})
end
function Manager:RegisterNativeSurface(root,header)
  if root.windowSurfaceRegistered then return end
  root.windowSurfaceRegistered=true;root.windowHeader=header
  local update=function()self:ApplyNativeSurface(root,header)end
  update()
  root:HookScript("OnSizeChanged",function()
    if root.mainBodyClipped then
      local surface=root.windowSurface
      surface.bodyFrame:SetHeight(math.max(1,root:GetHeight()-surface.bodyTop))
    else
      update()
    end
  end)
  local relevant={chatBackgroundColor=true,headerBackgroundColor=true,backgroundFade=true,
    backgroundFadeLeftPercent=true,backgroundFadeRightPercent=true,frameWidth=true,frameHeight=true,
    chatHeaderStyle=true,font=true,tabFontSize=true,chatTitleIconSize=true,chatTitleIconOpacity=true,
    chatTitleIcons=true,tabHighlightTextColor=true,tabMessageSeparatorColor=true}
  Core:Subscribe(Constants.EVENTS.UPDATE_CONFIG,function(key)if relevant[key]then update()end end)
end
function Manager:UpdateContentExtent(root,height,top)
  if not root or not root.windowSurfaceRegistered or root.mainBodyClipped then return end
  local extent=math.max(0,height+top-root:GetHeight())
  if root.windowContentExtent==extent then return end
  root.windowContentExtent=extent
  self:ApplyNativeSurface(root,root.windowHeader)
end
function Manager:CreateWindowResizer(root,options)
  local handle=Core.Components.CreateResizeHandle(root,options)
  handle:SetSize(24,24);handle:SetAlpha(.4);handle:SetFrameLevel(root:GetFrameLevel()+30)
  for _,method in ipairs({"GetNormalTexture","GetHighlightTexture","GetPushedTexture"})do
    local texture=handle[method] and handle[method](handle)
    if texture then texture:ClearAllPoints();texture:SetSize(16,16);texture:SetPoint("BOTTOMRIGHT")end
  end
  handle:ClearAllPoints();handle:SetPoint("BOTTOMRIGHT",root.windowSurface and root.windowSurface.frame or root,"BOTTOMRIGHT",-2,2)
  handle:SetScript("OnEnter",function()handle:SetAlpha(.85)end)
  handle:SetScript("OnLeave",function()handle:SetAlpha(.4)end)
  return handle
end
function Manager:Settings(id)
  Core.db.char.windowControls=Core.db.char.windowControls or {}
  local all=Core.db.char.windowControls;all[id]=all[id] or {}
  return all[id]
end
function Manager:CanMove(settings)return not settings.movementLocked end
function Manager:BindDrag(region,start,stop)
  region:EnableMouse(true);region:RegisterForDrag("LeftButton")
  region:SetScript("OnDragStart",start);region:SetScript("OnDragStop",stop)
end
-- Drivers live under UIParent, never under an edit overlay or fading header.
function Manager:MoveDriver(owner)
  if not owner.windowMoveDriver then owner.windowMoveDriver=CreateFrame("Frame",nil,UIParent)end
  owner.windowMoveDriver:Show();return owner.windowMoveDriver
end
function Manager:StartNativeMove(owner,frame,update,stop)
  if owner.windowMoveTarget then return end
  owner.windowMoveTarget=frame;frame.windowMoveStop=stop
  if not frame.windowMoveHideHook then
    frame.windowMoveHideHook=true
    frame:HookScript("OnHide",function()if frame.windowMoveStop then frame.windowMoveStop()end end)
  end
  frame:SetMovable(true);frame:SetClampedToScreen(true);frame:StartMoving()
  local driver=self:MoveDriver(owner)
  driver:SetScript("OnUpdate",function()
    if update then update()end
    if not IsMouseButtonDown("LeftButton")then stop()end
  end)
end
function Manager:StopNativeMove(owner,frame)
  frame.windowMoveStop=nil;owner.windowMoveTarget=nil
  frame:StopMovingOrSizing()
  if owner.windowMoveDriver then owner.windowMoveDriver:SetScript("OnUpdate",nil);owner.windowMoveDriver:Hide()end
end
function Manager:CreateGrip(parent,start,stop)
  local grip=CreateFrame("Button",nil,parent);grip:SetSize(18,24)
  for row=0,2 do for col=0,1 do
    local dot=grip:CreateTexture(nil,"OVERLAY");dot:SetSize(2,2);dot:SetPoint("CENTER",col*5-2.5,4-row*4);dot:SetColorTexture(.78,.68,.48,.85)
  end end
  self:BindDrag(grip,start,stop)
  grip:SetScript("OnMouseDown",function(_,button)if button=="LeftButton"then start()end end)
  grip:SetScript("OnMouseUp",stop)
  grip:SetScript("OnEnter",function()GameTooltip:SetOwner(grip,"ANCHOR_TOP");GameTooltip:AddLine("Drag to move this window",1,1,1);GameTooltip:Show()end)
  grip:SetScript("OnLeave",function()GameTooltip:Hide()end)
  return grip
end
function Manager:UpdateUnreadBadge(label,count,size)
  count=math.max(0,tonumber(count)or 0)
  if not label.unreadPlate then
    label.unreadPlate=label:GetParent():CreateTexture(nil,"BACKGROUND")
    label.unreadPlate:SetPoint("TOPLEFT",label,"TOPLEFT",-3,2);label.unreadPlate:SetPoint("BOTTOMRIGHT",label,"BOTTOMRIGHT",3,-2)
    label.unreadPlate:SetColorTexture(.24,.12,.025,.85)
  end
  label:SetText(count>0 and (count>99 and "99+" or tostring(count))or "")
  label:SetWidth(math.max(18,(size or 12)*2.2));label:SetHeight((size or 12)+4);label:SetJustifyH("CENTER")
  label:SetShown(count>0);label.unreadPlate:SetShown(count>0)
end
function Manager:RefreshAction(button)
  local selected=button.actionSelected==true
  local key=selected and button.selectedIconKey or button.actionKey
  if type(key)=="string" then button.icon:SetTexture(ICONS..key..".tga")end
  local accent=Core.GetThemeColor and Core:GetThemeColor("tabHighlightTextColor") or {r=.84,g=.66,b=.38}
  local disabled=button.actionDisabled==true
  local hovered=button.hovered==true
  local active=not disabled and (selected or hovered)
  button.icon:SetVertexColor(active and accent.r or .65,active and accent.g or .7,active and accent.b or .78)
  button.icon:SetAlpha(disabled and .25 or active and 1 or button.iconOpacity or 1)
  local iconOnly=button.actionKey=="favorite" or button.actionKey=="pin"
  button.plate:SetColorTexture(accent.r,accent.g,accent.b,not disabled and not (iconOnly and selected) and (selected and .13 or hovered and .07 or 0) or 0)
  local highlight=iconOnly and button.GetHighlightTexture and button:GetHighlightTexture()
  if highlight then highlight:SetVertexColor(accent.r,accent.g,accent.b,selected and 0 or .08)end
end
function Manager:SetActionSelected(button,selected,key)
  if not button then return end
  button.actionSelected=not not selected
  button.selectedIconKey=(key or button.actionKey).."-filled"
  self:RefreshAction(button)
end
function Manager:CreateAction(parent,key,tooltip,action,style)
  local b=CreateFrame("Button",nil,parent);b:SetSize(26,26);b.actionKey=key
  b.plate=b:CreateTexture(nil,"BACKGROUND");b.plate:SetAllPoints();b.plate:SetColorTexture(1,1,1,.035)
  local icon=b:CreateTexture(nil,"ARTWORK");b.icon=icon
  icon:SetSize(19,19);icon:SetPoint("CENTER");icon:SetTexture(ICONS..key..".tga");icon:SetVertexColor(.74,.8,.88)
  b:SetHighlightTexture("Interface\\Buttons\\WHITE8X8");b:GetHighlightTexture():SetVertexColor(.84,.66,.38,.08)
  function b:ShowActionTooltip()
    GameTooltip:SetOwner(b,"ANCHOR_TOP");GameTooltip:AddLine(type(tooltip)=="function" and tooltip() or tooltip,1,1,1);GameTooltip:Show()
  end
  b:SetScript("OnEnter",function()b.hovered=true;self:RefreshAction(b);b:ShowActionTooltip()end)
  b:SetScript("OnLeave",function()b.hovered=nil;self:RefreshAction(b);GameTooltip:Hide()end)
  b:SetScript("OnMouseDown",function()icon:ClearAllPoints();icon:SetPoint("CENTER",b.iconOffsetX or 0,-1)end)
  b:SetScript("OnMouseUp",function()icon:ClearAllPoints();icon:SetPoint("CENTER",b.iconOffsetX or 0,0)end)
  b:SetScript("OnDisable",function()b.actionDisabled=true;self:RefreshAction(b)end)
  b:SetScript("OnEnable",function()b.actionDisabled=nil;self:RefreshAction(b)end)
  b:SetScript("OnHide",function()b.hovered=nil;icon:ClearAllPoints();icon:SetPoint("CENTER",b.iconOffsetX or 0,0);self:RefreshAction(b)end)
  b:SetScript("OnClick",action)
  if style then style(b)end
  self:RefreshAction(b)
  return b
end
function Manager:CreateLock(parent,settings,stop,style)
  local b
  b=self:CreateAction(parent,"unlock",function()return settings().movementLocked and "Unlock window size and position" or "Lock window size and position"end,function()
    local cfg=settings();cfg.movementLocked=not cfg.movementLocked;stop();b:Refresh()
    if b.hovered == true then b:ShowActionTooltip() end
  end,style)
  function b:Refresh()self.actionKey=settings().movementLocked and "lock" or "unlock";Manager:SetActionSelected(self,settings().movementLocked,"lock")end
  b:Refresh();return b
end
function Manager:RaiseNativeActions(header)
  local controls = header.windowControls
  local child = header.scrollFrame and header.scrollFrame.child
  local level = math.max(header:GetFrameLevel(), child and child:GetFrameLevel() or 0,
    header.scrollFrame and header.scrollFrame:GetFrameLevel() or 0)
  controls:SetFrameStrata(header:GetFrameStrata())
  controls:SetFrameLevel(level + 5)
  for _, button in ipairs(controls.buttons or {}) do
    button:SetFrameStrata(header:GetFrameStrata())
    button:SetFrameLevel(level + 6)
  end
end

function Manager:CreateNativeHeader(header,options)
  if header.windowControls then return header.windowControls end
  local controls=CreateFrame("Frame",nil,header);header.windowControls=controls
  controls:SetPoint("RIGHT",header,"RIGHT",-4,0);controls:SetSize(50,Constants and Constants.DOCK_HEIGHT or 24)
  controls:SetFrameLevel(header:GetFrameLevel()+5)
  local settings=options.settings
  local style=function(b)
    local w=Core:GetModule("Whispers",true)
    if w and w.StyleWindowIcon then w:StyleWindowIcon(b)end
  end
  controls.style=style
  controls.lock=self:CreateLock(controls,settings,options.onLockChanged or options.stop,style)
  local host=options.host or {}
  host.hubActionButtons={}
  host.movementLockButton=controls.lock
  if options.host then
    self:CreateCollapseActions(controls,host,options.collapse,style)
    host.hubActionButtons.Maximize=self:CreateWindowAction(controls,"Maximize",host,options.maximize,style)
  end
  for _,entry in ipairs({{"Settings","settings",options.settingsAction},{"Dock","dock",options.dockAction}}) do
    if entry[3] then
      local button=self:CreateWindowAction(controls,entry[1],host,entry[3],style)
      controls[entry[2]]=button
      host.hubActionButtons[entry[1]]=button
    end
  end
  controls.move=self:CreateGrip(header,options.start,options.stop)
  controls.move:SetFrameLevel(math.max(header:GetFrameLevel(),header.scrollFrame and header.scrollFrame:GetFrameLevel() or 0)+10)
  controls.buttons={controls.lock}
  for _,button in pairs(host.hubActionButtons) do table.insert(controls.buttons,button) end
  self:RaiseNativeActions(header)
  local lastStep,lastMinimized
  local function fitActions()
    local count=#controls.buttons-(host.minimized and 1 or 0)
    local step=options.host and math.max(10,math.min(24,math.floor((header:GetWidth()-50)/count))) or 24
    if step==lastStep and host.minimized==lastMinimized then return end
    lastStep,lastMinimized=step,host.minimized
    header.windowTitleInset=step==24 and 30 or 18
    controls.move:SetPoint("LEFT",header,"LEFT",step==24 and 4 or 0,0)
    local width=self:LayoutHeaderActions(host,controls,2,step-2,math.min(14,step-3),2,22)
    controls:SetWidth(width)
    header.windowActionWidth=width+6
  end
  if options.host then controls.fitMainActions=fitActions end
  fitActions()
  self:BindDrag(header,options.start,options.stop)
  return controls
end

function Manager:AnchorMainContainer(root,mover)
  local offset=root.mainTopOffset or 0
  root:ClearAllPoints()
  if root.mainBottomAnchored then
    root:SetPoint("BOTTOMLEFT",mover,"TOPLEFT",0,offset-Core.db.profile.frameHeight)
  else
    root:SetPoint("TOPLEFT",mover,"TOPLEFT",0,offset)
  end
end

function Manager:AnimateHeight(frame, from, target, update, finish)
  local elapsed = 0
  frame:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + delta
    local t = math.min(1, elapsed / 0.24)
    local eased = t * t * (3 - 2 * t)
    update(math.max(1, from + (target - from) * eased))
    if t == 1 then frame:SetScript("OnUpdate", nil); finish() end
  end)
end

-- Shared, cancelable room transition; adapters supply layout and persistence only.
function Manager:SetRoomMinimized(host, minimized, instant)
  local self=host
  if not self.hub then return end
  minimized = not not minimized
  if self.minimized == minimized and not self.collapseAnimation then return end
  if minimized then self:SaveHubGeometry() end
  self:StopHubMove()
  self.hubResize:FinishResize()
  -- Guard adapter size callbacks before any anchoring or presentation changes.
  self.collapseAnimation = true
  self.hubContent:SetClipsChildren(true)
  if self.previewBody then self.previewBody:SetClipsChildren(true)end
  self:PresentWindowBody(true,1)
  self.minimized = minimized
  if self.LayoutHeaderStrip then self:LayoutHeaderStrip() end
  -- The header must never enter a transient root clipping rectangle.
  self.hub:SetClipsChildren(false)
  self:PresentCollapsedHeader()
  local scale = UIParent:GetEffectiveScale() / self.hub:GetEffectiveScale()
  local left = self.hub:GetLeft()
  local edge = self:HubSettings().minimizeEdge or "TOP"
  local anchor = "TOPLEFT"
  local y = self.hub:GetTop() - UIParent:GetTop() * scale
  self.hub:ClearAllPoints()
  self.hub:SetPoint(anchor, UIParent, anchor, left - UIParent:GetLeft() * scale, y)
  local target = minimized and self:HeaderHeight() or self:HubSettings().hubHeight
  local from = self.hub:GetHeight()
  -- Animate only while transitioning; no idle per-frame handler or new frames.
  local function resize(height)
    self.hub:SetHeight(height)
    if edge == "BOTTOM" then
      self.hub:SetPoint(anchor, UIParent, anchor, left - UIParent:GetLeft() * scale, y + height - from)
    end
  end
  local function finish()
    self.hub:SetScript("OnUpdate", nil)
    resize(target)
    if edge == "BOTTOM" then
      self.hub:ClearAllPoints()
      self.hub:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",left-UIParent:GetLeft()*scale,y+UIParent:GetTop()*scale-from-UIParent:GetBottom()*scale)
    end
    self.hub:SetClipsChildren(false)
    self.hubContent:SetClipsChildren(false)
    if self.previewBody then self.previewBody:SetClipsChildren(false)end
    self.collapseAnimation, self.finishCollapse = nil, nil
    self:UpdateTransitionBounds()
    self:PresentWindowBody(not minimized, 1)
    self:PresentCollapsedHeader()
    Manager:RefreshRoomActions(self)
    if not minimized then
      self:LayoutHub()
      if self.previewActive then self:EnsurePreviewTabVisible(self.previewSelected) else self:EnsureHubTabVisible(self.selected) end
    end
    self:SaveMessageWindowState()
  end
  self.collapseAnimation = true
  self.finishCollapse = finish
  if instant then finish(); return end
  Manager:AnimateHeight(self.hub, from, target, function(height)
    resize(height)
    Manager:UpdateRoomSurfaceGeometry(self)
    self:UpdateTransitionBounds()
    -- Reveal/collapse with geometry, not an early fade that leaves only chrome.
    self:PresentWindowBody(true, 1)
  end, finish)
end


function Manager:CreateUnreadIndicator(parent)
  local button=CreateFrame("Button",nil,parent)
  button:SetNormalFontObject("SunderChatDockFont")
  button:SetText("0")
  button.icon=button:CreateTexture(nil,"ARTWORK")
  button.icon:SetTexture(ICONS.."inbox.tga")
  return button
end

function Manager:StyleUnreadIndicator(button,count,r,g,b)
  local label=count>99 and "99+" or tostring(count)
  if button:GetText()~=label then button:SetText(label) end
  r,g,b=count>0 and r or .74,count>0 and g or .8,count>0 and b or .88
  button:GetFontString():SetTextColor(r,g,b,1)
  if button.icon then
    button.icon:SetVertexColor(r,g,b,1)
    button.icon:SetAlpha(count>0 and 1 or math.max(.15,math.min(1,tonumber(Core.db.profile.chatTitleIconOpacity)or .5)))
  end
end

-- Semantic window commands are capabilities; glyphs never select behavior.
Manager.windowActions={
  Close={icon="close",tooltip="Close window"},
  Settings={icon="settings",tooltip="Settings for this window"},
  Windows={icon="window-menu",tooltip="Window and conversation actions"},
  Maximize={icon="maximize",tooltip="Maximize window",enabled=function(host)local cfg=host:HubSettings();return cfg and not cfg.movementLocked end},
  CollapseTop={icon="collapse-up",tooltip="Collapse upward"},
  CollapseBottom={icon="collapse-down",tooltip="Collapse downward"},
  Info={icon="info",tooltip="Guild information",enabled=function(host)return not host.minimized end},
  Roster={icon="roster",tooltip="Show / hide member roster",enabled=function()return true end},
  Dock={icon="dock",tooltip="Return to General / main chat tabs"},
}
function Manager:CreateWindowAction(parent,id,host,action,style)
  local spec=assert(self.windowActions[id],"Unknown window capability: "..tostring(id))
  local button
  button=self:CreateAction(parent,spec.icon,function()return button.windowTooltip or spec.tooltip end,function(...)
    action(...)
    self:RefreshRoomActions(host)
    if button.hovered and button.ShowActionTooltip then button:ShowActionTooltip()end
  end,style)
  button.windowAction=id;button.windowHost=host
  return button
end
function Manager:CreateCollapseActions(parent,host,collapse,style)
  for _,edge in ipairs({"TOP","BOTTOM"}) do
    local direction=edge
    local id=edge=="TOP" and "CollapseTop" or "CollapseBottom"
    host.hubActionButtons[id]=self:CreateWindowAction(parent,id,host,function()collapse(direction)end,style)
  end
end

function Manager:RefreshRoomActions(host)
  for _,button in pairs(host.hubActionButtons or {})do
    local id=button.windowAction
    if id then
      local spec=self.windowActions[id]
      button.actionKey=spec.icon;button.windowTooltip=button.windowTooltipOverride or spec.tooltip
      if button.windowEnabled then button:SetEnabled(button.windowEnabled())elseif spec.enabled then button:SetEnabled(spec.enabled(host))end
      if id=="Maximize" and host.maximized then button.actionKey="restore-size";button.windowTooltip="Restore window size" end
      if id=="CollapseTop" or id=="CollapseBottom" then
        local bottom=host.minimized and host:HubSettings().minimizeEdge=="BOTTOM"
        button:SetShown(not host.minimized or (id=="CollapseBottom")==bottom)
        if host.minimized then
          button.actionKey=host:HubSettings().minimizeEdge=="BOTTOM" and "collapse-up" or "collapse-down"
          button.windowTooltip="Restore window"
        end
      end
      if button.windowSelected then
        button.actionSelected=not not button.windowSelected()
        button.selectedIconKey=spec.icon
        if id=="Roster" then button.windowTooltip=host.minimized and "Restore window and show members" or button.actionSelected and "Hide member roster" or "Show member roster" end
      end
      if button.windowCount and button.countLabel then button.countLabel:SetText(button.windowCount())end
      self:RefreshAction(button)
    end
  end
end
-- Rightmost first. Missing capabilities and hidden controls reserve no space.
local headerOrder={"Close","Settings","Maximize","CollapseTop","CollapseBottom","Lock","Windows","Dock","Info","Roster","Detach","Search","Reply"}
function Manager:LayoutHeaderActions(host,parent,right,size,icon,gap,height)
  self:RefreshRoomActions(host)
  for _,id in ipairs(headerOrder)do
    local button=id=="Lock" and host.movementLockButton or host.hubActionButtons[id]
    if button and button:IsShown() then
      button:ClearAllPoints();button:SetPoint("RIGHT",parent,"RIGHT",-right,0)
      local label=button.windowCount and button.windowCount() or nil
      local extra=0
      if label then
        if not button.countLabel then button.countLabel=button:CreateFontString(nil,"OVERLAY","SunderChatDockFont")end
        host:WorkspaceFont(button.countLabel,host:InterfaceTextSize())
        button.countLabel:SetText(label);extra=(button.countLabel:GetStringWidth())+6
        button.countLabel:ClearAllPoints();button.countLabel:SetPoint("LEFT",button,"LEFT",size,0)
      end
      button.iconOffsetX=-extra/2
      button:SetSize(size+extra,height or size);button.icon:SetSize(icon,icon)
      if host.StyleWindowIcon then host:StyleWindowIcon(button) end
      if label then button.icon:ClearAllPoints();button.icon:SetPoint("LEFT",button,"LEFT",(size-icon)/2,0)end
      right=right+button:GetWidth()+gap
    end
  end
  return right
end
function Manager:CollapseToward(host,edge)
  if host.finishCollapse then host.finishCollapse()end
  if host.minimized then host:SetMinimized(false);return end
  host:HubSettings().minimizeEdge=edge;host:SetMinimized(true)
end
function Manager:MaximizedSize(minWidth)
  return math.max(minWidth,math.min(1100,UIParent:GetWidth()-32)), math.max(220,math.min(720,UIParent:GetHeight()-64))
end
function Manager:ToggleMaximized(host,storage)
  if not self:CanMove(host:HubSettings())then return end
  if host.finishCollapse then host.finishCollapse()end
  if host.minimized then host:SetMinimized(false,true)end
  host:StopHubMove();host.hubResize:FinishResize()
  local cfg=host:HubSettings();storage=storage or cfg
  if not host.maximized then
    host:SaveHubGeometry()
    storage.roomRestore={hubPoint=cfg.hubPoint,hubX=cfg.hubX,hubY=cfg.hubY,hubWidth=cfg.hubWidth,hubHeight=cfg.hubHeight}
    host.maximized=true
    host.hub:ClearAllPoints();host.hub:SetPoint("CENTER",UIParent,"CENTER",0,0)
    host.hub:SetSize(self:MaximizedSize(host.minimumWorkspaceWidth or 480))
  else
    local previous=storage.roomRestore;host.maximized=false
    if previous then
      for key,value in pairs(previous)do cfg[key]=value end
      host.hub:ClearAllPoints();host.hub:SetPoint(cfg.hubPoint,UIParent,cfg.hubPoint,cfg.hubX,cfg.hubY);host.hub:SetSize(cfg.hubWidth,cfg.hubHeight)
    end
    storage.roomRestore=nil
  end
  cfg.maximized=host.maximized
  host:SaveHubGeometry();host:SaveMessageWindowState();host:LayoutHub();self:RefreshRoomActions(host)
end
function Manager:ClearMaximized(host)
  host.maximized=false
  local cfg=host:HubSettings();cfg.maximized=false;cfg.roomRestore=nil
  self:RefreshRoomActions(host)
end

-- Surface animation is independent of conversation-list presentation.
function Manager:UpdateRoomSurfaceGeometry(host)
  local surface=host.hub and host.hub.windowSurface
  if surface then surface.bodyFrame:SetHeight(math.max(1,host.hub:GetHeight()-(surface.bodyTop or host:HeaderHeight())+(surface.bottomExtent or 0)))end
end
function Manager:PresentRoomSurface(host,shown,alpha)
  local surface=host.hub and host.hub.windowSurface
  if surface then
    self:UpdateRoomSurfaceGeometry(host)
    surface.bodyFrame:SetShown(shown);surface.bodyFrame:SetAlpha(alpha or 1)
  end
end
function Manager:LayoutUnreadIndicator(button,width,height,iconSize)
  button:SetSize(width,height)
  button.icon:ClearAllPoints();button.icon:SetPoint("LEFT",4,0);button.icon:SetSize(iconSize,iconSize)
  local label=button:GetFontString()
  label:ClearAllPoints();label:SetPoint("LEFT",22,0);label:SetPoint("RIGHT",-4,0);label:SetJustifyH("CENTER")
end
function Manager:StyleTitleIcon(icon,hovered)
  local accent=Core.GetThemeColor and Core:GetThemeColor("tabHighlightTextColor") or {r=.84,g=.66,b=.38}
  icon:SetVertexColor(hovered and accent.r or .74,hovered and accent.g or .8,hovered and accent.b or .88)
  icon:SetAlpha(hovered and .9 or math.max(.15,math.min(1,tonumber(Core.db.profile.chatTitleIconOpacity)or .5)))
end

-- Shared body lifecycle; adapters supply content/layout, never parallel animation policy.
function Manager:PresentRoomBody(host,shown,alpha)
  self:PresentRoomSurface(host,shown,alpha)
  if host.hubBackground then host.hubBackground:SetAlpha(alpha or 1)end
  for _,frame in pairs({host.hubContent,host.previewBody})do
    frame:SetAlpha(alpha or 1)
    frame:SetShown(shown and (frame==host.hubContent and not host.previewActive or frame==host.previewBody and host.previewActive))
  end
end
function Manager:SidebarWidth(width,preferred,minimum,maximum,reserve)
  return math.max(1,math.min(math.max(minimum,math.min(maximum,preferred)),math.max(1,width-reserve)))
end

-- One width for all expanded people lists; narrow roots preserve message space.
Manager.PEOPLE_SIDEBAR_WIDTH=150
function Manager:PeopleSidebarWidth(width)
  return math.max(1,math.min(self.PEOPLE_SIDEBAR_WIDTH,width-220))
end

-- Passive list affordance stays visible even when all rows fit.
function Manager:UpdateListScrollIndicator(scroll,child,visible)
  if not scroll or not child then return end
  if not scroll.roomTrack then
    local track=scroll:GetParent():CreateTexture(nil,"OVERLAY");scroll.roomTrack=track
    local thumb=scroll:GetParent():CreateTexture(nil,"OVERLAY");scroll.roomThumb=thumb
  end
  local height=math.max(1,scroll:GetHeight()-12)
  local maximum=math.max(0,child:GetHeight()-scroll:GetHeight())
  local thumbHeight=math.min(height,math.max(18,height*scroll:GetHeight()/math.max(1,child:GetHeight())))
  local track,thumb=scroll.roomTrack,scroll.roomThumb
  track:ClearAllPoints();track:SetPoint("TOPRIGHT",scroll,"TOPRIGHT",-3,-6);track:SetSize(2,height);track:SetColorTexture(.7,.75,.8,.09)
  thumb:ClearAllPoints();thumb:SetPoint("TOPRIGHT",track,"TOPRIGHT",0,-(height-thumbHeight)*(maximum>0 and math.min(1,scroll:GetVerticalScroll()/maximum)or 0));thumb:SetSize(2,thumbHeight)
  thumb:SetColorTexture(.7,.75,.8,maximum>0 and .4 or .13)
  track:SetShown(scroll:IsShown() and visible);thumb:SetShown(scroll:IsShown() and visible and maximum>0)
end


-- List rails sit against the viewport edge, never inside body padding.
function Manager:LayoutListScrollRail(rail,scroll)
  rail:ClearAllPoints();rail:SetPoint("TOPRIGHT",scroll,"TOPRIGHT",-1,-4)
  rail:SetWidth(10);rail:SetHeight(math.max(1,scroll:GetHeight()-8))
  rail:SetFrameLevel(scroll:GetFrameLevel()+6)
end

function Manager:PersonDetailSize(host)return math.max(9,math.floor(host:InterfaceTextSize()*.78))end
function Manager:ApplyPersonDetailFont(host,label)
  host:WorkspaceFont(label,self:PersonDetailSize(host))
  local path,_,flags=label:GetFont()
  if path then label:SetFont(path,self:PersonDetailSize(host),flags or "")end
end
function Manager:StylePersonDetail(host,label,person)
  person=person or {}
  local token=person.classFile or person.classToken
  local localized=token and ((_G.LOCALIZED_CLASS_NAMES_MALE or {})[token] or (_G.LOCALIZED_CLASS_NAMES_FEMALE or {})[token])
  local class=localized or person.class or ""
  local level=tonumber(person.level)
  local text=level and level>0 and tostring(math.floor(level)) or ""
  if class~="" then text=text~="" and text.." · "..class or class end
  self:ApplyPersonDetailFont(host,label)
  local color=token and ((_G.CUSTOM_CLASS_COLORS or _G.RAID_CLASS_COLORS or {})[token])
  label:SetText(text:gsub("|","||"));label:SetWordWrap(false);label:SetJustifyH("LEFT");label:SetJustifyV("MIDDLE")
  label:SetTextColor(color and color.r or .6,color and color.g or .65,color and color.b or .7,person.online==false and .4 or .68)
  label:SetShown(text~="")
  return text~=""
end

function Manager:StyleFilterButton(button,active,hover,r,g,b)
  if button.key=="favorites"then button.icon:SetTexture(ICONS..(active and "favorite-filled" or "favorite")..".tga")end
  button.plate:SetColorTexture(active and r or 1,active and g or 1,active and b or 1,active and .075 or hover and .035 or 0)
  button.indicator:SetColorTexture(r,g,b,active and .8 or 0)
  button.icon:SetVertexColor(active and r or hover and .9 or .58,active and g or hover and .92 or .63,active and b or hover and .96 or .70)
  button:GetFontString():SetTextColor(active and .97 or .68,active and .88 or .72,active and .67 or .78)
end

function Manager:StyleInsetPanel(panel,host)
  if not panel.insetFill then
    panel.insetFill=panel:CreateTexture(nil,"BACKGROUND");panel.insetFill:SetAllPoints()
    panel.insetRule=panel:CreateTexture(nil,"BORDER");panel.insetRule:SetPoint("TOPLEFT");panel.insetRule:SetPoint("BOTTOMLEFT");panel.insetRule:SetWidth(1)
  end
  local color=Core.db.profile.chatBackgroundColor or {r=.035,g=.04,b=.05,a=.5}
  if host and not host:UsesChatAppearance()then local cfg=host:Settings();color=cfg.hubBackgroundColor or color end
  local opacity=host and not host:UsesChatAppearance() and host:Settings().hubBackgroundOpacity or color.a or .5
  panel.insetFill:SetColorTexture(color.r,color.g,color.b,opacity)
  panel.insetRule:SetColorTexture(.7,.75,.8,color.a==0 and 0 or .13)
end

function Manager:CreateTextAction(parent,label,callback)
  local b=CreateFrame("Button",nil,parent);b:SetNormalFontObject("SunderChatDockFont");b:SetText(label)
  local plate=b:CreateTexture(nil,"BACKGROUND");plate:SetAllPoints();plate:SetColorTexture(1,1,1,.04)
  b:SetHighlightTexture("Interface\\Buttons\\WHITE8X8");b:GetHighlightTexture():SetVertexColor(1,1,1,.06)
  b:SetScript("OnEnter",function()GameTooltip:SetOwner(b,"ANCHOR_TOP");GameTooltip:AddLine(label,1,1,1);GameTooltip:Show()end)
  b:SetScript("OnLeave",function()GameTooltip:Hide()end)
  b:SetScript("OnEnable",function()b:SetAlpha(1)end);b:SetScript("OnDisable",function()b:SetAlpha(.35)end)
  b:SetScript("OnClick",callback)
  return b
end

-- One geometry/state owner for Guild and Whispers identities. Adapters provide
-- data and actions only; selection must never restore legacy tab anchors.
function Manager:PersonPriority(favorite,pinned)
  return favorite and (pinned and 0 or 1) or (pinned and 2 or 3)
end
function Manager:PersonRowHeight(host)
  return host:InterfaceTextSize()+self:PersonDetailSize(host)+9
end
function Manager:LayoutPersonRow(host,row,options)
  row.personRowOptions=options
  local size,detail=host:InterfaceTextSize(),self:PersonDetailSize(host)
  local height=self:PersonRowHeight(host)
  row:SetHeight(height)
  local label=options.label or row:GetFontString()
  if not row.personDetails then row.personDetails=row.details or row:CreateFontString(nil,"OVERLAY","SunderChatDockFont")end
  local secondary=row.personDetails
  if not row.selection then row.selection=row.selectedFill or row:CreateTexture(nil,"BACKGROUND");row.selection:SetAllPoints()end
  if not row.underline then row.underline=row.accent or row:CreateTexture(nil,"OVERLAY")end
  if not row.separator then row.separator=row:CreateTexture(nil,"BORDER")end
  local r,g,b=host:InterfaceAccent()
  row.selection:SetColorTexture(r,g,b,options.selected and .10 or options.unread and .035 or 0)
  row.underline:ClearAllPoints();row.underline:SetPoint("TOPLEFT",0,-2);row.underline:SetPoint("BOTTOMLEFT",0,2);row.underline:SetWidth(1)
  row.underline:SetColorTexture(r,g,b,.8);row.underline:SetShown(options.selected or options.unread)
  row.separator:ClearAllPoints();row.separator:SetPoint("BOTTOMLEFT",2,0);row.separator:SetPoint("BOTTOMRIGHT",-2,0);row.separator:SetHeight(1)
  row.separator:SetColorTexture(.7,.75,.8,.065);row.separator:SetShown(options.separator~=false)
  local right=2
  for _,entry in ipairs({{"favoriteButton","favorite","onFavorite","favorite"},{"pinControl","pin","onPin","pinned"}})do
    local field,icon,callback,state=unpack(entry)
    local control=row[field]
    if options[callback] and not control then
      control=host:IconButton(row,icon,icon=="pin" and "Pin / unpin this person" or "Favorite / unfavorite this person",function()end);row[field]=control
    end
    if control then
      control.iconOpacity=.35;control:SetFrameLevel(row:GetFrameLevel()+3)
      control:Show();control:SetEnabled(options[callback]~=nil)
      if not control.personIdentityHook then
        control.personIdentityHook=true
        control:HookScript("OnMouseDown",function()control.personPressedIdentity=row.personRowOptions and row.personRowOptions.identity end)
        control:HookScript("OnHide",function()control.personPressedIdentity=nil end)
      end
      control:SetScript("OnClick",function()
        local current=row.personRowOptions;local pressed=control.personPressedIdentity;control.personPressedIdentity=nil
        if current and (not pressed or pressed==current.identity) and current[callback]then current[callback]()end
      end)
      control:ClearAllPoints();control:SetPoint("RIGHT",row,"RIGHT",-right,0);control:SetSize(18,height-2);control.icon:SetSize(12,12)
      self:SetActionSelected(control,options[state],icon)
      right=right+18
    end
  end
  if row.unread then
    local count=options.unreadCount or 0
    self:UpdateUnreadBadge(row.unread,count,size)
    row.unread:ClearAllPoints();row.unread:SetPoint("RIGHT",row,"RIGHT",-right-2,0)
    if count>0 then right=right+row.unread:GetWidth()+5 end
  end
  host:WorkspaceFont(label,size)
  -- Native font glyphs sit below their line-box center. Raise the identity block
  -- two pixels so the separator has balanced visible breathing room.
  label:ClearAllPoints();label:SetPoint("TOPLEFT",row,"TOPLEFT",4,0);label:SetSize(math.max(1,row:GetWidth()-right-9),size+2)
  label:SetJustifyH("LEFT");label:SetJustifyV("MIDDLE");label:SetWordWrap(false)
  local shown=self:StylePersonDetail(host,secondary,options.person)
  secondary:ClearAllPoints();secondary:SetPoint("TOPLEFT",label,"BOTTOMLEFT",0,-1);secondary:SetSize(label:GetWidth(),detail+2)
  if not shown then label:ClearAllPoints();label:SetPoint("LEFT",row,"LEFT",4,2)end
end

function Manager:RegisterChatRoom(id,controller)
  self.chatRooms=self.chatRooms or {};self.chatRooms[id]=controller
end
function Manager:GetChatRoom(frame)
  for _,controller in pairs(self.chatRooms or {})do if controller.IsRoom and controller:IsRoom(frame)then return controller end end
end

function Manager:CreateEmptyConversation(parent,copy,options)
  options=options or {}
  local label=parent:CreateFontString(nil,"OVERLAY","SunderChatDockFont")
  label:SetJustifyH("CENTER");label:SetJustifyV("MIDDLE")
  label:SetPoint("CENTER",0,options.icon==false and 0 or -12);label:SetText(copy);label:SetTextColor(.65,.68,.72)
  local icon=parent:CreateTexture(nil,"ARTWORK");icon:SetSize(24,24);icon:SetPoint("CENTER",0,30)
  icon:SetTexture(ICONS.."inbox.tga");icon:SetVertexColor(.84,.66,.38,.55);icon:SetShown(options.icon~=false)
  return label,icon
end


-- Shared player actions: resolve only existing unit tokens, never target a player
-- or issue background inspection requests. Revalidate identity/range on click.
function Manager:ResolveInspectUnit(name)
  if type(name)~="string" or (_G.canaccessvalue and not canaccessvalue(name)) or name:find("|K",1,true)then return end
  local tokens={"player","target","focus","mouseover"}
  for i=1,4 do tokens[#tokens+1]="party"..i end
  for i=1,40 do tokens[#tokens+1]="raid"..i end
  for _,unit in ipairs(tokens)do
    local full=GetUnitName and GetUnitName(unit,true) or UnitName and UnitName(unit)
    if type(full)=="string" and (not _G.canaccessvalue or canaccessvalue(full)) and full:lower()==name:lower()then
      if InspectUnit and CanInspect and CanInspect(unit) and (not UnitIsConnected or UnitIsConnected(unit)) and (not CheckInteractDistance or CheckInteractDistance(unit,1))then return unit end
    end
  end
end
function Manager:AddInspectAction(menu,name)
  if type(name)~="string" or (_G.canaccessvalue and not canaccessvalue(name)) or name:find("|K",1,true)then return end
  local button=menu:CreateButton("Inspect",function()
    local unit=self:ResolveInspectUnit(name)
    if unit and not (InCombatLockdown and InCombatLockdown())then InspectUnit(unit)
    else Core:GetModule("Config"):Print("Inspect requires an available nearby player outside combat.")end
  end)
  if button and button.SetEnabled then button:SetEnabled(not (InCombatLockdown and InCombatLockdown()) and self:ResolveInspectUnit(name)~=nil)end
end
function Manager:StylePersonName(label,r,g,b,online)
  label:SetTextColor(r,g,b,online==false and .45 or 1)
end
