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
  local renderedWidth

  local function updateScroll(offset)
    local maximum = math.max(0, child:GetHeight() - scroll:GetHeight())
    scroll:SetVerticalScroll(math.max(0, math.min(offset, maximum)))
    manager:UpdateListScrollIndicator(scroll, child, scroll:IsVisible())
  end

  local function appendRow(index, line, top, pad)
    local tp = Core:GetModule("TextProcessing")
    local row = pool:Acquire()
    row.sourceFrame, row.sourceText = source, line[1]
    row.text:SetFontObject("SunderMessageFont")
    local r, g, b = tp:WhisperReplyStyle(source, line.typeID, line.own, line[1])
    row.text:SetTextColor(r or line[2] or 1, g or line[3] or 1, b or line[4] or 1, 1)
    row:SetDisplayText(tp:ProcessText(line[1], source, line.receivedAt, line.typeID, nil, line.own))
    row:UpdateFrame()
    tops[index] = top
    row.text:ClearAllPoints()
    row.text:SetPoint("TOPLEFT", child, "TOPLEFT", pad, -top - row.sunderTextPadding)
    local height = row.sunderHeight or 18
    row:SetBackgroundCoverage(1)
    row:SetScript("OnMouseDown", nil)
    row:SetAlpha(1)
    row:Show()
    return height
  end

  function scroll:Render()
    self:SetScript("OnUpdate", nil)
    local width = owner:GetLayoutWidth()
    local offset = self:GetVerticalScroll()
    if width ~= renderedWidth then
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
      renderedWidth = width
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
    if renderedWidth ~= owner:GetLayoutWidth() then
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
