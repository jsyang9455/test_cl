# 이상치 탐지 결과 (IQR 방식)

- 분석 대상: 1,000행
- 이상치 탐지 행 수: 438행 (43.8%)

## 컬럼별 이상치 수
| 컬럼 | 이상치 수 | 정상 범위 |
|------|----------|----------|
| final_price | 220 | -24,266 ~ 40,480 |
| rating | 94 | 5 ~ 5 |
| reviews | 148 | -424 ~ 732 |
| number_sold | 157 | -1,262 ~ 2,134 |
| gmv | 138 | -4,052,123 ~ 6,759,914 |

## 이상치 대표 사례 (final_price 상위 5개)
| 상품명 | final_price | gmv | 이상치 컬럼 |
|--------|------------|-----|------------|
| Apple iPhone 15 Pro Max | 31,249,000 | 6,187,302,000 | final_price|gmv |
| Apple iPhone 15 Pro Max | 31,249,000 | 6,187,302,000 | final_price|gmv |
| Apple iPhone 15 Pro Max | 31,249,000 | 6,187,302,000 | final_price|gmv |
| Apple iPhone 15 Pro Max | 31,249,000 | 6,187,302,000 | final_price|gmv |
| Laptop HP Spectre x360 2 in 1 Intel | 29,649,000 | 0 | final_price |
