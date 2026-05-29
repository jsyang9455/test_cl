# 이상치 탐지 결과 v2 (iPhone 15 Pro Max 제외)

## 초기(v1) vs v2 비교
| 지표 | v1 (전체) | v2 (iPhone 제외) | 변화 |
|------|-----------|-----------------|------|
| 전체 행 수 | 1,000 | 982 | -18 |
| 이상치 행 수 | 438 (43.8%) | 421 (42.9%) | -17 |

## 컬럼별 이상치 수 비교
| 컬럼 | v1 | v2 | 변화 | v2 정상 범위 |
|------|-----|-----|------|-------------|
| final_price | 220 | 208 | -12 | -24,268 ~ 40,480 |
| rating | 94 | 94 | +0 | 5 ~ 5 |
| reviews | 148 | 143 | -5 | -427 ~ 733 |
| number_sold | 157 | 152 | -5 | -1,260 ~ 2,128 |
| gmv | 138 | 129 | -9 | -3,606,735 ~ 6,016,841 |

## 이상치 대표 사례 상위 5개 (final_price 기준, v2)
| 상품명 | final_price | gmv | 이상치 컬럼 |
|--------|------------|-----|------------|
| Laptop HP Spectre x360 2 in 1 Intel | 29,649,000 | 0 | final_price |
| Laptop HP Spectre x360 2 in 1 Intel | 27,899,000 | 0 | final_price |
| Victus Laptop Gaming HP AMD Ryzen 7 | 26,299,000 | 0 | final_price |
| Victus Laptop Gaming HP AMD Ryzen 7 | 26,299,000 | 0 | final_price |
| Laptop HP Envy x360 2 in 1 AMD Ryze | 22,399,000 | 0 | final_price |
