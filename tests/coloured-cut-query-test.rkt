#lang racket/base

(require rackunit
         racket/list
         "../potkin/main.rkt"
         "../potkin/analysis.rkt")

(define P (singleton-hypersequent '() '(p)))

(define ground-occ
  (make-concrete-occurrence 'colour-ground '() P))
(define top-occ
  (make-concrete-occurrence 'colour-top (list P) P))
(define a-occ
  (make-concrete-occurrence 'colour-a (list P) P))
(define b-occ
  (make-concrete-occurrence 'colour-b (list P) P))
(define c-occ
  (make-concrete-occurrence 'colour-c (list P) P))
(define branch-occ
  (make-concrete-occurrence 'colour-branch (list P P) P))

(define calculus
  (make-equipped-calculus
   (list ground-occ top-occ a-occ b-occ c-occ branch-occ)))

(define assignment
  (make-ck-colour-assignment
   calculus
   (list (cons 'a a-occ)
         (cons 'b b-occ)
         (cons 'c c-occ)
         (cons 'root branch-occ))))

(check-eq? (ck-colour-assignment-calculus assignment) calculus)
(check-equal? (ck-colour-assignment-colours assignment) '(a b c root))
(check-eq? (ck-colour-assignment-colour-of assignment b-occ) 'b)
(check-false (ck-colour-assignment-colour-of assignment ground-occ))

(define raw-ground (raw-app 'colour-ground))
(define (raw-top child) (raw-app 'colour-top child))
(define (raw-a child) (raw-app 'colour-a child))
(define (raw-b child) (raw-app 'colour-b child))
(define (raw-c child) (raw-app 'colour-c child))
(define (raw-branch left right) (raw-app 'colour-branch left right))

(define (check-proof raw)
  (define proof (validate-candidate calculus raw #:expected P))
  (unless (complete-proof? proof)
    (error 'coloured-cut-query-test "fixture did not check: ~e" proof))
  proof)

;; The oracle is deliberately independent of the recurrence: it consumes only
;; POTKIN's native cut generator and exact node occurrences.  It stops rather
;; than broadening if one of these tiny fixtures exceeds its explicit bound.
(define (bounded-native-oracle-coefficient
         proof requested #:limit [limit 32])
  (let/ec over-limit
    (define observed 0)
    (for/sum ([addresses (in-admissible-cuts proof)])
      (set! observed (add1 observed))
      (when (> observed limit) (over-limit #f))
      (define colours
        (for/list ([address (in-list addresses)])
          (ck-colour-assignment-colour-of
           assignment
           (checked-node-occurrence (vertex-at-address proof address)))))
      (if (and (pair? addresses)
               (andmap symbol? colours)
               (not (check-duplicates colours eq?))
               (= (length colours) (length requested))
               (for/and ([colour (in-list requested)])
                 (and (memq colour colours) #t)))
          1
          0))))

(define (check-positive proof requested expected)
  (define result
    (query-coloured-ck-cuts proof assignment requested #:limit 256))
  (check-true (coloured-cut-result? result))
  (check-true (coloured-cut-result-positive? result))
  (check-equal? (coloured-cut-result-coefficient result) expected)
  (define oracle
    (bounded-native-oracle-coefficient proof requested #:limit 32))
  (check-true (exact-nonnegative-integer? oracle))
  (check-equal? (coloured-cut-result-coefficient result) oracle)
  (define witness (coloured-cut-result-witness result))
  (check-true (cut-witness? witness))
  (check-eq? (cut-witness-source witness) proof)
  (check-equal? (validate-ck-cut proof (cut-witness-addresses witness))
                (cut-witness-addresses witness))
  (check-equal?
   (map detached-entry-address (coloured-cut-result-detached result))
   (cut-witness-addresses witness))
  (check-true (proof-context? (coloured-cut-result-remainder result)))
  (check-true
   (checked-term-has-exact-calculus?
    (coloured-cut-result-remainder result) calculus))
  (check-equal?
   (derivation-root-boundary (coloured-cut-result-remainder result))
   (derivation-root-boundary proof))
  (check-true (cut-witness-reconstructs? witness))
  (check-equal? (reconstruct-cut-witness witness) proof)
  result)

(define (check-zero proof requested)
  (define result
    (query-coloured-ck-cuts proof assignment requested #:limit 256))
  (check-true (coloured-cut-result? result))
  (check-false (coloured-cut-result-positive? result))
  (check-equal? (coloured-cut-result-coefficient result) 0)
  (check-false (coloured-cut-result-witness result))
  (define oracle
    (bounded-native-oracle-coefficient proof requested #:limit 32))
  (check-true (exact-nonnegative-integer? oracle))
  (check-equal? oracle 0)
  result)

;; 1. Both colours occur below the root, but ancestry forbids selecting both.
(define chain-proof
  (check-proof (raw-top (raw-a (raw-b raw-ground)))))
(void (check-positive chain-proof '(a) 1))
(void (check-positive chain-proof '(b) 1))
(define chain-mixed (check-zero chain-proof '(a b)))
(check-equal? (hash-ref (coloured-cut-result-polynomial chain-mixed)
                        '(a b)
                        0)
              0)

;; 2. Separate branches give one native mixed cut.  Reverse query order also
;; checks canonicalisation by the assignment's certified colour order.
(define separate-proof
  (check-proof
   (raw-branch (raw-a raw-ground) (raw-b raw-ground))))
(define separate-mixed (check-positive separate-proof '(b a) 1))
(check-equal? (coloured-cut-result-requested-colours separate-mixed) '(a b))
(check-equal? (hash-ref (coloured-cut-result-polynomial separate-mixed)
                        '(a b))
              1)

;; 3. Two chain branches realise every pair, but no cut can select three
;; roots.  The exact b occurrence is copied to two distinct addresses.
(define three-colour-proof
  (check-proof
   (raw-branch
    (raw-a (raw-b raw-ground))
    (raw-b (raw-c raw-ground)))))
(void (check-positive three-colour-proof '(a b) 1))
(void (check-positive three-colour-proof '(a c) 1))
(void (check-positive three-colour-proof '(b c) 1))
(void (check-zero three-colour-proof '(a b c)))
(define copied-b-addresses
  (for/list ([address (in-list (vertex-addresses three-colour-proof))]
             #:when
             (eq? (checked-node-occurrence
                   (vertex-at-address three-colour-proof address))
                  b-occ))
    address))
(check-equal? copied-b-addresses '((1 1) (2)))
(define copied-b-result (check-positive three-colour-proof '(b) 2))
(check-not-false
 (member (cut-witness-addresses
          (coloured-cut-result-witness copied-b-result))
         '(((1 1)) ((2)))
         equal?))

;; 4. A colour assigned to the exact root occurrence never manufactures the
;; forbidden whole-tree cut endpoint.
(define root-result (check-zero three-colour-proof '(root)))
(check-false (coloured-cut-result-detached root-result))
(check-false (coloured-cut-result-remainder root-result))
(define rejected-root
  (make-cut-witness three-colour-proof (list root-address)))
(check-true (cut-error? rejected-root))
(check-equal? (cut-error-code rejected-root) 'root-cut)

;; Exact occurrence and calculus identity are enforced before certification.
(define structural-a-copy
  (make-concrete-occurrence 'colour-a (list P) P))
(check-exn
 exn:fail?
 (lambda ()
   (make-ck-colour-assignment
    calculus (list (cons 'a structural-a-copy)))))
(define foreign-calculus
  (make-equipped-calculus
   (list ground-occ top-occ a-occ b-occ c-occ branch-occ)))
(define foreign-assignment
  (make-ck-colour-assignment foreign-calculus (list (cons 'a a-occ))))
(check-exn
 exn:fail?
 (lambda ()
   (query-coloured-ck-cuts chain-proof foreign-assignment '(a) #:limit 32)))

;; A bound failure is explicit and carries no zero coefficient or partial
;; polynomial result.
(define truncated
  (query-coloured-ck-cuts three-colour-proof assignment '(a b) #:limit 0))
(check-true (analysis-limit? truncated))
(check-equal? (analysis-limit-operation truncated) 'query-coloured-ck-cuts)
(check-equal? (analysis-limit-metric truncated)
              'squarefree-recurrence-work)
(check-false (coloured-cut-result? truncated))

(displayln
 "coloured-cut-query: chain obstruction, branching, pairwise/no-triple, copied occurrences, root rejection, provenance, and bounded oracle checks passed")
