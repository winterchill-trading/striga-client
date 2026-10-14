# AGENTS.md: test/live/

The live sandbox walk (`live.ml`). It runs only when the credentials and `STRIGA_LIVE_TESTS=1` are set,
and creates two new sandbox users per run.

- It is an executable, not a test in the offline sense. Keep its output readable: one line per step.
- Each step waits for the provider's asynchronous effects and records a gap when they do not come.
- Do not run it from CI or from a loop. Run it by hand, with the credentials loaded from the environment.
