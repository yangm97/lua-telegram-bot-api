local _M = {
  VERSION = "3.5.0.0"
}

local json = require "cjson"
local lru, http, ltn12
if ngx then
  lru = require "resty.lrucache"
  http = require "resty.http"
else
  lru = require "lru"
  http = require "ssl.https"
  ltn12 = require "ltn12"
end

local c, err = lru.new(200)
if not c then
  return error("failed to create the cache: " .. (err or "unknown"))
end

function _M.init(bot_api_key, config)
  local server = "api.telegram.org"
  if config and config.server then
    server = config.server
  end
  _M.BASE_URL = "https://"..server.."/bot"..bot_api_key.."/"
  return _M
end

local function request(method, body)
  local res
  if ngx then -- Return the result of a resty.http request
    local arguments = {}
    if body then
      body = json.encode(body)
      arguments = {
        method = "POST",
        headers = {
          ["Content-Type"] = "application/json"
        },
        body = body
      }
      ngx.log(ngx.DEBUG, "Outgoing request: "..body)
    end
    local httpc = http.new()
    res, err = httpc:request_uri((_M.BASE_URL..method), arguments)
    if res then
      ngx.log(ngx.DEBUG, "Incoming reply: "..res.body)
      local tab = json.decode(res.body)
      if res.status == 200 and tab.ok then
        return tab.result
      else
        ngx.log(ngx.INFO, method.."() failed: "..tab.description)
        return false, tab
      end
    else
      ngx.log(ngx.ERR, err) -- HTTP request failed
    end
  else -- Return the result of a luasocket/luasec request
    local success
    local response_body = {}
    local arguments = {
      url = _M.BASE_URL..method,
      method = "POST",
      sink = ltn12.sink.table(response_body)
    }
    if body then
      body = json.encode(body)
      arguments.headers = {
        ["Content-Type"] = "application/json",
        ["Content-Length"] = body:len()
      }
      arguments.source = ltn12.source.string(body)
    end
    success, res = http.request(arguments)
    if success then
      local tab = json.decode(table.concat(response_body))
      if res == 200 and tab.ok then
        return tab.result
      else
        print("Failed: "..tab.description)
        return false, tab
      end
    else
      print("Connection error [" .. res .. "]")
    end
  end
end

local function is_table(value)
  if type(value) == "table" then
    return value
  else
    return nil
  end
end

local function assert_var(body, ...)
  for _,v in ipairs({...}) do
    assert(body[v], "Missing required variable "..v)
  end
end

local function check_id(body)
  if not body.inline_message_id then
    assert(body.chat_id, "Missing required variable chat_id")
    assert(body.message_id, "Missing required variable message_id")
  end
end

-- Getting updates

function _M.getUpdates(offset, limit, timeout, allowed_updates)
  local body = is_table(offset) or {
      offset = offset,
      limit = limit,
      timeout = timeout,
      allowed_updates = allowed_updates
    }
  return request("getUpdates", body)
end

function _M.setWebhook(url, certificate, max_connections, allowed_updates)
  local body = is_table(url) or {
    url = url,
    certificate = certificate,
    max_connections = max_connections,
    allowed_updates = allowed_updates
  }
  assert_var(body, "url")
  request("setWebhook", body)
end

function _M.deleteWebhook()
  return request("deleteWebhook")
end

function _M.getWebhookInfo()
  return request("getWebhookInfo")
end

-- Available methods
function _M.getMe()
  local getMe = c:get("getMe")
  if getMe then
    return getMe
  else
    getMe = request("getMe")
    c:set("getMe", getMe)
    return getMe
  end
end

function _M.sendMessage(chat_id, text, parse_mode, disable_web_page_preview, disable_notification, reply_to_message_id, reply_markup)
  local body = is_table(chat_id) or {
    chat_id = chat_id,
    text = text,
    parse_mode = parse_mode,
    disable_web_page_preview = disable_web_page_preview,
    disable_notification = disable_notification,
    reply_to_message_id = reply_to_message_id,
    reply_markup = reply_markup
  }
  assert_var(body, "chat_id", "text")
  return request("sendMessage", body)
end

function _M.forwardMessage(chat_id, from_chat_id, message_id, disable_notification)
  local body = is_table(chat_id) or {
    chat_id = chat_id,
    from_chat_id = from_chat_id,
    message_id = message_id,
    disable_notification = disable_notification
  }
  assert_var(body, "chat_id", "from_chat_id", "message_id")
  return request("forwardMessage", body)
end

function _M.sendPhoto(chat_id, photo, caption, disable_notification, reply_to_message_id, reply_markup)
  local body = is_table(chat_id) or {
    chat_id = chat_id,
    photo = photo,
    caption = caption,
    disable_notification = disable_notification,
    reply_to_message_id = reply_to_message_id,
    reply_markup = reply_markup
  }
  assert_var(body, "chat_id", "photo")
  return request("sendPhoto", body)
end

function _M.sendAudio(chat_id, audio, caption, duration, performer, title, disable_notification, reply_to_message_id, reply_markup)
  local body = is_table(chat_id) or {
    chat_id = chat_id,
    audio = audio,
    caption = caption,
    duration = duration,
    performer = performer,
    title = title,
    disable_notification = disable_notification,
    reply_to_message_id = reply_to_message_id,
    reply_markup = reply_markup
  }
  assert_var(body, "chat_id", "audio")
  return request("sendAudio", body)
end

function _M.sendDocument(chat_id, document, caption, disable_notification, reply_to_message_id, reply_markup)
  local body = is_table(chat_id) or {
    chat_id = chat_id,
    document = document,
    caption = caption,
    disable_notification = disable_notification,
    reply_to_message_id = reply_to_message_id,
    reply_markup = reply_markup
  }
  assert_var(body, "chat_id", "document")
  return request("sendDocument", body)
end

function _M.sendVideo(chat_id, video, duration, width, height, caption, disable_notification, reply_to_message_id, reply_markup)
  local body = is_table(chat_id) or {
    chat_id = chat_id,
    video = video,
    duration = duration,
    width = width,
    height = height,
    caption = caption,
    disable_notification = disable_notification,
    reply_to_message_id = reply_to_message_id,
    reply_markup = reply_markup
  }
  assert_var(body, "chat_id", "video")
  return request("sendVideo", body)
end

function _M.sendVoice(chat_id, voice, caption, duration, disable_notification, reply_to_message_id, reply_markup)
  local body = is_table(chat_id) or {
    chat_id = chat_id,
    voice = voice,
    duration = duration,
    caption = caption,
    disable_notification = disable_notification,
    reply_to_message_id = reply_to_message_id,
    reply_markup = reply_markup
  }
  assert_var(body, "chat_id", "voice")
  return request("sendVoice", body)
end

function _M.sendVideoNote(chat_id, video_note, duration, lenght, disable_notification, reply_to_message_id, reply_markup)
  local body = is_table(chat_id) or {
    chat_id = chat_id,
    video_note = video_note,
    duration = duration,
    lenght = lenght,
    disable_notification = disable_notification,
    reply_to_message_id = reply_to_message_id,
    reply_markup = reply_markup
  }
  assert_var(body, "chat_id", "video_note")
  return request("sendVideoNote", body)
end

function _M.sendMediaGroup(chat_id, media, disable_notification, reply_to_message_id)
  local body = is_table(chat_id) or {
    chat_id = chat_id,
    media = media,
    disable_notification = disable_notification,
    reply_to_message_id = reply_to_message_id,
  }
  assert_var(body, "chat_id", "media")
  return request("sendMediaGroup", body)
end

function _M.sendLocation(chat_id, latitude, longitude, live_period, disable_notification, reply_to_message_id, reply_markup)
  local body = is_table(chat_id) or {
    chat_id = chat_id,
    latitude = latitude,
    longitude = longitude,
    live_period = live_period,
    disable_notification = disable_notification,
    reply_to_message_id = reply_to_message_id,
    reply_markup = reply_markup
  }
  assert_var(body, "chat_id", "latitude", "longitude")
  return request("sendLocation", body)
end

function _M.editMessageLiveLocation(chat_id, message_id, inline_message_id, latitude, longitude, reply_markup)
  local body = is_table(chat_id) or {
    chat_id = chat_id,
    message_id = message_id,
    inline_message_id = inline_message_id,
    latitude = latitude,
    longitude = longitude,
    reply_markup = reply_markup
  }
  check_id(body)
  assert_var(body, "latitude", "longitude")
  return request("editMessageLiveLocation", body)
end

function _M.stopMessageLiveLocation(chat_id, message_id, inline_message_id, reply_markup)
  local body = is_table(chat_id) or {
    chat_id = chat_id,
    message_id = message_id,
    inline_message_id = inline_message_id,
    reply_markup = reply_markup
  }
  check_id(body)
  return request("editMessageLiveLocation", body)
end

function _M.sendVenue(chat_id, latitude, longitude, title, address, foursquare_id, disable_notification, reply_to_message_id, reply_markup)
  local body = is_table(chat_id) or {
    chat_id = chat_id,
    latitude = latitude,
    longitude = longitude,
    title = title,
    address = address,
    foursquare_id = foursquare_id,
    disable_notification = disable_notification,
    reply_to_message_id = reply_to_message_id,
    reply_markup = reply_markup
  }
  assert_var(body, "chat_id", "latitude", "longitude", "title", "address")
  return request("sendVenue", body)
end

function _M.sendContact(chat_id, phone_number, first_name, last_name, disable_notification, reply_to_message_id, reply_markup)
  local body = is_table(chat_id) or {
    chat_id = chat_id,
    phone_number = phone_number,
    first_name = first_name,
    last_name = last_name,
    disable_notification = disable_notification,
    reply_to_message_id = reply_to_message_id,
    reply_markup = reply_markup
  }
  assert_var(body, "chat_id", "phone_number", "first_name")
  return request("sendContact", body)
end

function _M.sendChatAction(chat_id, action)
  local body = is_table(chat_id) or {
    chat_id = chat_id,
    action = action
  }
  assert_var(body, "chat_id", "action")
  return request("sendChatAction", body)
end

function _M.getUserProfilePhotos(user_id, offset, limit)
  local body = is_table(user_id) or {
    user_id = user_id,
    offset = offset,
    limit = limit
  }
  assert_var(body, "user_id")
  return request("getUserProfilePhotos", body)
end

function _M.getFile(file_id)
  local body = is_table(file_id) or {
    file_id = file_id
  }
  assert_var(body, "file_id")
  return request("getFile", body)
end

function _M.kickChatMember(chat_id, user_id, until_date)
  local body = is_table(chat_id) or {
    chat_id = chat_id,
    user_id = user_id,
    until_date = until_date
  }
  assert_var(body, "chat_id", "user_id")
  return request("kickChatMember", body)
end

function _M.unbanChatMember(chat_id, user_id)
  local body = is_table(chat_id) or {
    chat_id = chat_id,
    user_id = user_id
  }
  assert_var(body, "chat_id", "user_id")
  return request("unbanChatMember", body)
end

function _M.restrictChatMember(chat_id, user_id, until_date, can_send_messages, can_send_media_messages, can_send_other_messages, can_add_web_page_previews)
  local body = is_table(chat_id) or {
    chat_id = chat_id,
    user_id = user_id,
    until_date = until_date,
    can_send_messages = can_send_messages,
    can_send_media_messages = can_send_media_messages,
    can_send_other_messages = can_send_other_messages,
    can_add_web_page_previews = can_add_web_page_previews
  }
  assert_var(body, "chat_id", "user_id")
  return request("restrictChatMember", body)
end

function _M.promoteChatMember(chat_id, user_id, can_change_info, can_post_messages, can_edit_messages, can_delete_messages, can_invite_users, can_restrict_members, can_pin_messages, can_promote_members)
  local body = is_table(chat_id) or {
    chat_id = chat_id,
    user_id = user_id,
    can_change_info = can_change_info,
    can_post_messages = can_post_messages,
    can_edit_messages = can_edit_messages,
    can_delete_messages = can_delete_messages,
    can_invite_users = can_invite_users,
    can_restrict_members = can_restrict_members,
    can_pin_messages = can_pin_messages,
    can_promote_members = can_promote_members
  }
  assert_var(body, "chat_id", "user_id")
  return request("promoteChatMember", body)
end

function _M.exportChatInviteLink(chat_id)
  local body = is_table(chat_id) or {
    chat_id = chat_id
  }
  assert_var(body, "chat_id")
  return request("exportChatInviteLink", body)
end

function _M.setChatPhoto(chat_id, photo)
  local body = is_table(chat_id) or {
    chat_id = chat_id,
    photo = photo
  }
  assert_var(body, "chat_id", "photo")
  return request("setChatPhoto", body)
end

function _M.deleteChatPhoto(chat_id)
  local body = is_table(chat_id) or {
    chat_id = chat_id
  }
  assert_var(body, "chat_id")
  return request("deleteChatPhoto", body)
end

function _M.setChatTitle(chat_id, title)
  local body = is_table(chat_id) or {
    chat_id = chat_id,
    title = title
  }
  assert_var(body, "chat_id", "title")
  return request("setChatTitle", body)
end

function _M.setChatDescription(chat_id, description)
  local body = is_table(chat_id) or {
    chat_id = chat_id,
    description = description
  }
  assert_var(body, "chat_id", "description")
  return request("setChatDescription", body)
end

function _M.pinChatMessage(chat_id, message_id, disable_notification)
  local body = is_table(chat_id) or {
    chat_id = chat_id,
    message_id = message_id,
    disable_notification = disable_notification
  }
  assert_var(body, "chat_id", "message_id")
  return request("pinChatMessage", body)
end

function _M.unpinChatMessage(chat_id)
  local body = is_table(chat_id) or {
    chat_id = chat_id
  }
  assert_var(body, "chat_id")
  return request("unpinChatMessage", body)
end

function _M.leaveChat(chat_id)
  local body = is_table(chat_id) or {
    chat_id = chat_id
  }
  assert_var(body, "chat_id")
  return request("leaveChat", body)
end

function _M.getChat(chat_id)
  local body = is_table(chat_id) or {
    chat_id = chat_id
  }
  assert_var(body, "chat_id")
  return request("getChat", body)
end

function _M.getChatAdministrators(chat_id)
  local body = is_table(chat_id) or {
    chat_id = chat_id
  }
  assert_var(body, "chat_id")
  return request("getChatAdministrators", body)
end

function _M.getChatMembersCount(chat_id)
  local body = is_table(chat_id) or {
    chat_id = chat_id
  }
  assert_var(body, "chat_id")
  return request("getChatMembersCount", body)
end

function _M.getChatMember(chat_id, user_id)
  local body = is_table(chat_id) or {
    chat_id = chat_id,
    user_id = user_id
  }
  assert_var(body, "chat_id", "user_id")
  return request("getChatMember", body)
end

function _M.setChatStickerSet(chat_id, sticker_set_name)
  local body = is_table(chat_id) or {
    chat_id = chat_id,
    sticker_set_name = sticker_set_name
  }
  assert_var(body, "chat_id", "sticker_set_name")
  return request("setChatStickerSet", body)
end

function _M.deleteChatStickerSet(chat_id)
  local body = is_table(chat_id) or {
    chat_id = chat_id,
  }
  assert_var(body, "chat_id")
  return request("setChatStickerSet", body)
end

function _M.answerCallbackQuery(callback_query_id, text, show_alert, cache_time)
  local body = is_table(callback_query_id) or {
    callback_query_id = callback_query_id,
    text = text,
    show_alert = show_alert,
    cache_time = cache_time
  }
  assert_var(body, "callback_query_id")
  return request("answerCallbackQuery", body)
end

-- Updating messages

function _M.editMessageText(chat_id, message_id, inline_message_id, text, parse_mode, disable_web_page_preview, reply_markup)
  local body = is_table(chat_id) or {
    chat_id = chat_id,
    message_id = message_id,
    inline_message_id = inline_message_id,
    text = text,
    parse_mode = parse_mode,
    disable_web_page_preview = disable_web_page_preview,
    reply_markup = reply_markup
  }
  check_id(body)
  assert_var(body, "text")
  return request("editMessageText", body)
end

function _M.editMessageCaption(chat_id, message_id, inline_message_id, caption, reply_markup)
  local body = is_table(chat_id) or {
    chat_id = chat_id,
    message_id = message_id,
    inline_message_id = inline_message_id,
    caption = caption,
    reply_markup = reply_markup
  }
  check_id(body)
  return request("editMessageCaption", body)
end

function _M.editMessageReplyMarkup(chat_id, message_id, inline_message_id, reply_markup)
  local body = is_table(chat_id) or {
    chat_id = chat_id,
    message_id = message_id,
    inline_message_id = inline_message_id,
    reply_markup = reply_markup
  }
  check_id(body)
  return request("editMessageReplyMarkup", body)
end

function _M.deleteMessage(chat_id, message_id)
  local body = is_table(chat_id) or {
    chat_id = chat_id,
    message_id = message_id
  }
  assert_var(body, "chat_id", "message_id")
  return request("deleteMessage", body)
end

-- Stickers

function _M.sendSticker(chat_id, sticker, caption, disable_notification, reply_to_message_id, reply_markup)
  local body = is_table(chat_id) or {
    chat_id = chat_id,
    sticker = sticker,
    caption = caption,
    disable_notification = disable_notification,
    reply_to_message_id = reply_to_message_id,
    reply_markup = reply_markup
  }
  assert_var(body, "chat_id", "sticker")
  return request("sendSticker", body)
end

function _M.getStickerSet(name)
  local body = is_table(name) or {
    name = name
  }
  assert_var(body, "name")
  return request("getSticker", body)
end

function _M.uploadStickerFile(user_id, png_sticker)
  local body = is_table(user_id) or {
    user_id = user_id,
    png_sticker = png_sticker
  }
  assert_var(body, "user_id", "png_sticker")
  return request("uploadStickerFile", body)
end

function _M.createNewStickerSet(user_id, name, title, png_sticker, emojis, contains_masks, mask_position)
  local body = is_table(user_id) or {
    user_id = user_id,
    name = name,
    title = title,
    png_sticker = png_sticker,
    emojis = emojis,
    contains_masks = contains_masks,
    mask_position = mask_position
  }
  assert_var(body, "user_id", "name", "title", "png_sticker", "emojis")
  return request("createNewStickerSet", body)
end

function _M.addStickerToSet(user_id, name, png_sticker, emojis, mask_position)
  local body = is_table(user_id) or {
    user_id = user_id,
    name = name,
    png_sticker = png_sticker,
    emojis = emojis,
    mask_position = mask_position
  }
  assert_var(body, "user_id", "name", "png_sticker", "emojis")
  return request("addStickerToSet", body)
end

function _M.setStickerPositionInSet(sticker, position)
  local body = is_table(sticker) or {
    sticker = sticker,
    position = position
  }
  assert_var(body, "sticker", "position")
  return request("setStickerPositionInSet", body)
end

function _M.deleteStickerFromSet(sticker)
  local body = is_table(sticker) or {
    sticker = sticker
  }
  assert_var(body, "sticker")
  return request("deleteStickerFromSet", body)
end

-- Inline mode

function _M.answerInlineQuery(inline_query_id, results, cache_time, is_personal, switch_pm_text, switch_pm_parameter)
  local body = is_table(inline_query_id) or {
    inline_query_id = inline_query_id,
    results = results,
    cache_time = cache_time,
    is_personal = is_personal,
    switch_pm_text = switch_pm_text,
    switch_pm_parameter = switch_pm_parameter
  }
  assert_var(body, "inline_query_id", "results")
  return request("answerInlineQuery", body)
end

-- Payments

function _M.sendInvoice(chat_id, title, description, payload, provider_token, start_parameter, currency, prices, photo_url, photo_width, photo_height, need_name, need_phone_number, need_email, need_shipping_address, send_phone_number_to_provider, send_email_to_provider, is_flexible, disable_notification, reply_to_message_id, reply_markup)
  local body = is_table(chat_id) or {
    chat_id = chat_id,
    title = title,
    description = description,
    payload = payload,
    provider_token = provider_token,
    start_parameter = start_parameter,
    currency = currency,
    prices = prices,
    photo_url = photo_url,
    photo_width = photo_width,
    photo_height = photo_height,
    need_name = need_name,
    need_phone_number = need_phone_number,
    need_email = need_email,
    need_shipping_address = need_shipping_address,
    send_phone_number_to_provider = send_phone_number_to_provider,
    send_email_to_provider = send_email_to_provider,
    is_flexible = is_flexible,
    disable_notification = disable_notification,
    reply_to_message_id = reply_to_message_id,
    reply_markup = reply_markup
  }
  assert_var(body, "chat_id", "title", "description", "payload", "provider_token", "start_parameter", "currency", "prices")
  return request("sendInvoice", body)
end

function _M.answerShippingQuery(shipping_query_id, ok, shipping_options, error_message)
  local body = is_table(shipping_query_id) or {
    shipping_query_id = shipping_query_id,
    ok = ok,
    shipping_options = shipping_options,
    error_message = error_message
  }
  assert_var(body, "shipping_query_id")
  if body.ok then
    assert(body.shipping_options, "Missing required variable shipping_options")
  else
    assert(body.error_message, "Missing required variable error_message")
  end
  return request("answerShippingQuery", body)
end

function _M.answerPreCheckoutQuery(pre_checkout_query_id, ok, error_message)
  local body = is_table(pre_checkout_query_id) or {
    pre_checkout_query_id = pre_checkout_query_id,
    ok = ok,
    error_message = error_message
  }
  assert_var(body, "pre_checkout_query_id")
  if not body.ok then
    assert(body.error_message, "Missing required variable error_message")
  end
  return request("answerPreCheckoutQuery", body)
end

-- Games

function _M.sendGame(chat_id, game_short_name, disable_notification, reply_to_message_id, reply_markup)
  local body = is_table(chat_id) or {
    chat_id = chat_id,
    game_short_name = game_short_name,
    disable_notification = disable_notification,
    reply_to_message_id = reply_to_message_id,
    reply_markup = reply_markup
  }
  assert_var(body, "chat_id", "game_short_name")
  request("sendGame", body)
end

function _M.setGameScore(user_id, score, force, disable_edit_message, chat_id, message_id, inline_message_id)
  local body = is_table(user_id) or {
    user_id = user_id,
    score = score,
    force = force,
    disable_edit_message = disable_edit_message,
    chat_id = chat_id,
    message_id = message_id,
    inline_message_id = inline_message_id
  }
  check_id(body)
  assert_var(body, "user_id", "score")
  return request("setGameScore", body)
end

function _M.getGameHighScores(user_id, chat_id, message_id, inline_message_id)
  local body = is_table(user_id) or {
    user_id = user_id,
    chat_id = chat_id,
    message_id = message_id,
    inline_message_id = inline_message_id
  }
  check_id(body)
  assert_var(body, "user_id")
  return request("getGameHighScores", body)
end

function _M.Custom(method, body)
  return request(method, body)
end

return _M
