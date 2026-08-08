-- =============================================
-- =============== WORKSPACES ==================
-- =============================================

local workspace_rules = {
    { workspace = "1",  class = "^(kitty)$" },
    { workspace = "2",  class = "^(firefox)$" },
    { workspace = "3",  class = "^(org.mozilla.Thunderbird)$" },
    { workspace = "4",  class = "^(Thunar|thunar)$" },
    { workspace = "5",  class = "^(codium)$" },
    { workspace = "6",  class = "^(Cqrlog)$" },
    { workspace = "7",  class = "^(WSJT-X)$" },
    { workspace = "10", class = "^(Spotify|spotify|Audacious|audacious)$" },
}

for _, rule in ipairs(workspace_rules) do
    hl.window_rule({
        match = {
            class = rule.class,
        },
        workspace = rule.workspace,
    })
end
