#lang racket/base

(require racket/list
         rackunit
         "../potkin/kernel.rkt"
         "../potkin/analysis/ancestry.rkt"
         "../potkin/analysis/derivative-frame.rkt"
         "derivative-frame-fixtures.rkt")

(define (edge-id edge)
  (concrete-occurrence-id (derivative-frame-edge-occurrence edge)))

(define (edge-id/slot edge)
  (list (edge-id edge) (derivative-frame-edge-slot edge)))

(define (cycle-id/slots cycle)
  (map edge-id/slot (frame-cycle-edges cycle)))

(define (boundary-datum boundary)
  (for/list ([sequent (in-list (hypersequent-sequents boundary))])
    (list (formula-context->list (sequent-left sequent))
          (formula-context->list (sequent-right sequent)))))

(define (graph-edge-data graph)
  (for/list ([edge (in-list (derivative-frame-graph-edges graph))])
    (list (boundary-datum (derivative-frame-edge-source edge))
          (boundary-datum (derivative-frame-edge-target edge))
          (edge-id edge)
          (derivative-frame-edge-slot edge))))

;; Acyclicity is graph-theoretic, even when every boundary in the finite chain
;; has a complete proof witness.
(define acyclic-graph (derivative-frame-graph-of acyclic-calculus))
(check-true (derivative-frame-graph? acyclic-graph))
(check-eq? (derivative-frame-graph-calculus acyclic-graph) acyclic-calculus)
(check-equal? (derivative-frame-graph-vertices acyclic-graph)
              (list frame-G frame-H))
(check-equal? (length (derivative-frame-graph-edges acyclic-graph)) 1)
(define acyclic-edge (car (derivative-frame-graph-edges acyclic-graph)))
(check-eq? (derivative-frame-edge-occurrence acyclic-edge)
           acyclic-step-occurrence)
(check-equal? (derivative-frame-edge-slot acyclic-edge) 1)
(check-equal? (derivative-frame-edge-source acyclic-edge) frame-H)
(check-equal? (derivative-frame-edge-target acyclic-edge) frame-G)
(check-equal? (derivative-frame-edge-selected-address acyclic-edge) '(1))
(check-equal? (derivative-frame-edge-off-spine acyclic-edge) '())
(check-equal? (derivative-frame-edge-incidence acyclic-edge) '())
(check-equal? (checked-term->raw (derivative-frame-edge-corolla acyclic-edge))
              '(app frame-acyclic-H-from-G (puncture)))

(define acyclic-productivity
  (derivative-frame-productivity-of acyclic-graph))
(check-true (frame-productivity? acyclic-productivity))
(check-eq? (frame-productivity-graph acyclic-productivity) acyclic-graph)
(define acyclic-G-witness
  (frame-productivity-ref acyclic-productivity frame-G))
(define acyclic-H-witness
  (frame-productivity-ref acyclic-productivity frame-H))
(check-true (productivity-witness? acyclic-G-witness))
(check-true (productivity-witness? acyclic-H-witness))
(check-equal? (productivity-witness-height acyclic-G-witness) 1)
(check-equal? (productivity-witness-height acyclic-H-witness) 2)
(check-equal? (checked-term->raw (productivity-witness-proof acyclic-H-witness))
              '(app frame-acyclic-H-from-G
                    (app frame-acyclic-ground)))
(check-false (raw-frame-cycle-at acyclic-graph frame-H))
(check-false
 (realised-frame-cycle-at
  acyclic-graph acyclic-productivity frame-H))
(define acyclic-recurrence
  (boundary-recurrence-of acyclic-graph frame-H))
(check-true (boundary-recurrence? acyclic-recurrence))
(check-equal? (boundary-recurrence-status acyclic-recurrence) 'acyclic)
(check-false (boundary-recurrence-productivity acyclic-recurrence))
(check-false (boundary-recurrence-decomposition acyclic-recurrence))
(check-true (boundary-recurrence-theorem-holds? acyclic-recurrence))

;; Unary recurrence needs no productive off-spine premise.  Hence its return
;; context is realised even though the boundary itself has no complete seed.
(define no-seed-graph
  (derivative-frame-graph-of self-no-seed-calculus))
(define no-seed-productivity
  (derivative-frame-productivity-of no-seed-graph))
(check-equal? (frame-productivity-witnesses no-seed-productivity) '())
(define no-seed-edge
  (car (derivative-frame-graph-edges no-seed-graph)))
(check-true
 (derivative-frame-edge-realised? no-seed-edge no-seed-productivity))
(define no-seed-cycle (raw-frame-cycle-at no-seed-graph frame-G))
(check-true (frame-cycle? no-seed-cycle))
(check-equal? (cycle-id/slots no-seed-cycle)
              '((frame-self-no-seed 1)))
(check-equal? (checked-term->raw (frame-cycle-raw-context no-seed-cycle))
              '(app frame-self-no-seed (puncture)))
(check-equal? (frame-cycle-distinguished-address no-seed-cycle) '(1))
(check-equal? (frame-cycle-off-spine-addresses no-seed-cycle) '())
(check-true (frame-cycle-simple? no-seed-cycle))
(define no-seed-realised-cycle
  (realised-frame-cycle-at
   no-seed-graph no-seed-productivity frame-G))
(check-equal? (cycle-id/slots no-seed-realised-cycle)
              (cycle-id/slots no-seed-cycle))
(define no-seed-realisation
  (realise-frame-cycle no-seed-realised-cycle no-seed-productivity))
(check-true (frame-realisation? no-seed-realisation))
(check-equal? (frame-realisation-status no-seed-realisation)
              'realised-no-seed)
(check-false (frame-realisation-seed-proof no-seed-realisation))
(check-equal? (frame-realisation-fillers no-seed-realisation) '())
(check-true
 (positive-one-hole-context? (frame-realisation-context no-seed-realisation)))
(check-eq?
 (checked-term-calculus (frame-realisation-context no-seed-realisation))
 self-no-seed-calculus)

;; Cycle -> realised context -> frame walk is an exact presentation round trip.
(define no-seed-decomposition
  (one-hole-context->frame-walk
   no-seed-graph (frame-realisation-context no-seed-realisation)))
(check-true (frame-context-decomposition? no-seed-decomposition))
(check-equal? (map edge-id/slot
                   (frame-context-decomposition-edges no-seed-decomposition))
              '((frame-self-no-seed 1)))
(check-equal? (frame-context-decomposition-distinguished-address
               no-seed-decomposition)
              '(1))
(check-true (frame-context-decomposition-cycle? no-seed-decomposition))
(check-true (frame-context-decomposition-reconstructs? no-seed-decomposition))
(check-equal? (frame-context-decomposition-reconstructed
               no-seed-decomposition)
              (frame-realisation-context no-seed-realisation))
(check-true
 (frame-context-decomposition-realised?
  no-seed-decomposition no-seed-productivity))
(define no-seed-recurrence
  (boundary-recurrence-of no-seed-graph frame-G))
(check-equal? (boundary-recurrence-status no-seed-recurrence)
              'realised-no-seed)
(check-true
 (frame-context-decomposition?
  (boundary-recurrence-decomposition no-seed-recurrence)))
(check-true
 (frame-context-decomposition-reconstructs?
  (boundary-recurrence-decomposition no-seed-recurrence)))
(check-true (boundary-recurrence-theorem-holds? no-seed-recurrence))

;; Adding a nullary ground changes only seed classification, not the unary
;; derivative frame or its distinguished premise.
(define seeded-graph
  (derivative-frame-graph-of self-with-seed-calculus))
(define seeded-productivity
  (derivative-frame-productivity-of seeded-graph))
(define seeded-G-witness
  (frame-productivity-ref seeded-productivity frame-G))
(check-true (productivity-witness? seeded-G-witness))
(check-equal? (productivity-witness-height seeded-G-witness) 1)
(check-eq? (productivity-witness-occurrence seeded-G-witness)
           self-seed-occurrence)
(check-equal? (checked-term->raw (productivity-witness-proof seeded-G-witness))
              '(app frame-self-seed))
(define seeded-recurrence
  (boundary-recurrence-of seeded-graph frame-G))
(check-equal? (boundary-recurrence-status seeded-recurrence)
              'realised-with-seed)
(check-true
 (frame-context-decomposition?
  (boundary-recurrence-decomposition seeded-recurrence)))
(check-true
 (frame-context-decomposition-reconstructs?
  (boundary-recurrence-decomposition seeded-recurrence)))
(check-true (boundary-recurrence-theorem-holds? seeded-recurrence))
(define seeded-realisation
  (boundary-recurrence-realisation seeded-recurrence))
(check-equal? (checked-term->raw (frame-realisation-context seeded-realisation))
              '(app frame-self-with-seed (puncture)))
(check-equal? (checked-term->raw (frame-realisation-seed-proof seeded-realisation))
              '(app frame-self-seed))
(define seeded-unfolding
  (context-insert
   (frame-realisation-context seeded-realisation)
   (frame-cycle-distinguished-address
    (frame-realisation-cycle seeded-realisation))
   (frame-realisation-seed-proof seeded-realisation)))
(check-true (complete-proof? seeded-unfolding))
(check-equal? (checked-term->raw seeded-unfolding)
              '(app frame-self-with-seed (app frame-self-seed)))
(check-eq? (checked-term-calculus seeded-unfolding)
           self-with-seed-calculus)

;; A mutual G/H recurrence composes ordered unary slots; addresses concatenate
;; to (1 1), and each base boundary gets the corresponding rotation.
(define mutual-graph (derivative-frame-graph-of mutual-calculus))
(define mutual-productivity
  (derivative-frame-productivity-of mutual-graph))
(check-equal? (frame-productivity-witnesses mutual-productivity) '())
(define mutual-G-cycle (raw-frame-cycle-at mutual-graph frame-G))
(define mutual-H-cycle (raw-frame-cycle-at mutual-graph frame-H))
(check-equal? (cycle-id/slots mutual-G-cycle)
              '((frame-mutual-G-from-H 1)
                (frame-mutual-H-from-G 1)))
(check-equal? (cycle-id/slots mutual-H-cycle)
              '((frame-mutual-H-from-G 1)
                (frame-mutual-G-from-H 1)))
(check-equal? (checked-term->raw (frame-cycle-raw-context mutual-G-cycle))
              '(app frame-mutual-G-from-H
                    (app frame-mutual-H-from-G (puncture))))
(check-equal? (frame-cycle-distinguished-address mutual-G-cycle) '(1 1))
(check-equal? (frame-cycle-off-spine-addresses mutual-G-cycle) '())
(check-true (frame-cycle-simple? mutual-G-cycle))
(define mutual-realisation
  (realise-frame-cycle
   (realised-frame-cycle-at mutual-graph mutual-productivity frame-G)
   mutual-productivity))
(check-equal? (frame-realisation-status mutual-realisation)
              'realised-no-seed)
(define mutual-decomposition
  (one-hole-context->frame-walk
   mutual-graph (frame-realisation-context mutual-realisation)))
(check-true (frame-context-decomposition-cycle? mutual-decomposition))
(check-true (frame-context-decomposition-reconstructs? mutual-decomposition))
(check-equal? (map edge-id/slot
                   (frame-context-decomposition-edges mutual-decomposition))
              (cycle-id/slots mutual-G-cycle))
(check-equal? (frame-context-decomposition-source-boundary
               mutual-decomposition)
              frame-G)
(check-equal? (frame-context-decomposition-target-boundary
               mutual-decomposition)
              frame-G)
(check-true
 (frame-context-decomposition-realised?
  mutual-decomposition mutual-productivity))

;; A raw recursive skeleton is not a realised one-hole context when an
;; off-spine boundary has no complete witness.
(define blocked-graph
  (derivative-frame-graph-of blocked-cycle-calculus))
(define blocked-edges (derivative-frame-graph-edges blocked-graph))
(check-equal? (map edge-id/slot blocked-edges)
              '((frame-blocked-cycle 2)
                (frame-blocked-cycle 1)))
(check-false (eq? (first blocked-edges) (second blocked-edges)))
(define blocked-slot-1
  (findf (lambda (edge) (= (derivative-frame-edge-slot edge) 1))
         blocked-edges))
(define blocked-slot-2
  (findf (lambda (edge) (= (derivative-frame-edge-slot edge) 2))
         blocked-edges))
(check-equal? (map frame-off-spine-slot
                   (derivative-frame-edge-off-spine blocked-slot-1))
              '(2))
(check-equal? (map frame-off-spine-boundary
                   (derivative-frame-edge-off-spine blocked-slot-1))
              (list frame-Dead))
(define blocked-productivity
  (derivative-frame-productivity-of blocked-graph))
(check-equal? (frame-productivity-witnesses blocked-productivity) '())
(check-false
 (derivative-frame-edge-realised?
  blocked-slot-1 blocked-productivity))
(check-false
 (derivative-frame-edge-realised?
  blocked-slot-2 blocked-productivity))
(define blocked-raw-cycle
  (raw-frame-cycle-at blocked-graph frame-G))
(check-equal? (cycle-id/slots blocked-raw-cycle)
              '((frame-blocked-cycle 1)))
(check-equal? (checked-term->raw (frame-cycle-raw-context blocked-raw-cycle))
              '(app frame-blocked-cycle (puncture) (puncture)))
(check-equal? (frame-cycle-distinguished-address blocked-raw-cycle) '(1))
(check-equal? (frame-cycle-off-spine-addresses blocked-raw-cycle) '((2)))
(check-false
 (positive-one-hole-context? (frame-cycle-raw-context blocked-raw-cycle)))
(check-false
 (realised-frame-cycle-at blocked-graph blocked-productivity frame-G))
(define blocked-realisation-attempt
  (realise-frame-cycle blocked-raw-cycle blocked-productivity))
(check-true (analysis-error? blocked-realisation-attempt))
(check-equal? (analysis-error-code blocked-realisation-attempt)
              'unproductive-off-spine)
(check-equal? (analysis-error-operation blocked-realisation-attempt)
              'realise-frame-cycle)
(check-equal? (analysis-error-expected blocked-realisation-attempt)
              'productive-off-spine-premises)
(check-equal? (analysis-error-actual blocked-realisation-attempt)
              (list (list '(2) frame-Dead)))
(define blocked-recurrence
  (boundary-recurrence-of blocked-graph frame-G))
(check-equal? (boundary-recurrence-status blocked-recurrence)
              'raw-unrealised)
(check-false (boundary-recurrence-realised-cycle blocked-recurrence))
(check-false (boundary-recurrence-realisation blocked-recurrence))
(check-false (boundary-recurrence-decomposition blocked-recurrence))
(check-true (boundary-recurrence-theorem-holds? blocked-recurrence))

;; Equal displayed premise boundaries retain separate local slot identities.
(define parallel-graph
  (derivative-frame-graph-of parallel-calculus))
(define parallel-edges
  (filter
   (lambda (edge) (eq? (derivative-frame-edge-occurrence edge)
                       parallel-occurrence))
   (derivative-frame-graph-edges parallel-graph)))
(check-equal? (length parallel-edges) 2)
(check-equal? (map derivative-frame-edge-slot parallel-edges) '(1 2))
(check-true
 (for/and ([edge (in-list parallel-edges)])
   (and (equal? (derivative-frame-edge-source edge) frame-G)
        (equal? (derivative-frame-edge-target edge) frame-G))))
(check-false (eq? (first parallel-edges) (second parallel-edges)))
(check-equal? (map frame-off-spine-slot
                   (derivative-frame-edge-off-spine
                    (first parallel-edges)))
              '(2))
(check-equal? (map frame-off-spine-slot
                   (derivative-frame-edge-off-spine
                    (second parallel-edges)))
              '(1))
(check-eq? (derivative-frame-edge-corolla (first parallel-edges))
           (derivative-frame-edge-corolla (second parallel-edges)))
(define parallel-productivity
  (derivative-frame-productivity-of parallel-graph))
(check-true
 (andmap
  (lambda (edge)
    (derivative-frame-edge-realised? edge parallel-productivity))
  parallel-edges))
(define parallel-frame-1
  (realise-derivative-frame-edge
   (first parallel-edges) parallel-productivity))
(define parallel-frame-2
  (realise-derivative-frame-edge
   (second parallel-edges) parallel-productivity))
(check-true (realised-frame? parallel-frame-1))
(check-true (realised-frame? parallel-frame-2))
(check-equal? (checked-term->raw (realised-frame-context parallel-frame-1))
              '(app frame-parallel
                    (puncture)
                    (app frame-parallel-ground)))
(check-equal? (checked-term->raw (realised-frame-context parallel-frame-2))
              '(app frame-parallel
                    (app frame-parallel-ground)
                    (puncture)))
(check-equal? (realised-frame-distinguished-address parallel-frame-1) '(1))
(check-equal? (realised-frame-distinguished-address parallel-frame-2) '(2))
(check-equal? (map car (realised-frame-fillers parallel-frame-1)) '((2)))
(check-equal? (map car (realised-frame-fillers parallel-frame-2)) '((1)))
(check-equal? (cycle-id/slots (raw-frame-cycle-at parallel-graph frame-G))
              '((frame-parallel 1)))

;; Context -> frame walk is also tested independently of the canonical cycle:
;; this valid return context selects the second of the two parallel slots.
(define parallel-slot-2-context
  (validate-candidate
   parallel-calculus
   (raw-app 'frame-parallel
            (raw-app 'frame-parallel-ground)
            raw-hole)
   #:expected frame-G))
(check-true (positive-one-hole-context? parallel-slot-2-context))
(define parallel-slot-2-decomposition
  (one-hole-context->frame-walk
   parallel-graph parallel-slot-2-context))
(check-true (frame-context-decomposition? parallel-slot-2-decomposition))
(check-equal? (map edge-id/slot
                   (frame-context-decomposition-edges
                    parallel-slot-2-decomposition))
              '((frame-parallel 2)))
(check-equal? (frame-context-decomposition-distinguished-address
               parallel-slot-2-decomposition)
              '(2))
(check-equal? (map car
                   (frame-context-decomposition-off-spine-fillers
                    parallel-slot-2-decomposition))
              '((1)))
(check-equal? (checked-term->raw
               (frame-context-decomposition-raw-context
                parallel-slot-2-decomposition))
              '(app frame-parallel (puncture) (puncture)))
(check-equal? (frame-context-decomposition-reconstructed
               parallel-slot-2-decomposition)
              parallel-slot-2-context)
(check-true
 (frame-context-decomposition-reconstructs? parallel-slot-2-decomposition))
(check-true (frame-context-decomposition-cycle?
             parallel-slot-2-decomposition))
(check-true
 (frame-context-decomposition-realised?
  parallel-slot-2-decomposition parallel-productivity))

;; Ties are broken by immutable symbolic structure, not by registry insertion,
;; hash traversal, or a printed representation.
(define deterministic-graph
  (derivative-frame-graph-of deterministic-calculus))
(define deterministic-graph/reversed
  (derivative-frame-graph-of deterministic-calculus/reversed))
(check-false (eq? deterministic-calculus
                  deterministic-calculus/reversed))
(check-equal? (graph-edge-data deterministic-graph)
              (graph-edge-data deterministic-graph/reversed))
(check-equal? (map edge-id/slot
                   (derivative-frame-graph-edges deterministic-graph))
              '((frame-deterministic-loop-a 1)
                (frame-deterministic-loop-z 1)))
(define deterministic-productivity
  (derivative-frame-productivity-of deterministic-graph))
(define deterministic-productivity/reversed
  (derivative-frame-productivity-of deterministic-graph/reversed))
(check-equal?
 (checked-term->raw
  (productivity-witness-proof
   (frame-productivity-ref deterministic-productivity frame-G)))
 '(app frame-deterministic-ground-a))
(check-equal?
 (checked-term->raw
  (productivity-witness-proof
   (frame-productivity-ref deterministic-productivity/reversed frame-G)))
 '(app frame-deterministic-ground-a))
(define deterministic-cycle
  (raw-frame-cycle-at deterministic-graph frame-G))
(define deterministic-cycle/reversed
  (raw-frame-cycle-at deterministic-graph/reversed frame-G))
(check-equal? (cycle-id/slots deterministic-cycle)
              '((frame-deterministic-loop-a 1)))
(check-equal? (cycle-id/slots deterministic-cycle/reversed)
              '((frame-deterministic-loop-a 1)))
(check-equal? (checked-term->raw (frame-cycle-raw-context deterministic-cycle))
              (checked-term->raw
               (frame-cycle-raw-context deterministic-cycle/reversed)))
(check-eq? (checked-term-calculus
            (frame-cycle-raw-context deterministic-cycle))
           deterministic-calculus)
(check-eq? (checked-term-calculus
            (frame-cycle-raw-context deterministic-cycle/reversed))
           deterministic-calculus/reversed)

;; Every bounded exact search reports that it was not computed; none silently
;; reclassifies a cutoff as acyclic, unproductive, or nonrecurrent.
(define raw-cycle-limit
  (raw-frame-cycle-at no-seed-graph frame-G #:limit 0))
(check-true (analysis-limit? raw-cycle-limit))
(check-equal? (analysis-limit-code raw-cycle-limit) 'not-computed-limit)
(check-equal? (analysis-limit-operation raw-cycle-limit) 'raw-frame-cycle-at)
(check-equal? (analysis-limit-limit raw-cycle-limit) 0)
(check-equal? (analysis-limit-required raw-cycle-limit) 1)
(check-equal? (analysis-limit-metric raw-cycle-limit) 'cycle-search-work)

(define productivity-limit
  (derivative-frame-productivity-of seeded-graph #:limit 0))
(check-true (analysis-limit? productivity-limit))
(check-equal? (analysis-limit-operation productivity-limit)
              'derivative-frame-productivity-of)
(check-equal? (analysis-limit-limit productivity-limit) 0)
(check-equal? (analysis-limit-required productivity-limit) 1)
(check-equal? (analysis-limit-metric productivity-limit)
              'productivity-work)

(define recurrence-limit
  (boundary-recurrence-of no-seed-graph frame-G #:limit 0))
(check-true (analysis-limit? recurrence-limit))
(check-equal? (analysis-limit-operation recurrence-limit)
              'raw-frame-cycle-at)
(check-equal? (analysis-limit-metric recurrence-limit)
              'cycle-search-work)
