local Core = include("junkjet/core.lua")
language.Add("tool.junkjet.name", "Junk Jet")
language.Add("tool.junkjet.desc", "Launch your own collection of junk.")
language.Add("tool.junkjet.left", "Launch selected mode")
language.Add("tool.junkjet.right", "Add/remove the aimed prop or supported entity")
language.Add("tool.junkjet.reload", "Open your saved launch pool")
language.Add("Cleanup_junkjet", "Junk Jet objects")
language.Add("Cleaned_junkjet", "Removed Junk Jet objects")
language.Add("SBoxLimit_junkjet", "Junk Jet object limit reached")
local pool, frame, refresh = {Props = {}, Entities = {}}, nil, nil
net.Receive("junkjet_pool", function()
    for _, kind in ipairs({"Props", "Entities"}) do
        pool[kind] = {}
        local count = net.ReadUInt(8)
        for i = 1, count do pool[kind][i] = net.ReadString() end
    end
    if IsValid(frame) and refresh then refresh() end
end)
local function button(parent, label, callback)
    local control = parent:Add("DButton")
    control:SetText(label)
    control:Dock(TOP)
    control:DockMargin(0, 0, 0, 5)
    control:SetTall(28)
    control.DoClick = callback
    return control
end
concommand.Add("junkjet_menu", function()
    if IsValid(frame) then frame:MakePopup() RunConsoleCommand("junkjet_requestpool") return end
    frame = vgui.Create("DFrame")
    frame:SetTitle("Junk Jet - Your launch pool")
    frame:SetSize(math.min(860, ScrW() - 32), math.min(640, ScrH() - 32))
    frame:Center()
    frame:MakePopup()
    local actions = frame:Add("DPanel")
    actions:Dock(RIGHT)
    actions:SetWide(210)
    actions:DockPadding(8, 8, 8, 8)
    local search = frame:Add("DTextEntry")
    search:Dock(TOP)
    search:DockMargin(0, 0, 8, 6)
    search:SetPlaceholderText("Search your pool...")
    local summary = frame:Add("DLabel")
    summary:Dock(BOTTOM)
    summary:SetTall(28)
    local listing = frame:Add("DListView")
    listing:Dock(FILL)
    listing:DockMargin(0, 0, 8, 0)
    listing:SetMultiSelect(false)
    listing:AddColumn("Type"):SetFixedWidth(55)
    listing:AddColumn("Model / class")
    listing:AddColumn("Client content"):SetFixedWidth(95)
    refresh = function()
        if not IsValid(listing) then return end
        listing:Clear()
        local query = search:GetValue():lower()
        for _, kind in ipairs({"Props", "Entities"}) do
            for _, value in ipairs(pool[kind]) do
                if value:find(query, 1, true) then
                    local available = kind ~= "Props" or util.IsValidModel(value)
                    local row = listing:AddLine(kind == "Props" and "Prop" or "Entity", value, available and "Available" or "Missing")
                    row.PoolKind, row.PoolValue = kind, value
                end
            end
        end
        summary:SetText(#pool.Props .. " props / " .. #pool.Entities .. " entities. Saved on this server. Server validates launches.")
    end
    search.OnChange = refresh
    local preview = actions:Add("DModelPanel")
    preview:Dock(TOP)
    preview:SetTall(145)
    preview:SetFOV(45)
    listing.OnRowSelected = function(_, _, row)
        local model = row.PoolKind == "Props" and row.PoolValue or Core.EntityModels[row.PoolValue]
        if model and util.IsValidModel(model) then
            preview:SetModel(model)
            local ent = preview:GetEntity()
            if IsValid(ent) then
                local mins, maxs = ent:GetRenderBounds()
                local center, size = (mins + maxs) * 0.5, (maxs - mins):Length()
                preview:SetLookAt(center)
                preview:SetCamPos(center + Vector(1, 1, 0.6) * size)
            end
        else preview:SetModel("") end
    end
    button(actions, "Remove selected", function()
        local row = listing:GetLine(listing:GetSelectedLine() or -1)
        if not IsValid(row) then return end
        RunConsoleCommand(row.PoolKind == "Props" and "junkjet_removeprop" or "junkjet_removeentity", row.PoolValue)
    end)
    local entry = actions:Add("DTextEntry")
    entry:Dock(TOP)
    entry:SetTall(28)
    entry:DockMargin(0, 8, 0, 5)
    entry:SetPlaceholderText("models/...mdl or entity class")
    button(actions, "Add model / entity", function()
        local value = Core.Normalize(entry:GetValue())
        if not value or value == "" then return end
        RunConsoleCommand(value:sub(1, 7) == "models/" and "junkjet_addprop" or "junkjet_addentity", value)
    end)
    button(actions, "Restore default props", function() RunConsoleCommand("junkjet_resetitems") end)
    button(actions, "Empty pool", function()
        Derma_Query("Empty your saved launch pool? You can restore defaults afterwards.", "Junk Jet",
            "Empty pool", function() RunConsoleCommand("junkjet_clearitems") end, "Cancel")
    end)
    button(actions, "Clean up my launches", function() RunConsoleCommand("junkjet_cleanup") end)
    button(actions, "Audit default models", function() RunConsoleCommand("junkjet_diagnose") end)
    local help = actions:Add("DLabel")
    help:Dock(FILL)
    help:SetWrap(true)
    help:SetTextColor(Color(45, 45, 45))
    help:SetContentAlignment(7)
    help:SetText("Right-click props to toggle them.\n\nSupported entities: sent_ball, item_healthkit, item_battery.\n\nMissing custom models stay saved, but are skipped when firing.")
    refresh()
    RunConsoleCommand("junkjet_requestpool")
end)
function TOOL.BuildCPanel(panel)
    panel:Help("Left-click launches. Right-click toggles an item. Reload opens your saved pool.")
    local modes = panel:ComboBox("Launch mode", "junkjet_mode")
    modes:AddChoice("Random from entire pool", "random")
    modes:AddChoice("Props only", "props")
    modes:AddChoice("Entities only", "entities")
    modes:AddChoice("Sawblade only (ignores pool)", "sawblade")
    panel:NumSlider("Speed multiplier (1 = 1500 units/sec)", "junkjet_launchspeed", 0.1, 4, 2)
    panel:NumSlider("Prop scale (1 = original size)", "junkjet_propscale", 0.25, 3, 2)
    panel:NumSlider("Spread (0 = straight)", "junkjet_spread", 0, 0.25, 2)
    panel:CheckBox("Ignite launched objects", "junkjet_firemode")
    panel:CheckBox("Slippery physics props", "junkjet_slipperymode")
    panel:CheckBox("Dissolve after delay", "junkjet_dissolve")
    panel:NumSlider("Lifetime before dissolve (seconds)", "junkjet_dissolvespeed", 1, 120, 0)
    panel:Help("Sawblades use native gravity-gun-style physics: zombie slicing and edge embedding on eligible world impacts. Slow shots, glancing hits and metal surfaces may bounce, just as in the engine.")
    panel:Help("A first lethal body cut usually leaves a living classic-zombie torso if its headcrab survives. Head hits and later attacks remain lethal. Server default: 75% survival.")
    panel:Button("Manage launch pool", "junkjet_menu")
    panel:Button("Restore default props", "junkjet_resetitems")
    panel:Button("Clean up my launches", "junkjet_cleanup")
    panel:Button("Audit default models", "junkjet_diagnose")
    local reset = panel:Button("Reset launch settings")
    reset.DoClick = function()
        for name, value in pairs({launchspeed = "1", propscale = "1", spread = "0", mode = "random",
            firemode = "0", slipperymode = "0", dissolve = "1", dissolvespeed = "10"}) do
            RunConsoleCommand("junkjet_" .. name, value)
        end
    end
end
