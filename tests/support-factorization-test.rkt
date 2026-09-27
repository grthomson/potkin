#lang racket/base

(require rackunit
         racket/list
         "../potkin/main.rkt"
         "../potkin/analysis.rkt")

;; One small native checked registry supplies every fixture.  Names are only
;; readable fixture labels: support comes solely from exact material profiles.
(define P (singleton-hypersequent '() '(p)))
(define Q (singleton-hypersequent '() '(q)))
(define R (singleton-hypersequent '() '(r)))

(define (incidence premises conclusion)
  (make-component-incidence
   premises conclusion
   (for/list ([premise (in-list premises)]
              [slot (in-naturals 1)])
     (void premise)
     (make-component-edge slot 1 1))))

(define leaf-occ
  (make-concrete-occurrence
   'support-leaf '() P #:instance 'base-leaf
   #:incidence (incidence '() P)))
(define root-occ
  (make-concrete-occurrence
   'support-root (list P) P #:instance 'base-root
   #:incidence (incidence (list P) P)))
(define ornament-occ
  (make-concrete-occurrence
   'support-ornament (list P) P #:instance 'nonbase-ornament
   #:incidence (incidence (list P) P)))
(define shortcut-occ
  (make-concrete-occurrence
   'support-c (list P) R #:instance 'shortcut
   #:incidence (incidence (list P) R)))
(define first-occ
  (make-concrete-occurrence
   'support-a (list P) Q #:instance 'first-stage
   #:incidence (incidence (list P) Q)))
(define second-occ
  (make-concrete-occurrence
   'support-b (list Q) R #:instance 'second-stage
   #:incidence (incidence (list Q) R)))
(define copy-occ
  (make-concrete-occurrence
   'support-copy (list P P) P #:instance 'copy
   #:incidence (incidence (list P P) P)))
(define drop-occ
  (make-concrete-occurrence
   'support-drop '() P #:instance 'drop
   #:incidence (incidence '() P)))
(define opaque-occ
  (make-concrete-occurrence
   'support-opaque (list P) P #:instance 'opaque
   #:incidence 'unknown-incidence))

(define occurrences
  (list leaf-occ root-occ ornament-occ shortcut-occ first-occ second-occ
        copy-occ drop-occ opaque-occ))
(define calculus (make-equipped-calculus occurrences))

(define (checked raw boundary #:calculus [registry calculus])
  (define result (validate-candidate registry raw #:expected boundary))
  (check-false (validation-error? result))
  result)

(define leaf (checked (raw-app 'support-leaf) P))

;; 1. Chain/base interval.  The base vertices are the root and leaf; the
;; middle ornament is syntactic Q-support.  K={leaf} has exactly two lifts.
(define chain
  (checked
   (raw-app 'support-root
            (raw-app 'support-ornament
                     (raw-app 'support-leaf)))
   P))
(define interval-profile
  (make-material-profile calculus (list leaf-occ root-occ)))
(define chain-category
  (compile-support-factorization-category
   chain interval-profile #:limit 64))
(check-true (support-factorization-category? chain-category))
(check-equal? (length (support-factorization-category-objects chain-category))
              4)
(check-equal? (length (support-factorization-category-arrows chain-category))
              10)
(check-equal? (support-factorization-category-incidence-status chain-category)
              'exact)

(define K '((1 1)))
(check-true (support-factorization-base-ideal? chain-category K))
(define interval-check
  (verify-support-factorization-fibre-interval
   chain-category K #:limit 8))
(check-true (support-fibre-verification? interval-check))
(check-equal? (support-fibre-verification-status interval-check) 'verified)
(check-true (support-fibre-verification-equal? interval-check))
(check-equal?
 (support-factorization-object-ideal
  (support-fibre-verification-lower interval-check))
 '((1 1)))
(check-equal?
 (support-factorization-object-ideal
  (support-fibre-verification-upper interval-check))
 '((1) (1 1)))
(check-equal? (length (support-fibre-verification-fibre interval-check)) 2)

;; Empty, proper, and whole remain three native classifications.  Whole has
;; no witness and no fabricated root cut.
(define empty-object
  (support-factorization-category-object-at-ideal chain-category '()))
(define proper-object
  (support-factorization-category-object-at-ideal chain-category '((1 1))))
(define whole-object
  (support-factorization-category-object-at-ideal
   chain-category '(() (1) (1 1))))
(check-equal? (map support-factorization-object-kind
                   (list empty-object proper-object whole-object))
              '(empty proper whole))
(check-true
 (cut-witness? (support-factorization-object-native-witness empty-object)))
(check-true
 (cut-witness? (support-factorization-object-native-witness proper-object)))
(check-false (support-factorization-object-native-witness whole-object))
(for ([object (in-list (support-factorization-category-objects chain-category))]
      #:unless (eq? (support-factorization-object-kind object) 'whole))
  (check-false
   (member root-address
           (cut-witness-addresses
            (support-factorization-object-native-witness object))
           equal?)))

;; 2. The zero-vertex identity macro is the operadic unit, not a fabricated
;; rule.  Its native source/target correspondence is exact in degrees 2 and 3.
(define x-port (make-macro-port 'x P))
(define identity-summary
  (compile-macro-summary
   calculus (identity-context calculus P) (list x-port)
   (list (cons root-address 'x))))
(define identity-profile (make-material-profile calculus (list leaf-occ)))
(define identity-audit
  (audit-support-factorization-macro
   identity-summary 'x leaf identity-profile #:limit 32))
(check-equal? (support-macro-audit-status identity-audit) 'exact/cartesian)
(check-false (support-macro-audit-positive? identity-audit))
(check-true (support-macro-audit-externally-linear? identity-audit))
(check-true (support-macro-audit-incidence-exact? identity-audit))
(define identity-comparison (support-macro-audit-comparison identity-audit))
(check-equal?
 (support-exactness-result-status
  (support-factorization-comparison-degree-2 identity-comparison))
 'exact)
(check-equal?
 (support-exactness-result-status
  (support-factorization-comparison-degree-3 identity-comparison))
 'exact)
(check-true
 (support-factorization-comparison-cartesian-objects? identity-comparison))
(check-true
 (support-factorization-comparison-cartesian-arrows? identity-comparison))
(check-equal? (length (support-factorization-profile-pp
                       (support-macro-audit-profile identity-audit)))
              2)
(check-equal? (support-factorization-profile-qp
               (support-macro-audit-profile identity-audit))
              '())

;; 3. Shortcut versus composite.  Both native macros have input P and output
;; R.  The explicit occurrence map aligns the endpoint constructors and the
;; copied leaf, but the composite has the unmatched a-stage ideal.
(define shortcut-context
  (checked (raw-app 'support-c raw-hole) R))
(define composite-context
  (checked (raw-app 'support-b (raw-app 'support-a raw-hole)) R))
(define shortcut-summary
  (compile-macro-summary
   calculus shortcut-context (list x-port) (list (cons '(1) 'x))))
(define composite-summary
  (compile-macro-summary
   calculus composite-context (list x-port) (list (cons '(1 1) 'x))))
(define shortcut-profile
  (make-material-profile
   calculus (list leaf-occ shortcut-occ first-occ second-occ)))
(define shortcut-audit
  (audit-support-factorization-macro
   shortcut-summary 'x leaf shortcut-profile #:limit 64))
(define composite-audit
  (audit-support-factorization-macro
   composite-summary 'x leaf shortcut-profile #:limit 64))
(define shortcut-category (support-macro-audit-target-category shortcut-audit))
(define composite-category
  (support-macro-audit-target-category composite-audit))

(define shortcut-empty
  (support-factorization-category-object-at-ideal shortcut-category '()))
(define shortcut-leaf
  (support-factorization-category-object-at-ideal shortcut-category '((1))))
(define shortcut-whole
  (support-factorization-category-object-at-ideal shortcut-category '(() (1))))
(define composite-empty
  (support-factorization-category-object-at-ideal composite-category '()))
(define composite-leaf
  (support-factorization-category-object-at-ideal
   composite-category '((1 1))))
(define composite-middle
  (support-factorization-category-object-at-ideal
   composite-category '((1) (1 1))))
(define composite-whole
  (support-factorization-category-object-at-ideal
   composite-category '(() (1) (1 1))))
(define shortcut/composite-pairs
  (list
   (make-support-factorization-relation-pair
    shortcut-empty composite-empty 'empty-endpoint)
   (make-support-factorization-relation-pair
    shortcut-leaf composite-leaf
    (list (support-factorization-object-native-witness shortcut-leaf)
          (support-factorization-object-native-witness composite-leaf)))
   (make-support-factorization-relation-pair
    shortcut-whole composite-whole 'whole-endpoint)))
(define shortcut/composite
  (audit-support-factorization-relation
   shortcut-category composite-category shortcut/composite-pairs
   #:occurrence-map (hash root-address root-address '(1) '(1 1))))
(check-true
 (support-factorization-inconclusive?
  (audit-support-factorization-relation
   shortcut-category composite-category shortcut/composite-pairs
   #:occurrence-map (hash root-address root-address '(1) '(1 1))
   #:limit 1)))
(check-equal? (support-factorization-comparison-status shortcut/composite)
              'relation/profile-only)
(check-not-false
 (member
  'output-object-without-lift
  (map support-factorization-failure-kind
       (support-exactness-result-failures
        (support-factorization-comparison-degree-2 shortcut/composite)))))
(define arrow-lift-failures
  (filter
   (lambda (failure)
     (eq? (support-factorization-failure-kind failure)
          'arrow-unique-lift-failure))
   (support-exactness-result-failures
    (support-factorization-comparison-degree-3 shortcut/composite))))
(check-not-equal? arrow-lift-failures '())
(check-true
 (for/or ([failure (in-list arrow-lift-failures)])
   (define arrow (support-factorization-failure-target failure))
   (and (support-factorization-arrow? arrow)
        (eq? (support-factorization-arrow-source arrow) composite-middle)
        (eq? (support-factorization-arrow-target arrow) composite-whole))))

;; 4. Leak then purify.  The composite P->P edge is explicitly split into
;; its P-intermediate part and Xi; this fixture has one Xi witness and no
;; direct P-intermediate contribution.
(define pure-lift
  (support-factorization-category-object-at-ideal chain-category '((1 1))))
(define impure-lift
  (support-factorization-category-object-at-ideal
   chain-category '((1) (1 1))))
(check-equal? (support-factorization-object-sector pure-lift) 'P)
(check-equal? (support-factorization-object-sector impure-lift) 'Q)
(define leak-profile
  (make-support-factorization-profile
   chain-category chain-category
   (list
    (make-support-factorization-relation-pair
     pure-lift impure-lift
     (support-factorization-object-native-witness impure-lift)))))
(define purify-profile
  (make-support-factorization-profile
   chain-category chain-category
   (list
    (make-support-factorization-relation-pair
     impure-lift pure-lift
     (support-factorization-object-native-witness pure-lift)))))
(check-equal? (length (support-factorization-profile-qp leak-profile)) 1)
(check-equal? (length (support-factorization-profile-pq purify-profile)) 1)
(define excursion
  (compose-support-factorization-profiles leak-profile purify-profile))
(check-true
 (support-factorization-inconclusive?
  (compose-support-factorization-profiles
   leak-profile purify-profile #:limit 0)))
(check-equal? (length (support-profile-composition-pp excursion)) 1)
(check-equal? (support-profile-composition-pp-direct excursion) '())
(check-equal? (length (support-profile-composition-excursions excursion)) 1)
(check-eq?
 (support-composite-edge-intermediate
  (car (support-profile-composition-excursions excursion)))
 impure-lift)
(check-true
 (cut-witness?
  (support-profile-edge-evidence
   (support-composite-edge-first
    (car (support-profile-composition-excursions excursion))))))

;; 5. Copy and drop retain native relations but cannot be certified as one
;; strict externally-linear functor.
(define copy-summary
  (compile-macro-summary
   calculus
   (checked (raw-app 'support-copy raw-hole raw-hole) P)
   (list x-port)
   (list (cons '(1) 'x) (cons '(2) 'x))))
(define drop-port (make-macro-port 'x P #:allow-zero-use? #t))
(define drop-summary
  (compile-macro-summary
   calculus (checked (raw-app 'support-drop) P)
   (list drop-port) '()))
(define nonlinear-profile
  (make-material-profile calculus (list leaf-occ copy-occ drop-occ)))
(define copy-audit
  (audit-support-factorization-macro
   copy-summary 'x leaf nonlinear-profile #:limit 64))
(define drop-audit
  (audit-support-factorization-macro
   drop-summary 'x leaf nonlinear-profile #:limit 64))
(check-equal? (support-macro-audit-status copy-audit)
              'relation/profile-only)
(check-equal? (support-macro-audit-status drop-audit)
              'relation/profile-only)
(check-false (support-macro-audit-externally-linear? copy-audit))
(check-false (support-macro-audit-externally-linear? drop-audit))
(check-equal? (macro-summary-occurrence-addresses copy-summary 'x)
              '((1) (2)))
(check-equal?
 (map support-occurrence-address
      (filter
       (lambda (occurrence)
         (eq? (support-occurrence-occurrence occurrence) leaf-occ))
       (support-factorization-category-occurrences
        (support-macro-audit-target-category copy-audit))))
 '((1) (2)))

;; Opaque incidence is unsupported, never treated as an empty relation.
(define opaque-summary
  (compile-macro-summary
   calculus (checked (raw-app 'support-opaque raw-hole) P)
   (list x-port) (list (cons '(1) 'x))))
(define opaque-audit
  (audit-support-factorization-macro
   opaque-summary 'x leaf identity-profile #:limit 32))
(check-equal? (support-macro-audit-status opaque-audit)
              'unsupported-opaque-incidence)
(check-not-false (member 'opaque-incidence
                         (support-macro-audit-reasons opaque-audit)))

;; 6. Provenance and truncation are rejected/reported before certification.
(define foreign-calculus (make-equipped-calculus occurrences))
(define foreign-leaf
  (checked (raw-app 'support-leaf) P #:calculus foreign-calculus))
(check-exn
 exn:fail?
 (lambda ()
   (compile-support-factorization-category
    foreign-leaf identity-profile #:limit 8)))
(define truncated
  (compile-support-factorization-category
   chain interval-profile #:limit 1))
(check-true (support-factorization-inconclusive? truncated))
(check-equal? (support-factorization-inconclusive-operation truncated)
              'compile-support-factorization-category)

(displayln
 "support-factorization: interval, exact identity, degree-3 obstruction, excursion, nonlinear, provenance, and truncation checks passed")
