#lang racket/base

(require rackunit
         racket/list
         "../potkin/main.rkt"
         "../potkin/analysis.rkt")

;; One deliberately tiny registry.  The audit uses native checked structure
;; and addresses; these constructor names carry no analytical meaning.
(define S (singleton-hypersequent '() '(S)))
(define empty-incidence (make-component-incidence '() S '()))

(define v-occ
  (make-concrete-occurrence
   'audit-v '() S #:instance 'leaf #:incidence empty-incidence))
(define u-occ
  (make-concrete-occurrence
   'audit-u (list S) S #:instance 'unary-filler
   #:incidence 'opaque-audit-incidence))
(define c-occ
  (make-concrete-occurrence
   'audit-c '() S #:instance 'closed #:incidence empty-incidence))
(define d-occ
  (make-concrete-occurrence
   'audit-d (list S S) S #:instance 'binary-copy
   #:incidence 'opaque-audit-incidence))
(define s-occ
  (make-concrete-occurrence
   'audit-s (list S) S #:instance 'unary-inner
   #:incidence 'opaque-audit-incidence))
(define r1-occ
  (make-concrete-occurrence
   'audit-r1 (list S) S #:instance 'unary-outer
   #:incidence 'opaque-audit-incidence))
(define r2-occ
  (make-concrete-occurrence
   'audit-r2 (list S S) S #:instance 'binary-outer
   #:incidence 'opaque-audit-incidence))

(define occurrences
  (list v-occ u-occ c-occ d-occ s-occ r1-occ r2-occ))
(define calculus (make-equipped-calculus occurrences))

(define (checked raw [registry calculus])
  (define result (validate-candidate registry raw #:expected S))
  (check-false (validation-error? result))
  result)

(define v (checked (raw-app 'audit-v)))
(define uv (checked (raw-app 'audit-u (raw-app 'audit-v))))

(define x-port (make-macro-port 'x S))
(define dropped-x-port (make-macro-port 'x S #:allow-zero-use? #t))

(define pass-summary
  (compile-macro-summary
   calculus (identity-context calculus S) (list x-port)
   (list (cons root-address 'x))))
(define drop-summary
  (compile-macro-summary
   calculus (checked (raw-app 'audit-c)) (list dropped-x-port) '()))
(define dup2-summary
  (compile-macro-summary
   calculus
   (checked (raw-app 'audit-d raw-hole raw-hole))
   (list x-port)
   (list (cons '(1) 'x) (cons '(2) 'x))))
(define chain-summary
  (compile-macro-summary
   calculus
   (checked (raw-app 'audit-r1 (raw-app 'audit-s raw-hole)))
   (list x-port)
   (list (cons '(1 1) 'x))))
(define branch-summary
  (compile-macro-summary
   calculus
   (checked (raw-app 'audit-r2 raw-hole (raw-app 'audit-c)))
   (list x-port)
   (list (cons '(1) 'x))))
(define chain-after-dup2-summary
  (macro-summary-substitute chain-summary 'x dup2-summary))

(define pass-audit (audit-macro-cuts pass-summary 'x uv))
(define drop-audit (audit-macro-cuts drop-summary 'x uv))
(define dup2-audit (audit-macro-cuts dup2-summary 'x uv))
(define chain-audit (audit-macro-cuts chain-summary 'x v))
(define branch-audit (audit-macro-cuts branch-summary 'x v))
(define composed-audit
  (audit-macro-cuts chain-after-dup2-summary 'x v))

(define audits
  (list pass-audit drop-audit dup2-audit chain-audit branch-audit
        composed-audit))

(define (state-of-kind audit kind)
  (findf (lambda (state) (eq? (macro-pointed-state-kind state) kind))
         (macro-cut-audit-source-states audit)))

(define (entries-in-sector audit sector)
  (filter (lambda (entry)
            (eq? (macro-cut-audit-entry-sector entry) sector))
          (macro-cut-audit-entries audit)))

;; Global architecture checks over both independently generated ledgers.
(for ([audit (in-list audits)])
  (check-equal? (macro-cut-audit-completeness audit) 'complete)
  (check-true (macro-cut-audit-direct=compositional? audit))
  (check-equal? (length (macro-cut-audit-entries audit))
                (length (macro-cut-audit-compositional-entries audit)))
  (define target (macro-cut-audit-target audit))
  (for ([entry (in-list
                (append (macro-cut-audit-entries audit)
                        (macro-cut-audit-compositional-entries audit)))])
    (define witness (macro-cut-audit-entry-witness entry))
    (check-true (cut-witness? witness))
    (check-eq? (cut-witness-source witness) target)
    (check-equal? (macro-cut-audit-entry-addresses entry)
                  (cut-witness-addresses witness))
    (check-equal? (map detached-entry-address
                       (macro-cut-audit-entry-detached entry))
                  (macro-cut-audit-entry-addresses entry))
    (check-equal? (macro-cut-audit-entry-detached entry)
                  (cut-witness-detached witness))
    (check-equal? (macro-cut-audit-entry-forest entry)
                  (cut-witness-forest witness))
    (check-equal? (macro-cut-audit-entry-remainder entry)
                  (cut-witness-remainder witness))
    (check-eq? (proof-forest-calculus
                (macro-cut-audit-entry-forest entry))
               calculus)
    (check-true
     (checked-term-has-exact-calculus?
      (macro-cut-audit-entry-remainder entry) calculus))
    (check-true (cut-witness-reconstructs? witness))
    (check-true
     (checked-term-has-exact-calculus?
      (macro-cut-audit-entry-reconstruction entry) calculus))
    (check-equal? (macro-cut-audit-entry-reconstruction entry) target)
    (check-false
     (member root-address (macro-cut-audit-entry-addresses entry) equal?))))

;; Pass[u(v)]: E and V retain their native addresses; U reaches only the
;; witness-free endpoint.  There are no positive or lost defect records.
(check-equal? (length (macro-cut-audit-entries pass-audit)) 2)
(for ([sector '(partial-copy cross-copy macro-internal lost)])
  (check-equal? (macro-cut-audit-sector-count pass-audit sector) 0))
(check-equal? (macro-cut-audit-sector-count pass-audit 'saturated) 2)
(define pass-empty (state-of-kind pass-audit 'empty))
(define pass-proper (state-of-kind pass-audit 'proper))
(define pass-whole (state-of-kind pass-audit 'whole))
(check-equal?
 (macro-cut-audit-entry-addresses
  (macro-cut-audit-transport-source-state pass-audit pass-empty))
 '())
(check-equal?
 (macro-cut-audit-entry-addresses
  (macro-cut-audit-transport-source-state pass-audit pass-proper))
 (cut-witness-addresses (macro-pointed-state-witness pass-proper)))
(define pass-whole-image
  (macro-cut-audit-transport-source-state pass-audit pass-whole))
(check-true (macro-whole-endpoint? pass-whole-image))
(check-false (cut-witness? pass-whole-image))
(check-eq? (macro-whole-endpoint-paired-source-state pass-whole-image)
           pass-whole)
(define pass-root-attempt
  (make-cut-witness (macro-cut-audit-target pass-audit)
                    (list root-address)))
(check-true (cut-error? pass-root-attempt))
(check-equal? (cut-error-code pass-root-attempt) 'root-cut)

;; Drop[u(v)]: E is the neutral saturated record; V and U are explicit lost
;; source records.  The target endpoint is separate and unpaired.
(check-equal? (length (macro-cut-audit-entries drop-audit)) 1)
(check-equal? (macro-cut-audit-sector-count drop-audit 'saturated) 1)
(check-equal? (macro-cut-audit-sector-count drop-audit 'lost) 2)
(check-equal? (map macro-pointed-state-kind
                   (macro-cut-audit-lost-states drop-audit))
              '(proper whole))
(check-true
 (macro-cut-audit-entry?
  (macro-cut-audit-transport-source-state
   drop-audit (state-of-kind drop-audit 'empty))))
(for ([state (in-list (macro-cut-audit-lost-states drop-audit))])
  (check-false (macro-cut-audit-transport-source-state drop-audit state)))
(check-false
 (macro-whole-endpoint-paired-source-state
  (macro-cut-audit-endpoint drop-audit)))

;; Dup2[u(v)]: preserve every occurrence-resolved witness in the exact sector
;; split E/V/U x E/V/U.
(check-equal? (length (macro-cut-audit-entries dup2-audit)) 9)
(check-equal? (macro-cut-audit-sector-count dup2-audit 'saturated) 3)
(check-equal? (macro-cut-audit-sector-count dup2-audit 'partial-copy) 4)
(check-equal? (macro-cut-audit-sector-count dup2-audit 'cross-copy) 2)
(check-equal? (macro-cut-audit-sector-count dup2-audit 'macro-internal) 0)
(check-equal? (macro-cut-audit-sector-count dup2-audit 'lost) 0)

(define expected-dup-records
  (list
   (list 'saturated '() '(empty empty))
   (list 'saturated '((1 1) (2 1)) '(proper proper))
   (list 'saturated '((1) (2)) '(whole whole))
   (list 'partial-copy '((2 1)) '(empty proper))
   (list 'partial-copy '((1 1)) '(proper empty))
   (list 'partial-copy '((2)) '(empty whole))
   (list 'partial-copy '((1)) '(whole empty))
   (list 'cross-copy '((1 1) (2)) '(proper whole))
   (list 'cross-copy '((1) (2 1)) '(whole proper))))

(define actual-dup-records
  (for/list ([entry (in-list (macro-cut-audit-entries dup2-audit))])
    (list
     (macro-cut-audit-entry-sector entry)
     (macro-cut-audit-entry-addresses entry)
     (map (lambda (profile-entry)
            (macro-pointed-state-kind
             (macro-copy-profile-entry-source-state profile-entry)))
          (macro-cut-audit-entry-copy-profile entry)))))
(for ([expected (in-list expected-dup-records)])
  (check-not-false (member expected actual-dup-records equal?)))
(for ([entry (in-list (macro-cut-audit-entries dup2-audit))])
  (check-equal?
   (map macro-copy-profile-entry-occurrence-address
        (macro-cut-audit-entry-copy-profile entry))
   '((1) (2)))
  (check-equal?
   (map macro-copy-profile-entry-port
        (macro-cut-audit-entry-copy-profile entry))
   '(x x)))

(define (sector-polynomial audit sector)
  (define selected (entries-in-sector audit sector))
  (define max-degree
    (if (null? selected)
        0
        (apply max (map (lambda (entry)
                          (length (macro-cut-audit-entry-addresses entry)))
                        selected))))
  (for/list ([degree (in-range (add1 max-degree))])
    (count (lambda (entry)
             (= (length (macro-cut-audit-entry-addresses entry)) degree))
           selected)))

(check-equal? (sector-polynomial dup2-audit 'saturated) '(1 0 2))
(check-equal? (sector-polynomial dup2-audit 'partial-copy) '(0 4))
(check-equal? (sector-polynomial dup2-audit 'cross-copy) '(0 0 2))
(check-equal?
 (for/list ([degree (in-range 3)])
   (+ (count (lambda (entry)
               (= (length (macro-cut-audit-entry-addresses entry)) degree))
             (macro-cut-audit-entries dup2-audit))
      (if (= degree 1) 1 0)))
 '(1 5 4))

(define dup-degree-two
  (filter (lambda (entry)
            (= (length (macro-cut-audit-entry-addresses entry)) 2))
          (macro-cut-audit-entries dup2-audit)))
(check-equal? (length dup-degree-two) 4)
(check-equal? (count (lambda (entry)
                       (eq? (macro-cut-audit-entry-sector entry) 'saturated))
                     dup-degree-two)
              2)
(check-equal? (count (lambda (entry)
                       (eq? (macro-cut-audit-entry-sector entry) 'cross-copy))
                     dup-degree-two)
              2)
(check-equal?
 (length (remove-duplicates
          (map macro-cut-audit-entry-addresses dup-degree-two) equal?))
 4)
(check-equal?
 (length (remove-duplicates
          (map macro-cut-audit-entry-remainder dup-degree-two) equal?))
 4)

;; Chain[a] and Branch[a] distinguish one internal chain cut from two branch
;; cuts; the mixed branch cut retains two independent detached factors.
(check-equal? (length (macro-cut-audit-entries chain-audit)) 3)
(check-equal? (macro-cut-audit-sector-count chain-audit 'saturated) 2)
(check-equal? (macro-cut-audit-sector-count chain-audit 'macro-internal) 1)
(check-equal?
 (map macro-cut-audit-entry-addresses
      (entries-in-sector chain-audit 'macro-internal))
 '(((1))))

(check-equal? (length (macro-cut-audit-entries branch-audit)) 4)
(check-equal? (macro-cut-audit-sector-count branch-audit 'saturated) 2)
(check-equal? (macro-cut-audit-sector-count branch-audit 'macro-internal) 2)
(define branch-mixed
  (findf (lambda (entry)
           (equal? (macro-cut-audit-entry-addresses entry) '((1) (2))))
         (macro-cut-audit-entries branch-audit)))
(check-not-false branch-mixed)
(check-equal? (length (macro-cut-audit-entry-detached branch-mixed)) 2)
(check-equal? (proof-forest-size
               (macro-cut-audit-entry-forest branch-mixed))
              2)

;; Compiled Chain[Dup2[a]] is a regression fixture only; it is not asserted as
;; a general staged-composition theorem.
(check-equal? (length (macro-cut-audit-entries composed-audit)) 6)
(check-equal? (macro-cut-audit-sector-count composed-audit 'saturated) 2)
(check-equal? (macro-cut-audit-sector-count composed-audit 'partial-copy) 2)
(check-equal? (macro-cut-audit-sector-count composed-audit 'cross-copy) 0)
(check-equal? (macro-cut-audit-sector-count composed-audit 'macro-internal) 2)
(check-equal?
 (map macro-cut-audit-entry-addresses
      (entries-in-sector composed-audit 'macro-internal))
 '(((1)) ((1 1))))
(check-equal?
 (map macro-cut-audit-entry-addresses
      (entries-in-sector composed-audit 'partial-copy))
 '(((1 1 1)) ((1 1 2))))

;; Nested clients may reuse an already completed audit's retained target
;; witnesses instead of enumerating that completed source again.  The public
;; constructor remains unavailable, and the resulting native ledger is exact.
(define reused-source-audit
  (audit-macro-cuts
   pass-summary 'x (macro-cut-audit-target chain-audit)
   #:source-audit chain-audit))
(define fresh-source-audit
  (audit-macro-cuts
   pass-summary 'x (macro-cut-audit-target chain-audit)))
(check-equal? (macro-cut-audit-completeness reused-source-audit) 'complete)
(check-true (macro-cut-audit-direct=compositional? reused-source-audit))
(check-equal?
 (map macro-pointed-state-kind
      (macro-cut-audit-source-states reused-source-audit))
 (map macro-pointed-state-kind
      (macro-cut-audit-source-states fresh-source-audit)))
(check-equal?
 (map macro-cut-audit-entry-addresses
      (macro-cut-audit-compositional-entries reused-source-audit))
 (map macro-cut-audit-entry-addresses
      (macro-cut-audit-compositional-entries fresh-source-audit)))

;; Truncation is explicit and disables the equality claim.
(define truncated (audit-macro-cuts dup2-summary 'x uv #:limit 1))
(check-equal? (macro-cut-audit-completeness truncated) 'truncated)
(check-false (macro-cut-audit-direct=compositional? truncated))

;; Structurally equal registry contents do not permit cross-snapshot filling.
(define foreign-calculus (make-equipped-calculus occurrences))
(define foreign-uv
  (checked (raw-app 'audit-u (raw-app 'audit-v)) foreign-calculus))
(check-exn exn:fail:contract?
           (lambda () (audit-macro-cuts pass-summary 'x foreign-uv)))

(printf
 "MACRO CUT AUDIT: Pass 2; Drop 1+2 lost; Dup2 3/4/2; Chain 2/1; Branch 2/2; Chain-o-Dup2 2/2/2; all complete and reconstructed.\n")
