exec(open('work/test_interactive_preview.py', encoding='utf-8').read())
lua.execute('''
local methods=getmetatable(UIParent).__index
function methods:SetAutoFocus() end
function methods:SetMaxLetters() end
function methods:SetFocus() self.focus=true end
function methods:ClearFocus() self.focus=false end
cfg.previewConversations=30;W:StartPreview();W.previewTabScroll:SetWidth(350)
W:RefreshConversationNavigation(true)
local nav=W.previewNavigation
assert(nav.total==30 and nav.hiddenUnread>0 and nav.left.disabled and not nav.right.disabled)
W:PageConversationTabs(true,1);assert(W.previewTabScroll:GetHorizontalScroll()==math.floor(350/W:TabStep())*W:TabStep())
for i=1,40 do W:PageConversationTabs(true,1) end
assert(W.previewTabScroll:GetHorizontalScroll()==30*W:TabStep()-350 and nav.right.disabled)
W:SelectPreviewConversation(30);assert(W.previewSelected==30)
W:ShowConversationPicker(true,nav.all)
assert(#W.conversationPicker.matches==30 and W.conversationPicker.rows[9]:IsShown())
local picker=W.conversationPicker
picker.search:SetText("Dorian");W:RefreshConversationPicker()
assert(#picker.matches==1,"picker did not filter all 30 conversations")
local chosen=picker.matches[1];W:ChoosePickerConversation(chosen)
assert(W.previewConversations[W.previewSelected]==chosen.value and not picker:IsShown())
local left=(W.previewSelected-1)*W:TabStep()
assert(left>=W.previewTabScroll:GetHorizontalScroll() and left+W:TabWidth()<=W.previewTabScroll:GetHorizontalScroll()+350)
W:ShowConversationPicker(true,nav.all);picker.search:SetText("no such person");W:RefreshConversationPicker()
assert(#picker.matches==0 and not picker.rows[1]:IsShown())
picker.search:SetText("");W:RefreshConversationPicker();picker.offset=21;W:RefreshConversationPicker();assert(picker.rows[9].entry)
W.previewTabScroll:SetWidth(7000);W:RefreshConversationNavigation(true)
assert(nav.left.disabled and nav.right.disabled and W.previewTabScroll:GetHorizontalScroll()==0)
W:ClearPreviewData()
W.tabScroll:SetWidth(220);W:RefreshConversationNavigation(false)
local entries=W:ConversationEntries(false)
assert(#entries==#W.hubOrder)
if #entries>1 then
 W:PageConversationTabs(false,1);assert(W.tabScroll:GetHorizontalScroll()>0)
 W:ShowConversationPicker(false,W.conversationNavigation.all)
 local entry=W.conversationPicker.matches[#W.conversationPicker.matches]
 W:ChoosePickerConversation(entry);assert(W.selected==entry.value)
end
''')
print('Tab navigation passed: 30 conversations, bounded paging, edge states, hidden unread, searchable full list, empty search, list scrolling, selection reveal and resize clamping for preview/native tabs.')

lua.execute("""
local create=CreateFrame
function CreateFrame(kind,...)
 local frame=create(kind,...)
 if kind=="Button" then
  local get,set=frame.GetFontString,frame.SetText
  function frame:GetFontString() if self.explicitText then return get(self) end end
  function frame:SetText(text) self.explicitText=text~="";return set(self,text) end
 end
 return frame
end
W.conversationPicker=nil
W:ShowConversationPicker(false,W.conversationNavigation.all)
assert(W.conversationPicker.status and #W.conversationPicker.rows==9)
W:StartPreview();assert(W.previewTabs[1].favoriteButton)
""")
print("Lazy button text initialization passed.")
