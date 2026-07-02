# matchbox TODO

## Known issues

### Publish output ordering (gallery)
Symptom was: rung 0's text, and the rung 0 and rung 6 figures, rendered at
the very bottom of the published HTML below the local-helpers code block.

Applied fix: the gallery helpers (genScenario, emit, pickClearTime,
checkScenario, computeEventIds, reportRung, plotScenario, plotScenarioAxes,
defaults, tf) now live in examples/private/, so gallery.m is a pure cell
script with no trailing function definitions. Mixing a script and local
functions in one file was the likely cause.

Verify on next publish that the ordering is correct. If any cell still
misorders, try an explicit `drawnow` at the end of that rung cell, and check
whether the behaviour is MATLAB-version specific.

Note: this relies on a script calling functions in its parent folder's
private/ subfolder (standard MATLAB behaviour). If publish reports an
undefined helper, rename examples/private to a plain folder and addpath it in
the setup cell.

Ruled out earlier: `snapnow` did not help (inside a function it behaves like
`drawnow`); all `snapnow` calls were removed.

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
- [x] Turn example 6 into a clustered-vs-gridded head-to-head. Both timelines
      and both parameter sweeps are shown. Framing is two methods answering
      two questions, not a contest: clustered searches for a per-call plateau
      the chorus does not contain (buffer sweep keeps falling); gridded reports
      per-bin presence at a resolution you choose (count varies smoothly with
      gridStep). A dashed "true calls detected" reference line anchors both
      plots. The clustered sweep now extends into negative buffers: a negative
      buffer requires overlap to link, fragments loose chains, and drives the
      count up across the reference line. The example tunes the buffer to that
      crossing and shows, from the synthetic truth, that the count can be right
      while the capture history still holds merges and fragments. Event
      duration versus known call duration is offered as the real-data proxy
      for that check, since real data has no truth to measure against.
- [ ] Open question (Brian's finding): are negative timeBuffers ever a
      defensible matching choice on real data, or only a count-matching
      artefact? Example 6 shows the count can land on target while the CHT is
      wrong. If a principled use exists, document it; otherwise add a caution
      to the clustered matcher's help against tuning by count alone.
- [ ] Labelling convention to settle: the gallery calls a matched row an
      "event" and a ground-truth call a "call". The CDE pipeline calls a
      matched row a "detection" and a true acoustic call an "event". The
      gallery is internally consistent as is. If the CDE convention is
      preferred, switch prose, printouts, and figure labels together.
- [x] Drop the `matcher` function handle from the gallery. Every example now
      calls `matchbox` directly; clustered is left implicit (timeBuffer only)
      except in example 6, which names both methods to compare them.
- [x] Rename "rung" to "example" throughout the gallery (headers, prose, the
      reportRung printout). The ladder metaphor is kept in the intro. The
      helper is still named reportRung internally (not reader-facing).
- [ ] Extend the ladder: call-type presets beyond `zcall`/`chorus`
      (D-call, fin 20 Hz, SRW upcall) so regimes read as named cases.
- [ ] Promote the timeline visual to a reusable QC tool. plotScenarioAxes
      colours by ground-truth call, which real data lacks. A public
      `plotCaptureHistory` (colour by event, show detect flags, no truth
      required) would give a point-check on real capture-history tables. Put
      it on the general path (repo root), not in examples/private.
- [ ] Anchor the Casey comparison against the adjudicated every-eighth
      subset from the manuscript (duplicate-free reference).
- [ ] Decide the fate of the legacy pairwise path: keep for reproducibility
      or archive once gridded is proven in use.

## Protocol note (not code)

- Add an explicit "one annotation box per call" instruction to the
  annotation protocol. The Casey 2019 a2 lumping (all long events traced to
  one analyst) is unrecoverable after the fact and corrupts co-observers'
  capture histories. Cheap to prevent upstream, impossible to fix downstream.
