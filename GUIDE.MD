##  Development Workflow

1. Always activate virtual environment before working:
```powershell
.\venv\Scripts\activate
```

2. Run your setup manager:
```powershell
python src/setup_manager.py
```

3. Run tests:
```powershell
pytest tests/
```

4. Format code:
```powershell
black src/ tests/
```

5. Check code quality:
```powershell
pylint src/ tests/
```