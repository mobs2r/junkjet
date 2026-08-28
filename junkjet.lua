TOOL.Name = "Junk Jet"
TOOL.Category = "Fun + Games"
TOOL.ClientConVar = {
    dissolve = "1",
    launchspeed = "1",
    firemode = "0",
    propscale = "1",
    dissolvespeed = "10",
    slipperymode = "0"
}

TOOL.Props = {
    "models/props_junk/watermelon01.mdl",
    "models/props_phx/oildrum001_explosive.mdl",
    "models/props_junk/TrafficCone001a.mdl",
    "models/maxofs2d/hover_rings.mdl",
    "models/props_junk/sawblade001a.mdl",
    "models/props_c17/FurnitureChair001a.mdl",
    "models/props_c17/oildrum001.mdl",
    "models/props_junk/wood_crate001a.mdl",
    "models/hunter/blocks/cube05x05x05.mdl",
    "models/props_wasteland/prison_toilet01.mdl",
    "models/props_c17/FurnitureRadiator001a.mdl",
    "models/props_lab/reciever01b.mdl",
    "models/props_interiors/Furniture_Lamp01a.mdl",
    "models/props_junk/propane_tank001a.mdl"
}

TOOL.Entities = {
    "sent_ball",
    "item_healthkit",
    "weapon_frag"
}

if SERVER then
    local playerData = {}

    hook.Add("PlayerInitialSpawn", "JunkJet_InitPlayerData", function(ply)
        playerData[ply] = {
            Props = {},
            Entities = {}
        }
    end)

    hook.Add("PlayerDisconnected", "JunkJet_CleanupPlayerData", function(ply)
        playerData[ply] = nil
    end)

    local function GetPlayerProps(ply)
        local data = playerData[ply]
        if data and #data.Props > 0 then
            return data.Props
        end
        return TOOL.Props
    end

    local function GetPlayerEntities(ply)
        local data = playerData[ply]
        if data and #data.Entities > 0 then
            return data.Entities
        end
        return TOOL.Entities
    end

    local function AddProp(ply, model)
        local data = playerData[ply]
        if not data then return end
        if not table.HasValue(data.Props, model) then
            table.insert(data.Props, model)
        end
    end

    local function RemoveProp(ply, model)
        local data = playerData[ply]
        if not data then return end
        for i, v in ipairs(data.Props) do
            if v == model then
                table.remove(data.Props, i)
                break
            end
        end
    end

    local function AddEntity(ply, class)
        local data = playerData[ply]
        if not data then return end
        if not table.HasValue(data.Entities, class) then
            table.insert(data.Entities, class)
        end
    end

    local function RemoveEntity(ply, class)
        local data = playerData[ply]
        if not data then return end
        for i, v in ipairs(data.Entities) do
            if v == class then
                table.remove(data.Entities, i)
                break
            end
        end
    end

    concommand.Add("junkjet_addprop", function(ply, cmd, args)
        if not IsValid(ply) or not args[1] then return end
        AddProp(ply, args[1])
        ply:ChatPrint(args[1] .. " added to your Junk Jet prop pool.")
    end)

    concommand.Add("junkjet_removeprop", function(ply, cmd, args)
        if not IsValid(ply) or not args[1] then return end
        RemoveProp(ply, args[1])
        ply:ChatPrint(args[1] .. " removed from your Junk Jet prop pool.")
    end)

    concommand.Add("junkjet_addentity", function(ply, cmd, args)
        if not IsValid(ply) or not args[1] then return end
        AddEntity(ply, args[1])
        ply:ChatPrint(args[1] .. " added to your Junk Jet entity pool.")
    end)

    concommand.Add("junkjet_removeentity", function(ply, cmd, args)
        if not IsValid(ply) or not args[1] then return end
        RemoveEntity(ply, args[1])
        ply:ChatPrint(args[1] .. " removed from your Junk Jet entity pool.")
    end)

    concommand.Add("junkjet_clearitems", function(ply, cmd, args)
        if not IsValid(ply) then return end
        local data = playerData[ply]
        if data then
            data.Props = {}
            data.Entities = {}
            ply:ChatPrint("Your Junk Jet pools have been cleared.")
        end
    end)
end

local function isEmptyTable(tbl)
    return next(tbl) == nil
end

function TOOL:LeftClick(trace)
    if CLIENT then return true end

    local owner = self:GetOwner()
    if not IsValid(owner) then return false end

    local props = SERVER and GetPlayerProps(owner) or TOOL.Props
    local entities = SERVER and GetPlayerEntities(owner) or TOOL.Entities

    local availableTypes = {}
    if not isEmptyTable(props) then table.insert(availableTypes, "prop") end
    if not isEmptyTable(entities) then table.insert(availableTypes, "entity") end

    if #availableTypes == 0 then
        owner:EmitSound("buttons/button8.wav")
        if CLIENT then
            notification.AddLegacy("No items left in the launch pool!", NOTIFY_ERROR, 5)
        end
        return true
    end

    local dropRates = { prop = 0.75, entity = 0.25 }
    local totalRate = 0
    for _, subType in ipairs(availableTypes) do
        totalRate = totalRate + dropRates[subType]
    end
    local choice = math.random() * totalRate
    local selectedType
    local cumulative = 0
    for _, subType in ipairs(availableTypes) do
        cumulative = cumulative + dropRates[subType]
        if choice <= cumulative then
            selectedType = subType
            break
        end
    end

    local entity
    local isSawblade = false

    if selectedType == "entity" then
        local entityClass = table.Random(entities)
        entity = ents.Create(entityClass)
    else
        local propModel = table.Random(props)
        if propModel == "models/props_junk/sawblade001a.mdl" then
            entity = ents.Create("sawblade_thrown")
            isSawblade = true
        else
            entity = ents.Create("prop_physics")
            entity:SetModel(propModel)
        end
    end

    if not IsValid(entity) then return false end

    entity:SetPos(owner:EyePos() + owner:GetAimVector() * 50)
    entity:SetAngles(owner:EyeAngles())

    if selectedType == "prop" and not isSawblade then
        local scaleValue = 1 + (self:GetClientNumber("propscale") / 20)
        entity:SetModelScale(scaleValue, 0)
    end

    entity:Spawn()

    if isSawblade then
        local phys = entity:GetPhysicsObject()
        if IsValid(phys) then
            local launchSpeed = 3000 + (self:GetClientNumber("launchspeed") * 10000)
            phys:SetVelocity(owner:GetAimVector() * launchSpeed)
            phys:AddAngleVelocity(Vector(0, 5000, 0))
        end
    else
        local phys = entity:GetPhysicsObject()
        if IsValid(phys) then
            local launchSpeed = 3000 + (self:GetClientNumber("launchspeed") * 10000)
            local aimVector = owner:GetAimVector()
            local randomVector = Vector(math.Rand(-0.1, 0.1), math.Rand(-0.1, 0.1), math.Rand(0, 0.2))
            phys:ApplyForceCenter((aimVector + randomVector) * launchSpeed)

            if self:GetClientNumber("firemode") == 1 then
                entity:Ignite(30)
            end

            if self:GetClientNumber("slipperymode") == 1 then
                phys:SetMaterial("ice")
            end
        end
    end

    if self:GetClientNumber("firemode") == 1 and isSawblade then
        entity:Ignite(30)
    end

    undo.Create("Junk Jet")
    undo.AddEntity(entity)
    undo.SetPlayer(owner)
    undo.Finish()

    local dissolve = self:GetClientNumber("dissolve") == 1
    local dissolveSpeed = self:GetClientNumber("dissolvespeed")
    timer.Simple(dissolveSpeed, function()
        if IsValid(entity) and dissolve then
            entity:Dissolve()
        end
    end)

    return true
end

function TOOL:RightClick(trace)
    if CLIENT then return true end

    local owner = self:GetOwner()
    if not IsValid(owner) then return false end

    if IsValid(trace.Entity) then
        local phys = trace.Entity:GetPhysicsObject()
        if IsValid(phys) then
            local model = trace.Entity:GetModel()
            local class = trace.Entity:GetClass()

            if class == "prop_physics" or class == "sawblade_thrown" then
                local props = SERVER and GetPlayerProps(owner) or TOOL.Props
                local propModel = model
                if class == "sawblade_thrown" then
                    propModel = "models/props_junk/sawblade001a.mdl"
                end
                if table.HasValue(props, propModel) then
                    if SERVER then RemoveProp(owner, propModel) end
                    owner:ChatPrint(propModel .. " removed from your Junk Jet prop pool.")
                else
                    if SERVER then AddProp(owner, propModel) end
                    owner:ChatPrint(propModel .. " added to your Junk Jet prop pool.")
                end
            else
                local entities = SERVER and GetPlayerEntities(owner) or TOOL.Entities
                if table.HasValue(entities, class) then
                    if SERVER then RemoveEntity(owner, class) end
                    owner:ChatPrint(class .. " removed from your Junk Jet entity pool.")
                else
                    if SERVER then AddEntity(owner, class) end
                    owner:ChatPrint(class .. " added to your Junk Jet entity pool.")
                end
            end
        end
    end

    return true
end

if CLIENT then
    language.Add("tool.junkjet.name", "Junk Jet")
    language.Add("tool.junkjet.desc", "Launch junk at high speed!")
    language.Add("tool.junkjet.0", "M1: Fires junk... | M2: Scans junk...")

    function TOOL.BuildCPanel(panel)
        panel:AddControl("Header", {
            Text = "Junk Jet",
            Description = "Launch junk at high speed!"
        })

        panel:AddControl("CheckBox", {
            Label = "Fire Mode",
            Command = "junkjet_firemode"
        })

        panel:AddControl("CheckBox", {
            Label = "Slippery Mode",
            Command = "junkjet_slipperymode"
        })

        panel:AddControl("CheckBox", {
            Label = "Dissolve Mode",
            Command = "junkjet_dissolve",
            Default = "1"
        })

        panel:AddControl("Slider", {
            Label = "Launch Speed",
            Command = "junkjet_launchspeed",
            Type = "Float",
            Min = "1",
            Max = "100",
            Default = "1"
        })

        panel:AddControl("Slider", {
            Label = "Prop Scaling",
            Command = "junkjet_propscale",
            Type = "Float",
            Min = "1",
            Max = "100",
            Default = "1"
        })

        panel:AddControl("Slider", {
            Label = "Dissolve Speed",
            Command = "junkjet_dissolvespeed",
            Type = "Float",
            Min = "1",
            Max = "100",
            Default = "10"
        })

        panel:AddControl("Button", {
            Label = "Clear Items",
            Command = "junkjet_clearitems"
        })
    end
end
