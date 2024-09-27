init: *const fn () void,
deinit: *const fn () void,

onTick: ?*const fn () void = null,
onPaint: ?*const fn () void = null,
onSessionStart: ?*const fn () void = null,

loaded: bool = false,
