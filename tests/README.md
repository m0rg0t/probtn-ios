# Offline preference persistence regression

Run `python3 tests/run_preferences_tests.py` on macOS with Apple's command-line
tools and Python 3. There are no downloaded dependencies. CI first runs the test
against the original commit and requires the specific persistence assertion to
fail, then runs it against the checked-out fix.

The runner extracts the exact `stringFromType:`, `loadFromSetting`, and
`saveToSetting` methods from production `ContentViewController.m`; it does not
copy or reimplement their persistence logic. Foundation supplies real
NSDictionary, NSData, property-list validation and NSUserDefaults. Defaults are
redirected to a random, synthetic suite and removed afterward. Test-only UIImage
and PNG conversion doubles carry deterministic bytes. No vendor SDK, UIKit,
application delegate, analytics, network, remote service or user data is used.

Coverage includes both custom images, property-list validity, save/load byte
round trips, associated settings, default/nil images, failed encoding, and
repeated edits. This validates the sample's persistence boundary; it is **not**
a UIKit image codec test, full app build, SDK compatibility test or UI test.
The app deployment targets, original SDK libraries, project and assets remain
unchanged. Updating the opaque ProBtn/TestFlight binaries still needs a
rebuildable or verified supported vendor baseline; no SDK modernization is
claimed by this isolated sample fix.
