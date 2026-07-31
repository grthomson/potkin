#lang racket/base

(require rackunit
         racket/list
         "../potkin/kernel.rkt"
         (prefix-in example: "../examples/v56-running-factorisation.rkt")
         "kernel-fixtures.rkt")

(define bS-proof
  (validate-candidate running-calculus (raw-app 'bS) #:expected S))
(define bS-prime-proof
  (validate-candidate running-calculus (raw-app 'bS-prime) #:expected S))
(define bT-proof
  (validate-candidate running-calculus (raw-app 'bT) #:expected T))
(define m-proof
  (validate-candidate
   running-calculus
   (raw-app 'm (raw-app 'bS) (raw-app 'bT))
   #:expected ST))

(define expected-running-cuts
  (list '()
        '((1))
        '((1 1))
        '((1 2))
        '((1 1) (1 2))))

(check-equal? (vertex-addresses running-proof)
              '(() (1) (1 1) (1 2)))
(check-equal? (for/list ([cut (in-admissible-cuts running-proof)]) cut)
              expected-running-cuts)
(check-equal? example:example-admissible-cuts expected-running-cuts)
(check-equal? (vertex-addresses example:t)
              '(() (1) (1 1) (1 2)))
(check-true (complete-proof? example:t))
(check-equal? (derivation-root-boundary example:t) example:U)
(check-equal? example:two-leaf-detached
              '(((1 1) (app bS))
                ((1 2) (app bT))))
(check-equal? example:two-leaf-remainder
              '(app i (app m (puncture) (puncture))))
(check-equal? example:two-leaf-telescope
              '(((1 1) S) ((1 2) T)))
(check-true example:two-leaf-reconstructs?)

(define two-leaf-witness
  ;; Deliberately reverse the input: validation canonicalises addresses before
  ;; building the aligned tuple.
  (make-cut-witness running-proof '((1 2) (1 1))))
(check-true (cut-witness? two-leaf-witness))
(check-equal? (cut-witness-addresses two-leaf-witness)
              '((1 1) (1 2)))
(check-equal?
 (map detached-entry-address (cut-witness-detached two-leaf-witness))
 '((1 1) (1 2)))
(check-equal?
 (map detached-entry-term (cut-witness-detached two-leaf-witness))
 (list bS-proof bT-proof))
(check-equal?
 (checked-term->raw (cut-witness-remainder two-leaf-witness))
 (raw-app 'i (raw-app 'm raw-hole raw-hole)))
(check-equal?
 (map telescope-entry-address
      (premise-telescope (cut-witness-remainder two-leaf-witness)))
 '((1 1) (1 2)))
(check-equal?
 (map telescope-entry-requirement
      (premise-telescope (cut-witness-remainder two-leaf-witness)))
 (list S T))
(check-equal? (proof-forest-size (cut-witness-forest two-leaf-witness)) 2)
(check-equal? (proof-forest-count
               (cut-witness-forest two-leaf-witness)
               bS-proof)
              1)
(check-equal? (proof-forest-count
               (cut-witness-forest two-leaf-witness)
               bT-proof)
              1)
(check-equal? (reconstruct-cut-witness two-leaf-witness) running-proof)

(define all-running-witnesses
  (for/list ([witness (in-admissible-cut-witnesses running-proof)])
    witness))
(check-equal? (map cut-witness-addresses all-running-witnesses)
              expected-running-cuts)
(for ([witness (in-list all-running-witnesses)])
  (check-true (cut-witness-reconstructs? witness))
  (check-equal? (puncture-addresses (cut-witness-remainder witness))
                (cut-witness-addresses witness)))

(define empty-witness (first all-running-witnesses))
(check-true (proof-forest-empty? (cut-witness-forest empty-witness)))
(check-equal? (cut-witness-remainder empty-witness) running-proof)

(define root-cut (make-cut-witness running-proof (list root-address)))
(check-true (cut-error? root-cut))
(check-equal? (cut-error-code root-cut) 'root-cut)
(check-false (member (list root-address) expected-running-cuts))

(define crossing-cut
  (make-cut-witness running-proof '((1) (1 1))))
(check-true (cut-error? crossing-cut))
(check-equal? (cut-error-code crossing-cut) 'non-prefix-free)
(check-equal? (hash-ref (cut-error-details crossing-cut) 'ancestor) '(1))
(check-equal? (hash-ref (cut-error-details crossing-cut) 'descendant)
              '(1 1))
(check-equal? (cut-error-code
               (make-cut-witness running-proof '((2))))
              'nonvertex-address)
(check-equal? (cut-error-code
               (make-cut-witness running-proof '((1 1) (1 1))))
              'duplicate-address)
(check-equal? (cut-error-code
               (make-cut-witness running-proof (list #f)))
              'malformed-address)
(check-equal? (cut-error-code
               (make-cut-witness running-proof '((0))))
              'malformed-address)

;; Existing punctures are not vertices and survive a cut/reconstruction.
(define open-source
  (validate-candidate
   running-calculus
   (raw-app 'i (raw-app 'm raw-hole (raw-app 'bT)))
   #:expected U))
(check-equal? (vertex-addresses open-source) '(() (1) (1 2)))
(check-equal? (for/list ([cut (in-admissible-cuts open-source)]) cut)
              (list '() '((1)) '((1 2))))
(define open-leaf-witness (make-cut-witness open-source '((1 2))))
(check-equal? (puncture-addresses
               (cut-witness-remainder open-leaf-witness))
              '((1 1) (1 2)))
(check-equal? (reconstruct-cut-witness open-leaf-witness) open-source)
(check-equal? (puncture-addresses
               (reconstruct-cut-witness open-leaf-witness))
              '((1 1)))
(define open-parent-witness (make-cut-witness open-source '((1))))
(check-true (proof-context?
             (detached-entry-term
              (first (cut-witness-detached open-parent-witness)))))
(check-equal? (reconstruct-cut-witness open-parent-witness) open-source)
(check-true (cut-witness-reconstructs? open-parent-witness))

;; Structural generation follows the chain directly: a 25-edge ancestry
;; chain has just the empty cut and 25 singleton cuts.
(define chain-occ
  (make-concrete-occurrence 'chain (list S) S #:kind 'logical))
(define chain-calculus
  (make-equipped-calculus (list bS-occ chain-occ)))
(define chain-raw
  (for/fold ([candidate (raw-app 'bS)])
            ([depth (in-range 25)])
    (raw-app 'chain candidate)))
(define chain-proof
  (validate-candidate chain-calculus chain-raw #:expected S))
(define chain-cuts
  (for/list ([cut (in-admissible-cuts chain-proof)]) cut))
(check-equal? (length chain-cuts) 26)
(check-equal? (last chain-cuts)
              (list (make-list 25 1)))

;; Equal detached trees at distinct positions remain separate occurrences in
;; the aligned tuple, and their commutative forest retains multiplicity two.
(define repeated-proof
  (validate-candidate
   running-calculus
   (raw-app 'a (raw-app 'bS) (raw-app 'bS))
   #:expected V))
(define repeated-witness
  (make-cut-witness repeated-proof '((1) (2))))
(check-equal?
 (map detached-entry-address (cut-witness-detached repeated-witness))
 '((1) (2)))
(check-equal?
 (map detached-entry-term (cut-witness-detached repeated-witness))
 (list bS-proof bS-proof))
(check-equal? (proof-forest-size (cut-witness-forest repeated-witness)) 2)
(check-equal? (proof-forest-count
               (cut-witness-forest repeated-witness)
               bS-proof)
              2)
(check-equal? (hypersequent-size
               (forest-flattened-root
                (cut-witness-forest repeated-witness)))
              2)
(check-equal? (block-root-profile-count
               (forest-block-root-profile
                (cut-witness-forest repeated-witness))
               S)
              2)
(check-equal? (puncture-addresses (cut-witness-remainder repeated-witness))
              '((1) (2)))
(check-true (cut-witness-reconstructs? repeated-witness))

;; Premise order is proof structure; forest order is not.
(define left-first
  (validate-candidate
   running-calculus
   (raw-app 'a (raw-app 'bS) (raw-app 'bS-prime))
   #:expected V))
(define right-first
  (validate-candidate
   running-calculus
   (raw-app 'a (raw-app 'bS-prime) (raw-app 'bS))
   #:expected V))
(check-not-equal? left-first right-first)
(check-equal?
 (make-proof-forest running-calculus (list left-first right-first))
 (make-proof-forest running-calculus (list right-first left-first)))

;; A connected assembly proof and two independent proof blocks flatten to the
;; same root boundary but retain different block-root profiles and types.
(define connected-forest
  (make-proof-forest running-calculus (list m-proof)))
(define separate-forest
  (make-proof-forest running-calculus (list bS-proof bT-proof)))
(check-equal? (forest-flattened-root connected-forest) ST)
(check-equal? (forest-flattened-root separate-forest) ST)
(check-not-equal? (forest-block-root-profile connected-forest)
                  (forest-block-root-profile separate-forest))
(check-equal? (block-root-profile-count
               (forest-block-root-profile connected-forest)
               ST)
              1)
(check-equal? (block-root-profile-count
               (forest-block-root-profile separate-forest)
               S)
              1)
(check-equal? (block-root-profile-count
               (forest-block-root-profile separate-forest)
               T)
              1)
(check-false (equal? m-proof separate-forest))

(define reversed-separate
  (make-proof-forest running-calculus (list bT-proof bS-proof)))
(check-equal? separate-forest reversed-separate)
(check-equal? (forest-union (make-proof-forest running-calculus
                                               (list bS-proof))
                            (make-proof-forest running-calculus
                                               (list bT-proof)))
              separate-forest)

(define forest-extension
  (make-equipped-calculus
   (append (calculus-occurrences running-calculus) (list chain-occ))))
(define rehomed-running-forest
  (make-proof-forest forest-extension (list running-proof)))
(check-true
 (eq? (checked-term-calculus
       (first (proof-forest-factors rehomed-running-forest)))
      forest-extension))

;; Forest multiplication has one fixed calculus and rejects cross-calculus
;; operands symmetrically rather than choosing an implicit target by order.
(define S-only-calculus (make-equipped-calculus (list bS-occ)))
(define S-only-unit (empty-proof-forest S-only-calculus))
(for ([left+right (in-list (list (list S-only-unit separate-forest)
                                 (list separate-forest S-only-unit)))])
  (check-exn exn:fail:contract?
             (lambda ()
               (forest-union (first left+right) (second left+right)))))

(define forest-unit (empty-proof-forest running-calculus))
(define identity-S (identity-context running-calculus S))
(check-equal? (proof-forest-size forest-unit) 0)
(check-false (forest-flattened-root forest-unit))
(check-false (equal? forest-unit identity-S))
(check-exn exn:fail:contract?
           (lambda ()
             (make-proof-forest running-calculus (list identity-S))))

;; The invariant-bearing witnesses and forests do not expose reflective
;; constructors to clients.
(for ([protected (in-list (list two-leaf-witness
                                (cut-witness-forest two-leaf-witness)))])
  (define-values (reflected-type skipped?) (struct-info protected))
  (check-false reflected-type)
  (check-true skipped?))
