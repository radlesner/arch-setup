-- =============================================
-- ================ AUTOSTART ==================
-- =============================================

hl.on("hyprland.start", function()

    hl.exec_cmd("hypridle")
    hl.exec_cmd("~/.config/hypr/scripts/start-waybar.sh")
    hl.exec_cmd("nm-applet")
    hl.exec_cmd("wl-paste --watch clipman store")
    hl.exec_cmd("mako")
    hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")

    -- =========================================
    -- ================ WALLPAPERS ==============
    -- =========================================

    hl.exec_cmd(
        "swaybg -o HDMI-A-1 -i ~/.config/wallpapers/material-design-01.png -m fill"
    )

    hl.exec_cmd(
        "swaybg -o DP-2 -i ~/.config/wallpapers/material-design-01.png -m fill"
    )

end)
