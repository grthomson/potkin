#lang racket/base

;; Native material/profile-relative CK core projector
;;   Pi_P = m (S_C tensor id) rho_P.
;; All values remain in POTKIN's existing forest/formal-sum carriers.  Forest
;; multiplication below is independent commutative juxtaposition; it is never
;; filling, reconstruction, repair, Mix, or Gentzen Cut.

(require "../algebra/formal-sum.rkt"
         "../hopf/antipode.rkt"
         "../kernel/cut.rkt"
         "material-hopf-selector.rkt")

(provide material-hopf-selector-relative-core)

(define (check-input who selector sum)
  (unless (material-hopf-selector? selector)
    (raise-argument-error who "material-hopf-selector?" selector))
  (unless (formal-sum? sum)
    (raise-argument-error who "formal-sum?" sum))
  (unless (= (formal-sum-rank sum) 1)
    (raise-arguments-error
     who "the relative core is defined on rank-one formal forest sums"
     "expected rank" 1
     "actual rank" (formal-sum-rank sum)))
  (unless (eq? (formal-sum-calculus sum)
               (material-hopf-selector-calculus selector))
    (raise-arguments-error
     who
     "the selector and input must carry one exact calculus snapshot"
     "selector calculus" (material-hopf-selector-calculus selector)
     "input calculus" (formal-sum-calculus sum))))

(define (assert-pure-antipode-support who selector antipode-value)
  (unless (and (formal-sum? antipode-value)
               (= (formal-sum-rank antipode-value) 1)
               (eq? (formal-sum-calculus antipode-value)
                    (material-hopf-selector-calculus selector)))
    (error who "ambient antipode returned an incompatible native carrier"))
  (for ([term (in-list (formal-sum-terms antipode-value))])
    (define forest (vector-ref (car term) 0))
    (unless (material-hopf-selector-forest-pure? selector forest)
      (error who
             "ambient antipode escaped the selected material sector: ~e"
             forest))))

(define (material-hopf-selector-relative-core selector sum)
  (define who 'material-hopf-selector-relative-core)
  (check-input who selector sum)
  (define calculus (material-hopf-selector-calculus selector))
  (define coaction (material-hopf-selector-coaction selector sum))
  (cond
    [(not (formal-sum? coaction)) coaction]
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
          (unless (and (eq? (proof-forest-calculus left) calculus)
                       (eq? (proof-forest-calculus right) calculus))
            (error who "coaction coordinate crossed calculus provenance"))
          (unless (material-hopf-selector-forest-pure? selector left)
            (error who "coaction emitted a nonmaterial left coordinate"))
          (define antipode-value (forest-antipode left))
          (cond
            [(not (formal-sum? antipode-value)) antipode-value]
            [else
             ;; Do not project this value: purity is an invariant to check,
             ;; and silently filtering it could conceal an antipode defect.
             (assert-pure-antipode-support who selector antipode-value)
             (define product
               (formal-sum-multiply antipode-value (forest-basis right)))
             (cond
               [(not (formal-sum? product)) product]
               [else
                (define scaled (formal-sum-scale coefficient product))
                (define next
                  (and (formal-sum? scaled)
                       (formal-sum-add result scaled)))
                (cond
                  [(not (formal-sum? scaled)) scaled]
                  [(not (formal-sum? next)) next]
                  [else (loop (cdr terms) next)])])])]))]))
