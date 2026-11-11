local Core = unpack(select(2, ...))

-- Cursor deltas avoid native sizing changing chat's anchors or lock state.
Core.Components.CreateResizeHandle = function (overlay, options)
  local handle = CreateFrame("Button", nil, overlay)
  handle:SetSize(24, 24)
  handle:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT", -2, 2)
  handle:SetFrameLevel(overlay:GetFrameLevel() + 2)
  handle:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
  handle:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
  handle:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")

  function handle:FinishResize()
    if not self.resizeState then return end
    self.resizeState = nil
    self:SetScript("OnUpdate", nil)
    options.finish()
  end

  function handle:UpdateResize()
    local state = self.resizeState
    if not state then return end
    if not options.allowed() or not IsMouseButtonDown("LeftButton") then
      self:FinishResize()
      return
    end
    local x, y = GetCursorPosition()
    local width = math.max(options.minWidth, math.min(9999, math.floor(state.width + (x - state.x) / state.scale + 0.5)))
    local height = math.max(options.minHeight, math.min(9999, math.floor(state.height - (y - state.y) / state.scale + 0.5)))
    if width ~= state.lastWidth or height ~= state.lastHeight then
      state.lastWidth, state.lastHeight = width, height
      options.apply(width, height)
    end
  end

  handle:SetScript("OnMouseDown", function (_, button)
    if button ~= "LeftButton" or not options.allowed() then return end
    local target, width, height = options.begin()
    if not target then return end
    local scale = target:GetEffectiveScale()
    local left, top = target:GetLeft(), target:GetTop()
    if not scale or scale <= 0 or not left or not top then return end
    -- A fixed upper-left corner makes every anchor behave identically.
    target:ClearAllPoints()
    local parentScale = UIParent:GetEffectiveScale() / scale
    target:SetPoint("TOPLEFT", UIParent, "TOPLEFT",
      left - UIParent:GetLeft() * parentScale, top - UIParent:GetTop() * parentScale)
    local x, y = GetCursorPosition()
    handle.resizeState = {x = x, y = y, scale = scale, width = width, height = height,
      lastWidth = width, lastHeight = height}
    handle:SetScript("OnUpdate", function () handle:UpdateResize() end)
  end)
  handle:SetScript("OnMouseUp", function (_, button)
    if button == "LeftButton" then handle:UpdateResize(); handle:FinishResize() end
  end)
  handle:SetScript("OnHide", function () handle:FinishResize() end)
  return handle
end
