# Tower of Hanoi AI Demonstration

Godot 4.7.1, GDScript, Compatibility renderer. Run `node_2d.tscn` (F6) or the project (F5).

## Modes

- Manual: click a tower's top disk, then the destination tower. Only legal moves apply.
- AI Visual: Start, Pause, Resume, Stop, or Step One Move. Solves the current board
  optimally without resetting manual progress. Speed is seconds/move; zero means
  at most one actual move per rendered frame. Animation runs at speeds >= 0.05 seconds.
- Ultra Simulation: samples the exact optimal A-to-C path from the standard starting
  board. Jump accepts an exact integer from 0 through the total, including 31-digit
  indices. Switching from a manual board to Ultra resets to the standard start.

For the 100-disk experiment, select Ultra Simulation, click
`100 DISK - 24 HOUR SIMULATION`, then Start AI. Alternatively set a disk count,
choose 1 minute / 1 hour / 1 Day / Custom, and Start AI. Real uses the visual
seconds/move setting but still samples mathematical states.

The experiment lasts 24 hours of active time; Pause excludes paused time.
Jump and Final Move work immediately. Tower State shows every disk, bottom to top.
Custom durations range from 0.001 seconds to 1,000 days.

## Exact Arithmetic and Algorithm

`hanoi_solver.gd` uses nonnegative decimal-string integers. Move counts never use
floats or int64. Query `get_hanoi_move(index, disks)` / `get_move_at(index, disks)`
with a 1-based decimal string. `state_at(index, disks)` uses the number of completed
moves, where zero means the initial board.

For move k, disk = trailing zero bits of k + 1. Each disk's direction depends on
the parity of disk count minus disk number. After k moves, disk d has moved
floor(k / 2^d) + bit(d - 1, k) times. Its position is that count times direction,
modulo three. Direct queries do not replay any earlier moves.

Binary conversion uses bounded decimal long division, followed by a linear scan
of the bits. Storage is O(n); digit arithmetic makes conversion O(n^2) in bit
width, bounded to 100 disks. Ultra refreshes at 10 Hz. No list of all moves is
allocated. Manual-board continuation uses an O(n)-space lazy task stack.

Time is sampled in integer microseconds. For duration T and elapsed time t,
index = floor(total * t / T), computed with exact integer multiplication/division.
Progress displays a truncated exact percentage with nine decimal places.
Time and ETA displays are rounded; very long ETAs use scientific notation.

## Verification

Click Verify AI to compare every move and state against a separate recursive
reference for 1-15 disks. Verification runs on a worker so the interface remains
responsive. It also checks known totals, first/middle/final transitions, largest
disk midpoint structures and exact half/full-day indices for 32, 64 and 100 disks.

Run automated tests with Godot:

```text
godot --headless --path <project-directory> --script res://tests/verify_simulation.gd
godot --headless --path <project-directory> --script res://tests/verify_optimal.gd
godot --path <project-directory> --script res://tests/ui_smoke.gd
```

The BFS regression compares shortest paths from all 363 legal boards with 1-5
disks. The integration test covers manual/visual, exact jumps, 100 disks, duration
presets, pause/resume, final state and invalid-move handling. The graphical test
uses viewport mouse input, checks actual rendering and exports screenshots.

Every AI move is validated before applying it. Invalid moves stop execution and
open a report with move index, disk, source/destination and all three towers.

## Limits

100 disks require exactly 1,267,650,600,228,229,401,496,703,205,375 moves from the
initial board. Finishing in one day is mathematical fast-forward, not evidence
that the CPU executed every intermediate move. Actual executed and mathematically
simulated counts are displayed separately. Frame sampling skips intermediate
states; the displayed state's index and all disk positions remain exact.

From an arbitrary manually played board, the remaining optimal count generally
differs from 2^n - 1; that formula applies to the standard initial tower transfer.
The interface uses a fixed 1200 x 900 viewport scaled to the window; UI labels are
English. The graphical smoke test's screenshot destination is this workspace.
