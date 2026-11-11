from pathlib import Path
from lupa.lua51 import LuaRuntime
import re
ROOT=Path(__file__).resolve().parents[1]
CODE=ROOT/'addon/Sunder/Sunder'
def runtime():
    lua=LuaRuntime(unpack_returned_tuples=True)
    lua.execute("""
    modules={};core={};vars={}
    function clone(t)if type(t)~="table"then return t end local out={};for k,v in pairs(t)do out[k]=clone(v)end;return out end
    function core:NewModule(name)modules[name]={};return modules[name]end
    function core:GetModule(name)return modules[name]end
    function core:SetEnabledState(value)self.enabled=value end
    local ace={NewAddon=function()return core end}
    local db={New=function(_,name,defaults)
      _G[name]=_G[name] or {profiles={Default=clone(defaults.profile)},global={}}
      local saved=_G[name];return {profile=saved.profiles.Custom or saved.profiles.Default,global=saved.global,char=saved.char}
    end}
    function LibStub(name)if name=="AceAddon-3.0"then return ace elseif name=="AceDB-3.0"then return db elseif name=="LibSharedMedia-3.0"then return {GetDefault=function()return "Native"end}end;return {}end
    C_AddOns={GetAddOnMetadata=function()return "0.9.11"end}
    """)
    lua.execute((CODE/'init.lua').read_text(encoding='utf-8'),'Sunder',lua.globals().vars)
    lua.execute((CODE/'Migration.lua').read_text(encoding='utf-8'),'Sunder',lua.globals().vars)
    return lua
lua=runtime()
lua.execute(r"""
ROTBOTForeverDB={profiles={Custom={frameWidth=777,font="ROTBOTForever: Game default",asset="Interface\\AddOns\\ROTBOTForever\\ROTBOTForever\\Assets\\snapToBottomIcon",whispers={mode="hub",headerFont="Custom font"}}},
 profileKeys={["Person-Realm"]="Custom"},global={whisperModeBeforeRotbot="inline",minimap={hide=true,angle=70}},
 char={["Person-Realm"]={whisperHistory={{text="ROTBOT message text stays exactly as written"}},whisperFavorites={friend="Friend"},protectedItems={GUID={itemID=42}},whisperLayouts={friend={workspace="messages",pinned=true}},messageWindowStates={messages={open=true,minimized=true}}}}}
core:OnInitialize()
assert(SunderDB~=ROTBOTForeverDB and SunderDB.profiles.Custom~=ROTBOTForeverDB.profiles.Custom)
assert(SunderDB.profiles.Custom.frameWidth==777 and SunderDB.profileKeys["Person-Realm"]=="Custom")
assert(SunderDB.global.migratedFrom=="ROTBOTForeverDB" and SunderDB.global.sunderMigrationVersion==1 and SunderDB.global.whisperModeBeforeSunder=="inline")
assert(SunderDB.profiles.Custom.font=="Sunder: Game default")
assert(SunderDB.profiles.Custom.asset=="Interface\\AddOns\\Sunder\\Sunder\\Assets\\snapToBottomIcon")
local char=SunderDB.char["Person-Realm"]
assert(char.whisperHistory[1].text=="ROTBOT message text stays exactly as written" and char.protectedItems.GUID.itemID==42)
assert(char.whisperFavorites.friend=="Friend" and char.messageWindowStates.messages.minimized and char.whisperLayouts.friend.pinned)
SunderDB.profiles.Custom.frameWidth=900;core:OnInitialize();assert(SunderDB.profiles.Custom.frameWidth==900 and ROTBOTForeverDB.profiles.Custom.frameWidth==777)
assert(core.DisplayName=="Sunder" and core.Icon:find("SunderIcon",1,true))
ROTBOTForever={};core:CheckLegacyImplementation();assert(core.enabled==false,"two real implementations allowed to run")
""")
for name in ('RunestoneDB','GlassyDB'):
    test=runtime();test.execute(f'{name}={{profiles={{Default={{frameWidth=555}}}},global={{}}}};core:OnInitialize();assert(SunderDB.profiles.Default.frameWidth==555 and SunderDB.global.migratedFrom=="{name}")')
fresh=runtime();fresh.execute('core:OnInitialize();assert(SunderDB.profiles.Default.frameWidth==600)')
# Run the real slash registration code against both free and occupied short aliases.
source=(CODE/'Modules/Config.lua').read_text(encoding='utf-8')
registration=source[source.index('function C:OnEnable()'):source.index('function C:OnSlashCommand')]
short=runtime();short.execute("""
C=modules.Config;Core=core;commands={}
function normalizeSettings()end
function getChatOptions()return {}end
function core:RegisterFeature()end;function core:BuildOptions()return {}end;function core:LocalizeOptions()end
function core:Subscribe()end
function C:RegisterBlizzardOptions()end
function C:RegisterChatCommand(name)commands[name]=true end
core.db={RegisterCallback=function()end}
AceConfig={RegisterOptionsTable=function()end};AceConfigDialog={SetDefaultSize=function()end}
SAVE_FRAME_POSITION='save'
""")
short.execute(registration)
short.execute('C:OnEnable();assert(commands.sunder and commands.sun and commands.rotbot and commands.rotbotforever and commands.rb and commands.gl);commands={};SLASH_OTHER1="/sun";C:OnEnable();assert(commands.sunder and not commands.sun)')
# Profile exports use the new prefix; legacy inputs still decode without executing code.
transfer=runtime();transfer.execute((CODE/'Modules/ProfileTransfer.lua').read_text(encoding='utf-8'),'Sunder',transfer.globals().vars)
transfer.execute('local p=modules.ProfileTransfer;local text=p:Export({frameWidth=700});assert(text:sub(1,8)=="SUNDER1:");local imported=p:Import("GLASSY1:"..text:sub(9),{frameWidth=600});assert(imported.frameWidth==700);assert(p:Import("bad",{})==nil)')
# Every static Sunder asset reference resolves in the shipping folder.
addon=ROOT/'addon/Sunder'
for path in list(CODE.rglob('*.lua'))+[addon/'Sunder.toc']:
    text=path.read_text(encoding='utf-8').replace(chr(92)*2,chr(92))
    for suffix in re.findall(r'Interface\\Add[Oo]ns\\Sunder\\([^"\n|]+)',text):
        suffix=suffix.split(':',1)[0].replace(chr(92),'/')
        target=addon/suffix
        assert target.exists() or any(Path(str(target)+ext).exists() for ext in ('.tga','.blp','.ogg','.wav')),f'Broken asset: {path.name}: {suffix}'
print('Sunder migration/branding passed: complete legacy DB copy, profile/character/history preservation, idempotence, fresh install, media remap, old implementation guard, slash aliases/collision, profile import compatibility and asset references.')
