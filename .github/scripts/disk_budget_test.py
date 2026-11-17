import contextlib
import io
import json
import sys
import unittest
from unittest.mock import patch

import disk_budget


def fs(free_bytes, free_inodes, device=1):
    return dict(device=device, free_bytes=free_bytes, free_inodes=free_inodes)


class DiskBudgetTest(unittest.TestCase):
    def test_requires_explicit_budget_for_bytes_and_inodes(self):
        for min_bytes, min_inodes in [(0, 20), (100, 0), (-1, 20)]:
            with patch.object(disk_budget, 'probe') as probe:
                self.assertFalse(disk_budget.may_skip(['/'], min_bytes, min_inodes))
                probe.assert_not_called()

    def test_skips_only_with_both_reserves_on_one_filesystem(self):
        for store, expected in [(fs(100, 20), True), (fs(99, 20), False),
                                (fs(100, 19), False), (fs(100, 20, 2), False)]:
            with patch.object(disk_budget, 'probe', return_value={'/': fs(100, 20), '/nix/store': store}):
                self.assertEqual(disk_budget.may_skip(['/', '/nix/store'], 100, 20), expected)

    def test_missing_probe_uses_fallback(self):
        with patch.object(disk_budget, 'probe', side_effect=OSError('missing')):
            with contextlib.redirect_stderr(io.StringIO()):
                self.assertFalse(disk_budget.may_skip(['/'], 100, 20))

    def measure(self, observations, *, runs_long=False, status=0):
        output = io.StringIO()
        delay = 'import time; time.sleep(0.15); ' if runs_long else ''
        with (patch.object(disk_budget, 'probe', side_effect=observations),
              patch.object(disk_budget, 'INTERVAL', 0.05),
              contextlib.redirect_stdout(output)):
            rc = disk_budget.watch(['/'], [sys.executable, '-c', f'{delay}raise SystemExit({status})'])
        result = json.loads(output.getvalue().splitlines()[-1].split(' ', 2)[2])
        return rc, result

    def test_records_transient_low_even_if_final_space_recovers(self):
        rc, result = self.measure(iter([{'/': fs(100, 80)}, {'/': fs(30, 50)}]
                                       + [{'/': fs(90, 70)}] * 100), runs_long=True)
        self.assertEqual(rc, 0)
        self.assertGreaterEqual(result['samples'], 3)
        self.assertEqual(result['minima']['/'], fs(30, 50))
        self.assertIsNone(result['error'])

    def test_preserves_child_failure_and_reports_broken_measurement(self):
        rc, result = self.measure([{'/': fs(100, 80)}, {'/': fs(100, 80, 2)}], status=27)
        self.assertEqual(rc, 27)
        self.assertIn('filesystem changed', result['error'])

    def test_probe_failure_invalidates_successful_measurement(self):
        rc, result = self.measure([{'/': fs(100, 80)}, OSError('missing')])
        self.assertEqual(rc, 1)
        self.assertEqual(result['error'], 'missing')


if __name__ == '__main__':
    unittest.main()
