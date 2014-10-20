scriptId = 'com.tylercasson.scripts.pandora'

-- Wave In to skip to the next song

-- Hold a Wave Out gesture and rotate arm to adjust volume.
-- Tip: If you pinch your fingers together as if you were grabbing a volume
-- knob, this might make a little more sense and feel more natural

-- Spread Fingers to toggle play and pause

-- Make a "thumbs up" fist and release to give the current song a thumbs up

-- Make a "thumbs up" fist, rotate into a "thumbs down" fist and release to
-- give the current song a thumbs down


-- Pandora keyboard shortcuts

function togglePlayPause()
    myo.keyboard("space", "press")
end

function nextSong()
    myo.keyboard("right_arrow", "press")
end

function volumeUp()
    myo.keyboard("up_arrow", "press", "alt")
end

function volumeDown()
   myo.keyboard("down_arrow", "press", "alt")
end

function thumbsUp()
    myo.keyboard("equal", "press", "shift")
end

function thumbsDown()
    myo.keyboard("minus", "press")
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

function degreesForRadians(radians)
    return radians * (180.0 / math.pi)
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

    conditionallySwapWave(pose)

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
        if pose == "waveIn" and edge == "on" then
            nextSong()
        end

        if pose == "waveOut" then
            initialRoll = degreesForRadians(currentRoll)
            local now = myo.getTimeMilliseconds()
            if enabled and edge == "on" then
                volumeInitiated = now
                volumeTimeout = VOLUME_CONTROL_TIMEOUT
                extendUnlock()
            elseif edge == "off" then
                volumeTimeout = nil
            end
        end

        if pose == "fingersSpread" and edge == "on" then
            togglePlayPause()
        end

        if pose == "fist" and edge == "on" then
            savedRoll = degreesForRadians(currentRoll)
            extendUnlock()
        elseif pose == "fist" and edge == "off" then
            difference = degreesForRadians(currentRoll) - savedRoll
            if difference >= -10 then
                thumbsUp()
            elseif difference <= -20 then
                thumbsDown()
            end
            extendUnlock()
        end
    end
end

-- All timeouts in milliseconds
ENABLED_TIMEOUT = 2200
VOLUME_CONTROL_TIMEOUT = 220

currentRoll = 0
currentPitch = 0
currentYaw = 0

currentXDirection = ""

function onPeriodic()

    currentRoll = myo.getRoll()
    currentPitch = myo.getPitch()
    currentYaw = myo.getYaw()
    currentXDirection = myo.getXDirection()

    local now = myo.getTimeMilliseconds()
    local rollNow = degreesForRadians(currentRoll)

    if volumeTimeout then
        extendUnlock()
        if now - volumeInitiated > volumeTimeout then
            local rollDifference = rollNow - initialRoll
            if rollDifference > 10 then
                volumeUp()
            elseif rollDifference < -10 then
                volumeDown()
            end

            volumeInitiated = now

        end
    end

    if enabled then
        if myo.getTimeMilliseconds() - enabledSince > ENABLED_TIMEOUT then
            enabled = false
            -- Vibrate once on lock
            myo.vibrate("short")
        end
    end
end

function onForegroundWindowChange(app, title)
    local wantActive = false
    activeApp = ""
    if platform == "MacOS" or platform == "Windows" then
        wantActive = string.match(title, "Pandora")
        activeApp = "Pandora"
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

