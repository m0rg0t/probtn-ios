#!/usr/bin/env python3
"""Run the actual persistence methods with Foundation and test-only image doubles."""
import argparse
import pathlib
import re
import subprocess
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
DEFAULT = ROOT / "Kitchensink/Kitchensink/Classes/ViewControllers/Main/ContentViewController.m"
parser = argparse.ArgumentParser()
parser.add_argument("--source", type=pathlib.Path, default=DEFAULT)
args = parser.parse_args()
source = args.source.read_text()
methods = []
for signature in ("- (NSString*)stringFromType:(ContentPreferenceType)type", "- (void)loadFromSetting", "- (void)saveToSetting"):
    matches = re.findall(r"^" + re.escape(signature) + r" \{.*?^\}", source, re.M | re.S)
    if len(matches) != 1:
        raise SystemExit("Expected exactly one production method: " + signature)
    methods.append(matches[0])
with tempfile.TemporaryDirectory(prefix="probtn-preferences-") as directory:
    work = pathlib.Path(directory)
    (work / "ProductionPersistence.inc").write_text("\n\n".join(methods))
    subprocess.run(["xcrun", "clang", "-fobjc-arc", "-Wall", "-Wextra", "-Werror", "-framework", "Foundation", "-I", str(work), str(ROOT / "tests/preferences_test.m"), "-o", str(work / "preferences-test")], check=True)
    subprocess.run([str(work / "preferences-test")], check=True)
