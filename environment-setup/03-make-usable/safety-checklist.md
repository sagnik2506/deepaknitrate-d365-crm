# Safety checklist (do this before anything else)
| # | Item | AMS | CR-DEV | Notes |
|---|---|---|---|---|
| 1 | Cloud flows turned off or re-pointed | | | A copy does not run flows by default; keep it that way until checked |
| 2 | Integrations switched off or pointed at test endpoints (for example the plugin assembly that sends order schedules to the external ERP) | | | Check environment variables and connection references |
| 3 | Email sending and mailbox processing disabled | | | |
| 4 | Scheduled jobs and bulk delete jobs reviewed | | | |
| 5 | Service endpoints, webhooks and custom APIs reviewed | | | |
| 6 | No real customer contact data can receive a message | | | |
| 7 | Environment variable and connection reference values recorded | | | |
