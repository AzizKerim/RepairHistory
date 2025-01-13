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
                locked = false,
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
    
    -- Set initial lock state
    if RepairHistoryDB.minimapButton.locked then
        LDBIcon:Lock("RepairHistory")
    else
        LDBIcon:Unlock("RepairHistory")
    end

    self:UpdateMinimapButton()
end

function addon:UpdateMinimapButton()
    if RepairHistoryDB.minimapButton.hide then
        LDBIcon:Hide("RepairHistory")
    else
        LDBIcon:Show("RepairHistory")
    end
end

-- Helper function to toggle minimap button lock state
function addon:ToggleMinimapLock()
    RepairHistoryDB.minimapButton.locked = not RepairHistoryDB.minimapButton.locked
    if RepairHistoryDB.minimapButton.locked then
        LDBIcon:Lock("RepairHistory")
        print("Repair History • |cFF00FF00Minimap button locked in place.|r")
    else
        LDBIcon:Unlock("RepairHistory")
        print("Repair History • |cFF00FF00Minimap button is now draggable.|r")
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

    local currentInstanceName = nil -- Store the name of the current raid instance

    -- Event handler for entering and leaving instances
local function CheckInstanceStatus()
    local inInstance, instanceType = IsInInstance()
    if inInstance and instanceType == "raid" then
        local instanceName = GetInstanceInfo()
        if currentInstanceName ~= instanceName then
            currentInstanceName = instanceName
            RepairHistoryCharDB.raidRepairCost = 0 -- Reset the raid repair cost for the new instance
        end
    else
        currentInstanceName = nil -- Clear the instance name when leaving
        RepairHistoryCharDB.raidRepairCost = nil -- Clear raid repair costs
    end
end


-- Event handler
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("MERCHANT_SHOW")
frame:RegisterEvent("MERCHANT_CLOSED")
frame:RegisterEvent("PLAYER_MONEY")

local playerMoney = 0
local atRepairMerchant = false
local repairAllCost = 0

frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        addon:OnInitialize()
        playerMoney = GetMoney()
    elseif event == "PLAYER_ENTERING_WORLD" then
        CheckInstanceStatus()
    elseif event == "MERCHANT_SHOW" then
        playerMoney = GetMoney()
        if CanMerchantRepair() then
            atRepairMerchant = true
            repairAllCost = GetRepairAllCost()
        end
    elseif event == "MERCHANT_CLOSED" then
        atRepairMerchant = false
        repairAllCost = 0
        playerMoney = GetMoney()
    elseif event == "PLAYER_MONEY" and atRepairMerchant then
        local newMoney = GetMoney()
        if newMoney < playerMoney then
            local moneySpent = playerMoney - newMoney

            -- Track the repair
            CheckDailyReset()
            CheckWeeklyReset()
            CheckMonthlyReset()

            RepairHistoryCharDB.dailyRepairCost = RepairHistoryCharDB.dailyRepairCost + moneySpent
            RepairHistoryCharDB.weeklyRepairCost = RepairHistoryCharDB.weeklyRepairCost + moneySpent
            RepairHistoryCharDB.monthlyRepairCost = RepairHistoryCharDB.monthlyRepairCost + moneySpent
            RepairHistoryCharDB.lifetimeRepairCost = RepairHistoryCharDB.lifetimeRepairCost + moneySpent
            RepairHistoryDB.accountWideRepairCost = RepairHistoryDB.accountWideRepairCost + moneySpent

            -- Track raid-specific repair costs
            if currentInstanceName then
                RepairHistoryCharDB.raidRepairCost = (RepairHistoryCharDB.raidRepairCost or 0) + moneySpent
                print("[" .. currentInstanceName .. "] |cFF00FF00Repair Cost:|r " .. FormatMoneyWithIcons(RepairHistoryCharDB.raidRepairCost))
            end

            -- Print the message
            print("|cFF00FF00Daily Repair Total:|r " .. FormatMoneyWithIcons(RepairHistoryCharDB.dailyRepairCost))
        end

        -- Update money and repair cost tracking
        playerMoney = newMoney
        repairAllCost = GetRepairAllCost()
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
    if currentInstanceName and RepairHistoryCharDB.raidRepairCost then
        print("[" .. currentInstanceName .. "] |cFFFFD700Repair Cost:|r " .. FormatMoneyWithIcons(RepairHistoryCharDB.raidRepairCost))
    end
    print("|cFFFFD700Weekly Repair Cost:|r " .. FormatMoneyWithIcons(RepairHistoryCharDB.weeklyRepairCost))
    print("|cFFFFD700Monthly Repair Cost:|r " .. FormatMoneyWithIcons(RepairHistoryCharDB.monthlyRepairCost))
    print("|cFFFFD700Lifetime Repair Cost:|r " .. FormatMoneyWithIcons(RepairHistoryCharDB.lifetimeRepairCost))
    print("|cFFFFD700Account-Wide Repair Cost:|r " .. FormatMoneyWithIcons(RepairHistoryDB.accountWideRepairCost))
end

-- Function to get the player's currently selected chat channel
function addon:GetCurrentChannel()
    -- Get the currently selected chat type from the chat frame
    local chatType = ChatFrame1.editBox:GetAttribute("chatType")
    local chatTarget = ChatFrame1.editBox:GetAttribute("channelTarget")
    
    -- Convert chat types to their proper channel identifiers
    local channelMap = {
        SAY = "SAY",
        YELL = "YELL",
        PARTY = "PARTY",
        RAID = "RAID",
        GUILD = "GUILD",
        OFFICER = "OFFICER",
        WHISPER = "WHISPER",
        CHANNEL = "CHANNEL",
    }
    
    -- If it's a numbered channel, return the channel number
    if chatType == "CHANNEL" then
        return "CHANNEL", chatTarget
    end
    
    -- Return the mapped channel type
    return channelMap[chatType] or "SAY"  -- Default to SAY if no valid channel is found
end

-- Share repair data
function addon:ShareRepairData()
    if InCombatLockdown() then
        print("Cannot send repair data during combat.")
        return
    end

    local charName = GetCharacterName()
    local headerText = "===== Repair History [ " .. charName .. " ] ====="
    local messages = {
        headerText,
        "Daily Repair: " .. FormatMoneyAsText(RepairHistoryCharDB.dailyRepairCost),
    }

    if currentInstanceName and RepairHistoryCharDB.raidRepairCost then
        table.insert(messages, "[" .. currentInstanceName .. "] Repair: " .. FormatMoneyAsText(RepairHistoryCharDB.raidRepairCost))
    end

    table.insert(messages, "Weekly Repair: " .. FormatMoneyAsText(RepairHistoryCharDB.weeklyRepairCost))
    table.insert(messages, "Monthly Repair: " .. FormatMoneyAsText(RepairHistoryCharDB.monthlyRepairCost))
    table.insert(messages, "Lifetime: " .. FormatMoneyAsText(RepairHistoryCharDB.lifetimeRepairCost))
    table.insert(messages, "Account-Wide: " .. FormatMoneyAsText(RepairHistoryDB.accountWideRepairCost))

    local channelType, channelTarget = self:GetCurrentChannel()

    -- Send all messages in a single loop
    for _, msg in ipairs(messages) do
        SendChatMessage(msg, channelType, nil, channelTarget)
    end
end


-- Show help
function addon:ShowHelp()
    print("|cFF00FF00[Repair History Commands]|r" .. " |cFFB0B0B0- Version: 1.0.0|r")
    print("|cFFFFD700/rh|r - Show repair cost data.")
    print("|cFFFFD700/rh charclear|r - Reset character repair data.")
    print("|cFFFFD700/rh accountclear|r - Reset and erases all repair data.")
    print("|cFFFFD700/rh minimap|r - Toggle minimap icon visibility.")
    print("|cFFFFD700/rh lock|r - Lock or unlock minimap button movement.")
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
    elseif cmd == "lock" then
        addon:ToggleMinimapLock()
    else
        print("Repair History • |cFFB0B0B0Invalid command. \nPlease type </rh help> for a list of commands.|r")
    end
end