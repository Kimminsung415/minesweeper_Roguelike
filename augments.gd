extends RefCounted

const ACTIVE = "active"
const PASSIVE = "passive"
const DEBUFF = "debuff"

# IDs are stable save/test keys. Descriptions also document the first-version rulings.
const ALL = {
	"domain": {"name": "영역전개", "kind": ACTIVE, "target": true, "description": "선택한 3×3의 안전 칸 공개 + 지뢰 자동 정산. 영역 밖 연쇄 없음. 신관 부작용 적용."},
	"hound": {"name": "지뢰탐지견", "kind": ACTIVE, "target": false, "description": "미공개·미정산 지뢰 최대 2개를 무작위로 자동 정산. 은신지뢰 포함. 신관 부작용 적용."},
	"scanner": {"name": "정밀 스캐너", "kind": ACTIVE, "target": true, "description": "선택한 5×5의 미확정 지뢰 총개수만 표시. 위치·타일 공개 없음. 은신지뢰 포함."},
	"safe_dig": {"name": "안전 굴착", "kind": ACTIVE, "target": true, "description": "미공개 칸 하나를 무료 확인. 안전하면 연쇄 공개, 지뢰면 피해·골드 없이 확정. Commit 부작용 없음."},
	"survey": {"name": "지질 탐사", "kind": ACTIVE, "target": false, "description": "미공개 안전 칸 최대 3개 무작위 공개. 연쇄 공개 없음."},
	"shield": {"name": "방폭 태세", "kind": ACTIVE, "target": false, "description": "다음 유효한 직접 파기의 지뢰 피해 무효. 안전 칸을 파도 소모. 파기 비용·지반 피해는 정상."},
	"transfusion": {"name": "긴급 수혈", "kind": ACTIVE, "target": false, "description": "HP 3 회복. 최대 HP 제한. 체력이 가득 차면 사용하지 않음."},
	"grant": {"name": "비상 지원금", "kind": ACTIVE, "target": false, "description": "현재 실제 파기 비용 4회분 골드 획득."},
	"audit": {"name": "깃발 감수", "kind": ACTIVE, "target": false, "description": "미검증 오답 깃발 최대 3개 제거. 타일 공개·정산·피해 없음."},
	"acceleration": {"name": "작업 가속", "kind": ACTIVE, "target": false, "description": "다음 유효한 직접 파기 4회 무료. 피해·파기 횟수 정상. 알뜰 굴착과 겹쳐도 횟수 소모."},
	"vitality": {"name": "생명력 주입", "kind": ACTIVE, "target": false, "description": "이번 스테이지 최대 HP +2, 현재 HP +2. 다음 스테이지에는 최대 HP 보너스가 사라짐. 회복 저하에는 영향받지 않음."},
	"blood_trade": {"name": "혈액 거래", "kind": ACTIVE, "target": false, "description": "HP 2를 지불하고 현재 파기 비용 6회분의 골드 획득. HP 3 이상일 때만 사용. 피해 감소·정산 보험 미적용."},
	"insurance": {"name": "정산 보험", "kind": ACTIVE, "target": false, "description": "다음 유효한 수동 Commit 1회의 총 오답 피해 50% 감소(올림). 정답만 정산해도 소모. 신관·자동 정산에는 미적용."},
	"shock": {"name": "충격 흡수 기관", "kind": PASSIVE, "description": "스테이지당 첫 직접 지뢰 피해 후 생존 시 HP 3 회복. 치명상을 단독으로 막지 못함."},
	"dividend": {"name": "폭발 배당", "kind": PASSIVE, "description": "스테이지당 첫 직접 지뢰 폭발 후 생존하면 보유 골드 2배. 파기 비용·잔해 회수 후 계산."},
	"regeneration": {"name": "재생 세포", "kind": PASSIVE, "description": "유효한 직접 파기 6회마다 생존 시 HP 1 회복. 카운터는 스테이지마다 초기화."},
	"revival": {"name": "부활권", "kind": PASSIVE, "description": "런 전체 1회, 치명적 피해 후 HP 4로 부활. 최대 HP 제한. 사용 뒤에도 다시 선택 불가."},
	"echo": {"name": "공명 곡괭이", "kind": PASSIVE, "description": "직접 안전 파기 시 무작위 안전 칸 1개 추가 공개. 스테이지당 4회. 추가 칸 연쇄·재발동 없음."},
	"decontamination": {"name": "사전 제독", "kind": PASSIVE, "description": "이후 스테이지 생성 지뢰 2개 감소. 최소 1개. 정산 가능한 수입도 감소."},
	"armor": {"name": "방폭복", "kind": PASSIVE, "description": "직접 지뢰 피해 1 감소, 최소 피해 1. 오답 Commit·신관·지반 피해에는 미적용."},
	"artisan": {"name": "정산 장인", "kind": PASSIVE, "description": "한 Commit에서 오답 없이 3개 이상 정답이면 지뢰 1개분 추가 수입. 자동 Commit에도 적용."},
	"frugal": {"name": "알뜰 굴착", "kind": PASSIVE, "description": "매 스테이지 첫 유효한 직접 파기 3회 무료. 보드 생성 전 첫 파기에도 적용."},
	"salvage": {"name": "잔해 회수", "kind": PASSIVE, "description": "직접 폭발시킨 지뢰에서 정상 정산 보상의 50% 획득(내림). 재정산 불가."},
	"heart": {"name": "강화 심장", "kind": PASSIVE, "description": "획득 후 다음 스테이지부터 최대 HP +3. 처음 적용될 때 현재 HP도 +3. 현재 HP 증가는 1회만 적용."},
	"medic": {"name": "야전 의무관", "kind": PASSIVE, "description": "스테이지 클리어 시 생존하면 HP 1 자동 회복. 골드/회복 선택과 별도 적용. 최종 클리어에도 적용."},
	"reserve": {"name": "비상 저금통", "kind": PASSIVE, "description": "스테이지 시작 시 골드가 현재 파기 비용 3회분 미만이면 그 금액까지 보충. 스테이지당 1회. 상점 소비 후에는 재보충하지 않음."},
	"stealth": {"name": "은신지뢰", "kind": DEBUFF, "description": "지뢰 1개를 숫자에 집계되지 않는 은신지뢰로 전환. 연쇄 공개는 건너뜀. 액티브로 탐지 가능."},
	"high_explosive": {"name": "고폭약", "kind": DEBUFF, "description": "직접 지뢰 폭발과 오답 Commit의 지뢰당 피해 +1. 방폭복·방폭 태세는 직접 폭발에만 적용."},
	"fuse": {"name": "불안정한 신관", "kind": DEBUFF, "description": "정답 지뢰 Commit마다 20% 확률로 HP 1 피해. 보상 정상. 영역전개·탐지견 자동 정산에도 적용."},
	"weakness": {"name": "쇠약", "kind": DEBUFF, "description": "다음 스테이지부터 최대 HP -2(최소 1). 현재 HP가 새 최대치를 넘으면 감소."},
	"overcrowding": {"name": "과밀 매설", "kind": DEBUFF, "description": "이후 스테이지 지뢰 +3. 밀도 25% 상한과 첫 파기 안전 구역 유지."},
	"dig_tax": {"name": "굴착세", "kind": DEBUFF, "description": "직접 파기 비용 +1. 지뢰 기본 정산 보상은 늘지 않음. 무료 파기로 대응 가능."},
	"reward_cut": {"name": "보상 삭감", "kind": DEBUFF, "description": "지뢰 정산 보상 25% 감소(내림), 최소 1골드. 잔해 회수·정산 장인도 줄어든 보상 기준."},
	"interference": {"name": "통신 장애", "kind": DEBUFF, "description": "수동 Commit은 미검증 깃발 3개 이상 필요. 남은 미공개·미정산 칸이 3개 미만이면 예외. 자동 정산은 가능."},
	"instrument": {"name": "계측기 고장", "kind": DEBUFF, "description": "숫자 타일의 10%를 ?로 표시(내림). 실제 인접 수·스캐너 계산은 유지."},
	"unstable_ground": {"name": "불안정 지반", "kind": DEBUFF, "description": "매 6번째 유효한 직접 파기마다 HP 1 피해. 무료 직접 파기 포함. 액티브·연쇄 공개 제외."},
	"healing_loss": {"name": "회복 저하", "kind": DEBUFF, "description": "모든 일반 회복량 -1, 최소 1. 최대 HP 증가와 그에 따른 현재 HP 증가, 부활권에는 미적용."},
	"settlement_fee": {"name": "정산 수수료", "kind": DEBUFF, "description": "정답이 있는 Commit마다 현재 파기 비용 1회분을 총보상에서 차감. 보상 최소 0. 자동 Commit에도 적용, 안전 확정·잔해 회수에는 미적용."},
}

static func pool(kind: String, excluded: Array) -> Array:
	var result = []
	for id in ALL:
		if id in excluded:
			continue
		if (kind == "buff" and ALL[id]["kind"] != DEBUFF) or ALL[id]["kind"] == kind:
			result.append(id)
	return result

static func kind_label(kind: String) -> String:
	return {ACTIVE: "액티브", PASSIVE: "패시브", DEBUFF: "디버프"}.get(kind, kind)
