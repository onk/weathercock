# Changelog

## v1.1.0 - 2026-04-17

### Added

- `#rank` returns the 1-indexed ranking position of an instance; returns `nil` if unranked
- `#remove_hits` removes all recorded hits for an instance across all keys

### Changed

- Bucket count unified to 90 across all time granularities; data is retained longer
- `hit_counts` now uses a single ZMSCORE call instead of N ZSCORE calls

## v1.0.0 - 2026-04-15

### Added

- `.top` now accepts a required `limit` keyword argument; pass `nil` to retrieve all results

### Fixed

- `require "weathercock"` now loads `Weathercock::Scorable` automatically

## v0.1.0 - 2026-04-15

Initial release.
