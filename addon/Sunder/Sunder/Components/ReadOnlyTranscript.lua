local Core,Constants=unpack(select(2,...))
-- Archived logs use the same MessageLine wrapping, links and text processing as live rooms.
function Core.Components.CreateReadOnlyTranscript(parent,source)
  local scroll=CreateFrame("ScrollFrame",nil,parent);scroll:SetClipsChildren(true)
  local child=CreateFrame("Frame",nil,scroll);scroll:SetScrollChild(child)
  local owner={sharedFullSurface=true}
  function owner:GetLayoutWidth()return math.max(1,scroll:GetWidth()-8)end
  local pool=Core.Components.CreateMessageLinePool(child,owner)
  local lines={};local renderedWidth
  local function indicator()Core.Components.WindowManager:UpdateListScrollIndicator(scroll,child,true)end
  function scroll:Render(force)
    local width=owner:GetLayoutWidth();if not force and renderedWidth==width then return end
    renderedWidth=width;pool:ReleaseAll();child:SetWidth(width)
    local top=0;local tp=Core:GetModule("TextProcessing")
    for _,line in ipairs(lines)do
      local row=pool:Acquire();row.sourceFrame=source;row.sourceText=line[1]
      row.text:SetFontObject("SunderMessageFont")
      local r,g,b=tp:WhisperReplyStyle(source,line.typeID,line.own,line[1])
      row.text:SetTextColor(r or line[2] or 1,g or line[3] or 1,b or line[4] or 1,1)
      row:SetDisplayText(tp:ProcessText(line[1],source,line.receivedAt,line.typeID,nil,line.own));row:UpdateFrame()
      row.text:ClearAllPoints();row.text:SetPoint("TOPLEFT",child,"TOPLEFT",Core:GetModule("Whispers"):BodyPadding(),-top)
      top=top+(row.sunderHeight or 18);row:SetBackgroundCoverage(1)
      row:SetScript("OnMouseDown",nil);row:SetAlpha(1);row:Show()
    end
    child:SetHeight(math.max(1,top));scroll:SetVerticalScroll(math.min(scroll:GetVerticalScroll(),math.max(0,top-scroll:GetHeight())));indicator()
  end
  function scroll:SetLines(value)lines=value or {};scroll:SetVerticalScroll(0);self:Render(true)end
  scroll:EnableMouseWheel(true)
  scroll:SetScript("OnMouseWheel",function(_,delta)scroll:SetVerticalScroll(math.max(0,math.min(math.max(0,child:GetHeight()-scroll:GetHeight()),scroll:GetVerticalScroll()-delta*36)));indicator()end)
  scroll:SetScript("OnSizeChanged",function()scroll:Render()end)
  scroll:SetScript("OnShow",function()scroll:Render();indicator()end)
  scroll:SetScript("OnHide",function()Core.Components.WindowManager:UpdateListScrollIndicator(scroll,child,false)end)
  Core:Subscribe(Constants.EVENTS.UPDATE_CONFIG,function()renderedWidth=nil;if scroll:IsVisible()then scroll:Render(true)end end)
  return scroll
end
