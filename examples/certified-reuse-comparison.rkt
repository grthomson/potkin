#lang racket/base

(require racket/list racket/format "../potkin/main.rkt" "certified-modular-reuse.rkt")
(provide run-certified-reuse-comparison)

(define (timed thunk)
  (define start (current-inexact-milliseconds))
  (define answer (thunk))
  (values answer (- (current-inexact-milliseconds) start)))

(define (prepare f #:cap [cap 256])
  (prepare-reuse (reuse-fixture-source f) (reuse-fixture-frontier f)
                 (reuse-fixture-model f) #:profile (reuse-fixture-profile f)
                 #:history (reuse-fixture-history f) #:state-limit cap
                 #:require '(behavior boundary replay)))

;; Native fixture sizes, not an exhaustive degree or assertion target. A
;; repeated tuple is a warm no-change update: unchanged summaries survive.
(define (run-certified-reuse-comparison)
  (define structured
    (for/list ([m '(2 3 4 6)])
      (define-values (f admission-ms) (timed (lambda () (make-tensor-reuse-fixture m))))
      (define-values (p preparation-ms) (timed (lambda () (prepare f))))
      (define-values (u update-ms)
        (timed (lambda () (apply-reuse-update p (reuse-fixture-replacements f)))))
      (define-values (v verification-ms) (timed (lambda () (verify-reuse-update p u))))
      (unless (and (reuse-update-accepted? u) (reuse-verification-valid? v))
        (error 'run-certified-reuse-comparison "structured workflow gate failed at m=~a: ~e" m v))
      (hash 'family 'tensor-bundle 'm m 'native-admission-ms admission-ms
            'preparation-ms preparation-ms 'update-ms update-ms 'verification-ms verification-ms
            'preparation-stats (reuse-preparation-stats p) 'plan (reuse-update-plan u)
            'certificate
            (let* ([e (reuse-contract-evidence (reuse-update-boundary u))]
                   [c (and (ck-protection-evidence? e) (ck-protection-evidence-certificate e))])
              (if (ck-structured-certificate? c)
                  (hash 'kind 'strict-family 'vertices (derivation-vertex-count (reuse-update-filled u))
                        'blocks (length (remove-duplicates (vector->list (ck-structured-certificate-partition c))))
                        'history-cells (length (ck-structured-certificate-history c)))
                  (hash 'kind 'generic)))
            'semantic-comparison
            (compare-native-reuse (reuse-fixture-model f) (reuse-fixture-source f)
                                  (reuse-fixture-frontier f)
                                  (make-list 3 (reuse-fixture-replacements f))
                                  #:read-contract (reuse-update-boundary u)))))
  (define joint (make-curried-reuse-fixture))
  (define joint-rows
    (compare-native-reuse (reuse-fixture-model joint) (reuse-fixture-source joint)
                          (reuse-fixture-frontier joint)
                          (make-list 3 (reuse-fixture-replacements joint))))
  (define generic
    (for/list ([j '(1 2)])
      (define f (make-tensor-reuse-fixture 2 #:dependent-position j))
      (define-values (r ms)
        (timed (lambda () (certify-native-ck-boundary
                           (reuse-fixture-source f) (reuse-fixture-frontier f)
                           #:state-limit 32 #:generation-limit 2000 #:time-limit-ms 1000))))
      (define c (ck-boundary-result-certificate r))
      (hash 'family 'generic-context 'position j 'milliseconds ms
            'status (ck-boundary-result-status r)
            'states (if c (length (ck-boundary-certificate-states c)) 0)
            'edges (if c (length (ck-boundary-certificate-edges c)) 0)
            'state-cap 32 'generation-cap 2000)))
  (define f (make-tensor-reuse-fixture))
  (define stock (mixed-schema-material-occurrences (checked-term-calculus (reuse-fixture-source f))))
  (define old-K (make-mixed-schema-calculus stock #:sector 'tensor))
  (define old (validate-candidate old-K (checked-term->raw (reuse-fixture-source f))))
  (define comparison
    (certify-tensor-mixed-comparison old (list (list (car (reuse-fixture-profile f))) (reuse-fixture-profile f))
                                    (rational-model-material-maps (reuse-fixture-model f))
                                    #:target (checked-term-calculus (reuse-fixture-source f))))
  (define square
    (and (ck-comparison-certificate? comparison)
         (verify-tensor-mixed-comparison comparison)))
  (unless (and square (ck-closure-report-valid? square))
    (error 'run-certified-reuse-comparison "actual tensor/profile comparison failed: ~e" comparison))
  (hash 'structured structured 'joint joint-rows 'generic generic 'comparison-square square
        'claim 'same-semantic-engine-no-intrinsic-speedup
        'protection 'same-certified-read-contract-common-input
        'timing 'single-run-wall-clock-not-a-statistical-speedup-study))

(define (stat s key) (hash-ref s key 0))
(define (print-rows label rows)
  (for ([r (in-list rows)])
    (define s (reuse-comparison-row-stats r))
    (printf "~a ~a/~a ~a ms; arithmetic ~a, nodes ~a, entries ~a, coefficient bits ~a; retained/admitted ~a/~a; ~a\n"
            label (reuse-comparison-row-mode r) (reuse-comparison-row-phase r)
            (~ms (reuse-comparison-row-milliseconds r)) (stat s 'arithmetic)
            (+ (stat s 'proof-nodes) (stat s 'context-nodes)) (stat s 'matrix-entries)
            (stat s 'maximum-coefficient-bits) (reuse-comparison-row-retained-components r)
            (reuse-comparison-row-admitted-components r) (reuse-comparison-row-result r))))
(define (~ms n) (real->decimal-string n 3))

(module+ main
  (define applications (run-certified-reuse-examples))
  (for ([(name value) (in-hash applications)])
    (when (reuse-update? value)
      (printf "workflow ~a accepted=~a contracts=~s independently-verified=~a\n"
              name (reuse-update-accepted? value)
              (for/hash ([(key c) (in-hash (reuse-update-contracts value))])
                (values key (reuse-contract-status c)))
              (reuse-verification-valid? (verify-reuse-update (reuse-update-preparation value) value)))))
  (define rejected (hash-ref applications 'uncompensated))
  (define counterinput
    (behavior-result-witness (reuse-contract-evidence (reuse-update-behavior rejected))))
  (printf "counterinput: external basis column ~a, observed coordinate ~a, old/new ~a/~a, native-verified=~a\n"
          (semantic-counterinput-input-index counterinput) (semantic-counterinput-observed-index counterinput)
          (semantic-counterinput-old-value counterinput) (semantic-counterinput-new-value counterinput)
          (semantic-counterinput-verified? counterinput))
  (define joint (hash-ref applications 'joint))
  (define cut (reuse-preparation-frontier (reuse-update-preparation joint)))
  (printf "inspectable native cut: addresses ~s, ordered detached IDs ~s, remainder holes ~s, refill=~a\n"
          (cut-witness-addresses cut)
          (map (lambda (d) (concrete-occurrence-id (checked-node-occurrence (detached-entry-term d))))
               (cut-witness-detached cut))
          (puncture-addresses (cut-witness-remainder cut)) (cut-witness-reconstructs? cut))
  (printf "inverse exposure: ~s\n"
          (hash-ref (reuse-contract-details (reuse-update-boundary (hash-ref applications 'bidirectional)))
                    'exposure-region (hash)))
  (define report (run-certified-reuse-comparison))
  (for ([r (in-list (hash-ref report 'structured))])
    (printf "tensor m=~a admission/preparation/update/independent-verification ms ~a/~a/~a/~a; certificate ~s\n"
            (hash-ref r 'm) (~ms (hash-ref r 'native-admission-ms)) (~ms (hash-ref r 'preparation-ms))
            (~ms (hash-ref r 'update-ms)) (~ms (hash-ref r 'verification-ms)) (hash-ref r 'certificate))
    (printf "  preparation phases ~s; update phases ~s\n"
            (hash-ref (hash-ref r 'preparation-stats) 'phase-ms (hash))
            (hash-ref (hash-ref r 'plan) 'phase-ms (hash)))
    (print-rows (format "m=~a" (hash-ref r 'm)) (hash-ref r 'semantic-comparison)))
  (print-rows "dim2 joint" (hash-ref report 'joint))
  (for ([g (in-list (hash-ref report 'generic))]) (printf "generic ~s\n" g))
  (printf "tensor/profile square: ~a; ~s\n" (ck-closure-report-status (hash-ref report 'comparison-square))
          (ck-closure-report-details (hash-ref report 'comparison-square)))
  (displayln "The warm engines are deliberately identical; protection, replay and fidelity costs are additional, not a CK speedup."))
