#lang racket/base

(require racket/list
         "ancestry.rkt"
         "../kernel/address.rkt"
         "../kernel/boundary.rkt"
         "../kernel/calculus.rkt"
         "../kernel/check.rkt"
         "../kernel/context.rkt")

(provide (struct-out frame-off-spine)
         (struct-out derivative-frame-edge)
         (struct-out derivative-frame-graph)
         derivative-frame-graph-of
         derivative-frame-edges-from
         (struct-out productivity-witness)
         (struct-out frame-productivity)
         derivative-frame-productivity-of
         frame-productivity-ref
         derivative-frame-edge-realised?
         (struct-out realised-frame)
         realise-derivative-frame-edge
         (struct-out frame-cycle)
         raw-frame-cycle-at
         realised-frame-cycle-at
         (struct-out frame-realisation)
         realise-frame-cycle
         positive-one-hole-context?
         (struct-out frame-context-decomposition)
         one-hole-context->frame-walk
         frame-context-decomposition-realised?
         (struct-out boundary-recurrence)
         boundary-recurrence-of)

;; A derivative-frame edge remembers the exact selected occurrence and slot.
;; Equal source/target boundaries and parallel edges are never collapsed.
(struct frame-off-spine (slot boundary) #:transparent)
(struct derivative-frame-edge
  (calculus
   occurrence
   slot
   source
   target
   off-spine
   corolla
   selected-address
   incidence)
  #:transparent)
(struct derivative-frame-graph (calculus vertices edges) #:transparent)

;; Productivity stores one deterministic minimum-height complete proof for a
;; boundary.  The ordered premise witnesses are explanatory data, not a proof
;; search tree: only the selected witness at each premise is retained.
(struct productivity-witness
  (boundary height proof occurrence premise-witnesses)
  #:transparent)
(struct frame-productivity (graph witnesses work) #:transparent)

(struct realised-frame
  (edge fillers context distinguished-address)
  #:transparent)

;; A cycle is a nonempty, shortest simple edge path based at `boundary`.
;; `raw-context` composes its full corollas along the selected slots; all
;; off-spine obligations and the final recursive obligation remain punctures.
(struct frame-cycle
  (graph
   boundary
   edges
   raw-context
   distinguished-address
   off-spine-addresses
   simple?)
  #:transparent)

;; Realisation fills only the off-spine obligations with the productivity
;; fixed point.  The distinguished recursive puncture is retained.
(struct frame-realisation
  (cycle fillers context seed-proof status)
  #:transparent)

;; Decomposing an existing positive one-hole context follows its unique
;; root-to-puncture path.  Its actual complete off-spine proofs are retained
;; separately from the raw frame walk and are used for the round trip.
(struct frame-context-decomposition
  (source
   graph
   source-boundary
   target-boundary
   edges
   distinguished-address
   off-spine-fillers
   raw-context
   reconstructed
   cycle?
   reconstructs?)
  #:transparent)

;; Status is one of acyclic, raw-unrealised, realised-no-seed, or
;; realised-with-seed.  An analysis-limit is returned instead of this value
;; when exact cycle/productivity work exceeds the requested bound.
(struct boundary-recurrence
  (graph
   boundary
   productivity
   raw-cycle
   realised-cycle
   realisation
   decomposition
   status
   theorem-holds?)
  #:transparent)

(define (make-analysis-error code message operation
                             #:expected [expected #f]
                             #:actual [actual #f]
                             #:details [details (hash)])
  (analysis-error code message operation expected actual details))

(define (make-analysis-limit operation limit required metric
                             [details (hash)])
  (analysis-limit
   'not-computed-limit
   "the exact derivative-frame analysis exceeds its configured finite limit"
   operation
   limit
   required
   metric
   details))

(define (check-limit who limit)
  (unless (or (not limit) (exact-nonnegative-integer? limit))
    (raise-argument-error
     who "(or/c #f exact-nonnegative-integer?)" limit)))

(define (over-limit? work limit)
  (and limit (> work limit)))

;; Boundaries themselves are not formula data.  This key expands their
;; canonical multiset presentation into ordinary symbolic data, so all graph
;; ordering is structural and shares boundary.rkt's datum comparator.
(define (boundary-order-key boundary)
  (for/list ([component (in-list (hypersequent-sequents boundary))])
    (list (formula-context->list (sequent-left component))
          (formula-context->list (sequent-right component)))))

(define (boundary<? left right)
  (symbolic-datum<? (boundary-order-key left)
                    (boundary-order-key right)))

(define (compare-field left right less? continue)
  (cond
    [(equal? left right) (continue)]
    [else (less? left right)]))

(define (frame-edge<? left right)
  (compare-field
   (derivative-frame-edge-source left)
   (derivative-frame-edge-source right)
   boundary<?
   (lambda ()
     (compare-field
      (derivative-frame-edge-target left)
      (derivative-frame-edge-target right)
      boundary<?
      (lambda ()
        (compare-field
         (concrete-occurrence-id
          (derivative-frame-edge-occurrence left))
         (concrete-occurrence-id
          (derivative-frame-edge-occurrence right))
         symbolic-datum<?
         (lambda ()
           (< (derivative-frame-edge-slot left)
              (derivative-frame-edge-slot right)))))))))

(define (edge-list<? left right)
  (cond
    [(null? left) (pair? right)]
    [(null? right) #f]
    [(eq? (car left) (car right))
     (edge-list<? (cdr left) (cdr right))]
    [else (frame-edge<? (car left) (car right))]))

(define (canonical-boundaries boundaries)
  (sort (remove-duplicates boundaries equal?) boundary<?))

(define (derivative-frame-graph-of calculus)
  (unless (equipped-calculus? calculus)
    (raise-argument-error
     'derivative-frame-graph-of "equipped-calculus?" calculus))
  (define occurrences (calculus-occurrences calculus))
  (define vertices
    (canonical-boundaries
     (append-map
      (lambda (occurrence)
        (cons
         (concrete-occurrence-conclusion occurrence)
         (vector->list (concrete-occurrence-premises occurrence))))
      occurrences)))
  (define edges
    (sort
     (append-map
      (lambda (occurrence)
        (define source (concrete-occurrence-conclusion occurrence))
        (define full-corolla (corolla calculus occurrence))
        (when (context-error? full-corolla)
          (error
           'derivative-frame-graph-of
           "an admitted occurrence unexpectedly failed corolla construction: ~e"
           full-corolla))
        (for/list ([slot (in-range 1 (add1 (occurrence-arity occurrence)))])
          (derivative-frame-edge
           calculus
           occurrence
           slot
           source
           (occurrence-premise occurrence slot)
           (for/list
               ([other-slot
                 (in-range 1 (add1 (occurrence-arity occurrence)))]
                #:unless (= other-slot slot))
             (frame-off-spine
              other-slot
              (occurrence-premise occurrence other-slot)))
           full-corolla
           (list slot)
           (concrete-occurrence-incidence occurrence))))
      occurrences)
     frame-edge<?))
  (derivative-frame-graph calculus vertices edges))

(define (check-graph who graph)
  (unless (derivative-frame-graph? graph)
    (raise-argument-error who "derivative-frame-graph?" graph)))

(define (check-graph-boundary who graph boundary)
  (unless (hypersequent? boundary)
    (raise-argument-error who "hypersequent? boundary" boundary))
  (unless (member boundary (derivative-frame-graph-vertices graph) equal?)
    (raise-arguments-error
     who
     "the boundary does not occur in this derivative-frame graph"
     "boundary" boundary)))

(define (derivative-frame-edges-from graph boundary)
  (check-graph 'derivative-frame-edges-from graph)
  (check-graph-boundary 'derivative-frame-edges-from graph boundary)
  (filter
   (lambda (edge)
     (equal? boundary (derivative-frame-edge-source edge)))
   (derivative-frame-graph-edges graph)))

(define (frame-productivity-ref productivity boundary)
  (unless (frame-productivity? productivity)
    (raise-argument-error
     'frame-productivity-ref "frame-productivity?" productivity))
  (unless (hypersequent? boundary)
    (raise-argument-error
     'frame-productivity-ref "hypersequent? boundary" boundary))
  (findf
   (lambda (witness)
     (equal? boundary (productivity-witness-boundary witness)))
   (frame-productivity-witnesses productivity)))

(struct productivity-candidate
  (height proof occurrence premise-witnesses)
  #:transparent)

(define (productivity-candidate<? left right)
  (cond
    [(< (productivity-candidate-height left)
        (productivity-candidate-height right))
     #t]
    [(> (productivity-candidate-height left)
        (productivity-candidate-height right))
     #f]
    [else
     (symbolic-datum<?
      (checked-term->raw (productivity-candidate-proof left))
      (checked-term->raw (productivity-candidate-proof right)))]))

(define (derivative-frame-productivity-of
         graph #:limit [limit analysis-default-limit])
  (check-graph 'derivative-frame-productivity-of graph)
  (check-limit 'derivative-frame-productivity-of limit)
  (define calculus (derivative-frame-graph-calculus graph))
  (define occurrences
    (sort
     (calculus-occurrences calculus)
     symbolic-datum<?
     #:key concrete-occurrence-id))
  (let/ec abort
    (define work 0)
    (define (tick! [amount 1])
      (set! work (+ work amount))
      (when (over-limit? work limit)
        (abort
         (make-analysis-limit
          'derivative-frame-productivity-of
          limit
          work
          'productivity-work
          (hash 'boundary-count
                (length (derivative-frame-graph-vertices graph))
                'occurrence-count (length occurrences))))))
    (let loop ([witness-table (hash)])
      ;; This round reads only the fixed point from the preceding round.
      ;; Consequently the first round discovering a boundary has its minimum
      ;; possible proof height.
      (define candidates
        (for/fold ([table (hash)]) ([occurrence (in-list occurrences)])
          (tick!)
          (define output (concrete-occurrence-conclusion occurrence))
          (cond
            [(hash-has-key? witness-table output) table]
            [else
             (define premise-witnesses
               (for/list
                   ([premise
                     (in-vector
                      (concrete-occurrence-premises occurrence))])
                 (tick!)
                 (hash-ref witness-table premise #f)))
             (cond
               [(and (positive? (occurrence-arity occurrence))
                     (ormap not premise-witnesses))
                table]
               [else
                (define height
                  (if (null? premise-witnesses)
                      1
                      (add1
                       (apply max
                              (map productivity-witness-height
                                   premise-witnesses)))))
                (define full-corolla (corolla calculus occurrence))
                (define proof
                  (complete-fill
                   full-corolla
                   (map productivity-witness-proof premise-witnesses)))
                (when (context-error? proof)
                  (error
                   'derivative-frame-productivity-of
                   "canonical productive premises failed checked filling: ~e"
                   proof))
                (define candidate
                  (productivity-candidate
                   height proof occurrence premise-witnesses))
                (define previous (hash-ref table output #f))
                (if (or (not previous)
                        (productivity-candidate<? candidate previous))
                    (hash-set table output candidate)
                    table)])])))
      (cond
        [(zero? (hash-count candidates))
         (frame-productivity
          graph
          (sort
           (hash-values witness-table)
           boundary<?
           #:key productivity-witness-boundary)
          work)]
        [else
         (define next-table
           (for/fold ([table witness-table])
                     ([output
                       (in-list
                        (sort (hash-keys candidates) boundary<?))])
             (define candidate (hash-ref candidates output))
             (hash-set
              table
              output
              (productivity-witness
               output
               (productivity-candidate-height candidate)
               (productivity-candidate-proof candidate)
               (productivity-candidate-occurrence candidate)
               (productivity-candidate-premise-witnesses candidate)))))
         (loop next-table)]))))

(define (check-productivity-for-graph who graph productivity)
  (unless (frame-productivity? productivity)
    (raise-argument-error who "frame-productivity?" productivity))
  (unless (eq? graph (frame-productivity-graph productivity))
    (raise-arguments-error
     who
     "the productivity result belongs to a different exact graph value"
     "graph" graph
     "productivity graph" (frame-productivity-graph productivity))))

(define (derivative-frame-edge-realised? edge productivity)
  (unless (derivative-frame-edge? edge)
    (raise-argument-error
     'derivative-frame-edge-realised? "derivative-frame-edge?" edge))
  (unless (frame-productivity? productivity)
    (raise-argument-error
     'derivative-frame-edge-realised? "frame-productivity?" productivity))
  (define graph (frame-productivity-graph productivity))
  (unless (and
           (eq? (derivative-frame-edge-calculus edge)
                (derivative-frame-graph-calculus graph))
           (memq edge (derivative-frame-graph-edges graph)))
    (raise-arguments-error
     'derivative-frame-edge-realised?
     "the edge does not belong to the productivity result's exact graph"
     "edge" edge
     "graph" graph))
  ;; The selected premise becomes the recursive hole.  Requiring it to be
  ;; productive would incorrectly reject unary recurrence without a seed.
  (for/and ([off-spine
             (in-list (derivative-frame-edge-off-spine edge))])
    (and
     (frame-productivity-ref
      productivity (frame-off-spine-boundary off-spine))
     #t)))

(define (check-edge-walk who graph edges)
  (unless (and (list? edges) (pair? edges)
               (andmap derivative-frame-edge? edges))
    (raise-argument-error
     who "nonempty-list-of derivative-frame-edge?" edges))
  (for ([edge (in-list edges)])
    (unless (and
             (eq? (derivative-frame-edge-calculus edge)
                  (derivative-frame-graph-calculus graph))
             (memq edge (derivative-frame-graph-edges graph)))
      (raise-arguments-error
       who
       "every edge must belong to the exact supplied graph"
       "edge" edge
       "graph" graph)))
  (for ([left (in-list edges)]
        [right (in-list (cdr edges))])
    (unless (equal? (derivative-frame-edge-target left)
                    (derivative-frame-edge-source right))
      (raise-arguments-error
       who
       "consecutive derivative-frame edges are not boundary-composable"
       "left target" (derivative-frame-edge-target left)
       "right source" (derivative-frame-edge-source right)))))

(define (walk-address-data edges)
  (let loop ([remaining edges]
             [prefix root-address]
             [off-spine-addresses '()])
    (define edge (car remaining))
    (define new-off-spine
      (append
       off-spine-addresses
       (for/list
           ([entry (in-list (derivative-frame-edge-off-spine edge))])
         (address-append prefix (list (frame-off-spine-slot entry))))))
    (define selected
      (address-append
       prefix (derivative-frame-edge-selected-address edge)))
    (if (null? (cdr remaining))
        (values selected (sort new-off-spine address<?))
        (loop (cdr remaining) selected new-off-spine))))

(define (build-raw-frame-walk graph edges)
  (check-edge-walk 'build-raw-frame-walk graph edges)
  (define current (derivative-frame-edge-corolla (car edges)))
  (define distinguished
    (derivative-frame-edge-selected-address (car edges)))
  (for ([edge (in-list (cdr edges))])
    (define inserted
      (context-insert
       current distinguished (derivative-frame-edge-corolla edge)))
    (when (context-error? inserted)
      (error
       'build-raw-frame-walk
       "composable exact frame corollas unexpectedly failed insertion: ~e"
       inserted))
    (set! current inserted)
    (set! distinguished
          (address-append
           distinguished (derivative-frame-edge-selected-address edge))))
  (define-values (computed-distinguished off-spine-addresses)
    (walk-address-data edges))
  (unless (equal? distinguished computed-distinguished)
    (error 'build-raw-frame-walk "internal distinguished-address mismatch"))
  (values current distinguished off-spine-addresses))

(define (make-cycle graph boundary edges)
  (check-edge-walk 'make-cycle graph edges)
  (unless (and
           (equal? boundary (derivative-frame-edge-source (car edges)))
           (equal? boundary (derivative-frame-edge-target (last edges))))
    (raise-arguments-error
     'make-cycle
     "the edge walk must be a nonempty cycle at the supplied boundary"
     "boundary" boundary
     "first source" (derivative-frame-edge-source (car edges))
     "last target" (derivative-frame-edge-target (last edges))))
  (define-values (raw distinguished off-spine-addresses)
    (build-raw-frame-walk graph edges))
  (frame-cycle
   graph boundary edges raw distinguished off-spine-addresses #t))

(define (cycle-search graph boundary edges operation limit)
  (check-graph operation graph)
  (check-graph-boundary operation graph boundary)
  (check-limit operation limit)
  (let/ec abort
    (define work 0)
    (define (tick!)
      (set! work (add1 work))
      (when (over-limit? work limit)
        (abort
         (make-analysis-limit
          operation
          limit
          work
          'cycle-search-work
          (hash 'boundary-count
                (length (derivative-frame-graph-vertices graph))
                'edge-count (length edges)
                'boundary (boundary-order-key boundary))))))

    ;; Reverse breadth-first distances give the shortest distance from every
    ;; reachable vertex back to the queried boundary.  A strictly decreasing
    ;; distance path is automatically simple and needs no cycle enumeration.
    (define distances (make-hash))
    (hash-set! distances boundary 0)
    (let bfs ([frontier (list boundary)] [distance 0])
      (unless (null? frontier)
        (define next (make-hash))
        (for* ([target (in-list (sort frontier boundary<?))]
               [edge (in-list edges)])
          (tick!)
          (when
              (and
               (equal? target (derivative-frame-edge-target edge))
               (not
                (hash-has-key?
                 distances (derivative-frame-edge-source edge))))
            (hash-set! next (derivative-frame-edge-source edge) #t)))
        (define next-frontier
          (sort (hash-keys next) boundary<?))
        (for ([source (in-list next-frontier)])
          (hash-set! distances source (add1 distance)))
        (bfs next-frontier (add1 distance))))

    (define (shortest-suffix source)
      (cond
        [(equal? source boundary) '()]
        [else
         (define distance (hash-ref distances source))
         (define selected
           (for/first
               ([edge (in-list edges)]
                #:when
                (and
                 (equal? source (derivative-frame-edge-source edge))
                 (hash-has-key?
                  distances (derivative-frame-edge-target edge))
                 (= (hash-ref
                     distances (derivative-frame-edge-target edge))
                    (sub1 distance))))
             edge))
         (unless selected
           (error 'cycle-search "reverse BFS lost a shortest suffix"))
         (cons
          selected
          (shortest-suffix (derivative-frame-edge-target selected))) ]))

    (define candidates
      (for/list
          ([edge (in-list edges)]
           #:when
           (and
            (equal? boundary (derivative-frame-edge-source edge))
            (hash-has-key? distances (derivative-frame-edge-target edge))))
        (cons edge (shortest-suffix (derivative-frame-edge-target edge)))))
    (cond
      [(null? candidates) #f]
      [else
       (define selected
         (car
          (sort
           candidates
           (lambda (left right)
             (cond
               [(< (length left) (length right)) #t]
               [(> (length left) (length right)) #f]
               [else (edge-list<? left right)])))))
       (make-cycle graph boundary selected)])))

(define (raw-frame-cycle-at
         graph boundary #:limit [limit analysis-default-limit])
  (check-graph 'raw-frame-cycle-at graph)
  (cycle-search
   graph
   boundary
   (derivative-frame-graph-edges graph)
   'raw-frame-cycle-at
   limit))

(define (realised-frame-cycle-at
         graph productivity boundary #:limit [limit analysis-default-limit])
  (check-graph 'realised-frame-cycle-at graph)
  (check-productivity-for-graph
   'realised-frame-cycle-at graph productivity)
  (define realised-edges
    (filter
     (lambda (edge)
       (derivative-frame-edge-realised? edge productivity))
     (derivative-frame-graph-edges graph)))
  (cycle-search
   graph
   boundary
   realised-edges
   'realised-frame-cycle-at
   limit))

(define (fill-raw-walk raw fillers operation)
  (let loop ([current raw] [remaining fillers])
    (cond
      [(null? remaining) current]
      [else
       (define entry (car remaining))
       (define inserted
         (context-insert current (car entry) (cdr entry)))
       (if (context-error? inserted)
           (make-analysis-error
            'frame-filling-failed
            "an exactly typed derivative-frame filler failed insertion"
            operation
            #:expected (puncture-requirement current (car entry))
            #:actual inserted
            #:details (hash 'address (car entry)))
           (loop inserted (cdr remaining)))])))

(define (realise-derivative-frame-edge edge productivity)
  (unless (derivative-frame-edge? edge)
    (raise-argument-error
     'realise-derivative-frame-edge "derivative-frame-edge?" edge))
  (unless (frame-productivity? productivity)
    (raise-argument-error
     'realise-derivative-frame-edge "frame-productivity?" productivity))
  (cond
    [(not (derivative-frame-edge-realised? edge productivity))
     (make-analysis-error
      'unproductive-off-spine
      "the selected frame has an off-spine boundary with no complete proof witness"
      'realise-derivative-frame-edge
      #:expected 'productive-off-spine-premises
      #:actual
      (for/list
          ([entry (in-list (derivative-frame-edge-off-spine edge))]
           #:unless
           (frame-productivity-ref
            productivity (frame-off-spine-boundary entry)))
        (frame-off-spine-boundary entry)))]
    [else
     (define fillers
       (for/list
           ([entry (in-list (derivative-frame-edge-off-spine edge))])
         (define witness
           (frame-productivity-ref
            productivity (frame-off-spine-boundary entry)))
         (cons
          (list (frame-off-spine-slot entry))
          (productivity-witness-proof witness))))
     (define context
       (fill-raw-walk
        (derivative-frame-edge-corolla edge)
        fillers
        'realise-derivative-frame-edge))
     (cond
       [(analysis-error? context) context]
       [(not
         (and
          (positive-one-hole-context? context)
          (equal? (puncture-addresses context)
                  (list (derivative-frame-edge-selected-address edge)))
          (equal? (derivation-root-boundary context)
                  (derivative-frame-edge-source edge))
          (equal?
           (puncture-requirement
            context (derivative-frame-edge-selected-address edge))
           (derivative-frame-edge-target edge))))
        (make-analysis-error
         'frame-realisation-invariant
         "canonical off-spine filling did not realise the selected frame"
         'realise-derivative-frame-edge
         #:expected
         (list 'positive-one-hole-frame
               (derivative-frame-edge-source edge)
               (derivative-frame-edge-target edge))
         #:actual context)]
       [else
        (realised-frame
         edge
         fillers
         context
         (derivative-frame-edge-selected-address edge))])]))

(define (realise-frame-cycle cycle productivity)
  (unless (frame-cycle? cycle)
    (raise-argument-error 'realise-frame-cycle "frame-cycle?" cycle))
  (define graph (frame-cycle-graph cycle))
  (check-productivity-for-graph 'realise-frame-cycle graph productivity)
  (define missing-off-spines
    (let loop ([edges (frame-cycle-edges cycle)]
               [prefix root-address]
               [result '()])
      (define edge (car edges))
      (define next-result
        (append
         result
         (for/list
             ([off-spine
               (in-list (derivative-frame-edge-off-spine edge))]
              #:unless
              (frame-productivity-ref
               productivity (frame-off-spine-boundary off-spine)))
           (list
            (address-append prefix (list (frame-off-spine-slot off-spine)))
            (frame-off-spine-boundary off-spine)))))
      (define next-prefix
        (address-append
         prefix (derivative-frame-edge-selected-address edge)))
      (if (null? (cdr edges))
          (sort next-result address<? #:key car)
          (loop (cdr edges) next-prefix next-result))))
  (if (pair? missing-off-spines)
     (make-analysis-error
      'unproductive-off-spine
      "the supplied cycle has an unproductive off-spine premise"
      'realise-frame-cycle
      #:expected 'productive-off-spine-premises
      #:actual missing-off-spines)
      (let ()
        (define fillers
          (let loop ([edges (frame-cycle-edges cycle)]
                     [prefix root-address]
                     [result '()])
            (define edge (car edges))
            (define next-result
              (append
               result
               (for/list
                   ([off-spine
                     (in-list (derivative-frame-edge-off-spine edge))])
                 (define witness
                   (frame-productivity-ref
                    productivity (frame-off-spine-boundary off-spine)))
                 (cons
                  (address-append
                   prefix (list (frame-off-spine-slot off-spine)))
                  (productivity-witness-proof witness)))))
            (define next-prefix
              (address-append
               prefix (derivative-frame-edge-selected-address edge)))
            (if (null? (cdr edges))
                (sort next-result address<? #:key car)
                (loop (cdr edges) next-prefix next-result))))
        (define context
          (fill-raw-walk
           (frame-cycle-raw-context cycle) fillers 'realise-frame-cycle))
        (cond
          [(analysis-error? context) context]
          [(not
            (and
             (positive-one-hole-context? context)
             (equal? (puncture-addresses context)
                     (list (frame-cycle-distinguished-address cycle)))
             (equal? (derivation-root-boundary context)
                     (frame-cycle-boundary cycle))
             (equal?
              (puncture-requirement
               context (frame-cycle-distinguished-address cycle))
              (frame-cycle-boundary cycle))))
           (make-analysis-error
            'frame-realisation-invariant
            "canonical off-spine filling did not produce the expected return context"
            'realise-frame-cycle
            #:expected
            (list 'positive-one-hole-return
                  (frame-cycle-boundary cycle)
                  (frame-cycle-distinguished-address cycle))
            #:actual context)]
          [else
           (define seed-witness
             (frame-productivity-ref productivity (frame-cycle-boundary cycle)))
           (frame-realisation
            cycle
            fillers
            context
            (and seed-witness (productivity-witness-proof seed-witness))
            (if seed-witness 'realised-with-seed 'realised-no-seed))]))))

(define (positive-one-hole-context? value)
  (and (checked-node? value)
       (proof-context? value)
       (= (length (puncture-addresses value)) 1)))

(define (edge-for-node-slot graph occurrence slot)
  (for/first
      ([edge (in-list (derivative-frame-graph-edges graph))]
       #:when
       (and
        (eq? occurrence (derivative-frame-edge-occurrence edge))
        (= slot (derivative-frame-edge-slot edge))))
    edge))

(define (one-hole-context->frame-walk graph context)
  (check-graph 'one-hole-context->frame-walk graph)
  (cond
    [(not (positive-one-hole-context? context))
     (make-analysis-error
      'not-positive-one-hole-context
      "frame decomposition requires a positive context with exactly one puncture"
      'one-hole-context->frame-walk
      #:expected 'positive-one-hole-context
      #:actual context)]
    [(not
      (checked-term-has-exact-calculus?
       context (derivative-frame-graph-calculus graph)))
     (make-analysis-error
      'calculus-mismatch
      "the context must carry the derivative-frame graph's exact calculus"
      'one-hole-context->frame-walk
      #:expected (derivative-frame-graph-calculus graph)
      #:actual (checked-term-calculus context))]
    [else
     (define distinguished (car (puncture-addresses context)))
     (define edges '())
     (define fillers '())
     (define failure #f)
     (let walk ([prefix root-address] [remaining distinguished])
       (cond
         [(null? remaining)
          (unless (checked-hole? (checked-term-at-address context prefix))
            (set! failure
                  (make-analysis-error
                   'frame-path-invariant
                   "the distinguished frame path did not end at its puncture"
                   'one-hole-context->frame-walk
                   #:actual prefix)))]
         [else
          (define node (vertex-at-address context prefix))
          (define slot (car remaining))
          (cond
            [(not node)
             (set! failure
                   (make-analysis-error
                    'frame-path-invariant
                    "a strict puncture prefix was not a retained vertex"
                    'one-hole-context->frame-walk
                    #:actual prefix))]
            [else
             (define edge
               (edge-for-node-slot
                graph (checked-node-occurrence node) slot))
             (cond
               [(not edge)
                (set! failure
                      (make-analysis-error
                       'missing-frame-edge
                       "the exact retained occurrence/slot is absent from the graph"
                       'one-hole-context->frame-walk
                       #:actual
                       (list
                        (concrete-occurrence-id
                         (checked-node-occurrence node))
                        slot)))]
               [else
                (set! edges (append edges (list edge)))
                (for ([child (in-list (checked-node-children node))]
                      [child-slot (in-naturals 1)]
                      #:unless (= child-slot slot))
                  (unless (complete-proof? child)
                    (set! failure
                          (make-analysis-error
                           'incomplete-off-spine
                           "a one-hole frame path had an incomplete off-spine child"
                           'one-hole-context->frame-walk
                           #:actual
                           (address-append prefix (list child-slot)))))
                  (set! fillers
                        (append
                         fillers
                         (list
                          (cons
                           (address-append prefix (list child-slot))
                           child)))))
                (unless failure
                  (walk
                   (address-append prefix (list slot))
                   (cdr remaining)))])])]))
     (cond
       [failure failure]
       [else
        (define-values (raw computed-distinguished off-spine-addresses)
          (build-raw-frame-walk graph edges))
        (define sorted-fillers (sort fillers address<? #:key car))
        (define reconstructed
          (fill-raw-walk
           raw sorted-fillers 'one-hole-context->frame-walk))
        (cond
          [(analysis-error? reconstructed) reconstructed]
          [else
           (define source-boundary (derivation-root-boundary context))
           (define target-boundary
             (puncture-requirement context distinguished))
           (frame-context-decomposition
            context
            graph
            source-boundary
            target-boundary
            edges
            computed-distinguished
            sorted-fillers
            raw
            reconstructed
            (equal? source-boundary target-boundary)
            (and
             (equal? distinguished computed-distinguished)
             (equal? off-spine-addresses (map car sorted-fillers))
             (checked-term-has-exact-calculus?
              reconstructed (derivative-frame-graph-calculus graph))
             (equal? context reconstructed)))])])]))

(define (frame-context-decomposition-realised? decomposition productivity)
  (unless (frame-context-decomposition? decomposition)
    (raise-argument-error
     'frame-context-decomposition-realised?
     "frame-context-decomposition?"
     decomposition))
  (define graph (frame-context-decomposition-graph decomposition))
  (check-productivity-for-graph
   'frame-context-decomposition-realised? graph productivity)
  (and
   (frame-context-decomposition-reconstructs? decomposition)
   (for/and
       ([edge (in-list (frame-context-decomposition-edges decomposition))])
     (derivative-frame-edge-realised? edge productivity))))

(define (boundary-recurrence-of
         graph boundary #:limit [limit analysis-default-limit])
  (check-graph 'boundary-recurrence-of graph)
  (check-graph-boundary 'boundary-recurrence-of graph boundary)
  (check-limit 'boundary-recurrence-of limit)
  (define raw (raw-frame-cycle-at graph boundary #:limit limit))
  (cond
    [(analysis-limit? raw) raw]
    [(not raw)
     (boundary-recurrence
      graph boundary #f #f #f #f #f 'acyclic #t)]
    [else
     ;; Productivity is computed only when a raw recurrence actually needs
     ;; off-spine realisation or seed classification.
     (define productivity
       (derivative-frame-productivity-of graph #:limit limit))
     (cond
       [(analysis-limit? productivity) productivity]
       [else
        (define realised
          (realised-frame-cycle-at
           graph productivity boundary #:limit limit))
        (cond
          [(analysis-limit? realised) realised]
          [(not realised)
           (boundary-recurrence
            graph
            boundary
            productivity
            raw
            #f
            #f
            #f
            'raw-unrealised
            #t)]
          [else
           (define realisation
             (realise-frame-cycle realised productivity))
           (cond
             [(analysis-error? realisation) realisation]
             [else
              (define decomposition
                (one-hole-context->frame-walk
                 graph (frame-realisation-context realisation)))
              (define theorem-holds?
                (and
                 (frame-context-decomposition? decomposition)
                 (frame-context-decomposition-cycle? decomposition)
                 (frame-context-decomposition-realised?
                  decomposition productivity)))
              (boundary-recurrence
               graph
               boundary
               productivity
               raw
               realised
               realisation
               decomposition
               (frame-realisation-status realisation)
               theorem-holds?)])])])]))
