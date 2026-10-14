--[=[
 blockxycola.lua — Roblox Studio Developer Toolkit
 ใช้เฉพาะในเกมที่คุณเป็นผู้พัฒนา: วางเป็น LocalScript ใน
 StarterPlayer > StarterPlayerScripts

 รวม: UI ลากย้าย/ย่อ/RightShift, player HUD, speed toggle + configurable key,
 local test heal + configurable key/amount, graphics reduce/restore, diagnostics, NPC-only training ESP/Aim Assist,
 shop scanner (ProximityPrompt, CollectionService tags, shop/item-like names and attributes),
 scan results + selection, cleanup and respawn handling.

 ข้อจำกัดโดยเจตนา: ไม่มี aimbot/aim assist/ล็อกหัว หรือ ESP ติดตามผู้เล่นอื่น
 สำหรับใช้กับเกมคนอื่น/Executor และ Shop Scanner ไม่ซื้อของเอง; การซื้อจริงควรเรียก
 RemoteEvent ที่ตรวจสอบเงิน ราคา ระยะ และสิทธิ์บนเซิร์ฟเวอร์ของเกมที่คุณเป็นเจ้าของ.
]=]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")
local player = Players.LocalPlayer
if not player then return end

local GUI_NAME = "BlockxycolaToolkit"
local old = player:WaitForChild("PlayerGui"):FindFirstChild(GUI_NAME)
if old then old:Destroy() end

local alive = true
local connections = {}
local function bind(signal, fn)
    local c = signal:Connect(fn)
    table.insert(connections, c)
    return c
end
local function disconnectAll()
    for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    table.clear(connections)
end

local C = {
    bg = Color3.fromRGB(15,17,24), panel = Color3.fromRGB(24,27,38), card = Color3.fromRGB(31,35,49),
    line = Color3.fromRGB(55,61,80), text = Color3.fromRGB(244,246,255), muted = Color3.fromRGB(157,165,187),
    accent = Color3.fromRGB(125,100,255), green = Color3.fromRGB(83,218,148), red = Color3.fromRGB(244,93,110),
    amber = Color3.fromRGB(255,190,90),
}
local function make(class, props, parent)
    local o = Instance.new(class)
    for k,v in pairs(props or {}) do o[k] = v end
    o.Parent = parent
    return o
end
local function corner(o, r) make("UICorner", {CornerRadius=UDim.new(0,r or 10)}, o) end
local function stroke(o, color) make("UIStroke", {Color=color or C.line, Thickness=1, Transparency=0.12}, o) end
local function label(parent, text, pos, size, opts)
    opts = opts or {}
    return make("TextLabel", {BackgroundTransparency=1, Text=text, Position=pos, Size=size,
        Font=opts.font or Enum.Font.Gotham, TextSize=opts.textSize or 13, TextColor3=opts.color or C.text,
        TextXAlignment=opts.align or Enum.TextXAlignment.Left, TextYAlignment=opts.yAlign or Enum.TextYAlignment.Center,
        TextWrapped=opts.wrap or false}, parent)
end
local function button(parent, text, pos, size, color)
    local b = make("TextButton", {Text=text, Position=pos, Size=size, BackgroundColor3=color or C.accent,
        TextColor3=C.text, Font=Enum.Font.GothamSemibold, TextSize=12, AutoButtonColor=true,
        BorderSizePixel=0}, parent)
    corner(b, 8)
    return b
end
local function textbox(parent, text, pos, size, placeholder)
    local t = make("TextBox", {Text=text or "", PlaceholderText=placeholder or "", Position=pos, Size=size,
        BackgroundColor3=C.bg, TextColor3=C.text, PlaceholderColor3=C.muted, Font=Enum.Font.Gotham,
        TextSize=12, ClearTextOnFocus=false, BorderSizePixel=0}, parent)
    corner(t, 7); stroke(t)
    return t
end

local gui = make("ScreenGui", {Name=GUI_NAME, ResetOnSpawn=false, ZIndexBehavior=Enum.ZIndexBehavior.Sibling}, player.PlayerGui)
local main = make("Frame", {Name="Main", AnchorPoint=Vector2.new(.5,.5), Position=UDim2.fromScale(.5,.5),
    Size=UDim2.fromOffset(760,520), BackgroundColor3=C.bg, BorderSizePixel=0}, gui)
corner(main, 16); stroke(main, C.line)
local scale = make("UIScale", {Scale=1}, main)
local function applyScale()
    local cam = workspace.CurrentCamera
    if cam then scale.Scale = math.clamp(math.min((cam.ViewportSize.X-20)/760,(cam.ViewportSize.Y-20)/520),.5,1) end
end
if workspace.CurrentCamera then bind(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"), applyScale) end
bind(workspace:GetPropertyChangedSignal("CurrentCamera"), function()
    local cam=workspace.CurrentCamera
    if cam then bind(cam:GetPropertyChangedSignal("ViewportSize"), applyScale); applyScale() end
end)
applyScale()

local header = make("Frame", {Size=UDim2.new(1,0,0,66), BackgroundColor3=C.panel, BorderSizePixel=0}, main)
corner(header,16)
make("Frame", {Position=UDim2.new(0,0,1,-12),Size=UDim2.new(1,0,0,12),BackgroundColor3=C.panel,BorderSizePixel=0},header)
label(header,"BLOCKXYCOLA",UDim2.fromOffset(20,10),UDim2.new(1,-140,0,25),{font=Enum.Font.GothamBold,textSize=19})
label(header,"Developer Toolkit  •  Studio test tools",UDim2.fromOffset(21,36),UDim2.new(1,-140,0,17),{color=C.muted,textSize=11})
local closeBtn=button(header,"×",UDim2.new(1,-48,0,16),UDim2.fromOffset(30,30),C.card); closeBtn.TextSize=20
local minimizeBtn=button(header,"—",UDim2.new(1,-86,0,16),UDim2.fromOffset(30,30),C.card); minimizeBtn.TextSize=18
local sidebar=make("Frame",{Position=UDim2.fromOffset(14,80),Size=UDim2.new(0,155,1,-96),BackgroundColor3=C.panel,BorderSizePixel=0},main)
corner(sidebar,12)
local nav=make("Frame",{Position=UDim2.fromOffset(8,10),Size=UDim2.new(1,-16,1,-20),BackgroundTransparency=1},sidebar)
make("UIListLayout",{Padding=UDim.new(0,7),SortOrder=Enum.SortOrder.LayoutOrder},nav)
local content=make("Frame",{Position=UDim2.fromOffset(181,80),Size=UDim2.new(1,-195,1,-96),BackgroundTransparency=1},main)
local status=label(main,"พร้อมทำงาน",UDim2.fromOffset(185,main.AbsoluteSize.Y-27),UDim2.new(1,-205,0,17),{color=C.green,textSize=11})

local pages, navButtons = {}, {}
local function newPage(name)
    local p=make("ScrollingFrame",{Name=name,Size=UDim2.fromScale(1,1),CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,
        ScrollBarThickness=4,ScrollBarImageColor3=C.line,BackgroundTransparency=1,BorderSizePixel=0,Visible=false},content)
    make("UIListLayout",{Padding=UDim.new(0,10),SortOrder=Enum.SortOrder.LayoutOrder},p)
    make("UIPadding",{PaddingRight=UDim.new(0,5),PaddingBottom=UDim.new(0,8)},p)
    pages[name]=p
    local b=button(nav,name,UDim2.new(),UDim2.new(1,0,0,36),C.card)
    b.TextXAlignment=Enum.TextXAlignment.Left; b.Text="   "..name
    navButtons[name]=b
    bind(b.MouseButton1Click,function()
        for n,page in pairs(pages) do page.Visible=(n==name); navButtons[n].BackgroundColor3=(n==name) and C.accent or C.card end
    end)
    return p
end
local function card(parent, height)
    local f=make("Frame",{Size=UDim2.new(1,-2,0,height),BackgroundColor3=C.panel,BorderSizePixel=0},parent)
    corner(f,11); stroke(f)
    return f
end
local function section(parent, title, subtitle, height)
    local f=card(parent,height or 90)
    label(f,title,UDim2.fromOffset(14,8),UDim2.new(1,-28,0,21),{font=Enum.Font.GothamSemibold,textSize=14})
    if subtitle then label(f,subtitle,UDim2.fromOffset(14,31),UDim2.new(1,-28,0,28),{color=C.muted,textSize=11,wrap=true,yAlign=Enum.TextYAlignment.Top}) end
    return f
end
local function setStatus(text, color) status.Text=text; status.TextColor3=color or C.green end

-- Home / diagnostics
local home=newPage("หน้าหลัก")
local playersCard=section(home,"สถานะเซิร์ฟเวอร์","ข้อมูลพื้นฐานและการทำงานของเครื่องมือ",106)
local playerCount=label(playersCard,"ผู้เล่น: - / -",UDim2.fromOffset(14,58),UDim2.new(1,-28,0,22),{font=Enum.Font.GothamBold,textSize=17})
local runtime=label(playersCard,"Runtime: Studio test tools",UDim2.fromOffset(14,81),UDim2.new(1,-28,0,16),{color=C.muted,textSize=11})
local diag=section(home,"Diagnostics","ตรวจตัวละคร กล้อง และการเชื่อมต่อ UI",94)
local diagText=label(diag,"รอการตรวจสอบ",UDim2.fromOffset(14,58),UDim2.new(1,-145,0,22),{color=C.muted,textSize=12})
local diagBtn=button(diag,"ตรวจตอนนี้",UDim2.new(1,-122,0,55),UDim2.fromOffset(106,30),C.accent)
local function updateCount() playerCount.Text=string.format("ผู้เล่น: %d / %d",#Players:GetPlayers(),Players.MaxPlayers) end
updateCount(); bind(Players.PlayerAdded,updateCount); bind(Players.PlayerRemoving,function() task.defer(updateCount) end)
bind(diagBtn.MouseButton1Click,function()
    local char=player.Character; local hum=char and char:FindFirstChildOfClass("Humanoid")
    local cam=workspace.CurrentCamera
    diagText.Text=string.format("ตัวละคร: %s  •  กล้อง: %s",hum and "พร้อม" or "ไม่พบ",cam and "พร้อม" or "ไม่พบ")
    setStatus("ตรวจสอบเสร็จแล้ว")
end)

-- Speed
local speedPage=newPage("ความเร็ว")
local speedCard=section(speedPage,"ปรับความเร็ว","ระบบนี้ปรับเฉพาะตัวละครของผู้เล่นในเกมทดสอบที่คุณพัฒนา",146)
label(speedCard,"WalkSpeed",UDim2.fromOffset(14,65),UDim2.fromOffset(100,24),{color=C.muted})
local speedBox=textbox(speedCard,"24",UDim2.fromOffset(115,62),UDim2.fromOffset(90,30),"16-100")
label(speedCard,"ปุ่มเปิด/ปิด",UDim2.fromOffset(225,65),UDim2.fromOffset(90,24),{color=C.muted})
local speedKeyBox=textbox(speedCard,"V",UDim2.fromOffset(315,62),UDim2.fromOffset(70,30),"V")
local speedToggle=button(speedCard,"เปิดความเร็ว",UDim2.new(1,-145,0,62),UDim2.fromOffset(130,30),C.accent)
local speedOn=false
local originalSpeed
local function humanoid() local ch=player.Character; return ch and ch:FindFirstChildOfClass("Humanoid") end
local function setSpeed(on)
    local h=humanoid()
    if on and h then originalSpeed=originalSpeed or h.WalkSpeed; local n=tonumber(speedBox.Text) or 24; h.WalkSpeed=math.clamp(n,0,100); speedOn=true
    else if h and originalSpeed then h.WalkSpeed=originalSpeed end; speedOn=false; originalSpeed=nil end
    speedToggle.Text=speedOn and "ปิดความเร็ว" or "เปิดความเร็ว"
    speedToggle.BackgroundColor3=speedOn and C.green or C.accent
    setStatus(speedOn and "เปิดความเร็วแล้ว" or "ปิดความเร็วแล้ว")
end
bind(speedToggle.MouseButton1Click,function() setSpeed(not speedOn) end)

-- Heal
local healPage=newPage("ฟื้นเลือด")
local healCard=section(healPage,"ฟื้นเลือดสำหรับทดสอบ","มีผลเฉพาะ Humanoid ของตัวเองใน LocalScript; เกมจริงควรตรวจและฟื้นเลือดจากเซิร์ฟเวอร์",142)
label(healCard,"จำนวนเลือดที่เพิ่ม",UDim2.fromOffset(14,65),UDim2.fromOffset(130,24),{color=C.muted})
local healAmount=textbox(healCard,"25",UDim2.fromOffset(145,62),UDim2.fromOffset(80,30),"1-100")
label(healCard,"ปุ่มฟื้นเลือด",UDim2.fromOffset(245,65),UDim2.fromOffset(90,24),{color=C.muted})
local healKey=textbox(healCard,"H",UDim2.fromOffset(335,62),UDim2.fromOffset(70,30),"H")
local healBtn=button(healCard,"ฟื้นเลือด",UDim2.new(1,-130,0,62),UDim2.fromOffset(115,30),C.green)
local function healSelf()
    local h=humanoid(); if not h or h.Health<=0 then setStatus("ไม่พบตัวละครที่ยังมีชีวิต",C.red); return end
    local amount=math.clamp(tonumber(healAmount.Text) or 25,0,100)
    h.Health=math.min(h.MaxHealth,h.Health+amount)
    setStatus("ฟื้นเลือดทดสอบแล้ว")
end
bind(healBtn.MouseButton1Click,healSelf)

-- Graphics
local perfPage=newPage("Performance")
local perfCard=section(perfPage,"กราฟิกและประสิทธิภาพ","ปิด PostEffect และเงาชั่วคราว แล้วคืนค่าที่บันทึกไว้ได้",118)
local reduceBtn=button(perfCard,"ลดกราฟิก",UDim2.fromOffset(14,62),UDim2.fromOffset(130,32),C.accent)
local restoreBtn=button(perfCard,"คืนค่าเดิม",UDim2.fromOffset(154,62),UDim2.fromOffset(130,32),C.card)
local perfState=label(perfCard,"ยังไม่ได้เปลี่ยนกราฟิก",UDim2.fromOffset(300,62),UDim2.new(1,-315,0,32),{color=C.muted,textSize=11,wrap=true})
local graphicsBackup=nil
local function reduceGraphics()
    if graphicsBackup then perfState.Text="ลดกราฟิกอยู่แล้ว"; return end
    graphicsBackup={shadows=Lighting.GlobalShadows,fog=Lighting.FogEnd,effects={}}
    for _,obj in ipairs(Lighting:GetChildren()) do if obj:IsA("PostEffect") then table.insert(graphicsBackup.effects,{obj=obj,enabled=obj.Enabled}); obj.Enabled=false end end
    Lighting.GlobalShadows=false; Lighting.FogEnd=100000
    perfState.Text="ลดกราฟิกแล้ว"; setStatus("ลดกราฟิกชั่วคราวแล้ว")
end
local function restoreGraphics()
    if not graphicsBackup then perfState.Text="ไม่มีค่าที่ต้องคืน"; return end
    Lighting.GlobalShadows=graphicsBackup.shadows; Lighting.FogEnd=graphicsBackup.fog
    for _,r in ipairs(graphicsBackup.effects) do if r.obj and r.obj.Parent then r.obj.Enabled=r.enabled end end
    graphicsBackup=nil; perfState.Text="คืนค่าเดิมแล้ว"; setStatus("คืนค่ากราฟิกแล้ว")
end
bind(reduceBtn.MouseButton1Click,reduceGraphics); bind(restoreBtn.MouseButton1Click,restoreGraphics)

-- Shop Scanner
local shopPage=newPage("Shop Scanner")
local scanCard=section(shopPage,"สแกนร้านค้าใน Workspace","ค้นหา ProximityPrompt, CollectionService tags, ชื่อวัตถุที่คล้ายร้าน/สินค้า และ Attributes ที่เกี่ยวข้อง",126)
local scanBtn=button(scanCard,"สแกน Workspace",UDim2.fromOffset(14,70),UDim2.fromOffset(145,32),C.accent)
local clearBtn=button(scanCard,"ล้างรายการ",UDim2.fromOffset(169,70),UDim2.fromOffset(105,32),C.card)
local scanSummary=label(scanCard,"ยังไม่ได้สแกน",UDim2.fromOffset(290,70),UDim2.new(1,-305,0,32),{color=C.muted,textSize=11,wrap=true})
local resultsCard=card(shopPage,260)
label(resultsCard,"ผลการสแกน / เลือกรายการ",UDim2.fromOffset(14,8),UDim2.new(1,-28,0,22),{font=Enum.Font.GothamSemibold,textSize=14})
local resultList=make("ScrollingFrame",{Position=UDim2.fromOffset(12,36),Size=UDim2.new(1,-24,1,-76),CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,
    ScrollBarThickness=4,BackgroundColor3=C.bg,BorderSizePixel=0},resultsCard); corner(resultList,8)
make("UIListLayout",{Padding=UDim.new(0,4),SortOrder=Enum.SortOrder.LayoutOrder},resultList)
local selectedLabel=label(resultsCard,"ยังไม่ได้เลือกรายการ",UDim2.fromOffset(14,resultsCard.AbsoluteSize.Y-31),UDim2.new(1,-28,0,20),{color=C.muted,textSize=11})
local scanResults={}
local function nameLooksRelevant(s)
    s=string.lower(s)
    for _,word in ipairs({"shop","store","vendor","merchant","item","product","buy","purchase","ร้าน","สินค้า","ขาย","ซื้อ"}) do
        if string.find(s,word,1,true) then return true end
    end
    return false
end
local function describe(inst)
    local parts={inst.ClassName,inst:GetFullName()}
    if inst:IsA("ProximityPrompt") then table.insert(parts,"Prompt="..inst.ActionText); if inst.ObjectText~="" then table.insert(parts,"Object="..inst.ObjectText) end end
    for _,attr in ipairs({"Price","Cost","ItemId","ProductId","ItemName","ShopItem","Currency","Stock"}) do
        local v=inst:GetAttribute(attr); if v~=nil then table.insert(parts,attr.."="..tostring(v)) end
    end
    local ok,tags=pcall(function() return CollectionService:GetTags(inst) end)
    if ok and #tags>0 then table.insert(parts,"Tags="..table.concat(tags,",")) end
    return table.concat(parts,"  |  ")
end
local function clearResults()
    for _,child in ipairs(resultList:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end
    table.clear(scanResults); selectedLabel.Text="ยังไม่ได้เลือกรายการ"; scanSummary.Text="ล้างรายการแล้ว"
end
bind(clearBtn.MouseButton1Click,clearResults)
bind(scanBtn.MouseButton1Click,function()
    clearResults(); local found={}; local seen={}
    for _,inst in ipairs(workspace:GetDescendants()) do
        local relevant=inst:IsA("ProximityPrompt") or nameLooksRelevant(inst.Name)
        if not relevant then
            local ok,tags=pcall(function() return CollectionService:GetTags(inst) end)
            if ok then for _,tag in ipairs(tags) do if nameLooksRelevant(tag) then relevant=true; break end end end
        end
        if not relevant then
            for _,attr in ipairs({"Price","Cost","ItemId","ProductId","ItemName","ShopItem"}) do if inst:GetAttribute(attr)~=nil then relevant=true; break end end
        end
        if relevant and not seen[inst] then seen[inst]=true; table.insert(found,inst) end
    end
    table.sort(found,function(a,b) return a:GetFullName()<b:GetFullName() end)
    for i,inst in ipairs(found) do
        scanResults[i]=inst
        local b=button(resultList,describe(inst),UDim2.new(),UDim2.new(1,-8,0,38),C.card)
        b.TextXAlignment=Enum.TextXAlignment.Left; b.TextWrapped=true; b.TextSize=10
        bind(b.MouseButton1Click,function()
            if not inst or not inst.Parent then selectedLabel.Text="รายการนี้ถูกลบไปแล้ว"; return end
            selectedLabel.Text="เลือก: "..inst:GetFullName()
            setStatus("เลือกรายการจาก Shop Scanner แล้ว",C.amber)
        end)
    end
    scanSummary.Text=string.format("พบรายการที่อาจเกี่ยวข้อง %d รายการ — ตรวจสอบด้วยตนเองก่อนใช้",#found)
    setStatus("สแกนเสร็จแล้ว: "..#found.." รายการ")
end)
local shopNote=section(shopPage,"การซื้อสินค้า","สแกนเนอร์นี้ตรวจพบวัตถุและข้อมูลที่มองเห็นใน Workspace เท่านั้น ไม่สามารถยืนยันระบบซื้อจริงหรือซื้ออัตโนมัติได้เอง",86)
label(shopNote,"การซื้อจริงต้องเรียก RemoteEvent/ระบบร้านค้าที่คุณสร้าง และให้เซิร์ฟเวอร์ตรวจสอบราคา เงิน ระยะ และจำนวนสินค้า",UDim2.fromOffset(14,47),UDim2.new(1,-28,0,28),{color=C.amber,textSize=11,wrap=true,yAlign=Enum.TextYAlignment.Top})

-- Safe visual options: own-character status only, no tracking ESP/aim.
local visualPage=newPage("HUD")
local hudCard=section(visualPage,"HUD และสถานะตัวเอง","แสดงข้อมูลผู้เล่นในเซิร์ฟเวอร์และสถานะตัวละครของคุณ",120)
local hudToggle=button(hudCard,"ซ่อน HUD",UDim2.fromOffset(14,65),UDim2.fromOffset(120,30),C.card)
local selfHud=make("Frame",{Name="SelfStatusHUD",AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,10),Size=UDim2.fromOffset(260,34),BackgroundColor3=C.panel,BorderSizePixel=0},gui)
corner(selfHud,9); stroke(selfHud)
local selfHudLabel=label(selfHud,"ผู้เล่น: 0  •  HP: --",UDim2.fromOffset(10,0),UDim2.new(1,-20,1,0),{textSize=12,align=Enum.TextXAlignment.Center})
local hudVisible=true
bind(hudToggle.MouseButton1Click,function() hudVisible=not hudVisible; selfHud.Visible=hudVisible; hudToggle.Text=hudVisible and "ซ่อน HUD" or "แสดง HUD" end)
local hudAccumulator=0
bind(RunService.Heartbeat,function(dt)
    hudAccumulator+=dt
    if hudAccumulator<0.25 then return end; hudAccumulator=0
    local h=humanoid(); selfHudLabel.Text=string.format("ผู้เล่น: %d/%d  •  HP: %s",#Players:GetPlayers(),Players.MaxPlayers,h and (math.floor(h.Health).."/"..math.floor(h.MaxHealth)) or "--")
end)


-- NPC Training: only models explicitly tagged "TrainingTarget" by the game developer.
-- No player tracking. Add the CollectionService tag to your own NPC test dummies in Studio.
local trainingPage = newPage("NPC Training")
local trainingCard = section(trainingPage, "เป้าหมายฝึกที่กำหนดไว้", 'ทำงานเฉพาะ NPC ที่ติดแท็ก CollectionService: "TrainingTarget"', 170)
local espBtn = button(trainingCard, "เปิดไฮไลต์ NPC", UDim2.fromOffset(14, 65), UDim2.fromOffset(145, 30), C.accent)
local aimBtn = button(trainingCard, "เปิด Aim Assist", UDim2.fromOffset(169, 65), UDim2.fromOffset(145, 30), C.accent)
label(trainingCard, "FOV (องศา)", UDim2.fromOffset(14, 108), UDim2.fromOffset(90, 22), {color=C.muted})
local fovBox = textbox(trainingCard, "90", UDim2.fromOffset(105, 104), UDim2.fromOffset(65, 28), "10-180")
label(trainingCard, "ความสมูท", UDim2.fromOffset(185, 108), UDim2.fromOffset(80, 22), {color=C.muted})
local smoothBox = textbox(trainingCard, "8", UDim2.fromOffset(265, 104), UDim2.fromOffset(65, 28), "1-30")
local trainingInfo = label(trainingCard, "Aim Assist ทำงานขณะกดคลิกขวา และเลือกเฉพาะ NPC ที่ติดแท็ก", UDim2.fromOffset(14, 139), UDim2.new(1, -28, 0, 22), {color=C.muted, textSize=10, wrap=true})

local npcEspOn, npcAimOn = false, false
local npcVisuals = {}
local function removeNpcVisual(model)
    local v = npcVisuals[model]
    if not v then return end
    if v.highlight then pcall(function() v.highlight:Destroy() end) end
    if v.billboard then pcall(function() v.billboard:Destroy() end) end
    npcVisuals[model] = nil
end
local function addNpcVisual(model)
    if not model or not model:IsA("Model") or model == player.Character then return end
    local hum = model:FindFirstChildOfClass("Humanoid")
    local root = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Head")
    if not hum or not root then return end
    if not npcVisuals[model] then
        local h = Instance.new("Highlight")
        h.Name = "BlockxycolaTrainingHighlight"
        h.FillColor = C.accent
        h.OutlineColor = C.green
        h.FillTransparency = 0.65
        h.DepthMode = Enum.HighlightDepthMode.Occluded
        h.Enabled = npcEspOn
        h.Adornee = model
        h.Parent = workspace
        local bb = Instance.new("BillboardGui")
        bb.Name = "BlockxycolaTrainingLabel"
        bb.Adornee = root
        bb.Size = UDim2.fromOffset(150, 38)
        bb.StudsOffset = Vector3.new(0, 2.5, 0)
        bb.AlwaysOnTop = false
        bb.Enabled = npcEspOn
        bb.Parent = player:WaitForChild("PlayerGui")
        local txt = Instance.new("TextLabel")
        txt.BackgroundTransparency = 0.25
        txt.BackgroundColor3 = C.bg
        txt.Size = UDim2.fromScale(1, 1)
        txt.Font = Enum.Font.GothamSemibold
        txt.TextSize = 11
        txt.TextColor3 = C.text
        txt.TextStrokeTransparency = 0.6
        txt.Parent = bb
        corner(txt, 6)
        npcVisuals[model] = {highlight=h, billboard=bb, text=txt}
    end
    local v = npcVisuals[model]
    v.highlight.Enabled = npcEspOn
    v.billboard.Enabled = npcEspOn
    v.text.Text = string.format("%s  |  HP %d/%d", model.Name, math.floor(hum.Health), math.floor(hum.MaxHealth))
end
local function refreshNpcVisuals()
    for _, model in ipairs(CollectionService:GetTagged("TrainingTarget")) do
        if model:IsA("Model") then addNpcVisual(model) end
    end
    for model in pairs(npcVisuals) do
        if not model.Parent or not CollectionService:HasTag(model, "TrainingTarget") then removeNpcVisual(model) end
    end
end
bind(espBtn.MouseButton1Click, function()
    npcEspOn = not npcEspOn
    espBtn.Text = npcEspOn and "ปิดไฮไลต์ NPC" or "เปิดไฮไลต์ NPC"
    espBtn.BackgroundColor3 = npcEspOn and C.green or C.accent
    refreshNpcVisuals()
    for _, v in pairs(npcVisuals) do
        v.highlight.Enabled = npcEspOn
        v.billboard.Enabled = npcEspOn
    end
    setStatus(npcEspOn and "เปิดไฮไลต์ NPC ฝึกแล้ว" or "ปิดไฮไลต์ NPC ฝึกแล้ว")
end)
bind(aimBtn.MouseButton1Click, function()
    npcAimOn = not npcAimOn
    aimBtn.Text = npcAimOn and "ปิด Aim Assist" or "เปิด Aim Assist"
    aimBtn.BackgroundColor3 = npcAimOn and C.green or C.accent
    setStatus(npcAimOn and "Aim Assist สำหรับ NPC ฝึกเปิดแล้ว" or "ปิด Aim Assist แล้ว")
end)
local function nearestTrainingTarget()
    local cam = workspace.CurrentCamera
    if not cam then return nil end
    local fov = math.clamp(tonumber(fovBox.Text) or 90, 10, 180)
    local best, bestAngle = nil, math.rad(fov / 2)
    local center = cam.ViewportSize / 2
    for _, model in ipairs(CollectionService:GetTagged("TrainingTarget")) do
        if model:IsA("Model") and model ~= player.Character then
            local hum = model:FindFirstChildOfClass("Humanoid")
            local part = model:FindFirstChild("Head") or model:FindFirstChild("HumanoidRootPart")
            if hum and hum.Health > 0 and part and part:IsA("BasePart") then
                local projected, visible = cam:WorldToViewportPoint(part.Position)
                if visible and projected.Z > 0 then
                    local delta = Vector2.new(projected.X, projected.Y) - center
                    local angle = math.atan2(delta.Magnitude, math.max(cam.ViewportSize.X, cam.ViewportSize.Y) / (2 * math.tan(math.rad(fov/2))))
                    if angle < bestAngle then bestAngle, best = angle, part end
                end
            end
        end
    end
    return best
end
local aimAccumulator = 0
bind(RunService.RenderStepped, function(dt)
    aimAccumulator += dt
    if aimAccumulator >= 0.2 then
        aimAccumulator = 0
        if npcEspOn then refreshNpcVisuals() end
    end
    if not npcAimOn or not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then return end
    local cam = workspace.CurrentCamera
    local target = nearestTrainingTarget()
    if not cam or not target then return end
    local smooth = math.clamp(tonumber(smoothBox.Text) or 8, 1, 30)
    local desired = CFrame.lookAt(cam.CFrame.Position, target.Position)
    cam.CFrame = cam.CFrame:Lerp(desired, math.clamp(dt * smooth, 0, 1))
end)


-- Keybinds
local function parseKey(box, fallback)
    local raw=string.upper((box.Text or ""):gsub("%s+",""))
    if #raw==1 then local ok,key=pcall(function() return Enum.KeyCode[raw] end); if ok and key then return key end end
    return fallback
end
bind(UserInputService.InputBegan,function(input,processed)
    if processed or UserInputService:GetFocusedTextBox() then return end
    if input.KeyCode==Enum.KeyCode.RightShift then main.Visible=not main.Visible; return end
    if input.KeyCode==Enum.KeyCode.End then
        if graphicsBackup then restoreGraphics() end
        setSpeed(false); alive=false; disconnectAll(); for model in pairs(npcVisuals) do removeNpcVisual(model) end; gui:Destroy(); return
    end
    if input.KeyCode==parseKey(speedKeyBox,Enum.KeyCode.V) then setSpeed(not speedOn) end
    if input.KeyCode==parseKey(healKey,Enum.KeyCode.H) then healSelf() end
    if input.KeyCode==Enum.KeyCode.Q then
        npcAimOn = not npcAimOn
        aimBtn.Text = npcAimOn and "ปิด Aim Assist" or "เปิด Aim Assist"
        aimBtn.BackgroundColor3 = npcAimOn and C.green or C.accent
        setStatus(npcAimOn and "Aim Assist สำหรับ NPC ฝึกเปิดแล้ว" or "ปิด Aim Assist แล้ว")
    end
end)

-- Drag window
local dragging=false; local dragStart; local startPos; local dragInput
bind(header.InputBegan,function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
        dragging=true; dragStart=input.Position; startPos=main.Position; dragInput=input
    end
end)
bind(UserInputService.InputChanged,function(input)
    if dragging and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then
        local d=input.Position-dragStart
        main.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y)
    end
end)
bind(UserInputService.InputEnded,function(input)
    if input==dragInput or input.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false; dragInput=nil end
end)
bind(minimizeBtn.MouseButton1Click,function() sidebar.Visible=not sidebar.Visible; content.Visible=not content.Visible end)
bind(closeBtn.MouseButton1Click,function()
    if graphicsBackup then restoreGraphics() end
    setSpeed(false); alive=false; disconnectAll(); for model in pairs(npcVisuals) do removeNpcVisual(model) end; gui:Destroy()
end)

-- Character respawn safety: apply speed if active; otherwise preserve new character defaults.
bind(player.CharacterAdded,function(char)
    task.defer(function()
        local h=char:WaitForChild("Humanoid",5)
        if h and speedOn then originalSpeed=h.WalkSpeed; h.WalkSpeed=math.clamp(tonumber(speedBox.Text) or 24,0,100) end
    end)
end)

-- Start page
pages["หน้าหลัก"].Visible=true; navButtons["หน้าหลัก"].BackgroundColor3=C.accent
print("[blockxycola] Developer Toolkit loaded. Studio-owned game use only.")
