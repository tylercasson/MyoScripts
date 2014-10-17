scriptId = 'com.tylercasson.scripts.xcode'

-- Wave Out to Clean
-- Wave In to Build
-- Spread Fingers to Build and Run
-- Fist to stop


-- Xcode Product Actions

function build()
    myo.keyboard("b", "press", "command")
end

function run()
    myo.keyboard("r", "press", "command")
end

function clean()
    myo.keyboard("k", "press", "command", "shift")
end

function stop()
    myo.keyboard("period", "press", "command")
end


-- Helpers

function conditionallySwapWave(pose)
    if myo.getArm() == "left" then
        if pose == "waveIn" then
            pose = "waveOut"
        elseif pose == "waveOut" then
            pose = "waveIn"
        end
    end
    return pose
end


-- Unlock mechanism

function unlock()
    enabled = true
    extendUnlock()
end

function extendUnlock()
    enabledSince = myo.getTimeMilliseconds()
end


-- Triggers

function onPoseEdge(pose, edge)
    if pose == "thumbToPinky" then
        if edge == "off" then
            enabled = true
            enabledSince = myo.getTimeMilliseconds()
        elseif edge == "on" and not enabled then
            -- Vibrate twice on unlock
            myo.vibrate("short")
            myo.vibrate("short")
        end
    end

    if enabled then
        pose = conditionallySwapWave(pose)

        if pose == "waveIn" and edge == "on" then
            myo.vibrate("short")
            enabled = false
            build()
        end
        if pose == "waveOut" and edge == "on" then
            myo.vibrate("short")
            enabled = false
            clean()
        end
        if pose == "fingersSpread" then
            myo.vibrate("short")
            enabled = false
            run()
        end
        if pose == "fist" and edge == "on" then
            myo.vibrate("short")
            enabled = false
            stop()
        end
    end
end

-- All timeouts in milliseconds
ENABLED_TIMEOUT = 2200

function onPeriodic()
   if enabled then
        if myo.getTimeMilliseconds() - enabledSince > ENABLED_TIMEOUT then
            enabled = false
        end
    end
end

function onForegroundWindowChange(app, title)
    local wantActive = false
    activeApp = ""
    if platform == "MacOS" then
        wantActive = string.match(app, "com.apple.dt.Xcode")
        activeApp = "Xcode"
    end
    return wantActive
end

function activeAppName()
    return activeApp
end

function onActiveChange(isActive)
    if not isActive then
        enabled = false
    end
end

