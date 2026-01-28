--[[
    This file is part of mpv-auto-torrent-title
    https://github.com/ExiledEye/mpv-auto-torrent-title

    start_torrent_metadata.lua
    Author: Exiled Eye
    Version: 1.0.1
    Description: Local server starter module.

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
local server_process = nil
local is_windows = package.config:sub(1,1) == "\\"
local is_mac = package.config:sub(1,1) == "/" and os.execute("uname") == 0
local is_linux = not is_windows and not is_mac -- Unused

loghelper.consolelog_debug(options.verbose_debuglog,"Local torrent-metadata server starter loaded")

-- Start server, requires pnpm.
local function start_server()
    loghelper.consolelog_debug(options.verbose_debuglog,"Starting torrent-metadata server...")

    local args
    if is_windows then
        args = {"cmd", "/c", "cd", "/d", options.server_path, "&&", "pnpm", "dev"}
    else
        args = {"sh", "-c", "cd '" .. options.server_path .. "' && pnpm dev"}
    end

    local res = mp.command_native({
        name = "subprocess",
        playback_only = false,
        detach = true,
        args = args
    })

    server_process = res or {}
    if server_process.pid then
        loghelper.consolelog_info(options.verbose_infolog,"Server start command executed, PID=" .. tostring(server_process.pid))
    else
        loghelper.consolelog_info(options.verbose_infolog,"Server start command executed (no PID).")
    end
end

-- Stop server
local function stop_server()
    loghelper.consolelog_debug(options.verbose_debuglog,"Stopping torrent-metadata server...")

    if server_process and server_process.pid then
        local pid = tostring(server_process.pid)
        loghelper.consolelog_debug(options.verbose_debuglog,"Killing server PID " .. pid)

        if is_windows then
            mp.command_native({
                name = "subprocess",
                playback_only = false,
                args = {"taskkill", "/PID", pid, "/F", "/T"}
            })
        else
            mp.command_native({
                name = "subprocess",
                playback_only = false,
                args = {"kill", "-9", pid}
            })
        end

        server_process = nil
        return
    end

    loghelper.consolelog_debug(options.verbose_debuglog,"No tracked PID for server; attempting fallback to kill any 'node' processes")
    if is_windows then
        mp.command_native({
            name = "subprocess",
            playback_only = false,
            args = {"taskkill", "/F", "/IM", "node.exe", "/T"}
        })
    else
        mp.command_native({
            name = "subprocess",
            playback_only = false,
            args = {"pkill", "-f", "node"}
        })
    end
end

-- Load script
if options.server_path ~= "undefined" then
    loghelper.consolelog_debug(options.verbose_debuglog,"server_path = " .. tostring(options.server_path))
    start_server()
else
    mp.msg.error("Local server path not defined: cannot start local server. Please set server_path in mpv-auto-torrent-title.conf")
end

-- Kill server based on choosen option
if options.stop_server_on_exit then
    mp.register_event("shutdown", stop_server)
end