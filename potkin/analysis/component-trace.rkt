#lang racket/base

(require racket/list
         "ancestry.rkt"
         "../kernel/address.rkt"
         "../kernel/boundary.rkt"
         "../kernel/calculus.rkt"
         "../kernel/check.rkt"
         "../kernel/component-incidence.rkt"
         "../kernel/context.rkt"
         "../kernel/cut.rkt")

(provide (struct-out component-analysis-unavailable)
         (struct-out component-trace-blocker)
         (struct-out component-trace-input)
         (struct-out addressed-component)
         (struct-out component-trace-edge)
         (struct-out component-trace)
         (struct-out component-trace-unavailable)
         component-trace-result?
         component-trace-result-inputs
         component-trace-result-sources
         component-trace-result-output
         component-trace-result-targets
         component-trace-result-known-edges
         component-trace-of
         component-trace-compose
         component-trace-functional?
         component-trace-inverse-functional?
         component-trace-total?
         component-trace-surjective?
         (struct-out component-relation-classification)
         classify-component-relation
         (struct-out local-component-analysis)
         (struct-out component-scalar-analysis)
         occurrence-proof-factor-defect
         occurrence-hypersequent-defect
         derivation-proof-factor-defect
         derivation-hypersequent-defect
         derivation-scalar-analysis
         (struct-out ck-component-profile)
         cut-witness->ck-component-profile
         component-profiles-of
         ck-component-profile-final-corolla-law
         (struct-out component-analysis)
         component-analysis-of)

;; Unknown legacy incidence is data, not a negative relational answer.
(struct component-analysis-unavailable (reason details) #:transparent)
(struct component-trace-blocker (address occurrence-id) #:transparent)
(struct component-trace-input (address boundary) #:transparent)
(struct addressed-component (address component) #:transparent)
(struct component-trace-edge (source target) #:transparent)

;; A known trace records its entire typed domain and codomain, including
;; isolated sources and targets.  Its edge list is therefore allowed to be
;; genuinely empty without being confused with unavailable incidence.
(struct component-trace (inputs sources output targets edges) #:transparent)
(struct component-trace-unavailable
  (inputs sources output targets blockers known-edges)
  #:transparent)

(struct component-relation-classification
  (functional?
   inverse-functional?
   total?
   surjective?
   splitting?
   merger?
   erasure?
   unsupported-creation?)
  #:transparent)

(struct local-component-analysis
  (address occurrence relation classification proof-factor-defect
           hypersequent-defect)
  #:transparent)

(struct component-scalar-analysis
  (proof-factor-total
   proof-factor-expected
   proof-factor-euler-holds?
   hypersequent-total
   hypersequent-expected
   hypersequent-euler-holds?)
  #:transparent)

(struct ck-component-profile
  (witness
   addresses
   detached
   puncture-telescope
   remainder
   source-components
   output-components
   trace
   reconstruction
   reconstructs?)
  #:transparent)

(struct component-analysis
  (local-relations scalar-analysis net-trace ck-profiles)
  #:transparent)

(define (component-trace-result? value)
  (or (component-trace? value) (component-trace-unavailable? value)))

(define (component-trace-result-inputs value)
  (cond
    [(component-trace? value) (component-trace-inputs value)]
    [(component-trace-unavailable? value)
     (component-trace-unavailable-inputs value)]
    [else
     (raise-argument-error
      'component-trace-result-inputs "component-trace-result?" value)]))

(define (component-trace-result-sources value)
  (cond
    [(component-trace? value) (component-trace-sources value)]
    [(component-trace-unavailable? value)
     (component-trace-unavailable-sources value)]
    [else
     (raise-argument-error
      'component-trace-result-sources "component-trace-result?" value)]))

(define (component-trace-result-output value)
  (cond
    [(component-trace? value) (component-trace-output value)]
    [(component-trace-unavailable? value)
     (component-trace-unavailable-output value)]
    [else
     (raise-argument-error
      'component-trace-result-output "component-trace-result?" value)]))

(define (component-trace-result-targets value)
  (cond
    [(component-trace? value) (component-trace-targets value)]
    [(component-trace-unavailable? value)
     (component-trace-unavailable-targets value)]
    [else
     (raise-argument-error
      'component-trace-result-targets "component-trace-result?" value)]))

(define (component-trace-result-known-edges value)
  (cond
    [(component-trace? value) (component-trace-edges value)]
    [(component-trace-unavailable? value)
     (component-trace-unavailable-known-edges value)]
    [else
     (raise-argument-error
      'component-trace-result-known-edges "component-trace-result?" value)]))

(define (component-at boundary index)
  (list-ref (hypersequent-components boundary) (sub1 index)))

(define (inputs-at term prefix)
  (for/list ([entry (in-list (premise-telescope term))])
    (component-trace-input
     (address-append prefix (telescope-entry-address entry))
     (telescope-entry-requirement entry))))

(define (sources-of-inputs inputs)
  (append-map
   (lambda (input)
     (for/list ([component
                 (in-list
                  (hypersequent-components
                   (component-trace-input-boundary input)))])
       (addressed-component
        (component-trace-input-address input)
        component)))
   inputs))

(define (addressed-component<? left right)
  (define left-address (addressed-component-address left))
  (define right-address (addressed-component-address right))
  (cond
    [(equal? left-address right-address)
     (< (component-occurrence-index
         (addressed-component-component left))
        (component-occurrence-index
         (addressed-component-component right)))]
    [else (address<? left-address right-address)]))

(define (trace-edge<? left right)
  (define left-source (component-trace-edge-source left))
  (define right-source (component-trace-edge-source right))
  (cond
    [(equal? left-source right-source)
     (< (component-occurrence-index (component-trace-edge-target left))
        (component-occurrence-index (component-trace-edge-target right)))]
    [else (addressed-component<? left-source right-source)]))

(define (canonical-trace-edges edges)
  (sort (remove-duplicates edges equal?) trace-edge<?))

(define (open-path-blockers term prefix)
  (define punctures (puncture-addresses term))
  (sort
   (for/list ([address (in-list (vertex-addresses term))]
              #:when
              (and
               (ormap (lambda (puncture) (address-prefix? address puncture))
                      punctures)
               (not
                (component-incidence?
                 (concrete-occurrence-incidence
                  (checked-node-occurrence
                   (vertex-at-address term address)))))))
     (define node (vertex-at-address term address))
     (component-trace-blocker
      (address-append prefix address)
      (concrete-occurrence-id (checked-node-occurrence node))))
   (lambda (left right)
     (address<? (component-trace-blocker-address left)
                (component-trace-blocker-address right)))))

(define (known-trace-at term prefix)
  (define output (derivation-root-boundary term))
  (define targets (hypersequent-components output))
  (cond
    [(checked-hole? term)
     (define input (component-trace-input prefix output))
     (define sources (sources-of-inputs (list input)))
     (component-trace
      (list input)
      sources
      output
      targets
      (for/list ([source (in-list sources)]
                 [target (in-list targets)])
        (component-trace-edge source target)))]
    [(derivation-complete? term)
     ;; A complete subtree has no external component inputs.  Opaque local
     ;; incidence inside it therefore cannot be reverse-engineered from its
     ;; (known empty-domain) external trace.
     (component-trace '() '() output targets '())]
    [else
     (define occurrence (checked-node-occurrence term))
     (define incidence (concrete-occurrence-incidence occurrence))
     (define child-traces
       (for/list ([child (in-list (checked-node-children term))]
                  [slot (in-naturals 1)])
         (known-trace-at child (address-append prefix (list slot)))))
     (define inputs (append-map component-trace-inputs child-traces))
     (define sources (append-map component-trace-sources child-traces))
     (define edges
       (append-map
        (lambda (slot+trace)
          (define slot (car slot+trace))
          (define child-trace (cdr slot+trace))
          (append-map
           (lambda (child-edge)
             (define child-target-index
               (component-occurrence-index
                (component-trace-edge-target child-edge)))
             (for/list
                 ([local-edge
                   (in-list (component-incidence-edges incidence))]
                  #:when
                  (and
                   (= slot (component-edge-premise-slot local-edge))
                   (= child-target-index
                      (component-edge-source-index local-edge))))
               (component-trace-edge
                (component-trace-edge-source child-edge)
                (component-at
                 output
                 (component-edge-target-index local-edge)))))
           (component-trace-edges child-trace)))
        (for/list ([child-trace (in-list child-traces)]
                   [slot (in-naturals 1)])
          (cons slot child-trace))))
     (component-trace
      inputs
      (sort sources addressed-component<?)
      output
      targets
      (canonical-trace-edges edges))]))

;; Even an unavailable trace can retain edges whose entire path is typed.
;; These are a safe partial observation, not a completion of an opaque local
;; relation.  Retaining them lets insertion discard blockers that cease to
;; lie on the resulting external frontier without losing unrelated branches.
(define (partial-trace-edges-at term prefix)
  (define output (derivation-root-boundary term))
  (cond
    [(checked-hole? term)
     (for/list ([component
                 (in-list (hypersequent-components output))])
       (component-trace-edge
        (addressed-component prefix component)
        component))]
    [(derivation-complete? term) '()]
    [else
     (define occurrence (checked-node-occurrence term))
     (define incidence (concrete-occurrence-incidence occurrence))
     (if (not (component-incidence? incidence))
         '()
         (canonical-trace-edges
          (append-map
           (lambda (slot+child)
             (define slot (car slot+child))
             (define child (cdr slot+child))
             (append-map
              (lambda (child-edge)
                (define child-target-index
                  (component-occurrence-index
                   (component-trace-edge-target child-edge)))
                (for/list
                    ([local-edge
                      (in-list (component-incidence-edges incidence))]
                     #:when
                     (and
                      (= slot (component-edge-premise-slot local-edge))
                      (= child-target-index
                         (component-edge-source-index local-edge))))
                  (component-trace-edge
                   (component-trace-edge-source child-edge)
                   (component-at
                    output
                    (component-edge-target-index local-edge)))))
              (partial-trace-edges-at
               child (address-append prefix (list slot)))))
           (for/list ([child (in-list (checked-node-children term))]
                      [slot (in-naturals 1)])
             (cons slot child)))))]))

(define (component-trace-of term)
  (unless (checked-term? term)
    (raise-argument-error 'component-trace-of "checked-term?" term))
  (define inputs (inputs-at term root-address))
  (define sources (sources-of-inputs inputs))
  (define output (derivation-root-boundary term))
  (define targets (hypersequent-components output))
  (define blockers (open-path-blockers term root-address))
  (if (pair? blockers)
      (component-trace-unavailable
       inputs sources output targets blockers
       (partial-trace-edges-at term root-address))
      (known-trace-at term root-address)))

(define (prefix-input prefix input)
  (component-trace-input
   (address-append prefix (component-trace-input-address input))
   (component-trace-input-boundary input)))

(define (prefix-source prefix source)
  (addressed-component
   (address-append prefix (addressed-component-address source))
   (addressed-component-component source)))

(define (prefix-edge prefix edge)
  (component-trace-edge
   (prefix-source prefix (component-trace-edge-source edge))
   (component-trace-edge-target edge)))

(define (component-trace-compose outer puncture-address replacement)
  (unless (component-trace-result? outer)
    (raise-argument-error
     'component-trace-compose "component-trace-result? outer" outer))
  (unless (address? puncture-address)
    (raise-argument-error
     'component-trace-compose "address? puncture-address" puncture-address))
  (unless (component-trace-result? replacement)
    (raise-argument-error
     'component-trace-compose
     "component-trace-result? replacement"
     replacement))
  (define selected
    (findf
     (lambda (input)
       (equal? puncture-address (component-trace-input-address input)))
     (component-trace-result-inputs outer)))
  (unless selected
    (raise-arguments-error
     'component-trace-compose
     "the address must name an input of the outer trace"
     "address" puncture-address))
  (unless
      (equal? (component-trace-input-boundary selected)
              (component-trace-result-output replacement))
    (raise-arguments-error
     'component-trace-compose
     "the replacement output must equal the selected input boundary"
     "required" (component-trace-input-boundary selected)
     "replacement output" (component-trace-result-output replacement)))
  (define retained-inputs
    (filter
     (lambda (input)
       (not (equal? puncture-address
                    (component-trace-input-address input))))
     (component-trace-result-inputs outer)))
  (define inserted-inputs
    (map (lambda (input) (prefix-input puncture-address input))
         (component-trace-result-inputs replacement)))
  (define inputs
    (sort (append retained-inputs inserted-inputs)
          (lambda (left right)
            (address<? (component-trace-input-address left)
                       (component-trace-input-address right)))))
  (define sources (sources-of-inputs inputs))
  (define retained-edges
    (filter
     (lambda (edge)
       (not
        (equal? puncture-address
                (addressed-component-address
                 (component-trace-edge-source edge)))))
     (component-trace-result-known-edges outer)))
  (define composed-edges
    (append-map
     (lambda (replacement-edge)
       (define prefixed-source
         (prefix-source
          puncture-address
          (component-trace-edge-source replacement-edge)))
       (define replacement-target
         (component-trace-edge-target replacement-edge))
       (for/list
           ([outer-edge
             (in-list (component-trace-result-known-edges outer))]
            #:when
            (let ([outer-source (component-trace-edge-source outer-edge)])
              (and
               (equal? puncture-address
                       (addressed-component-address outer-source))
               (= (component-occurrence-index
                   (addressed-component-component outer-source))
                  (component-occurrence-index replacement-target)))))
         (component-trace-edge
          prefixed-source
          (component-trace-edge-target outer-edge))))
     (component-trace-result-known-edges replacement)))
  (define known-edges
    (canonical-trace-edges (append retained-edges composed-edges)))
  (define outer-blockers
    (if (component-trace-unavailable? outer)
        (component-trace-unavailable-blockers outer)
        '()))
  (define replacement-blockers
    (if (component-trace-unavailable? replacement)
        (for/list
            ([blocker
              (in-list
               (component-trace-unavailable-blockers replacement))])
          (component-trace-blocker
           (address-append
            puncture-address
            (component-trace-blocker-address blocker))
           (component-trace-blocker-occurrence-id blocker)))
        '()))
  (define relevant-blockers
    (filter
     (lambda (blocker)
       (ormap
        (lambda (input)
          (address-prefix?
           (component-trace-blocker-address blocker)
           (component-trace-input-address input)))
        inputs))
     (sort (remove-duplicates
            (append outer-blockers replacement-blockers)
            equal?)
           (lambda (left right)
             (address<? (component-trace-blocker-address left)
                        (component-trace-blocker-address right))))))
  (if (null? relevant-blockers)
      (component-trace
       inputs
       sources
       (component-trace-result-output outer)
       (component-trace-result-targets outer)
       known-edges)
     (component-trace-unavailable
      inputs
      sources
      (component-trace-result-output outer)
      (component-trace-result-targets outer)
      relevant-blockers
      known-edges)))

(define (check-known-trace who trace)
  (unless (component-trace? trace)
    (raise-argument-error who "component-trace?" trace)))

(define (component-trace-functional? trace)
  (check-known-trace 'component-trace-functional? trace)
  (for/and ([source (in-list (component-trace-sources trace))])
    (<= (length
         (remove-duplicates
          (for/list ([edge (in-list (component-trace-edges trace))]
                     #:when (equal? source (component-trace-edge-source edge)))
            (component-trace-edge-target edge))
          equal?))
        1)))

(define (component-trace-inverse-functional? trace)
  (check-known-trace 'component-trace-inverse-functional? trace)
  (for/and ([target (in-list (component-trace-targets trace))])
    (<= (length
         (remove-duplicates
          (for/list ([edge (in-list (component-trace-edges trace))]
                     #:when (equal? target (component-trace-edge-target edge)))
            (component-trace-edge-source edge))
          equal?))
        1)))

(define (component-trace-total? trace)
  (check-known-trace 'component-trace-total? trace)
  (for/and ([source (in-list (component-trace-sources trace))])
    (ormap (lambda (edge) (equal? source (component-trace-edge-source edge)))
           (component-trace-edges trace))))

(define (component-trace-surjective? trace)
  (check-known-trace 'component-trace-surjective? trace)
  (for/and ([target (in-list (component-trace-targets trace))])
    (ormap (lambda (edge) (equal? target (component-trace-edge-target edge)))
           (component-trace-edges trace))))

(define (classification functional? inverse-functional? total? surjective?)
  (component-relation-classification
   functional?
   inverse-functional?
   total?
   surjective?
   (not functional?)
   (not inverse-functional?)
   (not total?)
   (not surjective?)))

(define (classify-component-relation relation)
  (cond
    [(component-incidence? relation)
     (classification
      (component-incidence-functional? relation)
      (component-incidence-inverse-functional? relation)
      (component-incidence-total? relation)
      (component-incidence-surjective? relation))]
    [(component-trace? relation)
     (classification
      (component-trace-functional? relation)
      (component-trace-inverse-functional? relation)
      (component-trace-total? relation)
      (component-trace-surjective? relation))]
    [(or (component-analysis-unavailable? relation)
         (component-trace-unavailable? relation))
     relation]
    [else
     (raise-argument-error
      'classify-component-relation
      "(or/c component-incidence? component-trace? component-analysis-unavailable? component-trace-unavailable?)"
      relation)]))

(define (occurrence-proof-factor-defect occurrence)
  (unless (concrete-occurrence? occurrence)
    (raise-argument-error
     'occurrence-proof-factor-defect "concrete-occurrence?" occurrence))
  (- 1 (occurrence-arity occurrence)))

(define (occurrence-hypersequent-defect occurrence)
  (unless (concrete-occurrence? occurrence)
    (raise-argument-error
     'occurrence-hypersequent-defect "concrete-occurrence?" occurrence))
  (- (hypersequent-size (concrete-occurrence-conclusion occurrence))
     (for/sum
         ([premise (in-vector (concrete-occurrence-premises occurrence))])
       (hypersequent-size premise))))

(define (derivation-proof-factor-defect term)
  (unless (checked-term? term)
    (raise-argument-error
     'derivation-proof-factor-defect "checked-term?" term))
  (for/sum ([address (in-list (vertex-addresses term))])
    (occurrence-proof-factor-defect
     (checked-node-occurrence (vertex-at-address term address)))))

(define (derivation-hypersequent-defect term)
  (unless (checked-term? term)
    (raise-argument-error
     'derivation-hypersequent-defect "checked-term?" term))
  (for/sum ([address (in-list (vertex-addresses term))])
    (occurrence-hypersequent-defect
     (checked-node-occurrence (vertex-at-address term address)))))

(define (derivation-scalar-analysis term)
  (unless (checked-term? term)
    (raise-argument-error
     'derivation-scalar-analysis "checked-term?" term))
  (define proof-total (derivation-proof-factor-defect term))
  (define proof-expected (- 1 (length (premise-telescope term))))
  (define hypersequent-total (derivation-hypersequent-defect term))
  (define hypersequent-expected
    (- (hypersequent-size (derivation-root-boundary term))
       (for/sum ([entry (in-list (premise-telescope term))])
         (hypersequent-size (telescope-entry-requirement entry)))))
  (component-scalar-analysis
   proof-total
   proof-expected
   (= proof-total proof-expected)
   hypersequent-total
   hypersequent-expected
   (= hypersequent-total hypersequent-expected)))

(define (local-component-table term)
  (for/list ([address (in-list (vertex-addresses term))])
    (define occurrence
      (checked-node-occurrence (vertex-at-address term address)))
    (define incidence (concrete-occurrence-incidence occurrence))
    (define relation
      (if (component-incidence? incidence)
          incidence
          (component-analysis-unavailable
           'legacy-opaque-incidence
           (hash 'address address
                 'occurrence-id (concrete-occurrence-id occurrence)))))
    (local-component-analysis
     address
     occurrence
     relation
     (classify-component-relation relation)
     (occurrence-proof-factor-defect occurrence)
     (occurrence-hypersequent-defect occurrence))))

(define (cut-witness->ck-component-profile witness)
  (unless (cut-witness? witness)
    (raise-argument-error
     'cut-witness->ck-component-profile "cut-witness?" witness))
  (unless (complete-proof? (cut-witness-source witness))
    (raise-arguments-error
     'cut-witness->ck-component-profile
     "the witness source must be a connected complete proof"
     "source" (cut-witness-source witness)))
  (when (null? (cut-witness-addresses witness))
    (raise-arguments-error
     'cut-witness->ck-component-profile
     "component profiles are defined only for nonempty CK cuts"
     "addresses" (cut-witness-addresses witness)))
  (define detached (cut-witness-detached witness))
  (define source-components
    (append-map
     (lambda (entry)
       (for/list
           ([component
             (in-list
              (hypersequent-components
               (derivation-root-boundary (detached-entry-term entry))))])
         (addressed-component (detached-entry-address entry) component)))
     detached))
  (define source (cut-witness-source witness))
  (define remainder (cut-witness-remainder witness))
  (define reconstruction (reconstruct-cut-witness witness))
  (ck-component-profile
   witness
   (cut-witness-addresses witness)
   detached
   (premise-telescope remainder)
   remainder
   source-components
   (hypersequent-components (derivation-root-boundary source))
   (component-trace-of remainder)
   reconstruction
   (equal? reconstruction source)))

(define (component-profiles-of term #:limit [limit #f])
  (unless (complete-proof? term)
    (raise-argument-error 'component-profiles-of "complete-proof?" term))
  (unless (or (not limit) (exact-nonnegative-integer? limit))
    (raise-argument-error
     'component-profiles-of
     "(or/c #f exact-nonnegative-integer?)"
     limit))
  (let/ec stop
    (define count 0)
    (reverse
     (for/fold ([profiles '()])
               ([witness (in-admissible-cut-witnesses term)]
                #:unless (null? (cut-witness-addresses witness)))
       (set! count (add1 count))
       (when (and limit (> count limit))
         (stop
          (analysis-limit
           'not-computed-limit
           "the exact component-profile family exceeds its configured finite limit"
           'component-profiles-of
           limit
           count
           'component-profile-count
           (hash 'required-at-least count))))
       (cons (cut-witness->ck-component-profile witness) profiles)))))

(define (ck-component-profile-final-corolla-law profile)
  (unless (ck-component-profile? profile)
    (raise-argument-error
     'ck-component-profile-final-corolla-law
     "ck-component-profile?"
     profile))
  (define source (cut-witness-source (ck-component-profile-witness profile)))
  (define occurrence (checked-node-occurrence source))
  (define arity (occurrence-arity occurrence))
  (define immediate-addresses
    (for/list ([slot (in-range 1 (add1 arity))]) (list slot)))
  (cond
    [(zero? arity)
     (component-analysis-unavailable 'nullary-final-occurrence (hash))]
    [(not (equal? immediate-addresses
                  (ck-component-profile-addresses profile)))
     (component-analysis-unavailable
      'not-the-full-immediate-child-cut
      (hash 'expected immediate-addresses
            'actual (ck-component-profile-addresses profile)))]
    [(not (component-incidence?
           (concrete-occurrence-incidence occurrence)))
     (component-analysis-unavailable
      'legacy-opaque-incidence
      (hash 'occurrence-id (concrete-occurrence-id occurrence)))]
    [(not (component-trace? (ck-component-profile-trace profile)))
     (ck-component-profile-trace profile)]
    [else
     (define incidence (concrete-occurrence-incidence occurrence))
     (define expected
       (canonical-trace-edges
        (for/list ([edge (in-list (component-incidence-edges incidence))])
          (component-trace-edge
           (addressed-component
            (list (component-edge-premise-slot edge))
            (component-at
             (occurrence-premise
              occurrence (component-edge-premise-slot edge))
             (component-edge-source-index edge)))
           (component-at
            (concrete-occurrence-conclusion occurrence)
            (component-edge-target-index edge))))))
     (equal? expected
             (component-trace-edges
              (ck-component-profile-trace profile)))]))

(define (component-analysis-of term #:profile-limit [profile-limit #f])
  (unless (checked-term? term)
    (raise-argument-error 'component-analysis-of "checked-term?" term))
  (component-analysis
   (local-component-table term)
   (derivation-scalar-analysis term)
   (component-trace-of term)
   (if (complete-proof? term)
       (component-profiles-of term #:limit profile-limit)
       (component-analysis-unavailable
        (if (checked-hole? term) 'nodeless-box 'incomplete-context)
        (hash 'operation 'component-profiles-of)))))
