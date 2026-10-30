extends RefCounted
const DATA = {
 "domain": [[1,2,3,4], "범위 반경 %s칸"],
 "scanner": [[2,3,4,5], "범위 반경 %s칸"],
 "safe_dig": [[0,1,2,3], "범위 반경 %s칸"],
 "hound": [[2,3,4,5], "지뢰 최대 %s개 자동 정산"],
 "survey": [[3,4,5,6], "안전 칸 %s개 공개"],
 "shield": [[1,2,3,4], "다음 직접 파기 %s회 방폭 (안전 파기도 소모)"],
 "transfusion": [[3,4,5,6], "HP %s 회복"],
 "grant": [[4,5,6,8], "파기 비용 %s회분 골드"],
 "audit": [[3,5,7,10], "오답 깃발 최대 %s개 제거"],
 "acceleration": [[4,5,6,8], "다음 직접 파기 %s회 무료"],
 "vitality": [[2,3,4,5], "이번 스테이지 최대·현재 HP +%s"],
 "blood_trade": [[6,8,10,12], "HP 2 지불 → 파기 비용 %s회분 골드"],
 "insurance": [[50,60,70,80], "다음 수동 Commit 오답 피해 %s%% 감소 (남는 피해 올림)"],
 "shock": [[3,4,5,6], "첫 직접 지뢰 피해 후 생존 시 HP %s 회복"],
 "dividend": [[2.0,2.25,2.5,3.0], "첫 직접 폭발 생존 후 골드 ×%s (내림)"],
 "regeneration": [[6,5,4,3], "직접 파기 %s회마다 HP 1 회복"],
 "revival": [[4,5,6,8], "런 전체 1회 HP %s로 부활 (횟수 재충전 없음)"],
 "echo": [[4,6,8,10], "안전 칸 1개 추가 공개, 스테이지 최대 %s회"],
 "decontamination": [[2,3,4,5], "다음 스테이지부터 지뢰 %s개 감소 (최소 1개)"],
 "armor": [[0,1,2,3], "직접 지뢰 피해 -1 유지 · 추가 최대 HP +%s"],
 "artisan": [[1.0,1.5,2.0,3.0], "오답 없는 3개 이상 Commit: 지뢰 보상 %s개분 추가 (내림)"],
 "frugal": [[3,4,5,6], "스테이지 첫 직접 파기 %s회 무료"],
 "salvage": [[50,65,80,100], "직접 폭발 지뢰 보상 %s%% 회수 (내림)"],
 "heart": [[3,4,5,6], "최대 HP +%s · 증가분만큼 현재 HP 증가"],
 "medic": [[1,2,3,4], "클리어 시 HP %s 회복"],
 "reserve": [[3,4,5,6], "다음 스테이지 시작 골드를 파기 비용 %s회분까지 보충"]
}
static func value(id: String, level: int):
 return DATA[id][0][clampi(level,1,4)-1] if DATA.has(id) else 0
static func describe(id: String, level: int) -> String:
 if not DATA.has(id): return "강화 불가"
 if id in ["domain","scanner","safe_dig"]:
  var side = int(value(id,level))*2+1
  return "%d×%d 범위" % [side,side]
 return DATA[id][1] % str(value(id,level))
