# Notice to the owner of the account used for the production reads
Subject: Read-only checks on production, <dates>

Hello <name>,
On <dates>, between <times>, we will run read-only checks on production using <account>. They only read solution, form, view, script, plugin and flow definitions (no business records such as quotes, orders, customers or products; configuration content is read and only fingerprints are saved) and make about <n> requests per night at roughly one per second. Nothing is created, changed or deleted. You may see sign-in entries and a rise in API calls for that account on those nights. We can stop at any time. Please tell us if the window clashes with a release or a heavy job.
Thank you, <name>
