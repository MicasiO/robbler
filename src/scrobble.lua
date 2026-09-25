local json = require("dkjson")

local scrobble = {}

local function first_of(tbl, ...)
	for _, key in ipairs({ ... }) do
		if tbl[key] then
			return tbl[key]
		end
	end
	return nil
end

-- removes entries older than 14 days
-- and entries which were not listened to enough
function scrobble.trim_log_by_date(log)
	local FOURTEEN_DAYS = 14 * 24 * 60 * 60
	local FOUR_MINUTES = 4 * 60 * 1000
	local cutoff = os.time() - FOURTEEN_DAYS

	local kept_lines = {}

	for line in log:gmatch("[^\r\n]+") do
		local timestamp_str, listened_str, duration_str = line:match("^(%d+):(%d+):(%d+):")
		local timestamp = timestamp_str and tonumber(timestamp_str)
		local listened = listened_str and tonumber(listened_str)
		local duration = duration_str and tonumber(duration_str)

		if timestamp and listened and duration and timestamp >= cutoff then
			if listened >= duration / 2 or listened > FOUR_MINUTES then
				table.insert(kept_lines, line)
			end
		end
	end

	return table.concat(kept_lines, "\n") .. "\n"
end

function scrobble.get_file_metadata(path)
	if type(path) ~= "string" or path:len() == 0 then
		return nil, "Invalid path"
	end

	local safe_path = path:gsub("'", "'\\''")
	local ffprobe, err = io.popen("ffprobe -v quiet -print_format json -show_format '" .. safe_path .. "' 2>&1")
	if not ffprobe then
		return nil, "Failed to run ffprobe: " .. tostring(err)
	end

	local output = ffprobe:read("*a")
	local ffprobe_close = ffprobe:close()

	if not ffprobe_close then
		return nil, "ffprobe failed: " .. output
	end

	local data, _, data_err = json.decode(output)
	if not data then
		return nil, "Failed to parse ffprobe output: " .. tostring(data_err)
	end

	local tags = data.format and data.format.tags or {}

	local normalized = {}
	for k, v in pairs(tags) do
		normalized[k:upper()] = v
	end

	if not normalized["ARTIST"] or not normalized["TITLE"] then
		return nil, "Missing artist or title tag"
	end

	local filtered = {
		artist = normalized["ARTIST"],
		track = normalized["TITLE"],
		album = normalized["ALBUM"],
		mbid = first_of(normalized, "MUSICBRAINZ_TRACKID", "MUSICBRAINZ TRACK ID", "MUSICBRAINZ_TRACK_ID"),
	}

	return filtered
end

function scrobble.get_log_metadata(log, mount_path)
	local data = {}

	local i = 1
	for line in log:gmatch("[^\r\n]+") do
		local timestamp_str, raw_path = line:match("^(%d+):%d+:%d+:(.+)$")
		if not timestamp_str or not raw_path then
			goto continue
		end

		local timestamp = tonumber(timestamp_str)
		local path = mount_path .. raw_path:gsub("^/<[^>]+>", "")

		local metadata, err = scrobble.get_file_metadata(path)
		if not metadata then
			print(err)
			goto continue
		end
		metadata.timestamp = timestamp

		table.insert(data, metadata)
                print("Parsed tracks: " .. i)
                i = i + 1
		::continue::
	end

	return data
end

return scrobble
