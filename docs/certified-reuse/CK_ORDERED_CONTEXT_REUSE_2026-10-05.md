# Ordered contextual reuse: exact forward and conversion protection

Date: 5 October 2026. Status: universal paper proof for the existing two-cell positive tensor registry, independently audited, with exact persistence in the specified mixed registry. This is a new exact contextual extension of the all-arity bundle theorem, together with a typed obstruction to initial-redex-only static discovery. It does not claim a polynomial procedure for arbitrary sources.

## 1 Registry and target

Use precisely the registered principal tensor cell and independent Cut/tensor-left cell, including their checked inverses:

\[
\operatorname{Cut}_{A\otimes B}(\otimes R(P,Q),\otimes L_{A,B}(R))
\leftrightarrow
\operatorname{Cut}_A(P,\operatorname{Cut}_B(Q,R)),
\tag{1}
\]

\[
\operatorname{Cut}_D(P,\otimes L_{A,B}(R))
\leftrightarrow
\otimes L_{A,B}(\operatorname{Cut}_D(P,R)),
\tag{2}
\]

where (2) requires the selected D occurrence to be disjoint from the selected tensor-left occurrence. Both cells preserve the left-to-right physical provider frontier. Each whole rigid read shell is collapsed to one causal origin class; unchanged vertices and ports are retained once. There is no Cut/Cut interchange or identity erasure.

The inverse of (1) on nested Cuts is admitted only when both selected cut occurrences are inputs of the same innermost consumer. In particular

\[
\operatorname{Cut}_D(S,\operatorname{Cut}_A(P,W))
\tag{3}
\]

is an inverse-principal redex only if its selected D input originates in W, rather than in the producer P. This is an exact occurrence-routing condition, not a test of formula-name inequality alone.

The general question is whether exact all-zigzag protection can be computed by a polynomial source-local residual closure. The results below refute a particularly natural proposed closure and give an exact unbounded family in which the missing propagation has practical effect. A completeness theorem for arbitrary sources remains an explicit obligation.

## 2 Fully typed source family

Fix m >= 1 and pairwise distinct atomic formulas

\[
a_1,\ldots,a_m,d,c.
\]

Let F be any binary tensor formula with ordered leaves a_1,...,a_m, and let j be any index between 1 and m. Choose distinct nullary primitive material proof vertices with these exact interfaces:

\[
S:\ \Rightarrow d,\qquad
P_j:d\Rightarrow a_j,\qquad
P_i:\ \Rightarrow a_i\ (i\ne j),\qquad
R:a_1,\ldots,a_m\Rightarrow c.
\tag{4}
\]

Every displayed antecedent occurrence retains its physical index. Primitive material vertices have no proof-premise ports and are never read by (1) or (2).

Form the usual tensor-right producer R_F(P_1,...,P_m) and any complete legal tensor-left packing chain L_F(R). Define the inner bundle and the entire source by

\[
B_j=\operatorname{Cut}_F(R_F(P_1,\ldots,P_m),L_F(R)):d\Rightarrow c,
\qquad
T_j=\operatorname{Cut}_d(S,B_j):\ \Rightarrow c.
\tag{5}
\]

The selected d of the outer Cut is the unique residual input occurrence originally belonging to P_j. Its location in the source is therefore completely specified. The inner bundle has 2m-1 logical/Cut scaffold vertices. The complete source has 2m such vertices and m+2 material vertices. The physical inner material frontier is P_1,...,P_m,R; the full frontier is S,P_1,...,P_m,R.

For m=1, F=a_1 and the inner bundle is simply Cut_{a_1}(P_1,R); there are no tensor constructors or alternative j values.

## 3 Exact theorem

Write E(T) for the intrinsic source-origin join over every finite zigzag of (1)-(2). Let C be the outer d-Cut vertex, let L be the set of the inner bundle's 2m-1 scaffold vertices, and let M be the m+2 distinct material vertices.

**Theorem 3.1 (ordered contextual protection).** For every F, every legal complete packing order and every m >= 1,

\[
E(T_j)=
\begin{cases}
\{L,\{C\}\}\cup\{\{v\}:v\in M\}, & j=1,\\[2mm]
\{L\cup\{C\}\}\cup\{\{v\}:v\in M\}, & j>1.
\end{cases}
\tag{6}
\]

For j>1, a history witnessing the combined logical block has at most 2m(m-1)+1 local cells. For j=1, the proof is a universal exclusion of any first outer read and requires no exploration of a finite sample of histories.

### 3.1 The j>1 case

Apply the previously proved bundled residualization inside the unchanged outer context. It takes B_j to

\[
N_j=\operatorname{Cut}_{a_1}(P_1,
\operatorname{Cut}_{a_2}(P_2,\ldots,
\operatorname{Cut}_{a_m}(P_m,R)\ldots)).
\tag{7}
\]

The marked history merges precisely all original inner scaffold vertices into one class. It uses at most 2m(m-1) cells. Every final atomic Cut inherits that class.

Let W be the consumer of the first atomic Cut in (7), so N_j=Cut_{a_1}(P_1,W). Because j>1, P_1 has empty antecedent, while W has exactly the distinct inputs d,a_1 and output c. The d occurrence is carried by P_j inside W; it is not an input of P_1. Thus the whole outer source at this endpoint is the admitted inverse-principal cell

\[
\operatorname{Cut}_d(S,\operatorname{Cut}_{a_1}(P_1,W))
\longrightarrow
\operatorname{Cut}_{d\otimes a_1}
(\otimes R(S,P_1),\otimes L_{d,a_1}(W)).
\tag{8}
\]

The selected d,a_1 are distinct physical inputs of W. Its provider ports S,P_1,W have the same left-to-right order before and after (8). The whole two-Cut source shell merges C with the first atomic Cut, whose origin class already contains every original vertex in L. Consequently one actual source-history partition contains L union {C} as a block.

No material vertex can ever enter a rigid shell, and every one is retained literally once. Hence this lower bound is exact. Equation (8) is a single additional cell, proving the claimed history-length bound.

### 3.2 An invariant for the j=1 case

Suppose a history has not yet read the outer vertex C. Because C is the root, every preceding nonidentity step is then strictly inside B_1; S and C stay unchanged. Such a history preserves the following facts about its current inner endpoint U.

1. U has the exact complete boundary d=>c, with one atomic input d and atomic output c.
2. Its material leaves, in physical left-to-right order, are exactly P_1,...,P_m,R.
3. The multiset of atomic tokens appearing in all its cut formulas contains only a_1,...,a_m. It contains no d or c.
4. The unique boundary d occurrence comes from P_1 and is never consumed or grouped with another occurrence.

Items 1-2 are the exact boundary and physical-port invariants of the registry. For item 3, the initial only inner cut formula is F. A principal forward step partitions its atomic token multiset into the factors A,B; an inverse step combines those same two multisets; the commutation leaves its cut formula unchanged. Thus no inner cut formula can contain d. The source tensor-left nodes also have only a_i formulas, and any tensor-left created by an inverse principal step packs factors of its newly formed cut formula; none can contain d. Tensor-right and occurrence exchanges only transport antecedent inputs, while all Cuts and tensor-left nodes act on formulas not containing d. This proves item 4 by induction over the actual routed history. There is only one original d occurrence inside B_1, namely P_1's input, and no rule creates another.

**Lemma 3.2 (root producer carries d).** Every such U has a Cut root, and its producer premise contains the unique selected d input.

**Proof.** A tensor-right root would have tensor succedent, contradicting the atomic succedent c. A tensor-left root would have a tensor antecedent occurrence, contradicting the sole atomic antecedent d. A nullary material root would have just one material leaf, contradicting the preserved m+1 material frontier (m+1 >= 2). The available constructors are material, tensor-right, tensor-left and Cut, so the root must be Cut.

Every subtree of this closed endpoint has a material leaf: the source has no vacancies, both rule sides use their closed providers exactly once, and the registry creates no empty proof-provider branch. The producer is the first physical child of the Cut root, so its material frontier is a nonempty prefix of U's frontier and contains P_1. By item 4, P_1's d input has not been consumed or grouped anywhere on its route. It therefore belongs to the producer's antecedent. The other premise contains no d. QED.

### 3.3 There can be no first outer read

Assume for contradiction that a finite history has a first cell whose rigid shell reads C. Its preceding endpoint is Cut_d(S,U) for a U satisfying Lemma 3.2. Because C is the whole-tree root, list every possible registered shell containing it:

- A forward principal shell would require S to have tensor-right root. S is an unchanged primitive material vertex, so this fails.
- A forward independent commutation would require U to have tensor-left root. Lemma 3.2 excludes that.
- An inverse-principal shell would require the selected d of C to be an input of the root Cut's consumer. Lemma 3.2 places it in that Cut's producer, so the occurrence-routing condition fails.
- An inverse independent commutation has tensor-left at its whole-shell root. The root C is a Cut, and there is no ancestor above it; this cannot be an instance containing C.

These exhaust both directions of both cells. Thus no first outer read exists. C remains a singleton source-origin class under every history.

The existing inner bundle history, lifted into the outer context, merges every vertex of L. Material vertices remain singleton as before. No further source vertices exist. This proves the j=1 clause of (6), including m=1. The proof also handles arbitrarily long cyclic inverse/forward histories, because it excludes their first possible outer read rather than assuming a normalization strategy.

## 4 Exact reuse frontier

Let e be the native edge from C to the root of B_j. Cutting e detaches the entire inner bundle and leaves the outer d-Cut with S and a typed hole of complete interface d=>c.

**Corollary 4.1 (conversion safety).** This frontier is guarded against every admitted bidirectional conversion history if and only if j=1.

**Proof.** For j=1, the two compartments are unions of the exact blocks in (6): all of L and its material leaves are detached, while C,S stay in the remainder. For j>1, the block L union {C} crosses e. The E-saturation criterion therefore gives the equivalence. Equation (8), after the bundled normalization, is an explicit offending history for the latter case. QED.

For j=1, the hereditary protection theorem therefore retains the corresponding term in the conversion-invariant restricted CK coproduct: detached q(B_1) tensor the positive outer Cut module with S and the reopened d=>c provider slot. For j>1 the same native edge is suppressed. In semantic compression the former source has an outer Cut module above the inner bundle module, while the latter has one combined scaffold module with m+2 material children. This is a difference in exact decomposition, not merely in reduction length.

### 4.1 Forward strategy safety and conversion safety differ exactly

Let E^*(T) be the source-origin join over histories using only the displayed forward directions of (1) and (2), namely principal tensor residualization and hoisting a tensor-left constructor outside an independent consumer Cut.

**Corollary 4.2 (universal forward reuse).** For every j,

\[
E^*(T_j)=\{L,\{C\}\}\cup\{\{v\}:v\in M\}.
\tag{10}
\]

Consequently the bundle edge e is universally guarded against every forward history for all j, whereas it is guarded against every conversion history precisely when j=1.

**Proof.** Before any hypothetical first forward cell reading C, the inner endpoint retains boundary d=>c and the outer producer S remains primitive. A forward principal cell containing the root C would require its producer S to be tensor-right (and its cut formula d to be a tensor); neither is possible. A forward commutation would require its consumer root to be tensor-left; this is impossible because its complete conclusion d=>c has no tensor antecedent occurrence. Those are the only forward cells, and C has no ancestor in whose shell it could otherwise occur. Thus no first forward outer read exists, independently of the location j of the d input.

The constructive bundled normalization uses only forward cells and merges all of L. It gives the lower bound in (10). C remains singleton and material vertices are never read, giving the matching upper bound. The E-saturation criterion for e proves the two safety claims using (10) and Theorem 3.1. QED.

For j>1, the extra outer merge in (8) is explicitly an inverse-principal cell. Its existence proves **conversion-unsafety**, not failure of a forward normalizer's opaque reuse. A policy preserving all declared proof conversions therefore suppresses a boundary that a policy certifying only forward tensor normalization may retain. The positive material-rich forward decomposition is larger here than the positive conversion-invariant decomposition; neither policy is silently substituted for the other.

### 4.2 Persistence under the precisely oriented mixed registry

The mixed extension in `CK_MIXED_PRINCIPAL_PROTECTION_2026-10-05.md` adds the audited positive-outer/negative-inner implication principal cell and the negative-Cut/implication-right commuting cell. A negative Cut has consumer-first physical proof-port order. The extension includes no Cut orientation swap and no unrestricted inverse arrow cell on an arbitrary pair of positive Cuts.

Its conserved nonnegative constructor charge is

\[
A_{\mathrm{arr}}(U)=2\#\operatorname{Cut}^{-}(U)
 +\#\multimap R(U)+\#\multimap L(U).
\tag{11}
\]

The implication principal shell has charge 2 at either endpoint: two arrow constructors before the step and one negative Cut after it. Its commuting shell retains a negative Cut and one implication-right constructor. The tensor shells leave the charge unchanged. Every T_j has charge zero, so every endpoint reachable in the mixed registry has no negative Cut and no arrow constructor. Neither implication cell can consequently match in either direction. Its mixed histories are exactly its tensor histories, including their marked origin updates.

Thus Theorem 3.1, Corollaries 4.1-4.2 and the complete protected coproduct of this family persist under that particular mixed extension. The same argument applies to its forward-only subregistry. This is conversion/decomposition conservativity on these old sources, not conservativity of arbitrary derivability and not permission to add an orientation-changing or unrestricted arrow conversion.

**Interpretive limit.** Guardedness here means an operational absence of cross-boundary reads for this exact filled source and this fixed registry. The producer P_1 still semantically depends on d. Supplying a different same-interface compound provider can expose new cross-boundary cells; the theorem does not certify the intrinsic partition after arbitrary future filling. It does not claim that provider denotations are independent, that replacement preserves behavior, or that ordinary Cut substitution is irrelevant. Those are separate semantic contracts.

## 5 Typed obstruction to initial-redex static closure

Define the initial-redex relation R_0(T) to be the equivalence relation generated by all complete rigid shells that are admitted redexes in the initial checked source, in either registered direction. Material vertices begin singleton. Merely taking connected components of this initial read graph is a natural linear-size candidate for static protection.

Take m=2 with F=a_1 tensor a_2. In both j=1 and j=2 sources, the only initial admitted redex is the inner principal shell:

\[
\operatorname{Cut}_{a_1\otimes a_2}
(\otimes R(P_1,P_2),\otimes L_{a_1,a_2}(R)).
\]

The outer Cut is not initially inverse-principal: in either source its d occurrence belongs to the inner tensor-right producer, not to its tensor-left consumer. It is not a forward principal redex because S is material. Every possible independent Cut/tensor-left pair is either absent or targets the packed a_1 tensor a_2 occurrence itself, violating disjointness. No material root is inspected by a cell.

Thus both initial read graphs consist of the same three-vertex inner scaffold component and an isolated outer Cut, together with material singletons. Both also have the same outer boundary, unlabelled plane constructor tree, constructor counts and conserved numerical invariants W=2c+t=6 and K=sum(|cut formula|+1)=6.

For j=2, however, the explicit two-step history is

\[
\begin{aligned}
&\operatorname{Cut}_d(S,
 \operatorname{Cut}_{a_1\otimes a_2}(\otimes R(P_1,P_2),\otimes L(R)))\\
&\quad\longrightarrow
 \operatorname{Cut}_d(S,
 \operatorname{Cut}_{a_1}(P_1,\operatorname{Cut}_{a_2}(P_2,R)))\\
&\quad\longrightarrow
 \operatorname{Cut}_{d\otimes a_1}
 (\otimes R(S,P_1),\otimes L_{d,a_1}(\operatorname{Cut}_{a_2}(P_2,R))).
\end{aligned}
\tag{9}
\]

The second move is a typed inverse-created redex that the initial graph misses. It merges the outer Cut with the inner scaffold origin block. For j=1 that redex is prohibited by the opposite occurrence routing, and Section 3 proves universal separation.

Consequently R_0(T_2) is strictly smaller than E(T_2), whereas R_0(T_1)=E(T_1). An algorithm using only the initial shell graph, constructor shape and W,K cannot distinguish these sources. The full checked occurrence routes can distinguish them, and must be used by any exact static closure. This is an analytic counterexample, not an inference from testing finitely many cases.

## 6 Precise remaining obligation for polynomial general discovery

The counterexample identifies a necessary residual propagation rule: splitting a tensor cut into ordered factor Cuts can move an outer selected occurrence from the aggregate producer region into the consumer of an earlier factor Cut. If that outer dependency lies in a later factor's provider, an inverse-principal read with the earlier factor becomes possible and merges causal blocks across the old boundary.

For the explicit primitive family, Section 3 proves both sides exactly. For arbitrary sources, a candidate source-local system must additionally account for:

1. checked occurrence ancestry through every tensor factor split or regrouping;
2. Cut/tensor-left residual exposure without treating a producer occurrence as a consumer occurrence;
3. future inverse-created tensor shells and their ability to meet retained source vertices;
4. whether abstractly composable residual exposures are jointly realizable by one actual history, rather than taking an unsound union of incompatible endpoint configurations.

The missing lemma is an **exact reachable-read characterization**: each proposed static merge must have a realizable registered history, and every rigid read appearing in every reachable marked endpoint must be contained in a static block. Soundness and completeness must both be proved before claiming equality with E. If a finite annotation domain of polynomial size can satisfy these two clauses, saturation would give an efficient procedure; no such domain or theorem is established here.

The bounded search stops at an exact contextual theorem and a typed obstruction. The existing complete marked-orbit procedure remains the general decision method. The result advances reuse applicability without replacing that procedure by an unsupported efficiency assertion.
