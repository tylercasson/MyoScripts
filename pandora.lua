scriptId = 'com.tylercasson.scripts.pandora'

-- Wave In to skip to the next song

-- Hold a Wave Out gesture and rotate arm to adjust volume.
-- Tip: If you pinch your fingers together as if you were grabbing a volume
-- knob, this might make a little more sense and feel more natural

-- Spread Fingers to toggle play and pause

-- Make a "thumbs up" fist to give the current song a thumbs up

-- Make a "thumbs down" fist to give the current song a thumbs down


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

function lock()
    enabled = false
    myo.vibrate("short")
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
            extendUnlock()
        end

        if pose == "waveOut" then
            initialRoll = degreesForRadians(currentRoll)
            local now = myo.getTimeMilliseconds()
            if enabled and edge == "on" then
                volumeInitiated = now
                volumeTimeout = VOLUME_CONTROL_TIMEOUT
            elseif edge == "off" then
                volumeTimeout = nil
            end
            extendUnlock()
        end

        if pose == "fingersSpread" and edge == "on" then
            togglePlayPause()
            extendUnlock()
        end

        if pose == "fist" and edge == "on" then
            -- Calculate mean from interquartile range of rolls
            local iqrMeanRoll = degreesForRadians(mean(iqrTable(firstQuartile(rolls), rolls, thirdQuartile(rolls))))

            -- Degrees the Myo must roll for a thumbs down to be registered
            local thumbsDownThreshold = -35.0

            local currentRoll = myo.getRoll()

            -- Negate current roll for lefties
            if myo.getArm() == "left" then
                currentRoll = -currentRoll
            end

            if degreesForRadians(currentRoll) >= (iqrMeanRoll + thumbsDownThreshold) then
                thumbsUp()
            else
                thumbsDown()
            end
        end
    end
end

-- All timeouts in milliseconds
ENABLED_TIMEOUT = 2200
VOLUME_CONTROL_TIMEOUT = 220
COLLECTION_INTERVAL = 100

currentRoll = 0
currentPitch = 0
currentYaw = 0

currentXDirection = ""

-- This is where roll data points wil be stored for calculating various orientation thresholds
rolls = {}

-- Maximum number of roll readings to store before dumping 90%
maxDataPoints = 5000

collectData = myo.getTimeMilliseconds()

function storeRollData()
    local count = length(rolls)
    if count == maxCount then
        rolls = slice(rolls, count - math.floor(count * 0.1), count)
        count = length(rolls)
    end
    table.insert(rolls, myo.getRoll())
    table.sort(rolls)

    -- myo.debug(
    --     "\nCount    : "..count..
    --     "\nInstant  : "..tostring(degreesForRadians(myo.getRoll()))..
    --     "\nMean     : "..tostring(degreesForRadians(mean(rolls)))..
    --     "\nIQR Mean : "..tostring(degreesForRadians(mean(iqrTable(firstQuartile(rolls), rolls, thirdQuartile(rolls)))))..
    --     "\nStd. Dev.: "..tostring(degreesForRadians(stdDev(rolls))).."\n")

end

function onPeriodic()

    currentRoll = myo.getRoll()
    currentPitch = myo.getPitch()
    currentYaw = myo.getYaw()
    currentXDirection = myo.getXDirection()

    local now = myo.getTimeMilliseconds()
    local rollNow = degreesForRadians(currentRoll)

    if (myo.getTimeMilliseconds() - collectData) > COLLECTION_INTERVAL then
        storeRollData()
        collectData = myo.getTimeMilliseconds()
    end


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
            lock()
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
        if enabled then
            enabled = false
            lock()
        end
    end
end



-- Statistics Helper Functions

-- Note: These are not safe in any way. I haven't taken the time to do any
-- proper type checking so use them at your own risk. The purpose is to provide
-- a basic means of perfoming basic statistical analysis of data provided by
-- the Myo. In this example, I use an interquartile range to determine a
-- relatively stable mean (average) for roll (rotation). This provides a value
-- that is fairly resistant to change and is stable enough for basic thumbs up
-- or thumbs down detection without much thought on the wearer's part.

function slice(ns, first, last)
    local oType = type(ns)
    local copy
    if oType == "table" then
        copy = {}
        for i,v in ipairs(ns) do
            if i <= first then
                goto continue
            elseif i > first and i <= last then
                table.insert(copy, v)
            end
            ::continue::
        end
    else
        copy = ns
    end
    return copy
end

function length(ns)
    local oType = type(ns)
    local count = 0
    if oType == "table" then
        for i,v in ipairs(ns) do
            count = count + 1
        end
    end
    return count
end

map = function(ns, fn)
    local new = {}
    for i,v in ipairs(ns) do
        new[i] = fn(v)
    end
    return new
end

reduce = function (ns, fn)
    local acc
    for i,v in ipairs(ns) do
        if 1 == i then
            acc = v
        else
            acc = fn(acc, v)
        end
    end
    return acc
end

stdDev = function(ns)
    return mean(map(ns, function(a) return math.pow(mean(ns) - a, 2) end))
end

sum = function(a, b) return a + b end

mean = function(ns)
    local oType = type(ns)
    if oType == "table" then
        if length(ns) == 0 then
            return 0
        else
            return reduce(ns, sum) / length(ns)
        end
    end
    return 0.0
end

median = function(ns)
    local oType = type(ns)
    local copy = slice(ns, 0, length(ns))
    table.sort(copy)
    if oType == "table" then
        if length(copy) % 2 ~= 0 then
            return copy[math.ceil(length(copy) / 2)]
        else
            local upper = math.ceil(length(copy) / 2)
            local lower = math.floor(length(copy) / 2)

            local nss = slice(copy, lower, upper + 1)

            return mean(nss)
        end
    end
    return 0.0
end

-- There are more complicated methods for finding
-- quartiles, but these are good enough
firstQuartile = function(ns)
    local oType = type(ns)
    local copy = slice(ns, 1, length(ns) / 2)
    if oType == "table" then
        if length(ns) % 2 == 0 then
            table.insert(copy, median(ns))
            return median(copy)
        else
            copy = slice(ns, 1, length(ns) / 2)
            return median(copy)
        end
    end
    return 0.0
end

thirdQuartile = function(ns)
    local oType = type(ns)
    local copy = slice(ns, length(ns) / 2, length(ns))
    if oType == "table" then
        if length(ns) % 2 == 0 then
            table.insert(copy, median(ns))
            return median(copy)
        else
            copy = slice(ns, length(copy) / 2, length(copy))
            return median(copy)
        end
    end
    return 0.0
end

iqrTable = function(first, ns, third)
    local oType = type(ns)
    if oType == "table" then
        local newTable = slice(ns, math.ceil(length(ns) / 4) + 1, length(ns) - (math.ceil(length(ns) / 4) + 1))

        local interquartileTable = {first}

        for i,v in ipairs(newTable) do
            table.insert(interquartileTable, v)
        end

        table.insert(interquartileTable, third)

        return interquartileTable
    else
        return ns
    end
end





