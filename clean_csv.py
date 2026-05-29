import csv, json, os

INPUT  = r'C:\Users\HP\test_cl\data\lazada-products.csv'
OUTPUT = r'C:\Users\HP\test_cl\data\lazada-products-clean.csv'
REPORT = r'C:\Users\HP\test_cl\data\clean-report.md'

with open(INPUT, encoding='utf-8') as f:
    reader = csv.DictReader(f)
    rows = list(reader)

total = len(rows)
stats = {'duplicates': 0, 'rating_invalid': 0, 'missing_filled': 0}

# 중복 제거 (url 기준)
seen = set()
deduped = []
for r in rows:
    url = r.get('url','')
    if url not in seen:
        seen.add(url)
        deduped.append(r)
    else:
        stats['duplicates'] += 1

# 타입 정규화 + 결측값 처리 + 이상 범위 제거
clean = []
numeric_cols = ['rating','reviews','initial_price','final_price','seller_ratings','seller_ship_on_time','seller_chat_response','number_sold','gmv']
for r in deduped:
    for col in numeric_cols:
        val = r.get(col,'')
        if val == '' or val is None:
            r[col] = '0'
            stats['missing_filled'] += 1
        else:
            try: float(val)
            except: r[col] = '0'; stats['missing_filled'] += 1
    rating = float(r['rating'])
    if rating < 0 or rating > 5:
        stats['rating_invalid'] += 1
        continue
    clean.append(r)

with open(OUTPUT, 'w', newline='', encoding='utf-8') as f:
    writer = csv.DictWriter(f, fieldnames=reader.fieldnames)
    writer.writeheader()
    writer.writerows(clean)

report = f"""# 데이터 정제 결과

## 요약
- 원본 행 수: {total:,}
- 중복 제거: {stats['duplicates']}건
- 평점 이상치 제거: {stats['rating_invalid']}건
- 결측값 처리: {stats['missing_filled']}건
- 최종 정제 행 수: {len(clean):,}

## 정제 기준
- url 기준 중복 제거
- rating 범위 초과(0 미만 또는 5 초과) 행 제거
- 수치형 컬럼 결측값 → 0으로 대체
"""

with open(REPORT, 'w', encoding='utf-8') as f:
    f.write(report)

print('완료:', OUTPUT)
print('리포트:', REPORT)
print(f'정제 결과: {total} → {len(clean)}행')
