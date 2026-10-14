#lang racket/base
(require rackunit racket/list "../potkin/main.rkt" "../examples/certified-modular-reuse.rkt")

(test-case "equally informed zipper retains unchanged summaries and rejects foreign fillings"
  (define f (make-tensor-reuse-fixture))
  (define cache (prepare-typed-zipper-cache (reuse-fixture-model f) (reuse-fixture-source f)
                                          (reuse-fixture-frontier f)))
  (define u (apply-typed-zipper-update cache (reuse-fixture-replacements f)))
  (check-equal? (typed-zipper-update-reused u) 3)
  (check-equal? (typed-zipper-update-admitted u) 0)
  (check-eq? (behavior-result-status (typed-zipper-update-behavior u)) 'EQUAL)
  (define foreign (make-tensor-reuse-fixture))
  (check-exn exn:fail? (lambda () (apply-typed-zipper-update cache (reuse-fixture-replacements foreign)))))

(test-case "cold and both warm engines use equal exact models and charge changed admission"
  (define f (make-curried-reuse-fixture))
  (define rows (compare-native-reuse (reuse-fixture-model f) (reuse-fixture-source f)
                                    (reuse-fixture-frontier f) (list (reuse-fixture-replacements f))))
  (check-equal? (map reuse-comparison-row-mode rows) '(common cold typed-zipper/DAG CK-shared-DAG))
  (for ([r (in-list (drop rows 2))])
    (check-equal? (reuse-comparison-row-admitted-components r) 2)
    (check-equal? (reuse-comparison-row-retained-components r) 1)
    (check-eq? (reuse-comparison-row-result r) 'EQUAL)
    (check-true (positive? (hash-ref (hash-ref (reuse-comparison-row-stats r) 'admission) 'material-admissions))))
  (check-equal? (hash-remove (reuse-comparison-row-stats (third rows)) 'phase-milliseconds)
                (hash-remove (reuse-comparison-row-stats (fourth rows)) 'phase-milliseconds)))

(test-case "cold full recomputation asks the same rejecting joint observation question"
  (define f (make-curried-reuse-fixture))
  (define old (map detached-entry-term (cut-witness-detached (reuse-fixture-frontier f))))
  (define bad (list (first old) (second (reuse-fixture-replacements f)) (third old)))
  (define rows (compare-native-reuse (reuse-fixture-model f) (reuse-fixture-source f)
                                    (reuse-fixture-frontier f) (list bad)
                                    #:observation (make-qmatrix '((1 0)))))
  (check-equal? (map reuse-comparison-row-result (cdr rows)) '(DIFFERENT DIFFERENT DIFFERENT)))
