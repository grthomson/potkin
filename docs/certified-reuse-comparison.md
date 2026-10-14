# Certified reuse: proof obligations and reproducible comparison

The runnable commands are:

```powershell
& 'C:\Program Files\Racket\racket.exe' .\examples\certified-modular-reuse.rkt
& 'C:\Program Files\Racket\racket.exe' .\examples\certified-reuse-comparison.rkt
& 'C:\Program Files\Racket\raco.exe' test --make --heartbeat .\tests\certified-reuse-regression-test.rkt
```

The comparison command is the single integrated entry point: it first runs the
successful and rejecting public workflow examples, then the actual comparison
square and the bounded benchmark. The first command runs just the application
examples, without measurement.

The regression command includes the relevant existing ordered-CK and complete
marked-closure tests. It is not the full repository suite. The public import is
exercised there, so a separate smoke run is redundant under AGENTS.md.

## What is being compared

The typed zipper/DAG baseline is deliberately as informed as the CK workflow:
same native checked source, physical frontier, exact whole interfaces, admitted
provider matrices, immutable interpretation, linear observer, shared contraction
DAG and checker-sealed opaque filling. It receives the same verified read
contract; it is not allowed to substitute an initial-redex-only footprint for an
all-history certificate. Both warm semantic engines are literally the same
implementation. Therefore their exact decisions and semantic operation counts
should agree. No intrinsic CK speedup is claimed.

The baseline exposes the conventional semantic cache that the CK workflow also
uses. CK additionally organizes native detachable interfaces, universally
certified protection, occurrence-resolved hereditary cut flags, replay and
material fidelity. These are extra obligations, not free work. A baseline given
those same certificates can obtain the same reuse decisions.

Cold rows reevaluate **both** native proofs and ask the same joint, all-input
observational question, not just the new proof's denotation. They do not measure
a full normalization run. Common preparation charges checked
provider admission and context compilation. Warm rows charge changed-provider
admission, opaque native assembly, joint observation and output materialization.
Cold and warm update timing both include the same opaque native assembly.
The full workflow separately reports protection preparation/recertification,
history projection/replay and live-profile queries. Independent verifier time is
also separate. Full coaction/core expansion is requested only when fidelity is
required; otherwise its status is explicitly UNKNOWN/not requested.

The benchmark uses tensor bundles of sizes 2, 3, 4 and 6, fixed one-dimensional
atomic spaces, three repeated updates each, a two-dimensional compensated
implication update, and two generic contextual checks with explicit state and
generation caps. These are structured input sizes, not a larger exhaustive
fixture degree. Single-run wall-clock timings are reproducibility observations,
not statistically established performance superiority. Rational counts include
addition/multiplication, allocated or inspected matrix entries, admitted proof
and compiled DAG nodes, and maximum numerator/denominator bit length. Dense
matrix and expanded subset output sizes remain real costs.
For an explicit observer the cold coefficient metric combines native-arithmetic
peak and final observed-output size; it does not measure every intermediate
observer coefficient. The measured benchmark uses full-output observations,
so its cold and warm coefficient metrics have identical scope.

## Constructor proof ledger

These are paper arguments supporting the implemented algorithms; execution does
not prove their universal statements, and no Lean theorem was added.

1. Give each atom a positive finite dimension. Use lexicographic tensor bases
   and the matrix-unit basis `(a,b)` of `Hom(A,B)`. For each exact checked rule,
   its stored physical slot/index routes determine premise input coordinates.
   Tensor-right multiplies entries; tensor-left reindexes the two packed
   coordinates; implication-right reshapes/curries; implication-left contracts
   the supplied argument with the selected Hom basis coordinate; either Cut
   contracts producer output with the exact selected consumer input. This gives
   the constructor interpretation, including equal-formula exchanges.
2. Induction over the native remainder establishes that the compiled DAG denotes
   its typed simultaneous filling. Distinct physical holes get distinct DAG
   parameters even when interfaces or logical labels agree. Topological
   evaluation and direct native-tree evaluation implement the same local
   equations independently. Applying a fixed linear observer gives a complete
   matrix. Equality is consequently equality on every external vector in this
   declared model; a differing matrix entry is witnessed by its basis column.
3. For a retained protected native cut, address-prefix restriction gives each
   detached factor's original vertices; remainder addresses retain the residual
   attachments and discard punctures from the vertex set. The heredity theorem
   identifies these restrictions with independently recomputed protection. The
   software requires that finite instance check before a complete protected
   observable or flag receives SAFE, returning UNKNOWN at a cap.
4. Left and right iterated separations are bijections with the same stratified
   occurrence flags. Their factor words remain ordered, while tensor coordinate
   multiplication is coordinatewise concatenation. The empty native cut and the
   separately added whole endpoint supply the counit; neither invents a root
   cut. Heredity makes the protected reduced coproduct recursive. Connected
   grading gives `S(t)=-t-sum S(P_c)R_c`; on words the antipode reverses order.
   The core `m(S pi tensor id)Delta` is a signed ordered forest expression,
   not a proof, filling, repair, or automatic algebra/Hopf endomorphism.
5. Strict family certificates combine a checked history establishing the lower
   partition bound with the template's all-history upper bound: every frozen
   rigid read shell contains only logical constructors and preserves distinct
   nullary primitives. The surrounding-context first-position exclusion needs
   its distinct atomic interfaces and exact consumer ancestry. Recognition is
   rejected outside these hypotheses. Curried application has `m+2` primitive
   singleton blocks and one scaffold block; `m(m+1)/2` counts local cells only.
6. A recorded opaque replay is an event-by-event induction. Each source event
   is checked in the exact source registry and binds to the exact refilled open
   event, not merely a schema name. Its transported holes retain full interfaces
   and order; no rigid read enters a hole. Checker-sealed completeness/provenance
   receipts let assembly avoid provider-body reads. Newly filled proofs still
   require independent all-history boundary recertification.
7. The actual tensor sector admits only positive Cut and tensor constructors.
   Explicit rechecking embeds its native proofs into the mixed registry.
   Conserved nonnegative arrow charge zero excludes every arrow conversion
   instance in that sector. Retained witnesses, selector, coaction and signed
   core therefore transport at each unchanged-ID/map profile. Nested profiles
   satisfy `pi_B pi_C=pi_B`; coactions at different profiles are **not** asserted
   equal. Admission growth and trust growth remain different operations.

The legacy commutative carrier is unchanged. Its forgetful projection is taken
from the ordered native data, never used to reconstruct addresses or order.
The existing ordered module gives the separate constructor/flag argument for
that comparison.

## Unresolved contracts

Fixed-tuple rational equality is not a future-parametric formal identity, proof
identity, SMCC-wide equivalence or operational adequacy. Changed meanings of old
ambient material IDs invalidate the compiled interpretation. Replay across a
new registry requires new event admission and is currently UNKNOWN. Native
full fidelity is shape-sensitive; a semantic module quotient identifying
transformed scaffolds is not fabricated. Profile growth can repair current
eligibility without equating old and new historical spectra. Generic complete
closure and exact expanded protected observables remain bounded. No general
polynomial discovery claim, minimum-cost exposure theorem, full Cut elimination,
group-specific quotation theorem or Lean mechanization is made.

## Recorded execution

Execution used Racket at `C:\Program Files\Racket\raco.exe` / `racket.exe`.
HEAD remains `e07d20fff427bf1fdee2f1770e386e99e555dece` on `main`; everything is
uncommitted and unstaged. Existing unrelated changes, AGENTS.md, the supplied
paper packet, and the workspace configuration were preserved.
The final integrated example command exited 0 in **6.467 seconds**. Every
reported workflow result passed its independent verifier, including rejections.

| Check | Final result | Seconds |
| --- | --- | ---: |
| `raco make --vv .\tests\certified-reuse-regression-test.rkt` | exit 0 | 23.262 |
| `raco test --make --heartbeat .\tests\certified-reuse-regression-test.rkt` | 69 cases passed | 37.537 |
| `raco test --make --heartbeat .\tests\typed-reuse-comparison-test.rkt` after final fairness correction | 3 cases passed | 23.605 |
| `racket .\examples\certified-reuse-comparison.rkt` | exit 0 | 6.467 |

Earlier targeted compile attempts caught three delimiter errors, in the new
semantics module (23.837 s), comparator (44.443 s), and workflow test (76.591 s).
Each rerun followed its concrete correction. The first regression execution
(18.693 s) passed 66/68 cases: both failures correctly charged a freshly checked
continuation as changed. The example now retains its original sealed handle.
The first runnable comparison passed (8.579 s); review then strengthened the
cold path to ask the identical joint question and include filling time. The
comparison-only check passed before that final tightening (24.831 s), and was
rerun after it (23.605 s). No unchanged command was rerun for reassurance.

No full suite, separate redundant smoke test, Lean invocation, install, branch,
commit, or push was performed. Compiler dependency work was part of the named
focused command, not a separate project build.

### Observed contracts and certificates

- Shape-changing tensor replay: accepted; zero new provider admissions, zero
  context recompilations, and one checked open event replayed.
- Two-dimensional compensation: behavior EQUAL, boundary SAFE, replay ELIGIBLE;
  only two changed providers admitted and the exact original continuation
  summary retained. Behavior-only requested acceptance is distinct from trust.
- Omitting compensation: DIFFERENT with external basis column 0 and observed
  coordinate 0, old value **1**, new value **2**, independently native-verified.
- New IDs under the old profile: profile INELIGIBLE and requested native full
  fidelity UNSAFE, although behavior remains EQUAL. Enlarged profile repairs
  eligibility; historical/full fidelity is not thereby asserted.
- Contextual later dependency: forward SAFE, bidirectional UNSAFE. The actual
  crossing origin block contains source addresses `(), (2), (2 1), (2 2)`;
  opacity fails at the whole interface attached at `(2)`. This is not a
  globally minimum-cost exposure plan.
- Inspectable application witness: ordered detached IDs `(e d r)` at
  `((1 1) (2 1) (2 2))`; the typed remainder has exactly those physical holes
  and native reconstruction succeeds. Whole endpoints remain witness-free.
- Nested contexts passed staged/direct matrix, filling, hole-shuffle and replay
  checks. Same-interface compound refilling passed behavior but changed boundary
  safety to UNSAFE; changing the registry leaves old-history replay UNKNOWN.
- Tensor-to-mixed inclusion and both nested profiles: independently verified
  SAFE with arrow charge 0 and literal occurrence/address transports.

The retained small ordered oracle generated **35 native cut witnesses** over
6 fixed checked trees and 10 words. These are falsification/implementation
objects, not a universal proof. The two generic benchmark checks each visited
3 marked states: first position SAFE with 3 edges (7.125 ms); later position
UNSAFE with 2 edges (3.509 ms), under caps 32 states/2000 generated instances.

### Final measured comparison

Times below are milliseconds, medians of the three measured updates. Cold
reevaluates both native proofs and applies the same observation; all rows
returned EQUAL. Preparation is charged separately, not amortized invisibly.
There were 15 supplied update tuples and 45 cold/warm query executions, not an
exhaustive family generator.

| Tensor arguments | Native vertices / blocks / history cells | Whole preparation | Whole update | Independent verifier | Cold joint | Zipper/DAG joint | CK shared-DAG joint |
| ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 2 | 6 / 4 / 1 | 3.561 | 2.210 | 3.007 | 0.346 | 0.402 | 0.393 |
| 3 | 9 / 5 / 2 | 6.854 | 5.725 | 6.519 | 0.561 | 0.639 | 0.677 |
| 4 | 12 / 6 / 3 | 13.555 | 9.955 | 8.935 | 0.805 | 0.931 | 0.974 |
| 6 | 18 / 8 / 5 | 34.462 | 31.923 | 27.265 | 1.426 | 2.325 | 1.713 |

Native fixture admission took 2.546, 2.989, 4.062, 6.876 ms respectively.
The shared semantic preparations took 0.240, 0.458, 0.788, 1.763 ms.
Full workflow protection preparation cost 1.724, 4.727, 10.817, 29.496 ms;
its repeated source-specific recertification cost 1.616, 4.797, 8.706,
29.268 ms. Open-history projection cost 1.476, 1.619, 1.894, 3.514 ms;
replay assembly cost 0.037, 0.059, 0.086, 0.142 ms. Live-profile work was
0.021, 0.028, 0.040, 0.063 ms. Exact expanded provenance was not requested in
these scaling rows, so its near-zero phase is **not** an expansion-cost claim.
The actual comparison square and the provenance-rejection example separately
exercise full protected expansion under its visible cap.

Cold and both warm engines used respectively 6, 8, 10, 14 rational arithmetic
operations and 12, 18, 24, 36 matrix entries per tensor query. Cold directly
visited 12, 18, 24, 36 native nodes; the warm matrix admission/binding paths
charged 24, 36, 48, 72 context nodes. Warm retained 3, 4, 5, 7 providers and
admitted none. Maximum coefficient size was 1 bit. The extra warm checks are
real overhead; these small fixtures do not establish an advantage over cold.

For dimension-2 joint replacement the medians were **1.874 ms cold, 2.191 ms
zipper/DAG, 2.194 ms CK shared-DAG**. Both warm paths used 160 arithmetic
operations, 108 matrix entries, maximum 4 coefficient bits, retained one
provider and admitted two. Cold used 160 arithmetic operations and 96 entries
while reevaluating both entire native proofs. There is no measured semantic
engine speedup. The demonstrated payoff is certified coordinated acceptance,
precise independent failure evidence, and avoided unchanged-provider admission,
not a fabricated asymptotic improvement.

Independent GPT-6.1 Sol cross-reviews covered semantic/type/witness correctness,
closure/protected heredity, and baseline fairness/scope. They found and prompted
fixes for exact event routing, foreign-registry targets hidden by presentation
equality, contract-status verifier bypasses, source-bound fidelity/cache claims,
recursive completeness reads, and omitted admission/coefficient accounting.
The reviewers did not execute additional diagnostic commands or test suites.
