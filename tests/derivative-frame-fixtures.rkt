#lang racket/base

(require "../potkin/kernel.rkt")

(provide frame-G
         frame-H
         frame-Dead
         acyclic-ground-occurrence
         acyclic-step-occurrence
         acyclic-calculus
         self-no-seed-occurrence
         self-no-seed-calculus
         self-seed-occurrence
         self-with-seed-occurrence
         self-with-seed-calculus
         mutual-G-from-H-occurrence
         mutual-H-from-G-occurrence
         mutual-calculus
         blocked-cycle-occurrence
         blocked-cycle-calculus
         parallel-ground-occurrence
         parallel-occurrence
         parallel-calculus
         deterministic-ground-a-occurrence
         deterministic-ground-z-occurrence
         deterministic-loop-a-occurrence
         deterministic-loop-z-occurrence
         deterministic-calculus
         deterministic-calculus/reversed)

(define frame-G (singleton-hypersequent '() '(G)))
(define frame-H (singleton-hypersequent '() '(H)))
(define frame-Dead (singleton-hypersequent '() '(Dead)))

;; A finite productive chain with no return edge.
(define acyclic-ground-occurrence
  (make-concrete-occurrence
   'frame-acyclic-ground
   '()
   frame-G
   #:kind 'material
   #:tag 'ground))
(define acyclic-step-occurrence
  (make-concrete-occurrence
   'frame-acyclic-H-from-G
   (list frame-G)
   frame-H
   #:tag 'acyclic-step))
(define acyclic-calculus
  (make-equipped-calculus
   (list acyclic-ground-occurrence acyclic-step-occurrence)))

;; A unary frame is realised without any off-spine productivity.  With no
;; ground constructor its return context exists but has no complete seed.
(define self-no-seed-occurrence
  (make-concrete-occurrence
   'frame-self-no-seed
   (list frame-G)
   frame-G
   #:tag 'self-frame))
(define self-no-seed-calculus
  (make-equipped-calculus (list self-no-seed-occurrence)))

(define self-seed-occurrence
  (make-concrete-occurrence
   'frame-self-seed
   '()
   frame-G
   #:kind 'material
   #:tag 'ground))
(define self-with-seed-occurrence
  (make-concrete-occurrence
   'frame-self-with-seed
   (list frame-G)
   frame-G
   #:tag 'self-frame))
(define self-with-seed-calculus
  (make-equipped-calculus
   (list self-with-seed-occurrence self-seed-occurrence)))

;; The shortest return to G is the two-edge walk G -> H -> G.
(define mutual-G-from-H-occurrence
  (make-concrete-occurrence
   'frame-mutual-G-from-H
   (list frame-H)
   frame-G
   #:tag 'mutual-frame))
(define mutual-H-from-G-occurrence
  (make-concrete-occurrence
   'frame-mutual-H-from-G
   (list frame-G)
   frame-H
   #:tag 'mutual-frame))
(define mutual-calculus
  (make-equipped-calculus
   (list mutual-G-from-H-occurrence mutual-H-from-G-occurrence)))

;; Selecting slot 1 gives a raw G-return frame.  Its slot-2 Dead obligation
;; has no complete proof, so that raw frame cannot be realised.
(define blocked-cycle-occurrence
  (make-concrete-occurrence
   'frame-blocked-cycle
   (list frame-G frame-Dead)
   frame-G
   #:tag 'blocked-frame))
(define blocked-cycle-calculus
  (make-equipped-calculus (list blocked-cycle-occurrence)))

;; Both premise occurrences display G.  They remain distinct 1-indexed frame
;; edges, and either selected edge can be realised by the same ground witness
;; in its opposite, occurrence-local slot.
(define parallel-ground-occurrence
  (make-concrete-occurrence
   'frame-parallel-ground
   '()
   frame-G
   #:kind 'material
   #:tag 'ground))
(define parallel-occurrence
  (make-concrete-occurrence
   'frame-parallel
   (list frame-G frame-G)
   frame-G
   #:tag 'parallel-frame))
(define parallel-calculus
  (make-equipped-calculus
   (list parallel-occurrence parallel-ground-occurrence)))

;; These tied grounds and tied unary loops make deterministic structural
;; selection observable.  A second exact registry is built in reverse input
;; order to ensure no caller or hash iteration order leaks into the result.
(define deterministic-ground-a-occurrence
  (make-concrete-occurrence
   'frame-deterministic-ground-a
   '()
   frame-G
   #:kind 'material
   #:tag 'ground))
(define deterministic-ground-z-occurrence
  (make-concrete-occurrence
   'frame-deterministic-ground-z
   '()
   frame-G
   #:kind 'material
   #:tag 'ground))
(define deterministic-loop-a-occurrence
  (make-concrete-occurrence
   'frame-deterministic-loop-a
   (list frame-G)
   frame-G
   #:tag 'self-frame))
(define deterministic-loop-z-occurrence
  (make-concrete-occurrence
   'frame-deterministic-loop-z
   (list frame-G)
   frame-G
   #:tag 'self-frame))

(define deterministic-occurrences
  (list deterministic-ground-z-occurrence
        deterministic-loop-z-occurrence
        deterministic-ground-a-occurrence
        deterministic-loop-a-occurrence))
(define deterministic-calculus
  (make-equipped-calculus deterministic-occurrences))
(define deterministic-calculus/reversed
  (make-equipped-calculus (reverse deterministic-occurrences)))
