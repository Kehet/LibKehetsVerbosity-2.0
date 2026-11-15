-- Message types an addon declares, printed where the player chose, with a native settings page to choose it.
-- Needs only LibStub: no Ace3.
local MAJOR, MINOR = "LibKehetsVerbosity-2.0", 5
local lib = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then
    return
end

-- Kept on the library so a newer copy that loads later takes over what older copies registered
lib.embeds = lib.embeds or {}
lib.types = lib.types or {}
lib.profiles = lib.profiles or {}
lib.pages = lib.pages or {}

local COMBAT_LOG_WINDOW = 2

-- Colour of the text in the frames that do not have a colour of their own
local TEXT_COLOR = { r = 1, g = 0.82, b = 0 }

-- Outputs other than the chat windows. The settings list them by key, after the chat windows.
local FRAME_OUTPUTS = {
    combat = {
        name = "Floating combat text",
        -- The combat text is loaded only while the player has it turned on
        IsAvailable = function() return CombatText_AddMessage ~= nil end,
        Show = function(text)
            CombatText_AddMessage(text, CombatText_StandardScroll, TEXT_COLOR.r, TEXT_COLOR.g, TEXT_COLOR.b)
        end,
    },
    emote = {
        name = "Boss emote frame",
        IsAvailable = function() return RaidNotice_AddMessage ~= nil and RaidBossEmoteFrame ~= nil end,
        Show = function(text)
            RaidNotice_AddMessage(RaidBossEmoteFrame, text, ChatTypeInfo["RAID_BOSS_EMOTE"])
        end,
    },
    errors = {
        name = "Error frame",
        IsAvailable = function() return UIErrorsFrame ~= nil end,
        Show = function(text)
            UIErrorsFrame:AddMessage(text, TEXT_COLOR.r, TEXT_COLOR.g, TEXT_COLOR.b)
        end,
    },
    raid = {
        name = "Raid warning frame",
        IsAvailable = function() return RaidNotice_AddMessage ~= nil and RaidWarningFrame ~= nil end,
        Show = function(text)
            RaidNotice_AddMessage(RaidWarningFrame, text, ChatTypeInfo["RAID_WARNING"])
        end,
    },
}

local function GetType(addon, key)
    local types = lib.types[addon]
    local messageType = types and types[key]
    if not messageType then
        error(MAJOR .. ": message type '" .. tostring(key) .. "' is not registered", 3)
    end
    return messageType
end

-- The table the settings are saved in: what the function given to Embed returns, or else addon.db.
-- Nil until the saved variables are loaded, and then the declared defaults apply.
local function GetProfile(addon)
    local getProfile = lib.profiles[addon]
    if getProfile then
        return getProfile()
    end
    return addon.db
end

local function GetSaved(addon)
    local profile = GetProfile(addon)
    return profile and profile.verbosity
end

local function IsMuted(addon)
    local saved = GetSaved(addon)
    return saved ~= nil and saved.mute == true
end

local function SetMuted(addon, muted)
    local profile = GetProfile(addon)
    if not profile then
        return
    end

    local saved = profile.verbosity or {}
    saved.mute = muted or nil
    profile.verbosity = next(saved) and saved or nil
end

local function GetSetting(addon, key, field)
    local saved = GetSaved(addon)
    local settings = saved and saved.types and saved.types[key]
    if settings and settings[field] ~= nil then
        return settings[field]
    end
    return lib.types[addon][key].defaults[field]
end

-- Only what differs from the declaration is saved, so a profile reset brings the declared defaults back
local function SetSetting(addon, key, field, value)
    local profile = GetProfile(addon)
    if not profile then
        return
    end
    if value == lib.types[addon][key].defaults[field] then
        value = nil
    end

    local saved = profile.verbosity or {}
    saved.types = saved.types or {}
    local settings = saved.types[key] or {}
    settings[field] = value
    saved.types[key] = next(settings) and settings or nil
    if not next(saved.types) then
        saved.types = nil
    end
    profile.verbosity = next(saved) and saved or nil
end

-- Other addons whose message frames or scroll areas are outputs while the addon is loaded. GetAreas
-- returns them as key = name, or nil without the addon. Show returns false when the addon cannot show
-- the message now. With hasSticky each area is also listed in the sticky style, which the scrolling
-- text addons use for critical hits.
local MESSAGE_ADDONS = {
    bigwigs = {
        name = "BigWigs",
        GetAreas = function()
            if type(_G.BigWigsLoader) ~= "table" or type(_G.BigWigsLoader.SendMessage) ~= "function" then
                return nil
            end
            return { normal = "Messages", emphasized = "Emphasized messages" }
        end,
        -- BigWigs loads its message frames only where it has boss modules, such as in an instance
        Show = function(area, sticky, text)
            local messages = _G.BigWigs and _G.BigWigs:GetPlugin("Messages", true)
            if not messages or not messages:IsEnabled() then
                return false
            end
            _G.BigWigsLoader:SendMessage("BigWigs_Message", nil, nil, text, TEXT_COLOR, nil, area == "emphasized")
        end,
    },
    dbm = {
        name = "DBM",
        GetAreas = function()
            local dbm = _G.DBM
            if type(dbm) ~= "table" or type(dbm.AddWarning) ~= "function" or type(dbm.AddSpecialWarning) ~= "function" then
                return nil
            end
            return { warning = "Warnings", special = "Special warnings" }
        end,
        Show = function(area, sticky, text)
            if area == "special" then
                _G.DBM:AddSpecialWarning(text, nil, nil, nil, nil, true)
            else
                _G.DBM:AddWarning(text)
            end
        end,
    },
    msbt = {
        name = "MSBT",
        hasSticky = true,
        GetAreas = function()
            local msbt = _G.MikSBT
            if type(msbt) ~= "table" or type(msbt.IterateScrollAreas) ~= "function" or type(msbt.DisplayMessage) ~= "function" then
                return nil
            end
            local areas = {}
            for area, name in msbt.IterateScrollAreas() do
                areas[area] = name
            end
            return areas
        end,
        -- MSBT takes colours from 0 to 255
        Show = function(area, sticky, text)
            _G.MikSBT.DisplayMessage(text, area, sticky, TEXT_COLOR.r * 255, TEXT_COLOR.g * 255, TEXT_COLOR.b * 255)
        end,
    },
    parrot = {
        name = "Parrot",
        hasSticky = true,
        GetAreas = function()
            local parrot = _G.Parrot
            if type(parrot) ~= "table" or type(parrot.GetScrollAreasChoices) ~= "function" or type(parrot.ShowMessage) ~= "function" then
                return nil
            end
            return parrot:GetScrollAreasChoices()
        end,
        Show = function(area, sticky, text)
            _G.Parrot:ShowMessage(text, area, sticky, TEXT_COLOR.r, TEXT_COLOR.g, TEXT_COLOR.b)
        end,
    },
}

-- The calls are protected, so an addon that is missing, turned off or changed never stops a message
local function GetAddonAreas(messageAddon)
    local ok, areas = pcall(messageAddon.GetAreas)
    return ok and type(areas) == "table" and areas or nil
end

-- An output of another addon is "<addon>:<area>", or "<addon>sticky:<area>"
local function ShowInAddon(output, text)
    local kind, area = output:match("^(%a+):(.+)$")
    local sticky = kind and kind:match("^(%a+)sticky$")
    local messageAddon = MESSAGE_ADDONS[sticky or kind]
    local areas = messageAddon and GetAddonAreas(messageAddon)
    if not areas or not areas[area] then
        return false
    end
    local ok, shown = pcall(messageAddon.Show, area, sticky ~= nil, text)
    return ok and shown ~= false
end

-- A chat window is in use when it is shown or is a tab in the dock
local function IsWindowOpen(index)
    if index == COMBAT_LOG_WINDOW or not _G["ChatFrame" .. index] then
        return false
    end
    local name, _, _, _, _, _, shown, _, docked = GetChatWindowInfo(index)
    return name ~= nil and name ~= "" and (shown or docked) and true or false
end

-- A declaration says "chat" for the default chat window, which is saved and listed as the window it is
local function GetDefaultOutputs(messageType)
    local outputs = {}
    for _, output in ipairs(messageType.outputs) do
        if output == "chat" then
            output = "chat" .. DEFAULT_CHAT_FRAME:GetID()
        end
        outputs[output] = true
    end
    return outputs
end

local function GetOutputs(addon, key)
    return GetSetting(addon, key, "outputs") or GetDefaultOutputs(lib.types[addon][key])
end

local function SetOutput(addon, key, output, state)
    local outputs, isDefault = {}, true
    for current in pairs(GetOutputs(addon, key)) do
        outputs[current] = true
    end
    outputs[output] = state or nil

    local defaults = GetDefaultOutputs(lib.types[addon][key])
    for current in pairs(outputs) do
        isDefault = isDefault and defaults[current] == true
    end
    for current in pairs(defaults) do
        isDefault = isDefault and outputs[current] == true
    end
    SetSetting(addon, key, "outputs", not isDefault and outputs or nil)
end

-- The outputs that can show a message now: the open chat windows by their names, the frames,
-- and the message frames and scroll areas of other addons
local function GetOutputNames()
    local names = {}
    for index = 1, NUM_CHAT_WINDOWS do
        if IsWindowOpen(index) then
            names["chat" .. index] = GetChatWindowInfo(index)
        end
    end
    for output, frame in pairs(FRAME_OUTPUTS) do
        if frame.IsAvailable() then
            names[output] = frame.name
        end
    end
    for key, messageAddon in pairs(MESSAGE_ADDONS) do
        for area, name in pairs(GetAddonAreas(messageAddon) or {}) do
            local label = messageAddon.name .. ": " .. tostring(name)
            names[key .. ":" .. area] = label
            if messageAddon.hasSticky then
                names[key .. "sticky:" .. area] = label .. " (sticky)"
            end
        end
    end
    return names
end

-- An output that is not there now, such as a closed chat window, stays saved. When none of the
-- chosen outputs is there the message goes to the default chat window, so it is not lost.
local function ShowText(addon, key, text)
    local outputs = GetOutputs(addon, key)
    local shown = false
    for output in pairs(outputs) do
        local window = tonumber(output:match("^chat(%d+)$"))
        local frame = FRAME_OUTPUTS[output]
        if window and IsWindowOpen(window) then
            addon:Print(_G["ChatFrame" .. window], text)
            shown = true
        elseif frame and frame.IsAvailable() then
            frame.Show(text)
            shown = true
        elseif ShowInAddon(output, text) then
            shown = true
        end
    end

    if not shown and next(outputs) then
        addon:Print(text)
        shown = true
    end
    return shown
end

local function PlayTypeSound(sound)
    if sound.kit then
        PlaySound(sound.kit, sound.channel or "Master")
    else
        PlaySoundFile(sound.file, sound.channel or "Master")
    end
end

--- Declare the message types of the addon. Call it once, before the first Notify.
-- @param types Table of key = { name, desc, order, shown, outputs, tag, sound, text }.
-- shown (default true) and outputs (default { "chat" }) are what the player gets until they change it.
-- An output is "chat" for the default chat window, "errors", "raid", "emote" or "combat".
-- tag is put in front of each message. sound is { kit = soundKitID } or { file = pathOrFileID },
-- with an optional channel. text = false makes a type that only plays its sound: the page then
-- has only its Enable check box.
function lib:RegisterMessageTypes(types)
    local registered = {}
    for key, declaration in pairs(types) do
        if declaration.text == false and not declaration.sound then
            error(MAJOR .. ": message type '" .. tostring(key) .. "' has neither text nor sound", 2)
        end
        local outputs = declaration.outputs or { "chat" }
        for _, output in ipairs(outputs) do
            if output ~= "chat" and not FRAME_OUTPUTS[output] then
                error(MAJOR .. ": message type '" .. tostring(key) .. "' has unknown output '" .. tostring(output) .. "'", 2)
            end
        end

        registered[key] = {
            name = declaration.name or key,
            desc = declaration.desc,
            order = declaration.order,
            tag = declaration.tag,
            sound = declaration.sound,
            text = declaration.text ~= false,
            outputs = outputs,
            defaults = {
                shown = declaration.shown ~= false,
                sound = true,
            },
        }
    end
    lib.types[self] = registered
end

--- Show a message of a declared type where the player wants it, and play the sound of the type.
-- The sound plays only while the type is on, so turning a type off silences it too.
-- @param message Text to show, or nil to only play the sound. A type with text = false takes none.
-- @param options Optional { force = true } to show the text also when the type is off or everything is
-- muted. The sound still follows the settings.
-- @return true if the text was shown.
function lib:Notify(key, message, options)
    local messageType = GetType(self, key)
    local enabled = not IsMuted(self) and GetSetting(self, key, "shown")

    if messageType.sound and enabled and GetSetting(self, key, "sound") then
        PlayTypeSound(messageType.sound)
    end

    local force = options and options.force
    if message == nil or not messageType.text or not force and not enabled then
        return false
    end

    local text = tostring(message)
    if messageType.tag then
        text = messageType.tag .. " " .. text
    end

    return ShowText(self, key, text)
end

--- Whether Notify would show text of this type. Use it to skip work that only builds a message.
function lib:IsMessageShown(key)
    GetType(self, key)
    return not IsMuted(self) and GetSetting(self, key, "shown")
end

--- Turn the text of a type on or off, for example to carry over a setting the addon had before.
function lib:SetMessageShown(key, shown)
    GetType(self, key)
    SetSetting(self, key, "shown", shown and true or false)
end

--- Turn the sound of a type on or off, as the Play sound check box does.
function lib:SetMessageSound(key, on)
    if not GetType(self, key).sound then
        error(MAJOR .. ": message type '" .. tostring(key) .. "' has no sound", 2)
    end
    SetSetting(self, key, "sound", on and true or false)
end

-- The text in front of chat lines: the addon's chatPrefix, or its name in the AceConsole-3.0 colour.
-- It is read at each print, so a newer copy of the library that embeds itself again keeps it.
local function GetChatPrefix(addon)
    if addon.chatPrefix ~= nil then
        return tostring(addon.chatPrefix)
    end
    return "|cFF33FF99" .. tostring(addon.name) .. "|r: "
end

--- Print to chat with the name of the addon in front, like AceConsole-3.0 did, or with the addon's chatPrefix.
-- A chat frame may come before the text. Use it for answers to slash commands, which always show.
function lib:Print(...)
    local frame, first = DEFAULT_CHAT_FRAME, 1
    local candidate = ...
    if type(candidate) == "table" and type(candidate.AddMessage) == "function" then
        frame, first = candidate, 2
    end

    local parts = {}
    for index = first, select("#", ...) do
        table.insert(parts, tostring((select(index, ...))))
    end
    frame:AddMessage(GetChatPrefix(self) .. table.concat(parts, " "))
end

-- Types in the order they are listed in the settings
local function GetSortedKeys(addon)
    local types = lib.types[addon] or {}
    local keys = {}
    for key in pairs(types) do
        table.insert(keys, key)
    end
    table.sort(keys, function(a, b)
        local orderA, orderB = types[a].order or math.huge, types[b].order or math.huge
        if orderA ~= orderB then
            return orderA < orderB
        end
        return a < b
    end)
    return keys
end

-- A control is greyed out while all messages are muted, and the sound and outputs also while the type is off
local function IsDisabled(addon, key, field)
    if IsMuted(addon) then
        return true
    end
    return field ~= "shown" and not GetSetting(addon, key, "shown")
end

-- Chat windows by their number, then the frames, then the outputs of other addons
local function GetSortedOutputs()
    local names = GetOutputNames()
    local sorted = {}
    for output, name in pairs(names) do
        local window = tonumber(output:match("^chat(%d+)$"))
        local group = window and string.format("1%02d", window) or (FRAME_OUTPUTS[output] and "2" or "3") .. name
        table.insert(sorted, { output = output, name = name, sort = group })
    end
    table.sort(sorted, function(a, b) return a.sort < b.sort end)
    return sorted
end

-- For the tests, and for an addon that builds its own settings controls
lib.internal = {
    GetSetting = GetSetting,
    SetSetting = SetSetting,
    GetOutputs = GetOutputs,
    SetOutput = SetOutput,
    GetOutputNames = GetOutputNames,
    GetSortedOutputs = GetSortedOutputs,
    GetSortedKeys = GetSortedKeys,
    IsDisabled = IsDisabled,
    IsMuted = IsMuted,
    SetMuted = SetMuted,
}

-- Settings page: a title over a divider like the native settings, then a section for each type.
-- The check boxes are cells in a grid, the box left of its label, so a section takes a few lines.

local CELL_HEIGHT = 24
local CELL_MIN_WIDTH = 190
local LEGEND_HEIGHT = 7
local FIELDSET_PAD = 8
-- The native section header: 45 high, with the title 16 down
local SECTION_HEIGHT = 45
local SECTION_TITLE_TOP = 16
-- The native list puts 9 between its elements
local ELEMENT_SPACING = 9
-- Lined up with the labels of the native rows
local GRID_LEFT = 37
local GRID_RIGHT = 10
local HEADER_HEIGHT = 56

local function HasTemplate(name)
    return C_XMLUtil ~= nil and C_XMLUtil.GetTemplateInfo ~= nil and C_XMLUtil.GetTemplateInfo(name) ~= nil
end

local function HasAtlas(name)
    return C_Texture ~= nil and C_Texture.GetAtlasInfo ~= nil and C_Texture.GetAtlasInfo(name) ~= nil
end

local function ShowCellTooltip(cell)
    cell.hover:Show()
    GameTooltip:SetOwner(cell, "ANCHOR_RIGHT")
    GameTooltip:SetText(cell.labelText, 1, 1, 1)
    if cell.tooltip then
        GameTooltip:AddLine(cell.tooltip, nil, nil, nil, true)
    end
    GameTooltip:Show()
end

local function HideCellTooltip(cell)
    cell.hover:Hide()
    GameTooltip:Hide()
end

-- A check box with its label on the right. A click on the label clicks the box. The tooltip
-- also gives the whole label, which the cell cuts when it is too long for the column.
local function CreateCell(parent, label, tooltip, onClick)
    local cell = CreateFrame("Frame", nil, parent)
    cell:SetHeight(CELL_HEIGHT)
    cell.labelText = label
    cell.tooltip = tooltip

    local native = HasTemplate("SettingsCheckboxTemplate")
    cell.check = CreateFrame("CheckButton", nil, cell, native and "SettingsCheckboxTemplate" or "UICheckButtonTemplate")
    cell.check:SetSize(24, 24)
    cell.check:SetPoint("LEFT", cell, "LEFT", 0, 0)
    cell.check:SetScript("OnClick", function(check)
        onClick(check:GetChecked() and true or false)
    end)
    cell.check:SetScript("OnEnter", function() ShowCellTooltip(cell) end)
    cell.check:SetScript("OnLeave", function() HideCellTooltip(cell) end)
    -- The highlight of the native box covers a whole settings row; the cell has its own
    if type(cell.check.HoverBackground) == "table" then
        cell.check.HoverBackground:Hide()
        cell.check.HoverBackground:SetAlpha(0)
    end

    cell.label = cell:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cell.label:SetJustifyH("LEFT")
    cell.label:SetWordWrap(false)
    cell.label:SetPoint("LEFT", cell.check, "RIGHT", 4, 0)
    cell.label:SetPoint("RIGHT", cell, "RIGHT", -4, 0)
    cell.label:SetText(label)

    cell.hover = cell:CreateTexture(nil, "BACKGROUND")
    cell.hover:SetAllPoints()
    cell.hover:SetColorTexture(1, 1, 1, 0.1)
    cell.hover:Hide()

    cell:EnableMouse(true)
    cell:SetScript("OnMouseUp", function()
        if cell.check:IsEnabled() then
            cell.check:Click()
        end
    end)
    cell:SetScript("OnEnter", ShowCellTooltip)
    cell:SetScript("OnLeave", HideCellTooltip)
    return cell
end

local function SetCell(cell, checked, disabled)
    cell.check:SetChecked(checked and true or false)
    cell.check:SetEnabled(not disabled)
    cell.label:SetFontObject(disabled and "GameFontDisable" or "GameFontNormal")
end

-- Places the cells left to right in columns of the same width, and returns the y under the last line
local function PlaceGrid(cells, content, left, y, columns, width)
    for index, cell in ipairs(cells) do
        local column = (index - 1) % columns
        local line = math.floor((index - 1) / columns)
        cell:ClearAllPoints()
        cell:SetPoint("TOPLEFT", content, "TOPLEFT", left + column * width, y - line * CELL_HEIGHT)
        cell:SetWidth(width)
        cell:Show()
    end
    return y - math.ceil(#cells / columns) * CELL_HEIGHT
end

local function CreateEdge(box)
    local edge = box:CreateTexture(nil, "BORDER")
    edge:SetColorTexture(1, 1, 1, 1)
    table.insert(box.edges, edge)
    return edge
end

-- A frame drawn around a group of cells, with the legend on its top line, like a fieldset.
-- It is drawn with plain textures, so it looks the same on every client.
local function CreateFieldset(parent, legend)
    local box = CreateFrame("Frame", nil, parent)
    box.edges = {}

    box.fill = box:CreateTexture(nil, "BACKGROUND")
    box.fill:SetAllPoints()
    box.fill:SetColorTexture(0, 0, 0, 0.25)

    box.legend = box:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    box.legend:SetPoint("LEFT", box, "TOPLEFT", 10, 0)
    box.legend:SetText(legend)

    local left = CreateEdge(box)
    left:SetPoint("TOPLEFT")
    left:SetPoint("BOTTOMLEFT")
    left:SetWidth(1)

    local right = CreateEdge(box)
    right:SetPoint("TOPRIGHT")
    right:SetPoint("BOTTOMRIGHT")
    right:SetWidth(1)

    local bottom = CreateEdge(box)
    bottom:SetPoint("BOTTOMLEFT")
    bottom:SetPoint("BOTTOMRIGHT")
    bottom:SetHeight(1)

    -- The top line stops on both sides of the legend
    local topLeft = CreateEdge(box)
    topLeft:SetPoint("TOPLEFT")
    topLeft:SetPoint("RIGHT", box.legend, "LEFT", -4, 0)
    topLeft:SetHeight(1)

    local topRight = CreateEdge(box)
    topRight:SetPoint("LEFT", box.legend, "RIGHT", 4, 0)
    topRight:SetPoint("TOPRIGHT")
    topRight:SetHeight(1)

    return box
end

local function SetFieldset(box, disabled)
    box.legend:SetFontObject(disabled and "GameFontDisableSmall" or "GameFontNormalSmall")
    for _, edge in ipairs(box.edges) do
        edge:SetVertexColor(1, 0.82, 0, disabled and 0.15 or 0.35)
    end
end

local function BuildPage(addon, page)
    page.title = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightHuge")
    page.title:SetPoint("TOPLEFT", 7, -22)
    page.title:SetText(page.titleText)

    page.divider = page:CreateTexture(nil, "ARTWORK")
    if HasAtlas("Options_HorizontalDivider") then
        page.divider:SetAtlas("Options_HorizontalDivider", true)
        page.divider:SetPoint("TOP", 0, -50)
    else
        page.divider:SetColorTexture(1, 1, 1, 0.2)
        page.divider:SetHeight(1)
        page.divider:SetPoint("TOPLEFT", 7, -50)
        page.divider:SetPoint("TOPRIGHT", -7, -50)
    end

    -- The thin native scroll bar where the client has it
    local modern = HasTemplate("ScrollFrameTemplate")
    page.scroll = CreateFrame("ScrollFrame", nil, page, modern and "ScrollFrameTemplate" or "UIPanelScrollFrameTemplate")
    page.scroll:SetPoint("TOPLEFT", 0, -HEADER_HEIGHT)
    page.scroll:SetPoint("BOTTOMRIGHT", -28, 8)
    if modern and type(page.scroll.ScrollBar) == "table" and page.scroll.ScrollBar.SetHideIfUnscrollable then
        page.scroll.ScrollBar:SetHideIfUnscrollable(true)
    end

    local content = CreateFrame("Frame", nil, page.scroll)
    content:SetSize(1, 1)
    page.scroll:SetScrollChild(content)
    page.content = content

    page.mute = CreateCell(content, "Mute all messages",
        "Turn off every message and sound on this page. Answers to slash commands still print.",
        function(checked)
            SetMuted(addon, checked)
            page:Refresh()
        end)

    page.sections = {}
    for _, key in ipairs(GetSortedKeys(addon)) do
        local messageType = lib.types[addon][key]
        local section = { key = key, outputs = {} }

        section.title = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
        section.title:SetJustifyH("LEFT")
        section.title:SetText(messageType.name)

        local enableTip = messageType.text and "Show this message." or "Play the sound of this message."
        section.shown = CreateCell(content, "Enable", messageType.desc or enableTip, function(checked)
            SetSetting(addon, key, "shown", checked)
            page:Refresh()
        end)
        section.toggles = { section.shown }

        -- A type that has only a sound plays it while it is on, so it needs no other control
        if messageType.sound and messageType.text then
            section.sound = CreateCell(content, "Play sound",
                "Play the sound of this message. Turn it off to keep only the text.",
                function(checked)
                    SetSetting(addon, key, "sound", checked)
                end)
            table.insert(section.toggles, section.sound)
        end

        if messageType.text then
            section.showIn = CreateFieldset(content, "Show in")
        end

        page.sections[key] = section
    end
end

-- The fieldset of outputs of one type, at y. Returns the y under it.
local function PlaceOutputs(addon, key, section, content, outputs, y, width, columns, cellWidth)
    local disabled = IsDisabled(addon, key, "outputs")
    SetFieldset(section.showIn, disabled)
    -- The legend sits on the top line, inside the spacing above the box
    y = y - ELEMENT_SPACING
    local boxTop = y
    y = y - LEGEND_HEIGHT - FIELDSET_PAD / 2

    local chosen = GetOutputs(addon, key)
    local cells = {}
    for index, entry in ipairs(outputs) do
        local cell = section.outputs[index]
        if not cell then
            cell = CreateCell(content, "", nil, function(checked)
                SetOutput(addon, key, section.outputs[index].output, checked)
            end)
            section.outputs[index] = cell
        end
        cell.output = entry.output
        cell.labelText = entry.name
        cell.label:SetText(entry.name)
        SetCell(cell, chosen[entry.output] == true, disabled)
        cells[index] = cell
    end
    for index = #outputs + 1, #section.outputs do
        section.outputs[index]:Hide()
    end
    y = PlaceGrid(cells, content, GRID_LEFT + FIELDSET_PAD, y, columns, cellWidth)
    y = y - FIELDSET_PAD / 2

    local box = section.showIn
    box:ClearAllPoints()
    box:SetPoint("TOPLEFT", content, "TOPLEFT", GRID_LEFT, boxTop)
    box:SetPoint("BOTTOMRIGHT", content, "TOPLEFT", width - GRID_RIGHT, y)
    -- Under the cells, which are one level above the content
    box:SetFrameLevel(content:GetFrameLevel())
    box:Show()
    y = y - ELEMENT_SPACING
    return y
end

-- Lays the page out again, because the open chat windows and the loaded addons change between visits
local function RefreshPage(addon, page)
    local content = page.content
    local width = page.scroll:GetWidth()
    width = type(width) == "number" and width > 0 and width or 600
    content:SetWidth(width)

    local columns = math.max(1, math.floor((width - GRID_LEFT - GRID_RIGHT) / CELL_MIN_WIDTH))
    local cellWidth = (width - GRID_LEFT - GRID_RIGHT) / columns

    SetCell(page.mute, IsMuted(addon), false)
    local y = PlaceGrid({ page.mute }, content, GRID_LEFT, -4, columns, cellWidth)

    -- The outputs are in a fieldset, so their columns are a little narrower
    local inner = width - GRID_LEFT - GRID_RIGHT - 2 * FIELDSET_PAD
    local outputColumns = math.max(1, math.floor(inner / CELL_MIN_WIDTH))
    local outputWidth = inner / outputColumns

    local outputs = GetSortedOutputs()
    for _, key in ipairs(GetSortedKeys(addon)) do
        local section = page.sections[key]

        section.title:ClearAllPoints()
        section.title:SetPoint("TOPLEFT", content, "TOPLEFT", 7, y - SECTION_TITLE_TOP)
        y = y - SECTION_HEIGHT

        SetCell(section.shown, GetSetting(addon, key, "shown"), IsDisabled(addon, key, "shown"))
        if section.sound then
            SetCell(section.sound, GetSetting(addon, key, "sound"), IsDisabled(addon, key, "sound"))
        end
        y = PlaceGrid(section.toggles, content, GRID_LEFT, y, columns, cellWidth)

        if section.showIn then
            y = PlaceOutputs(addon, key, section, content, outputs, y, width, outputColumns, outputWidth)
        end
    end

    content:SetHeight(-y + 8)
end

--- Register a settings page in Options > AddOns that holds the message settings. It needs no other library.
-- @param parentCategory Optional category of the addon's own Settings page, to list this page under it.
function lib:RegisterMessagePage(parentCategory)
    local addon = self
    local page = CreateFrame("Frame")
    -- An unparented frame starts shown, so the settings panel's first Show() would not fire OnShow
    page:Hide()
    page.name = addon.name
    -- Under the addon's own category the page is listed, and titled, as Messages, like the native subpages
    page.titleText = parentCategory and "Messages" or addon.name

    page.Refresh = function()
        RefreshPage(addon, page)
    end
    page:SetScript("OnShow", function()
        if not page.content then
            BuildPage(addon, page)
        end
        page:Refresh()
    end)

    local category
    if Settings and Settings.RegisterCanvasLayoutCategory then
        if parentCategory then
            category = Settings.RegisterCanvasLayoutSubcategory(parentCategory, page, "Messages")
        else
            category = Settings.RegisterCanvasLayoutCategory(page, addon.name)
            Settings.RegisterAddOnCategory(category)
        end
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(page)
    end

    lib.pages[addon] = { frame = page, category = category }
    return category
end

--- Open the page of RegisterMessagePage in the game settings.
function lib:OpenMessagePage()
    local page = lib.pages[self]
    if not page then
        return
    end
    if page.category and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(page.category:GetID())
    elseif InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(page.frame)
    end
end

local MIXINS = {
    "Print",
    "RegisterMessageTypes",
    "Notify",
    "IsMessageShown",
    "SetMessageShown",
    "SetMessageSound",
    "RegisterMessagePage",
    "OpenMessagePage",
}

--- Give an addon table the functions of the library.
-- @param target The addon table. It needs a name, which is shown in front of chat messages and on the page.
-- An optional chatPrefix replaces the name in front of chat messages, for example "|cFF009900Short|r: ".
-- @param getProfile Optional function that returns the table the settings are saved in, or nil before the
-- saved variables are loaded. Without it the settings are saved in target.db.
function lib:Embed(target, getProfile)
    for _, name in ipairs(MIXINS) do
        target[name] = lib[name]
    end
    if getProfile then
        lib.profiles[target] = getProfile
    end
    lib.embeds[target] = true
    return target
end

for target in pairs(lib.embeds) do
    lib:Embed(target)
end
