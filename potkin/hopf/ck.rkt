#lang racket/base

(require racket/list
         "../algebra/formal-sum.rkt"
         "../kernel/check.rkt"
         "../kernel/cut.rkt")

(provide connected-coproduct
         forest-coproduct
         coproduct
         forest-counit
         counit
         tensor-counit-left
         tensor-counit-right
         forest-degree
         formal-sum-support-degrees
         formal-sum-homogeneous-degree
         hopf-error?
         hopf-error-code
         hopf-error-message
         hopf-error-operation
         hopf-error-expected
         hopf-error-actual
         hopf-error-details)

(struct hopf-error
  (code message operation expected actual details)
  #:transparent)

(define (make-hopf-error code message operation
                         #:expected [expected #f]
                         #:actual [actual #f]
                         #:details [details (hash)])
  (hopf-error code message operation expected actual details))

(define (hopf-layer-error? value)
  (or (hopf-error? value) (algebra-error? value)))

(define (rank-error sum expected operation)
  (and (not (= (formal-sum-rank sum) expected))
       (make-hopf-error
        'rank-mismatch
        "the Hopf operation received the wrong formal tensor rank"
        operation
        #:expected expected
        #:actual (formal-sum-rank sum))))

(define (connected-coproduct term)
  (unless (checked-node? term)
    (raise-argument-error 'connected-coproduct "checked-node?" term))
  (define calculus (checked-node-calculus term))
  (define empty-forest (empty-proof-forest calculus))
  (define source-forest (make-proof-forest calculus (list term)))

  ;; This endpoint is not an admissible CK root cut.  The empty witness below
  ;; separately contributes 1 tensor t exactly once.
  (define endpoint
    (pure-tensor calculus (vector source-forest empty-forest)))
  (if (algebra-error? endpoint)
      endpoint
      (let loop ([witnesses
                  (for/list
                      ([witness (in-admissible-cut-witnesses term)])
                    witness)]
                 [result endpoint])
        (cond
          [(null? witnesses) result]
          [else
           (define witness (car witnesses))
           (when (cut-error? witness)
             (error
              'connected-coproduct
              "the admissible-cut enumerator produced an invalid witness: ~e"
              witness))
           (define remainder-forest
             (make-proof-forest
              calculus
              (list (cut-witness-remainder witness))))
           (define witness-term
             (pure-tensor
              calculus
              (vector (cut-witness-forest witness)
                      remainder-forest)))
           (cond
             [(algebra-error? witness-term) witness-term]
             [else
              (define next (formal-sum-add result witness-term))
              (if (algebra-error? next)
                  next
                  (loop (cdr witnesses) next))])]))))

(define (forest-coproduct forest)
  (unless (proof-forest? forest)
    (raise-argument-error 'forest-coproduct "proof-forest?" forest))
  (define calculus (proof-forest-calculus forest))
  (let loop ([factors (proof-forest-factors forest)]
             [result (tensor-unit calculus 2)])
    (cond
      [(hopf-layer-error? result) result]
      [(null? factors) result]
      [else
       ;; proof-forest-factors expands the multiset, so equal occurrences are
       ;; multiplied independently and generate the required coefficients.
       (define factor-coproduct (connected-coproduct (car factors)))
       (cond
         [(hopf-layer-error? factor-coproduct) factor-coproduct]
         [else
          (define next
            (formal-sum-multiply result factor-coproduct))
          (if (hopf-layer-error? next)
              next
              (loop (cdr factors) next))])])))

(define (coproduct sum)
  (unless (formal-sum? sum)
    (raise-argument-error 'coproduct "formal-sum?" sum))
  (define wrong-rank (rank-error sum 1 'coproduct))
  (cond
    [wrong-rank wrong-rank]
    [else
     (define calculus (formal-sum-calculus sum))
     (let loop ([terms (formal-sum-terms sum)]
                [result (tensor-zero calculus 2)])
       (cond
         [(hopf-layer-error? result) result]
         [(null? terms) result]
         [else
          (define term (car terms))
          (define basis-coproduct
            (forest-coproduct (vector-ref (car term) 0)))
          (cond
            [(hopf-layer-error? basis-coproduct) basis-coproduct]
            [else
             (define scaled
               (formal-sum-scale (cdr term) basis-coproduct))
             (cond
               [(hopf-layer-error? scaled) scaled]
               [else
                (define next (formal-sum-add result scaled))
                (if (hopf-layer-error? next)
                    next
                    (loop (cdr terms) next))])])]))]))

(define (forest-counit forest)
  (unless (proof-forest? forest)
    (raise-argument-error 'forest-counit "proof-forest?" forest))
  (if (proof-forest-empty? forest) 1 0))

(define (counit sum)
  (unless (formal-sum? sum)
    (raise-argument-error 'counit "formal-sum?" sum))
  (define wrong-rank (rank-error sum 1 'counit))
  (if wrong-rank
      wrong-rank
      (forest-coefficient
       sum
       (empty-proof-forest (formal-sum-calculus sum)))))

(define (tensor-counit-left sum)
  (unless (formal-sum? sum)
    (raise-argument-error 'tensor-counit-left "formal-sum?" sum))
  (define wrong-rank (rank-error sum 2 'tensor-counit-left))
  (if wrong-rank
      wrong-rank
      (formal-sum-contract-coordinate sum 1 forest-counit)))

(define (tensor-counit-right sum)
  (unless (formal-sum? sum)
    (raise-argument-error 'tensor-counit-right "formal-sum?" sum))
  (define wrong-rank (rank-error sum 2 'tensor-counit-right))
  (if wrong-rank
      wrong-rank
      (formal-sum-contract-coordinate sum 2 forest-counit)))

(define (forest-degree forest)
  (unless (proof-forest? forest)
    (raise-argument-error 'forest-degree "proof-forest?" forest))
  (for/sum ([factor (in-list (proof-forest-factors forest))])
    (derivation-vertex-count factor)))

(define (support-degrees/internal sum)
  (remove-duplicates
   (sort
    (for/list ([key (in-list (formal-sum-support sum))])
      (forest-degree (vector-ref key 0)))
    <)))

(define (formal-sum-support-degrees sum)
  (unless (formal-sum? sum)
    (raise-argument-error
     'formal-sum-support-degrees "formal-sum?" sum))
  (define wrong-rank
    (rank-error sum 1 'formal-sum-support-degrees))
  (if wrong-rank wrong-rank (support-degrees/internal sum)))

(define (formal-sum-homogeneous-degree sum)
  (unless (formal-sum? sum)
    (raise-argument-error
     'formal-sum-homogeneous-degree "formal-sum?" sum))
  (define wrong-rank
    (rank-error sum 1 'formal-sum-homogeneous-degree))
  (cond
    [wrong-rank wrong-rank]
    [else
     (define degrees (support-degrees/internal sum))
     (cond
       [(null? degrees)
        (make-hopf-error
         'empty-support
         "formal zero has no homogeneous support degree"
         'formal-sum-homogeneous-degree
         #:expected 'nonempty-support
         #:actual '())]
       [(null? (cdr degrees)) (car degrees)]
       [else
        (make-hopf-error
         'nonhomogeneous
         "the formal sum has support in more than one degree"
         'formal-sum-homogeneous-degree
         #:expected 'single-degree
         #:actual degrees
         #:details (hash 'degrees degrees))])]))
