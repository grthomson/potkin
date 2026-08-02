#lang racket/base

(require "../algebra/formal-sum.rkt"
         "../kernel/cut.rkt"
         "ck.rkt")

(provide forest-antipode
         antipode
         antipode-convolution-left
         antipode-convolution-right
         antipode-error?
         antipode-error-code
         antipode-error-message
         antipode-error-operation
         antipode-error-details)

(struct antipode-error (code message operation details)
  #:transparent)

(define (make-antipode-error code message operation
                             #:details [details (hash)])
  (antipode-error code message operation details))

(define (antipode-layer-error? value)
  (or (antipode-error? value)
      (hopf-error? value)
      (algebra-error? value)))

(define (rank-error sum operation)
  (and (not (= (formal-sum-rank sum) 1))
       (make-antipode-error
        'rank-mismatch
        "the antipode operation is defined only for rank-one formal sums"
        operation
        #:details (hash 'expected 1
                        'actual (formal-sum-rank sum)))))

(define (grading-violation operation forest left right coefficient)
  (define total-degree (forest-degree forest))
  (define left-degree (forest-degree left))
  (define right-degree (forest-degree right))
  (make-antipode-error
   'grading-violation
   "a reduced coproduct term did not strictly lower degree in both coordinates"
   operation
   #:details (hash 'forest forest
                   'left left
                   'right right
                   'coefficient coefficient
                   'forest-degree total-degree
                   'left-degree left-degree
                   'right-degree right-degree)))

(define (strictly-reduced-degrees? forest left right)
  (define total-degree (forest-degree forest))
  (define left-degree (forest-degree left))
  (define right-degree (forest-degree right))
  (and (< 0 left-degree total-degree)
       (< 0 right-degree total-degree)))

;; The memo is deliberately supplied by one top-level operation.  Its forest
;; keys may use structural equality safely because every entry belongs to the
;; one exact calculus passed alongside it.
(define (forest-antipode/internal forest calculus memo operation)
  (unless (eq? (proof-forest-calculus forest) calculus)
    (error
     operation
     "internal antipode recursion crossed an equipped-calculus snapshot"))
  (cond
    [(hash-ref memo forest #f) => values]
    [(proof-forest-empty? forest)
     (define result (algebra-unit calculus))
     (hash-set! memo forest result)
     result]
    [else
     (define reduced (reduced-coproduct forest))
     (cond
       [(antipode-layer-error? reduced) reduced]
       [else
        (let loop ([terms (formal-sum-terms reduced)]
                   [correction (formal-zero calculus)])
          (cond
            [(antipode-layer-error? correction) correction]
            [(null? terms)
             (define result
               (formal-sum-subtract
                (formal-sum-negate (forest-basis forest))
                correction))
             (unless (antipode-layer-error? result)
               (hash-set! memo forest result))
             result]
            [else
             (define term (car terms))
             (define key (car term))
             (define coefficient (cdr term))
             (define left (vector-ref key 0))
             (define right (vector-ref key 1))
             (cond
               [(not (strictly-reduced-degrees? forest left right))
                (grading-violation
                 operation forest left right coefficient)]
               [else
                (define left-antipode
                  (forest-antipode/internal
                   left calculus memo operation))
                (cond
                  [(antipode-layer-error? left-antipode) left-antipode]
                  [else
                   ;; This is multiplication of forest basis values only.  It
                   ;; is not filling, reconstruction, or proof assembly.
                   (define product
                     (formal-sum-multiply
                      left-antipode
                      (forest-basis right)))
                   (cond
                     [(antipode-layer-error? product) product]
                     [else
                      (define scaled
                        (formal-sum-scale coefficient product))
                      (cond
                        [(antipode-layer-error? scaled) scaled]
                        [else
                         (define next
                           (formal-sum-add correction scaled))
                         (if (antipode-layer-error? next)
                             next
                             (loop (cdr terms) next))])])])])]))])]))

(define (forest-antipode forest)
  (unless (proof-forest? forest)
    (raise-argument-error 'forest-antipode "proof-forest?" forest))
  (forest-antipode/internal
   forest
   (proof-forest-calculus forest)
   (make-hash)
   'forest-antipode))

(define (antipode/internal sum memo operation)
  (define calculus (formal-sum-calculus sum))
  (let loop ([terms (formal-sum-terms sum)]
             [result (formal-zero calculus)])
    (cond
      [(antipode-layer-error? result) result]
      [(null? terms) result]
      [else
       (define term (car terms))
       (define basis-antipode
         (forest-antipode/internal
          (vector-ref (car term) 0)
          calculus
          memo
          operation))
       (cond
         [(antipode-layer-error? basis-antipode) basis-antipode]
         [else
          (define scaled
            (formal-sum-scale (cdr term) basis-antipode))
          (cond
            [(antipode-layer-error? scaled) scaled]
            [else
             (define next (formal-sum-add result scaled))
             (if (antipode-layer-error? next)
                 next
                 (loop (cdr terms) next))])])])))

(define (antipode sum)
  (unless (formal-sum? sum)
    (raise-argument-error 'antipode "formal-sum?" sum))
  (define wrong-rank (rank-error sum 'antipode))
  (if wrong-rank
      wrong-rank
      (antipode/internal sum (make-hash) 'antipode)))

(define (convolution/internal sum left? operation)
  (define wrong-rank (rank-error sum operation))
  (cond
    [wrong-rank wrong-rank]
    [else
     (define calculus (formal-sum-calculus sum))
     (define delta (coproduct sum))
     (cond
       [(antipode-layer-error? delta) delta]
       [else
        (define memo (make-hash))
        (let loop ([terms (formal-sum-terms delta)]
                   [result (formal-zero calculus)])
          (cond
            [(antipode-layer-error? result) result]
            [(null? terms) result]
            [else
             (define term (car terms))
             (define key (car term))
             (define coefficient (cdr term))
             (define left (vector-ref key 0))
             (define right (vector-ref key 1))
             (define recursive-forest (if left? left right))
             (define plain-forest (if left? right left))
             (define recursive-value
               (forest-antipode/internal
                recursive-forest calculus memo operation))
             (cond
               [(antipode-layer-error? recursive-value) recursive-value]
               [else
                (define product
                  (if left?
                      (formal-sum-multiply
                       recursive-value
                       (forest-basis plain-forest))
                      (formal-sum-multiply
                       (forest-basis plain-forest)
                       recursive-value)))
                (cond
                  [(antipode-layer-error? product) product]
                  [else
                   (define scaled
                     (formal-sum-scale coefficient product))
                   (cond
                     [(antipode-layer-error? scaled) scaled]
                     [else
                      (define next (formal-sum-add result scaled))
                      (if (antipode-layer-error? next)
                          next
                          (loop (cdr terms) next))])])])]))])]))

(define (antipode-convolution-left sum)
  (unless (formal-sum? sum)
    (raise-argument-error
     'antipode-convolution-left "formal-sum?" sum))
  (convolution/internal sum #t 'antipode-convolution-left))

(define (antipode-convolution-right sum)
  (unless (formal-sum? sum)
    (raise-argument-error
     'antipode-convolution-right "formal-sum?" sum))
  (convolution/internal sum #f 'antipode-convolution-right))
