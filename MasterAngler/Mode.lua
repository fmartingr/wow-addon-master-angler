local _, ns = ...

ns.Mode = {}
local Mode = ns.Mode

local subscribers = {}
local pending = false

function Mode.IsOn()
	local char = ns.Char()
	return char ~= nil and char.mode.on == true
end

function Mode.Subscribe(fn)
	subscribers[#subscribers + 1] = fn
end

local function notify(isOn)
	for _, fn in ipairs(subscribers) do
		if not pcall(fn, isOn) then
			ns.ReportOnce("mode-subscriber", ns.L.HOOK_FAILED)
		end
	end
end

function Mode.IsPending()
	return pending
end

-- The record of the old gear is kept until a swap back runs without an error,
-- so a failed swap can be retried. Skipped slots have their own warnings. Subscribers always see the stored state.
local function perform(char)
	local mode = char.mode
	local ok, err = true, nil
	if mode.on then
		-- A valid record holds every slot, so an empty one is lost data: planning
		-- against it would strip all worn gear.
		if next(mode.previous) ~= nil then
			ok, err = pcall(ns.Gear.Apply, ns.Gear.Plan(mode.previous, ns.Gear.Snapshot()))
		end
		if ok then
			mode.on = false
			mode.previous = {}
		end
	else
		local previous = ns.Gear.Snapshot()
		mode.previous = previous
		mode.on = true
		ok, err = pcall(ns.Gear.Apply, ns.Gear.Plan(char.gear, previous))
	end
	notify(mode.on)
	if not ok then
		error(err, 0)
	end
	ns.Print(mode.on and ns.L.MODE_ON or ns.L.MODE_OFF)
end

function Mode.Toggle()
	local char = ns.Char()
	if not char then
		return
	end
	if pending then
		pending = false
		ns.Print(ns.L.SWAP_CANCELLED)
		return
	end
	if not char.mode.on and ns.Gear.Count(char.gear) == 0 then
		ns.Print(ns.L.NO_GEAR_SAVED)
		return
	end
	if InCombatLockdown() then
		pending = true
		ns.Print(ns.L.SWAP_AFTER_COMBAT)
		return
	end
	perform(char)
end

ns.On("PLAYER_REGEN_ENABLED", function()
	if pending then
		pending = false
		if not pcall(Mode.Toggle) then
			ns.Print(ns.L.COMMAND_FAILED)
		end
	end
end)

ns.Commands.Register("mode", Mode.Toggle, "HELP_MODE")
