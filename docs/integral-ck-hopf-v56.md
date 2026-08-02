# Integral calculus-relative CK Hopf algebra

This layer implements, in ordinary Racket, the integral presentation-level
Hopf algebra associated with one exact finite equipped-calculus registry `K`.
It builds on the checked kernel and does not change the independent Redex
checker or the raw s-expression syntax.

## Carrier and coefficients

The connected generators are the locally admitted checked nodes with at least
one rule vertex. Both complete proofs and positive-vertex punctured contexts
are included. A typed nodeless `Box^G` is not a generator. The monomial basis
is the free commutative monoid on those connected checked nodes: the finite
proof forests, including their empty-forest unit. Formal values are finite
normalized integer combinations of those monomials; ordered tensor powers use
immutable vectors of forests.

Formal zero is empty support indexed by the exact registry object. It differs
from the empty-forest basis unit, from `Box^G`, and from the kernel deletion
API's diagnostic `algebraic-zero`. Structural presentation equality still
ignores registry provenance, so every operational algebra and Hopf API checks
exact `eq?` registry identity separately.

This carrier is cut-hereditary because current admission is local: every
constructor has fixed finite arity and exact ordered premise boundaries, and
an occupied child may be replaced by its typed vacancy without a global
condition. This claim does not extend automatically to future calculi with
proof-global normality, freshness, liveness, or incidence constraints.

## Coproduct, counit, and grading

For a connected term `t`, the implementation computes

```text
Delta(t) = t tensor 1
           + sum_{c in A(t)} P^c(t) tensor R^c(t).
```

The existing witness enumeration `A(t)` includes the empty cut, which supplies
`1 tensor t`. The endpoint `t tensor 1` is added once separately. A root cut
is never admitted. Each right remainder is injected as a singleton proof
forest and may contain typed punctures; neither a bare context nor a hole is a
tensor coordinate.

Complete proofs alone are not coproduct-closed, because a cut generally leaves
a positive-vertex punctured remainder. The empty forest maps to `1 tensor 1`.
The coproduct of a nonempty forest is
the componentwise tensor product of the connected coproduct of every factor
occurrence, so repeated equal factors produce their integral binomial
coefficients. The map then extends linearly. Collection forgets cut addresses,
while the kernel witness API continues to retain its address-aligned detached
tuple.

The counit is the coefficient of the empty forest. Forest degree is the sum of
the checked vertex counts of every factor occurrence. Thus the unit has degree
zero, every other public basis forest has positive degree, and holes contribute
zero only inside a positive rooted factor. Formal zero has no invented
homogeneous degree.

## Reduced coproduct and rooted operations

`reduced-coproduct` exposes the literal forest formula

```text
reduced-Delta(F) = Delta(F) - F tensor 1 - 1 tensor F.
```

Its antipode recursion uses nonempty forests. On the empty-forest unit the
same public formula is retained exactly and gives `-1 tensor 1`; it is not
silently replaced by additive zero.

For a positive connected term `t` of root `G`, `root-coaction` removes only
the separately adjoined `t tensor 1` endpoint. The empty cut remains as
`1 tensor t`, and every right coordinate is checked to be a singleton
positive retained context with exact calculus provenance and root `G`. The
finite-input tests check `(Delta tensor id) delta = (id tensor delta) delta`
and `(epsilon tensor id) delta = id` by ordered coordinate expansion and
contraction.

For a complete connected proof, `final-corolla-factorization` retains its
source, exact final occurrence, immediate children in premise-slot order,
their commutative forest image, and the full-premise corolla. The ordered
children recompose the source. `final-corolla-projection` computes and checks

```text
(id tensor pr_1) Delta(t) = Prem(t) tensor Cor(final(t)),
```

including the nullary case, where `Prem(t)` is the empty forest. The aligned
child vector is indispensable: commutative forest multiplication does not
remember premise order.

`one-slot-context-insertion(S,T)` is a finite integral sum over exactly the
typed punctures of the positive connected context `T` that accept the root of
`S`. It is context insertion, not forest multiplication. Its coefficient at
`U` is paired with the coefficient of `S tensor T` in
`singleton-cut-coproduct(U)`, which contains exactly the nonroot one-address
cuts and no endpoint or multi-address cut. Typed nodeless `Box^G` remains the
context-composition identity and is outside every Hopf basis operation.

## Antipode

The connected grading gives a terminating recursion. For a nonempty forest
`F`, let

```text
reduced-Delta(F) = Delta(F) - F tensor 1 - 1 tensor F
                 = sum a(P,R) P tensor R.

S(F) = -F - sum a(P,R) S(P) R,
S(1) = 1.
```

Every reduced term is checked to have both coordinate degrees strictly between
zero and `degree(F)` before recursion. Memoization is local to one top-level
operation and therefore cannot conflate structurally equal forests from
different registries. The antipode uses only formal addition, scaling, and
forest juxtaposition. It is a convolution inverse, not an inverse derivation,
proof repair, filling procedure, reduction, or normalization algorithm.

For the one-colour fixtures:

```text
S(g)       = -g
S(u(Box))  = -u(Box)
S(u(g))    = -u(g) + g join u(Box)
S(g join g)=  g join g.
```

## Formal revision maps

For a calculus revision `K0 -> K1`, `formal-revision-map` accepts a formal
value of any positive tensor rank carrying the exact source registry.

- If any coordinate forest of a basis tensor contains a withdrawn exact
  occurrence ID, the whole tensor contribution is omitted and becomes genuine
  target formal zero.
- Otherwise every coordinate is lifted through the checked revision API and
  rebuilt under the exact target registry in the same coordinate order.
- Coefficients are collected only after this componentwise basis mapping.
- Wrong source provenance and failed lifting are structured map errors, never
  zero.

For no-addition revisions this is the executable exact-ID constructor-deletion
quotient projection into `H_Z(K0-D)`. If the revision also has fresh additions,
it is deletion followed by inclusion into `H_Z((K0-D)+A)` and is generally not
surjective. With no withdrawals it is the corresponding persistent inclusion.
Deletion by a manuscript-level tag or family would first need a selector that
expands that family to exact registry IDs. No quotient-module datatype is
implemented.

Finite composable revision paths are represented without flattening their
steps. `make-revision-chain` requires an explicit source and exact `eq?`
agreement at every intermediate endpoint; its empty path is the identity at
that source. `formal-revision-map-chain` applies the one-step maps in order.
Consequently an intermediate formal zero is still transported through later
targets, and a constructor ID withdrawn in one step cannot be confused with a
new occurrence that legally reuses that ID in a later snapshot. The analogous
checked through-lifts are partial on retired terms and return structured
revision errors instead of algebraic zero.

`identity-calculus-revision K` has both endpoints exactly `K`. It is distinct
from `make-calculus-revision K '() '()`, whose target is a newly constructed,
structurally equal snapshot. Together the one-step maps and their literal
sequential composites form an executable action of revision paths. This does
not turn arbitrary deletion-containing revisions into persistent inclusions;
only addition-only steps have that interpretation.

## Executable law evidence

The tests compare normalized sparse values and ordered rank-three tensors; no
support iteration order or printed string is used as a semantic ordering. They
cover the two counit laws, coassociativity, coproduct and counit
multiplicativity, grading, both antipode convolution identities, and the unit,
product, coproduct, counit, antipode, and degree laws for formal revision maps,
including exact identity, empty-path, one-step, and finite composite-path
cases.

A test-local one-colour generator exhausts all locally admitted nullary,
unary, and binary rooted checked terms through four vertices:

```text
rooted terms by degree:  3, 9, 36, 162  (210 total)
complete / punctured:    8 / 202
forests by degree 0..3:  1, 3, 15, 73   (92 total)
ordered forest pairs:    282
```

These finite computations exercise the representation and laws; they are not
a formal proof for every finite equipped calculus. Each computation on a
finite input terminates, although the complete algebra for a calculus may
have infinite rank.

## Deferred scope

The implementation does not provide coefficient rings other than the
integers, completions or infinite series, explicit quotient modules or
arbitrary Hopf ideals, proof-identity quotients or commuting conversions,
coherent component reindexing, tag-family deletion, Birkhoff factorisation or
renormalisation, Green functions, resource polynomials, causal tracelets,
history polynomials, harmony, normalization, Cut elimination, further repair
frontiers, positive-arity repair, proof search, HCP,
execution/concurrency/effects/cancellation, a GUI, or a custom language.

Incidence remains trusted occurrence metadata rather than an independently
validated global condition. If it later participates in admission, CK closure
and all induced Hopf-map claims must be reassessed.
