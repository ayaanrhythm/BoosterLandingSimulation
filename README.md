# Booster Landing Simulator

A standalone Lean 4 + browser visualization project for a 2D booster landing simulation using affine geometry.

This project models a rocket booster trying to land on a ship deck. Lean 4 generates a finite sequence of simulation frames from a formal world model, and a plain browser page visualizes the result as either a demo replay or an interactive game.


## The main ideas are:

- define a small 2D geometry layer in Lean
- define a physics layer on top of geometry
- model the simulation as a world state
- update the world with an `onTick` function
- stop the simulation with a `stopWhen` condition
- generate browser-readable JSON frames
- visualize the simulation in a polished browser UI
- include an interactive game mode controlled by the user


## Project structure

- `BoosterLandingSimulation/Project.lean` — the simulation model
- `Main.lean` — writes `viz/frames.json`
- `viz/game.html` — browser UI
- `viz/frames.json` — generated demo frames
- `lakefile.toml` — Lake project config

## What the Lean side does

The Lean code defines the main simulation model.

It includes a small geometry layer:

- `Point`
- `Vec`

It also includes a physics layer:

- `Position`
- `Velocity`
- `Acceleration`
- `Fuel`
- `Booster`
- `Ship`
- `World`

The simulation includes simple physical effects:

- gravity
- wind
- drag
- thrust
- fuel use
- ship motion
- booster motion
- landing and crash outcomes

The project also computes physical measurements using finite differences. It also includes one extra abstraction:

- **measured velocity** = (current position - previous position) / dt
- **measured acceleration** = (current velocity - previous velocity) / dt

This helps show thatthe project starts to model physics quantities explicitly.

## Coinductive-Style Stream

The Lean side also includes a coinductive-style stream idea.

Instead of treating the simulation only as a fixed list, the project defines an ongoing stream of world states:

```text
world₀, world₁, world₂, world₃, ...
```

Each next world is produced by applying `onTick`.

The browser only needs a finite number of frames, so the project takes a finite prefix of that stream and writes it to `frames.json`.


## Browser Modes

The browser app has two modes.

### Demo Mode

Demo mode replays the Lean-generated frames from:

```text
viz/frames.json
```

This shows the simulation data produced by Lean.

### Interactive Mode

Interactive mode lets the user control the booster manually.

There is no autopilot in interactive mode. The user must use thrust to land the booster safely on the ship deck.

The booster lands only if:

- its landing legs touch the ship deck
- both feet are over the deck
- the vertical speed is safe (slow enough speed)
- the horizontal speed relative to the ship is safe (slow enough speed)

Otherwise, the booster crashes.


## Browser Controls

Buttons:

- **Watch Demo** — plays the Lean-generated frames
- **Play Interactive** — starts live keyboard control
- **Pause / Resume**
- **Restart**

Keyboard controls in interactive mode:

- `W` or `↑` — upward thrust
- `A` or `←` — thrust left
- `D` or `→` — thrust right

Ship mode selector:

- **Moving** — the ship moves horizontally
- **Static** — the ship stays in one place

---

## 2. Build the Lean executable

From the project root:

```powershell
lake build
```

## 3. Generate the demo frames JSON

```powershell
lake exe make_frames
```

This writes:

```text
viz\frames.json
```

## 4. Start a local web server

From the project root:

```powershell
cd viz
python -m http.server 8080
```

If `python` is not on your PATH, try:

```powershell
py -m http.server 8080
```

## 5. Open the app

In your browser, open:

```text
http://localhost:8080/game.html
```


## Description of Main Files

### `BoosterLandingSimulation/Project.lean`

This is the main Lean file. It defines the geometry, physics, world state, update logic, coinductive-style stream, and JSON output.

### `Main.lean`

This file writes the generated frames to:

```text
viz/frames.json
```

### `viz/game.html`

This file contains the browser visualization and interactive game. It includes the canvas drawing code, HUD, buttons, keyboard controls, ship mode selector, and landing/crash logic.

---

## Summary

This project is a standalone Lean 4 and browser-based booster landing simulator.

The high-level flow is:

```text
Lean geometry layer
      ↓
Lean physics layer
      ↓
World state
      ↓
onTick simulation
      ↓
coinductive-style stream
      ↓
finite JSON frames
      ↓
browser visualization
```

The project shows how Lean can model the state and logic of a physical simulation, while the browser provides an interactive way to see and test the result.

## Easy next upgrades

If you want to keep improving this for the final project:

- add a better landing score
- make ship motion less predictable
- add fuel-based thrust limits
- display measured velocity vs commanded velocity
- replace the finite list with a stream-style model later
- add a richer notion of force / mass