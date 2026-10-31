## M3 economy tests: transactions, hold-to-buy guards, track curves, DPS delta,
## reward-bundle idempotency, speed maths and tap guards.
##
## Pure logic only: no scene tree and no autoloads (BattleClock is instantiated and
## freed directly), so the suite runs under `--headless --script`.
extends RefCounted

const TREE_DATA_PATH := "res://data/tree/tree_base.tres"
const FRAME := 1.0 / 60.0
const HOLD_FRAMES := 300


func test_wallet_transactions() -> bool:
	var wallet := RunWallet.new(100)
	var spent := wallet.try_spend(40, &"test")
	if not spent.is_ok() or spent.balance != 60 or wallet.get_cash() != 60:
		print("  spend should leave 60: ", spent.code, " ", wallet.get_cash())
		return false
	var refused := wallet.try_spend(1000, &"test")
	if refused.is_ok() or refused.code != SpendResult.Code.INSUFFICIENT_FUNDS:
		print("  unaffordable spend must fail with INSUFFICIENT_FUNDS: ", refused.code)
		return false
	if refused.reason_key.is_empty() or wallet.get_cash() != 60:
		print("  failed spend must keep the balance and carry a reason")
		return false
	if wallet.add(-5, &"test").is_ok() or wallet.add(0, &"test").is_ok():
		print("  add() must reject non-positive amounts")
		return false
	if not wallet.add(10, &"test").is_ok() or wallet.get_cash() != 70:
		print("  add(10) should leave 70: ", wallet.get_cash())
		return false
	var log := wallet.get_log()
	if log.size() != 2:
		print("  expected 2 logged transactions (rejects are not logged), got ", log.size())
		return false
	var small := RunWallet.new(0)
	for index in 60:
		small.add(1, &"loop")
	if small.get_log().size() != RunWallet.MAX_LOG_ENTRIES:
		print("  transaction log must be bounded at ", RunWallet.MAX_LOG_ENTRIES)
		return false
	print("  wallet guard, reasons and 50-entry log verified")
	return true


func test_hold_to_buy_over_buy_guard() -> bool:
	var track := UpgradeTrack.new()
	track.id = &"test_track"
	track.cost_base = 40
	track.cost_growth = 1.35
	track.max_level = 30
	var model := TreeUpgrades.new()
	model.setup([track])

	var wallet := RunWallet.new(100000)
	var purchased := _hold(model, track.id, wallet, &"hold_unbounded")
	if wallet.get_cash() < 0:
		print("  hold-to-buy went negative: ", wallet.get_cash())
		return false
	if purchased > 30 or model.get_level(track.id) != purchased:
		print("  hold bought past max level: ", purchased, " level ", model.get_level(track.id))
		return false
	var maximum := TrackBudget.max_purchases(track, 100000)
	if purchased > maximum:
		print("  hold bought %d, budget allows %d" % [purchased, maximum])
		return false

	# Exactly three affordable purchases plus change: it must stop before the 4th.
	var budget := track.cost_at(1) + track.cost_at(2) + track.cost_at(3) + 10
	var wallet_budget := RunWallet.new(budget)
	var model_budget := TreeUpgrades.new()
	model_budget.setup([track])
	var bought := _hold(model_budget, track.id, wallet_budget, &"hold_budget")
	var next_cost := track.cost_at(model_budget.get_level(track.id) + 1)
	if bought != 3:
		print("  expected 3 purchases with %d cash, got %d" % [budget, bought])
		return false
	if wallet_budget.get_cash() < 0 or wallet_budget.get_cash() >= next_cost:
		print("  overspent: balance %d, next cost %d" % [wallet_budget.get_cash(), next_cost])
		return false

	# Cadence: a 5 s hold at 8/s is ~40 attempts, never more than one per 0.125 s.
	var cheap := UpgradeTrack.new()
	cheap.id = &"cheap"
	cheap.cost_base = 1
	cheap.cost_growth = 1.0
	cheap.max_level = 1000
	var cheap_model := TreeUpgrades.new()
	cheap_model.setup([cheap])
	var cheap_wallet := RunWallet.new(1000)
	var held := _hold(cheap_model, cheap.id, cheap_wallet, &"hold_cadence")
	if held < 38 or held > 42:
		print("  5 s hold should buy ~40 levels, got ", held)
		return false
	print("  5 s hold: %d buys, no negative cash, <= 1 over-buy" % purchased)
	return true


func test_upgrade_track_curves() -> bool:
	var tracks := TreeUpgrades.load_tracks()
	if tracks.size() != 6:
		print("  expected 6 tree tracks, got ", tracks.size())
		return false
	var expected := {
		&"tree_damage": [40, 1.35, 0.08, 0.0],
		&"tree_attack_speed": [50, 1.40, 0.06, 0.0],
		&"tree_crit_chance": [60, 1.45, 0.02, 0.6],
		&"tree_crit_damage": [60, 1.45, 0.15, 0.0],
		&"tree_range": [40, 1.30, 0.03, 0.0],
		&"tree_regen": [80, 1.40, 0.003, 0.0],
	}
	var model := TreeUpgrades.new()
	model.setup(tracks)
	for track in tracks:
		if not expected.has(track.id):
			print("  unexpected track ", track.id)
			return false
		var want: Array = expected[track.id]
		if track.cost_base != int(want[0]) or not is_equal_approx(track.cost_growth, float(want[1])):
			print("  cost curve mismatch for ", track.id)
			return false
		if not is_equal_approx(track.effect_per_level, float(want[2])):
			print("  effect mismatch for ", track.id)
			return false
		if not is_equal_approx(track.cap, float(want[3])):
			print("  cap mismatch for ", track.id)
			return false
		var first := track.cost_at(0)
		var second := track.cost_at(1)
		if first != track.cost_base or second != roundi(float(track.cost_base) * track.cost_growth):
			print("  level costs must start at base then grow: ", first, " ", second)
			return false
		var cheap := RunWallet.new(first - 1)
		var check := model.can_buy(track.id, cheap)
		if check.is_ok() or check.code != SpendResult.Code.INSUFFICIENT_FUNDS:
			print("  affordability must use the next cost for ", track.id)
			return false
	var crit := model.get_track(&"tree_crit_chance")
	if not is_equal_approx(crit.value_at(30), 0.6) or not crit.is_maxed(30):
		print("  crit chance must cap at 60 % at level 30")
		return false
	print("  6 tracks match the brief (costs, growth, effects, crit cap)")
	return true


func test_tree_dps_after_damage_upgrade() -> bool:
	var tree := load(TREE_DATA_PATH) as TreeData
	if tree == null:
		print("  cannot load ", TREE_DATA_PATH)
		return false
	var model := TreeUpgrades.new()
	model.setup(TreeUpgrades.load_tracks())
	var before := TreeUpgrades.tree_dps(
		tree.damage, tree.attack_interval, tree.crit_chance, tree.crit_multiplier, model.get_bonuses()
	)
	var check := model.can_buy(&"tree_damage", RunWallet.new(1000))
	if not check.is_ok() or not model.record_purchase(&"tree_damage").is_ok():
		print("  damage track purchase failed")
		return false
	var after := TreeUpgrades.tree_dps(
		tree.damage, tree.attack_interval, tree.crit_chance, tree.crit_multiplier, model.get_bonuses()
	)
	var ratio := after / before
	if absf(ratio - 1.08) > 0.0001:
		print("  +8 %% damage should raise DPS by 8 %%, ratio %.4f" % ratio)
		return false
	var speed_before := after
	model.record_purchase(&"tree_attack_speed")
	var speed_after := TreeUpgrades.tree_dps(
		tree.damage, tree.attack_interval, tree.crit_chance, tree.crit_multiplier, model.get_bonuses()
	)
	if speed_after <= speed_before:
		print("  attack speed upgrade must raise DPS")
		return false
	print("  DPS %.1f -> %.1f after +1 damage (+8 %%)" % [before, after])
	return true


func test_reward_bundle_idempotency() -> bool:
	var bundle := RewardBundle.for_run(10, 1, true)
	if bundle.coins != 240 or bundle.gems != 7 or bundle.xp != 100:
		print("  wave 10 + boss + new best bundle wrong: ", bundle.to_dict())
		return false
	var plain := RewardBundle.for_run(5)
	if plain.coins != 70 or plain.gems != 1 or plain.xp != 50:
		print("  default bundle must keep M2 values: ", plain.to_dict())
		return false
	var wallet := {"coins": 0, "gems": 0, "stones": 0}
	var player := {"xp": 0}
	var ledger := RewardLedger.new()
	if not ledger.claim("run-a"):
		print("  first claim must succeed")
		return false
	if ledger.claim("run-a"):
		print("  repeated claim must be refused")
		return false
	bundle.apply_to(wallet, player)
	if wallet["coins"] != 240 or wallet["gems"] != 7 or player["xp"] != 100:
		print("  bundle apply wrong: ", wallet, " ", player)
		return false
	var negative := RewardBundle.new()
	negative.coins = -50
	negative.xp = -5
	negative.apply_to(wallet, player)
	if wallet["coins"] != 240 or player["xp"] != 100:
		print("  negative bundle amounts must be ignored")
		return false
	var doubled := RewardBundle.coins_only(240)
	doubled.apply_to(wallet, player)
	if wallet["coins"] != 480:
		print("  coins_only bundle should add 240: ", wallet["coins"])
		return false
	print("  bundle math (coins 240 / gems 7 / xp 100) and one-claim ledger verified")
	return true


func test_speed_multiplier_math() -> bool:
	var clock := BattleClock.new()
	clock.set_speed(2.0)
	if absf(clock.scaled(0.5) - 1.0) > 0.0001:
		print("  2x should scale 0.5 s to 1.0 s, got ", clock.scaled(0.5))
		clock.free()
		return false
	clock.set_paused(true)
	if clock.scaled(0.5) != 0.0:
		print("  paused clock must return a zero delta")
		clock.free()
		return false
	clock.set_paused(false)
	clock.set_speed_index(1)
	if not is_equal_approx(clock.get_speed(), 1.5) or clock.get_speed_index() != 1:
		print("  speed index 1 should be 1.5x, got ", clock.get_speed())
		clock.free()
		return false
	clock.set_speed(999.0)
	if clock.get_speed() > BattleClock.MAX_SPEED:
		print("  speed must clamp to MAX_SPEED")
		clock.free()
		return false
	clock.free()
	print("  speed delta multiplier, pause and clamp verified")
	return true


func test_tap_guard() -> bool:
	if not TapGuard.requires_hold(0) or not TapGuard.requires_hold(2) or TapGuard.requires_hold(3):
		print("  first 3 skips must require a hold")
		return false
	if TapGuard.allows(0, 0.24) or not TapGuard.allows(0, 0.25):
		print("  hold threshold must be 250 ms")
		return false
	if not TapGuard.allows(3, 0.0):
		print("  skips after the first three must accept a tap")
		return false
	print("  next-wave tap guard verified")
	return true


## Drives one HoldToBuy for five seconds at 60 fps and returns purchases made.
func _hold(model: TreeUpgrades, track_id: StringName, wallet: RunWallet, reason: StringName) -> int:
	var hold := HoldToBuy.new()
	hold.start()
	var attempt := func() -> SpendResult:
		var check := model.can_buy(track_id, wallet)
		if not check.is_ok():
			return check
		var spent := wallet.try_spend(check.amount, reason)
		if spent.is_ok():
			model.record_purchase(track_id)
		return spent
	var purchases := 0
	for _frame in HOLD_FRAMES:
		purchases += hold.tick(FRAME, attempt)
	return purchases


## Pure budget helper used by the over-buy test (no wallet mutation).
class TrackBudget:
	static func max_purchases(track: UpgradeTrack, cash: int) -> int:
		var level := 0
		var remaining := cash
		while level < track.max_level:
			var cost := track.cost_at(level)
			if cost > remaining:
				break
			remaining -= cost
			level += 1
		return level
