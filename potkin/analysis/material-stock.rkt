#lang racket/base

;; CK-native material-stock queries.
;;
;; A material profile explicitly names exact occurrence objects from one
;; equipped-calculus registry.  Nothing in this module infers materiality from
;; an occurrence ID, tag, kind, name, boundary, or incidence relation.
;; “Material” here therefore means observer-designated stock membership; it is
;; not the `kind`-based predicate used by constructor-repair policy.
;; Connected proofs retain their ordered children; opening evidence is always
;; an existing address-based `cut-witness`.  The whole-tree contribution is a
;; separately tagged algebraic endpoint and is never represented by a root cut.
;;
;; Correctness account (PROVED as a paper-level argument; its implementation
;; correspondence is CODE-CHECKED by differential tests).
;; Let W(t) be the finite sequence produced by
;; `in-admissible-cut-witnesses` for the checked source t.  The summary pass
;; records one summary per vertex, for the exact subtree rooted there,
;; whether every vertex occurrence belongs to the supplied material profile
;; and the additive resource demand of those occurrences.  A witness belongs
;; to the material stock exactly when every summary at one of its prefix-free
;; cut roots is material.  Prefix-freeness makes those selected subtrees
;; disjoint, so summing their summaries is exactly the demand of the retained
;; detached tuple, including repeated equal-looking occurrences.  Preparation
;; inserts that same witness once into the choice, forest, and tensor buckets;
;; it neither synthesises nor deduplicates witnesses.  Lookup only selects a
;; stored bucket and applies the same resource inequality.  Consequently it
;; neither invents nor loses a witness.  A tensor coefficient is the length of
;; its surviving occurrence-level contribution list.  A forest coefficient is
;; instead the marginal sum over all right remainders with that left forest,
;; and an all query reports total surviving mass.  Each therefore preserves
;; witness multiplicity.  The separately constructed whole endpoint satisfies
;; the analogous one-case statement and has no `cut-witness`.  Finally, under
;; one exact calculus and profile, equal left proof-forest keys contain the
;; same exact occurrence multiset, so every candidate in such a bucket has the
;; same material status and demand (and equal tensor keys are stronger).  This
;; is the lemma that permits one exact demand check for a prepared bucket.
;;
;; Complexity.  Write N for source vertices, P for the sum of source-address
;; lengths, D for the number of resource coordinates, W for native CK
;; witnesses, C_i for the actual native construction/profile cost of witness
;; i, H for total structural hash/key cost, and S for the retained native
;; witness/index representation.  The exact bounded cut-polynomial preflight
;; runs before enumeration.  Source summaries cost O(P + N*D).
;; Preparation costs O(P + N*D + sum_i C_i + H) and uses O(N*D + S) memory;
;; in particular, validation, prefix checks, address copying, and component
;; tracing are not treated as constant-time.  A direct forest or tensor query
;; repeats enumeration and detached-term scans with the corresponding summed
;; costs.  Prepared choice/forest/tensor count and existence lookup is expected
;; O(hash(q) + D), using Racket hash tables.  A full result over B matched
;; candidates costs O(hash(q) + B*D + output); constructing nonmaterial
;; blocker evidence can additionally scan N uses per rejected candidate.
;; Thus witness retrieval is output-sensitive in accepted and rejected
;; occurrence evidence, not merely accepted k.  An unbudgeted all query is
;; O(W + diagnostics), and a budgeted one O(W*D + diagnostics).  There is
;; deliberately no incremental-update API: changing the source, calculus
;; snapshot, material profile, or resource policy requires a full rebuild
;; with the preparation bound above.

(require racket/list
         racket/promise
         racket/vector
         "../kernel/address.rkt"
         "../kernel/calculus.rkt"
         "../kernel/check.rkt"
         "../kernel/component-incidence.rkt"
         "../kernel/context.rkt"
         "../kernel/cut.rkt"
         "ancestry.rkt"
         "component-trace.rkt")

(provide resource-vector?
         resource-vector-add
         resource-vector-subtract
         resource-vector-fits?
         resource-vector-deficit

         material-profile?
         make-material-profile
         material-profile-calculus
         material-profile-occurrences
         material-profile-dimensions
         material-profile-designates?
         material-profile-demand

         material-use?
         material-use-address
         material-use-term
         material-use-occurrence
         material-use-designated?
         material-use-own-demand
         material-use-subtree-material?
         material-use-subtree-demand
         material-use-subtree-vertex-count
         material-use-incidence
         material-module?
         material-module-address
         material-module-term
         material-module-vertex-count
         material-module-demand
         material-decomposition?
         material-decomposition-source
         material-decomposition-modules
         material-decomposition-maximum-module-size
         material-decomposition-vertex-count
         material-decomposition-material-use-count
         material-decomposition-blockers
         material-component-not-applicable?
         material-component-not-applicable-reason
         material-blocker?
         material-blocker-reason
         material-blocker-address
         material-blocker-occurrence
         material-blocker-details
         material-witness-contribution?
         material-witness-contribution-choice
         material-witness-contribution-witness
         material-witness-contribution-tensor
         material-witness-contribution-demand
         material-witness-contribution-component-profile
         material-whole-endpoint-contribution?
         material-whole-endpoint-contribution-choice
         material-whole-endpoint-contribution-source
         material-whole-endpoint-contribution-tensor
         material-whole-endpoint-contribution-demand
         material-whole-endpoint-contribution-component-status
         material-contribution?
         material-contribution-choice
         material-contribution-tensor
         material-contribution-demand
         material-contribution-witness
         material-query-rejection?
         material-query-rejection-choice
         material-query-rejection-witness
         material-query-rejection-demand
         material-query-rejection-blockers

         material-query?
         material-query-kind
         material-query-selector
         material-query-budget
         material-query-include-whole-endpoint?
         make-material-choice-query
         make-material-forest-query
         make-material-tensor-query
         make-material-all-query
         material-query-result?
         material-query-result-ancestry
         material-query-result-profile
         material-query-result-query
         material-query-result-contributions
         material-query-result-coefficient
         material-query-result-rejections
         material-query-result-available?
         material-query-result-witnesses
         material-query-result-blockers

         material-stock-index?
         material-stock-index-source
         material-stock-index-profile
         material-stock-index-ancestry
         material-stock-index-uses
         material-stock-index-vertex-count
         material-stock-index-ordinary-witness-count
         material-stock-index-material-witness-count
         prepare-material-stock-index

         direct-material-uses
         direct-material-decomposition
         indexed-material-decomposition
         direct-material-subtree-available?
         indexed-material-subtree-available?
         direct-material-query
         indexed-material-query
         direct-material-stock-count
         indexed-material-stock-count
         direct-material-available?
         indexed-material-available?
         direct-material-coefficient
         indexed-material-coefficient
         direct-material-tensor-coefficient
         indexed-material-tensor-coefficient
         direct-material-witnesses
         indexed-material-witnesses)

;; Resource coordinates are caller-declared consumable quantities.  They are
;; not formula occurrences, component traces, reusable locks, or proof rules.
(define (resource-vector? value)
  (and (list? value) (andmap exact-nonnegative-integer? value)))

(define (check-resource-pair who left right)
  (unless (and (resource-vector? left)
               (resource-vector? right)
               (= (length left) (length right)))
    (raise-arguments-error
     who
     "expected equal-dimensional lists of exact nonnegative integers"
     "left" left
     "right" right)))

(define (resource-vector-add left right)
  (check-resource-pair 'resource-vector-add left right)
  (map + left right))

(define (resource-vector-subtract available demand)
  (check-resource-pair 'resource-vector-subtract available demand)
  (and (andmap >= available demand)
       (map - available demand)))

(define (resource-vector-fits? demand available)
  (check-resource-pair 'resource-vector-fits? demand available)
  (andmap <= demand available))

(define (resource-vector-deficit demand available)
  (check-resource-pair 'resource-vector-deficit demand available)
  (map (lambda (required supplied) (max 0 (- required supplied)))
       demand available))

(define (zero-resource-vector dimensions)
  (make-list dimensions 0))

(struct material-profile
  (calculus occurrences dimensions demand-table occurrence-table)
  #:constructor-name make-material-profile/internal
  #:sealed)

(define (exact-registry-occurrence? calculus occurrence)
  (and (concrete-occurrence? occurrence)
       (eq? occurrence
            (calculus-lookup calculus (concrete-occurrence-id occurrence)))))

(define (copy-resource-vector value)
  (for/list ([coordinate (in-list value)]) coordinate))

(define (make-material-profile calculus occurrences
                               #:resource-dimensions [dimensions 0]
                               #:demands [demands '()])
  (unless (equipped-calculus? calculus)
    (raise-argument-error
     'make-material-profile "equipped-calculus?" calculus))
  (unless (and (list? occurrences)
               (andmap concrete-occurrence? occurrences))
    (raise-argument-error
     'make-material-profile "(listof concrete-occurrence?)" occurrences))
  (unless (exact-nonnegative-integer? dimensions)
    (raise-argument-error
     'make-material-profile "exact-nonnegative-integer?" dimensions))
  (unless (list? demands)
    (raise-argument-error 'make-material-profile "association list" demands))

  (define occurrence-table
    (for/fold ([table (hasheq)]) ([occurrence (in-list occurrences)])
      (unless (exact-registry-occurrence? calculus occurrence)
        (raise-arguments-error
         'make-material-profile
         "each material occurrence must be the exact object stored in the supplied registry"
         "occurrence" occurrence
         "calculus" calculus))
      (when (hash-has-key? table occurrence)
        (raise-arguments-error
         'make-material-profile
         "material occurrences must not be repeated"
         "occurrence" occurrence))
      (hash-set table occurrence #t)))

  (define demand-table
    (for/fold ([table (hasheq)]) ([entry (in-list demands)])
      (unless (and (pair? entry)
                   (concrete-occurrence? (car entry))
                   (resource-vector? (cdr entry)))
        (raise-arguments-error
         'make-material-profile
         "each demand entry must be an occurrence/resource-vector pair"
         "entry" entry))
      (define occurrence (car entry))
      (define demand (cdr entry))
      (unless (hash-has-key? occurrence-table occurrence)
        (raise-arguments-error
         'make-material-profile
         "a resource demand may be assigned only to a designated exact material occurrence"
         "occurrence" occurrence))
      (unless (= (length demand) dimensions)
        (raise-arguments-error
         'make-material-profile
         "a demand has the wrong resource dimension"
         "occurrence" occurrence
         "expected dimensions" dimensions
         "actual demand" demand))
      (when (hash-has-key? table occurrence)
        (raise-arguments-error
         'make-material-profile
         "an occurrence may have only one resource demand"
         "occurrence" occurrence))
      (hash-set table occurrence (copy-resource-vector demand))))

  (make-material-profile/internal
   calculus
   (for/list ([occurrence (in-list occurrences)]) occurrence)
   dimensions
   demand-table
   occurrence-table))

(define (material-profile-designates? profile occurrence)
  (unless (material-profile? profile)
    (raise-argument-error
     'material-profile-designates? "material-profile?" profile))
  (and (concrete-occurrence? occurrence)
       (hash-has-key? (material-profile-occurrence-table profile) occurrence)))

(define (material-profile-demand profile occurrence)
  (unless (material-profile? profile)
    (raise-argument-error 'material-profile-demand "material-profile?" profile))
  (unless (material-profile-designates? profile occurrence)
    (raise-arguments-error
     'material-profile-demand
     "the occurrence is not designated by this exact material profile"
     "occurrence" occurrence))
  (hash-ref (material-profile-demand-table profile)
            occurrence
            (lambda ()
              (zero-resource-vector
               (material-profile-dimensions profile)))))

;; `designated?` concerns the occurrence at this address.  `subtree-material?`
;; concerns every vertex in the connected subtree rooted there.  Holes contain
;; no occurrence and contribute zero, but they are retained in `term`.
(struct material-use
  (address term occurrence designated? own-demand subtree-material?
           subtree-demand subtree-vertex-count incidence)
  #:transparent)

(struct subtree-summary (material? demand vertex-count) #:transparent)

(define (check-source/profile who source profile)
  (unless (checked-node? source)
    (raise-argument-error who "checked-node?" source))
  (unless (material-profile? profile)
    (raise-argument-error who "material-profile?" profile))
  (define calculus (material-profile-calculus profile))
  (unless (and (eq? (checked-term-calculus source) calculus)
               (checked-term-has-exact-calculus? source calculus)
               (term-admitted-by? calculus source))
    (raise-arguments-error
     who
     "the source must be admitted with the exact calculus snapshot of the material profile"
     "profile calculus" calculus
     "source calculus" (checked-term-calculus source)
     "source" source)))

(define (scan-source who source profile)
  (check-source/profile who source profile)
  (define dimensions (material-profile-dimensions profile))
  (define zero (zero-resource-vector dimensions))
  (define mutable-use-table (make-hash))
  (define mutable-summary-table (make-hash))

  (define (walk term address)
    (cond
      [(checked-hole? term)
       (subtree-summary #t zero 0)]
      [else
       (define child-summaries
         (for/list ([child (in-list (checked-node-children term))]
                    [slot (in-naturals 1)])
           (walk child (address-append address (list slot)))))
       (define occurrence (checked-node-occurrence term))
       (define designated?
         (material-profile-designates? profile occurrence))
       (define own-demand
         (if designated?
             (material-profile-demand profile occurrence)
             zero))
       (define subtree-demand
         (for/fold ([total own-demand])
                   ([summary (in-list child-summaries)])
           (resource-vector-add total (subtree-summary-demand summary))))
       (define subtree-material?
         (and designated?
              (andmap subtree-summary-material? child-summaries)))
       (define subtree-vertex-count
         (add1
          (for/sum ([summary (in-list child-summaries)])
            (subtree-summary-vertex-count summary))))
       (define incidence
         (let ([supplied (concrete-occurrence-incidence occurrence)])
           (if (component-incidence? supplied)
               supplied
               (component-analysis-unavailable
                'legacy-opaque-incidence
                (hash 'address address
                      'occurrence-id
                      (concrete-occurrence-id occurrence))))))
       (define use
         (material-use
          address term occurrence designated? own-demand subtree-material?
          subtree-demand subtree-vertex-count incidence))
       (define summary
         (subtree-summary
          subtree-material? subtree-demand subtree-vertex-count))
       (hash-set! mutable-use-table address use)
       (hash-set! mutable-summary-table address summary)
       summary]))

  (walk source root-address)
  (define uses
    (for/list ([address (in-list (vertex-addresses source))])
      (hash-ref mutable-use-table address)))
  (values
   uses
   (for/hash ([(address use) (in-hash mutable-use-table)])
     (values address use))
   (for/hash ([(address summary) (in-hash mutable-summary-table)])
     (values address summary))))

(define (direct-material-uses source profile)
  (define-values (uses _use-table _summary-table)
    (scan-source 'direct-material-uses source profile))
  uses)

(struct material-blocker (reason address occurrence details) #:transparent)

(define (use->material-blocker use)
  (material-blocker
   'not-designated-material-occurrence
   (material-use-address use)
   (material-use-occurrence use)
   (hash 'term (material-use-term use))))

(struct material-module (address term vertex-count demand) #:transparent)
;; This is the CK-native blocked decomposition used by this query layer:
;; modules are maximal wholly material connected subtrees.  It is deliberately
;; narrower than the recovered neutral-context ownership decomposition, which
;; permits nonmaterial descendants inside a designated module.
(struct material-decomposition
  (source modules maximum-module-size vertex-count material-use-count blockers)
  #:transparent)

(define (decomposition-from-scan source uses use-table)
  (define modules '())
  (define maximum-size 0)
  (define (walk term address)
    (cond
      [(checked-hole? term) (void)]
      [else
       (define use (hash-ref use-table address))
       (cond
         [(material-use-subtree-material? use)
          (define module
            (material-module
             address
             term
             (material-use-subtree-vertex-count use)
             (material-use-subtree-demand use)))
          (set! modules (cons module modules))
          (set! maximum-size
                (max maximum-size
                     (material-use-subtree-vertex-count use)))]
         [else
          (for ([child (in-list (checked-node-children term))]
                [slot (in-naturals 1)])
            (walk child (address-append address (list slot))))])]))
  (walk source root-address)
  (material-decomposition
   source
   (reverse modules)
   maximum-size
   (length uses)
   (count material-use-designated? uses)
   (for/list ([use (in-list uses)]
              #:unless (material-use-designated? use))
     (use->material-blocker use))))

(define (direct-material-decomposition source profile)
  (define-values (uses use-table _summary-table)
    (scan-source 'direct-material-decomposition source profile))
  (decomposition-from-scan source uses use-table))

(struct material-component-not-applicable (reason) #:transparent)

;; The tensor is an immutable, ordered vector of the existing proof-forest
;; coordinates.  It is evidence-side data, not a new algebra carrier.
(struct material-witness-contribution
  (choice witness tensor demand component-profile)
  #:transparent)
(struct material-whole-endpoint-contribution
  (choice source tensor demand component-status)
  #:transparent)

(define (material-contribution? value)
  (or (material-witness-contribution? value)
      (material-whole-endpoint-contribution? value)))

(define (material-contribution-choice contribution)
  (cond
    [(material-witness-contribution? contribution)
     (material-witness-contribution-choice contribution)]
    [(material-whole-endpoint-contribution? contribution)
     (material-whole-endpoint-contribution-choice contribution)]
    [else
     (raise-argument-error
      'material-contribution-choice "material-contribution?" contribution)]))

(define (material-contribution-tensor contribution)
  (cond
    [(material-witness-contribution? contribution)
     (material-witness-contribution-tensor contribution)]
    [(material-whole-endpoint-contribution? contribution)
     (material-whole-endpoint-contribution-tensor contribution)]
    [else
     (raise-argument-error
      'material-contribution-tensor "material-contribution?" contribution)]))

(define (material-contribution-demand contribution)
  (cond
    [(material-witness-contribution? contribution)
     (material-witness-contribution-demand contribution)]
    [(material-whole-endpoint-contribution? contribution)
     (material-whole-endpoint-contribution-demand contribution)]
    [else
     (raise-argument-error
      'material-contribution-demand "material-contribution?" contribution)]))

(define (material-contribution-witness contribution)
  (cond
    [(material-witness-contribution? contribution)
     (material-witness-contribution-witness contribution)]
    [(material-whole-endpoint-contribution? contribution) #f]
    [else
     (raise-argument-error
      'material-contribution-witness "material-contribution?" contribution)]))

(struct material-candidate
  (choice witness tensor demand material? contribution)
  #:transparent)

(define (immutable-tensor left right)
  (vector->immutable-vector (vector left right)))

(define (witness-component-profile witness)
  (cond
    [(null? (cut-witness-addresses witness))
     (material-component-not-applicable 'empty-cut)]
    [(not (complete-proof? (cut-witness-source witness)))
     (component-analysis-unavailable
      'incomplete-source
      (hash 'addresses (cut-witness-addresses witness)))]
    [else (cut-witness->ck-component-profile witness)]))

(define (summaries-for-addresses summary-table addresses)
  (for/list ([address (in-list addresses)])
    (hash-ref summary-table address)))

;; The direct baseline deliberately rescans the detached checked terms instead
;; of consulting the prepared address summaries.  It shares the exact profile
;; definition, but not the index's material/demand cache.
(define (direct-term-summary term profile)
  (define zero
    (zero-resource-vector (material-profile-dimensions profile)))
  (cond
    [(checked-hole? term) (subtree-summary #t zero 0)]
    [else
     (define child-summaries
       (for/list ([child (in-list (checked-node-children term))])
         (direct-term-summary child profile)))
     (define occurrence (checked-node-occurrence term))
     (define designated?
       (material-profile-designates? profile occurrence))
     (define own-demand
       (if designated?
           (material-profile-demand profile occurrence)
           zero))
     (subtree-summary
      (and designated? (andmap subtree-summary-material? child-summaries))
      (for/fold ([total own-demand])
                ([summary (in-list child-summaries)])
        (resource-vector-add total (subtree-summary-demand summary)))
      (add1
       (for/sum ([summary (in-list child-summaries)])
         (subtree-summary-vertex-count summary))))]))

(define (ordinary-candidate witness profile summary-table)
  (define addresses (cut-witness-addresses witness))
  (define summaries (summaries-for-addresses summary-table addresses))
  (define material?
    (andmap subtree-summary-material? summaries))
  (define demand
    (for/fold
        ([total (zero-resource-vector
                 (material-profile-dimensions profile))])
        ([summary (in-list summaries)])
      (resource-vector-add total (subtree-summary-demand summary))))
  (define choice
    (if (null? addresses)
        (empty-cut-choice)
        (proper-cut-choice addresses)))
  (define calculus (material-profile-calculus profile))
  (define tensor
    (immutable-tensor
     (cut-witness-forest witness)
     (make-proof-forest
      calculus
      (list (cut-witness-remainder witness)))))
  (material-candidate
   choice
   witness
   tensor
   demand
   material?
   (and material?
        (material-witness-contribution
         choice witness tensor demand (witness-component-profile witness)))))

(define (direct-ordinary-candidate witness profile)
  (define summaries
    (for/list ([entry (in-list (cut-witness-detached witness))])
      (direct-term-summary (detached-entry-term entry) profile)))
  (define material?
    (andmap subtree-summary-material? summaries))
  (define demand
    (for/fold
        ([total (zero-resource-vector
                 (material-profile-dimensions profile))])
        ([summary (in-list summaries)])
      (resource-vector-add total (subtree-summary-demand summary))))
  (define addresses (cut-witness-addresses witness))
  (define choice
    (if (null? addresses)
        (empty-cut-choice)
        (proper-cut-choice addresses)))
  (define calculus (material-profile-calculus profile))
  (define tensor
    (immutable-tensor
     (cut-witness-forest witness)
     (make-proof-forest
      calculus
      (list (cut-witness-remainder witness)))))
  (material-candidate
   choice
   witness
   tensor
   demand
   material?
   (and material?
        (material-witness-contribution
         choice witness tensor demand (witness-component-profile witness)))))

(define (whole-endpoint-candidate source profile root-summary)
  (define calculus (material-profile-calculus profile))
  (define choice (whole-cut-choice))
  (define tensor
    (immutable-tensor
     (make-proof-forest calculus (list source))
     (empty-proof-forest calculus)))
  (define material? (subtree-summary-material? root-summary))
  (define demand (subtree-summary-demand root-summary))
  (material-candidate
   choice
   #f
   tensor
   demand
   material?
   (and material?
        (material-whole-endpoint-contribution
         choice
         source
         tensor
         demand
         (material-component-not-applicable
          'whole-algebraic-endpoint)))))

(define (direct-whole-endpoint-candidate source profile)
  (whole-endpoint-candidate
   source profile (direct-term-summary source profile)))

(define (enumerate-ordinary-candidates source profile summary-table)
  (for/list ([witness (in-admissible-cut-witnesses source)])
    (when (cut-error? witness)
      (error
       'enumerate-ordinary-candidates
       "the native admissible-cut enumerator produced an invalid witness: ~e"
       witness))
    (ordinary-candidate witness profile summary-table)))

(define (enumerate-direct-ordinary-candidates source profile)
  (for/list ([witness (in-admissible-cut-witnesses source)])
    (when (cut-error? witness)
      (error
       'enumerate-direct-ordinary-candidates
       "the native admissible-cut enumerator produced an invalid witness: ~e"
       witness))
    (direct-ordinary-candidate witness profile)))

(struct material-bucket (all material count demand) #:transparent)

(define (build-bucket-table candidates key-of)
  (define mutable (make-hash))
  (for ([candidate (in-list candidates)])
    (hash-update!
     mutable
     (key-of candidate)
     (lambda (entries) (cons candidate entries))
     '()))
  (for/hash ([(key reversed-candidates) (in-hash mutable)])
    (define ordered (reverse reversed-candidates))
    (define material
      (filter material-candidate-material? ordered))
    (define demands
      (remove-duplicates (map material-candidate-demand material) equal?))
    (when (> (length demands) 1)
      (error
       'prepare-material-stock-index
       "equal material query keys unexpectedly carried different exact demands: ~e"
       key))
    (values
     key
     (material-bucket
      ordered
      material
      (length material)
      (and (pair? demands) (car demands))))))

(struct material-stock-index
  (source profile ancestry uses use-table summary-table candidates choice-table
          forest-table tensor-table endpoint decomposition vertex-count
          ordinary-witness-count material-witness-count)
  #:constructor-name make-material-stock-index/internal
  #:sealed)

(define (prepare-material-stock-index
         source profile #:limit [limit analysis-default-limit])
  (unless (or (not limit) (exact-nonnegative-integer? limit))
    (raise-argument-error
     'prepare-material-stock-index
     "(or/c #f exact-nonnegative-integer?)"
     limit))
  (define-values (uses use-table summary-table)
    (scan-source 'prepare-material-stock-index source profile))
  (define ancestry (premise-ancestry-of source))
  (when (analysis-error? ancestry)
    (error
     'prepare-material-stock-index
     "an exact checked source unexpectedly failed native ancestry preparation: ~e"
     ancestry))
  (let/ec not-computed
    (when limit
      (when (zero? limit)
        (not-computed
         (analysis-limit
          'not-computed-limit
          "the exact material witness family exceeds its configured finite limit"
          'prepare-material-stock-index
          limit
          1
          'ordinary-witness-count
          (hash 'source source))))
      ;; `cut-size-polynomial` counts proper cuts.  The material stock also
      ;; retains the native empty witness, hence the limit-minus-one preflight.
      (define proper-polynomial
        (cut-size-polynomial ancestry #:limit (sub1 limit)))
      (cond
        [(analysis-limit? proper-polynomial)
         (not-computed
          (analysis-limit
           'not-computed-limit
           "the exact material witness family exceeds its configured finite limit"
           'prepare-material-stock-index
           limit
           (add1 (analysis-limit-required proper-polynomial))
           'ordinary-witness-count
           (hash 'source source
                 'proper-cut-preflight proper-polynomial)))]
        [(> (add1 (cut-size-polynomial-evaluate proper-polynomial 1))
            limit)
         (not-computed
          (analysis-limit
           'not-computed-limit
           "the exact material witness family exceeds its configured finite limit"
           'prepare-material-stock-index
           limit
           (add1 (cut-size-polynomial-evaluate proper-polynomial 1))
           'ordinary-witness-count
           (hash 'source source)))]))
    (define candidates
      (enumerate-ordinary-candidates source profile summary-table))
    (define endpoint
      (whole-endpoint-candidate
       source profile (hash-ref summary-table root-address)))
    (define choice-table
      (for/hash ([candidate (in-list candidates)])
        (values (material-candidate-choice candidate) candidate)))
    (define forest-table
      (build-bucket-table
       candidates
       (lambda (candidate)
         (vector-ref (material-candidate-tensor candidate) 0))))
    (define tensor-table
      (build-bucket-table candidates material-candidate-tensor))
    (define decomposition
      (decomposition-from-scan source uses use-table))
    (make-material-stock-index/internal
     source
     profile
     ancestry
     uses
     use-table
     summary-table
     candidates
     choice-table
     forest-table
     tensor-table
     endpoint
     decomposition
     (length uses)
     (length candidates)
     (count material-candidate-material? candidates))))

(define (indexed-material-decomposition index)
  (unless (material-stock-index? index)
    (raise-argument-error
     'indexed-material-decomposition "material-stock-index?" index))
  (material-stock-index-decomposition index))

(define (check-budget who profile budget)
  (unless (or (not budget) (resource-vector? budget))
    (raise-argument-error who "(or/c #f resource-vector?)" budget))
  (when (and budget
             (not (= (length budget)
                     (material-profile-dimensions profile))))
    (raise-arguments-error
     who
     "the query budget has the wrong resource dimension"
     "expected dimensions" (material-profile-dimensions profile)
     "actual budget" budget)))

(define (direct-material-subtree-available? source profile address
                                            #:budget [budget #f])
  (unless (address? address)
    (raise-argument-error
     'direct-material-subtree-available? "address?" address))
  (check-budget 'direct-material-subtree-available? profile budget)
  (define-values (_uses use-table _summary-table)
    (scan-source 'direct-material-subtree-available? source profile))
  (define use (hash-ref use-table address #f))
  (and use
       (material-use-subtree-material? use)
       (or (not budget)
           (resource-vector-fits?
            (material-use-subtree-demand use) budget))))

(define (indexed-material-subtree-available? index address
                                             #:budget [budget #f])
  (unless (material-stock-index? index)
    (raise-argument-error
     'indexed-material-subtree-available? "material-stock-index?" index))
  (unless (address? address)
    (raise-argument-error
     'indexed-material-subtree-available? "address?" address))
  (define profile (material-stock-index-profile index))
  (check-budget 'indexed-material-subtree-available? profile budget)
  (define use
    (hash-ref (material-stock-index-use-table index) address #f))
  (and use
       (material-use-subtree-material? use)
       (or (not budget)
           (resource-vector-fits?
            (material-use-subtree-demand use) budget))))

(struct material-query
  (kind selector budget include-whole-endpoint?)
  #:constructor-name make-material-query/internal
  #:sealed)

(define (copy-budget who budget)
  (unless (or (not budget) (resource-vector? budget))
    (raise-argument-error who "(or/c #f resource-vector?)" budget))
  (and budget (copy-resource-vector budget)))

(define (make-material-choice-query choice #:budget [budget #f])
  (unless (cut-choice? choice)
    (raise-argument-error
     'make-material-choice-query "cut-choice?" choice))
  (make-material-query/internal
   'choice choice (copy-budget 'make-material-choice-query budget)
   (whole-cut-choice? choice)))

(define (make-material-forest-query forest
                                    #:budget [budget #f]
                                    #:include-whole-endpoint?
                                    [include-whole-endpoint? #f])
  (unless (proof-forest? forest)
    (raise-argument-error
     'make-material-forest-query "proof-forest?" forest))
  (unless (boolean? include-whole-endpoint?)
    (raise-argument-error
     'make-material-forest-query "boolean?" include-whole-endpoint?))
  (make-material-query/internal
   'forest forest (copy-budget 'make-material-forest-query budget)
   include-whole-endpoint?))

(define (make-material-tensor-query tensor
                                    #:budget [budget #f]
                                    #:include-whole-endpoint?
                                    [include-whole-endpoint? #f])
  (unless (and (vector? tensor)
               (= (vector-length tensor) 2)
               (for/and ([coordinate (in-vector tensor)])
                 (proof-forest? coordinate)))
    (raise-argument-error
     'make-material-tensor-query
     "length-2 vector of proof-forest? coordinates"
     tensor))
  (unless (boolean? include-whole-endpoint?)
    (raise-argument-error
     'make-material-tensor-query "boolean?" include-whole-endpoint?))
  (make-material-query/internal
   'tensor
   (vector->immutable-vector (vector-copy tensor))
   (copy-budget 'make-material-tensor-query budget)
   include-whole-endpoint?))

(define (make-material-all-query #:budget [budget #f]
                                 #:include-whole-endpoint?
                                 [include-whole-endpoint? #f])
  (unless (boolean? include-whole-endpoint?)
    (raise-argument-error
     'make-material-all-query "boolean?" include-whole-endpoint?))
  (make-material-query/internal
   'all #f (copy-budget 'make-material-all-query budget)
   include-whole-endpoint?))

(struct material-query-rejection (choice witness demand blockers) #:transparent)
(struct material-query-result
  (ancestry profile query contributions coefficient rejections)
  #:transparent)

(define (material-query-result-available? result)
  (unless (material-query-result? result)
    (raise-argument-error
     'material-query-result-available? "material-query-result?" result))
  (positive? (material-query-result-coefficient result)))

(define (material-query-result-witnesses result)
  (unless (material-query-result? result)
    (raise-argument-error
     'material-query-result-witnesses "material-query-result?" result))
  (filter-map material-contribution-witness
              (material-query-result-contributions result)))

(define (material-query-result-blockers result)
  (unless (material-query-result? result)
    (raise-argument-error
     'material-query-result-blockers "material-query-result?" result))
  (append-map material-query-rejection-blockers
              (material-query-result-rejections result)))

(define (query-provenance-blocker query calculus)
  (define (wrong? forest)
    (not (eq? (proof-forest-calculus forest) calculus)))
  (define bad
    (case (material-query-kind query)
      [(forest)
       (and (wrong? (material-query-selector query))
            (material-query-selector query))]
      [(tensor)
       (for/first ([coordinate
                    (in-vector (material-query-selector query))]
                   #:when (wrong? coordinate))
         coordinate)]
      [else #f]))
  (and bad
       (material-blocker
        'wrong-calculus-provenance
        #f
        #f
        (hash 'expected-calculus calculus
              'actual-calculus (proof-forest-calculus bad)))))

(define (invalid-query-result ancestry profile query blocker [choice #f])
  (material-query-result
   ancestry
   profile
   query
   '()
   0
   (list
    (material-query-rejection choice #f #f (list blocker)))))

(define (candidate-selected-roots candidate)
  (define choice (material-candidate-choice candidate))
  (cond
    [(empty-cut-choice? choice) '()]
    [(proper-cut-choice? choice) (proper-cut-choice-addresses choice)]
    [else (list root-address)]))

(define (candidate-material-blockers candidate uses)
  (define roots (candidate-selected-roots candidate))
  (for/list ([use (in-list uses)]
             #:unless (material-use-designated? use)
             #:when
             (for/or ([root (in-list roots)])
               (address-prefix? root (material-use-address use))))
    (use->material-blocker use)))

(define (candidate-resource-blocker candidate budget)
  (material-blocker
   'resource-deficit
   #f
   #f
   (hash 'required (material-candidate-demand candidate)
         'available budget
         'deficit
         (resource-vector-deficit
          (material-candidate-demand candidate) budget))))

(define (evaluate-candidates ancestry query profile uses candidates)
  (define budget (material-query-budget query))
  (check-budget 'material-query profile budget)
  (cond
    [(null? candidates)
     (invalid-query-result
      ancestry
      profile
      query
      (material-blocker
       'no-native-opening
       #f
       #f
       (hash 'query-kind (material-query-kind query)
             'selector (material-query-selector query))))]
    [else
     (define-values (accepted rejected)
       (for/fold ([accepted '()] [rejected '()])
                 ([candidate (in-list candidates)])
         (cond
           [(not (material-candidate-material? candidate))
            (values
             accepted
             (cons
              (material-query-rejection
               (material-candidate-choice candidate)
               (material-candidate-witness candidate)
               (material-candidate-demand candidate)
               (candidate-material-blockers candidate uses))
              rejected))]
           [(and budget
                 (not
                  (resource-vector-fits?
                   (material-candidate-demand candidate) budget)))
            (values
             accepted
             (cons
              (material-query-rejection
               (material-candidate-choice candidate)
               (material-candidate-witness candidate)
               (material-candidate-demand candidate)
               (list (candidate-resource-blocker candidate budget)))
              rejected))]
           [else
            (values
             (cons (material-candidate-contribution candidate) accepted)
             rejected)])))
     (define contributions (reverse accepted))
     (material-query-result
      ancestry profile query contributions (length contributions)
      (reverse rejected))]))

(define (proper-choice->direct-candidate source profile choice)
  (define witness
    (make-cut-witness source (proper-cut-choice-addresses choice)))
  (and (cut-witness? witness)
       (direct-ordinary-candidate witness profile)))

(define (invalid-choice-result ancestry profile query source choice)
  (define addresses
    (if (proper-cut-choice? choice)
        (proper-cut-choice-addresses choice)
        '()))
  (define validation (make-cut-witness source addresses))
  (invalid-query-result
   ancestry
   profile
   query
   (material-blocker
    'invalid-native-cut
    (and (cut-error? validation) (cut-error-address validation))
    #f
    (hash 'cut-error validation))
   choice))

(define (select-direct-candidates source profile query)
  (define ordinary
    (delay (enumerate-direct-ordinary-candidates source profile)))
  (define endpoint
    (direct-whole-endpoint-candidate source profile))
  (define (with-matching-endpoint values matches-endpoint?)
    (if (and (material-query-include-whole-endpoint? query)
             matches-endpoint?)
        (cons endpoint values)
        values))
  (case (material-query-kind query)
    [(choice)
     (define choice (material-query-selector query))
     (cond
       [(empty-cut-choice? choice)
        (list
         (direct-ordinary-candidate
          (make-cut-witness source '()) profile))]
       [(proper-cut-choice? choice)
        (define candidate
          (proper-choice->direct-candidate source profile choice))
        (and candidate (list candidate))]
       [else (list endpoint)])]
    [(forest)
     (define forest (material-query-selector query))
     (with-matching-endpoint
      (for/list ([candidate (in-list (force ordinary))]
                 #:when
                 (equal? forest
                         (vector-ref
                          (material-candidate-tensor candidate) 0)))
        candidate)
      (equal? forest
              (vector-ref (material-candidate-tensor endpoint) 0)))]
    [(tensor)
     (define tensor (material-query-selector query))
     (with-matching-endpoint
      (for/list ([candidate (in-list (force ordinary))]
                 #:when (equal? tensor (material-candidate-tensor candidate)))
        candidate)
      (equal? tensor (material-candidate-tensor endpoint)))]
    [else
     (with-matching-endpoint (force ordinary) #t)]))

(define (direct-material-query source profile query)
  (unless (material-query? query)
    (raise-argument-error 'direct-material-query "material-query?" query))
  (check-source/profile 'direct-material-query source profile)
  (check-budget 'direct-material-query profile (material-query-budget query))
  (define ancestry (premise-ancestry-of source))
  (when (analysis-error? ancestry)
    (error
     'direct-material-query
     "an exact checked source unexpectedly failed native ancestry preparation: ~e"
     ancestry))
  (define provenance-blocker
    (query-provenance-blocker query (material-profile-calculus profile)))
  (cond
    [provenance-blocker
     (invalid-query-result ancestry profile query provenance-blocker)]
    [else
     (define-values (uses _use-table _summary-table)
       (scan-source 'direct-material-query source profile))
     (define candidates
       (select-direct-candidates source profile query))
     (cond
       [(not candidates)
        (invalid-choice-result
         ancestry profile query source (material-query-selector query))]
       [else (evaluate-candidates ancestry query profile uses candidates)])]))

(define (bucket-candidates table key)
  (define bucket (hash-ref table key #f))
  (if bucket (material-bucket-all bucket) '()))

(define (select-indexed-candidates index query)
  (define endpoint (material-stock-index-endpoint index))
  (define (with-matching-endpoint values matches-endpoint?)
    (if (and (material-query-include-whole-endpoint? query)
             matches-endpoint?)
        (cons endpoint values)
        values))
  (case (material-query-kind query)
    [(choice)
     (define choice (material-query-selector query))
     (cond
       [(whole-cut-choice? choice) (list endpoint)]
       [else
        (define candidate
          (hash-ref (material-stock-index-choice-table index) choice #f))
        (and candidate (list candidate))])]
    [(forest)
     (define forest (material-query-selector query))
     (with-matching-endpoint
      (bucket-candidates
       (material-stock-index-forest-table index)
       forest)
      (equal? forest
              (vector-ref (material-candidate-tensor endpoint) 0)))]
    [(tensor)
     (define tensor (material-query-selector query))
     (with-matching-endpoint
      (bucket-candidates
       (material-stock-index-tensor-table index)
       tensor)
      (equal? tensor (material-candidate-tensor endpoint)))]
    [else
     (with-matching-endpoint
      (material-stock-index-candidates index)
      #t)]))

(define (indexed-material-query index query)
  (unless (material-stock-index? index)
    (raise-argument-error
     'indexed-material-query "material-stock-index?" index))
  (unless (material-query? query)
    (raise-argument-error 'indexed-material-query "material-query?" query))
  (define profile (material-stock-index-profile index))
  (define ancestry (material-stock-index-ancestry index))
  (check-budget 'indexed-material-query profile (material-query-budget query))
  (define provenance-blocker
    (query-provenance-blocker query (material-profile-calculus profile)))
  (cond
    [provenance-blocker
     (invalid-query-result ancestry profile query provenance-blocker)]
    [else
     (define candidates (select-indexed-candidates index query))
     (cond
       [(not candidates)
        (invalid-choice-result
         ancestry
         profile
         query
         (material-stock-index-source index)
         (material-query-selector query))]
       [else
        (evaluate-candidates
         ancestry query profile (material-stock-index-uses index)
         candidates)])]))

(define (candidate-fits-budget? candidate budget)
  (and (material-candidate-material? candidate)
       (or (not budget)
           (resource-vector-fits?
            (material-candidate-demand candidate) budget))))

(define (bucket-count-under-budget bucket budget)
  (cond
    [(not bucket) 0]
    [(zero? (material-bucket-count bucket)) 0]
    [(or (not budget)
         (resource-vector-fits? (material-bucket-demand bucket) budget))
     (material-bucket-count bucket)]
    [else 0]))

(define (indexed-query-count index query)
  (define profile (material-stock-index-profile index))
  (define budget (material-query-budget query))
  (check-budget 'indexed-query-count profile budget)
  (cond
    [(query-provenance-blocker query (material-profile-calculus profile)) 0]
    [else
     (define endpoint (material-stock-index-endpoint index))
     (define (matching-endpoint-count matches?)
       (if (and (material-query-include-whole-endpoint? query)
                matches?
                (candidate-fits-budget? endpoint budget))
           1
           0))
     (case (material-query-kind query)
       [(choice)
        (define choice (material-query-selector query))
        (define candidate
          (if (whole-cut-choice? choice)
              endpoint
              (hash-ref
               (material-stock-index-choice-table index) choice #f)))
        (if (and candidate (candidate-fits-budget? candidate budget)) 1 0)]
       [(forest)
        (define forest (material-query-selector query))
        (+ (matching-endpoint-count
            (equal? forest
                    (vector-ref (material-candidate-tensor endpoint) 0)))
           (bucket-count-under-budget
            (hash-ref
             (material-stock-index-forest-table index)
             forest
             #f)
            budget))]
       [(tensor)
        (define tensor (material-query-selector query))
        (+ (matching-endpoint-count
            (equal? tensor (material-candidate-tensor endpoint)))
           (bucket-count-under-budget
            (hash-ref
             (material-stock-index-tensor-table index)
             tensor
             #f)
            budget))]
       [else
        (+ (matching-endpoint-count #t)
           (if budget
               (count
                (lambda (candidate)
                  (candidate-fits-budget? candidate budget))
                (material-stock-index-candidates index))
               (material-stock-index-material-witness-count index)))])]))

(define (direct-material-stock-count source profile #:budget [budget #f])
  (material-query-result-coefficient
   (direct-material-query
    source profile (make-material-all-query #:budget budget))))

(define (indexed-material-stock-count index #:budget [budget #f])
  (unless (material-stock-index? index)
    (raise-argument-error
     'indexed-material-stock-count "material-stock-index?" index))
  (indexed-query-count index (make-material-all-query #:budget budget)))

(define (direct-material-available? source profile query)
  (material-query-result-available?
   (direct-material-query source profile query)))

(define (indexed-material-available? index query)
  (unless (material-query? query)
    (raise-argument-error
     'indexed-material-available? "material-query?" query))
  (positive? (indexed-query-count index query)))

(define (direct-material-coefficient source profile forest
                                     #:budget [budget #f]
                                     #:include-whole-endpoint?
                                     [include-whole-endpoint? #f])
  (material-query-result-coefficient
   (direct-material-query
    source
    profile
    (make-material-forest-query
     forest
     #:budget budget
     #:include-whole-endpoint? include-whole-endpoint?))))

(define (indexed-material-coefficient index forest
                                      #:budget [budget #f]
                                      #:include-whole-endpoint?
                                      [include-whole-endpoint? #f])
  (indexed-query-count
   index
   (make-material-forest-query
    forest
    #:budget budget
    #:include-whole-endpoint? include-whole-endpoint?)))

(define (direct-material-tensor-coefficient source profile tensor
                                            #:budget [budget #f]
                                            #:include-whole-endpoint?
                                            [include-whole-endpoint? #f])
  (material-query-result-coefficient
   (direct-material-query
    source
    profile
    (make-material-tensor-query
     tensor
     #:budget budget
     #:include-whole-endpoint? include-whole-endpoint?))))

(define (indexed-material-tensor-coefficient index tensor
                                             #:budget [budget #f]
                                             #:include-whole-endpoint?
                                             [include-whole-endpoint? #f])
  (indexed-query-count
   index
   (make-material-tensor-query
    tensor
    #:budget budget
    #:include-whole-endpoint? include-whole-endpoint?)))

(define (direct-material-witnesses source profile query)
  (material-query-result-witnesses
   (direct-material-query source profile query)))

(define (indexed-material-witnesses index query)
  (material-query-result-witnesses
   (indexed-material-query index query)))
