# tests/test_setup.py
import pytest
from pathlib import Path
from src.stackops.setup_manager import ServerSetup
from src.stackops.utils import ensure_directory_exists

def test_server_setup_creation():
    """Test basic ServerSetup instance creation"""
    setup = ServerSetup()
    assert setup is not None
    assert setup.logger is not None

def test_ensure_directory_exists(tmp_path):
    """Test directory creation utility"""
    test_dir = tmp_path / "test_dir"
    ensure_directory_exists(test_dir)
    assert test_dir.exists()
    assert test_dir.is_dir()

def test_run_setup():
    """Test run_setup method"""
    setup = ServerSetup()
    result = setup.run_setup()
    assert result is True  # assuming success for now

@pytest.fixture
def setup_instance():
    """Fixture for ServerSetup instance"""
    return ServerSetup()

def test_setup_with_config(tmp_path):
    """Test ServerSetup with config file"""
    config_path = tmp_path / "config.json"
    config_path.write_text("{}")
    setup = ServerSetup(config_path=config_path)
    assert setup.config_path == config_path