local Core = unpack(select(2, ...))
local W = Core:GetModule("Whispers")
local function accessible(v) return not _G.canaccessvalue or _G.canaccessvalue(v) end
local function read(box,method,attribute)
  if box[method] then return box[method](box) end
  return box.GetAttribute and box:GetAttribute(attribute)
end
-- Native reply shortcuts can activate the main editor. Move that editor's
-- presentation, keeping its draft, recipient, and secure send path untouched.
function W:ReplyWindow(box)
  if not self.ready or not self:Settings().enabled then return end
  local kind=read(box,"GetChatType","chatType")
  local target=read(box,"GetTellTarget","tellTarget")
  if not accessible(kind) or not accessible(target) or target==nil or (kind~="WHISPER" and kind~="BN_WHISPER") then return end
  for frame,record in pairs(self.records or {}) do
    local peer=frame.chatTarget
    if frame.inUse and record.placement~="main" and frame.chatType==kind and accessible(peer) then
      local match=peer==target
      if not match and kind=="WHISPER" and type(peer)=="string" and type(target)=="string" then match=peer:lower()==target:lower() end
      if match then return Core:GetModule("UIManager"):GetChatWindow(frame),frame end
    end
  end
end
function W:ReleaseReplyEditor(box,immediate)
  local route=self.replyEditors and self.replyEditors[box]
  if not route then return end
  route.generation=(route.generation or 0)+1
  local generation=route.generation
  local function release()
    if self.replyEditors[box]~=route or route.generation~=generation or not immediate and box:HasFocus() then return end
    self.replyEditors[box]=nil
    if route.target.replyEditBox==box then route.target.replyEditBox=nil end
    local ui=Core:GetModule("UIManager")
    if route.source and route.source.active~=false then ui:RefreshChatFrameLayout(route.source.chatFrame) end
    if route.target.active~=false and route.target.slidingMessageFrame then ui:RefreshChatFrameLayout(route.target.chatFrame) end
  end
  if immediate then release() else C_Timer.After((tonumber(Core.db.profile.editBoxFadeOutDuration) or .2)+.05,release) end
end
function W:RouteReplyEditor(box)
  if not box or not box:HasFocus() then return end
  local target,frame=self:ReplyWindow(box)
  local old=self.replyEditors and self.replyEditors[box]
  if old and old.target==target then old.generation=(old.generation or 0)+1;return end
  if old then self:ReleaseReplyEditor(box,true) end
  if not target or target.editBox==box then return end
  local ui=Core:GetModule("UIManager")
  local source
  for _,window in pairs(ui.state.windows) do if window.editBox==box then source=window;break end end
  if not source then return end
  self.replyEditors=self.replyEditors or {}
  self.replyEditors[box]={target=target,source=source,generation=1}
  target.replyEditBox=box
  local height=target.slidingMessageFrame.config and target.slidingMessageFrame.config.height
  if self:IsGrouped(frame) then
    local host=self:HubFor(frame)
    host.windowManuallyClosed=false;host.hubOpenedAt=GetTime();host.selected=frame
    host:SetMinimized(false);host.hub:Show();host.hub:SetAlpha(1);host:RefreshHubSelection()
  else self:Reveal(frame) end
  source.slidingMessageFrame:SetTyping(false)
  ui:RefreshChatFrameLayout(source.chatFrame);ui:RefreshChatFrameLayout(frame)
  local smf=target.slidingMessageFrame
  if height and smf.ApplyDynamicEditBoxHeight then smf:ApplyDynamicEditBoxHeight(height);smf:UpdateDynamicEditBoxLayout() end
end
function W:LayoutEditBox(window)
  if window.replyEditBox then return window.replyEditBox end
  if self.replyEditors and self.replyEditors[window.editBox] then return false end
  return window.editBox
end

local apply=W.ApplySettings
function W:ApplySettings(...)
  if not self:Settings().enabled then
    local boxes={};for box in pairs(self.replyEditors or {}) do boxes[#boxes+1]=box end
    for _,box in ipairs(boxes) do self:ReleaseReplyEditor(box,true) end
  end
  return apply(self,...)
end
local closed=W.OnWindowClosed
function W:OnWindowClosed(frame)
  local boxes={}
  for box,route in pairs(self.replyEditors or {}) do if route.target.chatFrame==frame or route.source.chatFrame==frame then boxes[#boxes+1]=box end end
  for _,box in ipairs(boxes) do self:ReleaseReplyEditor(box,true) end
  return closed(self,frame)
end
