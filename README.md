# PropOobDetector

A Source Engine plugin that detects out-of-bounds props.

Tested on Portal 3420, Portal 4104, Portal 5135, and latest Portal Steampipe version.

## Command
`pod_print_oob_ents`
- Prints entities that are oob

`pod_hud_oob_ents`
- Shows entities that are oob

## Build
Only Windows build.

Use [zig 0.13.0](https://ziglang.org/download/#release-0.13.0)

```sh
zig build -Doptimize=ReleaseSmall
```
