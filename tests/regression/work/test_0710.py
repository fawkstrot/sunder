exec(open('work/test_079.py',encoding='utf-8').read())
lua.execute('''
for _,host in ipairs({W,W:GetWorkspace("group2"),W:GetWorkspace("group1")}) do
 host:OpenMessages();host:SetMinimized(false,true)
 for _,scroll in pairs({host.tabScroll,host.previewTabScroll,host.contactScroll}) do
  local point,height=scroll.SetPoint,scroll.SetHeight
  scroll.SetPoint=function(frame,anchor,...) assert(anchor~="BOTTOMLEFT" and anchor~="BOTTOMRIGHT","scroll rectangle can invert during collapse");point(frame,anchor,...) end
  scroll.SetHeight=function(frame,value) assert(value>=1,"nonpositive scroll viewport");height(frame,value) end
 end
 for _,edge in ipairs({"TOP","BOTTOM"}) do
  host:HubSettings().minimizeEdge=edge
  for cycle=1,10 do
   host:SetMinimized(not host.minimized)
   for tick=1,16 do
    local animate=host.hub:GetScript("OnUpdate")
    if animate then animate(host.hub,.016) end
    for _,scroll in pairs({host.tabScroll,host.previewTabScroll,host.contactScroll}) do assert(scroll:GetHeight()>=1) end
   end
   assert(not host.collapseAnimation)
   assert(host.hubChrome:IsShown())
  end
 end
 host:SetMinimized(false,true)
 assert(host.tabScroll:IsShown())
 assert(host.tabScroll:GetHeight()==math.max(1,host.hub:GetHeight()-host:HeaderHeight()-host:HeaderGap()))
end
''')
print('Minimize/restore viewport regression passed: 60 complete animated transitions across three windows/both edges, no inverted anchors or nonpositive scroll bounds, restored header and list.')
