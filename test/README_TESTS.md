# TurboCrud tests

These tests use a tiny in-memory Rails app (sqlite in-memory) so the gem can test
its controller responses without needing a full generated dummy app.

Run:

```bash
bundle exec rake test
```

If you want a full dummy app folder later (with views/assets), we can add it —
but this setup keeps tests fast and easy to run.
