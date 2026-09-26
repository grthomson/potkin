#lang racket/base

(require rackunit
         racket/list
         "../potkin/main.rkt"
         "../potkin/analysis.rkt")

;; One small exact registry; constructor names carry no analytical meaning.
(define S (singleton-hypersequent '() '(S)))
(define empty-incidence (make-component-incidence '() S '()))

(define filler-occ
  (make-concrete-occurrence
   'macro-filler '() S
   #:instance 'filler
   #:incidence empty-incidence))
(define c-occ
  (make-concrete-occurrence
   'macro-c '() S
   #:instance 'closed
   #:incidence empty-incidence))
(define d-occ
  (make-concrete-occurrence
   'macro-d (list S S) S
   #:instance 'binary
   #:incidence 'opaque-macro-incidence))
(define s-occ
  (make-concrete-occurrence
   'macro-s (list S) S
   #:instance 'unary-inner
   #:incidence 'opaque-macro-incidence))
(define unary-r-occ
  (make-concrete-occurrence
   'macro-r1 (list S) S
   #:instance 'unary-outer
   #:incidence 'opaque-macro-incidence))
(define binary-r-occ
  (make-concrete-occurrence
   'macro-r2 (list S S) S
   #:instance 'binary-outer
   #:incidence 'opaque-macro-incidence))

(define calculus
  (make-equipped-calculus
   (list filler-occ c-occ d-occ s-occ unary-r-occ binary-r-occ)))

(define (checked raw)
  (define result (validate-candidate calculus raw #:expected S))
  (check-false (validation-error? result))
  result)

(define filler (checked (raw-app 'macro-filler)))
(define pass-context (identity-context calculus S))
(define drop-context (checked (raw-app 'macro-c)))
(define dup2-context
  (checked (raw-app 'macro-d raw-hole raw-hole)))
(define chain-context
  (checked (raw-app 'macro-r1 (raw-app 'macro-s raw-hole))))
(define branch-context
  (checked (raw-app 'macro-r2 raw-hole (raw-app 'macro-c))))

(define x-port (make-macro-port 'x S))
(define unused-x-port (make-macro-port 'x S #:allow-zero-use? #t))

(define filler-summary
  (compile-macro-summary calculus filler '() '()))
(define pass-summary
  (compile-macro-summary
   calculus pass-context (list x-port) (list (cons '() 'x))))
(define drop-summary
  (compile-macro-summary
   calculus drop-context (list unused-x-port) '()))
(define dup2-summary
  (compile-macro-summary
   calculus dup2-context (list x-port)
   (list (cons '(1) 'x) (cons '(2) 'x))))
(define chain-summary
  (compile-macro-summary
   calculus chain-context (list x-port)
   (list (cons '(1 1) 'x))))
(define branch-summary
  (compile-macro-summary
   calculus branch-context (list x-port)
   (list (cons '(1) 'x))))

;; Unused ports are legal only when declared explicitly as zero-use.
(check-exn
 exn:fail:contract?
 (lambda ()
   (compile-macro-summary calculus drop-context (list x-port) '())))

(define fixtures
  (list (list 'Pass pass-summary 1 0 '(1 1))
        (list 'Drop drop-summary 0 1 '(1 1))
        (list 'Dup2 dup2-summary 2 1 '(1 3 1))
        (list 'Chain chain-summary 1 2 '(1 3))
        (list 'Branch branch-summary 1 2 '(1 3 1))))

(for ([fixture (in-list fixtures)])
  (define summary (second fixture))
  (check-equal? (macro-summary-use-count summary 'x) (third fixture))
  (check-equal? (macro-summary-fixed-vertex-count summary) (fourth fixture)))

(check-equal? (macro-summary-occurrence-addresses dup2-summary 'x)
              '((1) (2)))
(check-not-equal?
 (first (macro-summary-occurrence-addresses dup2-summary 'x))
 (second (macro-summary-occurrence-addresses dup2-summary 'x)))

;; Coefficient vectors are low-degree first.  The compact evaluator never
;; enumerates cuts; the native oracle below does, independently and only on
;; these five tiny fixtures.
(define (trim-polynomial coefficients)
  (let loop ([reversed (reverse coefficients)])
    (cond
      [(null? reversed) '(0)]
      [(and (zero? (car reversed)) (pair? (cdr reversed)))
       (loop (cdr reversed))]
      [else (reverse reversed)])))

(define (coefficient coefficients degree)
  (if (< degree (length coefficients))
      (list-ref coefficients degree)
      0))

(define (poly+ left right)
  (trim-polynomial
   (for/list ([degree (in-range (max (length left) (length right)))])
     (+ (coefficient left degree) (coefficient right degree)))))

(define (poly* left right)
  (define result
    (make-vector (sub1 (+ (length left) (length right))) 0))
  (for* ([left-degree (in-range (length left))]
         [right-degree (in-range (length right))])
    (define degree (+ left-degree right-degree))
    (vector-set!
     result degree
     (+ (vector-ref result degree)
        (* (list-ref left left-degree)
           (list-ref right right-degree)))))
  (trim-polynomial (vector->list result)))

(define z '(0 1))

(define (circuit-polynomial summary hole-polynomial)
  (evaluate-macro-summary
   summary
   #:add poly+
   #:multiply poly*
   #:zero '(0)
   #:one '(1)
   #:hole (lambda (_input) hole-polynomial)
   #:endpoint (lambda (_endpoint) z)))

(define filler-polynomial (circuit-polynomial filler-summary '(0)))
(check-equal? filler-polynomial '(1 1))

;; The same fold can count the exact native frontier without interpreting
;; rule names: multiplication is reinterpreted as addition and its unit as 0.
(define (circuit-frontier-count summary)
  (evaluate-macro-summary
   summary
   #:add +
   #:multiply +
   #:zero 0
   #:one 0
   #:hole (lambda (_input) 1)
   #:endpoint (lambda (_endpoint) 0)))

(for ([fixture (in-list fixtures)])
  (check-equal? (circuit-frontier-count (second fixture))
                (third fixture)))

(define (fresh-filler)
  (checked (raw-app 'macro-filler)))

(define (fill-with-filler summary)
  (define filled
    (complete-fill
     (macro-summary-context summary)
     (for/list ([_input (in-list (macro-summary-inputs summary))])
       (fresh-filler))))
  (check-false (context-error? filled))
  (check-true (complete-proof? filled))
  filled)

(define (native-frontier-polynomial proof)
  (define coefficients
    (make-vector (add1 (derivation-vertex-count proof)) 0))
  ;; Ordinary native witnesses include the empty witness.
  (for ([witness (in-admissible-cut-witnesses proof)])
    (define degree (length (cut-witness-addresses witness)))
    (vector-set! coefficients degree
                 (add1 (vector-ref coefficients degree))))
  ;; The whole connected endpoint is added once and is not a root cut.
  (vector-set! coefficients 1 (add1 (vector-ref coefficients 1)))
  (trim-polynomial (vector->list coefficients)))

(for ([fixture (in-list fixtures)])
  (define name (first fixture))
  (define summary (second fixture))
  (define expected (fifth fixture))
  (define compact (circuit-polynomial summary filler-polynomial))
  (define native (native-frontier-polynomial (fill-with-filler summary)))
  (define message (symbol->string name))
  (check-equal? compact expected message)
  (check-equal? native expected message)
  (check-equal? compact native message))

;; Equal diagonal summaries do not determine CK frontier structure.
(check-equal? (macro-summary-use-count chain-summary 'x)
              (macro-summary-use-count branch-summary 'x))
(check-equal? (macro-summary-fixed-vertex-count chain-summary)
              (macro-summary-fixed-vertex-count branch-summary))
(check-not-equal? (circuit-polynomial chain-summary filler-polynomial)
                  (circuit-polynomial branch-summary filler-polynomial))

;; Native typed substitution rechecks one independent Dup2 copy.  Its two
;; equal-looking inputs acquire flattened prefixed identities.
(define chain-after-dup2
  (macro-summary-substitute chain-summary 'x dup2-summary))
(check-equal? (macro-summary-use-count chain-after-dup2 'x) 2)
(check-equal? (macro-summary-fixed-vertex-count chain-after-dup2) 3)
(check-equal? (macro-summary-occurrence-addresses chain-after-dup2 'x)
              '((1 1 1) (1 1 2)))
(define independently-filled-chain-after-dup2
  (checked
   (raw-app 'macro-r1
            (raw-app 'macro-s
                     (raw-app 'macro-d
                              (raw-app 'macro-filler)
                              (raw-app 'macro-filler))))))
(define chain-after-dup2-polynomial
  (circuit-polynomial chain-after-dup2 filler-polynomial))
(check-equal? chain-after-dup2-polynomial '(1 5 1))
(check-equal?
 (fill-with-filler chain-after-dup2)
 independently-filled-chain-after-dup2)
(check-equal?
 (native-frontier-polynomial independently-filled-chain-after-dup2)
 chain-after-dup2-polynomial)

;; Root remains forbidden to the native CK witness API; the evaluator's
;; whole endpoint above is separate metadata.
(define root-attempt
  (make-cut-witness independently-filled-chain-after-dup2
                    (list root-address)))
(check-true (cut-error? root-attempt))
(check-equal? (cut-error-code root-attempt) 'root-cut)

;; Structural equality of registry contents does not weaken exact snapshot
;; provenance.
(define foreign-calculus
  (make-equipped-calculus
   (list filler-occ c-occ d-occ s-occ unary-r-occ binary-r-occ)))
(define foreign-pass (identity-context foreign-calculus S))
(check-exn
 exn:fail:contract?
 (lambda ()
   (compile-macro-summary
    calculus foreign-pass (list x-port) (list (cons '() 'x)))))

(printf
 "MACRO SUMMARY FIXTURE: Pass 1+z; Drop 1+z; Dup2 1+3z+z^2; Chain 1+3z; Branch 1+3z+z^2; Chain-o-Dup2 1+5z+z^2.\n")
