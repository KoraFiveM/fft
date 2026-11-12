local sessions, replies, fixtures, history, throttle = {}, {}, {}, {}, {}
local serial = 0
local function uid() serial=serial+1; return ('%s:%s'):format(GetGameTimer(),serial) end
local function authorised(src)
    return GetConvar('fft_enabled','false')=='true' and IsPlayerAceAllowed(src,'fft.use')
end
-- Listings and reports run to hundreds of kilobytes. Sent as ordinary events
-- they stall the tester's reliable channel, so they travel latent instead.
local BULKY={catalogue=true,definitions=true,detail=true,report=true,pastReport=true,history=true,recording=true,search=true,errors=true}
local BULK_RATE=2000000 -- bytes per second
local function send(src,kind,data)
    if BULKY[kind] then TriggerLatentClientEvent('fft:ui',src,BULK_RATE,kind,data)
    else TriggerClientEvent('fft:ui',src,kind,data) end
end
-- Error log. Every run keeps one list holding both kinds of error:
--   type='test'    a step, hook, cleanup or scenario failure reported by FFT
--   type='console' an error line printed to the server console while the run was active
-- Console errors are attributed to the scenario and step that were executing.
-- Client (F8) console output is not visible to scripts and is not captured.
local MAX_ERRORS,MAX_MESSAGE=1000,4000
local function logError(s,entry)
    local r=s.report
    if not r then return end
    if #r.errors>=MAX_ERRORS then r.errorsTruncated=true; return end
    entry.n=#r.errors+1
    entry.time=os.date('!%Y-%m-%dT%H:%M:%SZ')
    entry.message=tostring(entry.message or ''):sub(1,MAX_MESSAGE)
    local c=s.cursor
    if c then
        entry.scenario,entry.uri,entry.line,entry.scenarioIndex=c.scenario,c.uri,c.line,c.index
        if entry.step==nil then entry.step,entry.stepIndex,entry.stepTotal=c.step,c.stepIndex,c.stepTotal end
    end
    r.errors[#r.errors+1]=entry
    s.unsent[#s.unsent+1]=entry
    return entry
end
local function flushErrors(s)
    if #s.unsent==0 then return end
    local batch=s.unsent
    s.unsent={}
    send(s.tester,'errors',{id=s.id,entries=batch})
end
-- Classification, traceback joining and expected errors live in shared/core.lua
-- (FFT.consoleLine/consoleRecord) so test/console.lua can cover them offline.
local consolePartial,consoleLast={},{}
local function consoleRecord(resource,plain)
    local entries={}
    for _,s in pairs(sessions) do
        if s.mode=='run' and s.report then
            local entry,expected=FFT.consoleRecord(s.context,resource,plain,function(e) return logError(s,e) end)
            if expected and s.cursor then entry.step,entry.stepIndex=s.cursor.step,s.cursor.stepIndex end
            if entry then entries[#entries+1]=entry end
        end
    end
    return entries
end
local function consoleLine(channel,line)
    FFT.consoleLine(consoleLast,channel,line,GetGameTimer(),consoleRecord)
end
if RegisterConsoleListener then
    RegisterConsoleListener(function(channel,message)
        if not next(sessions) then return end
        -- Never print from here: output would re-enter this listener.
        pcall(function()
            channel=tostring(channel)
            local text=(consolePartial[channel] or '')..tostring(message)
            local tail=text:match('[^\n]*$')
            for line in text:sub(1,#text-#tail):gmatch('([^\n]*)\n') do consoleLine(channel,line) end
            consolePartial[channel]=#tail>0 and tail:sub(-MAX_MESSAGE) or nil
        end)
    end)
end
local function summarise(report,planned)
    local sum={planned=planned or (report.summary and report.summary.planned) or #report.scenarios,
        run=#report.scenarios,passed=0,failed=0,cancelled=0,testErrors=0,consoleErrors=0,
        -- Console error lines a scenario declared in advance, and declarations that never matched.
        expectedConsole=0,unmatchedConsole=0}
    for _,r in ipairs(report.scenarios) do
        if r.status=='passed' then sum.passed=sum.passed+1 elseif r.status=='cancelled' then sum.cancelled=sum.cancelled+1 else sum.failed=sum.failed+1 end
        for _,e in ipairs(r.expectedConsole or {}) do
            sum.expectedConsole=sum.expectedConsole+e.matched
            if e.matched==0 then sum.unmatchedConsole=sum.unmatchedConsole+1 end
        end
    end
    for _,e in ipairs(report.errors or {}) do
        if e.type=='console' then sum.consoleErrors=sum.consoleErrors+1 else sum.testErrors=sum.testErrors+1 end
    end
    report.summary=sum
    return sum
end
local function errorLogText(report)
    local sum=report.summary or summarise(report)
    local out={('FFT error log · run %s · adapter %s'):format(tostring(report.id or 'setup'),tostring(report.adapter)),
        ('Started %s · finished %s · status %s'):format(tostring(report.started),tostring(report.finished or 'in progress'),tostring(report.status or 'running')),
        ('Scenarios: %d planned, %d run, %d passed, %d failed, %d cancelled'):format(sum.planned,sum.run,sum.passed,sum.failed,sum.cancelled),
        ('Errors: %d test, %d console%s'):format(sum.testErrors,sum.consoleErrors,report.errorsTruncated and (' (log capped at %d entries)'):format(MAX_ERRORS) or ''),
        'TEST = failure reported by a step, hook or cleanup. CONSOLE = error printed to the server console during the run.'}
    if sum.expectedConsole+sum.unmatchedConsole>0 then
        out[#out+1]=('Expected console errors: %d line(s) matched a scenario\'s declaration and are listed at the end, not above; %d declaration(s) never matched.')
            :format(sum.expectedConsole,sum.unmatchedConsole)
    end
    out[#out+1]=''
    for _,e in ipairs(report.errors or {}) do
        local label=e.type=='console' and ('CONSOLE '..tostring(e.resource)) or ('TEST '..tostring(e.kind))
        out[#out+1]=('#%d [%s] %s'):format(e.n,label,tostring(e.time))
        if e.scenario then
            out[#out+1]=('    scenario %s: %s (%s%s)'):format(tostring(e.scenarioIndex),e.scenario,tostring(e.uri),e.line and (':'..e.line) or '')
        end
        if e.step then out[#out+1]=('    step %s/%s: %s'):format(tostring(e.stepIndex),tostring(e.stepTotal),e.step) end
        for line in (e.message..'\n'):gmatch('([^\n]*)\n') do out[#out+1]='    '..line end
        out[#out+1]=''
    end
    -- Declared refusals are not errors, but nothing is dropped silently.
    for index,r in ipairs(report.scenarios or {}) do
        for _,e in ipairs(r.expectedConsole or {}) do
            out[#out+1]=('[EXPECTED CONSOLE%s] %s'):format(e.resource and (' '..e.resource) or '',
                e.matched>0 and ('matched %d line(s)'):format(e.matched) or 'NEVER SEEN (not a failure; check the text and that the refusal still prints)')
            out[#out+1]=('    scenario %d: %s (%s%s)'):format(index,tostring(r.name),tostring(r.uri),r.location and r.location.line and (':'..r.location.line) or '')
            out[#out+1]='    expected text: '..e.text
            for _,l in ipairs(e.lines) do
                if l.step then out[#out+1]=('    during step %s: %s'):format(tostring(l.stepIndex),l.step) end
                for line in (l.message..'\n'):gmatch('([^\n]*)\n') do out[#out+1]='        '..line end
            end
            out[#out+1]=''
        end
    end
    return table.concat(out,'\n')
end
-- Finished runs are archived as reports/<uuid>.json with reports/<uuid>-errors.log
-- and listed in reports/index.json with who ran them, so a tester can fetch
-- their own earlier results from the panel. A tester is identified by license;
-- only that tester's reports are listed or served to them.
local MAX_REPORTS_PER_TESTER=50
local function newUuid()
    return (('xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'):gsub('[xy]',function(c)
        return ('%x'):format(c=='x' and math.random(0,15) or math.random(8,11))
    end))
end
local function testerOf(src)
    local license=GetPlayerIdentifierByType and GetPlayerIdentifierByType(src,'license')
    if not license then
        for _,id in ipairs(GetPlayerIdentifiers(src) or {}) do if id:sub(1,8)=='license:' then license=id; break end end
    end
    return {name=tostring(GetPlayerName(src) or 'unknown'):sub(1,64),license=license or false}
end
local function reportPaths(id) return ('reports/%s.json'):format(id),('reports/%s-errors.log'):format(id) end
local function readIndex()
    local ok,list=pcall(json.decode,LoadResourceFile(GetCurrentResourceName(),'reports/index.json') or '[]')
    return ok and type(list)=='table' and list or {}
end
local function indexReport(report)
    local name=GetCurrentResourceName()
    local index,kept,dropped=readIndex(),{},{}
    index[#index+1]={uuid=report.uuid,tester=report.tester,adapter=report.adapter,status=report.status,
        started=report.started,finished=report.finished,summary=report.summary}
    -- Newest first per tester; anything beyond the cap is removed from disk.
    local count={}
    for i=#index,1,-1 do
        local entry=index[i]
        local key=type(entry.tester)=='table' and entry.tester.license or false
        count[key]=(count[key] or 0)+1
        if count[key]<=MAX_REPORTS_PER_TESTER then table.insert(kept,1,entry) else dropped[#dropped+1]=entry end
    end
    SaveResourceFile(name,'reports/index.json',json.encode(kept),-1)
    local root=GetResourcePath(name)
    for _,entry in ipairs(dropped) do
        if FFT.reportUuid(entry.uuid) and root and os and os.remove then
            for _,path in ipairs({reportPaths(entry.uuid)}) do pcall(os.remove,root..'/'..path) end
        end
    end
end
-- A tester's own archived runs, newest first.
local function ownReports(src)
    local license=testerOf(src).license
    local list={}
    if not license then return list end
    local index=readIndex()
    for i=#index,1,-1 do
        local entry=index[i]
        if type(entry.tester)=='table' and entry.tester.license==license and FFT.reportUuid(entry.uuid) then
            list[#list+1]={uuid=entry.uuid,name=entry.tester.name,adapter=entry.adapter,status=entry.status,
                started=entry.started,finished=entry.finished,summary=entry.summary}
        end
    end
    return list
end
local function loadOwnReport(src,id)
    assert(FFT.reportUuid(id),'Invalid report id')
    local license=testerOf(src).license
    assert(license,'No license identifier: past reports are unavailable')
    local owned=false
    for _,entry in ipairs(readIndex()) do
        if entry.uuid==id then owned=type(entry.tester)=='table' and entry.tester.license==license; break end
    end
    assert(owned,'No such report among your runs')
    local body=assert(LoadResourceFile(GetCurrentResourceName(),(reportPaths(id))),'The report file is missing')
    local ok,report=pcall(json.decode,body)
    assert(ok and type(report)=='table' and report.uuid==id,'The report file is unreadable')
    return report
end
-- One JSON file holds every result of a run, next to one text log of its errors.
-- 'latest' is rewritten as the run progresses so a crash still leaves a record.
local reportHint=false
local function writeReport(report,final)
    local name=GetCurrentResourceName()
    summarise(report)
    local paths={json='reports/latest.json',errors='reports/latest-errors.log'}
    report.files={json=paths.json,errors=paths.errors}
    local archived=final and FFT.reportUuid(report.uuid)
    if archived then report.files.archive,report.files.archiveErrors=reportPaths(report.uuid) end
    local body,log=json.encode(report),errorLogText(report)
    local ok=SaveResourceFile(name,paths.json,body,-1) and SaveResourceFile(name,paths.errors,log,-1)
    if ok and archived and SaveResourceFile(name,report.files.archive,body,-1) then
        SaveResourceFile(name,report.files.archiveErrors,log,-1)
        indexReport(report)
    end
    if not ok then
        report.files=nil
        if not reportHint then reportHint=true; print('[fft] Could not write reports: create a "reports" folder inside the fft resource.') end
    end
end
local function beginSession(src,mode)
    assert(not sessions[src],'A run or recording is already active')
    local s={id=uid(),tester=src,mode=mode,adapter=FFTConfig.adapter,cancelled=false}
    sessions[src]=s
    Player(src).state:set('fftSession',s.id,true)
    return s
end
local function finishSession(s)
    if sessions[s.tester]==s then
        sessions[s.tester]=nil
        Player(s.tester).state:set('fftSession',false,true)
    end
end
local function rpc(s,kind,data,timeout)
    local request=uid()
    replies[request]={source=s.tester,session=s.id}
    TriggerClientEvent('fft:execute',s.tester,{request=request,session=s.id,kind=kind,data=data})
    local deadline=GetGameTimer()+(timeout or FFTConfig.stepTimeout+1000)
    while replies[request] and not replies[request].result and GetGameTimer()<deadline do
        if (s.cancelled or not authorised(s.tester)) and kind~='cleanup' then break end
        Wait(25)
    end
    local response=replies[request] and replies[request].result
    replies[request]=nil
    if not response then error(kind..' response timed out or was cancelled') end
    assert(response.ok,response.error or 'Client execution failed')
    return response.value
end
RegisterNetEvent('fft:reply',function(request,session,result)
    local pending=replies[request]
    if pending and pending.source==source and pending.session==session and type(result)=='table'
        and #json.encode(result)<65536 then pending.result=result end
end)
local function parse(text,uri,tags,definitions)
    local response=json.decode(exports[GetCurrentResourceName()]:parseFeature(text,uri,definitions or json.encode(FFT.catalogue()),tags or ''))
    assert(response.ok,response.error)
    return response.scenarios
end
exports('registerFeature',function(path)
    local owner=GetInvokingResource() or GetCurrentResourceName()
    assert(type(path)=='string' and not path:find('..',1,true) and path:match('%.feature$'),'Use a resource-relative .feature path')
    assert(LoadResourceFile(owner,path),'Feature file missing: '..path)
    FFT.features[owner..'/'..path]={owner=owner,path=path}
end)
-- Matching every step against every definition costs seconds across the Kora
-- suites, so parsed plans are kept per feature and reused until the feature
-- text or the step catalogue changes. Plans are shared: treat them as read-only.
local planCache,cachedDefinitions,cachedKeys={},nil,nil
local bootId,revisionSerial=os.time(),0
local function revision() return ('%s:%s'):format(bootId,revisionSerial) end
---@param tags? string tag expression; nil or '' selects everything
---@param progress? fun(index:integer,total:integer) called before each feature that must be parsed
local function catalogue(tags,progress)
    tags=tags or ''
    local definitions=json.encode(FFT.catalogue())
    if definitions~=cachedDefinitions then cachedDefinitions,planCache=definitions,{}; revisionSerial=revisionSerial+1 end
    local scenarios={}
    local keys={}
    for key in pairs(FFT.features) do keys[#keys+1]=key end
    table.sort(keys)
    local joined=table.concat(keys,'\n')
    if joined~=cachedKeys then cachedKeys=joined; revisionSerial=revisionSerial+1 end
    for index,key in ipairs(keys) do
        local f=FFT.features[key]
        if f then -- a resource may stop while an earlier feature is being parsed
            local text=assert(LoadResourceFile(f.owner,f.path),'Feature removed: '..key)
            local entry=planCache[key]
            if not entry or entry.text~=text or entry.definitions~=definitions then
                entry={text=text,definitions=definitions}
                planCache[key]=entry
                revisionSerial=revisionSerial+1
            end
            -- The untagged plan backs the list; only the latest tag filter is kept beside it.
            local parsed=tags=='' and entry.all or (entry.tags==tags and entry.tagged) or nil
            if not parsed then
                if progress then progress(index,#keys) end
                parsed=parse(text,key,tags,definitions)
                if tags=='' then entry.all=parsed else entry.tags,entry.tagged=tags,parsed end
                Wait(0) -- let the server breathe between features
            end
            for _,p in ipairs(parsed) do scenarios[#scenarios+1]=p end
        end
    end
    return scenarios
end
-- The list carries one line per scenario; steps are fetched on demand ('detail').
local function listing(scenarios)
    local features,byUri={},{}
    for _,p in ipairs(scenarios) do
        local group=byUri[p.uri]
        if not group then group={uri=p.uri,scenarios={}}; byUri[p.uri]=group; features[#features+1]=group end
        local problems=0
        for _,step in ipairs(p.steps) do if step.error then problems=problems+1 end end
        group.scenarios[#group.scenarios+1]={id=p.id,name=p.name,tags=p.tags,steps=#p.steps,problems=problems}
    end
    return features
end
local function loadingStatus(src)
    return function(index,total) send(src,'status',{phase='Loading tests',loading=true,index=index,total=total}) end
end
---@param known? string revision the client already holds; the list is omitted when it is current
local function publish(src,known)
    local scenarios=catalogue(nil,loadingStatus(src))
    local current=revision()
    local payload={revision=current,adapter=FFTConfig.adapter,serverAddress=FFTConfig.serverAddress,
        fixture=fixtures[src] or FFTConfig.vending,stepKey=FFTConfig.debugStepKey or 'F6'}
    if known~=current then payload.features=listing(scenarios); payload.report=history[src] end
    send(src,'catalogue',payload)
end
local function dispatch(s,ctx,definition,args,argument)
    local d=assert(FFT.definitions[definition],'Definition removed during run')
    if d.realm=='server' then return FFT.execute(ctx,definition,args,argument) end
    return rpc(s,'step',{context=ctx.id,definition=definition,args=args,argument=argument})
end
local function hooks(s,ctx,kind,results)
    local list=FFT.catalogue()
    if kind=='After' then local reverse={}; for i=#list,1,-1 do reverse[#reverse+1]=list[i] end; list=reverse end
    for _,d in ipairs(list) do
        if d.hook==kind then
            local ok,result=pcall(dispatch,s,ctx,d.id,{},nil)
            results[#results+1]={name=d.pattern,status=ok and result.status or 'failed',error=ok and result.error or tostring(result)}
        end
    end
end
-- A persistent character belongs to the tester's own license. Its citizen ID is
-- remembered by this resource; every run switches to it before touching data.
local function seedKey(src)
    local license = GetPlayerIdentifierByType(src,'license')
    assert(license,'A player license is required to seed a test character')
    return 'test-character:'..license
end
local function revealCharacter(src, position)
    TriggerClientEvent('qb-multicharacter:client:closeNUI',src)
    Wait(250)
    TriggerClientEvent('fft:characterReady',src,position)
end
local function characterTransition(fn, label)
    local deadline=GetGameTimer()+5000
    repeat
        local ok,reason=fn()
        if ok then return end
        if reason~='player data is busy' and reason~='character logout is in progress' then
            error(label..': '..tostring(reason))
        end
        Wait(100)
    until GetGameTimer()>=deadline
    error(label..': player data remained busy for five seconds')
end
local function testCharacter(src)
    assert(FFTConfig.adapter=='kora','Test-character seeding requires the Kora adapter')
    local core=exports.kora_core
    local key=seedKey(src)
    local citizenid=GetResourceKvpString(key)
    local current=core:getPlayer(src)
    if citizenid and current and current.citizenid==citizenid then return current.citizenid end
    local original=current and current.citizenid or nil
    Player(src).state:set('fftCharacterSwitch',true,true)
    Wait(250)
    if citizenid then
        assert(core:ownsCharacter(src,citizenid),'Saved test character no longer belongs to this tester')
    end
    if current then
        characterTransition(function() return core:logout(src) end,'Could not leave the current character')
    end
    if citizenid then
        characterTransition(function() return core:selectCharacter(src,citizenid) end,'Could not load the test character')
    else
        local created,err=core:createCharacter(src,{firstname='Functional',lastname='Tester',birthdate='1990-01-01',gender=0,nationality='USA'})
        assert(created,err or 'Could not create the test character; a free character slot is required')
        citizenid=created
        SetResourceKvp(key,citizenid)
    end
    assert(core:getPlayer(src).citizenid==citizenid,'Test character did not become active')
    revealCharacter(src)
    return original
end
local function restockVending()
    -- This resource does not load inventory's Config; use our own known fixture stock.
    local inventory=exports.kora_inventory
    local current,err=inventory:GetShopItems('vendingmachine')
    assert(current,err or 'Vending shop stock unavailable')
    local changed=false
    for slot,row in ipairs({{name='water_bottle',amount=45,price=4},{name='soda',amount=45,price=5}}) do
        local item=current[slot]
        if not item or item.name~=row.name or item.amount~=row.amount then
            current[slot]={name=row.name,amount=row.amount,price=row.price}
            changed=true
        end
    end
    if changed then
        local ok,reason=inventory:SetShopItems('vendingmachine',current)
        assert(ok,reason or 'Could not restock vending machine')
    end
end
local function resetTestCharacter(src)
    restockVending()
    local core=exports.kora_core
    local data=assert(core:getPlayer(src),'Test character is not loaded')
    assert(data.citizenid==GetResourceKvpString(seedKey(src)),'Refusing to reset a non-test character')
    -- Use public mutation APIs so persistence, replication, and physical cash agree.
    local malformed=false
    for slot,item in pairs(data.items or {}) do
        if item and item.name and item.amount and item.amount>0 then
            local ok,err=core:removeItem(src,item.name,item.amount,tonumber(slot),'functional test reset')
            assert(ok,err or 'Could not clear inventory slot '..tostring(slot))
        elseif item then
            malformed=true
        end
    end
    -- A stack without a positive amount cannot be removed by amount; one left
    -- behind breaks every later add of that item, so clear the inventory outright.
    if malformed and GetResourceState('kora_inventory')=='started' then
        pcall(function() exports.kora_inventory:clearInventory(src) end)
    end
    for account,amount in pairs(FFTConfig.testCharacter or {}) do
        local ok,err=core:setMoney(src,account,amount,'functional test reset')
        assert(ok,err or 'Could not reset '..account)
    end
    -- A scenario that downs the tester (damage, a fall, an ambulance flow) must not
    -- leave the next one downed: downed players cannot target or open shops.
    local meta=data.metadata or {}
    if (meta.isdead or meta.inlaststand) and GetResourceState('kora_ambulance')=='started' then
        pcall(function() exports.kora_ambulance:fullRevive(src) end)
    end
end
-- First line of an error without the '@file:line:' prefixes and traceback.
local function plainError(e)
    local line=tostring(e):match('^[^\n]*') or ''
    while true do
        local rest=line:match('^@?[%w_%-/%.]+%.lua:%d+: (.*)$')
        if not rest then return line end
        line=rest
    end
end
local function run(s,plans)
    local report={id=s.id,uuid=newUuid(),tester=testerOf(s.tester),adapter=s.adapter,started=os.date('!%Y-%m-%dT%H:%M:%SZ'),stamp=os.date('!%Y%m%d-%H%M%S'),
        tags=s.tags,search=s.search,scenarios={},errors={}}
    s.report,s.unsent=report,{}
    summarise(report,#plans)
    -- Drives the tester's on-screen status while the panel is closed.
    local passed,failed,position,current=0,0,0,nil
    local function status(phase,step,stepIndex,stepTotal,paused,previous)
        send(s.tester,'status',{id=s.id,phase=phase,index=position,total=#plans,scenario=current,
            step=step,stepIndex=stepIndex,stepTotal=stepTotal,passed=passed,failed=failed,
            paused=paused,previous=previous,debug=s.debug or nil})
    end
    local ok,err=xpcall(function()
        -- A missing hook or core resource fails every scenario identically: report it once.
        status('Checking test hooks')
        local ready,why=pcall(function()
            FFT.preflight(s.adapter,{})
            rpc(s,'preflight',{adapter=s.adapter})
        end)
        if not ready then error('Run aborted before the first scenario: '..plainError(why),0) end
        for scenarioIndex,scenario in ipairs(plans) do
            if s.cancelled or not authorised(s.tester) then break end
            position,current=scenarioIndex,scenario.name
            s.cursor={scenario=scenario.name,uri=scenario.uri,line=scenario.location and scenario.location.line,index=scenarioIndex}
            status('Preparing scenario')
            local result={name=scenario.name,uri=scenario.uri,location=scenario.location,status='passed',steps={},hooks={},cleanupErrors={}}
            report.scenarios[#report.scenarios+1]=result
            if s.adapter=='kora' then resetTestCharacter(s.tester) end
            local ctx=FFT.context(uid(),s.tester,fixtures[s.tester] or FFTConfig.vending,s.adapter)
            s.context=ctx
            local began=false
            -- The resource a feature covers (K.feature) must be running in both realms.
            local feature=FFT.features[scenario.uri]
            local required=feature and feature.resource or nil
            local notStarted=false
            local scenarioOK,scenarioErr=xpcall(function()
                for _,step in ipairs(scenario.steps) do if step.error then error(step.error..': '..step.text) end end
                if required and GetResourceState(required)~='started' then
                    notStarted=true
                    error(('%s is %s on the server; start it to run this scenario'):format(required,GetResourceState(required)),0)
                end
                FFT.preflight(s.adapter,{})
                local begun,beginErr=pcall(rpc,s,'begin',{context=ctx.id,fixture=ctx.fixture,adapter=s.adapter,requires=required})
                if not begun then
                    if tostring(beginErr):find(' on the client; start it',1,true) then notStarted=true; error(plainError(beginErr),0) end
                    error(beginErr,0)
                end
                began=true
                hooks(s,ctx,'Before',result.hooks)
                for _,h in ipairs(result.hooks) do assert(h.status=='passed','Before hook failed: '..h.name) end
                local failed=false
                for stepIndex,step in ipairs(scenario.steps) do
                    local outcome={status='skipped'}
                    s.cursor.step,s.cursor.stepIndex,s.cursor.stepTotal=step.text,stepIndex,#scenario.steps
                    if s.debug and not failed and not s.cancelled then
                        -- Debug: hold before the step. The scenario context stays alive.
                        local before=result.steps[#result.steps]
                        s.paused=true
                        status('Paused',step.text,stepIndex,#scenario.steps,true,before and {text=before.text,status=before.status} or nil)
                        while s.paused and not s.cancelled and authorised(s.tester) do Wait(50) end
                        s.paused=false
                    end
                    if not failed and not s.cancelled and authorised(s.tester) then
                        status('Running',step.text,stepIndex,#scenario.steps)
                        local executed,value=pcall(dispatch,s,ctx,step.definition,step.args,step.argument)
                        outcome=executed and value or {status='failed',error=tostring(value)}
                        if outcome.status~='passed' then failed=true end
                    else failed=true end
                    outcome.text,outcome.location,outcome.realm=step.text,step.location,step.realm
                    outcome.authority=step.realm=='server' and 'server' or 'client-reported'
                    result.steps[#result.steps+1]=outcome
                    if outcome.status=='failed' or outcome.status=='timed_out' then
                        local message=tostring(outcome.error or outcome.status)
                        if outcome.assertion then
                            message=('%s\nExpected: %s\nActual: %s'):format(message,json.encode(outcome.assertion.expected),json.encode(outcome.assertion.actual))
                        end
                        logError(s,{type='test',kind=outcome.status=='timed_out' and 'timeout' or 'step',realm=step.realm,message=message})
                    end
                    flushErrors(s)
                    send(s.tester,'progress',result)
                    if not failed and stepIndex<#scenario.steps and s.stepDelayMs>0 then
                        local untilTime=GetGameTimer()+s.stepDelayMs
                        while not s.cancelled and GetGameTimer()<untilTime do Wait(50) end
                    end
                end
                if failed then result.status=s.cancelled and 'cancelled' or 'failed' end
            end,function(e) return notStarted and e or debug.traceback(e) end)
            s.cursor.step,s.cursor.stepIndex,s.cursor.stepTotal=nil,nil,nil
            if not scenarioOK then
                result.status='failed'; result.error=scenarioErr
                logError(s,{type='test',kind='scenario',step=false,message=scenarioErr})
            end
            status(s.cancelled and 'Stopping' or 'Cleaning up')
            -- Never revive a timed-out context: a late coroutine must stay cancelled.
            local after=FFT.context(ctx.id..':after',s.tester,ctx.fixture,s.adapter)
            after.state=json.decode(json.encode(ctx.state))
            after.expectedConsole=ctx.expectedConsole
            local afterBegan=false
            if began then
                local ready=pcall(rpc,s,'afterBegin',{context=after.id,previous=ctx.id},FFTConfig.cleanupTimeout)
                afterBegan=ready
            end
            if not s.cancelled and authorised(s.tester) and afterBegan then hooks(s,after,'After',result.hooks) end
            for _,h in ipairs(result.hooks) do if h.status~='passed' then result.status='failed' end end
            result.cleanupErrors=FFT.cleanup(ctx)
            for _,e in ipairs(FFT.cleanup(after)) do result.cleanupErrors[#result.cleanupErrors+1]=e end
            if began then
                local cleaned,errors=pcall(rpc,s,'cleanup',{context=ctx.id,after=after.id},FFTConfig.cleanupTimeout*3)
                if cleaned then for _,e in ipairs(errors or {}) do result.cleanupErrors[#result.cleanupErrors+1]=e end
                else result.cleanupErrors[#result.cleanupErrors+1]=tostring(errors) end
            end
            if #result.cleanupErrors>0 then result.status='failed' end
            -- Expectations end with the scenario: later console lines are ordinary errors again.
            if #ctx.expectedConsole>0 then result.expectedConsole=ctx.expectedConsole end
            for _,h in ipairs(result.hooks) do
                if h.status~='passed' then logError(s,{type='test',kind='hook',step=false,message=('%s hook: %s'):format(h.name,tostring(h.error or h.status))}) end
            end
            for _,e in ipairs(result.cleanupErrors) do logError(s,{type='test',kind='cleanup',step=false,message=e}) end
            flushErrors(s)
            s.context=nil
            if result.status=='passed' then passed=passed+1 else failed=failed+1 end
            if s.adapter=='kora' then resetTestCharacter(s.tester) end
            if scenarioIndex%25==0 then writeReport(report,false) end
        end
    end,debug.traceback)
    current=nil
    if not ok then logError(s,{type='test',kind='run',step=false,message=err}) end
    s.cursor=nil
    status('Finishing')
    report.error=not ok and err or nil
    report.status=s.cancelled and 'cancelled' or (ok and 'passed' or 'failed')
    if #report.scenarios==0 then report.status=s.cancelled and 'cancelled' or 'failed' end
    for _,r in ipairs(report.scenarios) do if r.status~='passed' and report.status~='cancelled' then report.status='failed' end end
    if s.originalCitizenId and s.originalCitizenId~=GetResourceKvpString(seedKey(s.tester)) then
        status('Restoring your character')
        local restored,restoreErr=pcall(function()
            local core=exports.kora_core
            local current=core:getPlayer(s.tester)
            if current and current.citizenid~=s.originalCitizenId then
                characterTransition(function() return core:logout(s.tester) end,'Could not leave test character')
            end
            local active=core:getPlayer(s.tester)
            if not active then
                characterTransition(function() return core:selectCharacter(s.tester,s.originalCitizenId) end,'Could not restore original character')
            end
        end)
        if restored then revealCharacter(s.tester,s.originalPosition)
        else
            report.status='failed'; report.error=(report.error or '')..' Character restore failed: '..tostring(restoreErr)
            logError(s,{type='test',kind='run',step=false,message='Character restore failed: '..tostring(restoreErr)})
        end
    end
    if s.adapter=='kora' then
        Wait(250)
        Player(s.tester).state:set('fftCharacterSwitch',false,true)
    end
    report.finished=os.date('!%Y-%m-%dT%H:%M:%SZ')
    -- Entries were already delivered or travel inside the report itself.
    s.unsent={}
    writeReport(report,true)
    history[s.tester]=report
    pcall(function() send(s.tester,'history',ownReports(s.tester)) end)
    finishSession(s)
    send(s.tester,'report',report)
end
local function matches(p,query)
    if p.name:lower():find(query,1,true) or p.uri:lower():find(query,1,true) then return true end
    for _,tag in ipairs(p.tags or {}) do if tag:lower():find(query,1,true) then return true end end
    for _,step in ipairs(p.steps) do if step.text:lower():find(query,1,true) then return true end end
    return false
end
local function query(value)
    value=type(value)=='string' and value:lower():gsub('^%s+',''):gsub('%s+$',''):sub(1,120) or ''
    return value~='' and value or nil
end
local function emitRecording(s,kind,data,authority)
    if sessions[s.tester]~=s or s.mode~='record' then return end
    if #s.events>=FFTConfig.maxRecordingEvents then s.truncated=true; return end
    s.events[#s.events+1]={id=#s.events+1,time=GetGameTimer()-s.started,kind=kind,data=data,authority=authority}
end
local function stopRecording(s)
    FFT.cleanup(s.context)
    pcall(rpc,s,'recordStop',{},FFTConfig.cleanupTimeout)
    local events=s.events
    local draft=exports[GetCurrentResourceName()]:recordingDraft(json.encode(events))
    finishSession(s)
    send(s.tester,'recording',{events=events,draft=draft,truncated=s.truncated,fixture=fixtures[s.tester] or FFTConfig.vending})
end
RegisterNetEvent('fft:recordEvent',function(session,sequence,kind,data)
    local s=sessions[source]
    if not s or s.mode~='record' or s.id~=session or not authorised(source) then return end
    if type(sequence)~='number' or sequence%1~=0 or sequence<=(s.sequence or 0) then return end
    if type(kind)~='string' or #kind>80 or type(data)~='table' or #json.encode(data)>4096 then return end
    if kind~='target.selected' and not kind:match('^ui%.') and kind~='note' then return end
    s.sequence=sequence
    emitRecording(s,kind,data,'client-reported')
end)
local function fixtureValid(src,f)
    assert(type(f)=='table' and type(f.model)=='number','Invalid fixture model')
    for _,p in ipairs({f.coords or {},f.approach or {}}) do
        for _,key in ipairs({'x','y','z'}) do assert(type(p[key])=='number' and p[key]==p[key] and math.abs(p[key])<20000,'Invalid fixture coordinates') end
    end
    local p=GetEntityCoords(GetPlayerPed(src))
    assert(#(vector3(f.approach.x,f.approach.y,f.approach.z)-p)<5,'Capture a fixture at your current position')
    assert(#(vector3(f.coords.x,f.coords.y,f.coords.z)-p)<5,'Stand within five metres of the vending machine')
    assert(type(f.approach.heading)=='number' and math.abs(f.approach.heading)<=360,'Invalid heading')
    if f.camera then
        assert(type(f.camera.heading)=='number' and math.abs(f.camera.heading)<=360,'Invalid camera heading')
        assert(type(f.camera.pitch)=='number' and math.abs(f.camera.pitch)<=90,'Invalid camera pitch')
    end
    return f
end
RegisterNetEvent('fft:request',function(action,data)
    local src=source
    if not authorised(src) then send(src,'error','Enable fft_enabled and grant fft.use to this tester'); return end
    if type(action)~='string' or type(data)~='table' or #json.encode(data)>140000 then return end
    local now=GetGameTimer()
    if throttle[src] and now-throttle[src]<100 and action~='stop' then return end
    throttle[src]=now
    CreateThread(function()
        local ok,err=xpcall(function()
            if action=='list' then publish(src,type(data.revision)=='string' and data.revision or nil); send(src,'history',ownReports(src))
            elseif action=='loadReport' then send(src,'pastReport',loadOwnReport(src,data.uuid))
            elseif action=='detail' then
                for _,p in ipairs(catalogue()) do
                    if p.id==data.id then
                        local steps={}
                        for i,step in ipairs(p.steps) do steps[i]={text=step.text,realm=step.realm,error=step.error,location=step.location} end
                        send(src,'detail',{id=p.id,uri=p.uri,steps=steps})
                        return
                    end
                end
                error('That scenario no longer exists. Refresh the list.',0)
            elseif action=='definitions' then
                local list={}
                for _,d in ipairs(FFT.catalogue()) do
                    if not d.hook then list[#list+1]={realm=d.realm,pattern=d.pattern,owner=d.id:match('^([^:]+)')} end
                end
                send(src,'definitions',list)
            elseif action=='search' then
                -- Step text is not part of the list, so step matches are resolved here.
                -- A tag expression is resolved by the parser, exactly as 'Run matching' does.
                local q,ids=query(data.query),{}
                local tags=type(data.tags)=='string' and data.tags or ''
                if q or tags~='' then
                    for _,p in ipairs(catalogue(tags,loadingStatus(src))) do if not q or matches(p,q) then ids[#ids+1]=p.id end end
                end
                send(src,'search',{query=data.query,tags=tags,ids=ids})
            elseif action=='continue' then
                local s=sessions[src]
                if s and s.mode=='run' then
                    if data.all then s.debug=false end
                    s.paused=false
                end
            elseif action=='feedback' then
                local text=type(data.text)=='string' and data.text:sub(1,4000) or ''
                assert(text:find('%S'),'Write some feedback first')
                local name=GetCurrentResourceName()
                local line=json.encode({time=os.date('!%Y-%m-%dT%H:%M:%SZ'),tester=GetPlayerName(src),adapter=FFTConfig.adapter,text=text})
                assert(SaveResourceFile(name,'reports/feedback.jsonl',(LoadResourceFile(name,'reports/feedback.jsonl') or '')..line..'\n',-1),
                    'Could not save feedback: create a "reports" folder inside the fft resource')
                send(src,'feedback','reports/feedback.jsonl')
            elseif action=='validate' then send(src,'validation',parse(data.text or '','draft.feature',data.tags))
            elseif action=='fixture' then
                assert(not sessions[src],'Stop the current session before changing its fixture')
                fixtures[src]=fixtureValid(src,data); publish(src)
            elseif action=='run' then
                send(src,'status',{phase='Loading tests'})
                local plans=data.text and parse(data.text,'draft.feature',data.tags) or catalogue(data.tags,loadingStatus(src))
                if data.id then local selected={}; for _,p in ipairs(plans) do if p.id==data.id then selected[#selected+1]=p end end; plans=selected end
                local q=not data.id and not data.text and query(data.search) or nil
                if q then local selected={}; for _,p in ipairs(plans) do if matches(p,q) then selected[#selected+1]=p end end; plans=selected end
                assert(#plans>0,'No scenarios selected')
                assert(not sessions[src],'A run or recording is already active')
                local original,originalPosition
                if FFTConfig.adapter=='kora' then
                    send(src,'status',{phase='Switching to the test character',total=#plans})
                    local before=exports.kora_core:getPlayer(src)
                    local ped=GetPlayerPed(src)
                    if before and ped and ped~=0 then
                        local pos=GetEntityCoords(ped)
                        originalPosition={x=pos.x,y=pos.y,z=pos.z,heading=GetEntityHeading(ped)}
                    end
                    local ok,value=pcall(testCharacter,src)
                    if not ok then
                        if before and not exports.kora_core:getPlayer(src) then
                            pcall(function() exports.kora_core:selectCharacter(src,before.citizenid) end)
                        end
                        Player(src).state:set('fftCharacterSwitch',false,true)
                        error(value)
                    end
                    original=value
                end
                local s=beginSession(src,'run'); s.originalCitizenId=original; s.originalPosition=originalPosition
                s.stepDelayMs=math.min(5000,math.max(0,math.floor(tonumber(data.stepDelayMs) or 0)))
                s.debug=data.debug==true
                s.tags=type(data.tags)=='string' and data.tags~='' and data.tags or nil
                s.search=q
                send(src,'running',{id=s.id,debug=s.debug}); run(s,plans)
            elseif action=='record' then
                FFT.preflight(FFTConfig.adapter,{})
                local s=beginSession(src,'record')
                s.events,s.started={},GetGameTimer()
                s.context=FFT.context(s.id,src,fixtures[src],s.adapter)
                local a=FFT.adapters[s.adapter]
                if a.record then a.record(s.context,function(k,d,authority) emitRecording(s,k,d,authority) end) end
                local started,errorMessage=pcall(rpc,s,'recordStart',{adapter=s.adapter})
                if not started then FFT.cleanup(s.context); finishSession(s); error(errorMessage) end
                send(src,'recordStarted',{id=s.id})
            elseif action=='stop' then
                local s=sessions[src]
                if s then
                    if s.mode=='record' then stopRecording(s)
                    else
                        s.cancelled=true; if s.context then s.context.cancelled=true end; TriggerClientEvent('fft:cancel',src,s.id)
                        send(src,'status',{id=s.id,phase='Stopping'})
                    end
                end
            else error('Unknown action') end
        end,debug.traceback)
        if not ok then
            if action=='run' then
                local stamp=os.date('!%Y-%m-%dT%H:%M:%SZ')
                local report={uuid=newUuid(),tester=testerOf(src),status='failed',phase='setup',adapter=FFTConfig.adapter,error=err,scenarios={},started=stamp,finished=stamp,
                    stamp=os.date('!%Y%m%d-%H%M%S'),errors={{n=1,type='test',kind='setup',time=stamp,message=tostring(err):sub(1,MAX_MESSAGE)}}}
                pcall(writeReport,report,true)
                history[src]=report
                send(src,'report',report)
                send(src,'history',ownReports(src))
            else send(src,'error',err) end
        end
    end)
end)
AddEventHandler('playerDropped',function()
    local src=source
    local s=sessions[src]
    if s then s.cancelled=true; if s.context then CreateThread(function() FFT.cleanup(s.context) end) end; sessions[src]=nil end
    fixtures[src],history[src],throttle[src]=nil,nil,nil
end)
AddEventHandler('onResourceStop',function(name)
    if name==GetCurrentResourceName() then
        for src,s in pairs(sessions) do s.cancelled=true; Player(src).state:set('fftSession',false,true); TriggerClientEvent('fft:cancel',src,s.id) end
    end
end)
CreateThread(function()
    Wait(0)
    for _,path in ipairs({'features/native.feature','features/kora_basics.feature','features/vending.feature'}) do
        FFT.features[GetCurrentResourceName()..'/'..path]={owner=GetCurrentResourceName(),path=path}
    end
    -- Parse the suites ahead of the first /fft so the panel opens with a warm cache.
    CreateThread(function()
        Wait(2000)
        local ok,err=pcall(catalogue)
        if not ok then print('[fft] Could not preload features: '..tostring(err)) end
    end)
    while true do
        Wait(1000)
        for src,s in pairs(sessions) do
            if s.mode=='run' and s.unsent then flushErrors(s) end
            if not authorised(src) then
                s.cancelled=true
                if s.context then s.context.cancelled=true end
                Player(src).state:set('fftSession',false,true)
                TriggerClientEvent('fft:cancel',src,s.id)
                if s.mode=='record' then CreateThread(function() stopRecording(s) end) end
            end
        end
    end
end)
