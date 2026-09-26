#lang racket/base

;; Exact-profile selection on POTKIN's native CK forest algebra.
;;
;; Paper-level argument.  Every native coproduct term partitions the source
;; vertex occurrences between its detached left forest and retained right
;; forest.  The vertex-local characteristic function is therefore
;; multiplicative on forest union, idempotent, and compatible with the
;; coproduct when applied to both coordinates.  Filtering only the left
;; coordinate consequently gives the stated material-sector coaction.  The
;; executable functions below instantiate that argument over Z; finite tests
;; are bounded evidence, not a mechanized proof of the universal laws.
;;
;; A selector is derived immutable metadata around the existing exact
;; material profile.  It is not a new forest, tensor, formal-sum, profile, or
;; registry carrier.

(require "../algebra/formal-sum.rkt"
         "../hopf/ck.rkt"
         "../kernel/cut.rkt"
         "material-stock.rkt")

(provide material-hopf-selector?
         material-hopf-selector-calculus
         material-hopf-selector-profile
         prepare-material-hopf-selector
         material-hopf-selector-forest-pure?
         material-hopf-selector-project-forest
         material-hopf-selector-project
         material-hopf-selector-coaction)

(struct material-hopf-selector (calculus profile)
  #:constructor-name make-material-hopf-selector/internal
  #:transparent)

(define (prepare-material-hopf-selector profile)
  (unless (material-profile? profile)
    (raise-argument-error
     'prepare-material-hopf-selector "material-profile?" profile))
  (make-material-hopf-selector/internal
   (material-profile-calculus profile) profile))

(define (check-selector who selector)
  (unless (material-hopf-selector? selector)
    (raise-argument-error who "material-hopf-selector?" selector)))

(define (check-forest-provenance who selector forest)
  (unless (proof-forest? forest)
    (raise-argument-error who "proof-forest?" forest))
  (unless (eq? (proof-forest-calculus forest)
               (material-hopf-selector-calculus selector))
    (raise-arguments-error
     who
     "the forest and selector must carry one exact calculus snapshot"
     "selector calculus" (material-hopf-selector-calculus selector)
     "forest calculus" (proof-forest-calculus forest)
     "forest" forest)))

(define (check-sum-provenance who selector sum)
  (unless (formal-sum? sum)
    (raise-argument-error who "formal-sum?" sum))
  (unless (= (formal-sum-rank sum) 1)
    (raise-arguments-error
     who "material selection is defined on rank-one formal sums"
     "expected rank" 1
     "actual rank" (formal-sum-rank sum)))
  (unless (eq? (formal-sum-calculus sum)
               (material-hopf-selector-calculus selector))
    (raise-arguments-error
     who
     "the formal sum and selector must carry one exact calculus snapshot"
     "selector calculus" (material-hopf-selector-calculus selector)
     "formal-sum calculus" (formal-sum-calculus sum))))

(define (material-hopf-selector-forest-pure? selector forest)
  (define who 'material-hopf-selector-forest-pure?)
  (check-selector who selector)
  (check-forest-provenance who selector forest)
  (define profile (material-hopf-selector-profile selector))
  ;; The empty forest contains no vertices and is therefore selected.  Every
  ;; positive factor is rescanned by the existing exact occurrence classifier;
  ;; no rule names, tags, kinds, syntax, or incidence approximations enter.
  (for/and ([factor (in-list (proof-forest-factors forest))])
    (for/and ([use (in-list (direct-material-uses factor profile))])
      (define classified (material-use-designated? use))
      (unless (boolean? classified)
        (error who
               "exact material classification was unavailable at ~e"
               (material-use-address use)))
      classified)))

(define (material-hopf-selector-project-forest selector forest)
  (define who 'material-hopf-selector-project-forest)
  (check-selector who selector)
  (check-forest-provenance who selector forest)
  (if (material-hopf-selector-forest-pure? selector forest)
      (forest-basis forest)
      (formal-zero (material-hopf-selector-calculus selector))))

(define (material-hopf-selector-project selector sum)
  (define who 'material-hopf-selector-project)
  (check-selector who selector)
  (check-sum-provenance who selector sum)
  ;; Coordinate expansion performs the coefficient-linear extension in the
  ;; native collected formal-sum carrier.  In particular it retains arbitrary
  ;; exact integer coefficients and performs collision/cancellation itself.
  (formal-sum-expand-coordinate
   sum 1 1
   (lambda (forest)
     (material-hopf-selector-project-forest selector forest))))

(define (material-hopf-selector-coaction selector sum)
  (define who 'material-hopf-selector-coaction)
  (check-selector who selector)
  (check-sum-provenance who selector sum)
  ;; This is literally (pi_P tensor id) Delta_C.  Only the first native forest
  ;; coordinate is expanded; the right remainder coordinate is untouched.
  (define delta (coproduct sum))
  (if (formal-sum? delta)
      (formal-sum-expand-coordinate
       delta 1 1
       (lambda (forest)
         (material-hopf-selector-project-forest selector forest)))
      delta))
