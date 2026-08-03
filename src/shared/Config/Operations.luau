--!strict
-- Active-shift retention tuning. Automatic work is useful, but finite: staff
-- spend shift capacity while producing, serving, and cleaning. Capacity only
-- recovers while the owner is in-game, and hands-on work gives a small boost.

local Operations = {
	maxSatisfaction = 100,
	startingSatisfaction = 86,
	startingCleanliness = 92,
	offlineSatisfactionLossPerHour = 2.5,
	maxOfflineSatisfactionLoss = 30,

	-- ————— shift capacity: WHICH OF THESE IS ACTUALLY LIVE —————
	--
	-- Audited 2026-08-03 (economy fix #2, docs/ECONOMY_ANALYSIS.md §2.3). Capacity
	-- is a real mechanic, but only for the roles that still SPEND it:
	--
	--   Waiter   LIVE — KitchenService charges serviceCapacityPerWorkMinute on
	--                   every serve, so a waiter genuinely runs a shift down.
	--   Cleaner  LIVE — StaffService charges cleanerCapacityPerMess per clean.
	--   Barista  }  producers are limited by WORK-MINUTES per hour instead
	--   Cook     }  (Kitchen.workMinutesBase/PerLevel). While
	--              Kitchen.useProductionPlan is true they never spend capacity
	--              online, so their recovery rates below only matter to the
	--              legacy scheduler and to the offline settlement.
	--
	-- Kept rather than deleted because the legacy path still needs it and the
	-- offline settlement still reads productionCapacityPerWorkMinute. Do NOT wire
	-- producers back into capacity without re-running tools/economy_sim.py: it
	-- would throttle production a second time on top of the work-minute budget.
	staffCapacityMax = 100,
	startingStaffCapacity = 100,
	onlineRecoveryPerMinute = {
		Barista = 0.45, -- legacy scheduler + offline settlement only
		Cook = 0.45, -- legacy scheduler + offline settlement only
		Waiter = 0.35, -- LIVE
		Cleaner = 0.55, -- LIVE
	},
	productionCapacityPerWorkMinute = 1.6, -- legacy scheduler + offline settlement
	serviceCapacityPerWorkMinute = 1.8, -- LIVE (every serve)
	cleanerCapacityPerMess = 3, -- LIVE (every clean)
	manualCapacityRestore = 1.25,

	dirtSpawnSeconds = 55, -- much less frequent (owner: dirt was appearing too often)
	maxDirt = 4,
	cleanlinessLossPerDirt = 11,
	cleanlinessGainPerClean = 13,
	dirtyRejectThreshold = 30,
	dirtyPatienceThreshold = 65,
	minPatienceMultiplier = 0.55,

	-- ————— satisfaction —————
	-- Owner decision 2026-08-03: KEEP, a consequence is coming later. As of today
	-- satisfaction is written by a dozen call sites and read by NONE for any
	-- decision — it cannot reject a customer, slow a spawn or change a payout, so
	-- it is presentational. The numbers below are therefore not balanced against
	-- anything yet; tune them when the consequence lands, not before.
	satisfactionPerServe = 0.8,
	satisfactionPerManualServe = 1.4,
	satisfactionPerClean = 0.7,
	satisfactionWalkoutLoss = 6,
	satisfactionNoSeatLoss = 8,
	satisfactionDirtyLoss = 9,

	offlineTimeMultiplier = 20,
	offlineEarningsDivisor = 20,
	maxOfflineEarningHours = 8,
}

return Operations
