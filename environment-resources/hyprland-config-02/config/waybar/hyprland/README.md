## Waybar config documentation

Waybar configuration for Hyprland focused on a minimal and functional desktop layout.


## Modules overview

### Left modules

| Module                | Description                           |
| -----------------------| ---------------------------------------|
| `hyprland/workspaces` | Workspace indicator with custom icons |
| `custom/media`        | Currently playing media information   |

### Center modules

| Module  | Description           |
| ---------| -----------------------|
| `clock` | Current date and time |

### Right modules

| Module              | Description                             |
| ---------------------| -----------------------------------------|
| `idle_inhibitor`    | Prevents automatic screen locking/sleep |
| `pulseaudio`        | Audio volume and microphone status      |
| `network`           | Network connection information          |
| `cpu`               | CPU usage                               |
| `temperature`       | CPU temperature                         |
| `temperature#gpu`   | GPU temperature                         |
| `memory`            | RAM usage                               |
| `custom/disk-usage` | Root filesystem usage                   |
| `custom/disk-02`    | Pictures disk usage                     |
| `custom/disk-01`    | Games disk usage                        |
| `custom/disk-03`    | Virtualbox disk usage                   |
| `custom/uptime`     | System uptime                           |
| `custom/logout`     | Logout button                           |
| `custom/reboot`     | Reboot button                           |
| `custom/power`      | Power off button                        |

## Workspace icons

| Workspace | Application      |
| -----------| ------------------|
| 1         | Terminals        |
| 2         | Firefox          |
| 3         | Thunderbird      |
| 4         | Thunar           |
| 5         | VS Code          |
| 6         | Steam and Heroic |
| 9         | Discord          |
| 10        | Spotify          |

## Temperature module

The temperature module uses a direct hwmon path:

```json
"hwmon-path": "/sys/class/hwmon/hwmon2/temp1_input"
```

Check available hwmon devices:

```bash
ls -l /sys/class/hwmon/
```

Or

```json
"thermal-zone": 1
```

Check available thermal zones:

```bash
ls -l /sys/class/thermal/thermal_zone*
```

## Network module

The network module supports:

- Wi-Fi SSID display
- Signal strength
- Ethernet IP display
- Quick access to `nmtui`

Click action:

```bash
kitty --class waybar-nmtui --title waybar-nmtui nmtui
```


## Audio module

Uses PulseAudio / PipeWire Pulse compatibility layer.

Click action:

```bash
pavucontrol
```


## Custom scripts

The configuration uses custom scripts located in:

```text
~/.config/waybar/scripts/
```

Used scripts:

| Script | Description |
|---|---|
| `disk-used.sh` | Disk usage display |
| `uptime.sh` | System uptime |
| `mediaplayer.py` | Media player integration |


## Dependencies

Required packages:

```text
waybar
playerctl
pavucontrol
kitty
networkmanager
```

Optional:

```text
pipewire
wireplumber
brightnessctl
```


## Fonts

Recommended Nerd Font:

```text
JetBrainsMono Nerd Font
```

Icons used from:

- Font Awesome
- Nerd Fonts



## Notes

- Designed for Hyprland and Sway
- Optimized for desktop PC
- Persistent workspaces enabled
- Uses Unicode and Nerd Font glyphs