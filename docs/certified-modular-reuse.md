# Certified incremental reuse

Run the public end-to-end examples with:

```sh
racket examples/certified-modular-reuse.rkt
```

`prepare-reuse(source, frontier, model)` accepts a native complete checked
proof, its exact native CK witness, and a rational-vector-space interpretation.
Keyword arguments declare the forward/bidirectional policy, linear observation,
live material-ID profile, recorded native four-schema history, and requested
contracts. The default requested contracts are behavior, boundary, replay and
profile. Add `fidelity` to require exact selector/coaction/signed-core equality.
Use `#:require '(behavior)` when only behavioral acceptance is intended.
Both preparation and update accept `#:semantic-budget (make-semantic-budget ...)`.
If context compilation or provider admission exhausts this budget, the operation
returns a `reuse-contract` with status UNKNOWN, phase and exhaustion reason;
it does not construct a partial preparation or accepted update. Callers should
check `reuse-preparation?` or `reuse-update?` before using their accessors.
Budget exhaustion during joint comparison remains an UNKNOWN behavior contract
inside a complete update, preventing acceptance when behavior was requested.

`apply-reuse-update(preparation, ordered-providers)` admits changed complete
providers, checks exact whole interfaces and native filling, evaluates the
compiled operation jointly, recertifies the new filled boundary, and replays
the stored checked open remainder history. Optional model/profile arguments
declare admission-base or trust-profile changes explicitly.
`verify-reuse-update(preparation, result)` independently evaluates native filled
proofs and verifies returned behavioral, replay and boundary evidence. Evidence
records are not checked proof constructors.

## Independent meanings

The result keeps separate contracts; one rejection does not overwrite the others.

| Contract | Positive result | Failure evidence |
| --- | --- | --- |
| Behavior | Exact equality for every external vector in the declared rational model | Native-verified basis input and observed coordinate |
| Boundary | Independently checked complete marked closure or strict theorem-family certificate | Native checked crossing history; incomplete exploration is UNKNOWN |
| Replay | Exact open event word, complete interfaces and physical hole routes, zero provider-body reads | Event/interface/read obligation that fails |
| Profile | Every current live material occurrence belongs to the declared profile | Exact occurrence address and material ID |
| Fidelity | Equal full represented selector, relative coaction and signed core | Differing represented term, or UNKNOWN when incomplete |

Equality is for the supplied *joint* provider tuple and explicit full-output or
linear observation. It is not proof equality, arbitrary future-provider
equality, operational completeness, or equivalence in every closed category.
Unsupported nonlinear observations do not receive this completeness verdict.
The finite group paper's normalization and quotation equations are not used.

The two-dimensional implication example changes the argument by an invertible
matrix M and compensates the body by its inverse. Because the native canonical
input order is `(a g)`, the actual body update is `E(M^-1 tensor id_g)`.
Both component summaries change, but the downstream operation agrees. Omitting
the body compensation returns a rational basis counterinput. New IDs fail the
old live profile; enlarging that profile repairs eligibility, not historical
provenance equality.

The tensor example preserves provider analyses while one native principal cell
changes the scaffold. Preparation charges compilation and admission; the update
reports zero context recompilations and zero unchanged-provider admissions.
`make-curried-family-reuse-fixture(m)` supplies the strict all-arity application
family with dimension-one atoms, m+2 primitive providers and the checked native
scaffold history. At m=2, its three local cells establish four primitive
singleton blocks plus one scaffold block. This is a local-cell count, not a
wall-clock bound or a generic polynomial certification claim.
The nested example records exact prefixed holes and checks staged/direct
evaluation and projected replay. The contextual m=2 later-provider example
is forward SAFE and bidirectionally UNSAFE. Its crossing describes where opacity
fails; no global minimum recomputation-cost claim is made.

## Cache and replay limits

Preparation retains the original proof, ordered detached tuple, complete
punctured remainder, interfaces, refill witness, compiled shared circuit,
component summaries, registry, routes, model/version, observation, policy,
profile and supplied history. The plan reports cached summaries, changed
components, affected interfaces, actual admissions, context recompilations and
replayed events. Preparation and update include separately measured phase
timings; these are empirical measurements, not mathematical certificates.
The independent verifier checks cache dependencies and recomputation counts.
Boundary certificates are source-bound and are never silently
applied to another filled proof, even when its interface is unchanged.

Opaque assembly traverses only rigid remainder vertices and gives the native
checker sealed provider handles. Projected events are freshly matched on open
native remainders with exact provider routes. A recorded provider-internal event
is rejected by this remainder-only replay interface; old internal histories
need separate certification. All-history safety and replay of the particular
stored open history remain distinct, especially for compound replacement.

An admission extension must preserve old ambient maps and dimensions. Changed
old assignments invalidate the compiled interpretation; behavioral comparison
for that cross-interpretation situation is currently UNKNOWN rather than an
implicit cast. Registry-changing replay also needs new history admission.
Full protected expansion and generic closure remain explicitly bounded.
Finite example checks are CODE-CHECKED evidence, not universal proofs or Lean
mechanization. The cited template arguments remain PAPER PROVED under their
strict hypotheses.
