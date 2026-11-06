# Forward merge (AMS to CR-DEV)
1. AMS exports the hotfix as an unmanaged patch and unpacks it into git.
2. On a schedule (for example weekly), CR-DEV imports the new AMS patches.
3. Conflicts: the AMS version wins for existing components. CR-DEV re-applies its own changes on top.
4. Record each merge in the commit message (patch name and version).
