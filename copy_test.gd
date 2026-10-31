extends SceneTree
func _initialize():
	var copy=load("res://augment_copy.gd")
	var failures=0
	var checks=0
	for id in copy.Catalog.ALL:
		checks+=1
		if copy.summary(id).contains("Lv.") or copy.summary(id).contains("레벨"):
			failures+=1
			push_error("Summary leaks levels: "+id)
		checks+=1
		if copy.kind(id).is_empty(): failures+=1
		if copy.Levels.DATA.has(id):
			for level in range(1,5):
				checks+=1
				if not copy.level_table(id).contains("Lv.%d"%level): failures+=1
	print("COPY CHECKS ",checks," failures ",failures)
	quit(failures)
