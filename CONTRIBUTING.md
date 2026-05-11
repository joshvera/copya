# Contributing

COPYA is intentionally small: pyinfra renders config into a native macOS menu
bar app, and the app owns scheduling, policy, process control, status, and logs.

Before changing behavior:

1. Keep local deployment values in `group_data/all.py`.
2. Keep committed defaults in `group_data/example.py` generic.
3. Add or update focused tests in `tests/test_copya_template.py`.
4. Run the targeted checks:

```bash
python3 -m py_compile deploy.py tests/test_copya_template.py
uv run python -m unittest tests/test_copya_template.py
scripts/oss-scan.sh
git diff --check
```

For backup behavior changes, also run:

```bash
uv run pyinfra @local deploy.py --dry
```

Do not commit secrets, local paths, signing identities, status files, logs,
built app bundles, or private SSID names.
