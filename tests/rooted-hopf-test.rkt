#lang racket/base

(require racket/list
         rackunit
         "../potkin/kernel.rkt"
         "../potkin/algebra.rkt"
         "../potkin/hopf.rkt"
         "revision-fixtures.rkt"
         "hopf-fixtures.rkt")

(define (singleton-forest term)
  (make-proof-forest (checked-term-calculus term) (list term)))

(define (tensor-key left right)
  (vector->immutable-vector (vector left right)))

(define (coefficient-sum sum)
  (for/sum ([entry (in-list (formal-sum-terms sum))])
    (cdr entry)))

(define (singleton-root-coaction forest)
  (define factors (proof-forest-factors forest))
  (if (= (length factors) 1)
      (root-coaction (car factors))
      (error
       'rooted-hopf-test
       "root coaction right coordinate was not singleton: ~e"
       forest)))

(define (check-coaction-laws term)
  (define delta (root-coaction term))
  (check-false (hopf-error? delta))
  (check-equal?
   (formal-sum-expand-coordinate delta 1 2 forest-coproduct)
   (formal-sum-expand-coordinate delta 2 2 singleton-root-coaction))
  (check-equal?
   (formal-sum-contract-coordinate delta 1 forest-counit)
   (forest-basis (singleton-forest term))))

;; The literal reduced formula is public on every forest.  Its antipode use is
;; in the augmentation ideal; on the algebra unit the stated formula is
;; deliberately -1 tensor 1 rather than an invented zero.
(define one/K0 (empty-proof-forest K0))
(check-equal?
 (reduced-coproduct one/K0)
 (formal-sum-scale -1 (tensor-unit K0 2)))

;; Exact running coproduct sectors.
(define t-forest (singleton-forest t))
(define m-bS-bT (vertex-at-address t '(1)))
(define m-bS-bT-forest (singleton-forest m-bS-bT))
(define i-Box (corolla K0 i-occ))
(define i-Box-forest (singleton-forest i-Box))
(define bS-forest (singleton-forest bS-proof))
(define bT-forest (singleton-forest bT-proof))
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
(define bS+bT-forest (make-proof-forest K0 (list bS-proof bT-proof)))

(define running-proper-cuts
  (list (tensor-key m-bS-bT-forest i-Box-forest)
        (tensor-key bS-forest R-forest)
        (tensor-key bT-forest i-m-bS-Box-forest)
        (tensor-key bS+bT-forest i-m-Box-Box-forest)))

(define reduced-t (reduced-coproduct t-forest))
(check-equal? (formal-sum-support-size reduced-t) 4)
(check-equal? (coefficient-sum reduced-t) 4)
(for ([key (in-list running-proper-cuts)])
  (check-equal? (formal-sum-coefficient reduced-t key) 1))
(check-equal? (formal-sum-coefficient
               reduced-t
               (tensor-key t-forest one/K0))
              0)
(check-equal? (formal-sum-coefficient
               reduced-t
               (tensor-key one/K0 t-forest))
              0)

(define rooted-t (root-coaction t))
(check-equal? (formal-sum-support-size rooted-t) 5)
(check-equal? (coefficient-sum rooted-t) 5)
(check-equal? (formal-sum-coefficient
               rooted-t
               (tensor-key t-forest one/K0))
              0)
(check-equal? (formal-sum-coefficient
               rooted-t
               (tensor-key one/K0 t-forest))
              1)
(for ([key (in-list running-proper-cuts)])
  (check-equal? (formal-sum-coefficient rooted-t key) 1))
(check-coaction-laws t)
(check-coaction-laws R)

;; Coaction equations are also checked on a genuinely bounded mix of nullary,
;; unary, binary, complete, and punctured connected terms.
(for* ([degree (in-range 1 4)]
       [term (in-list (hopf-terms-of-degree degree))])
  (check-coaction-laws term))

;; Final-corolla data retains ordered premises separately from their
;; commutative forest image, and recomposes exactly.
(define t-factorization (final-corolla-factorization t))
(check-true (final-corolla-factorization? t-factorization))
(check-equal? (final-corolla-factorization-source t-factorization) t)
(check-eq? (final-corolla-factorization-occurrence t-factorization) i-occ)
(define aligned-t
  (final-corolla-factorization-aligned-children t-factorization))
(check-true (immutable? aligned-t))
(check-equal? (vector-length aligned-t) 1)
(check-equal? (vector-ref aligned-t 0) m-bS-bT)
(check-equal?
 (final-corolla-factorization-premise-forest t-factorization)
 m-bS-bT-forest)
(check-equal?
 (final-corolla-factorization-corolla t-factorization)
 i-Box)
(check-equal?
 (context-compose
  (final-corolla-factorization-corolla t-factorization)
  (vector->list aligned-t))
 t)
(check-equal?
 (final-corolla-projection t)
 (pure-tensor K0 (vector m-bS-bT-forest i-Box-forest)))

;; The nullary case uses the empty premise forest and its empty cut; punctured
;; connected sources are intentionally outside final-corolla factorization.
(define bS-factorization (final-corolla-factorization bS-proof))
(check-true (final-corolla-factorization? bS-factorization))
(check-equal?
 (vector-length
  (final-corolla-factorization-aligned-children bS-factorization))
 0)
(check-true
 (proof-forest-empty?
  (final-corolla-factorization-premise-forest bS-factorization)))
(check-equal?
 (final-corolla-projection bS-proof)
 (pure-tensor K0 (vector one/K0 bS-forest)))
(define punctured-factorization-error (final-corolla-factorization R))
(check-true (hopf-error? punctured-factorization-error))
(check-equal? (hopf-error-code punctured-factorization-error)
              'incomplete-source)

;; All eight bounded complete roots satisfy the factorization and projection
;; identity, including ordered binary children and nullary roots.
(for ([term (in-list hopf-complete-terms)])
  (define factorization (final-corolla-factorization term))
  (check-true (final-corolla-factorization? factorization))
  (define children
    (final-corolla-factorization-aligned-children factorization))
  (check-equal?
   (context-compose
    (final-corolla-factorization-corolla factorization)
    (vector->list children))
   term)
  (check-equal?
   (final-corolla-projection term)
   (pure-tensor
    hopf-calculus
    (vector
     (final-corolla-factorization-premise-forest factorization)
     (singleton-forest
      (final-corolla-factorization-corolla factorization))))))

;; One-slot insertion is typed context composition, not forest product.
(check-equal? (one-slot-context-insertion bS-proof R)
              (checked-node-basis t))
(check-true (formal-zero? (one-slot-context-insertion bT-proof R)))
(check-true (formal-zero? (one-slot-context-insertion bS-proof t)))

(define g
  (validate-candidate hopf-calculus hopf-g-raw #:expected hopf-S))
(define u-Box
  (validate-candidate
   hopf-calculus (hopf-u-raw raw-hole) #:expected hopf-S))
(define u-g
  (validate-candidate
   hopf-calculus (hopf-u-raw hopf-g-raw) #:expected hopf-S))
(define g-forest (singleton-forest g))
(define u-Box-forest (singleton-forest u-Box))
(check-equal? (one-slot-context-insertion g u-Box)
              (checked-node-basis u-g))
(check-not-equal?
 (one-slot-context-insertion g u-Box)
 (formal-sum-multiply (checked-node-basis g)
                      (checked-node-basis u-Box)))

;; Box remains the nodeless context identity, not a positive connected input
;; or output factor of any rooted Hopf operation.
(define Box/S (identity-context hopf-calculus hopf-S))
(check-true (checked-hole? Box/S))
(check-equal? (context-compose Box/S (list g)) g)
(for ([operation
       (in-list
        (list (lambda () (root-coaction Box/S))
              (lambda () (final-corolla-factorization Box/S))
              (lambda () (one-slot-context-insertion Box/S u-Box))
              (lambda () (one-slot-context-insertion g Box/S))
              (lambda () (singleton-cut-coproduct Box/S))))])
  (check-exn exn:fail:contract? operation))

;; Repeated equal requirements remain separate ordered punctures.
(define b-Box-Box
  (validate-candidate
   hopf-calculus (hopf-b-raw raw-hole raw-hole) #:expected hopf-S))
(define b-g-Box
  (validate-candidate
   hopf-calculus (hopf-b-raw hopf-g-raw raw-hole) #:expected hopf-S))
(define b-Box-g
  (validate-candidate
   hopf-calculus (hopf-b-raw raw-hole hopf-g-raw) #:expected hopf-S))
(define repeated-insertion (one-slot-context-insertion g b-Box-Box))
(check-equal? (formal-sum-support-size repeated-insertion) 2)
(check-equal? (coefficient-sum repeated-insertion) 2)
(check-equal? (forest-coefficient repeated-insertion
                                  (singleton-forest b-g-Box))
              1)
(check-equal? (forest-coefficient repeated-insertion
                                  (singleton-forest b-Box-g))
              1)

;; Structurally equal registries are not common operational provenance.
(define Kclone (make-equipped-calculus (calculus-occurrences K0)))
(define bS/clone
  (validate-candidate Kclone (raw-app 'bS) #:expected S))
(define insertion-provenance-error
  (one-slot-context-insertion bS/clone R))
(check-true (hopf-error? insertion-provenance-error))
(check-equal? (hopf-error-code insertion-provenance-error)
              'calculus-mismatch)

;; Singleton cutting has neither endpoint nor multi-address cuts.  The unary
;; acceptance case is exactly transpose to inserting g into u(Box).
(define singleton-u-g (singleton-cut-coproduct u-g))
(check-equal? (formal-sum-support-size singleton-u-g) 1)
(check-equal?
 (formal-sum-coefficient
  singleton-u-g
  (tensor-key g-forest u-Box-forest))
 1)
(check-true (formal-zero? (singleton-cut-coproduct g)))

;; The transpose also holds when the inserted connected context and the
;; resulting context are punctured.
(define u-u-Box
  (validate-candidate
   hopf-calculus
   (hopf-u-raw (hopf-u-raw raw-hole))
   #:expected hopf-S))
(check-true (proof-context? u-u-Box))
(check-equal? (one-slot-context-insertion u-Box u-Box)
              (checked-node-basis u-u-Box))
(check-equal?
 (formal-sum-coefficient
  (singleton-cut-coproduct u-u-Box)
  (tensor-key u-Box-forest u-Box-forest))
 1)

;; Equal requirements at separate slots stay occurrence-distinct on both
;; sides of the pairing; collection preserves their total multiplicity.
(for ([U-term (in-list (list b-g-Box b-Box-g))])
  (check-equal?
   (forest-coefficient repeated-insertion (singleton-forest U-term))
   (formal-sum-coefficient
    (singleton-cut-coproduct U-term)
    (tensor-key g-forest (singleton-forest b-Box-Box)))))

(define singleton-t (singleton-cut-coproduct t))
(check-equal? (formal-sum-support-size singleton-t) 3)
(check-equal? (coefficient-sum singleton-t) 3)
(check-equal?
 (formal-sum-coefficient singleton-t
                         (tensor-key bS+bT-forest i-m-Box-Box-forest))
 0)

;; Bounded coefficient-transpose oracle: each actual nonroot address supplies
;; S, T and U independently through the cut witness, then prospective
;; insertion and retrospective singleton cutting must give the same integer.
(for* ([degree (in-range 1 4)]
       [U-term (in-list (hopf-terms-of-degree degree))]
       [address (in-list (filter pair? (vertex-addresses U-term)))])
  (define witness (make-cut-witness U-term (list address)))
  (define S-term (detached-entry-term (car (cut-witness-detached witness))))
  (define T-term (cut-witness-remainder witness))
  (define insertion (one-slot-context-insertion S-term T-term))
  (define singleton-delta (singleton-cut-coproduct U-term))
  (define insertion-coefficient
    (forest-coefficient insertion (singleton-forest U-term)))
  (define cut-coefficient
    (formal-sum-coefficient
     singleton-delta
     (tensor-key (singleton-forest S-term)
                 (singleton-forest T-term))))
  (check-equal? insertion-coefficient cut-coefficient)
  (check-true (positive? cut-coefficient)))
