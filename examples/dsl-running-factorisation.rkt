#lang racket/base

(require potkin)

(define-formula-signature L
  #:atoms [S T U]
  [fusion 2])

(define HS
  (hseq L
    (seq L [] => [S])))
(define HT
  (hseq L
    (seq L [] => [T])))
(define HST
  (hseq L
    (seq L [] => [(fusion S T)])))
(define HU
  (hseq L
    (seq L [] => [U])))

(define-rule-signature Rules
  [ground   #:kind material   #:arity 0]
  [fusion-R #:kind logical    #:arity 2]
  [wrap     #:kind structural #:arity 1])

(define-occurrence bS
  #:type ground
  #:instance S
  #:premises []
  #:conclusion HS)
(define-occurrence bT
  #:type ground
  #:instance T
  #:premises []
  #:conclusion HT)
(define-occurrence m
  #:type fusion-R
  #:instance (list S T)
  #:premises [HS HT]
  #:conclusion HST)
(define-occurrence i
  #:type wrap
  #:instance U
  #:premises [HST]
  #:conclusion HU)

(define-calculus K
  #:language L
  #:rules Rules
  #:occurrences [bS bT m i])

(define-proof t
  #:in K
  #:root HU
  (i (m bS bT)))

(write-analysis (analyze-derivation t))
