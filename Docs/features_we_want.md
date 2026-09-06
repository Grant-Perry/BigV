# Features We Want

Ideas worth building, not yet in the app. Capture the intent here; implement when we pick one up.

---

## Location auto-lap (track / loop finish line)

**Status:** not built.

**The ask:** tap LAP still cuts a lap right now. Long-press LAP plants a finish line at the current GPS point so the next time you come around the loop, BigVelo cuts the lap for you.

Neighborhood loop, criterium, pump track, velodrome — mark the line once, then just ride.

### How it should feel

- **Tap LAP** — cut a lap here. Unchanged.
- **Long-press LAP** — drop a finish line on this spot, and cut the lap you're in (you're standing on the line; that *is* the end of this one).
- Every later crossing of that spot cuts the next lap automatically.
- Long-press again clears the line. The LAP button chrome shows when a line is armed.
- Armed for **this ride only**. Does not persist to the next ride.

### Not the same as Settings auto-lap

Settings already has distance auto-lap ("every N miles"). That stays. This is a **place**, not a distance. Both can exist; they are different jobs.

### Two things it has to get right

1. **A gate, not a point.** GPS wanders 10–20 m. Require leave-then-re-enter so sitting on the line, or weaving in the same corner, cannot fire five laps.
2. **Armed state is obvious.** Flag chrome on LAP when a line is live. Easy to clear mid-ride.

### Out of scope until we build it

- Multiple finish lines
- Saving a line across rides or onto a route
- Drawing the line on the map (nice later; not required for v1)
