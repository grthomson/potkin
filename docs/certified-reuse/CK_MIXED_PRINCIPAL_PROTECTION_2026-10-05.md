# Complete mixed principal protection and exact conservative comparison

Date: 5 October 2026. Status: universal paper proof, extending the complete tensor discovery theorem of 4 October. The full mathematical audit passed the source bounds, discharge routing, marked completeness and conservative comparison. No finite test run or implemented checker is invoked.

## 1. The precisely admitted extension

Formulas are generated from atomic labels by the two binary connectives \(\otimes\) and \(\multimap\). There are no units. Checked open proofs are finite planar trees with a fixed finite stock of nullary material occurrences and typed vacancies. Vacancies have complete judgment interfaces but no rigid vertex. Contexts are indexed multisets with a recorded representative order; every rule stores its actual occurrence routing and every necessary context exchange. An external occurrence identity is never replaced by equality of its displayed formula.

There are two genuinely different ordered Cut constructors. Their premise ports are:

\[
\begin{aligned}
\operatorname{Cut}^{+}_F(P,Q)&:
  (P:\Gamma\Rightarrow F,\quad Q:\Delta,F\Rightarrow C)
   \longmapsto \Gamma,\Delta\Rightarrow C,\\
\operatorname{Cut}^{-}_F(Q,P)&:
  (Q:\Delta,F\Rightarrow C,\quad P:\Gamma\Rightarrow F)
   \longmapsto \Delta,\Gamma\Rightarrow C.
\end{aligned}
\tag{1}
\]

The displayed antecedent blocks are placed in the specified boundary order by their stored occurrence exchange. The distinction between the two constructors is physical: the first port of \(\operatorname{Cut}^{+}\) is a producer, whereas the first port of \(\operatorname{Cut}^{-}\) is a consumer. There is **no equation interchanging their premise ports or identifying the orientations**.

The exact registry contains the following four equations and their checked inverses, with their schema-closed outer contexts and opaque same-interface fillings:

\[
\operatorname{Cut}^{+}_{A\otimes B}
 (\otimes R(P,Q),\otimes L_{A,B}(R))
\ \leftrightarrow\
\operatorname{Cut}^{+}_A(P,\operatorname{Cut}^{+}_B(Q,R));
\tag{2}
\]

\[
\operatorname{Cut}^{+}_D(P,\otimes L_{A,B}(R))
\ \leftrightarrow\
\otimes L_{A,B}(\operatorname{Cut}^{+}_D(P,R));
\tag{3}
\]

\[
\operatorname{Cut}^{+}_{A\multimap B}
 (\multimap R_A(E),\multimap L_A(D,F))
\ \leftrightarrow\
\operatorname{Cut}^{+}_B(\operatorname{Cut}^{-}_A(E,D),F);
\tag{4}
\]

\[
\operatorname{Cut}^{-}_D(\multimap R_A(E),P)
\ \leftrightarrow\
\multimap R_A(\operatorname{Cut}^{-}_D(E,P)).
\tag{5}
\]

Equation (2) has providers \(P:\Gamma\Rightarrow A\), \(Q:\Delta\Rightarrow B\), and \(R:\Theta,A,B\Rightarrow C\). Equation (3) has \(P:\Gamma\Rightarrow D\) and \(R:\Theta,D,A,B\Rightarrow C\); its selected cut occurrence \(D\) lies outside the selected tensor-left occurrence.

Equation (4) has providers

\[
 E:\Gamma,A\Rightarrow B,\qquad
 D:\Delta\Rightarrow A,\qquad
 F:\Theta,B\Rightarrow C.
\tag{6}
\]

Both sides have conclusion \(\Gamma,\Delta,\Theta\Rightarrow C\). The selected consumer \(A\) in \(E\) is exactly the occurrence discharged by the displayed implication-right rule; the selected \(B\) in \(F\) is the displayed implication-left continuation occurrence.

Equation (5) has \(E:\Gamma,D,A\Rightarrow B\) and \(P:\Delta\Rightarrow D\). Its selected \(D\) occurrence and discharged \(A\) occurrence in \(E\) must be distinct physical occurrences, even when their formulas coincide. After the inner negative Cut, the recorded exchange places the surviving \(A\) in the premise position discharged by \(\multimap R_A\). Both whole outputs are \(\Gamma,\Delta\Rightarrow A\multimap B\).

All four equations preserve the ordered provider frontier literally: respectively \((P,Q,R)\), \((P,R)\), \((E,D,F)\), and \((E,P)\). They use each provider exactly once. Their rigid shells are connected and nonempty on both sides. Each shell is read as one causal block: three versus two rigid vertices in each principal equation; two versus two in each commuting equation. Thus every local cell has the positive surjective origin cospan required by the intrinsic protection construction.

No negative-outer principal equation, further implication permutation, Cut/Cut interchange, identity erasure, orientation swap, copying rule, Communication, or unrestricted structural rule belongs to this theorem. In particular, completeness below is completeness for (2)–(5), not for an unspecified full implication calculus.

## 2. The conserved quantities

Let \(c_+(U),c_-(U)\) count the two Cut constructors, and let \(\ell(U)\) count all four logical constructors \(\otimes R,\otimes L,\multimap R,\multimap L\). Define

\[
 W(U)=2(c_+(U)+c_-(U))+\ell(U).
\tag{7}
\]

Every principal equation has rigid weight \(2+1+1=4\) on its left and \(2+2=4\) on its right. Both commuting equations preserve their one Cut and one logical constructor. Therefore \(W\) is conserved in both directions, along arbitrary finite zigzags.

A second constructor invariant isolates the old tensor fragment. Set

\[
 A_{\mathrm{arr}}(U)=2c_-(U)+r_{\multimap}(U)+l_{\multimap}(U),
\tag{7a}
\]

where the last two counts refer to implication-right and implication-left. Equation (4) has \(A_{\mathrm{arr}}=2\) on each rigid shell: two implication constructors on the left, one negative Cut on the right. Equation (5) retains its negative Cut and implication-right constructor. Equations (2)–(3) change none of these counts. Thus \(A_{\mathrm{arr}}\) is conserved. Its nonnegativity will give exact conversion/decomposition conservativity in section 7a.

Let \(|F|\) count formula syntax-tree nodes, including atoms. Since both connectives are binary,

\[
 |A\otimes B|=|A\multimap B|=|A|+|B|+1.
\]

Define the cut-formula mass, summing over both orientations, by

\[
 K(U)=\sum_{\operatorname{Cut}^{\pm}_F\text{ in }U}(|F|+1).
\tag{8}
\]

Each principal equation replaces \(|A\mathbin\star B|+1=|A|+|B|+2\), for \(\star\in\{\otimes,\multimap\}\), by \((|A|+1)+(|B|+1)\). The commuting equations retain their cut formula. Hence \(K\) is conserved too. Its summation must include the negative inner Cut in (4); counting positive Cuts alone would be incorrect.

If the source has \(m\) material vertices, then every endpoint has at most

\[
 N=m+W(T)
\tag{9}
\]

rigid vertices. No provider is copied or discarded, so the same material occurrences and vacancies remain present. Every cut formula has size at most \(K(T)-1\) whenever Cuts exist.

No rule creates a new atomic label. Inverse principal equations assemble a binary formula from the two existing cut formulas. Inverse commuting equations move an already recorded logical formula and its selected occurrences. Thus all endpoint formulas use the finite atomic alphabet of the source interfaces and labels.

## 3. A bound on every judgment, including discharge interfaces

The vertex bound does not by itself bound checked syntax. We also need source bounds on formulas, contexts and routes.

Write \(a(F)\) for the atomic leaf count of a formula, and define the atomic mass of a judgment by

\[
 M(\Gamma\Rightarrow C)=\sum_{F\in\Gamma}a(F)+a(C),
\tag{10}
\]

counting physical occurrences. Directly from the checked rule shapes:

| Constructor | Output mass in terms of its premise masses |
|---|---|
| \(\otimes R\) | Sum of the two premise masses |
| \(\otimes L\) | The single premise mass |
| \(\multimap R\) | The single premise mass |
| \(\multimap L\) | Sum of the two premise masses |
| \(\operatorname{Cut}^{+}_F,\operatorname{Cut}^{-}_F\) | Sum of the two premise masses minus \(2a(F)\) |

For implication-right, the premise \(\Gamma,A\Rightarrow B\) and output \(\Gamma\Rightarrow A\multimap B\) both have mass \(\sum_\Gamma a+a(A)+a(B)\). Discharge changes occurrence placement, not atomic mass. For implication-left, the premises \(\Delta\Rightarrow A\) and \(\Theta,B\Rightarrow C\) sum to the output mass of \(\Delta,\Theta,A\multimap B\Rightarrow C\). The contravariant role of \(A\) in function application changes no part of this calculation.

Let \(b\) be the sum of the atomic masses of all source material-leaf and vacancy interfaces, across the forest. Their ordered interfaces are retained exactly once by every cell. Induction from the leaves shows that the mass of every judgment in every endpoint is at most \(b\): each output has mass no greater than the sum of the masses of its premises, and the leaves under any subtree form a subset of the fixed frontier.

Consequently each judgment has at most \(b\) formula occurrences. Each displayed formula has at most \(b\) atomic leaves and hence at most \(2b-1\) syntax-tree nodes. This latter conclusion uses the unit-free binary formula grammar. There are only finitely many formulas of that size over the finite source atomic alphabet, with either connective at each internal node. Contexts, principal marks and occurrence maps therefore also have finite source bounds.

The implication-right discharge introduces no semantic fresh-variable space. It marks a particular antecedent occurrence. An inverse step may give that private occurrence a fresh administrative spelling; its formula is a domain subformula already determined by the matched arrow, and its mark and routes remain stored. Canonicalization chooses bounded local indices for internal interfaces and records all actual incidence maps, including discharge/domain correspondences. External identities, material identities, principal distinctions and ordered provider ports remain fixed. This removes arbitrary private names while retaining everything that affects typing, matching, or origin propagation.

If one treats displayed formula occurrences as indistinguishable merely because their formulas match, or forgets which \(A\) was discharged, this proof does not justify the resulting quotient. The finite construction uses exact checked incidence.

## 4. Finite marked states and exact origin updates

For \(n=|V(T)|>0\), a search state is a triple

\[
 (U,\pi,\lambda),\qquad
 \pi\in\operatorname{Part}(V(T)),\quad
 \lambda:V(U)\twoheadrightarrow V(T)/\pi.
\tag{11}
\]

Here \(U\) is a canonical checked endpoint, \(\pi\) is the source partition accumulated by the history's causal pushout, and \(\lambda\) labels every current vertex by its source-origin block. Positive local shells guarantee surjectivity. The initial triple is \((T,\mathrm{discrete},\mathrm{id})\).

For a matched cell, merge every source block labeling a vertex of its entire rigid read shell. Give all replacement-shell vertices the merged block, retain all other vertices through the exact correspondence, and relabel every vertex outside the shell whose source block was also merged. This is precisely the pushout composition of the whole-shell causal cospans. In particular, retaining an old label on an outside vertex after its block has merged would be wrong.

Sections 2–3 show that there are finitely many canonical checked endpoints. The orientation of each Cut is simply one additional two-valued constructor decoration. There are at most \(B_n\) possible source partitions and at most \(n^N\) current origin labelings for each endpoint. Therefore the complete marked state space is finite.

An endpoint-only visited set is insufficient: different histories can reach the same checked term with different source partitions or origin labels. All three parts of (11) are required. For a source with no rigid vertices, none of the positive cells matches; its empty protection is immediate.

## 5. Universal complete-discovery theorem

**Theorem.** For the exact four-cell registry (2)–(5), the intrinsic positive-congruence protection \(E^{\leftrightarrow}(T)\) is computable from a finite checked source. Its computation is complete for all finite registered zigzags, including inverse conversions and cyclic histories.

**Construction.** Starting at the initial marked state, process a worklist of canonical triples. At each triple enumerate every exactly routed occurrence of each of (2)–(5), in either direction. Type-check the match and its occurrence side conditions, compute its exact marked update, canonicalize only coherent private names, and add each previously unseen resulting triple. On closure, return the join of all stored source partitions.

**Termination.** The source-dependent bounds of sections 2–4 make the marked state space finite. A triple is processed only once.

**Soundness.** By induction on a retained predecessor path, every stored triple represents an actual registered history from \(T\). The induction step is a checked local cell in a checked context, followed by the exact causal pushout update. Thus every stored partition is an actual source-origin partition.

**Completeness.** Consider any finite history. Its empty prefix has the initial triple. If a prefix has been generated, its next exactly routed local cell is among that triple's enumerated transitions. Coherent private canonicalization preserves that transition because the principal indices, discharge correspondence, outside occurrence identities and physical ports are retained. Hence every prefix and the full history have generated marked triples. Taking the join of the stored partitions therefore gives exactly the universal join defining \(E^{\leftrightarrow}(T)\). QED.

Neither confluence nor termination of every rewriting strategy is needed. Inverse equations can cycle; finite marked-state closure handles the cycles. No claim of full Cut elimination follows, and no omitted orientation or commuting equation is smuggled in by the word “complete.”

## 6. Safety, offending histories and independently checkable certificates

Let \(c\) be an already checked native frontier and let \(C_c\) be the equivalence relation whose classes are its source compartments. The exact two-outcome contract is:

\[
 c\text{ is universally guarded}
 \quad\Longleftrightarrow\quad
 E^{\leftrightarrow}(T)\subseteq C_c.
\tag{12}
\]

If the inclusion fails, some stored partition \(\pi\) also fails \(\pi\subseteq C_c\): otherwise the equivalence relation \(C_c\) would contain the join of all stored partitions. A predecessor path to that state is an actual local-cell history whose source causal block crosses the frontier. Thus an unsafe answer has a finite explicit offending history. Its length is not promised to be polynomial for an arbitrary mixed source.

A safe answer can be certified by a finite closed marked-state graph. Its independent checks are: the initial triple is included; every listed edge is an admitted cell with the exact origin update; every listed state has a checked path from the initial state; and every admitted one-step move from every listed state has a coherently matching listed successor. Soundness follows from reachability and local validity. Completeness follows by induction on arbitrary history length from the one-step closure condition. Joining the certified source partitions gives the exact protection.

This universal closure certificate is the mathematical reason that a finite graph suffices. A number of sampled boundaries or successfully tested endpoints cannot replace it.

## 7. Coarse complexity and the CK consequence

Let \(I\) count the source's explicit incidence data: rigid vertices, written formula syntax, all leaf/vacancy interfaces, principal indices and route tables. The invariants \(N,K,b\) and source alphabet size are \(O(I)\). Mixed binary formulas of bounded size have at most \(2^{O(I\log(I+1))}\) choices. Bounded interfaces and their complete finite routing decorations have at most \(2^{O(I^2\log(I+1))}\) choices. Multiplying over \(O(I)\) vertices and then over source partitions, origin labelings and Cut orientations gives the coarse state bound

\[
 2^{O(I^3\log(I+1))}.
\tag{13}
\]

Exact local candidate enumeration is finite under the same bounded-incidence representation. This is a conservative single-exponential bound with polynomial exponent, not a tractability claim or a tight complexity classification. No executable implementation has been written for this extension.

The orientation is essential to the stronger CK conclusion. In (4), a producer-first inner Cut would give the physical frontier \((D,E,F)\) instead of \((E,D,F)\). The negative constructor fixes this by preserving the source order without a swap equation. The guarded commuting equation (5) likewise preserves \((E,P)\). With the typed, body-insensitive lifting and guarded projection of these cells established, the intrinsic heredity theorem applies to the same planar forest-concatenation carrier: computed protection characterizes exactly its retained native CK antichains, coproduct and relative material coaction. No change to a commutative product is required.

Rich finite-vector-space semantics is compatible with this registry when atomic interpretations and ambient material maps are fixed: the principal arrow equation is the evaluation/currying identity, and (5) is disjoint substitution through currying. This semantic fact is separately proved in the oriented-constructor report; it is not needed to obtain the source bounds or marked-state completeness. Its base-extension naturality must keep those ambient interpretations and exact routed registry fixed.

## 7a. Exact conservativity for existing tensor proofs

Call a proof **old** when it uses only positive Cuts, tensor constructors, the unchanged material stock and vacancies. Its fixed material interfaces may contain immutable implication formulas if the old tensor equipment already admits those interfaces; the definition concerns proof constructors. Then \(A_{\mathrm{arr}}(T)=0\).

**Conservativity theorem.** For every old proof \(T\), its reachable marked triples and intrinsic protection are exactly the same in the old tensor registry (2)–(3) and the mixed registry (2)–(5):

\[
 E^{\leftrightarrow}_{\mathrm{mix}}(T)
   =E^{\leftrightarrow}_{\mathrm{tensor}}(T).
\tag{14}
\]

**Proof.** Invariance and nonnegativity of \(A_{\mathrm{arr}}\) imply that every endpoint of any mixed history starting at \(T\) has no negative Cut and no implication constructor. Equation (4) cannot match in its forward direction without implication constructors or in its reverse direction without a negative Cut. Equation (5) cannot match in either direction without a negative Cut and an implication-right constructor. Hence every step of the mixed history is one of (2)–(3). Its exact marked update is the old tensor update. Conversely every old tensor history is an admitted mixed history. Therefore their full marked reachable sets and the joins of their partitions agree. QED.

Consequently the inclusion of old proofs both preserves and reflects universally safe native frontiers; it preserves their complete protected coproduct, not just a sufficient selection of cuts. Under the common fixed semantic label universe, the induced inclusion of protected planar forest Hopf algebras is injective and preserves coproduct, counit and antipode. This follows directly on each old generator from (14) and on forests by concatenation.

For an unchanged designated material selector \(\pi\), let \(i\) be this inclusion and \(i_B\) the corresponding inclusion on the material subalgebra. The selector square commutes:

\[
 \pi_{\mathrm{mix}}i=i_B\pi_{\mathrm{tensor}}.
\tag{15}
\]

The relative coactions and signed cores therefore satisfy

\[
 \rho_{\mathrm{mix}}i=(i_B\otimes i)\rho_{\mathrm{tensor}},
 \qquad
 \Pi_{\mathrm{mix}}i=i\Pi_{\mathrm{tensor}}.
\tag{16}
\]

Indeed \(\rho=(\pi\otimes\mathrm{id})\Delta\). If \(j_B:B\hookrightarrow H\) is the designated material-subalgebra inclusion, the core is \(\Pi=m_H(j_B S_B\pi\otimes\mathrm{id})\Delta\); Hopf morphisms preserve multiplication, inclusion and antipode, giving the second equality. Equivalently one can treat \(j_B\pi\) as the usual whole-monomial Hopf projection into \(H\). Thus all old live-material profiles retain their exact coaction and core observations. These identities commute with base extension when the registry, ambient interpretations and transported material selector stay fixed.

This is **conversion and decomposition conservativity on existing tensor proofs**. It makes no claim that adding implication constructors is conservative for derivability of arbitrary judgments or that every newly expressible mixed proof is old.

## 8. What has advanced, and the remaining boundary

The tensor-only complete-discovery theorem now extends to a concrete mixed tensor–implication registry while retaining the original planar CK product. The added difficulty is resolved by an explicit consumer-first Cut constructor and the corresponding disjoint currying conversion, not by ignoring the implication rule's physical provider permutation.

The universal discovery proof remains finite-state closure, a standard general method. Its project contribution is the logically justified finite bounds and exact agreement with the intrinsic hereditary CK protection, now for this oriented mixed presentation. The new theorem does not cover unit/identity erasure, unrestricted Cut orientations, all implication permutations, variable ambient semantics, arbitrary provider copying, or the full Avron structural registry. Each would require its own origin, order and finiteness argument.
