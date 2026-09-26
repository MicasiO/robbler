local request = require("http.request")
local util = require("http.util")
local md5 = require("md5")
local json = require("dkjson")

local requests = {}

local function get_token(api_key)
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

local function get_auth(token, api_key)
	local auth_url = "http://www.last.fm/api/auth/"
	local auth_params = {
		token = token,
		api_key = api_key,
	}

	os.execute("xdg-open '" .. auth_url .. "?" .. util.dict_to_query(auth_params) .. "'")
end

local function get_session(token, api_key, shared_secret)
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

local function build_scrobble_params(batch, api_key, session_key, shared_key)
	local params = {
		method = "track.scrobble",
		api_key = api_key,
		sk = session_key,
	}

	for i, entry in ipairs(batch) do
		local idx = i - 1
		params["artist[" .. idx .. "]"] = entry.artist
		params["track[" .. idx .. "]"] = entry.track
		params["timestamp[" .. idx .. "]"] = tostring(entry.timestamp)
		if entry.album then
			params["album[" .. idx .. "]"] = entry.album
		end
		if entry.mbid then
			params["mbid[" .. idx .. "]"] = entry.mbid
		end
	end

	local keys = {}
	for k in pairs(params) do
		table.insert(keys, k)
	end
	table.sort(keys)

	local sig_string = ""
	for _, k in ipairs(keys) do
		sig_string = sig_string .. k .. params[k]
	end
	sig_string = sig_string .. shared_key

	params.api_sig = md5.sumhexa(sig_string)
	params.format = "json"

	return params
end

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

function requests.post(url, params)
	local body = util.dict_to_query(params)

	local req = request.new_from_uri(url)
	req.headers:upsert(":method", "POST")
	req.headers:upsert("content-type", "application/x-www-form-urlencoded")
	req:set_body(body)

	local headers, stream = req:go()
	if not stream then
		return nil, "Network error: " .. tostring(headers)
	end

	local response_body = stream:get_body_as_string()

	local data, _, err = json.decode(response_body)
	if err then
		return nil, "JSON decode error: " .. tostring(err)
	end

	if data.error then
		return nil, "Last.fm error: " .. tostring(data.error) .. ": " .. tostring(data.message)
	end

	return data
end

-- splits up to batches of 50 and sends POST request to Last.fm
function requests.send_scrobble(data, api_key, session_key, shared_secret)
	local batches = {}
	local current_batch = {}
	for i, entry in ipairs(data) do
		table.insert(current_batch, entry)
		if #current_batch == 50 or i == #data then
			table.insert(batches, current_batch)
			current_batch = {}
		end
	end

	local scrobble_url = "https://ws.audioscrobbler.com/2.0/"
	local results = {}

	for _, batch in ipairs(batches) do
		local params = build_scrobble_params(batch, api_key, session_key, shared_secret)

		local response, err = requests.post(scrobble_url, params)
		if not response then
			print("Batch failed: " .. err)
		else
			table.insert(results, response)
		end

	end

	return results
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

return requests
