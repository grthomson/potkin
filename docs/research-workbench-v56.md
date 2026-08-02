# Potkin research workbench

The research workbench is a deterministic, finite-input view of Potkin's
checked proof/context kernel and integral calculus-relative CK Hopf algebra.
It joins the declaration EDSL, exact checked construction, rooted Hopf
operations, premise-ancestry analysis, and presentation reports without
introducing another proof carrier.

The intended workflow is:

```text
finite formula and rule declarations
  -> fully instantiated concrete occurrences
  -> one immutable equipped-calculus registry
  -> declarative complete or open checked terms
  -> typed context/filling operations
  -> rooted CK and causal analyses
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

A rule signature declares only fixed tag, kind, and arity decorations.  Each
`define-occurrence` remains a fully instantiated concrete occurrence with an
exact ID, ordered whole-hypersequent premises, conclusion, instance, and
optional opaque incidence.  `define-calculus` validates those declarations
and returns an ordinary immutable equipped-calculus registry.

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

## Reports

The stable inspection entry points are:

- `analyze-derivation` for one connected checked derivation;
- `analyze-context` for one checked open context;
- `analyze-forest` for one commutative proof forest; and
- `check-hopf-laws` for exact checks on the supplied finite value.

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

This workbench analyzes exact finite proof presentations.  It does not add
proof search, automatic hole filling, rule schemata, metavariable
substitution, unification, proof quotients, commuting conversions, implicit
Weakening/Contraction/Mix, assembly, or Gentzen Cut.  It also does not infer
component action, Communication profiles, splitting, merger, erasure, or
unsupported creation from opaque incidence metadata.

Also deferred are a custom `#lang potkin`, a command-line interface, GUI,
JSON/project persistence, dependent-type migration, a proof-assistant
companion, formula/resource substitution polynomials, completed Green or
Faà di Bruno series, coherent component reindexing, arbitrary coideal search,
normalization and Cut elimination, coefficient rings other than the integers,
and additional repair-frontier machinery.
