# matchbox

**CHAOS** — Capture History Across Observers of Sounds

Matching acoustic detections from multiple observers of a single sensor into
multi-observer capture histories.


## What is matchbox CHAOS?

It's a detection matching tool that produces capture histories. For one real 
event, (here an acoustic call) a **capture history** records which of several 
independent observers detected it. Observers are analysts and automated 
detectors. Each row is a call, each column is an observer, each entry says
whether that observer detected that call. The idea comes from mark-recapture and
double-observer survey methods.

Building a **capture history table** requires **matching**: deciding when a 
detection from one observer is the same call as a detection from another. In 
continuous time, with imperfect boxes drawn around calls, this is the hard part. 
This toolbox provides matching algorithms behind a common interface, mirroring 
the `bsnr` pattern of one interface with several algorithms.

## What sets this apart

This is not generic detection matching. Pairwise schemes and
intersection-over-union answer a two-way question: does this detection match
that one. The premise here is different and is the whole point. Many
observers, human analysts and automated detectors together, all disagree at
once, and the job is to reconcile them into a single set of events in one
pass, so that every event carries a consistent record of who detected it.
That reconciliation must not depend on the order the observers are
considered, and it must survive one observer lumping or splitting where
another does not. A sequence of pairwise IoU matches gives neither. The
algorithms here are built around the N-observer case from the start.

**Scope: one sensor, many observers.** Observers here means independent ways of
detecting calls in the same recording: several analysts, one or more
automated detectors, or both, observing the same single-hydrophone
data. Matching detections across spatially separated sensors, where
time-of-arrival differences and coherence matter (wide-baseline arrays), is a
different problem and is out of scope.

## Two applications, kept distinct

1. **Detection functions for call density estimation** — how detection
   probability falls with range or signal-to-noise ratio, so counts become
   densities. Feeds the Common Ground protocol (Miller et al. 2026, *Methods
   in Ecology and Evolution*; the `callDensity` R package).
2. **Detector characterisation** — how a detector performs against analysts
   or against other detectors, in precision and recall terms.

Some corrections apply to one application but not the other. Lumping (one box
over several calls) has a downstream correction for density estimation (count
calls per detection) but not for detector characterisation. The algorithms
and the gallery keep the two straight.

## Usage

`matchbox` is the front door. Pick a method and pass its tuning parameter.

```matlab
ch = matchbox(d1, d2, d3, 'method','clustered', 'timeBuffer', 5/86400);
ch = matchbox(d1, d2, d3, 'method','gridded',   'gridStep', 60/86400);
ch = matchbox(d1, d2, d3, 'method','pairwise',  'timeBuffer', 5/86400);
```

Each input is one observer's detection table with columns `t0`, `tEnd`,
`fLow`, `fHigh` (times in days). The output is one row per event, with
`detect_observerK` flags and every observer's columns suffixed `_observerK`.
`method` defaults to `clustered`. `splitRule` (`overlap` or `snr`) and
`verbose` are shared; `timeBuffer` and `gridStep` are method-specific and
forwarded to the chosen implementation, which validates them.

## Algorithms

| method | approach | use when |
|---|---|---|
| `clustered` (default) | temporal single-linkage clustering | calls well separated relative to cross-observer timing jitter (Z-calls, D-calls, SRW upcalls in sparse bouts) |
| `gridded` | fixed reference grid | calls close-spaced, where event-equals-call breaks down (fin 20/40 Hz pulse trains, choruses) |
| `pairwise` | matches each observer against a growing aggregate, gated on time AND frequency overlap | reproducing pre-2026 results, or where frequency-gated matching is specifically wanted; order dependent, prefer clustered/gridded for new work otherwise |

All three share the same input/output contract and the `splitRule`/`verbose`
options. `pairwise` is a supported, first-class option for the cases it
still gets used for, not a discouraged one -- but its order dependence is a
structural property of matching against a growing aggregate, not something
promoting the interface fixes. See `help multiCaptureHistoryPairwise` for
the mechanism and what a collapsed-duplicate-match fix does and doesn't
address.

The implementations live in `multiCaptureHistoryClustered.m`,
`multiCaptureHistoryGridded.m`, and `multiCaptureHistoryPairwise.m`. They can
be called directly, but `matchbox` is the intended interface. Run per call
type: filter each input to a single classification first, since clustered
and gridded match on time only, and mixed call types make pairwise's
frequency comparison meaningless too.

## Layout

```
matchbox.m                       front door: matchbox(..., 'method', ...)
multiCaptureHistoryClustered.m   clustered implementation
multiCaptureHistoryGridded.m     gridded implementation
multiCaptureHistoryPairwise.m    pairwise implementation
tests/                           fast invariant checks (testMatchboxSmoke)
examples/
  gallery.m                           illustrated validation ladder (publishable)
  compareCaptureHistory_Casey2019.m   pairwise-vs-clustered comparison on real data
  publishDocs.m                       render the gallery to examples/html/
  html/                               generated HTML
TODO.md                          open items
```

## Getting started

```matlab
addpath(genpath('matchbox'))
testMatchboxSmoke                 % fast checks, no data needed
cd matchbox/examples
publishDocs                       % render the gallery to html/
```

## Dependencies

The clustered and gridded matchers, and the gallery, are self-contained
(base MATLAB). The pairwise matcher additionally needs `doTimespansOverlap`
and `timespanOverlap` from the original annotatedLibrary or bsmUtils
toolboxes.

## Citation

If the capture-history method is useful, cite the Common Ground protocol:
Miller et al. (2026), *Methods in Ecology and Evolution*.
