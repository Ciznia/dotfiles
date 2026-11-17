import subprocess

from libqtile.config import Click, Drag, Key, KeyChord
from libqtile.lazy import lazy
from libqtile.log_utils import logger


def _find_touchpad():
    """xinput name of the touchpad (its numeric id changes between machines)."""
    try:
        names = subprocess.run(
            ["xinput", "list", "--name-only"], capture_output=True, text=True
        ).stdout.splitlines()
    except OSError:
        return None
    return next((n for n in names if "touchpad" in n.lower()), None)


def _toggle(*args, **kwargs):
    def wrapper(func):
        state: bool = False

        def wrapped(_):
            nonlocal state

            state = not state
            func(*args, **kwargs, state=state)

        return wrapped
    return wrapper


@_toggle()
def toggle_keypad(state: bool):
    touchpad = _find_touchpad()
    if touchpad is None:
        logger.warning("toggle_keypad: no touchpad found in `xinput list`")
        return
    subprocess.run(["xinput", "disable" if state else "enable", touchpad])


mod = "mod4"
alt = "mod1"


def _digit_keys(action):
    """Keys 1-9 for a chord. The keysym resolves to the number-row key on the
    AZERTY layout too; Shift may still be held from the chord's shortcut."""
    return [
        Key(mods, str(n), lazy.spawn(f"display-profile {action} {n}"))
        for n in range(1, 10)
        for mods in ([], ["shift"])
    ]


mouse = [
    Drag(
        [mod],
        "Button1",
        lazy.window.set_position_floating(),
        start=lazy.window.get_position()),
    Drag(
        [mod],
        "Button3",
        lazy.window.set_size_floating(),
        start=lazy.window.get_size()),
    Click([mod], "Button2", lazy.window.bring_to_front()),
]

keys = [
    Key([alt], "Tab", lazy.spawn("rofi -show window --show-icons")),
    Key([alt], "F4", lazy.window.kill()),
    Key([mod], "v", lazy.spawn("kitty -e pulsemixer")),
    Key([mod], "h", lazy.spawn("kitty -e nmtui")),
    Key([mod, "shift"], "v", lazy.spawn("pavucontrol")),
    Key([mod], "l", lazy.spawn("loginctl lock-session")),
    Key([mod], "n", lazy.spawn("notif-menu")),
    Key([mod], "f", lazy.window.toggle_floating()),
    Key([mod], "b", lazy.spawn("firefox")),
    Key([], "Print", lazy.spawn("flameshot gui --clipboard")),
    Key([mod, "shift"], "space", lazy.layout.next()),
    Key([mod, "shift"], "h", lazy.layout.shuffle_left()),
    Key([mod, "shift"], "n", lazy.layout.normalize()),
    Key([mod], "Return", lazy.spawn("kitty")),
    Key([mod], "Tab", lazy.next_layout()),
    Key([mod], "w", lazy.window.kill()),
    Key([mod, "control"], "r", lazy.reload_config()),
    Key([mod, "control"], "q", lazy.shutdown()),
    Key([mod], "r", lazy.spawncmd()),
    Key([mod], "t", lazy.function(toggle_keypad)),
    # Screens, like Win+P: the profile map shows, then a digit loads that
    # profile and Enter opens arandr. Super+Shift+P then a digit saves the
    # current layout under that profile.
    KeyChord([mod], "p", [
        *_digit_keys("load"),
        Key([], "Return", lazy.spawn("display-profile arandr")),
    ], name="display"),
    KeyChord([mod, "shift"], "p", _digit_keys("save"), name="save display"),
    # Backlight
    Key([], "XF86MonBrightnessUp", lazy.spawn("brightnessctl set +5%")),
    Key([], "XF86MonBrightnessDown", lazy.spawn("brightnessctl set 5%-")),
    # Volume (same commands as the lock screen's)
    Key([], "XF86AudioMute", lazy.spawn("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")),
    Key([], "XF86AudioLowerVolume", lazy.spawn("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-")),
    Key([], "XF86AudioRaiseVolume", lazy.spawn("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+")),
    Key([], "XF86AudioMicMute", lazy.spawn("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle")),
    Key(
        [mod, "control"],
        "Right",
        lazy.layout.grow_right(),
        lazy.layout.grow(),
        lazy.layout.increase_ratio(),
        lazy.layout.delete(),
    ),
    Key(
        [mod, "control"],
        "Left",
        lazy.layout.grow_left(),
        lazy.layout.shrink(),
        lazy.layout.decrease_ratio(),
        lazy.layout.add(),
    ),
    Key(
        [mod, "control"],
        "Up",
        lazy.layout.grow_up(),
        lazy.layout.shrink(),
        lazy.layout.decrease_ratio(),
        lazy.layout.add(),
    ),
    Key(
        [mod, "control"],
        "Down",
        lazy.layout.grow_down(),
        lazy.layout.shrink(),
        lazy.layout.decrease_ratio(),
        lazy.layout.add(),
    ),
]
