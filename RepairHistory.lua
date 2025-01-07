local addonName, addon = ...
local LDB = LibStub:GetLibrary("LibDataBroker-1.1")
local LDBIcon = LibStub:GetLibrary("LibDBIcon-1.0")

local dataobj = LDB:NewDataObject("RepairHistory", {
    type = "data source",
    text = "Repair History",
    icon = "Interface\\AddOns\\RepairHistory\\ICON_RepairHistory",
    OnClick = function(self, button)
        if button == "LeftButton" then
            addon:ShowRepairData()
        elseif button == "RightButton" then
            addon:ShowHelp()
        elseif button == "MiddleButton" then
            addon:ShareRepairData()
        end
    end,
    OnTooltipShow = function(tooltip)
        tooltip:AddLine("|cFF00FF00Repair History|r")
        tooltip:AddLine("|cFFB0B0B0Tracks repair costs across characters and globally.|r")
        tooltip:AddLine("|cFFB0B0B0Please, see also: /rh help|r")
        tooltip:AddLine(" ")
        tooltip:AddLine("|cFFFFD700Left-Click:|r |cFFFFFFFFView the repair cost history for the current character.|r")
        tooltip:AddLine("|cFFFFD700Right-Click:|r |cFFFFFFFFSend the help commands for Repair History.|r")
        tooltip:AddLine("|cFFFFD700Middle-Click:|r |cFFFFFFFFShare your Repair History with others.|r")
    end,
})

-- Helper function to get the character's name
    local function GetCharacterName()
        return UnitName("player")
    end

-- Helper function to format money with coin icons
local function FormatMoneyWithIcons(money)
    if not money then return "0" end
    local gold = floor(money / 10000)
    local silver = floor((money % 10000) / 100)
    local copper = money % 100
    local TEXT_GOLD = "|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:2:0|t"
    local TEXT_SILVER = "|TInterface\\MoneyFrame\\UI-SilverIcon:12:12:2:0|t"
    local TEXT_COPPER = "|TInterface\\MoneyFrame\\UI-CopperIcon:12:12:2:0|t"

    local text = ""
    if gold > 0 then
        text = text .. gold .. TEXT_GOLD .. " "
    end
    if silver > 0 or gold > 0 then
        text = text .. silver .. TEXT_SILVER .. " "
    end
    text = text .. copper .. TEXT_COPPER

    return text
end

-- Helper function to format money as strings (gold, silver, copper) / This is mainly for rh share.
    local function FormatMoneyAsText(money)
        if not money then return "0c" end
        local gold = floor(money / 10000)
        local silver = floor((money % 10000) / 100)
        local copper = money % 100
    
        local text = ""
        if gold > 0 then
            text = text .. gold .. "g "
        end
        if silver > 0 or gold > 0 then
            text = text .. silver .. "s "
        end
        text = text .. copper .. "c"
    
        return text
    end

  
-- Initialize addon
function addon:OnInitialize()
    -- Initialize saved variables
    if not RepairHistoryDB then
        RepairHistoryDB = {
            accountWideRepairCost = 0,
            minimapButton = {
                hide = false,
            },
        }
    end

    if not RepairHistoryCharDB then
        RepairHistoryCharDB = {
            dailyRepairCost = 0,
            weeklyRepairCost = 0,
            monthlyRepairCost = 0,
            lifetimeRepairCost = 0,
            lastResetDay = 0,
            lastResetWeek = 0,
            lastResetMonth = 0,
            previousWeekCost = 0,
            previousMonthCost = 0
        }
    end

    -- Initialize minimap button
    LDBIcon:Register("RepairHistory", dataobj, RepairHistoryDB.minimapButton)
    self:UpdateMinimapButton()
end

-- Update minimap button visibility
function addon:UpdateMinimapButton()
    if RepairHistoryDB.minimapButton.hide then
        LDBIcon:Hide("RepairHistory")
    else
        LDBIcon:Show("RepairHistory")
    end
end

-- Helper function to reset daily values if it's a new day
    local function CheckDailyReset()
        local currentTime = C_DateAndTime.GetCurrentCalendarTime()
        local currentDay = currentTime.monthDay
        
        if RepairHistoryCharDB.lastResetDay ~= currentDay then
            RepairHistoryCharDB.dailyRepairCost = 0
            RepairHistoryCharDB.lastResetDay = currentDay
        end
    end

    local function CheckWeeklyReset()
        local currentTime = C_DateAndTime.GetCurrentCalendarTime()
        local currentWeek = math.floor(time() / (7 * 24 * 60 * 60))  -- Current week number
        
        if RepairHistoryCharDB.lastResetWeek ~= currentWeek then
            -- Store the previous week's total before resetting
            RepairHistoryCharDB.previousWeekCost = RepairHistoryCharDB.weeklyRepairCost
            RepairHistoryCharDB.weeklyRepairCost = 0
            RepairHistoryCharDB.lastResetWeek = currentWeek
        end
    end
    
    local function CheckMonthlyReset()
        local currentTime = C_DateAndTime.GetCurrentCalendarTime()
        local currentMonth = currentTime.month
        
        if RepairHistoryCharDB.lastResetMonth ~= currentMonth then
            -- Store the previous month's total before resetting
            RepairHistoryCharDB.previousMonthCost = RepairHistoryCharDB.monthlyRepairCost
            RepairHistoryCharDB.monthlyRepairCost = 0
            RepairHistoryCharDB.lastResetMonth = currentMonth
        end
    end

-- Event handler
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("MERCHANT_SHOW")
frame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        addon:OnInitialize()
    elseif event == "MERCHANT_SHOW" then
        if CanMerchantRepair() then
            local repairCost = GetRepairAllCost()
            if repairCost and repairCost > 0 then
                -- Call the reset functions to check if any reset is needed
                CheckDailyReset()
                CheckWeeklyReset()
                CheckMonthlyReset()

                RepairHistoryCharDB.dailyRepairCost = RepairHistoryCharDB.dailyRepairCost + repairCost
                RepairHistoryCharDB.weeklyRepairCost = RepairHistoryCharDB.weeklyRepairCost + repairCost
                RepairHistoryCharDB.monthlyRepairCost = RepairHistoryCharDB.monthlyRepairCost + repairCost
                RepairHistoryCharDB.lifetimeRepairCost = RepairHistoryCharDB.lifetimeRepairCost + repairCost
                RepairHistoryDB.accountWideRepairCost = RepairHistoryDB.accountWideRepairCost + repairCost
                print("|cFF00FF00You repaired your items for:|r " .. FormatMoneyWithIcons(repairCost))
                C_Timer.After(1, function()
                print("|cFF00FF00Daily Repair Total:|r " .. FormatMoneyWithIcons(RepairHistoryCharDB.dailyRepairCost))
            end )
        end
    end
end
end)

-- Show repair data
function addon:ShowRepairData()
    CheckDailyReset()
    CheckWeeklyReset()
    CheckMonthlyReset()

    local charName = GetCharacterName()
    
    print("|cFF00FF00===== Repair History|r [ " .. charName .. " ] |cFF00FF00=====|r")
    print("|cFFFFD700Daily Repair Cost:|r " .. FormatMoneyWithIcons(RepairHistoryCharDB.dailyRepairCost))
    print("|cFFFFD700Weekly Repair Cost:|r " .. FormatMoneyWithIcons(RepairHistoryCharDB.weeklyRepairCost))
    -- print("|cFFFFD700Last Week's Cost:|r " .. FormatMoneyWithIcons(RepairHistoryCharDB.previousWeekCost))
    print("|cFFFFD700Monthly Repair Cost:|r " .. FormatMoneyWithIcons(RepairHistoryCharDB.monthlyRepairCost))
    -- print("|cFFFFD700Last Month's Cost:|r " .. FormatMoneyWithIcons(RepairHistoryCharDB.previousMonthCost))
    print("|cFFFFD700Lifetime Repair Cost:|r " .. FormatMoneyWithIcons(RepairHistoryCharDB.lifetimeRepairCost))
    print("|cFFFFD700Account-Wide Repair Cost:|r " .. FormatMoneyWithIcons(RepairHistoryDB.accountWideRepairCost))
end

-- Function to get the active channel based on group context
function addon:GetActiveChannel()
    -- Check if the player is in a raid group (highest priority)
    if IsInRaid() then
        return "RAID"   -- Send to Raid if in a raid group
    -- Check if the player is in a party (next priority)
    elseif IsInGroup(LE_PARTY_CATEGORY_HOME) then
        return "PARTY"  -- Send to Party if in a party
    else
        return "SAY"    -- Fallback to Say if not in a party or raid
    end
end

-- Share repair data
function addon:ShareRepairData()
    local charName = GetCharacterName()
    local headerText = "===== Repair History [ " .. charName .. " ] ====="
    local messages = {
        headerText,
        "Daily Repair: " .. FormatMoneyAsText(RepairHistoryCharDB.dailyRepairCost),
        "Weekly Repair: " .. FormatMoneyAsText(RepairHistoryCharDB.weeklyRepairCost),
            -- "Last Week: " .. FormatMoneyAsText(RepairHistoryCharDB.previousWeekCost),
            "Monthly Repair: " .. FormatMoneyAsText(RepairHistoryCharDB.monthlyRepairCost),
            -- "Last Month: " .. FormatMoneyAsText(RepairHistoryCharDB.previousMonthCost),
            "Lifetime: " .. FormatMoneyAsText(RepairHistoryCharDB.lifetimeRepairCost),
            "Account-Wide: " .. FormatMoneyAsText(RepairHistoryDB.accountWideRepairCost),
        }
    
    -- Get the active channel using the addon's method
    local targetChannel = self:GetActiveChannel()
        
    -- Send the messages to the selected channel
    for _, msg in ipairs(messages) do
        SendChatMessage(msg, targetChannel)
    end
    end


-- Show help
function addon:ShowHelp()
    print("|cFF00FF00[Repair History Commands]|r" .. " |cFFB0B0B0- Version: 0.0.1|r")
    print("|cFFFFD700/rh|r - Show repair cost data.")
    print("|cFFFFD700/rh charclear|r - Reset character repair data.")
    print("|cFFFFD700/rh accountclear|r - Reset and erases all repair data.")
    print("|cFFFFD700/rh minimap|r - Toggle minimap icon visibility.")
    print("|cFFFFD700/rh help|r - Show this help message.")
end

-- Register slash commands
SLASH_REPAIRHISTORY1 = "/rh"
SlashCmdList["REPAIRHISTORY"] = function(msg)
    local cmd = msg:lower():trim()
    if cmd == "" then
        addon:ShowRepairData()
    elseif cmd == "charclear" then
        RepairHistoryCharDB = {
            dailyRepairCost = 0,
            weeklyRepairCost = 0,
            monthlyRepairCost = 0,
            lifetimeRepairCost = 0,
            lastResetDay = 0,
            lastResetWeek = 0,
            lastResetMonth = 0,
            previousWeekCost = 0,
            previousMonthCost = 0,
        }
        print("Repair History • |cFF00FF00Character repair data has been reset.|r")
    elseif cmd == "accountclear" then
        RepairHistoryDB.accountWideRepairCost = 0
        RepairHistoryCharDB = {
            dailyRepairCost = 0,
            weeklyRepairCost = 0,
            monthlyRepairCost = 0,
            lifetimeRepairCost = 0,
            lastResetDay = 0,
            lastResetWeek = 0,
            lastResetMonth = 0,
            previousWeekCost = 0,
            previousMonthCost = 0,
        }
        print("Repair History • |cFF00FF00Account-wide repair data has been reset.|r")
    elseif cmd == "minimap" then
        RepairHistoryDB.minimapButton.hide = not RepairHistoryDB.minimapButton.hide
        addon:UpdateMinimapButton()
        print("Repair History • |cFF00FF00Minimap button visibility toggled.|r")
    elseif cmd == "help" then
        addon:ShowHelp()
    elseif cmd == "share" then
        addon:ShareRepairData()
    end
end