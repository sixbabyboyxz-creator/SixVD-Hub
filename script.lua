--[[
    ================================================================================
    👑 sixbabyboy Hub — Violence District (V8.2 MacBook Edition)
    ================================================================================
    
    V8.2 Patch Notes:
    ✅ NEW: ระบบ Generator Aura ESP (แสดงเฉพาะเครื่องที่ยังไม่เสร็จ)
       - แสดง Aura สีส้มทองนีออนเรืองแสงทะลุกำแพง พร้อมหลอด % ความคืบหน้า
       - แสดงเฉพาะเครื่องที่ยังปั่นไม่เสร็จ (เครื่องที่เสร็จแล้ว 100% จะหายไปอัตโนมัติ)
    ✅ NEW: ระบบ Auto Wiggle / Struggle (ดิ้นหลุดอัตโนมัติ)
       - ตรวจจับเมื่อถูกฆาตกรอุ้ม (FreeYourself Prompt & Character Weld)
       - สแปมปุ่ม A / D สลับกันรัวๆ พร้อม Spacebar ความเร็วสูง ดิ้นหลุดทันใจ
    ✅ PRESERVED: ฟังก์ชันเดิมทั้งหมดทำงานสมบูรณ์ 100%
       - Auto Skill Check: Great Zone 105°
       - Smooth Speed: CFrame Boost + macOS Slider
       - Ghost Noclip: ทะลุกำแพงไม่ตกแมพ
       - Player & Killer ESP Box
--]] local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- ============================================================================
-- ⚙️ CONFIGURATION
-- ============================================================================
local HubConfig = {
    AutoGreatZone = false, -- Auto Skill Check (Default: OFF)
    GreatZoneOffset = 105, -- Great Zone องศา 105° ล็อกถาวร
    HitWindow = 14, -- ช่วงกด 105° ถึง 119°

    ESPEnabled = false, -- ระบบ ESP Box (Default: OFF)

    -- ระบบ Smooth Speed (CFrame Motion Boost คำนวณแบบเนียนตา)
    SpeedEnabled = false, -- สปีด (Default: OFF)
    SpeedValue = 24, -- ความเร็วเริ่มต้น (เกมปกติคือ 16, ปรับระดับได้ 16 ถึง 100)
    SpeedKey = Enum.KeyCode.B, -- ปุ่มลัดสลับเปิด/ปิด Speed (ปุ่ม B)

    -- ระบบ Ghost Noclip (เดินทะลุกำแพง/วัตถุ)
    NoclipEnabled = false, -- Noclip (Default: OFF)
    NoclipKey = Enum.KeyCode.N, -- ปุ่มลัดสลับเปิด/ปิด Noclip (ปุ่ม N)

    -- ระบบ Auto Wiggle (ดิ้นหลุดจากไหล่ฆาตกรอัตโนมัติ)
    AutoWiggle = false, -- Auto Wiggle (Default: OFF)

    -- ระบบ Auto Heal Teammate (รักษาเพื่อนร่วมทีมอัตโนมัติ)
    AutoHeal = false, -- Auto Heal (Default: OFF)

    -- ระบบ No Fall Stun (ตกจากที่สูงไม่สตั้น)
    NoFall = false, -- No Fall Stun (Default: OFF)

    -- ระบบ Auto Pallet Drop (ทิ้งแผ่นไม้ใส่ฆาตกรอัตโนมัติ)
    AutoPallet = false, -- Auto Pallet Drop (Default: OFF)
    PalletStunDist = 12, -- ระยะตรวจจับฆาตกรเพื่อดรอปไม้ (studs)

    -- ระบบ Fast Vault Helper (ตัวช่วยกระโดดข้ามหน้าต่างเร็ว)
    FastVault = false, -- Fast Vault Helper (Default: OFF)

    -- ระบบ Generator Aura ESP (แสดงเฉพาะเครื่องที่ยังไม่เสร็จ)
    GenESPEnabled = false, -- Generator Aura ESP (Default: OFF)

    -- ระบบ Balanced Fullbright (สว่างสบายตา เคลียร์หมอกควัน)
    FullbrightEnabled = false, -- Fullbright (Default: OFF)

    UIVisible = true, -- แสดง UI เมื่อรัน
    ToggleKey = Enum.KeyCode.RightControl -- ปุ่มลัดซ่อน/เปิดแผง (Right Ctrl)
}

local SCState = {
    Active = false,
    Fired = false,
    PrevAngle = 0,
    TotalRotated = 0,
    LastGoalAngle = -1
}

-- ============================================================================
-- 2. Container สูงสุด (Always-On-Top เหนือเมนู ESC)
-- ============================================================================
local function getTopParent()
    if gethui then
        local h = gethui()
        if h then
            return h
        end
    end
    local ok, core = pcall(game.GetService, game, "CoreGui")
    if ok and core then
        local canW = pcall(function()
            local t = Instance.new("Folder");
            t.Parent = core;
            t:Destroy()
        end)
        if canW then
            return core
        end
    end
    return PlayerGui
end

-- ============================================================================
-- 3. คำสั่งกด Spacebar แบบ Zero-Latency (ส่งทันทีในเฟรม ไม่ติด Wait บล็อก)
-- ============================================================================
local function hitSpace()
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
    end)
    if keypress then
        pcall(function()
            keypress(0x20)
        end)
    end
    task.spawn(function()
        task.wait(0.02)
        pcall(function()
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
        end)
        if keyrelease then
            pcall(function()
                keyrelease(0x20)
            end)
        end
    end)
end

-- ============================================================================
-- 4. คอร์ลูป Auto Great Zone (Dynamic 100% — Zero Fail Zone & No Overshoot)
-- ============================================================================
local function findSkillCheckUI()
    for _, name in ipairs({"SkillCheckPromptGui", "SkillCheckPromptGui-con"}) do
        local gui = PlayerGui:FindFirstChild(name)
        if gui and gui:IsA("ScreenGui") and gui.Enabled then
            local chk = gui:FindFirstChild("Check")
            if chk and chk:IsA("Frame") and chk.Visible then
                local line = chk:FindFirstChild("Line")
                local goal = chk:FindFirstChild("Goal")
                if line and goal then
                    if line.Visible ~= false and goal.Visible ~= false then
                        return line, goal
                    end
                end
            end
        end
    end
    return nil, nil
end

RunService.RenderStepped:Connect(function()
    if not HubConfig.AutoGreatZone then
        SCState.Active = false
        SCState.Fired = false
        SCState.PrevAngle = 0
        SCState.TotalRotated = 0
        SCState.LastGoalAngle = -1
        return
    end

    local line, goal = findSkillCheckUI()

    if line and goal then
        local curAngle = line.Rotation % 360
        local goalAngle = goal.Rotation % 360

        -- ตรวจจับสกิลเช็คชุดใหม่ (Goal หมุนไปตำแหน่งใหม่ หรือเพิ่งเปิด UI ครั้งแรก)
        local isNewCheck = (not SCState.Active) or
                               (SCState.LastGoalAngle >= 0 and math.abs(goalAngle - SCState.LastGoalAngle) > 2)

        -- ตรวจจับกรณีสกิลเช็คก่อนหน้ากดไปแล้ว แล้วเข็มรีเซ็ตเริ่มรอบใหม่ (King's Scourge สกิลเช็ครัวๆ)
        local isFiredReset = (SCState.Fired and curAngle < 30 and SCState.PrevAngle > 90)

        if isNewCheck or isFiredReset then
            SCState.Active = true
            SCState.Fired = false
            SCState.PrevAngle = curAngle
            SCState.TotalRotated = 0
            SCState.LastGoalAngle = goalAngle
            if isNewCheck and not isFiredReset then
                return
            end
        end

        -- 1. คำนวณความเร็วและระยะหมุนสะสมของเข็ม
        local delta = (curAngle - SCState.PrevAngle) % 360
        if delta > 180 then
            delta = delta - 360
        end
        local step = math.clamp(delta, 0, 40)
        SCState.TotalRotated = SCState.TotalRotated + step

        if not SCState.Fired then
            -- 🛡️ ป้องกัน Fail Zone 100%:
            -- เข็มต้องหมุนสะสมแล้วอย่างน้อย 35° (ตัดปัญหา Modulo Wrap-Around 110° ตอนเข็มอยู่ที่ 0°)
            -- โดยไม่ใช้ minRotNeeded ที่เคยเกิน 360° ซึ่งทำให้เข็มวิ่งเลยสกิลเช็คไป 5%
            if SCState.TotalRotated >= 35 then
                local pastGoal = (curAngle - goalAngle) % 360
                local prevPast = (SCState.PrevAngle - goalAngle) % 360

                local targetStart = HubConfig.GreatZoneOffset -- 105°
                local targetEnd = targetStart + HubConfig.HitWindow -- 119°

                -- เงื่อนไข 1: เข็มอยู่ในช่วง Great Zone (105° ถึง 119°)
                local inGreatZone = (pastGoal >= targetStart) and (pastGoal <= targetEnd)

                -- เงื่อนไข 2: เข็มหมุนเร็วกระโดดข้ามเส้นเข้า Great Zone ในเฟรมนี้ (รองรับ Perk เร่งสปีดเข็มและ FPS Drop)
                local deltaPast = (pastGoal - prevPast) % 360
                if deltaPast > 180 then
                    deltaPast = deltaPast - 360
                end
                local crossedIn = (prevPast < targetStart) and (pastGoal >= targetStart) and
                                      (deltaPast > 0 and deltaPast < 50)

                if inGreatZone or crossedIn then
                    SCState.Fired = true
                    hitSpace()
                end
            end
        end

        SCState.PrevAngle = curAngle
    else
        if SCState.Active then
            SCState.Active = false
            SCState.Fired = false
            SCState.PrevAngle = 0
            SCState.TotalRotated = 0
            SCState.LastGoalAngle = -1
        end
    end
end)

-- ============================================================================
-- 5. ระบบ ESP BOX (Killer: สีแดง / Player: สีเขียว)
-- ============================================================================
local ESPObjects = {}

-- ตรวจสอบว่าตัวละครเป็น Killer หรือไม่
local function isKiller(char, plr)
    if not char then
        return false
    end

    -- 1. เช็ค Attributes เฉพาะตัวของ Killer
    if char:GetAttribute("BloodLust") ~= nil or char:GetAttribute("SuspenseRadius") ~= nil or
        char:GetAttribute("Chasemusic") ~= nil then
        return true
    end

    -- 2. เช็คโมเดล Weapon ที่อยู่ในตัวละคร
    if char:FindFirstChild("Weapon") then
        return true
    end

    -- 3. เช็คว่าเป็น Survivor แน่นอนหรือไม่ (มี HookedProgress หรือ Knocked)
    if char:GetAttribute("HookedProgress") ~= nil or char:GetAttribute("Knocked") ~= nil then
        return false
    end

    -- 4. เช็ค Attribute เพิ่มเติม
    if char:GetAttribute("Role") == "Killer" or char:GetAttribute("IsKiller") == true then
        return true
    end
    if plr and (plr:GetAttribute("Role") == "Killer" or plr:GetAttribute("IsKiller") == true) then
        return true
    end

    return false
end

local function removeESP(char)
    if ESPObjects[char] then
        local data = ESPObjects[char]
        if data.hl and data.hl.Parent then
            pcall(function()
                data.hl:Destroy()
            end)
        end
        if data.bbg and data.bbg.Parent then
            pcall(function()
                data.bbg:Destroy()
            end)
        end
        ESPObjects[char] = nil
    end
end

local function clearAllESP()
    for char, _ in pairs(ESPObjects) do
        removeESP(char)
    end
    table.clear(ESPObjects)
end

local function applyESP(char, plr, name)
    if not HubConfig.ESPEnabled then
        return
    end
    if not char or not char.Parent then
        return
    end
    if char == LocalPlayer.Character then
        return
    end

    local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
    if not root then
        return
    end

    removeESP(char)

    local isTargetKiller = isKiller(char, plr)
    local espColor = isTargetKiller and Color3.fromRGB(255, 45, 45) or Color3.fromRGB(45, 255, 45)
    local titlePrefix = isTargetKiller and "👹 [KILLER] " or "🏃 [PLAYER] "

    -- 1. Highlight เรืองแสงทะลุกำแพง
    local hl = Instance.new("Highlight")
    hl.Name = "SBB_Highlight"
    hl.Adornee = char
    hl.FillColor = espColor
    hl.OutlineColor = espColor
    hl.FillTransparency = 0.75
    hl.OutlineTransparency = 0.1
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = char

    -- 2. BillboardGui แสดงกรอบ BOX 3D
    local bbg = Instance.new("BillboardGui")
    bbg.Name = "SBB_ESP_Box"
    bbg.Adornee = root
    bbg.Size = UDim2.new(4.4, 0, 5.8, 0)
    bbg.AlwaysOnTop = true
    bbg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    bbg.LightInfluence = 0
    bbg.Parent = root

    local boxFrame = Instance.new("Frame")
    boxFrame.Size = UDim2.new(1, 0, 1, 0)
    boxFrame.Position = UDim2.new(0, 0, 0, 0)
    boxFrame.BackgroundTransparency = 0.92
    boxFrame.BackgroundColor3 = espColor
    boxFrame.BorderSizePixel = 0
    boxFrame.Parent = bbg

    local stroke = Instance.new("UIStroke")
    stroke.Color = espColor
    stroke.Thickness = 1.8
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = boxFrame
    Instance.new("UICorner", boxFrame).CornerRadius = UDim.new(0, 3)

    local tag = Instance.new("TextLabel")
    tag.Size = UDim2.new(2, 0, 0, 18)
    tag.Position = UDim2.new(-0.5, 0, 0, -22)
    tag.BackgroundTransparency = 1
    tag.Font = Enum.Font.GothamBold
    tag.TextSize = 11
    tag.TextColor3 = espColor
    tag.TextStrokeTransparency = 0.3
    tag.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    tag.Text = titlePrefix .. name
    tag.Parent = bbg

    ESPObjects[char] = {
        hl = hl,
        bbg = bbg,
        tag = tag,
        root = root,
        prefix = titlePrefix,
        name = name,
        isKiller = isTargetKiller
    }
end

local function refreshAllESP()
    if not HubConfig.ESPEnabled then
        clearAllESP()
        return
    end

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            applyESP(p.Character, p, p.DisplayName or p.Name)
        end
    end

    for _, m in ipairs(workspace:GetChildren()) do
        if m:IsA("Model") and m:FindFirstChild("Humanoid") and m ~= LocalPlayer.Character then
            if not ESPObjects[m] then
                local p = Players:GetPlayerFromCharacter(m)
                if p ~= LocalPlayer then
                    applyESP(m, p, p and (p.DisplayName or p.Name) or m.Name)
                end
            end
        end
    end
end

-- อัปเดตระยะทาง ESP แบบเรียลไทม์
RunService.RenderStepped:Connect(function()
    if not HubConfig.ESPEnabled then
        return
    end

    local myChar = LocalPlayer.Character
    local myRoot = myChar and (myChar:FindFirstChild("HumanoidRootPart") or myChar:FindFirstChild("Torso"))

    for char, data in pairs(ESPObjects) do
        if char and char.Parent and data.root and data.root.Parent and data.tag then
            if myRoot then
                local dist = math.floor((data.root.Position - myRoot.Position).Magnitude)
                data.tag.Text = data.prefix .. data.name .. " [" .. dist .. "m]"
            end
        else
            removeESP(char)
        end
    end
end)

-- สแกนตัวละครใหม่อัตโนมัติทุก 1.5 วินาที
task.spawn(function()
    while true do
        task.wait(1.5)
        if HubConfig.ESPEnabled then
            refreshAllESP()
        end
    end
end)

-- ============================================================================
-- 5.1 ระบบ Generator Aura ESP (แสดงเฉพาะเครื่องที่ยังไม่เสร็จ พร้อมเปอร์เซ็นต์)
-- ============================================================================
local GenESPObjects = {}

local function isGenUnfinished(gen)
    if not gen or not gen.Parent then
        return false
    end
    if gen:GetAttribute("Completed") == true then
        return false
    end
    local prog = gen:GetAttribute("RepairProgress")
    if prog and type(prog) == "number" and prog >= 99.9 then
        return false
    end
    return true
end

local function getGenProgress(gen)
    if not gen then
        return 0
    end
    local prog = gen:GetAttribute("RepairProgress")
    if prog and type(prog) == "number" then
        return math.clamp(math.floor(prog), 0, 100)
    end
    return 0
end

local function getGenerators()
    local list = {}
    local map = workspace:FindFirstChild("Map")
    if map then
        local gens = map:FindFirstChild("Generators")
        if gens then
            for _, gen in ipairs(gens:GetChildren()) do
                if gen:IsA("Model") then
                    table.insert(list, gen)
                end
            end
        end
    end
    if #list == 0 then
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("Model") and (obj.Name == "Generator" or obj.Name:match("^Gen")) then
                table.insert(list, obj)
            end
        end
    end
    return list
end

local function removeGenESP(gen)
    if GenESPObjects[gen] then
        local data = GenESPObjects[gen]
        if data.hl and data.hl.Parent then
            pcall(function()
                data.hl:Destroy()
            end)
        end
        if data.bbg and data.bbg.Parent then
            pcall(function()
                data.bbg:Destroy()
            end)
        end
        GenESPObjects[gen] = nil
    end
end

local function clearAllGenESP()
    for gen, _ in pairs(GenESPObjects) do
        removeGenESP(gen)
    end
    table.clear(GenESPObjects)
end

local function applyGenESP(gen)
    if not HubConfig.GenESPEnabled then
        return
    end
    if not gen or not gen.Parent then
        return
    end
    if not isGenUnfinished(gen) then
        removeGenESP(gen)
        return
    end

    if GenESPObjects[gen] then
        return
    end

    local root = gen:FindFirstChild("RootPart") or gen:FindFirstChild("Gen Invis") or gen.PrimaryPart or
                     gen:FindFirstChildWhichIsA("BasePart")
    if not root then
        return
    end

    local espColor = Color3.fromRGB(255, 185, 45) -- สีส้มทองนีออน (Aura เครื่องปั่นไฟที่ยังไม่เสร็จ)

    -- 1. Highlight เรืองแสงทะลุกำแพง
    local hl = Instance.new("Highlight")
    hl.Name = "SBB_GenHighlight"
    hl.Adornee = gen
    hl.FillColor = espColor
    hl.OutlineColor = Color3.fromRGB(255, 255, 255)
    hl.FillTransparency = 0.65
    hl.OutlineTransparency = 0.1
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = gen

    -- 2. BillboardGui แสดงป้ายชื่อ เปอร์เซ็นต์ และระยะทาง
    local bbg = Instance.new("BillboardGui")
    bbg.Name = "SBB_Gen_ESP"
    bbg.Adornee = root
    bbg.Size = UDim2.new(0, 160, 0, 32)
    bbg.StudsOffset = Vector3.new(0, 3.5, 0)
    bbg.AlwaysOnTop = true
    bbg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    bbg.LightInfluence = 0
    bbg.Parent = root

    local tag = Instance.new("TextLabel")
    tag.Size = UDim2.new(1, 0, 1, 0)
    tag.BackgroundTransparency = 1
    tag.Font = Enum.Font.GothamBold
    tag.TextSize = 11
    tag.TextColor3 = espColor
    tag.TextStrokeTransparency = 0.2
    tag.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    local pct = getGenProgress(gen)
    tag.Text = "⚙️ [GEN " .. pct .. "%]"
    tag.Parent = bbg

    GenESPObjects[gen] = {
        hl = hl,
        bbg = bbg,
        tag = tag,
        root = root,
        gen = gen
    }
end

local function refreshAllGenESP()
    if not HubConfig.GenESPEnabled then
        clearAllGenESP()
        return
    end

    local gens = getGenerators()
    for _, gen in ipairs(gens) do
        if isGenUnfinished(gen) then
            applyGenESP(gen)
        else
            removeGenESP(gen)
        end
    end
end

-- อัปเดตระยะทางและเปอร์เซ็นต์ Generator ESP แบบเรียลไทม์
RunService.RenderStepped:Connect(function()
    if not HubConfig.GenESPEnabled then
        return
    end

    local myChar = LocalPlayer.Character
    local myRoot = myChar and (myChar:FindFirstChild("HumanoidRootPart") or myChar:FindFirstChild("Torso"))

    for gen, data in pairs(GenESPObjects) do
        if gen and gen.Parent and data.root and data.root.Parent and data.tag then
            if not isGenUnfinished(gen) then
                removeGenESP(gen)
            else
                local pct = getGenProgress(gen)
                local distStr = ""
                if myRoot then
                    local dist = math.floor((data.root.Position - myRoot.Position).Magnitude)
                    distStr = " [" .. dist .. "m]"
                end
                data.tag.Text = "⚙️ [GEN " .. pct .. "%]" .. distStr
            end
        else
            removeGenESP(gen)
        end
    end
end)

-- สแกนเครื่องปั่นไฟทุก 1.5 วินาที
task.spawn(function()
    while true do
        task.wait(1.5)
        if HubConfig.GenESPEnabled then
            refreshAllGenESP()
        end
    end
end)

-- ============================================================================
-- 5.2 ระบบ Auto Wiggle (ดิ้นหลุดจากไหล่ฆาตกรอัตโนมัติ)
-- ============================================================================
local function isSurvivorCarried()
    -- 1. เช็คจาก UI Prompt FreeYourself
    for _, guiName in ipairs({"pcprompts", "consoleprompts"}) do
        local gui = PlayerGui:FindFirstChild(guiName)
        if gui and gui:IsA("ScreenGui") and gui.Enabled then
            local frame = gui:FindFirstChild("Frame")
            if frame and frame.Visible then
                local fy = frame:FindFirstChild("FreeYourself")
                if fy and fy.Visible then
                    return true
                end
            end
        end
    end

    -- 2. เช็คจาก Attributes และข้อต่อเชื่อมต่อกับ Killer
    local char = LocalPlayer.Character
    if char then
        if char:GetAttribute("BeingCarried") == true or char:GetAttribute("Carried") == true or
            char:GetAttribute("isCarried") == true then
            return true
        end

        local root = char:FindFirstChild("HumanoidRootPart")
        if root then
            for _, obj in ipairs(root:GetChildren()) do
                if (obj:IsA("Weld") or obj:IsA("Motor6D") or obj:IsA("WeldConstraint")) and obj.Part0 and obj.Part1 then
                    local other = (obj.Part0 == root) and obj.Part1 or obj.Part0
                    if other and other.Parent and other.Parent ~= char and other.Parent:FindFirstChild("Humanoid") then
                        return true
                    end
                end
            end
        end
    end

    return false
end

-- ลูปส่งปุ่มดิ้น A / D สลับกันรัวๆ พร้อม Spacebar
task.spawn(function()
    local toggleAD = false
    while true do
        task.wait(0.05)
        if HubConfig.AutoWiggle and isSurvivorCarried() then
            toggleAD = not toggleAD
            if toggleAD then
                pcall(function()
                    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.A, false, game)
                    task.wait(0.01)
                    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.A, false, game)
                end)
                if keypress and keyrelease then
                    pcall(function()
                        keypress(0x41);
                        task.wait(0.01);
                        keyrelease(0x41)
                    end)
                end
            else
                pcall(function()
                    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.D, false, game)
                    task.wait(0.01)
                    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.D, false, game)
                end)
                if keypress and keyrelease then
                    pcall(function()
                        keypress(0x44);
                        task.wait(0.01);
                        keyrelease(0x44)
                    end)
                end
            end

            -- ส่ง Spacebar ด้วย
            pcall(function()
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
                task.wait(0.01)
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
            end)
            if keypress and keyrelease then
                pcall(function()
                    keypress(0x20);
                    task.wait(0.01);
                    keyrelease(0x20)
                end)
            end
        end
    end
end)

-- ============================================================================
-- 6. ระบบ Smooth Speed (CFrame Motion Boost คำนวณแบบเนียนตา)
-- ============================================================================
RunService.Heartbeat:Connect(function(dt)
    if not HubConfig.SpeedEnabled then
        return
    end

    local char = LocalPlayer.Character
    if not char then
        return
    end

    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")

    if hum and root and hum.Health > 0 and hum.MoveDirection.Magnitude > 0 then
        local baseSpeed = 16
        local targetSpeed = HubConfig.SpeedValue or 24
        local extraSpeed = math.max(0, targetSpeed - baseSpeed)

        if extraSpeed > 0 then
            -- เลื่อนตำแหน่ง CFrame ตามทิศทางการเดินจริงของผู้เล่นอย่างนุ่มนวล
            local moveVec = hum.MoveDirection * (extraSpeed * dt)
            root.CFrame = root.CFrame + moveVec
        end
    end
end)

-- ============================================================================
-- 7. ระบบ Ghost Noclip (เดินทะลุกำแพง/วัตถุสิ่งกีดขวาง ไม่ร่วงตกแมพ)
-- ============================================================================
RunService.Stepped:Connect(function()
    if not HubConfig.NoclipEnabled then
        return
    end

    local char = LocalPlayer.Character
    if not char then
        return
    end

    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") and part.CanCollide then
            part.CanCollide = false
        end
    end
end)

-- ============================================================================
-- ฟังก์ชันค้นหา RootPart ของ Killer (สำหรับ ESP, Radar, Auto Pallet)
-- ============================================================================
local function getKillerRoot()
    for char, data in pairs(ESPObjects) do
        if data.isKiller and data.root and data.root.Parent then
            return data.root, char
        end
    end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            if isKiller(plr.Character, plr) then
                local root = plr.Character:FindFirstChild("HumanoidRootPart") or plr.Character:FindFirstChild("Torso")
                if root then
                    return root, plr.Character
                end
            end
        end
    end
    return nil, nil
end

-- ============================================================================
-- 7.1 ระบบ Auto Heal Teammate (รักษาเพื่อนร่วมทีมอัตโนมัติเมื่ออยู่ในระยะ)
-- ============================================================================
local AutoHealState = {
    IsHealing = false
}

local function isPlayerHealPromptActive()
    for _, guiName in ipairs({"pcprompts", "consoleprompts"}) do
        local gui = PlayerGui:FindFirstChild(guiName)
        if gui and gui:IsA("ScreenGui") and gui.Enabled then
            local frame = gui:FindFirstChild("Frame")
            if frame and frame.Visible then
                local ph = frame:FindFirstChild("PlayerHeal")
                if ph and ph.Visible then
                    return true
                end
            end
        end
    end
    return false
end

local function getNearbyHealableTeammate()
    local myChar = LocalPlayer.Character
    if not myChar then
        return nil
    end
    local myRoot = myChar:FindFirstChild("HumanoidRootPart") or myChar:FindFirstChild("Torso")
    if not myRoot then
        return nil
    end

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character and plr.Character.Parent then
            local char = plr.Character
            if not isKiller(char, plr) then
                local hum = char:FindFirstChild("Humanoid")
                local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
                if hum and root and hum.Health > 0 and hum.Health < hum.MaxHealth then
                    local dist = (root.Position - myRoot.Position).Magnitude
                    if dist <= 8.5 then
                        return char, root, hum
                    end
                end
                if root and
                    (char:GetAttribute("Knocked") == true or char:GetAttribute("Downed") == true or
                        (hum and hum.Health <= 1)) then
                    local dist = (root.Position - myRoot.Position).Magnitude
                    if dist <= 8.5 then
                        return char, root, hum
                    end
                end
            end
        end
    end
    return nil
end

local function triggerHealInput(active)
    if active then
        pcall(function()
            if mouse1press then
                mouse1press()
            end
            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
        end)
    else
        pcall(function()
            if mouse1release then
                mouse1release()
            end
            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
        end)
    end
end

task.spawn(function()
    while true do
        task.wait(0.1)
        if HubConfig.AutoHeal then
            local canHealPrompt = isPlayerHealPromptActive()
            local targetChar = getNearbyHealableTeammate()

            if canHealPrompt or targetChar then
                if not AutoHealState.IsHealing then
                    AutoHealState.IsHealing = true
                    triggerHealInput(true)
                end
                pcall(function()
                    local healRemote = ReplicatedStorage:FindFirstChild("Remotes") and
                                           ReplicatedStorage.Remotes:FindFirstChild("Healing") and
                                           ReplicatedStorage.Remotes.Healing:FindFirstChild("HealEvent")
                    if healRemote and targetChar then
                        healRemote:FireServer(targetChar)
                    end
                end)
            else
                if AutoHealState.IsHealing then
                    AutoHealState.IsHealing = false
                    triggerHealInput(false)
                end
            end
        else
            if AutoHealState.IsHealing then
                AutoHealState.IsHealing = false
                triggerHealInput(false)
            end
        end
    end
end)

-- ============================================================================
-- 7.2 ระบบ No Fall Stun (ตกจากที่สูงไม่สตั้น / เดินต่อได้ทันที 100%)
-- ============================================================================
local function setupNoFall(char)
    if not char then
        return
    end
    local hum = char:WaitForChild("Humanoid", 3)
    local root = char:WaitForChild("HumanoidRootPart", 3)
    if not hum or not root then
        return
    end

    hum.StateChanged:Connect(function(oldState, newState)
        if not HubConfig.NoFall then
            return
        end
        if newState == Enum.HumanoidStateType.Landed or newState == Enum.HumanoidStateType.Freefall then
            task.defer(function()
                if not HubConfig.NoFall then
                    return
                end
                hum:ChangeState(Enum.HumanoidStateType.Running)
                hum.PlatformStand = false
            end)
        end
    end)

    hum.AnimationPlayed:Connect(function(track)
        if not HubConfig.NoFall then
            return
        end
        local name = (track.Name or ""):lower()
        local anim = track.Animation
        local animName = anim and (anim.Name or ""):lower() or ""
        if name:find("fall") or name:find("land") or name:find("stagger") or name:find("stun") or animName:find("fall") or
            animName:find("land") or animName:find("stagger") then
            track:Stop(0)
            hum:ChangeState(Enum.HumanoidStateType.Running)
        end
    end)
end

if LocalPlayer.Character then
    task.spawn(setupNoFall, LocalPlayer.Character)
end
LocalPlayer.CharacterAdded:Connect(setupNoFall)

RunService.Heartbeat:Connect(function()
    if not HubConfig.NoFall then
        return
    end
    local char = LocalPlayer.Character
    if not char then
        return
    end
    local hum = char:FindFirstChild("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not hum or not root then
        return
    end

    if root.AssemblyLinearVelocity.Y < -28 then
        local ray = Ray.new(root.Position, Vector3.new(0, -6, 0))
        local hitPart = workspace:FindPartOnRayWithIgnoreList(ray, {char})
        if hitPart then
            root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, -2, root.AssemblyLinearVelocity.Z)
            hum:ChangeState(Enum.HumanoidStateType.Running)
            for _, trk in ipairs(hum:GetPlayingAnimationTracks()) do
                local n = (trk.Name or ""):lower()
                if n:find("fall") or n:find("land") or n:find("stagger") then
                    trk:Stop(0)
                end
            end
        end
    end
end)

-- ============================================================================
-- 7.3 ระบบ Auto Pallet Drop (ทิ้งแผ่นไม้ใส่ฆาตกรอัตโนมัติเมื่ออยู่ในระยะ Stun)
-- ============================================================================
local AutoPalletState = {
    LastDropTick = 0
}

local function isPalletDropPromptActive()
    for _, guiName in ipairs({"pcprompts", "consoleprompts"}) do
        local gui = PlayerGui:FindFirstChild(guiName)
        if gui and gui:IsA("ScreenGui") and gui.Enabled then
            local frame = gui:FindFirstChild("Frame")
            if frame and frame.Visible then
                local pd = frame:FindFirstChild("PalletDropPromptGui")
                if pd and pd.Visible then
                    return true
                end
            end
        end
    end
    return false
end

local function findNearbyPallet(maxDist)
    local myChar = LocalPlayer.Character
    if not myChar then
        return nil
    end
    local myRoot = myChar:FindFirstChild("HumanoidRootPart") or myChar:FindFirstChild("Torso")
    if not myRoot then
        return nil
    end

    local closestPallet = nil
    local closestDist = maxDist or 8.5

    local map = workspace:FindFirstChild("Map") or workspace
    for _, desc in ipairs(map:GetDescendants()) do
        if desc:IsA("Model") and (desc.Name:lower():find("pallet")) then
            local point = desc:FindFirstChild("PalletPoint") or desc:FindFirstChild("PrimaryPartPallet") or
                              desc.PrimaryPart or desc:FindFirstChildWhichIsA("BasePart")
            if point then
                local d = (point.Position - myRoot.Position).Magnitude
                if d < closestDist then
                    closestDist = d
                    closestPallet = desc
                end
            end
        end
    end
    return closestPallet, closestDist
end

local function dropPallet(pallet)
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
        if keypress then
            keypress(0x20)
        end
        task.delay(0.08, function()
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
            if keyrelease then
                keyrelease(0x20)
            end
        end)
    end)

    pcall(function()
        local palletRemote = ReplicatedStorage:FindFirstChild("Remotes") and
                                 ReplicatedStorage.Remotes:FindFirstChild("Pallet") and
                                 ReplicatedStorage.Remotes.Pallet:FindFirstChild("PalletDropEvent")
        if palletRemote and pallet then
            palletRemote:FireServer(pallet)
        end
    end)
end

RunService.Heartbeat:Connect(function()
    if not HubConfig.AutoPallet then
        return
    end
    local now = tick()
    if now - AutoPalletState.LastDropTick < 1.2 then
        return
    end

    local myChar = LocalPlayer.Character
    if not myChar then
        return
    end
    local myRoot = myChar:FindFirstChild("HumanoidRootPart") or myChar:FindFirstChild("Torso")
    if not myRoot then
        return
    end

    local hasPrompt = isPalletDropPromptActive()
    local nearbyPallet = findNearbyPallet(8.5)

    if hasPrompt or nearbyPallet then
        local killerRoot, killerChar = getKillerRoot()
        if killerRoot then
            local checkPos = nearbyPallet and
                                 (nearbyPallet:FindFirstChild("PalletPoint") and nearbyPallet.PalletPoint.Position) or
                                 myRoot.Position
            local distKillerToPallet = (killerRoot.Position - checkPos).Magnitude

            if distKillerToPallet <= (HubConfig.PalletStunDist or 12) then
                AutoPalletState.LastDropTick = now
                dropPallet(nearbyPallet)
            end
        end
    end
end)

-- ============================================================================
-- 7.4 ระบบ Fast Vault Helper (ตัวช่วยกระโดดข้ามหน้าต่าง/แผ่นไม้เร็วระดับ Fast Vault)
-- ============================================================================
local function isVaultPromptActive()
    for _, guiName in ipairs({"pcprompts", "consoleprompts"}) do
        local gui = PlayerGui:FindFirstChild(guiName)
        if gui and gui:IsA("ScreenGui") and gui.Enabled then
            local frame = gui:FindFirstChild("Frame")
            if frame and frame.Visible then
                local vp = frame:FindFirstChild("VaultPromptGui") or frame:FindFirstChild("PalletSlidePromptGui")
                if vp and vp.Visible then
                    return true, vp.Name
                end
            end
        end
    end
    return false, nil
end

RunService.RenderStepped:Connect(function()
    if not HubConfig.FastVault then
        return
    end

    local myChar = LocalPlayer.Character
    if not myChar then
        return
    end
    local myRoot = myChar:FindFirstChild("HumanoidRootPart") or myChar:FindFirstChild("Torso")
    local hum = myChar:FindFirstChild("Humanoid")
    if not myRoot or not hum then
        return
    end

    local hasVaultPrompt = isVaultPromptActive()

    if hasVaultPrompt then
        local moveDir = hum.MoveDirection
        if moveDir.Magnitude > 0.1 then
            myRoot.AssemblyLinearVelocity = Vector3.new(moveDir.X * 28, myRoot.AssemblyLinearVelocity.Y, moveDir.Z * 28)
        end

        pcall(function()
            local windowRemote = ReplicatedStorage:FindFirstChild("Remotes") and
                                     ReplicatedStorage.Remotes:FindFirstChild("Window")
            if windowRemote then
                local fv = windowRemote:FindFirstChild("fastvault")
                if fv then
                    fv:FireServer()
                end
                local sfv = windowRemote:FindFirstChild("SurvivorFastVault")
                if sfv and sfv:IsA("RemoteEvent") then
                    sfv:FireServer()
                end
            end
        end)
    end
end)

-- ============================================================================
-- 8. ระบบ Balanced Fullbright (ปรับแสงสว่างพอเหมาะ & ล้างหมอกควัน)
-- ============================================================================
local OrigLighting = {
    Saved = false,
    Brightness = 1,
    ClockTime = 14,
    Ambient = Color3.fromRGB(0, 0, 0),
    OutdoorAmbient = Color3.fromRGB(128, 128, 128),
    GlobalShadows = true,
    ExposureCompensation = 0,
    FogEnd = 1000,
    FogStart = 0,
    AtmosphereDensity = 0.3,
    AtmosphereHaze = 0,
    AtmosphereGlare = 0,
    DarknessGuis = {}
}

local function saveOriginalLighting()
    if OrigLighting.Saved then
        return
    end
    pcall(function()
        OrigLighting.Brightness = Lighting.Brightness
        OrigLighting.ClockTime = Lighting.ClockTime
        OrigLighting.Ambient = Lighting.Ambient
        OrigLighting.OutdoorAmbient = Lighting.OutdoorAmbient
        OrigLighting.GlobalShadows = Lighting.GlobalShadows
        OrigLighting.ExposureCompensation = Lighting.ExposureCompensation
        OrigLighting.FogEnd = Lighting.FogEnd
        OrigLighting.FogStart = Lighting.FogStart

        local atmos = Lighting:FindFirstChildOfClass("Atmosphere")
        if atmos then
            OrigLighting.AtmosphereDensity = atmos.Density
            OrigLighting.AtmosphereHaze = atmos.Haze
            OrigLighting.AtmosphereGlare = atmos.Glare
        end
        OrigLighting.Saved = true
    end)
end

local function applyFullbright()
    pcall(function()
        saveOriginalLighting()

        -- ปรับแสงสว่างระดับ Balanced (สว่างชัดเจน ไม่ขาวโพลน ไม่แสบตา)
        Lighting.Brightness = 2.0
        Lighting.ClockTime = 14
        Lighting.Ambient = Color3.fromRGB(135, 135, 140)
        Lighting.OutdoorAmbient = Color3.fromRGB(135, 135, 140)
        Lighting.GlobalShadows = false
        Lighting.ExposureCompensation = 0.2
        Lighting.FogEnd = 100000
        Lighting.FogStart = 0

        -- เคลียร์หมอก Atmosphere ใน Lighting
        local atmos = Lighting:FindFirstChildOfClass("Atmosphere")
        if atmos then
            atmos.Density = 0
            atmos.Haze = 0
            atmos.Glare = 0
        end

        -- เคลียร์หมอก/Vignette มืดใน PlayerGui.Darkness
        local darkGui = PlayerGui:FindFirstChild("Darkness")
        if darkGui and darkGui:IsA("ScreenGui") then
            local darkImg = darkGui:FindFirstChild("ImageLabel")
            if darkImg and darkImg:IsA("ImageLabel") and darkImg.Visible then
                darkImg.Visible = false
                OrigLighting.DarknessGuis[darkImg] = true
            end
        end
    end)
end

local function restoreLighting()
    pcall(function()
        if not OrigLighting.Saved then
            return
        end
        Lighting.Brightness = OrigLighting.Brightness
        Lighting.ClockTime = OrigLighting.ClockTime
        Lighting.Ambient = OrigLighting.Ambient
        Lighting.OutdoorAmbient = OrigLighting.OutdoorAmbient
        Lighting.GlobalShadows = OrigLighting.GlobalShadows
        Lighting.ExposureCompensation = OrigLighting.ExposureCompensation
        Lighting.FogEnd = OrigLighting.FogEnd
        Lighting.FogStart = OrigLighting.FogStart

        local atmos = Lighting:FindFirstChildOfClass("Atmosphere")
        if atmos then
            atmos.Density = OrigLighting.AtmosphereDensity
            atmos.Haze = OrigLighting.AtmosphereHaze
            atmos.Glare = OrigLighting.AtmosphereGlare
        end

        for img, _ in pairs(OrigLighting.DarknessGuis) do
            if img and img.Parent then
                img.Visible = true
            end
        end
        OrigLighting.DarknessGuis = {}
    end)
end

-- ป้องกันเกมรีเซ็ตความมืดกลับมาระหว่างเล่น
task.spawn(function()
    while true do
        task.wait(1.5)
        if HubConfig.FullbrightEnabled then
            applyFullbright()
        end
    end
end)

-- ============================================================================
-- 9. สร้าง UI Hub สไตล์ MacBook macOS (V8.1)
-- ============================================================================
local function buildUI()
    local parent = getTopParent()

    local old = parent:FindFirstChild("SBB_Hub") or PlayerGui:FindFirstChild("SBB_Hub")
    if old then
        old:Destroy()
    end

    local scr = Instance.new("ScreenGui")
    scr.Name = "SBB_Hub"
    scr.ResetOnSpawn = false
    scr.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    scr.DisplayOrder = 2147483647
    scr.IgnoreGuiInset = true
    scr.Parent = parent

    -- สถานะหน้าต่าง
    local normalSize = UDim2.new(0, 520, 0, 370)
    local normalPos = UDim2.new(0.06, 0, 0.24, 0)
    local isMinimized = false
    local isMaximized = false

    -- กรอบหลัก Main Window (สไตล์ macOS Frosted Glass Red Theme)
    local main = Instance.new("Frame")
    main.Name = "Main"
    main.Size = normalSize
    main.Position = normalPos
    main.BackgroundColor3 = Color3.fromRGB(15, 12, 18)
    main.BorderSizePixel = 0
    main.Active = true
    main.ClipsDescendants = true
    main.ZIndex = 100
    main.Parent = scr
    Instance.new("UICorner", main).CornerRadius = UDim.new(0, 12)
    local ms = Instance.new("UIStroke", main)
    ms.Color = Color3.fromRGB(60, 25, 35)
    ms.Thickness = 1.4

    -- แถบหัวข้อ Header (Titlebar)
    local hdr = Instance.new("Frame")
    hdr.Name = "Header"
    hdr.Size = UDim2.new(1, 0, 0, 42)
    hdr.BackgroundColor3 = Color3.fromRGB(12, 10, 15)
    hdr.BorderSizePixel = 0
    hdr.Active = true
    hdr.ZIndex = 101
    hdr.Parent = main
    Instance.new("UICorner", hdr).CornerRadius = UDim.new(0, 12)

    -- เส้นคั่นล่างของ Titlebar (โทนแดงเรืองแสง)
    local hdrBorder = Instance.new("Frame")
    hdrBorder.Size = UDim2.new(1, 0, 0, 1)
    hdrBorder.Position = UDim2.new(0, 0, 1, -1)
    hdrBorder.BackgroundColor3 = Color3.fromRGB(80, 25, 40)
    hdrBorder.BorderSizePixel = 0
    hdrBorder.ZIndex = 102
    hdrBorder.Parent = hdr

    -- ========================================================================
    -- 🍎 MacBook Traffic Lights Buttons (🔴 แดง / 🟡 ส้ม / 🟢 เขียว)
    -- ========================================================================
    local trafficContainer = Instance.new("Frame")
    trafficContainer.Size = UDim2.new(0, 76, 1, 0)
    trafficContainer.Position = UDim2.new(0, 14, 0, 0)
    trafficContainer.BackgroundTransparency = 1
    trafficContainer.ZIndex = 103
    trafficContainer.Parent = hdr

    local function makeTrafficDot(baseColor, hoverColor, symbol, posX, onClick)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 13, 0, 13)
        btn.Position = UDim2.new(0, posX, 0.5, -6.5)
        btn.BackgroundColor3 = baseColor
        btn.Text = ""
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 9
        btn.TextColor3 = Color3.fromRGB(40, 10, 10)
        btn.AutoButtonColor = false
        btn.ZIndex = 104
        btn.Parent = trafficContainer
        Instance.new("UICorner", btn).CornerRadius = UDim.new(1, 0)

        local stroke = Instance.new("UIStroke", btn)
        stroke.Color = baseColor:Lerp(Color3.fromRGB(0, 0, 0), 0.3)
        stroke.Thickness = 0.8

        btn.MouseEnter:Connect(function()
            btn.Text = symbol
            TweenService:Create(btn, TweenInfo.new(0.15), {
                BackgroundColor3 = hoverColor
            }):Play()
        end)
        btn.MouseLeave:Connect(function()
            btn.Text = ""
            TweenService:Create(btn, TweenInfo.new(0.15), {
                BackgroundColor3 = baseColor
            }):Play()
        end)
        btn.MouseButton1Click:Connect(onClick)

        return btn
    end

    -- Forward declares
    local closeWindow, toggleMinimize, toggleMaximize

    -- 🔴 ปุ่มสีแดง: ปิดหน้าต่าง (Close)
    local dotRed = makeTrafficDot(Color3.fromRGB(255, 95, 86), Color3.fromRGB(255, 125, 115), "✕", 0, function()
        closeWindow()
    end)

    -- 🟡 ปุ่มสีส้ม: ย่อหน้าต่าง (Minimize)
    local dotYellow = makeTrafficDot(Color3.fromRGB(255, 189, 46), Color3.fromRGB(255, 215, 85), "−", 22, function()
        toggleMinimize()
    end)

    -- 🟢 ปุ่มสีเขียว: ขยายเต็มจอ / ย่อกลับ (Fullscreen / Maximize)
    local dotGreen = makeTrafficDot(Color3.fromRGB(39, 201, 63), Color3.fromRGB(75, 230, 100), "⤢", 44, function()
        toggleMaximize()
    end)

    -- ชื่อไตเติลแอปข้างปุ่ม MacBook
    local logo = Instance.new("TextLabel")
    logo.Text = "sixbabyboy"
    logo.Font = Enum.Font.GothamBold
    logo.TextSize = 14
    logo.TextColor3 = Color3.fromRGB(255, 75, 90)
    logo.Size = UDim2.new(0, 90, 1, 0)
    logo.Position = UDim2.new(0, 96, 0, 0)
    logo.TextXAlignment = Enum.TextXAlignment.Left
    logo.BackgroundTransparency = 1
    logo.Active = false
    logo.ZIndex = 102
    logo.Parent = hdr

    local subT = Instance.new("TextLabel")
    subT.Text = "Violence District"
    subT.Font = Enum.Font.GothamMedium
    subT.TextSize = 11
    subT.TextColor3 = Color3.fromRGB(160, 140, 155)
    subT.Size = UDim2.new(0, 180, 1, 0)
    subT.Position = UDim2.new(0, 176, 0, 0)
    subT.TextXAlignment = Enum.TextXAlignment.Left
    subT.BackgroundTransparency = 1
    subT.Active = false
    subT.ZIndex = 102
    subT.Parent = hdr

    -- ========================================================================
    -- แถบด้านซ้าย Sidebar (สไตล์ macOS Sidebar)
    -- ========================================================================
    local side = Instance.new("Frame")
    side.Name = "Sidebar"
    side.Size = UDim2.new(0, 130, 1, -48)
    side.Position = UDim2.new(0, 6, 0, 45)
    side.BackgroundColor3 = Color3.fromRGB(12, 10, 14)
    side.BorderSizePixel = 0
    side.ZIndex = 101
    side.Parent = main
    Instance.new("UICorner", side).CornerRadius = UDim.new(0, 8)

    local sideList = Instance.new("UIListLayout", side)
    sideList.Padding = UDim.new(0, 4)
    sideList.SortOrder = Enum.SortOrder.LayoutOrder
    sideList.HorizontalAlignment = Enum.HorizontalAlignment.Center
    Instance.new("UIPadding", side).PaddingTop = UDim.new(0, 8)

    -- พื้นที่เนื้อหาด้านขวา (Content Area)
    local content = Instance.new("Frame")
    content.Name = "Content"
    content.Size = UDim2.new(1, -148, 1, -48)
    content.Position = UDim2.new(0, 142, 0, 45)
    content.BackgroundColor3 = Color3.fromRGB(12, 10, 14)
    content.BorderSizePixel = 0
    content.ZIndex = 101
    content.Parent = main
    Instance.new("UICorner", content).CornerRadius = UDim.new(0, 8)

    -- เส้นตกแต่งสีแดง + เอฟเฟกต์ Glow Pulse
    local redLine = Instance.new("Frame")
    redLine.Size = UDim2.new(0, 60, 0, 2.5)
    redLine.Position = UDim2.new(0, 14, 0, 24)
    redLine.BackgroundColor3 = Color3.fromRGB(220, 50, 75)
    redLine.BorderSizePixel = 0
    redLine.ZIndex = 103
    redLine.Parent = content
    Instance.new("UICorner", redLine).CornerRadius = UDim.new(1, 0)

    task.spawn(function()
        while true do
            TweenService:Create(redLine, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                BackgroundTransparency = 0.45,
                Size = UDim2.new(0, 72, 0, 2.5)
            }):Play()
            task.wait(1.2)
            TweenService:Create(redLine, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                BackgroundTransparency = 0,
                Size = UDim2.new(0, 56, 0, 2.5)
            }):Play()
            task.wait(1.2)
        end
    end)

    local sectionTitle = Instance.new("TextLabel")
    sectionTitle.Text = "Main"
    sectionTitle.Font = Enum.Font.GothamBold
    sectionTitle.TextSize = 13
    sectionTitle.TextColor3 = Color3.fromRGB(230, 215, 225)
    sectionTitle.Size = UDim2.new(0, 120, 0, 28)
    sectionTitle.Position = UDim2.new(1, -134, 0, 8)
    sectionTitle.TextXAlignment = Enum.TextXAlignment.Right
    sectionTitle.BackgroundTransparency = 1
    sectionTitle.ZIndex = 103
    sectionTitle.Parent = content

    -- ========================================================================
    -- 📁 ระบบ Multi-Tab Pages (แยกหน้าแต่ละหมวดหมู่อย่างแท้จริง)
    -- ========================================================================
    local tabButtons = {}
    local tabPages = {}

    local function createTabPage(name)
        local scroll = Instance.new("ScrollingFrame")
        scroll.Name = name .. "Page"
        scroll.Size = UDim2.new(1, -20, 1, -44)
        scroll.Position = UDim2.new(0, 10, 0, 38)
        scroll.BackgroundTransparency = 1
        scroll.BorderSizePixel = 0
        scroll.ScrollBarThickness = 3
        scroll.ScrollBarImageColor3 = Color3.fromRGB(60, 25, 40)
        scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
        scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
        scroll.Visible = (name == "Main")
        scroll.ZIndex = 102
        scroll.Parent = content

        local scrollList = Instance.new("UIListLayout", scroll)
        scrollList.Padding = UDim.new(0, 8)
        scrollList.SortOrder = Enum.SortOrder.LayoutOrder

        tabPages[name] = scroll
        return scroll
    end

    local mainPage = createTabPage("Main")
    local movementPage = createTabPage("Movement")
    local survivalPage = createTabPage("Survival")
    local visualsPage = createTabPage("Visuals")
    local settingsPage = createTabPage("Settings")

    local function switchTab(name)
        for tName, page in pairs(tabPages) do
            if tName == name then
                page.Visible = true
                page.Position = UDim2.new(0, 16, 0, 38)
                TweenService:Create(page, TweenInfo.new(0.24, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
                    Position = UDim2.new(0, 10, 0, 38)
                }):Play()
            else
                page.Visible = false
            end
        end

        for tName, btn in pairs(tabButtons) do
            local isAct = (tName == name)
            local ind = btn:FindFirstChild("Indicator")
            if ind then
                TweenService:Create(ind, TweenInfo.new(0.2), {
                    BackgroundTransparency = isAct and 0 or 1,
                    Size = isAct and UDim2.new(0, 3, 0, 16) or UDim2.new(0, 3, 0, 6)
                }):Play()
            end
            local lbl = btn:FindFirstChild("TabLabel")
            if lbl then
                TweenService:Create(lbl, TweenInfo.new(0.2), {
                    TextColor3 = isAct and Color3.fromRGB(255, 75, 90) or Color3.fromRGB(140, 130, 145)
                }):Play()
            end
            TweenService:Create(btn, TweenInfo.new(0.2), {
                BackgroundColor3 = isAct and Color3.fromRGB(40, 15, 25) or Color3.fromRGB(14, 10, 16)
            }):Play()
        end

        sectionTitle.Text = name
    end

    local function makeTab(name, order)
        local tb = Instance.new("TextButton")
        tb.Name = name .. "Tab"
        tb.Size = UDim2.new(0.92, 0, 0, 34)
        local isInit = (name == "Main")
        tb.BackgroundColor3 = isInit and Color3.fromRGB(40, 15, 25) or Color3.fromRGB(14, 10, 16)
        tb.Text = ""
        tb.AutoButtonColor = false
        tb.LayoutOrder = order
        tb.ZIndex = 102
        tb.Parent = side
        Instance.new("UICorner", tb).CornerRadius = UDim.new(0, 7)

        -- แถบสีแดงระบุแท็บที่กำลังเปิดอยู่ (Active Tab Indicator) ชิดซ้ายสุด
        local ind = Instance.new("Frame")
        ind.Name = "Indicator"
        ind.Size = isInit and UDim2.new(0, 3, 0, 16) or UDim2.new(0, 3, 0, 6)
        ind.Position = UDim2.new(0, 5, 0.5, -8)
        ind.BackgroundColor3 = Color3.fromRGB(255, 75, 90)
        ind.BorderSizePixel = 0
        ind.BackgroundTransparency = isInit and 0 or 1
        ind.ZIndex = 104
        ind.Parent = tb
        Instance.new("UICorner", ind).CornerRadius = UDim.new(1, 0)

        -- ข้อความชื่อแท็บ (เว้นระยะชัดเจน ไม่ทับกับ Indicator 100%)
        local tabLbl = Instance.new("TextLabel")
        tabLbl.Name = "TabLabel"
        tabLbl.Size = UDim2.new(1, -20, 1, 0)
        tabLbl.Position = UDim2.new(0, 16, 0, 0)
        tabLbl.Font = Enum.Font.GothamSemibold
        tabLbl.TextSize = 12
        tabLbl.TextColor3 = isInit and Color3.fromRGB(255, 75, 90) or Color3.fromRGB(140, 130, 145)
        tabLbl.Text = name
        tabLbl.TextXAlignment = Enum.TextXAlignment.Left
        tabLbl.BackgroundTransparency = 1
        tabLbl.Active = false
        tabLbl.ZIndex = 103
        tabLbl.Parent = tb

        tabButtons[name] = tb

        tb.MouseButton1Click:Connect(function()
            switchTab(name)
        end)
        return tb
    end

    makeTab("Main", 1)
    makeTab("Movement", 2)
    makeTab("Survival", 3)
    makeTab("Visuals", 4)
    makeTab("Settings", 5)

    -- ========================================================================
    -- ฟังก์ชันสร้างปุ่ม Checkbox คลีน (ไม่มีกล่องเขียวทางขวา)
    -- ========================================================================
    local allCheckboxes = {}

    local function makeCheckbox(parentScroll, labelText, descText, initialState, onToggle, order)
        local rowHeight = descText and 52 or 44
        local row = Instance.new("TextButton")
        row.Size = UDim2.new(1, -4, 0, rowHeight)
        row.BackgroundColor3 = initialState and Color3.fromRGB(24, 16, 24) or Color3.fromRGB(18, 14, 20)
        row.AutoButtonColor = false
        row.Text = ""
        row.ZIndex = 103
        row.LayoutOrder = order or 1
        row.Parent = parentScroll
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)
        local rowStroke = Instance.new("UIStroke", row)
        rowStroke.Color = initialState and Color3.fromRGB(255, 60, 80) or Color3.fromRGB(50, 22, 32)
        rowStroke.Thickness = 1.2

        -- กล่อง Checkbox สี่เหลี่ยมทางซ้าย
        local box = Instance.new("Frame")
        box.Size = UDim2.new(0, 22, 0, 22)
        box.Position = UDim2.new(0, 12, 0.5, -11)
        box.BackgroundColor3 = initialState and Color3.fromRGB(220, 45, 70) or Color3.fromRGB(30, 20, 28)
        box.BorderSizePixel = 0
        box.ZIndex = 104
        box.Parent = row
        Instance.new("UICorner", box).CornerRadius = UDim.new(0, 6)

        -- เครื่องหมายถูก ✓
        local tick = Instance.new("TextLabel")
        tick.Text = initialState and "✓" or ""
        tick.Font = Enum.Font.GothamBold
        tick.TextSize = 15
        tick.TextColor3 = Color3.fromRGB(255, 255, 255)
        tick.Size = UDim2.new(1, 0, 1, 0)
        tick.BackgroundTransparency = 1
        tick.Active = false
        tick.ZIndex = 105
        tick.Parent = box

        -- ข้อความชื่อฟังก์ชัน
        local label = Instance.new("TextLabel")
        label.Text = labelText
        label.Font = Enum.Font.GothamSemibold
        label.TextSize = 13
        label.TextColor3 = Color3.fromRGB(235, 235, 245)
        label.Size = UDim2.new(1, -50, 0, 20)
        label.Position = UDim2.new(0, 44, descText and 0.16 or 0.5, descText and 0 or -10)
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.BackgroundTransparency = 1
        label.Active = false
        label.ZIndex = 104
        label.Parent = row

        if descText then
            local desc = Instance.new("TextLabel")
            desc.Text = descText
            desc.Font = Enum.Font.Gotham
            desc.TextSize = 10
            desc.TextColor3 = Color3.fromRGB(145, 135, 150)
            desc.Size = UDim2.new(1, -50, 0, 16)
            desc.Position = UDim2.new(0, 44, 0.55, 0)
            desc.TextXAlignment = Enum.TextXAlignment.Left
            desc.BackgroundTransparency = 1
            desc.Active = false
            desc.ZIndex = 104
            desc.Parent = row
        end

        local enabled = initialState
        local isToggling = false

        local function updateVisual()
            tick.Text = enabled and "✓" or ""
            -- Scale bounce animation on toggle
            box.Size = UDim2.new(0, 18, 0, 18)
            box.Position = UDim2.new(0, 14, 0.5, -9)
            TweenService:Create(box, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                Size = UDim2.new(0, 22, 0, 22),
                Position = UDim2.new(0, 12, 0.5, -11),
                BackgroundColor3 = enabled and Color3.fromRGB(220, 45, 70) or Color3.fromRGB(30, 20, 28)
            }):Play()
            TweenService:Create(rowStroke, TweenInfo.new(0.18), {
                Color = enabled and Color3.fromRGB(255, 60, 80) or Color3.fromRGB(50, 22, 32)
            }):Play()
            TweenService:Create(row, TweenInfo.new(0.12), {
                BackgroundColor3 = enabled and Color3.fromRGB(24, 16, 24) or Color3.fromRGB(18, 14, 20)
            }):Play()
        end

        row.MouseEnter:Connect(function()
            TweenService:Create(row, TweenInfo.new(0.15), {
                BackgroundColor3 = Color3.fromRGB(26, 18, 26)
            }):Play()
        end)
        row.MouseLeave:Connect(function()
            TweenService:Create(row, TweenInfo.new(0.15), {
                BackgroundColor3 = enabled and Color3.fromRGB(24, 16, 24) or Color3.fromRGB(18, 14, 20)
            }):Play()
        end)

        local function toggle(forcedState)
            if isToggling then
                return
            end
            isToggling = true

            if forcedState ~= nil then
                enabled = forcedState
            else
                enabled = not enabled
            end

            updateVisual()
            if onToggle then
                onToggle(enabled)
            end

            task.wait(0.25)
            isToggling = false
        end

        row.MouseButton1Click:Connect(function()
            toggle()
        end)

        local entry = {
            row = row,
            toggle = toggle,
            get = function()
                return enabled
            end
        }
        table.insert(allCheckboxes, entry)
        return entry
    end

    local function makePlaceholder(parentScroll, text, desc, order)
        local btn = Instance.new("Frame")
        btn.Size = UDim2.new(1, -4, 0, 46)
        btn.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
        btn.LayoutOrder = order
        btn.ZIndex = 103
        btn.Parent = parentScroll
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
        local s = Instance.new("UIStroke", btn);
        s.Color = Color3.fromRGB(34, 34, 42);
        s.Thickness = 1

        local t1 = Instance.new("TextLabel")
        t1.Text = "    🔒 " .. text
        t1.Font = Enum.Font.GothamMedium
        t1.TextSize = 12
        t1.TextColor3 = Color3.fromRGB(120, 120, 135)
        t1.Size = UDim2.new(1, -20, 0, 20)
        t1.Position = UDim2.new(0, 4, 0.15, 0)
        t1.TextXAlignment = Enum.TextXAlignment.Left
        t1.BackgroundTransparency = 1
        t1.ZIndex = 104
        t1.Parent = btn

        local t2 = Instance.new("TextLabel")
        t2.Text = "        " .. desc
        t2.Font = Enum.Font.Gotham
        t2.TextSize = 10
        t2.TextColor3 = Color3.fromRGB(80, 80, 95)
        t2.Size = UDim2.new(1, -20, 0, 16)
        t2.Position = UDim2.new(0, 4, 0.55, 0)
        t2.TextXAlignment = Enum.TextXAlignment.Left
        t2.BackgroundTransparency = 1
        t2.ZIndex = 104
        t2.Parent = btn
    end

    -- ========================================================================
    -- 🎚️ ฟังก์ชันสร้าง Slider แถบเลื่อน สไตล์ macOS Frosted Glass
    -- ========================================================================
    local allSliders = {}

    local function makeSlider(parentScroll, labelText, descText, minVal, maxVal, initialVal, onChanged, order)
        -- 1. สร้างกล่องล่องหนมาครอบไว้ก่อนเพื่อหลอก UIListLayout
        local container = Instance.new("Frame")
        container.Name = "SliderContainer"
        container.Size = UDim2.new(1, 0, 0, 58) -- ขนาดความสูงเท่ากล่องเดิม
        container.BackgroundTransparency = 1
        container.LayoutOrder = order or 1
        container.Parent = parentScroll -- เอาลง Scroll แทน

        -- 2. สร้างกล่อง Slider สีเทาไว้ข้างใน Container
        local row = Instance.new("Frame")
        row.Name = "SliderRow"
        row.Size = UDim2.new(1, -16, 1, 0) -- ลดความกว้างลงเผื่อขอบซ้าย-ขวา (-24)
        row.Position = UDim2.new(0, 12, 0, 0) -- ขยับกล่องดันไปทางขวา 12 พิกเซล
        row.BackgroundColor3 = Color3.fromRGB(18, 14, 20)
        row.BorderSizePixel = 0
        row.ZIndex = 103
        row.Parent = container -- *** สำคัญ: เอา row มาใส่ใน container ***

        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)
        local rowStroke = Instance.new("UIStroke", row)
        rowStroke.Color = Color3.fromRGB(50, 22, 32)
        rowStroke.Thickness = 1.2

        -- ข้อความชื่อ
        local label = Instance.new("TextLabel")
        label.Text = labelText
        label.Font = Enum.Font.GothamSemibold
        label.TextSize = 12
        label.TextColor3 = Color3.fromRGB(235, 235, 245)
        label.Size = UDim2.new(1, -95, 0, 16)
        label.Position = UDim2.new(0, 12, 0, 6)
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.BackgroundTransparency = 1
        label.ZIndex = 104
        label.Parent = row

        -- ป้ายแสดงค่า (ขวาบน)
        local valueLabel = Instance.new("TextLabel")
        valueLabel.Font = Enum.Font.GothamBold
        valueLabel.TextSize = 12
        valueLabel.TextColor3 = Color3.fromRGB(255, 75, 90)
        valueLabel.Size = UDim2.new(0, 75, 0, 16)
        valueLabel.Position = UDim2.new(1, -87, 0, 6)
        valueLabel.TextXAlignment = Enum.TextXAlignment.Right
        valueLabel.BackgroundTransparency = 1
        valueLabel.ZIndex = 104
        valueLabel.Parent = row

        -- คำอธิบายสถานะ (ใต้ป้าย)
        local statusLabel = Instance.new("TextLabel")
        statusLabel.Font = Enum.Font.Gotham
        statusLabel.TextSize = 10
        statusLabel.TextColor3 = Color3.fromRGB(145, 135, 150)
        statusLabel.Size = UDim2.new(1, -24, 0, 13)
        statusLabel.Position = UDim2.new(0, 12, 0, 23)
        statusLabel.TextXAlignment = Enum.TextXAlignment.Left
        statusLabel.BackgroundTransparency = 1
        statusLabel.ZIndex = 104
        statusLabel.Parent = row

        -- แถบ Track (พื้นหลังสีเข้ม)
        local track = Instance.new("Frame")
        track.Name = "SliderTrack"
        track.Size = UDim2.new(1, -24, 0, 5)
        track.Position = UDim2.new(0, 16, 0, 42)
        track.BackgroundColor3 = Color3.fromRGB(30, 18, 26)
        track.BorderSizePixel = 0
        track.ZIndex = 104
        track.Parent = row
        Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

        -- แถบ Fill (สีแดงชมพู)
        local fill = Instance.new("Frame")
        fill.Name = "SliderFill"
        fill.BackgroundColor3 = Color3.fromRGB(220, 50, 75)
        fill.BorderSizePixel = 0
        fill.ZIndex = 105
        fill.Parent = track
        Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

        -- ปุ่ม Knob (จุดกลมลาก)
        local knob = Instance.new("Frame")
        knob.Name = "SliderKnob"
        knob.Size = UDim2.new(0, 14, 0, 14)
        knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        knob.BorderSizePixel = 0
        knob.ZIndex = 106
        knob.Parent = track
        Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)
        local knobStroke = Instance.new("UIStroke", knob)
        knobStroke.Color = Color3.fromRGB(200, 200, 210)
        knobStroke.Thickness = 1

        -- เงา Knob (Glow Effect)
        local knobGlow = Instance.new("Frame")
        knobGlow.Size = UDim2.new(0, 20, 0, 20)
        knobGlow.Position = UDim2.new(0.5, -10, 0.5, -10)
        knobGlow.BackgroundColor3 = Color3.fromRGB(255, 60, 80)
        knobGlow.BackgroundTransparency = 0.85
        knobGlow.BorderSizePixel = 0
        knobGlow.ZIndex = 105
        knobGlow.Parent = knob
        Instance.new("UICorner", knobGlow).CornerRadius = UDim.new(1, 0)

        local currentValue = math.clamp(initialVal, minVal, maxVal)
        local lastStrokeState = nil
        local isSyncing = false
        local sliderDragging = false

        -- ฟังก์ชันคำนวณข้อความสถานะตามระดับสปีด (ช่วง 16 ถึง 100 แบบคลีนไม่มี Emoji)
        local function getSpeedDesc(val)
            if val <= 16 then
                return descText or "ความเร็วปกติ (Default 16)"
            elseif val <= 22 then
                return "Ghost Walk — เนียนตาสุดๆ ฆาตกรดูไม่ออก"
            elseif val <= 28 then
                return
                    "Balanced Boost — วิ่งฉีกระยะพอดีๆ ปลอดภัยและเนียนตา (แนะนำ)"
            elseif val <= 45 then
                return "Fast Runner — ฉีกระยะห่างจากฆาตกรสบาย"
            elseif val <= 70 then
                return "Sonic Rush — สปีดสูง วิ่งข้ามแมพในพริบตา"
            else
                return "Flash God — ความเร็วสูงสุด (100 spd)!"
            end
        end

        local function applyVisual(val, directPct)
            local pct = directPct or math.clamp((val - minVal) / (maxVal - minVal), 0, 1)
            fill.Size = UDim2.new(pct, 0, 1, 0)
            knob.Position = UDim2.new(pct, -7, 0.5, -7)
            valueLabel.Text = tostring(val) .. " spd"
            statusLabel.Text = getSpeedDesc(val)

            local isHigh = (val > 28)
            if lastStrokeState ~= isHigh then
                lastStrokeState = isHigh
                TweenService:Create(rowStroke, TweenInfo.new(0.15), {
                    Color = isHigh and Color3.fromRGB(255, 60, 80) or Color3.fromRGB(50, 22, 32)
                }):Play()
            end
        end

        local function updateSlider(val, skipCallback)
            local rounded = math.clamp(math.floor(val + 0.5), minVal, maxVal)
            currentValue = rounded
            applyVisual(rounded)

            if onChanged and not skipCallback and not isSyncing then
                isSyncing = true
                onChanged(currentValue)
                isSyncing = false
            end
        end

        -- ตั้งค่าเริ่มต้น
        updateSlider(currentValue, true)

        -- ========== ระบบลากเลื่อน Slider แบบ Smooth 60 FPS ไร้กระตุก ==========
        local function processInput(inputPos)
            local trackAbsPos = track.AbsolutePosition.X
            local trackAbsSize = track.AbsoluteSize.X
            if trackAbsSize <= 0 then
                return
            end
            local relX = math.clamp((inputPos.X - trackAbsPos) / trackAbsSize, 0, 1)
            local rawVal = minVal + relX * (maxVal - minVal)
            local rounded = math.clamp(math.floor(rawVal + 0.5), minVal, maxVal)

            -- เลื่อน Knob และ Fill ทันทีอย่างต่อเนื่อง (Continuous Float) ไม่กระตุก
            applyVisual(rounded, relX)

            if rounded ~= currentValue then
                currentValue = rounded
                if onChanged and not isSyncing then
                    isSyncing = true
                    onChanged(currentValue)
                    isSyncing = false
                end
            end
        end

        local function startDrag(inputPos)
            sliderDragging = true
            TweenService:Create(knobGlow, TweenInfo.new(0.12), {
                Size = UDim2.new(0, 24, 0, 24),
                Position = UDim2.new(0.5, -12, 0.5, -12),
                BackgroundTransparency = 0.5
            }):Play()
            processInput(inputPos)
        end

        local function stopDrag()
            if sliderDragging then
                sliderDragging = false
                TweenService:Create(knobGlow, TweenInfo.new(0.15), {
                    Size = UDim2.new(0, 20, 0, 20),
                    Position = UDim2.new(0.5, -10, 0.5, -10),
                    BackgroundTransparency = 0.85
                }):Play()
                applyVisual(currentValue)
            end
        end

        -- ป้องกัน Scroll ขณะลาก Slider
        local inputFrame = Instance.new("TextButton")
        inputFrame.Text = ""
        inputFrame.BackgroundTransparency = 1
        inputFrame.Size = UDim2.new(1, 0, 0, 26)
        inputFrame.Position = UDim2.new(0, 0, 0, 31)
        inputFrame.ZIndex = 107
        inputFrame.Parent = row

        inputFrame.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                startDrag(input.Position)
            end
        end)

        UserInputService.InputChanged:Connect(function(input)
            if sliderDragging and
                (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType ==
                    Enum.UserInputType.Touch) then
                processInput(input.Position)
            end
        end)

        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                stopDrag()
            end
        end)

        local entry = {
            row = row,
            track = track,
            processInput = processInput,
            isDragging = function()
                return sliderDragging
            end,
            setDragging = function(v)
                sliderDragging = v
                if not v then
                    stopDrag()
                end
            end,
            getValue = function()
                return currentValue
            end,
            setValue = function(val)
                if not sliderDragging then
                    updateSlider(val, true)
                end
            end
        }
        table.insert(allSliders, entry)
        return entry
    end

    -- ========================================================================
    -- ฟังก์ชันสร้างหัวข้อย่อยคั่นหมวดหมู่ (Section Header)
    -- ========================================================================
    local function makeSectionHeader(parentScroll, titleText, order)
        local hdr = Instance.new("Frame")
        hdr.Name = "SectionHeader"
        hdr.Size = UDim2.new(1, -4, 0, 22)
        hdr.BackgroundTransparency = 1
        hdr.LayoutOrder = order or 1
        hdr.ZIndex = 103
        hdr.Parent = parentScroll

        local lbl = Instance.new("TextLabel")
        lbl.Text = titleText
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 12
        lbl.TextColor3 = Color3.fromRGB(215, 65, 85)
        lbl.Size = UDim2.new(1, 0, 1, 0)
        lbl.Position = UDim2.new(0, 4, 0, 0)
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.BackgroundTransparency = 1
        lbl.ZIndex = 104
        lbl.Parent = hdr
        return hdr
    end

    -- ========================================================================
    -- TAB 1: MAIN (หน้าหลัก — ศูนย์รวม 3 สวิตช์หลักที่สำคัญที่สุด)
    -- ========================================================================
    makeSectionHeader(mainPage, "สวิตช์ด่วนยอดนิยม (Top 3 Core Features)", 1)

    local survSC -- Forward declare for sync
    local mainSC = makeCheckbox(mainPage, "Auto Skill Check (Great Zone 105°)",
        "กด Great Zone 105° ให้อัตโนมัติทุกรอบ (ปั่นไฟ & รักษา)",
        HubConfig.AutoGreatZone, function(st)
            HubConfig.AutoGreatZone = st
            if survSC then
                pcall(function()
                    survSC.toggle(st)
                end)
            end
        end, 2)

    local movSpeedCB -- Forward declare for sync
    local mainSpeedCB = makeCheckbox(mainPage, "Smooth Speed Boost [B]",
        "ระบบบูสต์ความเร็ว CFrame เนียนตา ไม่ดีด ไม่กระตุก",
        HubConfig.SpeedEnabled, function(st)
            HubConfig.SpeedEnabled = st
            if movSpeedCB then
                pcall(function()
                    movSpeedCB.toggle(st)
                end)
            end
        end, 3)

    local movSpeedSlider -- Forward declare for sync
    local mainSpeedSlider = makeSlider(mainPage, "ปรับระดับความเร็ว (Speed Level)",
        "สปีด CFrame ปรับได้อิสระ 16 - 100 (แนะนำ 21-28 เพื่อความเนียนตา)",
        16, 100, HubConfig.SpeedValue, function(val)
            HubConfig.SpeedValue = val
            if movSpeedSlider then
                pcall(function()
                    movSpeedSlider.setValue(val)
                end)
            end
        end, 4)

    local visESP -- Forward declare for sync
    local mainESP = makeCheckbox(mainPage, "Player & Killer ESP (Box 3D)",
        "กล่องแดง: Killer  |  กล่องเขียว: Player พร้อมระยะทาง",
        HubConfig.ESPEnabled, function(st)
            HubConfig.ESPEnabled = st
            refreshAllESP()
            if visESP then
                pcall(function()
                    visESP.toggle(st)
                end)
            end
        end, 5)

    -- ========================================================================
    -- TAB 2: MOVEMENT (หมวดหมู่การเคลื่อนที่ & กายภาพ)
    -- ========================================================================
    makeSectionHeader(movementPage, "ความเร็วและการเดิน (Speed & Motion)", 1)

    movSpeedCB = makeCheckbox(movementPage, "Smooth Speed Boost [B]",
        "ระบบบูสต์ความเร็ว CFrame เนียนตา ไม่ดีด ไม่กระตุก",
        HubConfig.SpeedEnabled, function(st)
            HubConfig.SpeedEnabled = st
            if mainSpeedCB then
                pcall(function()
                    mainSpeedCB.toggle(st)
                end)
            end
        end, 2)

    movSpeedSlider = makeSlider(movementPage, "ปรับระดับความเร็ว (Speed Level)",
        "สปีด CFrame ปรับได้อิสระ 16 - 100 (แนะนำ 21-28 เพื่อความเนียนตา)",
        16, 100, HubConfig.SpeedValue, function(val)
            HubConfig.SpeedValue = val
            if mainSpeedSlider then
                pcall(function()
                    mainSpeedSlider.setValue(val)
                end)
            end
        end, 3)

    local movNoclipCB = makeCheckbox(movementPage, "Ghost Noclip (Walkthrough) [N]",
        "เดินทะลุกำแพง ประตูล็อก สิ่งกีดขวาง ไม่ร่วงตกแมพ",
        HubConfig.NoclipEnabled, function(st)
            HubConfig.NoclipEnabled = st
        end, 4)

    makeSectionHeader(movementPage,
        "กายภาพและการเคลื่อนไหวพิเศษ (Advanced Mobility)", 5)

    local movNoFall = makeCheckbox(movementPage,
        "No Fall Stun (ตกจากที่สูงไม่สตั้น)",
        "โดดลงจากที่สูงไม่มีดีเลย์/กระตุก วิ่งต่อได้ทันที 100%",
        HubConfig.NoFall, function(st)
            HubConfig.NoFall = st
        end, 6)

    local movFastVault = makeCheckbox(movementPage,
        "Fast Vault Helper (ข้ามหน้าต่างเร็ว)",
        "เร่งโมเมนตัมพุ่งข้ามหน้าต่างและแผ่นไม้ระดับ Fast Vault",
        HubConfig.FastVault, function(st)
            HubConfig.FastVault = st
        end, 7)

    -- ========================================================================
    -- TAB 3: SURVIVAL (หมวดหมู่การเอาชีวิตรอด & ภารกิจ)
    -- ========================================================================
    makeSectionHeader(survivalPage, "ซ่อมเครื่อง & รักษา (Objectives & Health)", 1)

    survSC = makeCheckbox(survivalPage, "Auto Skill Check (Great Zone 105°)",
        "กด Great Zone 105° ให้อัตโนมัติทุกรอบ (ปั่นไฟ & รักษาเพื่อน)",
        HubConfig.AutoGreatZone, function(st)
            HubConfig.AutoGreatZone = st
            if mainSC then
                pcall(function()
                    mainSC.toggle(st)
                end)
            end
        end, 2)

    local survHeal = makeCheckbox(survivalPage,
        "Auto Heal Teammate (รักษาเพื่อนอัตโนมัติ)",
        "ช่วยรักษาเพื่อนร่วมทีมทันทีเมื่อเดินเข้าไปใกล้",
        HubConfig.AutoHeal, function(st)
            HubConfig.AutoHeal = st
        end, 3)

    makeSectionHeader(survivalPage,
        "การป้องกันตัว & โต้กลับฆาตกร (Defense & Counter)", 4)

    local survWiggle = makeCheckbox(survivalPage, "Auto Wiggle / Struggle",
        "ดิ้นหลุดจากไหล่ฆาตกรอัตโนมัติ (สแปม A/D + Spacebar ทันที)",
        HubConfig.AutoWiggle, function(st)
            HubConfig.AutoWiggle = st
        end, 5)

    local survPallet = makeCheckbox(survivalPage, "Auto Pallet Drop (ทิ้งไม้ใส่ฆาตกร)",
        "ทิ้งแผ่นไม้ใส่ฆาตกรทันทีเมื่ออยู่ในระยะ Stun 12 studs",
        HubConfig.AutoPallet, function(st)
            HubConfig.AutoPallet = st
        end, 6)

    -- ========================================================================
    -- TAB 4: VISUALS (หมวดหมู่การมองเห็น & แดชบอร์ดสด)
    -- ========================================================================
    makeSectionHeader(visualsPage, "ระบบเรดาร์ทะลุกำแพง (ESP Wallhacks)", 1)

    visESP = makeCheckbox(visualsPage, "Player & Killer ESP (Box 3D)",
        "กล่องแดง: Killer  |  กล่องเขียว: Player พร้อมระยะทาง",
        HubConfig.ESPEnabled, function(st)
            HubConfig.ESPEnabled = st
            refreshAllESP()
            if mainESP then
                pcall(function()
                    mainESP.toggle(st)
                end)
            end
        end, 2)

    local visGen = makeCheckbox(visualsPage, "Generator Aura ESP (เฉพาะยังไม่เสร็จ)",
        "แสดง Aura เรืองแสงสีส้มทองเฉพาะเครื่องที่ยังไม่เสร็จ พร้อม %",
        HubConfig.GenESPEnabled, function(st)
            HubConfig.GenESPEnabled = st
            refreshAllGenESP()
        end, 3)

    makeSectionHeader(visualsPage,
        "การปรับแต่งทัศนวิสัย (Lighting & Visibility)", 4)

    local visFullbright = makeCheckbox(visualsPage,
        "Balanced Fullbright (สว่างสบายตา เคลียร์หมอก)",
        "ปรับแสงสว่างพอเหมาะ ไม่แสบตา ล้างหมอกควัน มืดแค่ไหนก็มองเห็นชัด",
        HubConfig.FullbrightEnabled, function(st)
            HubConfig.FullbrightEnabled = st
            if st then
                applyFullbright()
            else
                restoreLighting()
            end
        end, 5)

    makeSectionHeader(visualsPage, "แดชบอร์ดแมตช์สด (Live Match Radar)", 6)

    local function makeStatusCard(parent, titleText, descText, order)
        local card = Instance.new("Frame")
        card.Size = UDim2.new(1, -4, 0, 52)
        card.BackgroundColor3 = Color3.fromRGB(18, 14, 20)
        card.LayoutOrder = order
        card.ZIndex = 103
        card.Parent = parent
        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
        local cs = Instance.new("UIStroke", card);
        cs.Color = Color3.fromRGB(50, 22, 32);
        cs.Thickness = 1

        local title = Instance.new("TextLabel")
        title.Text = titleText
        title.Font = Enum.Font.GothamBold
        title.TextSize = 12
        title.TextColor3 = Color3.fromRGB(255, 75, 90)
        title.Size = UDim2.new(1, -20, 0, 18)
        title.Position = UDim2.new(0, 12, 0, 8)
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.BackgroundTransparency = 1
        title.ZIndex = 104
        title.Parent = card

        local desc = Instance.new("TextLabel")
        desc.Text = descText
        desc.Font = Enum.Font.Gotham
        desc.TextSize = 11
        desc.TextColor3 = Color3.fromRGB(180, 175, 190)
        desc.Size = UDim2.new(1, -20, 0, 18)
        desc.Position = UDim2.new(0, 12, 0, 26)
        desc.TextXAlignment = Enum.TextXAlignment.Left
        desc.BackgroundTransparency = 1
        desc.ZIndex = 104
        desc.Parent = card

        return desc
    end

    local killerStatusLabel = makeStatusCard(visualsPage, "Killer Status",
        "กำลังสแกนหาฆาตกรในห้อง...", 7)
    local survivorCountLabel = makeStatusCard(visualsPage, "Survivor Count",
        "ผู้เล่นในเซิร์ฟเวอร์: " .. tostring(#Players:GetPlayers()) .. " คน",
        8)
    local fpsLabel = makeStatusCard(visualsPage, "Client Performance", "FPS: 60  •  Ping: 0 ms", 9)

    task.spawn(function()
        while true do
            task.wait(0.8)
            pcall(function()
                local kName = "ไม่พบฆาตกร / ฆาตกรซ่อนตัว"
                local kDist = ""
                local myChar = LocalPlayer.Character
                local myRoot = myChar and (myChar:FindFirstChild("HumanoidRootPart") or myChar:FindFirstChild("Torso"))

                for char, data in pairs(ESPObjects) do
                    if data.isKiller and data.root and data.root.Parent then
                        kName = data.name
                        if myRoot then
                            local d = math.floor((data.root.Position - myRoot.Position).Magnitude)
                            kDist = " (ระยะ: " .. d .. "m)"
                        end
                        break
                    end
                end
                killerStatusLabel.Text = "ฆาตกร: " .. kName .. kDist
                local plrs = Players:GetPlayers()
                survivorCountLabel.Text = "ผู้เล่นทั้งหมดในห้อง: " ..
                                              tostring(#plrs) .. " คน (พร้อมเล่น)"
                local ping = math.floor(LocalPlayer:GetNetworkPing() * 1000)
                fpsLabel.Text = "Ping: " .. tostring(ping) ..
                                    " ms  •  ระบบพร้อมทำงาน 100%"
            end)
        end
    end)

    -- ========================================================================
    -- TAB 5: SETTINGS (การตั้งค่า)
    -- ========================================================================
    makeSectionHeader(settingsPage, "คู่มือปุ่มลัด (Hotkeys Guide)", 1)

    local setCard1 = Instance.new("Frame")
    setCard1.Size = UDim2.new(1, -4, 0, 68)
    setCard1.BackgroundColor3 = Color3.fromRGB(18, 14, 20)
    setCard1.LayoutOrder = 2
    setCard1.ZIndex = 103
    setCard1.Parent = settingsPage
    Instance.new("UICorner", setCard1).CornerRadius = UDim.new(0, 8)
    local scs1 = Instance.new("UIStroke", setCard1);
    scs1.Color = Color3.fromRGB(50, 22, 32);
    scs1.Thickness = 1

    local sTitle = Instance.new("TextLabel")
    sTitle.Text = "ปุ่มลัดเปิด/ปิดหน้าต่าง (Toggle Key)"
    sTitle.Font = Enum.Font.GothamBold
    sTitle.TextSize = 12
    sTitle.TextColor3 = Color3.fromRGB(255, 75, 90)
    sTitle.Size = UDim2.new(1, -20, 0, 18)
    sTitle.Position = UDim2.new(0, 12, 0, 10)
    sTitle.TextXAlignment = Enum.TextXAlignment.Left
    sTitle.BackgroundTransparency = 1
    sTitle.ZIndex = 104
    sTitle.Parent = setCard1

    local sDesc = Instance.new("TextLabel")
    sDesc.Text =
        "กดปุ่ม [ Right Control ] บนคีย์บอร์ด เพื่อซ่อนหรือเปิดแผงควบคุม"
    sDesc.Font = Enum.Font.Gotham
    sDesc.TextSize = 11
    sDesc.TextColor3 = Color3.fromRGB(160, 150, 165)
    sDesc.Size = UDim2.new(1, -20, 0, 18)
    sDesc.Position = UDim2.new(0, 12, 0, 32)
    sDesc.TextXAlignment = Enum.TextXAlignment.Left
    sDesc.BackgroundTransparency = 1
    sDesc.ZIndex = 104
    sDesc.Parent = setCard1

    makeStatusCard(settingsPage, "ปุ่มลัด Speed Boost",
        "กดปุ่ม [ B ] เปิด/ปิดระบบ Smooth Speed  •  ปรับค่าได้ในแท็บ Movement",
        3)
    makeStatusCard(settingsPage, "ปุ่มลัด Ghost Noclip",
        "กดปุ่ม [ N ] เปิด/ปิดระบบเดินทะลุกำแพง  •  ไม่ร่วงตกแมพ",
        4)

    makeSectionHeader(settingsPage, "จัดการหน้าต่าง (Window Controls)", 5)

    local resetBtn = Instance.new("TextButton")
    resetBtn.Size = UDim2.new(1, -4, 0, 42)
    resetBtn.BackgroundColor3 = Color3.fromRGB(24, 16, 24)
    resetBtn.Font = Enum.Font.GothamSemibold
    resetBtn.TextSize = 12
    resetBtn.TextColor3 = Color3.fromRGB(230, 220, 230)
    resetBtn.Text = "รีเซ็ตตำแหน่งหน้าต่าง (Reset Window Position)"
    resetBtn.LayoutOrder = 6
    resetBtn.ZIndex = 103
    resetBtn.Parent = settingsPage
    Instance.new("UICorner", resetBtn).CornerRadius = UDim.new(0, 8)
    local rbs = Instance.new("UIStroke", resetBtn);
    rbs.Color = Color3.fromRGB(60, 25, 38);
    rbs.Thickness = 1
    resetBtn.MouseButton1Click:Connect(function()
        TweenService:Create(main, TweenInfo.new(0.3, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
            Position = UDim2.new(0.5, -main.Size.X.Offset / 2, 0.5, -main.Size.Y.Offset / 2)
        }):Play()
    end)

    -- ========================================================================
    -- ชุมชน Discord (Community Link)
    -- ========================================================================
    makeSectionHeader(settingsPage, "ชุมชน Discord (Community)", 7)

    local discordCard = Instance.new("TextButton")
    discordCard.Size = UDim2.new(1, -4, 0, 58)
    discordCard.BackgroundColor3 = Color3.fromRGB(24, 15, 22)
    discordCard.AutoButtonColor = false
    discordCard.Text = ""
    discordCard.LayoutOrder = 8
    discordCard.ZIndex = 103
    discordCard.Parent = settingsPage
    Instance.new("UICorner", discordCard).CornerRadius = UDim.new(0, 8)
    local dcs = Instance.new("UIStroke", discordCard)
    dcs.Color = Color3.fromRGB(200, 55, 75)
    dcs.Thickness = 1.3

    local dTitle = Instance.new("TextLabel")
    dTitle.Text = "sixbabyboy discord"
    dTitle.Font = Enum.Font.GothamBold
    dTitle.TextSize = 13
    dTitle.TextColor3 = Color3.fromRGB(255, 75, 90)
    dTitle.Size = UDim2.new(1, -28, 0, 18)
    dTitle.Position = UDim2.new(0, 14, 0, 9)
    dTitle.TextXAlignment = Enum.TextXAlignment.Left
    dTitle.BackgroundTransparency = 1
    dTitle.ZIndex = 104
    dTitle.Parent = discordCard

    local dLink = Instance.new("TextLabel")
    dLink.Text = "https://discord.gg/TEv68MzVtb  •  [คลิกเพื่อคัดลอกลิงก์]"
    dLink.Font = Enum.Font.GothamMedium
    dLink.TextSize = 11
    dLink.TextColor3 = Color3.fromRGB(195, 185, 200)
    dLink.Size = UDim2.new(1, -28, 0, 18)
    dLink.Position = UDim2.new(0, 14, 0, 29)
    dLink.TextXAlignment = Enum.TextXAlignment.Left
    dLink.BackgroundTransparency = 1
    dLink.ZIndex = 104
    dLink.Parent = discordCard

    local copiedAnim = false
    discordCard.MouseButton1Click:Connect(function()
        if copiedAnim then
            return
        end
        copiedAnim = true

        pcall(function()
            if setclipboard then
                setclipboard("https://discord.gg/TEv68MzVtb")
            elseif toclipboard then
                toclipboard("https://discord.gg/TEv68MzVtb")
            elseif syn and syn.write_clipboard then
                syn.write_clipboard("https://discord.gg/TEv68MzVtb")
            end
        end)

        dLink.Text = "คัดลอกลิงก์เรียบร้อยแล้ว! (Copied to clipboard)"
        dLink.TextColor3 = Color3.fromRGB(45, 255, 120)
        TweenService:Create(dcs, TweenInfo.new(0.2), {
            Color = Color3.fromRGB(45, 255, 120)
        }):Play()

        task.delay(2.5, function()
            dLink.Text =
                "https://discord.gg/TEv68MzVtb  •  [คลิกเพื่อคัดลอกลิงก์]"
            dLink.TextColor3 = Color3.fromRGB(195, 185, 200)
            TweenService:Create(dcs, TweenInfo.new(0.2), {
                Color = Color3.fromRGB(200, 55, 75)
            }):Play()
            copiedAnim = false
        end)
    end)

    -- ========================================================================
    -- 🍎 อนิเมชั่นหน้าต่างสไตล์ MacBook (Close / Minimize / Maximize)
    -- ========================================================================
    closeWindow = function()
        if not HubConfig.UIVisible then
            return
        end
        HubConfig.UIVisible = false

        -- Smooth shrink & fade out
        local closeTween = TweenService:Create(main,
            TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
                Size = UDim2.new(0, main.Size.X.Offset * 0.85, 0, main.Size.Y.Offset * 0.85),
                BackgroundTransparency = 1
            })
        closeTween:Play()
        closeTween.Completed:Connect(function()
            main.Visible = false
            main.BackgroundTransparency = 0
            main.Size = normalSize
        end)
    end

    local function openWindow()
        HubConfig.UIVisible = true
        main.Visible = true
        main.BackgroundTransparency = 0.6
        local targetSize = isMaximized and UDim2.new(0, 740, 0, 480) or normalSize
        main.Size = UDim2.new(0, targetSize.X.Offset * 0.9, 0, targetSize.Y.Offset * 0.9)

        TweenService:Create(main, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = targetSize,
            BackgroundTransparency = 0
        }):Play()
    end

    -- 🟡 Minimize (ย่อหน้าต่างพับเหลือเฉพาะแถบ Header)
    toggleMinimize = function()
        isMinimized = not isMinimized
        if isMinimized then
            side.Visible = false
            content.Visible = false
            TweenService:Create(main, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Size = UDim2.new(0, main.Size.X.Offset, 0, 42)
            }):Play()
        else
            local targetH = isMaximized and 480 or 370
            local tween = TweenService:Create(main, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
                {
                    Size = UDim2.new(0, main.Size.X.Offset, 0, targetH)
                })
            tween:Play()
            tween.Completed:Connect(function()
                if not isMinimized then
                    side.Visible = true
                    content.Visible = true
                end
            end)
        end
    end

    -- 🟢 Maximize (ขยายขนาดใหญ่ขึ้นเต็มตา / ย่อกลับขนาดปกติ)
    toggleMaximize = function()
        if isMinimized then
            toggleMinimize()
        end

        isMaximized = not isMaximized
        if isMaximized then
            normalPos = main.Position
            TweenService:Create(main, TweenInfo.new(0.32, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
                Size = UDim2.new(0, 740, 0, 480),
                Position = UDim2.new(0.5, -370, 0.5, -240)
            }):Play()
        else
            TweenService:Create(main, TweenInfo.new(0.32, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
                Size = normalSize,
                Position = normalPos
            }):Play()
        end
    end

    -- ========================================================================
    -- 7. ระบบลากหน้าต่าง (Draggable Header)
    -- ========================================================================
    local dragging = false
    local dragOrigin = Vector3.zero
    local frameOrigin = UDim2.new()

    hdr.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragOrigin = input.Position
            frameOrigin = main.Position
            local c;
            c = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false;
                    if c then
                        c:Disconnect()
                    end
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and
            (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - dragOrigin
            main.Position = UDim2.new(frameOrigin.X.Scale, frameOrigin.X.Offset + d.X, frameOrigin.Y.Scale,
                frameOrigin.Y.Offset + d.Y)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    -- ========================================================================
    -- 9. คีย์ลัด Right Ctrl / B / N + ดักคลิกขณะเปิดเมนู ESC
    -- ========================================================================
    local function insideGui(obj, x, y)
        if not obj or not obj.Visible then
            return false
        end
        local p = obj.AbsolutePosition;
        local s = obj.AbsoluteSize
        return x >= p.X and x <= p.X + s.X and y >= p.Y and y <= p.Y + s.Y
    end

    UserInputService.InputBegan:Connect(function(input, gpe)
        -- ปุ่มลัดซ่อน/เปิดแผง (Right Ctrl)
        if input.KeyCode == HubConfig.ToggleKey then
            if HubConfig.UIVisible then
                closeWindow()
            else
                openWindow()
            end
            return
        end

        -- ปุ่มลัด Speed Toggle [B]
        if input.KeyCode == HubConfig.SpeedKey then
            HubConfig.SpeedEnabled = not HubConfig.SpeedEnabled
            pcall(function()
                if movSpeedCB then
                    movSpeedCB.toggle(HubConfig.SpeedEnabled)
                end
            end)
            pcall(function()
                if mainSpeedCB then
                    mainSpeedCB.toggle(HubConfig.SpeedEnabled)
                end
            end)
            return
        end

        -- ปุ่มลัด Noclip Toggle [N]
        if input.KeyCode == HubConfig.NoclipKey then
            HubConfig.NoclipEnabled = not HubConfig.NoclipEnabled
            pcall(function()
                if movNoclipCB then
                    movNoclipCB.toggle(HubConfig.NoclipEnabled)
                end
            end)
            pcall(function()
                if mainNoclipCB then
                    mainNoclipCB.toggle(HubConfig.NoclipEnabled)
                end
            end)
            return
        end

        local isEscOpen = false
        pcall(function()
            isEscOpen = GuiService.MenuIsOpen
        end)

        if not isEscOpen then
            return
        end

        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if not HubConfig.UIVisible or not main.Visible then
                return
            end
            local cx, cy = input.Position.X, input.Position.Y

            -- Traffic lights
            if insideGui(dotRed, cx, cy) then
                closeWindow();
                return
            end
            if insideGui(dotYellow, cx, cy) then
                toggleMinimize();
                return
            end
            if insideGui(dotGreen, cx, cy) then
                toggleMaximize();
                return
            end

            -- Tabs
            for tName, btn in pairs(tabButtons) do
                if insideGui(btn, cx, cy) then
                    switchTab(tName);
                    return
                end
            end

            -- Checkboxes
            for _, cb in ipairs(allCheckboxes) do
                if insideGui(cb.row, cx, cy) then
                    cb.toggle();
                    return
                end
            end

            -- Sliders (ESC menu support)
            for _, sl in ipairs(allSliders) do
                if insideGui(sl.row, cx, cy) then
                    sl.processInput(input.Position)
                    sl.setDragging(true)
                    return
                end
            end

            -- Header Dragging
            if insideGui(hdr, cx, cy) then
                dragging = true;
                dragOrigin = input.Position;
                frameOrigin = main.Position
            end
        end
    end)

    -- ดักลากเลื่อน Slider ขณะเปิดเมนู ESC
    UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            for _, sl in ipairs(allSliders) do
                if sl.isDragging() then
                    sl.processInput(input.Position)
                end
            end
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            for _, sl in ipairs(allSliders) do
                sl.setDragging(false)
            end
        end
    end)

    -- ========================================================================
    -- 📱 ปุ่มเปิด/ปิดเมนูสำหรับมือถือ (Mobile Floating Logo Button)
    -- ========================================================================
    local mobileBtn = Instance.new("ImageButton")
    mobileBtn.Name = "SBB_MobileToggle"
    mobileBtn.Size = UDim2.new(0, 52, 0, 52)
    mobileBtn.Position = UDim2.new(0, 16, 0.45, 0)
    mobileBtn.BackgroundColor3 = Color3.fromRGB(20, 14, 22)
    mobileBtn.BorderSizePixel = 0
    mobileBtn.AutoButtonColor = false
    mobileBtn.Active = true
    mobileBtn.ZIndex = 200
    mobileBtn.Parent = scr

    Instance.new("UICorner", mobileBtn).CornerRadius = UDim.new(1, 0)
    local mStroke = Instance.new("UIStroke", mobileBtn)
    mStroke.Color = Color3.fromRGB(255, 60, 80)
    mStroke.Thickness = 1.8

    local mGlow = Instance.new("Frame")
    mGlow.Size = UDim2.new(1, 8, 1, 8)
    mGlow.Position = UDim2.new(0, -4, 0, -4)
    mGlow.BackgroundColor3 = Color3.fromRGB(255, 60, 80)
    mGlow.BackgroundTransparency = 0.88
    mGlow.BorderSizePixel = 0
    mGlow.ZIndex = 199
    mGlow.Parent = mobileBtn
    Instance.new("UICorner", mGlow).CornerRadius = UDim.new(1, 0)

    local logoImg = Instance.new("ImageLabel")
    logoImg.Name = "LogoImage"
    logoImg.Size = UDim2.new(0.85, 0, 0.85, 0)
    logoImg.Position = UDim2.new(0.075, 0, 0.075, 0)
    logoImg.BackgroundTransparency = 1
    logoImg.ScaleType = Enum.ScaleType.Fit
    logoImg.ZIndex = 201
    logoImg.Parent = mobileBtn

    local fallbackText = Instance.new("TextLabel")
    fallbackText.Name = "FallbackText"
    fallbackText.Size = UDim2.new(1, 0, 1, 0)
    fallbackText.BackgroundTransparency = 1
    fallbackText.Font = Enum.Font.GothamBold
    fallbackText.Text = "SB"
    fallbackText.TextSize = 18
    fallbackText.TextColor3 = Color3.fromRGB(255, 75, 90)
    fallbackText.Visible = true
    fallbackText.ZIndex = 201
    fallbackText.Parent = mobileBtn

    task.spawn(function()
        pcall(function()
            local customAssetFunc = getcustomasset or getsynasset
            if customAssetFunc and writefile then
                if not (isfile and isfile("sbb_logo.png")) then
                    local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
                    local b64Data =
                        "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"
                    local res = {}
                    local k = 1
                    for i = 1, #b64Data, 4 do
                        local s1 = b:find(b64Data:sub(i, i))
                        local s2 = b:find(b64Data:sub(i + 1, i + 1))
                        local s3 = b:find(b64Data:sub(i + 2, i + 2))
                        local s4 = b:find(b64Data:sub(i + 3, i + 3))
                        if s1 and s2 then
                            local b1 = s1 - 1
                            local b2 = s2 - 1
                            res[k] = string.char((b1 * 4) + math.floor(b2 / 16))
                            k = k + 1
                            if s3 then
                                local b3 = s3 - 1
                                res[k] = string.char(((b2 % 16) * 16) + math.floor(b3 / 4))
                                k = k + 1
                                if s4 then
                                    local b4 = s4 - 1
                                    res[k] = string.char(((b3 % 4) * 64) + b4)
                                    k = k + 1
                                end
                            end
                        end
                    end
                    writefile("sbb_logo.png", table.concat(res))
                end

                local asset = customAssetFunc("sbb_logo.png")
                if asset then
                    logoImg.Image = asset
                    fallbackText.Visible = false
                end
            end
        end)
    end)

    local mDragging = false
    local mDragStart = Vector3.zero
    local mStartPos = UDim2.new()
    local mTotalDist = 0

    mobileBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            mDragging = true
            mDragStart = input.Position
            mStartPos = mobileBtn.Position
            mTotalDist = 0
            TweenService:Create(mobileBtn, TweenInfo.new(0.12), {
                Size = UDim2.new(0, 47, 0, 47)
            }):Play()
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if mDragging and
            (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - mDragStart
            mTotalDist = mTotalDist + math.abs(delta.X) + math.abs(delta.Y)
            mobileBtn.Position = UDim2.new(mStartPos.X.Scale, mStartPos.X.Offset + delta.X, mStartPos.Y.Scale,
                mStartPos.Y.Offset + delta.Y)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if mDragging then
                mDragging = false
                TweenService:Create(mobileBtn, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                    Size = UDim2.new(0, 52, 0, 52)
                }):Play()

                if mTotalDist < 14 then
                    if HubConfig.UIVisible then
                        closeWindow()
                    else
                        openWindow()
                    end
                end
            end
        end
    end)

end

buildUI()
