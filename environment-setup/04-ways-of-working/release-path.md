# Release path
AMS or CR-DEV (unmanaged, authoring) -> managed export (once) -> preprod (rehearsal, refreshed from production) -> production (change window, backup, rollback ready).
UAT becomes a managed test environment (refreshed from production), not an authoring one.
Gates: tests passed, change record approved, rollback copy kept, release owner present.
