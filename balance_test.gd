extends SceneTree
var g
var failures=0
var checks=0
func check(ok, label):
	checks+=1
	if not ok:
		failures+=1
		push_error(label)
	else: print("PASS ",label)
func fresh(owned=[]):
	if is_instance_valid(g): g.free()
	g=load("res://run_model.gd").new()
	g.owned_augments=owned.duplicate()
	g.rng.seed=1234
	g._start_stage()
	g._generate_board(0)
func _initialize(): call_deferred("run")
func run():
	fresh()
	check(not g.Augments.ALL.has("overcrowding") and not g.Augments.ALL.has("healing_loss"),"Removed debuffs")
	for level in range(1,5):
		g.augment_levels.survey=level
		check(g._power("survey")==level*6,"Survey level %d"%level)
	fresh(["communism","survey","smith"])
	g.augment_levels={"communism":2,"survey":4,"smith":1}
	check(g._level("survey")==2 and g._level("smith")==2,"Communism lowers and raises effective levels")
	g.upgrade_target="communism"
	check(g._ticket_cost()==12 and is_equal_approx(g._ticket_chance(),0.25),"Smith halves costs and level bonus applies")
	check(not g._can_upgrade("survey"),"Individual upgrades locked under communism")
	fresh(["decontamination"])
	check(g.money==42 and g.mine_count==8,"Decontamination removes three and pays three rewards")
	fresh(["gamble"])
	g.money=100
	g._use_active("gamble")
	check(g.money>=50 and g.money<=200 and "gamble" in g.used_actives,"Gamble bounds and once per stage")
	var balance=g.money
	g._use_active("gamble")
	check(g.money==balance,"No repeated gamble")
	fresh(["relief","recycle"])
	g._use_active("relief")
	check(g.money==530 and not g._card_ready("relief"),"Consumable first use")
	g.stage=2
	check(not g._card_ready("relief"),"Recycle stage two cooldown")
	g.stage=3
	check(g._card_ready("relief"),"Recycle after two stages")
	g.augment_levels.recycle=4
	g.spent_cards.relief=2
	check(g._card_ready("relief"),"Recycle level four one stage")
	fresh(["cleanse","high_explosive"])
	g._use_active("cleanse")
	check(not g._has("high_explosive") and g.spent_cards.has("cleanse"),"Cleanse removes debuff")
	fresh(["relief"])
	g.phase="augment"
	g.offered_augments=["hynix"]
	g.money=101
	g._choose_augment("hynix")
	check(g.money==50 and g.phase=="reward","Hynix immediately halves gold")
	fresh(["survey"])
	g.phase="augment"
	g.offered_augments=["reversal"]
	g._choose_augment("reversal")
	check(not g._has("survey"),"Reversal removes random buff")
	fresh(["reroll"])
	g.phase="augment"
	g.offered_augments=["survey","gamble","beast"]
	g._reroll_slot(1)
	var id=g.offered_augments[1]
	g._reroll_slot(1)
	check(id==g.offered_augments[1] and g.rerolled_slots==[1],"Each slot rerolls once")
	fresh(["genius","communism"])
	g._use_active("genius")
	check(g._level("communism")==4 and g._level("genius")==4,"Genius upgrades communism")
	fresh(["cluster"])
	check(g.mine_count==15,"Cluster mine total stage one")
	var full=false
	for y in range(1,g.board_height-1):
		for x in range(1,g.board_width-1):
			if g._area(y*g.board_width+x,1).all(func(i):return g.cells[i].mine):full=true
	check(full,"Cluster has a complete 3x3 mine square")
	fresh(["unfair"])
	g.unfair_stage=2
	g.stage=2
	g._start_stage()
	g._generate_board(0)
	check(g.cells.all(func(c):return c.mine),"Unfair next stage has no safe tiles")
	g.stage=3
	g._start_stage()
	g._generate_board(0)
	check(not g.cells[0].mine,"Unfair lasts only one stage")
	fresh(["beast"])
	g.hp=100
	g.max_hp=100
	g._use_active("beast")
	check(g.cells.filter(func(c):return c.revealed).size()==10 and g.direct_digs==0,"Beast reveals ten without direct counters")
	fresh(["adaptation"])
	g._adapt()
	check(g.max_hp==11 and g.hp==11,"Adaptation increases current and maximum hp")
	fresh(["slip","survey"])
	g.ticket_pending={"success":false,"cost":1,"id":"survey","level":1}
	# Repeat independent failed upgrades until destruction occurs, bounded deterministic RNG.
	for i in range(500):
		g.ticket_pending={"success":false,"cost":1,"id":"survey","level":1}
		g._resolve_upgrade_ticket()
		if not g._has("survey"):break
	check(not g._has("survey"),"Failure can destroy augment")
	fresh(["unstable_ground"])
	for c in g.cells: c.adjacent=1
	g.direct_digs=28
	g._dig(1)
	check(g.hp==10,"Ground no damage on dig 29")
	g._dig(2)
	check(g.hp==9,"Ground damage on dig 30")
	fresh(["bleeding"])
	for c in g.cells: c.adjacent=1
	var mine=g.cells.find_custom(func(c):return c.mine)
	g._dig(mine)
	var hp_after=g.hp
	var safe=g._hidden_safe()
	g._dig(safe[0])
	g._dig(safe[1])
	g._dig(safe[2])
	check(g.hp==hp_after-2 and g.bleed_digs==0,"Bleeding damages exactly next two digs")
	fresh(["chain"])
	for i in range(g.cells.size()):
		g.cells[i].mine = i in [9,10,18,27]
		g.cells[i].adjacent=1
	g._dig(9)
	check(g.cells[10].revealed and g.cells[18].revealed and not g.cells[27].revealed and g.hp==4,"Chain damages neighbors without recursion")
	print("PATCH CHECKS ",checks," failures ",failures)
	g.free()
	quit(failures)
