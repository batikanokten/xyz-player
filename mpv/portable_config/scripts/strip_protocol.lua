-- xyz:// protokolünü temizleyen, URL decode eden, Referer ve Başlık ayarlayan hook
local utils = require 'mp.utils'

local DEFAULT_UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"

local function log_to_file(text)
    local f = io.open("D:/xyz-player/mpv_launch.log", "a")
    if f then
        f:write(os.date("[%Y-%m-%d %H:%M:%S] ") .. text .. "\n")
        f:close()
    end
end

local function url_decode(str)
    if not str then return "" end
    str = str:gsub("+", " ")
    str = str:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end)
    return str
end

-- Priority 5: ytdl_hook (priority 10) çalışmadan ÖNCE xyz:// protokolünü temizle
mp.add_hook("on_load", 5, function()
    local path = mp.get_property("stream-open-filename", "")
    if not path or path == "" then
        path = mp.get_property("path", "")
    end

    log_to_file("RAW INCOMING: " .. tostring(path))

    if path and (path:find("^xyz://") or path:find("^xyz:")) then
        local raw = path:gsub("^xyz://", ""):gsub("^xyz:", "")
        raw = raw:gsub('^"', ''):gsub('"$', '')

        local clean_url = nil
        local ref = nil
        local title = nil

        -- Format 1: xyz://open?url=...&ref=...&title=...
        if raw:find("[?&]url=") then
            local query_url = raw:match("[?&]url=([^&]+)")
            local query_ref = raw:match("[?&]ref=([^&]+)")
            local query_title = raw:match("[?&]title=([^&]+)")

            if query_url then
                clean_url = url_decode(query_url)
            end
            if query_ref and query_ref ~= "" then
                ref = url_decode(query_ref)
            end
            if query_title and query_title ~= "" then
                title = url_decode(query_title)
            end
        end

        -- Format 2: xyz://https://...#ref=... (Eski / alternatif format)
        if not clean_url then
            raw = url_decode(raw)
            raw = raw:gsub("^open/?", "")
            if raw:sub(-1) == "/" then
                raw = raw:sub(1, -2)
            end

            local target, r = raw:match("^(.-)#ref=(.+)$")
            if target and r then
                clean_url = target
                ref = url_decode(r)
            else
                clean_url = raw
            end
        end

        if clean_url then
            clean_url = clean_url:gsub('^%s+', ''):gsub('%s+$', '')
            clean_url = clean_url:gsub('^"', ''):gsub('"$', '')
        end
        if ref then
            ref = ref:gsub('^%s+', ''):gsub('%s+$', '')
            ref = ref:gsub('^"', ''):gsub('"$', '')
        end

        -- Chrome / Windows tarafından silinen iki nokta üst üste (colon) düzeltmesi
        if clean_url:find("^https//") then
            clean_url = "https://" .. clean_url:sub(8)
        elseif clean_url:find("^http//") then
            clean_url = "http://" .. clean_url:sub(7)
        elseif clean_url:find("^https:/") and not clean_url:find("^https://") then
            clean_url = "https://" .. clean_url:sub(8)
        elseif clean_url:find("^http:/") and not clean_url:find("^http://") then
            clean_url = "http://" .. clean_url:sub(7)
        end

        if clean_url and clean_url ~= "" then
            mp.set_property("stream-open-filename", clean_url)
            mp.set_property("file-local-options/user-agent", DEFAULT_UA)
            if title and title ~= "" then
                mp.set_property("file-local-options/force-media-title", title)
            end
            if ref and ref ~= "" then
                mp.set_property("file-local-options/referrer", ref)
                mp.set_property("referrer", ref)
                log_to_file("SUCCESS: Playing " .. clean_url .. " [Referer: " .. ref .. "]")
            else
                log_to_file("SUCCESS: Playing " .. clean_url)
            end
        else
            log_to_file("ERROR: clean_url is empty!")
        end
    end
end)
