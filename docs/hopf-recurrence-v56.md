# Typed grafting cocycles and first-return recurrence

This document describes Potkin's finite, calculus-relative implementation of
typed grafting/comodule equations, protected factorisation defects, and
first-return recurrence in the integral CK proof-forest Hopf algebra.  It is
an executable theorem layer over the existing checked kernel: it introduces
neither a second proof syntax nor a new algebra carrier.

## Pointed inputs and typed grafting

For a concrete occurrence

```text
a : (G1,...,Gn) -> G
```

the input profile is an ordered tuple.  Position `i` contains either the
existing checked typed hole of boundary `Gi` or a positive checked term with
that root.  A pointed hole may occur only in the retained input tuple.  It is
not an empty forest, a CK generator, or an extra algebra basis value.

The pointed coaction of a hole has only `1 tensor hole`.  A positive input has
three occurrence-level kinds of choice: its whole-input endpoint, the empty
CK cut, and each proper CK cut.  The tensor-product input coaction chooses one
term independently in every ordered premise, multiplies the detached left
forests by commutative forest juxtaposition, and retains the right inputs in
premise order.  Equal detached factors retain multiplicity.  This forest
product is not filling, a hypersequent bar, Mix, assembly, or ordered premise
composition.

`typed-grafting-cocycle` constructs the recursive side of

```text
Delta_CK B_a(v)
  = B_a(v) tensor 1 + (id tensor B_a) lambda_Xi(v)
```

independently of `connected-coproduct`.  Its certificate retains each choice
tuple, the multiplied forest, ordered retained tuple, checked grafted
remainder, corresponding global CK witness, reconstruction, and both
collected formal tensors.  The forward map prefixes every local address by
its exact outer premise address.  The reverse map restricts a below-root CK
cut to every ordered premise region.  Both composites are checked, giving an
explicit witness bijection before collected-sum equality is tested.  The
public claim is a typed grafting cocycle or comodule equation, not a general
Hochschild cochain complex.

## Protected context defect

For a positive checked context `s` and a selected set of its addressed input
positions, a protected complete input receives the pointed coaction, an
unprotected complete input receives only `1 tensor t`, and a protected typed
hole may remain unresolved.  The evaluated defect is

```text
Omega_s^Prot(v)
  = delta_root(e_s(v))
    - (id tensor e_s) lambda_Xi^Prot(v).
```

The certificate keeps both its collected integral tensor and an uncollected
cut family.  Every output vertex is classified as fixed-context, protected
input, or unprotected input data, with its absolute and input-relative
addresses.  Restriction and address prefixing give the support bijection:

- the empty cut cancels;
- a cut wholly inside protected input regions cancels, including detaching a
  whole protected input;
- a cut entering fixed context remains;
- a cut inside an unprotected input remains; and
- a mixed cut remains exactly when at least one selected root is outside the
  protected regions.

Thus a one-vertex corolla has zero all-input defect, while a context with a
retained nonroot fixed vertex can have nonzero defect.  Local replacement
residues are literal differences of two such finite defects.  Their identity,
antisymmetry, and telescoping laws are checked as formal-sum equations.  No
claim is made about membership in an arbitrary schema-generated ideal,
coideal closure, or descent of a global proof congruence.

## Derivative frames: construction, not the Hopf theorem

The finite derivative-frame multigraph has one edge for every exact
occurrence and every positive ordered premise slot:

```text
G --(a,i)--> Gi.
```

Parallel edges and equal premise boundaries remain distinct.  An edge stores
the exact registry, occurrence, selected slot, source and target boundaries,
ordered off-spine requirements, open corolla, selected address, and supplied
component incidence.

Productivity is the least finite fixed point used only for off-spine
obligations.  It retains one deterministic minimum-height complete witness
per productive boundary, with structural tie-breaking, and never enumerates
a proof family.  The selected recursive premise need not be productive, so a
unary self-cycle can realise a positive one-hole context even when no complete
seed exists.

A raw cycle composes full corollas and may leave several obligations open.  A
realised cycle fills every off-spine obligation canonically while retaining
one distinguished recursive hole.  Conversely, unique-hole constructor
decomposition follows the literal puncture address, recovers the exact frame
walk and actual complete side fillers, and reconstructs the context.  These
two maps certify

```text
G lies on a realised frame cycle
  iff a positive checked context G -> G exists.
```

Graph reachability only selects a candidate.  The recursive decomposition and
inverse reconstruction are the theorem data.

## Boundary-return character and convolution witnesses

For one exact calculus snapshot `K` and boundary `G`, `rho_G` is one on a
connected positive context with exactly one `G` puncture and root `G`, and
zero on every other connected generator.  It extends multiplicatively to
proof forests, so its value on the empty-forest unit is one.  Exact calculus
identity is checked operationally.

The reduced functional is defined literally on a forest by

```text
bar-rho_G(F) = rho_G(F) - epsilon_CK(F).
```

It is not obtained by multiplicatively extending generator values.  Each
convolution power evaluates the actual rightmost-expanded
`iterated-coproduct`, including endpoints, off-spine cuts, and multicuts.
Annihilated occurrence witnesses are retained with their zero coordinate
evaluation rather than omitted.

For a return context `C`, the unique-hole constructor decomposition follows
the puncture-bearing child at every vertex and retains all ordered off-spine
children.  Its inverse fold reconstructs `C`.  A proper `G` return is a
nonroot constructor frame on that spine whose root boundary is `G`.

For power `n`, recursive include/omit decomposition of those frames constructs
all chains of `n-1` proper returns.  Independently, the code expands every
occurrence-level rightmost CK choice.  A surviving expansion must use one
proper singleton spine cut at every stage.  Reversing its inner-to-outer cut
sequence gives the unique outer-to-inner return chain.  Cutting that chain in
reverse reconstructs the same ordered tensor.  The certificate retains both
maps and both round trips, and only then checks the collected projection and
scalar identity

```text
(bar-rho_G ^ star n)(C) = binomial(r_G(C), n-1).
```

The binomial calculation and collected finite formal-sum equality are
independent checks of this constructor-level witness bijection; neither is
used as a substitute for it.

## Antipode and the sign qualification

The public first-return certificate evaluates the existing recursive CK
antipode formal sum.  With

```text
R_G,C(q) = sum_{n>=1} (bar-rho_G ^ star n)(C) q^n
         = q (1+q) ^ r_G(C),
```

the exact identities are

```text
R_G,C(-1) = rho_G(S_CK(C))
-rho_G(S_CK(C)) = 1  iff r_G(C) = 0.
```

The second quantity is the first-return indicator.  Writing
`R(-1) = -rho(S(C))` would be a sign error: for a first-return context both
sides would be `-1` and `1`, respectively.  A context may be first-return
relative to `G` while repeating another intermediate boundary; this is not
the same notion as an elementary graph cycle.

One separately labelled falsification oracle generates exactly eleven
one-colour positive one-hole contexts through vertex degree three, with
degree distribution `(1 3 7)`.  It compares the recursive addresses, actual
convolution powers, polynomial, and antipode evaluation.  This bounded
agreement is regression and counterexample-search evidence only.  The
universal result is organised by constructor decomposition and the explicit
witness bijection above.  The existing global degree-four fixture is not
enlarged.

## Unfolding, side evidence, and components

A certified first-return context can be inserted into its distinguished hole
recursively.  Every layer retains its checked context, literal prefixed
inserted-root and puncture addresses, and its own return certificate proving

```text
R_G,C^n(q) = q(1+q)^(n-1).
```

When a complete seed exists, an address-resolved iterated CK witness separates
the seed and every context layer in the API's tensor orientation.  Its actual
collected coefficient is reported and is not assumed to be one.

The side-evidence frontier consists of all complete off-spine child roots on
the unique puncture path.  Its CK witness retains the detached forest, bare
spine, new cut vacancies, and reconstruction.  `Box^G` is handled separately:
its side evidence is the empty-forest algebra unit and it has no fabricated
root cut.  Literal address prefixing and forest juxtaposition certify

```text
Sigma(C o D) = Sigma(C) Sigma(D),
```

including multiplicity of equal proof factors.  The multiplication remains
independent forest juxtaposition, never a hypersequent bar.

Component recurrence uses only supplied Milestone 7 incidence.  It composes
the puncture-to-root endorelation, recursively constructs checked powers
`C^n`, and compares each direct trace with the corresponding finite relation
power.  It records an observed preperiod and period, the identity power zero,
the scalar calibration `(0,0)`, and every local scalar defect.  Opaque
incidence yields an explicit unavailable result.  These finite relation
powers are static component transport, not execution semantics or a cyclic-
proof progress condition.

## Limits and deferred claims

Every potentially expansive construction has a finite limit guard and exposes
no partial result. Exceeding the caller's limit yields an `analysis-limit`;
it is not zero, acyclicity, unrealised recurrence, or unavailable incidence.

This milestone does not implement proof-reduction loops, cyclic-proof
soundness, normalization, confluence, Cut elimination, polarities, focusing
completeness, general bidirectional proof search, indexed nested sequents,
infinite Green series,
Dyson--Schwinger solvers, proof DAGs, or arbitrary quotient/coideal decision
procedures.
