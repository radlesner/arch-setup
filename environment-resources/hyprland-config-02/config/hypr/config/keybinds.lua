-- =============================================
-- ================ KEYBINDINGS ================
-- =============================================

local function exec(cmd)
    return hl.dsp.exec_cmd(cmd)
end

-- =============================================
-- ================= SYSTEM ====================
-- =============================================

hl.bind(
    main_mod .. " + grave",
    exec("hyprctl reload && ~/.config/hypr/scripts/start-waybar.sh")
)

hl.bind(
    main_mod .. " + SPACE",
    exec(menu)
)

-- =============================================
-- ================= LOCKSCREEN ================
-- =============================================

hl.bind(
    main_mod .. " + L",
    exec(lockscreen)
)

-- =============================================
-- ================ APPLICATIONS ===============
-- =============================================

hl.bind(main_mod .. " + 1", exec(terminal))
hl.bind(main_mod .. " + 2", exec("firefox"))
hl.bind(main_mod .. " + 3", exec("thunderbird"))
hl.bind(main_mod .. " + 4", exec(file_manager))

hl.bind(
    main_mod .. " + 5",
    exec("codium --enable-features=UseOzonePlatform,WaylandWindowDecorations --ozone-platform=wayland")
)

hl.bind(main_mod .. " + 6", exec("steam"))
hl.bind(main_mod .. " + 9", exec("discord"))

-- Flatpak:
-- hl.bind(main_mod .. " + 0", exec("com.spotify.Client"))

-- AUR:
hl.bind(main_mod .. " + 0", exec("spotify"))

-- =============================================
-- ============ WORKSPACE NAVIGATION ===========
-- =============================================

for i = 1, 9 do
    hl.bind(
        second_mod .. " + " .. tostring(i),
        hl.dsp.focus({
            workspace = i,
        })
    )
end

hl.bind(
    second_mod .. " + 0",
    hl.dsp.focus({
        workspace = 10,
    })
)

-- =============================================
-- ========= MOVE WINDOWS BETWEEN WS ===========
-- =============================================

for i = 1, 9 do
    hl.bind(
        second_mod .. " + SHIFT + " .. tostring(i),
        hl.dsp.window.move({
            workspace = i,
        })
    )
end

hl.bind(
    second_mod .. " + SHIFT + 0",
    hl.dsp.window.move({
        workspace = 10,
    })
)

-- =============================================
-- ========= MOVE WORKSPACE / MONITORS =========
-- =============================================

hl.bind(
    second_mod .. " + left",
    hl.dsp.workspace.move({
        monitor = "l",
    })
)

hl.bind(
    second_mod .. " + right",
    hl.dsp.workspace.move({
        monitor = "r",
    })
)

-- =============================================
-- ============== WINDOW MANAGEMENT ============
-- =============================================

hl.bind(
    main_mod .. " + mouse:272",
    hl.dsp.window.drag(),
    { mouse = true }
)

hl.bind(
    main_mod .. " + mouse:273",
    hl.dsp.window.resize(),
    { mouse = true }
)

hl.bind(
    main_mod .. " + mouse_down",
    hl.dsp.focus({
        workspace = "e+1",
    })
)

hl.bind(
    main_mod .. " + mouse_up",
    hl.dsp.focus({
        workspace = "e-1",
    })
)

hl.bind(
    main_mod .. " + X",
    hl.dsp.window.close()
)

hl.bind(
    main_mod .. " + V",
    hl.dsp.window.float({
        action = "toggle",
    })
)

hl.bind(
    main_mod .. " + J",
    hl.dsp.layout("togglesplit")
)

hl.bind(
    main_mod .. " + F",
    hl.dsp.window.fullscreen({
        action = "toggle",
    })
)

-- =============================================
-- ================= MOVE FOCUS ================
-- =============================================

hl.bind(
    main_mod .. " + left",
    hl.dsp.focus({
        direction = "l",
    })
)

hl.bind(
    main_mod .. " + right",
    hl.dsp.focus({
        direction = "r",
    })
)

hl.bind(
    main_mod .. " + up",
    hl.dsp.focus({
        direction = "u",
    })
)

hl.bind(
    main_mod .. " + down",
    hl.dsp.focus({
        direction = "d",
    })
)

-- =============================================
-- ================= MOVE WINDOWS ==============
-- =============================================

hl.bind(
    main_mod .. " + SHIFT + left",
    hl.dsp.window.move({
        direction = "l",
    })
)

hl.bind(
    main_mod .. " + SHIFT + right",
    hl.dsp.window.move({
        direction = "r",
    })
)

hl.bind(
    main_mod .. " + SHIFT + up",
    hl.dsp.window.move({
        direction = "u",
    })
)

hl.bind(
    main_mod .. " + SHIFT + down",
    hl.dsp.window.move({
        direction = "d",
    })
)

-- =============================================
-- ================= SCREENSHOTS ===============
-- =============================================

hl.bind(
    "Print",
    exec("~/.config/hypr/scripts/screenshot.sh area")
)

hl.bind(
    "SHIFT + Print",
    exec("~/.config/hypr/scripts/screenshot.sh full")
)

hl.bind(
    main_mod .. " + P",
    exec("~/.config/hypr/scripts/screenshot.sh area")
)

hl.bind(
    main_mod .. " + SHIFT + P",
    exec("~/.config/hypr/scripts/screenshot.sh full")
)

-- =============================================
-- ============== MULTIMEDIA KEYS ==============
-- =============================================

hl.bind(
    "XF86AudioNext",
    exec("playerctl next"),
    { locked = true }
)

hl.bind(
    "XF86AudioPause",
    exec("playerctl play-pause"),
    { locked = true }
)

hl.bind(
    "XF86AudioPlay",
    exec("playerctl play-pause"),
    { locked = true }
)

hl.bind(
    "XF86AudioPrev",
    exec("playerctl previous"),
    { locked = true }
)

hl.bind(
    "XF86AudioRaiseVolume",
    exec("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"),
    { repeating = true }
)

hl.bind(
    "XF86AudioLowerVolume",
    exec("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
    { repeating = true }
)

hl.bind(
    "XF86AudioMute",
    exec("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
    { locked = true }
)

hl.bind(
    "XF86AudioMicMute",
    exec("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
    { locked = true }
)

-- =============================================
-- ============= BRIGHTNESS CONTROL ============
-- =============================================

hl.bind(
    "XF86MonBrightnessUp",
    exec("brightnessctl set +5%")
)

hl.bind(
    "XF86MonBrightnessDown",
    exec("brightnessctl set 5%-")
)

-- =============================================
-- ================== MISC =====================
-- =============================================

hl.bind(
    main_mod .. " + K",
    exec(calculator)
)