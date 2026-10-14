# Codex milestone: certified incremental transformation and component reuse

Implement this in the existing POTKIN Racket repository. The goal is an **end-to-end certified incremental analysis workflow**: after a checked proof transformation, coordinated component replacement, or declared material-base/profile change, determine precisely what analysis survives, what must be recomputed, and why. Deliver runnable software, independently checked evidence and a reproducible comparison. The protected coproduct is supporting machinery, not the completion milestone.

Use GPT-6.1 Sol and available subagents. Follow AGENTS.md. Inspect the actual checkout and uncommitted changes first. Preserve unrelated edits, the legacy commutative carrier and existing APIs. Leave this work uncommitted; do not push. Proceed through the whole milestone rather than stopping after an algebra module, design note, or small fixture.

## Current starting point and scope

The user reports an uncommitted implementation of:

- `potkin/hopf/ordered-ck.rkt`, built directly from native detached tuples;
- `potkin/kernel/mixed-schema.rkt`, with frozen schemas and inverse-created instances;
- `potkin/analysis/ck-boundary-certification.rkt`, returning SAFE/UNSAFE/UNKNOWN with independent closure verification;
- public exports, focused tests, `docs/native-ck-certification.md` and `examples/native-ck-certification.rkt`.

The reported focused test file compiled and passed 30 cases. This is a starting report, not an independent source audit or universal mechanization. Build on the work that is actually present; repair substantive defects rather than creating parallel infrastructure.

Read the supplied papers, using their explicit hypotheses:

1. `CK_MIXED_PRINCIPAL_PROTECTION_2026-10-05.md`: exact four-schema registry, marked discovery, certificates and old-tensor conservativity.
2. `CK_HIGHER_ORDER_CERTIFIED_MODULARITY_2026-10-05.md`: oriented implication, rational-vector-space interpretation, application families and comparison laws.
3. `CK_ORDERED_CONTEXT_REUSE_2026-10-05.md`: the exact forward/bidirectional distinction and inverse-created crossing.
4. `CK_RELATIVE_SOUNDNESS_AND_MODULE_QUOTIENTS_2026-10-04.md`: separation of semantic, replay and provenance contracts.
5. `CK_SYMBOLIC_REPLACEMENT_AND_GUARDED_REPLAY_2026-10-04.md`: joint replacement, counterinputs, nested context composition and cost accounting. Its finite-group instance uses a DIFFERENT normalization registry; do not import its group-specific completeness or quotation rules into the mixed certifier.
6. `CK_PROJECT_TARGET_REGISTER.md`: T-IMP is the practical target, serving T-TRN/T-QUO and concrete T-DBL comparisons.

The supplied packet may be extracted into `docs/research/certified-reuse/`. The target register predates the latest uncommitted implementation report; inspect the current code to establish its actual status. These papers describe universal arguments, not verified implementations of the newly added native modules. Preserve the exact positive four-schema registry, both Cut orientations and the explicit forward/bidirectional policy. The general polynomial reachable-read problem remains mathematical research outside this implementation milestone.

## 1. Deliver one public preparation/update/verification workflow

Choose names consistent with the repository. An illustrative API is:

```text
prepare-reuse(checked-proof, checked-frontier, policy,
              material-interpretation, observations, profile)
apply-update(prepared-artifact, replacement-tuple,
             optional-checked-history, new-admission-base, new-profile)
verify-update(original-inputs, proposed-result)
```

The result must report separate contracts, each with its own evidence:

- **Boundary protection:** SAFE, UNSAFE with a checked crossing history, or UNKNOWN.
- **Behavior:** equal for every external input in the declared model, or a concrete differing input/output; unsupported or budget-limited checks are explicitly unassessed/UNKNOWN.
- **Recorded remainder replay:** eligible with a checked open projected history, ineligible with a precise failed obligation, or unresolved.
- **Material/profile fidelity:** the stated selector/coaction/core comparison holds, or an explicit differing occurrence/term, or unresolved.
- **Reuse plan:** named cached artifacts that remain valid, changed components requiring admission/analysis, affected scaffold interfaces, and actual recomputation performed.

Do not collapse these into one boolean. Return an accepted overall plan only when every contract requested by the caller is certified. The caller must be able to request behavioral acceptance without historical fidelity, or require both, with the distinction visible.

Preparation retains the ordered detached tuple, complete typed multi-hole remainder, physical hole correspondence and refill witness. Cache the compiled remainder operation and admitted component summaries. Version dependencies include exact occurrence routes, interfaces, material-ID interpretation, observations, registry, policy, profile and relevant source/history identity. Do not reuse a source-bound certificate for a different filled proof. Include a clear invalidation reason rather than silently recomputing everything.

## 2. Implement meaningful exact behavioral admission

Use the finite-dimensional **rational-vector-space model from the mixed paper**, with fixed positive dimensions for atoms, tensor products and internal hom. Implement exact rational matrices/tensors for all four logical constructors and both Cut orientations, including the actual coherent occurrence permutations, evaluation and currying. Empty antecedents use the semantic tensor unit; this does not introduce a logical unit or identify a positive proof with the empty forest.

Admit primitive material maps by exact checked interface dimensions. For compound replacement proofs, derive summaries through native checked syntax; count their admission and evaluation cost. Material IDs have an immutable ambient map assignment. A changed map is an explicit new interpretation/version or a newly admitted ID, not an unnoticed mutation.

Compile a typed multi-hole remainder into a shared contraction/composition circuit once, treating hole matrices as parameters. Evaluate supplied old and new tuples JOINTLY. Admit observations only as the full output or an explicitly typed rational LINEAR map O, including selected output-coordinate projections. Compare O F_old and O F_new exactly. Equality certifies equality for every external vector in this declared interpretation. A nonzero entry of O(F_new-F_old) supplies a basis input and an observed output coordinate with different rational values. Independently evaluate that counterinput and its observed outputs on both native filled proofs. Unsupported nonlinear observers must not receive this matrix-completeness verdict.

Support simultaneous replacements whose individual maps differ but whose complete downstream operation agrees. Do not substitute independent equality tests at each hole for the joint contract. Fixed-tuple matrix equality is not arbitrary future-provider equality, proof identity, operational adequacy or equivalence in every SMCC. Any stronger future-parametric contract requires an actual exact formal-coefficient identity procedure; label it unassessed unless implemented and justified.

Keep computation shared. Sparse or lazy exact representations are acceptable; equal hash values or sampled inputs are not equality certificates. Budget exhaustion must be explicit.

## 3. Make protected CK operations support the workflow

Audit ordered product, coproduct and cut collection against the actual native occurrence witnesses. Keep ordered forests distinct, indexed multiplicities and typed residual attachments intact. Derive ordered data before legacy commutative aggregation. Any forgetful comparison with that legacy carrier needs its own proof; it is not assumed Hopf.

Implement retained native antichains from exact protection and check factor/remainder heredity with coherent source transports: recomputed protection on every certified safe detached factor and punctured remainder must agree with the original restriction. Carry this into protected iterated coproducts/flags, the declared pure material selector pi, relative coaction rho=(pi tensor id)Delta and signed core Pi=m(S pi tensor id)Delta.

State the actual carrier and selector hypotheses. The ordered core is a signed forest-concatenation expression; it is not a filled proof, normalization procedure, or automatically an algebra/Hopf endomorphism. Do not import claims that depend on commutativity. Keep live material eligibility separate from inherited historical spectra.

Demand equality of full represented objects for full-fidelity verdicts, retaining occurrences and attachments before collection. A single coaction term can certify a failure but cannot certify full equality. Avoid eagerly materializing exponentially many provider-subset terms for large families: use an exact factored/lazy representation where justified, or enforce a visible budget. Linear-size protection does not imply a linear-size expanded coproduct.

## 4. Implement opaque replay and precise exposure

Project a supplied checked transformation history along a guarded native frontier. Certify that the remainder history is open at the complete hole interfaces and that no event reads inside the replacement providers. Replay that stored remainder history around new admitted same-interface fillings, preserving event order and routing. Changed provider interiors are independently analyzed; their old internal normalization histories are not automatically reusable.

For an unsafe frontier, identify the crossing source-origin block and its attached typed interface using the existing exact protection/counterhistory evidence. Give the concrete region where opacity fails and recomputation must resume. Do not call an exposure plan globally cost-minimal without a separate optimization theorem.

Crucially, same-interface compound refilling may enable new interactions. Reusing a checked open remainder history and reusing all-history boundary safety are DIFFERENT claims. Re-certify the latter on the new filled source; if certification cannot close, return UNKNOWN for that contract. The replay certificate may still certify the particular stored history.

## 5. Add useful exact certification paths

Retain the complete generic marked-state procedure and independent verifier. Deduplicate `(U, pi, lambda)`, merge the entire read shell and relabel outside vertices sharing merged origins. Enumerate every routed schema instance at every reached state, including inverses; freeze schemas/admissibility, not a fixture list. SAFE needs complete independently checked closure. UNSAFE needs a replayed actual crossing. Limits or unsupported generation produce UNKNOWN.

Add strictly admitted theorem-based certificates for the tensor bundles, curried applications and ordered surrounding-context family. Their recognizers must check every theorem hypothesis: exact constructors, distinct nullary primitive occurrences, physical port order, complete routes and relevant formula/position restrictions. Their verifiers check these templates and partitions independently. These are structured-family algorithms, not a general polynomial claim. Where hypotheses fail, use general certification or return UNKNOWN.

For the m-argument application, retain one scaffold block and m+2 primitive singleton blocks. Its m(m+1)/2 history length is a local-cell count, not a wall-clock bound. Preserve the contextual regression: the whole bundle edge is forward-safe for every producer position, bidirectionally safe exactly at the first position; a later dependency has a checked inverse crossing.

## 6. Show actual comparative and application payoff

Deliver a reproducible native example suite with all of these outcomes:

1. **Successful shape-changing reuse:** a tensor or curried-application conversion changes the scaffold while a certified provider frontier survives. Reuse the compiled open operation and unchanged component summaries, and show precisely which work was avoided and why the certificates license it.
2. **Joint replacement:** in an implication application choose a nontrivial invertible rational matrix M. Replace argument map D by M D and body map E by E(id_Gamma tensor M^-1). Both component maps change, but the complete external operation agrees. Use dimensions greater than one in at least one example. Admit the new IDs/maps explicitly and preserve the exact interfaces.
3. **Behavioral rejection:** omit one compensating change and return a verified rational basis counterinput.
4. **Operational rejection:** execute the two-step m=2 later-provider inverse crossing, while the forward-only policy accepts the same frontier. Report the actual exposure interface.
5. **Provenance rejection despite equal behavior:** use new material IDs with compensating maps, so behavior is accepted but the caller's old live trust profile rejects a specific retained provenance term. A larger declared profile may admit those IDs; this repairs eligibility, not automatically equality of old/new provenance expressions or historical fidelity. Do not disguise historical labels as current eligibility.
6. **Concrete comparison square:** old tensor-to-mixed inclusion horizontally, nested admitted profiles vertically, with unchanged ambient IDs/maps. Use conserved arrow charge to certify that no new arrow instance can occur on the old source. Check protected decomposition and selector/coaction/core transport through that actual inclusion at each profile, then the justified vertical composition/naturality laws. Profile inclusion alone does not make two coactions or cores equal. A component replacement is not automatically this Hopf map. Admission-base extension and trust-profile growth are separate operations and must be labeled separately.
7. **Nested reuse:** compose two typed remainders and compare staged versus direct filling/evaluation and projected replay, retaining the exact hole shuffle. Use protected cut flags where the certified boundaries allow it.

These examples must exercise the public workflow, not bypass it through test-only helpers. Explain the application in plain terms: which stored analysis is reused, which contracts justify that reuse, and which failed contract requires renewed checking.

## 7. Compare honestly with a competent baseline

Implement or adapt a typed zipper/DAG cache baseline with the SAME exact semantic summaries, observations and read information. Compare both with cold full recomputation and repeated updates. Do not give the baseline weaker typing, an inferior representation or a different quantification over histories. If its protection contract differs, mark that comparison incomparable. It may obtain the same reuse decisions; that is an acceptable result.

Report proof/provider admission, context compilation, protection preparation, update checking, replay, provenance-query work, rational arithmetic and output materialization separately. Include state/certificate sizes, coefficient growth, operation counts and reproducible cold/warm timings. Benchmark increasing structured family sizes and a few generic cases under explicit limits. Preparation is not free, and expanded subset coproducts may dominate. Claim a speedup only where measurements support it; no intrinsic advantage or historical novelty follows merely from using CK.

## 8. Validation and completion gate

Use independent subagents for (a) typing, semantic equations and witness correctness; (b) closure/certificate soundness, occurrence transport and protected heredity; and (c) practical value, baseline fairness and scope. Coordinate edits so reviews remain independent. Resolve substantive findings.

Run the relevant tests and the repository-required regression suite, adding meaningful tests for wrong orientation/consumer ancestry, repeated formula occurrences, stale certificates, altered origin labels, omitted closure successors, profile changes, compound refilling, numerical compensation and nested hole shuffles. Also check exact protected iterated coproduct/coaction/core identities on focused native cases and review the universal constructor/flag arguments. Do not present a finite case count as their proof.

Completion requires a stable public API, separate verifiers for returned evidence, one documented runnable command exercising the complete workflow, a reproducible comparison report, and passing required checks. State the declared interpretation and every unresolved contract. Summarize changed files, actual checks, observed reuse and remaining limitations. Distinguish paper proof, code-checked evidence and mechanization. Leave the work uncommitted and preserve unrelated changes.

This is one ambitious integrated milestone. It does not require full Cut elimination, identity erasure, new Communication equipment, a Lean port or a speculative polynomial algorithm. Its success is a demonstrably useful certified reuse operation with honest failure explanations, supported by the existing CK mathematics.
