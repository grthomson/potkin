#lang racket/base

;; A modest reproducible workload for repeated native material queries.
;;
;; comb(0)   = stop
;; comb(n+1) = neutral2(mat2(g,g), comb(n))
;;
;; If A_n counts the choices available when comb(n) occurs below a parent,
;; then A_0 = 2 and A_(n+1) = 1 + 5*A_n.  At depth four the checked source
;; therefore has A_4 - 1 = 1,405 ordinary CK witnesses.  Because neutral2 and
;; stop are not designated material, its material witness count is 5^4 = 625.
;; Timings below are supporting runtime observations only; the correctness
;; argument is the general witness-partition argument in material-stock.rkt.

(require racket/pretty
         "../potkin/main.rkt")

(provide run-material-stock-workload)

(define (elapsed-milliseconds thunk)
  (define started (current-inexact-milliseconds))
  (define value (thunk))
  (values value (- (current-inexact-milliseconds) started)))

(define (run-material-stock-workload #:depth [depth 4]
                                     #:repetitions [repetitions 5])
  (unless (exact-nonnegative-integer? depth)
    (raise-argument-error
     'run-material-stock-workload "exact-nonnegative-integer?" depth))
  (unless (exact-positive-integer? repetitions)
    (raise-argument-error
     'run-material-stock-workload "exact-positive-integer?" repetitions))

  (define S (singleton-hypersequent '() '(S)))
  (define g-occ
    (make-concrete-occurrence
     'material-workload-g '() S #:kind 'material #:instance 'g))
  (define mat2-occ
    (make-concrete-occurrence
     'material-workload-mat2 (list S S) S
     #:kind 'material #:instance 'mat2))
  (define neutral2-occ
    (make-concrete-occurrence
     'material-workload-neutral2 (list S S) S
     #:kind 'logical #:instance 'neutral2))
  (define stop-occ
    (make-concrete-occurrence
     'material-workload-stop '() S #:kind 'logical #:instance 'stop))
  (define calculus
    (make-equipped-calculus
     (list g-occ mat2-occ neutral2-occ stop-occ)))
  (define profile
    (make-material-profile calculus (list g-occ mat2-occ)))

  (define g-raw (raw-app 'material-workload-g))
  (define module-raw
    (raw-app 'material-workload-mat2 g-raw g-raw))
  (define (comb-raw n)
    (if (zero? n)
        (raw-app 'material-workload-stop)
        (raw-app
         'material-workload-neutral2
         module-raw
         (comb-raw (sub1 n)))))
  (define source
    (validate-candidate calculus (comb-raw depth) #:expected S))
  (define g-proof
    (validate-candidate calculus g-raw #:expected S))
  (define requested-forest
    (make-proof-forest calculus (list g-proof)))

  (define-values (index preparation-ms)
    (elapsed-milliseconds
     (lambda () (prepare-material-stock-index source profile))))

  (define-values (direct-values direct-query-ms)
    (elapsed-milliseconds
     (lambda ()
       (for/list ([iteration (in-range repetitions)])
         (direct-material-coefficient source profile requested-forest)))))
  (define-values (indexed-values indexed-query-ms)
    (elapsed-milliseconds
     (lambda ()
       (for/list ([iteration (in-range repetitions)])
         (indexed-material-coefficient index requested-forest)))))

  (unless (and (equal? direct-values indexed-values)
               (andmap (lambda (value) (= value (* 2 depth)))
                       indexed-values))
    (error
     'run-material-stock-workload
     "direct and indexed workload results diverged: direct ~e; indexed ~e"
     direct-values
     indexed-values))

  (hash
   'depth depth
   'vertices (derivation-vertex-count source)
   'native-witnesses
   (material-stock-index-ordinary-witness-count index)
   'material-witnesses
   (material-stock-index-material-witness-count index)
   'query 'singleton-g-left-forest-coefficient
   'coefficient (car indexed-values)
   'repetitions repetitions
   'preparation-ms preparation-ms
   'repeated-direct-query-ms direct-query-ms
   'repeated-indexed-query-ms indexed-query-ms))

(module+ main
  (pretty-write (run-material-stock-workload)))
