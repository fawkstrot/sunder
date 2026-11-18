local Core, _, Utils = unpack(select(2, ...))
local ChatCopy = Core:GetModule("ChatCopy")
local TP = Core:GetModule("TextProcessing")

local AceGUI = Core.Libs.AceGUI
local L = function(text) return Core:Localize(text) end
local MAX_COPY_BYTES = 60000

-- WoW provides these globals at runtime, so suppress Luacheck's undefined-global warning while localizing them.
-- luacheck: push ignore 113
local DEFAULT_CHAT_FRAME = DEFAULT_CHAT_FRAME
-- luacheck: pop

local copyFrame
local copyTextBox

local function stripChatMarkup(text)
  if _G.canaccessvalue and not _G.canaccessvalue(text) then return "<protected>" end
  if type(text) ~= "string" then
    return nil
  end

  local clean = text
  clean = clean:gsub("|K.-|k", "<protected>")
  clean = clean:gsub("|H.-|h(.-)|h", "%1")
  clean = clean:gsub("|A.-|a", "")
  clean = clean:gsub("|T.-|t", "")
  clean = clean:gsub("|c%x%x%x%x%x%x%x%x", "")
  clean = clean:gsub("|r", "")
  clean = clean:gsub("||", "|")
  return clean
end

local function getSelectedChatFrame()
  return _G.SELECTED_CHAT_FRAME or
    (_G.GeneralDockManager and _G.GeneralDockManager.selected) or
    DEFAULT_CHAT_FRAME
end

local function getFrameLabel(chatFrame)
  local tab = chatFrame and _G[chatFrame:GetName().."Tab"]
  local label = tab and tab.Text and tab.Text:GetText()

  if label == nil or label == "" then
    label = chatFrame and chatFrame:GetName() or L("Chat")
  end

  return label
end

local function datedText(chatFrame,index,count,text)
  local receipt=Utils.frameReceipt(chatFrame,index,count,text)
  local prefix=receipt and date("[%Y-%m-%d %H:%M] ",receipt) or ""
  return prefix..text
end

local function readChatFrame(chatFrame)
  local reverseLines = {}
  local bytesUsed = 0
  local limit = tonumber(Core.db.profile.scrollbackLines) or Core.defaults.profile.scrollbackLines
  limit = math.max(1, math.floor(limit))
  local count = chatFrame and chatFrame:GetNumMessages() or 0
  local first = math.max(1, count - limit + 1)

  -- Blizzard's hidden chat frame already retains lightweight history.
  -- Read it newest-first so the copy window remains bounded without cutting old lines.
  for index = count, first, -1 do
    local raw=chatFrame:GetMessageInfo(index)
    local text = stripChatMarkup(raw)
    if text and text ~= "" and not TP:IsMessageBlacklisted(text) then
      if not canaccessvalue or canaccessvalue(raw) then text=stripChatMarkup(datedText(chatFrame,index,count,raw)) end
      local separatorBytes = #reverseLines > 0 and 1 or 0
      if bytesUsed + separatorBytes + #text > MAX_COPY_BYTES then
        break
      end

      reverseLines[#reverseLines + 1] = text
      bytesUsed = bytesUsed + separatorBytes + #text
    end
  end

  if #reverseLines == 0 then
    if count > 0 then
      return L("The newest chat message exceeds Sunder's 60,000-character copy limit.")
    end

    return L("This chat tab has no messages to copy.")
  end

  local lines = {}
  for index = #reverseLines, 1, -1 do
    lines[#lines + 1] = reverseLines[index]
  end

  return table.concat(lines, "\n")
end

local function ensureCopyWindow()
  if copyFrame ~= nil then
    return
  end

  copyFrame = AceGUI:Create("Frame")
  copyFrame:SetWidth(760)
  copyFrame:SetHeight(500)
  copyFrame:SetStatusText(L("Press Ctrl+C to copy, then close this window."))
  copyFrame:SetCallback("OnClose", function(widget)
    widget:Hide()
  end)
  copyFrame:SetLayout("Fill")

  copyTextBox = AceGUI:Create("MultiLineEditBox")
  copyTextBox:SetLabel(L("All text is selected"))
  copyTextBox:DisableButton(true)
  copyFrame:AddChild(copyTextBox)
  Core:GetModule("Ellesmere"):SkinWindow(copyFrame, {copyTextBox})
end

function ChatCopy:ShowText(title, text)
  ensureCopyWindow()
  copyFrame:SetTitle(title)
  copyTextBox:SetText(text)
  copyFrame:Show()
  copyTextBox:SetFocus()
  copyTextBox:HighlightText()
end

function ChatCopy:Show(chatFrame)
  chatFrame = chatFrame or getSelectedChatFrame()
  if chatFrame == nil then
    return
  end

  self:ShowText(L("Sunder: Copy chat — ")..getFrameLabel(chatFrame), readChatFrame(chatFrame))
end

local SEARCH_RESULT_LIMIT = 200
local searchFrame
local searchInput
local searchResults
local previousResults,nextResults

local function toHex(value)
  return string.format("%02x", math.floor(math.max(0, math.min(1, value or 1)) * 255 + 0.5))
end

-- Newest first, in each message's chat color. Secret and blocked lines are never searched.
local function searchChatFrame(chatFrame, query)
  local lines, found, bytes = {}, 0, 0
  query = query:lower()
  for index = chatFrame:GetNumMessages(), 1, -1 do
    local text, red, green, blue = chatFrame:GetMessageInfo(index)
    local plain = (not _G.canaccessvalue or _G.canaccessvalue(text)) and stripChatMarkup(text)
    if plain and plain:lower():find(query, 1, true) and not TP:IsMessageBlacklisted(plain) then
      found = found + 1
      if found <= SEARCH_RESULT_LIMIT then
        if not chatFrame.sunderDated and (not canaccessvalue or canaccessvalue(text)) then plain=stripChatMarkup(datedText(chatFrame,index,chatFrame:GetNumMessages(),text)) end
        local display=plain:gsub("|", "||")
        if TP.ColorPersonNames then
          local person=chatFrame.GetPersonInfo and chatFrame:GetPersonInfo(index)
          display=TP:ColorPersonNames(display,person)
        end
        local result="|cff"..toHex(red)..toHex(green)..toHex(blue)..display.."|r"
        if bytes+#result+1<=MAX_COPY_BYTES then lines[#lines+1]=result;bytes=bytes+#result+1 end
      end
    end
  end
  return lines, found
end

-- Search references existing records; no transcript is copied into SavedVariables.
-- Work is chunked and generation-cancelled when the query or view changes.
function ChatCopy:SearchSaved(query,page,complete)
  self.searchGeneration=(self.searchGeneration or 0)+1
  local generation=self.searchGeneration
  local sources={}
  local function add(label,record)
    if record and type(record.lines)=="table" then sources[#sources+1]={label=label,lines=record.lines,count=#record.lines}end
  end
  add("Conversation log",SunderConversationLog)
  local char=Core.db.char or {}
  for _,record in pairs(char.whisperArchive or {})do add("Whisper: "..(record.displayName or record.target or record.battleTag or "Unknown"),record)end
  add("Guild",char.guildRoomHistory)
  add("Current group",char.partyRoomHistory)
  for _,record in ipairs(char.partyRoomArchive or {})do add("Previous group",record)end
  if ChatFrame2 and ChatFrame2.GetNumMessages then
    sources[#sources+1]={label="Combat Log (this session)",native=ChatFrame2,count=ChatFrame2:GetNumMessages()}
  end
  query=query:lower();page=math.max(1,page or 1)
  local sourceIndex,index=1,nil
  local found,bytes,results,seen=0,0,{},{}
  local function scan()
    if generation~=self.searchGeneration then return end
    local work=0
    while sourceIndex<=#sources and work<200 do
      local source=sources[sourceIndex]
      index=index or source.count
      if index<1 then sourceIndex=sourceIndex+1;index=nil
      else
        local line=source.lines and source.lines[index]
        local text=line and line[1] or source.native and source.native:GetMessageInfo(index)
        local receipt=line and line.receivedAt
        if source.native and text and (not canaccessvalue or canaccessvalue(text))then receipt=Utils.frameReceipt(source.native,index,source.count,text)end
        local plain=(not canaccessvalue or canaccessvalue(text)) and stripChatMarkup(text)
        if plain and not plain:find("<protected>",1,true) and plain:lower():find(query,1,true) and not TP:IsMessageBlacklisted(plain)then
          local identity=tostring(receipt).."\031"..plain
          if not seen[identity] or seen[identity]==sourceIndex then
            seen[identity]=sourceIndex;found=found+1
            if found>(page-1)*SEARCH_RESULT_LIMIT and found<=page*SEARCH_RESULT_LIMIT then
              local stamp=type(receipt)=="number" and date("%Y-%m-%d %H:%M",receipt) or "Date unknown"
              local result=("["..source.label.." · "..stamp.."] "..plain):gsub("|","||")
              if TP.ColorPersonNames then result=TP:ColorPersonNames(result,line)end
              if bytes+#result+1<=MAX_COPY_BYTES then results[#results+1]=result;bytes=bytes+#result+1 end
            end
          end
        end
        index=index-1;work=work+1
      end
    end
    if sourceIndex<=#sources then C_Timer.After(0,scan) else complete(results,found,page)end
  end
  C_Timer.After(.15,scan)
end
local function updateSearch()
  local query = searchInput:GetText() or ""
  if searchFrame.allSaved then
    if query=="" then
      ChatCopy.searchGeneration=(ChatCopy.searchGeneration or 0)+1
      searchResults:SetLabel(L("Type to search all saved conversations"));searchResults:SetText("")
      previousResults:SetDisabled(true);nextResults:SetDisabled(true);return
    end
    if searchFrame.lastQuery~=query then searchFrame.page=1;searchFrame.lastQuery=query end
    searchResults:SetLabel(L("Searching…"))
    previousResults:SetDisabled(true);nextResults:SetDisabled(true)
    ChatCopy:SearchSaved(query,searchFrame.page,function(lines,count,page)
      searchResults:SetLabel(count==0 and L("No messages found") or string.format("%d matches · Page %d of %d · %d displayed",count,page,math.max(1,math.ceil(count/SEARCH_RESULT_LIMIT)),#lines))
      searchResults:SetText(table.concat(lines,"\n"))
      previousResults:SetDisabled(page<=1);nextResults:SetDisabled(page*SEARCH_RESULT_LIMIT>=count)
    end)
    return
  end
  if query == "" and not searchFrame.archive then
    searchResults:SetLabel(L("Type to search"))
    searchResults:SetText("")
    return
  end
  local lines, found = searchChatFrame(searchFrame.chatFrame, query)
  if found == 0 then
    searchResults:SetLabel(L("No messages found"))
  elseif found > #lines then
    local shown = " ("..L("showing the newest").." "..#lines..")"
    searchResults:SetLabel(L("Messages found:").." "..found..shown)
  else
    searchResults:SetLabel(L("Messages found:").." "..found)
  end
  searchResults:SetText(table.concat(lines, "\n"))
end

local function ensureSearchWindow()
  if searchFrame ~= nil then
    return
  end

  searchFrame = AceGUI:Create("Frame")
  searchFrame:SetWidth(640)
  searchFrame:SetHeight(460)
  searchFrame:SetStatusText(L("Results can be selected and copied with Ctrl+C."))
  searchFrame:SetCallback("OnClose", function (widget)
    ChatCopy.searchGeneration=(ChatCopy.searchGeneration or 0)+1
    widget:Hide()
  end)
  searchFrame:SetLayout("Flow")

  searchInput = AceGUI:Create("EditBox")
  searchInput:SetLabel(L("Search messages"))
  searchInput:SetFullWidth(true)
  searchInput:DisableButton(true)
  searchInput:SetCallback("OnTextChanged", updateSearch)
  searchFrame:AddChild(searchInput)

  local all=AceGUI:Create("Button");all:SetText("All saved conversations");all:SetWidth(190)
  all:SetCallback("OnClick",function()ChatCopy:ShowAllSearch()end);searchFrame:AddChild(all)
  previousResults=AceGUI:Create("Button");previousResults:SetText("Previous");previousResults:SetWidth(100)
  previousResults:SetCallback("OnClick",function()searchFrame.page=math.max(1,(searchFrame.page or 1)-1);updateSearch()end);searchFrame:AddChild(previousResults)
  nextResults=AceGUI:Create("Button");nextResults:SetText("Next");nextResults:SetWidth(100)
  nextResults:SetCallback("OnClick",function()searchFrame.page=(searchFrame.page or 1)+1;updateSearch()end);searchFrame:AddChild(nextResults)
  searchResults = AceGUI:Create("MultiLineEditBox")
  searchResults:SetFullWidth(true)
  searchResults:SetFullHeight(true)
  searchResults:DisableButton(true)
  searchFrame:AddChild(searchResults)
  Core:GetModule("Ellesmere"):SkinWindow(searchFrame, {searchInput, searchResults})
end

function ChatCopy:ShowSearch(chatFrame)
  chatFrame = chatFrame or getSelectedChatFrame()
  if chatFrame == nil then
    return
  end

  ensureSearchWindow()
  ChatCopy.searchGeneration=(ChatCopy.searchGeneration or 0)+1
  searchFrame.allSaved=false;previousResults:SetDisabled(true);nextResults:SetDisabled(true)
  searchFrame.archive=nil
  searchFrame.chatFrame = chatFrame
  searchFrame:SetTitle(L("Sunder: Search — ")..getFrameLabel(chatFrame))
  searchFrame:Show()
  updateSearch()
  searchInput:SetFocus()
end

function ChatCopy:ShowAllSearch()
  ensureSearchWindow()
  searchFrame.allSaved=true;searchFrame.archive=nil;searchFrame.page=1
  searchFrame:SetTitle("Sunder: Search all saved conversations")
  searchFrame:SetStatusText("Current character · Combat Log is session-only · Ctrl+C copies results")
  searchFrame:Show();updateSearch();searchInput:SetFocus()
end

-- Reuse the bounded search/copy shell; opening history creates no native chat
-- window, reply recipient or rendered message frames.
function ChatCopy:ShowArchive(entry)
  ensureSearchWindow()
  ChatCopy.searchGeneration=(ChatCopy.searchGeneration or 0)+1
  searchFrame.allSaved=false;previousResults:SetDisabled(true);nextResults:SetDisabled(true)
  searchFrame.archive=true
  searchFrame.chatFrame={sunderDated=true,GetPersonInfo=function(_,index)return entry.lines[index]end,GetNumMessages=function() return #(entry.lines or {}) end,
    GetMessageInfo=function(_,index)
      local line=entry.lines[index]
      local stamp=type(line.receivedAt)=="number" and date("[%Y-%m-%d %H:%M] ",line.receivedAt) or "[Date unknown] "
      return stamp..line[1],line[2],line[3],line[4]
    end}
  searchFrame:SetTitle(L("Sunder: Saved history — ")..Core.Components.WindowManager:FormatPersonName(entry.displayName or entry.target or entry.battleTag or "Whisper",entry))
  searchInput:SetText("");searchFrame:Show();updateSearch();searchInput:SetFocus()
end

-- A page is bounded independently of how much history the player keeps.
local logFrame, logText, older, newer, clear
function ChatCopy:ShowLog(db,requestClear)
  if not logFrame then
    logFrame=AceGUI:Create("Frame")
    logFrame:SetTitle("Conversation history")
    logFrame:SetWidth(680)
    logFrame:SetHeight(480)
    logFrame:SetLayout("Flow")
    logFrame:SetCallback("OnClose",function(widget) widget:Hide() end)
    local function button(label)
      local control=AceGUI:Create("Button")
      control:SetText(label)
      control:SetWidth(125)
      logFrame:AddChild(control)
      return control
    end
    older=button("Older messages")
    newer=button("Newer messages")
    clear=button("Clear log…")
    logText=AceGUI:Create("MultiLineEditBox")
    logText:SetFullWidth(true)
    logText:SetFullHeight(true)
    logText:DisableButton(true)
    logFrame:AddChild(logText)
    Core:GetModule("Ellesmere"):SkinWindow(logFrame,{logText})
  end
  local function show(last)
    local lines={}
    last=math.min(last,#db.lines)
    local first=math.max(1,last-49)
    for i=first,last do
      local line=db.lines[i]
      local timestamp=line.receivedAt and date("%Y-%m-%d %H:%M:%S",line.receivedAt) or "Date unknown"
      local text=(stripChatMarkup(line[1]) or ""):gsub("|","||")
      local tp=Core:GetModule("TextProcessing",true)
      if tp and tp.ColorPersonNames then text=tp:ColorPersonNames(text,line) end
      lines[#lines+1]=timestamp.."  "..text
    end
    logText:SetText(table.concat(lines,"\n"))
    logText:SetLabel(last==0 and "No saved messages." or first.."–"..last.." of "..#db.lines.." messages")
    older:SetDisabled(first<=1)
    newer:SetDisabled(last>=#db.lines)
    older:SetCallback("OnClick",function() show(math.max(0,first-1)) end)
    newer:SetCallback("OnClick",function() show(math.min(#db.lines,last+50)) end)
  end
  clear:SetCallback("OnClick",requestClear)
  logFrame:SetStatusText("Times are local. Clearing requires confirmation.")
  show(#db.lines)
  logFrame:Show()
end
