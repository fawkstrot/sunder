exec(open('work/test_078.py',encoding='utf-8').read())
lua.execute('''
local extra=W:GetWorkspace("group1")
for _,host in ipairs({W,W:GetWorkspace("group2"),extra}) do
 host:EnsureHub();host:OpenMessages()
 local started,stopped,rects=0,0,0
 host.hub.StartMoving=function() started=started+1 end
 host.hub.StopMovingOrSizing=function() stopped=stopped+1 end
 host.tabScroll.UpdateScrollChildRect=function() rects=rects+1 end
 local setClips=host.hub.SetClipsChildren
 host.hub.SetClipsChildren=function(frame,value) assert(not value,"window root clipped the title bar");setClips(frame,value) end
 for _,edge in ipairs({"TOP","BOTTOM"}) do
  host:HubSettings().minimizeEdge=edge
  for _,small in ipairs({false,true,false,true}) do
   host:SetMinimized(small,true)
   local width,height=host.hub:GetWidth(),host.hub:GetHeight()
   host:BeginHubMove(true)
   assert(host.hubMoving.native,"native drag path was not used")
   local point,relative,relativePoint,x,y=host.hub:GetPoint()
   cursorX,cursorY=800,400;host:UpdateHubMove()
   local _,_,_,nextX,nextY=host.hub:GetPoint()
   assert(nextX==x and nextY==y,"manual reanchoring competed with native movement")
   host:StopHubMove()
   assert(host.hub:GetWidth()==width and host.hub:GetHeight()==height)
   assert(host.hubChrome:IsShown() and host.hubChrome:GetAlpha()==1)
  end
 end
 assert(started==8 and stopped==8 and rects>=16)
end
''')
print('Minimized drag checks passed: native movement, no competing anchor writes, no root clipping, refreshed scroll rectangles, stable dimensions/header for all groups and both collapse edges.')
