# Nyx Player

A KDE Plasma 6 panel music player with a spinning vinyl cover and an [Easy Effects](https://github.com/wwmm/easyeffects) preset switcher.

![Nyx Player popup with a song playing and the Easy Effects presets](screenshots/popup.png)

By default colors come from your active Plasma theme, with the accent taken from the album art. The **Style** page switches it to one of the shared Nyx looks, the same ones [Nyx Clock](https://github.com/OthrineTM/nyx-clock) and [Nyx Control](https://github.com/OthrineTM/nyx-control) use; with sharing on, a look applied in one widget is used by all of them.

## Features

- **Panel view:** cover art, title, elapsed / total time, and previous / play / next buttons. Show all of it, just cover and title, or just cover and controls.
- **Popup:**
  - spinning vinyl-style cover, or a square or round one
  - title, artist, the audio output in use, and the app that's playing
  - seek bar and playback controls
  - a player switcher: stay on Auto, or pick one player by hand when several are open
- **Easy Effects section:**
  - every output preset as a button
  - one on/off switch for all effects
  - a button that opens the Easy Effects window
- **Desktop cards:** drag the player onto the desktop for a card: **Album** (the cover fills the card, like a phone widget), **Wide**, **Vinyl**, or **Easy Effects** (the current preset, its effects, quick preset switching, Edit effects and Bypass). Right-click and choose **Next Card** to switch.
- **Album art colors:** the accent color follows the cover of what's playing. Turn it off in the settings.
- **Styles:** the shared Nyx looks (Glass, Frost, Smoke, Solid, Light, Neon, Clear, Theme), tweakable, with your own saved presets.
- **Phone players:** media from your phone through KDE Connect ranks below this computer's players. Turn this off with *Prefer This Computer's Players* in the right-click menu.
- **Preset intensity:** presets named `name-min` / `name-max` are grouped into one button, with an Intensity toggle between the two

Works with any player that supports MPRIS: Spotify, browsers, VLC, mpv and others.

## Requirements

- KDE Plasma 6 (tested on 6.8.0)
- Easy Effects (only for the Easy Effects section, but the popup expects it)
- WirePlumber (`wpctl`), which most PipeWire setups already have

## Install

**From the KDE Store:** right-click your panel → **Add or Manage Widgets…** → **Get New Widgets…** → **Download New Plasma Widgets…**, search for **Nyx Player** and click **Install**. Or download it from its [KDE Store page](https://store.kde.org/p/2378511).

**From GitHub:**

```bash
git clone https://github.com/OthrineTM/nyx-player.git
kpackagetool6 --type Plasma/Applet --install nyx-player/package
```

Then right-click your panel → **Add or Manage Widgets…**, search for **Nyx Player**, and drag it onto the panel.

**Update:** `git pull`, then `kpackagetool6 --type Plasma/Applet --upgrade nyx-player/package`, then `systemctl --user restart plasma-plasmashell`.

**Remove:** `kpackagetool6 --type Plasma/Applet --remove io.github.othrinetm.nyxplayer`

## Notes

- Easy Effects presets are read from `~/.local/share/easyeffects/output`. If Easy Effects isn't running, the widget starts it in the background (`--service-mode`).
- The widget uses Plasma's private MPRIS QML module (`org.kde.plasma.private.mpris`), the same one the built-in Media Player widget uses. A big Plasma update could break it.

## See also

- [Nyx Control](https://github.com/OthrineTM/nyx-control): control center with notifications, clipboard, system gauges and quick toggles
- [Nyx Clock](https://github.com/OthrineTM/nyx-clock): customizable desktop clock with weekday, date and weather

## License

GPL-3.0-or-later. See [LICENSE](LICENSE).
