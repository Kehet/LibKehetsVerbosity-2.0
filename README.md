# LibKehetsVerbosity-2.0

A library for World of Warcraft addons that lets the player decide which messages an addon shows, and where.

The addon declares its message types. The library shows each message where the player wants it, and adds a settings page for it to Options > AddOns. The page uses the native game templates. The library needs only LibStub, not Ace3.

For each message type the player can set:

- Enable: turn the message on or off. Off stops the text and the sound.
- Play sound: turn the sound of the message on or off, if the addon gave the type a sound. Off keeps only the text.
- Show in: one or more of the chat windows, the error frame, the raid warning frame, the boss emote frame and the floating combat text.

One more setting, Mute all messages, turns off all messages and sounds of the addon.

Use message types for messages that the addon shows by itself, such as a login message, an alert or debug output. Print the answer to a slash command with `self:Print`, so that it always shows.

## Differences from 1.0

- No Ace3. The addon is a plain table with a `name`, and calls `Embed` itself.
- The settings are saved in a table that the addon gives, not in an AceDB profile.
- `self:Print` comes from the library, with the same output as AceConsole-3.0.
- The settings page is a native Settings page. `GetMessageOptions`, which returned an AceConfig group, is gone.

## Usage

Embed the library in the addon table, then declare the message types:

```lua
local MyAddon = { name = "MyAddon" }
LibStub("LibKehetsVerbosity-2.0"):Embed(MyAddon, function() return MyAddonDB end)

MyAddon:RegisterMessageTypes({
    banner = { name = "Login message", order = 1 },
    alert = {
        name = "Alerts",
        desc = "A currency is almost full.",
        order = 2,
        outputs = { "chat", "raid" },
        sound = { kit = SOUNDKIT.ALARM_CLOCK_WARNING_2 },
    },
    debug = { name = "Debug output", order = 3, shown = false, tag = "|cFF66B2FF[Debug]|r" },
})
```

The function given to `Embed` returns the table that the settings are saved in, usually a SavedVariables table. It can return `nil` until the saved variables are loaded. Without the function, the settings are saved in `MyAddon.db`.

Show a message:

```lua
self:Notify("alert", "Justice Points soon full!")
```

Add the settings page, after the saved variables are loaded:

```lua
self:RegisterMessagePage()
```

If the addon has its own Settings category, give it, and the page is listed under it with the name Messages:

```lua
self:RegisterMessagePage(category)
```

Chat messages start with the name of the addon in the colour of AceConsole-3.0. To use other text, give the addon table a `chatPrefix`:

```lua
local MyAddon = { name = "Kehet's MyAddon", chatPrefix = "|cFF009900MyAddon|r: " }
```

## Message type fields

| Field | Default | Meaning |
|---|---|---|
| `name` | The key | Title in the settings |
| `desc` | None | Description in the settings |
| `order` | By key | Position in the settings |
| `shown` | `true` | Whether the message is on until the player changes it |
| `outputs` | `{ "chat" }` | Where the message is shown until the player changes it. See Outputs. |
| `tag` | None | Text put in front of each message |
| `sound` | None | `{ kit = soundKitID }` or `{ file = pathOrFileID }`, with an optional `channel` (default `"Master"`) |
| `text` | `true` | `false` for a type that only plays its sound. Its section on the page has only Enable. It needs a `sound`. |

## Outputs

| Output | Place |
|---|---|
| `"chat"` | The default chat window. The player can choose any open chat window. |
| `"errors"` | The error frame, at the top of the screen |
| `"raid"` | The raid warning frame, in the middle of the screen |
| `"emote"` | The boss emote frame |
| `"combat"` | The floating combat text. It is listed only while the player has it turned on. |

The settings also list the outputs of these addons while the addon is loaded. An addon cannot declare them as a default.

| Addon | Outputs |
|---|---|
| Parrot | Each scroll area, in the normal style and in the sticky style |
| MikScrollingBattleText | Each scroll area, in the normal style and in the sticky style |
| BigWigs | Messages and Emphasized messages. BigWigs shows them only where it is active, such as in an instance. |
| DBM | Warnings and Special warnings. Special warnings show without their sound. |

The settings list the chat windows by their names. Only chat messages have the name of the addon in front.

If none of the chosen outputs can show the message, for example because the chat window is closed or BigWigs is not active, the message goes to the default chat window.

## Functions

| Function | Action |
|---|---|
| `lib:Embed(addon, getProfile)` | Give the addon the functions below. `getProfile` is optional. |
| `self:RegisterMessageTypes(types)` | Declare the message types. Call it once, before the first `Notify`. |
| `self:Notify(key, message, options)` | Show the message and play the sound of the type. Returns `true` if the text was shown. A `nil` message only plays the sound. `{ force = true }` as options shows the text also when the type is off or all messages are muted, but does not play the sound. |
| `self:IsMessageShown(key)` | Return whether `Notify` would show text of the type. |
| `self:SetMessageShown(key, shown)` | Turn the type on or off, as Enable does. |
| `self:SetMessageSound(key, on)` | Turn the sound of the type on or off, as Play sound does. Only for a type with a sound. |
| `self:Print([chatFrame,] ...)` | Print to chat with the addon name in front. |
| `self:RegisterMessagePage(parentCategory)` | Register a settings page with the message settings. Returns the Settings category. |
| `self:OpenMessagePage()` | Open that page in the game settings. |

## Saved settings

The settings are saved in the `verbosity` field of the table from `getProfile`. Only the settings that the player changed are saved.

Before that table exists, the declared defaults apply.

## Add the library to an addon

1. Add LibStub and the library to the externals in `.pkgmeta`, with the tag of the version you want:

    ```yaml
    externals:
      Libs/LibStub: https://repos.wowace.com/wow/libstub/trunk
      Libs/LibKehetsVerbosity-2.0:
        url: https://github.com/Kehet/LibKehetsVerbosity-2.0
        tag: 2.0.0
    ```

2. Add them to `embeds.xml`:

    ```xml
    <Script file="Libs\LibStub\LibStub.lua"/>
    <Include file="Libs\LibKehetsVerbosity-2.0\LibKehetsVerbosity-2.0.xml"/>
    ```

3. Add `LibKehetsVerbosity-2.0` to `## OptionalDeps` in the `.toc` file.

## Development

The library is not published as an addon. To run an addon from a git checkout, link this repository into the AddOns folder of the game. The development copy loads its own LibStub, so it needs no other addon.

```sh
ln -s /path/to/LibKehetsVerbosity-2.0 "/path/to/World of Warcraft/_classic_/Interface/AddOns/LibKehetsVerbosity-2.0"
```

Run the tests with Lua 5.1:

```sh
lua5.1 tests/test.lua
```

To release a version, increase `MINOR` in `LibKehetsVerbosity-2.0.lua` and tag the commit. LibStub keeps the copy with the highest `MINOR` when more than one addon loads the library.

## Requirements

- World of Warcraft: Mists of Pandaria Classic
- World of Warcraft: Classic Era
- World of Warcraft: Forever
- LibStub

## License

Public domain (The Unlicense). See `LICENSE`. LibStub is public domain too.
