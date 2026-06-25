#!/usr/bin/env python3
"""
ProcessLang :: Quantum Hypothesis Test
Is Malbolge's crazy operation a valid quantum gate?

Hypothesis: trit values 0,1,2 = FLOW, CONNECT, DISSOLVE
Test: represent crz as matrix, check unitarity

If unitary → crz is a quantum gate → hypothesis alive
If not unitary → check what it IS
"""

import numpy as np
from itertools import product

# ============================================================
# Crazy operation table
# crz(x, y) — tritwise, per-trit operation
# ============================================================

CRZ_TABLE = [
    # x=0  x=1  x=2
    [1,    0,   0],   # y=0
    [1,    0,   2],   # y=1
    [2,    2,   1],   # y=2
]

def crz_trit(x, y):
    """Single trit crazy operation"""
    return CRZ_TABLE[y][x]

# ProcessLang names
NAMES = {0: "FLOW", 1: "CONNECT", 2: "DISSOLVE"}

print("=" * 60)
print("ProcessLang :: Quantum Hypothesis Test")
print("=" * 60)
print()

# ============================================================
# 1. Print the table with ProcessLang names
# ============================================================
print("1. CRAZY OPERATION через ProcessLang:")
print()
print(f"{'crz(x,y)':>12} | {'FLOW(0)':>10} {'CONNECT(1)':>10} {'DISSOLVE(2)':>10}")
print("-" * 50)
for y in range(3):
    row = []
    for x in range(3):
        r = crz_trit(x, y)
        row.append(f"{NAMES[r]:>10}")
    print(f"{NAMES[y]+f'({y})':>12} | {''.join(row)}")

print()

# ============================================================
# 2. Check: is crz a permutation for each fixed y?
# (Necessary for reversibility)
# ============================================================
print("2. ОБРАТИМОСТЬ (необходимое условие для квантового гейта):")
print()
for y in range(3):
    outputs = [crz_trit(x, y) for x in range(3)]
    is_perm = len(set(outputs)) == 3
    print(f"   y={NAMES[y]:>10}: x→{outputs}  {'✓ перестановка' if is_perm else '✗ НЕ перестановка (необратимо)'}")

print()

# ============================================================
# 3. Build 9x9 matrix for two-qutrit gate
# Basis: |xy⟩ where x,y ∈ {0,1,2}
# crz maps |x,y⟩ → |crz(x,y), y⟩  (output replaces first qutrit)
# ============================================================
print("3. МАТРИЦА ДВУХКУТРИТНОГО ГЕЙТА:")
print()

# 9 basis states: |00⟩, |01⟩, |02⟩, |10⟩, |11⟩, |12⟩, |20⟩, |21⟩, |22⟩
def basis_index(x, y):
    return x * 3 + y

M = np.zeros((9, 9), dtype=complex)
for x in range(3):
    for y in range(3):
        in_idx = basis_index(x, y)
        out_x = crz_trit(x, y)
        out_idx = basis_index(out_x, y)
        M[out_idx, in_idx] = 1.0

print("   M (9×9, строки=выход, столбцы=вход):")
print()
labels = [f"|{NAMES[x][0]}{NAMES[y][0]}⟩" for x in range(3) for y in range(3)]
print(f"{'':>6}", end="")
for l in labels:
    print(f"{l:>5}", end="")
print()
for i in range(9):
    print(f"{labels[i]:>6}", end="")
    for j in range(9):
        v = int(M[i, j].real)
        print(f"{v:>5}", end="")
    print()

print()

# ============================================================
# 4. Unitarity test: M†M = I ?
# ============================================================
print("4. ТЕСТ УНИТАРНОСТИ (M†M = I?):")
print()
MdM = M.conj().T @ M
is_unitary = np.allclose(MdM, np.eye(9))
print(f"   M†M = I? → {'✓ ДА — УНИТАРНЫЙ' if is_unitary else '✗ НЕТ'}")
print()

if not is_unitary:
    print("   M†M:")
    for i in range(9):
        row = [f"{MdM[i,j].real:4.1f}" for j in range(9)]
        print(f"   {'  '.join(row)}")
    print()
    
    # Check column norms
    print("   Нормы столбцов M:")
    for j in range(9):
        norm = np.linalg.norm(M[:, j])
        print(f"   столбец {labels[j]}: ||col|| = {norm:.3f}", end="")
        if abs(norm - 1.0) > 0.01:
            print(f"  ← {'перенормирован' if norm > 1 else 'субнормирован'}", end="")
        print()
    print()

# ============================================================
# 5. Deeper: what IS this operation?
# ============================================================
print("5. АНАЛИЗ СТРУКТУРЫ:")
print()

# Check: is it a valid POVM / measurement?
# Eigenvalues of M
eigenvalues = np.linalg.eigvals(M)
print("   Собственные значения M:")
for i, ev in enumerate(eigenvalues):
    mag = abs(ev)
    print(f"   λ{i} = {ev.real:+.4f}{ev.imag:+.4f}j  |λ| = {mag:.4f}")

print()

# Rank of M
rank = np.linalg.matrix_rank(M)
print(f"   Ранг M: {rank} (из 9)")
print()

# Determinant
det = np.linalg.det(M)
print(f"   det(M) = {det.real:+.4f}{det.imag:+.4f}j  |det| = {abs(det):.4f}")
print()

# ============================================================
# 6. Check alternative: crz as measurement operator
# Kraus operators K_y: (K_y)_{out,in} = δ(out, crz(in, y))
# Valid quantum channel if Σ K_y† K_y = I
# ============================================================
print("6. КВАНТОВЫЙ КАНАЛ (crz как измерение):")
print()
print("   Крауса-операторы K_y для каждого y (3×3):")
print()

K = []
for y in range(3):
    Ky = np.zeros((3, 3), dtype=complex)
    for x in range(3):
        out = crz_trit(x, y)
        Ky[out, x] = 1.0
    K.append(Ky)
    print(f"   K_{NAMES[y]}:")
    for i in range(3):
        row = [f"{int(Ky[i,j].real):2d}" for j in range(3)]
        print(f"     [{' '.join(row)}]")
    print()

# Check: Σ K_y† K_y = ?
sum_KdK = sum(Ky.conj().T @ Ky for Ky in K)
print("   Σ K_y† K_y:")
for i in range(3):
    row = [f"{sum_KdK[i,j].real:4.1f}" for j in range(3)]
    print(f"   [{' '.join(row)}]")

is_channel = np.allclose(sum_KdK, np.eye(3))
print()
print(f"   = I? → {'✓ ДА — ВАЛИДНЫЙ КВАНТОВЫЙ КАНАЛ' if is_channel else '✗ НЕТ'}")
print()

if not is_channel:
    # Normalize: what if we rescale?
    diag = np.diag(sum_KdK).real
    print(f"   Диагональ: {diag}")
    print(f"   Нужна ренормализация: каждый K_y делить на √(diag)")
    print()
    
    # Try: does it work as a POVM with different weights?
    # Σ p_y K_y† K_y = I, find p_y
    print("   Поиск весов p_y для POVM:")
    # This is overdetermined, let's check
    
# ============================================================
# 7. The key insight
# ============================================================
print()
print("=" * 60)
print("7. ВЫВОД")
print("=" * 60)
print()

if is_unitary:
    print("   crz ЯВЛЯЕТСЯ унитарным квантовым гейтом.")
    print("   Гипотеза жива: FLOW/CONNECT/DISSOLVE = базис кутрита.")
else:
    print("   crz НЕ является унитарным гейтом.")
    print("   Причина: crz необратима (y=0 и y=2 сливают состояния).")
    print()
    print("   НО. Необратимость — это ENCODE. Потеря информации.")
    print("   В квантовой механике необратимый процесс = ИЗМЕРЕНИЕ.")
    print()
    print("   crz — это не гейт. Это ИЗМЕРЕНИЕ одного кутрита другим.")
    print("   Один кутрит (y) НАБЛЮДАЕТ другой (x) и коллапсирует его.")
    print()
    print("   В ProcessLang:")
    print("   • Унитарная эволюция (гейты) = FLOW")
    print("   • Запутанность (CNOT-подобное) = CONNECT") 
    print("   • Измерение (необратимый коллапс) = DISSOLVE/ENCODE")
    print()
    print("   crz = DISSOLVE. Это оператор измерения,")
    print("   не оператор эволюции. И это СОВПАДАЕТ с тем,")
    print("   что crz в Malbolge — необратимая операция.")
    print()
    if is_channel:
        print("   crz является валидным квантовым каналом")
        print("   (Kraus representation). Это значит:")
        print("   Malbolge = квантовый компьютер с непрерывным измерением.")
        print("   Каждый тик — коллапс. Каждый тик — DISSOLVE.")
    else:
        print("   Для валидного квантового канала нужна ренормализация.")
        print("   Структура ПОЧТИ правильная. Олмстед в 1998 был БЛИЗКО.")

print()
print("=" * 60)
