import csv, json
from collections import Counter

INPUT    = r'C:\Users\HP\test_cl\data\lazada-products-clean.csv'
OUT_CSV  = r'C:\Users\HP\test_cl\data\lazada-categories.csv'
OUT_RPT  = r'C:\Users\HP\test_cl\data\category-report.md'

with open(INPUT, encoding='utf-8') as f:
    rows = list(csv.DictReader(f))

cat1_counter = Counter()
cat2_counter = Counter()
enriched = []

for r in rows:
    raw = r.get('breadcrumb', '') or ''
    cat1, cat2 = '', ''
    try:
        parts = json.loads(raw)
        if isinstance(parts, list):
            cat1 = parts[0] if len(parts) > 0 else ''
            cat2 = parts[1] if len(parts) > 1 else ''
    except:
        pass
    r['category_1'] = cat1
    r['category_2'] = cat2
    if cat1: cat1_counter[cat1] += 1
    if cat2: cat2_counter[cat2] += 1
    enriched.append(r)

fieldnames = list(rows[0].keys()) + ['category_1', 'category_2']
with open(OUT_CSV, 'w', newline='', encoding='utf-8') as f:
    writer = csv.DictWriter(f, fieldnames=fieldnames)
    writer.writeheader()
    writer.writerows(enriched)

top1 = cat1_counter.most_common(10)
top2 = cat2_counter.most_common(10)

lines = ["# 카테고리 분류 결과\n",
         f"- 전체 상품 수: {len(enriched):,}\n",
         f"- 대분류 종류: {len(cat1_counter)}\n",
         f"- 소분류 종류: {len(cat2_counter)}\n\n",
         "## 상위 10개 대분류\n",
         "| 순위 | 대분류 | 상품 수 |\n|------|--------|--------|\n"]
for i,(k,v) in enumerate(top1,1):
    lines.append(f"| {i} | {k} | {v} |\n")
lines += ["\n## 상위 10개 소분류\n",
          "| 순위 | 소분류 | 상품 수 |\n|------|--------|--------|\n"]
for i,(k,v) in enumerate(top2,1):
    lines.append(f"| {i} | {k} | {v} |\n")

with open(OUT_RPT, 'w', encoding='utf-8') as f:
    f.writelines(lines)

print('완료:', OUT_CSV)
print('리포트:', OUT_RPT)
print('대분류 top3:', top1[:3])
