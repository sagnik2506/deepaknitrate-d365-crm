# Restrict Views plugin (source)

Source of the plugin assembly `Restrict Views` (v1.0.0.0, sandbox) that restricts list reads by sales organisation and division.
Taken from a zip supplied on 5 Nov 2026. Production holds the assembly with 20 steps (RetrieveMultiple, PreOperation, synchronous):
19 enabled and 1 disabled (Quote Product, `quoteproductview`, disabled since 29 Jan 2026). The assembly was last modified in production on 27 Oct 2026.
The match between this source and the assembly in production has **not** been proven (the zip held a Debug build).

Full analysis: `analysis/plugins/restrict-views-analysis.md`.

## Layout
| Path | Content |
|---|---|
| `Restrict Views.sln` | Solution file |
| `Restrict Views/*.cs` | 19 plugin classes (one per table) plus `Properties/AssemblyInfo.cs` |
| `Restrict Views/Restrict Views.csproj`, `packages.config` | Project (.NET Framework 4.6.2, Microsoft.CrmSdk.CoreAssemblies 9.0.2.12) |
| `solution-root-copies/` | Two `.cs` files that sat next to the `.sln` in the zip, NOT part of the project. Kept apart; they differ from the project copies (probably older). Confirm before use |

## What is deliberately NOT here
- `RestrictViews.snk` (the strong-name private key). The project file points to it (`AssemblyOriginatorKeyFile`). To build, get the key from the team that owns the assembly,
  or create a new key and register the new assembly. Never commit it (`.gitignore` blocks `*.snk`).
- `bin/`, `obj/`, `packages/`, `.vs/` and the compiled DLLs. Restore the NuGet packages with `nuget restore`.

## Known issues (see the analysis for details)
Appends the restriction to the first filter whatever its type; no restriction for some sales organisation combinations; business unit names drive access;
hard-coded codes; up to 3 extra synchronous queries per list read, no caching; 20 near-identical classes.
