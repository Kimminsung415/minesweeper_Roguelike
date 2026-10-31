extends SceneTree
var g
var failures = 0
var checks = 0
func check(ok, label):
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func fixture(id, level):
	g._new_run()
	g.owned_augments = [id]
	g.augment_levels[id] = level
	g._start_stage()
	g.generated = true
	g.money = 10000
	g.hp = g.max_hp
	g.mine_count = 6
	for i in range(g.cells.size()):
		g.cells[i] = {"mine": i in [9,10,18,40,41,63], "stealth": false, "adjacent": 1, "revealed": false, "flagged": false, "settled": false, "committed": false, "obscured": false}
func seed_for(success):
	var rng = RandomNumberGenerator.new()
	for seed_value in range(10000):
		rng.seed = seed_value
		if (rng.randf() < g._ticket_chance()) == success: return seed_value
	return -1
func _initialize(): call_deferred("run")
func run():
	g = load("res://run_model.gd").new()
	root.add_child(g)
	check(g.Upgrades.DATA.size()==33,"33 upgradeable buffs")
	for id in g.Upgrades.DATA:
		for level in range(1,5):
			fixture(id,level)
			g.upgrade_target = id
			check(g._level(id)==level and g._ticket_cost()==(6 if id=="smith" else 12)*(1<<(level-1)),"Independent level and price "+id)
			check(is_equal_approx(g._ticket_chance(),([0.3,0.2,0.1,0.0][level-1] + ((level-1)*0.05 if id=="smith" and level<4 else 0.0))),"Chance "+id)
			if level==4:
				var gold = g.money
				var state = g.rng.state
				check(not g._begin_upgrade_ticket() and g.money==gold and g.rng.state==state,"Max level blocks charge and RNG "+id)
			else:
				g.rng.seed = seed_for(false)
				g._buy_upgrade_ticket()
				check(g._level(id)==level and g.money==10000-(6 if id=="smith" else 12)*(1<<(level-1)),"Failure charges once "+id)
				g.rng.seed = seed_for(true)
				g._begin_upgrade_ticket()
				var gold = g.money
				check(not g._begin_upgrade_ticket() and g.money==gold,"Pending duplicate block "+id)
				g._resolve_upgrade_ticket()
				check(g._level(id)==level+1 and g._level("scanner" if id!="scanner" else "domain")==1,"Success only upgrades target "+id)
		for level in range(1,5):
			fixture(id,level)
			var value = g._power(id)
			match id:
				"domain","scanner","safe_dig": check(g._active_radius(id)==int(g.Upgrades.DATA[id][0][0])+level-1,"Range grows one cell "+id)
				"hound":
					g._use_active(id)
					check(g.last_commit.correct==int(value),"Hound count")
				"survey":
					g._use_active(id)
					check(g._hidden_safe().size()==58-int(value),"Survey count")
				"shield":
					g._use_active(id)
					for i in range(int(value)): g._dig(i)
					check(not g.shield_ready and g.shield_charges==0,"Shield charges consumed")
				"transfusion":
					g.hp=1
					g._use_active(id)
					check(g.hp==1+int(value),"Transfusion healing")
				"grant","blood_trade":
					g._use_active(id)
					check(g.money==10000+g.dig_cost*int(value),"Gold active "+id)
				"audit":
					for i in range(12):
						if not g.cells[i].mine: g._toggle_flag(i)
					g._use_active(id)
					check(g._pending_flags().size()==maxi(0,10-int(value)),"Audit removal")
				"acceleration":
					g._use_active(id)
					check(g.accelerated_digs==int(value),"Free digs")
				"vitality":
					g._use_active(id)
					check(g.max_hp==10+int(value) and g.hp==g.max_hp,"Vitality maximum")
				"insurance":
					g._use_active(id)
					g._settle_mines([],2,true)
					check(g.hp==10-ceili(4*(100-value)/100.0),"Insurance rounded damage")
				"shock":
					g.hp=5; g._dig(9)
					check(g.hp==mini(10,3+int(value)),"Shock healing")
				"dividend":
					g._dig(9)
					check(g.money==floori(9998*value),"Dividend multiplier")
				"regeneration":
					g.hp=5
					for i in range(int(value)): g._dig(i)
					check(g.hp==6,"Regeneration interval")
				"revival":
					g._apply_damage(100)
					check(g.hp==int(value) and g.revival_used,"Revival HP")
				"echo":
					for i in range(int(value)): g._dig(g._hidden_safe()[0])
					check(g.echo_uses==int(value),"Echo cap")
				"decontamination": check(g._rules_for(2).mines==19-int(value),"Next-stage mine reduction")
				"armor": check(g.max_hp==10+int(value) and g._mine_damage()==1,"Armor HP and reduction")
				"artisan":
					g._settle_mines([9,10,18])
					check(g.last_commit.bonus==floori(4*value),"Artisan bonus")
				"frugal":
					for i in range(int(value)): g._dig(i)
					check(g.money==10000,"Frugal count")
				"salvage":
					g._dig(9)
					check(g.money==9998+floori(4*value/100.0),"Salvage percentage")
				"heart": check(g.max_hp==10+int(value),"Heart maximum")
				"medic":
					g.hp=3; g._settle_mines([9,10,18,40,41,63]); g._finish_action()
					check(g.hp==3+int(value),"Medic clear healing")
				"reserve":
					g.money=0;g._start_stage()
					check(g.money==g.dig_cost*int(value),"Reserve next-stage funds")
	fixture("domain",3)
	g._new_run()
	check(g.augment_levels.is_empty(),"New run resets levels")
	print("Finished %d level checks with %d failures" % [checks,failures])
	quit(failures)
