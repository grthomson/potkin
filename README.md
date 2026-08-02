# Potkin

Executable Racket/Redex presentation of the project's calculus-relative
proof/context kernel and integral proof-forest algebra.

## Status

The implemented slice contains:

- Racket package metadata;
- a finite declaration EDSL for symbolic formula signatures, canonical
  sequent/hypersequent boundaries, fixed rule decorations, fully instantiated
  concrete occurrences, and ordinary equipped calculi;
- declarative complete/open proof terms with lexical exact-occurrence
  selection, derived context interfaces, addressed context composition,
  backward refinement, and checked filling/extraction points;
- canonical multiset sequent and hypersequent boundaries;
- sealed component-incidence relations whose ordered-premise and local
  component endpoints are validated against one concrete occurrence profile,
  while absent and legacy opaque payloads remain admitted but explicitly
  unanalyzable;
- immutable equipped-calculus registries of concrete occurrences;
- a shared raw syntax with independent Redex and ordinary-Racket checkers;
- typed punctures, telescopes, context composition, and complete filling;
- commutative proof forests with block and flattened root profiles;
- prefix-free, address-indexed CK cut witnesses and lazy cut enumeration;
- immutable compatible calculus revisions, exact identity revisions,
  composable revision paths, exact liveness diagnostics, and checked lifting;
- explicit basis-level constructor deletion for terms and proof forests;
- exact repair plans for withdrawn nullary material grounds, including the separate whole-proof endpoint;
- immutable finite sparse sums over the integers, with rank-one proof-forest
  algebra, ordered finite tensor ranks, exact calculus provenance, normalized
  coefficients, and checked coordinate expansion and contraction;
- the collected, full multiplicative CK coproduct on complete and punctured
  positive-vertex trees, together with its counit and vertex grading;
- the public reduced coproduct, rooted coaction, exact final-corolla
  factorization/projection, and the typed one-slot-insertion/singleton-cut
  coefficient pairing;
- address-resolved premise ancestry, explicit empty/proper/whole cut choices,
  ancestry ideals, cut polynomials, causal width, root-first refinement
  orders, iterated coproducts, and independently checked convolution counts;
- address-resolved component traces for open contexts, local relational
  classifications and scalar structural defects, and nonempty-cut
  CK-resolved component profiles with exact detached alignment;
- immutable finite-input derivation, context, forest, and Hopf-law reports
  with deterministic structural rendering and explicit analysis limits;
- the connected-graded antipode and both convolution identities;
- total componentwise formal maps for exact-ID constructor deletion and
  persistent calculus additions, together with their sequential action along
  exact revision paths;
- exact Hopf-law and revision-naturality checks over a bounded exhaustive
  locally admitted fixture; and
- the preserved standard Redex smoke example and test.

The accurate implemented claim is the integral calculus-relative CK Hopf
algebra on locally typed, positive-vertex complete and punctured proof-tree
presentations. The executable bounded law checks are evidence for this exact
implementation; they are not a machine-checked mathematical proof of every
law or an implementation of every result in the manuscript.

See `docs/semantic-contract-v56.md` for the representation contract and
`docs/integral-ck-hopf-v56.md` for the algebra, laws, revision maps, and exact
deferred scope.  `docs/research-workbench-v56.md` describes the declaration,
analysis, and reporting workflow.

## Layout

```text
potkin/
  model.rkt       Redex language and judgments (plus preserved smoke model)
  model/          Redex static kernel
  kernel.rkt      Ordinary-Racket public facade
  kernel/         Boundaries, component incidence, checking, contexts, forests, and CK cuts
  algebra.rkt     Integral formal-sum public facade
  algebra/        Sparse forest and ordered-tensor sums
  hopf.rkt        Integral CK Hopf public facade
  hopf/           Coproduct, rooted operations, antipode, and revision maps
  dsl.rkt         Finite declaration EDSL public facade
  dsl/            Declarations, checked proof terms, contexts, and filling points
  analysis.rkt    Component-trace, premise-ancestry, and convolution facade
  analysis/       Component profiles, causal ideals, orders, and bounded counts
  tool.rkt        Deterministic research-report public facade
  tool/           Immutable reports and structural presentation
  main.rkt        Public package entry point
examples/
  smoke.rkt       Preserved installation smoke example
  v56-running-factorisation.rkt
  dsl-running-factorisation.rkt
  dsl-open-context.rkt
  dsl-hypersequent.rkt
  dsl-communication-assembly.rkt
tests/
  smoke-test.rkt  Preserved installation smoke test
```

## Local toolchain

The machine is configured with Racket 9.2 x64 and the distribution-provided
Redex package.

From PowerShell:

```powershell
& 'C:\Program Files\Racket\racket.exe' examples\smoke.rkt
& 'C:\Program Files\Racket\racket.exe' examples\v56-running-factorisation.rkt
& 'C:\Program Files\Racket\racket.exe' -S . examples\dsl-running-factorisation.rkt
& 'C:\Program Files\Racket\racket.exe' -S . examples\dsl-open-context.rkt
& 'C:\Program Files\Racket\racket.exe' -S . examples\dsl-hypersequent.rkt
& 'C:\Program Files\Racket\racket.exe' -S . examples\dsl-communication-assembly.rkt
& 'C:\Program Files\Racket\raco.exe' test tests\smoke-test.rkt
& 'C:\Program Files\Racket\raco.exe' test -j 4 .
```

The expected example output is:

```text
#t
(ground)
```

The v56 example then prints the four vertex addresses, the five admissible
cuts (including the empty cut), and the two-leaf factorisation:

```text
(() (1) (1 1) (1 2))
()
((1))
((1 1))
((1 2))
((1 1) (1 2))
(detached (((1 1) (app bS)) ((1 2) (app bT))))
(remainder (app i (app m (puncture) (puncture))))
(telescope (((1 1) S) ((1 2) T)))
(reconstructs? #t)
```

After installing or linking the package, the declaration surface is available
from the ordinary entry point:

```racket
(require potkin)

(define-formula-signature L
  #:atoms [S T U]
  [fusion 2])

(define HS  (hseq L (seq L [] => [S])))
(define HT  (hseq L (seq L [] => [T])))
(define HST (hseq L (seq L [] => [(fusion S T)])))
(define HU  (hseq L (seq L [] => [U])))

(define-rule-signature Rules
  [ground   #:kind material #:arity 0]
  [fusion-R #:kind logical  #:arity 2]
  [wrap     #:kind structural #:arity 1])

(define-occurrence bS
  #:type ground #:instance S #:premises [] #:conclusion HS)
(define-occurrence bT
  #:type ground #:instance T #:premises [] #:conclusion HT)
(define-occurrence m
  #:type fusion-R #:instance (list S T)
  #:premises [HS HT] #:conclusion HST)
(define-occurrence i
  #:type wrap #:instance U
  #:premises [HST] #:conclusion HU)

(define-calculus K
  #:language L #:rules Rules #:occurrences [bS bT m i])

(define-proof t
  #:in K #:root HU
  (i (m bS bT)))

(define-context r
  #:in K #:root HU
  (i (m _ bT)))

(write-analysis (analyze-derivation t))
```

Formula constructors still produce ordinary immutable symbolic data, and
`K` is an ordinary `equipped-calculus?` value. Rule declarations describe
fixed decorations only; they do not generate schematic rule instances.
Application heads and leaves in declarative terms are lexical concrete-
occurrence bindings; `_` is the sole puncture form.

`make-component-incidence` supplies a finite relation only after validating
every `(premise slot, source component, target component)` edge against the
declared occurrence boundaries. Its predicates distinguish functionality,
inverse functionality, totality, and surjectivity, and hence splitting,
merger, erasure, and unsupported creation. Legacy `#:incidence` data remain
valid registry metadata, but component analysis reports them as unknown
rather than silently reading them as the empty relation. The separate
implementation fields `instance` and `incidence` are two stored parts of the
manuscript's fully instantiated occurrence data, not independent semantic
decorations.

`component-trace-of` composes supplied local relations from addressed
punctures to the root. `component-profiles-of` enriches each nonempty CK cut
with the address-aligned detached tuple, retained context, component
frontier, trace, and reconstruction. See
`examples/dsl-communication-assembly.rkt` for two proofs with the same
binary CK tree and detached immediate-premise forest but different supplied
component action: nondegenerate Communication has `K_2,2`, while connected
bar-assembly has a disjoint-union bijection. Neither relation asserts any
formula-occurrence incidence.

The running report keeps five occurrence-level CK witnesses distinct from
the six collected coproduct terms.  It also shows the final-corolla tensor,
`3q + q^2` cut polynomial, ancestry width two, and the two root-first
histories.  Expensive analyses are budgeted; exceeding a budget renders
`not computed: limit`, never zero or a failed law.
