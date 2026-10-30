# Tests

Mock tests for the `run.sh` of `minecraft_vanilla_server` and `minecraft_paper_geyser_server`.
They run the real scripts with a mock `curl` and a mock `java` in the `PATH` and the `OPTIONS_FILE`
variable pointing to a generated `options.json`. There is no network access and no Minecraft server involved.

```sh
tests/run_all.sh     # needs bash, jq, tar, sha1sum, sha256sum, timeout (any Linux)
tests/docker.sh      # same inside a Debian container, no local dependencies
```

Set `KEEP=1` to keep the temporary sandboxes for debugging.

## What is covered

Both add-ons: missing EULA, `xms_mb` greater than `xmx_mb`, normal start, SIGTERM sends `stop` to the server
and exits with 0, restart without re-downloads, wrong checksum (abort, no JAR left behind), unreachable
upstream API, exit code of a crashing server.

Vanilla: Java version resolved from Mojang's `javaVersion` (25, 21, 17 and the Java 8 fallback for versions before 1.17),
`java_major` override, cleanup of old Java runtimes, custom `server_jar_url`.

Paper + Geyser: `latest` picks the newest version with a `STABLE` build and skips versions containing `-`,
`allow_experimental`, a pinned version with its own Java version, `java_major` override, failing plugin
downloads (server still starts, existing JAR is kept), `update_plugins=false`, `bedrock_support=false`,
non-https plugin URLs are ignored, the one-time Geyser configuration. Also the Bedrock chat switch (`enforce-secure-profile` in both directions, untouched without Bedrock support).

Both add-ons: the whitelist, ban list and operator lists (commands sent to the server, sync of added and removed
entries, invalid names, the whitelist switch). Paper additionally covers Bedrock names with a dot.

Both add-ons: the free world options, the gameplay settings in `server.properties` (including special characters in the MOTD and invalid values) and the game rules (both spellings, converted to the version of the server, invalid entries).

Both add-ons: the performance options (G1 always set, `nice` priority, CPU core pinning and Java thread count, the memory guard with a fake `meminfo` and a container limit, fixed heap, performance profiles).

## How it works

- `mocks/curl` serves files from a fake web root (`$MOCK_WWW`) and logs every request. Failures are injected
  through `$MOCK_FAIL`.
- `mocks/java` is packed into a fake Temurin archive, so the scripts install it exactly like a real JRE.
  In `wait` mode it blocks until it reads `stop` on stdin.
- `lib.sh` builds the fixtures (Mojang manifest, Paper Fill v3 API, Geyser and Floodgate downloads).

The real services (Mojang, PaperMC, GeyserMC, Adoptium) are not part of these tests. Their formats were checked
separately with a smoke test in Docker.
