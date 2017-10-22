local json = require 'cjson'

local http, resty, ltn12

if ngx and ngx.get_phase() ~= 'init' then
	http = require 'resty.http'
	resty = true
else
	http = require 'ssl.https'
	ltn12 = require 'ltn12'
end

local _M = {
	VERSION = '3.2.0.0'
}

function _M.init(bot_api_key, reply)
	_M.BASE_URL = 'https://api.telegram.org/bot'..bot_api_key..'/'
	_M.REPLY = reply
	return _M
end

local function request(method, body)
	if _M.REPLY then -- Return request table to be used to reply the webhook
		local res = {}
		if body then
			res = body
		end
		res.method = method
		return res
	elseif resty then -- Return the result of a resty.http request
		local arguments = {}
		if body then
			body = json.encode(body)
			arguments = {
				method = 'POST',
				headers = {
					['Content-Type'] = 'application/json'
				},
				body = body
			}
			ngx.log(ngx.DEBUG, 'Outgoing request: '..body)
		end
		local httpc = http.new()
		local res, err = httpc:request_uri((_M.BASE_URL..method), arguments)
		if res then
			ngx.log(ngx.DEBUG, 'Incoming reply: '..res.body)
			local tab = json.decode(res.body)
			if res.status == 200 and tab.ok then
				return tab, res.status
			else
				ngx.log(ngx.INFO, 'Failed: '..tab.description)
				return false, res.status, tab
			end
		else
			ngx.log(ngx.ERR, err) -- HTTP request failed
		end
	else -- Return the result of a luasocket/luasec request
		local response_body = {}
		local arguments = {
			url = _M.BASE_URL..method,
			method = 'POST',
			sink = ltn12.sink.table(response_body)
		}
		if body then
			body = json.encode(body)
			arguments.headers = {
				['Content-Type'] = 'application/json',
				['Content-Length'] = body:len()
			}
			arguments.source = ltn12.source.string(body)
		end
		local success, res = http.request(arguments)
		if success then
			local tab = json.decode(table.concat(response_body))
			if res == 200 and tab.ok then
				return tab, res
			else
				print('Failed: '..tab.description)
				return false, res, tab
			end
		else
			print('Connection error [' .. res .. ']')
		end
	end
end

-- Pre-processors
local function pre_msg(body, disable_notification, reply_to_message_id, reply_markup)
	if disable_notification then
		body.disable_notification = disable_notification
	end
	if reply_to_message_id then
		body.reply_to_message_id = reply_to_message_id
	end
	if reply_markup then
		body.reply_markup = reply_markup
	end
	return body
end

local function pre_text(body, text, parse_mode, disable_web_page_preview)
	body.text = text
	if parse_mode then
		body.parse_mode = parse_mode
	end
	if disable_web_page_preview then
		body.disable_web_page_preview = disable_web_page_preview
	end
	return body
end

local function pre_media(body, caption, duration)
	if caption then
		body.caption = caption
	end
	if duration then
		body.duration = duration
	end
	return body
end

local function pre_edit(body, chat_id, message_id, inline_message_id)
	if inline_message_id then
		body.inline_message_id = inline_message_id
	else
		body.chat_id = chat_id
		body.message_id = message_id
	end
	return body
end

-- Getting updates

function _M.getUpdates(offset, limit, timeout, allowed_updates)
	local body = {}
	if offset then
		body.offset = offset
	end
	if limit then
		body.limit = limit
	end
	if timeout then
		body.timeout = timeout
	end
	if allowed_updates then
		body.allowed_updates = allowed_updates
	end
	return request('getUpdates', body)
end

function _M.setWebhook(url, certificate, max_connections, allowed_updates)
	local body = {
		url = url
	}
	if certificate then
		body.certificate = certificate
	end
	if max_connections then
		body.max_connections = max_connections
	end
	if allowed_updates then
		body.allowed_updates = allowed_updates
	end
	request('setWebhook', body)
end

function _M.deleteWebhook()
	return request('deleteWebhook')
end

function _M.getWebhookInfo()
	return request('getWebhookInfo')
end

-- Available methods

function _M.getMe()
	return request('getMe')
end

function _M.sendMessage(chat_id, text, parse_mode, disable_web_page_preview, disable_notification, reply_to_message_id,
	reply_markup)
	local body = {
		chat_id = chat_id
	}
	body = pre_text(body, text, parse_mode, disable_web_page_preview)
	body = pre_msg(body, disable_notification, reply_to_message_id, reply_markup)
	return request('sendMessage', body)
end

function _M.forwardMessage(chat_id, from_chat_id, disable_notification, message_id)
	local body = {
		chat_id = chat_id,
		from_chat_id = from_chat_id,
		message_id = message_id
	}
	body = pre_msg(body, disable_notification)
	return request('forwardMessage', body)
end

function _M.sendPhoto(chat_id, photo, caption, disable_notification, reply_to_message_id, reply_markup)
	local body = {
		chat_id = chat_id,
		photo = photo
	}
	body = pre_media(body, caption)
	body = pre_msg(body, disable_notification, reply_to_message_id, reply_markup)
	return request('sendPhoto', body)
end

function _M.sendAudio(chat_id, audio, caption, duration, performer, title, disable_notification, reply_to_message_id,
	reply_markup)
	local body = {
		chat_id = chat_id,
		audio = audio
	}
	if performer then
		body.performer = performer
	end
	if title then
		body.title = title
	end
	body = pre_media(body, caption, duration)
	body = pre_msg(body, disable_notification, reply_to_message_id, reply_markup)
	return request('sendAudio', body)
end

function _M.sendDocument(chat_id, document, caption, disable_notification, reply_to_message_id, reply_markup)
	local body = {
		chat_id = chat_id,
		document = document
	}
	body = pre_media(body, caption)
	body = pre_msg(body, disable_notification, reply_to_message_id, reply_markup)
	return request('sendDocument', body)
end

function _M.sendSticker(chat_id, sticker, caption, disable_notification, reply_to_message_id, reply_markup)
	local body = {
		chat_id = chat_id,
		sticker = sticker
	}
	body = pre_media(body, caption)
	body = pre_msg(body, disable_notification, reply_to_message_id, reply_markup)
	return request('sendSticker', body)
end

function _M.getSticker(name)
	local body = {
		name = name
	}
	return request('getSticker', body)
end

function _M.uploadStickerFile(user_id, png_sticker)
	local body = {
		user_id = user_id,
		png_sticker = png_sticker
	}
	return request('uploadStickerFile', body)
end

function _M.createNewStickerSet(user_id, name, title, png_sticker, emojis, contains_masks, mask_position)
	local body = {
		user_id = user_id,
		name = name,
		title = title,
		png_sticker = png_sticker,
		emojis = emojis
	}
	if contains_masks then
		body.contains_masks = contains_masks
	end
	if mask_position then
		body.mask_position = mask_position
	end
	return request('createNewStickerSet', body)
end

function _M.addStickerToSet(user_id, name, png_sticker, emojis, mask_position)
	local body = {
		user_id = user_id,
		name = name,
		png_sticker = png_sticker,
		emojis = emojis
	}
	if mask_position then
		body.mask_position = mask_position
	end
	return request('addStickerToSet', body)
end

function _M.setStickerPositionInSet(sticker, position)
	local body = {
		sticker = sticker,
		position = position
	}
	return request('setStickerPositionInSet', body)
end

function _M.deleteStickerFromSet(sticker)
	local body = {
		sticker = sticker
	}
	return request('deleteStickerFromSet', body)
end

function _M.sendVideo(chat_id, video, duration, width, height, caption, disable_notification, reply_to_message_id,
	reply_markup)
	local body = {
		chat_id = chat_id,
		video = video
	}
	if width then
		body.width = width
	end
	if height then
		body.height = height
	end
	body = pre_media(body, caption, duration)
	body = pre_msg(body, disable_notification, reply_to_message_id, reply_markup)
	return request('sendVideo', body)
end

function _M.sendVoice(chat_id, voice, caption, duration, disable_notification, reply_to_message_id, reply_markup)
	local body = {
		chat_id = chat_id,
		voice = voice
	}
	body = pre_media(body, caption, duration)
	body = pre_msg(body, disable_notification, reply_to_message_id, reply_markup)
	return request('sendVoice', body)
end

function _M.sendVideoNote(chat_id, video_note, duration, lenght, disable_notification, reply_to_message_id,
	reply_markup)
	local body = {
		chat_id = chat_id,
		video_note = video_note
	}
	if lenght then
		body.lenght = lenght
	end
	body = pre_media(body, false, duration)
	body = pre_msg(body, disable_notification, reply_to_message_id, reply_markup)
	return request('sendVideoNote', body)
end

function _M.sendLocation(chat_id, latitude, longitude, reply_to_message_id, reply_markup)
	local body = {
		chat_id = chat_id,
		latitude = latitude,
		longitude = longitude
	}
	if latitude then
		body.latitude = latitude
	end
	if longitude then
		body.longitude = longitude
	end
	body = pre_msg(body, false, reply_to_message_id, reply_markup)
	return request('sendLocation', body)
end

function _M.sendVenue(chat_id, latitude, longitude, title, address, foursquare_id, disable_notification,
	reply_to_message_id, reply_markup)
	local body = {
		chat_id = chat_id,
		latitude = latitude,
		longitude = longitude
	}
	if title then
		body.title = title
	end
	if address then
		body.address = address
	end
	if foursquare_id then
		body.foursquare_id = foursquare_id
	end
	body = pre_msg(body, disable_notification, reply_to_message_id, reply_markup)
	return request('sendVenue', body)
end

function _M.sendContact(chat_id, phone_number, first_name, last_name, disable_notification, reply_to_message_id,
	reply_markup)
	local body = {
		chat_id = chat_id,
		phone_number = phone_number,
		first_name = first_name
	}
	if last_name then
		body.last_name = last_name
	end
	body = pre_msg(body, disable_notification, reply_to_message_id, reply_markup)
	return request('sendContact', body)
end

function _M.sendChatAction(chat_id, action)
	local body = {
		chat_id = chat_id,
		action = action
	}
	return request('sendChatAction', body)
end

function _M.getUserProfilePhotos(user_id, offset, limit)
	local body = {
		user_id = user_id
	}
	if offset then
		body.offset = offset
	end
	if limit then
		body.limit = limit
	end
	return request('getUserProfilePhotos', body)
end

function _M.getFile(file_id)
	local body = {
		file_id = file_id
	}
	return request('getFile', body)
end

function _M.kickChatMember(chat_id, user_id, until_date)
	local body = {
		chat_id = chat_id,
		user_id = user_id
	}
	if until_date then
		body.until_date = until_date
	end
	return request('kickChatMember', body)
end

function _M.unbanChatMember(chat_id, user_id)
	local body = {
		chat_id = chat_id,
		user_id = user_id
	}
	return request('unbanChatMember', body)
end

function _M.restrictChatMember(chat_id, user_id, until_date, can_send_messages, can_send_media_messages,
	can_send_other_messages, can_add_web_page_previews)
	local body = {
		chat_id = chat_id,
		user_id = user_id
	}
	if until_date then
		body.until_date = until_date
	end
	if can_send_messages then
	body.can_send_messages = can_send_messages
	end
	if can_send_media_messages then
	body.can_send_media_messages = can_send_media_messages
	end
	if can_send_other_messages then
	body.can_send_other_messages = can_send_other_messages
	end
	if can_add_web_page_previews then
		body.can_add_web_page_previews = can_add_web_page_previews
	end
	return request('restrictChatMember', body)
end

function _M.promoteChatMember(chat_id, user_id, can_change_info, can_post_messages, can_edit_messages,
	can_delete_messages, can_invite_users, can_restrict_members, can_pin_messages, can_promote_members)
	local body = {
		chat_id = chat_id,
		user_id = user_id
	}
	if can_change_info then
		body.can_change_info = can_change_info
	end
	if can_post_messages then
		body.can_post_messages = can_post_messages
	end
	if can_edit_messages then
		body.can_edit_messages = can_edit_messages
	end
	if can_delete_messages then
		body.can_delete_messages = can_delete_messages
	end
	if can_invite_users then
		body.can_invite_users = can_invite_users
	end
	if can_restrict_members then
		body.can_restrict_members = can_restrict_members
	end
	if can_pin_messages then
		body.can_pin_messages = can_pin_messages
	end
	if can_promote_members then
		body.can_promote_members = can_promote_members
	end
	return request('restrictChatMember', body)
end

function _M.exportChatInviteLink(chat_id)
	local body = {
		chat_id = chat_id
	}
	return request('exportChatInviteLink', body)
end

function _M.setChatPhoto(chat_id, photo)
	local body = {
		chat_id = chat_id,
		photo = photo
	}
	return request('setChatPhoto', body)
end

function _M.deleteChatPhoto(chat_id)
	local body = {
		chat_id = chat_id
	}
	return request('deleteChatPhoto', body)
end

function _M.setChatTitle(chat_id, title)
	local body = {
		chat_id = chat_id,
		title = title
	}
	return request('setChatTitle', body)
end

function _M.setChatDescription(chat_id, description)
	local body = {
		chat_id = chat_id,
		description = description
	}
	return request('setChatDescription', body)
end

function _M.pinChatMessage(chat_id, message_id, disable_notification)
	local body = {
		chat_id = chat_id,
		message_id = message_id
	}
	if disable_notification then
		body.disable_notification = disable_notification
	end
	return request('pinChatMessage', body)
end

function _M.unpinChatMessage(chat_id)
	local body = {
		chat_id = chat_id
	}
	return request('unpinChatMessage', body)
end

function _M.leaveChat(chat_id)
	local body = {
		chat_id = chat_id
	}
	return request('leaveChat', body)
end

function _M.getChat(chat_id)
	local body = {
		chat_id = chat_id
	}
	return request('getChat', body)
end

function _M.getChatAdministrators(chat_id)
	local body = {
		chat_id = chat_id
	}
	return request('getChatAdministrators', body)
end

function _M.getChatMembersCount(chat_id)
	local body = {
		chat_id = chat_id
	}
	return request('getChatMembersCount', body)
end

function _M.getChatMember(chat_id, user_id)
	local body = {
		chat_id = chat_id,
		user_id = user_id
	}
return request('getChatMember', body)
end

function _M.answerCallbackQuery(callback_query_id, text, show_alert, cache_time)
	local body = {
		callback_query_id = callback_query_id
	}
	if text then
		body.text = text
	end
	if show_alert then
		body.show_alert = show_alert
	end
	if cache_time then
		body.cache_time = cache_time
	end
	return request('answerCallbackQuery', body)
end

-- Updating messages

function _M.editMessageText(chat_id, message_id, inline_message_id, text, parse_mode, disable_web_page_preview,
	reply_markup)
	local body = {}
	body = pre_edit(body, chat_id, message_id, inline_message_id)
	body = pre_text(body, text, parse_mode, disable_web_page_preview)
	body = pre_msg(body, false, false, reply_markup)
	return request('editMessageText', body)
end

function _M.editMessageCaption(chat_id, message_id, inline_message_id, caption, reply_markup)
	local body = {}
	if caption then
		body.caption = caption
	end
	body = pre_edit(body, chat_id, message_id, inline_message_id)
	body = pre_msg(body, false, false, reply_markup)
	return request('editMessageCaption', body)
end

function _M.editMessageReplyMarkup(chat_id, message_id, inline_message_id, reply_markup)
	local body = {}
	body = pre_edit(body, chat_id, message_id, inline_message_id)
	body = pre_msg(body, false, false, reply_markup)
	return request('editMessageReplyMarkup', body)
end

function _M.deleteMessage(chat_id, message_id)
	local body = {
		chat_id = chat_id,
		message_id = message_id
	}
	return request('deleteMessage', body)
end

-- Inline mode

function _M.answerInlineQuery(inline_query_id, results, cache_time, is_personal, switch_pm_text, switch_pm_parameter)
	local body = {
		inline_query_id = inline_query_id,
		results = results
	}
	if cache_time then
		body.cache_time = cache_time
	end
	if is_personal then
		body.is_personal = is_personal
	end
	if switch_pm_text then
		body.switch_pm_text = switch_pm_text
	end
	if switch_pm_parameter then
		body.switch_pm_parameter = switch_pm_parameter
	end
	return request('answerInlineQuery', body)
end

-- Payments

function _M.sendInvoice(chat_id, title, description, payload, provider_token, start_parameter, currency, prices,
	photo_url, photo_width, photo_height, need_name, need_phone_number, need_email, need_shipping_address, is_flexible,
	disable_notification, reply_to_message_id, reply_markup)
	local body = {
		chat_id = chat_id,
		title = title,
		description = description,
		payload = payload,
		provider_token = provider_token,
		start_parameter = start_parameter,
		currency = currency,
		prices = prices
	}
	if photo_url then
		body.photo_url = photo_url
	end
	if photo_width then
		body.photo_width = photo_width
	end
	if photo_height then
		body.photo_height = photo_height
	end
	if need_name then
		body.need_name = need_name
	end
	if need_phone_number then
		body.need_phone_number = need_phone_number
	end
	if need_email then
		body.need_email = need_email
	end
	if need_shipping_address then
		body.need_shipping_address = need_shipping_address
	end
	if is_flexible then
		body.is_flexible = is_flexible
	end
	body = pre_msg(body, disable_notification, reply_to_message_id, reply_markup)
	return request('sendInvoice', body)
end

function _M.answerShippingQuery(shipping_query_id, ok, shipping_options, error_message)
	local body = {
		shipping_query_id = shipping_query_id,
		ok = ok
	}
	if shipping_options then
		body.shipping_options = shipping_options
	end
	if error_message then
		body.error_message = error_message
	end
	return request('answerShippingQuery', body)
end

function _M.answerPreCheckoutQuery(pre_checkout_query_id, ok, error_message)
	local body = {
		pre_checkout_query_id = pre_checkout_query_id,
		ok = ok
	}
	if error_message then
		body.error_message = error_message
	end
	return request('answerPreCheckoutQuery', body)
end

-- Games

function _M.sendGame(chat_id, game_short_name, disable_notification, reply_to_message_id, reply_markup)
	local body = {
		chat_id = chat_id,
		game_short_name = game_short_name
	}
	body = pre_msg(body, disable_notification, reply_to_message_id, reply_markup)
	request('sendGame', body)
end

function _M.setGameScore(user_id, score, force, disable_edit_message, chat_id, message_id, inline_message_id)
	local body = {
		user_id = user_id,
		score = score
	}
	if force then
		body.force = force
	end
	if disable_edit_message then
		body.disable_edit_message = disable_edit_message
	end
	body = pre_edit(body, chat_id, message_id, inline_message_id)
	return request('setGameScore', body)
end

function _M.getGameHighScores(user_id, chat_id, message_id, inline_message_id)
	local body = {
		user_id = user_id
	}
	body = pre_edit(body, chat_id, message_id, inline_message_id)
	return request('getGameHighScores', body)
end

return _M
