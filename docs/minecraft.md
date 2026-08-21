# Minecraft — Crafty Controller on Bazzite

Minecraft servers on `console`, managed through [Crafty Controller](https://docs.craftycontrol.com/)
— a web panel that creates, runs, backs up and configures servers without
touching the terminal. Runs as a single rootless Podman container via Quadlet.

Players reach the server over Tailscale only; nothing is exposed to the
internet and no router port-forwarding is involved.

## Architecture

| Component | Image | Port | Purpose |
|-----------|-------|------|---------|
| `crafty` | `registry.gitlab.com/crafty-controller/crafty-4:latest` | 8443 | Web panel (HTTPS) |
| Minecraft server | managed by Crafty | 25565 | The game server itself |

The Quadlet unit lives at `.config/containers/systemd/crafty.container` in this
repo. Crafty runs the Minecraft server as a child process inside its own
container — there is no separate Minecraft container.

Data lives in `~/.local/share/crafty/` on `console`:

| Path | Contents |
|------|----------|
| `config/` | Crafty's SQLite DB, TLS cert, credentials |
| `servers/<uuid>/` | Each server's world, jar, `server.properties`, mods |
| `backups/` | Scheduled backups |
| `logs/` | Crafty's own logs |
| `import/` | Drop server zips here to import them |

## Access

| What | Address | Who |
|------|---------|-----|
| Crafty panel | `https://console:8443` | You (personal tailnet) |
| Minecraft server | `console:25565` | You + friends (`tag:gamer`) |

The panel serves a **self-signed certificate** — your browser will warn on
first visit. That is expected; accept it.

Login is `admin`. The password was changed from the generated default, so
`~/.local/share/crafty/config/default-creds.txt` is **stale** — ignore it.

The login page always renders a 2FA code field and a passkey button regardless
of whether either is configured. **Leave the 2FA field blank**; the form only
sends a code if you type one. No TOTP or passkey is enrolled on this instance,
and `superMFA` is off.

Three failed logins within three minutes trigger a **five-minute cooldown**
(HTTP 429) for that source IP. It is held in memory, so restarting the service
clears it:

```bash
systemctl --user restart crafty.service
```

To change the password, PATCH it through the API (this hashes it correctly —
editing the database directly does not):

```bash
TOKEN=$(curl -sk -X POST https://localhost:8443/api/v2/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"CURRENT"}' \
  | python3 -c 'import sys,json;print(json.load(sys.stdin)["data"]["token"])')

curl -sk -X PATCH https://localhost:8443/api/v2/users/1 \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"password":"NEW"}'
```

## Current Server

| Name | Version | Port | Memory | Difficulty | UUID |
|------|---------|------|--------|------------|------|
| Aether 1.21.1 | Fabric 1.21.1 (loader 0.19.3) | 25565 | 3–8 GB | hard | `6a39d4a5-7b0c-402a-86a3-f585c940d363` |

Autostart and crash detection are on, so it survives a `console` reboot.

**The version is pinned by The Aether**, which caps at 1.21.1 — as does Deeper
and Darker. Nothing newer is common to both, so this server does not follow
latest Minecraft.

### Java 21, not the container default

The Crafty image ships JDK 8/11/17/21/25 and defaults to **25**. This server's
execution command is pinned to Java 21:

```
/usr/lib/jvm/java-21-openjdk-amd64/bin/java -Xms3000M -Xmx8000M -jar fabric.jar nogui
```

On JDK 25 the server **segfaults ~18 s into boot**, right after
`Generating keypair`, with no error in `latest.log` — the crash lands in
`hs_err_pid*.log` in the server root. The faulting frame is spark's bundled
`libasyncProfiler.so`, which predates JDK 25. spark builds are strictly
per-Minecraft-version (1.10.109 is the only one for 1.21.1), so there is no
newer jar to upgrade to. Java 21 is what 1.21.1 targets anyway.

Set it through the API, not the file — Crafty stores it in its DB:

```bash
curl -sk -X PATCH -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"execution_command":"/usr/lib/jvm/java-21-openjdk-amd64/bin/java -Xms3000M -Xmx8000M -jar fabric.jar nogui"}' \
  https://localhost:8443/api/v2/servers/<uuid>
```

### Mods

22 jars in `~/.local/share/crafty/servers/<uuid>/mods/` (120 modules once
Fabric API, C2ME and Aether's bundled libraries are counted), plus three world
datapacks.

| Mod | Purpose |
|-----|---------|
| Fabric API | required base for everything below |
| The Aether | the Aether dimension — Moas, dungeons, the whole 1.5.11 rewrite |
| Deeper and Darker | Otherside dimension, sculk mobs, warden-adjacent content |
| owo-lib | required by both Aether and Deeper and Darker |
| Fabric Language Kotlin | required by Elytra Trims |
| Almanac | required by Let Me Despawn |
| Elytra Back Slot | dedicated elytra slot — wear a chestplate at the same time |
| Elytra Trims | armor trims applied to elytra |
| Copper Rails | oxidizable copper rails and crossings |
| Minecart Trains Fork | couple minecarts into trains — the server links them, the client draws the link |
| Simple Smithing Overhaul | rebalances smithing/anvil costs, adds templates and a 13-advancement tree |
| Fzzy Config | required by Simple Smithing Overhaul |
| Lithium | general tick/game-logic optimizer — the single biggest win |
| FerriteCore | cuts memory footprint |
| Krypton | network stack |
| C2ME | parallel chunk generation and I/O |
| VMP | multiplayer-oriented optimizations |
| Alternate Current | redstone engine rewrite |
| Let Me Despawn | trims live entity count |
| Clumps | merges XP orbs, cutting entity churn |
| Chunky | chunk pre-generation |
| spark | profiler, for diagnosing tick lag |

One datapack lives in `world/datapacks/`, not `mods/`:

| Datapack | Purpose |
|----------|---------|
| `darcenos-minecarts-slower-1.4.zip` | faster ridden/chest minecarts that chunk-load, at **half** the author's default speed |
| `soul-elytra-cape.zip` | hand-written; appends `deeperdarker:soul_elytra` to the `accessories:cape` item tag |
| `copper-rail-x12.zip` | hand-written; copper rail crafts 12 instead of 6, matching the powered rail |

World datapacks load **after** every mod's built-in pack, so a file under
`world/datapacks/` overrides a mod's own data. That is how the copper rail
recipe is retuned without touching the jar — copy the mod's recipe JSON, change
the `count`, ship it under the same path (`data/copperrails/recipe/copper_rail.json`).
`pack_format` is **48** for 1.21.1. Apply with `/reload`; no restart, no
downtime, and `datapack list enabled` confirms the file lands last in the order.

Worth knowing before retuning rails: **Copper Rails already overrides vanilla's
powered rail to 12** via its own `data/minecraft/recipe/powered_rail.json`, so
it and Darceno's agree on that number rather than fighting over it. The copper
rail recipe is the powered rail's shape with copper swapped for gold, which is
why 12 is the consistent value. `rail_crossing` still yields 1, and the four
waxed variants are 1:1 shapeless waxing with no count to tune.

**Darceno's Minecarts ships its slow variant only as a datapack.** The Modrinth
`.jar` (`1.4+mod`) packages the fast variant alone; `darcenos-minecarts-slower-1.4.zip`
under the `datapack` loader is the only way to get half speed. Being a datapack
it is 100% server-side — no client install, and the server auto-enables it on
the next boot (`Found new data pack file/..., loading it automatically`).
Confirm with `datapack list enabled`.

**Clients need Fabric 1.21.1** plus the eleven content mods: Fabric API, The
Aether, Deeper and Darker, owo-lib, Elytra Back Slot, Elytra Trims, Copper
Rails, Minecart Trains Fork, Simple Smithing Overhaul, Fzzy Config and Fabric
Language Kotlin. The Aether
bundles Accessories and Cumulus itself, so those are not separate downloads.
The optimization mods are all server-side and do not need to be mirrored on
clients.

Ready-made Modrinth packs live in `~/Downloads` on `console`:
`aether-1.21.1-console.mrpack` (plain Fabric, the eleven mods) and
`aether-1.21.1-FO.mrpack` (Fabulously Optimized 6.5.0 plus the nine content
mods — FO already ships Fabric API and Fabric Language Kotlin, and adding a
second copy of either aborts the launch on a duplicate mod id). Import with
Prism's **Add Instance → Import from zip**.

**Match the loader and the game version — never the version number alone.**
Elytra Trims and Elytra Slot publish Fabric and NeoForge builds under the
*same* `version_number`; Copper Rails ships five distinct jars all called
`1.0.5`, one per Minecraft version; and Deeper and Darker's newest build
overall is NeoForge, which is what Modrinth's default download button hands
you. Select on `loaders` **and** `game_versions` together, and assert the
result — a wrong pick is silent otherwise.
A NeoForge client cannot join this Fabric server at all once content mods are
involved, and the failure looks like the mods simply not installing.

### Accessories won, Trinkets lost — pick the elytra mod accordingly

The Aether jar-in-jars **Accessories**, which becomes the active accessory
system. A player's `.dat` then carries only Accessories containers:

```
accessories:chest  accessories:feet  accessories:head  accessories:legs
aether:accessory_slot  aether:cape_slot
```

There is no `trinkets` container at all. Accessories ships Trinkets *interop*
mixins, but they do not import third-party slot definitions.

This silently breaks any mod that registers a **Trinkets** slot. `illusivesoulworks`'
**Elytra Slot** (`data/trinkets/entities/elytra.json` → slot `chest/cape`) loads
without a single error or warning and does nothing — the slot it creates never
exists. It was swapped out on 2026-08-18 for **Elytra Back Slot**, which ships
both an `AccessoriesProvider` and a `TrinketsProvider` and registers into
`data/accessories/tags/item/cape.json`.

Its cape tag lists only `minecraft:elytra`, so modded elytras need appending —
hence the `soul-elytra-cape.zip` datapack for Deeper and Darker's soul elytra.
Any future modded elytra needs the same one-file addition.

Removing a mod that ships a data pack leaves the world's enabled-datapack list
pointing at it, and every boot then logs `Missing data pack <id>`. It is
cosmetic, and it clears itself the moment the mod comes back
(`Found new data pack <id>, loading it automatically`).

The boot log carries a wall of `Parsing error loading recipe` and
`No data fixer registered` lines. These are **cosmetic**: Aether and Deeper
and Darker ship compat recipes for mods that are not installed here
(Supplementaries, JEED). Likewise every `@Mixin target net.minecraft.class_310
was not found` is a client-only mixin on a dedicated server.

### Adding a mod

Resolve dependencies **transitively** before installing — Modrinth declares
them, and a missing one aborts boot at mod resolution.

```bash
# Query the required deps for a slug before downloading:
curl -s "https://api.modrinth.com/v2/project/<slug>/version?game_versions=%5B%221.21.1%22%5D&loaders=%5B%22fabric%22%5D" \
  | python3 -c 'import sys,json; print(json.load(sys.stdin)[0]["dependencies"])'
```

Prefer the newest `release` and fall back to `alpha`/`beta` only where that is
all there is — C2ME and VMP have no stable 1.21.1 build.

CurseForge is largely Forge/NeoForge territory; search Modrinth with the loader
facet instead. A mod that exists only for Forge, or that stops at an older
Minecraft version, has no workaround — *More Minecarts and Rails* fails on both
counts (Forge only, capped at 1.20.2).

Install into the mods directory through the user namespace, since the tree is
owned by the container's mapped uid:

```bash
podman unshare bash -c "cp /tmp/new/*.jar $DEST/mods/ && chown -R 1000:0 $DEST/mods"
```

Worldgen mods only affect chunks generated after they are installed. Adding one
to an established world leaves existing terrain untouched.

## Letting Friends In (Tailscale, tag-based)

Friends join your tailnet as **tagged devices**. Tagged nodes carry no user
identity, so they consume **no seats** — the 6-user cap on the Personal plan
does not apply to them, and the device count is unlimited.

> **The tag is not optional.** An auth key without a tag attributes the device
> to *your* identity, and Tailscale makes all devices sharing an identity
> mutually visible *even when the policy forbids connecting*. Friends would see
> `laptop`, `console`, `devbox` and `maistodos` in their device list. With the
> tag, they see only what the ACL permits.

### 1. Tailnet policy file

In the [admin console](https://login.tailscale.com/admin/acls), replace the
default allow-all policy with:

```jsonc
{
  "hosts": {
    "minecraft": "100.120.120.72"   // console's Tailscale IP
  },

  "tagOwners": {
    "tag:gamer": ["autogroup:admin"]
  },

  "acls": [
    // Your own devices keep full access to everything.
    { "action": "accept", "src": ["autogroup:member"], "dst": ["*:*"] },

    // Friends' devices reach the Minecraft port and nothing else —
    // not the Crafty panel, not SSH, not each other.
    {
      "action": "accept",
      "src": ["tag:gamer"],
      "proto": "tcp",
      "dst": ["minecraft:25565"]
    }
  ]
}
```

The default policy is `src: ["*"] → dst: ["*:*"]`. It **must** be replaced, not
appended to — leaving it in place grants tagged devices full access.

### 2. Generate a reusable auth key

Admin console → **Settings → Keys → Generate auth key**:

- **Reusable**: **off** — generate one single-use key per guest, on demand
- **Expiry**: up to 90 days (a hard cap — 1 to 90 inclusive)
- **Tags**: `tag:gamer`
- **Ephemeral**: off (friends' machines should persist between sessions)

Prefer one single-use key per guest over a shared reusable one. Tagged devices
never expire and revoking a key does **not** remove devices it already
authorized, so key creation is the only real chokepoint. A single-use key caps
the damage at one device; a shared reusable key is a standing invitation that
keeps working as it gets forwarded around.

Exceptions: a guest with two machines needs two keys, and onboarding a whole
group at once is easier with a reusable key — but give that one a short expiry.
The combination to avoid is reusable *and* long-lived.

**The 90-day cap does not disconnect anyone.** It only limits how long that
key string keeps working for onboarding *new* devices. Two separate expiries
are at play:

- An expired auth key leaves already-joined devices alone — "any device
  authorized by it remains authorized until its node key expires".
- Tagged devices have node key expiry **disabled by default** on first
  authentication, so friends never need to re-authenticate at all.

When the key lapses, generate another one; existing players are unaffected.

For onboarding that never lapses, an **OAuth client** with the `auth_keys`
scope and `tag:gamer` does not expire, and can mint keys on demand via
`POST /api/v2/tailnet/:tailnet/keys`. Worth it only for a self-service flow —
regenerating a key each quarter is less machinery to maintain.

### 3. What the friend runs

Install Tailscale, then once:

```bash
tailscale up --auth-key=tskey-auth-XXXXXXXX
```

Then connect in Minecraft to `console:25565` (or `100.120.120.72:25565` if
MagicDNS doesn't resolve for them).

### Revoking access

Remove the individual device from the admin console's machine list. To cut
everyone off at once, revoke the auth key — existing devices keep working, so
remove them too, or rotate the tag.

## Server Management

Day-to-day management is the web panel. From the terminal:

```bash
systemctl --user status  crafty.service
systemctl --user restart crafty.service
systemctl --user stop    crafty.service
journalctl --user -u crafty.service -f      # Crafty's logs

# The Minecraft server's own log:
tail -f ~/.local/share/crafty/servers/<uuid>/logs/latest.log
```

## Switching to a Modpack Later

The Crafty panel creates Forge/NeoForge/Fabric/Paper servers directly, and its
file manager handles individual mod `.jar` uploads.

**CurseForge** modpacks import through the panel. **Modrinth** `.mrpack` files
do not — the format is an archive that needs unpacking first:

```bash
# On console, unpack the pack, then zip the result into ~/.local/share/crafty/import/
mrpack-install <pack-slug> --server-dir /tmp/pack
```

Then use the panel's **Zip Import** to create the server from it.

For a modpack, raise the memory ceiling well above the vanilla server's 6 GB —
kitchen-sink packs want 8–12 GB. `console` has 31 GB total.

Note that new servers get a port in the 25500–25600 range, which is **not
published** by the container. Add a `PublishPort=` line to `crafty.container`
for the new port and restart the service.

## Notes

- **`stow` is not installed on `console`** (Bazzite is image-based). Quadlet
  symlinks are created by hand, matching the existing pattern:
  ```bash
  ln -sfn ../../../Dotfiles/.config/containers/systemd/crafty.container \
          ~/.config/containers/systemd/crafty.container
  ```
- Crafty runs as uid 1000, gid 0. Host directories must be owned accordingly
  inside the user namespace:
  ```bash
  podman unshare chown -R 1000:0 ~/.local/share/crafty
  ```
- Volumes use the shared SELinux label (`:z`), consistent with the fix applied
  to the Paperclip data volume.
- `online-mode=true` is set, so Mojang authentication is enforced. The
  whitelist is **off** — with tailnet-only access that is reasonable, but the
  panel can enable it if you want a second gate.

## Troubleshooting

### Panel unreachable at `https://console:8443`

```bash
ssh console 'systemctl --user status crafty.service'
ssh console 'journalctl --user -u crafty.service -n 50'
```

First boot generates the SQLite DB and a self-signed cert and can take a minute.

### Friend can't connect

1. Confirm their device appears in the admin console tagged `tag:gamer`.
2. Confirm the ACL still has the `tag:gamer → minecraft:25565` rule and that
   the default allow-all was removed rather than left alongside it.
3. Have them try the raw IP `100.120.120.72:25565` — a working connection there
   but not on `console:25565` is a MagicDNS problem, not an ACL one.

### Server won't start after a Crafty update

Check the memory ceiling against what's free, then read the server log at
`~/.local/share/crafty/servers/<uuid>/logs/latest.log`.
