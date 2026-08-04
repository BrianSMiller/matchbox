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
- [x] Turn example 7 into a clustered-vs-gridded head-to-head. Both timelines
      and both parameter sweeps are shown. Framing is two methods answering
      two questions, not a contest: clustered searches for a per-call plateau
      the chorus does not contain (buffer sweep keeps falling); gridded reports
      per-bin presence at a resolution you choose (count varies smoothly with
      gridStep). A dashed "true calls detected" reference line anchors both
      plots. The clustered sweep now extends into negative buffers (example 8):
      a negative buffer requires overlap to link, fragments loose chains, and
      drives the count up across the reference line. The example tunes the
      buffer to that crossing and shows, from the synthetic truth, that the
      count can be right while the capture history still holds merges and
      fragments. Event duration versus known call duration is offered as the
      real-data proxy for that check, since real data has no truth to measure
      against.
- [x] Open question (Brian's finding): are negative timeBuffers ever a
      defensible matching choice on real data, or only a count-matching
      artefact? Example 8 shows the count can land on target while the CHT is
      wrong. If a principled use exists, document it; otherwise add a caution
      to the clustered matcher's help against tuning by count alone.
- [ ] Labelling convention to settle: the gallery calls a matched row an
      "event" and a ground-truth call a "call". The CDE pipeline calls a
      matched row a "detection" and a true acoustic call an "event". The
      gallery is internally consistent as is. If the CDE convention is
      preferred, switch prose, printouts, and figure labels together.
- [x] Drop the `matcher` function handle from the gallery. Every example now
      calls `matchbox` directly; clustered is left implicit (timeBuffer only)
      except in examples 7 and 8, which name both methods to compare them.
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
- [x] Decide the fate of the legacy pairwise path: promoted and
      consolidated, not archived -- it's still used sometimes. Folded
      pairwiseCaptureHistory.m's two-table primitive in as a local
      subfunction of the new root-level `multiCaptureHistoryPairwise.m`,
      matched to the clustered/gridded input/output contract and shared
      options, wired into `matchbox(...,'method','pairwise',...)`, and
      fixed the row-multiplication bug (duplicate matches to the same
      existing event now collapse via splitRule, same mechanism
      clustered/gridded use for splitters). The order-dependence caveat is
      real and stays documented, not silently declared fixed.
- [x] Example 3 (order independence): current version only confirms the
      clustered matcher is order-independent, which it does thinly by
      reversing observer order on the example 2 scenario. The goal is also to
      demonstrate that the legacy pairwise matcher is order-dependent, using a
      synthetic scenario where the failure is legible and attributable.

      The mechanism: pairwise matching processes observers sequentially,
      matching each new table against a growing aggregate. When detections
      are ambiguous -- due to timing jitter, splitting, or lumping -- the
      max-overlap key assignment in captureHistoryTable.m produces a different
      result depending on what is already in the aggregate, which depends on
      observer order. The specific failure mode we discussed: a detection from
      one observer that overlaps two detections in the aggregate (because of
      jitter or a split) gets assigned to the wrong key depending on which
      of those aggregate detections was anchored first.

      A suitable scenario probably involves 3 observers, 2-3 real calls, and
      enough timing jitter or splitting to create at least one ambiguous
      overlap in the aggregate. The goal is four figures: clustered original
      order, clustered reversed (visually identical), pairwise original,
      pairwise reversed (visually different). The failure should be obvious
      from the figures without needing the prose to explain it.

      Approach: try genScenario with p.timeJitter large enough relative to
      call spacing to produce overlapping adjacent boxes (without going full
      chorus), and p.pSplit > 0 on one observer. Fix the RNG seed so the
      failure is reproducible. Run both matchers on both orderings and inspect
      the figures before committing. If genScenario cannot produce a reliable
      failure with sensible parameters, construct the three observer tables
      manually -- the scenario only needs a handful of rows and manual
      construction makes the mechanism explicit.

      The Casey 2019 real-data comparison (compareCaptureHistory_Casey2019.m)
      is not included in the published gallery. It remains available as a
      diagnostic script for developers. The gallery is entirely synthetic.

- [ ] Capstone example: all pathologies combined. A single scenario with
      jitter, splitting, lumping, and false positives together -- mirroring
      the conditions of the Casey 2019 real data. Run all four matchers
      (clustered, gridded, pairwise, pointProximity) and compare. This is
      the "why we built this toolbox" example. Deferred until after the
      AWR manuscript is further along.

- [x] Add a common scoring suite (`scoreDetections.m`, `scoreDetectionsSweep.m`)
      consuming the matchbox contract directly, to replace the three
      independent/reinvented scoring paths in the 2026-AWR-callDensity
      benchmark scripts (fin20p, Koogu, pamguard_scc). Ground truth is a
      caller-chosen observer, not hardcoded to observer 1. The duplicate-key
      correction the old annotatedLibrary scoreDetections.m needed is gone
      -- matchbox guarantees unique keys now, so that was compensating for
      a bug that no longer exists.

- [x] Add `pointProximity` as a fourth matchbox method: single-linkage
      clustering on one reference point per detection (default `t0`,
      overridable via `refCol`), no frequency test, same output contract
      and shared options as the other three. Inspired by, but explicitly
      NOT a reproduction of, Schall & Parcerisas (2022)'s matching
      criterion -- their algorithm is deliberately many-to-many
      (`matchByTimeProximity.m`, annotatedLibrary) and doesn't fit
      matchbox's one-row-per-event contract without a collapse rule they
      don't have.

      This splits the fin20p benchmark's two jobs cleanly, which is why it
      was doing double duty in the first place:
        1. Reproducing Schall & Parcerisas's published numbers -- stays on
           `scoreAgainstAnnotations.m`/`matchByTimeProximity.m` directly,
           untouched, not routed through matchbox.
        2. Comparing fin20p/Koogu/pamguard_scc/pamguard_energy_sum/
           annotated-library detectors against each other on equal
           footing -- uses `pointProximity` (or `clustered`/`gridded`).
           Combine ALL detectors into one N-observer `ch` and score every
           detector off the same shared match via repeated
           `scoreDetections(ch, groundTruthObserver, k)` calls -- no new
           sweep infrastructure needed, already falls out of
           `scoreDetections`'s caller-chosen-observer design.

- [x] Illustrated gallery.m Example 9 for pointProximity vs clustered: a
      precise 3-call observer against an imprecise, over-wide detection box
      that genuinely interval-overlaps one call but whose start point is
      farther than the buffer from that call's start. Clustered credits the
      box to the call (3 events); pointProximity does not (4 events, the
      wide box its own event). Moved here from testMatchboxSmoke.m, which
      had grown an elaborate "illustration" fixture+comment that belonged
      in the gallery, not the fast test suite -- same split already
      established for pairwise's order dependence (Example 3, not tested
      for instability in testMatchboxSmoke). testMatchboxSmoke.m keeps only
      structural/parameter-validation checks for pointProximity now.

- [ ] Build the combined-CHT detector comparison (task 2 above) for
      BallenyIslands2015 ATBFL: one `matchbox(...)` call with annotations +
      fin20p + Koogu + pamguard_scc + pamguard_energy_sum, scored via
      repeated `scoreDetections` calls off the shared `ch`. Also a natural
      place to test whether the matching method (clustered vs gridded vs
      pointProximity) actually changes the detector-comparison answer, by
      rebuilding the same combined `ch` under each and comparing.

- [ ] Migrate the three benchmark scripts (2026-AWR-callDensity, not this
      repo) onto the new scoring suite:
        - `benchmark_pamguard_scc_BallenyIslands2015_ATBFL.m`: done, fully
          replaced (its matching/scoring was inline, no opaque helper).
        - `benchmark_koogu_BallenyIslands2015_ATBFL.m`: drafted, replacing
          the opaque `sweepKooguThreshold` with `scoreDetectionsSweep`
          directly against `kooguDet`. Assumes a `score` column exists on
          `kooguDet` (Koogu's detection probability) -- confirm the actual
          field name from `loadKooguDetectionsForSite` and fix `scoreCol`
          in the script if it's named differently. Written before the
          reframe above; if Koogu's role shifts to the combined-CHT
          comparison (task 2) this draft may need revisiting rather than
          used as-is.
        - `benchmark_fin20p_BallenyIslands2015_ATBFL.m`: superseded by the
          two-task split above. No longer planned as a single
          matchbox-routed rewrite -- task 1 needs no matchbox changes,
          task 2 goes through the combined-CHT approach once that's built.

## Protocol note (not code)

- Add an explicit "one annotation box per call" instruction to the
  annotation protocol. The Casey 2019 a2 lumping (all long events traced to
  one analyst) is unrecoverable after the fact and corrupts co-observers'
  capture histories. Cheap to prevent upstream, impossible to fix downstream.
