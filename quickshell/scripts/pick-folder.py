#!/usr/bin/env python3
"""Open a GTK folder picker and print the chosen directory path."""

from __future__ import annotations

import os
import sys

import gi

gi.require_version("Gtk", "3.0")
from gi.repository import Gtk  # noqa: E402


def main() -> int:
    dialog = Gtk.FileChooserDialog(
        title="Select Wallpaper Folder",
        action=Gtk.FileChooserAction.SELECT_FOLDER,
    )
    dialog.add_buttons("Cancel", Gtk.ResponseType.CANCEL, "Select", Gtk.ResponseType.OK)
    dialog.set_default_response(Gtk.ResponseType.OK)

    start = sys.argv[1] if len(sys.argv) > 1 else ""
    if start:
        start = os.path.expanduser(start)
        if os.path.isdir(start):
            dialog.set_current_folder(start)
        else:
            folder = os.path.dirname(start)
            if os.path.isdir(folder):
                dialog.set_current_folder(folder)

    try:
        response = dialog.run()
        if response == Gtk.ResponseType.OK:
            filename = dialog.get_filename()
            if filename:
                print(filename)
                return 0
        return 1
    finally:
        dialog.destroy()


if __name__ == "__main__":
    raise SystemExit(main())
