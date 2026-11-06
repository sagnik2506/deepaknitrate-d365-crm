# Branching and versioning
- One branch per environment: `ams`, `cr`. The baseline is the tag `baseline-uat-freeze-<date>`.
- One person creates the next patch version. First check the highest version installed in production.
- Commit after every export: solutions are unpacked into `solutions/ams/` or `solutions/cr/`.
- Tag every release candidate (for example `ams-1.0.0.37`).
