# ii-island (preview)

A Dynamic Island for the bar in [end-4's illogical-impulse](https://github.com/end-4/dots-hyprland) Quickshell config, plus a system monitor panel.

This is a preview of my personal setup, shared so people can try it and give feedback. It is not the cleaned-up version I would propose upstream. Background and screenshots are in [discussion #3717](https://github.com/end-4/dots-hyprland/discussions/3717).

Built with help from Claude Code. Only tested on my own machine: Arch, Hyprland 0.57.1, Quickshell 0.2.1, horizontal top bar, two 1920x1080 monitors. The island hides itself on a vertical bar. Bottom bar and the waffle family are untested.

## What you get

- A pill in the bar, left of the workspaces. It drops below the bar only for notifications, info cards, or a click.
- A music pill that splits off while audio plays: spinning album art, title or synced lyrics, equaliser, and a carousel of all players.
- Activities and idle glances: recording, screen share, timers, weather, updates, failed units, disk and load.
- A system monitor panel.
- Optional Claude Code and opencode status in the pill.

Mouse on the main pill: left click opens the overview, long-press opens quick toggles, middle click is play/pause, scroll changes volume.

## What it changes while enabled

- Replaces end-4's notification popups with the island.
- Replaces the left sidebar (AI) button with the system monitor button.
- Hides the bar's resources/media group and weather widget.
- Keeps the workspaces centred on the screen.

## Install

The location matters, because some paths are fixed:

```sh
git clone https://github.com/sirschubert/ii-island ~/.config/quickshell/ii-island
~/.config/quickshell/ii-island/reapply.sh
```

`reapply.sh` links `src/` into `~/.config/quickshell/ii/modules/island` and patches two end-4 files. If the patch no longer applies, it changes neither file and prints the rejected hunks. Run it again after every end-4 update.

Then add this to `~/.config/hypr/custom/rules.lua` (without it you get a light ghost below the bar when a card opens and closes), and restart the shell:

```lua
hl.layer_rule({ match = { namespace = "quickshell:island" }, blur = false })
hl.layer_rule({ match = { namespace = "quickshell:island" }, no_anim = true })
```

## Dependencies

Besides what end-4's config already needs:

| Feature | Needs |
| --- | --- |
| Equaliser | `cava` |
| Clipboard cards | `wl-clipboard` |
| Lyrics, album colours | `curl` |
| Song recognition | `songrec` |
| Update counts | `pacman`, `fakeroot`, and `yay` for AUR |
| Opencode status | `python-requests` |

Clicking the updates or failed-units glance opens `kitty` and `fish`. Those two commands are hardcoded for now.

## Turning things off

Edit `~/.config/quickshell/ii-island/config.json`. Changes apply right away:

```json
{ "enable": true, "lyrics": true, "clipboard": true }
```

- `"enable": false` brings back the stock bar and popups.
- `"lyrics": false` stops lyric lookups. Lyrics send the current artist and title to lrclib.net.
- `"clipboard": false` turns off clipboard cards. Copied text is never shown, only its length (links show the domain).

To remove it completely, run these and restart the shell:

```sh
cd ~/.config/quickshell/ii
patch -R -p1 < ~/.config/quickshell/ii-island/upstream.patch
rm modules/island
```

## Claude Code (optional)

Add `python3 -I ~/.config/quickshell/ii-island/hooks/claude-island-hook.py` as a command hook in `~/.claude/settings.json` for `UserPromptSubmit`, `PreToolUse` (matcher `*`), `Stop`, `SessionEnd`, and `Notification` (matcher `permission_prompt`). The hook always exits 0, so it cannot break Claude Code.

## opencode (optional)

For opencode 2.x. A small watcher follows the local opencode server and needs a server running with its `service.json`:

```sh
systemctl --user enable --now ~/.config/quickshell/ii-island/hooks/opencode-island.service
```

## Debugging

```sh
qs -c ii ipc call island ping
qs -c ii ipc call island state
qs -c ii ipc call island test notif
qs -c ii log | grep -iE "island|providers/"
```

`test` also accepts `music`, `claudeLive`, `claudePerm`, `claudeDone`, `opencodeLive`, `opencodePerm`, `opencodeDone`, `flash`, `activity`, `noactivity`, `card`, `imagecard`, `idle` and `clear`.

Tests: `node --test tests/` and `python3 -I -m unittest discover -s tests -p 'test_*hook.py'`.

## License

GPL-3.0, the same as end-4's dots-hyprland, which this builds on.
