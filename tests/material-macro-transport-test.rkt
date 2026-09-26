#lang racket/base

(require rackunit
         racket/list
         "../potkin/main.rkt"
         "../potkin/analysis.rkt")

;; Exact fixture occurrence identities.  The labels B0/B1/B2/E1 are only
;; readable names; materiality comes solely from the prepared exact profile.
(define S (singleton-hypersequent '() '(S)))
(define S0 (make-component-incidence '() S '()))
(define b0-occ
  (make-concrete-occurrence
   'transport-b0 '() S #:instance 'selected-nullary #:incidence S0))
(define b1-occ
  (make-concrete-occurrence
   'transport-b1 (list S) S #:instance 'selected-unary
   #:incidence 'opaque-transport-incidence))
(define b2-occ
  (make-concrete-occurrence
   'transport-b2 (list S S) S #:instance 'selected-binary
   #:incidence 'opaque-transport-incidence))
(define e1-occ
  (make-concrete-occurrence
   'transport-e1 (list S) S #:instance 'extension-unary
   #:incidence 'opaque-transport-incidence))
(define occurrences (list b0-occ b1-occ b2-occ e1-occ))
(define calculus (make-equipped-calculus occurrences))

(define (checked raw #:calculus [registry calculus])
  (define result (validate-candidate registry raw #:expected S))
  (check-false (validation-error? result))
  result)

(define profile
  (make-material-profile calculus (list b0-occ b1-occ b2-occ)))
(define selector (prepare-material-hopf-selector profile))

(define b0 (checked (raw-app 'transport-b0)))
(define b1b0
  (checked (raw-app 'transport-b1 (raw-app 'transport-b0))))
(define e1b0
  (checked (raw-app 'transport-e1 (raw-app 'transport-b0))))
(define b1e1b0
  (checked
   (raw-app 'transport-b1
            (raw-app 'transport-e1 (raw-app 'transport-b0)))))
(define e1e1b0
  (checked
   (raw-app 'transport-e1
            (raw-app 'transport-e1 (raw-app 'transport-b0)))))

(define x-port (make-macro-port 'x S))
(define dropped-x-port (make-macro-port 'x S #:allow-zero-use? #t))
(define pass-summary
  (compile-macro-summary
   calculus (identity-context calculus S) (list x-port)
   (list (cons root-address 'x))))
(define drop-summary
  (compile-macro-summary calculus b0 (list dropped-x-port) '()))
(define dup2-summary
  (compile-macro-summary
   calculus
   (checked (raw-app 'transport-b2 raw-hole raw-hole))
   (list x-port)
   (list (cons '(1) 'x) (cons '(2) 'x))))
;; E1(B1[-]) makes B1 a strict macro vertex while E1 prevents a selected
;; global endpoint.  This is also the outer Chain in Chain o Dup2.
(define chain-summary
  (compile-macro-summary
   calculus
   (checked (raw-app 'transport-e1
                     (raw-app 'transport-b1 raw-hole)))
   (list x-port)
   (list (cons '(1 1) 'x))))
;; The roots (1 1) and (1 2) can coexist: the first is a strict B1 subtree,
;; while the second is an independent copied filler root.
(define branch-summary
  (compile-macro-summary
   calculus
   (checked
    (raw-app 'transport-e1
             (raw-app 'transport-b2
                      (raw-app 'transport-b1 raw-hole)
                      raw-hole)))
   (list x-port)
   (list (cons '(1 1 1) 'x) (cons '(1 2) 'x))))

(define (run summary filler #:limit [limit 4096])
  (audit-material-macro-transport
   summary 'x filler selector #:limit limit))

(define (descriptor record)
  (list (material-macro-record-kind record)
        (material-macro-record-roots record)
        (material-macro-record-origin record)))

(define (descriptors transport)
  (map descriptor (material-macro-transport-direct transport)))

(define (record-with-roots transport roots)
  (findf (lambda (record)
           (equal? (material-macro-record-roots record) roots))
         (material-macro-transport-direct transport)))

(define (check-certified transport expected-count)
  (check-equal? (material-macro-transport-status transport) 'certified)
  (check-true (material-macro-transport-certified? transport))
  (check-equal? (material-macro-transport-reasons transport) '())
  (check-equal? (length (material-macro-transport-direct transport))
                expected-count)
  (check-equal? (length (material-macro-transport-staged transport))
                expected-count)
  (check-equal? (length (material-macro-transport-matched transport))
                expected-count)
  (check-equal? (material-macro-transport-unexpected transport) '())
  (check-equal? (material-macro-transport-missing transport) '())
  (check-equal? (material-macro-transport-direct-coaction transport)
                (material-macro-transport-staged-coaction transport))
  (check-equal? (material-macro-transport-direct-coaction transport)
                (material-macro-transport-reference-coaction transport))
  (check-equal? (material-macro-transport-direct-core transport)
                (material-macro-transport-staged-core transport))
  (check-equal? (material-macro-transport-direct-core transport)
                (material-macro-transport-reference-core transport))
  (check-equal? (material-macro-transport-raw-curvature transport)
                'raw-curvature-unavailable)
  (for ([record (in-list (material-macro-transport-direct transport))])
    (check-equal? (material-macro-record-reconstruction record)
                  (material-macro-transport-target transport)))
  transport)

;; 1. Identity/pass.
(define identity (check-certified (run pass-summary b0) 2))
(check-equal? (map material-macro-record-kind
                   (material-macro-transport-direct identity))
              '(empty whole))

;; 2. Pure B1(B0): empty, the proper inner-root cut, and witness-free whole.
(define pure-chain (check-certified (run pass-summary b1b0) 3))
(check-not-false
 (member '(proper ((1)) input-transported)
         (descriptors pure-chain) equal?))
(define pure-whole
  (findf (lambda (record)
           (eq? (material-macro-record-kind record) 'whole))
         (material-macro-transport-direct pure-chain)))
(check-true (macro-whole-endpoint?
             (material-macro-record-native pure-whole)))
(check-false (cut-witness? (material-macro-record-native pure-whole)))
(check-false
 (member root-address
         (append-map material-macro-record-roots
                     (material-macro-transport-direct pure-chain))
         equal?))

;; 3. B1(E1(B0)): only empty and the proper B0 cut survive.
(define guarded-chain (check-certified (run pass-summary b1e1b0) 2))
(check-not-false
 (member '(proper ((1 1)) input-transported)
         (descriptors guarded-chain) equal?))

;; 4. Dup2 gives four independent selected leaf choices.  Logical port x is
;; shared, but the two native occurrence namespaces and copied addresses are
;; distinct.
(define copied (check-certified (run dup2-summary e1b0) 4))
(check-equal?
 (sort (map material-macro-record-roots
            (material-macro-transport-direct copied))
       (lambda (left right)
         (string<? (format "~s" left) (format "~s" right))))
 (sort '(() ((1 1)) ((2 1)) ((1 1) (2 1)))
       (lambda (left right)
         (string<? (format "~s" left) (format "~s" right)))))
(check-equal? (length (material-macro-transport-copied copied)) 2)
(check-equal?
 (map material-macro-copy-mapping-occurrence-address
      (material-macro-transport-copied copied))
 '((1) (2)))
(check-equal?
 (map material-macro-copy-mapping-port
      (material-macro-transport-copied copied))
 '(x x))
(check-equal?
 (map material-macro-copy-mapping-source-to-target
      (material-macro-transport-copied copied))
 '(((() 1) ((1) 1 1))
   ((() 2) ((1) 2 1))))

;; 5. Drop records one unused logical input, not one loss per source cut.
(define dropped-a (check-certified (run drop-summary e1b0) 2))
(define dropped-b (check-certified (run drop-summary e1e1b0) 2))
(check-equal? (length (material-macro-transport-dropped dropped-a)) 1)
(check-equal?
 (material-macro-dropped-input-reason
  (car (material-macro-transport-dropped dropped-a)))
 'globally-unused-logical-port)
(check-equal? (descriptors dropped-a) (descriptors dropped-b))
(check-equal? (material-macro-transport-direct-coaction dropped-a)
              (material-macro-transport-direct-coaction dropped-b))
(check-equal? (material-macro-transport-direct-core dropped-a)
              (material-macro-transport-direct-core dropped-b))

;; 6-7. A selected strict B1 root masks its hole only when the complete B0
;; filler is selected whole.  It is certified and classified macro-created;
;; the record contains no manufactured inner root.
(define masked-whole (check-certified (run chain-summary b0) 3))
(define macro-created (record-with-roots masked-whole '((1))))
(check-not-false macro-created)
(check-equal? (material-macro-record-origin macro-created) 'macro-created)
(check-equal? (material-macro-record-roots macro-created) '((1)))
(check-not-false
 (findf (lambda (masked)
          (and (equal? (material-macro-masked-hole-roots masked) '((1)))
               (equal? (material-macro-masked-hole-hole-address masked)
                       '(1 1))))
        (material-macro-transport-masked masked-whole)))
(check-equal? (material-macro-transport-dropped masked-whole) '())

;; The same strict B1 label over E1(B0) is not enough: its masked filler whole
;; endpoint is impure.  The precise failed guard is retained.
(define rejected-mask (check-certified (run chain-summary e1b0) 2))
(check-false (record-with-roots rejected-mask '((1))))
(check-not-false
 (findf (lambda (failure)
          (and (equal? (material-macro-guard-failure-strict-root failure)
                       '(1))
               (eq? (material-macro-guard-failure-reason failure)
                    'masked-filler-whole-not-selected)
               (eq? (material-macro-guard-failure-occurrence failure)
                    e1-occ)))
        (material-macro-transport-guard-failures rejected-mask)))

;; 8. One strict B1 root and one independent filler root retain both native
;; addresses and are classified mixed.
(define mixed (check-certified (run branch-summary b0) 7))
(define mixed-record (record-with-roots mixed '((1 1) (1 2))))
(check-not-false mixed-record)
(check-equal? (material-macro-record-origin mixed-record) 'mixed)
(check-equal? (length (material-macro-record-detached mixed-record)) 2)

;; 9. Chain o Dup2: direct filled, one-shot composed, and two-stage guarded
;; transports agree occurrence-by-occurrence and after collection/contraction.
(define nested-b0
  (audit-material-macro-composition
   chain-summary 'x dup2-summary 'x b0 selector #:limit 512))
(define nested-e1
  (audit-material-macro-composition
   chain-summary 'x dup2-summary 'x e1b0 selector #:limit 512))
(for ([comparison (in-list (list nested-b0 nested-e1))]
      [expected (in-list '(6 4))])
  (check-equal? (material-macro-composition-status comparison) 'certified)
  (check-true (material-macro-composition-certified? comparison))
  (check-equal? (material-macro-composition-reasons comparison) '())
  (check-equal? (length (material-macro-composition-direct comparison))
                expected)
  (check-equal? (length (material-macro-composition-one-shot comparison))
                expected)
  (check-equal? (length (material-macro-composition-two-stage comparison))
                expected)
  (check-equal?
   (material-macro-composition-unexpected-one-shot comparison) '())
  (check-equal? (material-macro-composition-missing-one-shot comparison) '())
  (check-equal?
   (material-macro-composition-unexpected-two-stage comparison) '())
  (check-equal? (material-macro-composition-missing-two-stage comparison) '())
  (check-equal? (material-macro-composition-direct-coaction comparison)
                (material-macro-composition-one-shot-coaction comparison))
  (check-equal? (material-macro-composition-direct-coaction comparison)
                (material-macro-composition-two-stage-coaction comparison))
  (check-equal? (material-macro-composition-direct-core comparison)
                (material-macro-composition-one-shot-core comparison))
  (check-equal? (material-macro-composition-direct-core comparison)
                (material-macro-composition-two-stage-core comparison)))

;; 10. Naively admitting selected strict labels without the whole-subtree guard
;; predicts two spurious states for E1(B0) under Chain o Dup2.
(define naive-input-only-count (expt 2 2))
(define naive-label-only-extra 2)
(check-equal? naive-input-only-count 4)
(check-equal? (+ naive-input-only-count naive-label-only-extra) 6)
(check-equal? (length (material-macro-composition-direct nested-e1)) 4)

;; 11. Exact foreign provenance is rejected during preparation, before native
;; filling/cut enumeration can begin.
(define foreign-calculus (make-equipped-calculus occurrences))
(define foreign-profile
  (make-material-profile foreign-calculus
                         (list b0-occ b1-occ b2-occ)))
(define foreign-selector (prepare-material-hopf-selector foreign-profile))
(check-exn
 exn:fail:contract?
 (lambda ()
   (prepare-material-macro-transport
    pass-summary 'x b0 foreign-selector)))

;; 12. A low bound is explicitly inconclusive and exposes no collected claim.
(define truncated (run dup2-summary e1b0 #:limit 1))
(check-equal? (material-macro-transport-status truncated) 'truncated)
(check-false (material-macro-transport-certified? truncated))
(check-equal? (material-macro-transport-direct-coaction truncated) #f)
(check-equal? (material-macro-transport-staged-coaction truncated) #f)

;; Small generated rule/schema family.  The declared bound is fixture degree
;; 3 and witness limit 512; these finite checks are falsification evidence, not
;; a universal proof.
(define generated-cases
  (list (run pass-summary b0 #:limit 512)
        (run pass-summary e1b0 #:limit 512)
        (run pass-summary b1b0 #:limit 512)
        (run pass-summary b1e1b0 #:limit 512)
        (run chain-summary b0 #:limit 512)
        (run chain-summary e1b0 #:limit 512)
        (run dup2-summary b0 #:limit 512)
        (run dup2-summary e1b0 #:limit 512)
        (run drop-summary b0 #:limit 512)
        (run drop-summary e1b0 #:limit 512)
        (run branch-summary b0 #:limit 512)
        (run branch-summary e1b0 #:limit 512)))
(for ([transport (in-list generated-cases)])
  (check-true (material-macro-transport-certified? transport)))
(define generated-record-count
  (for/sum ([transport (in-list generated-cases)])
    (length (material-macro-transport-direct transport))))
(define generated-tensor-count
  (for/sum ([transport (in-list generated-cases)])
    (formal-sum-support-size
     (material-macro-transport-direct-coaction transport))))
(define composition-cases (list nested-b0 nested-e1))
(for ([comparison (in-list composition-cases)])
  (check-true (material-macro-composition-certified? comparison)))

(printf
 (string-append
  "MATERIAL MACRO TRANSPORT: hand supports identity=2, pure-chain=3, "
  "guarded-chain=2, Dup2=4, Drop=2, masked/macro-created=3, mixed=7; "
  "nested Chain-o-Dup2=6/4. Generated degree<=3, limit=512: "
  "~a direct cases, ~a composition cases, ~a occurrence records, "
  "~a collected tensors; all certified.\n")
 (length generated-cases)
 (length composition-cases)
 generated-record-count
 generated-tensor-count)
