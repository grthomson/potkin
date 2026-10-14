# Native logical CK upgrade certificates

This is a one-sided, unit-free MLL + binary internal Mix client of POTKIN's
native checked-tree and additive ordered CK APIs. It does not change the
commutative carrier, MILL client, hypersequent Communication rules, rational
observer, or existing prepare/apply/verify contracts. Logical nets are
auxiliary observations, never Hopf generators or checked proof evidence.

## Source-to-theorem map

| Datum | Source / public API | Scope |
|---|---|---|
| Formulas, duality, rank | `kernel/mll-schema.rkt`: `mll-formula?`, `mll-dual`, `mll-rank` | Literals, tensor, par; ordered children; no units |
| Indexed whole judgments | `mll-boundary`, `mll-boundary-formulas` | Native singleton one-sided hypersequent; canonical exchange, physical multiplicity |
| Rules and routes | `mll-id`, `mll-expanded-id`, `mll-apply`, `mll-occurrence-routing` | Atomic identity, ordered tensor, par, binary internal Mix, logical Cut; every passive occurrence retained |
| Frozen admission | `make-mll-schema-calculus` | Separate exact full/F0/F1 snapshots on the same native carrier; F0/F1 check every Cut rank |
| Exact observer | `analysis/mll-net.rkt`: `mll-observe`, `mll-net=?` | Retains current logical links and indexed ports; forgets only internal Mix presentation |
| Complete embedded regions | `mll-embedding`, `mll-net-quotient` | Injective ownership, disjoint regions, exterior attaches only at complete roots |
| Switches and cycles | `mll-net-switching`, `mll-net-correctness`, `mll-verify-cycle` | Physical edge IDs; disconnected acyclic switches allowed; finite budget yields UNKNOWN |
| Open sequentialization | `mll-sequentialize` | Whole source stars, exterior pars, full-graph components, genuine tensor/current-Cut splits |
| Normal identity | `analysis/mll-normalization.rkt`: `mll-normalize`, `mll-normal-identity` | Only complete checked proofs; atomic splices and principal tensor/par reductions; indexed axiom matching |
| Native contexts | `kernel/context.rkt`: `identity-context`, `complete-fill` | Existing typed punctures and native rechecking |
| Ordered marked term | `kernel/cut.rkt`, `hopf/ordered-ck.rkt` | Actual lexicographically aligned tuple before collection; positive open remainder, separate empty/whole endpoints |
| Query / verifier / consumer | `analysis/ck-upgrade-certificates.rkt` | ACCEPT / REJECT / UNKNOWN for this logical query only |

Public entry points are re-exported by `kernel.rkt`, `analysis.rkt`, and hence
`main.rkt`. Certificates bind the original checked input, exact registry,
embeddings, routes and current source-content digests. HEAD alone is not a
source identity when these files are uncommitted.

## Constructor arguments and evidence boundaries

**Paper argument supplied by the task.** With full schematic admission,
atomic-Cut local normal equivalents preserve correctness; universal rank-one
replacement correctness is equivalent to whole-source quotient correctness
and joint opaque native CK support. The code's fixtures are not a proof of
this universal statement. There is no Lean mechanization in this milestone.

The positive constructor keeps both par-child edges in the full graph. It
inverts actual exterior par links, not par syntax inside opaque exports. Full
disconnected components produce binary internal Mix. Otherwise an exterior
tensor or current logical Cut must split its principal roots: tensor removal
also removes the old result position; Cut removal exposes its dual roots.
Each recursive call removes a link or separates nonempty components.
Under the stated correct-quotient hypotheses the splitting lemma gives O(n)
calls and conservative O(n^3) naive graph work. This paper bound is not a
measurement of the whole query: switching validation and witness delivery
are currently explicitly bounded finite searches.

Atomic normalization splices the surviving identity partner into its dual
wire's producer, leaving all passive attachments unchanged. Principal
tensor/par normalization replaces their Cut by one Cut per corresponding
ordered child. Complete external root positions and ordered formula paths
anchor the resulting axiom pairs; private support names may change, but
normal axiom matching cannot. Incorrect raw assemblies are never normalized
to give them a proof identity.

The rank-one stress constructor uses actual native literal identity detours
`Cut(Par(T), Tensor(id_a,id_b))`. Its second detour selects the *fresh* first
anchor and the original opposite second anchor, even for repeated atom
types. It chooses atomic occurrences in the normalized provider body and
inserts checked gadgets while preserving every exterior logical link,
then obtains and independently checks a native presentation. It checks all
Cut ranks, the 2m Cut / 10m vertex bounds, unchanged Mix bound and indexed
normal identity. Chosen boundary connectivity is finite witness delivery.
For a cycle passage through two literal exports, `mll-literal-port-stress`
uses only one pair detour and five added vertices; it does not claim to
connect the other exports. Compound ports dispatch to the general body
constructor, never to a compound-principal Cut falsely labelled rank one.

**Unresolved trace contract:** this implementation's exact net substitution
and native sequentialization do not yet provide a registered sequence of
the requested passive Mix-exposure moves. Consequently they must not be
advertised as such a replay trace. Similarly, same-fixed-net positive
presentations do not establish a registered replay from the submitted tree.

## Certificate and consumption gates

An ACCEPT verifier independently rechecks all native rules, exact fixed
net/current Cuts, designated full provider regions, actual nonroot antichain,
ordered detached tuple, typed remainder, full physical seams and literal
refill. It checks the residual observer against the whole-source quotient.
One marked ordered coproduct term is returned; no class-sum coefficient is
computed. The atomic-Cut rank filter is used only when every original
provider is fixed by it; otherwise the term belongs to the full coproduct.
This is not the material-base selector, and normalization is not a Hopf map.

The consumer takes the **recomputed native CK remainder**, admits complete
same-interface fillers in the exact snapshot, reapplies seams hygienically,
and rechecks the filled native proof. Equal local normal classes are checked
again against whole normal identity. A same-typed different-normal filler can
be requested without a meaning-preservation claim. Material/profile,
registered replay, full-fidelity and cache-validity obligations remain
separate existing contracts; this client does not mark them satisfied.

A REJECT verifier independently validates every local replacement, every
Cut rank, local normal identity, the original exterior raw replacement
assembly, legal switching choices and actual simple physical cycles. It
checks each quotient source-star passage against an actual provider-owned
physical path, keeps the exterior par choices, and verifies that these paths
and the exterior edges form the delivered raw cycle. A
malformed/stale certificate or failure to deliver a cycle is UNKNOWN, not
REJECT. The raw counterassembly is not a native proof or CK generator.

Staging requires one supported union and its common native representative.
Each actual stage cut has a subsequence-to-union map; a later detached
provider cannot contain an earlier hole. Reverse seam insertion is checked
against direct filling. Chronological tuples need not be the union word.
Singleton ACCEPTs never license a union. Whole-host consumption uses an
external typed identity context and the witness-free endpoint; whole-host
staging currently returns an explicit UNKNOWN.

## Verification and limitations

The focused test and runnable example are bounded executable evidence, not
MECHANIZED universal theorems. Default correctness switch budget is 65,536;
sequentialization graph-work budget is 1,000,000; normalization has a 10,000
step cap; V1 selected-switch delivery has a 65,536 switch cap. Exhaustion is
UNKNOWN. Unsupported calculus, incomplete embeddings, foreign provenance,
unavailable admitted instances and stale content are also UNKNOWN.

The current general negative delivery verifies an actual lifted raw cycle
afresh. The registered passive-exposure trace remains a distinct unresolved
contract; native sequentialization is not evidence of that trace. No full
class-sum enumeration, future-registry stability, semantic-base adequacy,
Hopf normalization map, HCP transfer or performance advantage is claimed.

See `examples/ck-upgrade-certificates.rkt` and
`tests/ck-upgrade-certificates-test.rkt` for the executable certificate ledger.
Exact command results are recorded in the completion report.

### Checked execution, 9 October 2026

HEAD remained `e07d20fff427bf1fdee2f1770e386e99e555dece`. All task changes
remain uncommitted and unpushed; prior dirty work was preserved.

Commands ran from the POTKIN repository root:

```powershell
& 'C:\Program Files\Racket\raco.exe' make --vv .\potkin\analysis\ck-upgrade-certificates.rkt
& 'C:\Program Files\Racket\raco.exe' make .\potkin\kernel\mll-schema.rkt
& 'C:\Program Files\Racket\raco.exe' test --make --heartbeat .\tests\ck-upgrade-certificates-test.rkt
& 'C:\Program Files\Racket\racket.exe' .\examples\ck-upgrade-certificates.rkt
```

Two early verbose compilation attempts stopped in the new adapter (the
second took 4.18 seconds); their obscured diagnostic was isolated by the
nonverbose adapter command to `mll-schema.rkt:139:34`, one extra closing
parenthesis. The focused test then exposed a separate extra parenthesis in
`mll-normalization.rkt:144:64` (18.07 seconds, exit 1). After that fix, it
ran all cases: 11/12 passed (49.85 seconds, exit 1); the remaining fixture
mistakenly equated input-provider order with the newly returned native
forest order. That fixture and independently found provenance guards were
corrected: 12/12 passed (21.62 seconds, exit 0). The final required literal
shortcut was added and checked by a relevant rerun: **12/12 passed, 24.79
seconds, exit 0**. The test's `--make` also compiled current public imports.

The integrated example exited 0 in **5.11 seconds**, delivering singleton
ACCEPT/consumption, literal and compound batch REJECT/physical lifted
cycles, atomic batch correctness/normal preservation, higher-rank original
normalization, and supported joint/staged consumption with reversed union
index maps `((2) (1))`.

Three requested GPT-6.1 Sol workers performed construction, integration and
adversarial source cross-review; executing verification remained with the
root agent. No full suite, Lean, benchmark or separate smoke test ran. Smoke
was unnecessary because the focused test imports `potkin/main.rkt`.

Status: **CODE-CHECKED / BOUNDED-EVIDENCE** for the finite delivered native
certificates; supplied universal theorem remains a paper theorem, **not
MECHANIZED here**. Registered passive-exposure replay and whole-host staged
extraction remain explicitly unsupported, not silently certified.
