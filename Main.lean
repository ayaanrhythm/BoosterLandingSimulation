import BoosterLandingSimulation.Project

open BoosterLandingSimulation

def main : IO Unit := do
  IO.FS.writeFile "viz/frames.json" framesJson
  IO.println s!"Wrote {frames.length} frames to viz/frames.json"
