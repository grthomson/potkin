#lang racket/base
(require rackunit racket/list racket/vector
         "../potkin/kernel.rkt"
         "../potkin/analysis/ck-rational-semantics.rkt")

(define (H left right) (singleton-hypersequent left (list right)))
(define (material id left right)
  (make-concrete-occurrence id '() (H left right) #:kind 'material))
(define stock
  (list (material 'E '(a g) 'b) (material 'E-new '(a g) 'b)
        (material 'D '(h) 'a) (material 'D-new '(h) 'a)
        (material 'R '(b) 'c) (material 'I '(a) 'a)
        (material 'equal-E '(a a) 'b) (material 'closed '() 'a)))
(define K (make-mixed-schema-calculus stock))
(define (g id [k K]) (validate-candidate k (raw-app id)))
(define (app f children [indices '()] [order #f])
  (mixed-apply K f children #:indices indices #:order order))
(define E (make-qmatrix '((1 2 3 4) (5 6 7 8))))
(define D (make-qmatrix '((1 2) (3 4))))
(define M (make-qmatrix '((1 1) (0 1))))
(define Mi (make-qmatrix '((1 -1) (0 1))))
(define Id (qmatrix-identity 2))
(define maps
  (hash 'E E 'E-new (qmatrix-multiply E (qmatrix-tensor Mi Id))
        'D D 'D-new (qmatrix-multiply M D) 'R Id 'I Id
        'equal-E E 'closed (make-qmatrix '((1/2) (2/3)))))
(define dims (hash 'a 2 'b 2 'c 2 'g 2 'h 2))
(define model (make-rational-model K dims maps))
(define (summary p [m model]) (admit-rational-proof m p))
(define (matrix p) (semantic-summary-matrix (summary p)))
(define (principal p)
  (hash-ref (mixed-occurrence-data K (checked-node-occurrence p)) 'principal-output-index))
(define (arrow-proof e d)
  (define ar (app 'impliesR (list e) '(1)))
  (define al (app 'impliesL (list d (g 'R)) '(1)))
  (app 'cut+ (list ar al) (list (principal al))))
(define (cut-proof e d) (app 'cut- (list e d) '(1)))
(define arrow (arrow-proof (g 'E) (g 'D)))
(define ctx
  (arrow-proof (identity-context K (H '(a g) 'b))
               (identity-context K (H '(h) 'a))))
(define compiled (compile-rational-context model ctx))

(test-case "exact rational matrix interfaces and semantic unit"
  (check-equal? (qmatrix-multiply M Mi) Id)
  (check-equal? (qmatrix-apply (make-qmatrix '((1/2 1/3))) '(2 3)) '(2))
  (check-equal? (boundary-shape model (H '() 'a)) '(2 1))
  (check-equal? (matrix (g 'closed)) (hash-ref maps 'closed))
  (check-equal? (hash-ref (semantic-summary-stats (summary (g 'closed))) 'maximum-coefficient-bits) 2)
  (check-equal? (formula-dimension model '(implies a (tensor b c))) 8)
  (check-exn exn:fail? (lambda () (make-qmatrix '((1.0)))))
  (check-exn exn:fail? (lambda () (make-rational-model K (hash 'a 0) maps))))

(test-case "all six constructors agree with concrete routed contractions"
  ;; Canonical input order at the complete operation is g,h. Body inputs
  ;; have canonical order a,g; the actual stored route implements the exchange.
  (define expected (make-qmatrix '((10 14 14 20) (26 38 30 44))))
  (check-equal? (matrix arrow) expected)
  (check-equal? (matrix (cut-proof (g 'E) (g 'D))) expected)
  (check-equal? (matrix (app 'cut+ (list (g 'D) (g 'E)) '(1))) expected)
  (check-equal? (matrix (app 'tensorR (list (g 'D) (g 'I))))
                (make-qmatrix '((1 2 0 0) (0 0 1 2) (3 4 0 0) (0 0 3 4))))
  (check-equal? (matrix (app 'tensorL (list (g 'E)) '(1 2))) E)
  (check-equal? (semantic-evaluation-matrix
                 (evaluate-rational-context compiled (list (summary (g 'E)) (summary (g 'D))))) expected))

(test-case "repeated formula occurrences retain different discharge and packing coordinates"
  (check-equal? (matrix (app 'impliesR (list (g 'equal-E)) '(1)))
                (make-qmatrix '((1 2) (5 6) (3 4) (7 8))))
  (check-equal? (matrix (app 'impliesR (list (g 'equal-E)) '(2)))
                (make-qmatrix '((1 3) (5 7) (2 4) (6 8))))
  (check-equal? (matrix (app 'tensorL (list (g 'equal-E)) '(2 1)))
                (make-qmatrix '((1 3 2 4) (5 7 6 8))))
  (define two (app 'tensorR (list (g 'I) (g 'I)) '() '((2 1) (1 1))))
  (check-equal? (matrix two)
                (make-qmatrix '((1 0 0 0) (0 0 1 0) (0 1 0 0) (0 0 0 1)))))

(test-case "physical equal-interface holes remain distinct and summaries are opaque in DAG evaluation"
  (define c (app 'tensorR (list (identity-context K (H '(a) 'a))
                               (identity-context K (H '(a) 'a)))))
  (define cc (compile-rational-context model c))
  (check-equal? (map rational-hole-address (compiled-rational-context-holes cc)) '((1) (2)))
  (define evaluated (evaluate-rational-context cc (list M Mi)))
  (check-equal? (semantic-evaluation-matrix evaluated) (qmatrix-tensor M Mi))
  (check-equal? (hash-ref (semantic-evaluation-stats evaluated) 'proof-nodes) 0)
  (check-exn exn:fail? (lambda () (evaluate-rational-context cc (list (make-qmatrix '((1))) Mi)))))

(test-case "coordinated numerical replacement is joint, not providerwise"
  (check-not-equal? (hash-ref maps 'E) (hash-ref maps 'E-new))
  (check-not-equal? (hash-ref maps 'D) (hash-ref maps 'D-new))
  (define old (list (summary (g 'E)) (summary (g 'D))))
  (define new (list (summary (g 'E-new)) (summary (g 'D-new))))
  (define result (compare-rational-tuples compiled old new
                    #:old-proof arrow #:new-proof (arrow-proof (g 'E-new) (g 'D-new))))
  (check-eq? (behavior-result-status result) 'EQUAL)
  (check-equal? (hash-ref (behavior-result-stats result) 'proof-nodes) 0)
  (check-equal? (matrix (arrow-proof (g 'E-new) (g 'D-new))) (matrix arrow)))

(test-case "uncompensated replacement yields independently checked rational basis counterinput"
  (define bad (arrow-proof (g 'E) (g 'D-new)))
  (define result (compare-rational-tuples compiled
                    (list (summary (g 'E)) (summary (g 'D)))
                    (list (summary (g 'E)) (summary (g 'D-new)))
                    #:old-proof arrow #:new-proof bad))
  (check-eq? (behavior-result-status result) 'DIFFERENT)
  (check-true (semantic-counterinput-verified? (behavior-result-witness result)))
  (check-true (verify-semantic-counterinput model arrow bad #f (behavior-result-witness result)))
  (check-true (> (hash-ref (behavior-result-stats result) 'proof-nodes) 0)))

(test-case "linear observations compare complete maps, unsupported observers receive no verdict"
  (define zero-observer (make-qmatrix '((0 0))))
  (define olds (list (summary (g 'E)) (summary (g 'D))))
  (define news (list (summary (g 'E)) (summary (g 'D-new))))
  (check-eq? (behavior-result-status (compare-rational-tuples compiled olds news #:observation zero-observer)) 'EQUAL)
  (define projection (make-qmatrix '((0 1))))
  (define r (compare-rational-tuples compiled olds news #:observation projection))
  (check-eq? (behavior-result-status r) 'DIFFERENT)
  (check-equal? (semantic-counterinput-observed-index (behavior-result-witness r)) 0)
  (check-eq? (behavior-result-status (compare-rational-tuples compiled olds news #:observation values)) 'UNKNOWN))

(test-case "equal cached maps cannot license unrelated native proof artifacts"
  (define olds (list (summary (g 'E)) (summary (g 'D))))
  (check-exn exn:fail?
    (lambda () (compare-rational-tuples compiled olds olds
                  #:old-proof arrow #:new-proof (arrow-proof (g 'E) (g 'D-new)))))
  (check-exn exn:fail?
    (lambda () (compare-rational-tuples compiled (map semantic-summary-matrix olds)
                                    (map semantic-summary-matrix olds)
                  #:old-proof arrow #:new-proof (arrow-proof (g 'E) (g 'D-new))))))

(test-case "model assignments are immutable and changed old meanings are not extensions"
  (define mutable-maps (hash-copy maps))
  (define m (make-rational-model K dims mutable-maps #:version 'copy))
  (hash-set! mutable-maps 'D Id)
  (check-equal? (hash-ref (rational-model-material-maps m) 'D) D)
  (define changed (make-rational-model K dims (hash-set maps 'D Id) #:version 'changed))
  (check-false (rational-model-extension? model changed))
  (check-exn exn:fail? (lambda () (evaluate-rational-context compiled
                                    (list (summary (g 'E)) (summary (g 'D) changed))))))

(test-case "explicit ambient admission extension consumes old circuit without provenance casts"
  (define fresh (material 'fresh '(h) 'a))
  (define K2 (make-mixed-schema-calculus (append stock (list fresh))))
  (define model2 (make-rational-model K2 dims (hash-set maps 'fresh D) #:version 'extended))
  (check-true (rational-model-extension? model model2))
  (define native-context (validate-candidate K2 (checked-term->raw ctx)))
  (define E2 (g 'E K2))
  (define F2 (g 'fresh K2))
  (define filled (complete-fill native-context (list E2 F2)))
  (define result (compare-rational-tuples compiled
                   (list (summary (g 'E)) (summary (g 'D)))
                   (list (summary E2 model2) (summary F2 model2))
                   #:old-proof arrow #:new-proof filled))
  (check-eq? (behavior-result-status result) 'EQUAL)
  (check-exn exn:fail? (lambda () (admit-rational-proof model filled))))

(test-case "nested composition retains precise lexicographic hole shuffle"
  (define inner (app 'cut+ (list (identity-context K (H '(h) 'a))
                                (identity-context K (H '(a) 'a))) '(1)))
  (define outer (app 'tensorR (list (identity-context K (H '(h) 'a))
                                  (identity-context K (H '(h) 'a)))))
  (define composed (context-compose outer (list inner (identity-context K (H '(h) 'a)))))
  (define inner-eval (evaluate-rational-context (compile-rational-context model inner) (list D Id)))
  (define staged (evaluate-rational-context (compile-rational-context model outer)
                                            (list (semantic-evaluation-matrix inner-eval) D)))
  (define cc (compile-rational-context model composed))
  (check-equal? (map rational-hole-address (compiled-rational-context-holes cc)) '((1 1) (1 2) (2)))
  (check-equal? (semantic-evaluation-matrix staged)
                (semantic-evaluation-matrix (evaluate-rational-context cc (list D Id D))))
  (check-equal? (matrix (complete-fill composed (list (g 'D) (g 'I) (g 'D))))
                (semantic-evaluation-matrix staged)))

(test-case "visible exact budgets and separate admission and arithmetic counters"
  (define old (list (summary (g 'E)) (summary (g 'D))))
  (define r (compare-rational-tuples compiled old old #:budget (make-semantic-budget #:operation-limit 0)))
  (check-eq? (behavior-result-status r) 'UNKNOWN)
  (check-eq? (behavior-result-reason r) 'arithmetic)
  (check-exn exn:fail:semantic-budget?
    (lambda () (admit-rational-proof model arrow #:budget (make-semantic-budget #:dimension-limit 1))))
  (check-true (> (hash-ref (semantic-summary-stats (summary arrow)) 'maximum-coefficient-bits) 0))
  (check-equal? (hash-ref (semantic-summary-stats (summary arrow)) 'material-admissions) 3))
