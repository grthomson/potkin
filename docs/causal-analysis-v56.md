# Premise ancestry and convolution analysis

Potkin's analysis layer derives a finite causal poset from one connected
checked proof or proof context.  Its vertices are rule-occurrence addresses;
punctures are typed vacancies and are not vertices.  The order follows the
v56 convention:

```text
descendant <= ancestor
```

Consequently, a downward ideal is a union of detached descendant subtrees.
The empty CK choice represents the empty ideal, an ordinary nonroot cut
represents the union below its address antichain, and a separate whole-tree
choice represents the total ideal.  The whole endpoint is analysis data only:
it is never admitted by `validate-ck-cut` or `in-admissible-cuts`.

`cut-size-polynomial` returns an immutable coefficient vector whose index is
the cut cardinality.  For the running proof `i(m(bS,bT))` it is `#(0 3 1)`,
meaning `3q + q^2`; the nonroot ancestry width is two.

Root-first refinement orders are reverse linear extensions.  Reconstruction
starts at the typed identity context and inserts the target's exact corolla at
each address.  Addresses occupied by punctures in the target never occur in
the order, so those punctures remain unresolved.

For a positive integer `n`, `iterated-coproduct` expands the rightmost tensor
coordinate and retains zero-degree endpoint layers.  Its coefficient sum is
`zeta-convolution-power`.  Independent memoised ancestry recurrences compute
`weak-order-map-count`; the two values agree on finite checked inputs.  At
vertex degree `N`, selecting rank-`N` tensors whose every coordinate has
degree one gives `omega-one-convolution-power`, independently checked by
`linear-extension-count`.

The expensive operations accept `#:limit`, defaulting to
`analysis-default-limit` (`10000`).  A calculation known to exceed its budget
returns an `analysis-limit` value with code `not-computed-limit` before an
enumerator yields any result.  This value is distinct from exact zero, false,
the empty-forest unit, and formal additive zero.  Passing `#:limit #f` is an
explicit request for unbounded exact calculation.

This layer analyses presentation ancestry only.  It does not assign semantic
identities to factors exposed in the unspecified traversal order of a
commutative proof forest, infer typed incidence, or claim a universal machine
proof of the manuscript's poset-Hopf results.
