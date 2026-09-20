local files = require("src.files")
local requests = require("src.requests")

local function api_setup()
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

local function device_setup()
	io.write("Enter your product ID: ")
	local product_id = files.validate_id(io.read("*l"))

	if not product_id then
		print("Cancelled")
		os.exit(1)
	end

	io.write("Enter your vendor ID: ")
	local vendor_id = files.validate_id(io.read("*l"))

	if not vendor_id then
		print("Cancelled")
		os.exit(1)
	end

	local write_device, write_err = files.write_device(product_id, vendor_id)
	if not write_device then
		print(write_err)
		os.exit(1)
	end
end

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
	api_setup()
end

local device, device_err = files.device_exists()
if device_err then
	print(device_err)
	os.exit(1)
end

if not device then
	device_setup()
end
