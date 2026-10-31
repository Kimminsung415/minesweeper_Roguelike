extends RefCounted
const Catalog = preload("res://augments.gd")
const Levels = preload("res://upgrade_rules.gd")

static func kind(id: String) -> String:
	var item = Catalog.ALL[id]
	if item.get("one_shot",false):
		return "일회용 · 즉시 사용" if item.get("immediate",false) else "일회용"
	return Catalog.kind_label(item["kind"])

static func summary(id: String) -> String:
	var overrides = {
		"gamble": "골드가 무작위 0.5~2배로 변합니다.",
		"communism": "모든 보유 액티브·패시브의 성능을 하나로 통일합니다.",
		"reroll": "앞으로 증강 선택 화면에서 슬롯마다 1회 리롤할 수 있습니다.",
		"recycle": "소모한 일회용 카드를 2스테이지마다 다시 사용할 수 있습니다. 부활권 제외.",
		"smith": "모든 강화 비용이 절반이 됩니다. 자신의 강화에도 적용됩니다.",
		"genius": "무작위 보유 버프 하나를 최고 성능으로 만듭니다."
	}
	return overrides.get(id,Catalog.ALL[id]["description"])

static func level_table(id: String) -> String:
	if not Levels.DATA.has(id): return ""
	var result = "레벨별 효과"
	for level in range(1,5):
		var effect = Levels.describe(id,level)
		if id == "gamble": effect = "골드 ×%s~%s" % [str([0.5,0.6,0.7,0.8][level-1]),str([2.0,2.1,2.2,2.2][level-1])]
		if id == "decontamination": effect += " · 제거 지뢰 수 × 정산 보상 지원금"
		result += "\nLv.%d · %s" % [level,effect]
	return result

static func details(id: String, level: int = 1) -> String:
	var result = "[%s] %s\n\n%s" % [kind(id),Catalog.ALL[id]["name"],Catalog.ALL[id]["description"]]
	if Levels.DATA.has(id):
		result += "\n\n현재/획득 Lv.%d\n%s" % [level,level_table(id)]
	return result
