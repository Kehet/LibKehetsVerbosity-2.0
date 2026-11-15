std = "lua51" -- WoW runs Lua 5.1
max_line_length = false
unused_args = false -- event handler and callback signatures are fixed by the API

exclude_files = {
    "LibStub/**", -- third-party, public domain
    "tests/**", -- runs outside the game and defines the game globals itself
}

-- WoW API and FrameXML
read_globals = {
    "C_Texture",
    "C_XMLUtil",
    "ChatTypeInfo",
    "CombatText_AddMessage",
    "CombatText_StandardScroll",
    "CreateFrame",
    "DEFAULT_CHAT_FRAME",
    "GameTooltip",
    "GameTooltip_Hide",
    "GetChatWindowInfo",
    "InterfaceOptions_AddCategory",
    "InterfaceOptionsFrame_OpenToCategory",
    "LibStub",
    "NUM_CHAT_WINDOWS",
    "PlaySound",
    "PlaySoundFile",
    "RaidBossEmoteFrame",
    "RaidNotice_AddMessage",
    "RaidWarningFrame",
    "Settings",
    "UIErrorsFrame",
}
