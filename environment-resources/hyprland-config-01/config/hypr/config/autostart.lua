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
        "swaybg -o eDP-1 -i ~/.config/wallpapers/firewatch-01.jpeg -m fill"
    )

    hl.exec_cmd(
        "swaybg -o DP-5 -i ~/.config/wallpapers/retro-future-02.jpg -m fill"
    )

    hl.exec_cmd(
        "swaybg -o DP-6 -i ~/.config/wallpapers/retro-future-02.jpg -m fill"
    )

    -- =========================================
    -- ================ WORKSPACE ===============
    -- =========================================

    hl.exec_cmd("hyprctl dispatch workspace 1")
end)
