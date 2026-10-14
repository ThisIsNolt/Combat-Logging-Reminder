-- Combat Log Reminder: Classic Era, configurable per instance.
local ADDON_NAME = ...
local frame = CreateFrame("Frame")
local db, entryTimer, snoozeTimer
local currentInstance, reminderShown, testMode = nil, false, false
local CheckInstance

-- GetInstanceInfo returns instance map IDs, independent of client language.
local raids = {
    {409, "Molten Core (MC)"}, {469, "Blackwing Lair (BWL)"},
    {509, "Ruins of Ahn'Qiraj (AQ20)"}, {531, "Temple of Ahn'Qiraj (AQ40)"},
    {309, "Zul'Gurub (ZG)"}, {533, "Naxxramas"}, {249, "Onyxia's Lair"},
}
local dungeons = {
    {48, "Blackfathom Deeps"}, {230, "Blackrock Depths"},
    {229, "Blackrock Spire (LBRS / UBRS)"}, {36, "Deadmines"},
    {429, "Dire Maul (all wings)"}, {90, "Gnomeregan"},
    {349, "Maraudon"}, {389, "Ragefire Chasm"},
    {129, "Razorfen Downs"}, {47, "Razorfen Kraul"},
    {189, "Scarlet Monastery (all wings)"}, {289, "Scholomance"},
    {33, "Shadowfang Keep"}, {329, "Stratholme (both entrances)"},
    {109, "Sunken Temple"}, {34, "The Stockade"},
    {70, "Uldaman"}, {43, "Wailing Caverns"}, {209, "Zul'Farrak"},
}

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00Combat Log Reminder:|r " .. msg)
end

local function InitializeSettings()
    if type(CombatLogReminderDB) ~= "table" then CombatLogReminderDB = {} end
    db = CombatLogReminderDB
    if type(db.instances) ~= "table" then db.instances = {} end
    for _, item in ipairs(raids) do
        if db.instances[item[1]] == nil then db.instances[item[1]] = true end
    end
    for _, item in ipairs(dungeons) do
        if db.instances[item[1]] == nil then db.instances[item[1]] = false end
    end
end

local function EnabledInstance()
    if not db then return nil end
    local inside, kind = IsInInstance()
    if not inside or (kind ~= "raid" and kind ~= "party") then return nil end
    local name, _, _, _, _, _, _, id = GetInstanceInfo()
    if id and db.instances[id] == true then return id, name end
end

local function CancelTimers()
    if entryTimer then entryTimer:Cancel(); entryTimer = nil end
    if snoozeTimer then snoozeTimer:Cancel(); snoozeTimer = nil end
end

local backdrop = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = {left = 11, right = 12, top = 12, bottom = 11},
}
local function Label(parent, text, font, x, y, width)
    local label = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    label:SetText(text)
    if width then label:SetWidth(width); label:SetJustifyH("LEFT") end
    return label
end
local function Button(parent, text, width, x, y)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 25)
    button:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", x, y)
    button:SetText(text)
    return button
end

local popup = CreateFrame("Frame", "CombatLogReminderPopup", UIParent, "BackdropTemplate")
popup:SetSize(430, 240)
popup:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
popup:SetFrameStrata("DIALOG")
popup:SetClampedToScreen(true)
popup:SetBackdrop(backdrop)
popup:Hide()
Label(popup, "|cffff0000COMBAT LOGGING REMINDER|r", "GameFontNormalLarge", 35, -30, 360)
local instanceText = Label(popup, "", nil, 25, -75, 380)
instanceText:SetJustifyH("CENTER")
local reminderText = Label(popup, "Don't forget to start combat logging!\n\nType |cff00ff00/combatlog|r to begin.", nil, 25, -120, 380)
reminderText:SetJustifyH("CENTER")
local ok = Button(popup, "OK", 100, 40, 25)
local snooze = Button(popup, "Snooze 2 Min", 130, 150, 25)
local cancel = Button(popup, "Cancel", 100, 290, 25)

local function ShowReminder(name, isTest)
    if not isTest and not EnabledInstance() then return end
    instanceText:SetText("You are inside:\n|cffffff00" .. (name or "this instance") .. "|r")
    snooze:SetText(isTest and "Snooze 10 Sec" or "Snooze 2 Min")
    popup:Show()
end

local function Dismiss(message)
    popup:Hide()
    CancelTimers()
    reminderShown = true
    testMode = false
    Print(message)
end
ok:SetScript("OnClick", function()
    Dismiss(testMode and "Test reminder acknowledged." or "Reminder acknowledged.")
end)
cancel:SetScript("OnClick", function()
    Dismiss(testMode and "Test reminder cancelled." or "Reminder cancelled for this visit.")
end)
snooze:SetScript("OnClick", function()
    popup:Hide()
    CancelTimers()
    local isTest, instanceID = testMode, currentInstance
    local duration = isTest and 10 or 120
    Print(isTest and "TEST MODE: Reminder snoozed for 10 seconds." or "Reminder snoozed for 2 minutes.")
    snoozeTimer = C_Timer.NewTimer(duration, function()
        snoozeTimer = nil
        if isTest then
            if testMode then ShowReminder("Test Instance", true) end
        elseif not testMode then
            local id, name = EnabledInstance()
            if id == instanceID and currentInstance == instanceID then ShowReminder(name, false) end
        end
    end)
end)

CheckInstance = function()
    local id = EnabledInstance()
    if not id then
        currentInstance, reminderShown = nil, false
        if not testMode then CancelTimers(); popup:Hide() end
        return
    end
    if id == currentInstance then return end
    CancelTimers()
    popup:Hide()
    currentInstance, reminderShown, testMode = id, false, false
    entryTimer = C_Timer.NewTimer(2, function()
        entryTimer = nil
        local activeID, name = EnabledInstance()
        if not testMode and activeID == id and currentInstance == id and not reminderShown then
            ShowReminder(name, false)
        end
    end)
end

-- Standalone settings window: /clr or /clr config.
local config = CreateFrame("Frame", "CombatLogReminderConfig", UIParent, "BackdropTemplate")
config:SetSize(720, 550)
config:SetPoint("CENTER")
config:SetFrameStrata("DIALOG")
config:SetClampedToScreen(true)
config:SetBackdrop(backdrop)
config:EnableMouse(true)
config:SetMovable(true)
config:RegisterForDrag("LeftButton")
config:SetScript("OnDragStart", function(self) self:StartMoving() end)
config:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
config:Hide()
UISpecialFrames = UISpecialFrames or {}
table.insert(UISpecialFrames, "CombatLogReminderConfig")
Label(config, "Combat Log Reminder Settings", "GameFontNormalLarge", 25, -25, 650)
Label(config, "Select where reminders appear. Changes save automatically for this character.", nil, 25, -55, 665)
Label(config, "Raids", "GameFontNormalLarge", 25, -90)
Label(config, "Dungeons", "GameFontNormalLarge", 350, -90)
local checkboxes = {}
local function Refresh()
    for id, box in pairs(checkboxes) do box:SetChecked(db.instances[id] == true) end
end
local function SettingsChanged()
    Refresh()
    CheckInstance()
end
local function AddCheckboxes(items, x, rowsPerColumn)
    for index, item in ipairs(items) do
        local id, text = item[1], item[2]
        local column = math.floor((index - 1) / rowsPerColumn)
        local row = (index - 1) % rowsPerColumn
        local box = CreateFrame("CheckButton", nil, config, "UICheckButtonTemplate")
        box:SetSize(18, 18)
        box:SetPoint("TOPLEFT", config, "TOPLEFT", x + column * 325, -120 - row * 18)
        -- Dungeons use one column; compact rows fit the whole Classic list.
        Label(box, text, "GameFontHighlightSmall", 23, -3, 300)
        checkboxes[id] = box
        box:SetScript("OnClick", function(self)
            db.instances[id] = self:GetChecked() and true or false
            SettingsChanged()
        end)
    end
end
AddCheckboxes(raids, 25, 7)
AddCheckboxes(dungeons, 350, 19)
Label(config, "Shared maps use one selection:\nLBRS / UBRS, Scarlet Monastery,\nDire Maul, and Stratholme.", "GameFontHighlightSmall", 25, -280, 290)
Label(config, "This addon reminds you to use /combatlog.\nThe OK button acknowledges the reminder.", "GameFontHighlightSmall", 25, -370, 290)
local close = Button(config, "Close", 100, 590, 25)
close:SetScript("OnClick", function() config:Hide() end)
local raidOnly = Button(config, "Raids Only", 105, 25, 25)
local all = Button(config, "Select All", 100, 140, 25)
local none = Button(config, "Select None", 105, 250, 25)
local function SetSelections(raidValue, dungeonValue)
    for _, item in ipairs(raids) do db.instances[item[1]] = raidValue end
    for _, item in ipairs(dungeons) do db.instances[item[1]] = dungeonValue end
    SettingsChanged()
end
raidOnly:SetScript("OnClick", function() SetSelections(true, false) end)
all:SetScript("OnClick", function() SetSelections(true, true) end)
none:SetScript("OnClick", function() SetSelections(false, false) end)
config:SetScript("OnShow", function()
    if not db then InitializeSettings() end
    Refresh()
end)

SLASH_COMBATLOGREMINDER1 = "/clr"
SLASH_COMBATLOGREMINDER2 = "/combatlogreminder"
SlashCmdList["COMBATLOGREMINDER"] = function(msg)
    msg = string.lower(msg or ""):match("^%s*(.-)%s*$")
    if not db then InitializeSettings() end
    if msg == "" or msg == "config" or msg == "settings" or msg == "options" then
        config:Show()
    elseif msg == "test" then
        CancelTimers()
        testMode, reminderShown = true, false
        ShowReminder("Test Instance", true)
        Print("TEST MODE active. Snooze time is 10 seconds.")
    elseif msg == "hide" then
        Dismiss("Reminder hidden.")
    else
        Print("/clr config - Select raids and dungeons.")
        Print("/clr test - Test the reminder with a 10 second snooze.")
        Print("/clr hide - Hide the reminder and cancel its timers.")
    end
end
frame:SetScript("OnEvent", function(self, event, addon)
    if event == "ADDON_LOADED" then
        if addon ~= ADDON_NAME then return end
        InitializeSettings()
        self:UnregisterEvent("ADDON_LOADED")
        Print("Loaded. Type |cffffff00/clr config|r for settings.")
    else
        CheckInstance()
    end
end)
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
