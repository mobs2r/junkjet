-- Opt-in engine smoke test. Run in a fresh Sandbox map, never on a live server.
-- Copy this file to lua/junkjet/engine_smoke.lua and run lua_openscript junkjet/engine_smoke.lua.
if not SERVER then return end
local results, created = {}, {}
local function check(name, condition, detail)
    results[#results + 1] = {name = name, passed = condition == true, detail = tostring(detail or "")}
    print("JUNKJET_TEST " .. (condition and "PASS " or "FAIL ") .. name .. " " .. tostring(detail or ""))
end
local function track(ent) created[#created + 1] = ent return ent end
local restorePlayer
local function finish()
    hook.Remove("EntityTakeDamage", "JunkJetSmokeDamage")
    hook.Remove("PlayerSpawnedProp", "JunkJetSmokeSpawn")
    hook.Remove("PlayerSpawnProp", "JunkJetSmokeDeny")
    if restorePlayer then restorePlayer() end
    for _, ent in ipairs(created) do if IsValid(ent) then ent:Remove() end end
    file.Write("junkjet_smoke_results.json", util.TableToJSON(results, true))
    print("JUNKJET_TEST COMPLETE " .. #results)
end
local function testTool(ply)
    local pos, angle, move = ply:GetPos(), ply:EyeAngles(), ply:GetMoveType()
    restorePlayer = function() ply:SetPos(pos) ply:SetEyeAngles(angle) ply:SetMoveType(move) end
    ply:SetMoveType(MOVETYPE_NOCLIP)
    ply:SetPos(pos + Vector(0, 0, 500))
    ply:SetEyeAngles(Angle(0, 90, 0))
    local settings = {dissolve = 1, dissolvespeed = 1, propscale = 1, launchspeed = 1, spread = 0}
    local mode, last = "sawblade", nil
    local tool = setmetatable({GetOwner = function() return ply end,
        GetClientInfo = function() return mode end,
        GetClientNumber = function(_, name) return settings[name] or 0 end}, {__index = ply:GetTool("junkjet")})
    hook.Add("PlayerSpawnedProp", "JunkJetSmokeSpawn", function(owner, model, ent)
        if owner == ply then last = track(ent) end
    end)
    check("tool launches sawblade", tool:LeftClick())
    local saw = last
    check("tool uses native prop_physics blade", IsValid(saw) and saw:GetClass() == "prop_physics")
    check("tool attributes creator", IsValid(saw) and saw:GetCreator() == ply)
    check("tool applies exact speed", IsValid(saw) and math.abs(saw:GetPhysicsObject():GetVelocity():Length() - 1500) < 1)
    check("tool blocks immediate repeat", tool:LeftClick() == false)
    timer.Simple(.3, function()
        hook.Add("PlayerSpawnProp", "JunkJetSmokeDeny", function() return false end)
        check("tool honors spawn veto", tool:LeftClick() == false)
        hook.Remove("PlayerSpawnProp", "JunkJetSmokeDeny")
    end)
    timer.Simple(.6, function()
        ply:SetPos(pos - Vector(0, 0, 100))
        check("tool rejects blocked muzzle", tool:LeftClick() == false)
        ply:SetPos(pos + Vector(0, 0, 500))
    end)
    timer.Simple(.9, function()
        mode = "props"
        check("tool launches random prop", tool:LeftClick())
    end)
    timer.Simple(3.5, function()
        check("dissolve removes launched sawblade", not IsValid(saw))
        finish()
    end)
end
local function run()
    local ply = player.GetAll()[1]
    if not IsValid(ply) then check("local player exists", false) finish() return end
    local Core = include("junkjet/core.lua")
    -- Grounded NPCs avoid the engine snapping airborne test NPCs below the shot.
    local origin = ply:GetPos() + Vector(0, 0, 36)
    check("tool registered", ply:GetTool("junkjet") ~= nil)
    local Sawblade = include("junkjet/sawblade.lua")
    for _, model in ipairs(Core.DefaultProps) do
        local valid = util.IsValidModel(model) and util.IsValidProp(model)
        check("default asset " .. model, valid)
        if valid then
            local ent = track(ents.Create("prop_physics"))
            if IsValid(ent) then
                ent:SetModel(model) ent:SetPos(origin) ent:Spawn()
                check("default physics " .. model, IsValid(ent:GetPhysicsObject()))
                ent:Remove()
            else check("create prop " .. model, false) end
        end
    end
    for class in pairs(Core.EntityModels) do
        local ent = track(ents.Create(class))
        if IsValid(ent) then
            ent:SetPos(origin) ent:Spawn() ent:Activate()
            check("entity physics " .. class, IsValid(ent:GetPhysicsObject()))
            ent:Remove()
        else check("entity exists " .. class, false) end
    end
    local npc = track(ents.Create("npc_zombie"))
    npc:SetPos(origin + Vector(160, 0, -36))
    npc:SetAngles(Angle(0, 180, 0))
    npc:Spawn()
    local damageType, attacker
    hook.Add("EntityTakeDamage", "JunkJetSmokeDamage", function(ent, info)
        if ent == npc then damageType, attacker = info:GetDamageType(), info:GetAttacker() end
    end)
    local function bladeAt(pos, angle, velocity)
        local blade = track(ents.Create("prop_physics"))
        blade:SetModel(Core.SawModel) blade:SetPos(pos) blade:SetAngles(angle) blade:Spawn()
        check("native launch armed", Sawblade.Launch(blade, ply, velocity))
        check("native first-impact interaction enabled", blade:GetInternalVariable("m_bFirstCollisionAfterLaunch") == true)
        check("native thrown flag enabled", blade:GetPhysicsObject():HasGameFlag(FVPHYSICS_WAS_THROWN))
        check("native slice flag enabled", blade:GetPhysicsObject():HasGameFlag(FVPHYSICS_DMG_SLICE))
        return blade
    end
    local oldGibs = {}
    for _, ent in ipairs(ents.GetAll()) do oldGibs[ent] = true end
    local blade = bladeAt(origin, Angle(0, 0, 0), Vector(1500, 0, 0))
    local ground = util.TraceLine({start = origin + Vector(0, 300, 200), endpos = origin + Vector(0, 300, -20000), mask = MASK_SOLID_BRUSHONLY})
    local wallBlade = bladeAt(ground.HitPos + Vector(0, 0, 200), Angle(90, 0, 0), Vector(0, 0, -1500))
    timer.Simple(1, function()
        check("native zombie impact includes CRUSH and SLASH", damageType ~= nil and bit.band(damageType, DMG_CRUSH) ~= 0 and bit.band(damageType, DMG_SLASH) ~= 0, damageType)
        check("native zombie damage credits launching player", attacker == ply)
        local torso, legs = false, false
        for _, ent in ipairs(ents.GetAll()) do
            if not oldGibs[ent] then
                local model = string.lower(ent:GetModel() or "")
                if model:find("classic_torso", 1, true) then torso = true track(ent) end
                if model:find("classic_legs", 1, true) then legs = true track(ent) end
            end
        end
        check("native zombie torso gib created", torso)
        check("native zombie legs gib created", legs)
        local phys = IsValid(wallBlade) and wallBlade:GetPhysicsObject()
        check("native world interaction embeds blade", IsValid(phys) and not phys:IsMotionEnabled())
        check("native world interaction enables gravity-gun release", IsValid(wallBlade) and bit.band(wallBlade:GetSpawnFlags(), 64) ~= 0)
        local fixup = false
        if IsValid(wallBlade) then
            for _, child in ipairs(wallBlade:GetChildren()) do
                if child:GetClass() == "point_enable_motion_fixup" then fixup = true end
            end
        end
        check("engine created embedded-blade release-position helper", fixup)
        for _, ent in ipairs(created) do if IsValid(ent) then ent:Remove() end end
        local ok, err = xpcall(function() testTool(ply) end, debug.traceback)
        if not ok then check("tool test error", false, err) finish() end
    end)
end
timer.Simple(5, function()
    local ok, err = xpcall(run, debug.traceback)
    if not ok then check("test runner error", false, err) finish() end
end)
