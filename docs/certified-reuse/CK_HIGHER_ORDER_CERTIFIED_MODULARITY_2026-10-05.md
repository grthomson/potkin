# Higher-order certified modularity: principal application and exact CK comparison

Date: 5 October 2026. Advances T-TRN/T-QUO with T-NRM/T-DBL compatibility. Status: universal paper theorem; the typed stage induction, physical frontier, certificate length, exact all-history partition and closure received an independent mathematical audit. No finite testing or mechanization is used. The new claim is an intrinsic planar CK theorem for a genuine implication application family; ordinary closed-category beta soundness was already established in the project's relative-soundness paper.


The substantive advance is that effective intrinsic decomposition now handles genuine curried function application in a precisely fixed positive \(\otimes,\multimap\) presentation. Every body, argument and continuation can remain separately exposed under the complete conversion theory. A conserved charge proves exact preservation and reflection of every old tensor cut. A separate contextual classification shows exactly when forward reuse and conversion-invariant decomposition demand different boundaries.

Read `CK_MIXED_PRINCIPAL_PROTECTION_2026-10-05.md` for the full general discovery proof and comparison equations; read `CK_ORDERED_CONTEXT_REUSE_2026-10-05.md` for the positional contextual theorem. The independent reviews and bounded primary-literature comparison are in `CK_HIGHER_ORDER_PROOF_AND_NOVELTY_AUDIT_2026-10-05.md`. These claims are universal paper proofs, with no finite checker, native implementation run or proof-assistant mechanization.

## 1 The obstruction and concrete repair

In the ordinary physical presentation, implication principal Cut has provider frontier E,D,R at its introduction/elimination endpoint and D,E,R at its two-Cut endpoint. A semantic exchange of tensor wires does not repair that change of physical provider order. The existing position-preserving planar intrinsic-Hopf theorem cannot be applied to that equation as stated.

Use two explicitly checked ordered Cut constructors. They are inference constructors, not a rewrite equation identifying their orders. For a producer P:Gamma=>A and consumer Q:Theta,A=>B, with one actual selected A occurrence, set

\[
\operatorname{Cut}^+_A(P,Q):\Gamma,\Theta\Rightarrow B,
\qquad
\operatorname{Cut}^-_A(Q,P):\Theta,\Gamma\Rightarrow B.
\tag{1.1}
\]

The physical premise list of Cut+ is producer,consumer; the list of Cut- is consumer,producer. Multiset antecedents have retained local physical occurrence indices and explicit coherent exchanges to the displayed ordered representative. Cut- substitutes the producer map into the consumer's selected input exactly as Cut+ does. The signature stores the orientation and its premise roles. There is no registered provider swap and no equation Cut+(P,Q)=Cut-(Q,P).

Formulas are unit-free IMLL formulas built from atoms by tensor and implication. Primitive material proof vertices are nullary, with fixed checked judgment and map denotation. Logical constructors and both Cut orientations are trusted background. Typed vacancies have complete interfaces but no proof vertex.

**Proposition 1.1 (logical conservativity of the ordered presentation).** Adding Cut- does not change which indexed multiset judgments are derivable from a fixed primitive base. There is a type- and denotation-preserving translation to the ordinary Cut+ presentation, using the explicitly recorded antecedent exchange. This translation is not asserted to preserve planar CK decomposition.

**Proof.** Recursively translate all ordinary constructors literally. Translate Cut-_A(Q,P) to Cut+_A(P,Q), followed by the coherent exchange from Gamma,Theta to Theta,Gamma. This is a well-typed ordinary proof of the same multiset judgment with the same retained external occurrence IDs. Its denotation equals the original Cut- after that exchange by the definition of consumer-first substitution. Conversely every ordinary proof is already a proof using only Cut+ in the enriched presentation. Thus derivable judgments coincide. The translation changes the physical provider order P,Q versus Q,P; it supplies no planar-Hopf comparison and no identification of those ordered proof trees. QED.

## 2 The exact additional cells

Use the ordinary checked implication constructors, with selected occurrence records:

\[
\frac{E:\Gamma,A\Rightarrow B}
 {\multimap R_A(E):\Gamma\Rightarrow A\multimap B},
\qquad
\frac{D:\Delta\Rightarrow A\quad R:\Theta,B\Rightarrow C}
 {\multimap L_{A,B}(D,R):\Delta,\Theta,A\multimap B\Rightarrow C}.
\tag{2.1}
\]

The displayed consumer B and discharged A have actual retained indices. The implication-left output occurrence has an exact decomposition record into those A/B positions.

Register principal implication beta and its checked inverse:

\[
\operatorname{Cut}^+_{A\multimap B}
  (\multimap R_A(E),\multimap L_{A,B}(D,R))
\quad\longleftrightarrow\quad
\operatorname{Cut}^+_B(\operatorname{Cut}^-_A(E,D),R).
\tag{2.2}
\]

Here E:Gamma,A=>B, D:Delta=>A and R:Theta,B=>C. Both endpoints have full conclusion Gamma,Delta,Theta=>C after the retained exchange. Their physical provider list is literally E,D,R on both sides. The source is a connected three-node rigid shell and the target a connected two-node rigid shell. The complete rigid shell is collapsed to one nonempty causal origin class at either endpoint. Every provider port is transported exactly once.

The inverse requires an outer Cut+ on B, a producer root Cut- on A, and its exact consumer/producer roles. It reconstructs the discharged A and selected B positions, their implication-left decomposition, and the recorded boundary exchange. It does not accept an inner Cut+ by silently reversing its ports. Fresh names for the reconstructed discharged occurrence are private, subject only to coherent alpha-renaming preserving their actual route and external boundary identities.

For repeated implication application one more cell is necessary. Principal beta leaves the next implication-right vertex inside the newly created Cut-. Register only the disjoint commutation

\[
\operatorname{Cut}^-_D(\multimap R_A(E),P)
\quad\longleftrightarrow\quad
\multimap R_A(\operatorname{Cut}^-_D(E,P)),
\tag{2.3}
\]

where E:Gamma,D,A=>B, P:Delta=>D, and the selected D occurrence is distinct from the discharged A occurrence. Both endpoints are Gamma,Delta=>A implication B; their physical provider order is E,P. The source/target each have two connected rigid nodes, marked together as one positive causal class. The inverse reconstructs the same two distinct occurrence routes; equality of displayed formulas D=A does not identify their indices.

Retain the previous two tensor cells, using only Cut+:

\[
\operatorname{Cut}^+_{A\otimes B}(\otimes R(P,Q),\otimes L(R))
\leftrightarrow \operatorname{Cut}^+_A(P,\operatorname{Cut}^+_B(Q,R)),
\tag{2.4}
\]

\[
\operatorname{Cut}^+_D(P,\otimes L(R))
\leftrightarrow\otimes L(\operatorname{Cut}^+_D(P,R)),
\tag{2.5}
\]

with precisely their old disjointness and inverse routing conditions. Equations (2.2)–(2.5) and their checked inverses are the entire registry here. There is no Cut-orientation exchange, Cut/Cut reassociation, identity erasure, quotation, Communication, contraction or weakening.

## 3 Open soundness and actual closure

Interpret the fragment in finite-dimensional vector spaces over a fixed field k, with tensor and internal hom Hom(V_A,V_B). Antecedents denote their ordered tensor object. Keep every required associator and symmetry or use the previously chosen coherent strictification. Primitive IDs have their fixed ambient map assignment.

For E:Gamma,A=>B let e:V_Gamma tensor V_A=>V_B. Its implication-right meaning is curry(e):V_Gamma=>Hom(V_A,V_B). If d:V_Delta=>V_A and r:V_Theta tensor V_B=>V_C, implication-left denotes application of its distinguished hom argument to d, followed by r. Cut- has precisely the ordinary substitution map in its consumer-first input order.

**Proposition 3.1.** The complete open operations of (2.2) and (2.3) agree for every typed provider tuple.

**Proof.** With the fixed transport placing the output antecedent blocks Gamma,Delta,Theta, the two sides of (2.2) both send a pure input x tensor y tensor z to r(z tensor e(x tensor d(y))). The closed-category evaluation/currying equation, or its direct finite-dimensional definition, gives the source expression. Ordinary substitution gives the target expression. Pure tensors span, so the maps agree. This is equality for arbitrary independent e,d,r of their declared interfaces.

For (2.3), write E's inputs in the recorded order Gamma,D,A. Both sides send x tensor y to the hom a |-> e(x tensor p(y) tensor a). The distinct D substitution commutes with currying the A coordinate. The equality holds for every e,p, even when the formulas on the two distinguished input occurrences coincide. QED.

Every port is used once, so the corresponding operation is multilinear in its provider-map arguments. Negative positions of implication are semantic input coordinates or internal hom variance; they are not additional physical proof-provider occurrences. Neither cell copies or deletes E, D or R.

Under the logical translation of Proposition 1.1, (2.2) becomes the usual principal implication equation with inner Cut+(D,E), and (2.3) becomes the usual disjoint Cut+/implication-right commute. Thus the new registered equalities have standard logical and semantic images. Their extra force here is the retained physical port order before that translation. This is logical conservativity, not equivalence of the two proof-identity theories or a new completeness result for ordinary Cut elimination.

Admission reads only the rigid constructors, their selected occurrences and the full port interfaces. Every same-interface filling and typed vacancy therefore yields the same admitted open instance. This proves opacity. Full conclusion interfaces are unchanged under recorded exchange, so arbitrary checked surrounding contexts lift the cell. Whole-shell connected reads contained in one transported cut compartment project to that same compartment; replaced outside subtrees are opaque holes, so the projected positive cell remains admitted. The positive cospan restricts exactly to each compartment, just as in the existing tensor proof. Independent forest factors are not jointly inspected. All four cells preserve the physical left-to-right frontier order; surrounding one-use contexts and arbitrary fillings preserve that order too.

Consequently the previously established intrinsic positive-conversion theorem applies to this concrete extended registry with the planar forest-concatenation product unchanged. Semantic exchanges occur inside the retained interfaces, not as an alteration of the ordered detached forest. Bases may enlarge the allowed primitive stock inside a fixed ambient ID/map assignment; registry and meanings are constant, so the semantic construction is natural over this inclusion tower.

## 4 Arbitrary-arity implication application

Choose m>=1, formulas A_1,...,A_m and B, and define

\[
F_j=A_j\multimap F_{j+1}\quad(1\le j\le m),
\qquad F_{m+1}=B.
\tag{4.1}
\]

Every designated A_i has a distinct physical input occurrence, including repeated formula names. Let

\[
E:\Gamma,A_1,\ldots,A_m\Rightarrow B,
\quad D_i:\Delta_i\Rightarrow A_i,
\quad R:\Theta,B\Rightarrow C.
\tag{4.2}
\]

Define CUR_j by successively currying A_j,...,A_m in E, so CUR_j:Gamma,A_1,...,A_{j-1}=>F_j and CUR_{m+1}=E. Define APP_{m+1}=R and

\[
APP_j=\multimap L_{A_j,F_{j+1}}(D_j,APP_{j+1}).
\tag{4.3}
\]

Let H_0(X)=X and H_j(X)=Cut^-_{A_j}(H_{j-1}(X),D_j), on the typed X that still has the designated A_1,...,A_j inputs. Put

\[
T_m=\operatorname{Cut}^+_{F_1}(CUR_1,APP_1),
\qquad
N_m=\operatorname{Cut}^+_B(H_m(E),R).
\tag{4.4}
\]

Both have conclusion Gamma,Delta_1,...,Delta_m,Theta=>C and the same physical frontier E,D_1,...,D_m,R. The source scaffold has 2m+1 vertices: its root Cut+, m implication-right nodes and m implication-left nodes. The target scaffold has m+1 Cut vertices: m Cut- and one outer Cut+. If all A_i and B are atomic, every target Cut is atomic; no primitive evaluation of those Cuts is included.

**Theorem 4.1 (positive planar application residualization).** A concrete history of (2.2), (2.3) takes T_m to N_m. It uses exactly m principal cells and m(m-1)/2 disjoint commutations, hence m(m+1)/2 local cells. Its complete source-origin kernel has all 2m+1 original scaffold vertices in one class, and every target scaffold vertex belongs to that class.

**Proof.** At stage j the displayed outer proof is

\[
\operatorname{Cut}^+_{F_j}(H_{j-1}(CUR_j),APP_j).
\tag{4.5}
\]

The j-1 Cut- wrappers of H_{j-1} substitute the already used A_1,...,A_{j-1} coordinates. The outermost constructor of CUR_j is implication-right discharging A_j. Starting at the innermost wrapper, commute that implication-right out through all j-1 wrappers using (2.3). Each selected previous A_i is distinct from the discharged A_j. This produces

\[
\operatorname{Cut}^+_{F_j}
 (\multimap R_{A_j}(H_{j-1}(CUR_{j+1})),
  \multimap L_{A_j,F_{j+1}}(D_j,APP_{j+1})).
\tag{4.6}
\]

Apply (2.2); its result is (4.5) with j replaced by j+1. For j=1 no commutation is needed. At j=m the result is N_m. The stage uses exactly j-1 commutations and one principal cell, so summing proves the displayed length. Every provider occurrence retains its position and is used once.

The first principal cell merges the initial Cut and first two implication nodes; its new Cut+ and Cut- inherit that class. At all later stages, every Cut participating in either a commute or principal cell belongs to that initial class: the residual outer Cut+ and all Cut- wrappers were created by previous principal steps. A commute absorbs the exposed implication-right node into it; a principal absorbs the matching implication-left node and any not already absorbed implication-right node. Every original implication node is eventually so absorbed. Every new Cut inherits the class. These are all scaffold vertices. QED.

The bound is a paper certificate-length bound, independent of opaque provider-body sizes. It is not a wall-clock bound, a general bidirectional-orbit bound, or a claim that every strategy normalizes.

Every discharge in this schedule follows the original designated E.A_j occurrence. Even if a previous argument's context Delta_i contains another occurrence of the formula A_j, that new context occurrence stays passive; it is not discharged or confused with E.A_j. This retained routing is necessary for the typed stage induction and for the disjointness of every commute.

The common operation is

\[
\Phi_m(e,d_1,\ldots,d_m,r)
 =r\circ\left(\mathrm{id}_{\Theta}\otimes
   \left[e\circ(\mathrm{id}_\Gamma\otimes d_1\otimes\cdots\otimes d_m)\right]
             \right)
\tag{4.7}
\]

after the fixed input association/permutation. Equivalently, on the ordered inputs x,y_1,...,y_m,z it gives r(z tensor e(x tensor d_1(y_1) tensor ... tensor d_m(y_m))). Equation (4.7) is written with Theta first at r's own consumer interface; the external Gamma,Delta_1,...,Delta_m,Theta order is restored by its explicitly retained exchange.

## 5 Exact all-history partition and live-provider CK corolla

Now require E,D_1,...,D_m,R to be distinct nullary primitive material vertices. Their antecedents and sequents can be nontrivial; nullarity refers to physical proof-premise ports.

**Theorem 5.1 (exact maximal intrinsic protection).** For the four-cell registry (2.2)–(2.5),

\[
E^{\leftrightarrow}(T_m)
 =\{\mathrm{Scaffold}(T_m),\{E\},\{D_1\},\ldots,\{D_m\},\{R\}\}.
\tag{5.1}
\]

At N_m its scaffold of m+1 Cuts is one block, and the same m+2 primitive providers are singleton blocks. These partitions quantify over every finite admitted zigzag, including both tensor cells and all four checked inverse families.

**Proof.** Theorem 4.1 supplies the whole source scaffold as one source-origin class in a particular finite history, hence as a lower bound on the intrinsic join. Every registered read shell contains only logical/Cut constructors. Every material provider remains outside every read shell, is retained once, and has an unchanged distinct source origin. Thus no history can merge it into any other class. There are no further source vertices; the lower bound is exact. Reversing the same history gives the target scaffold block. QED.

All native interior-scaffold cuts are unsafe, with the single history of Theorem 4.1 as a counterhistory of length m(m+1)/2. Every subset of the m+2 provider attachment edges is an admissible antichain with saturated compartments. The exact partition has O(m) structural description and can be returned by one node traversal after interface admission. This does not bound the cost of reading explicitly repeated formula annotations.

The intrinsic semantic Hopf image is the corolla U_m with positive root K_m and ordered primitive children E,D_1,...,D_m,R. Its fully punctured root label contains their complete ordered interfaces and operation Phi_m. Every root label is independent of which slots are currently occupied. If I is a subset of these m+2 indexed child positions, let P_I be their ordered forest and R_I the same root with precisely the I slots reopened. Then

\[
q(T_m)=q(N_m)=U_m,
\qquad
\Delta U_m=U_m\otimes1+
 \sum_{I\subseteq\{0,1,\ldots,m,m+1\}}P_I\otimes R_I.
\tag{5.2}
\]

There are 2^(m+2) indexed provider-subset terms including the empty subset, together with the separate whole-tree algebraic endpoint. Multiplicities are indexed before collecting equal labels. The planar product is ordinary ordered forest concatenation, and every ordered leaf position survives literally. No commutative or Grossman–Larson replacement is used.

The existing hereditary intrinsic theorem proves equality at every iterated cut flag and commutation with the CK coproduct, antipode, material coaction and relative signed core. Background root is trusted. Primitive purity is retained in the labels, so every selected stock-profile projector descends. For trusted provider-position subset J, the same closed formulas as the tensor corolla specialize to

\[
\rho_JU_m=\pi_J(U_m)\otimes1+
 \sum_{I\subseteq J}P_I\otimes R_I.
\tag{5.3}
\]

For proper J the core is sum_{I subseteq J} (-1)^|I| rev(P_I) dot R_I, where dot is forest concatenation. For full J it is zero. Distinct material IDs ensure that the connected U_m term cannot cancel for proper J. These formulas are applications of the existing CK coaction/core theorem, not fresh claims about the generic antipode.

Arbitrary same-interface compound fillings preserve the displayed local history and operation equality. They do not automatically preserve (5.1): a later admitted conversion can inspect a logical constructor inside a newly inserted body. The primitive-provider hypothesis is the stated sufficient all-history saturation condition.

## 6 Conserved bounds and the effective mixed fragment

The finite discovery theorem from the pure tensor registry extends by the same marked-state construction if the four additional constructor cases are counted explicitly. Let C count both Cut orientations; let L count all tensor-right/left and implication-right/left nodes. Then

\[
W=2C+L,
\qquad
K=\sum_{\operatorname{Cut}^{\pm}_F}(|F|+1),
\tag{6.1}
\]

where |F| counts all formula syntax nodes, are invariant. Both principal cells have rigid weight 4 at both endpoints; both commutes preserve constructor counts. For either connective circ in {tensor,implication}, |A circ B|+1=(|A|+1)+(|B|+1), so principal splitting preserves K. Orientation is finite discrete syntax data, not an unbounded parameter.

Let a(F) count atomic leaves, treating both tensor and implication as additive on their two factors. Judgment mass sums a over antecedent and succedent occurrences. Tensor-right and implication-left output mass equal the sum of their premise masses. Tensor-left and implication-right preserve mass. Both Cut orientations subtract 2a(F) from the sum of premise masses. Consequently every variable logical/Cut-region interface is bounded by the total mass of its unchanged physical frontier judgments. No rule introduces a new atom label. Each formula with at most b leaves has at most 2b-1 unit-free syntax nodes, using a finite two-connective alphabet. Exact routing tables therefore have a finite source-dependent bound too.

Private discharge names are alpha-canonicalized while retaining all external identities and actual routes. The positive marked state (current checked term,source partition,current source-origin labels) is finite for fixed source. Generating every one-step instance and each checked inverse, with exact whole-shell origin update, terminates. Soundness and completeness follow by the same path induction as the existing discovery theorem; every endpoint and marked partition of an arbitrary finite history is generated. The extended result thus retains a complete universal safety-or-offending-history contract. It is not justified merely by checking the specific application family.

This section supplies the new conservation and interface cases; the independently delegated mixed-discovery report gives the complete algorithm/certificate proof and its separate complexity qualification. No implementation is claimed.


### 6.1 Exact tensor-to-mixed comparison

Let

\[
\mathsf A(T)=2\#\operatorname{Cut}^{-}(T)
 +\#\multimap R(T)+\#\multimap L(T).
\tag{6.2}
\]

This nonnegative charge is conserved by all four registered cells and their inverses. Tensor cells leave its counts unchanged. Arrow principal conversion replaces two arrow vertices by one negative Cut, preserving charge two. The arrow-right commutation retains one negative Cut and one arrow-right vertex.

**Theorem 6.1 (exact old-sector conservativity).** For any existing tensor proof using only positive Cuts, tensor constructors, the unchanged material stock and vacancies,

\[
E^{\leftrightarrow}_{\mathrm{mix}}(T)
 =E^{\leftrightarrow}_{\mathrm{tensor}}(T).
\tag{6.3}
\]

**Proof.** Such a source has charge zero. Every mixed endpoint therefore has neither a negative Cut nor an implication constructor. Forward arrow beta requires implication constructors, its inverse requires a negative Cut, and both directions of the arrow-right commutation require a negative Cut and an arrow-right vertex. None can match. Thus every mixed history is an old tensor history with its identical origin updates. Every old history is conversely admitted. Their marked reachable sets and partition joins agree. QED.

The old and mixed native cuts and iterated flags coincide on these sources. The inclusion \(i:H_{\mathrm{tensor}}\hookrightarrow H_{\mathrm{mix}}\) is consequently an injective Hopf map preserving and reflecting every admitted native frontier. In a common fixed interpretation the semantic-image inclusion is also well-defined: old fully punctured operations, material IDs and exact interfaces are unchanged.

For the corresponding selected material-subalgebra inclusion \(i_B\),

\[
\pi_{\mathrm{mix}}i=i_B\pi_{\mathrm{tensor}},\qquad
\rho_{\mathrm{mix}}i=(i_B\otimes i)\rho_{\mathrm{tensor}},\qquad
\Pi_{\mathrm{mix}}i=i\Pi_{\mathrm{tensor}}.
\tag{6.4}
\]

The first identity holds by literal material selection; the coaction identity follows from the coproduct; the core identity follows from multiplication and antipode preservation. Every fixed-registry primitive-base inclusion commutes with this comparison. Hence admitting this higher-order conversion cannot invalidate an existing tensor decomposition or its trust-profile observations.

This is conversion/decomposition conservativity **on existing proofs**. It is separate from Proposition 1.1, which compares the two Cut presentations' derivable judgments in the same full formula language. No theorem of tensor-language derivability conservativity is inferred from either.

### 6.2 Why ordinary orientation erasure is not a Hopf comparison

Let \(e,d,r\) be distinct primitive providers and form the one-argument residual endpoint

\[
N_1=\operatorname{Cut}^{+}_B(\operatorname{Cut}^{-}_A(e,d),r).
\]

Let \(f\) erase the negative orientation by reversing its ordered premises, as in Proposition 1.1; the necessary coherent antecedent exchange is retained as boundary routing data. Removing all three primitive leaves is the unique native cut with pruned word \(edr\) and the nonempty two-Cut punctured remainder \(K\). Thus \((f\otimes f)\Delta N_1\) has the term \(edr\otimes f(K)\) with coefficient one. But \(f(N_1)=\operatorname{Cut}^{+}_B(\operatorname{Cut}^{+}_A(d,e),r)\) has maximal provider word \(der\), and coefficient zero on \(edr\otimes f(K)\). Other cuts have fewer primitive components or a component containing a Cut; none contributes to this coefficient. Hence

\[
\Delta_{\mathrm{native}} f(N_1)\ne(f\otimes f)\Delta_{\mathrm{native}} N_1.
\tag{6.5}
\]

So erasure preserves the actual judgment and aligned program denotation but fails the native ordered coproduct. No quotient identifying its provider words is taken. This supplies a concrete comparison where behavioral adequacy and CK decomposition exactness are different mathematical properties.

## 7 A worked application and the two reuse contracts

For a one-argument example over \(\mathbb Q\), let all displayed atomic spaces be one-dimensional. Take distinct material maps

\[
e:\mathbb Q\otimes\mathbb Q\to\mathbb Q,
 \quad e(x\otimes a)=3xa;
\qquad d:\mathbb Q\to\mathbb Q,\ d(y)=2y;
\qquad r:\mathbb Q\to\mathbb Q,\ r(b)=5b.
\]

Their proof interfaces are \(E:g,a\Rightarrow b\), \(D:h\Rightarrow a\), and \(R:b\Rightarrow c\), with retained indices. Currying produces the function \(a\mapsto3xa\); applying it to \(2y\), then the continuation, gives \(30xy\). The repaired single beta step has exactly the same map and exactly the same ordered CK corolla with children \(E,D,R\).

The CK result carries eight indexed provider-subset frontiers plus the whole-tree endpoint, including the simultaneous word \(EDR\) and each corresponding typed punctured continuation. These decompositions specify what a detached provider analysis means. An analysis depending on one provider's denotation can change even when compensating provider changes preserve the closed value \(30xy\). The earlier joint contract decides whole-operation equality; the retained labels and coaction decide component and trust reuse. This example illustrates the universal theorem and is not evidence replacing its proof.

The contextual theorem in `CK_ORDERED_CONTEXT_REUSE_2026-10-05.md` addresses a different, non-isolated situation. Feed one fresh input \(d\) to exactly one primitive provider \(P_j\) of a tensor bundle and enclose the bundle in \(\operatorname{Cut}_d(S,-)\), with the precise distinct-atom interfaces specified there. Then:

| Decomposition contract for the whole bundle edge | Exact result |
|---|---|
| Every forward admitted normalization history | Safe for every position \(j\) |
| Every admitted conversion zigzag, including inverses | Safe exactly when \(j=1\) |

For later positions, a bundle residualization followed by one inverse principal cell reads across the boundary, merging outer and inner scaffold origins. The offending history has at most \(2m(m-1)+1\) cells. At the first position, an invariant fixes the unique \(d\) occurrence in the inner root's producer, prohibiting any first crossing. The forward-only proof needs no positional restriction: the outer Cut cannot be a forward tensor redex or tensor-left commute at its atomic interface.

This proves an exact operational-policy distinction. It does not assert that supplying \(d\) has no semantic effect, that all choices of \(j\) have equal denotations, or that arbitrary later compound refilling preserves these partitions. The two-step \(m=2,j=2\) history also disproves exact discovery from initially visible redex components alone. General polynomial discovery remains open.

## 8 What actually advances

The pre-existing relative-soundness work already proves ordinary principal tensor/implication soundness in SMCCs, and the 4 October paper already proves effective protection for tensor. The new candidate is **effective higher-order planar CK modularity**, combining the exact all-history application partition, explicit counterhistory bound, conservative tensor-to-mixed comparison and sharp contextual policy distinction. It extends effective intrinsic modularity to the requested core tensor/implication fragment while retaining the planar CK algebra literally.

The carrier is enriched by a checked Cut-orientation tag. There is no assertion that its equation theory is equivalent to an ordinary single-orientation proof-identity quotient. Whether a chosen native API admits both orientations is an implementation obligation. Identity-Cut erasure, units, quotations, structural copying, Communication, arbitrary Cut permutations and general Cut-free progress remain outside this positive registry. Material-base naturality uses a fixed ambient map assignment; redefining existing primitive maps requires the separate previously developed comparison contract.

The inverse arrow beta is admitted only when its exact two-Cut orientation and occurrence routes match. This restriction is substantive: broadening it by an unregistered provider permutation would invalidate the planar theorem just repaired.
