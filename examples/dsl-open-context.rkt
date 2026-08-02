#lang racket/base

(require potkin)

(define-formula-signature L
  #:atoms [S T U]
  [fusion 2])

(define HS  (hseq L (seq L [] => [S])))
(define HT  (hseq L (seq L [] => [T])))
(define HST (hseq L (seq L [] => [(fusion S T)])))
(define HU  (hseq L (seq L [] => [U])))

(define-rule-signature Rules
  [ground   #:kind material   #:arity 0]
  [fusion-R #:kind logical    #:arity 2]
  [wrap     #:kind structural #:arity 1])

(define-occurrence bS
  #:type ground #:instance S #:premises [] #:conclusion HS)
(define-occurrence bT
  #:type ground #:instance T #:premises [] #:conclusion HT)
(define-occurrence m
  #:type fusion-R #:instance (list S T)
  #:premises [HS HT] #:conclusion HST)
(define-occurrence i
  #:type wrap #:instance U #:premises [HST] #:conclusion HU)

(define-calculus K
  #:language L
  #:rules Rules
  #:occurrences [bS bT m i])

(define-context r
  #:in K
  #:root HU
  (i (m _ bT)))
(define-proof s-proof
  #:in K
  #:root HS
  bS)

;; A filling point contains one complete proof per canonical telescope entry.
(define point (make-filling-point r (list s-proof)))
(define filled (evaluate-filling-point point))
(define extracted (extract-filling-point r filled))

;; Backward refinement by the nullary ground solves the same open obligation.
(define refined (backward-refine r '(1 1) bS))

(unless (and (filling-point? extracted)
             (equal? filled refined))
  (error 'dsl-open-context "filling/extraction or refinement did not round trip"))

(write-analysis (analyze-context r))
