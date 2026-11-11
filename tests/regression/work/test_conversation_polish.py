exec(open('work/test_unified_style.py',encoding='utf-8').read())
lua.execute('''
-- Copy the rendered font, not merely an inherited object left behind by a skin.
local methods=getmetatable(UIParent).__index
function methods:SetFont(path,size,flags) self.font={path,size,flags} end
local face=UIParent:CreateFontString()
function face:GetFont() return "ActualChat.ttf",9,"OUTLINE" end
function face:GetFontObject() return "SunderChatDockFont" end
ChatFrame1Tab={Text=face}
cfg.hubMatchChat=true;Core.db.profile.tabFontSize=9
W:RefreshHubStyle()
assert(W.hubTitle.font[1]=="ActualChat.ttf" and W.hubTitle.font[2]==9 and W.hubTitle.font[3]=="OUTLINE")
assert(not W.hubActionButtons.Pin:IsShown() and not W.hubActionButtons.Favorite:IsShown())
-- Isolate a regular group for native order, sorting, pinning and drag/edge-scroll.
Core.db.char.messageWorkspaces.sortTest={name="Friends",hubWidth=540,hubHeight=340,hubPoint="CENTER",hubX=0,hubY=0,keepMessagesOpen=true}
local host=W:GetWorkspace("sortTest");host:OpenMessages()
local create=CreateFrame
function CreateFrame(kind,...)
 local f=create(kind,...);if kind=="Button" then f:SetText(" ") end;return f
end
local a=conversation("ChatFrameOrderA","Zara-Realm")
local b=conversation("ChatFrameOrderB","Alda-Realm")
local c=conversation("ChatFrameOrderC","Yara-Realm")
for _,frame in ipairs({a,b,c}) do W:OnWindowOpened(frame);W:MoveToWorkspace(frame,"sortTest") end
host:SelectConversation(b,false)
local selected=host.selected
host:ReorderConversation(a,4,false)
assert(host.hubOrder[3]==a and host.selected==selected)
assert(Core.db.char.messageTabOrders.sortTest[3]=="zara-realm")
host.hubOrder={a,b,c};host:RestoreConversationOrder()
assert(host.hubOrder[1]==b and host.hubOrder[2]==c and host.hubOrder[3]==a)
W.records[a].unread=5;W.records[b].unread=2;W.records[c].unread=9
host:SortConversationTabs("unread");assert(host.hubOrder[1]==c and host.selected==selected)
host:SortConversationTabs("name");assert(host.hubOrder[1]==b)
W.records[a].lastActivity=100;W.records[b].lastActivity=200;W.records[c].lastActivity=300
host:SortConversationTabs("recent");assert(host.hubOrder[1]==c)
local pin=host.hubTabs[a].pinControl
pin:GetScript("OnClick")();assert(W.records[a].pinned and Core.db.char.whisperLayouts["zara-realm"].pinned)
host:SortConversationTabs("pinned");assert(host.hubOrder[1]==a)
for _,h in pairs(W.workspaces) do if h.hub then h.hub:Hide() end end
host.hub:Show();host.tabScroll:SetWidth(160);host.tabScroll:SetHorizontalScroll(0)
local tab=host.hubTabs[a]
cursorX=host.tabScroll:GetLeft()+159;cursorY=host.hub:GetTop()-host:HeaderHeight()-4
local count=#host.hubOrder
tab:GetScript("OnDragStart")()
for i=1,45 do tab:GetScript("OnUpdate")(tab,.05) end
assert(host.tabScroll:GetHorizontalScroll()>0 and host.tabInsertion:IsShown())
tab:GetScript("OnDragStop")();drain()
assert(host.hubOrder[1]==a and host.selected==selected and not host.tabInsertion:IsShown())
assert(not tab:GetScript("OnUpdate") and not host.tabDragging)
-- Distinct sample people, alternating replies, realistic text and no labels contaminating the mock UI.
cfg.previewConversations=30;cfg.previewLines=40;W:StartPreview();W:RefreshHubStyle()
local names={}
for _,person in ipairs(W.previewConversations) do
 assert(not names[person.name] and not person.name:find("Preview",1,true));names[person.name]=true
 assert(person.lines[2].outgoing and not person.lines[1].outgoing)
 for _,line in ipairs(person.lines) do assert(not line.text:find("preview") and not line.text:find("#%d")) end
end
assert(W.hubTitle:GetText()==W:WorkspaceName())
local sawYou=false
for _,row in ipairs(W.previewBody.rows) do assert(not row:find("Preview",1,true));if row:find("You",1,true) then sawYou=true end end
assert(sawYou)
local active=W.previewConversations[W.previewSelected]
local move=W.previewConversations[1]
W:ReorderConversation(move,31,true)
assert(W.previewConversations[30]==move and W.previewConversations[W.previewSelected]==active)
W.previewTabScroll:SetWidth(200)
W:SortConversationTabs("name");assert(W.previewConversations[1].name=="Alaric")
local activeLeft=(W.previewSelected-1)*W:TabStep();local scroll=W.previewTabScroll:GetHorizontalScroll()
assert(activeLeft>=scroll and activeLeft+W:TabWidth()<=scroll+200,"sorting hid the active tab")
local sample=W.previewConversations[1]
W.previewTabs[1].pinControl:GetScript("OnClick")()
assert(sample.pinned and W.previewTabs[1].pinRecord==sample)
W:SelectPreviewConversation(2)
assert(W.previewConversations[2].readMarker and W.previewConversations[2].unread==0)
local sawMarker=false;for _,row in ipairs(W.previewBody.rows) do if row:find("New messages",1,true) then sawMarker=true end end
assert(sawMarker)
assert(Core.db.char.messageTabOrders.sortTest and not Core.db.char.messageTabOrders.previewDetached1)
''')
print('Conversation polish passed: exact native header font, inline persistent pins, native reorder/restore/sorts, drag insertion and edge scrolling, stable selection, 30 distinct names, outgoing replies, unread boundary, sample reordering and session-only sample data.')
