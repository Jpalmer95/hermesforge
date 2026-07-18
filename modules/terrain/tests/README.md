# terrain tests

End-to-end coverage is in `templates/golden-demo/golden_test.gd` and
`golden_test2.gd` (run: `python qa/run.py --golden 1` and
`python qa/run.py --golden 2`), which drive this module's capability through
the real hermes_bridge socket and assert the resulting scene.
Module-specific unit tests land in a future phase.
