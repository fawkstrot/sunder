local Core, Constants = unpack(select(2, ...))

-- The archive owns its viewport and scroll offset. MessageLine owns glyph layout.
function Core.Components.CreateReadOnlyTranscript(parent, source)
  local scroll = CreateFrame("ScrollFrame", nil, parent)
  scroll:SetClipsChildren(true)
  local child = CreateFrame("Frame", nil, scroll)
  scroll:SetScrollChild(child)
  local manager = Core.Components.WindowManager
  local owner = {sharedFullSurface = true}
  function owner:GetLayoutWidth()
    return math.max(1, scroll:GetWidth())
  end
  local pool = Core.Components.CreateMessageLinePool(child, owner)
  local lines, tops = {}, {}
  local renderedWidth,renderedDay

  local function updateDate()
    local maximum=math.max(0,child:GetHeight()-scroll:GetHeight())
    local index=1
    while index<#tops and tops[index+1]<=scroll:GetVerticalScroll() do index=index+1 end
    local line=lines[index]
    Core.Components.TranscriptDates:Pinned(scroll,scroll,line and line.receivedAt,
      line~=nil and maximum>0 and scroll:GetVerticalScroll()<maximum,owner:GetLayoutWidth())
  end
  scroll:SetScript("OnVerticalScroll",updateDate)

  local function updateScroll(offset)
    local maximum = math.max(0, child:GetHeight() - scroll:GetHeight())
    scroll:SetVerticalScroll(math.max(0, math.min(offset, maximum)))
    manager:UpdateListScrollIndicator(scroll, child, scroll:IsVisible())
    updateDate()
  end

  local function appendRow(index, line, top, pad)
    local tp = Core:GetModule("TextProcessing")
    local row = pool:Acquire()
    row.sourceFrame, row.sourceText = source, line[1]
    row.text:SetFontObject("SunderMessageFont")
    local r, g, b = tp:WhisperReplyStyle(source, line.typeID, line.own, line[1])
    row.text:SetTextColor(r or line[2] or 1, g or line[3] or 1, b or line[4] or 1, 1)
    row:SetDisplayText(tp:ProcessText(line[1], source, line.receivedAt, line.typeID, nil, line.own, true, line))
    row.sunderDateLabel=Core.Components.TranscriptDates:Boundary(line.receivedAt,index>1 and lines[index-1].receivedAt or nil,index==1,source)
    row:UpdateFrame()
    tops[index] = top
    if row.sunderHeight then
      row:ClearAllPoints()
      row:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -top)
    else
      row.text:ClearAllPoints()
      row.text:SetPoint("TOPLEFT", child, "TOPLEFT", pad, -top - row.sunderTextPadding-(row.sunderDateHeight or 0))
    end
    local height = row.sunderHeight or 18
    row:SetBackgroundCoverage(1)
    row:SetScript("OnMouseDown", nil)
    row:SetScript("OnEnter",nil);row:SetScript("OnLeave",nil)
    if line.groupChange then
      row:SetScript("OnEnter",function()
        GameTooltip:SetOwner(row,"ANCHOR_RIGHT")
        local change=line.groupChange
        GameTooltip:AddLine(change.kind=="baseline" and "Recorded roster" or "Group change",.75,.78,.82)
        for _,group in ipairs({{change.joined,"Joined"},{change.left,"Left"}}) do
          for _,person in ipairs(group[1] or {}) do
            local suffix=change.kind=="baseline" and "" or " · "..group[2]
            GameTooltip:AddLine(manager:FormatPersonName(person.name,person)..suffix,.65,.7,.75)
          end
        end
        for _,rename in ipairs(change.renamed or {}) do
          GameTooltip:AddLine(manager:FormatPersonName(rename.before.name,rename.before).." → "..manager:FormatPersonName(rename.after.name,rename.after),.65,.7,.75)
        end
        Core:GetModule("Fonts"):StyleTooltip(GameTooltip);GameTooltip:Show()
      end)
      row:SetScript("OnLeave",function()GameTooltip:Hide()end)
    end
    row:SetAlpha(1)
    row:Show()
    return height
  end

  function scroll:Render()
    self:SetScript("OnUpdate", nil)
    local width = owner:GetLayoutWidth()
    local offset = self:GetVerticalScroll()
    local day=Core.Components.TranscriptDates:Day(GetServerTime())
    if width ~= renderedWidth or renderedDay~=day then
      -- Keep the same message in view when earlier lines gain or lose wraps.
      local anchor = #tops
      while anchor > 0 and tops[anchor] > offset do anchor = anchor - 1 end
      local within = anchor > 0 and offset - tops[anchor] or 0
      pool:ReleaseAll()
      child:SetWidth(width)
      local pad = manager:BodyPadding()
      local top = pad
      for index, line in ipairs(lines) do
        local height = appendRow(index, line, top, pad)
        if index == anchor then offset = top + math.min(within, math.max(0, height - 1)) end
        top = top + height
      end
      child:SetHeight(math.max(1, top + pad))
      renderedWidth,renderedDay = width,day
    end
    updateScroll(offset)
  end

  function scroll:SetLines(value, currentSource)
    source = currentSource or source
    lines, tops, renderedWidth = value or {}, {}, nil
    self:SetVerticalScroll(0)
    self:Render()
  end
  -- An observing view can append to the same bounded log without resetting readback.
  function scroll:ShowAppendedLines(value, currentSource)
    if lines ~= value or source ~= currentSource or #tops > #value then
      self:SetLines(value, currentSource)
      updateScroll(child:GetHeight())
      return
    end
    local offset = self:GetVerticalScroll()
    local follow = offset >= child:GetHeight() - self:GetHeight() - 1
    if renderedWidth ~= owner:GetLayoutWidth() or renderedDay~=Core.Components.TranscriptDates:Day(GetServerTime()) then
      self:Render()
      if follow then updateScroll(child:GetHeight()) end
      return
    end
    if #tops == #value then return end
    local pad = manager:BodyPadding()
    local top = #tops == 0 and pad or child:GetHeight() - pad
    for index = #tops + 1, #value do
      top = top + appendRow(index, value[index], top, pad)
    end
    child:SetHeight(top + pad)
    updateScroll(follow and child:GetHeight() or offset)
  end

  local function resize()
    updateScroll(scroll:GetVerticalScroll())
    if scroll:IsVisible() and renderedWidth ~= owner:GetLayoutWidth() then
      scroll:SetScript("OnUpdate", scroll.Render)
    end
  end
  manager:RegisterTranscriptKeys(scroll,function(direction)updateScroll(scroll:GetVerticalScroll()+direction*math.max(1,scroll:GetHeight()-24))end)
  scroll:EnableMouseWheel(true)
  scroll:SetScript("OnMouseWheel", function(_, delta)
    updateScroll(scroll:GetVerticalScroll() - delta * 36)
  end)
  scroll:SetScript("OnSizeChanged", resize)
  scroll:SetScript("OnShow", scroll.Render)
  scroll:SetScript("OnHide", function()
    scroll:SetScript("OnUpdate", nil)
    manager:UpdateListScrollIndicator(scroll, child, false)
  end)
  local presentationKeys = {
    bodyPadding=true, font=true, messageFontSize=true, messageLeading=true,
    messageLinePadding=true, indentWordWrap=true, timestampDisplay=true,
    iconTextureYOffset=true, emojiDisplay=true, whispers=true
  }
  Core:Subscribe(Constants.EVENTS.UPDATE_CONFIG, function(key)
    if key and not presentationKeys[key] then return end
    renderedWidth = nil
    resize()
  end)
  return scroll
end
