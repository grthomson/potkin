# Potkin

Executable Racket/Redex presentation of the project's calculus-relative
proof/context kernel and integral proof-forest algebra.

## Status

The implemented slice contains:

- Racket package metadata;
- a finite declaration EDSL for symbolic formula signatures, canonical
  sequent/hypersequent boundaries, fixed rule decorations, fully instantiated
  concrete occurrences, and ordinary equipped calculi;
- canonical multiset sequent and hypersequent boundaries;
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
deferred scope.

## Layout

```text
potkin/
  model.rkt       Redex language and judgments (plus preserved smoke model)
  model/          Redex static kernel
  kernel.rkt      Ordinary-Racket public facade
  kernel/         Boundaries, checking, contexts, forests, and CK cuts
  algebra.rkt     Integral formal-sum public facade
  algebra/        Sparse forest and ordered-tensor sums
  hopf.rkt        Integral CK Hopf public facade
  hopf/           Coproduct, grading, antipode, and formal revision maps
  dsl.rkt         Finite declaration EDSL public facade
  dsl/            Formula, boundary, rule, occurrence, and calculus declarations
  main.rkt        Public package entry point
examples/
  smoke.rkt       Preserved installation smoke example
  v56-running-factorisation.rkt
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
  #:atoms [S T]
  [fusion 2])

(define HS  (hseq L (seq L [] => [S])))
(define HT  (hseq L (seq L [] => [T])))
(define HST (hseq L (seq L [] => [(fusion S T)])))

(define-rule-signature Rules
  [ground   #:kind material #:arity 0]
  [fusion-R #:kind logical  #:arity 2])

(define-occurrence bS
  #:type ground #:instance S #:premises [] #:conclusion HS)
(define-occurrence bT
  #:type ground #:instance T #:premises [] #:conclusion HT)
(define-occurrence m
  #:type fusion-R #:instance (list S T)
  #:premises [HS HT] #:conclusion HST)

(define-calculus K
  #:language L #:rules Rules #:occurrences [bS bT m])
```

Formula constructors still produce ordinary immutable symbolic data, and
`K` is an ordinary `equipped-calculus?` value. Rule declarations describe
fixed decorations only; they do not generate schematic rule instances.
