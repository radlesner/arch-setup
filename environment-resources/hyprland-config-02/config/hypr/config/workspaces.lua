-- =============================================
-- =============== WORKSPACES ==================
-- =============================================

-- =============================================
-- Window -> Workspace rules
-- =============================================

local window_workspaces = {
    { class = "^(kitty)$",                    workspace = "1" },
    { class = "^(firefox)$",                  workspace = "2" },
    { class = "^(org.mozilla.Thunderbird)$",  workspace = "3" },
    { class = "^(thunar|Thunar)$",             workspace = "4" },
    { class = "^(mousepad)$",                 workspace = "4" },
    { class = "^(VSCodium|codium)$",           workspace = "5" },
    { class = "^(steam)$",                    workspace = "6" },
    { class = "^(heroic)$",                   workspace = "6" },
    { class = "^(discord)$",                  workspace = "9" },
    { class = "^(Spotify|spotify)$",          workspace = "10" },
}

for _, rule in ipairs(window_workspaces) do
    hl.window_rule({
        match = {
            class = rule.class,
        },
        workspace = rule.workspace,
    })
end

-- =============================================
-- Workspace -> Monitor rules
-- =============================================

for i = 1, 10 do
    hl.workspace_rule({
        workspace = tostring(i),
        monitor = "HDMI-A-1",
        default = true,
    })
end

hl.workspace_rule({
    workspace = "11",
    monitor = "DP-2",
    default = true,
})

-- =============================================
-- Initial workspace
-- =============================================

hl.on("hyprland.start", function()
    hl.exec_cmd("hyprctl dispatch workspace 1")
end)