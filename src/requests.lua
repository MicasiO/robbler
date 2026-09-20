local request = require("http.request")
local util = require("http.util")
local md5 = require("md5")
local json = require("dkjson")

local requests = {}

local get_token, get_auth, get_session

function requests.fetch(url, params, method)
	local query_string = util.dict_to_query(params)

	local req = request.new_from_uri(url .. "?" .. query_string)
	req.headers:upsert(":method", method)

	local headers, stream = req:go()
	if not stream then
		return nil, "Network error: " .. tostring(headers)
	end

	local body = stream:get_body_as_string()

	local data, _, err = json.decode(body)
	if err then
		return nil, "JSON decode error: " .. tostring(err)
	end

	if data.error then
		return nil, "Last.fm error: " .. tostring(data.error) .. ": " .. tostring(data.message)
	end

	return data
end

function requests.auth_user(api_key, shared_key)
	local token, token_err = get_token(api_key)
	if not token then
		return nil, token_err
	end

	get_auth(token, api_key)
	print("Press ENTER after you've clicked allow in the browser")
	local _ = io.read()

	local session, session_err = get_session(token, api_key, shared_key)
	if not session then
		return nil, session_err
	end

	return session
end

function get_token(api_key)
	local token_url = "https://ws.audioscrobbler.com/2.0/"
	local token_params = {
		method = "auth.getToken",
		format = "json",
		api_key = api_key,
	}

	local token_res, err = requests.fetch(token_url, token_params, "GET")
	if not token_res then
		return nil, "Failed to get token - " .. err
	end

	return token_res.token
end

function get_auth(token, api_key)
	local auth_url = "http://www.last.fm/api/auth/"
	local auth_params = {
		token = token,
		api_key = api_key,
	}

	os.execute("xdg-open '" .. auth_url .. "?" .. util.dict_to_query(auth_params) .. "'")
end

function get_session(token, api_key, shared_secret)
	local sig_string = "api_key" .. api_key .. "methodauth.getSessiontoken" .. token .. shared_secret
	local api_sig = md5.sumhexa(sig_string)

	local scrobble_url = "https://ws.audioscrobbler.com/2.0/"
	local session_params = {
		method = "auth.getSession",
		api_key = api_key,
		token = token,
		api_sig = api_sig,
		format = "json",
	}

	local session_res, err = requests.fetch(scrobble_url, session_params, "GET")
	if not session_res then
		return nil, "Failed to create session key - " .. err
	end

	return session_res.session.key
end

return requests
