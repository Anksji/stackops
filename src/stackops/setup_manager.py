# src/server_setup/setup_manager.py
import logging
import subprocess
from pathlib import Path
from typing import Optional, Dict
import os
import sys
import shutil

class ServerSetup:
    """Main class for server setup operations"""
    
    def __init__(self):
        """Initialize ServerSetup with logging configuration"""
        # Initialize paths
        self.base_dir = Path(__file__).parent
        self.scripts_dir = self.base_dir / "scripts"
        self.logs_dir = self.base_dir / "logs"
        
        # Clean up previous setup
        self.cleanup_previous_setup()
        
        # Setup logging first
        self.setup_logging()
        
        # Ensure scripts directory exists
        self.scripts_dir.mkdir(parents=True, exist_ok=True)
        
        # Initialize logger instance
        self.logger = logging.getLogger(__name__)
        self.logger.info("ServerSetup initialized")
    
    def cleanup_previous_setup(self):
        """Clean up artifacts from previous setup"""
        try:
            # Remove logs directory
            if self.logs_dir.exists():
                shutil.rmtree(self.logs_dir)
            
            # Remove scripts directory
            if self.scripts_dir.exists():
                shutil.rmtree(self.scripts_dir)
                
        except Exception as e:
            print(f"Warning: Cleanup failed - {e}")
    
    def setup_logging(self) -> None:
        """Configure logging for the application"""
        try:
            # Create logs directory if it doesn't exist
            self.logs_dir.mkdir(parents=True, exist_ok=True)
            
            # Configure logging
            logging.basicConfig(
                level=logging.INFO,
                format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
                handlers=[
                    # File handler
                    logging.FileHandler(self.logs_dir / 'setup.log'),
                    # Console handler
                    logging.StreamHandler(sys.stdout)
                ]
            )
        except Exception as e:
            print(f"Error setting up logging: {e}")
            sys.exit(1)
    
    def run_script(self, script_name: str, env_vars: Optional[Dict[str, str]] = None) -> bool:
        """
        Run a shell script with proper error handling
        
        Args:
            script_name: Name of the script to run
            env_vars: Optional environment variables for the script
        """
        script_path = self.scripts_dir / script_name
        
        if not script_path.exists():
            self.logger.error(f"Script not found: {script_path}")
            return False
            
        try:
            # Prepare environment variables
            env = os.environ.copy()
            if env_vars:
                env.update(env_vars)
            
            # Run the script
            self.logger.info(f"Running script: {script_name}")
            
            # Check if we're on Windows (for testing)
            if sys.platform == 'win32':
                self.logger.warning("Running on Windows - skipping script execution")
                return True
            
            result = subprocess.run(
                ['sudo', 'bash', str(script_path)],
                env=env,
                check=True,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE
            )
            
            self.logger.info(f"Script output: {result.stdout}")
            return True
            
        except subprocess.CalledProcessError as e:
            self.logger.error(f"Script failed: {e.stderr}")
            return False
        except Exception as e:
            self.logger.error(f"Error running script: {str(e)}")
            return False
    
    def verify_environment(self) -> bool:
        """Verify that all required conditions are met"""
        try:
            # Check if running as root or with sudo (only on Unix-like systems)
            if sys.platform != 'win32':
                if os.geteuid() != 0:
                    self.logger.warning("Not running with root privileges. Some operations may fail.")
            
            # Check if required directories exist
            for directory in [self.scripts_dir, self.logs_dir]:
                if not directory.exists():
                    directory.mkdir(parents=True, exist_ok=True)
            
            # Verify script permissions
            for script in ['initial_setup.sh', 'docker_setup.sh', 'setup.sh', 'runner-setup.sh']:
                script_path = self.scripts_dir / script
                if script_path.exists():
                    if sys.platform != 'win32':
                        script_path.chmod(0o755)
            
            return True
            
        except Exception as e:
            self.logger.error(f"Environment verification failed: {str(e)}")
            return False
    
    def run_setup(self, 
                 domain: str,
                 email: str,
                 github_token: Optional[str] = None) -> bool:
        """
        Run the complete setup process
        
        Args:
            domain: Domain name for the server
            email: Email for SSL certificate
            github_token: Optional GitHub token for runner setup
        """
        try:
            self.logger.info("Starting server setup process...")
            
            # 1. Run initial setup
            self.logger.info("Running initial server setup...")
            if not self.run_script('initial_setup.sh'):
                return False
                
            # 2. Run Docker setup
            self.logger.info("Setting up Docker...")
            if not self.run_script('docker_setup.sh'):
                return False
                
            # 3. Configure Nginx and SSL
            self.logger.info("Configuring Nginx and SSL...")
            if not self.run_script('setup.sh', {
                'DOMAIN': domain,
                'EMAIL': email
            }):
                return False
                
            # 4. Set up GitHub runner if token provided
            if github_token:
                self.logger.info("Setting up GitHub Actions runner...")
                if not self.run_script('runner-setup.sh', {
                    'GITHUB_TOKEN': github_token
                }):
                    return False
            
            self.logger.info("Setup completed successfully!")
            return True
            
        except Exception as e:
            self.logger.error(f"Setup failed: {str(e)}")
            return False