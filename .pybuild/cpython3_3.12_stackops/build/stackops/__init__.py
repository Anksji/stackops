"""Server Setup Package initialization"""
from importlib import metadata

try:
    __version__ = metadata.version("server-setup")
except metadata.PackageNotFoundError:
    __version__ = "0.0.0"

from .setup_manager import ServerSetup