#lang racket/base

(require racket/list
         racket/port
         racket/string
         rackunit
         "../potkin/main.rkt"
         "component-fixtures.rkt"
         (prefix-in old: "kernel-fixtures.rkt"))

(define (trace-edge-triples trace)
  (for/list ([edge (in-list (component-trace-edges trace))])
    (list
     (addressed-component-address (component-trace-edge-source edge))
     (component-occurrence-index
      (addressed-component-component
       (component-trace-edge-source edge)))
     (component-occurrence-index (component-trace-edge-target edge)))))

(define (incidence-edge-triples incidence)
  (for/list ([edge (in-list (component-incidence-edges incidence))])
    (list (list (component-edge-premise-slot edge))
          (component-edge-source-index edge)
          (component-edge-target-index edge))))

;; Box is the typed identity relation, including at its root address ().
(define left-box (identity-context component-calculus left-boundary))
(define left-box-trace (component-trace-of left-box))
(check-true (component-trace? left-box-trace))
(check-equal? (map component-trace-input-address
                   (component-trace-inputs left-box-trace))
              '(()))
(check-equal? (trace-edge-triples left-box-trace) '((() 1 1)))
(check-true (component-trace-functional? left-box-trace))
(check-true (component-trace-inverse-functional? left-box-trace))
(check-true (component-trace-total? left-box-trace))
(check-true (component-trace-surjective? left-box-trace))
(check-true
 (component-incidence-total?
  (concrete-occurrence-incidence left-ground-occurrence)))
(check-false
 (component-incidence-surjective?
  (concrete-occurrence-incidence left-ground-occurrence)))

;; A full-premise corolla exposes exactly its supplied local relation after
;; premise slots are re-read as one-step puncture addresses.
(define communication-corolla
  (corolla component-calculus communication-occurrence))
(define assembly-corolla
  (corolla component-calculus assembly-occurrence))
(define communication-corolla-trace
  (component-trace-of communication-corolla))
(define assembly-corolla-trace (component-trace-of assembly-corolla))
(check-true (component-trace? communication-corolla-trace))
(check-equal? (trace-edge-triples communication-corolla-trace)
              (incidence-edge-triples communication-incidence))
(check-equal? (trace-edge-triples assembly-corolla-trace)
              (incidence-edge-triples assembly-incidence))

(define communication-classification
  (classify-component-relation communication-incidence))
(check-false
 (component-relation-classification-functional?
  communication-classification))
(check-false
 (component-relation-classification-inverse-functional?
  communication-classification))
(check-true
 (component-relation-classification-total?
  communication-classification))
(check-true
 (component-relation-classification-surjective?
  communication-classification))

(define assembly-classification
  (classify-component-relation assembly-incidence))
(check-true
 (component-relation-classification-functional?
  assembly-classification))
(check-true
 (component-relation-classification-inverse-functional?
  assembly-classification))
(check-true
 (component-relation-classification-total?
  assembly-classification))
(check-true
 (component-relation-classification-surjective?
  assembly-classification))

;; Context composition prefixes the replacement address q by the selected
;; outer address p.  Here p=(1), q=(1), hence p++q=(1 1).
(define unary-incidence
  (make-component-incidence
   (list left-boundary)
   left-boundary
   (list (make-component-edge 1 1 1))))
(define unary-occurrence
  (make-concrete-occurrence
   'component-unary
   (list left-boundary)
   left-boundary
   #:incidence unary-incidence))
(define unary-calculus (make-equipped-calculus (list unary-occurrence)))
(define unary-corolla (corolla unary-calculus unary-occurrence))
(define nested-unary
  (context-insert unary-corolla '(1) unary-corolla))
(check-true (checked-node? nested-unary))
(define nested-direct (component-trace-of nested-unary))
(define nested-composed
  (component-trace-compose
   (component-trace-of unary-corolla)
   '(1)
   (component-trace-of unary-corolla)))
(check-equal? nested-direct nested-composed)
(check-equal? (map component-trace-input-address
                   (component-trace-inputs nested-direct))
              '((1 1)))
(check-equal? (trace-edge-triples nested-direct) '(((1 1) 1 1)))

;; Opaque incidence on an open path is explicitly unknown.  An opaque
;; complete sibling is not on that path and does not poison a known trace.
(define opaque-unary
  (make-concrete-occurrence
   'opaque-unary (list left-boundary) left-boundary))
(define opaque-unary-calculus
  (make-equipped-calculus (list opaque-unary)))
(define opaque-trace
  (component-trace-of (corolla opaque-unary-calculus opaque-unary)))
(check-true (component-trace-unavailable? opaque-trace))
(check-equal?
 (map component-trace-blocker-address
      (component-trace-unavailable-blockers opaque-trace))
 '(()))
(check-exn exn:fail:contract?
           (lambda () (component-trace-functional? opaque-trace)))

(define opaque-ground
  (make-concrete-occurrence
   'opaque-complete-sibling '() left-boundary #:kind 'material))
(define typed-binary
  (make-concrete-occurrence
   'typed-binary
   (list left-boundary left-boundary)
   left-boundary
   #:incidence
   (make-component-incidence
    (list left-boundary left-boundary)
    left-boundary
    (list (make-component-edge 1 1 1)))))
(define sibling-calculus
  (make-equipped-calculus (list opaque-ground typed-binary)))
(define sibling-context
  (validate-candidate
   sibling-calculus
   (raw-app 'typed-binary raw-hole (raw-app 'opaque-complete-sibling))
   #:expected left-boundary))
(define sibling-trace (component-trace-of sibling-context))
(check-true (component-trace? sibling-trace))
(check-equal? (trace-edge-triples sibling-trace) '(((1) 1 1)))

;; Once an opaque path is completely filled it no longer belongs to the
;; external frontier.  Direct and trace-level composition both become the
;; known empty-domain trace rather than retaining a stale blocker.
(define opaque-fill-ground
  (make-concrete-occurrence
   'opaque-fill-ground
   '()
   left-boundary
   #:kind 'material
   #:incidence (make-component-incidence '() left-boundary '())))
(define opaque-fill-calculus
  (make-equipped-calculus (list opaque-unary opaque-fill-ground)))
(define opaque-outer (corolla opaque-fill-calculus opaque-unary))
(define opaque-filler
  (validate-candidate
   opaque-fill-calculus
   (raw-app 'opaque-fill-ground)
   #:expected left-boundary))
(define opaque-filled (context-insert opaque-outer '(1) opaque-filler))
(define opaque-filled-direct (component-trace-of opaque-filled))
(define opaque-filled-composed
  (component-trace-compose
   (component-trace-of opaque-outer)
   '(1)
   (component-trace-of opaque-filler)))
(check-true (component-trace? opaque-filled-direct))
(check-true (component-trace? opaque-filled-composed))
(check-equal? opaque-filled-direct opaque-filled-composed)
(check-equal? (component-trace-edges opaque-filled-composed) '())

;; Complete terms have known empty external domains even though their local
;; vertex tables retain informative component relations.
(define complete-communication-trace
  (component-trace-of communication-proof))
(check-true (component-trace? complete-communication-trace))
(check-equal? (component-trace-sources complete-communication-trace) '())
(check-equal? (component-trace-edges complete-communication-trace) '())
(define old-complete-trace (component-trace-of old:running-proof))
(check-true (component-trace? old-complete-trace))
(check-equal? (component-trace-edges old-complete-trace) '())
(check-true
 (component-analysis-unavailable?
  (local-component-analysis-relation
   (car (component-analysis-local-relations
         (component-analysis-of old:running-proof))))))

;; The scalar laws telescope over internal boundaries for both complete and
;; punctured connected terms.  They remain independent of incidence data.
(check-equal?
 (list (occurrence-proof-factor-defect communication-occurrence)
       (occurrence-hypersequent-defect communication-occurrence))
 '(-1 0))
(check-equal?
 (list (occurrence-proof-factor-defect assembly-occurrence)
       (occurrence-hypersequent-defect assembly-occurrence))
 '(-1 0))
(define communication-scalars
  (derivation-scalar-analysis communication-proof))
(check-equal?
 (list (component-scalar-analysis-proof-factor-total
        communication-scalars)
       (component-scalar-analysis-hypersequent-total
        communication-scalars))
 '(1 2))
(check-true
 (component-scalar-analysis-proof-factor-euler-holds?
  communication-scalars))
(check-true
 (component-scalar-analysis-hypersequent-euler-holds?
  communication-scalars))
(define corolla-scalars (derivation-scalar-analysis communication-corolla))
(check-equal?
 (list (component-scalar-analysis-proof-factor-total corolla-scalars)
       (component-scalar-analysis-proof-factor-expected corolla-scalars)
       (component-scalar-analysis-hypersequent-total corolla-scalars)
       (component-scalar-analysis-hypersequent-expected corolla-scalars))
 '(-1 -1 0 0))
(check-true
 (component-scalar-analysis-proof-factor-euler-holds? corolla-scalars))
(check-true
 (component-scalar-analysis-hypersequent-euler-holds? corolla-scalars))

;; Both flagship proofs have the same binary CK tree and detached premise
;; forest, but different connected roots and different component frontiers.
(for ([proof (in-list (list communication-proof assembly-proof))])
  (check-equal? (derivation-vertex-count proof) 3)
  (check-equal? (cut-size-polynomial (premise-ancestry-of proof))
                '#(0 2 1)))

(define communication-profiles
  (component-profiles-of communication-proof))
(define assembly-profiles (component-profiles-of assembly-proof))
(check-equal? (length communication-profiles) 3)
(check-equal? (length assembly-profiles) 3)
(check-equal? (length (component-profiles-of old:running-proof)) 4)
(define limited-profiles
  (component-profiles-of communication-proof #:limit 2))
(check-true (analysis-limit? limited-profiles))
(check-equal? (analysis-limit-metric limited-profiles)
              'component-profile-count)
(check-true
 (string-contains?
  (with-output-to-string (lambda () (write-analysis limited-profiles)))
  "not computed: limit"))
(check-false
 (ormap (lambda (profile)
          (null? (ck-component-profile-addresses profile)))
        communication-profiles))

(define (profile-at profiles addresses)
  (findf (lambda (profile)
           (equal? addresses (ck-component-profile-addresses profile)))
         profiles))

(define communication-immediate
  (profile-at communication-profiles immediate-cut-addresses))
(define assembly-immediate
  (profile-at assembly-profiles immediate-cut-addresses))
(check-true (ck-component-profile? communication-immediate))
(check-true (ck-component-profile? assembly-immediate))
(check-true
 (ck-component-profile-final-corolla-law communication-immediate))
(check-true (ck-component-profile-final-corolla-law assembly-immediate))
(check-equal?
 (cut-witness-forest (ck-component-profile-witness communication-immediate))
 (cut-witness-forest (ck-component-profile-witness assembly-immediate)))
(check-not-equal? (ck-component-profile-remainder communication-immediate)
                  (ck-component-profile-remainder assembly-immediate))
(check-not-equal? communication-proof assembly-proof)
(check-not-equal? (derivation-root-boundary communication-proof)
                  (derivation-root-boundary assembly-proof))
(check-not-equal?
 (cut-witness-forest (ck-component-profile-witness communication-immediate))
 communication-proof)
(check-not-equal?
 (cut-witness-forest (ck-component-profile-witness communication-immediate))
 assembly-proof)
(check-equal?
 (trace-edge-triples (ck-component-profile-trace communication-immediate))
 (incidence-edge-triples communication-incidence))
(check-equal?
 (trace-edge-triples (ck-component-profile-trace assembly-immediate))
 (incidence-edge-triples assembly-incidence))
(check-true (ck-component-profile-reconstructs? communication-immediate))
(check-true (ck-component-profile-reconstructs? assembly-immediate))

;; Addition-only lifting preserves the address-resolved profile after an
;; explicit provenance-changing lift.  Deleting a used occurrence instead
;; returns a liveness error, so no target profile is constructed or claimed.
(define fresh-addition
  (make-concrete-occurrence
   'component-fresh-addition
   '()
   left-boundary
   #:kind 'material
   #:incidence (make-component-incidence '() left-boundary '())))
(define persistent-revision
  (make-calculus-revision component-calculus '() (list fresh-addition)))
(define lifted-communication
  (lift-term persistent-revision communication-proof))
(check-true (checked-node? lifted-communication))
(check-true
 (eq? (checked-term-calculus lifted-communication)
      (calculus-revision-target persistent-revision)))
(define lifted-profiles (component-profiles-of lifted-communication))
(check-equal? (map ck-component-profile-addresses lifted-profiles)
              (map ck-component-profile-addresses communication-profiles))
(check-equal? (map ck-component-profile-trace lifted-profiles)
              (map ck-component-profile-trace communication-profiles))
(for ([source-profile (in-list communication-profiles)]
      [target-profile (in-list lifted-profiles)])
  (check-equal? (ck-component-profile-detached target-profile)
                (ck-component-profile-detached source-profile))
  (check-equal? (ck-component-profile-puncture-telescope target-profile)
                (ck-component-profile-puncture-telescope source-profile))
  (check-equal? (ck-component-profile-remainder target-profile)
                (ck-component-profile-remainder source-profile))
  (check-equal? (ck-component-profile-source-components target-profile)
                (ck-component-profile-source-components source-profile))
  (check-equal? (ck-component-profile-output-components target-profile)
                (ck-component-profile-output-components source-profile))
  (check-equal? (ck-component-profile-reconstruction target-profile)
                (ck-component-profile-reconstruction source-profile))
  (check-equal? (ck-component-profile-reconstructs? target-profile)
                (ck-component-profile-reconstructs? source-profile)))

(define deleting-revision
  (make-calculus-revision
   component-calculus '(component-left-ground) '()))
(define dead-lift (lift-term deleting-revision communication-proof))
(check-true (revision-error? dead-lift))
(check-equal? (revision-error-code dead-lift) 'inactive-occurrences)

;; The nested report keeps compatibility constructors intact while exposing
;; a separate deterministic component-analysis value.
(define report (analyze-derivation communication-proof))
(define nested-report (derivation-analysis-component-analysis report))
(check-true (component-analysis? nested-report))
(check-equal? (length (component-analysis-local-relations nested-report)) 3)
(check-equal? (length (component-analysis-ck-profiles nested-report)) 3)
(define rendered
  (with-output-to-string (lambda () (write-analysis report))))
(check-equal?
 rendered
 (with-output-to-string (lambda () (write-analysis report))))
(for ([fragment
       (in-list
        '("(component-analysis"
          "(ck-profile-count 3)"
          "(status known)"
          "(splitting? #t)"
          "(cut-addresses ((1) (2)))"))])
  (check-true (string-contains? rendered fragment)))

(define box-report (analyze-context left-box))
(define box-components (context-analysis-component-analysis box-report))
(check-true (component-analysis? box-components))
(check-equal? (trace-edge-triples
               (component-analysis-net-trace box-components))
              '((() 1 1)))

;; The original public report constructor remains renderable.  New reports
;; use the enriched subtype, while directly constructed compatibility values
;; receive an explicit unattached component-analysis marker.
(define compatibility-context-report
  (context-analysis
   left-box
   left-boundary
   (context-interface-of left-box)
   0
   (premise-telescope left-box)
   (analysis-unavailable 'compatibility-fixture (hash))))
(check-not-exn
 (lambda () (analysis->datum compatibility-context-report)))
