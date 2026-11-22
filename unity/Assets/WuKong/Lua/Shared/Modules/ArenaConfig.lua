return {
    camera = {
        distance = 4.6, lockDistance = 6.8, pitch = 10.313, height = 1.5,
        fov = 55, probeRadius = 0.35, clearance = 0.3, minDistance = 0.6,
        alignSpeed = 90, alignGrace = 0.5, mask = 513,
        restoreDistance = 5, restorePitch = 10, restoreHeight = 1.5,
    },
    spawn = { x = 0, y = -1.197, z = 0, yaw = 1.459 },
    boss = { x = 1.226, y = -6.343, z = 48.157, targetHeight = 3.4 },
    fight = { x = -0.274, y = -6.419, z = 38.657, radius = 16.26 },
    -- Reproducible route probes use platform movement, never position stepping.
    route = {
        { name = "spawn", x = 0, z = 2 },
        { name = "passage", x = 0, z = 10 },
        { name = "stairs", x = 0, z = 20 },
        { name = "fight-entry", x = 0, z = 33 },
        { name = "blood-pool", x = 0, z = 42 },
    },
}
