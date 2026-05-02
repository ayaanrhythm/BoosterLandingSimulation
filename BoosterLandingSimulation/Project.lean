namespace BoosterLandingSimulation

/-!
A small standalone Lean 4 project for a class-demo-style booster landing simulation.

The project defines a small affine-geometry layer:
- Point
- Vec
- vector addition
- point translation

On top of that, it defines a physics layer:
- Position
- Velocity
- Acceleration
- Fuel
- World

The goal is to show more than raw numerical vectors. Velocity and acceleration
are represented as physical quantities, and measured velocity is computed from
successive positions using a discrete derivative:

  velocity ≈ (newPosition - oldPosition) / dt

The Lean program generates a finite list of simulation frames, writes them to
frames.json, and a plain browser page visualizes the result.

This pdated version also includes a coinductive-style stream section:
an infinite stream of worlds is defined, and the browser frames are a finite
prefix of that stream.
-/

/-
  Basic affine-geometry layer
-/

structure Vec where
  x : Rat
  y : Rat
deriving Repr

structure Point where
  x : Rat
  y : Rat
deriving Repr

def zeroVec : Vec :=
  ⟨0, 0⟩

def vecAdd (u v : Vec) : Vec :=
  ⟨u.x + v.x, u.y + v.y⟩

def vecSub (u v : Vec) : Vec :=
  ⟨u.x - v.x, u.y - v.y⟩

def vecScale (k : Rat) (v : Vec) : Vec :=
  ⟨k * v.x, k * v.y⟩

def movePoint (p : Point) (v : Vec) : Point :=
  ⟨p.x + v.x, p.y + v.y⟩

def displacement (p q : Point) : Vec :=
  ⟨p.x - q.x, p.y - q.y⟩

/-
  Physics layer:

  Velocity and acceleration are not just anonymous vectors anymore.
  They are physical quantities represented by vectors underneath.
-/

structure Position where
  value : Point
deriving Repr

structure Velocity where
  value : Vec
deriving Repr

structure Acceleration where
  value : Vec
deriving Repr

structure Fuel where
  amount : Rat
deriving Repr

def zeroVel : Velocity :=
  ⟨zeroVec⟩

def zeroAcc : Acceleration :=
  ⟨zeroVec⟩

structure Booster where
  pos : Position
  prevPos : Position
  vel : Velocity
  prevVel : Velocity
  fuel : Fuel
deriving Repr

structure Ship where
  pos : Position
  vel : Velocity
deriving Repr

inductive Outcome where
  | flying
  | landed
  | crashed
deriving Repr

structure World where
  tick : Nat
  booster : Booster
  ship : Ship
  acc : Acceleration
  outcome : Outcome
deriving Repr

/-
  Simulation constants
-/

def dt : Rat :=
  1 / 5

def maxTicks : Nat :=
  180

def burnRate : Rat :=
  1 / 20

def deckHalfWidth : Rat :=
  2

def deckHeight : Rat :=
  1 / 2

/-
  Small helper functions
-/

def ratAbs (r : Rat) : Rat :=
  if r < 0 then -r else r

def ratMax0 (r : Rat) : Rat :=
  if r < 0 then 0 else r

def posX (p : Position) : Rat :=
  p.value.x

def posY (p : Position) : Rat :=
  p.value.y

def outcomeName : Outcome → String
  | .flying => "flying"
  | .landed => "landed"
  | .crashed => "crashed"

/-
  Target and physical effects
-/

def targetPoint (w : World) : Point :=
  let shipP := w.ship.pos.value
  let targetY :=
    if w.booster.pos.value.y > 9 then
      6
    else if w.booster.pos.value.y > 4 then
      3
    else
      deckHeight
  ⟨shipP.x, targetY⟩

def gravity : Acceleration :=
  ⟨⟨0, -3 / 25⟩⟩

def windAt (tick : Nat) : Acceleration :=
  let phase := tick % 60
  if phase < 15 then
    ⟨⟨1 / 100, 0⟩⟩
  else if phase < 30 then
    ⟨⟨-1 / 120, 0⟩⟩
  else if phase < 45 then
    ⟨⟨1 / 160, 0⟩⟩
  else
    ⟨⟨0, 0⟩⟩

def dragAccel (v : Velocity) : Acceleration :=
  ⟨vecScale (-1 / 8) v.value⟩

def desiredVerticalSpeed (y : Rat) : Rat :=
  if y > 9 then
    -2 / 5
  else if y > 5 then
    -1 / 4
  else if y > 2 then
    -3 / 20
  else
    -1 / 20

def controlAccel (w : World) : Acceleration :=
  match w.outcome with
  | .landed => zeroAcc
  | .crashed => zeroAcc
  | .flying =>
      if w.booster.fuel.amount <= 0 then
        zeroAcc
      else
        let target := targetPoint w
        let bPos := w.booster.pos.value
        let bVel := w.booster.vel.value
        let shipVel := w.ship.vel.value

        let ex := target.x - bPos.x
        let ey := target.y - bPos.y

        let desiredVx := shipVel.x + ex / 6
        let desiredVy := desiredVerticalSpeed bPos.y

        let ax := (desiredVx - bVel.x) / 2 + ex / 20
        let ay := (desiredVy - bVel.y) / 2 + ey / 16 + 4 / 25

        ⟨⟨ax, ay⟩⟩

/-
  Discrete derivative-style physical measurements

  measuredVelocity:
   velocity ≈ (currentPosition - previousPosition) / dt

  measuredAcceleration:
    acceleration ≈ (currentVelocity - previousVelocity) / dt
-/

def measuredVelocity (w : World) : Velocity :=
  let dp := displacement w.booster.pos.value w.booster.prevPos.value
  ⟨vecScale (1 / dt) dp⟩

def measuredAcceleration (w : World) : Acceleration :=
  let dv := vecSub w.booster.vel.value w.booster.prevVel.value
  ⟨vecScale (1 / dt) dv⟩

def distanceToTarget (w : World) : Rat :=
  let t := targetPoint w
  let p := w.booster.pos.value
  ratAbs (t.x - p.x) + ratAbs (t.y - p.y)

/-
  Landing and crash checks
-/

def landed? (ship : Ship) (boosterPos : Position) (boosterVel : Velocity) : Bool :=
  let shipP := ship.pos.value
  let p := boosterPos.value
  let v := boosterVel.value
  (decide (p.y <= deckHeight)) &&
  (decide (ratAbs (p.x - shipP.x) <= deckHalfWidth)) &&
  (decide (ratAbs (v.x - ship.vel.value.x) <= 3 / 10)) &&
  (decide (ratAbs v.y <= 3 / 10))

def crashed? (boosterPos : Position) : Bool :=
  decide (boosterPos.value.y <= -1)

/-
  World update functions
-/

def updateShip (ship : Ship) : Ship :=
  let moved := movePoint ship.pos.value (vecScale dt ship.vel.value)
  let rawPos : Position := ⟨moved⟩
  let x := rawPos.value.x
  let newVel :=
    if x > 8 then
      ⟨⟨-1 / 3, 0⟩⟩
    else if x < -8 then
      ⟨⟨1 / 3, 0⟩⟩
    else
      ship.vel
  { ship with pos := rawPos, vel := newVel }

def advanceBooster (w : World) (netAcc : Acceleration) : Booster :=
  let vel' : Velocity :=
    ⟨vecAdd w.booster.vel.value (vecScale dt netAcc.value)⟩

  let pos' : Position :=
    ⟨movePoint w.booster.pos.value (vecScale dt vel'.value)⟩

  let fuel' : Fuel :=
    ⟨ratMax0 (w.booster.fuel.amount - burnRate)⟩

  { pos := pos'
  , prevPos := w.booster.pos
  , vel := vel'
  , prevVel := w.booster.vel
  , fuel := fuel'
  }

def onTick (w : World) : World :=
  match w.outcome with
  | .landed =>
      let ship' := updateShip w.ship
      let snappedPos : Position :=
        ⟨movePoint ship'.pos.value ⟨0, deckHeight⟩⟩

      { tick := w.tick + 1
      , ship := ship'
      , booster :=
          { w.booster with
            pos := snappedPos
            prevPos := w.booster.pos
            vel := ship'.vel
            prevVel := w.booster.vel
          }
      , acc := zeroAcc
      , outcome := .landed
      }

  | .crashed =>
      { w with tick := w.tick + 1, acc := zeroAcc }

  | .flying =>
      let ship' := updateShip w.ship
      let wind := windAt w.tick
      let drag := dragAccel w.booster.vel
      let thrust := controlAccel { w with ship := ship' }

      let netAcc : Acceleration :=
        ⟨vecAdd gravity.value
          (vecAdd wind.value
            (vecAdd drag.value thrust.value))⟩

      let booster' := advanceBooster { w with ship := ship' } netAcc

      if landed? ship' booster'.pos booster'.vel then
        let snappedPos : Position :=
          ⟨movePoint ship'.pos.value ⟨0, deckHeight⟩⟩

        { tick := w.tick + 1
        , ship := ship'
        , booster :=
            { booster' with
              pos := snappedPos
              prevPos := booster'.prevPos
              vel := ship'.vel
            }
        , acc := netAcc
        , outcome := .landed
        }

      else if crashed? booster'.pos then
        { tick := w.tick + 1
        , ship := ship'
        , booster := booster'
        , acc := netAcc
        , outcome := .crashed
        }

      else
        { tick := w.tick + 1
        , ship := ship'
        , booster := booster'
        , acc := netAcc
        , outcome := .flying
        }

def stopWhen (w : World) : Bool :=
  (decide (w.tick >= maxTicks)) ||
  (match w.outcome with
   | .flying => false
   | .landed => true
   | .crashed => true)

/-
  Initial world
-/

def initialWorld : World :=
  let shipStart : Position := ⟨⟨-6, 0⟩⟩
  let shipVel : Velocity := ⟨⟨1 / 3, 0⟩⟩
  let boosterStart : Position := ⟨⟨-12, 16⟩⟩
  let boosterVel : Velocity := ⟨⟨2 / 5, -1 / 10⟩⟩

  { tick := 0
  , ship := { pos := shipStart, vel := shipVel }
  , booster :=
      { pos := boosterStart
      , prevPos := boosterStart
      , vel := boosterVel
      , prevVel := boosterVel
      , fuel := ⟨8⟩
      }
  , acc := zeroAcc
  , outcome := .flying
  }

/-
  COINDUCTIVE-STYLE STREAM SECTION

  Here is the part for the coinductive streaming.

  Lean core does not require us to import a special game engine.
  We define our own stream abstraction.

  A CoStream α represents an infinite sequence of α values.

  Here:

    worldStream : CoStream World

  means an infinite stream of simulation worlds:

     world₀, world₁, world₂, world₃, ...

   The stream itself is infinite, but the browser only needs a finite
   prefix. So frames are produced by:

     CoStream.takeUntil (maxTicks + 1) stopWhen worldStream

   This matches the BigBang/game-loop idea:
   - World is the state
   - onTick advances the state
   - stopWhen decides when the simulation is done
-/

structure CoStream (α : Type) where
  nth : Nat → α

namespace CoStream

def head {α : Type} (s : CoStream α) : α :=
  s.nth 0

def tail {α : Type} (s : CoStream α) : CoStream α :=
  { nth := fun n => s.nth (n + 1) }

def take {α : Type} : Nat → CoStream α → List α
  | 0, _ => []
  | n + 1, s => head s :: take n (tail s)

def takeUntil {α : Type} : Nat → (α → Bool) → CoStream α → List α
  | 0, _, _ => []
  | n + 1, stop, s =>
      let h := head s
      if stop h then
        [h]
      else
        h :: takeUntil n stop (tail s)

end CoStream

/--
World at time t.

This recursively observes the infinite evolution of the simulation.
-/
def worldAt : Nat → World
  | 0 => initialWorld
  | n + 1 => onTick (worldAt n)

/--
The infinite coinductive-style world stream.
-/
def worldStream : CoStream World :=
  { nth := worldAt }

/--
The browser animation is a finite prefix of the infinite stream.
This replaces the old direct finite simulation list.
-/
def frames : List World :=
  CoStream.takeUntil (maxTicks + 1) stopWhen worldStream

/-
  JSON output
-/

def ratToJson (r : Rat) : String :=
  toString (Float.ofInt r.num / Float.ofNat r.den)

def pointToJson (p : Point) : String :=
  "{\"x\":" ++ ratToJson p.x ++ ",\"y\":" ++ ratToJson p.y ++ "}"

def vecToJson (v : Vec) : String :=
  "{\"x\":" ++ ratToJson v.x ++ ",\"y\":" ++ ratToJson v.y ++ "}"

def boolToJson (b : Bool) : String :=
  if b then "true" else "false"

def worldToJson (w : World) : String :=
  let target := targetPoint w
  let wind := windAt w.tick
  let drag := dragAccel w.booster.vel
  let thrust := controlAccel w
  let mVel := measuredVelocity w
  let mAcc := measuredAcceleration w

  "{"
    ++ "\"tick\":" ++ toString w.tick ++ ","
    ++ "\"done\":" ++ boolToJson (stopWhen w) ++ ","
    ++ "\"status\":\"" ++ outcomeName w.outcome ++ "\","
    ++ "\"ship\":" ++ pointToJson w.ship.pos.value ++ ","
    ++ "\"booster\":" ++ pointToJson w.booster.pos.value ++ ","
    ++ "\"target\":" ++ pointToJson target ++ ","
    ++ "\"shipVel\":" ++ vecToJson w.ship.vel.value ++ ","
    ++ "\"velocity\":" ++ vecToJson w.booster.vel.value ++ ","
    ++ "\"acceleration\":" ++ vecToJson w.acc.value ++ ","
    ++ "\"measuredVelocity\":" ++ vecToJson mVel.value ++ ","
    ++ "\"measuredAcceleration\":" ++ vecToJson mAcc.value ++ ","
    ++ "\"wind\":" ++ vecToJson wind.value ++ ","
    ++ "\"drag\":" ++ vecToJson drag.value ++ ","
    ++ "\"thrust\":" ++ vecToJson thrust.value ++ ","
    ++ "\"fuel\":" ++ ratToJson w.booster.fuel.amount ++ ","
    ++ "\"distance\":" ++ ratToJson (distanceToTarget w)
    ++ "}"

def joinWith (sep : String) : List String → String
  | [] => ""
  | x :: [] => x
  | x :: xs => x ++ sep ++ joinWith sep xs

def framesJson : String :=
  "[\n" ++ joinWith ",\n" (frames.map worldToJson) ++ "\n]\n"

end BoosterLandingSimulation
