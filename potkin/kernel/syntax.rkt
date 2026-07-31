#lang racket/base

(require racket/match)

(provide raw-hole
         raw-hole?
         raw-app
         raw-app?
         raw-app-occurrence-id
         raw-app-children
         raw-candidate?)

;; This is deliberately plain s-expression data: Redex and the ordinary
;; checker consume the exact same candidate, without parallel ASTs.
(define raw-hole '(puncture))

(define (raw-hole? candidate)
  (equal? candidate raw-hole))

(define (raw-app occurrence-id . children)
  (unless (symbol? occurrence-id)
    (raise-argument-error 'raw-app "symbol?" occurrence-id))
  (unless (andmap raw-candidate? children)
    (raise-argument-error 'raw-app "raw-candidate? children" children))
  (list* 'app occurrence-id children))

(define (raw-app? candidate)
  (match candidate
    [(list 'app (? symbol?) children ...)
     (andmap raw-candidate? children)]
    [_ #f]))

(define (raw-app-occurrence-id candidate)
  (unless (raw-app? candidate)
    (raise-argument-error 'raw-app-occurrence-id "raw-app?" candidate))
  (cadr candidate))

(define (raw-app-children candidate)
  (unless (raw-app? candidate)
    (raise-argument-error 'raw-app-children "raw-app?" candidate))
  (cddr candidate))

(define (raw-candidate? candidate)
  (or (raw-hole? candidate)
      (raw-app? candidate)))
