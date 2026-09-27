#lang racket/base

;; Compact sum/product evaluation of occurrence-level CK choices presented by
;; a validated sharing quotient.  This circuit is immutable analysis IR, not
;; a proof, cut, forest, remainder, tensor, context, source map, or Hopf
;; algebra element.  Decoding always returns to the original checked proof and
;; the existing native cut-witness API.
;;
;; Paper proof (not proof-assistant mechanised).  At an occurrence, Select is
;; the unique choice containing that occurrence.  Otherwise the cut decomposes
;; uniquely across its ordered premise cones, so Keep is the Cartesian product
;; of the child choices.  Premise lenses prefix child addresses; distinct
;; premise regions are incomparable, hence their union is prefix-free.  The
;; inverse restricts any cut omitting the current root to those ordered cones.
;; At the global root Select is the separate witness-free whole endpoint, and
;; Keep-everywhere is the empty cut.  This gives both the trace bijection and
;; a_v = 1 + product_i a_{p_i} by source-DAG induction.

(require racket/list
         "../algebra/formal-sum.rkt"
         "../kernel/address.rkt"
         "../kernel/check.rkt"
         "../kernel/context.rkt"
         "../kernel/cut.rkt"
         "material-hopf-selector.rkt"
         "sharing-saturation.rkt")

(provide shared-ck-edge-lens?
         shared-ck-edge-lens-use-edge
         shared-ck-edge-lens-premise-slot
         shared-ck-edge-lens-prefix-address
         shared-ck-gate?
         shared-ck-gate-source-node
         shared-ck-gate-edge-lenses
         shared-ck-gate-choice-count
         shared-ck-gate-unfolded-occurrence-count
         shared-ck-gate-source-use-multiplicity

         shared-ck-circuit?
         shared-ck-circuit-audit
         shared-ck-circuit-calculus
         shared-ck-circuit-root-source
         shared-ck-circuit-gates
         compile-shared-ck-circuit
         shared-ck-circuit-node-count
         shared-ck-circuit-edge-count
         shared-ck-circuit-unfolded-occurrence-count
         shared-ck-circuit-source-use-multiplicity
         shared-ck-circuit-choice-count
         shared-ck-circuit-fold
         shared-ck-circuit-character

         shared-ck-capped-count?
         shared-ck-capped-count-status
         shared-ck-capped-count-value
         shared-ck-capped-count-cap
         shared-ck-circuit-capped-choice-count

         shared-ck-trace?
         shared-ck-trace-source-id
         shared-ck-trace-occurrence-address
         shared-ck-trace-alternative
         shared-ck-trace-child-traces
         shared-ck-trace-addresses
         shared-ck-choice?
         shared-ck-choice-rank
         shared-ck-choice-kind
         shared-ck-choice-addresses
         shared-ck-choice-trace
         shared-ck-choice-native-record
         shared-ck-choice-resolved-witness
         shared-ck-choice-native-agreement?
         shared-ck-decode-error?
         shared-ck-decode-error-code
         shared-ck-decode-error-message
         shared-ck-decode-error-rank
         shared-ck-decode-error-bound
         shared-ck-circuit-decode

         shared-ck-native-agreement?
         shared-ck-native-agreement-choices
         shared-ck-native-agreement-unexpected
         shared-ck-native-agreement-missing
         shared-ck-native-agreement-status
         shared-ck-native-agreement-reasons
         shared-ck-native-agreement-rank-limit
         shared-ck-circuit-native-agreement

         shared-ck-circuit-material-choice-count
         shared-ck-material-audit?
         shared-ck-material-audit-selector
         shared-ck-material-audit-choice-count
         shared-ck-material-audit-choices
         shared-ck-material-audit-records
         shared-ck-material-audit-collected-coaction
         shared-ck-material-audit-reference-coaction
         shared-ck-material-audit-status
         shared-ck-material-audit-reasons
         shared-ck-circuit-material-audit)

(struct shared-ck-edge-lens (use-edge premise-slot)
  #:constructor-name make-shared-ck-edge-lens/internal
  #:transparent)
(struct shared-ck-gate
  (source-node edge-lenses choice-count unfolded-occurrence-count
               source-use-multiplicity)
  #:constructor-name make-shared-ck-gate/internal
  #:transparent)
(struct shared-ck-circuit
  (audit calculus root-source gates gate-table choice-count
         unfolded-occurrence-count)
  #:constructor-name make-shared-ck-circuit/internal
  #:transparent)
(struct shared-ck-capped-count (circuit status value cap)
  #:constructor-name make-shared-ck-capped-count/internal
  #:transparent)
(struct shared-ck-trace
  (source-id occurrence-address alternative child-traces addresses)
  #:constructor-name make-shared-ck-trace/internal
  #:transparent)
(struct shared-ck-choice
  (rank kind addresses trace native-record resolved-witness native-agreement?)
  #:constructor-name make-shared-ck-choice/internal
  #:transparent)
(struct shared-ck-decode-error (code message rank bound)
  #:constructor-name make-shared-ck-decode-error/internal
  #:transparent)
(struct shared-ck-native-agreement
  (choices unexpected missing status reasons rank-limit)
  #:constructor-name make-shared-ck-native-agreement/internal
  #:transparent)
(struct shared-ck-material-audit
  (selector choice-count choices records collected-coaction reference-coaction
            status reasons)
  #:constructor-name make-shared-ck-material-audit/internal
  #:transparent)

(define (edge-lenses-for source-node use-edges)
  (define source (sharing-source-node-id source-node))
  (define edges
    (sort
     (filter (lambda (edge)
               (equal? (sharing-use-edge-parent-source edge) source))
             use-edges)
     < #:key sharing-use-edge-premise-slot))
  (unless (= (length edges) (sharing-source-node-arity source-node))
    (error 'compile-shared-ck-circuit
           "validated source node lost an ordered use edge: ~e" source))
  (for/list ([edge (in-list edges)]
             [expected-child
              (in-list (sharing-source-node-child-source-ids source-node))]
             [slot (in-naturals 1)])
    (unless (and (= (sharing-use-edge-premise-slot edge) slot)
                 (equal? (sharing-use-edge-child-source edge)
                         expected-child))
      (error 'compile-shared-ck-circuit
             "ordered source-use edge mismatch at ~e slot ~e" source slot))
    (make-shared-ck-edge-lens/internal edge slot)))

(define (shared-ck-edge-lens-prefix-address lens outer-address relative-address)
  (unless (shared-ck-edge-lens? lens)
    (raise-argument-error
     'shared-ck-edge-lens-prefix-address "shared-ck-edge-lens?" lens))
  (unless (address? outer-address)
    (raise-argument-error
     'shared-ck-edge-lens-prefix-address "address? outer-address"
     outer-address))
  (unless (address? relative-address)
    (raise-argument-error
     'shared-ck-edge-lens-prefix-address "address? relative-address"
     relative-address))
  (address-append
   (address-append outer-address
                   (list (shared-ck-edge-lens-premise-slot lens)))
   relative-address))

(define (compile-shared-ck-circuit audit
                                   #:calculus
                                   [expected-calculus
                                    (and (sharing-saturation-audit? audit)
                                         (checked-term-calculus
                                          (sharing-saturation-audit-proof
                                           audit)))])
  (define who 'compile-shared-ck-circuit)
  (unless (sharing-saturation-audit? audit)
    (raise-argument-error who "sharing-saturation-audit?" audit))
  (unless (sharing-saturation-certified? audit)
    (raise-arguments-error
     who "only a complete certified sharing-saturation audit can be compiled"
     "audit status" (sharing-saturation-audit-status audit)
     "audit reasons" (sharing-saturation-audit-reasons audit)))
  (define proof (sharing-saturation-audit-proof audit))
  (define calculus (checked-term-calculus proof))
  (unless (and (eq? calculus expected-calculus)
               (eq? calculus
                    (sharing-source-map-calculus
                     (sharing-saturation-audit-source-map audit)))
               (checked-term-has-exact-calculus? proof calculus)
               (complete-proof? proof))
    (raise-arguments-error
     who "audit, proof, source map, and expected calculus must agree exactly"
     "proof calculus" calculus
     "expected calculus" expected-calculus))
  (define nodes (sharing-saturation-audit-source-nodes audit))
  (define use-edges (sharing-saturation-audit-use-edges audit))
  (define node-table
    (for/hash ([node (in-list nodes)])
      (values (sharing-source-node-id node) node)))
  (define root-source
    (sharing-source-map-source-at
     (sharing-saturation-audit-source-map audit) root-address))
  (define lens-table
    (for/hash ([node (in-list nodes)])
      (values (sharing-source-node-id node)
              (edge-lenses-for node use-edges))))
  (define choice-memo (make-hash))
  (define occurrence-memo (make-hash))
  (define (choice-count source)
    (hash-ref!
     choice-memo source
     (lambda ()
       (add1
        (for/product
            ([lens (in-list (hash-ref lens-table source))])
          (choice-count
           (sharing-use-edge-child-source
            (shared-ck-edge-lens-use-edge lens))))))))
  (define (occurrence-count source)
    (hash-ref!
     occurrence-memo source
     (lambda ()
       (add1
        (for/sum ([lens (in-list (hash-ref lens-table source))])
          (occurrence-count
           (sharing-use-edge-child-source
            (shared-ck-edge-lens-use-edge lens))))))))
  (define parent-table
    (for/fold ([table (hash)]) ([edge (in-list use-edges)])
      (hash-update table (sharing-use-edge-child-source edge)
                   (lambda (prior) (cons edge prior)) '())))
  (define multiplicity-memo (make-hash))
  (define (use-multiplicity source)
    (hash-ref!
     multiplicity-memo source
     (lambda ()
       (if (equal? source root-source)
           1
           (for/sum ([edge (in-list (hash-ref parent-table source '()))])
             (use-multiplicity
              (sharing-use-edge-parent-source edge)))))))
  (define gates
    (for/list ([node (in-list nodes)])
      (define source (sharing-source-node-id node))
      (define multiplicity (use-multiplicity source))
      (unless (= multiplicity (sharing-source-node-use-multiplicity node))
        (error who "source-use path count disagrees with the native fibre: ~e"
               source))
      (make-shared-ck-gate/internal
       node (hash-ref lens-table source) (choice-count source)
       (occurrence-count source) multiplicity)))
  (define gate-table
    (for/hash ([gate (in-list gates)])
      (values (sharing-source-node-id (shared-ck-gate-source-node gate)) gate)))
  (define total-choices (choice-count root-source))
  (define total-occurrences (occurrence-count root-source))
  (unless (= total-choices
             (length (sharing-saturation-audit-records audit)))
    (error who "compact choice count disagrees with the complete native oracle"))
  (unless (= total-occurrences (length (vertex-addresses proof)))
    (error who "compact unfolded count disagrees with the checked proof"))
  (make-shared-ck-circuit/internal
   audit calculus root-source gates gate-table total-choices
   total-occurrences))

(define (shared-ck-circuit-node-count circuit)
  (unless (shared-ck-circuit? circuit)
    (raise-argument-error
     'shared-ck-circuit-node-count "shared-ck-circuit?" circuit))
  (length (shared-ck-circuit-gates circuit)))

(define (shared-ck-circuit-edge-count circuit)
  (unless (shared-ck-circuit? circuit)
    (raise-argument-error
     'shared-ck-circuit-edge-count "shared-ck-circuit?" circuit))
  (for/sum ([gate (in-list (shared-ck-circuit-gates circuit))])
    (length (shared-ck-gate-edge-lenses gate))))

(define (shared-ck-circuit-source-use-multiplicity circuit source-id)
  (unless (shared-ck-circuit? circuit)
    (raise-argument-error
     'shared-ck-circuit-source-use-multiplicity
     "shared-ck-circuit?" circuit))
  (define gate (hash-ref (shared-ck-circuit-gate-table circuit) source-id #f))
  (unless gate
    (raise-arguments-error
     'shared-ck-circuit-source-use-multiplicity
     "unknown source id" "source id" source-id))
  (shared-ck-gate-source-use-multiplicity gate))

(define (gate-for circuit source)
  (hash-ref (shared-ck-circuit-gate-table circuit) source
            (lambda ()
              (error 'shared-ck-circuit "missing compiled gate: ~e" source))))

(define (shared-ck-circuit-fold circuit
                                #:select select
                                #:keep keep
                                #:plus plus
                                #:times times
                                #:one one)
  (unless (shared-ck-circuit? circuit)
    (raise-argument-error
     'shared-ck-circuit-fold "shared-ck-circuit?" circuit))
  (for ([procedure (in-list (list select keep plus times))]
        [name (in-list '(select keep plus times))])
    (unless (procedure? procedure)
      (raise-arguments-error
       'shared-ck-circuit-fold "fold operation must be a procedure"
       "operation" name "value" procedure)))
  (define memo (make-hash))
  (define (evaluate source)
    (hash-ref!
     memo source
     (lambda ()
       (define gate (gate-for circuit source))
       (define node (shared-ck-gate-source-node gate))
       (define retained
         (for/fold ([product one])
                   ([lens (in-list (shared-ck-gate-edge-lenses gate))])
           (times
            product
            (evaluate
             (sharing-use-edge-child-source
              (shared-ck-edge-lens-use-edge lens))))))
       (plus (select node) (keep node retained)))))
  (evaluate (shared-ck-circuit-root-source circuit)))

(define (shared-ck-circuit-character circuit #:term-limit [term-limit 4096])
  (unless (shared-ck-circuit? circuit)
    (raise-argument-error
     'shared-ck-circuit-character "shared-ck-circuit?" circuit))
  (define expansion
    (expand-sharing-source-character
     (map shared-ck-gate-source-node (shared-ck-circuit-gates circuit))
     (shared-ck-circuit-root-source circuit)
     #:term-limit term-limit))
  (when (eq? (sharing-character-expansion-status expansion) 'exact)
    (unless (equal?
             (sharing-character-expansion-polynomial expansion)
             (sharing-saturation-audit-recurrence-character
              (shared-ck-circuit-audit circuit)))
      (error 'shared-ck-circuit-character
             "limited source-character fold disagrees with the native audit")))
  expansion)

(define (shared-ck-circuit-capped-choice-count circuit cap)
  (unless (shared-ck-circuit? circuit)
    (raise-argument-error
     'shared-ck-circuit-capped-choice-count "shared-ck-circuit?" circuit))
  (unless (exact-nonnegative-integer? cap)
    (raise-argument-error
     'shared-ck-circuit-capped-choice-count
     "exact-nonnegative-integer?" cap))
  (define threshold (add1 cap))
  (define memo (make-hash))
  (define (capped source)
    (hash-ref!
     memo source
     (lambda ()
       (define product
         (for/fold ([product 1])
                   ([lens (in-list
                           (shared-ck-gate-edge-lenses
                            (gate-for circuit source)))])
           (min threshold
                (* product
                   (capped
                    (sharing-use-edge-child-source
                     (shared-ck-edge-lens-use-edge lens)))))))
       (min threshold (add1 product)))))
  (define result (capped (shared-ck-circuit-root-source circuit)))
  (if (<= result cap)
      (make-shared-ck-capped-count/internal circuit 'exact result cap)
      (make-shared-ck-capped-count/internal circuit 'exceeds-cap #f cap)))

(define (trace-decode circuit source occurrence-address rank global-root?)
  (define gate (gate-for circuit source))
  (define lenses (shared-ck-gate-edge-lenses gate))
  (cond
    [(zero? rank)
     (make-shared-ck-trace/internal
      source occurrence-address 'select '()
      (if global-root? '() (list occurrence-address)))]
    [else
     (define remaining-rank (sub1 rank))
     (define child-counts
       (for/list ([lens (in-list lenses)])
         (shared-ck-gate-choice-count
          (gate-for
           circuit
           (sharing-use-edge-child-source
            (shared-ck-edge-lens-use-edge lens))))))
     (define child-traces '())
     (let loop ([remaining-lenses lenses]
                [remaining-counts child-counts]
                [mixed-rank remaining-rank])
       (cond
         [(null? remaining-lenses) (void)]
         [else
          (define tail-product
            (for/product ([count (in-list (cdr remaining-counts))]) count))
          (define child-rank (quotient mixed-rank tail-product))
          (define next-rank (remainder mixed-rank tail-product))
          (define lens (car remaining-lenses))
          (define edge (shared-ck-edge-lens-use-edge lens))
          (define child-address
            (shared-ck-edge-lens-prefix-address
             lens occurrence-address root-address))
          (set! child-traces
                (cons
                 (trace-decode
                  circuit (sharing-use-edge-child-source edge)
                  child-address child-rank #f)
                 child-traces))
          (loop (cdr remaining-lenses) (cdr remaining-counts) next-rank)]))
     (set! child-traces (reverse child-traces))
     (make-shared-ck-trace/internal
      source occurrence-address 'keep child-traces
      (append-map shared-ck-trace-addresses child-traces))]))

(define (record-for-choice audit kind addresses)
  (findf
   (lambda (record)
     (and (eq? (sharing-cut-record-kind record) kind)
          (equal? (sharing-cut-record-addresses record) addresses)))
   (sharing-saturation-audit-records audit)))

(define (resolved-agrees? proof kind record witness)
  (cond
    [(not record) #f]
    [(eq? kind 'whole)
     (and (not witness)
          (not (sharing-cut-record-native-witness record))
          (equal? (sharing-cut-record-reconstruction record) proof))]
    [else
     (and (cut-witness? witness)
          (equal? (cut-witness-addresses witness)
                  (sharing-cut-record-addresses record))
          (equal? (cut-witness-detached witness)
                  (sharing-cut-record-detached record))
          (equal? (cut-witness-forest witness)
                  (sharing-cut-record-forest record))
          (equal? (cut-witness-remainder witness)
                  (sharing-cut-record-remainder record))
          (equal? (reconstruct-cut-witness witness)
                  (sharing-cut-record-reconstruction record))
          (cut-witness-reconstructs? witness))]))

(define (shared-ck-circuit-decode circuit rank
                                  #:count-result [count-result #f])
  (unless (shared-ck-circuit? circuit)
    (raise-argument-error
     'shared-ck-circuit-decode "shared-ck-circuit?" circuit))
  (cond
    [(not (exact-nonnegative-integer? rank))
     (make-shared-ck-decode-error/internal
      'invalid-rank "rank must be an exact nonnegative integer" rank
      (shared-ck-circuit-choice-count circuit))]
    [(and count-result
          (not (and (shared-ck-capped-count? count-result)
                    (eq? (shared-ck-capped-count-circuit count-result)
                         circuit))))
     (raise-argument-error
      'shared-ck-circuit-decode
      "capped count result from this exact circuit" count-result)]
    [(and count-result
          (eq? (shared-ck-capped-count-status count-result) 'exceeds-cap))
     (make-shared-ck-decode-error/internal
      'inexact-capped-count
      "rank selection is disabled for an exceeds-cap count result"
      rank (shared-ck-capped-count-cap count-result))]
    [else
     (define bound
       (if count-result
           (shared-ck-capped-count-value count-result)
           (shared-ck-circuit-choice-count circuit)))
     (cond
       [(>= rank bound)
        (make-shared-ck-decode-error/internal
         'rank-out-of-range "rank is outside the endpoint-completed family"
         rank bound)]
       [else
        (define trace
          (trace-decode circuit (shared-ck-circuit-root-source circuit)
                        root-address rank #t))
        (define addresses (shared-ck-trace-addresses trace))
        (define kind
          (cond
            [(eq? (shared-ck-trace-alternative trace) 'select) 'whole]
            [(null? addresses) 'empty]
            [else 'proper]))
        (define audit (shared-ck-circuit-audit circuit))
        (define proof (sharing-saturation-audit-proof audit))
        (define record (record-for-choice audit kind addresses))
        (define witness
          (and (not (eq? kind 'whole))
               (make-cut-witness proof addresses)))
        (define agreement?
          (and (not (cut-error? witness))
               (resolved-agrees? proof kind record witness)))
        (make-shared-ck-choice/internal
         rank kind addresses trace record witness agreement?)])]))

(define (shared-ck-circuit-native-agreement circuit
                                            #:rank-limit [rank-limit 4096])
  (unless (shared-ck-circuit? circuit)
    (raise-argument-error
     'shared-ck-circuit-native-agreement "shared-ck-circuit?" circuit))
  (unless (exact-positive-integer? rank-limit)
    (raise-argument-error
     'shared-ck-circuit-native-agreement
     "exact-positive-integer?" rank-limit))
  (define count (shared-ck-circuit-choice-count circuit))
  (cond
    [(> count rank-limit)
     (make-shared-ck-native-agreement/internal
      '() '() '() 'inconclusive '(rank-limit-exceeded) rank-limit)]
    [else
     (define decoded
       (for/list ([rank (in-range count)])
         (shared-ck-circuit-decode circuit rank)))
     (define unexpected
       (filter (lambda (choice)
                 (or (shared-ck-decode-error? choice)
                     (not (shared-ck-choice-native-agreement? choice))))
               decoded))
     (define decoded-records
       (for/list ([choice (in-list decoded)]
                  #:when (shared-ck-choice? choice))
         (shared-ck-choice-native-record choice)))
     (define native-records
       (sharing-saturation-audit-records
        (shared-ck-circuit-audit circuit)))
     (define missing
       (filter (lambda (record) (not (memq record decoded-records)))
               native-records))
     (define duplicate-record?
       (not (= (length decoded-records)
               (length (remove-duplicates decoded-records eq?)))))
     (define status
       (if (and (null? unexpected) (null? missing)
                (not duplicate-record?)
                (= (length decoded) (length native-records)))
           'certified
           'mismatch))
     (make-shared-ck-native-agreement/internal
      decoded unexpected missing status
      (append
       (if (null? unexpected) '() '(decoded-native-mismatch))
       (if (null? missing) '() '(missing-native-record))
       (if duplicate-record? '(duplicate-native-record) '()))
      rank-limit)]))

(define (representative-subtree circuit gate)
  (define address
    (car (sharing-source-node-fibre (shared-ck-gate-source-node gate))))
  (checked-term-at-address
   (sharing-saturation-audit-proof (shared-ck-circuit-audit circuit))
   address))

(define (shared-ck-circuit-material-choice-count circuit selector)
  (unless (shared-ck-circuit? circuit)
    (raise-argument-error
     'shared-ck-circuit-material-choice-count "shared-ck-circuit?" circuit))
  (unless (material-hopf-selector? selector)
    (raise-argument-error
     'shared-ck-circuit-material-choice-count
     "material-hopf-selector?" selector))
  (unless (eq? (shared-ck-circuit-calculus circuit)
               (material-hopf-selector-calculus selector))
    (raise-arguments-error
     'shared-ck-circuit-material-choice-count
     "circuit and selector must carry one exact calculus snapshot"
     "circuit calculus" (shared-ck-circuit-calculus circuit)
     "selector calculus" (material-hopf-selector-calculus selector)))
  (define calculus (shared-ck-circuit-calculus circuit))
  (define memo (make-hash))
  (define (count source)
    (hash-ref!
     memo source
     (lambda ()
       (define gate (gate-for circuit source))
       (define subtree (representative-subtree circuit gate))
       (define select-count
         (if (material-hopf-selector-forest-pure?
              selector (make-proof-forest calculus (list subtree)))
             1 0))
       (+ select-count
          (for/product
              ([lens (in-list (shared-ck-gate-edge-lenses gate))])
            (count
             (sharing-use-edge-child-source
              (shared-ck-edge-lens-use-edge lens))))))))
  (count (shared-ck-circuit-root-source circuit)))

(define (records->native-coaction calculus records)
  (make-formal-sum
   calculus 2
   (for/list ([record (in-list records)])
     (define right
       (if (eq? (sharing-cut-record-kind record) 'whole)
           (empty-proof-forest calculus)
           (make-proof-forest
            calculus (list (sharing-cut-record-remainder record)))))
     (cons (vector (sharing-cut-record-forest record) right) 1))))

(define (shared-ck-circuit-material-audit circuit selector
                                          #:rank-limit [rank-limit 4096])
  (unless (shared-ck-circuit? circuit)
    (raise-argument-error
     'shared-ck-circuit-material-audit "shared-ck-circuit?" circuit))
  (unless (material-hopf-selector? selector)
    (raise-argument-error
     'shared-ck-circuit-material-audit "material-hopf-selector?" selector))
  (unless (exact-positive-integer? rank-limit)
    (raise-argument-error
     'shared-ck-circuit-material-audit
     "exact-positive-integer?" rank-limit))
  (define material-count
    (shared-ck-circuit-material-choice-count circuit selector))
  (define total-count (shared-ck-circuit-choice-count circuit))
  (cond
    [(> total-count rank-limit)
     (make-shared-ck-material-audit/internal
      selector material-count '() '() #f #f 'inconclusive
      '(rank-limit-exceeded))]
    [else
     (define calculus (shared-ck-circuit-calculus circuit))
     (define audit (shared-ck-circuit-audit circuit))
     (define proof (sharing-saturation-audit-proof audit))
     (unless (eq? calculus (material-hopf-selector-calculus selector))
       (raise-arguments-error
        'shared-ck-circuit-material-audit
        "circuit and selector must carry one exact calculus snapshot"
        "circuit calculus" calculus
        "selector calculus" (material-hopf-selector-calculus selector)))
     (define choices
       (for/list ([rank (in-range total-count)])
         (shared-ck-circuit-decode circuit rank)))
     (define selected-choices
       (filter
        (lambda (choice)
          (and (shared-ck-choice? choice)
               (material-hopf-selector-forest-pure?
                selector
                (sharing-cut-record-forest
                 (shared-ck-choice-native-record choice)))))
        choices))
     (define records (map shared-ck-choice-native-record selected-choices))
     (define native-selected
       (filter
        (lambda (record)
          (material-hopf-selector-forest-pure?
           selector (sharing-cut-record-forest record)))
        (sharing-saturation-audit-records audit)))
     (define collected (records->native-coaction calculus records))
     (define reference
       (material-hopf-selector-coaction selector (checked-node-basis proof)))
     (define occurrence-agreement?
       (and (= material-count (length records))
            (= (length records) (length native-selected))
            (for/and ([record (in-list records)])
              (memq record native-selected))))
     (define collected-agreement?
       (and (formal-sum? collected) (formal-sum? reference)
            (equal? collected reference)))
     (make-shared-ck-material-audit/internal
      selector material-count selected-choices records collected reference
      (if (and occurrence-agreement? collected-agreement?)
          'certified 'mismatch)
      (append
       (if occurrence-agreement? '() '(occurrence-filter-mismatch))
       (if collected-agreement? '() '(collected-coaction-mismatch))))]))
