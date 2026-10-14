#lang racket/base

(require racket/list
         racket/vector
         "../kernel/calculus.rkt"
         "../kernel/check.rkt"
         "../kernel/context.rkt"
         "../kernel/cut.rkt"
         (prefix-in comm: "../algebra/formal-sum.rkt"))

(provide ordered-forest?
         make-ordered-forest
         ordered-forest-calculus
         ordered-forest-factors
         empty-ordered-forest
         ordered-forest-empty?
         ordered-forest-size
         ordered-forest-degree
         ordered-forest-concatenate
         ordered-cut-forest
         ordered-forest->commutative
         ordered-sum?
         ordered-sum-calculus
         ordered-sum-rank
         make-ordered-sum
         ordered-zero
         ordered-zero?
         ordered-unit
         ordered-pure-tensor
         ordered-forest-basis
         ordered-node-basis
         ordered-sum-terms
         ordered-sum-support-size
         ordered-sum-coefficient
         ordered-sum-add
         ordered-sum-scale
         ordered-sum-negate
         ordered-sum-subtract
         ordered-sum-multiply
         ordered-sum-tensor
         ordered-sum-expand-coordinate
         ordered-tensor-multiply
         ordered-connected-coproduct
         ordered-forest-coproduct
         ordered-coproduct
         ordered-forest-counit
         ordered-counit
         ordered-tensor-counit-left
         ordered-tensor-counit-right
         ordered-forest-antipode
         ordered-antipode
         ordered-antipode-convolution-left
         ordered-antipode-convolution-right
         ordered-sum->commutative)

;; This is an explicitly additive ORDERED algebra layer. It changes neither
;; proof-forest nor any checked proof, context, cut, or native tensor API.
;; A forest word is independent juxtaposition, never filling, Mix, or Cut.
;; Its factors are existing positive checked nodes, including open nodes with
;; typed vacancies. Box alone is not a factor and is not the forest unit.
;; Presentation equality omits registry identity just as native tree/forest
;; equality does; every operation separately requires exact eq? provenance.
(struct ordered-forest (calculus factors)
  #:constructor-name make-ordered-forest/internal
  #:property prop:equal+hash
  (list (lambda (left right recur)
          (and (ordered-forest? right)
               (recur (ordered-forest-factors left)
                      (ordered-forest-factors right))))
        (lambda (value recur) (recur (ordered-forest-factors value)))
        (lambda (value recur) (recur (ordered-forest-factors value)))))

(define (check-calculus who calculus)
  (unless (equipped-calculus? calculus)
    (raise-argument-error who "equipped-calculus?" calculus)))

(define (check-exact-calculus who expected actual)
  (unless (eq? expected actual)
    (raise-arguments-error
     who "operation requires one exact equipped-calculus snapshot"
     "expected calculus" expected "actual calculus" actual)))

(define (check-forest who forest)
  (unless (ordered-forest? forest)
    (raise-argument-error who "ordered-forest?" forest)))

(define (make-ordered-forest calculus factors)
  (check-calculus 'make-ordered-forest calculus)
  (unless (and (list? factors) (andmap checked-node? factors))
    (raise-argument-error
     'make-ordered-forest "(listof checked-node?)" factors))
  (for ([factor (in-list factors)])
    (unless (and (checked-term-has-exact-calculus? factor calculus)
                 (term-admitted-by? calculus factor))
      (raise-arguments-error
       'make-ordered-forest
       "every factor must be a native checked node of the exact calculus"
       "calculus" calculus "factor" factor)))
  (make-ordered-forest/internal calculus factors))

(define (empty-ordered-forest calculus)
  (make-ordered-forest calculus '()))

(define (ordered-forest-empty? forest)
  (check-forest 'ordered-forest-empty? forest)
  (null? (ordered-forest-factors forest)))

(define (ordered-forest-size forest)
  (check-forest 'ordered-forest-size forest)
  (length (ordered-forest-factors forest)))

(define (ordered-forest-degree forest)
  (check-forest 'ordered-forest-degree forest)
  (for/sum ([factor (in-list (ordered-forest-factors forest))])
    (derivation-vertex-count factor)))

(define (ordered-forest-concatenate first . rest)
  (check-forest 'ordered-forest-concatenate first)
  (define calculus (ordered-forest-calculus first))
  (for ([forest (in-list rest)])
    (check-forest 'ordered-forest-concatenate forest)
    (check-exact-calculus 'ordered-forest-concatenate calculus
                         (ordered-forest-calculus forest)))
  (make-ordered-forest/internal
   calculus (append-map ordered-forest-factors (cons first rest))))

;; Crucially, consume the native address-aligned tuple BEFORE collection.
;; proof-forest-factors has already irreversibly forgotten this order.
(define (ordered-cut-forest witness)
  (unless (cut-witness? witness)
    (raise-argument-error 'ordered-cut-forest "cut-witness?" witness))
  (make-ordered-forest
   (checked-term-calculus (cut-witness-source witness))
   (map detached-entry-term (cut-witness-detached witness))))

(define (ordered-forest->commutative forest)
  (check-forest 'ordered-forest->commutative forest)
  (make-proof-forest (ordered-forest-calculus forest)
                     (ordered-forest-factors forest)))

;; Immutable finite integer support; tensor coordinates AND factor words are
;; ordered. Equal presentations collect only after exact provenance checking.
(struct ordered-sum (calculus rank support)
  #:constructor-name make-ordered-sum/internal
  #:property prop:equal+hash
  (list (lambda (left right recur)
          (and (ordered-sum? right)
               (eq? (ordered-sum-calculus left)
                    (ordered-sum-calculus right))
               (= (ordered-sum-rank left) (ordered-sum-rank right))
               (recur (ordered-sum-support left)
                      (ordered-sum-support right))))
        (lambda (value recur)
          (recur (list (eq-hash-code (ordered-sum-calculus value))
                       (ordered-sum-rank value)
                       (ordered-sum-support value))))
        (lambda (value recur)
          (recur (list (ordered-sum-support value)
                       (ordered-sum-rank value)
                       (eq-hash-code (ordered-sum-calculus value)))))))

(define (check-sum who sum)
  (unless (ordered-sum? sum)
    (raise-argument-error who "ordered-sum?" sum)))

(define (check-rank who sum rank)
  (check-sum who sum)
  (unless (= (ordered-sum-rank sum) rank)
    (raise-arguments-error who "wrong ordered tensor rank"
                           "expected rank" rank
                           "actual rank" (ordered-sum-rank sum))))

(define (checked-key who calculus rank key)
  (unless (and (vector? key) (= (vector-length key) rank))
    (raise-arguments-error who "basis key must match the tensor rank"
                           "rank" rank "key" key))
  (for ([forest (in-vector key)])
    (check-forest who forest)
    (check-exact-calculus who calculus (ordered-forest-calculus forest)))
  (vector->immutable-vector (vector-copy key)))

(define (support-add support key coefficient)
  (define next (+ coefficient (hash-ref support key 0)))
  (if (zero? next) (hash-remove support key) (hash-set support key next)))

(define (make-ordered-sum calculus rank summands)
  (check-calculus 'make-ordered-sum calculus)
  (unless (exact-positive-integer? rank)
    (raise-argument-error 'make-ordered-sum "exact-positive-integer?" rank))
  (unless (list? summands)
    (raise-argument-error 'make-ordered-sum "list?" summands))
  (make-ordered-sum/internal
   calculus rank
   (for/fold ([support (hash)]) ([summand (in-list summands)])
     (unless (and (pair? summand) (exact-integer? (cdr summand)))
       (raise-arguments-error
        'make-ordered-sum "summand must be (cons vector exact-integer)"
        "summand" summand))
     (support-add support
                  (checked-key 'make-ordered-sum calculus rank (car summand))
                  (cdr summand)))))

(define (ordered-zero calculus [rank 1])
  (make-ordered-sum calculus rank '()))

(define (ordered-zero? value)
  (and (ordered-sum? value)
       (zero? (hash-count (ordered-sum-support value)))))

(define (ordered-unit calculus [rank 1])
  (unless (exact-positive-integer? rank)
    (raise-argument-error 'ordered-unit "exact-positive-integer?" rank))
  (ordered-pure-tensor
   calculus (for/vector ([slot (in-range rank)])
              (empty-ordered-forest calculus))))

(define (ordered-pure-tensor calculus key [coefficient 1])
  (unless (vector? key)
    (raise-argument-error 'ordered-pure-tensor "vector?" key))
  (make-ordered-sum calculus (vector-length key)
                    (list (cons key coefficient))))

(define (ordered-forest-basis forest)
  (check-forest 'ordered-forest-basis forest)
  (ordered-pure-tensor (ordered-forest-calculus forest) (vector forest)))

(define (ordered-node-basis node)
  (unless (checked-node? node)
    (raise-argument-error 'ordered-node-basis "checked-node?" node))
  (ordered-forest-basis
   (make-ordered-forest (checked-node-calculus node) (list node))))

(define (ordered-sum-terms sum)
  (check-sum 'ordered-sum-terms sum)
  (for/list ([(key coefficient) (in-hash (ordered-sum-support sum))])
    (cons key coefficient)))

(define (ordered-sum-support-size sum)
  (check-sum 'ordered-sum-support-size sum)
  (hash-count (ordered-sum-support sum)))

(define (ordered-sum-coefficient sum key)
  (check-sum 'ordered-sum-coefficient sum)
  (hash-ref (ordered-sum-support sum)
            (checked-key 'ordered-sum-coefficient
                         (ordered-sum-calculus sum)
                         (ordered-sum-rank sum) key)
            0))

(define (check-compatible who left right #:same-rank? [same-rank? #t])
  (check-sum who left)
  (check-sum who right)
  (check-exact-calculus who (ordered-sum-calculus left)
                       (ordered-sum-calculus right))
  (when same-rank? (check-rank who right (ordered-sum-rank left))))

(define (ordered-sum-add left right)
  (check-compatible 'ordered-sum-add left right)
  (make-ordered-sum
   (ordered-sum-calculus left) (ordered-sum-rank left)
   (append (ordered-sum-terms left) (ordered-sum-terms right))))

(define (ordered-sum-scale coefficient sum)
  (unless (exact-integer? coefficient)
    (raise-argument-error 'ordered-sum-scale "exact-integer?" coefficient))
  (check-sum 'ordered-sum-scale sum)
  (make-ordered-sum
   (ordered-sum-calculus sum) (ordered-sum-rank sum)
   (for/list ([term (in-list (ordered-sum-terms sum))])
     (cons (car term) (* coefficient (cdr term))))))

(define (ordered-sum-negate sum) (ordered-sum-scale -1 sum))
(define (ordered-sum-subtract left right)
  (ordered-sum-add left (ordered-sum-negate right)))

(define (ordered-sum-multiply left right)
  (check-compatible 'ordered-sum-multiply left right)
  (make-ordered-sum
   (ordered-sum-calculus left) (ordered-sum-rank left)
   (for*/list ([a (in-list (ordered-sum-terms left))]
               [b (in-list (ordered-sum-terms right))])
     (cons (for/vector ([x (in-vector (car a))]
                        [y (in-vector (car b))])
             (ordered-forest-concatenate x y))
           (* (cdr a) (cdr b))))))

(define (ordered-sum-tensor left right)
  (check-compatible 'ordered-sum-tensor left right #:same-rank? #f)
  (make-ordered-sum
   (ordered-sum-calculus left)
   (+ (ordered-sum-rank left) (ordered-sum-rank right))
   (for*/list ([a (in-list (ordered-sum-terms left))]
               [b (in-list (ordered-sum-terms right))])
     (cons (vector-append (car a) (car b)) (* (cdr a) (cdr b))))))

;; Expand exactly one 1-indexed tensor coordinate. The callback returns an
;; ordered sum of the declared rank, even for input or output additive zero.
(define (ordered-sum-expand-coordinate sum slot operation
                                       #:result-rank [result-rank 2])
  (check-sum 'ordered-sum-expand-coordinate sum)
  (unless (and (exact-positive-integer? slot)
               (<= slot (ordered-sum-rank sum)))
    (raise-arguments-error 'ordered-sum-expand-coordinate
                           "slot must name an existing 1-based coordinate"
                           "slot" slot "rank" (ordered-sum-rank sum)))
  (unless (procedure? operation)
    (raise-argument-error 'ordered-sum-expand-coordinate "procedure?" operation))
  (unless (exact-positive-integer? result-rank)
    (raise-argument-error 'ordered-sum-expand-coordinate
                          "exact-positive-integer?" result-rank))
  (define calculus (ordered-sum-calculus sum))
  (define index (sub1 slot))
  (make-ordered-sum
   calculus (+ (sub1 (ordered-sum-rank sum)) result-rank)
   (append-map
    (lambda (term)
      (define key (car term))
      (define expanded (operation (vector-ref key index)))
      (check-rank 'ordered-sum-expand-coordinate expanded result-rank)
      (check-exact-calculus 'ordered-sum-expand-coordinate calculus
                           (ordered-sum-calculus expanded))
      (for/list ([piece (in-list (ordered-sum-terms expanded))])
        (cons (vector-append (vector-copy key 0 index)
                             (car piece)
                             (vector-copy key (add1 index)))
              (* (cdr term) (cdr piece)))))
    (ordered-sum-terms sum))))

(define (ordered-tensor-multiply sum)
  (check-rank 'ordered-tensor-multiply sum 2)
  (make-ordered-sum
   (ordered-sum-calculus sum) 1
   (for/list ([term (in-list (ordered-sum-terms sum))])
     (cons (vector (ordered-forest-concatenate
                    (vector-ref (car term) 0) (vector-ref (car term) 1)))
           (cdr term)))))

;; PAPER CONSTRUCTOR RECURRENCE / TWO-WAY NATIVE WITNESS BIJECTION.
;; For r(t_1,...,t_n), a below-root cut is exactly one independent choice in
;; each ORDERED positive child: empty, proper, or whole-child. Prefix its
;; proper addresses by that child's slot; a whole-child choice selects the
;; existing child root at (slot), not this tree's root. A vacant child instead
;; has one identity choice and no vertex/cut. Concatenate detached child words
;; in slot order. Graft the native remainders in the same slots, converting a
;; child whole endpoint into the parent's typed Box. This is inverse to
;; restricting each native prefix-free cut to its first address component.
;; Thus Delta(r(...)) = r(...) tensor 1 plus this below-root sum. In particular
;; Box is never a forest factor, and the global whole term has NO cut witness.
;; The executable definition below consumes the native witness tuple directly;
;; no commutative collected forest is used to reconstruct an ordered word.
;;
;; PAPER COASSOCIATIVITY (INCLUDING TYPED VACANCIES).
;; Uncollected triples on either side correspond bijectively to assignments
;; of each existing vertex to strata 1,2,3, weakly nonincreasing from root to
;; leaves. Each stratum's connected components retain the original typed slots
;; and have vacancies at transitions. Empty strata use the empty forest; root
;; in stratum 1 or 2 is handled by the separate whole endpoints, not root cuts.
;; (Delta tensor id) first separates 3 from 1+2, then 1 from 2 componentwise;
;; (id tensor Delta) first separates 1 from 2+3, then 2 from 3. Original factor
;; index followed by native address lexicographic order orders every stratum.
;; Outer components occupy contiguous address intervals, so concatenating
;; their inner words gives exactly the same order, not a permutation/shuffle.
;; Existing holes are never vertices and stay attached to their retained
;; original parent slot. Reversing either separation uniquely recovers the
;; flag by native filling. The correspondence preserves multiplicity before
;; collection. Therefore coassociativity holds for arbitrary checked trees,
;; including open ones. Finite tests below are NOT the proof of this claim.
;;
;; Delta on words is multiplicative in concatenation order by definition;
;; epsilon kills every nonempty word. The grading is native vertex count:
;; cuts partition vertices, so Delta preserves degree; degree zero consists
;; only of the empty word. Consequently this is a connected graded bialgebra.
(define (ordered-connected-coproduct term)
  (unless (checked-node? term)
    (raise-argument-error 'ordered-connected-coproduct "checked-node?" term))
  (define calculus (checked-node-calculus term))
  (define whole (make-ordered-forest calculus (list term)))
  (define unit (empty-ordered-forest calculus))
  (for/fold ([result (ordered-pure-tensor calculus (vector whole unit))])
            ([witness (in-admissible-cut-witnesses term)])
    (unless (cut-witness? witness)
      (error 'ordered-connected-coproduct
             "native admissible-cut enumerator produced invalid evidence: ~e"
             witness))
    (ordered-sum-add
     result
     (ordered-pure-tensor
      calculus
      (vector (ordered-cut-forest witness)
              (make-ordered-forest
               calculus (list (cut-witness-remainder witness))))))))

(define (ordered-forest-coproduct forest)
  (check-forest 'ordered-forest-coproduct forest)
  (for/fold ([result (ordered-unit (ordered-forest-calculus forest) 2)])
            ([factor (in-list (ordered-forest-factors forest))])
    (ordered-sum-multiply result (ordered-connected-coproduct factor))))

(define (ordered-coproduct sum)
  (check-rank 'ordered-coproduct sum 1)
  (ordered-sum-expand-coordinate sum 1 ordered-forest-coproduct))

(define (ordered-forest-counit forest)
  (if (ordered-forest-empty? forest) 1 0))

(define (ordered-counit sum)
  (check-rank 'ordered-counit sum 1)
  (for/sum ([term (in-list (ordered-sum-terms sum))])
    (* (cdr term) (ordered-forest-counit (vector-ref (car term) 0)))))

(define (tensor-counit sum index who)
  (check-rank who sum 2)
  (make-ordered-sum
   (ordered-sum-calculus sum) 1
   (for/list ([term (in-list (ordered-sum-terms sum))])
     (cons (vector (vector-ref (car term) (- 1 index)))
           (* (cdr term)
              (ordered-forest-counit (vector-ref (car term) index)))))))

(define (ordered-tensor-counit-left sum)
  (tensor-counit sum 0 'ordered-tensor-counit-left))
(define (ordered-tensor-counit-right sum)
  (tensor-counit sum 1 'ordered-tensor-counit-right))

;; PAPER ANTIPODE: connected grading makes every proper nonempty cut's left
;; and right degrees strictly smaller. S(t)=-t-sum S(P_c) R_c, with the unit
;; fixed. On words S(t_1...t_n)=S(t_n)...S(t_1); factor reversal is essential
;; and must not be replaced by commutative multiplication. Connected graded
;; bialgebra recursion proves BOTH convolution identities and uniqueness.
;; This is an algebraic signed sum, not an inverse derivation or repair.
(define (forest-antipode/internal forest memo)
  (define calculus (ordered-forest-calculus forest))
  (cond
    [(hash-ref memo forest #f) => values]
    [else
     (define result
       (for/fold ([value (ordered-unit calculus)])
                 ([node (in-list (reverse (ordered-forest-factors forest)))])
         (ordered-sum-multiply value (node-antipode/internal node memo))))
     (hash-set! memo forest result)
     result]))

(define (node-antipode/internal node memo)
  (define calculus (checked-node-calculus node))
  (define forest (make-ordered-forest calculus (list node)))
  (cond
    [(hash-ref memo forest #f) => values]
    [else
     (define result
       (for/fold ([value (ordered-sum-negate (ordered-forest-basis forest))])
                 ([witness (in-admissible-cut-witnesses node)]
                  #:unless (null? (cut-witness-addresses witness)))
         (define left (ordered-cut-forest witness))
         (define right
           (make-ordered-forest calculus (list (cut-witness-remainder witness))))
         (unless (and (< 0 (ordered-forest-degree left)
                          (ordered-forest-degree forest))
                      (< 0 (ordered-forest-degree right)
                          (ordered-forest-degree forest)))
           (error 'ordered-antipode "native proper cut failed degree decrease"))
         (ordered-sum-subtract
          value (ordered-sum-multiply
                 (forest-antipode/internal left memo)
                 (ordered-forest-basis right)))))
     (hash-set! memo forest result)
     result]))

(define (ordered-forest-antipode forest)
  (check-forest 'ordered-forest-antipode forest)
  (forest-antipode/internal forest (make-hash)))

(define (ordered-antipode sum)
  (check-rank 'ordered-antipode sum 1)
  (define memo (make-hash))
  (ordered-sum-expand-coordinate
   sum 1 (lambda (forest) (forest-antipode/internal forest memo))
   #:result-rank 1))

(define (antipode-convolution sum slot)
  (check-rank 'ordered-antipode-convolution sum 1)
  (ordered-tensor-multiply
   (ordered-sum-expand-coordinate
    (ordered-coproduct sum) slot ordered-forest-antipode #:result-rank 1)))

(define (ordered-antipode-convolution-left sum)
  (antipode-convolution sum 1))
(define (ordered-antipode-convolution-right sum)
  (antipode-convolution sum 2))

;; Projection intentionally forgets word order at this explicit boundary.
;; It is multiplicative. Each uncollected cut has exactly the same native
;; remainder and its detached tuple's native multiset image, so projection
;; intertwines the two coproducts and counits. Antipodes then commute by their
;; uniqueness. This does NOT establish any converse/injective comparison or
;; the word-sensitive orientation-erasure obstruction after projection.
(define (ordered-sum->commutative sum)
  (check-sum 'ordered-sum->commutative sum)
  (comm:make-formal-sum
   (ordered-sum-calculus sum) (ordered-sum-rank sum)
   (for/list ([term (in-list (ordered-sum-terms sum))])
     (cons (for/vector ([forest (in-vector (car term))])
             (ordered-forest->commutative forest))
           (cdr term)))))
