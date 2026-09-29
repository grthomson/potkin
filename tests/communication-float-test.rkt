#lang racket/base

(require rackunit
         racket/list
         "../potkin/main.rkt"
         "../potkin/analysis/communication-float.rkt")

(define (ifo id formula)
  (make-indexed-formula-occurrence id formula))

(define (passive id left right)
  (make-named-passive-component id (make-sequent left right)))

(define (occurrence-from-profile id profile)
  (make-concrete-occurrence
   id
   (communication-occurrence-profile-premises profile)
   (communication-occurrence-profile-conclusion profile)
   #:kind 'structural
   #:tag (communication-occurrence-profile-role profile)
   #:instance (communication-occurrence-profile-instance profile)
   #:incidence (communication-occurrence-profile-incidence profile)))

(define (ground-occurrence id boundary instance)
  (make-concrete-occurrence
   id '() boundary
   #:kind 'material
   #:tag 'ground
   #:instance instance
   #:incidence (make-component-incidence '() boundary '())))

;; --------------------------------------------------------------------------
;; Passive IW and the two active IW routes share one unmodified Com profile.

(define main-layout
  (make-communication-layout
   (list (passive 'named-P '(p-resource) '(p-result)))
   (list (passive 'named-Q '(q-resource) '(q-result)))
   (list (ifo 'gamma-1 'G))
   (list (ifo 'gamma-prime-1 'G-prime))
   (list (ifo 'lambda-1 'L))
   (list (ifo 'lambda-prime-1 'L-prime))
   'A
   'B))

(define passive-shape
  (prepare-communication-float-shape
   main-layout
   (make-communication-iw-action
    (ifo 'iw-passive-copy 'W-passive)
    (make-communication-passive-route 'named-P))))

(define gamma-shape
  (prepare-communication-float-shape
   main-layout
   (make-communication-iw-action (ifo 'iw-gamma-copy 'W-active) 'gamma)))

(define gamma-prime-shape
  (prepare-communication-float-shape
   main-layout
   (make-communication-iw-action
    (ifo 'iw-gamma-prime-copy 'W-active-prime)
    'gamma-prime)))

(define main-x-occurrence
  (ground-occurrence
   'float-main-x
   (communication-layout-left-boundary main-layout)
   '(main-left-ground)))
(define main-y-occurrence
  (ground-occurrence
   'float-main-y
   (communication-layout-right-boundary main-layout)
   '(main-right-ground)))

(define main-target-com
  (occurrence-from-profile
   'float-main-target-com
   (communication-float-shape-target-communication-profile passive-shape)))

(define passive-source-iw
  (occurrence-from-profile
   'float-passive-source-iw
   (communication-float-shape-source-structural-profile passive-shape)))
(define passive-source-com
  (occurrence-from-profile
   'float-passive-source-com
   (communication-float-shape-source-communication-profile passive-shape)))
(define passive-target-iw
  (occurrence-from-profile
   'float-passive-target-iw
   (communication-float-shape-target-structural-profile passive-shape)))

(define gamma-source-iw
  (occurrence-from-profile
   'float-gamma-source-iw
   (communication-float-shape-source-structural-profile gamma-shape)))
(define gamma-source-com
  (occurrence-from-profile
   'float-gamma-source-com
   (communication-float-shape-source-communication-profile gamma-shape)))
(define gamma-target-iw
  (occurrence-from-profile
   'float-gamma-target-iw
   (communication-float-shape-target-structural-profile gamma-shape)))

(define gamma-prime-source-iw
  (occurrence-from-profile
   'float-gamma-prime-source-iw
   (communication-float-shape-source-structural-profile gamma-prime-shape)))
(define gamma-prime-source-com
  (occurrence-from-profile
   'float-gamma-prime-source-com
   (communication-float-shape-source-communication-profile gamma-prime-shape)))
(define gamma-prime-target-iw
  (occurrence-from-profile
   'float-gamma-prime-target-iw
   (communication-float-shape-target-structural-profile gamma-prime-shape)))

;; --------------------------------------------------------------------------
;; Same-route and split-route IC use two distinct IDs with equal formulae.

(define same-ic-layout
  (make-communication-layout
   '() '()
   (list (ifo 'same-c-1 'C) (ifo 'same-c-2 'C))
   (list (ifo 'same-gp 'D))
   (list (ifo 'same-l 'L))
   (list (ifo 'same-lp 'LP))
   'IC-A 'IC-B))

(define same-ic-shape
  (prepare-communication-float-shape
   same-ic-layout
   (make-communication-ic-action 'same-c-1 'same-c-2)))

(define same-ic-x-occurrence
  (ground-occurrence
   'float-same-ic-x
   (communication-layout-left-boundary same-ic-layout)
   '(same-ic-left-ground)))
(define same-ic-y-occurrence
  (ground-occurrence
   'float-same-ic-y
   (communication-layout-right-boundary same-ic-layout)
   '(same-ic-right-ground)))
(define same-source-ic
  (occurrence-from-profile
   'float-same-source-ic
   (communication-float-shape-source-structural-profile same-ic-shape)))
(define same-source-com
  (occurrence-from-profile
   'float-same-source-com
   (communication-float-shape-source-communication-profile same-ic-shape)))
(define same-target-com
  (occurrence-from-profile
   'float-same-target-com
   (communication-float-shape-target-communication-profile same-ic-shape)))
(define same-target-ic
  (occurrence-from-profile
   'float-same-target-ic
   (communication-float-shape-target-structural-profile same-ic-shape)))

(define split-ic-layout
  (make-communication-layout
   '() '()
   (list (ifo 'split-c-1 'C))
   (list (ifo 'split-c-2 'C))
   (list (ifo 'split-l 'L))
   (list (ifo 'split-lp 'LP))
   'SPLIT-A 'SPLIT-B))

(define split-ic-shape
  (prepare-communication-float-shape
   split-ic-layout
   (make-communication-ic-action 'split-c-1 'split-c-2)))
(define split-ic-x-occurrence
  (ground-occurrence
   'float-split-ic-x
   (communication-layout-left-boundary split-ic-layout)
   '(split-ic-left-ground)))
(define split-ic-y-occurrence
  (ground-occurrence
   'float-split-ic-y
   (communication-layout-right-boundary split-ic-layout)
   '(split-ic-right-ground)))
(define split-source-ic
  (occurrence-from-profile
   'float-split-source-ic
   (communication-float-shape-source-structural-profile split-ic-shape)))
(define split-source-com
  (occurrence-from-profile
   'float-split-source-com
   (communication-float-shape-source-communication-profile split-ic-shape)))
(define split-target-com
  (occurrence-from-profile
   'float-split-target-com
   (communication-float-shape-target-communication-profile split-ic-shape)))

;; --------------------------------------------------------------------------
;; Q=k(g) and the fresh equal-boundary ground e.

(define extension-layout
  (make-communication-layout
   '() '()
   (list (ifo 'extension-gamma 'U))
   (list (ifo 'extension-gamma-prime 'V))
   (list (ifo 'extension-lambda 'U))
   (list (ifo 'extension-lambda-prime 'V))
   'R 'R))

(define extension-shape
  (prepare-communication-float-shape
   extension-layout
   (make-communication-iw-action (ifo 'extension-iw 'W) 'gamma)))

(define extension-boundary
  (communication-layout-left-boundary extension-layout))
(check-equal? extension-boundary
              (communication-layout-right-boundary extension-layout))

(define g-occurrence
  (ground-occurrence 'float-extension-g extension-boundary '(base g)))
(define k-occurrence
  (make-concrete-occurrence
   'float-extension-k
   (list extension-boundary)
   extension-boundary
   #:kind 'logical
   #:tag 'derived-ground-wrapper
   #:instance '(k-of-g)
   #:incidence
   (let ([edge (make-component-edge 1 1 1)])
     (make-component-incidence
      (list extension-boundary) extension-boundary (list edge)))))
(define e-occurrence
  (ground-occurrence 'float-extension-e extension-boundary '(fresh base e)))
(define extension-source-iw
  (occurrence-from-profile
   'float-extension-source-iw
   (communication-float-shape-source-structural-profile extension-shape)))
(define extension-source-com
  (occurrence-from-profile
   'float-extension-source-com
   (communication-float-shape-source-communication-profile extension-shape)))
(define extension-target-com
  (occurrence-from-profile
   'float-extension-target-com
   (communication-float-shape-target-communication-profile extension-shape)))
(define extension-target-iw
  (occurrence-from-profile
   'float-extension-target-iw
   (communication-float-shape-target-structural-profile extension-shape)))

;; Exact negative instances: neither an old succedent swap, opaque incidence,
;; nor a misleading instance payload can establish standard Communication.
(define target-com-profile
  (communication-float-shape-target-communication-profile passive-shape))
(define target-com-premises
  (communication-occurrence-profile-premises target-com-profile))
(define swap-conclusion
  (hypersequent-union (first target-com-premises)
                      (second target-com-premises)))
(define bad-swap-com
  (make-concrete-occurrence
   'float-bad-succedent-swap
   target-com-premises swap-conclusion
   #:kind 'structural
   #:instance (communication-occurrence-profile-instance target-com-profile)
   #:incidence
   (make-component-incidence target-com-premises swap-conclusion '())))
(define bad-opaque-com
  (make-concrete-occurrence
   'float-bad-opaque-com
   target-com-premises
   (communication-occurrence-profile-conclusion target-com-profile)
   #:kind 'structural
   #:instance (communication-occurrence-profile-instance target-com-profile)
   #:incidence 'opaque-component-action))
(define bad-instance-com
  (make-concrete-occurrence
   'float-bad-instance-com
   target-com-premises
   (communication-occurrence-profile-conclusion target-com-profile)
   #:kind 'structural
   #:instance '(succedent-swap-by-name)
   #:incidence (communication-occurrence-profile-incidence target-com-profile)))

(define all-occurrences
  (list
   main-x-occurrence main-y-occurrence main-target-com
   passive-source-iw passive-source-com passive-target-iw
   gamma-source-iw gamma-source-com gamma-target-iw
   gamma-prime-source-iw gamma-prime-source-com gamma-prime-target-iw
   same-ic-x-occurrence same-ic-y-occurrence
   same-source-ic same-source-com same-target-com same-target-ic
   split-ic-x-occurrence split-ic-y-occurrence
   split-source-ic split-source-com split-target-com
   g-occurrence k-occurrence e-occurrence
   extension-source-iw extension-source-com
   extension-target-com extension-target-iw
   bad-swap-com bad-opaque-com bad-instance-com))

(define K (make-equipped-calculus all-occurrences))

(define (checked id expected . children)
  (define result
    (validate-candidate
     K
     (apply raw-app id (map checked-term->raw children))
     #:expected expected))
  (check-true (checked-node? result))
  result)

(define main-x
  (checked 'float-main-x (communication-layout-left-boundary main-layout)))
(define main-y
  (checked 'float-main-y (communication-layout-right-boundary main-layout)))
(define same-ic-x
  (checked 'float-same-ic-x
           (communication-layout-left-boundary same-ic-layout)))
(define same-ic-y
  (checked 'float-same-ic-y
           (communication-layout-right-boundary same-ic-layout)))
(define split-ic-x
  (checked 'float-split-ic-x
           (communication-layout-left-boundary split-ic-layout)))
(define split-ic-y
  (checked 'float-split-ic-y
           (communication-layout-right-boundary split-ic-layout)))
(define g (checked 'float-extension-g extension-boundary))
(define Q (checked 'float-extension-k extension-boundary g))
(define e (checked 'float-extension-e extension-boundary))

(check-equal? (derivation-root-boundary Q) (derivation-root-boundary e))
(check-equal? (derivation-vertex-count Q) 2)
(check-equal? (derivation-vertex-count e) 1)

(define C-profile (make-material-profile K all-occurrences))
(define B-profile
  (make-material-profile K (remove e-occurrence all-occurrences eq?)))
(check-false (material-profile-designates? B-profile e-occurrence))
(check-true (material-profile-designates? C-profile e-occurrence))

(define (certify shape x y source-structural source-com target-com
                 target-structural [profile C-profile])
  (certify-communication-float
   K shape x y profile
   #:source-structural source-structural
   #:source-communication source-com
   #:target-communication target-com
   #:target-structural target-structural
   #:limit 128))

(define passive-certificate
  (certify passive-shape main-x main-y
           passive-source-iw passive-source-com main-target-com
           passive-target-iw))
(define gamma-certificate
  (certify gamma-shape main-x main-y
           gamma-source-iw gamma-source-com main-target-com gamma-target-iw))
(define gamma-prime-certificate
  (certify gamma-prime-shape main-x main-y
           gamma-prime-source-iw gamma-prime-source-com main-target-com
           gamma-prime-target-iw))
(define same-ic-certificate
  (certify same-ic-shape same-ic-x same-ic-y
           same-source-ic same-source-com same-target-com same-target-ic))

(define accepted
  (list passive-certificate gamma-certificate
        gamma-prime-certificate same-ic-certificate))

(for ([certificate (in-list accepted)])
  (check-true (communication-float-certificate? certificate))
  (check-true (communication-float-certificate-verified? certificate))
  (check-true (complete-proof? (communication-float-certificate-source certificate)))
  (check-true (complete-proof? (communication-float-certificate-target certificate)))
  (check-true
   (checked-term-has-exact-calculus?
    (communication-float-certificate-source certificate) K))
  (check-true
   (checked-term-has-exact-calculus?
    (communication-float-certificate-target certificate) K))
  (check-equal?
   (derivation-root-boundary
    (communication-float-certificate-source certificate))
   (derivation-root-boundary
    (communication-float-certificate-target certificate)))
  (check-equal?
   (communication-float-certificate-actual-factor-difference certificate)
   (hash 2 1))
  (check-equal?
   (communication-float-certificate-predicted-factor-difference certificate)
   (hash 2 1))
  (check-equal?
   (communication-float-certificate-actual-bigraded-difference certificate)
   (hash (list 1 2) 1 (list 1 3) -1 (list 2 3) 1))
  (check-true
   (communication-float-certificate-negative-bigraded-coefficient?
    certificate))
  (for ([audit
         (in-list
          (list (communication-float-certificate-source-audit certificate)
                (communication-float-certificate-target-audit certificate)
                (communication-float-certificate-y-audit certificate)))])
    (check-true (communication-side-audit-verified? audit))
    (check-equal? (communication-side-audit-coaction audit)
                  (communication-side-audit-reconstructed-coaction audit))
    (check-equal?
     (communication-side-audit-ordinary-factor-polynomial audit)
     (communication-side-audit-witness-factor-polynomial audit))
    (check-equal?
     (communication-side-audit-ordinary-bigraded-polynomial audit)
     (communication-side-audit-witness-bigraded-polynomial audit))
    (check-equal?
     (length (communication-side-audit-empty-contributions audit)) 1)
    (check-equal?
     (length (communication-side-audit-whole-contributions audit)) 1)
    (check-false
     (material-contribution-witness
      (car (communication-side-audit-whole-contributions audit))))
    (check-equal?
     (cut-witness-addresses
      (material-contribution-witness
       (car (communication-side-audit-empty-contributions audit))))
     '())
    (for ([witness (in-list (communication-side-audit-witnesses audit))])
      (check-true (cut-witness-reconstructs? witness))
      (check-equal? (map detached-entry-address
                         (cut-witness-detached witness))
                    (cut-witness-addresses witness))
      (check-equal? (puncture-addresses (cut-witness-remainder witness))
                    (cut-witness-addresses witness))))
  (for ([audit
         (in-list
          (list (communication-float-certificate-source-audit certificate)
                (communication-float-certificate-target-audit certificate)))])
    (check-true
     (pair? (communication-side-audit-proper-contributions audit)))))

;; The two active weakenings route the new formula to different outputs.
(check-equal? (communication-float-shape-routes passive-shape)
              '((passive named-P) (passive named-P)))
(check-equal? (communication-float-shape-routes gamma-shape)
              '(gamma left-output))
(check-equal? (communication-float-shape-routes gamma-prime-shape)
              '(gamma-prime right-output))
(define gamma-final
  (communication-layout-conclusion
   (communication-float-shape-after-layout gamma-shape)))
(define gamma-prime-final
  (communication-layout-conclusion
   (communication-float-shape-after-layout gamma-prime-shape)))
(check-true
 (for/or ([component (in-list (hypersequent-sequents gamma-final))])
   (and (positive? (formula-context-count (sequent-left component) 'W-active))
        (positive? (formula-context-count (sequent-right component) 'A)))))
(check-true
 (for/or ([component (in-list (hypersequent-sequents gamma-prime-final))])
   (and (positive?
         (formula-context-count (sequent-left component) 'W-active-prime))
        (positive? (formula-context-count (sequent-right component) 'B)))))

;; Same-route IC is certified; split routing rejects only this one-step square.
(check-equal? (communication-float-shape-status same-ic-shape) 'accepted)
(check-equal? (communication-float-shape-routes same-ic-shape)
              '((gamma gamma) (left-output left-output)))
(check-equal? (communication-float-shape-status split-ic-shape)
              'split-contraction-routes)
(define split-result
  (certify-communication-float
   K split-ic-shape split-ic-x split-ic-y C-profile
   #:source-structural split-source-ic
   #:source-communication split-source-com
   #:target-communication split-target-com
   #:limit 128))
(check-true (communication-float-rejection? split-result))
(check-equal? (communication-float-rejection-code split-result)
              'split-contraction-routes)
(check-equal? (communication-float-rejection-routes split-result)
              '(left-output right-output))
(check-equal?
 (hash-ref (communication-float-rejection-details split-result) 'scope)
 "only the proposed one-step IC float is rejected")

;; The same checked Q/e float changes only the exact base selector.
(define extension-B
  (certify extension-shape Q e
           extension-source-iw extension-source-com extension-target-com
           extension-target-iw B-profile))
(define extension-C
  (certify extension-shape Q e
           extension-source-iw extension-source-com extension-target-com
           extension-target-iw C-profile))
(for ([certificate (in-list (list extension-B extension-C))])
  (check-true (communication-float-certificate? certificate))
  (check-true (communication-float-certificate-verified? certificate)))
(check-equal? (communication-float-certificate-epsilon-x extension-B) 1)
(check-equal? (communication-float-certificate-epsilon-y extension-B) 0)
(check-equal? (communication-float-certificate-epsilon-y extension-C) 1)
(for ([occurrence
       (in-list
        (list extension-source-iw extension-source-com
              extension-target-com extension-target-iw))])
  (check-true (material-profile-designates? B-profile occurrence)))
(check-equal?
 (communication-float-certificate-actual-factor-difference extension-B)
 (hash 1 1))
(check-equal?
 (communication-float-certificate-actual-factor-difference extension-C)
 (hash 2 1))
(check-equal?
 (length
  (communication-side-audit-whole-contributions
   (communication-float-certificate-y-audit extension-B)))
 0)
(check-equal?
 (length
  (communication-side-audit-whole-contributions
   (communication-float-certificate-y-audit extension-C)))
 1)

;; Exact failures: foreign proof provenance, absent registry occurrence, old
;; succedent swap, opaque incidence, and a misleading instance payload.
(define foreign-K (make-equipped-calculus all-occurrences))
(define foreign-main-x
  (validate-candidate
   foreign-K (raw-app 'float-main-x)
   #:expected (communication-layout-left-boundary main-layout)))
(define foreign-result
  (certify-communication-float
   K passive-shape foreign-main-x main-y C-profile
   #:source-structural passive-source-iw
   #:source-communication passive-source-com
   #:target-communication main-target-com
   #:target-structural passive-target-iw
   #:limit 128))
(check-true (communication-float-failure? foreign-result))
(check-equal? (communication-float-failure-code foreign-result)
              'foreign-provenance)

(define missing-source-iw
  (occurrence-from-profile
   'float-unregistered-source-iw
   (communication-float-shape-source-structural-profile passive-shape)))
(define (bad-target-com-result occurrence)
  (certify-communication-float
   K passive-shape main-x main-y C-profile
   #:source-structural passive-source-iw
   #:source-communication passive-source-com
   #:target-communication occurrence
   #:target-structural passive-target-iw
   #:limit 128))
(define missing-result
  (certify-communication-float
   K passive-shape main-x main-y C-profile
   #:source-structural missing-source-iw
   #:source-communication passive-source-com
   #:target-communication main-target-com
   #:target-structural passive-target-iw
   #:limit 128))
(check-equal? (communication-float-failure-code missing-result)
              'missing-exact-instance)
(check-equal? (communication-float-failure-code
               (bad-target-com-result bad-swap-com))
              'wrong-entire-conclusion-boundary)
(check-equal? (communication-float-failure-code
               (bad-target-com-result bad-opaque-com))
              'missing-typed-incidence)
(check-equal? (communication-float-failure-code
               (bad-target-com-result bad-instance-com))
              'wrong-indexed-instance)

(displayln
 "communication-float: passive/active IW, same/split IC, native CK reconstruction, scalar coactions, and B/C selector checks passed")
