-- Server-only: arm a real CPhysicsProp, preserving its native collision code.
-- Source: CPhysicsProp::OnPhysGunDrop(LAUNCHED_BY_CANNON) in Valve's props.cpp.
local M = {}
function M.Launch(ent, owner, velocity)
    if not IsValid(ent) or ent:GetClass() ~= "prop_physics" then return false end
    local phys = ent:GetPhysicsObject()
    if not IsValid(phys) then return false end
    -- This enables the model's world_stick first-impact interaction. The engine
    -- embeds the edge, stores its release position and enables physcannon pickup.
    if not ent:SetSaveValue("m_bFirstCollisionAfterLaunch", true) then return false end
    ent:SetPhysicsAttacker(owner, 120)
    phys:AddGameFlag(FVPHYSICS_WAS_THROWN)
    phys:AddGameFlag(FVPHYSICS_DMG_SLICE)
    -- Do not replace VPhysics with traces or manually damage/freeze targets:
    -- native sharp-prop impacts supply CRUSH|SLASH for zombie dismemberment.
    phys:Wake()
    phys:SetVelocity(velocity)
    phys:AddAngleVelocity(Vector(0, 0, 5000))
    return true
end
return M
