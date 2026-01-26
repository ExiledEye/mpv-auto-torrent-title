--[[
    This file is part of mpv-auto-torrent-title
    https://github.com/ExiledEye/mpv-auto-torrent-title

    loghelper.lua
    Author: Exiled Eye
    Version: 1.0
    Description: Logging helper.

    Copyright (c) 2026 Exiled Eye
    Licensed under the MPL-2.0 License.
    Refer to the LICENSE file for details.
]]
local M = {}

function M.consolelog_info(log,msg)
    if log then
        mp.msg.info(msg)
    end
end

function M.consolelog_debug(log,msg)
    if log then
        mp.msg.info(msg)
    end
end

function M.osdlog(log,msg,duration)
    if log then
        mp.osd_message(msg,duration)
    end
end

return M