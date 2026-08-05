--!strict
-- Contract tests for the timed work boost and the two ID-gated time products
-- (economy fix #11, docs/ECONOMY_ANALYSIS.md §5.5).
--
-- The pro-rating is the part worth pinning down: a one-hour Double Shift bought
-- just before logging off must pay for one boosted hour of an eight-hour
-- absence. Paying for none cheats the buyer; paying for all eight cheats the
-- economy. Both are silent failures, which is exactly why they are tested here.

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local BoostMath = require(ReplicatedStorage.Shared.Utilities.BoostMath)
	local Products = require(ReplicatedStorage.Shared.Config.Products)

	local NOW = 1_000_000 -- a fixed clock; nothing here reads os.time()
	local HOUR = 3600

	local function withBoost(expiry: number?): any
		return { boosts = if expiry then { work = expiry } else {} }
	end

	describe("Work boost multiplier", function()
		it("is 1 with no boost, and with a boost that has expired", function()
			expect(BoostMath.workMultiplier(withBoost(nil), NOW)).to.equal(1)
			expect(BoostMath.workMultiplier(withBoost(NOW - 1), NOW)).to.equal(1)
		end)

		it("is the configured multiplier while the boost is running", function()
			expect(BoostMath.workMultiplier(withBoost(NOW + HOUR), NOW)).to.equal(
				Products.workBoostMultiplier
			)
		end)

		it("survives a profile with no boosts table at all", function()
			-- Reconcile only fills TOP-LEVEL keys (HANDOFF §3), so an old save can
			-- reach the production loop with no boosts table. It must not throw.
			expect(BoostMath.workMultiplier({}, NOW)).to.equal(1)
			expect(BoostMath.workMultiplier({ boosts = "not a table" }, NOW)).to.equal(1)
		end)
	end)

	describe("Boost overlap with a window", function()
		it("is zero when the boost ended before the window opened", function()
			expect(BoostMath.activeSeconds(NOW - 10, NOW, HOUR)).to.equal(0)
		end)

		it("counts only the part of the window the boost covered", function()
			expect(BoostMath.activeSeconds(NOW + 600, NOW, HOUR)).to.equal(600)
		end)

		it("never exceeds the window, however long the boost runs", function()
			expect(BoostMath.activeSeconds(NOW + 99 * HOUR, NOW, HOUR)).to.equal(HOUR)
		end)

		it("is zero for an empty window rather than erroring", function()
			-- math.clamp errors when max < min, so a zero-length window has to be
			-- short-circuited rather than clamped (HANDOFF §5.6).
			expect(BoostMath.activeSeconds(NOW + HOUR, NOW, 0)).to.equal(0)
		end)
	end)

	describe("Offline settlement hours", function()
		it("pays the plain hours away when no boost was running", function()
			expect(BoostMath.offlineWorkHours(withBoost(nil), NOW, 8 * HOUR)).to.equal(8)
		end)

		it("pays ONE extra hour for a 1h boost across an 8h absence", function()
			-- The whole point: 8 hours away with one boosted hour is 9 hours of
			-- output at 2x, not 16. Buying a Double Shift and logging off must not
			-- double a whole night.
			local hours = BoostMath.offlineWorkHours(withBoost(NOW + HOUR), NOW, 8 * HOUR)
			expect(hours).to.equal(9)
		end)

		it("doubles a short absence entirely covered by the boost", function()
			local hours = BoostMath.offlineWorkHours(withBoost(NOW + HOUR), NOW, 30 * 60)
			expect(hours).to.equal(1) -- half an hour, paid twice
		end)

		it("pays nothing extra for a boost that expired before logging off", function()
			expect(BoostMath.offlineWorkHours(withBoost(NOW - 60), NOW, 4 * HOUR)).to.equal(4)
		end)

		it("returns zero hours for a zero-length window", function()
			expect(BoostMath.offlineWorkHours(withBoost(NOW + HOUR), NOW, 0)).to.equal(0)
		end)
	end)

	describe("Time product catalogue", function()
		it("never resolves a pending product from a receipt", function()
			-- The dark-ship guard: while the owner has not created the Dashboard
			-- products, no receipt may ever match one — including a bogus id of 0.
			expect(Products.timeProductForProduct(0)).to.equal(nil)
			expect(Products.timeProductForProduct(-1)).to.equal(nil)
			for _, entry in Products.timeProducts do
				if Products.isPending(entry) then
					expect(Products.timeProductForProduct(entry.productId)).to.equal(nil)
					expect(Products.timeProductLive(entry.key)).to.equal(nil)
				end
			end
		end)

		it("resolves each live product by id and by key", function()
			-- Vacuous until the owner pastes the IDs in, then it is the check that
			-- they were pasted correctly.
			for _, entry in Products.timeProducts do
				if not Products.isPending(entry) then
					expect(Products.timeProductForProduct(entry.productId)).to.equal(entry)
					expect(Products.timeProductLive(entry.key)).to.equal(entry)
				end
			end
		end)

		it("gives every product a distinct id and a coin-earnable twin", function()
			local seen: { [number]: boolean } = {}
			for _, entry in Products.timeProducts do
				expect(type(entry.earnable)).to.equal("string")
				expect(#entry.earnable > 0).to.equal(true)
				if not Products.isPending(entry) then
					-- Two SKUs sharing an id would silently grant the wrong thing.
					expect(seen[entry.productId]).to.equal(nil)
					seen[entry.productId] = true
					expect(Products.developerProducts[entry.productId]).to.equal(nil)
					expect(Products.stockPackForProduct(entry.productId)).to.equal(nil)
				end
			end
		end)
	end)
end
