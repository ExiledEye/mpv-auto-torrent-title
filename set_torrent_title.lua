--[[
    This file is part of mpv-auto-torrent-title
    https://github.com/ExiledEye/mpv-auto-torrent-title

    start_torrent_metadata.lua
    Author: Exiled Eye
    Version: 1.0.1
    Description: Title logic module.

    Copyright (c) 2026 Exiled Eye
    Licensed under the MPL-2.0 License.
    Refer to the LICENSE file for details.
]]

local options = { -- Options which can be changed in the mpv-auto-torrent-title.conf file
    use_stremio_service = true,
    fallback_to_torrentmetadata = false,
    stremio_endpoint = "undefined",
    
    use_local_server = false,
    fallback_to_local = false,
    skip_local_check = false,
    stop_server_on_exit = true,
    server_path = "undefined",
    local_server_url = "undefined",
    remote_server_url = "undefined",
    torrent_port = "undefined",

    set_title_when = "undefined",
    verbose_infolog = false,
    verbose_debuglog = false,
    verbose_osdlog = false,
    enable_cache = true,
    cache_file_path = "undefined",

    trim = "undefined",
    trim_extension= true,
    trim_spacing = false,
    trim_delete = true,
    trim_suffix_only = true,
    trim_preserve_middle = true,
    trim_protect_prefixes = true,

    check_updates = true,
    update_check_interval = 72
}
require("mp.options").read_options(options, "mpv-auto-torrent-title")
-- Kept the full table load even if not strictly needed to avoid mpv console warnings spam
local loghelper = require "loghelper"

function _G.torrent_title_cleanup()
    loghelper.consolelog_debug(options.verbose_debuglog,"Cleaning up torrent title script...")
    _G.torrent_title_cleanup = nil
end
if not _G.loaded_torrent_hash then
    _G.loaded_torrent_hash = ""
end
if _G.loaded_torrent_hash == _G.extracted_torrent_hash then
    return
end
_G.loaded_torrent_hash = _G.extracted_torrent_hash

loghelper.consolelog_debug(options.verbose_debuglog,"Title script loaded")

local utils = require 'mp.utils'
local server_url =
    (options.use_local_server == false)
    and options.remote_server_url
    or options.local_server_url
if(options.use_stremio_service) then
    server_url = options.stremio_endpoint
end
-- Caching stuff
local cache = {}

local function get_cache_path()
    local path = options.cache_file_path
    -- Default to script directory if undefined
    if not path or path == "undefined" or path == "" then
        path = mp.get_script_directory()
    end

    -- Ensure it treats the path as a directory add slash if missing
    local last_char = path:sub(-1)
    if last_char ~= "/" and last_char ~= "\\" then
        path = path .. "/"
    end

    return path .. "title_cache.txt"
end

local function cache_load()
    if not options.enable_cache then return end

    -- pcall catches any crash inside the function and prevents script failure if cache read or write fails
    local status, err = pcall(function()
        local full_path = get_cache_path()
        local f = io.open(full_path, "r")
        
        if not f then return end

        for line in f:lines() do
            local hash, title = line:match("^(%S+)%s+(.+)$")
            if hash and title then
                cache[hash] = title
            end
        end
        f:close()
        loghelper.consolelog_debug(options.verbose_debuglog, "Loaded title cache from: " .. full_path)
    end)

    if not status then
        loghelper.consolelog_debug(true, "CACHE ERROR (Read): " .. tostring(err))
    end
end

local function cache_save(hash, title)
    if not options.enable_cache then return end
    if not hash or not title then return end

    cache[hash] = title

    local status, err = pcall(function()
        local full_path = get_cache_path()
        local tmp = full_path .. ".tmp"
        
        local f = io.open(tmp, "w")
        if not f then
            error("Could not write to " .. full_path .. " (Check if directory exists)")
        end

        for h, t in pairs(cache) do
            f:write(h .. " " .. t .. "\n")
        end

        f:close()
        os.remove(full_path)
        os.rename(tmp, full_path)
    end)

    if not status then
        loghelper.consolelog_debug(true, "CACHE ERROR (Write): " .. tostring(err))
    end
end

cache_load()
_G.title_cache_save = cache_save

-- Title trimming stuff
local function apply_trimming(title)
    title = title:gsub("%s+", " "):gsub("^%s*(.-)%s*$", "%1")

    if options.trim_extension then
        title = title:gsub("%.[%w%d]+$", "")
    end

    if options.trim_spacing then
        title = title:gsub("%.", " ")
        title = title:gsub("%s+", " ")
    end

    if not options.trim or options.trim == "undefined" then
        return title
    end

    local trim_chars = {}
    for c in options.trim:gmatch("[%S]") do
        trim_chars[c] = true
    end

    local function extract_prefix(str)
        if not options.trim_protect_prefixes then
            return "", str
        end

        local prefix = ""
        local rest = str

        while true do
            local open = rest:match("^%s*([%[%(%{<])")
            if not open then break end

            local block = rest:match("^%s*(%" .. open .. ".-%" .. open:gsub("([%(%)%[%]{}<>])","%%%1") .. ")")
            if not block then break end

            prefix = prefix .. " " .. block
            rest = rest:gsub("^%s*%" .. open .. ".-%" .. open:gsub("([%(%)%[%]{}<>])","%%%1"), "", 1)
        end

        return prefix:gsub("^%s*(.-)%s*$", "%1"), rest:gsub("^%s*(.-)%s*$", "%1")
    end

    local prefix, remainder = extract_prefix(title)

    -- Corrected remove_suffix function
    local function remove_suffix(str)
        str = str:gsub("%s+$", "")  -- trim trailing spaces

        if options.trim_delete then
            -- Remove all consecutive bracketed blocks at the end
            local pattern = "%s*[" .. options.trim:gsub("(%W)","%%%1") .. "][^" .. options.trim:gsub("(%W)","%%%1") .. "]-[" .. options.trim:gsub("(%W)","%%%1") .. "]%s*$"
            while str:match(pattern) do
                str = str:gsub(pattern, "")
            end
        else
            -- Keep content inside brackets
            local pattern = "%s*[" .. options.trim:gsub("(%W)","%%%1") .. "](.-)[" .. options.trim:gsub("(%W)","%%%1") .. "]%s*$"
            while str:match(pattern) do
                str = str:gsub(pattern, " %1")
            end
        end

        str = str:gsub("%s+", " "):gsub("^%s*(.-)%s*$", "%1")
        return str
    end

    local function trim_all(str)
        local class = {}
        for c,_ in pairs(trim_chars) do
            table.insert(class, "%" .. c)
        end

        if #class > 0 then
            local pat = "[" .. table.concat(class) .. "]"
            str = str:gsub(pat, "")
        end

        return str:gsub("%s+", " "):gsub("^%s*(.-)%s*$", "%1")
    end

    local function remove_middle(str)
        if not options.trim_preserve_middle then
            return trim_all(str)
        end
        return trim_all(str)
    end

    local cleaned
    if options.trim_suffix_only then
        cleaned = remove_suffix(remainder)
    else
        cleaned = remove_middle(remainder)
    end

    local final = (prefix .. " " .. cleaned)
        :gsub("%s+", " ")
        :gsub("^%s*(.-)%s*$", "%1")

    return final
end

-- Main function (torrent-metadata)
local function set_title_from_torrent_metadata(path, retry)
    retry = retry or 0
    local max_retries = 5

    -- Check cache first
    local cached = cache[_G.extracted_torrent_hash]
    if cached then
        local t = apply_trimming(cached)
        mp.set_property("force-media-title", t)
        loghelper.consolelog_info(options.verbose_infolog,"Loaded cached title: " .. t)
        loghelper.osdlog(options.verbose_osdlog,"Loaded cached title: " .. t,1.5)
        return
    end

    local result = mp.command_native({
        name = "subprocess",
        playback_only = false,
        capture_stdout = true,
        capture_stderr = true,
        args = {
            "curl", "-s", "-X", "POST", server_url,
            "-H", "Content-Type: application/x-www-form-urlencoded",
            "-d", "query=" .. _G.extracted_torrent_hash
        }
    })

    if result.status == 0 and result.stdout and result.stdout ~= "" then
        local json = utils.parse_json(result.stdout)
        local torrent_name = nil

        if json and json.data and json.data.name then
            torrent_name = json.data.name
        end

        if torrent_name then
            local final_name = apply_trimming(torrent_name)
            mp.set_property("force-media-title", final_name)
            loghelper.consolelog_info(options.verbose_infolog,"Title set: " .. final_name)
            loghelper.osdlog(options.verbose_osdlog,"Title set: " .. final_name,1.5)

            if options.enable_cache then
                cache_save(_G.extracted_torrent_hash, torrent_name)
            end
        else
            mp.msg.warn("Could not extract name, retrying...")
            if retry < max_retries then
                mp.add_timeout(0.02, function()
                    set_title_from_torrent_metadata(path, retry + 1)
                end)
            else
                mp.msg.error("Metadata extract failed after retries.")
            end
        end
    else
        mp.msg.error("API request failed: " ..
            tostring(result.status) .. " - " .. tostring(result.stderr))
    end
end

-- Main function (Stremio service)
local function set_title_from_stremio_service(path, retry)
    retry = retry or 0
    local max_retries = 5

    local cached = cache[_G.extracted_torrent_hash]
    if cached then
        local t = apply_trimming(cached)
        mp.set_property("force-media-title", t)
        loghelper.consolelog_info(options.verbose_infolog,"Loaded cached title: " .. t)
        loghelper.consolelog_osdlog(options.verbose_osdlog,"Loaded cached title: " .. t,1.5)
        return
    end
    local file_index = string.match(path, _G.extracted_torrent_hash .. "/(%d+)")

    if not file_index then
        mp.msg.warn("Could not find file index in URL, defaulting to general stats")
        return
    end
    local stats_url = server_url .. _G.extracted_torrent_hash .. "/" .. file_index .. "/stats.json"

    local result = mp.command_native({
        name = "subprocess",
        playback_only = false,
        capture_stdout = true,
        capture_stderr = true,
        args = { "curl", "-s", stats_url }
    })

    if result.status == 0 and result.stdout and result.stdout ~= "" then
        local json = utils.parse_json(result.stdout)

        if json and json.streamName then
            local final_name = apply_trimming(json.streamName)
            
            mp.set_property("force-media-title", final_name)
            loghelper.consolelog_info(options.verbose_infolog,"Title set: " .. final_name)
            loghelper.osdlog(options.verbose_osdlog,"Title set: " .. final_name,1.5)

            if options.enable_cache then
                cache_save(_G.extracted_torrent_hash, json.streamName)
            end
        else
            mp.msg.warn("streamName not found yet, retrying...")
            if retry < max_retries then
                mp.add_timeout(0.5, function()
                    set_title_from_torrent_metadata(path, retry + 1)
                end)
            else
                mp.msg.error("Failed to extract streamName after retries.")
            end
        end
    else
        mp.msg.error("API request failed: " .. tostring(result.status))
    end
end

-- Load script
local path = mp.get_property("path", "")
if options.use_stremio_service then
    set_title_from_stremio_service(path)
else
    set_title_from_torrent_metadata(path)
end
