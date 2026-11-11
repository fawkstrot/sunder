exec(open('work/test_simulation050.py',encoding='utf-8').read())
lua.execute('''
local scenarioBase=math.max(GetTime(),100000)+1000;cfg.previewConversations=10;now=scenarioBase;W:StartMessageSimulation()
local sim=W.previewSimulation;local start=now
assert(#W.previewConversations==1 and #sim.events==120)
assert(W.simulationStatus:IsShown() and W.simulationStatus.label:GetText():find('5:00',1,true))
local phaseCounts={}
for seconds=1,299 do
 now=start+seconds;W:Tick()
 if seconds==60 or seconds==150 or seconds==240 then
  assert(not W.hub:IsShown() and W.simulationStatus:IsShown())
  assert(W.simulationStatus.label:GetText():find('Quiet',1,true))
 end
 if seconds==85 then assert(#W.previewConversations==4) end
 if seconds==175 then assert(#W.previewConversations==7) end
 if seconds==265 then assert(#W.previewConversations==10) end
 if seconds==90 or seconds==180 or seconds==270 then assert(W.hub:IsShown()) end
end
assert(sim.sent==120 and sim.incoming==60 and sim.outgoing==60)
for _,person in ipairs(W.previewSamples) do
 assert(#person.lines==12)
 for i=1,8 do assert(person.lines[i].outgoing==(i%2==0)) end
 assert(person.lines[1].text~=person.lines[2].text)
end
now=start+300;W:Tick();assert(not W.previewSimulation and not W.simulationStatus:IsShown())
-- Replies follow each person's destination; minimized bars accumulate unread messages.
now=scenarioBase+1000;W:StartMessageSimulation();local begin=now
now=begin+7;W:Tick();local person=W.previewConversations[2]
W:PreviewAction('Favorite',person);local host=person.host
assert(host==W, 'starring a sample changed its window')
host:SetMinimized(true,true)
local unread=person.unread;now=begin+12;W:Tick()
assert(person.unread>unread and host.previewNavigation.unreadTotal>=person.unread)
host:SetMinimized(false,true)
W:PreviewAction('Detach',person);host=person.host
local before=#person.lines;now=begin+24;W:Tick();assert(#person.lines>before and person.host==host)
W:PreviewAction('Pin',person);now=begin+70;W:Tick();assert(host.hub:GetAlpha()==1)
W:PreviewAction('Pin',person);W:Tick();assert(host.hub:GetAlpha()==0)
W.simulationStatus.stop:GetScript('OnClick')();assert(not W.previewSimulation and not W.simulationStatus:IsShown())
-- Sound belongs to incoming messages only.
now=scenarioBase+2000;W:StartMessageSimulation();sim=W.previewSimulation
local c=W.previewSamples[1];local sounds=soundsPlayed
W:PlaySimulationEvent({at=0,person=c,text='Sounds good. See you there.',outgoing=true})
assert(soundsPlayed==sounds)
W:PlaySimulationEvent({at=0,person=c,text='See you at the inn!',outgoing=false})
assert(soundsPlayed==sounds+1)
W:ClearPreviewData();assert(not W.previewSamples)
''')
print('Full scenario checks passed: 10 staggered arrivals, 120 coherent lines, 60 incoming/60 outgoing, three idle timeouts and revivals, visible countdown while faded, Favorites and detached routing, minimized unread updates, pin/unpin timeout behavior, stop button and incoming-only sound.')
