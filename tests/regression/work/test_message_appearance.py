exec(open('work/test_group_interactions.py', encoding='utf-8').read())
lua.execute('''
cfg.enabled=true
local host=W:CreateWorkspace("Appearance")
local other=W:CreateWorkspace("Other")
host.hub:SetSize(620,380);host:SaveHubGeometry()
host:HubSettings().minimizeEdge="BOTTOM"
host:SetMinimized(true,true)
local point=host.hub:GetPoint();assert(point=="BOTTOMLEFT" and host.hub:GetHeight()==40)
assert(host:HubSettings().hubHeight==380)
host:SetMinimized(false,true);assert(host.hub:GetPoint()=="BOTTOMLEFT" and host.hub:GetHeight()==380)
assert(not other.minimized)
host:HubSettings().minimizeEdge="TOP";host:SetMinimized(true,true)
assert(host.hub:GetPoint()=="TOPLEFT");host:SetMinimized(false,true)
local function recordColor(texture) function texture:SetColorTexture(r,g,b,a) self.rgba={r,g,b,a} end end
recordColor(host.hubBackground);recordColor(host.hubHeaderFill);recordColor(host.hubRule)
for _,line in ipairs(host.hubBorders) do recordColor(line) end
cfg.hubBackgroundColor={r=0.2,g=0.3,b=0.4};cfg.hubBackgroundOpacity=0;cfg.hubHeaderOpacity=0.6;cfg.hubBorderOpacity=0.25
host:ApplyHubAppearance()
assert(host.hubBackground.rgba[1]==0.2 and host.hubBackground.rgba[4]==0)
assert(host.hubHeaderFill.rgba[4]==0.6 and host.hubRule.rgba[4]==0.25)
assert(host.hub:GetAlpha()==1,"background opacity must not fade controls")
for _,line in ipairs(host.hubBorders) do assert(line.rgba[4]==0.25) end
host.previewFrame=CreateFrame("Frame",nil,host.hub);host.previewActive=true
host:SetMinimized(true,true);assert(host.previewFrame:IsShown() and host.previewNavigation == nil)
host:SetMinimized(false,true);assert(host.previewFrame:IsShown() and not host.hubContent:IsShown() and not host.tabScroll:IsShown())
''')
print('Appearance checks passed: independent collapse edges, full height preservation, zero opacity, separate header/border alpha, readable controls and minimized preview restoration.')
