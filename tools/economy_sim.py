"""Social Cafe City - economy simulator.

Models the LIVE server loop (Kitchen.useProductionPlan = true):
  * each producer role has a budget of workMinutesBase + (lvl-1)*workMinutesPerLevel
    work-minutes per REAL hour (15 -> 60)
  * one plan job = 1 serving, costs recipe.productionMinutes work-minutes and one
    ingredient table; no coin charge at production time
  * an appliance can run 60 minutes of work per hour, so appliances cap the role
  * customers spawn on the demand rate with NO stock check; unserved -> angry
    walkout at buzz -2, served -> buzz +1
  * revenue lands on SERVE: floor(basePrice*0.5), x0.8 when staff serve
"""
import json, math, os

SC = os.path.dirname(os.path.abspath(__file__))  # rec.json / furniture.json sit beside this file
REC = json.load(open(SC + "/rec.json"))
FURN = {f["id"]: f for f in json.load(open(SC + "/furniture.json"))}

XP_FOR_LEVEL = [0, 60, 150, 300, 520, 820, 1220, 1750, 2400, 3200]
REP_FOR_STAR = [50, 200, 600, 1500, 4000]
WORK_BASE, WORK_PER_LEVEL = 15, 5
BUZZ_MAX, BUZZ_START = 105, 10
STAFF_PAYOUT_MULT, STAFF_XP_MULT = 0.8, 0.5
XP_PER_SERVE, REP_PER_SERVE = 10, 2
TIP_EV = 0.25 * 0.20 * 1.0667      # chance x fraction x mean tipMultiplier
GIFT_EV_PER_HOUR = 84.5 * 4        # 15-min session gift, weighted mean
GOALS_PER_DAY = 30 + 40 + 50 + 25

ROLE_APPLIANCES = {"Barista": {"coffee_machine"}, "Cook": {"oven", "prep_station"}}


def level_for_xp(xp):
    lv = 1
    for i, need in enumerate(XP_FOR_LEVEL, start=1):
        if xp >= need:
            lv = i
    return lv


def stars_for_rep(rep):
    s = 0
    for i, need in enumerate(REP_FOR_STAR, start=1):
        if rep >= need:
            s = i
    return s


def coins_per_workmin(r):
    rev = math.floor(r["price"] * 0.5)
    return (rev - r["ingcost"]) / r["pm"] if r["pm"] else 0


def best_recipe(role, level, owned_appliances):
    """Highest coins-per-work-minute recipe this role can actually make."""
    best, bestv = None, -1
    for r in REC.values():
        if r["role"] != role or not r["pm"]:
            continue
        if r["lvl"] > level or r["appliance"] not in owned_appliances:
            continue
        v = coins_per_workmin(r)
        if v > bestv:
            best, bestv = r, v
    return best


class Sim:
    def __init__(self, buy_robux=None):
        self.coins = 150.0
        self.xp = 0.0
        self.rep = 0.0
        self.buzz = float(BUZZ_START)
        self.staff = {"Barista": 1, "Waiter": 1, "Cook": 0, "Cleaner": 0}  # 0 = not hired
        self.appliances = []          # list of catalogId
        self.seats = 0
        self.spent = {"appliances": 0.0, "seats": 0.0, "hire": 0.0, "upgrades": 0.0, "ingredients": 0.0}
        self.log = []
        self.buy_robux = buy_robux or set()
        self.stall_hours = 0

    @property
    def level(self):
        return level_for_xp(self.xp)

    def owned(self, role):
        return {a for a in self.appliances if a in ROLE_APPLIANCES[role]}

    def demand_per_hour(self):
        rate = 1.2 + (2.8 - 1.2) * (min(self.buzz, BUZZ_MAX) / BUZZ_MAX) + max(0, self.seats - 4) * 0.04
        cap = 2.8 if self.staff["Waiter"] > 0 else 1.2
        return 60 * max(0.2, min(rate, cap))

    def produce(self):
        """Returns (servings, revenue, ingredient_cost) for one hour."""
        total_serv, total_rev, total_ing = 0.0, 0.0, 0.0
        for role in ("Barista", "Cook"):
            lvl = self.staff[role]
            if lvl <= 0:
                continue
            owned = self.owned(role)
            if not owned:
                continue
            budget = WORK_BASE + (lvl - 1) * WORK_PER_LEVEL      # work-min / hour
            machine_cap = 60 * len(owned)                         # each machine: 60 min/hr
            work = min(budget, machine_cap)
            r = best_recipe(role, self.level, owned)
            if not r:
                continue
            serv = work / r["pm"]
            payout = math.floor(r["price"] * 0.5) * STAFF_PAYOUT_MULT + TIP_EV * r["price"]
            total_serv += serv
            total_rev += serv * payout
            total_ing += serv * r["ingcost"]
        return total_serv, total_rev, total_ing

    def step_hour(self, h):
        produced, rev_per_unit_pool, ing = self.produce()
        arrivals = self.demand_per_hour()
        served = min(arrivals, produced)
        walkouts = max(0.0, arrivals - served)
        frac = (served / produced) if produced > 0 else 0.0

        revenue = rev_per_unit_pool * frac
        ing_cost = ing                      # ingredients are consumed at PRODUCTION time
        self.coins += revenue - ing_cost + GIFT_EV_PER_HOUR + GOALS_PER_DAY / 24.0
        self.spent["ingredients"] += ing_cost
        self.xp += served * XP_PER_SERVE * STAFF_XP_MULT
        self.rep += served * REP_PER_SERVE
        self.buzz = max(0.0, min(BUZZ_MAX, self.buzz + served * 1 - walkouts * 2))
        self.shop()
        self.log.append(dict(h=h + 1, coins=self.coins, lvl=self.level, xp=self.xp, rep=self.rep,
                             stars=stars_for_rep(self.rep), buzz=self.buzz, produced=produced,
                             arrivals=arrivals, served=served, walkouts=walkouts,
                             net=revenue - ing_cost, gift=GIFT_EV_PER_HOUR,
                             barista=self.staff["Barista"], cook=self.staff["Cook"],
                             seats=self.seats, appl=len(self.appliances)))

    def shop(self):
        """A sensible player: unlock production first, then raise the ceiling."""
        progressed = True
        while progressed:
            progressed = False
            # 1. a coffee machine is the whole game
            if "coffee_machine" not in self.appliances and self.coins >= 120:
                self.coins -= 120; self.appliances.append("coffee_machine")
                self.spent["appliances"] += 120; progressed = True; continue
            # 2. seats so nobody storms out for a chair (4 is the free allowance)
            if self.seats < 6 and self.coins >= 55:
                self.coins -= 55; self.seats += 1          # table+chair pair ~55
                self.spent["seats"] += 55; progressed = True; continue
            # 3. hire the Cook -> a second production role (doubles the ceiling)
            if self.staff["Cook"] == 0 and self.level >= 1 and self.coins >= 600:
                self.coins -= 600; self.staff["Cook"] = 1
                self.spent["hire"] += 600; progressed = True; continue
            # 4. the Cook needs a machine
            if self.staff["Cook"] > 0 and "prep_station" not in self.appliances \
                    and self.level >= 2 and self.coins >= 160:
                self.coins -= 160; self.appliances.append("prep_station")
                self.spent["appliances"] += 160; progressed = True; continue
            if self.staff["Cook"] > 0 and "oven" not in self.appliances \
                    and self.level >= 2 and self.coins >= 220:
                self.coins -= 220; self.appliances.append("oven")
                self.spent["appliances"] += 220; progressed = True; continue
            # 5. raise work-minutes: the ONLY real throughput lever
            for role in ("Barista", "Cook"):
                lvl = self.staff[role]
                if 0 < lvl < 10:
                    cost = 100 * lvl
                    if self.coins >= cost:
                        self.coins -= cost; self.staff[role] += 1
                        self.spent["upgrades"] += cost; progressed = True; break
            # 6. cleaner last (cosmetic: satisfaction gates nothing)
            if not progressed and self.staff["Cleaner"] == 0 and self.coins >= 400 + 2000:
                self.coins -= 400; self.staff["Cleaner"] = 1
                self.spent["hire"] += 400; progressed = True

    def run(self, hours):
        for h in range(hours):
            self.step_hour(h)
        return self.log
