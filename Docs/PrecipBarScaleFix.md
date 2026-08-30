# Fixing the Lying Precipitation Bars

**Symptom:** the "Next 12 Hours" precipitation chart draws a 3% hour at full
height. Every hour with a non-zero chance looks like a downpour, the 0% hours
are hairlines, and the caption reads "Rain starting around 12 p" on a day with a
6% peak.

**Verdict:** two independent bugs multiplying each other. Fix both — either one
alone still produces a misleading chart.

---

## Bug 1 — Relative auto-scaling under an absolute caption

The chart normalised every bar against the tallest bar on screen:

```swift
// WRONG
private var maxFill: Double { max(bars.map(\.barFill).max() ?? 0, 0.12) }

private func column(for bar: RidePrecipBar, height: CGFloat) -> some View {
   let normalized = min(1, bar.barFill / maxFill)   // tallest bar is always 1.0
   ...
}
```

That is legitimate for a chart with no stated units. It is indefensible the
moment each bar prints `"6%"` on itself. The tallest bar is *by definition*
normalised to 1.0, so on a dry day the 6% column touches the ceiling and the
label under it says 6%. The geometry and the caption contradict each other, and
people read geometry first.

**Rule: if a bar carries a percentage caption, its height must come from an
absolute 0…100% domain. No `max()` over the visible data set.**

## Bug 2 — Intensity inflation hijacking the height

The hourly intensity helper slammed any trace of forecast precipitation up to a
0.35 (rain) or 0.45 (snow) floor:

```swift
// WRONG
private static func hourlyIntensity(_ hour: RideWeatherHour) -> Double {
   let chance = hour.precipitationChance
   if hour.snowfallAmountMillimeters > 0 { return max(chance, 0.45) }

   let inches = hour.precipitationAmountMillimeters / 25.4
   if inches > 0 { return min(1, max(chance, 0.35 + min(inches, 0.5))) }

   return chance
}
```

…and `barFill` took whichever of chance or intensity was larger:

```swift
// WRONG
var barFill: Double { max(precipitationIntensity, precipitationChance) }
var isWet: Bool { precipitationIntensity > 0.08 || precipitationChance >= 0.2 }
```

WeatherKit publishes a tiny non-zero `precipitationAmount` for most merely
cloudy hours. So a 3% hour became `barFill ≈ 0.3504`, a 6% hour became
`≈ 0.3505`, and **all of them landed within a rounding error of each other** —
which is why the bars in the screenshot are not only too tall but all the *same*
height. Bug 1 then normalised that shared 0.35 to 1.0.

The same inflated number tripped `isWet` (0.35 > 0.08), which is what produced
the false "Rain starting around 12 p" caption.

**Rule: intensity may drive colour, emphasis and the wet/dry test. It must never
touch the height of a captioned bar, and it must never be floored to a magic
constant.**

---

## The fix

### 1. Make the height metric explicit on the model

Two charts share one bar type but encode different quantities: the hourly chart
prints a percentage (so it must draw the chance), the minute chart prints
nothing (so it is free to draw the rate). Encode that instead of guessing with
`max()`.

```swift
nonisolated enum RidePrecipMetric: Sendable, Equatable {
   case chance
   case intensity
}

nonisolated struct RidePrecipBar: Identifiable, Equatable, Sendable {

   var id: Date { date }

   var date: Date

   /// 0…1 probability of precipitation — the number the caption prints.
   var precipitationChance: Double

   /// 0…1 normalised rate. Drives colour and the wet test, never the height of
   /// a captioned bar.
   var precipitationIntensity: Double

   /// Millimetres forecast for the hour. A trace is not rain.
   var precipitationAmountMillimeters: Double = 0

   var metric: RidePrecipMetric = .chance

   /// Share of the plot this bar fills, on an absolute 0…1 scale.
   var barFill: Double {
      switch metric {
         case .chance: min(1, max(0, precipitationChance))
         case .intensity: min(1, max(0, precipitationIntensity))
      }
   }

   var isWet: Bool {
      switch metric {
         case .chance:
            precipitationChance >= RidePrecipForecast.wetChance
               || precipitationAmountMillimeters >= RidePrecipForecast.wetMillimeters

         case .intensity:
            precipitationIntensity >= RidePrecipForecast.wetIntensity
      }
   }
}
```

### 2. Name the thresholds, drop the magic floors

```swift
/// Below a one-in-four chance, calling an hour wet turns a mostly dry forecast
/// into a warning the rider will learn to ignore.
static let wetChance = 0.25

/// The WMO trace cutoff: under 0.2 mm nothing measurable reaches the road.
static let wetMillimeters = 0.2

static let wetIntensity = 0.08

/// Heavy rain in mm/hr, used as full scale when mapping an amount onto 0…1.
static let heavyRainMillimetersPerHour = 7.6
```

### 3. Rewrite the intensity helper as a pure unit conversion

```swift
private static func hourlyMillimeters(_ hour: RideWeatherHour) -> Double {
   hour.precipitationAmountMillimeters + hour.snowfallAmountMillimeters
}

/// Forecast millimetres mapped onto 0…1 for colour and the wet test only.
private static func hourlyIntensity(_ hour: RideWeatherHour) -> Double {
   min(1, hourlyMillimeters(hour) / heavyRainMillimetersPerHour)
}
```

Hourly bars are then built with `metric: .chance` and carry their millimetres
along; live minute bars use `metric: .intensity`; the minute *fallback* path
(regions with no minute forecast, i.e. most of the world) is synthesised from
the hourly chance, so it must be `metric: .chance` with `intensity: 0` rather
than copying the chance into the intensity field.

### 4. Reserve caption space so a 3% bar can be 3% tall

This is the part that makes an absolute scale survive contact with a real
layout. The old code stuffed the label *inside* the bar, which forced a 16pt
minimum height on every hourly column — an absolute scale is impossible when the
label sets the floor. Hoist the caption above the bar and take its height out of
the plot:

```swift
var chartHeight: CGFloat = 56

private var captionHeight: CGFloat { isHourly ? 13 : 0 }
private var plotHeight: CGFloat { max(12, chartHeight - captionHeight) }

/// Enough of a stub that an empty hour still reads as a measured zero.
private var baseline: CGFloat { isHourly ? 2 : 1.5 }

private func column(for bar: RidePrecipBar) -> some View {
   let fraction = min(1, max(0, bar.barFill))
   let barHeight = max(baseline, plotHeight * fraction)

   return VStack(spacing: 1.5) {
      Spacer(minLength: 0)
      if isHourly { caption(for: bar) }
      barShape
         .fill(fill(isWet: bar.isWet, fraction: fraction))
         .frame(height: barHeight)
   }
   .frame(maxWidth: .infinity)
   .frame(height: chartHeight, alignment: .bottom)
}
```

The caption rides directly above its own bar rather than sitting in a detached
top row, so its vertical position becomes a second read of the same value. At
`fraction == 1` the bar consumes `plotHeight` and the caption consumes
`captionHeight`, which is exactly `chartHeight` — no clipping, no overflow.

Note the `GeometryReader` is gone. Once the scale is absolute there is nothing
to measure: `plotHeight` is arithmetic, and one less geometry read under a sheet
is one less layout pass.

### 5. State the ceiling, and dim the noise

An absolute chart of 4% bars is honest but looks broken unless you say what the
top of the plot means. Two cheap additions:

- Quarter gridlines across the plot with a labelled `100%` ceiling.
- Captions below the wet threshold render at `0.4` opacity instead of full
  white. The number stays available; it stops shouting.

```swift
private func caption(for bar: RidePrecipBar) -> some View {
   Text(RidePrecipForecast.percentLabel(bar.precipitationChance))
      .font(.system(size: 9, weight: .bold))
      .foregroundStyle(.white.opacity(bar.isWet ? 0.95 : 0.4))
      .lineLimit(1)
      .minimumScaleFactor(0.5)
      .padding(.horizontal, 1)
      .frame(height: captionHeight)
}
```

Also confine the gridlines to `plotHeight` and bottom-align them inside
`chartHeight`, or they will spread across the caption strip and float above the
baseline.

### 6. Fix the caption that the old `isWet` was lying through

With `wetChance = 0.25`, a 6% day now falls into the dry branch — so make that
branch say something useful instead of a flat denial that contradicts the
visible bars:

```swift
/// Naming the peak explains the short bars instead of leaving a rider to
/// wonder what a chart of 4% columns is trying to say.
private static func dryHourlySummary(bars: [RidePrecipBar]) -> String {
   let peak = bars.map(\.precipitationChance).max() ?? 0
   guard peak >= 0.01 else { return "No precipitation expected" }

   return "No rain expected — chance peaks at \(percentLabel(peak))"
}
```

---

## Porting checklist for BigFli / BigWX

Names differ per repo; the shapes do not. Search for these and fix each hit.

- [ ] `rg "max\(bars.map"` — any normalisation against the visible maximum in a
      captioned chart. Delete it; divide by the absolute domain instead.
- [ ] `rg "barFill|fillFraction|normalized"` — confirm height derives from the
      same quantity the label prints.
- [ ] `rg "0.35|0.45"` in the precip/intensity helpers — magic floors that
      inflate a trace into a storm.
- [ ] `rg "isWet|isRaining|hasPrecip"` — thresholds should be ≥ 0.25 chance or
      ≥ 0.2 mm, not 0.2 chance or a floored intensity.
- [ ] Percentage labels drawn *inside* bars — they impose a height floor that
      makes an absolute scale impossible. Move them above.
- [ ] Any daily/weekly precip chart in the same repo: same audit. Weekly bars
      are usually the worst offenders because a single wet day sets the max.
- [ ] `GeometryReader` in the chart body — usually only there to serve the
      relative scale. Remove it with the scale.

## How to verify

1. A location with a 0–6% twelve-hour outlook: all bars near the baseline, `0%`
   and `6%` visually distinguishable but both clearly low, caption reads
   "No rain expected — chance peaks at 6%".
2. A location with a 90% hour: that bar reaches the `100%` line's neighbourhood,
   caption above it, nothing clipped.
3. Snow-only hour: still scaled by its chance, coloured as wet via millimetres.
4. Toggle to the next-hour minute view: unlabelled, intensity-driven, absolute —
   a light drizzle must not fill the chart.
5. Region with no minute data: fallback bars draw from the hourly chance and the
   summary does not claim rain at single-digit chances.

## The general lesson

A caption is a contract. The instant you print a unit on a mark, that mark's
geometry is bound to an absolute domain — auto-scaling is only ever available to
charts that stay silent about their numbers. Every time these two are mixed, the
mark wins the argument and the caption becomes the thing users conclude is
broken.
