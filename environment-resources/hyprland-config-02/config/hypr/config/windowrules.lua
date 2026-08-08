-- =============================================
-- ============ WINDOW RULES ===================
-- =============================================

-- =============================================
-- VSCODIUM
-- =============================================

hl.window_rule({
    match = {
        class = "^(codium)$",
        title = "^(Open File|Open Folder)$",
    },
    float = true,
    size = { 1000, 600 },
    center = true,
})

-- =============================================
-- THUNAR
-- =============================================

hl.window_rule({
    match = {
        class = "^(Thunar|thunar)$",
        title = "^(File Operation Progress)$",
    },
    float = true,
    size = { 400, 100 },
    center = true,
})

hl.window_rule({
    match = {
        class = "^(Thunar|thunar)$",
        title = "^(Rename.*)$",
    },
    float = true,
    size = { 400, 130 },
    center = true,
})

hl.window_rule({
    match = {
        class = "^(Thunar|thunar)$",
        title = "^(.* - Properties)$",
    },
    float = true,
    size = { 506, 482 },
    center = true,
})

hl.window_rule({
    match = {
        class = "^(Thunar|thunar)$",
        title = "^(Rename Multiple Files)$",
    },
    float = true,
    size = { 616, 500 },
    center = true,
})

-- =============================================
-- AUDACIOUS
-- =============================================

-- Original disabled rule:
-- windowrule = float 1, size 830 530, move 1068 528,
--     match:class ^(Audacious|audacious)$,
--     match:title ^(.*Audacious)$

hl.window_rule({
    match = {
        class = "^(Audacious|audacious)$",
        title = "^(Equalizer Presets)$",
    },
    float = true,
    size = { 260, 290 },
    center = true,
})

hl.window_rule({
    match = {
        class = "^(Audacious|audacious)$",
        title = "^(Audacious Settings)$",
    },
    float = true,
    size = { 395, 485 },
    center = true,
})

hl.window_rule({
    match = {
        class = "^(Audacious|audacious)$",
        title = "^(Log Inspector)$",
    },
    float = true,
    size = { 576, 288 },
    center = true,
})

hl.window_rule({
    match = {
        class = "^(Audacious|audacious)$",
        title = "^(Add Folder|Add Files|Open Folder|Open Files|Import Playlist|Export Playlist)$",
    },
    float = true,
    size = { 624, 412 },
    center = true,
})

hl.window_rule({
    match = {
        class = "^(Audacious|audacious)$",
        title = "^(Add URL|Open URL)$",
    },
    float = true,
    size = { 452, 123 },
    center = true,
})

hl.window_rule({
    match = {
        class = "^(Audacious|audacious)$",
        title = "^(Song Info)$",
    },
    float = true,
    size = { 576, 450 },
    center = true,
})

-- =============================================
-- IMV & MPV
-- =============================================

hl.window_rule({
    match = {
        class = "^(imv|mpv)$",
    },
    float = true,
    size = { 1876, 986 },
    move = { 22, 72 },
})

-- =============================================
-- RISTRETTO
-- =============================================

hl.window_rule({
    match = {
        class = "^(org.xfce.ristretto|ristretto)$",
        title = "^(.*Image Viewer.*)$",
    },
    float = true,
    size = { 1876, 986 },
    move = { 22, 72 },
})

hl.window_rule({
    match = {
        class = "^(org.xfce.ristretto|ristretto)$",
        title = "^(Print)$",
    },
    float = true,
    size = { 740, 500 },
    center = true,
})

-- =============================================
-- WAYBAR NMTUI
-- =============================================

hl.window_rule({
    match = {
        class = "^(waybar-nmtui)$",
        title = "^(waybar-nmtui)$",
    },
    float = true,
    size = { 950, 850 },
    center = true,
})

-- =============================================
-- PAVUCONTROL
-- =============================================

hl.window_rule({
    match = {
        class = "^(org.pulseaudio.pavucontrol)$",
    },
    float = true,
    size = { 800, 900 },
    center = true,
})

-- =============================================
-- FIREFOX
-- =============================================

hl.window_rule({
    match = {
        class = "^(firefox)$",
        title = "^(Library)$",
    },
    float = true,
    size = { 900, 450 },
    center = true,
})

hl.window_rule({
    match = {
        class = "^(firefox)$",
        title = "^(Add bookmark folder)$",
    },
    float = true,
    size = { 587, 128 },
    center = true,
})

hl.window_rule({
    match = {
        class = "^(firefox)$",
        title = "^(Close Firefox)$",
    },
    float = true,
    size = { 670, 130 },
    center = true,
})

-- =============================================
-- THUNDERBIRD
-- =============================================

hl.window_rule({
    match = {
        class = "^(org.mozilla.Thunderbird)$",
        title = "^(Write.*)$",
    },
    float = true,
    size = { 1500, 800 },
    center = true,
})

hl.window_rule({
    match = {
        class = "^(org.mozilla.Thunderbird)$",
        title = "^(Compact folders)$",
    },
    float = true,
    size = { 400, 100 },
    center = true,
})

-- =============================================
-- KEEPASSXC
-- =============================================

hl.window_rule({
    match = {
        class = "^(org.keepassxc.KeePassXC)$",
        title = "^(Generate Password)$",
    },
    float = true,
    size = { 682, 381 },
    center = true,
})

-- =============================================
-- LIBREOFFICE
-- =============================================

hl.window_rule({
    match = {
        class = "^(soffice)$",
        title = "^(Area)$",
    },
    float = true,
    size = { 1000, 800 },
    center = true,
})

-- =============================================
-- GALCULATOR
-- =============================================

hl.window_rule({
    match = {
        class = "^(galculator)$",
    },
    float = true,
    size = { 346, 342 },
    center = true,
})

-- =============================================
-- NETCALC
-- =============================================

hl.window_rule({
    match = {
        class = "^(netcalc)$",
    },
    float = true,
    size = { 776, 489 },
    center = true,
})