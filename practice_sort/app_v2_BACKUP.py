def calculate_total(items):
    total = 0
    for item in items:
        total += item['price'] * item['qty']
    return total

def apply_discount(total, rate):
    return total * (1 - rate)

# 테스트
cart = [
    {'name': '노트북', 'price': 1200000, 'qty': 1},
    {'name': '마우스', 'price': 35000, 'qty': 2},
]
print(apply_discount(calculate_total(cart), 0.1))
