--------------------------------------------------------------------------------
--  DannerEllesmereRested
--
--  EllesmereUI's WoW Forever unit frame style draws the player level in a
--  round badge at the frame's bottom-left corner. While the player is resting
--  this shows a gold "zzz" in that badge instead, in the level's own font.
--
--  EllesmereUI keeps the level pieces on the player frame
--  (EllesmereUIUnitFrames_Player): _blizzLevel (the number), _blizzLevelSkull
--  and _blizzLevelBadge (the circle, WoW Forever style only). These are EUI
--  internals, so everything here is defensive: when they are missing (another
--  style, or a future EUI change) the addon does nothing.
--
--  EUI shows and hides the number itself on every refresh, so it is faded with
--  alpha rather than hidden; EUI's own show/hide logic is never touched. The
--  text follows the badge's visibility, so "Show Level" off hides it too.
--------------------------------------------------------------------------------

local PLAYER_FRAME = "EllesmereUIUnitFrames_Player"
local REST_TEXT = "zzz"
local REST_COLOR = { 1, 0.82, 0 }   -- the stock gold level colour
local FIT = 0.6             -- widest the text may be, as a share of the badge
local SIZE_DELTA = -2       -- pt off the level number's font size
local Y_OFFSET = 1          -- px up from the badge centre (lowercase "zzz"
                            -- has no ascenders, so it sits low in its box)
local FIND_TRIES = 30       -- one per second after login

local frame, fs, skull, badge, text

-- The level's own face, size and outline, shrunk only if "zzz" would not fit
-- inside the badge's ring. Re-read every update: EUI re-fonts the level on
-- each layout pass.
local function FitText()
    local face, size, flags = fs:GetFont()
    if not face then
        face, size, flags = GameNormalNumberFont:GetFont()
    end
    local fo = fs:GetFontObject()
    if fo then text:SetFontObject(fo) end
    size = math.max(6, size + SIZE_DELTA)
    text:SetFont(face, size, flags)
    text:SetText(REST_TEXT)
    local maxW = badge:GetWidth() * FIT
    local w = text:GetStringWidth()
    if w > maxW and w > 0 then
        text:SetFont(face, math.max(6, math.floor(size * maxW / w)), flags)
    end
    text:SetTextColor(REST_COLOR[1], REST_COLOR[2], REST_COLOR[3])
end

local function Update()
    if not text then return end
    local resting = IsResting() and badge:IsShown()
    if resting then FitText() end
    text:SetShown(resting)
    local a = resting and 0 or 1
    fs:SetAlpha(a)
    if skull then skull:SetAlpha(a) end
end

-- Attach once EUI has built the level badge. Returns true when done (attached,
-- or the frame exists but is not the WoW Forever style).
local function TryAttach()
    if text then return true end
    frame = _G[PLAYER_FRAME]
    if not frame then return false end
    fs, skull, badge = frame._blizzLevel, frame._blizzLevelSkull, frame._blizzLevelBadge
    if not (fs and badge) then
        -- Built without a level, or not the WoW Forever style (no badge).
        return fs ~= nil
    end
    -- On the badge's host, centred where the level number sits.
    local host = badge:GetParent()
    -- A font before any text (SetText errors on a FontString without one);
    -- FitText swaps in the level's own font.
    text = host:CreateFontString(nil, "OVERLAY", "GameNormalNumberFont")
    text:SetDrawLayer("OVERLAY", 1)
    text:SetText(REST_TEXT)
    text:SetJustifyH("CENTER")
    text:SetPoint("CENTER", badge, "CENTER", 0, Y_OFFSET)
    text:Hide()
    hooksecurefunc(badge, "Show", Update)
    hooksecurefunc(badge, "Hide", Update)
    hooksecurefunc(badge, "SetShown", Update)
    hooksecurefunc(badge, "SetSize", Update)
    Update()
    return true
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_UPDATE_RESTING")
ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        -- EUI builds its frames around login; keep looking for a while.
        if TryAttach() then return end
        local tries = 0
        local ticker
        ticker = C_Timer.NewTicker(1, function()
            tries = tries + 1
            if TryAttach() or tries >= FIND_TRIES then ticker:Cancel() end
        end)
        return
    end
    Update()
end)
