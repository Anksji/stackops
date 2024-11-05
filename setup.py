# setup.py

from setuptools import setup, find_packages

setup(
    name="stackops",
    version="1.0.0",  # This will be overridden by CI/CD
    packages=find_packages(where="src"),
    package_dir={"": "src"},
    install_requires=[
        "click>=7.0",
        # Add other dependencies here
    ],
    entry_points={
        'console_scripts': [
            'stackops=stackops.cli:main',
        ],
    },
    author="Ankitraj Dwivedi",
    author_email="ankitrajatwork@gmail.com",
    description="Server Operations Automation Tool",
    long_description=open("README.md").read(),
    long_description_content_type="text/markdown",
    url="https://github.com/anksji/stackops",
    classifiers=[
        "Development Status :: 3 - Alpha",
        "Intended Audience :: System Administrators",
        "License :: OSI Approved :: MIT License",
        "Operating System :: POSIX :: Linux",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
    ],
    python_requires=">=3.6",
)