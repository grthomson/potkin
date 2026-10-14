# CK relative soundness and canonical module quotients

Date: 2026-10-04.

This note advances the existing POTKIN programme without replacing its proof carriers or its hypersequent results. It supplies three missing pieces: a precise semantic contract for replacements at typed cuts; a canonical protected-module quotient that preserves exactly the base information required by coactions; and a universally normalizing multiplicative instantiation with an explicit functional interpretation.

The principal contribution candidate is their compatibility with occurrence-resolved, guarded CK replay. The predicate-transformer machinery, group multiplication, and standard multiplicative Cut reductions are established ingredients. Their individual novelty is not claimed.

The continuation in §§12–17 extends the one-wire calibration to arbitrary linear wire programs and develops constructive repairs for coaction obstructions. It also distinguishes future-base observational refinement from inherited historical provenance.

Every theorem below is a paper theorem under the displayed hypotheses. No universal theorem was checked in Lean, and no repository code or tests were run for this note. Three independent agents checked the contract laws, normalization argument, quotient descent criterion, concrete interpretation, and scope.

## 1 Fixed architecture and notation

The organizing question remains:

> Which typed proof decompositions can be replaced, normalized and reused through a recorded transformation and a change of primitive base, while satisfying a specified downstream semantic contract?

There are four layers.

1. Checked proof contexts and their substitution form a typed, ordered context operad. A physical proof port is a particular input position, not a logical port name and not a CK vertex.
2. Port-blind, one-use rewrite histories determine marked origin cospans. Their guarded CK cuts are exactly the decompositions separated for that recorded history.
3. Whole-monomial base selectors give relative coactions and signed relative cores. They certify provenance eligibility.
4. Semantic operations and predicates certify downstream behavior. This is a separate obligation, now made compositional below.

Independent forest multiplication is not Gentzen Cut, Mix, Communication, or function composition. Gentzen Cut is a typed two-premise constructor; its formation is a particular grafting operation. Eliminating that constructor is an operational rewrite, not multiplication by an antipode.

The existing generic history theorem permits erasing cells. The stronger connected-module and two-endpoint Hopf theorem applies only to positive connected cells using each physical proof-provider port exactly once. Identity–Cut elimination can fall outside that positive sector. We will use the generic theorem for sound replay and the positive sector for the module quotient.

A base-purity selector is written
\[
\pi_P(F)=
\begin{cases}
 F,&F\text{ is wholly }P\text{-pure},\\
 0,&\text{otherwise}.
\end{cases}
\]
It retains the empty forest, which is the algebra unit. It is distinct from additive zero and a typed vacancy. Set
\[
\rho_P=(\pi_P\otimes\mathrm{id})\Delta,
\qquad
\Pi_P=m(S\pi_P\otimes\mathrm{id})\Delta.
\tag{1.1}
\]
These equations apply to the appropriate ordinary, protected-module, or history Hopf carrier; the carrier must always be stated.

## 2 Semantic equipment at typed interfaces

Let \(\mathcal E\) be an essentially small category of admissible equipped base extensions. It is not the category of arbitrary atomic-rule additions. Later normalization assumptions define one useful admissible class.

For a typed judgment \(J\), suppose semantic carriers \(V_B(J)\) are equipped with functorial transports
\[
t_e:V_B(J)\longrightarrow V_C(eJ),\qquad e:B\to C.
\]
For simplicity equations below use strict interface representatives; coherent transport of complete boundaries, premise positions, and occurrence labels gives the equivalent indexed formulation.

A checked context
\[
K:(J_1,\ldots,J_m)\to J
\]
has an operation
\[
\operatorname{ev}_{K,B}:
 \prod_i V_B(J_i)\longrightarrow V_B(J).
\tag{2.1}
\]
Require compositional evaluation, including the recorded ordered port shuffle, and transport naturality:
\[
\operatorname{ev}_{K[L_1,\ldots,L_m],B}
 =\operatorname{ev}_{K,B}
    (\operatorname{ev}_{L_1,B},\ldots,\operatorname{ev}_{L_m,B}),
\]
\[
\operatorname{ev}_{eK,C}\,t_e^{\rm in}
 =t_e^{\rm out}\operatorname{ev}_{K,B}.
\tag{2.2}
\]
These are semantic hypotheses to prove for an instance. They do not follow from provenance labels alone. For a fixed context, quantify only over bases admitting its transported schema; equivalently, work in the extension category above its admission base.

For comparison of contexts \(K,K'\), put
\[
X_B=\prod_i\bigl(V_B(J_i)\times V_B(J_i')\bigr).
\]
The declared port correspondence determines how this paired tuple is split into the two input tuples. Including any chosen observations, let
\[
q_B:X_B\to O_B\times O_B'
\]
be their paired contextual evaluation. For a desired output relation \(R_B\), define
\[
W_B=\operatorname{WP}_{K,K'}(R_B)=q_B^{-1}(R_B).
\tag{2.3}
\]
This is the largest sufficient joint input relation, equivalently the weakest sufficient restriction. It need not factor into separate relations at individual ports.

The construction is ordinary inverse-image predicate semantics. Its role here is to decorate a typed CK factorization with an independently defined semantic replacement criterion.

### Theorem 2.1 Exact substitution law

If \(E_B:Z_B\to X_B\) evaluates the inner paired contexts, with their recorded port order, then
\[
\operatorname{WP}_{\rm composite,B}(R_B)
 =E_B^{-1}\operatorname{WP}_{K,K',B}(R_B).
\tag{2.4}
\]

**Proof.** Typed operadic associativity gives \(q_{\rm composite,B}=q_BE_B\). Inverse image preserves composition:
\((q_BE_B)^{-1}R_B=E_B^{-1}(q_B^{-1}R_B)\). This proves the equation for any nesting depth by induction on context substitution. No enumeration of proof trees or cuts occurs. \(\square\)

### Theorem 2.2 Weakest base-uniform contract

For an arbitrary predicate family \(W\), define
\[
\mathcal U(W)_B
 =\bigcap_{e:B\to C}t_e^{-1}(W_C).
\tag{2.5}
\]
A family \(F\) is persistent if \(t_e(F_B)\subseteq F_C\) for every extension. Then \(\mathcal U(W)\) is persistent, is contained in \(W\), and is the largest persistent family contained in \(W\):
\[
F\text{ persistent}\quad\Longrightarrow\quad
 F\subseteq W\ \Longleftrightarrow\ F\subseteq\mathcal U(W).
\tag{2.6}
\]

**Proof.** The identity extension gives \(\mathcal U(W)_B\subseteq W_B\). If \(x\in\mathcal U(W)_B\), then for \(e:B\to C\) and every \(f:C\to D\),
\(t_f(t_ex)=t_{fe}x\in W_D\); hence \(t_ex\in\mathcal U(W)_C\). Finally if \(F\) is persistent and \(F_C\subseteq W_C\), then \(x\in F_B\) implies \(t_ex\in W_C\) for every \(e\). The reverse implication uses \(\mathcal U(W)\subseteq W\). \(\square\)

Thus define the base-uniform weakest precondition by
\[
\operatorname{UWP}_{K,K'}(R)=\mathcal U(\operatorname{WP}_{K,K'}(R)).
\]
The operation \(\mathcal U\) is a coreflection from arbitrary predicate families to persistent ones. It preserves arbitrary intersections.

If inner evaluation is transport-natural, \(E_Ct_e^Z=t_e^XE_B\), then
\[
\mathcal U_Z(E^{-1}W)_B=E_B^{-1}\mathcal U_X(W)_B.
\tag{2.7}
\]
Indeed pull inverse image by \(E_B\) through the intersection in (2.5), using naturality. This gives an exact uniform substitution law, even when base change itself is only lax.

Quantifying over future bases can add information when future bases supply additional observations. If all observations and their relation already persist forward, ordinary WP is persistent and \(\mathcal U(WP)=WP\). We do not claim uniformization is nontrivial in every instance.

### Theorem 2.3 Exact base change from amalgamation and reflection

Suppose every pair \(e:B\to C,f:B\to D\) admits
\(e':C\to E,g:D\to E\) with \(e'e=gf\). Suppose also
\[
t_g^{-1}(W_E)\subseteq W_D
\quad\text{for every }g:D\to E.
\tag{2.8}
\]
Then
\[
\mathcal U(W)_B=t_e^{-1}\mathcal U(W)_C.
\tag{2.9}
\]

**Proof.** Forward inclusion is persistence from Theorem 2.2. Conversely take \(t_ex\in\mathcal U(W)_C\) and arbitrary \(f:B\to D\). Amalgamate the two extensions. Then
\(t_g(t_fx)=t_{e'}(t_ex)\in W_E\).
Reflection (2.8) gives \(t_fx\in W_D\). Since \(f\) was arbitrary, \(x\in\mathcal U(W)_B\). \(\square\)

For a growing observer family, reflection follows if every old observer has a transported observer whose success on transported values implies its old success. Commuting observation transport together with a reflecting observation relation suffices. Injective input transport alone is insufficient.

Both hypotheses are necessary for this proof and cannot be omitted generally:

- A chain sending Boolean values to a singleton can turn equality into the whole relation. It amalgamates but fails reflection, and (2.9) fails.
- A fork \(B\to C,B\to D\) with no common future can have singleton carriers, \(W_B=W_C=\{\ast\}\), and \(W_D=\varnothing\). Reflection holds, but \(\mathcal U(W)_B=\varnothing\) whereas the pullback of \(\mathcal U(W)_C\) is \(\{\ast\}\).

Together with (2.7), (2.9) gives an exact commuting reindexing law for the square
\[
\begin{array}{ccc}
Z_B&\xrightarrow{E_B}&X_B\\
\downarrow t_e^Z&&\downarrow t_e^X\\
Z_C&\xrightarrow{E_C}&X_C .
\end{array}
\]
This is a precise base/substitution compatibility statement. A full Beck–Chevalley theorem involving pushforward adjoints is not claimed.

### Proposition 2.4 Independent contracts and correlated replacement

Separate persistent port contracts \(C_i\) are safe precisely when
\[
\prod_i C_{i,B}\subseteq\operatorname{UWP}_{K,K'}(R)_B.
\tag{2.10}
\]
There need not be a greatest safe tuple of separate contracts.

**Proof of the negative statement.** On two Boolean coordinates let
\(W=\{(0,0),(1,1)\}\). Both singleton rectangles are safe. Any componentwise greatest safe tuple containing both must contain the whole square, which is not safe. \(\square\)

At a single base, with all other contracts fixed, the greatest safe contract at one chosen port does exist:
\[
C_i^{\max}=\{x_i:\forall x_{-i}\in\prod_{j\ne i}C_j,\ (x_i,x_{-i})\in W\}.
\tag{2.11}
\]
The pointwise family in (2.11) need not be persistent: another port can acquire additional permitted values at a future base. If \(A_B\) denotes that pointwise residual, the greatest persistent safe one-port family is \(\mathcal U(A)\), by Theorem 2.2. Thus CK independence of proof regions and semantic independence of their replacements are distinct. The correct universal semantic object is the joint relation.

## 3 Relative soundness of guarded CK replay

Assume every registered open rewrite cell is port-blind, one-use, and preserves contextual evaluation for all admissible typed fillings at every admissible future base. Its exact interface transport is part of the cell equipment. Source/target interface alignments here are coherent isomorphisms, with observations and the output relation reindexed along them; equality after an arbitrary collapsing output map would not suffice.

### Theorem 3.1 Uniform semantic replay and contract invariance

For a checked history \(\sigma:T\Rightarrow U\), let a source typed CK factorization be guarded for \(\sigma\) in the independently defined separated-replay sense. Its projected detached histories and projected remainder history are semantically sound. Consequently their paired WP and UWP contracts are unchanged under the recorded interface alignment.

Every replacement tuple satisfying the relevant UWP gives the specified downstream relation after replay, at every admissible future base. This applies to joint contracts as well as products of independent contracts.

**Proof.** Local soundness is stable under insertion into a checked context by (2.2). Induction on the event word proves whole-history soundness. Guardedness projects each event into exactly one detached region or the remainder; the same induction proves soundness of each projected history. Hence the paired contextual evaluation maps agree after their exact input/output transports. Taking inverse images gives WP invariance; taking (2.5) gives UWP invariance. Membership in that inverse image is exactly the required downstream relation. \(\square\)

No positivity assumption is needed for this semantic theorem. A projected remainder can become the nodeless typed identity context. That context is not an extra CK generator.

Theorem 3.1 uses the existing guarded completeness theorem, but its semantic replacement criterion is independently (2.3). It is not defined by a cut count, nor by successful reconstruction alone.

For a cut flag, its typed remainders compose by context substitution. Theorems 2.1 and 2.2 therefore make contract propagation independent of the order of staged substitution. Marked causal pushouts make history projection associative. These are the operational and semantic parts of the same compositional certificate.

The relative coaction selects the guarded detached forests whose entire provenance is trusted. Attach contracts to its occurrence-indexed witnesses before collecting equal tensor monomials. This retains ordered ports and multiplicity. Predicates have no additive inverse, so this does not assert a Hopf homomorphism from integer formal sums to Boolean semantic support.

A non-guarded source cut is still a valid typed context and has a WP. It does not admit separated replay of that particular history. A successful joint contract can justify a changed computation, but interaction across that frontier must be exposed or rechecked; it does not authorize opaque reuse of the old event sequence.

## 4 Canonical semantic quotients of protected modules

Fix a common equipped calculus and the positive connected-module sector established in the existing hypersequent note. Contract causal classes to module vertices. A vertex label \(M\) is an actual positive checked open context.

Let \(I(M)\) contain every structural interface field needed for edge checking and hereditary cuts: the output judgment, ordered physical input judgments, occupied and vacant input positions, complete boundary transport and component/formula routing, and any retained guards. Equal interface records are strict or have supplied coherent identifications.

Internal cuts of a protected module are forbidden. Its existing typed vacancies remain inputs, not vertices. The CK coproduct sees exactly intermodule edge antichains. Retained local matching guards do not impose additional coupled cut-policy restrictions; any such restriction would require its own hereditary coalgebra theorem. Use module-vertex count for the connected grading; original proof size is a different weight.

Choose either a common semantic interpretation or a jointly defined base-indexed family of contextual operations and write
\[
\kappa(M)=(I(M),\operatorname{ev}_M).
\tag{4.1}
\]
Across-base semantic equality means equality of the whole chosen family, not equality at a single selected base.

### Theorem 4.1 Semantic module relabeling is a Hopf map

Replace every module decoration by \(\kappa(M)\), retaining the whole rooted module tree, port positions, and typed vacancies. Extend multiplicatively to independent forests. The resulting map \(q\) is a CK Hopf map onto its image.

**Proof.** Interface retention preserves exactly the admissible intermodule cuts. For every indexed cut \(c\),
\[
q(P_cT)=P_cq(T),\qquad q(R_cT)=R_cq(T).
\tag{4.2}
\]
This follows by constructor induction: a below-root cut is the independent choice of empty, proper, or whole cuts in the ordered inputs; replacing the root label does not change those choices or positions. Whole input selections reopen the same typed vacancies. The complete whole-tree algebraic endpoint is retained separately.

Summing (4.2), with the same indexed multiplicities, yields
\[
\Delta q(T)=(q\otimes q)\Delta T.
\]
Forest multiplication and the unit are preserved by definition; the counit is preserved because vertices are retained. Antipode compatibility follows from uniqueness of convolution inverse. Restricting to the image makes \(q\) onto without assuming arbitrary semantic labels are realizable. \(\square\)

Equivalently, the typed root recurrence is
\[
\Delta B_M(T_1,\ldots,T_m)
 =B_M(T_1,\ldots,T_m)\otimes1+
 \sum_{(c_1,\ldots,c_m)}
 \Bigl(\prod_iP_{c_i}T_i\Bigr)\otimes
 B_M(R_{c_1}T_1,\ldots,R_{c_m}T_m),
\tag{4.3}
\]
where each input choice is empty, proper, or whole; a vacant input has its one formal empty choice. All vacancies in the right tensor are evaluated below the positive module root. This is the typed grafting/comodule form of the CK cocycle law, retaining ordered inputs. Relabeling commutes with \(B_M\), so the induction covers it automatically.

The quotient preserves module count. It can merge modules of different internal rigid sizes, so it need not preserve original-vertex weight. A module evaluating to identity remains an identity-operation vertex. It is never changed into a vacancy or an algebra unit.

A locally sound positive module history has the same semantic image at both endpoints if corresponding modules have equal contextual operations and coherently matched structural interfaces. Equality of the total program operation alone is insufficient.

### Theorem 4.2 Exact criterion for selector descent

Let module purity be vertex-local: \(p_P(M)\in\{0,1\}\). Define
\[
\pi_P(F)=\left(\prod_{v\in V(F)}p_P(M_v)\right)F.
\tag{4.4}
\]
A compatible whole-monomial selector \(\bar\pi_P\) on the semantic image, satisfying
\[
\bar\pi_Pq=q\pi_P,
\tag{4.5}
\]
exists if and only if \(p_P\) is constant on every \(\kappa\)-fibre.

**Proof.** For necessity take \(M,N\) with the same \(\kappa\)-label. Their legitimate one-vertex open module trees have the same nonzero image \(y\). Equation (4.5) forces
\(\bar\pi_P(y)=p_P(M)y=p_P(N)y\), hence equal purity. For sufficiency set
\(\bar p_P(\kappa(M))=p_P(M)\) and extend by (4.4). This is well-defined and gives (4.5). Since each cut partitions the vertices, whole-monomial purity is a Hopf projection. \(\square\)

Consequently,
\[
\bar\rho_Pq=(q\otimes q)\rho_P,\qquad
\bar\Pi_Pq=q\Pi_P.
\tag{4.6}
\]
This follows directly from Theorem 4.1, (4.5), and antipode naturality. It does not require separate finite checks for coproduct, core, and every cut flag.

### Theorem 4.3 Minimal refinement preserving all base coactions

For a set \(\mathfrak P\) of considered base profiles, define the base spectrum
\[
\operatorname{Spec}(M)=\{P\in\mathfrak P:p_P(M)=1\}
\]
and the refined label
\[
\kappa^+(M)=(I(M),\operatorname{ev}_M,\operatorname{Spec}(M)).
\tag{4.7}
\]
This is the coarsest refinement of the semantic label quotient through which every considered selector, coaction, and relative core descends.

The universal property is restricted to position-preserving vertex-label quotients. It is not a statement about all possible Hopf ideals.

**Proof.** Its kernel equivalence is
\[
\ker\kappa^+
 =\ker\kappa\cap\bigcap_{P\in\mathfrak P}\ker p_P.
\]
This is the largest equivalence relation refining semantic label equality on which every purity test is constant. If a position-preserving quotient \(\lambda\) retains \(\kappa\) and permits all selectors to descend, Theorem 4.2 implies
\(\lambda(M)=\lambda(N)\Rightarrow\kappa^+(M)=\kappa^+(N)\).
Thus \(\kappa^+\) factors uniquely through \(\lambda\) on its image. Descent through \(\kappa^+\) follows from Theorem 4.2. \(\square\)

When purity has support form
\[
p_P(M)=1\Longleftrightarrow\operatorname{supp}(M)\subseteq P
\]
for a finite primitive support, the spectrum is represented by that support's principal upset. If all primitive subsets are tested, the support is recovered by intersecting all passing profiles. For a smaller family of admissible bases, spectra can identify distinct supports; the spectrum, not an unjustified exact support set, is the minimal record.

This is a principled reduction of presentation detail: retain the module's contextual behavior and exactly the base distinctions needed by the specified trust policies.

### Why ordinary normal-form quotienting is different

A module containing two serial operations may have total identity behavior for both \((I,I)\) and \((S,S)\). An internal cut exposes different operations \(I\) and \(S\). Erasing those internal distinctions while retaining that cut destroys (4.2).

Protection is therefore essential. If internal cuts are wanted, the decoration must retain semantic operations at every exposed hereditary boundary. The present theorem does not quotient arbitrary ordinary CK trees by their total denotation or normal form.

## 5 A complete multiplicative normalization instance

Use unit-free, single-conclusion IMLL:
\[
A::=p\mid A\otimes B\mid A\multimap B.
\]
Contexts are finite multisets with distinct formula-occurrence labels. All context unions below are disjoint unions of those occurrences. Exchange uses specified coherent transport, not loss of multiplicity.

The logical rules are atomic identity, tensor right and left, implication right and left, and explicit Gentzen Cut:
\[
\frac{\Gamma\vdash A\quad\Delta\vdash B}
     {\Gamma,\Delta\vdash A\otimes B},
\qquad
\frac{\Gamma,a:A,b:B\vdash C}
     {\Gamma,z:A\otimes B\vdash C},
\]
\[
\frac{\Gamma,a:A\vdash B}{\Gamma\vdash A\multimap B},
\qquad
\frac{\Gamma\vdash A\quad\Delta,b:B\vdash C}
     {\Gamma,\Delta,f:A\multimap B\vdash C},
\]
\[
\frac{\Gamma\vdash A\quad\Delta,a:A\vdash C}
     {\Gamma,\Delta\vdash C}.
\tag{5.1}
\]

In addition, use genuinely atomic primitive rules: every premise and conclusion sequent contains only atoms. Equip each eligible atomic producer/consumer root pair, including the selected consumer antecedent occurrence, with a checked Cut-free, logical-constructor-free quotation macro.

The quotation uses every physical premise-provider port exactly once, preserves the complete external boundary and routing, and has rigid size at most \(M\), for a fixed integer \(M\in\mathbb N_{\ge1}\). Holes may be filled by arbitrary checked proofs; those fillers need not be atomic or Cut-free internally.

Require the logical rule schemas, quotation instances, and boundary transports to be closed under the contexts needed by the reductions. A finite native registry without the required ancestor equipment gives only the supported instances, not automatically the all-proof theorem.

Permit the following oriented reductions.

- Either identity–Cut orientation.
- Principal tensor and implication reductions:
\[
\begin{aligned}
&\operatorname{Cut}_z
 (\otimes R(D_A,D_B),\otimes L_{z;a,b}(E))\\
&\hspace{1em}\longrightarrow
 \operatorname{Cut}_b(D_B,\operatorname{Cut}_a(D_A,E)),
\end{aligned}
\tag{5.2}
\]
\[
\begin{aligned}
&\operatorname{Cut}_f
 (\multimap R_a(E),\multimap L_{f;b}(D,F))\\
&\hspace{1em}\longrightarrow
 \operatorname{Cut}_b(\operatorname{Cut}_a(D,E),F).
\end{aligned}
\tag{5.3}
\]
- Commute a Cut past a nonprincipal logical, non-Cut constructor into its unique active premise. Keep every inactive premise unchanged.
- Replace an atomic-root Cut by its registered quotation.

Do not include reversible Cut-over-Cut associativity permutations. They are unnecessary for innermost-Cut progress and can introduce loops. The theorem concerns exactly this relation.

### Theorem 5.1 Strong normalization and Cut admissibility

Every reduction at every depth strictly decreases a computable natural-number potential. Every complete normal form is Cut-free. Thus every checked proof has a Cut-free proof of the same complete sequent.

**Proof of termination.** Define \(A(T)=\#\mathrm{Cut}+\#\otimes L+\#\otimes R+\#\multimap L+\#\multimap R\), explicitly excluding atomic identities and all other atomic constructors. Let \(N(T)\) count all vertices, and
\[
H(T)=\sum_{\text{Cut }c}
 (N(\text{left premise of }c)+N(\text{right premise of }c)).
\]
Set
\[
K(T)=N(T)+MA(T),\qquad
\Psi(T)=A(T)(1+K(T)^2)+H(T).
\tag{5.4}
\]

For identity, principal, or atomic quotation steps, \(A'\le A-1\) and \(N'\le N+M\), hence \(K'\le K\). Principal reductions replace three counted vertices by two; a quotation removes a Cut and introduces no counted logical/Cut vertices. One-use holes prevent duplication of filler counts.

Globally,
\(H'\le(\#\text{Cuts}')N'\le A'N'\le K'^2\le K^2\).
Consequently
\[
\Psi'\le(A-1)(1+K^2)+K^2
       =A(1+K^2)-1<\Psi.
\]

For a nonprincipal logical permutation, \(A,N,K\) are unchanged. Its distinguished Cut loses exactly one logical root plus all inactive premise sizes from its premise-size sum:
\[
H-H'=1+\sum_{\rm inactive}N(T_i)>0.
\]
All other Cut contributions are unchanged, including those in providers and those above the replaced subtree. Thus \(\Psi'<\Psi\). The argument counts complete trees and therefore holds under arbitrary checked context insertion. \(\square\)

**Proof of Cut-free progress.** If a proof has a Cut, choose one whose premise subtrees contain no Cut. An identity root permits identity reduction. A nonprincipal logical root permits the prescribed permutation. If both logical roots are principal for the Cut formula, their matching tensor or implication rules permit (5.2) or (5.3). If both roots are atomic, the complete atomic table applies. An atomic root cannot introduce a compound Cut formula. These cases exhaust the possibilities. Therefore a normal form has no Cut. Termination plus this progress argument gives Cut admissibility. \(\square\)

This theorem requires no confluence assumption. It proves strong normalization for the entire stated reduction relation, not merely termination of one strategy. It neither covers contraction/weakening reductions nor establishes BI/HCP normalization.

### Theorem 5.2 Semantic soundness of every permitted reduction

Interpret the calculus in a symmetric monoidal closed category. Interpret the sequent \(\Gamma\vdash A\) as a morphism \(\bigotimes\Gamma\to A\), with the stated occurrence routing. Interpret the atomic quotation equations soundly for every typed filling.

Then every permitted reduction preserves denotation, including arbitrary contextual insertions.

**Proof.** Cut is composition with the specified context permutation. Tensor rules are tensoring and coherent reassociation; implication right is currying and implication left uses evaluation followed by its continuation.

For (5.2), both sides first apply \(D_A,D_B\) to their contexts and then supply those two results to \(E\), with identical ordered resource routes. For (5.3), both supply \(D\)'s result to the curried body \(E\), then supply \(E\)'s result to \(F\). The two equations are tensor/currying coherence. Identity reductions use categorical identities. Nonprincipal permutations use naturality and the same context permutation. Atomic steps use the supplied quotation equations. Compositionality propagates each local equality under contexts; induction propagates it along histories. \(\square\)

Set with Cartesian product and exponentials is one such model. Linear resource usage in that model is enforced by the proof syntax; the model is not asserted to be resource-faithful.

### Across admissible base extensions

An extension retaining old atomic quotes and their semantic equations, and supplying a complete bounded table for its new eligible pairs, has its own finite constant \(M_C\) and the same theorem. No single global bound over an infinite tower is required.

Adding atomic rules without quotations for all new interactions can violate Cut-free progress. Such an extension is outside the theorem's admissible class. This is an explicit stability condition, not a conclusion of provenance purity.

## 6 Finite groups give a universal functional classification

Let \(G\) be any finite group, acting on its own underlying set by left multiplication. Use one atom \(p\) interpreted by \(G\), and nullary atomic proof constructors
\[
u_g:p\vdash p\quad(g\in G),\qquad
q_a:\vdash p\quad(a\in G).
\tag{6.1}
\]
Here \(u_1\) is the actual atomic identity proof constructor, not a second copy of it. Its term readback is the assumption itself.

Equip all eligible atomic pairs by
\[
\operatorname{Cut}(u_g,u_h)\longrightarrow u_{hg},
\qquad
\operatorname{Cut}(q_a,u_h)\longrightarrow q_{ha}.
\tag{6.2}
\]
A \(q_a\) cannot be a right consumer, since it has no antecedent occurrence. Thus these equations cover all eligible atomic-root pairs. All quotes have one rigid vertex, so \(M=1\). General identity reductions with logical providers remain available.

Interpret \(u_g(x)=gx\) and \(q_a=a\). Both equations are sound. Fixing an ambient \(G\) also permits subgroup bases to use the same ambient Set interpretation, avoiding any unjustified extension of arbitrary function spaces along changing carrier inclusions.

### Theorem 6.1 Complete normal-form classification

Every closed proof
\[
\vdash p\multimap p
\]
in this calculus, of arbitrary size and allowing arbitrary intermediate compound Cut formulas, normalizes to
\[
N_g=\multimap R(u_g)
\tag{6.3}
\]
for a unique \(g\in G\), modulo the specified bound-label and exchange transports. The term readback is \(\lambda x.gx\); for \(g=1\), it is \(\lambda x.x\).

**Proof.** Theorems 5.1 and 5.2 give a Cut-free, denotationally equal normal form. Its last rule must be implication right: an atomic rule has atomic succedent, tensor right has tensor succedent, and a logical left rule requires a compound formula in the empty antecedent. Its premise is \(p\vdash p\). No logical rule can finish that atomic boundary, so its last rule is a nullary \(u_g\). Thus (6.3) lists all possible normal forms.

Distinct \(g\)'s give distinct functions: evaluate at \(1\in G\). Semantic preservation therefore forces every reduction route to have the same \(g\). Strong normalization then implies confluence on this particular closed judgment: any two reducts reach the same \(N_g\). Global confluence for all judgments is not asserted. \(\square\)

A useful invariant strengthens the absence of hidden atomic states. Define
\[
\chi(p)=1,\quad
\chi(A\otimes B)=\chi(A)+\chi(B),\quad
\chi(A\multimap B)=\chi(B)-\chi(A).
\]
Constructor induction gives
\[
\chi(A)-\sum_{\Gamma}\chi
 =\#\{\text{\(q_a\) leaves in a proof of }\Gamma\vdash A\}.
\tag{6.4}
\]
Every logical rule and every Cut, including compound Cuts, preserves this equation. Each \(u_g\) contributes zero and each \(q_a\) contributes one. Hence no \(q_a\) occurs anywhere in any closed endomorphism proof.

The classification is an infinite-family theorem, not enumeration of finitely many small proofs.

### Corollary 6.2 Exact contract for coordinated replacements

For the linear functional context
\[
C[E,D]=\lambda x.\,D(E(x)),
\]
each provider and the argument occurs once. If their canonical labels are \(g,h\), then
\[
\mu(C[E,D])=hg.
\tag{6.5}
\]
Therefore the exact identity contract is
\[
W=\{(g,h):hg=1\}=\{(g,g^{-1}):g\in G\}.
\tag{6.6}
\]

Replacing two identity providers by \(N_g,N_{g^{-1}}\) preserves the entire output function. Neither component is individually equivalent to identity when \(g\ne1\). An unmatched pair is well typed but fails the contract. This is a full functional equality, not merely preservation of provability.

More generally the exact contract for desired composite \(k\) is \(hg=k\). No enumeration of source proofs is required once their canonical semantic labels are soundly certified.

The context-level identity contract does not imply that the two regions remain guarded throughout normalization. The final atomic composition step reads both operations. Consequently fully normalizing arbitrary providers cannot be advertised as zero-interior-read replay. One may reuse admitted semantic summaries, or retain opaque bodies until the interaction reaches them, but the admission and interaction obligations must be stated separately.

### Proposition 6.3 Conservative subgroup extensions and normal-form naturality

For \(H\le G\), use the subgroup base with \(u_h,q_a\) for \(h,a\in H\), and the same logical schemas.

The extension to \(G\) is conservative for boundary provability in the unchanged formula language. Replace each newly admitted \(u_g\) by the old identity with the same boundary, and each newly admitted state by \(q_1\); constructor induction gives an old proof of the same sequent. This is a provability retraction, not a behavior-preserving or quote-step-preserving translation.

On closed endomorphism proofs from the old base, inclusion preserves canonical normal forms:
\[
N_G(\iota D)=\iota N_H(D),
\tag{6.7}
\]
where equality means the explicitly aligned canonical readbacks. The old \(N_h\) remains Cut-free and denotes the same ambient left action. Uniqueness from Theorem 6.1 proves (6.7).

Thus theorem conservativity, semantic conservativity of old programs, and proliferation of new behaviors are distinct and compatible phenomena.

## 7 An exact coaction obstruction with the same semantic example

Consider the positive, read-both atomic quotation history
\[
\sigma_{g,h}:
 \operatorname{Cut}(u_g,u_h)\Rightarrow u_{hg}.
\]
Its declared rigid read shell consists of the Cut and both atomic proof leaves. All three source vertices lie in one causal class. Its protected history coproduct is primitive:
\[
\Delta_G\sigma=1\otimes\sigma+\sigma\otimes1.
\tag{7.1}
\]
This calculation refers to that positive quotation certificate. A different identity-erasing certificate can have different causal data.

Let \(H\le G\) be the old primitive base. The fixed Cut/logical background is old. Source history purity is exactly \(g,h\in H\); target purity is \(hg\in H\). The target endpoint map \(t\) is the positive protected-module Hopf map. Hence
\[
\boxed{
\rho_H^{\rm target}(t\sigma_{g,h})
 -(t\otimes t)\rho_H^{\rm history}(\sigma_{g,h})
 =
 \mathbf1_{\,hg\in H,\;(g,h)\notin H^2}\,
 u_{hg}\otimes1 .
}
\tag{7.2}
\]

**Proof.** Equation (7.1) gives
\(\rho_H^{\rm history}(\sigma)=1\otimes\sigma+
\mathbf1_{g,h\in H}\sigma\otimes1\).
The one-vertex target gives
\(\rho_H^{\rm target}(u_{hg})=1\otimes u_{hg}+
\mathbf1_{hg\in H}u_{hg}\otimes1\).
Subtract after applying \(t\otimes t\). A subgroup is closed under multiplication, so the difference of indicators is the nonnegative indicator in (7.2). \(\square\)

Taking \(g\notin H,h=g^{-1}\), the normalized behavior is old identity, while the source history uses new primitives. The coaction defect is exactly \(u_1\otimes1\). This is also an instance of Theorem 4.2: the two source/target module labels have the same contextual semantic operation, but different base spectra. The pure semantic quotient cannot retain that old-base selector; the spectrum-refined quotient can.

For this same certificate,
\[
\Pi_H^{\rm history}(\sigma)=\sigma,\qquad
\Pi_H^{\rm target}(u_1)=0.
\]
Thus core transport fails by \(-u_1\), with the orientation
\(\Pi_H^{\rm target}t-t\Pi_H^{\rm history}\).
The zero target core means the target is entirely old-base material. It does not erase the source's historical trust obligation.

The two ordinary CK leaf cuts are not guarded for this interaction. That is a useful explanation, rather than a contradiction: their semantic replacements may be safe jointly, but the interaction must be rechecked.

### A universal weighted identity

Introduce commuting bookkeeping variables \(x_g,y_h\), independently of forest multiplication. Summing (7.2) over all pairs gives
\[
\sum_{g,h\in G}x_gy_hD_H(\sigma_{g,h})
 =
 \sum_{k\in H}\left(\sum_{g\notin H}x_g y_{kg^{-1}}\right)
 u_k\otimes1.
\tag{7.3}
\]
For each \(k\in H\), \(hg=k\) determines \(h=kg^{-1}\); if \(g\notin H\), this \(h\) is also outside \(H\). Setting all variables to one yields
\[
\sum_{g,h}D_H(\sigma_{g,h})
 =(|G|-|H|)\sum_{k\in H}u_k\otimes1.
\tag{7.4}
\]
This is an induction-free group-convolution identity for the exact defect, not a table of fixture counts. Sequential group composition remains distinct from independent forest product.

## 8 Base-extension semantics has a precise and bounded role

Existing sequent B-eS literature makes atomic derivability and context handling explicit. It also distinguishes atomic Cut closure from Cut-free atomic bases; one must not assume arbitrary bases admit Cut elimination.

Our admissible equipped bases require quotations for atomic interactions. They therefore support a normalization map on atomic derivations as well as the multiplicative background.

### Proposition 8.1 Support invariance under atomic normalization

Fix a category of admissible equipped bases. Suppose each base has atomic Cut elimination preserving the exact atomic boundary. In a fixed B-eS definition whose atomic clauses use these atomic derivability predicates, replacing atomic derivability by Cut-free atomic derivability leaves every support judgment unchanged.

**Proof.** At every admissible base and every atomic boundary, the two predicates agree by Cut admissibility and inclusion of Cut-free proofs. Structural induction over the fixed support definition preserves this equality through its connective clauses, resource parameters, and quantification over the same future extensions. If the definition uses derived mutually recursive inference-support clauses, the same argument follows its defining well-founded recursion. \(\square\)

The category of future bases must be held fixed in this statement. Restricting from all atomic bases to normalization-admissible bases can itself change a support semantics. The proposition does not establish completeness for that restricted semantics.

Ordinary B-eS support is proof-irrelevant. A proof-relevant layer uses actual quotations or semantic realizers at typed interfaces. Theorem 3.1 gives relative soundness of their replacements once compositional evaluation and local semantic equations are supplied. It does not infer computational equality from a Boolean support judgment.

The group bases illustrate this distinction sharply. Their same-boundary endomorphism primitives add behaviors without adding old-language theorems. Plain derivability cannot distinguish \(u_g\) from \(u_1\); the canonical operation label can. The base spectrum records which extra rules were used.

## 9 What happens to derivatives cocycles and hypersequents

The typed remainder of a CK cut is a multi-hole context derivative. A cut flag is staged factorization of its substitution. Equations (2.4) and (2.7) give semantic contract propagation along those same stages; Theorem 4.1 transports their occurrence-resolved combinatorics under a position-preserving semantic label map.

The typed grafting law (4.3) is the constructor recurrence organizing the coproduct. It explains why the proof proceeds by constructor induction. It does not, by itself, prove a rewrite relation well-founded. The additional potential (5.4) supplies that operational fact.

The McBride/Faà di Bruno interpretation is retained: derivative contexts describe exact recursive positions; nested substitution is operadic composition; coproduct flags record its decompositions. Standard operadic Faà di Bruno identities may be applied after their separate local-finiteness and symmetry hypotheses are met. No Bell-polynomial identity for every arbitrary resource-routing presentation is asserted here.

The hypersequent case remains part of the same architecture:

- Avron-style external structural rules are actual checked constructors with complete occurrence routing.
- The earlier positive Communication/weakening/contraction floats provide causal modules and bidirectional cut transport under their stated route constraints.
- Theorem 4.1 applies to such modules structurally. Semantic endpoint identification additionally requires proof of their open semantic equation in a chosen hypersequent model.
- Theorems 2 and 3 apply to any such supplied interface semantics, including joint intercomponent contracts.
- Formula copying by internal contraction is not the same as copying a physical proof-provider port. The present generic history theorem still excludes provider duplication.
- Mix, external contraction, Splitting and Shuffle must retain their actual rule schemas and routing. They are not renamed forest multiplication.
- HCP and BI remain subsequent semantic/operational instances. Nothing in this note establishes their Cut elimination, deadlock freedom, or full operational adequacy.

This is not a pivot to group theory. Finite groups provide one complete functional calibration of the fixed framework, including its normalization and base-change limits.

## 10 Proof ledger and next milestone

| Result | Method | Established scope |
|---|---|---|
| Exact WP substitution | Operadic composition and inverse image | Deterministic equipped typed contexts |
| Weakest base-uniform contract | Universal property and future-base composition | Any essentially small extension category with functorial transports |
| Exact base-change law | Amalgamation plus reflected observer success | Displayed hypotheses; not arbitrary extensions |
| Sound guarded replay | Local semantic equations, constructor and history induction | One-use port-blind histories, including erasure |
| Semantic module Hopf map | One constructor/cut correspondence | Protected positive modules; module-count grading |
| Selector descent criterion | One-vertex necessity and vertex partition sufficiency | Position-preserving semantic label quotients |
| Minimal spectrum refinement | Intersection of kernel equivalences | All considered purity tests; not all arbitrary Hopf quotients |
| Strong normalization | Strict natural-number potential | The stated IMLL reduction relation with complete bounded atomic quotations |
| Cut admissibility | Innermost-Cut progress plus termination | Schema-level contextual closure |
| Semantic normalization soundness | SMCC equations and quotation soundness | The chosen interpretation |
| Canonical group normal forms | Cut-free shape and faithful regular action | All closed endomorphism proofs; arbitrary intermediate Cut formulas |
| Provability conservation and old normal forms | Boundary retraction and uniqueness | Subgroups of one fixed ambient finite group |
| Exact base-return defect | Primitive protected coproduct and subgroup closure | The specified positive read-both atomic quotation histories |
| B-eS support compatibility | Atomic predicate equality and support recursion | Fixed support definition and fixed admissible extension category |

All are PAPER PROVED under the stated hypotheses. None is PROOF-ASSISTANT MECHANIZED. They do not upgrade earlier finite native tests into universal proof evidence.

The next implementation milestone should test this whole semantic/provenance distinction, rather than add another cut-count module:

1. Supply a small finite-group atomic equipment and genuine term-assigned IMLL readback.
2. Certify canonical semantic summaries for admitted closed endomorphism providers.
3. Check a coordinated replacement against the exact joint contract, rejecting a same-typed unmatched pair.
4. Retain the source CK interaction witness and its base-return defect separately from the canonical target proof.
5. Show exactly which interface must be opened when ordinary native normalization reaches the interacting providers.
6. Compare contract/summary reuse with a competent typed zipper or DAG baseline under an explicit sharing policy.

Before that coding task, map these mathematical interfaces to the existing native certificate APIs. No additional language, broad sharing mechanism, or unrelated analysis module is required. The new quotient is a mathematical analysis object; it is not permission to introduce a competing checked proof carrier.

Publication maturity now depends on mechanizing at least one decisive universal theorem, checking the compatibility results against adjacent literature, and demonstrating a real integrated workflow. Potential novelty is concentrated in typed guarded replay combined with semantic contracts and coaction-compatible abstraction, not in the standard ingredients separately.

## 11 Primary literature and attribution boundaries

- Joachim Kock and Mark Weber, Faà di Bruno for operads and internal algebras:
  https://arxiv.org/abs/1609.03276 .
  Established objective operadic factorization and Faà di Bruno background. It does not prove the typed POTKIN contract or base-spectrum results stated here.
- Bart Jacobs, Introduction to Coalgebra:
  https://www.cs.ru.nl/B.Jacobs/CLG/JacobsCoalgebraIntro.pdf .
  Predicate/relation reindexing by inverse image is standard background.
- A Categorical Approach to Proof-theoretic Semantics:
  https://arxiv.org/abs/2302.09031 .
  Distinguishes proof-irrelevant B-eS from proof-object semantics and develops substitution-based categorical interpretations.
- A Sequent Calculus Perspective on Base-Extension Semantics:
  https://arxiv.org/abs/2505.18589 .
  Makes sequent contexts and atomic Cut closure explicit and warns against transferring logical Cut admissibility to arbitrary atomic bases.
- Pierre-Evariste Dagand and Conor McBride, A Categorical Treatment of Ornaments:
  https://arxiv.org/abs/1212.3806 .
  Position-preserving polynomial refinement is established background for the label maps used here.

The new theorem proofs in this note are the project's own derivations. They are not attributed to these references, and this list is not a completed novelty survey.

## 12 Beyond the one-wire calibration

The judgment \(p\multimap p\) is a deliberately constrained calibration. The interesting extension below stays in exactly the same calculus, rather than introducing a new language to obtain a larger example.

Fix a finite group \(G\) with \(|G|>1\), and use the atomic equipment (6.1)–(6.2). For \(n\ge1\), fix a bracketing of
\[
A_n=p^{\otimes n}.
\]
Label its input and output atomic occurrences by \(1,\ldots,n\). These labels distinguish resource occurrences even though their formulas are equal.

### Theorem 12.1 Complete classification of linear wire programs

Every checked proof of
\[
\vdash A_n\multimap A_n
\]
denotes a uniquely determined function
\[
F_{\mathbf g,\sigma}(x)_i
 =g_i x_{\sigma(i)},\qquad
(\mathbf g,\sigma)\in G^n\times S_n.
\tag{12.1}
\]
Every such pair is realized by a checked proof. The source proof may have arbitrary size and arbitrary intermediate higher-order Cut formulas.

The conclusion is a complete semantic classification, with a canonical quote for each class. It is not uniqueness of literal Cut-free syntax: different tensor-rule interleavings can remain irreducible for the relation in §5.

**Proof.** Equation (6.4) gives charge zero for the displayed boundary. Thus no state constructor \(q_a\) can occur anywhere in the source proof, including inside compound Cuts.

By Theorems 5.1–5.2, normalize to a Cut-free proof of the same denotation. Its final rule is implication right. The resulting body has boundary \(A_n\vdash A_n\). Backward inspection of the Cut-free rules leaves only tensor left, tensor right, and atomic \(u_g:p\vdash p\): the boundary contains no implication subformula, and state leaves are excluded.

Induct on this body. A tensor-left rule exposes the distinct occurrences in one input tensor. A tensor-right rule partitions its antecedent occurrences disjointly between its two premises. At an atomic leaf \(u_g\), exactly one exposed input occurrence is supplied to exactly one output occurrence. Consequently every input is used once, every output receives one input, and the resulting input/output correspondence is a permutation \(\sigma\). The leaf at output \(i\) supplies \(g_i\). Interpretation gives (12.1).

Conversely, unpack the input tensor to its labelled atomic occurrences, route occurrence \(\sigma(i)\) to output \(i\), apply \(u_{g_i}\), and reconstruct the fixed output tensor with tensor right before implication right. This is a checked realization. Fixing this construction order gives a canonical quote.

Uniqueness is semantic. Evaluation at \((1,\ldots,1)\) recovers every \(g_i\). With those coefficients fixed, varying an input occurrence through a nonidentity element detects which output reads it, since every left multiplication is bijective. Hence distinct permutations give distinct functions. The assumption \(|G|>1\) is necessary for this last step. \(\square\)

These functions are closed under composition. With the output-to-input convention in (12.1),
\[
F_{\mathbf h,\tau}\circ F_{\mathbf g,\sigma}
 =F_{\mathbf k,\sigma\circ\tau},
\qquad k_i=h_i g_{\tau(i)}.
\tag{12.2}
\]
Thus the semantic classes form the standard wreath-product action, with \(|G|^n n!\) classes. Neither that group construction nor its cardinality is claimed novel.

The exact coordinated replacement contract for the composite to be identity is
\[
\tau=\sigma^{-1},
\qquad h_i=g_{\sigma^{-1}(i)}^{-1}.
\tag{12.3}
\]
This illustrates why independent per-port equality contracts can be too restrictive: coordinated changes of operation and routing can preserve the downstream function.

### Corollary 12.2 Exact semantic dependence slice

For an output set \(O\subseteq\{1,\ldots,n\}\) and an input set \(K\), the observed function \(\operatorname{pr}_O F_{\mathbf g,\sigma}\) factors through \(\operatorname{pr}_K\) if and only if
\[
\sigma(O)\subseteq K.
\tag{12.4}
\]
Therefore \(\sigma(O)\) is the unique least set of input coordinates determining those outputs.

**Proof.** Sufficiency follows directly from (12.1). If \(\sigma(i)\notin K\) for some \(i\in O\), choose two input tuples differing only at that coordinate. Their \(K\)-projections agree, but their output \(i\) values differ because left multiplication by \(g_i\) is injective. Hence factorization is impossible. \(\square\)

This is semantic minimality, beyond presentation dependency. It does not license weakening in IMLL or deletion of a same-boundary proof region. An executable reduced program needs its own smaller typed boundary, and a CK replay certificate still needs guardedness and routing.

### Corollary 12.3 A complete finite observation basis

Put \(q=|G|>1\) and \(\ell=\lceil\log_q n\rceil\). There is a fixed collection of \(1+\ell\) ground input tuples whose output observations determine the entire denotation of every checked program in Theorem 12.1.

**Proof.** Assign input positions distinct codes in \(G^\ell\). First observe the all-identity input, obtaining \(b_i=g_i\). For each code position \(r\), use the tuple whose input \(j\) is code entry \(r\) of \(j\). If its output is \(y_i^{(r)}\), then
\[
b_i^{-1}y_i^{(r)}
 =\operatorname{code}(\sigma(i))_r.
\]
The complete code determines \(\sigma(i)\). When \(n=1\), \(\ell=0\) and the baseline alone suffices. Each tuple has a checked state quotation. \(\square\)

Agreement on this fixed basis is equivalent to equality of classified program denotations. Soundness comes from the universal theorem, not from a finite fixture search. The premise that programs are checked in this fragment is essential; there is no corresponding completeness claim for arbitrary black-box functions, nor a bound here on the cost of one evaluation.

## 13 Future bases reveal behavior without adding old-language theorems

Keep one fixed ambient group \(G\). For every subgroup \(H\le G\), let \(B_H\) have exactly the subgroup atomic operations and states, together with the same multiplicative background and quotes. Inclusions retain the ambient interpretation \(p=G\).

The semantic carrier of closed \(n\)-wire programs admitted at \(H\) is
\[
V_H=H^n\times S_n.
\]
All available normalized closed ground inputs of type \(A_n\) are exactly \(H^n\). Indeed, Cut elimination leaves a closed ground proof with tensor-right nodes and \(q_a\) leaves; its fixed bracketing gives the canonical quote of that tuple. Conversely every such tuple is quotable.

For programs \(P,Q\in V_H\), define the available-input observation relation
\[
R_H(P,Q)\iff
\forall x\in H^n,\ F_P(x)=F_Q(x),
\]
and its future-base uniformization
\[
U(R)_H(P,Q)\iff
\forall K\ge H,\ 
 R_K(\iota_{HK}P,\iota_{HK}Q).
\tag{13.1}
\]
These observations are operational: application to an available input quote normalizes to the canonical ground quote of its computed output.

### Theorem 13.1 Complete future-base observation

\[
U(R)_H(P,Q)
\iff F_P=F_Q:G^n\to G^n
\iff P=Q\text{ in }V_H.
\tag{13.2}
\]

**Proof.** Global equality implies agreement on every future test set. Conversely choose the terminal future base \(K=G\). Its ground tests distinguish all pairs by Theorem 12.1. \(\square\)

At \(H=\{1\}\), current observations identify every permutation: the only input is \((1,\ldots,1)\). For \(n\ge2\), future observations distinguish them. Identity and a two-wire swap agree on the old input \((1,1)\), while adjoining any \(s\ne1\) supplies \((1,s)\), on which their outputs are \((1,s)\) and \((s,1)\).

Both programs already existed in the old base. The extension adds distinguishing inputs, not necessarily new old-language theorems. This is compatible with the provability retraction of Proposition 6.3. In this family every nontrivial subgroup already supplies complete observations for its own admitted programs, so strict observational refinement occurs at the trivial subgroup, uniformly for all \(n\ge2\).

This is equivalence under the specified ground-input observations, not automatically all contextual equivalence. It is a proof-relevant realization of future-base quantification, not a completeness theorem for ordinary proof-irrelevant B-eS.

The theorem does not repair provenance loss: two histories can be equal on every future input while using different primitive bases. Behavior and historical eligibility are separate invariants.

## 14 Exact coaction transport and the repair obstruction

All transport maps \(f,g\) in this section are actual Hopf maps on a declared CK carrier. The coactions and defects are not themselves claimed to be Hopf maps. Ordinary normalization on unprotected trees is not assumed to be a Hopf map.

### Lemma 14.1 The counit detects every selector mismatch

Let \(f:H\to H'\) be a Hopf map, with whole-monomial selectors \(\pi,\pi'\) and coactions \(\rho,\rho'\). Then
\[
\rho'f=(f\otimes f)\rho
\iff \pi'f=f\pi.
\tag{14.1}
\]

**Proof.** If selectors commute, coproduct compatibility gives
\[
(\pi'\otimes\mathrm{id})\Delta'f
 =(\pi'f\otimes f)\Delta
 =(f\pi\otimes f)\Delta.
\]
Conversely apply \(\mathrm{id}\otimes\varepsilon'\) to coaction equality. Counit compatibility gives exactly \(\pi'f=f\pi\). \(\square\)

Thus no change to cut enumeration, read granularity, or scalar weighting repairs an unchanged whole-source/whole-target purity mismatch.

Define the defect
\[
D_f=\rho'f-(f\otimes f)\rho.
\]
For composable Hopf maps \(f,g\), direct subtraction gives
\[
D_{gf}=D_gf+(g\otimes g)D_f.
\tag{14.2}
\]
Moreover antipode naturality gives the relative-core equation
\[
\Pi'f-f\Pi=m'(S'\otimes\mathrm{id})D_f.
\tag{14.3}
\]
Indeed \(\Pi=m(S\otimes\mathrm{id})\rho\), and \(fS=S'f\). These are typed defect identities, not a claim that \(D_f\) is itself a Hochschild cocycle.

They show how a measured square composes and how its coaction obstruction induces its antipode/core obstruction. A scalar defect alone would not recover either equation.

### Proposition 14.2 Sharp policy envelopes for a semantic quotient

For a position-preserving protected-module label map \(\kappa:M\to Y\) onto its realized image, let \(p:M\to\{0,1\}\) be source purity. Define
\[
b^-(y)=\bigwedge_{\kappa(m)=y}p(m),
\qquad
b^+(y)=\bigvee_{\kappa(m)=y}p(m).
\tag{14.4}
\]
For a quotient policy \(b\):

- source trust implies quotient trust exactly when \(b^+\le b\);
- quotient trust reflects source trust exactly when \(b\le b^-\);
- exact selector descent is possible exactly when \(b^-=b^+\).

**Proof.** Each implication quantifies respectively over all pure sources in a fibre or all sources of a trusted fibre. Taking the join or meet is precisely that condition. Exactness requires both, and \(b^-\le b^+\). \(\square\)

Writing \(P=p^{-1}(1)\), the least enlargement of the source predicate constant on semantic fibres is
\[
P^\uparrow=\kappa^{-1}\kappa(P);
\]
the greatest such contraction is
\[
P^\downarrow
 =M\setminus\kappa^{-1}\kappa(M\setminus P).
\tag{14.5}
\]
The first trusts every presentation with a trusted equivalent; the second trusts only classes whose every presentation was trusted. Both restore descent by changing the source policy too. Neither is automatic authorization to trust an implementation.

These label policies need not be realizable by a primitive-base subset. For example, take one semantic fibre with supports \(\{a,b\}\) and \(\{c\}\), and no other nontrivial fibres. Within the allowed base \(\{a,b\}\), both \(\{a\}\) and \(\{b\}\) are exact, but their union is not. Thus a greatest exact primitive-base contraction need not exist.

For finite module supports, the least primitive-base enlargement saturating every specified semantic fibre does exist. Starting at \(B\), repeatedly add \(\operatorname{supp}(N)\) whenever \(\kappa(M)=\kappa(N)\) and \(\operatorname{supp}(M)\) is already included. The union of the resulting \(\omega\)-chain is closed: a finite antecedent support lies in some finite stage. The same induction proves leastness.

This last existence statement is not a general algorithm for semantic equality. Arbitrary fibres can be infinite or undecidable. The next section gives the finite, effectively certified version.

## 15 A least repair algorithm for registered proof transformations

This is the main constructive extension of the repair analysis.

### Equipment hypotheses

Fix a finite common ambient exact primitive-ID set \(\Sigma\), an initial profile \(B_0\), and mandatory background IDs \(W\). All IDs and cells use one exact equipped-calculus snapshot.

Let \(\mathcal R\) be a finite collection of certified positive, connected, port-blind rewrite cells. Each cell has the same ordered physical provider ports, used exactly once on both sides, with the checked complete boundary and routing. Write
\[
S_r,T_r\subseteq\Sigma
\]
for its source and target rigid supports. These include every rigid occurrence used by that cell; provider interiors are not part of a rigid support. Administrative transports preserve profile membership.

Use the previously established positive protected-module/cut correspondence. A guarded projection contains complete interacting rigid modules; corresponding modules retain their occurrences, hereditary interfaces and cut multiplicities. This hypothesis is what turns local purity preservation into coaction preservation.

More precisely, every guarded restriction of a step is either absent or a complete registered cell at its retained typed context, with the same provider interiors on both sides. The local contextual purity factorization must therefore hold within each projected module, not merely for the complete endpoint proof. This condition is supplied by the registered guarded-cell theorem or must be checked as part of the equipment.

Assume every cell is exposed as an admitted open context with typed vacancies, or has an equivalent wholly trusted provider instantiation. This supplies necessity. If all possible contexts hide a cell behind unrelated impure support, the following constraints remain sufficient but need not be necessary.

The theorem applies to the registered cells and histories generated by them. It covers all semantic equalities only if those equations are separately proved complete.

### Theorem 15.1 Least exact repair and impossibility certificates

Put \(D=B_0\cup W\). Define
\[
\Phi(B)=B\cup
 \bigcup_{r:S_r\subseteq B}T_r
 \cup
 \bigcup_{r:T_r\subseteq B}S_r.
\tag{15.1}
\]
Iteration from \(D\) terminates after at most \(|\Sigma\setminus D|\) strict enlargements, at the unique least \(B^*\supseteq D\) satisfying
\[
S_r\subseteq B^*\iff T_r\subseteq B^*
\quad(r\in\mathcal R).
\tag{15.2}
\]
This equality propagates through every permitted typed contextual insertion and every generated positive history. On their corresponding protected-module carriers, the endpoint selectors, relative coactions, and relative cores commute.

For any forbidden set \(F\subseteq\Sigma\), an exact enlarging repair avoiding \(F\) exists if and only if \(B^*\cap F=\varnothing\).

**Proof of the fixed point and leastness.** The operator is monotone and inflationary. A fixed point is exactly a set satisfying both directions of (15.2). Finiteness gives termination. If \(C\supseteq D\) satisfies (15.2), induction gives \(B_i\subseteq C\): every newly added support is forced by a contained antecedent in \(C\). Thus \(B^*\subseteq C\), proving leastness.

**Proof of contextual and history compatibility.** Fix a cell instance and any typed fillers. The unchanged enclosing context and the unchanged one-use fillers contribute a common purity factor \(c_B\in\{0,1\}\). The two sides have purity
\[
c_B\,\mathbf1_{S_r\subseteq B},
\qquad
c_B\,\mathbf1_{T_r\subseteq B}.
\]
Equation (15.2) makes them equal. Conversely trusted vacancies or the stated trusted instantiation set \(c_B=1\), exposing each local failure.

Induct on contextual substitution and then on the history. Every projected guarded module consists of complete cells with the same retained providers, so corresponding module purity bits agree. Extend vertexwise to forests. The protected-module Hopf correspondence and Lemma 14.1 give coaction transport. Antipode naturality, or (14.3), gives core transport. This is a universal induction over the registered generators, not bounded cut enumeration.

**Proof of the forbidden-set criterion.** If \(B^*\) meets \(F\), every exact repair contains that offending ID by leastness. Otherwise \(B^*\) is itself an avoiding repair. \(\square\)

### Constructive certificates and cost

Write the two directions as Horn implications
\[
S_r\Rightarrow T_r,\qquad T_r\Rightarrow S_r,
\]
where a set on the right abbreviates one implication per head ID. Empty antecedents fire immediately.

A worklist stores one unfulfilled-antecedent counter per directional block, atom-to-block incidence lists, and the block's output IDs. Initially mark the IDs in \(D\), then propagate them once. Mark an ID before enqueueing and never enqueue it twice. Each incidence is processed once and each block fires once.

After exact IDs have been indexed, time and memory are
\[
O(|\Sigma|+L),
\]
where \(L\) counts antecedent and output occurrences in the block representation, including block overhead. This excludes cell admission, support extraction, routing validation, and proof checking.

Record every new ID together with the fired implication and antecedents already established. An independent checker verifies that ordered derivation and scans final closure. Derivation proves every repair must contain the output; closure proves the output is a repair. Together they prove minimality. If an offending forbidden ID is derived, backward extraction gives a finite proof that all exact repairs require it.

Use one shared firing record per block, referring to its registered antecedent list; new head IDs point to that record. Do not copy the antecedent list separately for every head. This retains the stated linear representation bound.

Horn least-model propagation is established algorithmic background. The prospective project contribution is extracting these obligations from certified typed cells and proving that the resulting certificate repairs all guarded CK coactions and antipode cores generated by them.

Keeping only the forward implications \(S_r\Rightarrow T_r\) computes the least profile preserving trust from source to target. It permits an impure source to normalize to a pure target; exact reflection is stronger.

No repair certificate by itself authorizes new primitives, establishes their semantic equations, registers missing ancestor rules, or proves that the repaired profile belongs to a chosen B-eS extension category. Those remain independent admission obligations.

## 16 When exact repair is expensive, preserve historical provenance

### Proposition 16.1 Cancellation forces complete operational trust

Suppose a monoid \(M\) labels protected atomic endomorphism modules, identity is trusted, and every composition quotation is admitted over fixed trusted background quotation machinery. Let \(A\subseteq M\) be the trusted operation labels. Exact source/target purity for every composition holds precisely when
\[
1\in A,\qquad
ab\in A\iff a,b\in A.
\tag{16.1}
\]
Thus \(A\) is a submonoid closed under taking factors. Every unit belongs to \(A\). In a group, \(A=G\).

**Proof.** Composition has pure source exactly when both factors are trusted and pure target exactly when their product is trusted. This is (16.1). For a unit \(g\), the trusted identity \(gg^{-1}\) reflects trust to both factors. \(\square\)

A proper subgroup is closed under forward composition, but cannot satisfy exact reflection across every inverse cancellation. In Theorem 15.1, the registered cell \(g;g^{-1}\to1\) gives a reverse implication forcing \(g\) and \(g^{-1}\) once identity and background Cut are trusted.

This does not invalidate normalization, behavioral equality, or theorem conservativity. It explains why demanding exact provenance reflection through cancellation can require too broad a trust policy.

There are also proper exact profiles. If a monoid has a content homomorphism
\[
c:M\to(\mathcal P(\Sigma),\cup,\varnothing),
\]
then \(A_B=\{m:c(m)\subseteq B\}\) satisfies (16.1). Free-word concatenation and content-preserving commutations supply examples. This is an algebraic sufficient condition, not a proof that an arbitrary Communication or Shuffle rule has such semantics.

### Theorem 16.2 Inherited-spectrum repair

Let a positive history have its common causal-module tree and protected endpoint Hopf correspondence. Decorate each target module with:

1. its checked target context and semantic operation;
2. its current live support;
3. the source support, or base spectrum, inherited from the original source origins in its causal class.

Define historical target purity using item 3. Then its annotated endpoint Hopf map \(\widetilde t\) satisfies
\[
\rho_B^{\rm hist}\widetilde t
 =(\widetilde t\otimes\widetilde t)\rho_B^{\rm source},
\qquad
\Pi_B^{\rm hist}\widetilde t
 =\widetilde t\Pi_B^{\rm source}.
\tag{16.2}
\]
These annotations agree independently of staging when propagated along the retained origin/live maps of the history composition and compared on the common protected carrier of the composite history.

Here the source coaction is the source-purity coaction on the common protected history/module carrier. It is not asserted to be the full ordinary CK coaction of the uncompressed source proof.

**Proof.** Every corresponding target module receives exactly its source causal class's support. Hence its historical purity bit is identical. Protection preserves hereditary cuts and their occurrence multiplicities, so relabeling is a Hopf map. Apply Lemma 14.1 and antipode naturality.

Composition merges origin classes by the recorded causal-interface pushout. Its canonical associativity is the existing marked-origin composition theorem: both parenthesizations impose the same generating interface identifications, hence produce the same least equivalence relation on the participating origins, up to the unique origin-preserving isomorphism. A merged source support is the union of its original constituent supports. Union is associative; equivalently the spectrum of a merged class is the intersection of its constituent spectra. Therefore staged and direct histories assign the same inherited label on the composite carrier. One must propagate the inherited labels, not reset them to the intermediate proof's live support. \(\square\)

Causal composition can merge modules. Such merging is not a position-preserving relabeling and is not automatically a Hopf map between the stage-specific module trees. The staging claim above is annotation agreement after passage to the compatible composite protected carrier; it does not assert arbitrary stage-carrier contractions are Hopf maps.

Current support, original-source support, and the set of every primitive ever introduced during a history are distinct records. Equation (16.2) uses original-source support. A separate audit can retain all introduced primitives; it is not silently identified with this source-purity coaction.

For \(g\notin H\), cancellation to the identity is currently old-base pure but historically impure. Retaining that inherited spectrum repairs exact historical transport without declaring \(g\) trusted and without changing the resulting program's behavior.

The result is restricted to positive live modules. An erased class needs the generic marked-cospan treatment and does not automatically supply a target module vertex. Historical annotations are derived analysis metadata, not a second checked proof carrier.

## 17 Updated proof status and implementation direction

| Additional result | Proof method | Scope |
|---|---|---|
| \(n\)-wire functional classification | Charge invariant, Cut-free shape induction, faithful action | All checked closed programs at the displayed type; semantic classes |
| Least semantic input slice | Coordinate factorization and distinguishing inputs | The classified fragment; no implicit weakening |
| Complete observation basis | Coding positions and recovering coefficients | Promised checked fragment, arbitrary \(n\) |
| Future-base observation theorem | Normalized ground quotations and terminal future base | Subgroups of one fixed ambient group; specified observations |
| Coaction/selector equivalence | Counit and Hopf-map equations | Actual declared Hopf carriers |
| Composed defect and core law | Direct subtraction and antipode naturality | Composable Hopf maps |
| Sharp semantic repair envelopes | Fibre joins/meets and saturation | Position-preserving module-label quotients |
| Least registered-cell primitive repair | Monotone fixed point and constructor/history induction | Finite registered positive cells and exposed trusted interfaces |
| Repair or impossibility certificate | Horn derivation plus independent closure check | Finite exact ID set; registration cost excluded |
| Inherited-spectrum repair | Origin propagation and protected hereditary cuts | Positive common-module histories |

These results were independently criticized by two agents. They are PAPER PROVED under the displayed hypotheses; no new repository tests, benchmarks, or proof-assistant mechanization were run.

The most valuable next implementation is a single integrated repair/explanation operation over the existing replay equipment: extract registered cell supports, return either the least exact profile and its derivation or a forbidden-ID impossibility proof, and expose the historical-spectrum alternative when trust expansion is unacceptable. It should feed the existing selector/coaction/core APIs and retained native cut witnesses. It should not add a competing proof carrier or another unrelated finite counting module.

The functional classification is an operational calibration and a source of exact contracts and semantic slicing. It does not replace the hypersequent programme. The repair theorem is applicable to certified Avron modules when its positive one-use/routing hypotheses are verified; copying, erasure, and unregistered semantic equations remain explicit boundaries.

For attribution of the standard propagation algorithm:
William F. Dowling and Jean H. Gallier, Linear-Time Algorithms for Testing the Satisfiability of Propositional Horn Formulae, Journal of Logic Programming 1(3), 267–284, 1984:
https://www.seas.upenn.edu/~cis5110/Dowling-Gallier-Horn-sat.pdf .

## 18 A completed semantic replacement milestone

The subsequent proof record
CK_SYMBOLIC_REPLACEMENT_AND_GUARDED_REPLAY_2026-10-04.md
discharges a stronger operational obligation than Horn repair or the
one-wire calibration alone.

For every checked context
\[
K:(\vdash A_{n_1}\multimap A_{n_1},\ldots,
   \vdash A_{n_m}\multimap A_{n_m})
 \to\vdash A_N\multimap A_N,
\]
in the nullary group-IMLL equipment, fresh-assumption threading and uniform
open normalization produce an acyclic first-order wiring circuit. The
construction reads no eventual provider body and handles arbitrary
higher-order Cut detours in the original remainder.

The open-scaffold budget is at most \(4V^3+V^2+V\) normalization steps, with
\(V=|K|_{\rm rigid}+\sum_i(6n_i-2)\), independently of all provider proof sizes.
Shared route/coefficient arrays then compute its contextual operation.

For supplied summaries and observed outputs \(O\), equality of each
observed route and coefficient is an exact joint future-uniform contract.
Failure returns an explicit checked future-base input separating an
observed output. Success is stronger than same typing or structural
dependency: it accepts correlated changes preserving the requested
function.

Nested context substitution and subgroup-base change commute semantically.
Together with an independently certified guarded frontier and open
remainder replay/read contract, this yields actual downstream soundness of
replay around newly admitted providers. Historical spectra retain the
separate original-source provenance obligation.

Old detached-region histories are not automatically replayable on arbitrary
new providers merely because the frontier is guarded. Changed providers
are admitted/normalized independently; reuse of their old internal histories
requires its own certificate.

This is a completed scoped PAPER theorem package, critically reviewed by
three agents. It is not a new native implementation or proof-assistant
formalization. Novelty remains concentrated in the integration; symbolic
compilation, translation validation and Hopf-image theory have established
precedents. The previous repair and spectrum results remain part of the
framework rather than being replaced.
