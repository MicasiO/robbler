local files = require("src.files")
local requests = require("src.requests")

local config_dir, config_err = files.ensure_config_dir()

if not config_dir then
	print(config_err)
	os.exit(1)
end

local keys, keys_err = files.keys_exist()
if keys_err then
	print(keys_err)
	os.exit(1)
end

if not keys then
	io.write("Enter your Last.fm API key: ")
	local api_key = io.read("*l")

	if not api_key or api_key:len() == 0 then
		print("Cancelled")
		os.exit(1)
	end

	io.write("Enter your Last.fm shared key: ")
	local shared_key = io.read("*l")

	if not shared_key or shared_key:len() == 0 then
		print("Cancelled")
		os.exit(1)
	end

	local session_key, err = requests.auth_user(api_key, shared_key)
	if not session_key then
		print(err)
		os.exit(1)
	end

	local write_keys, write_err = files.write_keys(api_key, shared_key, session_key)
	if not write_keys then
		print(write_err)
		os.exit(1)
	end
end

print("Done!")
