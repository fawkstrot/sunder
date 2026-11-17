local Core,Constants,Utils=unpack(select(2,...))
-- One implementation for persistent native chat rooms. Feature controllers supply
-- lifecycle, channel, roster data and caption adapters, never parallel chrome.
function Core.Components.InstallRosterRoom(G,options)
  local function theme()return Core:GetModule("Whispers")end
  local function state()return options.state(G)end
  local function profile()return options.profile(G)end
  local function accessible(v)return not _G.canaccessvalue or _G.canaccessvalue(v)end
  local function text(v)return accessible(v) and type(v)=="string" and not v:find("|K",1,true) and v or ""end
  local function number(v,fallback)return accessible(v) and type(v)=="number" and v or fallback end
  local function notice(v)return G.IsStartupNotice and G:IsStartupNotice(v) or false end
  local function acceptType(id)
    for _,kind in ipairs(options.historyTypes)do if ChatTypeInfo and ChatTypeInfo[kind] and ChatTypeInfo[kind].id==id then return true end end
    return false
  end
  local ROOM_FIELDS={"panel","rows","column","surface","toggle","guildLabel","countLabel","search","searchIcon","scroll","child","rail","empty","conversationLabel","motdLabel","captionHelp"}
  G.roomId=options.id;G.roomSettings=options.settings;G.roomLabel=options.title(G);G.editKey=options.editKey
  if not options.isolated then Core.Components.WindowManager:RegisterChatRoom(options.id,G) end
function G:RenderRoster()
  if self.renderingRoster then return end
  if not self.panel or not self.panel:IsVisible() then return end
  self.renderingRoster=true
  local pad=theme():BodyPadding();local size=theme():InterfaceTextSize()
  self.guildLabel:SetText("Members")
  self.countLabel:SetText((self.onlineCount or 0).." online")
  if self.compact then
    self.scroll:Hide();self.search:Hide();self.guildLabel:Hide();self.countLabel:Hide();self.empty:Hide();self.rail:Hide()
    Core.Components.WindowManager:UpdateListScrollIndicator(self.scroll,self.child,false)
    for _,row in ipairs(self.rows)do row:Hide()end
    self.renderingRoster=nil;return
  end
  self.scroll:Show();self.search:SetShown(not options.showSearch or options.showSearch(G));self.guildLabel:Show();self.countLabel:Show()
  local list=self.filtered or {};local detailSize=Core.Components.WindowManager:PersonDetailSize(theme());local rowHeight=Core.Components.WindowManager:PersonRowHeight(theme())
  self.rowHeight=rowHeight
  local height=math.max(1,self.scroll:GetHeight());local maximum=math.max(0,#list*rowHeight-height)
  local offset=math.max(0,math.min(maximum,self.scroll:GetVerticalScroll()))
  self.child:SetHeight(math.max(1,#list*rowHeight));self.child:SetWidth(math.max(1,self.scroll:GetWidth()))
  local first=math.floor(offset/rowHeight)+1
  local visible=math.min(256,math.ceil(height/rowHeight)+1)
  local r,g,b=theme():InterfaceAccent()
  for i=1,math.max(visible,#self.rows) do
    local row=self.rows[i];local member=i<=visible and list[first+i-1]
    if member then
      if not row then
        row=CreateFrame("Button",nil,self.child);self.rows[i]=row
        row:RegisterForClicks("LeftButtonUp","RightButtonUp")
        row:SetHighlightTexture("Interface\\Buttons\\WHITE8X8");row:GetHighlightTexture():SetVertexColor(r,g,b,.055)
        row.accent=row:CreateTexture(nil,"OVERLAY");row.accent:SetWidth(1);row.accent:SetPoint("TOPLEFT",-3,-3);row.accent:SetPoint("BOTTOMLEFT",-3,3);row.accent:SetColorTexture(r,g,b,.45);row.accent:Hide()
        row.separator=row:CreateTexture(nil,"BORDER");row.separator:SetPoint("BOTTOMLEFT",2,0);row.separator:SetPoint("BOTTOMRIGHT",-2,0);row.separator:SetHeight(1);row.separator:SetColorTexture(.7,.75,.8,.065)
        row.name=row:CreateFontString(nil,"OVERLAY","SunderChatDockFont")
        row.details=row:CreateFontString(nil,"OVERLAY","SunderChatDockFont")
        row.rank=row:CreateFontString(nil,"OVERLAY","SunderChatDockFont")
        row.note=row:CreateFontString(nil,"OVERLAY","SunderChatDockFont")
        row.selectedFill=row:CreateTexture(nil,"BACKGROUND");row.selectedFill:SetAllPoints();row.selectedFill:SetColorTexture(r,g,b,.075)
        row:SetScript("OnMouseDown",function(button)button.pressedMember=button.member and button.member.key end)
        row:SetScript("OnClick",function(button,mouse)
          if button.pressedMember and button.pressedMember~=button.member.key then button.pressedMember=nil;button.cancelDoubleClick=true;return end
          button.cancelDoubleClick=nil;button.pressedMember=nil
          if mouse=="RightButton" and MenuUtil and MenuUtil.CreateContextMenu then
            local person=button.member
            MenuUtil.CreateContextMenu(button,function(_,menu)
              menu:CreateTitle(person.name)
              if not options.isolated then Core.Components.WindowManager:AddInspectAction(menu,person.name) end
              if person.online then menu:CreateButton("Open whisper",function()self:OpenWhisper(person)end)end
              menu:CreateButton("Copy player name",function()Core:GetModule("ChatCopy"):ShowText("Player name",person.name)end)
            end)
          else
            self.selectedMember=button.member.key;self.selectedGuild=button.member.guildKey
            self:ShowMemberCard(button.member);self:RenderRoster()
          end
        end)
        row:SetScript("OnDoubleClick",function(button,mouse)if mouse=="LeftButton" and not button.cancelDoubleClick then self:OpenWhisper(button.member)end;button.cancelDoubleClick=nil end)
        row:SetScript("OnEnter",function(button)
          local person=button.member;if not person then return end
          button.accent:Show();GameTooltip:SetOwner(button,"ANCHOR_LEFT");GameTooltip:AddLine(person.name,1,1,1)
          GameTooltip:AddLine(person.rank,.65,.68,.73)
          if profile().publicNotes and person.note~="" then GameTooltip:AddLine(person.note:gsub("|","||"),.65,.68,.73,true)end
          GameTooltip:AddLine((person.level>0 and tostring(person.level).." " or "")..person.class,.8,.82,.85)
          if person.zone~="" then GameTooltip:AddLine(person.zone,.65,.68,.73)end
          local status=person.status
          GameTooltip:AddLine(not person.online and "Offline" or (status==1 or status=="AFK") and "Away" or (status==2 or status=="DND") and "Do not disturb" or "Online",.7,.75,.8)
          GameTooltip:AddLine(person.online and "Click for details. Use the right-side star/pin to organize. Double-click to whisper." or "This member is currently offline.",.7,.75,.8,true)
          GameTooltip:Show()
        end)
        row:SetScript("OnLeave",function(button)button.accent:SetShown(button.selected);GameTooltip:Hide()end)
        row:SetScript("OnHide",function(button)button.pressedMember=nil;button.accent:Hide()end)
      end
      row.member=member;row:SetSize(math.max(1,self.scroll:GetWidth()-12),rowHeight)
      row:ClearAllPoints();row:SetPoint("TOPLEFT",self.child,"TOPLEFT",0,-(first+i-2)*rowHeight)
      local selected=self.selectedMember==member.key and self.selectedGuild==member.guildKey
      row.selected=selected;row.selectedFill:SetShown(selected);row.accent:SetShown(selected)
      Core.Components.WindowManager:LayoutPersonRow(theme(),row,{identity=member.guildKey..":"..member.key,label=row.name,person=member,selected=selected,separator=first+i-1<#list,
        favorite=self:IsMemberFavorite(member),pinned=self:IsMemberPinned(member),
        onFavorite=function()self:ToggleMemberFavorite(row.member)end,onPin=function()self:ToggleMemberPin(row.member)end})
      local color=RAID_CLASS_COLORS and RAID_CLASS_COLORS[member.classFile]
      row.name:SetText(member.name);Core.Components.WindowManager:StylePersonName(row.name,color and color.r or .85,color and color.g or .85,color and color.b or .85,member.online)
      local detail=member.rank
      if profile().publicNotes and member.note~="" then detail=detail=="" and member.note or detail.." · "..member.note end
      row.rank:SetText(detail:gsub("|","||"));row.rank:SetTextColor(.58,.62,.68,member.online and 1 or .5)
      row.rank:Hide()
      row.note:SetText(member.note:gsub("|","||"));row.note:SetTextColor(.46,.51,.57,member.online and 1 or .5);row.note:Hide()
      row:Show()
    elseif row then row:Hide();row.member=nil end
  end
  if self.rosterFilters then self.rosterFilters:SetShown(not self.compact)end
  self.empty:SetText((self.rosterFilter=="favorites" and #list==0 and "No favorite members yet. Open a member card to add one.") or (self.rosterFilter=="zone" and #list==0 and "No members in your zone.") or self.rosterStatus or (self.query~="" and self.query and "No matching members." or "No members are online."))
  self.empty:SetShown(#list==0)
  self.syncingRail=true;self.rail:SetMinMaxValues(0,math.max(1,maximum));self.rail:SetValue(offset);self.syncingRail=nil
  self.rail:GetThumbTexture():SetHeight(math.max(14,(height-4)*height/math.max(height,#list*rowHeight)))
  self.rail:SetShown(maximum>0)
  Core.Components.WindowManager:UpdateListScrollIndicator(self.scroll,self.child,maximum<=0)
  self.renderingRoster=nil
end
function G:SelectInput()
  if self.frame then Core:GetModule("UIManager"):SelectMessageInput(self.frame)end
end
function G:SaveRoomState()
  if not self.room then return end
  state().open=self.room.hub:IsShown()
  state().minimized=not not self.room.minimized
  state().maximized=not not self.room.maximized
end
function G:CloseRoom()
  if not self.room then return end
  self:SaveHistory(true)
  self.room.windowManuallyClosed=true;self.room:StopHubMove()
  if self.room.finishCollapse then self.room.finishCollapse()end
  self.room.hub:Hide();self:SaveRoomState()
  if self.frame then Core:GetModule("UIManager"):ReleaseMessageInput(self.frame)end
end
function G:ToggleRoster()
  if options.hasRoster and not options.hasRoster(G)then return end
  local h=self.room;if not h then return end
  local restoring=h.minimized
  if restoring then
    local cfg=h:HubSettings();local minimum=h:HeaderHeight()+h:HeaderGap()+theme():InterfaceTextSize()*4+theme():BodyPadding()*5+30
    cfg.hubHeight=math.max(cfg.hubHeight or 400,minimum)
    profile().rosterShown=true;h:SetMinimized(false);if self.CloseGuildInfo then self:CloseGuildInfo()end;return
  end
  local show=self.compact or not profile().rosterShown
  profile().rosterShown=show
  if show then
    local minimum=h:HeaderHeight()+h:HeaderGap()+theme():InterfaceTextSize()*4+theme():BodyPadding()*5+30
    if h.hub:GetHeight()<minimum then h.hub:SetHeight(minimum);h:SaveHubGeometry()end
  end
  h:LayoutHub();Core.Components.WindowManager:RefreshRoomActions(h)
end
function G:ToggleMaximized()
  if self.room then Core.Components.WindowManager:ToggleMaximized(self.room,state())end
end
function G:EnsureRoom()
  if self.room then return self.room end
  local W=theme()
  local c=state().roomGeometry
  if not c then
    c={hubPoint="CENTER",hubX=80,hubY=70,hubWidth=760,hubHeight=400,minimizeEdge="TOP"}
    state().roomGeometry=c
  end
  local h=setmetatable({roomController=self,hostId=options.id,hubTabs={},hubOrder={},hubBorders={},minimized=false},{__index=function(_,key)local value=W[key];if type(value)=="function"then return value end end})
  self.room=h
  function h:WorkspaceName()return options.title(G)end
  function h:HubSettings()return state().roomGeometry end
  function h:SingleRowHeader()return true end
  function h:IsConversationList()return false end
  function h:RoomSidebarWidth()return G.panel and G.panel:IsShown() and G.panel:GetWidth() or 0 end
  function h:SaveMessageWindowState()
    self:ApplyHubAppearance();G:SaveRoomState()
  end
  function h:SetMinimized(value,instant)
    if self.minimized==not not value and not self.collapseAnimation then return end
    Core.Components.SetRoomMinimized(self,value,instant)
    if not value then G:AcknowledgeMessages()end
  end
  function h:PresentCollapsedHeader()
    Core.Components.WindowManager:RefreshRoomActions(self)
    self.hubTitle:SetText(self:WorkspaceName())
  end
  function h:UpdateTransitionBounds()self:RefreshWorkspaceClipRects()end
  function h:EnsureHubTabVisible()end
  function h:LayoutHubTabs()end
  function h:LayoutConversationStrip()end
  function h:LayoutHub()
    if G.frame and not self.minimized and not self.collapseAnimation then
      local window=Core:GetModule("UIManager"):GetChatWindow(G.frame)
      if window then G:LayoutWindow(window)end
    end
  end
  function h:SyncWorkspacePresentation()self:LayoutHub();self:ApplyHubAppearance()end
  function h:RefreshWorkspaceClipRects()
    for _,scroll in pairs({G.scroll,G.infoDrawer and G.infoDrawer.scroll})do if scroll.UpdateScrollChildRect then scroll:UpdateScrollChildRect()end end
  end
  function h:WorkspaceMenu(owner)
    if not (MenuUtil and MenuUtil.CreateContextMenu)then return end
    MenuUtil.CreateContextMenu(owner,function(_,menu)
      menu:CreateTitle(options.title(G))
      menu:CreateButton(self.minimized and "Restore window" or "Minimize window",function()self:SetMinimized(not self.minimized)end)
      menu:CreateButton(self.maximized and "Restore window size" or "Maximize window",function()G:ToggleMaximized()end)
      menu:CreateButton(options.title(G).." settings",function()Core:GetModule("Config"):OpenSettings(options.settings)end)
      if Core.Components.WindowManager:CanCloseWindow(self) then
        menu:CreateButton("Close window",function()if Core.Components.WindowManager:CanCloseWindow(self) then G:CloseRoom()end end)
      end
    end)
  end
  local hub=CreateFrame("Frame",options.frameName,UIParent);h.hub=hub;hub:Hide()
  hub:SetSize(c.hubWidth,c.hubHeight);hub:SetPoint(c.hubPoint,UIParent,c.hubPoint,c.hubX,c.hubY)
  hub:SetFrameStrata("MEDIUM");hub:SetToplevel(true);hub:SetClampedToScreen(true);hub:SetMovable(true);hub:EnableMouse(true)
  Core.Components.CreateRoomChrome(h,hub)
  local body=CreateFrame("Frame",nil,hub);body:SetAllPoints(hub);h.hubContent=body
  h.parking=CreateFrame("Frame",nil,UIParent);h.parking:Hide()
  h.hubActionButtons={}
  local actions={
    {"Close","close","Close window",function()self:CloseRoom()end},
    {"Settings","settings",options.title(G).." settings",function()Core:GetModule("Config"):OpenSettings(options.settings)end},
    {"Windows","window-menu","Window actions",function(owner)h:WorkspaceMenu(owner)end},
    {"Maximize","maximize","Maximize / restore window size",function()self:ToggleMaximized()end},
    {"Info","info","Guild information",function()options.infoAction(G)end},
    {"Roster","roster","Show / hide members",function()self:ToggleRoster()end},
  }
  for _,action in ipairs(actions)do if action[1]~="Info" or options.info then h.hubActionButtons[action[1]]=Core.Components.WindowManager:CreateWindowAction(h.hubChrome,action[1],h,action[4],function(b)h:StyleWindowIcon(b)end)end end
  Core.Components.WindowManager:CreateCollapseActions(h.hubChrome,h,function(edge)G:CollapseToward(edge)end,function(b)h:StyleWindowIcon(b)end)
  function h:LayoutHeaderStrip()G:LayoutRoomChrome()end
  if h.hubActionButtons.Info and options.infoTooltip then h.hubActionButtons.Info.windowTooltipOverride=options.infoTooltip end
  if h.hubActionButtons.Info then h.hubActionButtons.Info.windowSelected=function()return options.infoSelected(G) and not h.minimized end end
  h.hubActionButtons.Roster.windowCount=function()return tostring(self.onlineCount or 0).."/"..tostring(self.totalCount or 0)end
  h.hubActionButtons.Roster.windowEnabled=function()return not options.hasRoster or options.hasRoster(G)end
  h.hubActionButtons.Roster.windowSelected=function()return (not options.hasRoster or options.hasRoster(G)) and profile().rosterShown and not h.minimized and not self.autoCompact end
  h.minimizeButton=h.hubActionButtons.CollapseTop -- compatibility alias; no duplicate hidden control
  local badge=Core.Components.WindowManager:CreateUnreadIndicator(h.hubChrome);h.unreadBadge=badge
  badge:SetScript("OnClick",function()if h.minimized then h:SetMinimized(false)else G:AcknowledgeMessages()end end)
  badge:SetScript("OnEnter",function()
    GameTooltip:SetOwner(badge,"ANCHOR_TOP");GameTooltip:AddLine(tostring(G.unread or 0).." unread messages",1,.8,.4)
    GameTooltip:AddLine(tostring(G.onlineCount or 0).." members online",.7,.75,.8)
    GameTooltip:AddLine("Click to restore or mark read. No message toasters.",.7,.75,.8);GameTooltip:Show()
  end)
  badge:SetScript("OnLeave",function()GameTooltip:Hide()end)
  self:UpdateUnread()
  W.CreateHubOverlay(h)
  h.hubChrome:EnableMouse(true);h.hubChrome:RegisterForDrag("LeftButton")
  h.hubChrome:SetScript("OnDragStart",function()h:BeginHubMove(true)end)
  h.hubChrome:SetScript("OnDragStop",function()h:UpdateHubMove();h:StopHubMove()end)
  hub:SetScript("OnSizeChanged",function()if self.roomReady and not h.collapseAnimation then self:LayoutRoomChrome();h:LayoutHub()end end)
  hub:SetScript("OnShow",function()self:SaveRoomState();self:ScheduleRoster(true)end)
  hub:SetScript("OnHide",function()
    h:StopHubMove();h.hubResize:FinishResize()
    if h.finishCollapse then h.finishCollapse()end
    self.rosterGeneration=(self.rosterGeneration or 0)+1;self:SaveRoomState()
    local window=self.frame and Core:GetModule("UIManager"):GetChatWindow(self.frame)
    local input=window and Core:GetModule("UIManager"):GetLayoutEditBox(window)
    if input and input.HasFocus and input:HasFocus()then input:ClearFocus()end
  end)
  h.maximized=not not state().maximized
  self.roomReady=true
  self:LayoutRoomChrome();h:ApplyHubAppearance()
  return h
end
function G:LayoutRoomChrome()
  local h=self.room;if not h then return end
  local height,pad,icon=h:HeaderHeight(),h:HeaderPadding(),h:ToolbarIconSize()
  local size=icon+6;local right=pad
  h.hubChrome:SetHeight(height)
  right=Core.Components.WindowManager:LayoutHeaderActions(h,h.hubChrome,right,size,icon,2)
  h.unreadBadge:ClearAllPoints();h.unreadBadge:SetPoint("RIGHT",h.hubChrome,"RIGHT",-right,0);Core.Components.WindowManager:LayoutUnreadIndicator(h.unreadBadge,50,height,math.min(14,icon))
  h:WorkspaceFont(h.unreadBadge:GetFontString(),h:InterfaceTextSize());right=right+54
  self:UpdateUnread()
  h.hubGrip:ClearAllPoints();h.hubGrip:SetPoint("LEFT",h.hubChrome,"LEFT",pad,0);h.hubGrip:SetSize(18,height)
  h.hubMark:ClearAllPoints();h.hubMark:SetPoint("LEFT",h.hubGrip,"RIGHT",pad,0);h.hubMark:SetSize(icon,icon)
  h.hubMark:SetShown(Core.db.profile.chatTitleIcons~=false)
  h.hubTitle:ClearAllPoints();h.hubTitle:SetPoint("LEFT",h.hubMark,"RIGHT",pad,0);h.hubTitle:SetPoint("RIGHT",h.hubChrome,"RIGHT",-right-pad,0)
  h.hubTitle:SetHeight(math.max(1,height-pad));h.hubTitle:SetWordWrap(false);h:WorkspaceFont(h.hubTitle,h:InterfaceTextSize())
  h.hubRule:ClearAllPoints();h.hubRule:SetPoint("BOTTOMLEFT",h.hubChrome,"BOTTOMLEFT");h.hubRule:SetPoint("BOTTOMRIGHT",h.hubChrome,"BOTTOMRIGHT")
  h:PresentCollapsedHeader();h:ApplyHubAppearance();h.hubBackground:Show();h.hubHeaderFill:Show()
end
function G:CreatePanel(window)
  self.rooms=self.rooms or {}
  local cached=self.rooms[options.id]
  if cached then for _,key in ipairs(ROOM_FIELDS)do self[key]=cached[key]end;self.roomFrame=window.chatFrame;return end
  local layout={container=self:EnsureRoom().hubContent}
  local panel=CreateFrame("Frame",nil,layout.container);self.panel=panel;self.rows={}
  local column=CreateFrame("Frame",nil,layout.container);self.column=column
  self.conversationLabel=layout.container:CreateFontString(nil,"OVERLAY","SunderChatDockFont")
  self.conversationLabel:SetJustifyH("LEFT");self.conversationLabel:SetWordWrap(false);self.conversationLabel:SetTextColor(.65,.69,.75)
  self.motdLabel=layout.container:CreateFontString(nil,"OVERLAY","SunderChatDockFont")
  self.motdLabel:SetJustifyH("LEFT");self.motdLabel:SetWordWrap(false);self.motdLabel:SetTextColor(.58,.63,.69)
  self.captionHelp=CreateFrame("Button",nil,layout.container)
  self.captionHelp:SetScript("OnEnter",function(owner)
    GameTooltip:SetOwner(owner,"ANCHOR_TOP");GameTooltip:AddLine(options.caption(G),1,1,1)
    local motd=options.subtitle(G)
    if motd~=""then GameTooltip:AddLine(motd:gsub("|","||"),.65,.7,.76,true)end
    GameTooltip:Show()
  end)
  self.captionHelp:SetScript("OnLeave",function()GameTooltip:Hide()end)
  self.captionHelp:SetScript("OnClick",function()self:SelectInput()end)
  self.surface=self.room.hubBackground
  self.toggle=theme():IconButton(panel,"roster","Show / hide members",function()
    self:ToggleRoster()
  end)
  self.toggle:HookScript("OnEnter",function()
    GameTooltip:AddLine((self.onlineCount or 0).." online",.7,.75,.8)
    if self.autoCompact then GameTooltip:AddLine("Enlarge the window to expand the roster.",.7,.75,.8,true)end
    GameTooltip:Show()
  end)
  self.guildLabel=panel:CreateFontString(nil,"OVERLAY","SunderChatDockFont")
  self.countLabel=panel:CreateFontString(nil,"OVERLAY","SunderChatDockFont")
  self.search=CreateFrame("EditBox",nil,panel);self.search:SetAutoFocus(false);self.search:SetMaxLetters(64)
  self.search:SetFontObject("SunderChatDockFont");self.search:SetTextInsets(6,20,0,0)
  local searchPlate=self.search:CreateTexture(nil,"BACKGROUND");searchPlate:SetAllPoints();searchPlate:SetColorTexture(1,1,1,.04)
  self.searchPlaceholder=self.search:CreateFontString(nil,"OVERLAY","SunderChatDockFont")
  self.searchPlaceholder:SetPoint("LEFT",6,0);self.searchPlaceholder:SetText("Find a member…");self.searchPlaceholder:SetTextColor(.54,.58,.64)
  self.search:SetScript("OnTextChanged",function(box)self.query=box:GetText();self.searchPlaceholder:SetShown(self.query=="");self:FilterRoster()end)
  self.search:SetScript("OnEnterPressed",function(box)box:ClearFocus()end)
  self.search:SetScript("OnEscapePressed",function(box)box:SetText("");box:ClearFocus()end)
  self.search:SetScript("OnHide",function(box)box:ClearFocus()end)
  self.search:SetScript("OnEnter",function(box)
    GameTooltip:SetOwner(box,"ANCHOR_LEFT");GameTooltip:AddLine("Find a member",1,1,1)
    GameTooltip:AddLine("Search member details. Escape clears the search.",.7,.75,.8,true);GameTooltip:Show()
  end)
  self.search:SetScript("OnLeave",function()GameTooltip:Hide()end)
  self.searchIcon=self.search:CreateTexture(nil,"ARTWORK");self.searchIcon:SetTexture("Interface\\AddOns\\Sunder\\Media\\Icons\\search.tga");self.searchIcon:SetSize(11,11);self.searchIcon:SetPoint("RIGHT",-5,0);self.searchIcon:SetVertexColor(.6,.65,.7)
  local scroll=CreateFrame("ScrollFrame",nil,panel);self.scroll=scroll;scroll:SetClipsChildren(true)
  local child=CreateFrame("Frame",nil,scroll);self.child=child;child:SetSize(1,1);scroll:SetScrollChild(child)
  scroll:EnableMouseWheel(true)
  scroll:SetScript("OnMouseWheel",function(_,delta)
    local maximum=math.max(0,#(self.filtered or {})*(self.rowHeight or 50)-scroll:GetHeight())
    scroll:SetVerticalScroll(math.max(0,math.min(maximum,scroll:GetVerticalScroll()-delta*(self.rowHeight or 50)*2)))
    self:RenderRoster()
  end)
  scroll:SetScript("OnVerticalScroll",function()self:RenderRoster()end)
  local rail=CreateFrame("Slider",nil,panel);self.rail=rail
  local railTrack=rail:CreateTexture(nil,"BACKGROUND");railTrack:SetPoint("TOP");railTrack:SetPoint("BOTTOM");railTrack:SetWidth(2);railTrack:SetColorTexture(.7,.75,.8,.10)
  rail:SetFrameLevel(scroll:GetFrameLevel()+6)
  rail:SetOrientation("VERTICAL");rail:SetValueStep(1);rail:SetObeyStepOnDrag(true);rail:SetWidth(8)
  rail:SetThumbTexture("Interface\\Buttons\\WHITE8X8");rail:GetThumbTexture():SetWidth(3)
  rail:GetThumbTexture():SetVertexColor(theme():InterfaceAccent())
  rail:SetScript("OnValueChanged",function(_,value)if not self.syncingRail then scroll:SetVerticalScroll(value);self:RenderRoster()end end)
  self.empty=scroll:CreateFontString(nil,"OVERLAY","SunderChatDockFont")
  self.empty:SetPoint("TOPLEFT",0,0);self.empty:SetPoint("TOPRIGHT",0,0);self.empty:SetJustifyH("LEFT");self.empty:SetTextColor(.55,.6,.66)
  panel:EnableMouse(true)
  panel:SetScript("OnEnter",function()
    GameTooltip:SetOwner(panel,"ANCHOR_LEFT");GameTooltip:AddLine(options.caption(G),1,1,1)
    GameTooltip:AddLine((self.onlineCount or 0).." online · "..(self.totalCount or 0).." members in roster",.7,.75,.8)
    local motd=options.subtitle(G)
    if motd~="" then GameTooltip:AddLine(motd:gsub("|","||"),.65,.68,.73,true)end
    GameTooltip:Show()
  end)
  panel:SetScript("OnLeave",function()GameTooltip:Hide()end)
  panel:SetScript("OnShow",function()self:ScheduleRoster(true)end)
  panel:SetScript("OnHide",function()self.rosterGeneration=(self.rosterGeneration or 0)+1 end)
  local cached={};for _,key in ipairs(ROOM_FIELDS)do cached[key]=self[key]end
  self.rooms[options.id]=cached;self.roomFrame=window.chatFrame
end
function G:ClearRoomLayout(window)
  local smf=window.slidingMessageFrame
  smf.sharedFullSurface=nil;smf.keepRoomMessages=nil;smf.roomLabelOwner=nil
  if smf.roomGapUpdate and smf.gapBackground then smf.gapBackground:SetScript("OnUpdate",smf.roomGapUpdate)end
  smf.roomGapUpdate=nil
  if window.detachedLayout then window.detachedLayout.dock.keepRoomVisible=nil end
end
function G:LayoutWindow(window)
  if not self:IsRoom(window.chatFrame)then
    if self.frame==window.chatFrame then self:ClearRoomLayout(window)end
    return false
  end
  if InCombatLockdown() and window.chatFrame:IsProtected()then self.pendingLayout=true;return true end
  if self.layingOut then return true end
  if window.chatFrame.isDocked then FCF_UnDockFrame(window.chatFrame)end
  local h=self:EnsureRoom()
  if h.minimized or h.collapseAnimation then return true end
  self.layingOut=true
  if not self.panel or self.roomFrame~=window.chatFrame then self:CreatePanel(window)end
  local width,height=h.hub:GetWidth(),h.hub:GetHeight()
  local pad,size=theme():BodyPadding(),theme():InterfaceTextSize()
  local header=h:HeaderHeight()+h:HeaderGap()
  self.autoCompact=height<header+size*4+pad*5+30
  self.compact=self.autoCompact or not profile().rosterShown
  local hasRoster=not options.hasRoster or options.hasRoster(G)
  local showCaption=not options.showCaption or options.showCaption(G)
  local panelWidth=hasRoster and (self.compact and 26 or Core.Components.WindowManager:PeopleSidebarWidth(width)) or 0
  self.panel:ClearAllPoints();self.panel:SetPoint("TOPLEFT",h.hubContent,"TOPLEFT",0,-header);self.panel:SetPoint("BOTTOMLEFT",h.hubContent,"BOTTOMLEFT");self.panel:SetWidth(math.max(1,panelWidth));self.panel:SetShown(hasRoster)
  local input=Core:GetModule("UIManager"):GetLayoutEditBox(window)
  if self.CanSend and not self:CanSend()then input=nil end
  local anchor=Core.db.profile.editBoxAnchor
  local extent=input and math.max(0,input:GetHeight()+(anchor.position=="ABOVE" and anchor.yOfs or -anchor.yOfs))or 0
  local motd=options.subtitle(G)
  local titleSize=size+2
  local captionHeight=showCaption and (titleSize+pad*2+(motd~="" and size+5 or 0)) or 0
  self.conversationLabel:ClearAllPoints();self.conversationLabel:SetPoint("TOPLEFT",h.hubContent,"TOPLEFT",panelWidth+pad,-header-pad)
  self.conversationLabel:SetPoint("TOPRIGHT",h.hubContent,"TOPRIGHT",-pad,-header-pad);self.conversationLabel:SetHeight(titleSize+3)
  theme():WorkspaceFont(self.conversationLabel,titleSize)
  local font,_,flags=self.conversationLabel:GetFont();if font then self.conversationLabel:SetFont(font,titleSize,flags or "")end
  self.conversationLabel:SetTextColor(.78,.82,.88)
  self.conversationLabel:SetText(options.caption(G)~="" and options.caption(G) or options.title(G))
  self.motdLabel:ClearAllPoints();self.motdLabel:SetPoint("TOPLEFT",self.conversationLabel,"BOTTOMLEFT",0,-3);self.motdLabel:SetPoint("TOPRIGHT",h.hubContent,"TOPRIGHT",-pad,-header-pad-titleSize-6)
  theme():WorkspaceFont(self.motdLabel,size);self.motdLabel:SetHeight(size+3);self.motdLabel:SetText(motd:gsub("|","||"));self.motdLabel:SetShown(motd~="")
  self.captionHelp:ClearAllPoints();self.captionHelp:SetPoint("TOPLEFT",h.hubContent,"TOPLEFT",panelWidth,-header);self.captionHelp:SetSize(math.max(1,width-panelWidth),captionHeight)
  local top=math.max(0,h:HeaderHeight()-Constants.DOCK_HEIGHT)+captionHeight+(anchor.position=="ABOVE" and extent or 0)
  self.column:ClearAllPoints();self.column:SetPoint("TOPLEFT",h.hubContent,"TOPLEFT",panelWidth,-top)
  self.column:SetPoint("BOTTOMRIGHT",h.hubContent,"BOTTOMRIGHT",0,anchor.position=="BELOW" and extent or 0);self.column:Show()
  self.toggle:ClearAllPoints();self.toggle:SetPoint("TOPLEFT",2,-pad);self.toggle:SetSize(20,20);self.toggle:SetShown(self.compact)
  self.guildLabel:ClearAllPoints();self.guildLabel:SetPoint("TOPLEFT",pad,-pad);self.guildLabel:SetHeight(size+4);self.guildLabel:SetWidth(60)
  self.countLabel:ClearAllPoints();self.countLabel:SetPoint("TOPLEFT",self.guildLabel,"TOPRIGHT",4,0);self.countLabel:SetPoint("TOPRIGHT",-pad,-pad);self.countLabel:SetHeight(size+4)
  for _,label in ipairs({self.guildLabel,self.countLabel})do label:SetWordWrap(false);label:SetJustifyH("LEFT");theme():WorkspaceFont(label,size)end
  self.countLabel:SetJustifyH("RIGHT");self.guildLabel:SetTextColor(.58,.62,.68);self.countLabel:SetTextColor(theme():InterfaceAccent())
  local searchTop=pad+size+8
  local showSearch=not options.showSearch or options.showSearch(G)
  self.search:SetShown(showSearch)
  if not showSearch then
    self.search:ClearFocus()
    if self.query and self.query~=""then self.query="";self.search:SetText("")end
  end
  local listTop=searchTop
  if showSearch then
    self.search:ClearAllPoints();self.search:SetPoint("TOPLEFT",pad,-searchTop);self.search:SetPoint("TOPRIGHT",-pad,-searchTop);self.search:SetHeight(size+10)
    theme():WorkspaceFont(self.searchPlaceholder,math.max(10,size-1));self.searchPlaceholder:SetWidth(math.max(1,panelWidth-pad*2-26));self.searchPlaceholder:SetWordWrap(false)
    listTop=searchTop+size+10+6
  end
  if self.LayoutRosterFilters then listTop=self:LayoutRosterFilters(showSearch and searchTop+size+10+3 or searchTop,panelWidth)end
  self.scroll:ClearAllPoints();self.scroll:SetPoint("TOPLEFT",pad,-listTop);self.scroll:SetPoint("BOTTOMRIGHT",0,0)
  Core.Components.WindowManager:LayoutListScrollRail(self.rail,self.scroll)
  theme():WorkspaceFont(self.empty,size)
  window.tab:SetParent(h.parking)
  if input then input:SetSunderParent(self.column,true)end
  local smf=window.slidingMessageFrame
  if smf then smf.sharedFullSurface=true;smf.keepRoomMessages=true end
  local drawerWidth,replaceChat=0,false
  if self.LayoutGuildInfo then drawerWidth,replaceChat=self:LayoutGuildInfo(panelWidth,header,height)end
  self.column:SetPoint("BOTTOMRIGHT",h.hubContent,"BOTTOMRIGHT",-drawerWidth,anchor.position=="BELOW" and extent or 0)
  self.conversationLabel:SetShown(showCaption and not replaceChat);self.motdLabel:SetShown(showCaption and not replaceChat and motd~="");self.captionHelp:SetShown(showCaption and not replaceChat)
  if not replaceChat then
    self.conversationLabel:SetPoint("TOPRIGHT",h.hubContent,"TOPRIGHT",-drawerWidth-pad,-header-pad)
    self.motdLabel:SetPoint("TOPRIGHT",h.hubContent,"TOPRIGHT",-drawerWidth-pad,-header-pad-titleSize-6)
    self.captionHelp:SetWidth(math.max(1,width-panelWidth-drawerWidth))
  end
  if window.readOnlyTranscript then
    local transcript=window.readOnlyTranscript
    transcript:SetParent(self.column)
    transcript:ClearAllPoints()
    transcript:SetPoint("TOPLEFT",self.column,"TOPLEFT",0,-Constants.DOCK_HEIGHT)
    transcript:SetPoint("BOTTOMRIGHT",self.column,"BOTTOMRIGHT")
  else
    smf:SetLayout(self.column,math.max(1,width-panelWidth-drawerWidth),math.max(1,height-top-extent*(anchor.position=="BELOW" and 1 or 0)),input or false,nil)
    -- Native slots may have rendered retained history before room registration.
    -- Invalidate presentation once on ownership binding, never on every resize.
    if smf.roomLabelOwner~=self then
      smf.roomLabelOwner=self
      smf:RefreshLayout(true)
    end
    smf:UpdateAlwaysVisible()
    if smf.gapBackground then
      smf:UpdateGapBackground()
      if not smf.roomGapUpdate then smf.roomGapUpdate=smf.gapBackground:GetScript("OnUpdate")end
      smf.gapBackground:SetScript("OnUpdate",nil)
    end
  end
  self.column:SetShown(not replaceChat)
  if window.detachedLayout then window.detachedLayout.container:Hide()end
  h:ApplyHubAppearance();h.hubBackground:Show()
  self.layingOut=nil;self:RenderRoster()
  if self.rosterDirty or not self.members then self:ScheduleRoster(true)end
  return true
end
function G:SaveHistory(allowPartial)
  if self.restoringHistory and not allowPartial or not profile().remember or not self.frame or self.currentGuild~=options.scope(G) then return end
  local frame=self.frame;local lines={};local bytes=0
  if not frame.GetNumMessages or not frame.GetMessageInfo then return end
  local count=frame:GetNumMessages()
  -- An empty native slot during startup/reconfiguration is not a history reset.
  -- Intentional new-session/reset paths retire the store explicitly.
  local previous=Core.db.char[options.historyKey]
  if count==0 and previous and previous.key==self.currentGuild and #(previous.lines or {})>0 then return end
  for i=count,math.max(1,count-199),-1 do
    local value,r,g,b,typeID,accessID,lineID=frame:GetMessageInfo(i)
    value=text(value)
    if value~="" and not notice(value) and accessible(typeID) and type(typeID)=="number" and acceptType(typeID) then
      if bytes+#value>512*1024 then break end
      bytes=bytes+#value
      local tp=Core:GetModule("TextProcessing",true)
      local line={value,number(r,1),number(g,1),number(b,1),typeID=typeID,own=tp and tp.IsOwnChatLine and tp:IsOwnChatLine(value,typeID,lineID) or false}
      local entry=frame.historyBuffer and frame.historyBuffer:GetEntryAtIndex(count-i+1)
      line.receivedAt=Utils.getMessageReceipt(entry)
      table.insert(lines,1,line)
    end
  end
  if allowPartial and self.restoringHistory then
    local previous=Core.db.char[options.historyKey]
    if previous and previous.key==self.currentGuild then
      local old={};for _,line in ipairs(previous.lines or {})do if not notice(text(line[1]))then old[#old+1]=line end end;local overlap=0
      for count=math.min(#old,#lines),1,-1 do
        local match=true
        for i=1,count do
          local a,b=old[#old-count+i],lines[i]
          if a[1]~=b[1] or a.receivedAt~=b.receivedAt or a.typeID~=b.typeID then match=false;break end
        end
        if match then overlap=count;break end
      end
      local merged={};for _,line in ipairs(old)do merged[#merged+1]=line end
      for i=overlap+1,#lines do merged[#merged+1]=lines[i]end
      lines=merged;bytes=0
      for i=#lines,1,-1 do
        bytes=bytes+#lines[i][1]
        if #lines-i+1>200 or bytes>512*1024 then
          for j=i,1,-1 do table.remove(lines,j)end
          break
        end
      end
    end
  end
  Core.db.char[options.historyKey]={key=self.currentGuild,lines=lines}
end
function G:OnNativeMessage(frame)
  if not self:IsRoom(frame) or self.restoringHistory or self.historyScheduled then return end
  self.historyScheduled=true
  C_Timer.After(.2,function()self.historyScheduled=nil;self:SaveHistory()end)
end
function G:RestoreHistory()
  if self.restoredFrame==self.frame or not profile().remember then return end
  self.restoredFrame=self.frame
  local saved=Core.db.char[options.historyKey]
  if not saved or saved.key~=self.currentGuild or not saved.lines or not self.frame.BackFillMessage then return end
  local retained={};for _,line in ipairs(saved.lines)do if not notice(text(line[1]))then retained[#retained+1]=line end end
  saved.lines=retained
  local frame=self.frame;local index=#saved.lines;self.restoringHistory=true
  local generation=self.historyGeneration or 0
  local function chunk()
    if generation~=(self.historyGeneration or 0) then return end
    if self.frame~=frame or self.currentGuild~=options.scope(G) or not profile().enabled or not profile().remember then self.restoringHistory=nil;return end
    local last=math.max(1,index-11)
    for i=index,last,-1 do
      Utils.restoreChatLine(frame,saved.lines[i])
    end
    index=last-1
    if index>0 then C_Timer.After(0,chunk)else self.restoringHistory=nil end
  end
  if index>0 then chunk()else self.restoringHistory=nil end
end
function G:SavedFrame()
  local info=FCF_GetChatWindowInfo or GetChatWindowInfo
  if not info then return end
  local function namedFrame(id)
    local frame=_G["ChatFrame"..id]
    if not frame or self.closedSlots and self.closedSlots[frame]then return end
    local ok,name=pcall(info,id)
    if ok and text(name)==options.nativeTitle then return frame end
  end
  local id=tonumber(state().frameID)
  if id and id>=3 and id<=(NUM_CHAT_WINDOWS or 10)then
    local frame=namedFrame(id)
    if frame then return frame end
  end
  -- Native chat-cache survives character renames/profile loss. Recover only a
  -- unique, open, dedicated room slot; initialized/closed/unrelated slots stay alone.
  if not GetChatWindowMessages then return end
  local candidate
  for slot=3,(NUM_CHAT_WINDOWS or 10)do
    local frame=namedFrame(slot)
    local window=frame and Core:GetModule("UIManager"):GetChatWindow(frame)
    local renderer=window and window.slidingMessageFrame
    -- Sunder hides native frames while its replacement renderer is visible.
    local open=frame and (frame:IsShown() or frame.isDocked or renderer and renderer:IsVisible())
    if open then
      local groups={pcall(GetChatWindowMessages,slot)}
      local dedicated=groups[1] and #groups>1
      for i=2,#groups do if not options.nativeGroups[groups[i]]then dedicated=false end end
      if dedicated then
        if candidate then return end -- Ambiguous: do not take over either window.
        candidate=frame
      end
    end
  end
  if candidate then return candidate,true end
end
function G:RestoreWindow()
  if not profile().enabled then return end
  local wasOpen=state().open;local wasMinimized=state().minimized;local frame,recovered=self:SavedFrame()
  if recovered then wasOpen=true end
  if not frame then return end
  if InCombatLockdown() and frame:IsProtected() then self.pendingRestore=true;return end
  if not self:ConfigureFrame(frame,false)then return end
  frame:SetShown(not not wasOpen)
  local h=self:EnsureRoom();h.hub:SetShown(not not wasOpen)
  if wasMinimized then h:SetMinimized(true,true)end
end

end
