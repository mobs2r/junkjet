local M = {}
M.SawModel = "models/props_junk/sawblade001a.mdl"
M.DefaultProps = {
    "models/props_junk/watermelon01.mdl", "models/props_junk/trafficcone001a.mdl",
    M.SawModel, "models/props_c17/furniturechair001a.mdl", "models/props_c17/oildrum001.mdl",
    "models/props_junk/wood_crate001a.mdl", "models/props_junk/metalbucket01a.mdl",
    "models/props_junk/garbage_metalcan001a.mdl", "models/props_junk/garbage_milkcarton002a.mdl",
    "models/props_junk/garbage_plasticbottle003a.mdl", "models/props_c17/furnitureradiator001a.mdl",
    "models/props_lab/reciever01b.mdl"
}
M.EntityModels = {sent_ball = "models/Combine_Helicopter/helicopter_bomb01.mdl",
    item_healthkit = "models/items/healthkit.mdl", item_battery = "models/items/battery.mdl"}
M.MaxItems = 128
function M.Normalize(value)
    if type(value) ~= "string" then return nil end
    return value:match("^%s*(.-)%s*$"):lower():gsub("\\", "/")
end
function M.ValidModelPath(value)
    return type(value) == "string" and #value <= 200 and value:match("^models/[%w_/%-%.]+%.mdl$") ~= nil
        and not value:find("..", 1, true)
end
function M.Number(value, default, low, high)
    local n = tonumber(value)
    if not n or n ~= n then n = default end
    return math.max(low, math.min(high, n))
end
function M.Index(items, value)
    for i, item in ipairs(items) do if item == value then return i end end
end
function M.Edit(items, value, remove)
    local index = M.Index(items, value)
    if remove then
        if not index then return false, "Item is not in your pool." end
        table.remove(items, index)
    else
        if index then return false, "Item is already in your pool." end
        if #items >= M.MaxItems then return false, "Pool limit reached (128 items)." end
        items[#items + 1] = value
    end
    return true
end
function M.Clean(items, validator)
    local result = {}
    if type(items) ~= "table" then return result end
    for _, value in ipairs(items) do
        local normalized = M.Normalize(value)
        if normalized and validator(normalized) then M.Edit(result, normalized, false) end
        if #result >= M.MaxItems then break end
    end
    return result
end
return M
