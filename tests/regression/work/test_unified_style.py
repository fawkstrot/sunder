exec(open('work/test_window_persistence.py',encoding='utf-8').read())
lua.execute('''
local methods=getmetatable(UIParent).__index
function methods:SetFontObject(font) self.usedFont=font end
function methods:SetWordWrap(value) self.wrap=value end
function methods:SetColorTexture(r,g,b,a) self.rgba={r,g,b,a} end
Core.Components.PaintGradientTexture=function(texture,color,opacity,fade)
 texture.paint={r=color.r,g=color.g,b=color.b,a=opacity,fade=fade}
 texture:SetColorTexture(color.r,color.g,color.b,opacity)
end
function Core:GetThemeColor(key)
 if key=="tabMessageSeparatorColor" then return {r=.2,g=.4,b=.6,a=0} end
 return {r=.2,g=.4,b=.6,a=1}
end
Core.db.profile.tabFontSize=11;Core.db.profile.chatTitleIconSize=12
Core.db.profile.textLeftPadding=4;Core.db.profile.tabMessageSpacing=3
Core.db.profile.chatBackgroundColor={r=.1,g=.2,b=.3,a=.25}
Core.db.profile.headerBackgroundColor={r=.2,g=.3,b=.4,a=.35}
Core.db.profile.chatTitleIconOpacity=.4
-- A newly introduced setting applies by default to existing profiles without discarding custom values.
cfg.hubMatchChat=nil;cfg.headerFontSize=22;cfg.hubBorderOpacity=.8;cfg.hubBackgroundOpacity=.9
assert(W:UsesChatAppearance())
W:StartPreview();W:RefreshHubStyle()
assert(W:HeaderHeight()==20 and W:ConversationTabHeight()==20 and W:HeaderGap()==3)
assert(W.hubTitle.usedFont=="SunderChatDockFont")
assert(W.hubHeaderFill.paint.a==.35 and W.hubHeaderFill.paint.fade)
assert(W.hubBackground.paint.a==.25 and W.hubBackground.paint.fade)
assert(W.tabStripBackground.paint.a==.35)
assert(W.hubBackground.points.TOPLEFT.y==-(20+20+3))
assert(W.hubRule.paint.a==0)
for _,line in ipairs(W.hubBorders) do assert(line.rgba[4]==0) end
assert(W.previewTabs[1]:GetFontString().wrap==false)
assert(W.previewTabs[1].selection.rgba[4]==0 and W.previewTabs[1].underline:GetHeight()==1)
assert(W.previewNavigation.left:GetHeight()==20 and not W.previewNavigation.divider:IsShown())
assert(W.hubActionButtons.Close.plate.rgba[4]==0 and W.hubActionButtons.Close.icon:GetAlpha()==.4)
assert(W.hubActionButtons.Close:GetHeight()==18)
W:SetMinimized(true,true);assert(W.hub:GetHeight()==20)
W:SetMinimized(false,true)
W:ClearPreviewData()
-- Grouped native frames supply their own scrolling background; the shell stays transparent behind them.
W.hubTabs[bob]=W.hubTabs[bob] or CreateFrame("Button",nil,W.tabChild);W.selected=bob
W:ApplyHubAppearance();assert(W.hubBackground.paint.a==0)
local f=W:GetWorkspace("group2");f:OpenMessages();f:RefreshHubStyle()
assert(f.hubHeaderFill.paint.a==.35)
assert(f.hubBackground.points.TOPLEFT.x==0)
-- Shared changes update geometry; custom overrides remain available and unchanged.
Core.db.profile.tabFontSize=18;Core.db.profile.tabMessageSpacing=7;W:RefreshHubStyle()
assert(W:HeaderHeight()==26 and W:ConversationTabHeight()==26 and W:HeaderGap()==7)
cfg.hubMatchChat=false;W:RefreshHubStyle()
assert(W:HeaderHeight()>=40 and W.hubBackground.paint.a==.9 and W.hubBorders[1].rgba[4]==.8)
assert(cfg.headerFontSize==22 and cfg.hubBorderOpacity==.8)
''')
print('Unified style passed: compact inherited typography/icons, shared opacity and fades, header gap, borderless tabs/navigation, no doubled native background, Favorites, collapse geometry, live shared changes and reversible custom styling.')
