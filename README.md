# Lua Telegram Bot API
This package provides Openresty users Telegram API bindings and utilities for developing Telegram Bots. Contains bindings for all Bot API 3.5 methods. Supports both openresty and plain lua.

## Usage

You can call methods using either positional arguments or by sending a single body table, either way the table is serialized as json and the request is sent. On return, the json response is deserialized for you, if the request was successful, you will receive the `.result` as a lua table, if something goes wrong, you will receive `nil` and the whole error table.

## Example

Using positional arguments:

```
local api = require "telegram-bot-api.methods".init("123456789:ABCDefGhw3gUmZOq36-D_46_AMwGBsfefbcQ")

local ok, err = api.sendMessage(12345678, "<b>Hello World</b>", "html")

if not ok then
  print("Error while sending message: "..err.description)
end
```

Using body table:

```
local api = require "telegram-bot-api.methods".init("123456789:ABCDefGhw3gUmZOq36-D_46_AMwGBsfefbcQ")

local ok, err = api.sendMessage({
  chat_id = 12345678,
  text = "Hello World",
  parse_mode = "html"
  })

if not ok then
  print("Error while sending message: "..err.description)
end
```

## Customizing

You can also set a custom set a custom server as the second init argument, and call custom methods, like this:

```
local api = require "telegram-bot-api.methods".init("123456789:ABCDefGhw3gUmZOq36-D_46_AMwGBsfefbcQ", {server="api.pwrtelegram.xyz"})

local ok, err = api.phoneLogin({phone="+3984748839"})

if not ok then
  print("Error while using phoneLogin: "..err.description)
end
```

## Finishing lines

Both argument names and variable postioning try to mirror Telegram documentation as closely as possible, but you may prefer using `lib/telegram-bot-api/methods.lua` as a reference. The library will also try to warn you regarding missing required arguments before making a request and cache the `getMe()` method (more to be cached soon. Testing or something).
