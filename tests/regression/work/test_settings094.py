from pathlib import Path
source=Path('work/test_global_appearance.py').read_text(encoding='utf-8')
exec(source[:source.index("print('Global appearance schema")])
lua.execute('''
assert(not options.args.whispers and not options.args.appearance)
assert(options.args.chat.childGroups=="tree")
assert(options.args.chat.args.windows and options.args.chat.args.whispers and options.args.chat.args.appearance)
local function hasLayout(group)
 if group.args and group.args.globalLayout then return true end
 for _,v in pairs(group.args or {}) do if v.type=="group" and hasLayout(v) then return true end end
 return false
end
assert(hasLayout(options.args.chat))
for key,group in pairs(options.args) do if key~="chat" then assert(not hasLayout(group),"chat layout leaked onto "..key) end end
local p=core:GetSettingsPath("whispers");assert(p[1]=="chat" and p[2]=="whispers")
p=core:GetSettingsPath("appearance");assert(p[1]=="chat" and p[2]=="appearance")
modules.Ellesmere.skin=nil;modules.Ellesmere.optionsRegistered=false;EllesmereUI=nil
local dialog=core.Libs.AceConfigDialog
function dialog:Open(app)assert(app=="Sunder")end
function dialog:SelectGroup(app,...) selectedPath={...} end
modules.Config:OpenSettings("whispers")
assert(selectedPath[1]=="chat" and selectedPath[2]=="whispers","standalone deep link failed")
modules.Ellesmere.optionsRegistered=true
EllesmereUI={OpenPlugin=function(id,section,page) nativeSection,nativePage=section,page;return true end}
modules.Config:OpenSettings("appearance")
assert(nativeSection=="chat" and nativePage=="Appearance","EUI deep link failed")
EllesmereUI.OpenPlugin=function()error("optional integration failure")end
modules.Config:OpenSettings("whispers")
assert(selectedPath[2]=="whispers","failed EUI integration did not fall back")
-- Render real adapter code against narrow native rows, including nested subsection selection.
local rendered,clicked,dropdowns={},0,{}
local function label(text)
 return {IsObjectType=function(_,kind)return kind=="FontString"end,
 GetStringWidth=function()return #text*8 end,GetStringHeight=function(self)return math.ceil(#text*8/(self.width or 9999))*16 end,
 SetWidth=function(self,w)self.width=w end,SetWordWrap=function()end,SetMaxLines=function()end}
end
local function row(text)
 local l=label(text)
 local b={width=200,IsObjectType=function(_,kind)return kind=="Button"end,GetRegions=function()return l end,
 SetWidth=function(self,w)self.width=w end,GetWidth=function(self)return self.width end,SetHeight=function(self,h)self.height=h end}
 return {GetChildren=function()return b end,GetWidth=function()return 270 end,SetHeight=function(self,h)self.height=h end,button=b,label=l}
end
local widgets={}
function widgets:Button(parent,text,y,callback)local r=row(text);r.callback=callback;rendered[#rendered+1]=r;return r,50 end
function widgets:Dropdown(parent,text,y,values,get,set,order)local r=row(text);dropdowns[#dropdowns+1]={get=get,set=set,values=values};return r,50 end
local synthetic={type="group",args={chat={type="group",name="Chat",childGroups="tree",args={
 windows={type="group",name="Chat windows",childGroups="tab",args={
  first={type="group",name="First",order=1,args={action={type="execute",name="A long action label that must wrap within the button",func=function()clicked=clicked+1 end}}},
  second={type="group",name="Second",order=2,args={action={type="execute",name="Second action",func=function()clicked=clicked+10 end}}}
 }}
}}}}
function core.Libs.AceConfigRegistry:GetOptionsTable()return synthetic end
EllesmereUI={Widgets=widgets,CONTENT_PAD=20,IsSearchPrebuild=function()return false end}
local modulesList=modules.Ellesmere:BuildOptionModules(synthetic)
local parent={GetWidth=function()return 310 end}
modulesList[1].buildPage("Chat windows",parent,0)
assert(#rendered==1 and rendered[1].button.width<=230)
assert(rendered[1].button.height>32,"long native action did not wrap")
assert(rendered[1].label.width<rendered[1].button.width)
rendered[1].callback();assert(clicked==1)
function modules.Ellesmere:ScheduleOptionsRefresh()end
dropdowns[1].set("second")
modulesList[1].buildPage("Chat windows",parent,0)
assert(dropdowns[2].get()=="second","subsection selection not retained")
rendered[2].callback();assert(clicked==11,"subsection action not routed")
EllesmereUI.IsSearchPrebuild=function()return true end
modulesList[1].buildPage("Chat windows",parent,0)
assert(#rendered==4,"search omitted a subsection")
''')
print('Settings polish passed: Chat hierarchy, scoped layout controls, standalone/EUI deep links and failure fallback, narrow action wrapping, subsection memory, action routing and complete search indexing.')
