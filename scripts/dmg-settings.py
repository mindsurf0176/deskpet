# dmgbuild settings for the DeskPet installer window.
#
# Finder's AppleScript view settings are unreliable on current macOS, so the
# window layout is written straight into the disk image instead.

import os

application = os.environ["DESKPET_APP"]
appname = os.path.basename(application)

format = "UDZO"
compression_level = 9
files = [application]
symlinks = {"Applications": "/Applications"}
icon = os.environ["DESKPET_VOLUME_ICON"]
background = os.environ["DESKPET_BACKGROUND"]

window_rect = ((240, 140), (640, 400))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False

arrange_by = None
grid_spacing = 100
label_pos = "bottom"
text_size = 13
icon_size = 128
icon_locations = {
    appname: (170, 205),
    "Applications": (470, 205),
}
