
-- ============================================
-- プレイヤー位置表示 + 赤ハイライト（修正版）
-- エラーハンドリング強化 + 読み込み確認付き
-- ============================================

print("🔵 スクリプト開始")

-- ゲームが読み込まれるのを待つ
repeat task.wait() until game:IsLoaded()
print("✅ ゲーム読み込み完了")

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- プレイヤーがいるか確認
repeat task.wait() until LocalPlayer
print("✅ プレイヤー確認完了: " .. LocalPlayer.Name)

-- ============================================
-- OrionLib読み込み（確認付き）
-- ============================================
print("🔄 OrionLib読み込み中...")

local OrionLib = nil
local function LoadOrionLib()
    local success, result = pcall(function()
        return loadstring(game:HttpGet("https://raw.githubusercontent.com/jadpy/suki/refs/heads/main/orion"))()
    end)
    if success and result then
        print("✅ OrionLib読み込み成功")
        OrionLib = result
        return true
    else
        print("❌ OrionLib読み込み失敗: " .. tostring(result))
        return false
    end
end

-- 最大5回リトライ
local loaded = false
for i = 1, 5 do
    print("🔄 リトライ " .. i .. "/5")
    if LoadOrionLib() then
        loaded = true
        break
    end
    task.wait(1)
end

if not loaded then
    warn("❌ OrionLib読み込み失敗 - スクリプトを終了します")
    return
end

if not OrionLib then
    warn("❌ OrionLibがnilです")
    return
end

-- ============================================
-- 設定
-- ============================================
local Config = {
    UpdateSpeed = 1.0,
    ShowDistance = true,
    ShowCoordinates = true,
    TargetPlayer = nil,
}

local isRunning = false
local updateConnection = nil
local highlightConnections = {}
local statusLabel = nil
local targetLabel = nil
local lastUpdateTime = 0

-- ============================================
-- プレイヤーの位置情報を取得
-- ============================================
local function GetPlayerPosition(player)
    if not player then return nil end
    local char = player.Character
    if not char then return nil end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    return root.Position
end

local function GetPlayerDistance(player)
    local myPos = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not myPos then return nil end
    local targetPos = GetPlayerPosition(player)
    if not targetPos then return nil end
    return (targetPos - myPos.Position).Magnitude
end

-- ============================================
-- プレイヤーを赤くハイライト
-- ============================================
local function HighlightPlayer(player, enable)
    if not player or not player.Character then return end
    
    if enable then
        local highlight = player.Character:FindFirstChild("Highlight")
        if not highlight then
            highlight = Instance.new("Highlight")
            highlight.Name = "Highlight"
            highlight.FillColor = Color3.fromRGB(255, 0, 0)
            highlight.FillTransparency = 0.3
            highlight.OutlineColor = Color3.fromRGB(255, 0, 0)
            highlight.OutlineTransparency = 0
            highlight.Parent = player.Character
        end
        highlight.Enabled = true
        highlightConnections[player] = highlight
    else
        local highlight = player.Character:FindFirstChild("Highlight")
        if highlight then
            highlight.Enabled = false
        end
        highlightConnections[player] = nil
    end
end

-- ============================================
-- 全プレイヤーのハイライトを更新
-- ============================================
local function UpdateHighlights()
    for player, highlight in pairs(highlightConnections) do
        if highlight then
            highlight.Enabled = false
        end
    end
    highlightConnections = {}
    
    if not isRunning then return end
    
    if Config.TargetPlayer then
        HighlightPlayer(Config.TargetPlayer, true)
    else
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                HighlightPlayer(player, true)
            end
        end
    end
end

-- ============================================
-- 表示用テキストを生成
-- ============================================
local function GeneratePlayerInfo(player)
    local pos = GetPlayerPosition(player)
    if not pos then return player.Name .. " : オフライン" end
    
    local parts = {player.Name}
    if Config.ShowCoordinates then
        table.insert(parts, string.format(" [%.0f, %.0f, %.0f]", pos.X, pos.Y, pos.Z))
    end
    if Config.ShowDistance then
        local dist = GetPlayerDistance(player)
        if dist then
            table.insert(parts, string.format(" (%.0f studs)", dist))
        end
    end
    return table.concat(parts)
end

-- ============================================
-- UIを更新
-- ============================================
local function UpdatePlayerDisplay()
    if not isRunning then return end
    
    local now = tick()
    if now - lastUpdateTime < Config.UpdateSpeed then
        return
    end
    lastUpdateTime = now
    
    pcall(function()
        local players = {}
        if Config.TargetPlayer then
            table.insert(players, Config.TargetPlayer)
        else
            for _, player in pairs(Players:GetPlayers()) do
                if player ~= LocalPlayer then
                    table.insert(players, player)
                end
            end
        end
        
        table.sort(players, function(a, b)
            local distA = GetPlayerDistance(a) or math.huge
            local distB = GetPlayerDistance(b) or math.huge
            return distA < distB
        end)
        
        local labelParts = {"📡 プレイヤー位置情報", string.rep("-", 30)}
        local count = 0
        for _, player in ipairs(players) do
            if count >= 10 then break end
            table.insert(labelParts, GeneratePlayerInfo(player))
            count = count + 1
        end
        
        if count == 0 then
            table.insert(labelParts, "表示できるプレイヤーがいません")
        end
        
        local labelText = table.concat(labelParts, "\n")
        if statusLabel then
            statusLabel:Set(labelText)
        end
        
        if targetLabel then
            if Config.TargetPlayer then
                targetLabel:Set("🎯 ターゲット", Config.TargetPlayer.Name .. " (赤くハイライト中)")
            else
                targetLabel:Set("🎯 ターゲット", "全プレイヤー (" .. count .. "人)")
            end
        end
        
        task.spawn(UpdateHighlights)
    end)
end

-- ============================================
-- 更新ループ
-- ============================================
local function UpdateLoop()
    while isRunning do
        UpdatePlayerDisplay()
        task.wait(Config.UpdateSpeed)
    end
end

-- ============================================
-- 開始/停止関数
-- ============================================
local function StartTracking()
    if updateConnection then return end
    isRunning = true
    lastUpdateTime = 0
    updateConnection = RunService.Heartbeat:Connect(UpdateLoop)
    UpdatePlayerDisplay()
    print("🟢 位置追跡 + ハイライト開始（軽量モード）")
end

local function StopTracking()
    isRunning = false
    if updateConnection then
        updateConnection:Disconnect()
        updateConnection = nil
    end
    for player, highlight in pairs(highlightConnections) do
        if highlight then
            highlight.Enabled = false
        end
    end
    highlightConnections = {}
    if statusLabel then
        statusLabel:Set("🔴 停止中\n\nトグルをONにすると開始します")
    end
    if targetLabel then
        targetLabel:Set("🎯 ターゲット", "なし")
    end
    print("🔴 位置追跡 + ハイライト停止")
end

-- ============================================
-- プレイヤーリスト取得
-- ============================================
local function GetPlayerList()
    local list = {"全プレイヤー"}
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            table.insert(list, player.Name)
        end
    end
    return list
end

-- ============================================
-- UI作成（OrionLib）
-- ============================================
print("🔄 UI作成開始...")

local Window = OrionLib:MakeWindow({
    Name = "プレイヤー位置表示 + ハイライト",
    HidePremium = false,
    SaveConfig = true,
    ConfigFolder = "player_tracker_light",
})

local MainTab = Window:MakeTab({
    Name = "メイン",
    Icon = "rbxassetid://4483345998"
})

-- ステータス表示
MainTab:AddSection({ Name = "ステータス" })
statusLabel = MainTab:AddParagraph("📡 状態", "🔴 停止中")
targetLabel = MainTab:AddParagraph("🎯 ターゲット", "なし")

-- メインコントロール（トグル）
MainTab:AddSection({ Name = "コントロール" })

MainTab:AddToggle({
    Name = "🟢 位置追跡 + ハイライト（軽量モード）",
    Default = false,
    Callback = function(v)
        print("🔄 トグル変更: " .. tostring(v))
        if v then
            StartTracking()
        else
            StopTracking()
        end
    end
})

-- 表示設定
MainTab:AddSection({ Name = "表示設定" })

MainTab:AddToggle({
    Name = "距離を表示",
    Default = true,
    Callback = function(v)
        Config.ShowDistance = v
        if isRunning then 
            lastUpdateTime = 0
            UpdatePlayerDisplay() 
        end
    end
})

MainTab:AddToggle({
    Name = "座標を表示",
    Default = true,
    Callback = function(v)
        Config.ShowCoordinates = v
        if isRunning then 
            lastUpdateTime = 0
            UpdatePlayerDisplay() 
        end
    end
})

-- ターゲット設定
MainTab:AddSection({ Name = "ターゲット設定" })

local TargetDropdown = MainTab:AddDropdown({
    Name = "表示するプレイヤー（赤くハイライト）",
    Default = "全プレイヤー",
    Options = GetPlayerList(),
    Callback = function(v)
        if v and v ~= "全プレイヤー" then
            Config.TargetPlayer = Players:FindFirstChild(v)
        else
            Config.TargetPlayer = nil
        end
        if isRunning then 
            lastUpdateTime = 0
            UpdatePlayerDisplay() 
        end
    end
})

MainTab:AddButton({
    Name = "🔄 プレイヤーリスト更新",
    Callback = function()
        TargetDropdown:Refresh(GetPlayerList(), true)
    end
})

-- 更新速度
MainTab:AddSection({ Name = "更新速度（負荷調整）" })

MainTab:AddSlider({
    Name = "更新間隔（秒）",
    Min = 0.5,
    Max = 5.0,
    Default = 1.0,
    Increment = 0.5,
    ValueName = "秒",
    Callback = function(v)
        Config.UpdateSpeed = v
        if isRunning then
            lastUpdateTime = 0
        end
    end
})

-- その他
MainTab:AddSection({ Name = "その他" })

MainTab:AddButton({
    Name = "UIを閉じる",
    Callback = function()
        StopTracking()
        OrionLib:Destroy()
    end
})

-- ============================================
-- クリーンアップ
-- ============================================
OrionLib:Init()

print("✅ プレイヤー位置表示 + ハイライト（軽量版）起動！")
print("   トグルでON/OFF切り替え")
print("   更新間隔: " .. Config.UpdateSpeed .. "秒")
