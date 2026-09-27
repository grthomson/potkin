#lang racket/base

;; Support-labelled CK factorisation audits.
;;
;; Paper-level argument (PROVED on paper, not mechanised here).  POTKIN uses
;; descendant <= ancestor.  A CK cut therefore determines the downward ideal
;; consisting of the vertices in its detached upper forest; the empty cut is
;; the empty ideal and the separately adjoined, witness-free whole endpoint is
;; the total ideal.  CK n-layerings are consequently chains of ancestral
;; ideals.  Since J(P_D) is a thin category, its nerve is determined by
;; objects, arrows, identities, and composition: exactness in degrees 2 and 3
;; is the paper reason to expect exactness of every longer flag.
;;
;; For a base occurrence set B, restriction is r_B(I) = I intersect B.  On
;; base ideals, l_B(K) = down(K) and
;; u_B(K) = P_D \\ up(B \\ K).  The adjunctions
;; l_B -| r_B -| u_B imply r_B^-1(K) = [l_B(K), u_B(K)].  The functions below
;; check that finite identity exactly; their checks are bounded executable
;; evidence and are not a mechanisation of the universal argument.
;;
;; Every structure in this file is derived analysis metadata.  Proofs,
;; occurrences, cuts, detached tuples, forests, remainders, boundaries, and
;; calculus provenance are references to native POTKIN values.  None of these
;; structures is accepted by the native checker as proof evidence.

(require racket/list
         "../kernel/address.rkt"
         "../kernel/calculus.rkt"
         "../kernel/check.rkt"
         "../kernel/component-incidence.rkt"
         "../kernel/context.rkt"
         "../kernel/cut.rkt"
         "ancestry.rkt"
         "macro-cut-audit.rkt"
         "macro-summary.rkt"
         "material-stock.rkt")

(provide support-factorization-inconclusive?
         support-factorization-inconclusive-operation
         support-factorization-inconclusive-limit
         support-factorization-inconclusive-required
         support-factorization-inconclusive-metric
         support-factorization-inconclusive-details

         support-occurrence?
         support-occurrence-address
         support-occurrence-term
         support-occurrence-occurrence
         support-occurrence-boundary
         support-occurrence-base?
         support-occurrence-incidence

         support-factorization-object?
         support-factorization-object-source
         support-factorization-object-ideal
         support-factorization-object-support
         support-factorization-object-kind
         support-factorization-object-cut-choice
         support-factorization-object-native-witness
         support-factorization-object-detached
         support-factorization-object-forest
         support-factorization-object-remainder
         support-factorization-object-boundary
         support-factorization-object-base-support
         support-factorization-object-sector
         support-factorization-object-addresses
         support-factorization-object-base-addresses

         support-factorization-arrow?
         support-factorization-arrow-source
         support-factorization-arrow-target
         support-factorization-arrow-layer-support
         support-factorization-arrow-base-layer-support
         support-factorization-arrow-identity?
         support-factorization-arrow-sector
         support-factorization-arrow-layer-addresses
         support-factorization-arrow-base-layer-addresses

         support-factorization-category?
         support-factorization-category-calculus
         support-factorization-category-source
         support-factorization-category-profile
         support-factorization-category-ancestry
         support-factorization-category-occurrences
         support-factorization-category-base-occurrences
         support-factorization-category-objects
         support-factorization-category-arrows
         support-factorization-category-incidence-status
         support-factorization-category-opaque-occurrences
         support-factorization-category-limit
         compile-support-factorization-category
         support-factorization-category-object-at-ideal
         support-factorization-base-ideal?
         support-factorization-base-ideals

         support-factorization-restrict-base
         support-factorization-lower-lift
         support-factorization-upper-lift
         support-factorization-fibre-member?
         support-factorization-fibre
         support-fibre-verification?
         support-fibre-verification-base-ideal
         support-fibre-verification-lower
         support-fibre-verification-upper
         support-fibre-verification-fibre
         support-fibre-verification-interval
         support-fibre-verification-restriction-correct?
         support-fibre-verification-endpoints-correct?
         support-fibre-verification-equal?
         support-fibre-verification-status
         verify-support-factorization-fibre-interval

         support-factorization-relation-pair?
         make-support-factorization-relation-pair
         support-factorization-relation-pair-input
         support-factorization-relation-pair-output
         support-factorization-relation-pair-evidence
         support-factorization-failure?
         support-factorization-failure-kind
         support-factorization-failure-source
         support-factorization-failure-target
         support-factorization-failure-native-evidence
         support-factorization-failure-details
         support-exactness-result?
         support-exactness-result-status
         support-exactness-result-failures
         support-factorization-comparison?
         support-factorization-comparison-input-category
         support-factorization-comparison-output-category
         support-factorization-comparison-pairs
         support-factorization-comparison-occurrence-map
         support-factorization-comparison-degree-2
         support-factorization-comparison-degree-3
         support-factorization-comparison-identities-preserved?
         support-factorization-comparison-inclusions-preserved?
         support-factorization-comparison-restriction-compatible?
         support-factorization-comparison-lower-compatible?
         support-factorization-comparison-upper-compatible?
         support-factorization-comparison-cartesian-objects?
         support-factorization-comparison-cartesian-arrows?
         support-factorization-comparison-status
         audit-support-factorization-relation

         support-profile-edge?
         support-profile-edge-input
         support-profile-edge-output
         support-profile-edge-evidence
         support-profile-edge-input-sector
         support-profile-edge-output-sector
         support-factorization-profile?
         support-factorization-profile-input-category
         support-factorization-profile-output-category
         support-factorization-profile-edges
         support-factorization-profile-pp
         support-factorization-profile-pq
         support-factorization-profile-qp
         support-factorization-profile-qq
         support-factorization-profile-status
         make-support-factorization-profile
         support-factorization-comparison-profile
         support-composite-edge?
         support-composite-edge-first
         support-composite-edge-second
         support-composite-edge-input
         support-composite-edge-intermediate
         support-composite-edge-output
         support-profile-composition?
         support-profile-composition-first
         support-profile-composition-second
         support-profile-composition-edges
         support-profile-composition-pp
         support-profile-composition-pq
         support-profile-composition-qp
         support-profile-composition-qq
         support-profile-composition-pp-direct
         support-profile-composition-excursions
         compose-support-factorization-profiles

         support-macro-audit?
         support-macro-audit-summary
         support-macro-audit-port
         support-macro-audit-filler
         support-macro-audit-native-audit
         support-macro-audit-source-category
         support-macro-audit-target-category
         support-macro-audit-relation-pairs
         support-macro-audit-comparison
         support-macro-audit-profile
         support-macro-audit-positive?
         support-macro-audit-externally-linear?
         support-macro-audit-incidence-exact?
         support-macro-audit-status
         support-macro-audit-reasons
         audit-support-factorization-macro)

(struct support-factorization-inconclusive
  (operation limit required metric details)
  #:transparent)

(struct support-occurrence
  (address term occurrence boundary base? incidence)
  #:constructor-name make-support-occurrence/internal
  #:transparent)

(struct support-factorization-object
  (source ideal support kind cut-choice native-witness detached forest
          remainder boundary base-support sector)
  #:constructor-name make-support-factorization-object/internal
  #:transparent)

(struct support-factorization-arrow
  (source target layer-support base-layer-support identity? sector)
  #:constructor-name make-support-factorization-arrow/internal
  #:transparent)

(struct support-factorization-category
  (calculus source profile ancestry occurrences base-occurrences objects arrows
            object-table incidence-status opaque-occurrences limit)
  #:constructor-name make-support-factorization-category/internal
  #:transparent)

(struct support-fibre-verification
  (base-ideal lower upper fibre interval restriction-correct?
              endpoints-correct? equal? status)
  #:constructor-name make-support-fibre-verification/internal
  #:transparent)

(struct support-factorization-relation-pair (input output evidence)
  #:constructor-name make-support-factorization-relation-pair/internal
  #:transparent)

(struct support-factorization-failure
  (kind source target native-evidence details)
  #:constructor-name make-support-factorization-failure/internal
  #:transparent)

(struct support-exactness-result (status failures)
  #:constructor-name make-support-exactness-result/internal
  #:transparent)

(struct support-factorization-comparison
  (input-category output-category pairs occurrence-map degree-2 degree-3
                  identities-preserved? inclusions-preserved?
                  restriction-compatible? lower-compatible? upper-compatible?
                  cartesian-objects? cartesian-arrows? status)
  #:constructor-name make-support-factorization-comparison/internal
  #:transparent)

(struct support-profile-edge
  (input output evidence input-sector output-sector)
  #:constructor-name make-support-profile-edge/internal
  #:transparent)

(struct support-factorization-profile
  (input-category output-category edges pp pq qp qq status)
  #:constructor-name make-support-factorization-profile/internal
  #:transparent)

(struct support-composite-edge (first second input intermediate output)
  #:constructor-name make-support-composite-edge/internal
  #:transparent)

(struct support-profile-composition
  (first second edges pp pq qp qq pp-direct excursions)
  #:constructor-name make-support-profile-composition/internal
  #:transparent)

(struct support-macro-audit
  (summary port filler native-audit source-category target-category
           relation-pairs comparison profile positive? externally-linear?
           incidence-exact? status reasons)
  #:constructor-name make-support-macro-audit/internal
  #:transparent)

(define (check-limit who limit)
  (unless (exact-nonnegative-integer? limit)
    (raise-argument-error who "exact-nonnegative-integer?" limit)))

(define (canonical-addresses who addresses)
  (unless (and (list? addresses) (andmap address? addresses))
    (raise-argument-error who "(listof address?)" addresses))
  (when (check-duplicates addresses equal?)
    (raise-arguments-error who "addresses must be occurrence-distinct"
                           "addresses" addresses))
  (sort addresses address<?))

(define (address-member? address addresses)
  (and (member address addresses equal?) #t))

(define (address-subset? left right)
  (for/and ([address (in-list left)])
    (address-member? address right)))

(define (category-object? category object)
  (and (support-factorization-object? object)
       (memq object (support-factorization-category-objects category))
       #t))

(define (check-category who category)
  (unless (support-factorization-category? category)
    (raise-argument-error who "support-factorization-category?" category)))

(define (check-category-object who category object)
  (unless (category-object? category object)
    (raise-arguments-error
     who "the factorisation object must belong to this exact category"
     "category" category "object" object)))

(define (support-factorization-object-addresses object)
  (unless (support-factorization-object? object)
    (raise-argument-error
     'support-factorization-object-addresses
     "support-factorization-object?" object))
  (map support-occurrence-address
       (support-factorization-object-support object)))

(define (support-factorization-object-base-addresses object)
  (unless (support-factorization-object? object)
    (raise-argument-error
     'support-factorization-object-base-addresses
     "support-factorization-object?" object))
  (map support-occurrence-address
       (support-factorization-object-base-support object)))

(define (support-factorization-arrow-layer-addresses arrow)
  (unless (support-factorization-arrow? arrow)
    (raise-argument-error
     'support-factorization-arrow-layer-addresses
     "support-factorization-arrow?" arrow))
  (map support-occurrence-address
       (support-factorization-arrow-layer-support arrow)))

(define (support-factorization-arrow-base-layer-addresses arrow)
  (unless (support-factorization-arrow? arrow)
    (raise-argument-error
     'support-factorization-arrow-base-layer-addresses
     "support-factorization-arrow?" arrow))
  (map support-occurrence-address
       (support-factorization-arrow-base-layer-support arrow)))

(define (wrap-analysis-limit operation limit result)
  (support-factorization-inconclusive
   operation limit
   (analysis-limit-required result)
   (analysis-limit-metric result)
   (hash 'native-result result)))

(define (compile-support-factorization-category
         source profile #:limit [limit analysis-default-limit])
  (define who 'compile-support-factorization-category)
  (check-limit who limit)
  (unless (checked-node? source)
    (raise-argument-error who "checked-node?" source))
  (unless (material-profile? profile)
    (raise-argument-error who "material-profile?" profile))
  (define calculus (material-profile-calculus profile))
  ;; This check precedes ancestry traversal and rejects structurally equal but
  ;; foreign registry snapshots.
  (unless (and (eq? (checked-term-calculus source) calculus)
               (checked-term-has-exact-calculus? source calculus)
               (term-admitted-by? calculus source))
    (raise-arguments-error
     who "source and material profile must share one exact calculus snapshot"
     "profile calculus" calculus
     "source calculus" (checked-term-calculus source)
     "source" source))
  (define ancestry (premise-ancestry-of source))
  (when (analysis-error? ancestry)
    (error who "native ancestry compilation failed: ~e" ancestry))
  (define ideal-sequence (in-ancestry-ideals ancestry #:limit limit))
  (cond
    [(analysis-limit? ideal-sequence)
     (wrap-analysis-limit who limit ideal-sequence)]
    [(analysis-error? ideal-sequence)
     (error who "native ideal enumeration failed: ~e" ideal-sequence)]
    [else
     (define ideals (for/list ([ideal ideal-sequence]) ideal))
     (define uses (direct-material-uses source profile))
     (define occurrences
       (for/list ([use (in-list uses)])
         (make-support-occurrence/internal
          (material-use-address use)
          (material-use-term use)
          (material-use-occurrence use)
          (derivation-root-boundary (material-use-term use))
          (material-use-designated? use)
          (material-use-incidence use))))
     (define occurrence-table
       (for/hash ([occurrence (in-list occurrences)])
         (values (support-occurrence-address occurrence) occurrence)))
     (define base-occurrences
       (filter support-occurrence-base? occurrences))
     (define opaque-occurrences
       (filter (lambda (occurrence)
                 (not (component-incidence?
                       (support-occurrence-incidence occurrence))))
               occurrences))
     (define (object-from-ideal ideal)
       (define choice (ancestry-ideal->cut-choice ancestry ideal))
       (when (analysis-error? choice)
         (error who "native ideal/cut conversion failed: ~e" choice))
       (define-values (kind witness detached forest remainder)
         (cond
           [(empty-cut-choice? choice)
            (define native (make-cut-witness source '()))
            (when (cut-error? native)
              (error who "native empty cut failed: ~e" native))
            (values 'empty native
                    (cut-witness-detached native)
                    (cut-witness-forest native)
                    (cut-witness-remainder native))]
           [(proper-cut-choice? choice)
            (define native
              (make-cut-witness source
                                (proper-cut-choice-addresses choice)))
            (when (cut-error? native)
              (error who "native proper cut failed: ~e" native))
            (values 'proper native
                    (cut-witness-detached native)
                    (cut-witness-forest native)
                    (cut-witness-remainder native))]
           [else
            ;; The whole endpoint is deliberately witness-free; no root cut
            ;; or fabricated detached tuple is introduced here.
            (values 'whole #f #f #f #f)]))
       (define support
         (for/list ([address (in-list ideal)])
           (hash-ref occurrence-table address)))
       (define base-support (filter support-occurrence-base? support))
       (make-support-factorization-object/internal
        source ideal support kind choice witness detached forest remainder
        (derivation-root-boundary source)
        base-support
        (if (= (length support) (length base-support)) 'P 'Q)))
     (define objects (map object-from-ideal ideals))
     ;; Stop the preflight as soon as the advertised finite budget is known
     ;; to be insufficient; do not construct a partial arrow category.
     (define required-arrows
       (let/ec over-limit
         (define count 0)
         (for* ([source-object (in-list objects)]
                [target-object (in-list objects)]
                #:when
                (address-subset?
                 (support-factorization-object-ideal source-object)
                 (support-factorization-object-ideal target-object)))
           (set! count (add1 count))
           (when (> count limit) (over-limit count)))
         count))
     (cond
       [(> required-arrows limit)
        (support-factorization-inconclusive
         who limit required-arrows 'factorization-arrow-count
         (hash 'object-count (length objects)))]
       [else
        (define arrows
          (for*/list ([source-object (in-list objects)]
                      [target-object (in-list objects)]
                      #:when
                      (address-subset?
                       (support-factorization-object-ideal source-object)
                       (support-factorization-object-ideal target-object)))
            (define source-ideal
              (support-factorization-object-ideal source-object))
            (define target-ideal
              (support-factorization-object-ideal target-object))
            (define layer
              (for/list ([occurrence (in-list occurrences)]
                         #:when
                         (and (address-member?
                               (support-occurrence-address occurrence)
                               target-ideal)
                              (not (address-member?
                                    (support-occurrence-address occurrence)
                                    source-ideal))))
                occurrence))
            (define base-layer (filter support-occurrence-base? layer))
            (make-support-factorization-arrow/internal
             source-object target-object layer base-layer
             (eq? source-object target-object)
             (if (= (length layer) (length base-layer)) 'P 'Q))))
        (make-support-factorization-category/internal
         calculus source profile ancestry occurrences base-occurrences
         objects arrows
         (for/hash ([object (in-list objects)])
           (values (support-factorization-object-ideal object) object))
         (if (null? opaque-occurrences) 'exact 'opaque)
         opaque-occurrences limit)])]))

(define (support-factorization-category-object-at-ideal category ideal)
  (check-category 'support-factorization-category-object-at-ideal category)
  (define canonical
    (canonical-addresses 'support-factorization-category-object-at-ideal ideal))
  (hash-ref (support-factorization-category-object-table category)
            canonical #f))

(define (support-factorization-base-ideal? category candidate)
  (check-category 'support-factorization-base-ideal? category)
  (define canonical
    (and (list? candidate)
         (andmap address? candidate)
         (not (check-duplicates candidate equal?))
         (sort candidate address<?)))
  (and canonical
       (let* ([ancestry (support-factorization-category-ancestry category)]
              [base-addresses
               (map support-occurrence-address
                    (support-factorization-category-base-occurrences
                     category))])
         (and
          (address-subset? canonical base-addresses)
          (for*/and ([upper (in-list canonical)]
                     [lower (in-list base-addresses)]
                     #:when (ancestry<=? ancestry lower upper))
            (address-member? lower canonical))))))

(define (check-base-ideal who category candidate)
  (unless (support-factorization-base-ideal? category candidate)
    (raise-arguments-error
     who "expected a downward ideal of the exact induced base ancestry"
     "candidate" candidate
     "base occurrences"
     (map support-occurrence-address
          (support-factorization-category-base-occurrences category))))
  (sort candidate address<?))

(define (support-factorization-base-ideals
         category #:limit [limit analysis-default-limit])
  (define who 'support-factorization-base-ideals)
  (check-category who category)
  (check-limit who limit)
  (define ideals
    (remove-duplicates
     (map support-factorization-object-base-addresses
          (support-factorization-category-objects category))
     equal?))
  (if (> (length ideals) limit)
      (support-factorization-inconclusive
       who limit (length ideals) 'base-ideal-count (hash))
      ideals))

(define (support-factorization-restrict-base category object)
  (check-category 'support-factorization-restrict-base category)
  (check-category-object 'support-factorization-restrict-base category object)
  (support-factorization-object-base-addresses object))

(define (support-factorization-lower-lift category base-ideal)
  (define who 'support-factorization-lower-lift)
  (check-category who category)
  (define canonical (check-base-ideal who category base-ideal))
  (define ancestry (support-factorization-category-ancestry category))
  (define ideal
    (for/list ([occurrence
                (in-list
                 (support-factorization-category-occurrences category))]
               #:when
               (for/or ([base-address (in-list canonical)])
                 (ancestry<=? ancestry
                              (support-occurrence-address occurrence)
                              base-address)))
      (support-occurrence-address occurrence)))
  (or (support-factorization-category-object-at-ideal category ideal)
      (error who "native lower closure was not an ancestry ideal: ~e" ideal)))

(define (support-factorization-upper-lift category base-ideal)
  (define who 'support-factorization-upper-lift)
  (check-category who category)
  (define canonical (check-base-ideal who category base-ideal))
  (define ancestry (support-factorization-category-ancestry category))
  (define omitted
    (filter
     (lambda (address) (not (address-member? address canonical)))
     (map support-occurrence-address
          (support-factorization-category-base-occurrences category))))
  (define ideal
    (for/list ([occurrence
                (in-list
                 (support-factorization-category-occurrences category))]
               #:unless
               (for/or ([omitted-address (in-list omitted)])
                 (ancestry<=? ancestry omitted-address
                              (support-occurrence-address occurrence))))
      (support-occurrence-address occurrence)))
  (or (support-factorization-category-object-at-ideal category ideal)
      (error who "native upper closure was not an ancestry ideal: ~e" ideal)))

(define (support-factorization-fibre-member? category base-ideal object)
  (define who 'support-factorization-fibre-member?)
  (check-category who category)
  (define canonical (check-base-ideal who category base-ideal))
  (check-category-object who category object)
  (equal? canonical (support-factorization-restrict-base category object)))

(define (support-factorization-fibre
         category base-ideal #:limit [limit analysis-default-limit])
  (define who 'support-factorization-fibre)
  (check-category who category)
  (check-limit who limit)
  (define canonical (check-base-ideal who category base-ideal))
  (define fibre
    (filter
     (lambda (object)
       (equal? canonical
               (support-factorization-restrict-base category object)))
     (support-factorization-category-objects category)))
  (if (> (length fibre) limit)
      (support-factorization-inconclusive
       who limit (length fibre) 'syntactic-fibre-size
       (hash 'base-ideal canonical))
      fibre))

(define (same-object-set? left right)
  (and (= (length left) (length right))
       (for/and ([object (in-list left)])
         (and (memq object right) #t))))

(define (verify-support-factorization-fibre-interval
         category base-ideal #:limit [limit analysis-default-limit])
  (define who 'verify-support-factorization-fibre-interval)
  (check-category who category)
  (check-limit who limit)
  (define canonical (check-base-ideal who category base-ideal))
  (define fibre
    (support-factorization-fibre category canonical #:limit limit))
  (cond
    [(support-factorization-inconclusive? fibre) fibre]
    [else
     (define lower (support-factorization-lower-lift category canonical))
     (define upper (support-factorization-upper-lift category canonical))
     (define lower-ideal (support-factorization-object-ideal lower))
     (define upper-ideal (support-factorization-object-ideal upper))
     (define interval
       (filter
        (lambda (object)
          (define ideal (support-factorization-object-ideal object))
          (and (address-subset? lower-ideal ideal)
               (address-subset? ideal upper-ideal)))
        (support-factorization-category-objects category)))
     (define restriction-correct?
       (andmap (lambda (object)
                 (equal? canonical
                         (support-factorization-restrict-base category object)))
               interval))
     (define endpoints-correct?
       (and (equal? canonical
                    (support-factorization-restrict-base category lower))
            (equal? canonical
                    (support-factorization-restrict-base category upper))))
     (define interval-equal? (same-object-set? fibre interval))
     (make-support-fibre-verification/internal
      canonical lower upper fibre interval restriction-correct?
      endpoints-correct? interval-equal?
      (if (and restriction-correct? endpoints-correct? interval-equal?)
          'verified
          'mismatch))]))

(define (make-support-factorization-relation-pair input output
                                                   [evidence #f])
  (unless (and (support-factorization-object? input)
               (support-factorization-object? output))
    (raise-argument-error
     'make-support-factorization-relation-pair
     "two support-factorization-object? values"
     (list input output)))
  (make-support-factorization-relation-pair/internal
   input output evidence))

(define (make-failure kind [source #f] [target #f]
                      [native-evidence #f] [details (hash)])
  (make-support-factorization-failure/internal
   kind source target native-evidence details))

(define (pairs-from-input pairs object)
  (filter (lambda (pair)
            (eq? object (support-factorization-relation-pair-input pair)))
          pairs))

(define (pairs-to-output pairs object)
  (filter (lambda (pair)
            (eq? object (support-factorization-relation-pair-output pair)))
          pairs))

(define (unique-pair-outputs pairs object)
  (remove-duplicates
   (map support-factorization-relation-pair-output
        (pairs-from-input pairs object))
   eq?))

(define (find-arrow category source target)
  (findf (lambda (arrow)
           (and (eq? source (support-factorization-arrow-source arrow))
                (eq? target (support-factorization-arrow-target arrow))))
         (support-factorization-category-arrows category)))

(define (check-occurrence-map who input-category output-category mapping)
  (unless (and (hash? mapping) (immutable? mapping))
    (raise-argument-error who "immutable hash?" mapping))
  (define input-addresses
    (map support-occurrence-address
         (support-factorization-category-occurrences input-category)))
  (define output-addresses
    (map support-occurrence-address
         (support-factorization-category-occurrences output-category)))
  (unless (and (= (hash-count mapping) (length input-addresses))
               (for/and ([address (in-list input-addresses)])
                 (and (hash-has-key? mapping address)
                      (address? (hash-ref mapping address))
                      (address-member? (hash-ref mapping address)
                                       output-addresses)))
               (not (check-duplicates (hash-values mapping) equal?)))
    (raise-arguments-error
     who
     "occurrence map must be a total injective map into target native vertices"
     "mapping" mapping
     "input addresses" input-addresses
     "output addresses" output-addresses)))

(define (occurrence-at category address)
  (findf (lambda (occurrence)
           (equal? address (support-occurrence-address occurrence)))
         (support-factorization-category-occurrences category)))

(define (mapped-addresses mapping addresses)
  (sort (map (lambda (address) (hash-ref mapping address)) addresses)
        address<?))

(define (audit-support-factorization-relation
         input-category output-category pairs
         #:occurrence-map [occurrence-map #f]
         #:limit [limit analysis-default-limit])
  (define who 'audit-support-factorization-relation)
  (let/ec return
  (check-limit who limit)
  (check-category who input-category)
  (check-category who output-category)
  (unless (and (list? pairs)
               (andmap support-factorization-relation-pair? pairs))
    (raise-argument-error
     who "(listof support-factorization-relation-pair?)" pairs))
  (for ([pair (in-list pairs)])
    (check-category-object
     who input-category (support-factorization-relation-pair-input pair))
    (check-category-object
     who output-category (support-factorization-relation-pair-output pair)))
  (when occurrence-map
    (check-occurrence-map who input-category output-category occurrence-map))

  ;; This bound covers the largest nested search below (output arrows x
  ;; relation pairs x input arrows) as well as the linear scans.  Reject it
  ;; before emitting any partial exactness result.
  (define required-work
    (+ (length pairs)
       (length (support-factorization-category-objects input-category))
       (length (support-factorization-category-objects output-category))
       (length (support-factorization-category-arrows input-category))
       (length (support-factorization-category-arrows output-category))
       (* (length (support-factorization-category-arrows output-category))
          (length pairs)
          (length (support-factorization-category-arrows input-category)))))
  (when (> required-work limit)
    (return
     (support-factorization-inconclusive
      who limit required-work 'relation-audit-work
      (hash 'pair-count (length pairs)))))

  (define degree-2-failures '())
  (define degree-3-failures '())
  (define (fail-2! failure)
    (set! degree-2-failures (cons failure degree-2-failures)))
  (define (fail-3! failure)
    (set! degree-3-failures (cons failure degree-3-failures)))

  (for ([object
         (in-list (support-factorization-category-objects input-category))])
    (define outputs (unique-pair-outputs pairs object))
    (cond
      [(null? outputs)
       (fail-2!
        (make-failure 'object-not-total object #f
                      (support-factorization-object-native-witness object)))]
      [(> (length outputs) 1)
       (fail-2! (make-failure
                 'object-not-single-valued object outputs
                 (support-factorization-object-native-witness object)
                 (hash 'output-count (length outputs))))]))
  (for ([object
         (in-list (support-factorization-category-objects output-category))])
    (define inputs
      (remove-duplicates
       (map support-factorization-relation-pair-input
            (pairs-to-output pairs object))
       eq?))
    (cond
      [(null? inputs)
       (fail-2!
        (make-failure 'output-object-without-lift #f object
                      (support-factorization-object-native-witness object)))]
      [(> (length inputs) 1)
       (fail-2!
        (make-failure
         'output-object-nonunique-lift inputs object
         (support-factorization-object-native-witness object)
         (hash 'lift-count (length inputs))))]))

  (define boundary-labels-exact? #t)
  (define support-labels-exact? (and occurrence-map #t))
  (when occurrence-map
    (for ([(input-address output-address) (in-hash occurrence-map)])
      (define input-occurrence (occurrence-at input-category input-address))
      (define output-occurrence (occurrence-at output-category output-address))
      (unless (equal? (support-occurrence-boundary input-occurrence)
                      (support-occurrence-boundary output-occurrence))
        (set! boundary-labels-exact? #f)
        (fail-2!
         (make-failure
          'occurrence-boundary-mismatch input-occurrence output-occurrence #f
          (hash 'input-boundary
                (support-occurrence-boundary input-occurrence)
                'output-boundary
                (support-occurrence-boundary output-occurrence)))))
      (unless (eq? (support-occurrence-base? input-occurrence)
                   (support-occurrence-base? output-occurrence))
        (set! support-labels-exact? #f)
        (fail-2!
         (make-failure 'occurrence-support-label-mismatch
                       input-occurrence output-occurrence)))
      (unless (eq? (support-occurrence-occurrence input-occurrence)
                   (support-occurrence-occurrence output-occurrence))
        (set! support-labels-exact? #f)
        (fail-2!
         (make-failure 'native-occurrence-identity-mismatch
                       input-occurrence output-occurrence
                       (list (support-occurrence-occurrence input-occurrence)
                             (support-occurrence-occurrence
                              output-occurrence)))))
      (unless (equal? (support-occurrence-incidence input-occurrence)
                      (support-occurrence-incidence output-occurrence))
        (set! support-labels-exact? #f)
        (fail-2!
         (make-failure 'occurrence-incidence-mismatch
                       input-occurrence output-occurrence
                       (list (support-occurrence-incidence input-occurrence)
                             (support-occurrence-incidence
                              output-occurrence))))))
    (for ([pair (in-list pairs)])
      (define input (support-factorization-relation-pair-input pair))
      (define output (support-factorization-relation-pair-output pair))
      (define expected
        (mapped-addresses occurrence-map
                          (support-factorization-object-ideal input)))
      (unless (equal? expected
                      (support-factorization-object-ideal output))
        (set! support-labels-exact? #f)
        (fail-2!
         (make-failure
          'object-occurrence-support-mismatch input output
          (support-factorization-relation-pair-evidence pair)
          (hash 'expected-target-ideal expected
                'actual-target-ideal
                (support-factorization-object-ideal output)))))))

  (define restriction-compatible? (and occurrence-map #t))
  (define lower-compatible? (and occurrence-map #t))
  (define upper-compatible? (and occurrence-map #t))
  (when occurrence-map
    (define input-base-ideals
      (support-factorization-base-ideals
       input-category
       #:limit (support-factorization-category-limit input-category)))
    (unless (support-factorization-inconclusive? input-base-ideals)
      (for ([base-ideal (in-list input-base-ideals)])
        (define mapped-base (mapped-addresses occurrence-map base-ideal))
        (cond
          [(not (support-factorization-base-ideal?
                 output-category mapped-base))
           (set! restriction-compatible? #f)
           (set! lower-compatible? #f)
           (set! upper-compatible? #f)
           (fail-2!
            (make-failure
             'mapped-base-set-not-an-ideal base-ideal mapped-base))]
          [else
           (define input-lower
             (support-factorization-lower-lift input-category base-ideal))
           (define output-lower
             (support-factorization-lower-lift output-category mapped-base))
           (define input-upper
             (support-factorization-upper-lift input-category base-ideal))
           (define output-upper
             (support-factorization-upper-lift output-category mapped-base))
           (unless
               (equal?
                (mapped-addresses
                 occurrence-map
                 (support-factorization-object-ideal input-lower))
                (support-factorization-object-ideal output-lower))
             (set! lower-compatible? #f)
             (fail-2!
              (make-failure 'lower-lift-mismatch input-lower output-lower)))
           (unless
               (equal?
                (mapped-addresses
                 occurrence-map
                 (support-factorization-object-ideal input-upper))
                (support-factorization-object-ideal output-upper))
             (set! upper-compatible? #f)
             (fail-2!
              (make-failure 'upper-lift-mismatch input-upper output-upper)))])))
    (for ([pair (in-list pairs)])
      (define input (support-factorization-relation-pair-input pair))
      (define output (support-factorization-relation-pair-output pair))
      (unless
          (equal?
           (mapped-addresses
            occurrence-map
            (support-factorization-restrict-base input-category input))
           (support-factorization-restrict-base output-category output))
        (set! restriction-compatible? #f)
        (fail-2!
         (make-failure
          'base-restriction-mismatch input output
          (support-factorization-relation-pair-evidence pair))))))

  (define identities-preserved? #t)
  (for ([pair (in-list pairs)])
    (define input (support-factorization-relation-pair-input pair))
    (define output (support-factorization-relation-pair-output pair))
    (unless (and (find-arrow input-category input input)
                 (find-arrow output-category output output))
      (set! identities-preserved? #f)
      (fail-3! (make-failure 'identity-not-preserved input output
                             (support-factorization-relation-pair-evidence
                              pair)))))

  (define inclusions-preserved? #t)
  (for ([arrow
         (in-list (support-factorization-category-arrows input-category))])
    (define source-outputs
      (unique-pair-outputs pairs
                           (support-factorization-arrow-source arrow)))
    (define target-outputs
      (unique-pair-outputs pairs
                           (support-factorization-arrow-target arrow)))
    (when (and (= (length source-outputs) 1)
               (= (length target-outputs) 1)
               (not (find-arrow output-category
                                (car source-outputs)
                                (car target-outputs))))
      (set! inclusions-preserved? #f)
      (fail-3!
       (make-failure 'inclusion-not-preserved arrow
                     (list (car source-outputs) (car target-outputs))))))

  ;; Cartesian arrow test: for every output inclusion y0 <= y1 and every
  ;; related x1 over y1, there must be exactly one inclusion x0 <= x1 whose
  ;; source is related to y0.  Failures retain the exact target arrow and x1.
  (for ([output-arrow
         (in-list (support-factorization-category-arrows output-category))])
    (define y0 (support-factorization-arrow-source output-arrow))
    (define y1 (support-factorization-arrow-target output-arrow))
    (for ([target-pair (in-list (pairs-to-output pairs y1))])
      (define x1 (support-factorization-relation-pair-input target-pair))
      (define lifts
        (for*/list ([source-pair (in-list (pairs-to-output pairs y0))]
                    [input-arrow
                     (in-list
                      (support-factorization-category-arrows input-category))]
                    #:when
                    (and (eq? (support-factorization-arrow-source input-arrow)
                              (support-factorization-relation-pair-input
                               source-pair))
                         (eq? (support-factorization-arrow-target input-arrow)
                              x1)))
          input-arrow))
      (unless (= (length lifts) 1)
        (fail-3!
         (make-failure
          'arrow-unique-lift-failure x1 output-arrow
          (support-factorization-relation-pair-evidence target-pair)
          (hash 'lift-count (length lifts) 'lifts lifts))))))

  (set! degree-2-failures (reverse degree-2-failures))
  (set! degree-3-failures (reverse degree-3-failures))
  (define cartesian-objects? (null? degree-2-failures))
  (define cartesian-arrows? (null? degree-3-failures))
  (make-support-factorization-comparison/internal
   input-category output-category pairs occurrence-map
   (make-support-exactness-result/internal
    (if cartesian-objects? 'exact 'mismatch) degree-2-failures)
   (make-support-exactness-result/internal
    (if cartesian-arrows? 'exact 'mismatch) degree-3-failures)
   identities-preserved? inclusions-preserved?
   restriction-compatible? lower-compatible? upper-compatible?
   cartesian-objects? cartesian-arrows?
   (if (and cartesian-objects? cartesian-arrows?
            boundary-labels-exact? support-labels-exact?)
       'exact/cartesian
       'relation/profile-only))))

(define (all-profile-edges profile)
  (support-factorization-profile-edges profile))

(define (partition-profile-edges edges)
  (values
   (filter (lambda (edge)
             (and (eq? (support-profile-edge-output-sector edge) 'P)
                  (eq? (support-profile-edge-input-sector edge) 'P)))
           edges)
   (filter (lambda (edge)
             (and (eq? (support-profile-edge-output-sector edge) 'P)
                  (eq? (support-profile-edge-input-sector edge) 'Q)))
           edges)
   (filter (lambda (edge)
             (and (eq? (support-profile-edge-output-sector edge) 'Q)
                  (eq? (support-profile-edge-input-sector edge) 'P)))
           edges)
   (filter (lambda (edge)
             (and (eq? (support-profile-edge-output-sector edge) 'Q)
                  (eq? (support-profile-edge-input-sector edge) 'Q)))
           edges)))

(define (make-support-factorization-profile
         input-category output-category pairs
         #:status [status 'relation/profile-only])
  (define who 'make-support-factorization-profile)
  (check-category who input-category)
  (check-category who output-category)
  (unless (and (list? pairs)
               (andmap support-factorization-relation-pair? pairs))
    (raise-argument-error
     who "(listof support-factorization-relation-pair?)" pairs))
  (define edges
    (for/list ([pair (in-list pairs)])
      (define input (support-factorization-relation-pair-input pair))
      (define output (support-factorization-relation-pair-output pair))
      (check-category-object who input-category input)
      (check-category-object who output-category output)
      (make-support-profile-edge/internal
       input output (support-factorization-relation-pair-evidence pair)
       (support-factorization-object-sector input)
       (support-factorization-object-sector output))))
  (define-values (pp pq qp qq) (partition-profile-edges edges))
  (make-support-factorization-profile/internal
   input-category output-category edges pp pq qp qq status))

(define (support-factorization-comparison-profile comparison)
  (unless (support-factorization-comparison? comparison)
    (raise-argument-error
     'support-factorization-comparison-profile
     "support-factorization-comparison?" comparison))
  (make-support-factorization-profile
   (support-factorization-comparison-input-category comparison)
   (support-factorization-comparison-output-category comparison)
   (support-factorization-comparison-pairs comparison)
   #:status (support-factorization-comparison-status comparison)))

(define (partition-composite-edges edges)
  (define (sector object) (support-factorization-object-sector object))
  (values
   (filter (lambda (edge)
             (and (eq? (sector (support-composite-edge-output edge)) 'P)
                  (eq? (sector (support-composite-edge-input edge)) 'P)))
           edges)
   (filter (lambda (edge)
             (and (eq? (sector (support-composite-edge-output edge)) 'P)
                  (eq? (sector (support-composite-edge-input edge)) 'Q)))
           edges)
   (filter (lambda (edge)
             (and (eq? (sector (support-composite-edge-output edge)) 'Q)
                  (eq? (sector (support-composite-edge-input edge)) 'P)))
           edges)
   (filter (lambda (edge)
             (and (eq? (sector (support-composite-edge-output edge)) 'Q)
                  (eq? (sector (support-composite-edge-input edge)) 'Q)))
           edges)))

(define (compose-support-factorization-profiles
         first second #:limit [limit analysis-default-limit])
  (define who 'compose-support-factorization-profiles)
  (let/ec return
  (check-limit who limit)
  (unless (and (support-factorization-profile? first)
               (support-factorization-profile? second))
    (raise-argument-error
     who "two support-factorization-profile? values" (list first second)))
  (unless (eq? (support-factorization-profile-output-category first)
               (support-factorization-profile-input-category second))
    (raise-arguments-error
     who "profiles must share the exact intermediate category object"
     "first output"
     (support-factorization-profile-output-category first)
     "second input"
     (support-factorization-profile-input-category second)))
  (define required-work
    (* (length (all-profile-edges first))
       (length (all-profile-edges second))))
  (when (> required-work limit)
    (return
     (support-factorization-inconclusive
      who limit required-work 'profile-composition-pairs
      (hash 'first-edge-count (length (all-profile-edges first))
            'second-edge-count (length (all-profile-edges second))))))
  (define edges
    (for*/list ([first-edge (in-list (all-profile-edges first))]
                [second-edge (in-list (all-profile-edges second))]
                #:when
                (eq? (support-profile-edge-output first-edge)
                     (support-profile-edge-input second-edge)))
      (make-support-composite-edge/internal
       first-edge second-edge
       (support-profile-edge-input first-edge)
       (support-profile-edge-output first-edge)
       (support-profile-edge-output second-edge))))
  (define-values (pp pq qp qq) (partition-composite-edges edges))
  (define pp-direct
    (filter (lambda (edge)
              (eq? (support-factorization-object-sector
                    (support-composite-edge-intermediate edge))
                   'P))
            pp))
  (define excursions
    (filter (lambda (edge)
              (eq? (support-factorization-object-sector
                    (support-composite-edge-intermediate edge))
                   'Q))
            pp))
  (make-support-profile-composition/internal
   first second edges pp pq qp qq pp-direct excursions)))

(define (state-matches-object? state object)
  (case (support-factorization-object-kind object)
    [(empty) (eq? (macro-pointed-state-kind state) 'empty)]
    [(whole) (eq? (macro-pointed-state-kind state) 'whole)]
    [else
     (and (eq? (macro-pointed-state-kind state) 'proper)
          (equal?
           (cut-witness-addresses (macro-pointed-state-witness state))
           (cut-witness-addresses
            (support-factorization-object-native-witness object))))]))

(define (record->target-object category record)
  (cond
    [(macro-cut-audit-entry? record)
     (define witness (macro-cut-audit-entry-witness record))
     (define choice
       (if (null? (cut-witness-addresses witness))
           (empty-cut-choice)
           (proper-cut-choice (cut-witness-addresses witness))))
     (define ideal
       (cut-choice->ideal
        (support-factorization-category-ancestry category) choice))
     (support-factorization-category-object-at-ideal category ideal)]
    [(macro-whole-endpoint? record)
     (support-factorization-category-object-at-ideal
      category
      (ancestry-vertices
       (support-factorization-category-ancestry category)))]
    [else #f]))

(define (macro-occurrence-map source-category target-category summary)
  (define inputs (macro-summary-inputs summary))
  (and
   (= (length inputs) 1)
   (let ([prefix (macro-input-address (car inputs))]
         [target-addresses
          (map support-occurrence-address
               (support-factorization-category-occurrences target-category))])
     (define mappings
       (for/list
           ([occurrence
             (in-list
              (support-factorization-category-occurrences source-category))])
         (cons (support-occurrence-address occurrence)
               (address-append prefix
                               (support-occurrence-address occurrence)))))
     (and (for/and ([mapping (in-list mappings)])
            (address-member? (cdr mapping) target-addresses))
          (for/hash ([mapping (in-list mappings)])
            (values (car mapping) (cdr mapping)))))))

(define (audit-support-factorization-macro
         summary port filler profile #:limit [limit analysis-default-limit])
  (define who 'audit-support-factorization-macro)
  (check-limit who limit)
  (unless (macro-summary? summary)
    (raise-argument-error who "macro-summary?" summary))
  (unless (symbol? port)
    (raise-argument-error who "symbol?" port))
  (unless (complete-proof? filler)
    (raise-argument-error who "complete-proof?" filler))
  (unless (material-profile? profile)
    (raise-argument-error who "material-profile?" profile))
  (unless (and (eq? (macro-summary-calculus summary)
                    (material-profile-calculus profile))
               (eq? (checked-term-calculus filler)
                    (material-profile-calculus profile)))
    (raise-arguments-error
     who "summary, filler, and profile must share one exact calculus snapshot"
     "summary calculus" (macro-summary-calculus summary)
     "filler calculus" (checked-term-calculus filler)
     "profile calculus" (material-profile-calculus profile)))
  (define native-audit (audit-macro-cuts summary port filler #:limit limit))
  (define target (macro-cut-audit-target native-audit))
  (define source-category
    (compile-support-factorization-category filler profile #:limit limit))
  (define target-category
    (compile-support-factorization-category target profile #:limit limit))
  (define macro-positive? (> (macro-summary-fixed-vertex-count summary) 0))
  (define externally-linear?
    (and (= (length (macro-summary-inputs summary)) 1)
         (= (macro-summary-use-count summary port) 1)))
  (cond
    [(or (support-factorization-inconclusive? source-category)
         (support-factorization-inconclusive? target-category)
         (not (eq? (macro-cut-audit-completeness native-audit) 'complete)))
     (make-support-macro-audit/internal
      summary port filler native-audit source-category target-category
      '() #f #f macro-positive? externally-linear? #f
      'inconclusive-truncated
      '(factorization-or-native-enumeration-truncated))]
    [else
     (define incidence-exact?
       (and (eq? (support-factorization-category-incidence-status
                  source-category)
                 'exact)
            (eq? (support-factorization-category-incidence-status
                  target-category)
                 'exact)))
     (define relation-pairs
       (for/list
           ([object
             (in-list
              (support-factorization-category-objects source-category))]
            #:do
            [(define states
               (filter
                (lambda (state) (state-matches-object? state object))
                (macro-cut-audit-source-states native-audit)))]
            #:when (= (length states) 1)
            #:do
            [(define state (car states))
             (define record
               (macro-cut-audit-transport-source-state native-audit state))
             (define target-object
               (and record
                    (record->target-object target-category record)))]
            #:when target-object)
         (make-support-factorization-relation-pair
          object target-object (list state record))))
     (define occurrence-map
       (and externally-linear?
            (macro-occurrence-map source-category target-category summary)))
     (define comparison
       (and occurrence-map
            (audit-support-factorization-relation
             source-category target-category relation-pairs
             #:occurrence-map occurrence-map
             #:limit limit)))
     (define status
       (cond
         [(not incidence-exact?) 'unsupported-opaque-incidence]
         [(support-factorization-inconclusive? comparison)
          'inconclusive-truncated]
         [(not externally-linear?) 'relation/profile-only]
         [(and (support-factorization-comparison? comparison)
               (eq? (support-factorization-comparison-status comparison)
                    'exact/cartesian))
          'exact/cartesian]
         [else 'relation/profile-only]))
     (define reasons
       (append
        (if incidence-exact? '() '(opaque-incidence))
        (if externally-linear? '() '(copying-or-dropping))
        (if (support-factorization-inconclusive? comparison)
            '(relation-audit-limit-exceeded)
            '())
        (if (or (not (support-factorization-comparison? comparison))
                (eq? (support-factorization-comparison-status comparison)
                     'exact/cartesian))
            '()
            '(object-or-arrow-cartesianness-failed))
        (if (or macro-positive?
                (checked-hole? (macro-summary-context summary)))
            '()
            '(zero-vertex-nonidentity-macro))))
     (define profile-result
       (make-support-factorization-profile
        source-category target-category relation-pairs #:status status))
     (make-support-macro-audit/internal
      summary port filler native-audit source-category target-category
      relation-pairs comparison profile-result macro-positive? externally-linear?
      incidence-exact? status reasons)]))
