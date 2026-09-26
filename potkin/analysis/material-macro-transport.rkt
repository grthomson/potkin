#lang racket/base

;; Occurrence-certified material/profile-relative CK transport for native open
;; macros.  Every proof, puncture, cut witness, detached tuple, forest,
;; remainder, coaction, and core below is an existing POTKIN value.  The
;; records in this module are immutable audit metadata and cannot be consumed
;; as proof evidence.

(require racket/list
         "../algebra/formal-sum.rkt"
         "../hopf/antipode.rkt"
         "../kernel/address.rkt"
         "../kernel/check.rkt"
         "../kernel/context.rkt"
         "../kernel/cut.rkt"
         "macro-cut-audit.rkt"
         "macro-summary.rkt"
         "material-hopf-selector.rkt"
         "material-relative-core.rkt"
         "material-stock.rkt")

(provide material-macro-transport-plan?
         material-macro-transport-plan-summary
         material-macro-transport-plan-port
         material-macro-transport-plan-filler
         material-macro-transport-plan-selector
         material-macro-transport-plan-limit
         prepare-material-macro-transport
         run-material-macro-transport
         audit-material-macro-transport

         material-macro-root-alignment?
         material-macro-root-alignment-root
         material-macro-root-alignment-origin
         material-macro-root-alignment-hole-address
         material-macro-root-alignment-port
         material-macro-root-alignment-relative-address

         material-macro-record?
         material-macro-record-kind
         material-macro-record-native
         material-macro-record-roots
         material-macro-record-detached
         material-macro-record-forest
         material-macro-record-remainder
         material-macro-record-right-forest
         material-macro-record-alignment
         material-macro-record-reconstruction
         material-macro-record-origin
         material-macro-record-calculus
         material-macro-record-profile

         material-macro-match?
         material-macro-match-direct
         material-macro-match-staged
         material-macro-guard-failure?
         material-macro-guard-failure-strict-root
         material-macro-guard-failure-reason
         material-macro-guard-failure-offender-address
         material-macro-guard-failure-occurrence
         material-macro-guard-failure-masked-hole
         material-macro-copy-mapping?
         material-macro-copy-mapping-occurrence-address
         material-macro-copy-mapping-port
         material-macro-copy-mapping-source-to-target
         material-macro-dropped-input?
         material-macro-dropped-input-port
         material-macro-dropped-input-filler
         material-macro-dropped-input-reason
         material-macro-masked-hole?
         material-macro-masked-hole-roots
         material-macro-masked-hole-hole-address
         material-macro-masked-hole-port

         material-macro-transport?
         material-macro-transport-native-audit
         material-macro-transport-target
         material-macro-transport-direct
         material-macro-transport-staged
         material-macro-transport-guarded
         material-macro-transport-matched
         material-macro-transport-unexpected
         material-macro-transport-missing
         material-macro-transport-guard-failures
         material-macro-transport-copied
         material-macro-transport-dropped
         material-macro-transport-masked
         material-macro-transport-direct-coaction
         material-macro-transport-staged-coaction
         material-macro-transport-reference-coaction
         material-macro-transport-direct-core
         material-macro-transport-staged-core
         material-macro-transport-reference-core
         material-macro-transport-status
         material-macro-transport-reasons
         material-macro-transport-raw-curvature
         material-macro-transport-certified?

         material-macro-composition?
         material-macro-composition-composed-summary
         material-macro-composition-inner
         material-macro-composition-one-shot-audit
         material-macro-composition-two-stage-audit
         material-macro-composition-direct
         material-macro-composition-one-shot
         material-macro-composition-two-stage
         material-macro-composition-unexpected-one-shot
         material-macro-composition-missing-one-shot
         material-macro-composition-unexpected-two-stage
         material-macro-composition-missing-two-stage
         material-macro-composition-direct-coaction
         material-macro-composition-one-shot-coaction
         material-macro-composition-two-stage-coaction
         material-macro-composition-direct-core
         material-macro-composition-one-shot-core
         material-macro-composition-two-stage-core
         material-macro-composition-status
         material-macro-composition-reasons
         material-macro-composition-certified?
         audit-material-macro-composition)

(struct material-macro-transport-plan (summary port filler selector limit)
  #:constructor-name make-material-macro-transport-plan/internal
  #:transparent)

;; `origin` is either `macro` or `input`.  Logical port identity and native
;; hole-occurrence identity remain separate fields.
(struct material-macro-root-alignment
  (root origin hole-address port relative-address)
  #:constructor-name make-material-macro-root-alignment/internal
  #:transparent)

;; For an ordinary state, `native` is a macro-cut-audit-entry and `detached`
;; is its ordered native detached tuple.  For `whole`, `native` is the
;; witness-free macro-whole-endpoint, `detached` is empty, and the left/right
;; forest coordinates explicitly carry t and 1.  No root cut is fabricated.
(struct material-macro-record
  (kind native roots detached forest remainder right-forest alignment
        reconstruction origin calculus profile)
  #:constructor-name make-material-macro-record/internal
  #:transparent)

(struct material-macro-match (direct staged)
  #:constructor-name make-material-macro-match/internal
  #:transparent)
(struct material-macro-guard-failure
  (strict-root reason offender-address occurrence masked-hole)
  #:constructor-name make-material-macro-guard-failure/internal
  #:transparent)
(struct material-macro-copy-mapping (occurrence-address port source-to-target)
  #:constructor-name make-material-macro-copy-mapping/internal
  #:transparent)
(struct material-macro-dropped-input (port filler reason)
  #:constructor-name make-material-macro-dropped-input/internal
  #:transparent)
(struct material-macro-masked-hole (roots hole-address port)
  #:constructor-name make-material-macro-masked-hole/internal
  #:transparent)

(struct material-macro-transport
  (prepared native-audit target direct staged matched unexpected missing
        guard-failures copied dropped masked direct-coaction staged-coaction
        reference-coaction direct-core staged-core reference-core status
        reasons raw-curvature)
  #:constructor-name make-material-macro-transport/internal
  #:transparent)

(struct material-macro-composition
  (composed-summary inner one-shot-audit two-stage-audit direct one-shot
                    two-stage unexpected-one-shot missing-one-shot
                    unexpected-two-stage missing-two-stage direct-coaction
                    one-shot-coaction two-stage-coaction direct-core
                    one-shot-core two-stage-core status reasons)
  #:constructor-name make-material-macro-composition/internal
  #:transparent)

(define (material-macro-transport-guarded transport)
  (unless (material-macro-transport? transport)
    (raise-argument-error
     'material-macro-transport-guarded "material-macro-transport?" transport))
  (material-macro-transport-staged transport))

(define (material-macro-transport-certified? transport)
  (unless (material-macro-transport? transport)
    (raise-argument-error
     'material-macro-transport-certified? "material-macro-transport?"
     transport))
  (eq? (material-macro-transport-status transport) 'certified))

(define (material-macro-composition-certified? comparison)
  (unless (material-macro-composition? comparison)
    (raise-argument-error
     'material-macro-composition-certified? "material-macro-composition?"
     comparison))
  (eq? (material-macro-composition-status comparison) 'certified))

(define (find-summary-port summary port-name)
  (findf (lambda (port) (eq? (macro-port-name port) port-name))
         (macro-summary-ports summary)))

(define (prepare/internal who summary port-name filler selector limit
                          scan-filler?)
  (unless (macro-summary? summary)
    (raise-argument-error who "macro-summary?" summary))
  (unless (symbol? port-name)
    (raise-argument-error who "symbol?" port-name))
  (unless (complete-proof? filler)
    (raise-argument-error who "complete-proof?" filler))
  (unless (material-hopf-selector? selector)
    (raise-argument-error who "material-hopf-selector?" selector))
  (unless (exact-positive-integer? limit)
    (raise-argument-error who "exact-positive-integer?" limit))
  (define calculus (macro-summary-calculus summary))
  (unless (and (eq? calculus (material-hopf-selector-calculus selector))
               (eq? calculus (checked-term-calculus filler))
               (checked-term-has-exact-calculus? filler calculus))
    (raise-arguments-error
     who
     "macro, filler, and prepared selector must carry one exact calculus snapshot"
     "macro calculus" calculus
     "filler calculus" (checked-term-calculus filler)
     "selector calculus" (material-hopf-selector-calculus selector)))
  (define port (find-summary-port summary port-name))
  (unless port
    (raise-arguments-error who "the port is not declared by this summary"
                           "port" port-name))
  (unless (equal? (macro-port-boundary port)
                  (derivation-root-boundary filler))
    (raise-arguments-error
     who "the filler root must equal the selected port boundary"
     "port boundary" (macro-port-boundary port)
     "filler root" (derivation-root-boundary filler)))
  ;; These scans happen before cut enumeration.  They establish that the
  ;; prepared exact profile gives a total boolean classification on every
  ;; strict macro occurrence and (for a public one-stage plan) every filler
  ;; occurrence.  Holes contribute no fabricated vertex.
  (define profile (material-hopf-selector-profile selector))
  (when (checked-node? (macro-summary-context summary))
    (for ([use (in-list (direct-material-uses
                         (macro-summary-context summary) profile))])
      (unless (boolean? (material-use-designated? use))
        (error who "material classification is unavailable at ~e"
               (material-use-address use)))))
  (when scan-filler?
    (for ([use (in-list (direct-material-uses filler profile))])
      (unless (boolean? (material-use-designated? use))
        (error who "material classification is unavailable at ~e"
               (material-use-address use)))))
  (make-material-macro-transport-plan/internal
   summary port-name filler selector limit))

(define (prepare-material-macro-transport summary port-name filler selector
                                          #:limit [limit 4096])
  (prepare/internal 'prepare-material-macro-transport
                    summary port-name filler selector limit #t))

(define (singleton-forest calculus term)
  (make-proof-forest calculus (list term)))

(define (pointed-state-coordinates calculus filler state)
  (case (macro-pointed-state-kind state)
    [(empty)
     (cons (empty-proof-forest calculus)
           (singleton-forest calculus filler))]
    [(proper)
     (define witness (macro-pointed-state-witness state))
     (cons (cut-witness-forest witness)
           (singleton-forest calculus (cut-witness-remainder witness)))]
    [(whole)
     (cons (singleton-forest calculus filler)
           (empty-proof-forest calculus))]
    [else
     (error 'material-macro-transport
            "unknown source pointed-state kind: ~e"
            (macro-pointed-state-kind state))]))

(define (coaction-selects-state? coaction calculus filler state)
  (define coordinates (pointed-state-coordinates calculus filler state))
  (define coefficient
    (formal-sum-coefficient
     coaction (vector (car coordinates) (cdr coordinates))))
  (and (exact-integer? coefficient) (positive? coefficient)))

(define (record-coordinates record)
  (cons (material-macro-record-forest record)
        (material-macro-record-right-forest record)))

(define (records-select-state? records calculus filler state)
  (define coordinates (pointed-state-coordinates calculus filler state))
  (for/or ([record (in-list records)])
    (and (equal? (car coordinates) (material-macro-record-forest record))
         (equal? (cdr coordinates)
                 (material-macro-record-right-forest record)))))

(define (root-alignment summary root)
  (define owner
    (findf (lambda (input)
             (address-prefix? (macro-input-address input) root))
           (macro-summary-inputs summary)))
  (cond
    [owner
     (define prefix (macro-input-address owner))
     (make-material-macro-root-alignment/internal
      root 'input prefix (macro-input-port owner)
      (drop root (length prefix)))]
    [else
     (make-material-macro-root-alignment/internal
      root 'macro #f #f #f)]))

(define (alignment-origin alignments)
  (define macro? (ormap (lambda (entry)
                          (eq? (material-macro-root-alignment-origin entry)
                               'macro))
                        alignments))
  (define input? (ormap (lambda (entry)
                          (eq? (material-macro-root-alignment-origin entry)
                               'input))
                        alignments))
  (cond
    [(and macro? input?) 'mixed]
    [macro? 'macro-created]
    [input? 'input-transported]
    [else 'empty]))

(define (entry->record summary selector entry)
  (define calculus (material-hopf-selector-calculus selector))
  (define roots (macro-cut-audit-entry-addresses entry))
  (define alignment (map (lambda (root) (root-alignment summary root)) roots))
  (define remainder (macro-cut-audit-entry-remainder entry))
  (make-material-macro-record/internal
   (if (null? roots) 'empty 'proper)
   entry
   roots
   (macro-cut-audit-entry-detached entry)
   (macro-cut-audit-entry-forest entry)
   remainder
   (singleton-forest calculus remainder)
   alignment
   (macro-cut-audit-entry-reconstruction entry)
   (alignment-origin alignment)
   calculus
   (material-hopf-selector-profile selector)))

(define (endpoint->record summary selector endpoint)
  (define calculus (material-hopf-selector-calculus selector))
  (define target (macro-whole-endpoint-target endpoint))
  (make-material-macro-record/internal
   'whole endpoint '() '()
   (singleton-forest calculus target)
   #f
   (empty-proof-forest calculus)
   '()
   target
   'endpoint
   calculus
   (material-hopf-selector-profile selector)))

(define (record-native-equivalent? left right)
  (define left-native (material-macro-record-native left))
  (define right-native (material-macro-record-native right))
  (cond
    [(and (macro-cut-audit-entry? left-native)
          (macro-cut-audit-entry? right-native))
     (equal? (macro-cut-audit-entry-witness left-native)
             (macro-cut-audit-entry-witness right-native))]
    [(and (macro-whole-endpoint? left-native)
          (macro-whole-endpoint? right-native))
     (and (equal? (macro-whole-endpoint-target left-native)
                  (macro-whole-endpoint-target right-native))
          (not (cut-witness? left-native))
          (not (cut-witness? right-native)))]
    [else #f]))

(define (material-macro-record-equivalent? left right)
  (and (eq? (material-macro-record-calculus left)
            (material-macro-record-calculus right))
       (eq? (material-macro-record-profile left)
            (material-macro-record-profile right))
       (eq? (material-macro-record-kind left)
            (material-macro-record-kind right))
       (equal? (material-macro-record-roots left)
               (material-macro-record-roots right))
       (equal? (material-macro-record-detached left)
               (material-macro-record-detached right))
       (equal? (material-macro-record-forest left)
               (material-macro-record-forest right))
       (equal? (material-macro-record-remainder left)
               (material-macro-record-remainder right))
       (equal? (material-macro-record-right-forest left)
               (material-macro-record-right-forest right))
       (equal? (material-macro-record-alignment left)
               (material-macro-record-alignment right))
       (equal? (material-macro-record-reconstruction left)
               (material-macro-record-reconstruction right))
       (eq? (material-macro-record-origin left)
            (material-macro-record-origin right))
       (record-native-equivalent? left right)))

(define (extract-first predicate items)
  (let loop ([prefix '()] [remaining items])
    (cond
      [(null? remaining) (values #f items)]
      [(predicate (car remaining))
       (values (car remaining)
               (append (reverse prefix) (cdr remaining)))]
      [else (loop (cons (car remaining) prefix) (cdr remaining))])))

(define (match-records direct staged)
  (let loop ([remaining-direct direct]
             [remaining-staged staged]
             [matched '()]
             [unexpected '()])
    (cond
      [(null? remaining-direct)
       (values (reverse matched) (reverse unexpected) remaining-staged)]
      [else
       (define current (car remaining-direct))
       (define-values (found rest)
         (extract-first
          (lambda (candidate)
            (material-macro-record-equivalent? current candidate))
          remaining-staged))
       (if found
           (loop (cdr remaining-direct) rest
                 (cons (make-material-macro-match/internal current found)
                       matched)
                 unexpected)
           (loop (cdr remaining-direct) remaining-staged matched
                 (cons current unexpected)))])))

(define (strict-addresses summary)
  (if (checked-node? (macro-summary-context summary))
      (filter pair? (vertex-addresses (macro-summary-context summary)))
      '()))

(define (entry-strict-roots summary entry)
  (define strict (strict-addresses summary))
  (filter (lambda (root) (member root strict equal?))
          (macro-cut-audit-entry-addresses entry)))

(define (hole-masked? strict-roots hole-address)
  (for/or ([root (in-list strict-roots)])
    (proper-address-prefix? root hole-address)))

(define (subtree-guard-failures summary selector filler whole-selected?
                                strict-root inspect-filler?)
  (define profile (material-hopf-selector-profile selector))
  (define subtree
    (checked-term-at-address (macro-summary-context summary) strict-root))
  (unless (checked-node? subtree)
    (error 'material-macro-transport
           "strict macro root is not a native vertex: ~e" strict-root))
  (define filler-blocker
    (and inspect-filler?
         (findf (lambda (use) (not (material-use-designated? use)))
                (direct-material-uses filler profile))))
  (define (walk term address)
    (cond
      [(checked-hole? term)
       (if whole-selected?
           '()
           (list
            (make-material-macro-guard-failure/internal
             strict-root
             'masked-filler-whole-not-selected
             (if filler-blocker
                 (address-append address
                                 (material-use-address filler-blocker))
                 address)
             (and filler-blocker
                  (material-use-occurrence filler-blocker))
             address)))]
      [else
       (append
        (if (material-profile-designates?
             profile (checked-node-occurrence term))
            '()
            (list
             (make-material-macro-guard-failure/internal
              strict-root
              'strict-occurrence-not-selected
              address
              (checked-node-occurrence term)
              #f)))
        (append-map
         (lambda (slot+child)
           (walk (cdr slot+child)
                 (address-append address (list (car slot+child)))))
         (for/list ([child (in-list (checked-node-children term))]
                    [slot (in-naturals 1)])
           (cons slot child))))]))
  (walk subtree strict-root))

(define (whole-macro-eligible? summary selector filler whole-selected?)
  (define profile (material-hopf-selector-profile selector))
  (define (walk term)
    (cond
      [(checked-hole? term) whole-selected?]
      [else
       (and (material-profile-designates?
             profile (checked-node-occurrence term))
            (andmap walk (checked-node-children term)))]))
  (walk (macro-summary-context summary)))

(define (expected-embedded-addresses profile-entry)
  (define prefix (macro-copy-profile-entry-occurrence-address profile-entry))
  (define state (macro-copy-profile-entry-source-state profile-entry))
  (case (macro-pointed-state-kind state)
    [(empty) '()]
    [(proper)
     (map (lambda (relative) (address-append prefix relative))
          (cut-witness-addresses (macro-pointed-state-witness state)))]
    [(whole) (and (pair? prefix) (list prefix))]
    [else #f]))

(define (copy-profile-consistent? entry)
  (for/and ([profile-entry
             (in-list (macro-cut-audit-entry-copy-profile entry))])
    (equal? (expected-embedded-addresses profile-entry)
            (macro-copy-profile-entry-embedded-addresses profile-entry))))

(define (copy-mappings summary filler)
  (for/list ([input (in-list (macro-summary-inputs summary))])
    (define prefix (macro-input-address input))
    (make-material-macro-copy-mapping/internal
     prefix
     (macro-input-port input)
     (for/list ([relative (in-list (vertex-addresses filler))])
       (cons relative (address-append prefix relative))))))

(define (dropped-inputs summary port-name filler)
  (if (zero? (macro-summary-use-count summary port-name))
      (list
       (make-material-macro-dropped-input/internal
        port-name filler 'globally-unused-logical-port))
      '()))

(define (records->coaction calculus records)
  (make-formal-sum
   calculus 2
   (for/list ([record (in-list records)])
     (cons (vector (material-macro-record-forest record)
                   (material-macro-record-right-forest record))
           1))))

(define (contract-coaction selector coaction)
  (define calculus (material-hopf-selector-calculus selector))
  (cond
    [(not (and (formal-sum? coaction)
               (= (formal-sum-rank coaction) 2)
               (eq? (formal-sum-calculus coaction) calculus)))
     #f]
    [else
     (let loop ([terms (formal-sum-terms coaction)]
                [result (formal-zero calculus)])
       (cond
         [(null? terms) result]
         [else
          (define term (car terms))
          (define key (car term))
          (define coefficient (cdr term))
          (define left (vector-ref key 0))
          (define right (vector-ref key 1))
          (define antipode-value (forest-antipode left))
          (cond
            [(not (formal-sum? antipode-value)) antipode-value]
            [(for/or ([support-term (in-list
                                     (formal-sum-terms antipode-value))])
               (not
                (material-hopf-selector-forest-pure?
                 selector (vector-ref (car support-term) 0))))
             #f]
            [else
             (define product
               (formal-sum-multiply antipode-value (forest-basis right)))
             (define scaled
               (and (formal-sum? product)
                    (formal-sum-scale coefficient product)))
             (define next
               (and (formal-sum? scaled)
                    (formal-sum-add result scaled)))
             (if (formal-sum? next)
                 (loop (cdr terms) next)
                 (or next scaled product))])]))]))

(define (make-inconclusive plan audit copied dropped status reason)
  (make-material-macro-transport/internal
   plan audit (and audit (macro-cut-audit-target audit))
   '() '() '() '() '() '() copied dropped '()
   #f #f #f #f #f #f status (list reason)
   'raw-curvature-unavailable))

(define (run-plan/internal plan
                           #:canonical-summary
                           [canonical-summary
                            (material-macro-transport-plan-summary plan)]
                           #:source-audit [source-audit #f]
                           #:source-records [source-records #f]
                           #:inspect-filler? [inspect-filler? #t])
  (define summary (material-macro-transport-plan-summary plan))
  (define port-name (material-macro-transport-plan-port plan))
  (define filler (material-macro-transport-plan-filler plan))
  (define selector (material-macro-transport-plan-selector plan))
  (define limit (material-macro-transport-plan-limit plan))
  (define calculus (macro-summary-calculus summary))
  (define audit
    (audit-macro-cuts summary port-name filler
                      #:limit limit
                      #:source-audit source-audit))
  (define copied (copy-mappings summary filler))
  (define dropped (dropped-inputs summary port-name filler))
  (cond
    [(eq? (macro-cut-audit-completeness audit) 'truncated)
     (make-inconclusive plan audit copied dropped 'truncated
                        'native-witness-limit-exceeded)]
    [else
     (define target (macro-cut-audit-target audit))
     (define target-basis (checked-node-basis target))
     (define reference-coaction
       (material-hopf-selector-coaction selector target-basis))
     (unless (formal-sum? reference-coaction)
       (error 'run-material-macro-transport
              "native material coaction was unavailable: ~e"
              reference-coaction))
     (define input-coaction
       (and (not source-records)
            (material-hopf-selector-coaction
             selector (checked-node-basis filler))))
     (when (and (not source-records) (not (formal-sum? input-coaction)))
       (error 'run-material-macro-transport
              "native filler material coaction was unavailable: ~e"
              input-coaction))
     (define (source-selected? state)
       (if source-records
           (records-select-state? source-records calculus filler state)
           (coaction-selects-state?
            input-coaction calculus filler state)))
     (define whole-state
       (findf (lambda (state)
                (eq? (macro-pointed-state-kind state) 'whole))
              (macro-cut-audit-source-states audit)))
     (define whole-selected? (and whole-state (source-selected? whole-state)))

     ;; Direct oracle: only the natively filled target and each native
     ;; detached forest are inspected.  No macro decomposition participates.
     (define direct
       (append
        (for/list ([entry (in-list (macro-cut-audit-entries audit))]
                   #:when
                   (material-hopf-selector-forest-pure?
                    selector (macro-cut-audit-entry-forest entry)))
          (entry->record canonical-summary selector entry))
        (if (material-hopf-selector-forest-pure?
             selector (singleton-forest calculus target))
            (list
             (endpoint->record canonical-summary selector
                               (macro-cut-audit-endpoint audit)))
            '())))

     ;; Guarded staged path: selection depends only on strict skeleton
     ;; occurrences and the already selected source endpoint profile.
     (define guard-failures '())
     (define masked '())
     (define staged-ordinary
       (reverse
        (for/fold ([kept '()])
                  ([entry (in-list
                           (macro-cut-audit-compositional-entries audit))])
          (define strict-roots (entry-strict-roots summary entry))
          (define failures
            (append-map
             (lambda (root)
               (subtree-guard-failures
                summary selector filler whole-selected? root inspect-filler?))
             strict-roots))
          (set! guard-failures (append failures guard-failures))
          (define inputs-selected?
            (for/and ([profile-entry
                       (in-list
                        (macro-cut-audit-entry-copy-profile entry))])
              (or (hole-masked?
                   strict-roots
                   (macro-copy-profile-entry-occurrence-address profile-entry))
                  (source-selected?
                   (macro-copy-profile-entry-source-state profile-entry)))))
          (cond
            [(and (null? failures) inputs-selected?)
             (for ([profile-entry
                    (in-list (macro-cut-audit-entry-copy-profile entry))]
                   #:when
                   (hole-masked?
                    strict-roots
                    (macro-copy-profile-entry-occurrence-address profile-entry)))
               (set!
                masked
                (cons
                 (make-material-macro-masked-hole/internal
                  (macro-cut-audit-entry-addresses entry)
                  (macro-copy-profile-entry-occurrence-address profile-entry)
                  (macro-copy-profile-entry-port profile-entry))
                 masked)))
             (cons (entry->record canonical-summary selector entry) kept)]
            [else kept]))))
     (define staged
       (append
        staged-ordinary
        (if (whole-macro-eligible?
             summary selector filler whole-selected?)
            (list
             (endpoint->record canonical-summary selector
                               (macro-cut-audit-endpoint audit)))
            '())))
     (set! guard-failures
           (remove-duplicates (reverse guard-failures) equal?))
     (set! masked (remove-duplicates (reverse masked) equal?))

     (define-values (matched unexpected missing)
       (match-records direct staged))
     (define direct-coaction (records->coaction calculus direct))
     (define staged-coaction (records->coaction calculus staged))
     (define direct-core (contract-coaction selector direct-coaction))
     (define staged-core (contract-coaction selector staged-coaction))
     (define reference-core
       (material-hopf-selector-relative-core selector target-basis))
     (define algebra-available?
       (and (formal-sum? direct-coaction)
            (formal-sum? staged-coaction)
            (formal-sum? reference-coaction)
            (formal-sum? direct-core)
            (formal-sum? staged-core)
            (formal-sum? reference-core)))
     (define reconstruction-ok?
       (andmap
        (lambda (record)
          (and (equal? (material-macro-record-reconstruction record) target)
               (or (not (eq? (material-macro-record-kind record) 'whole))
                   (and (macro-whole-endpoint?
                         (material-macro-record-native record))
                        (not (cut-witness?
                              (material-macro-record-native record)))))))
        (append direct staged)))
     (define prefix-evidence-ok?
       (andmap copy-profile-consistent?
               (macro-cut-audit-compositional-entries audit)))
     (define occurrence-square?
       (and (macro-cut-audit-direct=compositional? audit)
            (null? unexpected)
            (null? missing)
            reconstruction-ok?
            prefix-evidence-ok?))
     (define coaction-square?
       (and algebra-available?
            (equal? direct-coaction staged-coaction)
            (equal? direct-coaction reference-coaction)))
     (define core-square?
       (and algebra-available?
            (equal? direct-core staged-core)
            (equal? direct-core reference-core)))
     (define status
       (cond
         [(not algebra-available?) 'unavailable]
         [(and occurrence-square? coaction-square? core-square?) 'certified]
         [else 'mismatch]))
     (define reasons
       (append
        (if (macro-cut-audit-direct=compositional? audit)
            '() '(underlying-macro-cut-square-mismatch))
        (if (null? unexpected) '() '(unexpected-direct-records))
        (if (null? missing) '() '(missing-staged-predictions))
        (if reconstruction-ok? '() '(native-reconstruction-mismatch))
        (if prefix-evidence-ok? '() '(address-prefix-evidence-mismatch))
        (if algebra-available? '() '(native-algebra-unavailable))
        (if coaction-square? '() '(coaction-mismatch))
        (if core-square? '() '(relative-core-mismatch))))
     (make-material-macro-transport/internal
      plan audit target direct staged matched unexpected missing
      guard-failures copied dropped masked direct-coaction staged-coaction
      reference-coaction direct-core staged-core reference-core status reasons
      'raw-curvature-unavailable)]))

(define (run-material-macro-transport plan)
  (unless (material-macro-transport-plan? plan)
    (raise-argument-error
     'run-material-macro-transport "material-macro-transport-plan?" plan))
  (run-plan/internal plan))

(define (audit-material-macro-transport summary port-name filler selector
                                        #:limit [limit 4096])
  (run-material-macro-transport
   (prepare-material-macro-transport
    summary port-name filler selector #:limit limit)))

(define (composition-inconclusive composed-summary inner one-shot status reason)
  (make-material-macro-composition/internal
   composed-summary inner one-shot #f '() '() '()
   '() '() '() '() #f #f #f #f #f #f status (list reason)))

(define (audit-material-macro-composition
         outer outer-port inner inner-port filler selector
         #:limit [limit 4096])
  (unless (and (macro-summary? outer) (macro-summary? inner))
    (raise-argument-error
     'audit-material-macro-composition
     "two macro-summary? values"
     (list outer inner)))
  (define inner-result
    (audit-material-macro-transport
     inner inner-port filler selector #:limit limit))
  (define composed-summary
    (macro-summary-substitute outer outer-port inner))
  (cond
    [(not (material-macro-transport-certified? inner-result))
     (composition-inconclusive
      composed-summary inner-result #f
      (material-macro-transport-status inner-result)
      'inner-transport-not-certified)]
    [else
     (define one-shot
       (audit-material-macro-transport
        composed-summary inner-port filler selector #:limit limit))
     (cond
       [(not (material-macro-transport-certified? one-shot))
        (composition-inconclusive
         composed-summary inner-result one-shot
         (material-macro-transport-status one-shot)
         'one-shot-transport-not-certified)]
       [else
        (define inner-target (material-macro-transport-target inner-result))
        ;; This internal preparation deliberately does not rescan the completed
        ;; inner target.  Its selected endpoint profile and full native cut
        ;; states come from the already completed inner transport/audit.
        (define outer-plan
          (prepare/internal
           'audit-material-macro-composition
           outer outer-port inner-target selector limit #f))
        (define two-stage
          (run-plan/internal
           outer-plan
           #:canonical-summary composed-summary
           #:source-audit
           (material-macro-transport-native-audit inner-result)
           #:source-records (material-macro-transport-staged inner-result)
           #:inspect-filler? #f))
        (cond
          [(not (material-macro-transport-certified? two-stage))
           (composition-inconclusive
            composed-summary inner-result one-shot
            (material-macro-transport-status two-stage)
            'two-stage-transport-not-certified)]
          [else
           (define direct (material-macro-transport-direct one-shot))
           (define one-shot-records
             (material-macro-transport-staged one-shot))
           (define two-stage-records
             (material-macro-transport-staged two-stage))
           (define-values (_matches-one unexpected-one missing-one)
             (match-records direct one-shot-records))
           (define-values (_matches-two unexpected-two missing-two)
             (match-records direct two-stage-records))
           (define direct-coaction
             (material-macro-transport-direct-coaction one-shot))
           (define one-shot-coaction
             (material-macro-transport-staged-coaction one-shot))
           (define two-stage-coaction
             (material-macro-transport-staged-coaction two-stage))
           (define direct-core
             (material-macro-transport-direct-core one-shot))
           (define one-shot-core
             (material-macro-transport-staged-core one-shot))
           (define two-stage-core
             (material-macro-transport-staged-core two-stage))
           (define certified?
             (and (null? unexpected-one) (null? missing-one)
                  (null? unexpected-two) (null? missing-two)
                  (equal? direct-coaction one-shot-coaction)
                  (equal? direct-coaction two-stage-coaction)
                  (equal? direct-core one-shot-core)
                  (equal? direct-core two-stage-core)))
           (define reasons
             (append
              (if (and (null? unexpected-one) (null? missing-one))
                  '() '(one-shot-occurrence-mismatch))
              (if (and (null? unexpected-two) (null? missing-two))
                  '() '(two-stage-occurrence-mismatch))
              (if (and (equal? direct-coaction one-shot-coaction)
                       (equal? direct-coaction two-stage-coaction))
                  '() '(nested-coaction-mismatch))
              (if (and (equal? direct-core one-shot-core)
                       (equal? direct-core two-stage-core))
                  '() '(nested-relative-core-mismatch))))
           (make-material-macro-composition/internal
            composed-summary inner-result one-shot two-stage
            direct one-shot-records two-stage-records
            unexpected-one missing-one unexpected-two missing-two
            direct-coaction one-shot-coaction two-stage-coaction
            direct-core one-shot-core two-stage-core
            (if certified? 'certified 'mismatch) reasons)])])]))
