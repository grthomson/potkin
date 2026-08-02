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

## Recursive frames and return chains

The occurrence-resolved derivative-frame multigraph is a separate finite
constructor analysis. It retains an edge `(a,i)` for every exact occurrence
and ordered positive premise slot, including parallel edges and equal premise
boundaries. A least fixed point stores one deterministic minimum-height proof
for each productive boundary and is used only to fill off-spine obligations.
Raw reachability, realised recurrence, and availability of a complete seed
are reported separately.

The realised-cycle theorem does not follow merely from graph reachability.
Cycle-to-context construction composes exact corollas and canonical side
fillers; context-to-cycle decomposition follows the unique literal puncture
path, retains its actual off-spine proofs, and reconstructs the source. The
boundary recurrence retains that decomposition and its reconstruction check.

For a positive one-hole `G -> G` context, the same recursive constructor
decomposition classifies every nonroot `G` frame on the puncture spine.
Include/omit recursion constructs return-factorisation chains. Independently,
the actual rightmost CK coproduct is expanded without collecting occurrence
witnesses. Surviving witnesses reverse to exactly those chains; endpoints,
off-spine cuts, and multicuts remain visible with zero reduced-character
evaluation. Thus the binomial convolution row is a consequence checked
against the explicit witness bijection, not inferred from a path length or a
bounded fixture.

The one separately labelled falsification oracle generates 11 contexts
through degree three, distributed `(1 3 7)`. It is intended to expose a
counterexample and is not a universal proof. Derivative-frame recurrence and
component-relation powers are static presentation analyses; they do not
implement proof-reduction loops, execution, cyclic-proof progress, or a
focusing discipline.

The expensive operations accept `#:limit`, defaulting to
`analysis-default-limit` (`10000`).  A calculation known to exceed its budget
returns an `analysis-limit` value with code `not-computed-limit` before an
enumerator yields any result.  This value is distinct from exact zero, false,
the empty-forest unit, and formal additive zero.  Passing `#:limit #f` is an
explicit request for unbounded exact calculation.

This layer analyses presentation ancestry and finite constructor recurrence
only. It does not assign semantic
identities to factors exposed in the unspecified traversal order of a
commutative proof forest, infer typed incidence, or claim a universal machine
proof of the manuscript's poset-Hopf results.
