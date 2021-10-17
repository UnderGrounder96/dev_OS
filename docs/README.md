# Documentation

This folder should provide more details on specific commands/options used.

It should eventually evolve into a proper documentation.

## Login logs

```bash
The `/var/log/wtmp` file records all logins and logouts.
The `/var/log/btmp` file records the bad login attempts.
The `/var/log/faillog` file records failed login attempts.
The `/var/log/lastlog` file records when each user last logged in.

The `/run/utmp` file records the users that are currently logged in.
This file is created dynamically in the boot scripts.
```
