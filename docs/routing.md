# Routing

Limit Lens is a router first and a meter second. The suggested route should answer: which assistant should get the next unit of work?

## Inputs

For each provider, routing considers:

- whether the provider has usable live or stale limit data
- the preferred usage window
- reset time
- raw usage percentage
- projected pace

Codex prefers the 5-hour window. Claude prefers weekly all-model usage, then 5-hour usage.

## Projection

`LimitProjector` uses single-snapshot linear extrapolation:

```text
elapsed = windowDuration - secondsUntilReset
expectedUsedPercent = elapsed / windowDuration * 100
paceRatio = usedPercent / expectedUsedPercent
projectedUsedPercent = usedPercent + burnRatePerSecond * secondsUntilReset
```

This intentionally avoids storing local history. It reacts immediately, but bursty use can over-project early in a window.

## Constraints

A provider is constrained when:

- it has no usable data
- raw usage crosses its threshold
- pace ratio exceeds 110%

Codex’s raw threshold is 80%. Claude’s raw threshold is 85%.

## Stale Data

Stale snapshots remain usable for routing because they contain the last known good limits. The UI marks them as stale so the recommendation is useful but not falsely presented as freshly live.
