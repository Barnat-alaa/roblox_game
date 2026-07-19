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

	staffCapacityMax = 100,
	startingStaffCapacity = 100,
	onlineRecoveryPerMinute = {
		Barista = 0.45,
		Cook = 0.45,
		Waiter = 0.35,
		Cleaner = 0.55,
	},
	productionCapacityPerWorkMinute = 1.6,
	serviceCapacityPerWorkMinute = 1.8,
	cleanerCapacityPerMess = 3,
	manualCapacityRestore = 1.25,

	dirtSpawnSeconds = 18,
	maxDirt = 8,
	cleanlinessLossPerDirt = 11,
	cleanlinessGainPerClean = 13,
	dirtyRejectThreshold = 30,
	dirtyPatienceThreshold = 65,
	minPatienceMultiplier = 0.55,

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
