-- // CONFIG
local mainName = "fellkyae"
local altNames = {
    "alperyousefahmed",
    "ayayyoungboy123",
    "armadylgodswrddd",
    "alperinooo01",
    "alperinooo012",
    "hunterino1233",
    "yousefrino9"
}

local DISTANCE = 40       -- outer circle radius
local INNER_RADIUS = 15   -- inner triangle radius
local UNDERGROUND_Y = -20
local ABOVEGROUND_Y = 5
local STEP = 0.2
local SPIN_SPEED = 3
local CHAOS_RADIUS = 20
local BOB_AMPLITUDE = 3
local BOB_SPEED = 4
local SUPERNOVA_RADIUS = 30
local SUPERNOVA_DURATION = 5
local COMBINE_SPEED = 2
local COMBINE_HEIGHT = 12

-- // SERVICES
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- // MAIN PLAYER
local mainPlayer = Players:FindFirstChild(mainName)

-- // ALTS
local alts = {}
for _, n in ipairs(altNames) do
    local p = Players:FindFirstChild(n)
    if p then table.insert(alts, p) end
end

-- STATE
local currentY = UNDERGROUND_Y
local targetY = UNDERGROUND_Y
local mode = "triangle"
local spinAngle = 0
local combineProgress = 0
local combineTime = 0
local supernovaTime = 0
local supernovaActive = false
local orbitTarget = nil -- player the alts orbit around

-- TRIANGLE OFFSETS
local function getTriangleOffsets(y)
    local offsets = {}
    local n = #alts
    local angleStep = 2*math.pi/n
    for i = 1, n do
        local angle = i * angleStep
        offsets[i] = Vector3.new(math.cos(angle)*DISTANCE, y, math.sin(angle)*DISTANCE)
    end
    return offsets
end

-- CLEAN COMBINE
local function getCleanCombineOffsets(centerPos, dt)
    combineProgress = math.clamp(combineProgress + dt * COMBINE_SPEED, 0, 1)
    spinAngle = spinAngle + SPIN_SPEED * dt
    local offsets = {}
    for i = 1, #alts do
        local angle = (i / #alts) * math.pi * 2 + spinAngle
        local radius = (1 - combineProgress) * DISTANCE
        local height = ABOVEGROUND_Y + combineProgress * COMBINE_HEIGHT
        local x = math.cos(angle) * radius
        local z = math.sin(angle) * radius
        offsets[i] = Vector3.new(x, height, z)
    end
    return offsets
end

-- BOBBING COMBINE
local function getBobbingCombineOffsets(centerPos, dt)
    combineTime = combineTime + dt * BOB_SPEED
    spinAngle = spinAngle + SPIN_SPEED * dt
    local offsets = {}
    for i = 1, #alts do
        local angle = (i / #alts) * math.pi * 2 + spinAngle
        local x = math.cos(angle) * DISTANCE
        local z = math.sin(angle) * DISTANCE
        local y = ABOVEGROUND_Y + math.sin(angle*3 + combineTime) * BOB_AMPLITUDE
        offsets[i] = Vector3.new(x, y, z)
    end
    return offsets
end

-- CHAOS SPHERE OFFSETS
local function getChaosOffsets(centerPos, dt)
    combineTime = combineTime + dt
    spinAngle = spinAngle + SPIN_SPEED * dt
    local offsets = {}
    local count = #alts
    for i = 1, count do
        local theta = (i / count) * math.pi * 2 + spinAngle
        local radius = CHAOS_RADIUS + math.sin(combineTime*2 + i) * 5
        local y = math.sin(combineTime + i) * 10 + ABOVEGROUND_Y
        local x = math.cos(theta) * radius
        local z = math.sin(theta) * radius
        offsets[i] = Vector3.new(x, y, z)
    end
    return offsets
end

-- SUPERNOVA OFFSETS
local function getSupernovaOffsets(centerPos, dt)
    supernovaTime = supernovaTime + dt
    local progress = math.clamp(supernovaTime / SUPERNOVA_DURATION, 0, 1)
    local offsets = {}
    for i = 1, #alts do
        local angle1 = math.random()*math.pi*2
        local angle2 = math.random()*math.pi
        local radius = SUPERNOVA_RADIUS * math.sin(progress * math.pi) * (0.5 + math.random()*0.5)
        local x = math.cos(angle1) * math.sin(angle2) * radius
        local y = math.cos(angle2) * radius
        local z = math.sin(angle1) * math.sin(angle2) * radius
        offsets[i] = Vector3.new(x, y, z)
    end
    if progress >= 1 then
        supernovaActive = false
        supernovaTime = 0
        mode = "triangle"
    end
    return offsets
end

-- ISPIN OFFSETS (inner triangle + outer circle)
local function getISpinOffsets(centerPos, dt)
    combineTime = combineTime + dt
    spinAngle = spinAngle + SPIN_SPEED * dt
    local offsets = {}
    local count = #alts
    local innerCount = math.min(3, count)
    local outerCount = count - innerCount

    -- Inner triangle
    for i = 1, innerCount do
        local angle = (i-1) * (2*math.pi / innerCount) + spinAngle
        local y = ABOVEGROUND_Y + math.sin(combineTime*3 + i) * 2
        offsets[i] = Vector3.new(math.cos(angle)*INNER_RADIUS, y, math.sin(angle)*INNER_RADIUS)
    end

    -- Outer circle
    for i = 1, outerCount do
        local idx = i + innerCount
        local angle = (i-1) * (2*math.pi / outerCount) + spinAngle
        local radius = DISTANCE + math.sin(combineTime + i) * 5
        local y = ABOVEGROUND_Y + math.sin(angle*2 + combineTime) * 4
        offsets[idx] = Vector3.new(math.cos(angle)*radius, y, math.sin(angle)*radius)
    end

    return offsets
end

-- ORDER FORMATION OFFSETS (3x3 behind player, last alt in middle)
local function getOrderOffsets(centerPos, dt)
    local offsets = {}
    local count = #alts
    local spacing = 15
    local rows = math.ceil(math.sqrt(count))
    local cols = math.ceil(count / rows)
    local startX = -((cols-1)/2) * spacing
    local startZ = -((rows-1)/2) * spacing - 10 -- behind player
    local idx = 1

    for r = 0, rows-1 do
        for c = 0, cols-1 do
            if idx <= count then
                local x = startX + c * spacing
                local y = ABOVEGROUND_Y
                local z = startZ + r * spacing
                offsets[idx] = Vector3.new(x, y, z)
                idx = idx + 1
            end
        end
    end

    -- Last alt in center
    if count > 0 then
        offsets[count] = Vector3.new(0, ABOVEGROUND_Y, startZ + ((rows-1)/2) * spacing)
    end

    return offsets
end

-- MAIN LOOP
RunService.Heartbeat:Connect(function(dt)
    local centerPlayer = orbitTarget or mainPlayer
    if not (centerPlayer and centerPlayer.Character and centerPlayer.Character:FindFirstChild("HumanoidRootPart")) then return end
    local centerPos = centerPlayer.Character.HumanoidRootPart.Position

    if math.abs(currentY - targetY) > 0.05 then
        if currentY < targetY then
            currentY = math.min(currentY + STEP, targetY)
        elseif currentY > targetY then
            currentY = math.max(currentY - STEP, targetY)
        end
    end

    local offsets
    if supernovaActive then
        offsets = getSupernovaOffsets(centerPos, dt)
    elseif mode == "triangle" then
        offsets = getTriangleOffsets(currentY)
    elseif mode == "combine" then
        offsets = getCleanCombineOffsets(centerPos, dt)
    elseif mode == "spin" then
        offsets = getBobbingCombineOffsets(centerPos, dt)
    elseif mode == "chaos" then
        offsets = getChaosOffsets(centerPos, dt)
    elseif mode == "ispin" then
        offsets = getISpinOffsets(centerPos, dt)
    elseif mode == "order" then
        offsets = getOrderOffsets(centerPos, dt)
    end

    for i, alt in ipairs(alts) do
        if alt.Character and alt.Character:FindFirstChild("HumanoidRootPart") then
            alt.Character.HumanoidRootPart.CFrame = CFrame.new(centerPos + offsets[i])
        end
    end
end)

-- CHAT COMMANDS
if mainPlayer then
    mainPlayer.Chatted:Connect(function(msg)
        msg = msg:lower()
        if msg:sub(1,7) == "/target" then
            local inputName = msg:sub(9):lower()
            local targetPlayer = nil
            for _, p in pairs(Players:GetPlayers()) do
                if p.Name:lower():sub(1, #inputName) == inputName then
                    targetPlayer = p
                    break
                end
            end
            orbitTarget = targetPlayer
        elseif msg == "/arise" then
            mode = "triangle"
            targetY = ABOVEGROUND_Y
        elseif msg == "/down" then
            mode = "triangle"
            targetY = UNDERGROUND_Y
        elseif msg == "/combine" then
            mode = "combine"
            targetY = ABOVEGROUND_Y
            spinAngle = 0
            combineProgress = 0
        elseif msg == "/spin" then
            mode = "spin"
            targetY = ABOVEGROUND_Y
            spinAngle = 0
            combineTime = 0
        elseif msg == "/chaos" then
            mode = "chaos"
            targetY = ABOVEGROUND_Y
            spinAngle = 0
            combineTime = 0
        elseif msg == "/supernova" then
            supernovaActive = true
            supernovaTime = 0
            spinAngle = 0
            targetY = ABOVEGROUND_Y
        elseif msg == "/ispin" then
            mode = "ispin"
            spinAngle = 0
            combineTime = 0
            targetY = ABOVEGROUND_Y
        elseif msg == "/order" then
            mode = "order"
            spinAngle = 0
            combineTime = 0
            targetY = ABOVEGROUND_Y
        end
    end)
end
