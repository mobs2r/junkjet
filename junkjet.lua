TOOL.Name = "Junk Jet"
TOOL.Category = "Fun + Games"
TOOL.ClientConVar["dissolve"] = "1"
TOOL.ClientConVar["launchspeed"] = "1"
TOOL.ClientConVar["firemode"] = "0"
TOOL.ClientConVar["propscale"] = "1"
TOOL.ClientConVar["dissolvespeed"] = "10"
TOOL.ClientConVar["slipperymode"] = "0"

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
    ["bouncyball"] = "sent_ball",
    ["healthkit"] = "item_healthkit",
    ["weapon_frag"] = "weapon_frag"
}

local function isEmptyTable(tbl)
    return next(tbl) == nil
end

local function launchSawBlade(self, ply)
    local entity = ents.Create("prop_physics")
    entity:SetModel("models/props_junk/sawblade001a.mdl")
    entity:SetMoveType(MOVETYPE_VPHYSICS)
    entity:SetCollisionGroup(COLLISION_GROUP_NONE)
    entity:SetPos(ply:EyePos() + (ply:GetAimVector() * 50))
    entity:SetAngles(ply:EyeAngles())
    entity:Spawn()

    local phys = entity:GetPhysicsObject()
    if IsValid(phys) then
        local launchSpeed = 3000 + (self:GetClientNumber("launchspeed") * 10000)
        phys:ApplyForceCenter(ply:GetAimVector() * launchSpeed)
        phys:AddAngleVelocity(Vector(0, 5000, 0))
    end

    return entity
end

concommand.Add("junkjet_addprop", function(ply, cmd, args)
    local prop = args[1]
    if not prop then return end
    local tool = ply:GetTool("junkjet")
    if tool then
        table.insert(tool.Props, prop)
        ply:ChatPrint(prop .. " added to Junk Jet prop pool.")
    end
end)

concommand.Add("junkjet_removeprop", function(ply, cmd, args)
    local prop = args[1]
    if not prop then return end
    local tool = ply:GetTool("junkjet")
    if tool then
        for i, v in ipairs(tool.Props) do
            if v == prop then
                table.remove(tool.Props, i)
                ply:ChatPrint(prop .. " removed from Junk Jet prop pool.")
                break
            end
        end
    end
end)

concommand.Add("junkjet_clearitems", function(ply, cmd, args)
    local tool = ply:GetTool("junkjet")
    if tool then
        tool.Props = {}
        tool.Entities = {}
        ply:ChatPrint("All props and entities removed from Junk Jet pool.")
    end
end)

function TOOL:LeftClick(trace)
    if CLIENT then return true end
    local availableTypes = {}
    if not isEmptyTable(self.Props) then table.insert(availableTypes, "prop") end
    if not isEmptyTable(self.Entities) then table.insert(availableTypes, "entity") end
    if #availableTypes == 0 then
        self:GetOwner():EmitSound("buttons/button8.wav")
        if CLIENT then
            notification.AddLegacy("No items left in the launch pool!", NOTIFY_ERROR, 5)
        end
        return true
    end
    local dropRates = {prop = 0.75, entity = 0.25}
    local adjustedDropRates = {}
    for _, subType in ipairs(availableTypes) do
        adjustedDropRates[subType] = dropRates[subType]
    end
    local totalRate = 0
    for _, rate in pairs(adjustedDropRates) do totalRate = totalRate + rate end
    for subType, rate in pairs(adjustedDropRates) do
        adjustedDropRates[subType] = rate / totalRate
    end
    local choice = math.random()
    local cumulativeRate = 0
    local selectedType
    for subType, rate in pairs(adjustedDropRates) do
        cumulativeRate = cumulativeRate + rate
        if choice <= cumulativeRate then
            selectedType = subType
            break
        end
    end
    local entity
    if selectedType == "entity" then
        local entityClass = self.Entities[table.Random(table.GetKeys(self.Entities))]
        entity = ents.Create(entityClass)
    else
        local propModel = table.Random(self.Props)
        if propModel == "models/props_junk/sawblade001a.mdl" then
            entity = launchSawBlade(self, self:GetOwner())
        else
            entity = ents.Create("prop_physics")
            entity:SetModel(propModel)
        end
    end
    if not IsValid(entity) then return false end
    entity:SetPos(self:GetOwner():EyePos() + (self:GetOwner():GetAimVector() * 50))
    entity:SetAngles(self:GetOwner():EyeAngles())
    entity:Spawn()
    local phys = entity:GetPhysicsObject()
    if IsValid(phys) then
        local launchSpeed = 3000 + (self:GetClientNumber("launchspeed") * 10000)
        if entity:GetModel() ~= "models/props_junk/sawblade001a.mdl" then
            local randomVector = Vector(math.Rand(-0.1, 0.1), math.Rand(-0.1, 0.1), math.Rand(0, 0.2))
            phys:ApplyForceCenter((self:GetOwner():GetAimVector() + randomVector) * launchSpeed)
        else
            phys:ApplyForceCenter(self:GetOwner():GetAimVector() * launchSpeed)
        end
        local scaleValue = 1 + (self:GetClientNumber("propscale") / 20)
        entity:SetModelScale(scaleValue, 0)
        if self:GetClientNumber("firemode") == 1 then entity:Ignite(30) end
        if self:GetClientNumber("slipperymode") == 1 then phys:SetMaterial("ice") end
    end
    undo.Create("Junk Jet")
    undo.AddEntity(entity)
    undo.SetPlayer(self:GetOwner())
    undo.Finish()
    local dissolve = self:GetClientNumber("dissolve") == 1
    local dissolveSpeed = self:GetClientNumber("dissolvespeed")
    timer.Simple(dissolveSpeed, function()
        if not IsValid(entity) then return end
        if dissolve then entity:Dissolve() end
    end)
    return true
end

function TOOL:RightClick(trace)
    if CLIENT then return true end
    if IsValid(trace.Entity) and trace.Entity:GetPhysicsObject():IsValid() then
        local model = trace.Entity:GetModel()
        local class = trace.Entity:GetClass()
        local tool = self:GetOwner():GetTool("junkjet")
        if class == "prop_physics" then
            if table.HasValue(tool.Props, model) then
                table.RemoveByValue(tool.Props, model)
                self:GetOwner():ChatPrint(model .. " removed from Junk Jet prop pool.")
            else
                table.insert(tool.Props, model)
                self:GetOwner():ChatPrint(model .. " added to Junk Jet prop pool.")
            end
        else
            if table.HasValue(tool.Entities, class) then
                table.RemoveByValue(tool.Entities, class)
                self:GetOwner():ChatPrint(class .. " removed from Junk Jet entity pool.")
            else
                table.insert(tool.Entities, class)
                self:GetOwner():ChatPrint(class .. " added to Junk Jet entity pool.")
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
        panel:AddControl("Header", {Text = "Junk Jet", Description = "Launch junk at high speed!"})

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