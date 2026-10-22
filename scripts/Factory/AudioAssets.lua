-- Stable runtime paths. Provider originals and receipts stay under assets/audio.
local root='audio/v07/runtime/'
return {
    music={file=root..'music.ogg',gain=.54,loop=true},
    grill={file=root..'grill.wav',gain=.30,loop=true,world=true},
    step={file=root..'step.wav',gain=.25,world=true,cooldown=.15},
    pickup={file=root..'pickup.wav',gain=.65,world=true,cooldown=.10},
    drop={file=root..'drop.wav',gain=.60,world=true,cooldown=.10},
    build={file=root..'build.wav',gain=.60,world=true,cooldown=.18},
    machine={file=root..'machine.wav',gain=.42,world=true,cooldown=.65},
    order={file=root..'order.wav',gain=.60,cooldown=.8},
    delivery={file=root..'delivery.wav',gain=.65,cooldown=.35},
    ui={file=root..'ui.wav',gain=.42,cooldown=.06},
    error={file=root..'error.wav',gain=.48,cooldown=.45},
    day={file=root..'day.wav',gain=.55,cooldown=1},
}
