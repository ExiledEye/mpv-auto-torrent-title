--[[
    This file is part of mpv-auto-torrent-title
    https://github.com/ExiledEye/mpv-auto-torrent-title

    start_torrent_metadata.lua
    Author: Exiled Eye
    Version: 1.0
    Description: Main script.

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
local current_version = "1.0"
local utils = require 'mp.utils'
local loghelper = require "loghelper"
local base = mp.get_script_directory()
local options_path = mp.command_native({"expand-path", "~~/script-opts/mpv-auto-torrent-title.conf"})
loghelper.consolelog_debug(options.verbose_debuglog,"Script directory: " .. tostring(base))
loghelper.consolelog_debug(options.verbose_debuglog,"Options file path: " .. tostring(options_path))

local function check_for_updates()
    local git_api_url = "https://api.github.com/repos/ExiledEye/mpv-auto-torrent-title/releases/latest"

    -- Modification time
    local meta = utils.file_info(options_path)
    local last_modified = 0
    if meta and meta.mtime then
        last_modified = meta.mtime
    end

    -- Compare with current time
    local current_time = os.time()
    if (current_time - last_modified) < (options.update_check_interval * 3600) then
        loghelper.consolelog_debug(options.verbose_infolog, "Too soon to check for updates")
        return -- Too soon to check
    end

    loghelper.consolelog_debug(options.verbose_infolog, "Checking for updates on GitHub...")

    mp.command_native_async({
        name = "subprocess",
        args = {"curl", "-s", git_api_url},
        playback_only = false,
        capture_stdout = true
    }, function(success, res, err)
        if success and res.status == 0 then
            local json = utils.parse_json(res.stdout)
            
            if json and json.tag_name then
                local remote_ver_str = json.tag_name:gsub("^v", "")
                local local_ver_str = current_version:gsub("^v", "")
                
                if remote_ver_str > local_ver_str then
                    mp.osd_message("mpv-auto-torrent-title: New version available: " .. json.tag_name, 7)
                    loghelper.consolelog_info(options.verbose_infolog, "New version available: " .. json.tag_name)
                    return -- Avoid touching the file so it keeps checking until updated
                else
                    loghelper.consolelog_info(options.verbose_infolog, "Script is up to date.")
                end

                -- Touch the file...
                local r = io.open(options_path, "rb")
                if r then
                    local content = r:read("*a")
                    r:close()
                    
                    if content then
                        local w = io.open(options_path, "wb")
                        if w then
                            w:write(content)
                            w:close()
                        end
                    end
                end
            end
        else
            mp.msg.warn("Failed to check for updates.")
        end
    end)
end

local function install_conf()
    local source = base .. "/mpv-auto-torrent-title.conf"
    
    local f = io.open(source, "r")
    if not f then
        source = base .. "/script-opts/mpv-auto-torrent-title.conf"
        f = io.open(source, "r")
        if not f then
            mp.msg.error("INSTALLER: Could not find source config file in " .. base)
            return
        end
    end
    f:close()

    local clean_base = base:gsub("\\", "/")
    local mpv_root = clean_base:match("^(.*)/scripts/")
    
    local dest_folder
    if mpv_root then
        dest_folder = mpv_root .. "/script-opts"
    else -- Fallback
        local up_one = clean_base:match("^(.*)/[^/]+$")
        local up_two = up_one and up_one:match("^(.*)/[^/]+$")
        if up_two then
            dest_folder = up_two .. "/script-opts"
        else
            dest_folder = mp.command_native({"expand-path", "~~/script-opts"}):gsub("\\", "/")
        end
    end

    local dest_path = dest_folder .. "/mpv-auto-torrent-title.conf"
    
    mp.msg.info("CONF-INSTALLER: Source: " .. source)
    mp.msg.info("CONF-INSTALLER: Target Folder: " .. dest_folder)

    local is_windows = package.config:sub(1,1) == "\\"
    
    if is_windows then
        local win_dest = dest_folder:gsub("/", "\\")
        os.execute('mkdir "' .. win_dest .. '" 2>nul') -- "2>nul" to hide the error.
    else
        os.execute('mkdir -p "' .. dest_folder .. '"')
    end

    local r = io.open(source, "rb")
    local w = io.open(dest_path, "wb")
    
    if r and w then
        w:write(r:read("*a"))
        r:close()
        w:close()
        mp.msg.info("Config installed successfully to: " .. dest_path)
        
        options_path = dest_path
        
        require("mp.options").read_options(options, "mpv-auto-torrent-title")
    else
        mp.msg.error("CONF-INSTALLER ERROR: Failed to write to " .. dest_path)
        if not w then 
            mp.msg.error("Write failed. Directory likely wasn't created.")
        end
    end
end

-- Config file failsafe
local function file_exists(path)
    local f = io.open(path, "r")
    if f then f:close() end
    return f ~= nil
end

if not file_exists(options_path) then
    mp.msg.error("Missing mpv-auto-torrent-title.conf in script-opts directory")
    install_conf()
    if file_exists(options_path) then
        mp.osd_message("mpv-auto-torrent-title.conf automatically installed. Configure the script and restart mpv.",10)
        return
    else
        mp.osd_message("Failed to install mpv-auto-torrent-title.conf. Please install it manually.",10)
        mp.msg.error("Failed to install mpv-auto-torrent-title.conf. Please install it manually.")
        return
    end
else
    require("mp.options").read_options(options, "mpv-auto-torrent-title")
end

local server_url = options.local_server_url
local title_script_path = base .. "/set_torrent_title.lua"
local starter_script_path = base .. "/start_torrent_metadata.lua"
loghelper.consolelog_debug(options.verbose_debuglog,"Detected script base directory = " .. tostring(base))

-- Torrent URL detection
local function is_torrent_url(path)
    if not path then return false end
    if path:match("^magnet:") or path:match("/[^/]+%.torrent([%?#]|$)") then
        loghelper.consolelog_info(options.verbose_infolog,"Detected torrent URL by magnet or .torrent pattern")
        return true
    end

    local hash40 = string.rep("%x", 40)
    local port_pattern = options.torrent_port ~= "undefined" and ":" .. options.torrent_port or ":%d+"
    local patterns = {
        "^https?://127%.0%.0%.1" .. port_pattern .. "/" .. hash40 .. "/%S*",
        "^https?://localhost" .. port_pattern .. "/" .. hash40 .. "/%S*",
    }

    for _, pat in ipairs(patterns) do
        if path:match(pat) then
            _G.extracted_torrent_hash = path:match("^http://[^:]+:%d+/([%x]+)")
            loghelper.consolelog_debug(options.verbose_debuglog,"Detected torrent URL on localhost, hash: " .. tostring(_G.extracted_torrent_hash))
            return _G.extracted_torrent_hash ~= nil
        end
    end
    return false
end

-- Cache
local title_cache = {}
if options.enable_cache then
    local function cache_file_path()
        local p = options.cache_file_path ~= "undefined" and options.cache_file_path or base
        if p:sub(-1) ~= "\\" and p:sub(-1) ~= "/" then p = p .. "/" end
        return p .. "title_cache.txt"
    end

    -- Load cache
    local f = io.open(cache_file_path(), "r")
    if f then
        for line in f:lines() do
            local hash, title = line:match("^(%S+)\t(.+)$")
            if hash and title then title_cache[hash] = title end
        end
        f:close()
    end

    -- Save cache function
    _G.title_cache_save = function(hash, title)
        title_cache[hash] = title
        local f = io.open(cache_file_path(), "a")
        if f then
            f:write(hash .. "\t" .. title .. "\n")
            f:close()
        end
    end
end

-- Check if local or remote server is operative
local function is_server_ready()
    local result = mp.command_native({
        name = "subprocess",
        playback_only = false,
        capture_stdout = true,
        capture_stderr = true,
        args = {"curl", "-s", "-m", "1", server_url}
    })
    return result and result.status == 0
end

local check_skipped = false
local function local_check()
    if not options.skip_local_check then
        return is_server_ready()
    else
        loghelper.consolelog_debug(options.verbose_debuglog,"Local server check skipped")
        check_skipped = true
        return true
    end
end

local function wait_for_server_and_load_title(retry_count)
    retry_count = retry_count or 0
    local max_retries = 15
    if local_check() then
        if not check_skipped then loghelper.consolelog_debug(options.verbose_debuglog,"Server operational, loading title script") end
        if _G.torrent_title_active and _G.torrent_title_cleanup then
            _G.torrent_title_cleanup()
            _G.torrent_title_active = false
        end
        local success, err = pcall(dofile, title_script_path)
        if not success then mp.msg.error("Failed to load title script: " .. tostring(err)) end
    elseif retry_count < max_retries then
        mp.add_timeout(0.010, function() wait_for_server_and_load_title(retry_count + 1) end)
    else
        mp.msg.error("Server not ready after " .. max_retries .. " attempts, loading title script anyway")
        if _G.torrent_title_active and _G.torrent_title_cleanup then
            _G.torrent_title_cleanup()
            _G.torrent_title_active = false
        end
        pcall(dofile, title_script_path)
    end
end

-- Script loading
local function set_title_local()
    if is_server_ready() then
        wait_for_server_and_load_title()
    else
        local success, err = pcall(dofile, starter_script_path)
        if success then wait_for_server_and_load_title() else mp.msg.error("Failed to load local server script: " .. tostring(err)) end
    end
end

local function set_title_remote()
    if _G.torrent_title_active and _G.torrent_title_cleanup then
        _G.torrent_title_cleanup()
        _G.torrent_title_active = false
    end
    pcall(dofile, title_script_path)
end

local function set_title_stremio()
    local success, err = pcall(dofile, starter_script_path)
    if success then wait_for_server_and_load_title() else mp.msg.error("Failed to load local server script: " .. tostring(err)) end
end

-- Main execution
local function check_and_execute()
    local path = mp.get_property("path", "")
    if not path or path == "" then return end
    loghelper.consolelog_debug(options.verbose_debuglog,"Current path: " .. tostring(path))
    if not is_torrent_url(path) then return end
    loghelper.consolelog_info(options.verbose_infolog,"Torrent detected, setting title...")

    if options.enable_cache and title_cache[_G.extracted_torrent_hash] then
        mp.set_property("force-media-title", title_cache[_G.extracted_torrent_hash])
        loghelper.consolelog_debug(options.verbose_debuglog,"Using cached title: " .. title_cache[_G.extracted_torrent_hash])
        return
    end

    if options.use_stremio_service then
        if options.fallback_to_torrentmetadata then
            server_url = options.stremio_endpoint
            if is_server_ready() then
                set_title_stremio()
                return
            else
                set_title_stremio()
                return
            end
        else
            server_url = options.local_server_url
        end
    end

    if options.use_local_server then
        set_title_local()
    else
        if options.fallback_to_local then
            server_url = options.remote_server_url
            if is_server_ready() then
                set_title_remote()
            else
                server_url = options.local_server_url
                set_title_local()
            end
        else
            set_title_remote()
        end
    end
end

if options.check_updates then
    check_for_updates()
end

-- Load script based on chosen event
if options.set_title_when == "file load" then
    mp.register_event("file-loaded", check_and_execute)
elseif options.set_title_when == "path change" then
    mp.observe_property("path", "string", check_and_execute)
else
    mp.msg.error("Invalid set_title_when config, plaease check mpv-auto-torrent-title.conf")
    mp.osd_message("mpv-auto-torrent-title: Invalid set_title_when config, please check mpv-auto-torrent-title.conf",10)
end