-- ==========================================================================
-- XYZ Player - Modern OSD & Upscaler Controller (Vulkan / libplacebo)
-- ==========================================================================
local mp = require 'mp'
local ov = mp.create_osd_overlay("ass-events")

-- Sabit Sanal Yükseklik (1080p / 2K / 4K ekranlarda tutarlı ve büyük ölçekleme)
local BASE_VH = 600

-- Durum Değişkenleri
local state = {
    ui_visible = true,
    hud_visible = true,
    menu_open = false,
    last_mouse_x = -1,
    last_mouse_y = -1,
    last_activity = mp.get_time(),
    hide_timeout = 2.8,
    shader_mode = 1,
    last_active_shader = 1,
    toast_text = nil,
    toast_until = 0,
    -- Space basılı tutunca 2x hız durumu
    space_holding = false,
    space_timer = nil,
    saved_speed = 1.0,
}

-- Kategorili Upscaler & Shader Profilleri (Anime + Film/YouTube)
local SHADER_PRESETS = {
    -- ANİME & ÇİZİM (Anime4K CNN AI)
    [1] = {
        name = "Anime4K: Dengeli (Restore + Upscale M)",
        short = "Anime4K M",
        category = "anime",
        files = "D:/xyz-player/shaders/Anime4K_Restore_CNN_M.glsl;D:/xyz-player/shaders/Anime4K_Upscale_CNN_x2_M.glsl"
    },
    [2] = {
        name = "Anime4K: Yüksek Kalite (Restore + Upscale L)",
        short = "Anime4K L",
        category = "anime",
        files = "D:/xyz-player/shaders/Anime4K_Restore_CNN_L.glsl;D:/xyz-player/shaders/Anime4K_Upscale_CNN_x2_L.glsl"
    },
    [3] = {
        name = "Anime4K: Ultra Kalite (Restore + Upscale VL)",
        short = "Anime4K VL",
        category = "anime",
        files = "D:/xyz-player/shaders/Anime4K_Restore_CNN_VL.glsl;D:/xyz-player/shaders/Anime4K_Upscale_CNN_x2_VL.glsl"
    },
    [4] = {
        name = "Anime4K: Yumuşak / Denoise (Restore Soft)",
        short = "Anime4K Soft",
        category = "anime",
        files = "D:/xyz-player/shaders/Anime4K_Restore_CNN_Soft_M.glsl;D:/xyz-player/shaders/Anime4K_Upscale_CNN_x2_M.glsl"
    },
    -- FİLM, DİZİ & YOUTUBE (Gerçek Görüntü)
    [5] = {
        name = "AMD FSR 1.0 + RCAS (YouTube & Genel Video)",
        short = "AMD FSR 1.0",
        category = "real",
        files = "D:/xyz-player/shaders/FSR_EASU_RCAS.glsl"
    },
    [6] = {
        name = "SSimSuperRes (Sinema, Film & Doğal Detay)",
        short = "SSimSuperRes",
        category = "real",
        files = "D:/xyz-player/shaders/SSimSuperRes_Natural.glsl"
    },
    [7] = {
        name = "Bilateral Denoise + FSR (Düşük Bitrate Web)",
        short = "Denoise + FSR",
        category = "real",
        files = "D:/xyz-player/shaders/Anime4K_Denoise_Bilateral_Mean.glsl;D:/xyz-player/shaders/FSR_EASU_RCAS.glsl"
    },
    -- KAPALI
    [0] = {
        name = "Kapalı (Orijinal Kaynak Görüntüsü)",
        short = "Kapalı",
        category = "off",
        files = ""
    }
}

-- Renk Paleti (ASS Formatı: BBGGRR)
local C = {
    bg_bar      = "120D09",
    bg_card     = "16100B",
    border_card = "3B291E",
    cyan        = "D4B606", -- #06b6d4
    cyan_bright = "F8BD38", -- #38bdf8
    cyan_bg     = "422B0F", -- #0f2b42
    cyan_border = "E9A50E", -- #0ea5e9
    green       = "99D334", -- #34d399
    green_bg    = "2B3B06", -- #063b2b
    green_bord  = "81B910", -- #10b981
    btn_off_bg  = "261E17",
    btn_off_brd = "3B2F25",
    text_white  = "FCFAF8",
    text_light  = "F0E2E2",
    text_muted  = "B8A394",
    text_dim    = "8B7464",
    track_bg    = "48382D",
    red_hover   = "4444EF",
}

local function get_virtual_size()
    local rw, rh = mp.get_osd_size()
    if not rw or not rh or rw < 100 or rh < 100 then return nil, nil, 1 end
    local scale = BASE_VH / rh
    local vw = math.floor(rw * scale)
    local vh = BASE_VH
    return vw, vh, scale
end

-- Yardımcı Çizim Fonksiyonları (ASS Vector \p1)
local function rect_path(x1, y1, x2, y2, r)
    r = r or 0
    if r <= 0 then
        return string.format("m %d %d l %d %d %d %d %d %d c", x1, y1, x2, y1, x2, y2, x1, y2)
    end
    local k = math.floor(r * 0.55)
    return string.format(
        "m %d %d l %d %d b %d %d %d %d %d %d l %d %d b %d %d %d %d %d %d l %d %d b %d %d %d %d %d %d l %d %d b %d %d %d %d %d %d c",
        x1 + r, y1,
        x2 - r, y1, x2 - r + k, y1, x2, y1 + r - k, x2, y1 + r,
        x2, y2 - r, x2, y2 - r + k, x2 - r + k, y2, x2 - r, y2,
        x1 + r, y2, x1 + r - k, y2, x1, y2 - r + k, x1, y2 - r,
        x1, y1 + r, x1, y1 + r - k, x1 + r - k, y1, x1 + r, y1
    )
end

local function draw_box(lines, x1, y1, x2, y2, r, fill_color, fill_alpha, bord_color, bord_size)
    local b = bord_size or 0
    local bc = bord_color or fill_color
    local fa = fill_alpha or "00"
    table.insert(lines, string.format(
        "{\\pos(0,0)\\an7\\p1\\bord%d\\shad0\\1c&H%s&\\3c&H%s&\\1a&H%s&\\3a&H00&}%s{\\p0}",
        b, fill_color, bc, fa, rect_path(math.floor(x1), math.floor(y1), math.floor(x2), math.floor(y2), math.floor(r or 0))
    ))
end

local function draw_text(lines, x, y, align, size, color, bold, text, alpha)
    local b = bold and 1 or 0
    local a = alpha or "00"
    local safe = tostring(text or ""):gsub("{", "\\{"):gsub("}", "\\}")
    table.insert(lines, string.format(
        "{\\pos(%d,%d)\\an%d\\fnSegoe UI\\fs%d\\b%d\\bord0\\shad0\\1c&H%s&\\1a&H%s&}%s",
        math.floor(x), math.floor(y), align, size, b, color, a, safe
    ))
end

local function draw_icon(lines, cx, cy, color, path_str, bord_w)
    if bord_w and bord_w > 0 then
        table.insert(lines, string.format(
            "{\\pos(%d,%d)\\an7\\p1\\bord%d\\shad0\\1c&H%s&\\3c&H%s&\\1a&HFF&\\3a&H00&}%s{\\p0}",
            math.floor(cx), math.floor(cy), bord_w, color, color, path_str
        ))
    else
        table.insert(lines, string.format(
            "{\\pos(%d,%d)\\an7\\p1\\bord0\\shad0\\1c&H%s&\\1a&H00&}%s{\\p0}",
            math.floor(cx), math.floor(cy), color, path_str
        ))
    end
end

local function fmt_time(sec)
    if not sec or sec < 0 then return "00:00" end
    local s = math.floor(sec)
    local h = math.floor(s / 3600)
    local m = math.floor((s % 3600) / 60)
    local rem = s % 60
    if h > 0 then
        return string.format("%d:%02d:%02d", h, m, rem)
    else
        return string.format("%02d:%02d", m, rem)
    end
end

local function show_toast(msg)
    state.toast_text = msg
    state.toast_until = mp.get_time() + 2.2
end

local function apply_shader_mode(mode)
    state.shader_mode = mode
    if mode ~= 0 then
        state.last_active_shader = mode
    end
    local preset = SHADER_PRESETS[mode] or SHADER_PRESETS[0]
    if preset.files == "" then
        mp.commandv("change-list", "glsl-shaders", "clr", "")
    else
        mp.commandv("change-list", "glsl-shaders", "set", preset.files)
    end
    show_toast(preset.name)
end

-- Shader Gecikmesini (ms) vo-passes üzerinden gerçek zamanlı hesapla
local function get_shader_latency_ms()
    local passes = mp.get_property_native("vo-passes")
    if not passes or not passes.fresh then return 2.1 end
    local total_ns = 0
    for _, pass in ipairs(passes.fresh) do
        if pass.avg then
            total_ns = total_ns + pass.avg
        elseif pass.last then
            total_ns = total_ns + pass.last
        end
    end
    if total_ns > 0 then
        return total_ns / 1000000.0
    end
    return 2.1
end

-- Tıklanabilir Bölgeler (Hitboxes)
local hitboxes = {}
local function add_hitbox(id, x1, y1, x2, y2, fn)
    table.insert(hitboxes, { id = id, x1 = x1, y1 = y1, x2 = x2, y2 = y2, fn = fn })
end

local function is_hovered(x1, y1, x2, y2)
    return state.last_mouse_x >= x1 and state.last_mouse_x <= x2
       and state.last_mouse_y >= y1 and state.last_mouse_y <= y2
end

-- Ana Çizim Fonksiyonu
local function render()
    local w, h = get_virtual_size()
    if not w or not h then return end

    ov.res_x = w
    ov.res_y = h
    hitboxes = {}
    local lines = {}

    local now = mp.get_time()
    local paused = mp.get_property_bool("pause", false)

    -- Fare otomatik gizleme kontrolü
    if not paused and not state.menu_open and (now - state.last_activity > state.hide_timeout) then
        if state.last_mouse_y < h - 90 and state.last_mouse_y > 55 then
            state.ui_visible = false
        end
    else
        state.ui_visible = true
    end

    -- ======================================================================
    -- 1. SAĞ ÜST HUD İSTATİSTİK KARTI
    -- ======================================================================
    if state.hud_visible then
        local cw = 375
        local ch = 246
        local cx1 = w - cw - 18
        local cy1 = 56
        local cx2 = cx1 + cw
        local cy2 = cy1 + ch

        draw_box(lines, cx1, cy1, cx2, cy2, 10, C.bg_card, "18", C.border_card, 1)
        draw_box(lines, cx1, cy1 + 4, cx1 + 4, cy2 - 4, 2, C.cyan, "00", C.cyan, 0)

        local vo_name = mp.get_property("current-vo", "gpu-next")
        local gpu_api = mp.get_property("gpu-api", "vulkan")
        gpu_api = gpu_api:sub(1,1):upper() .. gpu_api:sub(2)
        draw_text(lines, cx1 + 18, cy1 + 24, 4, 15, C.cyan_bright, true,
            string.format("mpv - %s (%s)", vo_name, gpu_api))
        draw_text(lines, cx2 - 16, cy1 + 24, 6, 13, C.green, false, "stats.lua (1)")

        local vw = mp.get_property_number("video-params/w") or 1920
        local vh = mp.get_property_number("video-params/h") or 1080
        local vfps = mp.get_property_number("container-fps") or 23.976

        local preset = SHADER_PRESETS[state.shader_mode] or SHADER_PRESETS[0]
        local scale_str, scale_col
        if state.shader_mode ~= 0 then
            scale_str = string.format("%dx%d (%s)", vw * 2, vh * 2, preset.short)
            scale_col = C.green
        else
            scale_str = string.format("%dx%d (Orijinal)", vw, vh)
            scale_col = C.text_muted
        end

        local dfps = mp.get_property_number("display-fps") or 0
        if dfps <= 0 then dfps = mp.get_property_number("estimated-display-fps") or 60 end
        local interp = mp.get_property_bool("interpolation") or false
        local fps_str, fps_col
        if interp then
            fps_str = string.format("%.2f FPS (Display-Resample)", dfps)
            fps_col = C.cyan_bright
        else
            fps_str = string.format("%.2f FPS (Standart)", vfps)
            fps_col = C.text_light
        end

        local drops = mp.get_property_number("frame-drop-count") or 0
        local raw_est = mp.get_property_number("estimated-frame-count") or 1000
        local est_frames = math.max(1, raw_est)
        local drop_pct = (drops / est_frames) * 100
        local drop_str = string.format("%d (%.2f%%)", drops, drop_pct)

        local latency = get_shader_latency_ms()
        local lat_str = string.format("%.1f ms", latency)

        local acodec = (mp.get_property("audio-codec-name") or "aac"):upper()
        local ach = mp.get_property_number("audio-params/channel-count") or 2
        local arate = (mp.get_property_number("audio-params/samplerate") or 48000) / 1000
        local audio_str = string.format("%s %.1fch %.0fkHz", acodec, ach, arate)

        local rows = {
            { "Giriş:",            string.format("%dx%d @ %.3f fps", vw, vh, vfps), C.text_white, false },
            { "Çıkış (Scale):",    scale_str,                                       scale_col,    true  },
            { "Ekran Hızı:",       fps_str,                                         fps_col,      true  },
            { "Kare Düşmesi:",     drop_str,                                        C.green,      false },
            { "Shader Gecikmesi:", lat_str,                                         C.text_white, false },
            { "Ses:",              audio_str,                                       C.text_light, false },
        }

        local ry = cy1 + 56
        for _, r in ipairs(rows) do
            draw_text(lines, cx1 + 18, ry, 4, 13, C.text_muted, false, r[1])
            draw_text(lines, cx2 - 16, ry, 6, 13, r[3], r[4], r[2])
            ry = ry + 25
        end

        draw_box(lines, cx1 + 16, cy2 - 34, cx2 - 16, cy2 - 33, 0, C.border_card, "40", C.border_card, 0)
        draw_text(lines, cx1 + 18, cy2 - 17, 4, 12, C.text_dim, false, "Kısayol: 'i' tuşu")
        draw_text(lines, cx2 - 16, cy2 - 17, 6, 12, C.cyan, true, "Zero-Copy Swapchain")
    end

    -- ======================================================================
    -- 2. SPACE BASILI TUTUNCA "2.0x HIZ" ROZETİ & TOAST MESAJI
    -- ======================================================================
    if state.space_holding then
        local bw_2x = 190
        local bx1 = math.floor((w - bw_2x) / 2)
        draw_box(lines, bx1, 56, bx1 + bw_2x, 92, 18, C.bg_card, "10", C.cyan_border, 1)
        draw_icon(lines, bx1 + 22, 68, C.cyan_bright, "m 0 0 l 9 6 0 12 c m 9 0 l 18 6 9 12 c")
        draw_text(lines, bx1 + 50, 74, 4, 15, C.text_white, true, "2.0x Hızda")
    elseif state.toast_text and now < state.toast_until then
        local tw = 350
        local tx1 = math.floor((w - tw) / 2)
        draw_box(lines, tx1, 58, tx1 + tw, 94, 8, C.bg_card, "15", C.cyan, 1)
        draw_text(lines, math.floor(w / 2), 76, 5, 14, C.text_white, true, state.toast_text)
    end

    -- ======================================================================
    -- 3. ÜST BAŞLIK BARI & ALT KONTROL BARI
    -- ======================================================================
    if state.ui_visible then
        -- 3A. ÜST BAŞLIK BARI
        local top_h = 44
        draw_box(lines, 0, 0, w, top_h, 0, C.bg_bar, "22", C.bg_bar, 0)

        draw_box(lines, 18, 13, 36, 31, 2, C.bg_bar, "00", C.text_muted, 1)
        draw_box(lines, 22, 13, 23, 31, 0, C.text_muted, "00", C.text_muted, 0)
        draw_box(lines, 31, 13, 32, 31, 0, C.text_muted, "00", C.text_muted, 0)

        local title = mp.get_property("media-title", "XYZ Player")
        if #title > 68 then title = title:sub(1, 65) .. "..." end
        draw_text(lines, 46, 22, 4, 15, C.text_white, true, title)

        add_hitbox("drag_window", 0, 0, w - 135, top_h, function()
            mp.commandv("begin-vo-dragging")
        end)

        local wb_w = 44
        local min_x1 = w - wb_w * 3
        if is_hovered(min_x1, 0, min_x1 + wb_w, top_h) then
            draw_box(lines, min_x1, 0, min_x1 + wb_w, top_h, 0, C.btn_off_bg, "20")
        end
        draw_box(lines, min_x1 + 15, 22, min_x1 + 29, 24, 0, C.text_light, "00")
        add_hitbox("win_min", min_x1, 0, min_x1 + wb_w, top_h, function()
            mp.set_property_bool("window-minimized", true)
        end)

        local max_x1 = w - wb_w * 2
        if is_hovered(max_x1, 0, max_x1 + wb_w, top_h) then
            draw_box(lines, max_x1, 0, max_x1 + wb_w, top_h, 0, C.btn_off_bg, "20")
        end
        draw_box(lines, max_x1 + 15, 15, max_x1 + 29, 29, 1, C.bg_bar, "FF", C.text_light, 1)
        add_hitbox("win_max", max_x1, 0, max_x1 + wb_w, top_h, function()
            mp.commandv("cycle", "fullscreen")
        end)

        local cls_x1 = w - wb_w
        if is_hovered(cls_x1, 0, w, top_h) then
            draw_box(lines, cls_x1, 0, w, top_h, 0, C.red_hover, "15")
        end
        draw_text(lines, cls_x1 + 22, 21, 5, 16, C.text_light, false, "✕")
        add_hitbox("win_close", cls_x1, 0, w, top_h, function()
            mp.commandv("quit")
        end)

        -- ------------------------------------------------------------------
        -- 3B. ALT KONTROL BARI
        -- ------------------------------------------------------------------
        local bar_h = 78
        local by1 = h - bar_h
        draw_box(lines, 0, by1, w, h, 0, C.bg_bar, "10", C.bg_bar, 0)

        -- İlerleme Çubuğu (Seekbar)
        local sx1 = 22
        local sx2 = w - 22
        local sw = sx2 - sx1
        local sy = by1 + 13
        local pos = mp.get_property_number("time-pos") or 0
        local dur = mp.get_property_number("duration") or 0
        local ratio = (dur > 0) and math.min(1, math.max(0, pos / dur)) or 0
        local seek_hover = is_hovered(sx1, sy - 9, sx2, sy + 11)
        local th = seek_hover and 4 or 3

        draw_box(lines, sx1, sy - th, sx2, sy + th, 2, C.track_bg, "00")
        local fill_x2 = sx1 + math.floor(sw * ratio)
        if fill_x2 > sx1 then
            draw_box(lines, sx1, sy - th, fill_x2, sy + th, 2, C.cyan, "00")
        end

        if seek_hover and dur > 0 then
            draw_box(lines, fill_x2 - 7, sy - 7, fill_x2 + 7, sy + 7, 7, C.cyan_bright, "00")
            local h_ratio = math.min(1, math.max(0, (state.last_mouse_x - sx1) / sw))
            local h_time = fmt_time(h_ratio * dur)
            local tx = math.min(sx2 - 32, math.max(sx1 + 32, state.last_mouse_x))
            draw_box(lines, tx - 30, sy - 36, tx + 30, sy - 12, 5, C.bg_card, "08", C.border_card, 1)
            draw_text(lines, tx, sy - 24, 5, 14, C.text_white, true, h_time)
        end

        add_hitbox("seekbar", sx1, sy - 10, sx2, sy + 12, function(mx)
            if dur > 0 then
                local target = math.min(1, math.max(0, (mx - sx1) / sw)) * dur
                mp.commandv("seek", tostring(target), "absolute", "exact")
            end
        end)

        local cy = by1 + 48

        -- 1. Oynat / Duraklat (Play / Pause)
        local px = 38
        if paused then
            draw_icon(lines, px - 7, cy - 10, C.text_white, "m 0 0 l 17 10 0 20 c")
        else
            draw_box(lines, px - 7, cy - 9, px - 2, cy + 9, 1, C.text_white, "00")
            draw_box(lines, px + 2, cy - 9, px + 7, cy + 9, 1, C.text_white, "00")
        end
        add_hitbox("play_pause", px - 20, cy - 20, px + 20, cy + 20, function()
            mp.commandv("cycle", "pause")
        end)

        -- 2. Geri Sar (-10 sn)
        local rwx = 86
        draw_text(lines, rwx, cy - 1, 5, 22, C.text_light, true, "↺")
        add_hitbox("rewind", rwx - 20, cy - 20, rwx + 20, cy + 20, function()
            mp.commandv("seek", "-10", "relative")
        end)

        -- 3. İleri Sar (+10 sn)
        local fwx = 132
        draw_text(lines, fwx, cy - 1, 5, 22, C.text_light, true, "↻")
        add_hitbox("forward", fwx - 20, cy - 20, fwx + 20, cy + 20, function()
            mp.commandv("seek", "10", "relative")
        end)

        -- 4. Süre Gösterimi
        local cur_s = fmt_time(pos)
        local tot_s = fmt_time(dur)
        draw_text(lines, 166, cy, 4, 16, C.text_white, true, cur_s)
        draw_text(lines, 166 + (#cur_s * 8) + 6, cy, 4, 16, C.text_muted, false, "/ " .. tot_s)

        -- ==================================================================
        -- SAĞ TARAF ÖZEL BUTONLAR
        -- ==================================================================
        local rx = w - 36

        -- Sağ 1: Tam Ekran (⛶)
        draw_icon(lines, rx - 8, cy - 8, C.text_light,
            "m 0 6 l 0 0 6 0 m 10 0 l 16 0 16 6 m 16 10 l 16 16 10 16 m 6 16 l 0 16 0 10", 2)
        add_hitbox("fullscreen", rx - 20, cy - 20, rx + 20, cy + 20, function()
            mp.commandv("cycle", "fullscreen")
        end)

        -- Sağ 2: Shader / Kalite Menüsü (☰)
        local mx = rx - 46
        draw_box(lines, mx - 9, cy - 7, mx + 9, cy - 5, 1, C.text_light, "00")
        draw_box(lines, mx - 9, cy - 1, mx + 9, cy + 1, 1, C.text_light, "00")
        draw_box(lines, mx - 9, cy + 5, mx + 9, cy + 7, 1, C.text_light, "00")
        add_hitbox("menu_btn", mx - 20, cy - 20, mx + 20, cy + 20, function()
            state.menu_open = not state.menu_open
        end)

        -- Sağ 3: Ses İkonu (🔊)
        local vx = mx - 46
        local muted = mp.get_property_bool("mute", false)
        local vcol = muted and C.red_hover or C.text_light
        draw_icon(lines, vx - 9, cy - 8, vcol, "m 0 5 l 5 5 11 0 11 16 5 11 0 11 c")
        if not muted then
            draw_box(lines, vx + 5, cy - 4, vx + 7, cy + 4, 1, C.text_light, "00")
            draw_box(lines, vx + 9, cy - 8, vx + 11, cy + 8, 1, C.text_muted, "00")
        end
        add_hitbox("mute_btn", vx - 20, cy - 20, vx + 20, cy + 20, function()
            mp.commandv("cycle", "mute")
        end)

        -- Dikey Ayırıcı Çizgi (|)
        local sep_x = vx - 30
        draw_box(lines, sep_x, cy - 14, sep_x + 1, cy + 14, 0, C.border_card, "20")

        -- ------------------------------------------------------------------
        -- 3 ÖZEL RENKLİ BUTON
        -- ------------------------------------------------------------------
        local bw = 42
        local bh = 36
        local gap = 9

        -- [Buton 3] HUD İstatistik Paneli (📊)
        local b3_x2 = sep_x - 14
        local b3_x1 = b3_x2 - bw
        local b3_bg = state.hud_visible and C.cyan_bg or C.btn_off_bg
        local b3_br = state.hud_visible and C.cyan_border or C.btn_off_brd
        local b3_ic = state.hud_visible and C.cyan_bright or C.text_muted
        draw_box(lines, b3_x1, cy - bh/2, b3_x2, cy + bh/2, 7, b3_bg, "05", b3_br, 1)
        local b3_cx = math.floor((b3_x1 + b3_x2) / 2)
        draw_box(lines, b3_cx - 8, cy - 1, b3_cx - 4, cy + 8, 1, b3_ic, "00")
        draw_box(lines, b3_cx - 2, cy - 8, b3_cx + 2, cy + 8, 1, b3_ic, "00")
        draw_box(lines, b3_cx + 4, cy - 4, b3_cx + 8, cy + 8, 1, b3_ic, "00")
        add_hitbox("btn_hud", b3_x1, cy - bh/2, b3_x2, cy + bh/2, function()
            state.hud_visible = not state.hud_visible
        end)

        -- [Buton 2] Akıcı Kare Senkronizasyonu / Interpolation (⚡)
        local b2_x2 = b3_x1 - gap
        local b2_x1 = b2_x2 - bw
        local interp_on = mp.get_property_bool("interpolation", false)
        local b2_bg = interp_on and C.cyan_bg or C.btn_off_bg
        local b2_br = interp_on and C.cyan_border or C.btn_off_brd
        local b2_ic = interp_on and C.cyan_bright or C.text_muted
        draw_box(lines, b2_x1, cy - bh/2, b2_x2, cy + bh/2, 7, b2_bg, "05", b2_br, 1)
        local b2_cx = math.floor((b2_x1 + b2_x2) / 2)
        draw_icon(lines, b2_cx - 7, cy - 9, b2_ic, "m 8 0 l 0 10 6 10 4 18 14 8 8 8 c")
        add_hitbox("btn_interp", b2_x1, cy - bh/2, b2_x2, cy + bh/2, function()
            local next_val = not interp_on
            mp.set_property_bool("interpolation", next_val)
            show_toast(next_val and "Kare Senkronizasyonu: AÇIK" or "Kare Senkronizasyonu: KAPALI")
        end)

        -- [Buton 1] Upscaler & Shader Seçici (🪄 Tıklayınca Kategorili Menü Açılır!)
        local b1_x2 = b2_x1 - gap
        local b1_x1 = b1_x2 - bw
        local a4k_on = (state.shader_mode ~= 0)
        local b1_bg = a4k_on and C.green_bg or C.btn_off_bg
        local b1_br = a4k_on and C.green_bord or C.btn_off_brd
        local b1_ic = a4k_on and C.green or C.text_muted
        draw_box(lines, b1_x1, cy - bh/2, b1_x2, cy + bh/2, 7, b1_bg, "05", b1_br, 1)
        local b1_cx = math.floor((b1_x1 + b1_x2) / 2)
        draw_icon(lines, b1_cx - 9, cy - 8, b1_ic,
            "m 2 14 l 4 16 18 2 16 0 c m 4 0 l 5 3 8 4 5 5 4 8 3 5 0 4 3 3 c")
        add_hitbox("btn_anime4k", b1_x1, cy - bh/2, b1_x2, cy + bh/2, function()
            state.menu_open = not state.menu_open
        end)

        -- ==================================================================
        -- 4. KATEGORİLİ SHADER & UPSCALER SEÇİM MENÜSÜ (🪄 veya ☰ Tıklanınca)
        -- ==================================================================
        if state.menu_open then
            local mw = 355
            local mh = 345
            local mx1 = math.min(w - mw - 18, math.max(18, b1_x1 - 80))
            local my1 = by1 - mh - 10
            draw_box(lines, mx1, my1, mx1 + mw, my1 + mh, 10, C.bg_card, "06", C.border_card, 1)

            -- Bölüm 1: Anime & Çizim
            local iy = my1 + 18
            draw_text(lines, mx1 + 16, iy, 4, 12, C.cyan_bright, true, "ANİME & ÇİZİM (Anime4K CNN AI)")
            iy = iy + 16

            local anime_modes = { 1, 2, 3, 4 }
            for _, m in ipairs(anime_modes) do
                local p = SHADER_PRESETS[m]
                local active = (state.shader_mode == m)
                local hov = is_hovered(mx1 + 10, iy, mx1 + mw - 10, iy + 28)
                if active then
                    draw_box(lines, mx1 + 10, iy, mx1 + mw - 10, iy + 28, 5, C.green_bg, "12", C.green_bord, 1)
                elseif hov then
                    draw_box(lines, mx1 + 10, iy, mx1 + mw - 10, iy + 28, 5, C.btn_off_bg, "18")
                end
                local tcol = active and C.green or C.text_white
                draw_text(lines, mx1 + 20, iy + 14, 4, 13, tcol, active, (active and "●  " or "○  ") .. p.name)
                local target_m = m
                add_hitbox("preset_" .. m, mx1 + 10, iy, mx1 + mw - 10, iy + 28, function()
                    apply_shader_mode(target_m)
                    state.menu_open = false
                end)
                iy = iy + 30
            end

            -- Bölüm 2: Film, Dizi & YouTube
            iy = iy + 8
            draw_text(lines, mx1 + 16, iy, 4, 12, C.cyan_bright, true, "FİLM, DİZİ & YOUTUBE (Gerçek Görüntü)")
            iy = iy + 16

            local real_modes = { 5, 6, 7 }
            for _, m in ipairs(real_modes) do
                local p = SHADER_PRESETS[m]
                local active = (state.shader_mode == m)
                local hov = is_hovered(mx1 + 10, iy, mx1 + mw - 10, iy + 28)
                if active then
                    draw_box(lines, mx1 + 10, iy, mx1 + mw - 10, iy + 28, 5, C.cyan_bg, "12", C.cyan_border, 1)
                elseif hov then
                    draw_box(lines, mx1 + 10, iy, mx1 + mw - 10, iy + 28, 5, C.btn_off_bg, "18")
                end
                local tcol = active and C.cyan_bright or C.text_white
                draw_text(lines, mx1 + 20, iy + 14, 4, 13, tcol, active, (active and "●  " or "○  ") .. p.name)
                local target_m = m
                add_hitbox("preset_" .. m, mx1 + 10, iy, mx1 + mw - 10, iy + 28, function()
                    apply_shader_mode(target_m)
                    state.menu_open = false
                end)
                iy = iy + 30
            end

            -- Bölüm 3: Devre Dışı (Kapalı)
            iy = iy + 6
            draw_box(lines, mx1 + 14, iy - 3, mx1 + mw - 14, iy - 2, 0, C.border_card, "40")
            local p0 = SHADER_PRESETS[0]
            local active0 = (state.shader_mode == 0)
            local hov0 = is_hovered(mx1 + 10, iy + 2, mx1 + mw - 10, iy + 30)
            if active0 then
                draw_box(lines, mx1 + 10, iy + 2, mx1 + mw - 10, iy + 30, 5, C.btn_off_bg, "12", C.btn_off_brd, 1)
            elseif hov0 then
                draw_box(lines, mx1 + 10, iy + 2, mx1 + mw - 10, iy + 30, 5, C.btn_off_bg, "18")
            end
            local tcol0 = active0 and C.text_muted or C.text_light
            draw_text(lines, mx1 + 20, iy + 16, 4, 13, tcol0, active0, (active0 and "●  " or "○  ") .. p0.name)
            add_hitbox("preset_0", mx1 + 10, iy + 2, mx1 + mw - 10, iy + 30, function()
                apply_shader_mode(0)
                state.menu_open = false
            end)
        end
    end

    ov.data = table.concat(lines, "\n")
    ov:update()
end

-- Fare Hareket ve Tıklama Yönetimi
mp.observe_property("mouse-pos", "native", function(_, pos)
    if not pos then return end
    local _, _, scale = get_virtual_size()
    local vx = pos.x * scale
    local vy = pos.y * scale
    if math.abs(vx - state.last_mouse_x) > 0.5 or math.abs(vy - state.last_mouse_y) > 0.5 then
        state.last_mouse_x = vx
        state.last_mouse_y = vy
        state.last_activity = mp.get_time()
        state.ui_visible = true
        render()
    end
end)

mp.add_forced_key_binding("MBTN_LEFT", "xyz_ui_click", function(e)
    if e.event ~= "down" then return end
    state.last_activity = mp.get_time()
    local mx, my = state.last_mouse_x, state.last_mouse_y
    for i = #hitboxes, 1, -1 do
        local hb = hitboxes[i]
        if mx >= hb.x1 and mx <= hb.x2 and my >= hb.y1 and my <= hb.y2 then
            hb.fn(mx, my)
            render()
            return
        end
    end
    if state.menu_open then
        state.menu_open = false
    else
        mp.commandv("cycle", "pause")
    end
    render()
end, { complex = true })

mp.add_forced_key_binding("MBTN_LEFT_DBL", "xyz_ui_dblclick", function()
    local my = state.last_mouse_y
    local _, h = get_virtual_size()
    if h and my < h - 80 then
        mp.commandv("cycle", "fullscreen")
    end
end)

-- ==========================================================================
-- BOŞLUK (SPACE) TUŞU: Tek Tık Duraklat/Oynat | Basılı Tutunca 2.0x Hız!
-- ==========================================================================
mp.add_forced_key_binding("SPACE", "xyz_space_hold_2x", function(e)
    if e.event == "down" then
        state.space_holding = false
        if state.space_timer then
            state.space_timer:kill()
            state.space_timer = nil
        end
        state.space_timer = mp.add_timeout(0.20, function()
            state.space_holding = true
            state.saved_speed = mp.get_property_number("speed") or 1.0
            if mp.get_property_bool("pause", false) then
                mp.set_property_bool("pause", false)
            end
            mp.set_property_number("speed", 2.0)
            render()
        end)
    elseif e.event == "up" or e.event == "cancel" then
        if state.space_timer then
            state.space_timer:kill()
            state.space_timer = nil
        end
        if state.space_holding then
            state.space_holding = false
            mp.set_property_number("speed", state.saved_speed or 1.0)
            render()
        else
            mp.commandv("cycle", "pause")
            state.last_activity = mp.get_time()
            render()
        end
    end
end, { complex = true })

-- Fare Tekerleği ile Ses Kontrolü
mp.add_forced_key_binding("WHEEL_UP", "xyz_vol_up", function()
    mp.commandv("add", "volume", "5")
    local vol = mp.get_property_number("volume") or 100
    show_toast(string.format("Ses: %%%d", math.floor(vol)))
    render()
end)

mp.add_forced_key_binding("WHEEL_DOWN", "xyz_vol_down", function()
    mp.commandv("add", "volume", "-5")
    local vol = mp.get_property_number("volume") or 100
    show_toast(string.format("Ses: %%%d", math.floor(vol)))
    render()
end)

-- Klavye Kısayolları ('i' tuşu ve CTRL+0..5 ile senkronizasyon)
mp.add_forced_key_binding("i", "xyz_toggle_hud", function()
    state.hud_visible = not state.hud_visible
    render()
end)

mp.add_forced_key_binding("I", "xyz_toggle_hud_shift", function()
    state.hud_visible = not state.hud_visible
    render()
end)

mp.add_forced_key_binding("CTRL+0", "xyz_shader_0", function() apply_shader_mode(0); render() end)
mp.add_forced_key_binding("CTRL+1", "xyz_shader_1", function() apply_shader_mode(1); render() end)
mp.add_forced_key_binding("CTRL+2", "xyz_shader_2", function() apply_shader_mode(2); render() end)
mp.add_forced_key_binding("CTRL+3", "xyz_shader_4", function() apply_shader_mode(4); render() end)
mp.add_forced_key_binding("CTRL+4", "xyz_shader_5", function() apply_shader_mode(5); render() end)
mp.add_forced_key_binding("CTRL+5", "xyz_shader_6", function() apply_shader_mode(6); render() end)

-- Periyodik Yenileme
mp.add_periodic_timer(0.25, function()
    render()
end)

mp.register_event("file-loaded", function()
    state.last_activity = mp.get_time()
    state.ui_visible = true
    render()
end)
