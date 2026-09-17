# Services

System services are configured by `.setup/50-services.sh`. Services that are
always enabled are separate from optional services that require confirmation.
User services must be checked with `systemctl --user` and may require an active
login session.

For a service change:

1. inspect the owning setup module and unit file;
2. update the relevant operational guide under `.docs/`;
3. validate shell syntax and unit presence;
4. only enable, restart, or remove the service when the user requested a host
   change.

Keeper.sh, Immich, storage, and related procedures are documented in `.docs/`.
