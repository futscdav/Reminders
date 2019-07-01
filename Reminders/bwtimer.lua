local timer = LibStub("AceAddon-3.0"):NewAddon("DummyBwTimerAddon", "AceTimer-3.0")

do
  local registeredBigWigsEvents = {}
  local bars = {};
  local nextExpire; -- time of next expiring timer
  local recheckTimer; -- handle of timer

  -- triggers when a timer expires and sets the new one
  local function recheckTimers()
    local now = GetTime();
    nextExpire = nil;
    for id, bar in pairs(bars) do
      if (bar.expirationTime < now) then
        bars[id] = nil;
        Reminders:BWTimerStop(bar);
      elseif (nextExpire == nil) then
        nextExpire = bar.expirationTime;
      elseif (bar.expirationTime < nextExpire) then
        nextExpire = bar.expirationTime;
      end
    end

    if (nextExpire) then
      recheckTimer = timer:ScheduleTimer(recheckTimers, nextExpire - now);
    end
  end

  local function bigWigsEventCallback(event, ...)
    if (event == "BigWigs_Message") then
      -- WeakAuras.ScanEvents("BigWigs_Message", ...);
      -- not exactly useful for now
    elseif (event == "BigWigs_StartBar") then
      local addon, spellId, text, duration, icon = ...
      local now = GetTime();
      local expirationTime = now + duration;

      local newBar;
      bars[text] = bars[text] or {};
      local bar = bars[text];
      bar.addon = addon;
      bar.spellId = spellId;
      bar.text = text;
      bar.duration = duration;
      bar.expirationTime = expirationTime;
      bar.icon = icon;
      Reminders:BWTimerStart(bar);
      if (nextExpire == nil) then
        recheckTimer = timer:ScheduleTimer(recheckTimers, expirationTime - now);
        nextExpire = expirationTime;
      elseif (expirationTime < nextExpire) then
        timer:CancelTimer(recheckTimer);
        recheckTimer = timer:ScheduleTimer(recheckTimers, expirationTime - now);
        nextExpire = expirationTime;
      end
    elseif (event == "BigWigs_StopBar") then
      local addon, text = ...
      if(bars[text]) then
        Reminders:BWTimerStop(bars[text]);
        bars[text] = nil;
      end
    elseif (event == "BigWigs_StopBars"
      or event == "BigWigs_OnBossDisable"
      or event == "BigWigs_OnPluginDisable") then
      local addon = ...
      for key, bar in pairs(bars) do
        if (bar.addon == addon) then
          bars[key] = nil;
          Reminders:BWTimerStop(bar);
        end
      end
    end
  end

  function Reminders:RegisterBigWigsCallback(event)
    if (registeredBigWigsEvents [event]) then
      return
    end
    if (BigWigsLoader) then
      BigWigsLoader.RegisterMessage(Reminders, event, bigWigsEventCallback);
      registeredBigWigsEvents [event] = true;
    end
  end

  function Reminders:RegisterBigWigsTimer()
    Reminders:RegisterBigWigsCallback("BigWigs_StartBar");
    Reminders:RegisterBigWigsCallback("BigWigs_StopBar");
    Reminders:RegisterBigWigsCallback("BigWigs_StopBars");
    Reminders:RegisterBigWigsCallback("BigWigs_OnBossDisable");
  end

  function Reminders:CopyBigWigsTimerToState(bar, states, id)
    states[id] = states[id] or {};
    local state = states[id];
    state.show = true;
    state.changed = true;
    state.addon = bar.addon;
    state.spellId = bar.spellId;
    state.text = bar.text;
    state.name = bar.text;
    state.duration = bar.duration;
    state.expirationTime = bar.expirationTime;
    state.resort = true;
    state.progressType = "timed";
    state.icon = bar.icon;
  end

  function Reminders:BigWigsTimerMatches(id, addon, spellId, textOperator, text)
    if(not bars[id]) then
      return false;
    end

    local v = bars[id];
    local bestMatch;
    if (addon and addon ~= v.addon) then
      return false;
    end
    if (spellId and spellId ~= v.spellId) then
      return false;
    end
    if (text) then
      if(textOperator == "==") then
        if (v.text ~= text) then
          return false;
        end
      elseif (textOperator == "find('%s')") then
        if (v.text == nil or not v.text:find(text, 1, true)) then
          return false;
        end
      elseif (textOperator == "match('%s')") then
        if (v.text == nil or v.text:match(text)) then
          return false;
        end
      end
    end
    return true;
  end

  function Reminders:GetAllBigWigsTimers()
    return bars;
  end

  function Reminders:GetBigWigsTimerById(id)
    return bars[id];
  end

  function Reminders:GetBigWigsTimer(addon, spellId, operator, text)
    local bestMatch
    for id, bar in pairs(bars) do
      if (Reminders:BigWigsTimerMatches(id, addon, spellId, operator, text)) then
        if (bestMatch == nil or bar.expirationTime < bestMatch.expirationTime) then
          bestMatch = bar;
        end
      end
    end
    return bestMatch;
  end

  local scheduled_scans = {};

  local function doBigWigsScan(fireTime)
    scheduled_scans[fireTime] = nil;
    Reminders:BWTimerUpdate();
  end
  function Reminders:ScheduleBigWigsCheck(fireTime)
    if not(scheduled_scans[fireTime]) then
      scheduled_scans[fireTime] = timer:ScheduleTimer(doBigWigsScan, fireTime - GetTime() + 0.1, fireTime);
    end
  end

end