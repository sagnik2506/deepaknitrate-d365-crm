# L3: content
Question: is each component identical in UAT and production, not just present?
Method: content hash (sha256) of forms (form XML), views (fetch and layout XML), web resources, plugin assemblies, flows and workflows. Normalise line endings and the byte-order mark before hashing text. Report identical, different, and size for each.
Order: night 2 forms, views, web resources; night 3 plugin assemblies, flows, workflows, roles.
Output here: `findings-<date>.md` (counts, and the names of every difference with its size). Raw output stays in `C:\DeepakNitrate\EnvSetup\data\parity\`.
