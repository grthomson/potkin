#lang racket/base

(require racket/list
         racket/vector
         rackunit
         "../potkin/kernel.rkt"
         "../potkin/algebra.rkt"
         "../potkin/hopf.rkt"
         "../potkin/analysis.rkt"
         "revision-fixtures.rkt"
         "hopf-fixtures.rkt")

(define A (premise-ancestry-of t))
(check-true (premise-ancestry? A))
(check-equal? (ancestry-vertices A) '(() (1) (1 1) (1 2)))
(check-equal?
 (ancestry-cover-edges A)
 '(((1) ()) ((1 1) (1)) ((1 2) (1))))
(check-true (ancestry<=? A '(1 1) '()))
(check-true (ancestry<=? A '(1 1) '(1)))
(check-false (ancestry<=? A '(1) '(1 1)))
(check-false (ancestry<=? A '(2) '()))

(define (sequence-values value)
  (check-false (analysis-limit? value))
  (check-false (analysis-error? value))
  (for/list ([item value]) item))

(define running-ideals (sequence-values (in-ancestry-ideals A)))
(check-equal?
 running-ideals
 '(()
   ((1) (1 1) (1 2))
   ((1 1))
   ((1 2))
   ((1 1) (1 2))
   (() (1) (1 1) (1 2))))
(check-equal? (length running-ideals) 6)

(define running-choices
  (append
   (list (empty-cut-choice))
   (for/list ([cut (in-admissible-cuts t)] #:when (pair? cut))
     (proper-cut-choice (reverse cut)))
   (list (whole-cut-choice))))
(for ([choice (in-list running-choices)])
  (define ideal (cut-choice->ideal A choice))
  (check-true (ancestry-ideal? A ideal))
  (check-equal? (ancestry-ideal->cut-choice A ideal) choice))
(for ([ideal (in-list running-ideals)])
  (check-equal?
   (cut-choice->ideal A (ancestry-ideal->cut-choice A ideal))
   ideal))
(check-true
 (analysis-error?
  (cut-choice->ideal A (proper-cut-choice '((2))))))
(check-true
 (analysis-error? (ancestry-ideal->cut-choice A '((1)))))

(define running-polynomial (cut-size-polynomial A))
(check-equal? running-polynomial '#(0 3 1))
(check-equal? (cut-size-polynomial-evaluate running-polynomial 2) 10)
(check-equal? (nonroot-ancestry-width A) 2)

;; Independent brute-force downward-ideal oracle.  It uses only source vertex
;; addresses and prefix order, not production ideal conversion or checking.
(define (brute-ideals term)
  (define vertices (sort (vertex-addresses term) address<?))
  (for/list ([mask (in-range (expt 2 (length vertices)))]
             #:do
             [(define subset
                (for/list ([vertex (in-list vertices)]
                           [bit (in-naturals)]
                           #:when (bitwise-bit-set? mask bit))
                  vertex))]
             #:when
             (for*/and ([ancestor (in-list subset)]
                        [descendant (in-list vertices)]
                        #:when (address-prefix? ancestor descendant))
               (member descendant subset equal?)))
    subset))

(define (same-address-sets? left right)
  (and (= (length left) (length right))
       (andmap (lambda (item) (member item right equal?)) left)
       (andmap (lambda (item) (member item left equal?)) right)
       #t))

;; Degree at most three keeps the independent powerset oracle genuinely small
;; while covering nullary, unary, binary, complete, and punctured sources.
(for* ([degree (in-range 1 4)]
       [term (in-list (hopf-terms-of-degree degree))])
  (define ancestry (premise-ancestry-of term))
  (define actual (sequence-values (in-ancestry-ideals ancestry)))
  (define expected (brute-ideals term))
  (check-true (same-address-sets? actual expected))
  (for ([ideal (in-list actual)])
    (define choice (ancestry-ideal->cut-choice ancestry ideal))
    (check-equal? (cut-choice->ideal ancestry choice) ideal))
  (define cuts (for/list ([cut (in-admissible-cuts term)]) cut))
  (define brute-coefficients
    (make-vector
     (max 1 (add1 (for/fold ([maximum 0]) ([cut (in-list cuts)])
                    (max maximum (length cut)))))
     0))
  (for ([cut (in-list cuts)] #:when (pair? cut))
    (vector-set! brute-coefficients
                 (length cut)
                 (add1 (vector-ref brute-coefficients (length cut)))))
  (check-equal?
   (cut-size-polynomial ancestry)
   (let loop ([length (vector-length brute-coefficients)])
     (if (and (> length 1)
              (zero? (vector-ref brute-coefficients (sub1 length))))
         (loop (sub1 length))
         (vector->immutable-vector
          (vector-copy brute-coefficients 0 length)))))
  (check-equal?
   (nonroot-ancestry-width ancestry)
   (for/fold ([maximum 0]) ([cut (in-list cuts)])
     (max maximum (length cut)))))

(define running-orders
  (sequence-values (in-root-first-refinement-orders A)))
(check-equal?
 running-orders
 '((() (1) (1 1) (1 2))
   (() (1) (1 2) (1 1))))
(for ([order (in-list running-orders)])
  (check-true (refinement-order-reconstructs? A order)))
(check-false
 (refinement-order-reconstructs? A '(() (1 1) (1) (1 2))))

;; Punctured targets leave their historical vacancies unresolved.
(define g
  (validate-candidate hopf-calculus hopf-g-raw #:expected hopf-S))
(define b-g-hole
  (validate-candidate
   hopf-calculus (hopf-b-raw hopf-g-raw raw-hole) #:expected hopf-S))
(define b-g-hole-A (premise-ancestry-of b-g-hole))
(check-equal? (ancestry-vertices b-g-hole-A) '(() (1)))
(check-equal?
 (sequence-values (in-root-first-refinement-orders b-g-hole-A))
 '((() (1))))
(check-true
 (refinement-order-reconstructs? b-g-hole-A '(() (1))))
(check-equal? (puncture-addresses b-g-hole) '((2)))

;; Equal displayed subtrees remain different address occurrences and collect
;; with coefficient two only after tensor coordinates forget those addresses.
(define b-g-g
  (validate-candidate
   hopf-calculus (hopf-b-raw hopf-g-raw hopf-g-raw) #:expected hopf-S))
(define b-g-g-A (premise-ancestry-of b-g-g))
(check-equal? (cut-size-polynomial b-g-g-A) '#(0 2 1))
(check-equal? (nonroot-ancestry-width b-g-g-A) 2)
(check-equal? (linear-extension-count b-g-g-A) 2)
(check-equal?
 (length (sequence-values (in-root-first-refinement-orders b-g-g-A)))
 2)

(check-equal? (weak-order-map-count A 2) 6)
(check-equal? (linear-extension-count A) 2)
(check-equal? (zeta-convolution-power t 2) 6)
(check-equal? (omega-one-convolution-power t 4) 2)

(define t-basis (checked-node-basis t))
(check-equal? (iterated-coproduct t 1) t-basis)
(check-equal? (iterated-coproduct t-basis 1) t-basis)
(check-equal? (iterated-coproduct t 2) (connected-coproduct t))
(define running-delta (connected-coproduct t))
(define running-iterated-3 (iterated-coproduct t 3))
(check-equal? (formal-sum-rank running-iterated-3) 3)
(check-equal?
 running-iterated-3
 (formal-sum-expand-coordinate running-delta 1 2 forest-coproduct))
(for ([entry (in-list (formal-sum-terms running-iterated-3))])
  (check-equal?
   (for/sum ([forest (in-vector (car entry))])
     (forest-degree forest))
   4))
(define one/K0 (empty-proof-forest K0))
(define t-forest (make-proof-forest K0 (list t)))
(check-equal?
 (formal-sum-coefficient
  running-iterated-3 (vector t-forest one/K0 one/K0))
 1)
(check-equal?
 (formal-sum-coefficient
  running-iterated-3 (vector one/K0 t-forest one/K0))
 1)
(check-equal?
 (formal-sum-coefficient
  running-iterated-3 (vector one/K0 one/K0 t-forest))
 1)
(check-true
 (analysis-error?
  (iterated-coproduct (formal-sum-scale 2 t-basis) 2)))
(check-exn exn:fail:contract? (lambda () (iterated-coproduct t 0)))

(define g-forest (make-proof-forest hopf-calculus (list g)))
(define b-hole-hole
  (validate-candidate
   hopf-calculus (hopf-b-raw raw-hole raw-hole) #:expected hopf-S))
(define b-hole-hole-forest
  (make-proof-forest hopf-calculus (list b-hole-hole)))
(define repeated-iterated (iterated-coproduct b-g-g 3))
(check-equal?
 (formal-sum-coefficient
  repeated-iterated
  (vector g-forest g-forest b-hole-hole-forest))
 2)
(check-equal? (omega-one-convolution-power b-g-g 3) 2)

;; The independent DP and the convolution observables agree on a capped
;; sample rather than a Cartesian product of all existing fixtures.
(for* ([term (in-list (take hopf-terms 12))]
       [n (in-range 1 4)])
  (check-equal?
   (zeta-convolution-power term n)
   (weak-order-map-count term n)))
(for ([term (in-list (take hopf-terms 12))])
  (define degree (derivation-vertex-count term))
  (check-equal?
   (omega-one-convolution-power term degree)
   (linear-extension-count term)))

;; Limits are structured, preflighted and distinct from exact zero.
(for ([limited
       (in-list
        (list (in-ancestry-ideals A #:limit 5)
              (cut-size-polynomial A #:limit 3)
              (in-root-first-refinement-orders A #:limit 1)
              (weak-order-map-count A 2 #:limit 5)
              (linear-extension-count A #:limit 1)
              (iterated-coproduct t 2 #:limit 5)
              (zeta-convolution-power t 2 #:limit 5)
              (omega-one-convolution-power t 4 #:limit 5)))])
  (check-true (analysis-limit? limited))
  (check-equal? (analysis-limit-code limited) 'not-computed-limit))
(define state-limited (weak-order-map-count A 2 #:limit 10))
(check-true (analysis-limit? state-limited))
(check-equal? (analysis-limit-metric state-limited)
              'dynamic-program-states)
(check-equal? (analysis-limit-required state-limited) 12)
(check-equal?
 (analysis-limit-operation
  (zeta-convolution-power t 2 #:limit 5))
 'zeta-convolution-power)
(check-equal?
 (analysis-limit-operation
  (omega-one-convolution-power t 4 #:limit 5))
 'omega-one-convolution-power)
(check-equal? (weak-order-map-count A 2 #:limit #f) 6)
