local server = FFT.realm == 'server'
local native = {}
local function point(v) return {x=v.x,y=v.y,z=v.z} end
if server then
    native['player.position'] = function(ctx) return point(GetEntityCoords(GetPlayerPed(ctx.tester))) end
else
    native['player.position'] = function() return point(GetEntityCoords(PlayerPedId())) end
    native['player.alive'] = function() return not IsEntityDead(PlayerPedId()) end
    native['player.onFoot'] = function() return IsPedOnFoot(PlayerPedId()) end
    native['player.heading'] = function() return GetEntityHeading(PlayerPedId()) end
    native['player.armour'] = function() return GetPedArmour(PlayerPedId()) end
    native['player.setArmour'] = function(ctx, value)
        assert(value >= 0 and value <= 100, 'Armour must be 0–100')
        local ped, original = PlayerPedId(), GetPedArmour(PlayerPedId())
        ctx:cleanup(function() SetPedArmour(ped,original) end)
        SetPedArmour(ped,value)
    end
    native['player.setHeading'] = function(ctx, value)
        assert(value >= 0 and value < 360, 'Heading must be 0–359')
        local ped, original = PlayerPedId(), GetEntityHeading(PlayerPedId())
        ctx:cleanup(function() SetEntityHeading(ped,original) end)
        SetEntityHeading(ped,value+0.0)
    end
    native['player.health'] = function() return GetEntityHealth(PlayerPedId()) end
    native['player.maxHealth'] = function() return GetEntityMaxHealth(PlayerPedId()) end
    native['player.setHealth'] = function(ctx, value)
        local ped=PlayerPedId()
        local maximum=GetEntityMaxHealth(ped)
        assert(value>100 and value<=maximum,'Health must be above 100 and at most '..maximum)
        local original=GetEntityHealth(ped)
        ctx:cleanup(function() SetEntityHealth(ped,original) end)
        SetEntityHealth(ped,value)
    end
    native['player.modelValid'] = function()
        local model=GetEntityModel(PlayerPedId())
        return model~=0 and IsModelValid(model)
    end
    native['camera.heading'] = function() return GetGameplayCamRelativeHeading() end
    native['camera.setHeading'] = function(ctx, value)
        assert(value>=-180 and value<=180,'Camera heading must be -180 to 180')
        local original=GetGameplayCamRelativeHeading()
        ctx:cleanup(function() SetGameplayCamRelativeHeading(original) end)
        SetGameplayCamRelativeHeading(value+0.0)
    end
    native['entity.nearby'] = function(ctx, model, coords, radius)
        local hash = type(model)=='number' and model or GetHashKey(model)
        local entity = GetClosestObjectOfType(coords.x,coords.y,coords.z,radius or 2.0,hash,false,false,false)
        return entity ~= 0 and entity or nil
    end
    native['fixture.approach'] = function(ctx)
        local f = ctx.fixture
        local ped = PlayerPedId()
        assert(not IsPedInAnyVehicle(ped,false), 'Leave the vehicle before running this fixture')
        local original, heading = GetEntityCoords(ped), GetEntityHeading(ped)
        local camHeading,camPitch = GetGameplayCamRelativeHeading(),GetGameplayCamRelativePitch()
        ctx:cleanup(function()
            SetEntityCoordsNoOffset(ped,original.x,original.y,original.z,false,false,false)
            SetEntityHeading(ped,heading)
            SetGameplayCamRelativeHeading(camHeading); SetGameplayCamRelativePitch(camPitch,1.0)
        end)
        if not f then
            local function discover()
                local best, distance = nil, math.huge
                local here = GetEntityCoords(ped)
                for _, entity in ipairs(GetGamePool('CObject')) do
                    local model = GetEntityModel(entity)
                    if model == GetHashKey('prop_vend_soda_01') or model == GetHashKey('prop_vend_soda_02') then
                        local coords = GetEntityCoords(entity)
                        local d = #(coords-here)
                        if d < distance then best, distance = entity, d end
                    end
                end
                return best
            end
            local machine = discover()
            if not machine then
                local seed = FFTConfig.vendingSearch
                SetEntityCoordsNoOffset(ped,seed.x,seed.y,seed.z,false,false,false)
                machine = ctx:waitUntil(function()
                    RequestCollisionAtCoord(seed.x,seed.y,seed.z)
                    return discover()
                end,'No soda prop found. Capture a fixture in Record near a machine, or change vendingSearch.',10000)
            end
            local coords = GetEntityCoords(machine)
            local approach = GetOffsetFromEntityInWorldCoords(machine,0.0,-1.0,0.0)
            -- Prop origins may sit below the pavement; resolve the standing height.
            RequestCollisionAtCoord(approach.x,approach.y,coords.z)
            local grounded, ground = GetGroundZFor_3dCoord(approach.x,approach.y,coords.z+2.0,false)
            approach = {x=approach.x,y=approach.y,z=grounded and ground+0.05 or coords.z}
            approach.heading = GetHeadingFromVector_2d(coords.x-approach.x,coords.y-approach.y)
            f = {model=GetEntityModel(machine),coords=point(coords),approach=approach,camera={heading=0,pitch=0}}
            ctx.fixture = f
        end
        SetEntityCoordsNoOffset(ped,f.approach.x,f.approach.y,f.approach.z,false,false,false)
        SetEntityHeading(ped,f.approach.heading or 0)
        if f.camera then
            SetGameplayCamRelativeHeading(f.camera.heading or 0)
            SetGameplayCamRelativePitch(f.camera.pitch or 0,1.0)
        end
        RequestCollisionAtCoord(f.coords.x,f.coords.y,f.coords.z)
        ctx.state.machine = ctx:waitUntil(function()
            return native['entity.nearby'](ctx,f.model,f.coords,1.5)
        end,'Configured vending machine did not stream in')
    end
end
local function recordNative(ctx,emit)
    if server then return end
    CreateThread(function()
        local last=GetEntityCoords(PlayerPedId())
        emit('note',{observation='player.position',coords=point(last)},'client')
        while not ctx.cancelled do
            Wait(1000)
            local current=GetEntityCoords(PlayerPedId())
            if not ctx.cancelled and #(current-last)>1.0 then
                emit('note',{observation='player.position',coords=point(current)},'client')
                last=current
            end
        end
    end)
end
FFT.registerAdapter('native',{ operations=native, record=recordNative })

local kora = {}
local function koraPreflight()
    for _,name in ipairs({'kora_core','kora_target','kora_inventory'}) do
        assert(GetResourceState(name)=='started', 'Start '..name..' before using the Kora adapter')
    end
    if not server then
        -- A missing export raises; report which hook is absent instead.
        local function version(resource)
            local ok,value=pcall(function() return exports[resource]:fftVersion() end)
            return ok and value or nil
        end
        assert(version('kora_target')==3,'Install Kora target test hooks v3 (setr fft_kora_hooks true, restart kora_target)')
        assert(version('kora_inventory')==1,'Install Kora inventory test hooks v1 (setr fft_kora_hooks true, restart kora_inventory)')
        assert(version('kora_lib')==2,'Install kora_lib test hooks v2 (setr fft_kora_hooks true, restart kora_lib)')
    end
end
if server then
    local function count(ctx,item)
        local player = assert(exports.kora_core:getPlayer(ctx.tester),'Kora character is not loaded')
        local data = player.PlayerData or player
        local n=0
        for _,entry in pairs(data.items or {}) do if entry.name==item then n=n+(entry.amount or 0) end end
        return n
    end
    kora['inventory.count']=count
    kora['inventory.empty']=function(ctx)
        local data=assert(exports.kora_core:getPlayer(ctx.tester),'Kora character is not loaded')
        for _,entry in pairs(data.items or {}) do
            if entry and (entry.amount or 0)>0 then error('Test inventory contains '..tostring(entry.name)) end
        end
    end
    kora['inventory.canCarry']=function(ctx,item,amount)
        local ok,reason=exports.kora_core:canCarry(ctx.tester,item,amount)
        assert(ok,reason or 'Cannot carry '..item)
    end
    kora['inventory.add']=function(ctx,item,amount)
        assert(amount>0 and amount<=20,'Grant amount must be 1–20')
        local ok,reason=exports.kora_core:addItem(ctx.tester,item,amount,nil,nil,'functional test')
        assert(ok,reason or 'Could not grant '..item)
        ctx:cleanup(function() exports.kora_core:removeItem(ctx.tester,item,amount,nil,'functional test cleanup') end)
    end
    kora['inventory.remove']=function(ctx,item,amount)
        assert(amount>0 and amount<=20,'Remove amount must be 1–20')
        local ok,reason=exports.kora_core:removeItem(ctx.tester,item,amount,nil,'functional test')
        assert(ok,reason or 'Could not remove '..item)
    end
    kora['money.account']=function(ctx,account)
        assert(account=='cash' or account=='bank','Only cash and bank are supported')
        return assert(exports.kora_core:getMoney(ctx.tester,account),account..' account unavailable')
    end
    kora['money.set']=function(ctx,account,amount)
        assert((account=='cash' or account=='bank') and amount>=0 and amount<=10000,'Invalid test balance')
        local original=kora['money.account'](ctx,account)
        local ok,reason=exports.kora_core:setMoney(ctx.tester,account,amount,'functional test')
        assert(ok,reason or 'Could not set '..account)
        ctx:cleanup(function() exports.kora_core:setMoney(ctx.tester,account,original,'functional test cleanup') end)
    end
    kora['money.seeded']=function(ctx)
        for account,expected in pairs(FFTConfig.testCharacter or {}) do
            ctx:equal(kora['money.account'](ctx,account),expected,account..' seed balance')
        end
    end
    kora['money.balance']=function(ctx) return kora['money.account'](ctx,'cash') end
    kora['purchase.prepare']=function(ctx,amount,item)
        assert(amount>0 and amount%1==0 and amount<=50,'Quantity must be 1–50')
        ctx.state.item,ctx.state.count,ctx.state.cash=item,count(ctx,item),kora['money.balance'](ctx)
        local price=({soda=5,water_bottle=4})[item]
        assert(price,'No configured vending price for '..item)
        assert(ctx.state.cash>=amount*price,'Insufficient cash for '..item)
        local can,reason=exports.kora_core:canCarry(ctx.tester,item,amount)
        assert(can,reason or 'Insufficient inventory capacity')
        ctx.state.purchases={}
        ctx:on('kora_inventory:server:itemPurchased',function(src,data)
            if src==ctx.tester and data.shopId=='vendingmachine' and data.itemName==item then
                ctx.state.purchases[#ctx.state.purchases+1]=data
            end
        end)
    end
    kora['purchase.assertItem']=function(ctx,amount,item)
        assert(ctx.state.item==item,'Missing purchase baseline for '..item)
        ctx:waitUntil(function() return #ctx.state.purchases>0 end,'No server purchase confirmation')
        local purchased=0
        for _,p in ipairs(ctx.state.purchases) do purchased=purchased+p.count end
        ctx:equal(purchased,amount,'Confirmed purchase quantity')
        ctx:equal(count(ctx,item)-ctx.state.count,amount,'Inventory delta')
    end
    kora['purchase.assertCash']=function(ctx,amount)
        assert(ctx.state.cash,'Missing cash baseline')
        ctx:equal(ctx.state.cash-kora['money.balance'](ctx),amount,'Cash delta')
    end
    kora.record = function(ctx,emit)
        ctx:on('kora_inventory:server:sessionOpened',function(src,payload)
            if src==ctx.tester then emit('shop.opened',{secondary=payload.secondary and payload.secondary.id},'server') end
        end)
        ctx:on('kora_inventory:server:itemPurchased',function(src,data)
            if src==ctx.tester then
                emit('purchase.confirmed',{shopId=data.shopId,itemName=data.itemName,count=data.count,price=data.price},'server')
            end
        end)
    end
else
    kora['target.select']=function(ctx,label)
        -- Shared with the generic targeting steps in steps/kora.lua.
        FFT.kora.target(ctx,label,ctx.state.machine)
        ctx.state.openedShop=true
        ctx:cleanup(function() exports.kora_inventory:closeInventory() end)
        ctx:waitUntil(function()
            local s=exports.kora_inventory:getCurrentSession()
            return s and s.secondary and s.secondary.type=='shop'
        end,'Shop UI did not open')
    end
    kora['ui.buy']=function(ctx,amount,item)
        assert(amount>0 and amount%1==0 and amount<=50,'Quantity must be 1–50')
        for i=1,amount do
            ctx:check()
            ctx:waitUntil(function()
                local ok,err=exports.kora_inventory:fftAction('dragBuy',item,1)
                if ok then return true end
                if err and err:find('No active shop session',1,true) then return false end
                error(err or 'Could not drag shop item into player inventory')
            end,'Shop UI did not become ready for dragging '..item)
            if i<amount then Wait(250) end
        end
    end
    kora.record = function(ctx,emit)
        recordNative(ctx,emit)
        ctx:on('fft:kora:target',function(data) emit('target.selected',data,'client') end)
        ctx:on('fft:kora:inventory',function(data) emit('ui.'..tostring(data.action),data,'client') end)
    end
end
FFT.registerAdapter('kora',{extends='native',operations=kora,preflight=koraPreflight,record=kora.record})
