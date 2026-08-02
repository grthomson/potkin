#lang racket/base

(require "../kernel/boundary.rkt"
         "signature.rkt"
         (for-syntax racket/base
                     syntax/parse))

(provide formula-context-in-signature?
         sequent-in-signature?
         hypersequent-in-signature?
         seq
         hseq)

(define (formula-context-in-signature? signature context)
  (unless (formula-signature? signature)
    (raise-argument-error
     'formula-context-in-signature? "formula-signature?" signature))
  (and (formula-context? context)
       (for/and ([formula (in-list (formula-context->list context))])
         (formula-in-signature? signature formula))))

(define (sequent-in-signature? signature value)
  (unless (formula-signature? signature)
    (raise-argument-error
     'sequent-in-signature? "formula-signature?" signature))
  (and (sequent? value)
       (formula-context-in-signature? signature (sequent-left value))
       (formula-context-in-signature? signature (sequent-right value))))

(define (hypersequent-in-signature? signature value)
  (unless (formula-signature? signature)
    (raise-argument-error
     'hypersequent-in-signature? "formula-signature?" signature))
  (and (hypersequent? value)
       (for/and ([component (in-list (hypersequent-sequents value))])
         (sequent-in-signature? signature component))))

(define (make-signature-sequent signature left right)
  (unless (formula-signature? signature)
    (raise-argument-error 'seq "formula-signature?" signature))
  (for ([formula (in-list (append left right))])
    (unless (formula-in-signature? signature formula)
      (raise-arguments-error
       'seq
       "formula is outside the declared signature"
       "formula" formula)))
  (make-sequent left right))

(define (make-signature-hypersequent signature components)
  (unless (formula-signature? signature)
    (raise-argument-error 'hseq "formula-signature?" signature))
  (unless (pair? components)
    (raise-arguments-error
     'hseq "a hypersequent must have at least one component"))
  (for ([component (in-list components)] [position (in-naturals 1)])
    (unless (sequent-in-signature? signature component)
      (raise-arguments-error
       'hseq
       "component is not a sequent over the declared signature"
       "position" position
       "component" component)))
  (make-hypersequent components))

(define-syntax (seq stx)
  (syntax-parse stx
    [(_ signature:expr
        [left-formula:expr ...]
        (~datum =>)
        [right-formula:expr ...])
     #'(make-signature-sequent
        signature
        (list left-formula ...)
        (list right-formula ...))]))

(define-syntax (hseq stx)
  (syntax-parse stx
    [(_ signature:expr component:expr ...+)
     #'(make-signature-hypersequent
        signature
        (list component ...))]
    [(_ signature:expr)
     (raise-syntax-error
      #f "a hypersequent needs at least one sequent component" stx)]))
