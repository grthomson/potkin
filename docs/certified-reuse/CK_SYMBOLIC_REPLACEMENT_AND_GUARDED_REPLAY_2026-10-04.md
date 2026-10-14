# Complete symbolic replacement contracts and guarded CK replay

Date: 2026-10-04.

This note completes a previously missing programme milestone: a constructive, sound and complete downstream replacement checker for every typed CK remainder in one explicit linear functional fragment. The source remainder need not already have circuit shape. It may contain arbitrary higher-order Cut detours.

The result combines the existing occurrence-resolved CK decomposition and guarded replay theorems with a new parameter-uniform open-scaffold construction. It retains base-relative coactions and historical spectra as provenance obligations, separately from behavioral equality.

The proofs below are paper proofs. Three agents checked the mathematical obligations, practical scope and adjacent literature. No universal theorem was formalized in a proof assistant, and no repository code or tests were run this turn.

## 1 Coherence and attribution audit

The organising purpose remains:

> Certify which simultaneously detached typed proof regions can be changed, and which recorded transformations can be reused around them, while preserving a stated downstream observation and historical primitive eligibility.

The layers have different jobs:

| Layer | Mathematical object | Obligation |
|---|---|---|
| Decomposition | Native occurrence-indexed CK antichain and typed multi-hole remainder | Exact detachable interfaces, multiplicity and refilling |
| Operational reuse | Guarded history projection and marked origin/live maps | Same-event separated replay |
| Behavior | Symbolic contextual operation and joint future-uniform contract | Requested output observations agree |
| Provenance | Whole-monomial selector, relative coaction and inherited spectrum | Historical eligibility survives the declared transport |

The current task does not replace these layers with group theory or a generic graph implementation.

The audit found two tempting but weaker headline candidates.

1. Horn least-profile repair is useful, but its propagation algorithm is standard. Its project-specific theorem is the extraction from typed cells and propagation through guarded histories.
2. A largest Hopf ideal contained in an observational kernel, with iterated coproduct tests, is established Hopf-image theory. We checked a selector-stable connected-CK specialization, but do not claim that abstract quotient construction as new. Aggregate tensor equality would not itself supply a native occurrence bijection or guarded replay.

The stronger application-facing result is therefore the complete symbolic contract below, including a constructive rejecting input and its integration with the native reuse criterion.

A competent baseline is a typed zipper/tree cache with symbolic operation summaries and recorded read footprints. It can perform the same semantic calculation. No asymptotic superiority over that baseline is claimed. The distinctive candidate is the combined exact theorem over CK remainders, nested substitutions, guarded histories, future bases and historical coactions.

## 2 The equipped sequent calculus and interfaces

Use the nullary group instance of §§5–6 of
CK_RELATIVE_SOUNDNESS_AND_MODULE_QUOTIENTS_2026-10-04.md.

Fix a finite group \(G\) with \(|G|>1\). There is one atom \(p\), interpreted as the underlying set \(G\), and formulas
\[
A::=p\mid A\otimes B\mid A\multimap B.
\]
The sequent calculus is unit-free single-conclusion IMLL with exact occurrence-labelled antecedents, tensor/implication left and right, and Gentzen Cut. Atomic constructors are nullary:
\[
u_g:p\vdash p,\qquad q_a:\vdash p,
\]
with \(u_1\) the actual atomic identity. Atomic quotations are
\[
\operatorname{Cut}(u_g,u_h)\to u_{hg},\qquad
\operatorname{Cut}(q_a,u_h)\to q_{ha}.
\]
Use the identity, principal tensor/arrow, nonprincipal logical permutation and atomic quotation reductions specified in that note. Do not add reversible Cut-over-Cut permutations.

The already proved normalization theorem supplies strong normalization, Cut-free progress and denotational soundness for this relation. Its schemas and boundary transports are closed under the contextual instances used below. An incomplete concrete native registry may not supply every instance; that is an implementation admission obligation.

For \(n\ge1\), fix a bracketing and order of atomic occurrences in
\[
A_n=p^{\otimes n},\qquad F_n=A_n\multimap A_n.
\]
Write \(J_n\) for the closed judgment \(\vdash F_n\).

Every checked closed provider \(D:J_n\) has the unique semantic summary
\[
\nu(D)=(\mathbf g,\sigma)\in W_n(G):=G^n\times S_n,
\qquad
\llbracket D\rrbracket(x)_j=g_jx_{\sigma(j)}.
\tag{2.1}
\]
This is the universal classification in §12 of the earlier note, not a finite-fixture assumption. Every summary is realizable.

A remainder in this note has signature
\[
K:(J_{n_1},\ldots,J_{n_m})\longrightarrow J_N,
\qquad n_i,N\ge1.
\tag{2.2}
\]
Each physical hole occurs once. Equal logical provider labels may be assigned equal summaries subsequently; they must not collapse distinct physical holes during the proof.

The closed-provider hypothesis is essential. Open providers with nonempty antecedent boundaries need a separate interface theorem.

For a native proper CK cut, \(K\) is its retained typed remainder and the input order is its native ordered detached tuple. Forest multiplication does not recover this order. Empty cuts and the witness-free whole endpoint remain separate. A nodeless identity context can be used in context semantics without becoming a CK generator or a fabricated root cut.

## 3 Assumptionization is uniform over all fillings

### Lemma 3.1 Compound identity expansion

Every formula \(A\) has a Cut-free proof
\[
a:A\vdash A
\]
denoting identity, with exact occurrence routing.

**Proof.** Induct on \(A\). Use \(u_1\) at \(p\). For \(A\otimes B\), tensor-left exposes the two assumptions and tensor-right recombines the two induction proofs. For \(A\multimap B\), introduce an \(A\) assumption, use implication-left with the identity proofs on \(A\) and \(B\), and discharge the introduced assumption by implication-right. The categorical identity equation proves the claimed denotation. \(\square\)

For fixed \(A_n\), this construction has \(3n-2\) vertices; for \(F_n\), it has \(6n-2\).

### Lemma 3.2 Open scaffold construction

From every checked \(K\) in (2.2), construct an ordinary proof
\[
\widehat K:
 f_1:F_{n_1},\ldots,f_m:F_{n_m}\vdash F_N
\tag{3.1}
\]
by replacing hole \(i\) by its identity expansion
\(f_i:F_{n_i}\vdash F_{n_i}\), with distinct fresh occurrence labels.
For any mathematical functions \(P_i:G^{n_i}\to G^{n_i}\), interpretation of (3.1) at \(f_i=P_i\) equals interpretation of \(K\) filled by those operations.

**Proof.** Rebuild the context by constructor induction. Thread each fresh \(f_i\) through exactly the ancestor premises of its physical hole. Tensor-right and implication-left preserve the original disjoint context splits; unary rules add it to their unchanged side context; Cut adds it to the appropriate side without changing its active formula occurrence. Freshness avoids capture by implication-right.

Atomic constructors cannot be ancestors of a hole because they are nullary. This point is specific to the present equipment; it is not automatic for arbitrary multi-premise atomic bases.

Identity expansion denotes the identity operation on the function resource. Each reconstructed rule has the same contextual operation after that resource is instantiated, so semantic substitution follows by the same induction. \(\square\)

No provider proof is required to construct \(\widehat K\). In particular, no later provider body is inspected.

### Lemma 3.3 No state is hidden in the open scaffold

Define
\[
\chi(p)=1,\quad
\chi(A\otimes B)=\chi(A)+\chi(B),\quad
\chi(A\multimap B)=\chi(B)-\chi(A).
\]
For every checked proof,
\[
\chi(A)-\sum_{B\in\Gamma}\chi(B)
 =\#\{q_a\text{ leaves}\}.
\tag{3.2}
\]
Consequently \(\widehat K\) contains no \(q_a\), including beneath arbitrary compound Cuts.

**Proof.** Constructor induction: logical rules and Cut preserve the equality; \(u_g\) contributes zero and \(q_a\) one. In (3.1), the conclusion and each function assumption have charge zero. \(\square\)

## 4 Uniform open circuitization and its normalization budget

### Theorem 4.1 Circuitization of every remainder

Normalize \(\widehat K\) using the stated relation. Its Cut-free proof determines a finite acyclic linear wiring circuit \(C_K\) with:

- \(N\) ordered external input and output wires;
- one \(n_i\)-input/\(n_i\)-output box for every \(f_i\), used once;
- fixed unary group gates;
- explicit tensor reindexing and exact routes, with no copying or deletion of wires.

For every assignment of mathematical functions to the boxes,
\[
\llbracket C_K\rrbracket(P_1,\ldots,P_m)
 =\llbracket K\rrbracket(P_1,\ldots,P_m).
\tag{4.1}
\]
Thus the theorem is uniform over every checked provider filling, regardless of its size or intermediate higher-order Cut formulas.

**Proof.** Strong normalization and Cut-free progress apply to the open sequent (3.1). Reduction soundness is valid at arbitrary interpretations of its antecedent assumptions.

Modulo the supplied exchange transports, the Cut-free final rule must be implication-right. It cannot be atomic or tensor-right. A final implication-left on \(f_i\) would require a premise
\(\Gamma\vdash A_{n_i}\), where \(\Gamma\) consists only of zero-charge function assumptions. Its charge \(n_i>0\) would require state leaves, contradicting Lemma 3.3. Expand compound identity macros before this argument.

The resulting body has boundary
\[
f_1:F_{n_1},\ldots,f_m:F_{n_m},x:A_N\vdash A_N.
\tag{4.2}
\]
The Cut-free subformula property leaves only tensor rules, atomic \(u_g\), and implication-left on the original \(f_i\). Their domains and codomains contain only tensors of \(p\), so implication-right cannot occur in the body. Every \(f_i\) is consumed exactly once: context partitioning neither drops nor duplicates it, and no atomic leaf accepts a function assumption.

For a precise graph induction, consider any body subderivation with tensor-only antecedents and some unused \(f_i\), and tensor-only succedent. Flatten the tensor antecedents to labelled source-wire bundles and the succedent to labelled sinks.

At \(u_g\), insert one unary gate. Tensor-right takes disjoint union. Tensor-left reindexes a bundle. Implication-left on \(f_i\) connects its producer's \(n_i\) sinks through the box to the continuation's distinguished \(A_{n_i}\) source bundle. Producer and continuation use disjoint resources. Connections go only from producer to box to continuation, preserving acyclicity; all resource wires remain used once.

This inductive graph interpretation is exactly the rule interpretation in Set. Combine it with soundness of open normalization and Lemma 3.2 to obtain (4.1). \(\square\)

The equality is semantic. We do not claim
\(\operatorname{nf}(K[D_i])=\operatorname{nf}(\widehat K)[D_i]\) as literal proofs: filling function assumptions can create new beta/Cut redexes.

### Proposition 4.2 Provider-independent scaffold budget

Let \(V\) be the vertex count of \(\widehat K\). Every open-scaffold normalization run has at most
\[
4V^3+V^2+V
\tag{4.3}
\]
steps. Moreover
\[
V=|K|_{\rm rigid}+\sum_i(6n_i-2).
\tag{4.4}
\]
The normalized circuit has size bounded by the scaffold and interface sizes, independently of every provider's proof size.

**Proof.** In this nullary group instance, every reduction either decreases total vertex count or leaves it unchanged. Atomic quotation replaces a Cut and two atomic vertices by one; identity and principal reductions decrease it; nonprincipal logical permutations preserve it. One-use prevents duplication.

Use the already proved potential with \(M=1\):
\[
\Psi=A(1+(N+A)^2)+H,
\]
where \(A\) counts Cut and tensor/arrow constructors, \(N\) all vertices, and \(H\) the sum of Cut-premise sizes. Initially \(A\le V\), \(H\le V^2\), so \(\Psi\le4V^3+V^2+V\). Every step strictly decreases this natural number. Equation (4.4) follows from the inserted identity expansions.

Circuit extraction inserts one box per provider, one gate per atomic operation and the recorded wire incidences; it does not expand the eventual provider functions. \(\square\)

The step count is not a wall-clock bound. Boundary/routing representations and checking costs require a separate implementation analysis. In particular it does not claim the complete changed program normalizes in this budget: provider interiors are excluded.

## 5 A compact symbolic transfer operation

For a supplied provider summary tuple \(z\), circuit evaluation has form
\[
\Phi_K(z)=(C_K(z),R_K(z))\in W_N(G),
\qquad
\llbracket K[z]\rrbracket(x)_j
 =C_{K,j}(z)x_{R_{K,j}(z)}.
\tag{5.1}
\]

Use shared group-valued and index-valued arrays, rather than expanded group words. At a provider box, its group and permutation entries are variables. Identity and a fixed permutation have coefficients \(1\); a unary \(u_g\) has coefficient \(g\).

For serial composition, let the first operation have arrays \((a,s)\), the second \((b,t)\). Then
\[
c_j=b_j\,\operatorname{select}(a,t_j),
\qquad
r_j=\operatorname{select}(s,t_j).
\tag{5.2}
\]
Tensor juxtaposition concatenates the coefficient arrays and offsets the right index array by the left width. This tensor operation on semantic wire maps is distinct from CK forest multiplication.

The same recurrence evaluates an acyclic circuit in topological order: a provider output selects its input bundle entry according to its assigned permutation and multiplies its coefficient on the left. Before permutations are assigned, a downstream box can choose different upstream branches. There need not be one fixed literal group word for each output.

### Theorem 5.1 Symbolic transfer correctness and cost

The shared array circuit computes \(\Phi_K\) for every admitted summary tuple. If \(L\) counts its wire incidences, array entries and output references, construction and evaluation of the symbolic transfer require \(O(L)\) nodes/operations for fixed \(G\), given the normalized circuit.

**Proof.** Induct over its topological gate order. Equation (5.2) is direct function composition:
\[
b_j\bigl(a_{t_j}x_{s_{t_j}}\bigr)
 =(b_ja_{t_j})x_{s_{t_j}}.
\]
Disjoint tensor bundles and fixed routes preserve the formula. Every shared node is constructed and evaluated once; group-table lookup and array selection are constant-time under the stated model. \(\square\)

Do not expand shared expressions into trees. Domain admission, permutation validation, group-table certification, scaffold normalization and solving for unspecified replacements are separate costs. This theorem decides membership for a supplied tuple; it does not enumerate or solve all satisfying tuples.

## 6 Soundness and completeness of the joint replacement contract

Let \(K,K'\) be paired contexts with the same external width \(N\), after a checked correspondence of their input/output occurrences. Their hole tuples may be paired or different, as explicitly declared. Let \(O\subseteq\{1,\ldots,N\}\) be the observed output coordinates.

For supplied summaries \(z,z'\), write
\[
\Phi_K(z)=(c,r),\qquad \Phi_{K'}(z')=(b,s).
\]
Define the symbolic joint predicate
\[
\mathcal A_O(z,z')
 =\bigwedge_{j\in O}(c_j=b_j\ \land\ r_j=s_j).
\tag{6.1}
\]
Include the group and permutation domains as part of the admitted input specification. In the replacement case, fix \(K'=K\) and the old tuple \(z\), leaving the new tuple variable.

For each subgroup \(H\le G\), use the normalization-admissible subgroup base \(B_H\) with all \(u_h,q_a\) for \(h,a\in H\), retaining the same logical equipment. Take a common \(H\) admitting both contexts and summary tuples.

### Theorem 6.1 Complete future-uniform contract

Predicate (6.1) holds if and only if, at every future subgroup base \(H\le J\le G\), the two instantiated programs give equal observed normalized ground outputs for every available input quote \(x\in J^N\).

Equivalently (6.1) computes the exact joint UWP for those ground-input/output-coordinate observations.

**Proof.** Equal route and coefficient at every observed output give identical expressions \(c_jx_{r_j}\), so imply equality on all inputs and all future bases.

Conversely the terminal future base \(G\) supplies every ground tuple. On the all-identity input, equality gives \(c_j=b_j\). If \(r_j\ne s_j\), select a nonidentity \(a\in G\), put it at input coordinate \(r_j\) and identity everywhere else. The two outputs are \(c_ja\) and \(c_j\), unequal by group cancellation. Hence routes must agree.

Available normalized ground tuples are exactly \(J^N\). Applying either checked program to an input quote normalizes to the unique canonical ground tuple quote of its interpreted output. Thus equality of these outputs is operationally equivalent to the displayed semantic equality.

Finally, the earlier definition of UWP quantifies exactly over the same transported summaries and future observations. Its terminal-base characterization is the equivalence just proved. \(\square\)

The predicate is exact even for coordinated changes whose individual providers are not equivalent to their old versions. It need not factor into independent port contracts.

### Theorem 6.2 Constructive rejecting certificate

Failure of (6.1) yields a checked future-base ground input distinguishing an explicitly identified observed output.

**Proof and procedure.** Select a failed \(j\).

- If \(c_j\ne b_j\), return the all-identity tuple. It is available already at \(H\).
- Otherwise \(r_j\ne s_j\). Choose any fixed \(a\ne1\). At the admissible future base \(J=\langle H,a\rangle\), return the tuple with \(a\) at \(r_j\) and identity elsewhere. Its two outputs are \(c_ja\ne c_j\).

Quote the input with \(q_a,q_1\) and tensor-right. Its proof has \(2N-1\) vertices. The two application proofs normalize to distinct canonical ground outputs at \(j\). \(\square\)

After transfer evaluation, acceptance checking is linear in \(|O|\). A certificate can record the per-node shared evaluation values and the checked output equalities, or the failed output and input quote. Full explicit input-proof materialization costs \(O(N)\); this is separate from finding the output mismatch. If \(O\) is empty, acceptance is vacuous.

No claim is made about all-context equivalence, arbitrary B-eS completeness, unrestricted functional programs, or solving symbolic group/permutation constraints.

## 7 Nested CK derivatives and base changes commute semantically

The family \(\Phi_K\) is the semantic interpretation of the typed context operad, restricted to these closed wire-function interfaces.

### Theorem 7.1 Exact substitution and base naturality

For compatible inner contexts \(L_i\),
\[
\Phi_{K[L_1,\ldots,L_m]}(z)
 =\Phi_K\bigl(\Phi_{L_1}(z_1),\ldots,\Phi_{L_m}(z_m)\bigr),
\tag{7.1}
\]
with the recorded physical port ordering.

For \(H\le J\le G\),
\[
\Phi_{\iota K}(\iota z)=\iota\Phi_K(z),
\tag{7.2}
\]
and the exact future-uniform contract at \(H\) is the pullback of the one at \(J\) on transported tuples.

**Proof.** Typed filling is associative and interpretation is compositional. Circuitization preserves that operation uniformly over every filling, so (7.1) follows as equality of functions on summary domains. Its proof does not require the two compiled circuit presentations to be literally identical.

Inclusions preserve group multiplication, permutations, fixed coefficients and every array selection. Constructor/topological induction proves (7.2). Predicate (6.1) uses the same arrays under inclusion, proving the pullback equality. \(\square\)

Taking inverse images of (6.1) under the inner operations yields the same joint contract regardless of substitution staging. This is the semantic counterpart of the McBride/Faà di Bruno factorization of nested CK cut remainders. All flags use the retained ordered tuples and puncture correspondences before commutative collection.

This proves actual horizontal substitution and vertical base-change compatibility in the specified semantic instance. It does not by itself construct a double category of arbitrary proof transformations or turn all normalization histories into Hopf maps.

There is a standard categorical packaging, rather than a new collection of ad hoc annotations. Interpret the typed context category (or its tuple/category envelope) by \(\Phi\) in Set, and pull back the ordinary predicate fibration: the fibre at a summary interface is its poset of predicates, and reindexing along an inner context is inverse image under its transfer operation. Equation (7.1) is exactly the cartesian contract law. CK cut flags supply the typed factorization arrows; their occurrence-indexed witnesses retain attachments before algebraic collection. This packages contracts over the existing CK factorization structure without treating Boolean predicates as linear Hopf elements.

## 8 Integrated CK replay theorem

Assume a recorded checked history \(\sigma:T\Rightarrow U\) with the existing port-blind, one-use, separated-replay equipment. Its local cells preserve the chosen contextual semantics under coherent interface alignments at every admissible future base.

Let a native CK cut \(c\) give source factorization \(T=K[D_1,\ldots,D_m]\), with hole types as in (2.2). Keep its exact ordered detached tuple, cut addresses, punctured remainder and refill certificate.

### Theorem 8.1 Complete behavioral certification with independent replay eligibility

For admitted replacement providers \(D_i'\), the following two checks have distinct exact meanings:

1. The symbolic predicate for old versus replaced filled source contexts accepts exactly when their requested outputs agree on every future subgroup-base ground input of §6.
2. The native guarded-cut criterion accepts exactly when this recorded history admits separated projection along \(c\), under the already specified same-event replay definition.

For opaque reuse also require a certified open projected remainder history, whose exact matching, boundary/interface transport and absence-of-reads contracts are satisfied by the supplied fillings. When both checks and that remainder replay contract accept, replay that remainder history around the new providers. Admit and, when needed, normalize changed detached providers independently. Their old internal histories may be reused only with a separate replay certificate for those replacements. The resulting program preserves the old requested observations at every future subgroup base.

For positive common-module histories, inherited original-source spectra additionally give exact historical coaction and relative-core transport. Current replacement admission remains a separate obligation.

**Proof.** Claim 1 is Theorem 6.1, including its rejecting witness. Claim 2 is the earlier independent guardedness completeness theorem, applied to the retained occurrence witness.

On a guarded cut, every event projects into one detached component or the remainder. The separately certified projected remainder is open at the retained interfaces, with matching and read obligations discharged, so constructor/event-word induction proves its soundness for the new fillings. Independently normalized providers retain their own summaries by reduction soundness. Therefore the replayed target has the new filled source's observed function; the accepted predicate identifies that with the old requested function. Theorem 7.1 handles further nested substitutions and base changes.

For the positive common-module carrier, carry its original-source spectrum to each target module along retained origin/live maps. Corresponding module purity bits are identical; the protected hereditary cut correspondence gives a Hopf map \(\widetilde t\). Hence
\[
\rho_B^{\rm hist}\widetilde t
 =(\widetilde t\otimes\widetilde t)\rho_B^{\rm source},
\qquad
\Pi_B^{\rm hist}\widetilde t
 =\widetilde t\Pi_B^{\rm source}.
\tag{8.1}
\]
This is the inherited-spectrum theorem already proved, now joined to the exact behavioral checker. \(\square\)

Semantic acceptance does not make a non-guarded frontier guarded. Compensating provider changes can preserve the function while their interaction event must still be rerun or exposed. Conversely, guardedness and typing alone do not establish preservation of old outputs.

The symbolic compiler reads the scaffold and summary interfaces, never provider bodies; the native projected history needs the separate absence-of-reads certificate stated above. Guardedness by itself does not certify reuse of old internal detached-region histories on arbitrary new proofs.

If the native target proof frame and replacements are Cut-free, literal typed filling reconstructs a Cut-free proof. This conditional observation is not a promise that every closed-function provider frontier can remain opaque throughout complete normalization. Reinstantiating the assumptionized scaffold or its semantic circuit can create new application redexes.

The source coaction selects historical provenance-eligible detached modules. It does not waive checking newly supplied providers. The formal signed core is not itself a repaired or normalized proof.

## 9 A universal coordinated-update example

For two serial \(N\)-wire provider stages with summaries \((g,\sigma)\), \((h,\tau)\), the exact identity contract is
\[
\sigma(\tau(j))=j,\qquad
h_jg_{\tau(j)}=1
\quad(j=1,\ldots,N).
\tag{9.1}
\]
Thus one can change both routing and operations jointly, choosing
\(\tau=\sigma^{-1}\) and
\(h_j=g_{\sigma^{-1}(j)}^{-1}\).

This is an infinite proof-family result: every admitted provider proof with those summaries is accepted, regardless of its presentation size or higher-order temporary Cuts. An unmatched replacement has the constructive witness from Theorem 6.2.

It demonstrates a real difference from dependency-only analysis and independent-provider equality: correlated updates can be certified exactly. It does not demonstrate an asymptotic advantage over a symbolic zipper baseline or authorize replay of the atomic interaction that composes the two stages.

A useful integrated benchmark should retain a port-blind structural shell for replay while admitting changed provider summaries separately; crossing interactions are explicitly recomputed. Admission, compilation, semantic membership, guard checking and replay costs must be reported separately.

## 10 Achieved goal and next implementation boundary

The completed mathematical goal is:

> A parameter-uniform, sound and complete behavioral replacement checker for every checked CK remainder in the closed linear wire-function fragment, with a finite rejecting observation, exact nested-substitution/base laws, and guarded normalization replay integration.

Its conventional theorem package is now present:

- construction/existence for every admitted remainder;
- uniform semantic correctness under all fillings;
- normalization termination and a provider-independent scaffold budget;
- exact acceptance completeness and constructive rejection;
- compositionality under nested derivatives;
- exact admissible base-change naturality;
- explicit separation of semantic soundness, guarded replay and provenance.

No finite fixture was used to establish these universal statements.

This does not solve full BI/HCP normalization, general copying/erasure, full B-eS adequacy, arbitrary DAG scalability or all-context equivalence. The Avron hypersequent equipment remains part of the framework; its structural guardedness/provenance theorems remain available, but its semantic contract instance must be supplied separately. Actual Mix, Communication, Splitting and Shuffle remain checked rules rather than forest multiplication.

The next code task should be one integrated instance, using existing native checked proofs, cut witnesses, normalization/replay certificates and exact provenance:

1. Admit a finite-group atomic equipment and checked wire-provider summaries.
2. Compile a native closed-function-hole remainder using a certified open scaffold or an explicitly registered equivalent circuitization certificate. Missing contextual rules are reported, never inferred from rule names.
3. Build the shared routing/coefficient analysis DAG.
4. For a supplied update, return exact behavioral acceptance or the future-input quotation, while independently reporting guarded replay eligibility.
5. Carry historical spectra on the existing positive module certificate.
6. Exercise one genuine two-provider correlated update and one rejecting update; use direct full normalization only as a bounded independent oracle, not as the production algorithm.

No secondary proof, forest, cut, tensor or calculus carrier is authorized. Immutable derived circuits and semantic summaries are analysis IR, not an independently trusted proof carrier. Every returned proof artifact, including the rejecting input quotation, must be constructed and admitted through native proof APIs. Scope actual implementation edits only after matching these mathematical interfaces to the native APIs.

## 11 Proof ledger and attribution

| Statement | Proof | Evidence status |
|---|---|---|
| Identity expansion and fresh-assumption scaffold | Formula and constructor induction | PAPER PROVED |
| Universal open circuitization | Charge, Cut elimination, subformula analysis, graph induction | PAPER PROVED |
| Provider-independent scaffold step bound | Existing strict potential and nonincreasing size | PAPER PROVED |
| Shared symbolic transfer | Topological induction and array equations | PAPER PROVED |
| Exact future-uniform contract | Faithful action and terminal future base | PAPER PROVED |
| Constructive distinguishing input | Explicit state quotation and cancellation | PAPER PROVED |
| Nested derivative and base laws | Operadic composition and inclusion naturality | PAPER PROVED |
| Integrated behavior/replay/provenance | Exact contract plus existing guarded and historical theorems | PAPER PROVED |

All scopes are explicit. None is PROOF-ASSISTANT MECHANIZED or new executable repository evidence.

Primary comparisons used in the coherence/novelty audit:

- Banica and Bichon, Hopf Images and Inner Faithful Representations, Theorem 2.1 and Proposition 2.2:
  https://lmbp.uca.fr/~bichon/hifr.pdf .
  The universal Hopf-image idea is established background.
- Kock and Weber, Faà di Bruno for Operads and Internal Algebras:
  https://arxiv.org/abs/1609.03276 .
  Operadic substitution/factorization background is established.
- Necula, Translation Validation for an Optimizing Compiler:
  https://people.eecs.berkeley.edu/~necula/Papers/tv_pldi00.pdf .
  Before/after semantic validation is established.
- Acar, Blume and Donham, A Consistent Semantics of Self-Adjusting Computation:
  https://arxiv.org/abs/1106.0478 .
  Correctness of reuse/change propagation is established.

The candidate contribution is the complete conjunction of native typed CK derivative interfaces, exact correlated contracts, guarded replay and historical coaction transport. A bounded literature audit does not establish novelty certainty. The standard ingredients are explicitly attributed rather than presented as independent new inventions.
