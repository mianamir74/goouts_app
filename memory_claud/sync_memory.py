"""
GoOuts Memory Sync Script
=========================
Watches the primary memory folder and instantly copies any new/updated
.md files to all other memory destinations.

SETUP:
  pip install watchdog

RUN (keep this running in background):
  python sync_memory.py

When you get your MacBook + Parallels, add the Mac path to DESTINATIONS below.
The Mac home folder appears in Windows as: \\Mac\Home\
"""

import shutil
import time
import sys
from pathlib import Path
from datetime import datetime

try:
    from watchdog.observers import Observer
    from watchdog.events import FileSystemEventHandler
    WATCHDOG_AVAILABLE = True
except ImportError:
    WATCHDOG_AVAILABLE = False

# ─── Configure your paths here ───────────────────────────────────────────────

# Primary source (where Claude saves memory on Windows)
SOURCE = Path(r"C:\Users\Maz\goouts_app\memory_claud")

# All destinations to keep in sync
DESTINATIONS = [
    Path(r"C:\Users\Maz\Desktop\memory"),

    # ── Add Mac path below when you have MacBook + Parallels ──────────────────
    # Parallels makes your Mac home folder available in Windows as \\Mac\Home\
    # Uncomment and update this line after setting up Parallels:
    # Path(r"\\Mac\Home\goouts_app\memory_claud"),
]

# File types to sync
SYNC_EXTENSIONS = {'.md', '.txt', '.json'}

# ─────────────────────────────────────────────────────────────────────────────

def log(msg: str):
    print(f"[{datetime.now().strftime('%H:%M:%S')}] {msg}")

def sync_file(src_path: Path):
    """Copy a single file to all destinations."""
    if src_path.suffix.lower() not in SYNC_EXTENSIONS:
        return
    if src_path.name.startswith('.'):
        return  # skip hidden files

    for dest_dir in DESTINATIONS:
        try:
            dest_dir.mkdir(parents=True, exist_ok=True)
            dest_path = dest_dir / src_path.name
            shutil.copy2(src_path, dest_path)
            log(f"✓ Synced '{src_path.name}' → {dest_dir}")
        except Exception as e:
            log(f"✗ Failed to sync to {dest_dir}: {e}")

def sync_all():
    """Do a full one-time sync of all files from source to all destinations."""
    if not SOURCE.exists():
        log(f"Source folder not found: {SOURCE}")
        return

    files = [f for f in SOURCE.iterdir() if f.is_file() and f.suffix.lower() in SYNC_EXTENSIONS]
    if not files:
        log("No memory files found to sync.")
        return

    log(f"Syncing {len(files)} file(s) to {len(DESTINATIONS)} destination(s)...")
    for f in files:
        sync_file(f)
    log("Full sync complete.")

class MemorySyncHandler(FileSystemEventHandler):
    def on_created(self, event):
        if not event.is_directory:
            sync_file(Path(event.src_path))

    def on_modified(self, event):
        if not event.is_directory:
            sync_file(Path(event.src_path))

    def on_moved(self, event):
        if not event.is_directory:
            sync_file(Path(event.dest_path))

def watch_mode():
    """Watch source folder and sync changes in real time."""
    log(f"Watching: {SOURCE}")
    for i, d in enumerate(DESTINATIONS, 1):
        log(f"  Destination {i}: {d}")
    log("Press Ctrl+C to stop.\n")

    # Do a full sync first
    sync_all()

    observer = Observer()
    observer.schedule(MemorySyncHandler(), str(SOURCE), recursive=False)
    observer.start()

    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        observer.stop()
        log("Stopped.")
    observer.join()

def once_mode():
    """Run a single sync and exit (for use in scripts/scheduled tasks)."""
    log("Running one-time sync...")
    sync_all()
    log("Done.")

if __name__ == '__main__':
    if not SOURCE.exists():
        log(f"ERROR: Source folder does not exist: {SOURCE}")
        sys.exit(1)

    if len(sys.argv) > 1 and sys.argv[1] == '--once':
        once_mode()
    elif WATCHDOG_AVAILABLE:
        watch_mode()
    else:
        log("watchdog not installed. Running one-time sync instead.")
        log("To enable auto-watch: pip install watchdog")
        log("")
        once_mode()
