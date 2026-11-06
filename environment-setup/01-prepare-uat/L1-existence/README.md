# L1: existence (environment level, by component type)
Question: does production have any customer component that UAT lacks (or the other way round)?
Scope (customer components only; Microsoft's own are excluded by publisher): tables, columns (on every table), forms, views, web resources, plugin assemblies and steps, flows and workflows, security roles (names), option sets, relationships, apps and site maps.
Method: match tables and columns by NAME (internal ids differ between environments); forms, views, flows and web resources can be matched by id.
Output here: `results-<date>.md` - per type: in both, only in UAT, only in production, with names. Raw output: `C:\DeepakNitrate\EnvSetup\data\parity\night1-existence-membership\`.
