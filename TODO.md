# matchbox TODO

## Known issues

### Publish output ordering (gallery)
Some cell output renders in the wrong place in the published HTML: rung 0's
text output, and the rung 0 and rung 6 figures, appear at the very bottom of
the document below the local-helpers code block instead of under their
sections.

- `snapnow` did not fix it and made figures worse. Note: inside a function
  `snapnow` behaves like `drawnow`, so it does not force a snapshot from a
  helper. All `snapnow` calls have been removed to match the bsnr gallery,
  which publishes correctly without them.
- The residual rung-0 text misplacement predates snapnow and is unexplained.

Things to try:
- Publish without any `snapnow` (current state) and re-check which cells,
  if any, still misorder.
- Add an explicit `drawnow` at the end of each rung cell before the section
  ends.
- Create the figure at the top of each rung cell (as bsnr does with
  `figNW = figure(...)` in the cell body) rather than inside `plotScenario`,
  and confirm whether that pins the ordering.
- Check whether the behaviour is MATLAB-version specific.
- As a fallback, split the gallery so local helper functions live in
  separate files, leaving the published script free of trailing function
  definitions.

## Roadmap

- [x] Build `multiCaptureHistoryGridded` (fixed reference grid) behind the
      same interface. Assigns detections to bins by midpoint; one event per
      occupied bin; order independent and reproducible.
- [x] Unified front door: `matchbox(d1,...,dN, 'method',
      'clustered'|'gridded', ...)` dispatches to the implementations and
      forwards method-specific params (`timeBuffer` / `gridStep`) plus the
      shared ones (`splitRule`, `verbose`), with strict per-method parsers so
      a wrong-method param errors rather than being silently ignored. The
      `multiCaptureHistory*` names are now internal; dropping the `multi`
      prefix is deferred since they are no longer user facing.
- [ ] Add the gridded curve to rung 6 of the gallery and turn it into the
      head-to-head comparison that motivates the family: clustered keeps
      merging as the buffer grows, gridded holds steady per occupied bin.
- [ ] Extend the ladder: call-type presets beyond `zcall`/`chorus`
      (D-call, fin 20 Hz, SRW upcall) so regimes read as named cases.
- [ ] Anchor the Casey comparison against the adjudicated every-eighth
      subset from the manuscript (duplicate-free reference).
- [ ] Decide the fate of the legacy pairwise path: keep for reproducibility
      or archive once gridded is proven in use.

## Protocol note (not code)

- Add an explicit "one annotation box per call" instruction to the
  annotation protocol. The Casey 2019 a2 lumping (all long events traced to
  one analyst) is unrecoverable after the fact and corrupts co-observers'
  capture histories. Cheap to prevent upstream, impossible to fix downstream.
