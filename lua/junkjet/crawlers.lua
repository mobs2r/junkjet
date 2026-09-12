-- A surviving first cut changes the existing classic zombie into its native
-- torso state. Blade movement, sharp-prop damage and world embedding stay native.
local chance = CreateConVar("junkjet_crawlerchance", "75", FCVAR_ARCHIVE,
    "Percent of qualifying first zombie body cuts that leave a living torso (0 = native lethal cuts)", 0, 100)
local pending = setmetatable({}, {__mode = "k"})
local contacts = setmetatable({}, {__mode = "k"})
local torsoModel = "models/zombie/classic_torso.mdl"
local legsModel = "models/zombie/classic_legs.mdl"

local function intactZombie(npc)
    return IsValid(npc) and npc:GetClass() == "npc_zombie" and npc:Health() > 0
        and npc:GetInternalVariable("m_lifeState") == 0
        and npc:GetInternalVariable("m_fIsTorso") == false
        and npc:GetInternalVariable("m_fIsHeadless") == false
        and string.lower(npc:GetModel() or "") == "models/zombie/classic.mdl"
        and npc:GetBodygroup(1) == 1
end

local function headHit(npc, info)
    if npc:GetInternalVariable("m_bHeadShot") then return true end
    -- Physics impacts do not reliably set a hitgroup. Use the actual contact
    -- position and head bone instead of treating a head-level blade as a body cut.
    local bone = npc:LookupBone("ValveBiped.Bip01_Head1")
    local position = bone and npc:GetBonePosition(bone)
    if not position then position = npc:EyePos() end
    return info:GetDamagePosition().z >= position.z - 10 * npc:GetModelScale()
end

local function becomeTorso(npc, cut)
    if not intactZombie(npc) then return end
    if not npc:SetSaveValue("m_fIsTorso", true) then return end
    local origin, scale = npc:GetPos(), npc:GetModelScale()
    -- Match CNPC_BaseZombie::BecomeTorso / CZombie::SetZombieModel without
    -- replacing the NPC or inventing an explosion to trigger that code path.
    npc:SetModel(torsoModel)
    npc:SetBodygroup(1, 1)
    npc:SetHullType(HULL_TINY)
    npc:SetHullSizeNormal(true)
    npc:SetViewOffset(Vector(0, 0, 24) * scale)
    npc:SetPos(origin + Vector(0, 0, 40) * scale)
    npc:SetGroundEntity(NULL)
    npc:SetMaxHealth(math.max(1, math.floor(cut.maxHealth * 0.5)))
    npc:SetHealth(npc:GetMaxHealth())
    npc:CapabilitiesRemove(bit.bor(CAP_OPEN_DOORS, CAP_AUTO_DOORS, CAP_USE))
    npc:SetSaveValue("m_hPhysicsEnt", NULL)
    npc:ClearSchedule()
    npc:SetActivity(ACT_IDLE)
    npc:SetSchedule(SCHED_FALL_TO_GROUND)
    npc:PhysicsInitShadow(true, false)
    npc:EmitSound("E3_Phystown.Slicer")

    local legs = ents.Create("prop_ragdoll")
    if IsValid(legs) then
        legs:SetModel(legsModel)
        legs:SetPos(origin)
        legs:SetAngles(npc:GetAngles())
        legs:SetSkin(npc:GetSkin())
        legs:SetColor(npc:GetColor())
        legs:SetModelScale(scale, 0)
        legs:SetOwner(npc)
        legs:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
        legs:Spawn()
        legs:Activate()
        npc:DeleteOnRemove(legs)
        if IsValid(cut.blade) then cut.blade:DeleteOnRemove(legs) end
        SafeRemoveEntityDelayed(legs, 30)
    end
end

hook.Add("EntityTakeDamage", "JunkJetSurvivingTorso", function(npc, info)
    local blade = info:GetInflictor()
    if not IsValid(blade) or not blade.JunkJetLaunchedSawblade then return end
    local contact = contacts[npc]
    -- A single VPhysics contact can report damage several times. Only the blade
    -- that made this cut gets a short contact grace; other attacks still work.
    if contact and contact.blade == blade and CurTime() < contact.untilTime then
        info:SetDamage(0)
        return true
    end
    if chance:GetInt() == 0 or not intactZombie(npc) then return end
    if npc:Health() <= 1 then return end
    if not info:IsDamageType(DMG_CRUSH) or not info:IsDamageType(DMG_SLASH) then return end
    if info:GetDamage() < npc:Health() or info:GetDamage() <= npc:GetMaxHealth() * 0.5 then return end
    if headHit(npc, info) or not util.IsValidModel(torsoModel) or not util.IsValidModel(legsModel) then return end
    if math.random(1, 100) > chance:GetInt() then return end
    pending[npc] = {blade = blade, maxHealth = npc:GetMaxHealth()}
    -- Still send a real damage event through the engine and other damage hooks.
    -- Conversion happens only if the event is accepted and the NPC stays alive.
    info:SetDamage(math.max(0, npc:Health() - 1))
end)

hook.Add("PostEntityTakeDamage", "JunkJetSurvivingTorso", function(npc, info, tookDamage)
    local cut = pending[npc]
    if not cut or info:GetInflictor() ~= cut.blade then return end
    pending[npc] = nil
    if not tookDamage or not intactZombie(npc) then return end
    contacts[npc] = {blade = cut.blade, untilTime = CurTime() + 0.35}
    -- Rebuild the NPC hull outside the physics collision callback.
    timer.Simple(0, function() becomeTorso(npc, cut) end)
end)
