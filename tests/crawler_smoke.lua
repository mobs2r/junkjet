-- Opt-in regression suite for live first-cut torso behavior. Fresh Sandbox map only.
if not SERVER then return end
local Sawblade = include("junkjet/sawblade.lua")
local setting = GetConVar("junkjet_crawlerchance")
local originalChance = setting:GetInt()
local results, made = {}, {}
local initialEntities, testPlayer, hadGodMode
local function check(name, ok, detail)
    results[#results + 1] = {name = name, passed = ok == true, detail = tostring(detail or "")}
    print("JUNKJET_CRAWLER " .. (ok and "PASS " or "FAIL ") .. name .. " " .. tostring(detail or ""))
end
local function track(ent) made[#made + 1] = ent return ent end
local function finish()
    setting:SetInt(originalChance)
    hook.Remove("EntityTakeDamage", "JunkJetCrawlerVeto")
    for _, ent in ipairs(made) do if IsValid(ent) then ent:Remove() end end
    if initialEntities then
        for _, ent in ipairs(ents.GetAll()) do
            if not initialEntities[ent] and (ent:GetClass() == "npc_headcrab" or ent:GetClass() == "prop_ragdoll") then ent:Remove() end
        end
    end
    if IsValid(testPlayer) and not hadGodMode then testPlayer:GodDisable() end
    file.Write("junkjet_crawler_results.json", util.TableToJSON(results, true))
    print("JUNKJET_CRAWLER COMPLETE " .. #results)
end
local function run()
    local ply = player.GetAll()[1]
    assert(IsValid(ply), "Need a player")
    if not ply:Alive() then ply:Spawn() end
    testPlayer, hadGodMode = ply, ply:HasGodMode()
    ply:GodEnable()
    initialEntities = {}
    for _, ent in ipairs(ents.GetAll()) do initialEntities[ent] = true end
    local base = ply:GetPos() + Vector(500, 0, 0)
    local function zombie(offset, class)
        local ent = track(ents.Create(class or "npc_zombie"))
        ent:SetPos(base + offset) ent:Spawn()
        return ent
    end
    local function blade(position, armed)
        local ent = track(ents.Create("prop_physics"))
        ent:SetModel("models/props_junk/sawblade001a.mdl")
        ent:SetPos(position) ent:Spawn()
        if armed then assert(Sawblade.Launch(ent, ply, Vector(0, 0, 0))) end
        return ent
    end
    local function hit(target, inflictor, head)
        local info = DamageInfo()
        info:SetInflictor(inflictor) info:SetAttacker(ply)
        info:SetDamage(1000) info:SetDamageType(bit.bor(DMG_CRUSH, DMG_SLASH))
        info:SetDamagePosition(target:GetPos() + Vector(0, 0, head and 80 or 30))
        info:SetDamageForce(Vector(1000, 0, 0))
        target:TakeDamageInfo(info)
    end
    check("default first-cut survival chance is 75 percent", originalChance == 75, originalChance)
    setting:SetInt(100)
    local body = zombie(Vector(0, 0, 0))
    local bodyMaxHealth = body:GetMaxHealth()
    body:AddEntityRelationship(ply, D_HT, 99)
    body:SetEnemy(ply)
    body:UpdateEnemyMemory(ply, ply:GetPos())
    local identity = body:EntIndex()
    local cutter = blade(body:GetPos() + Vector(-160, 0, 36), true)
    cutter:GetPhysicsObject():SetVelocity(Vector(1500, 0, 0))
    local otherBlade = blade(base + Vector(0, 500, 300), true)
    local head = zombie(Vector(0, 250, 0))
    local headCutter = blade(head:GetPos() + Vector(-160, 0, 66), true)
    headCutter:GetPhysicsObject():SetVelocity(Vector(1500, 0, 0))
    local headless = zombie(Vector(0, 500, 0))
    headless:SetSaveValue("m_fIsHeadless", true) headless:SetBodygroup(1, 0)
    hit(headless, otherBlade, false)
    local crawler = zombie(Vector(0, 750, 0), "npc_zombie_torso")
    hit(crawler, otherBlade, false)
    local untouched = zombie(Vector(0, 1000, 0))
    local ordinary = blade(base + Vector(0, 1200, 300), false)
    hit(untouched, ordinary, false)
    local disabled = zombie(Vector(0, 1250, 0))
    setting:SetInt(0)
    hit(disabled, otherBlade, false)
    setting:SetInt(100)
    local interrupted = zombie(Vector(0, 1400, 0))
    hit(interrupted, otherBlade, false)
    hit(interrupted, cutter, true)
    local vetoed = zombie(Vector(0, 1500, 0))
    local vetoedHealth = vetoed:Health()
    hook.Add("EntityTakeDamage", "JunkJetCrawlerVeto", function(ent) if ent == vetoed then return true end end)
    hit(vetoed, otherBlade, false)
    timer.Simple(1, function()
        local ok, err = xpcall(function()
            check("actual blade body cut leaves original NPC alive", IsValid(body) and body:Health() > 0 and body:EntIndex() == identity)
            check("survivor has native torso state", IsValid(body) and body:GetInternalVariable("m_fIsTorso") == true)
            check("survivor has torso model and small hull", IsValid(body) and body:GetModel() == "models/zombie/classic_torso.mdl" and body:GetHullType() == HULL_TINY)
            check("survivor keeps its headcrab", IsValid(body) and body:GetBodygroup(1) == 1 and not body:GetInternalVariable("m_fIsHeadless"))
            local torsoHealth = math.max(1, math.floor(bodyMaxHealth * 0.5))
            check("survivor has half-size health pool", IsValid(body) and body:GetMaxHealth() == torsoHealth and body:Health() == torsoHealth, IsValid(body) and body:Health())
            check("survivor preserves enemy relationship", IsValid(body) and body:GetEnemy() == ply and body:Disposition(ply) == D_HT)
            check("survivor has valid physics", IsValid(body) and IsValid(body:GetPhysicsObject()))
            check("head hit does not create a living crawler", not IsValid(head) or head:Health() <= 0)
            check("head kill before deferred conversion is not revived", not IsValid(interrupted) or interrupted:Health() <= 0)
            check("headless zombie does not survive", not IsValid(headless) or headless:Health() <= 0)
            check("existing crawler can still die", not IsValid(crawler) or crawler:Health() <= 0)
            check("unmarked sawblade keeps original damage", not IsValid(untouched) or untouched:Health() <= 0)
            check("zero chance keeps original lethal cut", not IsValid(disabled) or disabled:Health() <= 0)
            check("damage veto prevents transformation", IsValid(vetoed) and vetoed:Health() == vetoedHealth and not vetoed:GetInternalVariable("m_fIsTorso"))
            local legs = false
            if IsValid(body) then
                for _, ent in ipairs(ents.FindByClass("prop_ragdoll")) do
                    if ent:GetOwner() == body and ent:GetModel() == "models/zombie/classic_legs.mdl" then legs = true end
                end
            end
            check("surviving cut creates detached legs", legs)
            local firstPosition = IsValid(body) and body:GetPos()
            timer.Simple(2, function()
                check("surviving crawler continues moving", IsValid(body) and firstPosition and body:GetPos():DistToSqr(firstPosition) > 25)
                if IsValid(body) then hit(body, otherBlade, false) end
                check("later blade hit kills surviving crawler normally", not IsValid(body) or body:Health() <= 0)
                finish()
            end)
        end, debug.traceback)
        if not ok then check("runner error", false, err) finish() end
    end)
end
timer.Simple(3, function()
    local ok, err = xpcall(run, debug.traceback)
    if not ok then check("runner error", false, err) finish() end
end)
