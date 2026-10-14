#lang racket/base

;; A deliberately competent comparison: the zipper/DAG cache receives the
;; same checked frontier, exact model, observer, and shared context compiler.
;; It does not claim an all-history read certificate of its own. Such evidence
;; is a common input, not a cheaper or weaker protection contract.
(require racket/list
         "../kernel/check.rkt" "../kernel/context.rkt" "../kernel/cut.rkt"
         "ck-rational-semantics.rkt"
         (only-in "certified-modular-reuse.rkt" opaque-fill))

(provide typed-zipper-cache? prepare-typed-zipper-cache
         typed-zipper-cache-source typed-zipper-cache-frontier
         typed-zipper-cache-compiled typed-zipper-cache-summaries
         typed-zipper-cache-read-contract
         (struct-out typed-zipper-update) apply-typed-zipper-update
         (struct-out reuse-comparison-row) compare-native-reuse)

(struct typed-zipper-cache
  (model source frontier observation compiled summaries providers read-contract)
  #:transparent #:constructor-name make-typed-zipper-cache/internal)
(struct typed-zipper-update (filled summaries behavior reused admitted stats)
  #:transparent)
(struct reuse-comparison-row
  (mode phase milliseconds stats retained-components admitted-components result)
  #:transparent)

(define (sum-stats stats)
  (for/fold ([total (hash)]) ([s (in-list stats)])
    (for/fold ([out total]) ([(key value) (in-hash s)] #:when (number? value))
      (hash-update out key
                   (lambda (old) (if (eq? key 'maximum-coefficient-bits)
                                     (max old value) (+ old value))) 0))))

(define (checked-frontier! who source witness model)
  (unless (and (checked-node? source) (derivation-complete? source)
               (cut-witness? witness) (eq? source (cut-witness-source witness))
               (cut-witness-reconstructs? witness)
               (checked-term-has-exact-calculus?
                source (rational-model-calculus model)))
    (raise-arguments-error who "exact checked source/frontier/model required"
                           "source" source "frontier" witness)))

(define (prepare-typed-zipper-cache model source witness
                                   #:observation [observation #f]
                                   #:read-contract [read-contract #f])
  (checked-frontier! 'prepare-typed-zipper-cache source witness model)
  (define providers (map detached-entry-term (cut-witness-detached witness)))
  (define summaries (map (lambda (p) (admit-rational-proof model p)) providers))
  (define compiled (compile-rational-context model (cut-witness-remainder witness)))
  (make-typed-zipper-cache/internal model source witness observation compiled
                                  summaries providers read-contract))

(define (apply-typed-zipper-update cache replacements)
  (unless (typed-zipper-cache? cache)
    (raise-argument-error 'apply-typed-zipper-update "typed-zipper-cache?" cache))
  (unless (and (list? replacements)
               (= (length replacements) (length (typed-zipper-cache-providers cache))))
    (raise-argument-error 'apply-typed-zipper-update "ordered complete provider tuple" replacements))
  (define model (typed-zipper-cache-model cache))
  ;; Native sealed assembly enforces exact calculus and whole boundary.
  (define filling-start (current-inexact-milliseconds))
  (define filled
    (opaque-fill (cut-witness-remainder (typed-zipper-cache-frontier cache)) replacements))
  (unless (and (checked-node? filled) (derivation-complete? filled))
    (raise-arguments-error 'apply-typed-zipper-update "native filling rejected"
                           "result" filled))
  (define filling-ms (- (current-inexact-milliseconds) filling-start))
  (define reused 0)
  (define admissions '())
  (define admission-start (current-inexact-milliseconds))
  (define summaries
    (for/list ([new (in-list replacements)]
               [old (in-list (typed-zipper-cache-providers cache))]
               [summary (in-list (typed-zipper-cache-summaries cache))])
      (if (eq? new old)
          (begin (set! reused (add1 reused)) summary)
          (let ([s (admit-rational-proof model new)])
            (set! admissions (cons (semantic-summary-stats s) admissions)) s))))
  (define admission-ms (- (current-inexact-milliseconds) admission-start))
  (define joint-start (current-inexact-milliseconds))
  (define behavior
    (compare-rational-tuples
     (typed-zipper-cache-compiled cache)
     (typed-zipper-cache-summaries cache) summaries
     #:observation (typed-zipper-cache-observation cache)
     #:old-proof (typed-zipper-cache-source cache) #:new-proof filled))
  (typed-zipper-update filled summaries behavior reused
                       (- (length replacements) reused)
                       (hash-set*
                        (sum-stats (cons (behavior-result-stats behavior) admissions))
                        'admission (sum-stats admissions)
                        'joint (behavior-result-stats behavior)
                        'phase-milliseconds
                        (hash 'native-filling filling-ms 'provider-admission admission-ms
                              'joint (- (current-inexact-milliseconds) joint-start)))))

(define (timed thunk)
  (define start (current-inexact-milliseconds))
  (define answer (thunk))
  (values answer (- (current-inexact-milliseconds) start)))

(define (cold-joint-query model source filled observation)
  ;; Same all-input behavioral question as the warm engines, not merely an
  ;; evaluation of the new proof. Both native bodies are reevaluated afresh.
  (define old (admit-rational-proof model source))
  (define new (admit-rational-proof model filled))
  (define a (semantic-summary-matrix old))
  (define b (semantic-summary-matrix new))
  (define old-observed (if observation (qmatrix-multiply observation a) a))
  (define new-observed (if observation (qmatrix-multiply observation b) b))
  (define mismatch
    (for*/first ([r (in-range (qmatrix-rows old-observed))]
                 [c (in-range (qmatrix-cols old-observed))]
                 #:unless (= (qmatrix-ref old-observed r c) (qmatrix-ref new-observed r c)))
      (cons r c)))
  (when mismatch
    (define input
      (for/list ([i (in-range (qmatrix-cols a))]) (if (= i (cdr mismatch)) 1 0)))
    (unless (not (= (list-ref (qmatrix-apply old-observed input) (car mismatch))
                    (list-ref (qmatrix-apply new-observed input) (car mismatch))))
      (error 'cold-joint-query "direct native basis check failed")))
  (define output-entries (* 2 (qmatrix-rows old-observed) (qmatrix-cols old-observed)))
  (define observer-products (if observation (* output-entries (qmatrix-rows a)) 0))
  (define products (+ observer-products (if mismatch output-entries 0)))
  (define maximum-bits
    (for*/fold ([bits 0]) ([m (in-list (list old-observed new-observed))]
                           [r (in-range (qmatrix-rows m))] [c (in-range (qmatrix-cols m))])
      (define v (qmatrix-ref m r c))
      (max bits (integer-length (abs (numerator v))) (integer-length (denominator v)))))
  (define observation-stats
    (hash 'multiplications products 'additions products 'arithmetic (* 2 products)
          'matrix-entries (if observation output-entries 0)
          'maximum-coefficient-bits maximum-bits))
  (values (if mismatch 'DIFFERENT 'EQUAL) b old-observed new-observed
          (hash-set (sum-stats (list (semantic-summary-stats old) (semantic-summary-stats new)
                                    observation-stats))
                    'coefficient-metric
                    (if observation 'native-arithmetic-peak-and-observed-output
                        'native-arithmetic-peak))))

;; This comparator reports semantic costs only. Protection, replay, and full
;; provenance are reported separately by the integrated example. Both warm
;; entries deliberately use the *same* admitted DAG implementation. A faster
;; cache caused by withholding summaries from the baseline is not evidence.
;; Updates are measured against the same original tuple (not cumulative).
(define (compare-native-reuse model source witness updates
                              #:observation [observation #f]
                              #:read-contract [read-contract #f])
  (checked-frontier! 'compare-native-reuse source witness model)
  (define-values (cache prep-ms)
    (timed (lambda () (prepare-typed-zipper-cache model source witness
                                                #:observation observation
                                                #:read-contract read-contract))))
  (define preparation
    (reuse-comparison-row
     'common 'context-and-provider-preparation prep-ms
     (hash-set*
      (sum-stats (cons (compiled-rational-context-stats (typed-zipper-cache-compiled cache))
                       (map semantic-summary-stats (typed-zipper-cache-summaries cache))))
      'context (compiled-rational-context-stats (typed-zipper-cache-compiled cache))
      'admission (sum-stats (map semantic-summary-stats (typed-zipper-cache-summaries cache))))
     0 (length (typed-zipper-cache-providers cache)) 'ADMITTED))
  (cons
   preparation
   (append-map
    (lambda (tuple)
      (define filled (opaque-fill (cut-witness-remainder witness) tuple))
      (unless (checked-node? filled)
        (raise-arguments-error 'compare-native-reuse "native filling rejected"
                               "result" filled))
      (define-values (cold cold-ms)
        (timed (lambda ()
                 (call-with-values
                  (lambda () (cold-joint-query model source
                                               (opaque-fill (cut-witness-remainder witness) tuple)
                                               observation)) list))))
      (define-values (zip zip-ms)
        (timed (lambda () (apply-typed-zipper-update cache tuple))))
      (define-values (ck ck-ms)
        (timed (lambda () (apply-typed-zipper-update cache tuple))))
      (unless (and (eq? (first cold) (behavior-result-status (typed-zipper-update-behavior zip)))
                   (eq? (first cold) (behavior-result-status (typed-zipper-update-behavior ck)))
                   (equal? (third cold) (behavior-result-old-observed (typed-zipper-update-behavior zip)))
                   (equal? (third cold) (behavior-result-old-observed (typed-zipper-update-behavior ck)))
                   (equal? (fourth cold) (behavior-result-new-observed (typed-zipper-update-behavior zip)))
                   (equal? (behavior-result-new-observed (typed-zipper-update-behavior zip))
                           (behavior-result-new-observed (typed-zipper-update-behavior ck)))
                   (equal? (second cold)
                           (semantic-evaluation-matrix
                            (evaluate-rational-context
                             (typed-zipper-cache-compiled cache)
                             (typed-zipper-update-summaries ck)))))
        (error 'compare-native-reuse "cold and warm native semantics disagree"))
      (list
       (reuse-comparison-row 'cold 'full-native-joint-query cold-ms
                             (fifth cold) 0 (* 2 (length tuple)) (first cold))
       (reuse-comparison-row 'typed-zipper/DAG 'joint-update zip-ms
                             (typed-zipper-update-stats zip)
                             (typed-zipper-update-reused zip)
                             (typed-zipper-update-admitted zip)
                             (behavior-result-status (typed-zipper-update-behavior zip)))
       (reuse-comparison-row 'CK-shared-DAG 'joint-update ck-ms
                             (typed-zipper-update-stats ck)
                             (typed-zipper-update-reused ck)
                             (typed-zipper-update-admitted ck)
                             (behavior-result-status (typed-zipper-update-behavior ck)))))
    updates)))
