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

TOOL.PlayerData = {}

function TOOL:GetPlayerProps(ply)
    local data = self.PlayerData[ply]
    if data and data.Props and #data.Props > 0 then
        return data.Props
    end
    return self.Props
end

function TOOL:GetPlayerEntities(ply)
    local data = self.PlayerData[ply]
    if data and data.Entities and #data.Entities > 0 then
        return data.Entities
    end
    return self.Entities
end

function TOOL:AddProp(ply, model)
    local data = self.PlayerData[ply]
    if not data then
        data = { Props = {}, Entities = {} }
        self.PlayerData[ply] = data
    end
    if not table.HasValue(data.Props, model) then
        table.insert(data.Props, model)
    end
end

function TOOL:RemoveProp(ply, model)
    local data = self.PlayerData[ply]
    if not data then return end
    for i, v in ipairs(data.Props) do
        if v == model then
            table.remove(data.Props, i)
            break
        end
    end
end

function TOOL:AddEntity(ply, class)
    local data = self.PlayerData[ply]
    if not data then
        data = { Props = {}, Entities = {} }
        self.PlayerData[ply] = data
    end
    if not table.HasValue(data.Entities, class) then
        table.insert(data.Entities, class)
    end
end

function TOOL:RemoveEntity(ply, class)
    local data = self.PlayerData[ply]
    if not data then return end
    for i, v in ipairs(data.Entities) do
        if v == class then
            table.remove(data.Entities, i)
            break
        end
    end
end

if SERVER then
    concommand.Add("junkjet_addprop", function(ply, cmd, args)
        if not IsValid(ply) or not args[1] then return end
        local tool = ply:GetTool("junkjet")
        if tool then
            tool:AddProp(ply, args[1])
            ply:ChatPrint(args[1] .. " added to your Junk Jet prop pool.")
        end
    end)

    concommand.Add("junkjet_removeprop", function(ply, cmd, args)
        if not IsValid(ply) or not args[1] then return end
        local tool = ply:GetTool("junkjet")
        if tool then
            tool:RemoveProp(ply, args[1])
            ply:ChatPrint(args[1] .. " removed from your Junk Jet prop pool.")
        end
    end)

    concommand.Add("junkjet_addentity", function(ply, cmd, args)
        if not IsValid(ply) or not args[1] then return end
        local tool = ply:GetTool("junkjet")
        if tool then
            tool:AddEntity(ply, args[1])
            ply:ChatPrint(args[1] .. " added to your Junk Jet entity pool.")
        end
    end)

    concommand.Add("junkjet_removeentity", function(ply, cmd, args)
        if not IsValid(ply) or not args[1] then return end
        local tool = ply:GetTool("junkjet")
        if tool then
            tool:RemoveEntity(ply, args[1])
            ply:ChatPrint(args[1] .. " removed from your Junk Jet entity pool.")
        end
    end)

    concommand.Add("junkjet_clearitems", function(ply, cmd, args)
        if not IsValid(ply) then return end
        local tool = ply:GetTool("junkjet")
        if tool then
            tool.PlayerData[ply] = { Props = {}, Entities = {} }
            ply:ChatPrint("Your Junk Jet pools have been cleared.")
        end
    end)
end

function TOOL:LeftClick(trace)
    if CLIENT then return true end

    local owner = self:GetOwner()
    if not IsValid(owner) then return false end

    local props = self:GetPlayerProps(owner)
    local entities = self:GetPlayerEntities(owner)

    if #props == 0 and #entities == 0 then
        owner:EmitSound("buttons/button8.wav")
        if CLIENT then
            notification.AddLegacy("No items left in the launch pool!", NOTIFY_ERROR, 5)
        end
        return true
    end

    local availableTypes = {}
    if #props > 0 then table.insert(availableTypes, "prop") end
    if #entities > 0 then table.insert(availableTypes, "entity") end

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
        entity = ents.Create("prop_physics")
        entity:SetModel(propModel)
        if propModel == "models/props_junk/sawblade001a.mdl" then
            isSawblade = true
        end
    end

    if not IsValid(entity) then return false end

    entity:SetPos(owner:EyePos() + owner:GetAimVector() * 50)
    entity:SetAngles(owner:EyeAngles())

    if selectedType == "prop" then
        local scaleValue = 1 + (self:GetClientNumber("propscale") / 20)
        entity:SetModelScale(scaleValue, 0)
    end

    entity:Spawn()

    local phys = entity:GetPhysicsObject()
    if IsValid(phys) then
        local launchSpeed = 3000 + (self:GetClientNumber("launchspeed") * 10000)
        local aimVector = owner:GetAimVector()
        if isSawblade then
            phys:SetVelocity(aimVector * launchSpeed)
            phys:AddAngleVelocity(Vector(0, 5000, 0))
        else
            local randomVector = Vector(math.Rand(-0.1, 0.1), math.Rand(-0.1, 0.1), math.Rand(0, 0.2))
            phys:ApplyForceCenter((aimVector + randomVector) * launchSpeed)
        end

        if self:GetClientNumber("firemode") == 1 then
            entity:Ignite(30)
        end

        if self:GetClientNumber("slipperymode") == 1 then
            phys:SetMaterial("ice")
        end
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

            if class == "prop_physics" then
                local props = self:GetPlayerProps(owner)
                if table.HasValue(props, model) then
                    self:RemoveProp(owner, model)
                    owner:ChatPrint(model .. " removed from your Junk Jet prop pool.")
                else
                    self:AddProp(owner, model)
                    owner:ChatPrint(model .. " added to your Junk Jet prop pool.")
                end
            else
                local entities = self:GetPlayerEntities(owner)
                if table.HasValue(entities, class) then
                    self:RemoveEntity(owner, class)
                    owner:ChatPrint(class .. " removed from your Junk Jet entity pool.")
                else
                    self:AddEntity(owner, class)
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
