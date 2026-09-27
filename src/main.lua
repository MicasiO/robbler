local files = require("src.files")
local scrobble = require("src.scrobble")
local setup = require("src.setup")

local function cleanup(dev_path)
	local unmount, unmount_err = files.unmount_device(dev_path)
	if not unmount then
		print(unmount_err)
		os.exit(1)
	end
end

local keys, device = setup.start_setup()

local dev_path, dev_path_err = files.find_device(device.product_id, device.vendor_id)
if not dev_path then
	print(dev_path_err)
	os.exit(1)
end

local mount_path, mount_path_err = files.mount_device(dev_path)
if not mount_path then
	print(mount_path_err)
	os.exit(1)
end

local scrobble_log, scrobble_err = files.get_scrobble_log(mount_path)
if not scrobble_log then
	print(scrobble_err)
	cleanup(dev_path)
	os.exit(1)
end

local data = scrobble.get_log_metadata(scrobble_log, mount_path)

if #data > 0 then
	scrobble.run_scrobble(data, keys)

	local remove, err = os.remove(mount_path .. "/.rockbox/playback.log")
	if not remove then
		print("Failed to delete playback.log: " .. err)
	end
else
	print("No entries to scrobble")
end

cleanup(dev_path)
