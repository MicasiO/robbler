local lfs = require("lfs")
local json = require("dkjson")

local files = {}

local config_dir = os.getenv("HOME") .. "/.config/robbler"
local keys_file = config_dir .. "/keys.json"

function files.ensure_config_dir()
	local attr = lfs.attributes(config_dir)
	if attr and attr.mode == "directory" then
		return true
	end

	local ok, err = lfs.mkdir(config_dir)
	if not ok then
		return false, err
	end

	return true
end

function files.keys_exist()
	local file = io.open(keys_file, "r")
	if not file then
		return nil
	end

	local content = file:read("*a")
	if content:len() == 0 then
		file:close()
		return nil
	end
	local obj, _, err = json.decode(content, 1, nil)
	if err then
		file:close()
		return nil, "Error reading keys.json: " .. err
	end

	if not obj.api_key or not obj.shared_key or not obj.session_key then
		file:close()
		return nil
	end

	return obj
end

function files.write_keys(api_key, shared_key, session_key)
	local file, err = io.open(keys_file, "w")
	if not file then
		return false, "Could not open keys.json file: " .. tostring(err)
	end

	local obj = {
		api_key = api_key,
		shared_key = shared_key,
		session_key = session_key,
	}

	local str = json.encode(obj, { indent = true })

	local ok, write_err = file:write(str)
	file:close()
	if not ok then
		return false, "Writing to keys.json failed: " .. tostring(write_err)
	end

	return true
end

return files
