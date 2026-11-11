local currentSession, recording, recordSequence, opened = nil, nil, 0, false
-- Revision of the scenario list the UI already holds; lets the server skip resending it.
local listRevision = nil
local function ui(kind,data) SendNUIMessage({kind=kind,data=data}) end
local function focus(value) opened=value; SetNuiFocus(value,value); ui('visible',value) end
local function request(action,data) TriggerServerEvent('fft:request',action,data or {}) end
RegisterCommand('fft',function()
    if recording then request('stop') else focus(true); request('list',{revision=listRevision}) end
end,false)
RegisterCommand('fft_stop_recording',function() if recording then request('stop') end end,false)
RegisterKeyMapping('fft_stop_recording','Stop functional test recording','keyboard',FFTConfig.stopRecordKey)
-- Debug runs pause before each step with game focus released; this advances one step.
RegisterCommand('fft_step',function() request('continue') end,false)
RegisterKeyMapping('fft_step','Functional test debug: run next step','keyboard',FFTConfig.debugStepKey or 'F6')
RegisterNUICallback('action',function(data,cb)
    if data.action=='close' then focus(false)
    elseif data.action=='fixture' then
        local ped=PlayerPedId()
        local p=GetEntityCoords(ped)
        local found,best=nil,5.0
        for _,name in ipairs({'prop_vend_soda_01','prop_vend_soda_02'}) do
            local entity=GetClosestObjectOfType(p.x,p.y,p.z,5.0,GetHashKey(name),false,false,false)
            if entity~=0 then
                local c=GetEntityCoords(entity); local distance=#(c-p)
                if distance<best then best=distance; found={model=GetEntityModel(entity),coords={x=c.x,y=c.y,z=c.z}} end
            end
        end
        if found then
            found.approach={x=p.x,y=p.y,z=p.z,heading=GetEntityHeading(ped)}
            found.camera={heading=GetGameplayCamRelativeHeading(),pitch=GetGameplayCamRelativePitch()}
            request('fixture',found)
        else ui('error','Stand near a soda machine and aim at it before capturing a fixture') end
    else request(data.action,data.data) end
    cb({ok=true})
end)
-- Real NUI callback round trip for step files: the FFT page fetches
-- https://<resource>/<name> like the resource's own page and reports the answer.
-- Returns ok, result | false, message. The page is loaded even while hidden.
local nuiCalls, nuiSequence = {}, 0
RegisterNUICallback('nuiResult',function(data,cb)
    local call=type(data)=='table' and nuiCalls[data.id]
    if call then call.done=true; call.ok=data.ok==true; call.result=data.result; call.error=data.error end
    cb({ok=true})
end)
function FFT.nui(resource,name,body,timeout)
    assert(type(resource)=='string' and resource:match('^[%w_%-]+$'),'Invalid NUI resource name')
    assert(type(name)=='string' and #name>0 and #name<=120 and not name:find('[/?#%s]'),'Invalid NUI callback name')
    timeout=math.min(tonumber(timeout) or 5000,10000)
    nuiSequence=nuiSequence+1
    local id,call=nuiSequence,{}
    nuiCalls[id]=call
    ui('nuiFetch',{id=id,resource=resource,name=name,body=body==nil and {} or body,timeout=timeout})
    local deadline=GetGameTimer()+timeout+500
    while not call.done and GetGameTimer()<deadline do Wait(0) end
    nuiCalls[id]=nil
    if not call.done then return false,('%s did not answer the NUI callback %s'):format(resource,name) end
    if not call.ok then return false,('NUI callback %s/%s failed: %s'):format(resource,name,tostring(call.error)) end
    return true,call.result
end
RegisterNetEvent('fft:ui',function(kind,data)
    if kind=='recordStarted' or kind=='running' then focus(false) end
    if kind=='recording' or kind=='report' then focus(true) end
    if kind=='error' then focus(true) end
    if kind=='catalogue' and type(data)=='table' then listRevision=data.revision end
    ui(kind,data)
end)
local function recordEmit(kind,data)
    if recording then
        recordSequence=recordSequence+1
        TriggerServerEvent('fft:recordEvent',currentSession,recordSequence,kind,data)
    end
end
exports('recordNote',function(message) recordEmit('note',{message=tostring(message):sub(1,500)}) end)
RegisterNetEvent('fft:execute',function(message)
    if type(message)~='table' or type(message.data)~='table' then return end
    CreateThread(function()
        local ok,value=xpcall(function()
            local d=message.data
            if message.kind=='begin' or message.kind=='recordStart' then
                assert(not currentSession or currentSession==message.session,'Another session is active')
                FFT.preflight(d.adapter,{})
                if type(d.requires)=='string' and GetResourceState(d.requires)~='started' then
                    error(('%s is %s on the client; start it to run this scenario'):format(d.requires,GetResourceState(d.requires)),0)
                end
                local deadline=GetGameTimer()+2000
                while LocalPlayer.state.fftSession~=message.session and GetGameTimer()<deadline do Wait(25) end
                assert(LocalPlayer.state.fftSession==message.session,'Authorised session did not replicate')
                currentSession=message.session
                if message.kind=='begin' then FFT.context(d.context,GetPlayerServerId(PlayerId()),d.fixture,d.adapter)
                else
                    recordSequence=0
                    recording=FFT.context(message.session,GetPlayerServerId(PlayerId()),nil,d.adapter)
                    local a=FFT.adapters[d.adapter]
                    if a.record then a.record(recording,recordEmit) end
                end
                return true
            end
            if message.kind=='preflight' then FFT.preflight(d.adapter,{}); return true end
            assert(message.session==currentSession,'Stale session')
            if message.kind=='step' then
                local ctx=assert(FFT.contexts[d.context],'Scenario context missing')
                return FFT.execute(ctx,d.definition,d.args,d.argument)
            elseif message.kind=='afterBegin' then
                local previous=assert(FFT.contexts[d.previous],'Scenario context missing')
                local after=FFT.context(d.context,previous.tester,previous.fixture,previous.adapterId)
                after.state=json.decode(json.encode(previous.state))
                return true
            elseif message.kind=='cleanup' then
                local ctx=FFT.contexts[d.context]
                local errors=ctx and FFT.cleanup(ctx) or {}
                if d.after and FFT.contexts[d.after] then
                    for _,e in ipairs(FFT.cleanup(FFT.contexts[d.after])) do errors[#errors+1]=e end
                end
                currentSession=nil
                return errors
            elseif message.kind=='recordStop' then
                if recording then FFT.cleanup(recording) end
                recording,currentSession=nil,nil
                ui('recordStopped',true)
                return true
            end
            error('Unknown execution operation')
        end,debug.traceback)
        TriggerServerEvent('fft:reply',message.request,message.session,{ok=ok,value=ok and value or nil,error=not ok and value or nil})
    end)
end)
RegisterNetEvent('fft:cancel',function(session)
    if session~=currentSession then return end
    for _,ctx in pairs(FFT.contexts) do ctx.cancelled=true end
    if recording then CreateThread(function() FFT.cleanup(recording); recording=nil; currentSession=nil; ui('recordStopped',true) end) end
end)
AddEventHandler('onClientResourceStop',function(name)
    if name==GetCurrentResourceName() then
        SetNuiFocus(false,false)
        for _,ctx in pairs(FFT.contexts) do
            ctx.cancelled=true
            -- Resource-stop handlers cannot reliably yield: attempt synchronous cleanups.
            for i=#ctx.cleanups,1,-1 do pcall(ctx.cleanups[i]) end
        end
    end
end)

-- Programmatic character switches bypass the multichar spawn picker. Reveal the
-- live ped after its scene has been closed, and restore the tester's location.
RegisterNetEvent('fft:characterReady',function(position)
    CreateThread(function()
        local deadline=GetGameTimer()+5000
        while LocalPlayer.state['kora_core:loggedIn']~=true and GetGameTimer()<deadline do Wait(50) end
        local ped=PlayerPedId()
        if position then
            RequestCollisionAtCoord(position.x,position.y,position.z)
            SetEntityCoordsNoOffset(ped,position.x,position.y,position.z,false,false,false)
            SetEntityHeading(ped,position.heading or 0)
        end
        FreezeEntityPosition(ped,false)
        SetEntityVisible(ped,true,false)
        ShutdownLoadingScreen()
        ShutdownLoadingScreenNui()
        DoScreenFadeIn(300)
    end)
end)

RegisterCommand('fft_reveal',function()
    TriggerEvent('qb-multicharacter:client:closeNUI')
    TriggerEvent('fft:characterReady')
end,false)
