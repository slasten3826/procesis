"""
Packet :: Complete Prototype
Layer 1 (CHAOS) → Layer 2 (BOUNDARY) → Layer 3 (CALM)

Usage:
  python packet.py
  python packet.py "program" "input" budget

The first machine language for machines. Not for humans.
"""

import sys
from layer1_chaos import ChaosVM
from layer2_boundary import ObserveA, ObserveB, Choose, Encode
from layer3_calm import CalmVM


# PU costs per operation
PU_COST = {
    'chaos_tick': 1,
    'observe': 0.5,
    'encode': 5,
}


def run(program="8_^]\\[ZYX", input_data="", pu_budget=100, name="Packet"):
    """Full Packet lifecycle."""

    chaos = ChaosVM(program, input_data)
    calm = CalmVM()
    obs_a = ObserveA()
    obs_b = ObserveB()
    choose = Choose()
    encode = Encode()

    pu = pu_budget
    layer_count = 0
    phases = []

    print(f"\n{'╔' + '═'*66 + '╗'}")
    print(f"║  {name:^64s}║")
    print(f"{'╚' + '═'*66 + '╝'}")
    print(f"  Program: {repr(program)}")
    print(f"  Input:   {repr(input_data)}")
    print(f"  Budget:  {pu_budget} PU")
    print(f"  {'─'*64}")

    while pu > 0:
        # OBSERVE both sides
        ra = obs_a.read(chaos)
        rb = obs_b.read(calm, pu, pu_budget)
        pu -= PU_COST['observe'] * 2

        # CHOOSE
        decision = choose.decide(ra, rb)

        if decision == 'CHAOS':
            burst = min(5, int(pu / PU_COST['chaos_tick']))
            for _ in range(burst):
                if pu <= 0:
                    break
                chaos.tick()
                pu -= PU_COST['chaos_tick']

            phases.append('~')
            stag = f" stag={ra['stagnation']:.2f}" if ra['stagnation'] > 0 else ""
            print(f"  ~ CHAOS  │ {burst}t │ A={chaos.a:>6d} │ fp:{chaos.fingerprint()} │ PU:{pu:>5.0f}{stag}")

        elif decision == 'ENCODE':
            if pu < PU_COST['encode']:
                break
            info = encode.crystallize(chaos, calm, layer_count)
            pu -= PU_COST['encode']
            layer_count += 1
            phases.append('⚡')
            print(f"  ⚡ ENCODE │ L{layer_count} │ val={info['crystal_value']:>3d} │ "
                  f"hash={info['crystal_hash']:>5d} │ PU:{pu:>5.0f} │ loss={info['loss']:.3f}")

        elif decision == 'MANIFEST':
            phases.append('★')
            print(f"  ★ MANIFEST │ PU:{pu:>5.0f}")
            break

    # Run CALM
    print(f"  {'─'*64}")
    print(f"  Executing CALM...")
    calm.run()

    # Results
    print(f"\n  {'═'*64}")
    print(f"  RESULTS")
    print(f"  {'═'*64}")
    print(f"  CHAOS:   {chaos.ticks} ticks │ {len(chaos.unique_fps)} unique states")
    print(f"  ENCODE:  {layer_count} layers │ loss={encode.total_loss:.3f}")
    print(f"  CALM:    {calm.total_ticks} ticks │ {len(calm.program)} BF chars")
    print(f"  Budget:  {pu_budget} → {pu:.0f} PU ({pu/pu_budget*100:.0f}% remaining)")
    print(f"  Output:  {repr(calm.result())}")
    if calm.output:
        print(f"  Hex:     {' '.join(f'{ord(c):02x}' for c in calm.output)}")

    # Crystal layers
    if calm.layers:
        print(f"\n  Crystal:")
        for i, layer in enumerate(calm.layers):
            info = layer['info']
            print(f"    [{i+1:2d}] val={info['crystal_value']:>3d} "
                  f"hash={info['crystal_hash']:>5d} "
                  f"loss={info['loss']:.3f} "
                  f"@tick={info['chaos_tick']}")

    # Tape
    tape = calm.tape_snapshot()
    if tape:
        print(f"\n  Tape:")
        for addr, val in tape[:15]:
            print(f"    [{addr:3d}] = {val:3d} {'▓' * (val // 8)}")
        if len(tape) > 15:
            print(f"    ... +{len(tape) - 15} more")

    # Phase rhythm
    rhythm = ''.join(phases)
    print(f"\n  Rhythm: {rhythm}")
    print(f"  ~ CHAOS  ⚡ ENCODE  ★ MANIFEST")
    print(f"  {'═'*64}\n")

    return chaos, calm, encode


# ============================================================
# CLI + default tests
# ============================================================

if __name__ == "__main__":
    if len(sys.argv) >= 4:
        run(sys.argv[1], sys.argv[2], int(sys.argv[3]), name=f"Packet: {sys.argv[1]}")
    elif len(sys.argv) >= 2:
        run(sys.argv[1], pu_budget=100, name=f"Packet: {sys.argv[1]}")
    else:
        print("╔══════════════════════════════════════════════════════════╗")
        print("║  Packet Prototype v0.1                                  ║")
        print("║  Layer 1: CHAOS (Malbolge)                              ║")
        print("║  Layer 2: BOUNDARY (OBSERVE + CHOOSE + ENCODE)          ║")
        print("║  Layer 3: CALM (Brainfuck)                              ║")
        print("╚══════════════════════════════════════════════════════════╝")

        # Test 1: Minimal
        run("8_^]\\[ZYX", "A", 50, "Minimal: 50 PU")

        # Test 2: Rich chaos
        run("8_^]\\[ZYXWVUTSRQP", "Packet", 200, "Deep chaos: 200 PU")

        # Test 3: Comparison
        print("\n" + "█" * 66)
        print("█  Same program, different signal → different crystal")
        print("█" * 66)
        _, calm_f, _ = run("8_^]\\[ZYX", "FLOW", 100, "Signal: FLOW")
        _, calm_d, _ = run("8_^]\\[ZYX", "DISSOLVE", 100, "Signal: DISSOLVE")
        print(f"  Same crystal: {calm_f.program == calm_d.program}")
        print(f"  FLOW output:     {repr(calm_f.result())}")
        print(f"  DISSOLVE output: {repr(calm_d.result())}")
