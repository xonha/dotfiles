"""Show the Dotfiles folder's activities glyph in Nautilus bookmarks."""

from pathlib import Path

from gi import require_version

require_version("Gtk", "4.0")
require_version("Nautilus", "4.1")

from gi.repository import Gio, GLib, GObject, Gtk, Nautilus


DOTFILES_URI = (Path.home() / "Dotfiles").as_uri()
BOOKMARK_ICON = Gio.ThemedIcon.new("folder-activities")


def walk_widgets(widget):
    yield widget
    child = widget.get_first_child()
    while child is not None:
        yield from walk_widgets(child)
        child = child.get_next_sibling()


class DotfilesBookmarkIcon(GObject.GObject, Nautilus.MenuProvider):
    def __init__(self):
        super().__init__()
        # Nautilus rebuilds sidebar rows when bookmarks or mounts change.
        GLib.timeout_add_seconds(1, self._update_sidebar)

    def get_file_items(self, *args):
        return []

    def _update_sidebar(self):
        for window in Gtk.Window.list_toplevels():
            sidebar = next(
                (widget for widget in walk_widgets(window) if widget.get_css_name() == "placessidebar"),
                None,
            )
            if sidebar is None:
                continue
            for widget in walk_widgets(sidebar):
                if not isinstance(widget, Gtk.ListBoxRow):
                    continue
                try:
                    uri = widget.get_property("uri")
                    icon = widget.get_property("start-icon")
                except (AttributeError, TypeError):
                    continue
                if uri == DOTFILES_URI and (icon is None or not Gio.Icon.equal(icon, BOOKMARK_ICON)):
                    widget.set_property("start-icon", BOOKMARK_ICON)
        return GLib.SOURCE_CONTINUE
