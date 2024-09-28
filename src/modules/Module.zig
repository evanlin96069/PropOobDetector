name: []const u8,

init: *const fn () bool,
deinit: *const fn () void,

loaded: bool = false,
