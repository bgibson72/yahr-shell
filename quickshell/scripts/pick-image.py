#!/usr/bin/env python3
"""Open a GTK file picker for image files and print the chosen path."""

from __future__ import annotations

import os
import sys

import gi

gi.require_version("Gtk", "3.0")
from gi.repository import Gtk  # noqa: E402


def main() -> int:
    title = sys.argv[2] if len(sys.argv) > 2 else "Select Avatar Image"
    dialog = Gtk.FileChooserDialog(
        title=title,
        action=Gtk.FileChooserAction.OPEN,
    )
    dialog.add_buttons("Cancel", Gtk.ResponseType.CANCEL, "Open", Gtk.ResponseType.OK)
    dialog.set_default_response(Gtk.ResponseType.OK)

    images = Gtk.FileFilter()
    images.set_name("Images")
    for pattern in ("*.png", "*.jpg", "*.jpeg", "*.webp", "*.gif", "*.bmp", "*.ico"):
        images.add_pattern(pattern)
    dialog.add_filter(images)

    all_files = Gtk.FileFilter()
    all_files.set_name("All files")
    all_files.add_pattern("*")
    dialog.add_filter(all_files)

    start = sys.argv[1] if len(sys.argv) > 1 else ""
    if start:
        start = os.path.expanduser(start)
        if os.path.isdir(start):
            dialog.set_current_folder(start)
        elif os.path.isfile(start):
            dialog.set_filename(start)
        else:
            folder = os.path.dirname(start)
            if os.path.isdir(folder):
                dialog.set_current_folder(folder)
    else:
        pictures = os.path.expanduser("~/Pictures")
        if os.path.isdir(pictures):
            dialog.set_current_folder(pictures)

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
