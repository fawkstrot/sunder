exec(open('work/test_reply073.py',encoding='utf-8').read())
lua.execute("""
cfg.minimizedPreviews=true;cfg.minimizedPreviewUntilRead=true;W:StartPreview();W.minimizedWhispers={}
local first,second=W.previewConversations[2],W.previewConversations[3]
W:QueueMinimizedWhisper(first,true,first.lines[#first.lines-1].text)
W:QueueMinimizedWhisper(second,true,'Other person stays')
W:QueueMinimizedWhisper(first,true,first.lines[#first.lines-1].text)
local clicked=W.minimizedWhispers[1]
local favorites=W:GetWorkspace('group2');favorites.minimizedWhispers={W.minimizedWhispers[3]}
W:OpenMinimizedWhisper(clicked)
assert(#W.minimizedWhispers==1 and W.minimizedWhispers[1].person==second)
assert(#favorites.minimizedWhispers==0)
assert(W.pendingWhisperToast==clicked and W.previewConversations[W.previewSelected]==first)
W.minimized=true;W:QueueMinimizedWhisper(first,true,'A later incoming whisper');assert(#W.minimizedWhispers==2)
W:ClearPreviewData()
""")
print('Toast acknowledgement passed: opening clears all rows for the selected person across groups, preserves others and the jump target, and permits later notifications.')

