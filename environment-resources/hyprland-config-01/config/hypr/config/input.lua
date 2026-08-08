-- =============================================
-- ================== INPUT ====================
-- =============================================

hl.config({
    input = {
        kb_layout = "pl",
        kb_variant = "",
        kb_model = "",
        kb_options = "",
        kb_rules = "",
        follow_mouse = 1,
        sensitivity = 0,

        touchpad = {
            natural_scroll = true,
            tap_to_click = true,
        },
    },
})

hl.device({
    name = "epic-mouse-v1",
    sensitivity = -0.5,
})