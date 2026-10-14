# Native four-schema CK boundary certification

Targets: T-IMP, with T-TRN/T-QUO scope. The 5 October 2026 mixed-protection,
higher-order-modularity and ordered-context-reuse papers specify the conversion
theory. Their universal paper arguments are not proof-assistant mechanizations.

## Retained native data and the additive ordered algebra

Native checked nodes have a complete ordered child list; indices are 1-based.
A native cut witness contains its source, lexicographic nonroot antichain,
address-aligned detached entries, and a typed punctured remainder. Filling each
entry back at its retained address reconstructs the source, including old holes.
Distinct addresses survive even for equal checked presentations. These data are
sufficient: the new ordered carrier reads the detached entries, never the native
commutative forest's expanded multiset. All existing commutative APIs are unchanged.

`make-ordered-forest` takes a word of native positive checked nodes in one exact
snapshot. `ordered-forest-concatenate` is independent juxtaposition, not logical
Cut, Mix, or filling. Integer sums and tensor coordinates retain word order.
`ordered-connected-coproduct` adds the witness-free `t tensor 1` once, then
the native empty/proper witnesses with their ordered detached words and positive
native remainders. A root selection is not a native cut; `Box` is not a factor.
`ordered-sum->commutative` is the explicit forgetful boundary, not an order recovery.

### Paper laws (constructor decomposition, not finite agreement)

For a positive constructor with ordered premises, restrict an antichain by its
first address slot. A positive child has exactly one empty, proper, or whole-child
choice; a vacant child has one identity choice. Conversely prefix the independent
proper addresses by their slots, select `(slot)` for a whole-child choice, and
concatenate words in slot order. The parent remainder uses the original checked
rule and converts a whole child to its typed vacancy. This is a two-way witness
bijection. The separate global whole term has no cut witness.

Coassociativity is the two-way bijection with three-stratum vertex flags, weakly
nonincreasing along root-to-leaf paths. Each stratum retains original typed slots;
transitions open vacancies, and old vacancies are never vertices. Separating
stratum 3 from 1+2 then 1 from 2, or 1 from 2+3 then 2 from 3, yields the same
ordered connected components. Their order is original forest position followed
by native address; nested components occupy contiguous planar intervals. Empty
strata and whole endpoints give the degenerate flags. Both constructions reverse
by native filling and preserve occurrence multiplicities before collection.

Concatenation is associative with the empty word as unit. The coproduct is
extended multiplicatively in that literal order, and the counit kills nonempty
words. Native vertex degree is additive and cut-conserved, and degree zero has
only the unit. Hence this is a connected graded bialgebra. The reduced-coproduct
recurrence `S(t)=-t-sum S(P_c)R_c` strictly decreases degree; the connected-graded
induction gives both convolution identities. On words the antipode reverses factor
order. It is an algebraic signed sum, not a normalization or inverse proof.
The forgetful projection preserves every uncollected witness, so it is a Hopf
map to the unchanged commutative algebra. The word-sensitive orientation obstruction
does not survive that projection. These are paper arguments; the test is only a
small separately labelled falsification/implementation check.

## Frozen schema snapshot and exact routing

`make-mixed-schema-calculus` takes an explicit exact nullary material stock. It
creates a native equipped-calculus snapshot admitting, from inception, the six
constructor schemas `cut+`, `cut-`, `tensorR`, `tensorL`, `impliesR`, `impliesL`.
There is no finite list of conversion instances. Logical instances are generated
from complete singleton/single-succedent unit-free boundaries, selected physical
indices, and actual output exchanges. Only the native checker constructs nodes.

Formulas are atoms, `(tensor A B)` and `(implies A B)`. Input selections are global
1-based positions in `formula-context->list`, NOT formula equality or a rule name.
Cut+ ports are producer/consumer; Cut- ports are consumer/producer. Tensor-left
has an ordered pair of distinct selections; implication-right records the original
discharge; implication-left records its continuation selection. Every passive
occurrence and connective path is stored, independently of component incidence.

Generated IDs encode canonical local indices and actual exchanges deterministically.
All type-preserving exchanges of repeated equal formulas are enumerated lazily.
There are no free administrative names to canonicalize: external boundary positions,
material IDs, source vertex IDs and physical ports are never quotiented. The
snapshot's admitted set is frozen; private interning memoizes exact `eq?` objects
without enlarging that set. Legacy finite-registry behavior is unchanged. The
finite-inventory APIs explicitly reject schema snapshots rather than pretending
that the already interned instances are a complete stock.

The conversion registry is exactly:

1. Tensor principal: positive outer Cut of tensor-right/tensor-left to the
   ordered two positive Cuts. The inverse selects both occurrences in the same
   innermost consumer, not in the second producer.
2. Positive Cut/tensor-left commute: selected D lies outside the packed pair.
3. Arrow principal: positive outer Cut of implication-right/left to positive
   outer B Cut with NEGATIVE inner A Cut. The discharge and continuation are
   the original selected occurrences.
4. Negative Cut/implication-right commute: selected D and discharged A are
   distinct occurrences, even if displayed formulas are equal.

Every inverse has the same exact routing conditions. Every provider occurs once,
in the same physical order. Matching reads the rigid shell and provider interfaces,
not provider bodies. Full external occurrence expressions are compared after
composing the supplied exchanges. Surrounding constructors are reassembled through
the native checker. No identity erasure, orientation swap, Cut/Cut permutation,
quotation, Communication, weakening, contraction or copying equation is admitted.

## Query and certificate

```
(certify-native-ck-boundary source native-cut-witness
  #:policy 'forward ; or 'bidirectional
  #:state-limit 4096 #:generation-limit 20000 #:time-limit-ms 30000)
```

The nodeless supported Box source uses the empty frontier `()` and has no rigid
vertices. Other frontiers must be native witnesses of the exact source object.
Unsupported constructors/boundaries and foreign witnesses return MALFORMED.

A marked state contains native endpoint U, a canonical partition pi of fixed source
vertex indices, and the surjective current-address origin map lambda. On each
whole-shell read, all touched origin blocks merge; replacement vertices receive
that block, copied providers retain their literal address correspondence, and
ALL outside vertices sharing a merged block are relabelled. Deduplication uses
the complete triple, so returning to the same endpoint with a different origin
partition is not a visited-state hit.

The worklist generates every legal routed local instance at every current vertex,
including inverse-created compound formulas. Output-exchange generation is lazy;
state, generation and wall-time caps give UNKNOWN, never SAFE from a prefix.
UNSAFE carries reachable checked local edges and a block crossing two named source
compartments. SAFE is returned only after the separate verifier independently
regenerates all one-step moves, rechecks every origin update, checks reachability,
and checks exact one-step closure and compartment containment. It does not call
the search or trust its accumulated verdict. A verifier whose own generation is
incomplete returns UNKNOWN, including when validating an unsafe history.

The paper invariants W=2(#Cut+ + #Cut-)+#logical, K=sum(|cut formula|+1), and
arrow charge=2#Cut-+#impliesR+#impliesL are checked on generated moves. The physical
material/vacancy frontier is unchanged, bounding every intermediate judgment's
atomic mass. Canonical routes and formula alphabet are source-bounded; the finite
marked state space therefore gives a complete decision method without implying
polynomial complexity. Bounded runs may still return UNKNOWN.

`ck-certificate-protection` joins every partition only after fresh complete closure
verification. `certified-ordered-coproduct` retains exactly native cuts whose
compartments are unions of those blocks, retaining their native witnesses and
typed reconstruction. Its separate cut cap returns UNKNOWN rather than a partial
sum labelled exact. Ordinary raw ordered and commutative CK remain available.

Do not apply raw `ordered-coproduct` repeatedly to a protected sum and call that
the protected iterated coproduct. Protected heredity needs intrinsic closure on
the extracted pieces (or the paper projection/lifting theorem). A universal
protected Hopf/coaction/core implementation is not claimed here. Behavioral
replacement equality, live-profile fidelity and arbitrary future refilling are
separate, unassessed obligations. No proof-assistant universal theorem is MECHANIZED.

## Fixed evidence and runnable example

`tests/ck-boundary-certification-test.rkt` imports the public facade and the small
ordered-law test. It checks all cells/inverses, equal-formula physical indices,
the contextual m=2 policy distinction and checked two-step inverse crossing,
outside-origin relabelling, endpoint-only dedup regression, tensor and curried
scaffold partitions, certificate tampering, caps, foreign provenance and native
retained-cut reconstruction. Ordered laws also use six fixed trees, ten words
and their native cut witnesses; this is not a growing exhaustive fixture.

`examples/native-ck-certification.rkt` prints the forward SAFE versus bidirectional
UNSAFE result for the dependent second producer. Both use one exact schema snapshot.

Status: paper constructor/flag proofs are PROVED under the displayed assumptions;
successful focused execution is CODE-CHECKED / BOUNDED-EVIDENCE, not a universal
mechanization. Execution results belong in the handoff report, not inferred from
source presence. No benchmark or practical performance superiority is claimed.
