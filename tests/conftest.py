import sys
from pathlib import Path

# Ensure the repository root is importable as `scripts.*`, regardless of
# the directory pytest is invoked from.
ROOT_DIR = Path(__file__).resolve().parent.parent
if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))
