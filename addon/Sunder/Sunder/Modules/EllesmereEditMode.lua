local Core,Constants=unpack(select(2,...))
local E=Core:GetModule("Ellesmere")
local function copy(t)
  if type(t)~="table" then return t end
  local out={};for k,v in pairs(t)do out[k]=copy(v)end;return out
end
local function position(frame)
  local point,_,relPoint,x,y=frame:GetPoint(1)
  return {point=point or "CENTER",relPoint=relPoint or point or "CENTER",x=x or 0,y=y or 0}
end
local function place(frame,p)
  if InCombatLockdown() then return end
  frame:ClearAllPoints();frame:SetPoint(p.point,UIParent,p.relPoint or p.point,p.x or 0,p.y or 0)
end
local function canonical(frame)
  local scale=UIParent:GetEffectiveScale()/frame:GetEffectiveScale()
  return {point="BOTTOMLEFT",relPoint="BOTTOMLEFT",x=frame:GetLeft()-UIParent:GetLeft()*scale,y=frame:GetBottom()-UIParent:GetBottom()*scale}
end
local function refresh(key)Core:Dispatch(Constants.ACTIONS.UpdateConfig(key))end

function E:AddEditElement(key,label,frame,section,setWidth,setHeight,save,load,apply,hidden,live)
  local api=_G.EllesmereUI
  if api._ELEMENT_SETTINGS_MAP and api.GetPluginModuleKey then
    local module=api.GetPluginModuleKey("Sunder","chat")
    if module then api._ELEMENT_SETTINGS_MAP[key]={module=module,page=section}end
  end
  local existing=self.editElements[key]
  if existing and existing.frame==frame then
    existing.element.label=label
    if self.editSession and not self.editSession.snapshots[key] then
      self.editSession.snapshots[key]={position=copy(load()),width=frame:GetWidth(),height=frame:GetHeight()}
    end
    return
  end
  local element={key=key,label=label,group="Sunder",order=700,ownsPosition=true,noSpecLayout=true,
    getFrame=function()return frame end,getSize=function()return frame:GetWidth(),frame:GetHeight()end,
    isHidden=hidden or function()return false end,
    setWidth=function(_,value)if not InCombatLockdown() then setWidth(math.max(100,math.min(UIParent:GetWidth(),tonumber(value) or 100)))end end,
    setHeight=function(_,value)if not InCombatLockdown() then setHeight(math.max(100,math.min(UIParent:GetHeight(),tonumber(value) or 100)))end end,
    savePosition=function(_,point,relPoint,x,y)
      if InCombatLockdown() then return end
      place(frame,{point=point,relPoint=relPoint,x=x,y=y});save(canonical(frame))
    end,
    loadPosition=function()return copy(load())end,
    clearPosition=function()place(frame,{point="CENTER",x=0,y=0});save(canonical(frame))end,
    applyPosition=function()if not InCombatLockdown() then apply()end end,
    onLiveMove=function()if live then live()end end,
  }
  frame:SetClampedToScreen(true)
  self.editElements[key]={element=element,frame=frame,section=section}
  api:RegisterUnlockElements({element},"Sunder")
  if self.editSession then
    local w,h=frame:GetWidth(),frame:GetHeight()
    self.editSession.snapshots[key]={position=copy(load()),width=w,height=h}
  end
end

-- UIManager prepares every built-in slot; active means initialized, not open.
function E:IsDetachedEditWindow(window)
  local frame=window and window.chatFrame
  if not window or not window.active or not frame or frame.isDocked or not window.detachedLayout then return false end
  local W=Core:GetModule("Whispers")
  local record=W.records and W.records[frame]
  if record then return record.placement=="detached" and frame.inUse~=false end
  if window.temporary or frame.isTemporary then return frame.inUse==true end
  if frame==_G.ChatFrame2 and Core.db.profile.combatLogHidden then return false end
  local id=tonumber((frame:GetName() or ""):match("^ChatFrame(%d+)$"))
  if id and FCF_GetChatWindowInfo then
    local ok,_,_,_,_,_,_,shown=pcall(FCF_GetChatWindowInfo,id)
    if ok then return shown==true or shown==1 end
  end
  -- Without native slot metadata, require a visible real tab instead of guessing.
  local tab=_G[(frame:GetName() or "").."Tab"]
  return not not (tab and tab:IsShown() and window.detachedLayout.container and window.detachedLayout.container:IsShown())
end

function E:RefreshEditElements()
  local api=_G.EllesmereUI
  if not (api and api.RegisterUnlockElements) or InCombatLockdown() then return end
  self.editElements=self.editElements or {}
  local ui=Core:GetModule("UIManager")
  local W=Core:GetModule("Whispers")
  local seen={}
  local main=ui.moverFrame
  if main then
    local key="Sunder_Chat";seen[key]=true
    self:AddEditElement(key,"Chat",main,"Chat windows",
      function(value)Core.db.profile.frameWidth=value;refresh("frameWidth");main:UpdateLayoutBounds()end,
      function(value)local extra=main:GetHeight()-Core.db.profile.frameHeight;Core.db.profile.frameHeight=math.max(100,value-extra);refresh("frameHeight");main:UpdateLayoutBounds()end,
      function(p)Core.db.profile.positionAnchor={point=p.point,xOfs=p.x,yOfs=p.y};refresh("framePosition")end,
      function()local p=Core.db.profile.positionAnchor;return {point=p.point,relPoint=p.point,x=p.xOfs,y=p.yOfs}end,
      function()refresh("framePosition")end)
    if self.editSession then main:Show();main.boundsFrame:Hide() end
  end
  for _,window in pairs(ui.state and ui.state.windows or {})do
    local frame=window.chatFrame
    local record=W.records and W.records[frame]
    if self:IsDetachedEditWindow(window) then
      local key="Sunder_"..frame:GetName();seen[key]=true
      local function save(p)
        place(frame,p)
        if record then record.saved=record.saved or {};record.saved.point=p.point;record.saved.x=p.x;record.saved.y=p.y;record.saved.width=frame:GetWidth();record.saved.height=frame:GetHeight()end
        if not frame.isTemporary and FCF_SavePositionAndDimensions then FCF_SavePositionAndDimensions(frame)end
        if W.Save then W:Save()end
      end
      local nativeTab=_G[frame:GetName().."Tab"]
      local label=nativeTab and nativeTab.Text and nativeTab.Text:GetText() or frame.name or frame:GetName()
      if _G.canaccessvalue and not _G.canaccessvalue(label) then label="Chat window" end
      self:AddEditElement(key,label,frame,"Chat windows",
        function(value)frame:SetWidth(value);ui:RefreshChatFrameLayout(frame);save(canonical(frame))end,
        function(value)frame:SetHeight(value);ui:RefreshChatFrameLayout(frame);save(canonical(frame))end,
        save,function()return position(frame)end,function()ui:RefreshChatFrameLayout(frame)end,
        function()return not self:IsDetachedEditWindow(window) end)
      self.editElements[key].element.getInsets=function()
        local dock=window.detachedLayout and window.detachedLayout.dock
        local overlay=dock and dock.moverOverlay
        if not overlay then return 0,0,0,0 end
        dock:UpdateMoverBounds()
        local l,b,w,h=overlay:GetRect();local fl,fb,fw,fh=frame:GetRect()
        if not(l and b and w and h and fl and fb and fw and fh)then return 0,0,0,0 end
        local scale=overlay:GetEffectiveScale()/frame:GetEffectiveScale()
        return l*scale-fl,fl+fw-(l+w)*scale,fb+fh-(b+h)*scale,b*scale-fb
      end
    end
  end
  for id,host in pairs(W.workspaces or {})do
    if host.hub and not host.transientSettings and W:Settings().enabled then
      local frame=host.hub;local key="Sunder_Whispers_"..id;seen[key]=true
      if self.editSession and not self.editSession.views[host] then
        self.editSession.views[host]={shown=frame:IsShown(),alpha=frame:GetAlpha(),minimized=host.minimized,closed=host.windowManuallyClosed}
        if host.finishCollapse then host.finishCollapse()end
        if host.minimized then host:SetMinimized(false,true)end
      end
      self:AddEditElement(key,host:WorkspaceName(),frame,"Whispers",
        function(value)frame:SetWidth(math.max(host.minimumWorkspaceWidth or 480,value));host:SaveHubGeometry();host:LayoutHub()end,
        function(value)frame:SetHeight(math.max(220,value));host:SaveHubGeometry();host:LayoutHub()end,
        function(p)place(frame,p);host:SaveHubGeometry()end,
        function()local c=host:HubSettings();return {point=c.hubPoint,relPoint=c.hubPoint,x=c.hubX,y=c.hubY}end,
        function()local c=host:HubSettings();place(frame,{point=c.hubPoint,x=c.hubX,y=c.hubY});host:LayoutHub()end,
        function()return not W.workspaces[id] or not W:Settings().enabled end,
        function()host:RefreshWorkspaceClipRects()end)
      if self.editSession then host.windowManuallyClosed=false;host.lastUserInteraction=GetTime();host.hubOpenedAt=GetTime();frame:SetAlpha(1);frame:Show();host.hubOverlay:Hide()end
    end
  end
  for key,entry in pairs(self.editElements)do
    if not seen[key] then
      if api.UnregisterUnlockElement then api:UnregisterUnlockElement(key)end
      if api._ELEMENT_SETTINGS_MAP then api._ELEMENT_SETTINGS_MAP[key]=nil end
      self.editElements[key]=nil
    end
  end
end

function E:OnEllesmereEditSession(active,action)
  if not active and InCombatLockdown() then self.pendingEditClose=action or "exit";return end
  if active then
    if self.editSession or InCombatLockdown() then return end
    local W=Core:GetModule("Whispers")
    self.editSession={wasUnlocked=Core.sunderMoverUnlocked,snapshots={},views={},restoring=W.restoringWindowState}
    Core.sunderEllesmereEditing=true
    if Core.sunderMoverUnlocked then Core:Dispatch(Constants.ACTIONS.LockMover())end
    W.restoringWindowState=true
    if W:Settings().enabled and W:Settings().mode=="hub" then
      local created=not W.hub;W:EnsureHub()
      if created then self.editSession.views[W]={shown=false,alpha=1,minimized=false,closed=W.windowManuallyClosed}end
    end
    -- Existing elements also need a fresh session snapshot.
    self:RefreshEditElements()
    self.editTicker=C_Timer.NewTicker(.2,function()self:RefreshEditElements()end)
  else
    local session=self.editSession;if not session then return end
    if self.editTicker then self.editTicker:Cancel();self.editTicker=nil end
    if action=="discard" and not InCombatLockdown() then
      for key,snapshot in pairs(session.snapshots)do
        local entry=self.editElements[key]
        if entry then
          local element=entry.element;element.setWidth(key,snapshot.width);element.setHeight(key,snapshot.height)
          local p=snapshot.position;if p then element.savePosition(key,p.point,p.relPoint,p.x,p.y);element.applyPosition(key)end
        end
      end
    end
    self.editSession=nil;Core.sunderEllesmereEditing=nil
    local W=Core:GetModule("Whispers");W.restoringWindowState=session.restoring
    for host,view in pairs(session.views)do
      if view.minimized then host:SetMinimized(true,true)end
      host.windowManuallyClosed=view.closed;host.hub:SetAlpha(view.alpha);host.hub:SetShown(view.shown)
    end
    local ui=Core:GetModule("UIManager")
    if ui.moverFrame then ui.moverFrame.boundsFrame:Show();ui.moverFrame:Hide()end
    if session.wasUnlocked and not InCombatLockdown() then Core:Dispatch(Constants.ACTIONS.UnlockMover())end
  end
end
function E:SetupEditModeIntegration()
  if self.editDisabled then return false end
  if self.pendingEditClose and not InCombatLockdown() then local action=self.pendingEditClose;self.pendingEditClose=nil;self:OnEllesmereEditSession(false,action)end
  local api=_G.EllesmereUI
  if not (api and api.RegisterUnlockElements and api.RegisterUnlockModeListener) then return false end
  if self.editAPI~=api then
    self.editAPI=api
    api:RegisterUnlockModeListener("Sunder",function(active,action)self:OnEllesmereEditSession(active,action)end)
  end
  self:RefreshEditElements()
  return true
end
local enable=E.OnEnable
function E:OnEnable()
  self.editDisabled=nil
  if enable then enable(self)end
  self.editEvents=self.editEvents or CreateFrame("Frame")
  for _,event in ipairs({"ADDON_LOADED","PLAYER_ENTERING_WORLD","PLAYER_REGEN_ENABLED"})do self.editEvents:RegisterEvent(event)end
  self.editEvents:SetScript("OnEvent",function()C_Timer.After(0,function()self:SetupEditModeIntegration()end)end)
  C_Timer.After(0,function()self:SetupEditModeIntegration()end)
end

local disable=E.OnDisable
function E:OnDisable()
  self.editDisabled=true
  if self.editSession then self:OnEllesmereEditSession(false,"discard")end
  local api=self.editAPI
  if api then
    if api.UnregisterUnlockModeListener then api:UnregisterUnlockModeListener("Sunder")end
    for key in pairs(self.editElements or {})do
      if api.UnregisterUnlockElement then api:UnregisterUnlockElement(key)end
      if api._ELEMENT_SETTINGS_MAP then api._ELEMENT_SETTINGS_MAP[key]=nil end
    end
  end
  if self.editEvents then self.editEvents:UnregisterAllEvents()end
  self.editAPI=nil;self.editElements=nil
  if disable then disable(self)end
end
