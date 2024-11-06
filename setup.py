from setuptools import setup, find_packages

setup(
    name="stackops",
    version="1.0.1",
    packages=find_packages(where="src"),
    package_dir={"": "src"},
    include_package_data=True,
    install_requires=[
        "click>=7.0",
    ],
    entry_points={
        'console_scripts': [
            'stackops=stackops.cli:main',
        ],
    },
)