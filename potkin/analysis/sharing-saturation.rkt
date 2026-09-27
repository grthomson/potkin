#lang racket/base

;; Source-sharing saturation over an existing native checked proof tree.
;;
;; A sharing source map and every structure below are immutable analysis
;; metadata.  They are never accepted by the checker, cut constructor,
;; filling operations, or the CK algebra as proof evidence.  Native POTKIN
;; checked terms and cut witnesses remain authoritative throughout.
;;
;; Paper proof boundary (not a proof-assistant formalisation).  For a source
;; subset S, if one source reaches another, extending a root-to-source path
;; makes two members of q^-1(S) prefix-comparable.  Conversely, comparable
;; occurrence paths have reachability-comparable endpoints; two comparable
;; paths ending at one source would induce a source cycle, rejected below.
;; Hence q^-1(S) is a native CK antichain exactly when S is a strict-source
;; reachability antichain.  Fibre saturation then gives the stated bijection
;; with saturated ordinary witnesses; empty and witness-free whole endpoints
;; are retained separately.
;;
;; For the action audit, one stored output fixes one local action and one
;; ordered tuple of child variants.  Unequal recursively complete states
;; therefore cannot share in any source-respecting folding (the lower bound).
;; Conversely, one variant per equal (source, complete-state) class, routed to
;; the already classified ordered child states, unfolds to the requested
;; transformed tree (sufficiency).  This proves minimality only for the fixed
;; transformed occurrence tree and source-respecting foldings; it supplies no
;; logical contraction, Mix, communication, or general DAG theorem.

(require racket/list
         racket/vector
         "../kernel/address.rkt"
         "../kernel/calculus.rkt"
         "../kernel/check.rkt"
         "../kernel/component-incidence.rkt"
         "../kernel/context.rkt"
         "../kernel/cut.rkt")

(provide sharing-source-map?
         make-sharing-source-map
         sharing-source-map-calculus
         sharing-source-map-bindings
         sharing-source-map-source-at

         sharing-source-node?
         sharing-source-node-id
         sharing-source-node-occurrence
         sharing-source-node-boundary
         sharing-source-node-arity
         sharing-source-node-incidence
         sharing-source-node-child-source-ids
         sharing-source-node-fibre
         sharing-source-node-use-multiplicity
         sharing-use-edge?
         sharing-use-edge-parent-source
         sharing-use-edge-premise-slot
         sharing-use-edge-child-source
         sharing-use-edge-occurrence-uses

         sharing-cut-record?
         sharing-cut-record-kind
         sharing-cut-record-native-witness
         sharing-cut-record-addresses
         sharing-cut-record-source-ids
         sharing-cut-record-detached
         sharing-cut-record-forest
         sharing-cut-record-remainder
         sharing-cut-record-reconstruction
         sharing-cut-record-saturated?
         sharing-residual?
         sharing-residual-records
         sharing-residual-support-size

         sharing-source-subset?
         sharing-source-subset-source-ids
         sharing-source-subset-addresses
         sharing-source-subset-antichain?
         sharing-source-subset-prefix-free?
         sharing-antichain-match?
         sharing-antichain-match-source-subset
         sharing-antichain-match-cut-record

         sharing-character-polynomial?
         sharing-character-polynomial-source-order
         sharing-character-polynomial-terms
         sharing-character-polynomial-coefficient
         sharing-character-polynomial-degree
         sharing-character-expansion?
         sharing-character-expansion-status
         sharing-character-expansion-polynomial
         sharing-character-expansion-term-count
         sharing-character-expansion-term-limit
         expand-sharing-source-character

         sharing-saturation-audit?
         sharing-saturation-audit-proof
         sharing-saturation-audit-source-map
         sharing-saturation-audit-source-nodes
         sharing-saturation-audit-use-edges
         sharing-saturation-audit-records
         sharing-saturation-audit-saturated
         sharing-saturation-audit-unsaturated
         sharing-saturation-audit-residual
         sharing-saturation-audit-source-subsets
         sharing-saturation-audit-antichains
         sharing-saturation-audit-antichain-matches
         sharing-saturation-audit-unexpected-saturated
         sharing-saturation-audit-missing-saturated
         sharing-saturation-audit-native-character
         sharing-saturation-audit-recurrence-character
         sharing-saturation-audit-saturated-character
         sharing-saturation-audit-recurrence-saturated-character
         sharing-saturation-audit-laws
         sharing-saturation-audit-status
         sharing-saturation-audit-reasons
         sharing-saturation-audit-witness-count
         sharing-saturation-audit-antichain-candidate-count
         sharing-saturation-certified?
         audit-sharing-saturation

         sharing-local-action-key?
         make-sharing-local-action-key
         sharing-local-action-key-kind
         sharing-local-action-key-payload
         sharing-action-class?
         sharing-action-class-source-id
         sharing-action-class-key
         sharing-action-class-occurrence-addresses
         sharing-state-variant?
         sharing-state-variant-source-id
         sharing-state-variant-index
         sharing-state-variant-state
         sharing-state-variant-occurrence-addresses
         sharing-routing?
         sharing-routing-occurrence-address
         sharing-routing-source-id
         sharing-routing-variant-index
         sharing-routing-ordered-child-variants
         sharing-action-audit?
         sharing-action-audit-local-classes
         sharing-action-audit-variants
         sharing-action-audit-routings
         sharing-action-audit-variant-counts
         sharing-action-audit-active-addresses
         sharing-action-audit-hidden-addresses
         sharing-action-audit-status
         sharing-action-audit-reasons
         sharing-action-audit-laws
         sharing-action-audit-variant-count
         audit-sharing-actions)

(struct sharing-source-map (calculus table bindings)
  #:constructor-name make-sharing-source-map/internal
  #:transparent)
(struct sharing-source-node
  (id occurrence boundary arity incidence child-source-ids fibre
      use-multiplicity)
  #:constructor-name make-sharing-source-node/internal
  #:transparent)
(struct sharing-use-edge
  (parent-source premise-slot child-source occurrence-uses)
  #:constructor-name make-sharing-use-edge/internal
  #:transparent)
(struct sharing-cut-record
  (kind native-witness addresses source-ids detached forest remainder
        reconstruction saturated?)
  #:constructor-name make-sharing-cut-record/internal
  #:transparent)
(struct sharing-residual (records support-size)
  #:constructor-name make-sharing-residual/internal
  #:transparent)
(struct sharing-source-subset
  (source-ids addresses antichain? prefix-free?)
  #:constructor-name make-sharing-source-subset/internal
  #:transparent)
(struct sharing-antichain-match (source-subset cut-record)
  #:constructor-name make-sharing-antichain-match/internal
  #:transparent)

;; Exponents are stored in immutable vectors aligned with `source-order`.
;; This is a scalar diagnostic, not POTKIN's proof-forest formal-sum carrier.
(struct sharing-character-polynomial (source-order coefficient-table)
  #:constructor-name make-sharing-character-polynomial/internal
  #:transparent)
(struct sharing-character-expansion (status polynomial term-count term-limit)
  #:constructor-name make-sharing-character-expansion/internal
  #:transparent)

(struct sharing-saturation-audit
  (proof source-map source-nodes use-edges records saturated unsaturated
         residual source-subsets antichains antichain-matches
         unexpected-saturated missing-saturated native-character
         recurrence-character saturated-character
         recurrence-saturated-character laws status reasons witness-count
         antichain-candidate-count)
  #:constructor-name make-sharing-saturation-audit/internal
  #:transparent)

(struct sharing-local-action-key (kind payload)
  #:constructor-name make-sharing-local-action-key/internal
  #:transparent)
(struct sharing-action-class (source-id key occurrence-addresses)
  #:constructor-name make-sharing-action-class/internal
  #:transparent)
(struct sharing-state-variant (source-id index state occurrence-addresses)
  #:constructor-name make-sharing-state-variant/internal
  #:transparent)
(struct sharing-routing
  (occurrence-address source-id variant-index ordered-child-variants)
  #:constructor-name make-sharing-routing/internal
  #:transparent)
(struct sharing-action-audit
  (local-classes variants routings variant-counts active-addresses
                 hidden-addresses status reasons laws)
  #:constructor-name make-sharing-action-audit/internal
  #:transparent)

(define (stable-metadata? value)
  (cond
    [(or (and (symbol? value) (symbol-interned? value))
         (keyword? value) (number? value) (boolean? value) (char? value)
         (null? value))
     #t]
    [(string? value) (immutable? value)]
    [(bytes? value) (immutable? value)]
    [(pair? value)
     (and (stable-metadata? (car value))
          (stable-metadata? (cdr value)))]
    [(vector? value)
     (and (immutable? value)
          (for/and ([item (in-vector value)]) (stable-metadata? item)))]
    [(box? value)
     (and (immutable? value) (stable-metadata? (unbox value)))]
    [(hash? value)
     (and (immutable? value)
          (for/and ([(key item) (in-hash value)])
            (and (stable-metadata? key) (stable-metadata? item))))]
    [else #f]))

(define (make-sharing-source-map calculus bindings)
  (define who 'make-sharing-source-map)
  (unless (equipped-calculus? calculus)
    (raise-argument-error who "equipped-calculus?" calculus))
  (unless (list? bindings)
    (raise-argument-error who "association list" bindings))
  (define seen (make-hash))
  (define normalized
    (for/list ([binding (in-list bindings)])
      (unless (and (pair? binding)
                   (address? (car binding))
                   (stable-metadata? (cdr binding)))
        (raise-arguments-error
         who
         "each binding must pair a native vertex address with stable immutable source metadata"
         "binding" binding))
      (define address (car binding))
      (when (hash-has-key? seen address)
        (raise-arguments-error who "a vertex address may be mapped only once"
                               "address" address))
      (hash-set! seen address #t)
      (cons address (cdr binding))))
  (define sorted
    (sort normalized (lambda (left right) (address<? (car left) (car right)))))
  (make-sharing-source-map/internal
   calculus
   (for/hash ([binding (in-list sorted)])
     (values (car binding) (cdr binding)))
   sorted))

(define (sharing-source-map-source-at source-map address)
  (unless (sharing-source-map? source-map)
    (raise-argument-error
     'sharing-source-map-source-at "sharing-source-map?" source-map))
  (unless (address? address)
    (raise-argument-error 'sharing-source-map-source-at "address?" address))
  (hash-ref (sharing-source-map-table source-map) address
            (lambda ()
              (raise-arguments-error
               'sharing-source-map-source-at
               "the source map has no entry at this address"
               "address" address))))

(define (source-at source-map address)
  (hash-ref (sharing-source-map-table source-map) address))

(define (validate-total-map who proof source-map)
  (unless (complete-proof? proof)
    (raise-argument-error who "complete-proof?" proof))
  (unless (sharing-source-map? source-map)
    (raise-argument-error who "sharing-source-map?" source-map))
  (define calculus (checked-term-calculus proof))
  (unless (and (eq? calculus (sharing-source-map-calculus source-map))
               (checked-term-has-exact-calculus? proof calculus)
               (term-admitted-by? calculus proof))
    (raise-arguments-error
     who
     "proof and source map must carry one exact admitted calculus snapshot"
     "proof calculus" calculus
     "source-map calculus" (sharing-source-map-calculus source-map)))
  (define addresses (vertex-addresses proof))
  (define table (sharing-source-map-table source-map))
  (unless (= (hash-count table) (length addresses))
    (raise-arguments-error
     who "the source map must cover every native vertex exactly once"
     "vertex count" (length addresses)
     "mapping count" (hash-count table)))
  (for ([address (in-list addresses)])
    (unless (hash-has-key? table address)
      (raise-arguments-error who "the source map omits a native vertex"
                             "address" address)))
  (for ([address (in-hash-keys table)])
    (unless (member address addresses equal?)
      (raise-arguments-error who "the source map names a nonvertex address"
                             "address" address)))
  addresses)

(define (group-addresses source-map addresses)
  (for/fold ([groups (hash)]) ([address (in-list addresses)])
    (hash-update groups (source-at source-map address)
                 (lambda (prior) (cons address prior)) '())))

(define (node-at proof address)
  (define node (vertex-at-address proof address))
  (unless node
    (error 'sharing-saturation "validated vertex disappeared at ~e" address))
  node)

(define (child-source-ids source-map address node)
  (for/list ([child (in-list (checked-node-children node))]
             [slot (in-naturals 1)])
    (source-at source-map (address-append address (list slot)))))

(define (validate-source-nodes who proof source-map addresses)
  (define groups (group-addresses source-map addresses))
  (define ordered-groups
    (sort
     (for/list ([(source fibre) (in-hash groups)])
       (cons source (sort fibre address<?)))
     (lambda (left right) (address<? (cadr left) (cadr right)))))
  (for/list ([group (in-list ordered-groups)])
    (define source-id (car group))
    (define fibre (cdr group))
    (define representative-address (car fibre))
    (define representative (node-at proof representative-address))
    (define occurrence (checked-node-occurrence representative))
    (define boundary (derivation-root-boundary representative))
    (define arity (length (checked-node-children representative)))
    (define incidence (concrete-occurrence-incidence occurrence))
    (define children
      (child-source-ids source-map representative-address representative))
    (when (and (> (length fibre) 1)
               (not (component-incidence? incidence)))
      (raise-arguments-error
       who
       "shared source occurrences require exact endpoint-validated component incidence"
       "source id" source-id
       "fibre" fibre
       "opaque incidence" incidence))
    (for ([address (in-list (cdr fibre))])
      (define current (node-at proof address))
      (define current-occurrence (checked-node-occurrence current))
      (unless (eq? occurrence current-occurrence)
        (raise-arguments-error
         who "one source class contains different exact registry occurrences"
         "source id" source-id
         "representative address" representative-address
         "incompatible address" address))
      (unless (and (equal? boundary (derivation-root-boundary current))
                   (= arity (length (checked-node-children current)))
                   (equal? incidence
                           (concrete-occurrence-incidence current-occurrence)))
        (raise-arguments-error
         who "one source class has incompatible boundary, arity, or incidence"
         "source id" source-id
         "incompatible address" address))
      (define current-children
        (child-source-ids source-map address current))
      (unless (equal? children current-children)
        (raise-arguments-error
         who
         "one source class permutes or changes its ordered child-source tuple"
         "source id" source-id
         "expected ordered children" children
         "actual ordered children" current-children
         "incompatible address" address)))
    (make-sharing-source-node/internal
     source-id occurrence boundary arity incidence children fibre
     (length fibre))))

(define (source-node-table nodes)
  (for/hash ([node (in-list nodes)])
    (values (sharing-source-node-id node) node)))

(define (validate-acyclic! who nodes)
  (define table (source-node-table nodes))
  (define colors (make-hash))
  (define (visit source trail)
    (case (hash-ref colors source 'white)
      [(black) (void)]
      [(gray)
       (raise-arguments-error
        who "the derived source graph is cyclic"
        "cycle source" source
        "source trail" (reverse (cons source trail)))]
      [else
       (hash-set! colors source 'gray)
       (define node (hash-ref table source))
       (for ([child (in-list
                     (sharing-source-node-child-source-ids node))])
         (visit child (cons source trail)))
       (hash-set! colors source 'black)]))
  (for ([node (in-list nodes)])
    (visit (sharing-source-node-id node) '())))

(define (build-use-edges nodes)
  (append-map
   (lambda (node)
     (for/list ([child-source
                 (in-list (sharing-source-node-child-source-ids node))]
                [slot (in-naturals 1)])
       (make-sharing-use-edge/internal
        (sharing-source-node-id node)
        slot
        child-source
        (for/list ([parent-address
                    (in-list (sharing-source-node-fibre node))])
          (cons parent-address
                (address-append parent-address (list slot)))))))
   nodes))

(define (bounded-sequence->list sequence limit)
  (define items '())
  (define truncated? #f)
  (for ([item sequence]
        [index (in-range (add1 limit))])
    (if (= index limit)
        (set! truncated? #t)
        (set! items (cons item items))))
  (values (reverse items) truncated?))

(define (saturated-addresses? nodes selected-addresses)
  (for/and ([node (in-list nodes)])
    (define selected-count
      (count (lambda (address) (member address selected-addresses equal?))
             (sharing-source-node-fibre node)))
    (or (zero? selected-count)
        (= selected-count (sharing-source-node-use-multiplicity node)))))

(define (witness->record proof source-map nodes witness)
  (unless (cut-witness? witness)
    (error 'audit-sharing-saturation
           "native cut enumeration emitted an error: ~e" witness))
  (unless (eq? (cut-witness-source witness) proof)
    (error 'audit-sharing-saturation
           "native witness lost exact source identity"))
  (define addresses (cut-witness-addresses witness))
  (define detached (cut-witness-detached witness))
  (unless (equal? addresses (map detached-entry-address detached))
    (error 'audit-sharing-saturation
           "native detached tuple lost address alignment"))
  (define reconstruction (reconstruct-cut-witness witness))
  (unless (and (cut-witness-reconstructs? witness)
               (eq? (checked-term-calculus reconstruction)
                    (checked-term-calculus proof))
               (equal? reconstruction proof))
    (error 'audit-sharing-saturation
           "native witness failed checked reconstruction"))
  (make-sharing-cut-record/internal
   (if (null? addresses) 'empty 'proper)
   witness addresses
   (map (lambda (address) (source-at source-map address)) addresses)
   detached
   (cut-witness-forest witness)
   (cut-witness-remainder witness)
   reconstruction
   (saturated-addresses? nodes addresses)))

(define (whole-record proof source-map calculus)
  (make-sharing-cut-record/internal
   'whole #f '() (list (source-at source-map root-address)) '()
   (make-proof-forest calculus (list proof))
   #f proof #t))

(define (strict-source-reaches? table from to)
  (let visit ([current from] [seen '()])
    (for/or ([child
              (in-list
               (sharing-source-node-child-source-ids
                (hash-ref table current)))])
      (or (equal? child to)
          (and (not (member child seen equal?))
               (visit child (cons child seen)))))))

(define (source-antichain? table sources)
  (not
   (for*/or ([left (in-list sources)]
             [right (in-list sources)]
             #:unless (equal? left right))
     (strict-source-reaches? table left right))))

(define (mask->subset sources mask)
  (for/list ([source (in-list sources)]
             [index (in-naturals)]
             #:when (bitwise-bit-set? mask index))
    source))

(define (subset-addresses table sources)
  (sort
   (append-map
    (lambda (source) (sharing-source-node-fibre (hash-ref table source)))
    sources)
   address<?))

(define (enumerate-source-subsets proof nodes root-source limit)
  (define table (source-node-table nodes))
  (define selectable
    (for/list ([node (in-list nodes)]
               #:unless (equal? (sharing-source-node-id node) root-source))
      (sharing-source-node-id node)))
  (define total (arithmetic-shift 1 (length selectable)))
  (define inspected (min total limit))
  (define records
    (for/list ([mask (in-range inspected)])
      (define sources (mask->subset selectable mask))
      (define addresses (subset-addresses table sources))
      (make-sharing-source-subset/internal
       sources addresses
       (source-antichain? table sources)
       (equal? (validate-ck-cut proof addresses) addresses))))
  (values records (> total limit) total))

(define (match-antichains antichains saturated-records)
  (define ordinary-saturated
    (filter (lambda (record)
              (not (eq? (sharing-cut-record-kind record) 'whole)))
            saturated-records))
  (define matches
    (for/list ([antichain (in-list antichains)]
               #:do [(define found
                        (findf
                         (lambda (record)
                           (equal? (sharing-cut-record-addresses record)
                                   (sharing-source-subset-addresses antichain)))
                         ordinary-saturated))]
               #:when found)
      (make-sharing-antichain-match/internal antichain found)))
  (define missing
    (filter
     (lambda (antichain)
       (not
        (findf
         (lambda (match)
           (eq? (sharing-antichain-match-source-subset match) antichain))
         matches)))
     antichains))
  (define unexpected
    (filter
     (lambda (record)
       (not
        (findf
         (lambda (match)
           (eq? (sharing-antichain-match-cut-record match) record))
         matches)))
     ordinary-saturated))
  (values matches unexpected missing))

(define (immutable-vector-copy vector-value)
  (vector->immutable-vector (vector-copy vector-value)))

(define (zero-exponents count)
  (vector->immutable-vector (make-vector count 0)))

(define (polynomial-one source-order)
  (make-sharing-character-polynomial/internal
   source-order (hash (zero-exponents (length source-order)) 1)))

(define (source-index source-order source)
  (index-where source-order (lambda (candidate) (equal? candidate source))))

(define (polynomial-variable source-order source)
  (define exponents (make-vector (length source-order) 0))
  (define index (source-index source-order source))
  (unless index
    (error 'sharing-character-polynomial
           "unknown source variable: ~e" source))
  (vector-set! exponents index 1)
  (make-sharing-character-polynomial/internal
   source-order (hash (immutable-vector-copy exponents) 1)))

(define (table-add table exponents coefficient)
  (define combined (+ (hash-ref table exponents 0) coefficient))
  (if (zero? combined)
      (hash-remove table exponents)
      (hash-set table exponents combined)))

(define (polynomial-add left right)
  (unless (equal? (sharing-character-polynomial-source-order left)
                  (sharing-character-polynomial-source-order right))
    (error 'sharing-character-polynomial "source orders differ"))
  (make-sharing-character-polynomial/internal
   (sharing-character-polynomial-source-order left)
   (for/fold
       ([table (sharing-character-polynomial-coefficient-table left)])
       ([(exponents coefficient)
         (in-hash
          (sharing-character-polynomial-coefficient-table right))])
     (table-add table exponents coefficient))))

(define (vector-add left right)
  (vector->immutable-vector
   (for/vector #:length (vector-length left)
               ([left-value (in-vector left)]
                [right-value (in-vector right)])
     (+ left-value right-value))))

(define (polynomial-multiply left right)
  (unless (equal? (sharing-character-polynomial-source-order left)
                  (sharing-character-polynomial-source-order right))
    (error 'sharing-character-polynomial "source orders differ"))
  (make-sharing-character-polynomial/internal
   (sharing-character-polynomial-source-order left)
   (for*/fold
       ([table (hash)])
       ([(left-exponents left-coefficient)
         (in-hash
          (sharing-character-polynomial-coefficient-table left))]
        [(right-exponents right-coefficient)
         (in-hash
          (sharing-character-polynomial-coefficient-table right))])
     (table-add table
                (vector-add left-exponents right-exponents)
                (* left-coefficient right-coefficient)))))

(define (records->polynomial source-order records)
  (define size (length source-order))
  (make-sharing-character-polynomial/internal
   source-order
   (for/fold ([table (hash)]) ([record (in-list records)])
     (define exponents (make-vector size 0))
     (for ([source (in-list (sharing-cut-record-source-ids record))])
       (define index (source-index source-order source))
       (vector-set! exponents index (add1 (vector-ref exponents index))))
     (table-add table (immutable-vector-copy exponents) 1))))

(define (recurrence-polynomial nodes root-source)
  (define table (source-node-table nodes))
  (define source-order (map sharing-source-node-id nodes))
  (define memo (make-hash))
  (define (evaluate source)
    (hash-ref!
     memo source
     (lambda ()
       (define node (hash-ref table source))
       (define retained
         (for/fold ([product (polynomial-one source-order)])
                   ([child (in-list
                            (sharing-source-node-child-source-ids node))])
           (polynomial-multiply product (evaluate child))))
       (polynomial-add
        (polynomial-variable source-order source) retained))))
  (evaluate root-source))

(define (polynomial-saturation-filter polynomial multiplicities)
  (define source-order
    (sharing-character-polynomial-source-order polynomial))
  (make-sharing-character-polynomial/internal
   source-order
   (for/hash
       ([(exponents coefficient)
         (in-hash
          (sharing-character-polynomial-coefficient-table polynomial))]
        #:when
        (for/and ([source (in-list source-order)]
                  [exponent (in-vector exponents)])
          (or (zero? exponent)
              (= exponent (hash-ref multiplicities source)))))
     (values exponents coefficient))))

(define (normalize-exponent-spec polynomial specification)
  (define source-order
    (sharing-character-polynomial-source-order polynomial))
  (define table
    (cond
      [(hash? specification) specification]
      [(list? specification)
       (for/hash ([binding (in-list specification)])
         (unless (and (pair? binding)
                      (exact-nonnegative-integer? (cdr binding)))
           (raise-argument-error
            'sharing-character-polynomial-coefficient
            "association list of source/nonnegative-exponent pairs"
            specification))
         (values (car binding) (cdr binding)))]
      [else
       (raise-argument-error
        'sharing-character-polynomial-coefficient
        "hash or association list" specification)]))
  (for ([source (in-hash-keys table)])
    (unless (member source source-order equal?)
      (raise-arguments-error
       'sharing-character-polynomial-coefficient
       "the exponent specification names an unknown source"
       "source" source)))
  (vector->immutable-vector
   (for/vector #:length (length source-order)
               ([source (in-list source-order)])
     (define exponent (hash-ref table source 0))
     (unless (exact-nonnegative-integer? exponent)
       (raise-argument-error
        'sharing-character-polynomial-coefficient
        "exact-nonnegative-integer? exponent" exponent))
     exponent)))

(define (sharing-character-polynomial-coefficient polynomial specification)
  (unless (sharing-character-polynomial? polynomial)
    (raise-argument-error
     'sharing-character-polynomial-coefficient
     "sharing-character-polynomial?" polynomial))
  (hash-ref
   (sharing-character-polynomial-coefficient-table polynomial)
   (normalize-exponent-spec polynomial specification)
   0))

(define (exponents->label source-order exponents)
  (for/list ([source (in-list source-order)]
             [exponent (in-vector exponents)]
             #:when (positive? exponent))
    (cons source exponent)))

(define (sharing-character-polynomial-terms polynomial)
  (unless (sharing-character-polynomial? polynomial)
    (raise-argument-error
     'sharing-character-polynomial-terms
     "sharing-character-polynomial?" polynomial))
  (define source-order
    (sharing-character-polynomial-source-order polynomial))
  (sort
   (for/list ([(exponents coefficient)
               (in-hash
                (sharing-character-polynomial-coefficient-table polynomial))])
     (cons (exponents->label source-order exponents) coefficient))
   (lambda (left right)
     (string<? (format "~s" (car left)) (format "~s" (car right))))))

(define (sharing-character-polynomial-degree polynomial source)
  (unless (sharing-character-polynomial? polynomial)
    (raise-argument-error
     'sharing-character-polynomial-degree
     "sharing-character-polynomial?" polynomial))
  (define index
    (source-index (sharing-character-polynomial-source-order polynomial)
                  source))
  (unless index
    (raise-arguments-error
     'sharing-character-polynomial-degree
     "unknown source variable" "source" source))
  (for/fold ([maximum 0])
            ([exponents
              (in-hash-keys
               (sharing-character-polynomial-coefficient-table polynomial))])
    (max maximum (vector-ref exponents index))))

(define (limited-polynomial-add left right limit)
  (let/ec overflow
    (define table
      (for/fold
          ([table (sharing-character-polynomial-coefficient-table left)])
          ([(exponents coefficient)
            (in-hash
             (sharing-character-polynomial-coefficient-table right))])
        (define next (table-add table exponents coefficient))
        (when (> (hash-count next) limit) (overflow #f))
        next))
    (make-sharing-character-polynomial/internal
     (sharing-character-polynomial-source-order left) table)))

(define (limited-polynomial-multiply left right limit)
  (let/ec overflow
    ;; Coefficients are nonnegative, so a newly distinct monomial cannot later
    ;; disappear by cancellation.  Stopping at limit+1 is therefore exact.
    (define table
      (for*/fold
          ([table (hash)])
          ([(left-exponents left-coefficient)
            (in-hash
             (sharing-character-polynomial-coefficient-table left))]
           [(right-exponents right-coefficient)
            (in-hash
             (sharing-character-polynomial-coefficient-table right))])
        (define next
          (table-add table
                     (vector-add left-exponents right-exponents)
                     (* left-coefficient right-coefficient)))
        (when (> (hash-count next) limit) (overflow #f))
        next))
    (make-sharing-character-polynomial/internal
     (sharing-character-polynomial-source-order left) table)))

(define (expand-sharing-source-character nodes root-source
                                         #:term-limit [term-limit 4096])
  (define who 'expand-sharing-source-character)
  (unless (and (list? nodes) (andmap sharing-source-node? nodes))
    (raise-argument-error who "(listof sharing-source-node?)" nodes))
  (unless (exact-positive-integer? term-limit)
    (raise-argument-error who "exact-positive-integer?" term-limit))
  (define table (source-node-table nodes))
  (unless (hash-has-key? table root-source)
    (raise-arguments-error who "root source is absent from the source nodes"
                           "root source" root-source))
  (define source-order (map sharing-source-node-id nodes))
  (define memo (make-hash))
  (define expansion
    (let/ec truncated
      (define (evaluate source)
        (hash-ref
         memo source
         (lambda ()
           (define node (hash-ref table source))
           (define retained
             (for/fold ([product (polynomial-one source-order)])
                       ([child (in-list
                                (sharing-source-node-child-source-ids node))])
               (define next
                 (limited-polynomial-multiply product (evaluate child)
                                              term-limit))
               (unless next (truncated #f))
               next))
           (define result
             (limited-polynomial-add
              (polynomial-variable source-order source) retained term-limit))
           (unless result (truncated #f))
           (hash-set! memo source result)
           result)))
      (define polynomial (evaluate root-source))
      (make-sharing-character-expansion/internal
       'exact polynomial
       (hash-count (sharing-character-polynomial-coefficient-table polynomial))
       term-limit)))
  (or expansion
      (make-sharing-character-expansion/internal
       'truncated #f #f term-limit)))

(define (audit-sharing-saturation proof source-map
                                  #:witness-limit [witness-limit 4096]
                                  #:antichain-limit [antichain-limit 4096])
  (define who 'audit-sharing-saturation)
  (unless (exact-positive-integer? witness-limit)
    (raise-argument-error who "exact-positive-integer? witness-limit"
                          witness-limit))
  (unless (exact-positive-integer? antichain-limit)
    (raise-argument-error who "exact-positive-integer? antichain-limit"
                          antichain-limit))
  (define addresses (validate-total-map who proof source-map))
  (define nodes (validate-source-nodes who proof source-map addresses))
  (validate-acyclic! who nodes)
  (define edges (build-use-edges nodes))
  (define calculus (checked-term-calculus proof))
  (define-values (witnesses witness-truncated?)
    (bounded-sequence->list
     (in-admissible-cut-witnesses proof) witness-limit))
  (define ordinary-records
    (for/list ([witness (in-list witnesses)])
      (witness->record proof source-map nodes witness)))
  (define records
    (if witness-truncated?
        ordinary-records
        (append ordinary-records
                (list (whole-record proof source-map calculus)))))
  (define saturated (filter sharing-cut-record-saturated? records))
  (define unsaturated
    (filter (lambda (record) (not (sharing-cut-record-saturated? record)))
            records))
  (define residual
    (make-sharing-residual/internal unsaturated (length unsaturated)))
  (define root-source (source-at source-map root-address))
  (define-values (subsets antichain-truncated? candidate-count)
    (enumerate-source-subsets proof nodes root-source antichain-limit))
  (define antichains
    (filter sharing-source-subset-antichain? subsets))
  (define-values (matches unexpected missing)
    (match-antichains antichains saturated))
  (define source-order (map sharing-source-node-id nodes))
  (define native-character
    (and (not witness-truncated?)
         (records->polynomial source-order records)))
  (define saturated-character
    (and native-character
         (records->polynomial source-order saturated)))
  (define recurrence-character
    (recurrence-polynomial nodes root-source))
  (define multiplicities
    (for/hash ([node (in-list nodes)])
      (values (sharing-source-node-id node)
              (sharing-source-node-use-multiplicity node))))
  (define recurrence-saturated-character
    (polynomial-saturation-filter recurrence-character multiplicities))
  (define subset-iff?
    (andmap
     (lambda (subset)
       (eq? (sharing-source-subset-antichain? subset)
            (sharing-source-subset-prefix-free? subset)))
     subsets))
  (define partition?
    (and (= (length records) (+ (length saturated) (length unsaturated)))
         (for/and ([record (in-list records)])
           (not (and (memq record saturated) (memq record unsaturated))))))
  (define nonroot-addresses (filter pair? addresses))
  (define nonroot-source-ids
    (map (lambda (address) (source-at source-map address))
         nonroot-addresses))
  (define injective-nonroot?
    (= (length nonroot-source-ids)
       (length (remove-duplicates nonroot-source-ids equal?))))
  (define residual-law?
    (eq? (null? unsaturated) injective-nonroot?))
  (define degree-bounded?
    (for/and ([node (in-list nodes)])
      (<= (sharing-character-polynomial-degree
           recurrence-character (sharing-source-node-id node))
          (sharing-source-node-use-multiplicity node))))
  (define degree-attained?
    (for/and ([node (in-list nodes)])
      (= (sharing-character-polynomial-degree
          recurrence-character (sharing-source-node-id node))
         (sharing-source-node-use-multiplicity node))))
  (define reconstruction?
    (for/and ([record (in-list records)])
      (equal? (sharing-cut-record-reconstruction record) proof)))
  (define no-root-cut?
    (for/and ([record (in-list records)])
      (or (eq? (sharing-cut-record-kind record) 'whole)
          (not (member root-address
                       (sharing-cut-record-addresses record) equal?)))))
  (define whole-witness-free?
    (for/and ([record (in-list records)]
              #:when (eq? (sharing-cut-record-kind record) 'whole))
      (not (sharing-cut-record-native-witness record))))
  (define multiplicity-retained?
    (for/and ([record (in-list ordinary-records)])
      (= (length (sharing-cut-record-detached record))
         (proof-forest-size (sharing-cut-record-forest record)))))
  (define complete-enumerations?
    (and (not witness-truncated?) (not antichain-truncated?)))
  (define bijection?
    (and complete-enumerations? (null? unexpected) (null? missing)
         (= (length matches) (length antichains))))
  (define character-law?
    (and native-character
         (equal? native-character recurrence-character)))
  (define saturation-character-law?
    (and saturated-character
         (equal? saturated-character recurrence-saturated-character)))
  (define laws
    (hash
     'fibre-saturation-classified? #t
     'preimage-antichain-iff? subset-iff?
     'native-partition? partition?
     'residual-positive? (andmap (lambda (record)
                                   (not (sharing-cut-record-saturated? record)))
                                 unsaturated)
     'residual-empty-iff-no-sharing? residual-law?
     'source-antichain-bijection? bijection?
     'native-character=recurrence? character-law?
     'native-saturation=exponent-filter? saturation-character-law?
     'degree-bounded-by-use-multiplicity? degree-bounded?
     'degree-attains-use-multiplicity? degree-attained?
     'native-reconstruction? reconstruction?
     'whole-witness-free? whole-witness-free?
     'no-root-cut? no-root-cut?
     'forest-multiplicity-retained? multiplicity-retained?))
  (define all-laws?
    (andmap values (hash-values laws)))
  (define status
    (cond
      [(not complete-enumerations?) 'inconclusive]
      [all-laws? 'certified]
      [else 'mismatch]))
  (define reasons
    (append
     (if witness-truncated? '(native-witness-limit-exceeded) '())
     (if antichain-truncated? '(source-subset-limit-exceeded) '())
     (if (or (not complete-enumerations?) all-laws?)
         '()
         (for/list ([(law result) (in-hash laws)] #:unless result) law))))
  (make-sharing-saturation-audit/internal
   proof source-map nodes edges records saturated unsaturated residual subsets
   antichains matches unexpected missing native-character
   recurrence-character saturated-character recurrence-saturated-character
   laws status reasons (length records) candidate-count))

(define (sharing-saturation-certified? audit)
  (unless (sharing-saturation-audit? audit)
    (raise-argument-error
     'sharing-saturation-certified? "sharing-saturation-audit?" audit))
  (eq? (sharing-saturation-audit-status audit) 'certified))

(define (make-sharing-local-action-key kind payload)
  (unless (memq kind '(keep select))
    (raise-arguments-error
     'make-sharing-local-action-key "kind must be keep or select"
     "kind" kind))
  (unless (stable-metadata? payload)
    (raise-argument-error
     'make-sharing-local-action-key "stable immutable metadata" payload))
  (make-sharing-local-action-key/internal kind payload))

(define (sharing-action-audit-variant-count audit source-id)
  (unless (sharing-action-audit? audit)
    (raise-argument-error
     'sharing-action-audit-variant-count "sharing-action-audit?" audit))
  (define found
    (assoc source-id (sharing-action-audit-variant-counts audit)))
  (if found (cdr found) 0))

(define (incompatible-action-audit reason)
  (make-sharing-action-audit/internal
   '() '() '() '() '() '() 'incompatible (list reason)
   (hash 'bottom-up-sufficient? #f
         'source-respecting-minimal? #f)))

(define (audit-sharing-actions saturation-audit action-map)
  (define who 'audit-sharing-actions)
  (unless (sharing-saturation-audit? saturation-audit)
    (raise-argument-error who "sharing-saturation-audit?" saturation-audit))
  (unless (and (hash? action-map) (immutable? action-map))
    (raise-argument-error who "immutable hash?" action-map))
  (define proof (sharing-saturation-audit-proof saturation-audit))
  (define source-map (sharing-saturation-audit-source-map saturation-audit))
  (define addresses (vertex-addresses proof))
  (cond
    [(or (not (= (hash-count action-map) (length addresses)))
         (for/or ([address (in-list addresses)])
           (not (hash-has-key? action-map address)))
         (for/or ([address (in-hash-keys action-map)])
           (not (member address addresses equal?))))
     (incompatible-action-audit 'action-map-not-total-on-native-vertices)]
    [(for/or ([key (in-hash-values action-map)])
       (not (sharing-local-action-key? key)))
     (incompatible-action-audit 'invalid-local-action-key)]
    [else
     (define selected-addresses
       (for/list ([address (in-list addresses)]
                  #:when
                  (eq? (sharing-local-action-key-kind
                        (hash-ref action-map address))
                       'select))
         address))
     (define selected-conflict?
       (for*/or ([left (in-list selected-addresses)]
                 [right (in-list selected-addresses)]
                 #:unless (equal? left right))
         (proper-address-prefix? left right)))
     (cond
       [selected-conflict?
        (incompatible-action-audit 'selected-frontier-not-prefix-free)]
       [else
        (define hidden-addresses
          (filter
           (lambda (address)
             (for/or ([selected (in-list selected-addresses)])
               (proper-address-prefix? selected address)))
           addresses))
        (define active-addresses
          (filter (lambda (address)
                    (not (member address hidden-addresses equal?)))
                  addresses))
        (define state-table (make-hash))
        (define (state-at address)
          (hash-ref!
           state-table address
           (lambda ()
             (define key (hash-ref action-map address))
             (if (eq? (sharing-local-action-key-kind key) 'select)
                 (list 'selected (sharing-local-action-key-payload key))
                 (define-state/keep address key)))))
        (define (define-state/keep address key)
          (define node (node-at proof address))
          (list
           'keep
           (sharing-local-action-key-payload key)
           (for/list ([child (in-list (checked-node-children node))]
                      [slot (in-naturals 1)])
             (state-at (address-append address (list slot))))))
        (state-at root-address)
        (define nodes (sharing-saturation-audit-source-nodes saturation-audit))
        (define local-classes
          (append-map
           (lambda (node)
             (define source (sharing-source-node-id node))
             (define live-fibre
               (filter (lambda (address)
                         (member address active-addresses equal?))
                       (sharing-source-node-fibre node)))
             (define keys
               (remove-duplicates
                (map (lambda (address) (hash-ref action-map address))
                     live-fibre)
                equal?))
             (for/list ([key (in-list keys)])
               (make-sharing-action-class/internal
                source key
                (filter (lambda (address)
                          (equal? key (hash-ref action-map address)))
                        live-fibre))))
           nodes))
        (define variants '())
        (define address->variant (make-hash))
        (define variant-counts
          (for/list ([node (in-list nodes)])
            (define source (sharing-source-node-id node))
            (define live-fibre
              (filter (lambda (address)
                        (member address active-addresses equal?))
                      (sharing-source-node-fibre node)))
            (define states
              (remove-duplicates (map state-at live-fibre) equal?))
            (for ([state (in-list states)] [index (in-naturals 1)])
              (define members
                (filter (lambda (address)
                          (equal? state (state-at address)))
                        live-fibre))
              (for ([address (in-list members)])
                (hash-set! address->variant address index))
              (set! variants
                    (cons
                     (make-sharing-state-variant/internal
                      source index state members)
                     variants)))
            (cons source (length states))))
        (set! variants (reverse variants))
        (define routings
          (for/list ([address (in-list active-addresses)])
            (define node (node-at proof address))
            (define key (hash-ref action-map address))
            (make-sharing-routing/internal
             address
             (source-at source-map address)
             (hash-ref address->variant address)
             (if (eq? (sharing-local-action-key-kind key) 'select)
                 '()
                 (for/list ([child (in-list (checked-node-children node))]
                            [slot (in-naturals 1)])
                   (define child-address
                     (address-append address (list slot)))
                   (cons (source-at source-map child-address)
                         (hash-ref address->variant child-address)))))))
        (define split?
          (ormap (lambda (binding) (> (cdr binding) 1)) variant-counts))
        (make-sharing-action-audit/internal
         local-classes variants routings variant-counts active-addresses
         hidden-addresses
         (if split? 'local-split-lower-bound 'preserve-share)
         '()
         (hash 'bottom-up-sufficient? #t
               'source-respecting-minimal? #t))])]))
