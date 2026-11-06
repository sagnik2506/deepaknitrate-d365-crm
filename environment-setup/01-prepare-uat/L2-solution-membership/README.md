# L2: solution membership
Question: which solution carries which component, in UAT and in production? Do the 31 production solutions missing from UAT have their components in UAT, and under which solutions?
Method A (all 281 production customer solutions and their UAT counterparts): read each solution's component list, then turn ids into names. A solution that includes a whole table ("include all components") does not list its columns, forms and views individually: mark those as "carried through the whole table", not "carried by nothing".
Method B (key components and any ambiguous case): the layer stack of a component names every solution that carries it, including through whole tables. Key components: Quote and Order Product forms and views, dg_ web resources, plugin assemblies, key tables.
Compare only solutions that exist in both environments; review UAT's other solutions separately (see `../uat-only-review/`).
Output here: `component-to-solution-map-<date>.md` and a link to the workbook in `analysis/environment-sync/`.
