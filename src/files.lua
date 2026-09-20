local lfs = require("lfs")
local json = require("dkjson")

local files = {}

local config_dir = os.getenv("HOME") .. "/.config/robbler"
local keys_file = config_dir .. "/keys.json"
local device_file = config_dir .. "/device.json"

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

function files.device_exists()
	local file = io.open(device_file, "r")
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
		return nil, "Error reading device.json: " .. err
	end

	if not obj.vendor_id or not obj.product_id then
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

function files.write_device(product_id, vendor_id)
	local file, err = io.open(device_file, "w")
	if not file then
		return false, "Could not open device.json file: " .. tostring(err)
	end

	local obj = {
		product_id = product_id,
		vendor_id = vendor_id,
	}

	local str = json.encode(obj, { indent = true })

	local ok, write_err = file:write(str)
	file:close()
	if not ok then
		return false, "Writing to device.json failed: " .. tostring(write_err)
	end

	return true
end

function files.find_device(target_vid, target_pid)
	local handle, err = io.popen("ls /sys/block/")
	if not handle then
		return nil, "Failed to ls: " .. err
	end

	for dev in handle:lines() do
		local ph, ph_err = io.popen("udevadm info --query=property --name=/dev/" .. dev .. " 2>/dev/null")
		if not ph then
			handle:close()
			return nil, "Failed to udevadm: " .. ph_err
		end

		local props = ph:read("*a")
		ph:close()

		local vid = props:match("ID_VENDOR_ID=(%x+)")
		local pid = props:match("ID_MODEL_ID=(%x+)")

		if vid == target_vid and pid == target_pid then
			handle:close()
			return "/dev/" .. dev
		end
	end

	handle:close()
	return nil, "No matching devices found. Is it connected?"
end

function files.mount_device(dev_path)
	if not dev_path:match("^/dev/[%w%-_]+$") then
		return nil, "Invalid device path: " .. tostring(dev_path)
	end

	local handle, err = io.popen("udisksctl mount -b '" .. dev_path .. "' 2>&1")
	if not handle then
		return nil, "Failed to mount device: " .. err
	end
	local output = handle:read("*a")
	handle:close()

	local mount_path = output:match("at%s+(/[%w%-_/]+)")
	if not mount_path then
		return nil, "Failed to mount device"
	end

	return mount_path
end

function files.validate_id(id)
	if type(id) ~= "string" or not id:match("^%x%x%x%x$") then
		return nil, "Invalid VID/PID format: " .. tostring(id)
	end

	return id:lower()
end

-- local dev_path, err = find_block_device("0781", "5567")
-- if not dev_path then
-- 	error(err)
-- end
-- print("Found device:", dev_path)

return files
