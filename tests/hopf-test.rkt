#lang racket/base

(require racket/list
         rackunit
         "../potkin/kernel.rkt"
         "../potkin/algebra.rkt"
         "../potkin/hopf.rkt"
         "revision-fixtures.rkt"
         "hopf-fixtures.rkt")

(define (key . forests)
  (vector->immutable-vector (list->vector forests)))

(define (singleton-forest term)
  (make-proof-forest (checked-term-calculus term) (list term)))

(define (coefficient-sum sum)
  (for/sum ([term (in-list (formal-sum-terms sum))])
    (cdr term)))

(define (check-hopf-error value code operation)
  (cond
    [(hopf-error? value)
     (check-equal? (hopf-error-code value) code)
     (check-equal? (hopf-error-operation value) operation)
     (check-true (string? (hopf-error-message value)))
     (check-false (string=? (hopf-error-message value) ""))
     (check-true (hash? (hopf-error-details value)))
     (check-true (immutable? (hopf-error-details value)))
     (void (hopf-error-expected value)
           (hopf-error-actual value))]
    [else
     (check-true #f
                 (format "expected Hopf error ~a from ~a, received ~e"
                         code operation value))])
  (void))

(define (check-exact-formal-provenance sum calculus rank)
  (check-true (formal-sum? sum))
  (when (formal-sum? sum)
    (check-true (eq? (formal-sum-calculus sum) calculus))
    (check-equal? (formal-sum-rank sum) rank)
    (for ([support-key (in-list (formal-sum-support sum))])
      (check-true (immutable? support-key))
      (check-equal? (vector-length support-key) rank)
      (for ([forest (in-vector support-key)])
        (check-true (proof-forest? forest))
        (check-true (eq? (proof-forest-calculus forest) calculus))
        (for ([factor (in-list (proof-forest-factors forest))])
          (check-true (checked-node? factor))
          (check-true
           (checked-term-has-exact-calculus? factor calculus)))))))

(define (tensor-polynomial calculus specifications)
  (for/fold ([sum (tensor-zero calculus 2)])
            ([specification (in-list specifications)])
    (define coefficient (first specification))
    (define left (second specification))
    (define right (third specification))
    (formal-sum-add
     sum
     (formal-sum-scale coefficient
                       (pure-tensor calculus (key left right))))))

(define (check-exact-tensor actual calculus specifications)
  (define expected (tensor-polynomial calculus specifications))
  (check-equal? actual expected)
  (check-equal? (formal-sum-support-size actual)
                (length specifications))
  (for ([specification (in-list specifications)])
    (check-equal?
     (formal-sum-coefficient
      actual
      (key (second specification) (third specification)))
     (first specification)))
  (check-exact-formal-provenance actual calculus 2))

(define (support-key-degree support-key)
  (for/sum ([forest (in-vector support-key)])
    (forest-degree forest)))

(define (check-tensor-degree sum degree)
  (for ([term (in-list (formal-sum-terms sum))])
    (check-equal? (support-key-degree (car term)) degree)))

;; Test-local memoization is scoped first by exact calculus identity. It avoids
;; recomputing bounded coproducts without ever conflating structural clones.
(define forest-coproduct-caches (make-hasheq))
(define (cached-forest-coproduct forest)
  (define calculus (proof-forest-calculus forest))
  (define calculus-cache
    (hash-ref! forest-coproduct-caches calculus make-hash))
  (hash-ref! calculus-cache
             forest
             (lambda () (forest-coproduct forest))))

(define (coassociativity-left delta)
  (formal-sum-expand-coordinate
   delta 1 2 cached-forest-coproduct))

(define (coassociativity-right delta)
  (formal-sum-expand-coordinate
   delta 2 2 cached-forest-coproduct))

;; Exact one-colour fixtures for the primitive ground and its unary extension.
(define g
  (validate-candidate hopf-calculus hopf-g-raw #:expected hopf-S))
(define u-g
  (validate-candidate
   hopf-calculus
   (hopf-u-raw hopf-g-raw)
   #:expected hopf-S))
(define u-Box
  (validate-candidate
   hopf-calculus
   (hopf-u-raw raw-hole)
   #:expected hopf-S))
(define one/H (empty-proof-forest hopf-calculus))
(define g-forest (singleton-forest g))
(define u-g-forest (singleton-forest u-g))
(define u-Box-forest (singleton-forest u-Box))

;; Delta(1) = 1 tensor 1, whereas Delta(0) is genuine tensor zero.
(define delta-one (forest-coproduct one/H))
(check-exact-tensor delta-one hopf-calculus
                    (list (list 1 one/H one/H)))
(check-equal? delta-one (tensor-unit hopf-calculus 2))
(check-equal? (coproduct (formal-zero hopf-calculus))
              (tensor-zero hopf-calculus 2))

;; A nullary ground has only the empty CK cut. The second primitive endpoint
;; is algebraic bookkeeping, not a root cut.
(define g-witnesses
  (for/list ([witness (in-admissible-cut-witnesses g)]) witness))
(check-equal? (length g-witnesses) 1)
(check-equal? (cut-witness-addresses (first g-witnesses)) '())
(check-equal? (for/list ([cut (in-admissible-cuts g)]) cut)
              '(()))
(define delta-g (connected-coproduct g))
(check-exact-tensor
 delta-g
 hopf-calculus
 (list (list 1 g-forest one/H)
       (list 1 one/H g-forest)))
(check-equal? delta-g (forest-coproduct g-forest))

;; Delta(u(g)) is ordered and noncocommutative: u(Box) tensor g is absent.
(define delta-u-g (connected-coproduct u-g))
(check-exact-tensor
 delta-u-g
 hopf-calculus
 (list (list 1 u-g-forest one/H)
       (list 1 one/H u-g-forest)
       (list 1 g-forest u-Box-forest)))
(check-equal?
 (formal-sum-coefficient delta-u-g (key u-Box-forest g-forest))
 0)

;; The running proof t = i(m(bS,bT)) has exactly the six collected terms from
;; its five admissible cuts plus the separate whole-tree left endpoint.
(define one/K0 (empty-proof-forest K0))
(define t/K0-forest (singleton-forest t))
(define m-bS-bT (vertex-at-address t '(1)))
(define m-bS-bT-forest (singleton-forest m-bS-bT))
(define i-Box (corolla K0 i-occ))
(define i-Box-forest (singleton-forest i-Box))
(define bS/K0-forest (singleton-forest bS-proof))
(define bT/K0-forest (singleton-forest bT-proof))
(define R-forest (singleton-forest R))
(define i-m-bS-Box
  (validate-candidate
   K0
   (raw-app 'i (raw-app 'm (raw-app 'bS) raw-hole))
   #:expected U))
(define i-m-bS-Box-forest (singleton-forest i-m-bS-Box))
(define i-m-Box-Box
  (validate-candidate
   K0
   (raw-app 'i (raw-app 'm raw-hole raw-hole))
   #:expected U))
(define i-m-Box-Box-forest (singleton-forest i-m-Box-Box))
(define bS+bT-forest
  (make-proof-forest K0 (list bS-proof bT-proof)))

(define delta-t (connected-coproduct t))
(check-exact-tensor
 delta-t
 K0
 (list (list 1 t/K0-forest one/K0)
       (list 1 one/K0 t/K0-forest)
       (list 1 m-bS-bT-forest i-Box-forest)
       (list 1 bS/K0-forest R-forest)
       (list 1 bT/K0-forest i-m-bS-Box-forest)
       (list 1 bS+bT-forest i-m-Box-Box-forest)))
(check-equal? (coefficient-sum delta-t) 6)

;; Forest multiplicativity retains repeated factor occurrences, yielding the
;; binomial coefficients for g^2 and g^3.
(define g2-forest (make-proof-forest hopf-calculus (list g g)))
(define g3-forest (make-proof-forest hopf-calculus (list g g g)))
(define delta-g2 (forest-coproduct g2-forest))
(define delta-g3 (forest-coproduct g3-forest))
(check-exact-tensor
 delta-g2
 hopf-calculus
 (list (list 1 g2-forest one/H)
       (list 2 g-forest g-forest)
       (list 1 one/H g2-forest)))
(check-exact-tensor
 delta-g3
 hopf-calculus
 (list (list 1 g3-forest one/H)
       (list 3 g2-forest g-forest)
       (list 3 g-forest g2-forest)
       (list 1 one/H g3-forest)))
(check-equal? (proof-forest-count g3-forest g) 3)

;; A punctured input remains in the carrier. Cutting above its old S-hole can
;; detach the punctured subtree m(Box,bT); the hole itself is never a factor.
(define m-Box-bT (vertex-at-address R '(1)))
(define m-Box-bT-forest (singleton-forest m-Box-bT))
(define delta-R (connected-coproduct R))
(check-true (proof-context? m-Box-bT))
(check-exact-tensor
 delta-R
 K0
 (list (list 1 R-forest one/K0)
       (list 1 one/K0 R-forest)
       (list 1 m-Box-bT-forest i-Box-forest)
       (list 1 bT/K0-forest i-m-Box-Box-forest)))

;; Linear extension respects positive and negative coefficients.
(define linear-x
  (formal-sum-add
   (formal-sum-scale 7 (algebra-unit hopf-calculus))
   (formal-sum-add (formal-sum-scale 2 (checked-node-basis g))
                   (formal-sum-scale -3 (checked-node-basis u-g)))))
(define linear-y
  (formal-sum-subtract (checked-node-basis u-g)
                       (checked-node-basis g)))
(check-equal?
 (coproduct linear-x)
 (formal-sum-add
  (formal-sum-scale 7 delta-one)
  (formal-sum-add (formal-sum-scale 2 delta-g)
                  (formal-sum-scale -3 delta-u-g))))
(check-equal?
 (coproduct (formal-sum-add linear-x linear-y))
 (formal-sum-add (coproduct linear-x) (coproduct linear-y)))
(check-equal?
 (coproduct (formal-sum-scale -5 linear-y))
 (formal-sum-scale -5 (coproduct linear-y)))
(check-equal?
 (coproduct (formal-sum-multiply linear-x linear-y))
 (formal-sum-multiply (coproduct linear-x) (coproduct linear-y)))
(check-equal?
 (counit (formal-sum-multiply linear-x linear-y))
 (* (counit linear-x) (counit linear-y)))

;; Counit is the empty-forest coefficient, is multiplicative, and contracts
;; either ordered tensor coordinate back to the original rank-one value.
(check-equal? (forest-counit one/H) 1)
(check-equal? (forest-counit g-forest) 0)
(check-equal? (counit (algebra-unit hopf-calculus)) 1)
(check-equal? (counit (checked-node-basis g)) 0)
(check-equal? (counit linear-x) 7)
(check-equal? (tensor-counit-left (coproduct linear-x)) linear-x)
(check-equal? (tensor-counit-right (coproduct linear-x)) linear-x)
(check-equal? (tensor-counit-left (tensor-zero hopf-calculus 2))
              (formal-zero hopf-calculus))
(check-equal? (tensor-counit-right (tensor-zero hopf-calculus 2))
              (formal-zero hopf-calculus))

;; Vertex grading counts every forest-factor occurrence; holes contribute no
;; separate degree, but their positive rooted context still does.
(check-equal? (forest-degree one/H) 0)
(check-equal? (forest-degree g-forest) 1)
(check-equal? (forest-degree g2-forest) 2)
(check-equal? (forest-degree g3-forest) 3)
(check-equal? (forest-degree (singleton-forest u-Box)) 1)
(check-equal? (formal-sum-support-degrees (formal-zero hopf-calculus)) '())
(check-equal? (formal-sum-support-degrees linear-x) '(0 1 2))
(check-equal? (formal-sum-homogeneous-degree
               (algebra-unit hopf-calculus))
              0)
(check-equal? (formal-sum-homogeneous-degree (checked-node-basis u-g))
              2)
(check-tensor-degree delta-one 0)
(check-tensor-degree delta-g 1)
(check-tensor-degree delta-u-g 2)
(check-tensor-degree delta-t 4)
(check-tensor-degree delta-R 3)
(check-tensor-degree delta-g2 2)
(check-tensor-degree delta-g3 3)

;; Coassociativity is exact ordered rank-three equality computed by expanding
;; each tensor coordinate with the same forest coproduct.
(check-equal? (coassociativity-left delta-one)
              (coassociativity-right delta-one))
(check-equal? (coassociativity-left delta-g)
              (coassociativity-right delta-g))
(check-equal? (coassociativity-left delta-u-g)
              (coassociativity-right delta-u-g))
(check-equal? (coassociativity-left delta-t)
              (coassociativity-right delta-t))
(check-equal? (coassociativity-left delta-R)
              (coassociativity-right delta-R))
(check-equal? (coassociativity-left delta-g3)
              (coassociativity-right delta-g3))

;; Stable Hopf-domain errors are distinct from formal zero and from the lower
;; algebra layer's structured errors.
(define coproduct-rank-error (coproduct (tensor-zero hopf-calculus 2)))
(check-hopf-error coproduct-rank-error 'rank-mismatch 'coproduct)
(check-equal? (hopf-error-expected coproduct-rank-error) 1)
(check-equal? (hopf-error-actual coproduct-rank-error) 2)
(check-hopf-error (counit (tensor-zero hopf-calculus 2))
                  'rank-mismatch
                  'counit)
(check-hopf-error (tensor-counit-left (formal-zero hopf-calculus))
                  'rank-mismatch
                  'tensor-counit-left)
(check-hopf-error (tensor-counit-right (formal-zero hopf-calculus))
                  'rank-mismatch
                  'tensor-counit-right)
(check-hopf-error
 (formal-sum-support-degrees (tensor-zero hopf-calculus 2))
 'rank-mismatch
 'formal-sum-support-degrees)
(check-hopf-error
 (formal-sum-homogeneous-degree (tensor-zero hopf-calculus 2))
 'rank-mismatch
 'formal-sum-homogeneous-degree)

(define empty-degree-error
  (formal-sum-homogeneous-degree (formal-zero hopf-calculus)))
(check-hopf-error empty-degree-error
                  'empty-support
                  'formal-sum-homogeneous-degree)
(check-equal? (hopf-error-expected empty-degree-error) 'nonempty-support)
(check-equal? (hopf-error-actual empty-degree-error) '())
(define nonhomogeneous-error
  (formal-sum-homogeneous-degree linear-x))
(check-hopf-error nonhomogeneous-error
                  'nonhomogeneous
                  'formal-sum-homogeneous-degree)
(check-equal? (hopf-error-expected nonhomogeneous-error) 'single-degree)
(check-equal? (hopf-error-actual nonhomogeneous-error) '(0 1 2))

;; Bounded oracle cardinalities are part of the fixture contract.
(check-equal? hopf-term-counts '(3 9 36 162))
(check-equal? (length hopf-terms) 210)
(check-equal? (length hopf-complete-terms) 8)
(check-equal? (length hopf-punctured-terms) 202)
(check-equal? hopf-forest-counts '(1 3 15 73))
(check-equal? (length hopf-forests) 92)
(check-equal? (length hopf-ordered-forest-pairs) 282)

;; Every bounded connected root is CK-closed. Its witnesses reconstruct, its
;; remainders retain a positive root vertex, and collected coefficients retain
;; the endpoint-plus-witness multiplicity and total degree.
(for ([term (in-list hopf-terms)])
  (define degree (derivation-vertex-count term))
  (define forest (singleton-forest term))
  (define connected-delta (connected-coproduct term))
  (define forest-delta (cached-forest-coproduct forest))
  (define witnesses
    (for/list ([witness (in-admissible-cut-witnesses term)]) witness))

  (check-equal? connected-delta forest-delta)
  (check-exact-formal-provenance connected-delta hopf-calculus 2)
  (check-equal? (coefficient-sum connected-delta)
                (add1 (length witnesses)))
  (check-tensor-degree connected-delta degree)
  (check-equal? (tensor-counit-left connected-delta)
                (forest-basis forest))
  (check-equal? (tensor-counit-right connected-delta)
                (forest-basis forest))
  (check-equal? (coassociativity-left connected-delta)
                (coassociativity-right connected-delta))

  (for ([witness (in-list witnesses)])
    (define remainder (cut-witness-remainder witness))
    (define remainder-forest (singleton-forest remainder))
    (check-true (cut-witness-reconstructs? witness))
    (check-true (checked-node? remainder))
    (check-true (positive? (derivation-vertex-count remainder)))
    (check-true
     (checked-term-has-exact-calculus? remainder hopf-calculus))
    (check-true
     (eq? (proof-forest-calculus (cut-witness-forest witness))
          hopf-calculus))
    (check-false (member '() (cut-witness-addresses witness) equal?))
    (check-true
     (positive?
      (formal-sum-coefficient
       connected-delta
       (key (cut-witness-forest witness) remainder-forest))))))

;; All bounded forest monomials satisfy closure, positivity of basis
;; coefficients, grading, both counit laws, and exact coassociativity.
(for ([forest (in-list hopf-forests)])
  (define degree (forest-degree forest))
  (define basis (forest-basis forest))
  (define delta (cached-forest-coproduct forest))
  (check-equal? degree (hopf-forest-degree forest))
  (check-exact-formal-provenance delta hopf-calculus 2)
  (for ([term (in-list (formal-sum-terms delta))])
    (check-true (positive? (cdr term))))
  (check-tensor-degree delta degree)
  (check-equal? (forest-counit forest)
                (if (proof-forest-empty? forest) 1 0))
  (check-equal? (counit basis) (forest-counit forest))
  (check-equal? (tensor-counit-left delta) basis)
  (check-equal? (tensor-counit-right delta) basis)
  (check-equal? (coassociativity-left delta)
                (coassociativity-right delta))
  (check-equal? (formal-sum-support-degrees basis) (list degree))
  (check-equal? (formal-sum-homogeneous-degree basis) degree))

;; Multiplicativity, epsilon multiplicativity, and degree additivity hold for
;; every bounded ordered forest pair whose product remains within degree 3.
(for ([pair (in-list hopf-ordered-forest-pairs)])
  (define left (first pair))
  (define right (second pair))
  (define product (forest-union left right))
  (check-equal?
   (cached-forest-coproduct product)
   (formal-sum-multiply (cached-forest-coproduct left)
                        (cached-forest-coproduct right)))
  (check-equal? (forest-counit product)
                (* (forest-counit left) (forest-counit right)))
  (check-equal? (forest-degree product)
                (+ (forest-degree left) (forest-degree right))))
