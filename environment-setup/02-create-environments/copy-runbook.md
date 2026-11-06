# Copy runbook
1. Confirm the UAT freeze is still in force.
2. Power Platform admin center, Environments, UAT, Copy. Choose a MINIMAL copy (customizations only, no records). Target: the new sandbox.
3. Repeat for the second environment from the same freeze snapshot.
4. Record: start and end time, copy type, source version, any warnings.
5. Verify: solution list in each new environment equals UAT at the freeze date (run the solution list comparison).
6. Do NOT turn on flows or integrations yet (Phase 3).
Rollback: delete or reset the new environment. UAT is untouched.
