if SERVER then
    AddCSLuaFile("junkjet/core.lua")
    AddCSLuaFile("junkjet/client.lua")
end
local Core = include("junkjet/core.lua")
TOOL.Name = "#tool.junkjet.name"
TOOL.Category = "Fun + Games"
TOOL.ClientConVar = {dissolve = "1", launchspeed = "1", firemode = "0", propscale = "1",
    dissolvespeed = "10", slipperymode = "0", spread = "0", mode = "random"}
TOOL.Information = {{name = "left"}, {name = "right"}, {name = "reload"}}
cleanup.Register("junkjet")
if CLIENT then
    function TOOL:LeftClick() return true end
    function TOOL:RightClick() return true end
    function TOOL:Reload() return true end
    include("junkjet/client.lua")
    return
end
util.AddNetworkString("junkjet_pool")
local Sawblade = include("junkjet/sawblade.lua")
local limit = CreateConVar("sbox_maxjunkjet", "40", FCVAR_ARCHIVE, "Maximum live Junk Jet objects per player", 0, 200)
local cooldown = CreateConVar("junkjet_cooldown", "0.2", FCVAR_ARCHIVE, "Minimum seconds between launches", 0.1, 5)
local states = setmetatable({}, {__mode = "k"})
local function tell(ply, message) ply:ChatPrint("[Junk Jet] " .. message) end
local function validProp(model)
    return Core.ValidModelPath(model) and util.IsValidModel(model) and util.IsValidProp(model)
end
local function defaults() return {Props = Core.Clean(Core.DefaultProps, validProp), Entities = {}} end
local function path(ply)
    local id = ply:SteamID64()
    if ply:IsBot() or not id or not id:match("^%d+$") then return nil end
    return "junkjet/" .. id .. ".json"
end
local function state(ply)
    if states[ply] then return states[ply] end
    local data, filename = defaults(), path(ply)
    local raw = filename and file.Read(filename, "DATA")
    local saved = raw and #raw <= 65536 and util.JSONToTable(raw)
    if istable(saved) and saved.Version == 1 and istable(saved.Props) and istable(saved.Entities) then
        data = {Props = Core.Clean(saved.Props, Core.ValidModelPath),
            Entities = Core.Clean(saved.Entities, function(v) return Core.EntityModels[v] ~= nil end)}
    end
    data.Live = {}
    states[ply] = data
    return data
end
local function sync(ply)
    local data = state(ply)
    net.Start("junkjet_pool")
    for _, key in ipairs({"Props", "Entities"}) do
        net.WriteUInt(#data[key], 8)
        for _, value in ipairs(data[key]) do net.WriteString(value) end
    end
    net.Send(ply)
end
local function save(ply)
    local data, filename = state(ply), path(ply)
    if filename then
        file.CreateDir("junkjet")
        file.Write(filename, util.TableToJSON({Version = 1, Props = data.Props, Entities = data.Entities}, true))
    end
    sync(ply)
end
local function edit(ply, kind, value, remove)
    value = Core.Normalize(value)
    if not value then tell(ply, "Enter a model path or entity class.") return end
    if not remove and not (kind == "Props" and validProp(value) or kind == "Entities" and Core.EntityModels[value]) then
        tell(ply, "Unavailable physics model or unsupported entity. Supported: sent_ball, item_healthkit, item_battery.")
        return
    end
    local ok, reason = Core.Edit(state(ply)[kind], value, remove)
    if not ok then tell(ply, reason) return end
    save(ply)
    tell(ply, (remove and "Removed " or "Added ") .. value)
end
local function command(name, callback)
    concommand.Add("junkjet_" .. name, function(ply, _, args)
        if not IsValid(ply) then return end
        local data = state(ply)
        if CurTime() < (data.NextCommand or 0) then return end
        data.NextCommand = CurTime() + 0.1
        callback(ply, args)
    end)
end
for _, definition in ipairs({{"addprop", "Props", false}, {"removeprop", "Props", true},
    {"addentity", "Entities", false}, {"removeentity", "Entities", true}}) do
    local name, kind, remove = unpack(definition)
    command(name, function(ply, args) edit(ply, kind, args[1], remove) end)
end
command("clearitems", function(ply)
    local data = state(ply)
    data.Props, data.Entities = {}, {}
    save(ply)
    tell(ply, "Pool emptied. Add items or restore defaults to launch again.")
end)
command("resetitems", function(ply)
    local data, fresh = state(ply), defaults()
    data.Props, data.Entities = fresh.Props, fresh.Entities
    save(ply)
    tell(ply, "Restored " .. #data.Props .. " available base-game props.")
end)
command("requestpool", sync)
command("listitems", function(ply)
    local data = state(ply)
    tell(ply, #data.Props .. " props, " .. #data.Entities .. " entities. See console.")
    ply:PrintMessage(HUD_PRINTCONSOLE, table.concat(data.Props, "\n") .. "\n" .. table.concat(data.Entities, "\n"))
end)
command("cleanup", function(ply)
    for ent in pairs(state(ply).Live) do if IsValid(ent) then ent:Remove() end end
    state(ply).Live = {}
    tell(ply, "Removed your launched objects.")
end)
command("diagnose", function(ply)
    local failures = 0
    for _, model in ipairs(Core.DefaultProps) do
        local ok = validProp(model)
        if not ok then failures = failures + 1 end
        ply:PrintMessage(HUD_PRINTCONSOLE, (ok and "OK " or "MISSING/INVALID ") .. model .. "\n")
    end
    tell(ply, "Default model audit: " .. failures .. " unavailable. Sawblades use native prop_physics launch interactions. Details in console.")
end)
function TOOL:Reload()
    local ply = self:GetOwner()
    if not IsValid(ply) then return false end
    local data = state(ply)
    if CurTime() < (data.NextReload or 0) then return false end
    data.NextReload = CurTime() + 0.5
    sync(ply)
    ply:ConCommand("junkjet_menu")
    return true
end
function TOOL:RightClick(trace)
    local ply, ent = self:GetOwner(), trace.Entity
    if not IsValid(ply) or not IsValid(ent) or ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot() then return false end
    local data = state(ply)
    if CurTime() < (data.NextScan or 0) then return false end
    data.NextScan = CurTime() + 0.25
    local class = ent:GetClass()
    local prop = class == "prop_physics" or class == "prop_physics_multiplayer"
    local kind, value = prop and "Props" or "Entities", Core.Normalize(prop and ent:GetModel() or class)
    edit(ply, kind, value, Core.Index(data[kind], value) ~= nil)
    return true
end
local function expire(ent, seconds)
    timer.Simple(seconds, function()
        if not IsValid(ent) then return end
        local dissolver = ents.Create("env_entity_dissolver")
        if IsValid(dissolver) then
            local target = "junkjet_" .. ent:EntIndex() .. "_" .. math.floor(SysTime() * 1000)
            ent:SetName(target)
            dissolver:SetKeyValue("dissolvetype", "0")
            dissolver:Spawn()
            dissolver:Fire("Dissolve", target, 0)
            SafeRemoveEntityDelayed(dissolver, 1)
        end
        SafeRemoveEntityDelayed(ent, 2)
    end)
end
function TOOL:LeftClick()
    local ply = self:GetOwner()
    if not IsValid(ply) or not ply:Alive() then return false end
    local data = state(ply)
    if CurTime() < (data.NextShot or 0) then return false end
    data.NextShot = CurTime() + cooldown:GetFloat()
    local count = 0
    for ent in pairs(data.Live) do
        if IsValid(ent) then count = count + 1 else data.Live[ent] = nil end
    end
    if count >= limit:GetInt() then tell(ply, "Live object limit reached. Undo or clean up your launches.") return false end
    local mode, candidates = self:GetClientInfo("mode"), {}
    if mode == "sawblade" then
        if validProp(Core.SawModel) then candidates[1] = {kind = "Props", value = Core.SawModel} end
    else
        if mode ~= "entities" then
            for _, model in ipairs(data.Props) do
                if validProp(model) then candidates[#candidates + 1] = {kind = "Props", value = model} end
            end
        end
        if mode ~= "props" then
            for _, class in ipairs(data.Entities) do
                if Core.EntityModels[class] then candidates[#candidates + 1] = {kind = "Entities", value = class} end
            end
        end
    end
    if #candidates == 0 then tell(ply, "No available items in this mode. Reload to edit your pool or restore defaults.") return false end
    local choice = candidates[math.random(#candidates)]
    local prop, value = choice.kind == "Props", choice.value
    local saw = prop and value == Core.SawModel
    if not ply:CheckLimit(prop and "props" or "sents") then return false end
    if not prop then
        local registered = scripted_ents.GetStored(value)
        local definition = registered and registered.t or list.GetEntry("SpawnableEntities", value)
        if not definition or (definition.AdminOnly and not ply:IsAdmin())
            or (registered and not definition.Spawnable and not ply:IsAdmin()) then
            tell(ply, "This entity is unavailable or restricted to administrators.") return false
        end
    end
    if hook.Run(prop and "PlayerSpawnProp" or "PlayerSpawnSENT", ply, value) == false then
        tell(ply, "Server rules blocked this item.") return false
    end
    local scale = prop and Core.Number(self:GetClientNumber("propscale"), 1, 0.25, 3) or 1
    local model = prop and value or Core.EntityModels[value]
    if not util.IsValidModel(model) then tell(ply, "This entity's model is unavailable.") return false end
    local ent = ents.Create(prop and "prop_physics" or value)
    if not IsValid(ent) then tell(ply, "Could not create this item.") return false end
    ent:SetModel(model)
    local mins, maxs = ent:GetModelBounds()
    local radius = math.max(mins:Length(), maxs:Length()) * scale
    local aim, start = ply:GetAimVector(), ply:GetShootPos()
    local position = start + aim * (radius + 40)
    local hull = Vector(radius, radius, radius)
    local check = util.TraceHull({start = start, endpos = position, mins = -hull, maxs = hull, filter = ply, mask = MASK_SOLID})
    if check.Hit or check.StartSolid or not util.IsInWorld(position) then
        ent:Remove()
        tell(ply, "Not enough space ahead. Aim away from nearby surfaces or reduce prop scale.") return false
    end
    ent:SetPos(position)
    ent:SetAngles(saw and ply:EyeAngles() or Angle(0, ply:EyeAngles().y, 0))
    ent:SetCreator(ply)
    ent.JunkJetOwner = ply
    ent:Spawn()
    if not IsValid(ent) then return false end
    if prop and scale ~= 1 then ent:SetModelScale(scale, 0) end
    ent:Activate()
    local spread = Core.Number(self:GetClientNumber("spread"), 0, 0, 0.25)
    local direction = (aim + VectorRand() * spread):GetNormalized()
    local speed = Core.Number(self:GetClientNumber("launchspeed"), 1, 0.1, 4) * 1500
    if saw then
        if not Sawblade.Launch(ent, ply, direction * speed) then
            ent:Remove()
            tell(ply, "This engine could not enable the native sawblade launch interaction.")
            return false
        end
    else
        local phys = ent:GetPhysicsObject()
        if not IsValid(phys) then ent:Remove() tell(ply, "Item has no usable physics; launch cancelled.") return false end
        ent:SetPhysicsAttacker(ply, 120)
        phys:Wake()
        phys:SetVelocity(direction * speed)
        if self:GetClientNumber("slipperymode") == 1 then phys:SetMaterial("ice") end
    end
    if self:GetClientNumber("firemode") == 1 then ent:Ignite(30) end
    if prop then hook.Run("PlayerSpawnedProp", ply, value, ent) else hook.Run("PlayerSpawnedSENT", ply, ent) end
    if not IsValid(ent) then return false end
    data.Live[ent] = true
    ent:CallOnRemove("JunkJetTrack", function(removed) data.Live[removed] = nil end)
    ply:AddCleanup("junkjet", ent)
    undo.Create("Junk Jet")
    undo.AddEntity(ent)
    undo.SetPlayer(ply)
    undo.Finish()
    if self:GetClientNumber("dissolve") == 1 then
        expire(ent, Core.Number(self:GetClientNumber("dissolvespeed"), 10, 1, 120))
    end
    return true
end
hook.Add("PlayerDisconnected", "JunkJetCleanup", function(ply)
    local data = states[ply]
    if data then for ent in pairs(data.Live) do if IsValid(ent) then ent:Remove() end end end
    states[ply] = nil
end)
