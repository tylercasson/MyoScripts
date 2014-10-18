scriptId = 'com.tylercasson.scripts.missionControl'

-- Global:
    -- Spread Fingers to toggle Mission Control
    -- Make a Fist to toggle Application Windows for the current application

-- Mission Control:
    -- Wave Left to move right a space
    -- Wave Right to move left a space

-- Application Windows:
    -- Wave Left to highlight the previous window
    -- Wave Right to highlight the next window


applicationWindowsAreShowing = false
missionControlIsShowing = false


-- Mission Control Actions

function toggleMissionControl()
    missionControlIsShowing = not missionControlIsShowing
    myo.keyboard("up_arrow", "press", "control")
end

function toggleApplicationWindows()
    applicationWindowsAreShowing = not applicationWindowsAreShowing
    myo.keyboard("down_arrow", "press", "control")
end

function moveLeft()
    if applicationWindowsAreShowing then
        -- Swap the control direction for changing highlighted window
        myo.keyboard("right_arrow", "press")
    else
        myo.keyboard("left_arrow", "press", "control")
    end
end

function moveRight()
    if applicationWindowsAreShowing then
        -- Swap the control direction for changing highlighted window
        myo.keyboard("left_arrow", "press")
    else
        myo.keyboard("right_arrow", "press", "control")
    end
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
            moveRight()
            extendUnlock()
        end
        if pose == "waveOut" and edge == "on" then
            moveLeft()
            extendUnlock()
        end
        if pose == "fingersSpread" and edge == "on" then
            if not applicationWindowsAreShowing then
                toggleMissionControl()
            elseif applicationWindowsAreShowing then
                toggleApplicationWindows()
            end
            extendUnlock()
        end
        if pose == "fist" and edge == "on" then
            if not missionControlIsShowing then
                toggleApplicationWindows()
            elseif missionControlIsShowing then
                toggleMissionControl()
            end
            extendUnlock()
        end
    end
end

-- All timeouts in milliseconds
ENABLED_TIMEOUT = 2200

function onPeriodic()
   if enabled then
        if myo.getTimeMilliseconds() - enabledSince > ENABLED_TIMEOUT then
            enabled = false
            -- Vibrate once on lock
            myo.vibrate("short")
        end
    end
end

ingoreInApps = {
    ["app"] = {
        "com.apple.iTunes",
        "com.apple.iWork.Keynote",
        "VLC"
    },
    ["title"] = {
        "Netflix"
    }
}

function onForegroundWindowChange(app, title)
    local wantActive = true
    activeApp = ""
    if platform == "MacOS" then
        for key, list in pairs(ingoreInApps) do
            if key == "app" then
                for index, name in pairs(list) do
                    if string.match(app, name) then
                        wantActive = false
                        return wantActive
                    end
                end
            elseif key == "title" then
                for index, name in pairs(list) do
                    if string.match(title, name) then
                        wantActive = false
                        return wantActive
                    end
                end
            end
        end
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

