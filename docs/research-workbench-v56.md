# Potkin research workbench

The research workbench is a deterministic, finite-input view of Potkin's
checked proof/context kernel and integral calculus-relative CK Hopf algebra.
It joins the declaration EDSL, exact checked construction, rooted Hopf
operations, premise-ancestry analysis, and presentation reports without
introducing another proof carrier.

The intended workflow is:

```text
finite formula and rule declarations
  -> fully instantiated concrete occurrences with supplied or opaque incidence
  -> one immutable equipped-calculus registry
  -> declarative complete or open checked terms
  -> typed context/filling operations
  -> rooted CK, component-frontier, and causal analyses
  -> immutable reports and deterministic data
```

Everything is available from `(require potkin)`.  The complete running
example is `examples/dsl-running-factorisation.rkt`; its final expression is:

```racket
(write-analysis (analyze-derivation t))
```

## Declaration and checking boundary

A formula signature is a finite validation descriptor.  Its constructors
produce ordinary, deeply immutable symbolic formula data; it is neither a
second formula AST nor calculus provenance.  `seq` and `hseq` build the
kernel's canonical finite multisets.  Exchange is canonical while formula
and displayed-component multiplicity is retained.

A rule signature declares only fixed tag, kind, and arity decorations. Each
`define-occurrence` remains a fully instantiated concrete occurrence with an
exact ID, ordered whole-hypersequent premises, conclusion, instance, and
incidence field. A sealed value built by `make-component-incidence` is
recognised as a known component relation only after every edge is validated
against the exact premise slot and local source/target component indices.
Other deeply immutable incidence payloads remain admitted for compatibility,
but are reported as unknown rather than as empty relations. `define-calculus`
validates those declarations and returns an ordinary immutable equipped-
calculus registry. The separate `instance` and `incidence` fields store two
implementation parts of the occurrence's fully instantiated `theta`; they
are not independent mathematical decorations.

Declarative terms select lexical concrete-occurrence bindings, never tags or
schematic rules.  `_` compiles to the existing raw puncture, applications
compile to the shared raw s-expression syntax, and the checker alone creates
checked nodes and holes.  Every declaration supplies its whole root boundary
explicitly.  `define-proof` requires a complete rule-rooted term,
`define-context` requires at least one typed puncture, and
`define-derivation` permits either.

## Contexts, filling points, and refinement

`context-interface-of` derives the canonical input telescope word, output
boundary, and exact calculus snapshot from a checked term.  The interface is
metadata for nonsymmetric context composition; it is not a proof forest or a
Hopf generator.  A complete `G`-proof has interface `O(();G)`, while the
nodeless typed identity `Box^G` has interface `O((G);G)`.

`context-compose/addressed` accepts one address-to-replacement association
for every current puncture.  It rejects duplicate, missing, extra, and
retained-node addresses, then follows canonical lexicographic telescope
order.  Premise-slot order is never exchanged even when requirements are
equal.

A `filling-point` stores one supplied member of the fixed filling fibre: one
complete, exact-provenance, exactly typed proof for every telescope entry.
`evaluate-filling-point` delegates to checked filling.
`extract-filling-point` traverses a fixed context and candidate together,
preserves every retained exact occurrence and ordered premise structure, and
captures only at the original punctures.  It decides membership in that
fixed evaluation image; it performs no proof search or proof enumeration.
`backward-refine` inserts one admitted corolla at one selected puncture.

See `examples/dsl-open-context.rkt` for filling/extraction and a nullary
backward-refinement round trip.  See `examples/dsl-hypersequent.rkt` for a
genuinely multi-component whole boundary containing both repeated formulae
and repeated displayed components.

## Component incidence, traces, and CK frontiers

`make-component-edge` names an ordered premise slot, a source component
occurrence in that exact premise boundary, and a target component occurrence
in the conclusion. `make-component-incidence` stores the exact endpoints and
canonicalises its edges as a set. Equal displayed components remain
separately addressable through the indices returned by
`hypersequent-components`; those indices are canonical local presentation
indices, not a completed coherent-reindexing mechanism.

For a known relation, the public predicates report functionality,
inverse-functionality, totality, and surjectivity. Their complements expose
component-level splitting, merger, erasure, and unsupported creation. These
facts are not inferred from a rule name, tag, or kind. They make no claim
about formula-occurrence copying, erasure, discharge, or pairing.

`component-trace-of` computes the relation from addressed open inputs to root
components. `Box^G` gives the identity relation. At a rule vertex, child
traces are combined by ordered premise slot and composed with the supplied
local relation. `component-trace-compose` implements the same law for one
addressed insertion: a source at address `q` in a context inserted at `p`
becomes `p ++ q`. If a relevant puncture-to-root path contains legacy opaque
incidence, the result retains its typed domain and codomain but is explicitly
unavailable with the blocking vertex addresses. Complete subproofs have no
external input domain; their local relations remain visible in the vertex
table rather than being guessed from an empty net trace.

`component-profiles-of` enriches every nonempty admissible CK cut of a
connected complete proof. Each `ck-component-profile` retains its existing
witness, sorted addresses, address-aligned detached tuple, puncture telescope,
retained context, addressed component frontier, root-component codomain,
composite trace, and reconstruction. The empty witness remains in the
ordinary witness report but is not a component profile. There is no root-cut
profile and no profile for the algebraic `t tensor 1` endpoint. The full
immediate-child profile of a positive-arity final occurrence recovers its
declared local relation under the literal premise-slot/address
identification.

An explicitly successful lift through a persistent calculus addition keeps
the old raw tree, cut addresses, retained occurrences, and typed relations,
so its component profiles agree at the canonical local indices. If an
occurrence used by the proof is withdrawn, lifting fails and the workbench
makes no target-profile claim for that dead historical proof.

Scalar calibration is separate. `occurrence-proof-factor-defect` computes
`1 - arity`; `occurrence-hypersequent-defect` computes the conclusion breadth
minus total premise breadth. `derivation-scalar-analysis` checks both Euler
telescoping identities against the root boundary and puncture telescope.
Equal scalar pairs do not imply equal component action.

The dedicated `examples/dsl-communication-assembly.rkt` fixture makes this
last distinction explicit. Nondegenerate Communication and connected
bar-assembly use the same two premise proofs, have the same binary CK shape,
immediate cut addresses, detached forest, and final scalar pair `(-1,0)`.
Their roots and retained corollas remain different. Communication supplies
the component relation `K_2,2`, while assembly supplies the disjoint-union
bijection; neither is inferred or treated as forest multiplication.

## Typed grafting and protected defects

`typed-pointed-input-coaction` retains ordered telescope positions,
independent premise-level choices, the multiplied detached forest, the
ordered right tuple, and every prefixed relative cut address. A typed pointed
hole is the existing checked `Box` value and may occur only in that retained
input tuple.

`typed-grafting-cocycle` applies one exact occurrence to compatible pointed
inputs and independently constructs the typed grafting/comodule equation.
Its forward certificates map choice tuples to below-root CK witnesses; its
reverse certificates restrict each witness back to the ordered input regions.
Both round trips, every reconstruction, and direct/recursive collected tensor
equality are public certificate fields.

`protected-context-factorization-defect` evaluates a selected protected-input
coaction below a positive context. Its uncollected cut records classify the
empty cancellation, wholly protected cancellation, fixed-context residual,
unprotected-input residual, and mixed residual. The support theorem and
collected coefficient agreement are explicit. Local replacement residues
expose identity, antisymmetry, and telescoping without claiming an arbitrary
ideal or congruence decision.

## Recurrence workbench

`derivative-frame-graph-of` and `boundary-recurrence-of` distinguish acyclic,
raw-unrealised, realised-no-seed, and realised-with-seed boundaries. The graph
retains exact occurrence/slot parallel edges. Productivity stores one
deterministic minimum-height proof per boundary. Realisation and unique-hole
decomposition supply the two directions of the graph/context theorem.

`make-boundary-return-character`, `certify-return-convolution-power`, and
`certify-first-return` operate on one exact calculus and boundary. Every power
certificate contains the actual iterated CK coproduct, all uncollected
occurrence witnesses and their reduced-character evaluations, recursively
constructed return chains, and the explicit two-way witness bijection. The
first-return certificate evaluates the existing antipode and reports:

```text
polynomial at -1        = rho(S(C))
first-return indicator  = -rho(S(C)).
```

`unfold-first-return-context` retains a polynomial certificate at every
checked self-insertion layer. `certify-seeded-unfolding` reports literal
separation addresses and the actual iterated-coproduct coefficient.
`side-evidence-factorization` and `check-side-evidence-product` retain the
off-spine CK witness and multiplicative frontier law; `Box^G` has unit side
evidence and no manufactured cut. `component-recurrence-powers` compares
finite supplied-incidence relation powers with direct traces of recursively
constructed context powers.

## Reports

The stable inspection entry points are:

- `analyze-derivation` for one connected checked derivation;
- `analyze-context` for one checked open context;
- `analyze-forest` for one commutative proof forest;
- `check-hopf-laws` for exact checks on the supplied finite value;
- `analyze-grafting-cocycle` and `analyze-protected-defect` for typed cocycle
  and finite residual reports;
- `analyze-calculus-recurrence` for one graph boundary; and
- `analyze-return-context` for convolution, antipode, side-evidence, and
  component recurrence data attached to one return context.

They return immutable report values with public predicates and accessors.
`analysis->datum` converts any report to deterministic symbolic data, and
`write-analysis` writes that representation.  The narrower renderers
`checked-term->datum`, `proof-forest->datum`, and `formal-sum->datum` expose
the same presentation conventions for public carrier values.

A connected report records the exact root whole hypersequent, completeness,
context interface, vertex count, address-indexed vertices and typed premise
slots, puncture telescope, occurrence-level CK witnesses and their
reconstruction status, and the collected Hopf values.  When applicable it
also includes the final-corolla factorization, cut polynomial, premise
ancestry, ideals, width, schedule counts, and finite-input law checks.
Its nested `component-analysis` separately records the address-indexed local
relations and classifications, scalar defects and Euler checks, net context
trace, and nonempty-cut CK profile family. Component profile enumeration uses
the report's finite analysis budget and reports an explicit limit result
rather than silently truncating the family.

Witnesses and collected algebra deliberately remain separate.  For the
running proof

```text
t = i(m(bS,bT))
```

the report exposes four vertices, five admissible witnesses including the
empty cut, and six terms in the collected coproduct after the separate
`t tensor 1` endpoint is added.  Its reduced coproduct has four nonempty
proper-cut terms, while the rooted coaction has the five witness-derived
terms and omits `t tensor 1`.  Final-corolla projection is

```text
m(bS,bT) tensor i(Box)
```

and ordered-child recomposition recovers `t`.  The causal values are:

```text
vertex count                  4
ancestry ideals               6
cut-size polynomial           3q + q^2
nonroot ancestry width        2
zeta^2(t)                     6
omega_1^4(t)                  2
linear extensions             2
root-first histories          2
```

The two histories differ only in the order of the address-distinct `bS` and
`bT` leaves.

## Determinism and semantic distinctions

Presentation order is derived from structural raw terms, canonical
boundaries, lexicographic positive premise-slot addresses, and an exact
structural symbolic-data order.  Hash iteration and printed strings are not
used as semantic equality or ordering.  Structural presentation equality
also does not establish common calculus provenance: operational APIs still
require the same exact registry object or an explicit checked lift along a
revision.

The rendered forms keep these values visibly distinct:

- a typed vacant premise slot;
- the nodeless typed context identity `Box^G`;
- the empty proof-forest algebra unit;
- formal additive zero over one exact calculus snapshot; and
- a structured `not computed: limit` analysis result.

Forest juxtaposition is displayed as independent commutative multiplication,
never as filling, assembly, Mix, reconstruction, or Gentzen Cut.  Tensor
coordinates remain ordered.  In particular, the connected term
`m(bS,bT)` is not collected as a forest joining separate `bS` and `bT`
proofs.

## Finite checks and limits

`check-hopf-laws` checks the supplied finite input.  It does not turn those
checks into a universal machine proof.  Reports cover coassociativity, the
two counit equations, rooted-coaction equations where applicable, and the
implemented convolution identities.

Potentially expensive cut, ideal, iterated-coproduct, and schedule analyses
are preflighted against explicit limits.  A calculation known to exceed its
budget returns the structured analysis-limit result and is rendered as
`not computed: limit`.  That outcome is neither exact zero, false, a failed
law, the empty-forest unit, nor formal additive zero.  Unbounded analysis is
an explicit `#:limit #f` opt-in for callers who accept its cost.

## Scope

This workbench analyzes exact finite proof presentations. It does not add
general bidirectional proof search, arbitrary automatic hole filling, rule schemata, metavariable
substitution, unification, proof quotients, commuting conversions, implicit
Weakening/Contraction/Mix, assembly, or Gentzen Cut. Component relations and
Communication profiles are supplied and endpoint-validated, not inferred;
opaque incidence remains possible but unanalyzable. Classification of a
component relation does not implement formula-occurrence incidence or a
Communication reduction.

Also deferred are a custom `#lang potkin`, a command-line interface, GUI,
JSON/project persistence, dependent-type migration, a proof-assistant
companion, formula/resource substitution polynomials, completed Green or
Faà di Bruno series, coherent component reindexing, arbitrary coideal search,
formula-occurrence incidence, general Hochschild complexes, proof-reduction
loops, cyclic-proof soundness/progress, focusing completeness, indexed nested
sequents, normalization and Cut elimination, coefficient rings other than the
integers, and additional repair-frontier machinery.
