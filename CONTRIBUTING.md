# Contributing

COPYA is intentionally small: a native SwiftPM macOS app owns setup,
scheduling, policy, process control, status, and logs.

Before changing behavior:

1. Keep user-specific runtime config out of git.
2. Add or update focused tests in `tests/test_standalone_app.py` or
   `tests/COPYACoreTests/`.
3. Run the targeted checks:

```bash
swift test
python3 -m py_compile tests/test_standalone_app.py
uv run python -m unittest tests/test_standalone_app.py
scripts/oss-scan.sh
git diff --check
```

For app bundle or release behavior changes, also run:

```bash
scripts/build-app.sh
codesign --verify --deep --strict .build/app/COPYA.app
```

Do not commit secrets, local paths, signing identities, status files, logs,
built app bundles, or private SSID names.
