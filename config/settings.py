import os
from pathlib import Path

class Settings:
    def __init__(self):
        self.ENV = os.getenv('APP_ENV', 'development')
        self.IS_DEVELOPMENT = self.ENV == 'development'
        
        # Base paths
        self.BASE_DIR = Path(__file__).parent.parent
        self.SCRIPTS_DIR = self.BASE_DIR / "scripts"
        self.LOGS_DIR = self.BASE_DIR / "logs"
        
        # Package settings
        self.PACKAGE_NAME = "server-setup"
        self.PACKAGE_VERSION = "1.0.0"
        
    def get_script_path(self, script_name: str) -> Path:
        return self.SCRIPTS_DIR / script_name

settings = Settings()