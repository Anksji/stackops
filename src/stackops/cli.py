# src/server_setup/cli.py
import click
import sys
from pathlib import Path

# Add src to Python path
src_path = str(Path(__file__).resolve().parent.parent.parent / 'src')
if src_path not in sys.path:
    sys.path.insert(0, src_path)

from stackops.setup_manager import ServerSetup
from stackops.utils import install_scripts

def clear_screen():
    """Clear the terminal screen"""
    click.clear()

def print_welcome_message():
    """Print welcome message"""
    click.echo(click.style("""
    ╔══════════════════════════════════╗
    ║        StackOps v1.0.0           ║
    ╚══════════════════════════════════╝
    """, fg='bright_blue'))
    
    click.echo(click.style("""
    This tool will help you set up:
    • Initial server configuration
    • Nginx with SSL
    • Docker installation
    • GitHub Actions Runner (optional)
    """, fg='bright_black'))


@click.group()
def cli():
    """Server Setup CLI tool"""
    pass

@cli.command()
def setup():
    """Interactive server setup process"""
    try:
        # Clear screen and show welcome message
        clear_screen()
        print_welcome_message()
        
        # Get user confirmation to start fresh
        if click.confirm(
            click.style("\n⚠️  This will clear any previous setup. Continue?", fg='yellow'),
            default=True
        ):
            # Create setup manager instance (this will clean up previous setup)
            setup_manager = ServerSetup()
            
            # Install required scripts
            if not install_scripts(setup_manager.scripts_dir):
                click.echo(click.style("Failed to install required scripts.", fg='red'))
                return
            
            # Verify environment
            if not setup_manager.verify_environment():
                click.echo(click.style("Environment verification failed.", fg='red'))
                return
            
            # Get domain
            domain = click.prompt(
                click.style("\n🌐 Enter your domain name", fg='bright_blue'),
                type=str
            )
            
            # Get email
            email = click.prompt(
                click.style("\n📧 Enter your email for SSL certificate", fg='bright_blue'),
                type=str
            )
            
            # Ask about GitHub runner
            if click.confirm(
                click.style("\n🤖 Do you want to set up GitHub Actions Runner?", fg='bright_blue'),
                default=False
            ):
                github_token = click.prompt(
                    click.style("\nEnter your GitHub token", fg='bright_blue'),
                    hide_input=True
                )
            else:
                github_token = None
            
            # Show summary
            click.echo("\n" + "="*50)
            click.echo(click.style("Setup Summary:", fg='bright_blue'))
            click.echo(f"Domain: {domain}")
            click.echo(f"Email: {email}")
            click.echo(f"GitHub Runner: {'Yes' if github_token else 'No'}")
            click.echo("="*50)
            
            if click.confirm("\nProceed with setup?", default=True):
                with click.progressbar(
                    label=click.style('Setting up server', fg='bright_blue'),
                    length=4
                ) as bar:
                    success = setup_manager.run_setup(
                        domain=domain,
                        email=email,
                        github_token=github_token
                    )
                    bar.update(4)
                
                if success:
                    click.echo(click.style("\n✨ Setup completed successfully!", fg='green'))
                else:
                    click.echo(click.style("\n❌ Setup failed. Check logs for details.", fg='red'))
            else:
                click.echo(click.style("\nSetup cancelled.", fg='yellow'))
        else:
            click.echo(click.style("\nSetup cancelled.", fg='yellow'))
            
    except KeyboardInterrupt:
        click.echo(click.style("\n\nSetup cancelled by user.", fg='yellow'))
    except Exception as e:
        click.echo(click.style(f"\nError: {str(e)}", fg='red'))

if __name__ == '__main__':
    cli()