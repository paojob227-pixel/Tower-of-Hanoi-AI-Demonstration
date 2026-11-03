# Tower of Hanoi AI Demonstration

An advanced Tower of Hanoi puzzle simulator built with **Godot 4.7.1**, **GDScript**, and the **Compatibility Renderer**.

The project combines interactive gameplay, optimal AI solving, exact mathematical state computation, and large-scale simulation supporting up to 100 disks.

## Features

### 1. Manual Mode
- Click the top disk of a tower to select it.
- Click a destination tower to move the disk.
- Only legal Tower of Hanoi moves are accepted.
- Continue solving from the current board state.

### 2. AI Visual Mode
- Start, Pause, Resume, Stop, and Step One Move.
- Solves the current board optimally.
- Preserves manual progress instead of resetting the board.
- Adjustable animation speed.
- Zero-second speed executes at most one actual move per rendered frame.
- Animation is enabled at speeds of 0.05 seconds or higher.

### 3. Ultra Simulation Mode
- Mathematical simulation of the optimal A-to-C solution.
- Supports up to 100 disks.
- Exact integer-based Jump functionality.
- Supports indices containing up to 31 decimal digits.
- Samples mathematical states without allocating the entire move sequence.
- Ultra refreshes at 10 Hz.
- Displays every disk position and tower state.

### 4. 100-Disk, 24-Hour Experiment

The project includes a special 100-disk simulation experiment.

To run:

1. Select Ultra Simulation.
2. Click `100 DISK - 24 HOUR SIMULATION`.
3. Click Start AI.

Alternatively, select a disk count and choose a duration preset:
- 1 Minute
- 1 Hour
- 1 Day
- Custom

The experiment runs for 24 hours of active time. Paused time is excluded.

Additional controls:
- Jump to an exact simulation index.
- Final Move.
- Tower State inspection.
- Custom durations from 0.001 seconds to 1,000 days.

**Important:** This experiment uses mathematical fast-forwarding and state sampling. It does not physically execute every intermediate move.

## Exact Arithmetic and Algorithm

The solver is implemented in `hanoi_solver.gd`.

It uses nonnegative decimal-string integers instead of floating-point numbers or int64 for move-count arithmetic.

### Main Functions

```gdscript
get_hanoi_move(index, disks)
get_move_at(index, disks)
state_at(index, disks)
```

Move queries use a 1-based decimal-string index.

State queries use the number of completed moves:
- Index 0 represents the initial board.
- Each subsequent index represents a completed move.

### Mathematical Approach

For move k:

- The moved disk is determined by the trailing zero bits of k + 1.
- Each disk's direction depends on the parity of the disk count minus the disk number.
- The number of times disk d has moved after k moves is:

  `floor(k / 2^d) + bit(d - 1, k)`

- Its position is calculated from its movement count, direction, and modulo three.

Direct state queries do not replay previous moves.

### Performance Characteristics

- Binary conversion uses bounded decimal long division.
- Bit scanning is linear in the resulting bit width.
- Decimal digit arithmetic makes conversion O(n²) in bit width.
- Storage complexity is O(n).
- Maximum supported disk count is 100.
- No complete move list is allocated.
- Manual-board continuation uses an O(n)-space lazy task stack.

### Time and Progress Calculation

Time is sampled in integer microseconds.

For total duration T and elapsed time t:

`index = floor(total * t / T)`

The calculation uses exact integer multiplication and division.

Progress is displayed as a truncated exact percentage with nine decimal places.

Time and ETA displays use rounded values, with scientific notation for very long ETAs.

## Verification and Testing

The project includes independent verification and automated regression tests.

### Verify AI

The Verify AI function compares every move and state against a separate recursive reference implementation for 1–15 disks.

Verification runs on a worker to keep the interface responsive.

Additional checks include:
- Known optimal move totals.
- First, middle, and final transitions.
- Largest-disk midpoint structures.
- Exact half-day and full-day indices for 32, 64, and 100 disks.

### Automated Tests

Run the following commands using Godot:

```bash
godot --headless --path <project-directory> --script res://tests/verify_simulation.gd

godot --headless --path <project-directory> --script res://tests/verify_optimal.gd

godot --path <project-directory> --script res://tests/ui_smoke.gd
```

### Regression Coverage

- BFS regression compares shortest paths from all 363 legal boards with 1–5 disks.
- Integration testing covers manual and visual modes.
- Exact simulation jumps.
- 100-disk simulation.
- Duration presets.
- Pause and Resume.
- Final state verification.
- Invalid move handling.
- Graphical smoke testing with viewport mouse input.
- Actual rendering verification.
- Screenshot export.

Every AI move is validated before being applied.

Invalid moves stop execution and open a report containing:
- Move index.
- Disk number.
- Source tower.
- Destination tower.
- All three tower states.

## Limitations and Mathematical Notes

For 100 disks, the optimal solution requires exactly:

`1,267,650,600,228,229,401,496,703,205,375 moves`

Completing the 24-hour experiment does not mean the CPU executed every intermediate move.

The application displays actual executed moves and mathematically simulated moves separately.

Frame sampling skips intermediate states while preserving the exact mathematical index and disk positions of the displayed state.

For arbitrary manually played boards, the remaining optimal move count generally differs from `2^n - 1`. That formula applies to the standard initial tower transfer.

### Interface Limitations
- Fixed 1200 × 900 viewport scaled to the window.
- English UI labels.
- Graphical smoke-test screenshots are exported to the project workspace.

## Technology Stack

| Technology | Purpose |
|---|---|
| Godot 4.7.1 | Game engine |
| GDScript | Core implementation |
| Compatibility Renderer | Rendering backend |
| Recursive Reference Solver | Independent verification |
| BFS | Shortest-path regression |
| Decimal-string Arithmetic | Exact large-number computation |

## How to Run

1. Install Godot 4.7.1.
2. Open the project in Godot.
3. Run `node_2d.tscn` using F6, or run the entire project using F5.

## Project Goals

This project demonstrates how classical algorithms can be combined with interactive visualization and exact arithmetic to explore computational problems beyond ordinary integer limits.

It focuses on:
- Algorithm visualization.
- Optimal problem solving.
- Arbitrary-precision arithmetic.
- Mathematical state sampling.
- Performance-aware simulation.
- Automated correctness verification.

---

**Tower of Hanoi AI Demonstration**

*From Interactive Puzzle Solving to Exact Large-Scale Mathematical Simulation.*
