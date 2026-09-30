#lang racket/base

(require rackunit
         racket/list
         "../potkin/main.rkt"
         "../potkin/analysis/ancestry.rkt"
         "../potkin/analysis/communication-float.rkt"
         "../potkin/analysis/material-context-transport.rkt"
         "../potkin/analysis/material-stock.rkt")

(define (ifo id formula)
  (make-indexed-formula-occurrence id formula))

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

(define (context-occurrence id premises conclusion)
  (make-concrete-occurrence
   id premises conclusion
   #:kind 'logical
   #:tag 'one-hole-context-fixture
   #:instance (list 'native-context id)
   #:incidence (make-component-incidence premises conclusion '())))

(define (atomic-boundary atom)
  (make-hypersequent (list (make-sequent '() (list atom)))))

;; One genuine checked Communication float.  Under B, Q=k(g) is old stock and
;; e is not; under C, e is added to the same immutable registry profile.
(define layout
  (make-communication-layout
   '() '()
   (list (ifo 'gamma 'U))
   (list (ifo 'gamma-prime 'V))
   (list (ifo 'lambda 'U))
   (list (ifo 'lambda-prime 'V))
   'R 'R))

(define shape
  (prepare-communication-float-shape
   layout (make-communication-iw-action (ifo 'iw-copy 'W) 'gamma)))

(define input-boundary (communication-layout-left-boundary layout))
(define output-boundary
  (communication-layout-conclusion
   (communication-float-shape-after-layout shape)))

(define g-occurrence (ground-occurrence 'transport-g input-boundary '(base g)))
(define k-occurrence
  (make-concrete-occurrence
   'transport-k (list input-boundary) input-boundary
   #:kind 'logical
   #:tag 'derived-ground-wrapper
   #:instance '(k-of-g)
   #:incidence
   (make-component-incidence
    (list input-boundary) input-boundary
    (list (make-component-edge 1 1 1)))))
(define e-occurrence (ground-occurrence 'transport-e input-boundary '(fresh e)))
(define source-iw
  (occurrence-from-profile
   'transport-source-iw
   (communication-float-shape-source-structural-profile shape)))
(define source-com
  (occurrence-from-profile
   'transport-source-com
   (communication-float-shape-source-communication-profile shape)))
(define target-com
  (occurrence-from-profile
   'transport-target-com
   (communication-float-shape-target-communication-profile shape)))
(define target-iw
  (occurrence-from-profile
   'transport-target-iw
   (communication-float-shape-target-structural-profile shape)))

;; The first context is genuinely nested.  Its inner constructor has a
;; material off-spine sibling; the outer unary constructor adds another spine
;; level without changing the (1+z) side factor at t=1.
(define side-boundary (atomic-boundary 'Side))
(define mid-boundary (atomic-boundary 'Mid))
(define final-boundary (atomic-boundary 'Final))
(define side-occurrence
  (ground-occurrence 'transport-side side-boundary '(material side)))
(define nested-pair
  (context-occurrence
   'transport-nested-pair
   (list output-boundary side-boundary) mid-boundary))
(define nested-top
  (context-occurrence
   'transport-nested-top (list mid-boundary) final-boundary))

;; A same-shape context at the original input boundary witnesses the purity
;; change when its filling is changed from e to Q.
(define eq-mid-boundary (atomic-boundary 'EQ-Mid))
(define eq-final-boundary (atomic-boundary 'EQ-Final))
(define eq-pair
  (context-occurrence
   'transport-eq-pair
   (list input-boundary side-boundary) eq-mid-boundary))
(define eq-top
  (context-occurrence
   'transport-eq-top (list eq-mid-boundary) eq-final-boundary))
(define purity-final-boundary (atomic-boundary 'Purity-Final))
(define purity-root
  (context-occurrence
   'transport-purity-root
   (list input-boundary) purity-final-boundary))

(define occurrences
  (list g-occurrence k-occurrence e-occurrence
        source-iw source-com target-com target-iw
        side-occurrence nested-pair nested-top eq-pair eq-top purity-root))
(define K (make-equipped-calculus occurrences))

(define (checked id expected . children)
  (define result
    (validate-candidate
     K (apply raw-app id (map checked-term->raw children))
     #:expected expected))
  (check-true (checked-node? result))
  result)

(define g (checked 'transport-g input-boundary))
(define Q (checked 'transport-k input-boundary g))
(define e (checked 'transport-e input-boundary))
(define side (checked 'transport-side side-boundary))

(define nested-context
  (validate-candidate
   K
   (raw-app
    'transport-nested-top
    (raw-app 'transport-nested-pair raw-hole (checked-term->raw side)))
   #:expected final-boundary))
(define eq-context
  (validate-candidate
   K
   (raw-app
    'transport-eq-top
    (raw-app 'transport-eq-pair raw-hole (checked-term->raw side)))
   #:expected eq-final-boundary))
(define inner-context
  (validate-candidate
   K
   (raw-app 'transport-nested-pair raw-hole (checked-term->raw side))
   #:expected mid-boundary))
(define outer-context
  (validate-candidate
   K (raw-app 'transport-nested-top raw-hole)
   #:expected final-boundary))
(define pure-unary-context
  (validate-candidate
   K (raw-app 'transport-purity-root raw-hole)
   #:expected purity-final-boundary))
(for ([context
       (in-list
        (list nested-context eq-context inner-context outer-context
              pure-unary-context))])
  (check-true (proof-context? context))
  (check-equal? (length (puncture-addresses context)) 1))

(define C-profile (make-material-profile K occurrences))
(define B-profile
  (make-material-profile K (remove e-occurrence occurrences eq?)))
(check-eq? (material-profile-calculus B-profile)
           (material-profile-calculus C-profile))
(for ([occurrence (in-list (material-profile-occurrences B-profile))])
  (check-true (material-profile-designates? C-profile occurrence)))
(check-false (material-profile-designates? B-profile e-occurrence))
(check-true (material-profile-designates? C-profile e-occurrence))

(define (certify profile)
  (certify-communication-float
   K shape Q e profile
   #:source-structural source-iw
   #:source-communication source-com
   #:target-communication target-com
   #:target-structural target-iw
   #:limit 128))

(define float-B (certify B-profile))
(define float-C (certify C-profile))
(for ([certificate (in-list (list float-B float-C))])
  (check-true (communication-float-certificate? certificate))
  (check-true (communication-float-certificate-verified? certificate)))

(define source
  (communication-float-certificate-source float-B))
(define target
  (communication-float-certificate-target float-B))
(check-equal? source (communication-float-certificate-source float-C))
(check-equal? target (communication-float-certificate-target float-C))

(define nested-B
  (transport-material-coaction-difference
   nested-context source target B-profile #:limit 512))
(define nested-C
  (transport-material-coaction-difference
   nested-context source target C-profile #:limit 512))
(for ([certificate (in-list (list nested-B nested-C))])
  (check-true (material-context-transport-certificate? certificate))
  (check-true
   (material-context-transport-certificate-verified? certificate))
  (check-equal?
   (material-context-transport-certificate-predicted-state certificate)
   (material-context-transport-certificate-actual-state certificate))
  (check-equal?
   (length (material-context-transport-certificate-matrices certificate))
   2))

;; The local all-material z^2 difference acquires exactly the material side
;; factor (1+z); B retains the previously certified leading z distinction.
(define (factor-p state)
  (material-polynomial-at-t=1 (material-coaction-state-p state)))
(check-equal?
 (factor-p (material-context-transport-certificate-local-state nested-B))
 (hash 1 1))
(check-equal?
 (factor-p (material-context-transport-certificate-actual-state nested-B))
 (hash 1 1 2 1))
(check-equal?
 (factor-p (material-context-transport-certificate-local-state nested-C))
 (hash 2 1))
(check-equal?
 (factor-p (material-context-transport-certificate-actual-state nested-C))
 (hash 2 1 3 1))

(define first-C-matrix
  (car (material-context-transport-certificate-matrices nested-C)))
(check-equal?
 (material-polynomial-at-t=1
  (material-context-matrix-off-spine-full-polynomial first-C-matrix))
 (hash 0 1 1 1))

;; Ordered context composition agrees exactly: first fill/transport through
;; the binary context, then through its unary parent, versus the one-shot
;; nested context.  This comparison includes native tensor coordinates, not
;; merely scalar counts.
(define inner-C
  (transport-material-coaction-difference
   inner-context source target C-profile #:limit 512))
(check-true (material-context-transport-certificate? inner-C))
(define two-stage-C
  (transport-material-coaction-difference
   outer-context
   (material-context-transport-certificate-source-filling inner-C)
   (material-context-transport-certificate-target-filling inner-C)
   C-profile
   #:limit 512))
(check-true (material-context-transport-certificate? two-stage-C))
(check-true (material-context-transport-certificate-verified? two-stage-C))
(check-equal?
 (material-context-transport-certificate-source-filling two-stage-C)
 (material-context-transport-certificate-source-filling nested-C))
(check-equal?
 (material-context-transport-certificate-target-filling two-stage-C)
 (material-context-transport-certificate-target-filling nested-C))
(check-equal?
 (material-context-side-certificate-full-coaction
  (material-context-transport-certificate-source-side two-stage-C))
 (material-context-side-certificate-full-coaction
  (material-context-transport-certificate-source-side nested-C)))
(check-equal?
 (material-context-side-certificate-full-coaction
  (material-context-transport-certificate-target-side two-stage-C))
 (material-context-side-certificate-full-coaction
  (material-context-transport-certificate-target-side nested-C)))
(check-equal?
 (material-context-transport-certificate-transported-difference two-stage-C)
 (material-context-transport-certificate-transported-difference nested-C))

;; Although their scalar whole weights cancel, the source and target native
;; whole endpoints remain distinct tensors with their distinct checked roots.
(define nested-C-source-whole
  (material-context-side-certificate-whole-endpoint
   (material-context-transport-certificate-source-side nested-C)))
(define nested-C-target-whole
  (material-context-side-certificate-whole-endpoint
   (material-context-transport-certificate-target-side nested-C)))
(check-false (formal-zero? nested-C-source-whole))
(check-false (formal-zero? nested-C-target-whole))
(check-not-equal? nested-C-source-whole nested-C-target-whole)

;; Changing e -> Q under B beneath one pure unary rule changes q.  The child
;; root cut and the separately projected outer whole endpoint become eligible,
;; so the complete selected difference Q-minus-e is exactly 3z.
(define e-to-Q
  (transport-material-coaction-difference
   pure-unary-context Q e B-profile #:limit 128))
(check-true (material-context-transport-certificate? e-to-Q))
(check-true (material-context-transport-certificate-verified? e-to-Q))
(define e-to-Q-local
  (material-context-transport-certificate-local-state e-to-Q))
(check-not-equal? (material-coaction-state-q e-to-Q-local) (hash))
(define e-to-Q-first-matrix
  (car (material-context-transport-certificate-matrices e-to-Q)))
(define upper-right-effect
  (let ([upper
         (material-context-matrix-upper-right e-to-Q-first-matrix)])
    ;; Apply only the upper-right entry to (0,q).
    (material-coaction-state-p
     (apply-material-context-matrix
      e-to-Q-first-matrix
      (material-coaction-state (hash) (material-coaction-state-q e-to-Q-local))))))
(check-not-equal? upper-right-effect (hash))
(define (hash-add left right)
  (for/fold ([result left]) ([(key coefficient) (in-hash right)])
    (hash-update result key (lambda (old) (+ old coefficient)) 0)))
(define (factor-full state)
  (hash-add
   (factor-p state)
   (for/hash ([(degree coefficient)
               (in-hash
                (material-polynomial-at-t=1
                 (material-coaction-state-q state)))])
     (values (add1 degree) coefficient))))
(check-equal?
 (factor-full (material-context-transport-certificate-actual-state e-to-Q))
 (hash 1 3))

;; Bounded independent oracle: enumerate native witnesses only here, on the
;; completed fixtures, and rebuild the exact selected tensor sum.
(define (bounded-oracle proof profile)
  (define index (prepare-material-stock-index proof profile #:limit 512))
  (check-false (analysis-limit? index))
  (define result
    (indexed-material-query
     index (make-material-all-query #:include-whole-endpoint? #t)))
  (make-formal-sum
   K 2
   (for/list ([contribution
               (in-list (material-query-result-contributions result))])
     (cons (material-contribution-tensor contribution) 1))))

(for ([certificate (in-list (list nested-B nested-C e-to-Q))])
  (define profile
    (material-context-transport-certificate-profile certificate))
  (for ([side-certificate
         (in-list
          (list (material-context-transport-certificate-source-side certificate)
                (material-context-transport-certificate-target-side certificate)))])
    (check-equal?
     (material-context-side-certificate-full-coaction side-certificate)
     (bounded-oracle
      (material-context-side-certificate-proof side-certificate) profile))))

;; Collected tensors do not supply addresses.  The certificate separately
;; retains an existing native proper witness, its ordered detached tuple and
;; typed remainder, and checks native reconstruction.
(define addressed
  (findf
   (lambda (witness) (equal? (cut-witness-addresses witness) '((1))))
   (material-context-side-certificate-proper-witnesses
    (material-context-transport-certificate-source-side e-to-Q))))
(check-true (cut-witness? addressed))
(check-equal? (cut-witness-addresses addressed) '((1)))
(check-equal? (map detached-entry-address (cut-witness-detached addressed))
              (cut-witness-addresses addressed))
(check-equal? (puncture-addresses (cut-witness-remainder addressed))
              (cut-witness-addresses addressed))
(check-true (cut-witness-reconstructs? addressed))
(check-equal? (reconstruct-cut-witness addressed)
              (cut-witness-source addressed))
(check-equal?
 (complete-fill
  (cut-witness-remainder addressed)
  (map detached-entry-term (cut-witness-detached addressed)))
 (material-context-transport-certificate-source-filling e-to-Q))

;; A structurally equal profile in another immutable registry is rejected;
;; B subset C above used two exact profiles of K, never a snapshot cast.
(define foreign-K (make-equipped-calculus occurrences))
(define foreign-profile (make-material-profile foreign-K occurrences))
(define foreign-result
  (transport-material-coaction-difference
   nested-context source target foreign-profile #:limit 64))
(check-true (material-context-transport-failure? foreign-result))
(check-equal? (material-context-transport-failure-code foreign-result)
              'foreign-profile)

(displayln
 "material-context-transport: native pointed recurrence, matrix, nesting, exact B/C profiles, addressed reconstruction, and bounded oracle passed")
