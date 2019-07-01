local gui = {}
local db = {}

local Reminders = RemindersLite

Reminders.gui = gui

local function spairs(t, order)
    local keys = {}
    for k in pairs(t) do keys[#keys+1] = k end

    if order then
        table.sort(keys, function(a,b) return order(t, a, b) end)
    else
        table.sort(keys)
    end

    local i = 0
    return function()
        i = i + 1
        if keys[i] then
            return keys[i], t[keys[i]]
        end
    end
end

-- this will be called when Reminders request gui
function gui:InitializeGUI(RemindersInstance)
    db = RemindersInstance.db
    self:CreateNotificationFrame()
end

function gui:ReleaseFontstring(fontstring)
    fontstring:Hide()
    local delete = nil
    for i = 1, #self.active_fontstrings do
        if self.active_fontstrings[i] == fontstring then
            delete = i
        end
    end
    if not delete then 
        print("ERROR, DELETE NONACTIVE FONTSTRING")
    end
    table.remove(self.active_fontstrings, delete)
    self.frame.free_fontstrings[#self.frame.free_fontstrings + 1] = fontstring
    self.next_y = self.next_y + self.y_string_offset
end

function gui:GetFontstring()

    local store = self.frame.free_fontstrings or {} 
    if not self.frame.free_fontstrings then
        self.frame.free_fontstrings = store
    end

    local fontstring = nil
    if #store == 0 then
        fontstring = self.frame:CreateFontString();
        fontstring:SetSize(self.x_size, self.y_string_offset)
        fontstring:SetFont("Fonts\\FRIZQT__.TTF", 40, "THICKOUTLINE");
        fontstring:ClearAllPoints();
        fontstring:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, 0);
        fontstring:SetJustifyH("CENTER")
    else
        fontstring = store[1];
        table.remove(store, 1)
    end

    return fontstring

end

function gui:PositionFontstring(fontstring)
    local next_y = self.next_y
    fontstring:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, next_y)
    self.next_y = next_y - self.y_string_offset;
end

function gui:ArrangeActiveFontstrings()
    self.next_y = 0
    for k, v in spairs(self.active_fontstrings, function(t,a,b) return t[a].registered < t[b].registered end) do
        self:PositionFontstring(v)
    end
end

function gui:AddMessage(msg, duration)
    duration = duration or 2
    local fontstring = self:GetFontstring()
    fontstring:SetText(msg)
    self.active_fontstrings = self.active_fontstrings or {}
    self.active_fontstrings[#self.active_fontstrings + 1] = fontstring
    self:PositionFontstring(fontstring);
    fontstring.registered = GetTime()
    fontstring:Show()
    -- add callbacks
    C_Timer.After(duration, function() gui:ReleaseFontstring(fontstring) end)
    C_Timer.After(duration + 0.1, function() gui:ArrangeActiveFontstrings() end)
end

function gui:CreateNotificationFrame()
    local db = RemindersLiteDB

    gui.x_size = 600
    gui.y_size = 150
    gui.y_string_offset = 30
    gui.y_offset = db.gui_y or -30
    gui.x_offset = db.gui_x or 0
    gui.point = db.gui_point or "CENTER"
    gui.relative_point = db.gui_relative_point or "CENTER"

    gui.frame = CreateFrame("frame", "RemindersGUIFrame", UIParent)
    gui.frame:SetSize(gui.x_size, gui.y_size)
    gui.frame:SetPoint(gui.point, UIParent, db.gui_relative_point, gui.x_offset, gui.y_offset)

    gui.frame:Show()

    gui.next_y = 0

    -- test
end

function gui:SaveCurrentPoint()
    local point, _, relative_point, x, y = gui.frame:GetPoint()
    local db = RemindersLiteDB
    db.gui_point = point
    db.gui_relative_point = relative_point
    db.gui_y = y
    db.gui_x = x
end

function gui:UnlockMove()
    local frame = gui.frame
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and not self.isMoving then
            self:StartMoving();
            self.isMoving = true;
        end
        end)
        frame:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and self.isMoving then
            self:StopMovingOrSizing();
            self.isMoving = false;
            gui:SaveCurrentPoint()
        end
        end)
        frame:SetScript("OnHide", function(self)
        if ( self.isMoving ) then
            self:StopMovingOrSizing();
            self.isMoving = false;
            gui:SaveCurrentPoint()
        end
    end)
    local tex = frame.moveTex or frame:CreateTexture("ARTWORK");
    frame.moveTex = tex
    tex:SetAllPoints();
    tex:SetTexture(1.0, 0.5, 0); tex:SetAlpha(0.5);
    tex:Show()
    frame:Show()
end

function gui:LockMove()
    local frame = gui.frame
    if frame.moveTex then
        frame.moveTex:Hide()
    end
    frame:SetMovable(false)
    frame:EnableMouse(false)
    gui:SaveCurrentPoint()
end

function gui:ShowReminder(reminder)

    local SML = SML or LibStub:GetLibrary("LibSharedMedia-3.0")
    -- sound is the index into the table, sadly, so make sure to convert it when sending
    self:AddMessage(reminder.notification.message, reminder.notification.duration)

    if reminder.notification.sound then
        local sound_name = reminder.notification.sound
        Reminders:PlaySound(sound_name)
    end

end
