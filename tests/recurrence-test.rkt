#lang racket/base

(require racket/list
         racket/vector
         rackunit
         "../potkin/kernel.rkt"
         "../potkin/algebra.rkt"
         "../potkin/hopf.rkt"
         "../potkin/analysis/ancestry.rkt"
         "../potkin/analysis/component-trace.rkt"
         "../potkin/analysis/recurrence.rkt"
         "recurrence-fixtures.rkt")

(define rho
  (make-boundary-return-character return-calculus return-boundary))
(define rho/clone
  (make-boundary-return-character return-calculus/clone return-boundary))

(define (singleton-forest term)
  (make-proof-forest (checked-term-calculus term) (list term)))

(define (forest-raws forest)
  (map checked-term->raw (proof-forest-factors forest)))

(define (certificate-row certificate)
  (map return-power-certificate-actual-value
       (first-return-certificate-power-certificates certificate)))

(define (check-power-certificate certificate)
  (check-true (return-power-certificate? certificate))
  (check-true
   (return-power-certificate-uncollected-iterated-equal? certificate))
  (check-equal?
   (return-power-certificate-uncollected-iterated-sum certificate)
   (return-power-certificate-actual-iterated-coproduct certificate))
  (check-true
   (return-power-certificate-occurrence-projection-equal? certificate))
  (check-true (return-power-certificate-projection-equal? certificate))
  (check-true (return-power-certificate-scalar-equal? certificate))
  (check-true (return-power-certificate-witness-count-equal? certificate))
  (check-true
   (return-power-certificate-witness-bijection-holds? certificate)))

(define (check-analysis-scalar-zero analysis)
  (define scalar
    (component-recurrence-analysis-scalar-analysis analysis))
  (check-equal?
   (component-scalar-analysis-proof-factor-total scalar) 0)
  (check-equal?
   (component-scalar-analysis-proof-factor-expected scalar) 0)
  (check-true
   (component-scalar-analysis-proof-factor-euler-holds? scalar))
  (check-equal?
   (component-scalar-analysis-hypersequent-total scalar) 0)
  (check-equal?
   (component-scalar-analysis-hypersequent-expected scalar) 0)
  (check-true
   (component-scalar-analysis-hypersequent-euler-holds? scalar))
  (check-true
   (component-recurrence-analysis-scalar-calibrated? analysis))
  (check-equal?
   (component-recurrence-analysis-local-scalar-distribution analysis)
   '((() 0 0))))

;; The boundary-return map is a character on commutative proof forests.  Its
;; unit value is one; the reduced character alone kills the algebra unit.
(check-true (boundary-return-character? rho))
(check-eq? (boundary-return-character-calculus rho) return-calculus)
(check-equal? (boundary-return-character-boundary rho) return-boundary)
(check-false (equal? rho rho/clone))
(check-true (boundary-return-context? rho return-C))
(check-true (boundary-return-context? rho return-C2))
(check-true (boundary-return-context? rho return-C3))
(check-true (boundary-return-context? rho return-branching-context))
(check-false (boundary-return-context? rho return-Box))
(check-false (boundary-return-context? rho return-g))
(check-false (boundary-return-context? rho return-C/clone))

(define return-unit (empty-proof-forest return-calculus))
(define C-forest (singleton-forest return-C))
(define C2-forest (singleton-forest return-C2))
(define g-forest (singleton-forest return-g))
(define C*C2-forest (forest-union C-forest C2-forest))
(define C*g-forest (forest-union C-forest g-forest))
(check-equal? (boundary-return-forest-value rho return-unit) 1)
(check-equal? (reduced-boundary-return-forest-value rho return-unit) 0)
(check-equal? (boundary-return-forest-value rho C-forest) 1)
(check-equal? (boundary-return-forest-value rho C2-forest) 1)
(check-equal? (boundary-return-forest-value rho g-forest) 0)
(check-equal?
 (boundary-return-forest-value rho C*C2-forest)
 (* (boundary-return-forest-value rho C-forest)
    (boundary-return-forest-value rho C2-forest)))
(check-equal?
 (boundary-return-forest-value rho C*g-forest)
 (* (boundary-return-forest-value rho C-forest)
    (boundary-return-forest-value rho g-forest)))
(check-equal? (boundary-return-evaluate rho (algebra-unit return-calculus)) 1)
(check-equal?
 (reduced-boundary-return-evaluate rho (algebra-unit return-calculus)) 0)
(check-equal? (boundary-return-evaluate rho (checked-node-basis return-C)) 1)

;; Structural clones do not establish common operational provenance.
(check-exn
 exn:fail:contract?
 (lambda ()
   (boundary-return-forest-value rho (singleton-forest return-C/clone))))
(check-exn
 exn:fail:contract?
 (lambda ()
   (boundary-return-evaluate rho (checked-node-basis return-C/clone))))

;; Recursive constructor decomposition follows the unique puncture child and
;; its inverse retains ordered off-spine children rather than a forest alone.
(define C3-spine (return-spine-decomposition-of rho return-C3))
(check-true (return-spine-decomposition? C3-spine))
(check-eq? (return-spine-decomposition-character C3-spine) rho)
(check-eq? (return-spine-decomposition-source C3-spine) return-C3)
(check-equal? (return-spine-decomposition-puncture C3-spine) '(1 1 1))
(check-equal? (map return-spine-frame-address
                   (return-spine-decomposition-frames C3-spine))
              '(() (1) (1 1)))
(check-equal? (map return-spine-frame-selected-slot
                   (return-spine-decomposition-frames C3-spine))
              '(1 1 1))
(check-equal? (map return-spine-frame-return?
                   (return-spine-decomposition-frames C3-spine))
              '(#f #t #t))
(check-equal? (return-spine-decomposition-proper-return-addresses C3-spine)
              '((1) (1 1)))
(check-equal? (proper-boundary-return-addresses rho return-C3)
              '((1) (1 1)))
(check-equal? (return-spine-decomposition-reconstructed C3-spine) return-C3)
(check-true (return-spine-decomposition-reconstructs? C3-spine))
(check-eq?
 (checked-term-calculus
  (return-spine-decomposition-reconstructed C3-spine))
 return-calculus)

(define branching-spine
  (return-spine-decomposition-of rho return-branching-context))
(define branching-frames
  (return-spine-decomposition-frames branching-spine))
(check-equal? (map return-spine-frame-address branching-frames) '(() (1)))
(check-equal? (map return-spine-frame-selected-slot branching-frames) '(1 1))
(check-equal? (map return-spine-frame-return? branching-frames) '(#f #t))
(check-equal? (map car
                   (return-spine-frame-off-spine-children
                    (first branching-frames)))
              '(2))
(check-eq? (cdr (first
                 (return-spine-frame-off-spine-children
                  (first branching-frames))))
           (vertex-at-address return-branching-context '(2)))
(check-equal? (return-spine-decomposition-reconstructed branching-spine)
              return-branching-context)
(check-true (return-spine-decomposition-reconstructs? branching-spine))

;; These are actual uncollected rightmost CK witnesses.  Endpoint, off-spine,
;; and multicut occurrences remain visible even though the reduced character
;; annihilates them before collection.
(define branching-witnesses
  (iterated-return-witnesses
   rho return-branching-context 2 #:limit #f))
(check-equal? (length branching-witnesses) 5)
(check-equal?
 (map (lambda (witness)
        (map return-expansion-step-kind
             (return-iterated-witness-steps witness)))
      branching-witnesses)
 '((whole) (empty) (proper) (proper) (proper)))
(check-equal?
 (map (lambda (witness)
        (return-expansion-step-addresses
         (car (return-iterated-witness-steps witness))))
      branching-witnesses)
 '(() () ((1)) ((2)) ((1) (2))))
(check-equal? (map return-iterated-witness-coordinate-values
                   branching-witnesses)
              '((1 0) (0 1) (1 1) (0 0) (0 0)))
(check-equal? (map return-iterated-witness-survives? branching-witnesses)
              '(#f #f #t #f #f))
(check-equal?
 (map return-iterated-witness-reverse-chain-addresses branching-witnesses)
 '(#f #f ((1)) #f #f))

(define whole-witness (first branching-witnesses))
(define empty-witness (second branching-witnesses))
(define recursive-witness (third branching-witnesses))
(define off-spine-witness (fourth branching-witnesses))
(define multicut-witness (fifth branching-witnesses))
(check-false
 (return-expansion-step-cut-witness
  (car (return-iterated-witness-steps whole-witness))))
(check-true
 (cut-witness?
  (return-expansion-step-cut-witness
   (car (return-iterated-witness-steps empty-witness)))))
(check-equal?
 (cut-witness-addresses
  (return-expansion-step-cut-witness
   (car (return-iterated-witness-steps empty-witness))))
 '())
(check-true (return-iterated-witness-survives? recursive-witness))
(check-equal? (return-iterated-witness-reverse-chain-addresses
               recursive-witness)
              '((1)))
(check-false (return-iterated-witness-survives? off-spine-witness))
(check-equal?
 (return-expansion-step-addresses
  (car (return-iterated-witness-steps off-spine-witness)))
 '((2)))
(check-false (return-iterated-witness-survives? multicut-witness))
(check-equal?
 (return-expansion-step-addresses
  (car (return-iterated-witness-steps multicut-witness)))
 '((1) (2)))
(define multicut-left
  (first (return-iterated-witness-coordinate-forests multicut-witness)))
(check-equal? (proof-forest-count multicut-left return-g) 1)
(check-equal?
 (proof-forest-count multicut-left (vertex-at-address return-branching-context '(1)))
 1)
(for ([witness (in-list branching-witnesses)])
  (check-eq? (return-iterated-witness-source witness)
             return-branching-context)
  (check-equal? (return-iterated-witness-power witness) 2)
  (check-true (formal-sum? (return-iterated-witness-tensor witness)))
  (check-eq? (formal-sum-calculus (return-iterated-witness-tensor witness))
             return-calculus)
  (check-equal? (formal-sum-rank (return-iterated-witness-tensor witness)) 2))

;; Compute the three recurrence rows once.  Each certificate includes the first
;; forced zero after q(1+q)^r, so endpoint annihilation is observed explicitly.
(define first-C (certify-first-return rho return-C #:limit #f))
(define first-C2 (certify-first-return rho return-C2 #:limit #f))
(define first-C3 (certify-first-return rho return-C3 #:limit #f))
(check-true (first-return-certificate? first-C))
(check-true (first-return-certificate? first-C2))
(check-true (first-return-certificate? first-C3))
(check-equal? (certificate-row first-C) '(1 0))
(check-equal? (certificate-row first-C2) '(1 1 0))
(check-equal? (certificate-row first-C3) '(1 2 1 0))
(check-equal? (first-return-certificate-proper-return-addresses first-C) '())
(check-equal? (first-return-certificate-proper-return-addresses first-C2)
              '((1)))
(check-equal? (first-return-certificate-proper-return-addresses first-C3)
              '((1) (1 1)))
(for* ([first-certificate (in-list (list first-C first-C2 first-C3))]
       [power-certificate
        (in-list
         (first-return-certificate-power-certificates first-certificate))])
  (check-power-certificate power-certificate))

;; C^3 exposes the chain <-> surviving uncollected-witness bijection at powers
;; two and three, including the inner-to-outer staged cut order.
(define C3-power-2
  (second (first-return-certificate-power-certificates first-C3)))
(define C3-power-3
  (third (first-return-certificate-power-certificates first-C3)))
(define C3-power-4
  (fourth (first-return-certificate-power-certificates first-C3)))
(check-equal?
 (length (return-power-certificate-iterated-occurrence-witnesses C3-power-2))
 4)
(check-equal?
 (length (return-power-certificate-surviving-occurrence-witnesses C3-power-2))
 2)
(check-equal?
 (map return-chain-witness-addresses
      (return-power-certificate-chain-witnesses C3-power-2))
 '(((1)) ((1 1))))
(check-equal?
 (map return-iterated-witness-reverse-chain-addresses
      (return-power-certificate-surviving-occurrence-witnesses C3-power-2))
 '(((1)) ((1 1))))
(check-equal? (length (return-power-certificate-witness-bijections C3-power-2))
              2)
(check-equal?
 (length (return-power-certificate-iterated-occurrence-witnesses C3-power-3))
 10)
(check-equal?
 (length (return-power-certificate-surviving-occurrence-witnesses C3-power-3))
 1)
(check-equal?
 (map return-chain-witness-addresses
      (return-power-certificate-chain-witnesses C3-power-3))
 '(((1) (1 1))))
(check-equal?
 (map return-iterated-witness-reverse-chain-addresses
      (return-power-certificate-surviving-occurrence-witnesses C3-power-3))
 '(((1) (1 1))))
(check-equal? (length (return-power-certificate-witness-bijections C3-power-3))
              1)
(check-equal?
 (length (return-power-certificate-iterated-occurrence-witnesses C3-power-4))
 20)
(check-equal?
 (return-power-certificate-surviving-occurrence-witnesses C3-power-4)
 '())
(check-equal? (return-power-certificate-chain-witnesses C3-power-4) '())

(for ([certificate (in-list (list C3-power-2 C3-power-3))])
  (check-equal? (return-power-certificate-actual-survivor-projection certificate)
                (return-power-certificate-uncollected-survivor-projection
                 certificate))
  (check-equal? (return-power-certificate-actual-survivor-projection certificate)
                (return-power-certificate-recursive-chain-projection certificate))
  (for ([bijection
         (in-list (return-power-certificate-witness-bijections certificate))])
    (check-true (return-witness-bijection-forward-tensor-equal? bijection))
    (check-true (return-witness-bijection-reverse-chain-equal? bijection))
    (check-true (return-witness-bijection-roundtrip? bijection))
    (check-equal?
     (return-witness-bijection-addresses bijection)
     (return-chain-witness-addresses
      (return-witness-bijection-chain-witness bijection)))
    (check-equal?
     (return-witness-bijection-addresses bijection)
     (return-iterated-witness-reverse-chain-addresses
      (return-witness-bijection-iterated-witness bijection)))
    (check-true
     (return-chain-witness-reconstructs?
      (return-witness-bijection-chain-witness bijection)))))

(define C3-full-chain
  (car (return-power-certificate-chain-witnesses C3-power-3)))
(check-equal?
 (map cut-witness-addresses
      (return-chain-witness-staged-witnesses C3-full-chain))
 '(((1 1)) ((1))))
(check-equal? (map forest-raws
                   (return-chain-witness-coordinate-forests C3-full-chain))
              '(((app u (puncture)))
                ((app u (puncture)))
                ((app u (puncture)))))

;; Polynomial evaluation at -1 is rho(S(C)); the first-return indicator has
;; the opposite sign.  Keeping both assertions prevents the common sign slip.
(check-equal?
 (return-polynomial-data-coefficients
  (first-return-certificate-polynomial first-C))
 '#(0 1))
(check-equal?
 (return-polynomial-data-coefficients
  (first-return-certificate-polynomial first-C2))
 '#(0 1 1))
(check-equal?
 (return-polynomial-data-coefficients
  (first-return-certificate-polynomial first-C3))
 '#(0 1 2 1))
(check-equal? (map first-return-certificate-antipode-character-value
                   (list first-C first-C2 first-C3))
              '(-1 0 0))
(check-equal? (map first-return-certificate-polynomial-at-minus-one
                   (list first-C first-C2 first-C3))
              '(-1 0 0))
(check-equal? (map first-return-certificate-first-return-indicator
                   (list first-C first-C2 first-C3))
              '(1 0 0))
(check-equal? (map first-return-certificate-direct-first-return?
                   (list first-C first-C2 first-C3))
              '(#t #f #f))
(for ([certificate (in-list (list first-C first-C2 first-C3))])
  (check-true
   (first-return-certificate-polynomial-antipode-sign-law? certificate))
  (check-true (first-return-certificate-indicator-law? certificate))
  (check-true (first-return-certificate-theorem-holds? certificate))
  (check-eq?
   (formal-sum-calculus (first-return-certificate-antipode-image certificate))
   return-calculus))
(check-equal?
 (first-return-certificate-first-return-indicator first-C)
 (- (first-return-certificate-antipode-character-value first-C)))

(define deliberately-wrong-polynomial
  (return-factorization-polynomial rho return-C3 '#(0 1 9 0)))
(check-equal? (return-polynomial-data-return-count deliberately-wrong-polynomial)
              2)
(check-false (return-polynomial-data-equal? deliberately-wrong-polynomial))
(check-exn
 exn:fail:contract?
 (lambda ()
   (return-factorization-polynomial rho return-C3 '#(0 1 2 1 0))))

;; First return is relative to G along the unique spine.  Repeated H frames
;; and a complete off-spine G subtree do not manufacture a proper G return.
(define rho-G (make-boundary-return-character colour-calculus colour-G))
(check-true (boundary-return-context? rho-G G-first-via-repeated-H))
(check-true (boundary-return-context? rho-G G-first-with-off-spine-G))
(define repeated-H-spine
  (return-spine-decomposition-of rho-G G-first-via-repeated-H))
(check-equal? (map return-spine-frame-address
                   (return-spine-decomposition-frames repeated-H-spine))
              '(() (1) (1 1)))
(check-equal? (map return-spine-frame-root-boundary
                   (return-spine-decomposition-frames repeated-H-spine))
              (list colour-G colour-H colour-H))
(check-equal? (map return-spine-frame-selected-boundary
                   (return-spine-decomposition-frames repeated-H-spine))
              (list colour-H colour-H colour-G))
(check-equal? (map return-spine-frame-return?
                   (return-spine-decomposition-frames repeated-H-spine))
              '(#f #f #f))
(check-equal? (proper-boundary-return-addresses
               rho-G G-first-via-repeated-H)
              '())
(define repeated-H-certificate
  (certify-first-return rho-G G-first-via-repeated-H #:limit #f))
(check-true (first-return-certificate-direct-first-return?
             repeated-H-certificate))
(check-true (first-return-certificate-theorem-holds?
             repeated-H-certificate))

(check-equal?
 (derivation-root-boundary
  (vertex-at-address G-first-with-off-spine-G '(2)))
 colour-G)
(define off-spine-G-spine
  (return-spine-decomposition-of rho-G G-first-with-off-spine-G))
(check-equal? (map return-spine-frame-address
                   (return-spine-decomposition-frames off-spine-G-spine))
              '(() (1)))
(check-equal? (map car
                   (return-spine-frame-off-spine-children
                    (first
                     (return-spine-decomposition-frames off-spine-G-spine))))
              '(2))
(check-equal? (proper-boundary-return-addresses
               rho-G G-first-with-off-spine-G)
              '())
(define off-spine-G-certificate
  (certify-first-return rho-G G-first-with-off-spine-G #:limit #f))
(check-true (first-return-certificate-direct-first-return?
             off-spine-G-certificate))
(check-true (first-return-certificate-theorem-holds?
             off-spine-G-certificate))

;; Iterating the first-return generator C records every insertion prefix and
;; independently certifies the q(1+q)^(n-1) row at each layer.
(define unfolding-layers
  (unfold-first-return-context rho return-C 3 #:limit #f))
(check-equal? (length unfolding-layers) 3)
(check-equal? (map unfolding-layer-power unfolding-layers) '(1 2 3))
(check-equal? (map (lambda (layer)
                     (checked-term->raw (unfolding-layer-context layer)))
                   unfolding-layers)
              '((app u (puncture))
                (app u (app u (puncture)))
                (app u (app u (app u (puncture))))))
(check-equal? (map unfolding-layer-inserted-root-address unfolding-layers)
              '(() (1) (1 1)))
(check-equal? (map unfolding-layer-puncture-address unfolding-layers)
              '((1) (1 1) (1 1 1)))
(check-equal?
 (map (lambda (layer)
        (length
         (first-return-certificate-proper-return-addresses
          (unfolding-layer-return-certificate layer))))
      unfolding-layers)
 '(0 1 2))
(check-true (andmap unfolding-layer-power-law? unfolding-layers))
(check-true
 (for/and ([layer (in-list unfolding-layers)])
   (first-return-certificate-theorem-holds?
    (unfolding-layer-return-certificate layer))))
(check-exn
 exn:fail:contract?
 (lambda ()
   (unfold-first-return-context rho return-C2 2 #:limit #f)))

(define seeded-unfolding
  (certify-seeded-unfolding rho return-C 3 return-g #:limit #f))
(check-true (seeded-unfolding-certificate? seeded-unfolding))
(check-eq? (seeded-unfolding-certificate-base-context seeded-unfolding)
           return-C)
(check-equal? (seeded-unfolding-certificate-power seeded-unfolding) 3)
(check-eq? (seeded-unfolding-certificate-seed seeded-unfolding) return-g)
(check-equal? (seeded-unfolding-certificate-separation-addresses
               seeded-unfolding)
              '((1 1 1) (1 1) (1)))
(check-equal?
 (map cut-witness-addresses
      (seeded-unfolding-certificate-staged-witnesses seeded-unfolding))
 '(((1 1 1)) ((1 1)) ((1))))
(check-true
 (andmap cut-witness-reconstructs?
         (seeded-unfolding-certificate-staged-witnesses seeded-unfolding)))
(check-equal? (map forest-raws
                   (seeded-unfolding-certificate-coordinate-forests
                    seeded-unfolding))
              '(((app g))
                ((app u (puncture)))
                ((app u (puncture)))
                ((app u (puncture)))))
(check-equal? (seeded-unfolding-certificate-collected-coefficient
               seeded-unfolding)
              1)
(check-true (seeded-unfolding-certificate-reconstructs? seeded-unfolding))
(check-equal?
 (checked-term->raw
  (seeded-unfolding-certificate-completed-proof seeded-unfolding))
 '(app u (app u (app u (app g)))))
(check-true
 (complete-proof? (seeded-unfolding-certificate-completed-proof
                   seeded-unfolding)))
(check-equal?
 (formal-sum-rank
  (seeded-unfolding-certificate-actual-iterated-coproduct seeded-unfolding))
 4)
(check-equal?
 (formal-sum-coefficient
  (seeded-unfolding-certificate-actual-iterated-coproduct seeded-unfolding)
  (vector->immutable-vector
   (list->vector
    (seeded-unfolding-certificate-coordinate-forests seeded-unfolding))))
 1)

;; Side evidence treats Box^G as the context-composition unit.  For a positive
;; context it retains occurrence addresses, and product composition preserves
;; repeated equal side factors with multiplicity two.
(define Box-side (side-evidence-factorization return-Box))
(check-true (side-evidence-data? Box-side))
(check-eq? (side-evidence-data-source Box-side) return-Box)
(check-equal? (side-evidence-data-puncture Box-side) '())
(check-equal? (side-evidence-data-spine-addresses Box-side) '())
(check-equal? (side-evidence-data-frontier-addresses Box-side) '())
(check-false (side-evidence-data-witness Box-side))
(check-true (proof-forest-empty? (side-evidence-data-forest Box-side)))
(check-eq? (side-evidence-data-bare-spine-remainder Box-side) return-Box)
(check-equal? (side-evidence-data-new-puncture-addresses Box-side) '())
(check-eq? (side-evidence-data-reconstruction Box-side) return-Box)
(check-true (side-evidence-data-reconstructs? Box-side))

(define one-side (side-evidence-factorization return-side-context))
(check-equal? (side-evidence-data-puncture one-side) '(1))
(check-equal? (side-evidence-data-spine-addresses one-side) '(()))
(check-equal? (side-evidence-data-frontier-addresses one-side) '((2)))
(check-true (cut-witness? (side-evidence-data-witness one-side)))
(check-equal? (cut-witness-addresses
               (side-evidence-data-witness one-side))
              '((2)))
(check-equal? (forest-raws (side-evidence-data-forest one-side))
              '((app g)))
(check-equal?
 (checked-term->raw (side-evidence-data-bare-spine-remainder one-side))
 '(app b (puncture) (puncture)))
(check-equal? (side-evidence-data-new-puncture-addresses one-side) '((2)))
(check-equal? (side-evidence-data-reconstruction one-side)
              return-side-context)
(check-true (side-evidence-data-reconstructs? one-side))

(define doubled-side
  (side-evidence-factorization return-side-context-squared))
(check-equal? (side-evidence-data-frontier-addresses doubled-side)
              '((1 2) (2)))
(check-equal? (proof-forest-count
               (side-evidence-data-forest doubled-side) return-g)
              2)
(check-equal? (length (proof-forest-factors
                       (side-evidence-data-forest doubled-side)))
              2)
(check-true (side-evidence-data-reconstructs? doubled-side))

(define side-product
  (check-side-evidence-product return-side-context return-side-context))
(check-true (side-evidence-product-certificate? side-product))
(check-equal? (side-evidence-product-certificate-composed side-product)
              return-side-context-squared)
(check-equal? (side-evidence-product-certificate-prefixed-inner-frontier
               side-product)
              '((1 2)))
(check-equal? (side-evidence-data-frontier-addresses
               (side-evidence-product-certificate-composed-factorization
                side-product))
              '((1 2) (2)))
(check-equal? (proof-forest-count
               (side-evidence-product-certificate-expected-forest side-product)
               return-g)
              2)
(check-true (side-evidence-product-certificate-frontier-equal? side-product))
(check-true (side-evidence-product-certificate-forest-equal? side-product))
(check-true
 (side-evidence-product-certificate-reconstruction-holds? side-product))

;; Split, merge, and swap relations are iterated by ordinary relation
;; composition and checked independently against direct C^n context traces.
(define split-classification
  (classify-component-relation split-incidence))
(define merge-classification
  (classify-component-relation merge-incidence))
(define swap-classification
  (classify-component-relation swap-incidence))
(check-true
 (component-relation-classification-splitting? split-classification))
(check-false
 (component-relation-classification-merger? split-classification))
(check-false
 (component-relation-classification-splitting? merge-classification))
(check-true
 (component-relation-classification-merger? merge-classification))
(check-true
 (component-relation-classification-functional? swap-classification))
(check-true
 (component-relation-classification-inverse-functional? swap-classification))

(define split-analysis
  (component-recurrence-powers split-context 3 #:limit #f))
(define merge-analysis
  (component-recurrence-powers merge-context 3 #:limit #f))
(define swap-analysis
  (component-recurrence-powers swap-context 3 #:limit #f))
(define identity-relation '((1 1) (2 2)))
(define split-relation '((1 1) (1 2)))
(define merge-relation '((1 1) (2 1)))
(define swap-relation '((1 2) (2 1)))
(check-equal? (map component-relation-power-edges
                   (component-recurrence-analysis-powers split-analysis))
              (list identity-relation
                    split-relation split-relation split-relation))
(check-equal? (map component-relation-power-edges
                   (component-recurrence-analysis-powers merge-analysis))
              (list identity-relation
                    merge-relation merge-relation merge-relation))
(check-equal? (map component-relation-power-edges
                   (component-recurrence-analysis-powers swap-analysis))
              (list identity-relation
                    swap-relation identity-relation swap-relation))
(check-equal? (component-recurrence-analysis-status split-analysis)
              'stabilized)
(check-equal? (component-recurrence-analysis-repeat-start split-analysis) 1)
(check-equal? (component-recurrence-analysis-period split-analysis) 1)
(check-equal? (component-recurrence-analysis-status merge-analysis)
              'stabilized)
(check-equal? (component-recurrence-analysis-repeat-start merge-analysis) 1)
(check-equal? (component-recurrence-analysis-period merge-analysis) 1)
(check-equal? (component-recurrence-analysis-status swap-analysis)
              'eventually-periodic)
(check-equal? (component-recurrence-analysis-repeat-start swap-analysis) 0)
(check-equal? (component-recurrence-analysis-period swap-analysis) 2)

(for ([analysis (in-list (list split-analysis merge-analysis swap-analysis))])
  (check-true (component-recurrence-analysis? analysis))
  (check-equal? (component-recurrence-analysis-relation-state-count-bound
                 analysis)
                16)
  (check-false
   (component-recurrence-analysis-exhaustive-state-bound-reached? analysis))
  (check-true
   (component-recurrence-analysis-direct-power-agreement? analysis))
  (check-analysis-scalar-zero analysis)
  (for ([power (in-list (component-recurrence-analysis-powers analysis))]
        [expected-power (in-naturals)])
    (check-equal? (component-relation-power-power power) expected-power)
    (check-true (component-trace? (component-relation-power-direct-trace power)))
    (check-equal? (component-relation-power-edges power)
                  (component-relation-power-direct-edges power))
    (check-true (component-relation-power-agrees? power))
    (check-eq? (checked-term-calculus
                (component-relation-power-context power))
               component-recurrence-calculus)))

(define opaque-analysis
  (component-recurrence-powers opaque-recurrence-context 3 #:limit #f))
(check-true (component-recurrence-analysis? opaque-analysis))
(check-true
 (component-trace-unavailable?
  (component-recurrence-analysis-trace opaque-analysis)))
(check-equal? (component-recurrence-analysis-powers opaque-analysis) '())
(check-equal? (component-recurrence-analysis-status opaque-analysis)
              'component-analysis-unavailable)
(check-false (component-recurrence-analysis-repeat-start opaque-analysis))
(check-false (component-recurrence-analysis-period opaque-analysis))
(check-false
 (component-recurrence-analysis-direct-power-agreement? opaque-analysis))
(check-analysis-scalar-zero opaque-analysis)

;; Bounded computations report explicit not-computed values.  They are never
;; silently interpreted as zero coefficients, failed recurrence, or opacity.
(define chain-limit
  (return-chain-witnesses rho return-C3 2 #:limit 1))
(check-true (analysis-limit? chain-limit))
(check-equal? (analysis-limit-operation chain-limit)
              'return-chain-witnesses)
(check-equal? (analysis-limit-limit chain-limit) 1)
(check-equal? (analysis-limit-required chain-limit) 2)
(check-equal? (analysis-limit-metric chain-limit) 'return-chain-count)

(define uncollected-limit
  (iterated-return-witnesses
   rho return-branching-context 2 #:limit 4))
(check-true (analysis-limit? uncollected-limit))
(check-equal? (analysis-limit-operation uncollected-limit)
              'iterated-return-witnesses)
(check-equal? (analysis-limit-limit uncollected-limit) 4)
(check-equal? (analysis-limit-required uncollected-limit) 5)
(check-equal? (analysis-limit-metric uncollected-limit)
              'uncollected-iterated-witness-count)

(define power-limit
  (certify-return-convolution-power rho return-C3 2 #:limit 1))
(check-true (analysis-limit? power-limit))
(check-equal? (analysis-limit-operation power-limit)
              'return-chain-witnesses)

(define unfolding-limit
  (unfold-first-return-context rho return-C 3 #:limit 2))
(check-true (analysis-limit? unfolding-limit))
(check-equal? (analysis-limit-operation unfolding-limit)
              'unfold-first-return-context)
(check-equal? (analysis-limit-required unfolding-limit) 3)
(check-equal? (analysis-limit-metric unfolding-limit)
              'unfolding-layer-count)

(define component-limit
  (component-recurrence-powers split-context 3 #:limit 23))
(check-true (analysis-limit? component-limit))
(check-equal? (analysis-limit-operation component-limit)
              'component-recurrence-powers)
(check-equal? (analysis-limit-limit component-limit) 23)
(check-equal? (analysis-limit-required component-limit) 24)
(check-equal? (analysis-limit-metric component-limit)
              'component-relation-composition-work)
