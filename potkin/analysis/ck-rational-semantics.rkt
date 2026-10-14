#lang racket/base

;; Exact finite Q-vector-space semantics.  The DAG below is analysis IR, not
;; a proof carrier.  All occurrence data comes from the native checked registry.
;; Tensor bases are lexicographic (last coordinate fastest); Hom(A,B) has
;; matrix-unit basis (a,b), with index a*dim(B)+b.  Empty antecedents have dim 1.
(require racket/list racket/match racket/vector
         "../kernel/boundary.rkt" "../kernel/calculus.rkt"
         "../kernel/check.rkt" "../kernel/context.rkt"
         "../kernel/mixed-schema.rkt")

(provide make-qmatrix qmatrix? qmatrix-rows qmatrix-cols qmatrix-data qmatrix-ref
         qmatrix-identity qmatrix-multiply qmatrix-tensor qmatrix-apply
         make-rational-model rational-model? rational-model-calculus
         rational-model-atom-dimensions rational-model-material-maps rational-model-version rational-model-extension?
         formula-dimension boundary-shape
         make-semantic-budget semantic-budget? semantic-budget-max-entries
         semantic-budget-max-arithmetic semantic-budget-max-nodes
         exn:fail:semantic-budget? exn:fail:semantic-budget-reason
         semantic-summary? semantic-summary-model semantic-summary-proof
         semantic-summary-boundary semantic-summary-matrix semantic-summary-stats
         rational-hole? rational-hole-address rational-hole-boundary rational-hole-rows rational-hole-cols
         compiled-rational-context? compiled-rational-context-model
         compiled-rational-context-source compiled-rational-context-root
         compiled-rational-context-dag compiled-rational-context-holes compiled-rational-context-stats
         semantic-evaluation? semantic-evaluation-matrix semantic-evaluation-stats
         behavior-result? behavior-result-status behavior-result-old-observed
         behavior-result-new-observed behavior-result-witness behavior-result-reason behavior-result-stats
         semantic-counterinput? semantic-counterinput-input-index semantic-counterinput-observed-index
         semantic-counterinput-old-value semantic-counterinput-new-value semantic-counterinput-verified?
         admit-rational-proof compile-rational-context evaluate-rational-context
         compare-rational-tuples verify-semantic-counterinput)

(struct qmatrix (rows cols data) #:transparent #:constructor-name qmatrix/internal)
(struct rational-model (calculus atom-dimensions material-maps version)
  #:constructor-name rational-model/internal)
(struct semantic-budget (max-entries max-arithmetic max-nodes)
  #:transparent #:constructor-name semantic-budget/internal)
(struct exn:fail:semantic-budget exn:fail (reason) #:transparent)
(struct semantic-summary (model proof boundary matrix stats) #:transparent
  #:constructor-name semantic-summary/internal)
(struct rational-hole (address boundary rows cols) #:transparent
  #:constructor-name rational-hole/internal)
(struct circuit-node (kind payload children boundary) #:transparent)
(struct compiled-rational-context (model source root dag holes stats)
  #:constructor-name compiled-rational-context/internal)
(struct semantic-evaluation (matrix stats) #:transparent
  #:constructor-name semantic-evaluation/internal)
(struct behavior-result (status old-observed new-observed witness reason stats)
  #:transparent #:constructor-name behavior-result/internal)
(struct semantic-counterinput (input-index observed-index old-value new-value verified?)
  #:transparent #:constructor-name semantic-counterinput/internal)

(define (make-semantic-budget #:max-entries [entries 1000000]
                              #:max-arithmetic [arithmetic 10000000]
                              #:max-nodes [nodes 100000]
                              #:operation-limit [operations #f]
                              #:dimension-limit [dimensions #f])
  (define e (or dimensions entries))
  (define a (or operations arithmetic))
  (unless (and (exact-nonnegative-integer? e) (exact-nonnegative-integer? a)
               (exact-nonnegative-integer? nodes))
    (raise-arguments-error 'make-semantic-budget "limits must be nonnegative exact integers"))
  (semantic-budget/internal e a nodes))
(define default-budget (make-semantic-budget))
(define current-work (make-parameter #f))
(define current-budget (make-parameter default-budget))
(define stat-keys '(additions multiplications arithmetic matrix-entries inspected-input-entries proof-nodes
                             context-nodes hole-bindings material-admissions material-lookups
                             maximum-coefficient-bits))
(define (fresh-work) (make-hasheq (map (lambda (k) (cons k 0)) stat-keys)))
(define (work-snapshot) (make-immutable-hasheq (hash->list (current-work))))
(define (limit! reason)
  (raise (exn:fail:semantic-budget (format "exact semantics budget exhausted: ~a" reason)
                                 (current-continuation-marks) reason)))
(define (charge! key [amount 1])
  (when (current-work)
    (hash-update! (current-work) key (lambda (n) (+ n amount)) 0)
    (define budget (current-budget))
    (when (and (eq? key 'matrix-entries)
               (> (hash-ref (current-work) key) (semantic-budget-max-entries budget)))
      (limit! 'matrix-entries))
    (when (and (memq key '(proof-nodes context-nodes))
               (> (+ (hash-ref (current-work) 'proof-nodes)
                     (hash-ref (current-work) 'context-nodes))
                  (semantic-budget-max-nodes budget)))
      (limit! 'nodes))
    (when (memq key '(additions multiplications))
      (hash-update! (current-work) 'arithmetic (lambda (n) (+ n amount)) 0)
      (when (> (hash-ref (current-work) 'arithmetic)
               (semantic-budget-max-arithmetic budget)) (limit! 'arithmetic)))))
(define (record-value value)
  (when (current-work)
    (define bits (max (integer-length (abs (numerator value)))
                      (integer-length (denominator value))))
    (hash-update! (current-work) 'maximum-coefficient-bits (lambda (n) (max n bits)) 0))
  value)
(define (q+ a b) (charge! 'additions) (record-value (+ a b)))
(define (q* a b) (charge! 'multiplications) (record-value (* a b)))
(define (with-work budget thunk)
  (unless (semantic-budget? budget) (raise-argument-error 'exact-semantics "semantic-budget?" budget))
  (parameterize ([current-work (fresh-work)] [current-budget budget]) (thunk)))

(define (make-qmatrix rows)
  (unless (and (list? rows) (pair? rows) (andmap list? rows) (pair? (car rows))
               (andmap (lambda (r) (= (length r) (length (car rows)))) rows)
               (andmap (lambda (r) (andmap (lambda (q) (and (rational? q) (exact? q))) r)) rows))
    (raise-argument-error 'make-qmatrix "nonempty rectangular lists of exact rational entries" rows))
  (qmatrix/internal (length rows) (length (car rows))
                    (vector->immutable-vector
                     (list->vector (map (lambda (r) (vector->immutable-vector (list->vector r))) rows)))))
(define (qmatrix-ref m r c) (vector-ref (vector-ref (qmatrix-data m) r) c))
(define (inspect-matrix! matrix)
  ;; Count input inspection alongside allocation in the finite entry budget.
  ;; Ground maps and hole parameters can contain large rationals even when no
  ;; arithmetic operation is required by the context.
  (define count (* (qmatrix-rows matrix) (qmatrix-cols matrix)))
  (charge! 'matrix-entries count)
  (charge! 'inspected-input-entries count)
  (for* ([r (in-range (qmatrix-rows matrix))] [c (in-range (qmatrix-cols matrix))])
    (record-value (qmatrix-ref matrix r c)))
  matrix)
(define (build-matrix rows cols f)
  (charge! 'matrix-entries (* rows cols))
  (qmatrix/internal rows cols
    (vector->immutable-vector
     (for/vector ([r (in-range rows)])
       (vector->immutable-vector
        (for/vector ([c (in-range cols)]) (record-value (f r c))))))))
(define (qmatrix-identity n)
  (unless (exact-positive-integer? n) (raise-argument-error 'qmatrix-identity "exact-positive-integer?" n))
  (build-matrix n n (lambda (r c) (if (= r c) 1 0))))
(define (qmatrix-multiply a b)
  (unless (and (qmatrix? a) (qmatrix? b) (= (qmatrix-cols a) (qmatrix-rows b)))
    (raise-arguments-error 'qmatrix-multiply "incompatible exact matrices" "left" a "right" b))
  (build-matrix (qmatrix-rows a) (qmatrix-cols b)
    (lambda (r c) (for/fold ([sum 0]) ([i (in-range (qmatrix-cols a))])
                    (q+ sum (q* (qmatrix-ref a r i) (qmatrix-ref b i c)))))))
(define (qmatrix-tensor a b)
  (build-matrix (* (qmatrix-rows a) (qmatrix-rows b)) (* (qmatrix-cols a) (qmatrix-cols b))
    (lambda (r c) (q* (qmatrix-ref a (quotient r (qmatrix-rows b)) (quotient c (qmatrix-cols b)))
                     (qmatrix-ref b (remainder r (qmatrix-rows b)) (remainder c (qmatrix-cols b)))))))
(define (qmatrix-apply m input)
  (define xs (if (vector? input) (vector->list input) input))
  (unless (and (list? xs) (= (length xs) (qmatrix-cols m))
               (andmap (lambda (q) (and (rational? q) (exact? q))) xs))
    (raise-argument-error 'qmatrix-apply "exact rational vector of input dimension" input))
  (for/list ([r (in-range (qmatrix-rows m))])
    (for/fold ([sum 0]) ([x (in-list xs)] [c (in-naturals)])
      (q+ sum (q* (qmatrix-ref m r c) x)))))

(define (formula-dimension model formula)
  (match formula
    [(? symbol? atom)
     (hash-ref (rational-model-atom-dimensions model) atom
               (lambda () (raise-arguments-error 'formula-dimension "atom has no dimension" "atom" atom)))]
    [(list (or 'tensor 'implies) a b)
     (* (formula-dimension model a) (formula-dimension model b))]
    [_ (raise-argument-error 'formula-dimension "mixed-formula?" formula)]))
(define (product xs) (for/fold ([n 1]) ([x (in-list xs)]) (* n x)))
(define (left-dimensions model boundary)
  (map (lambda (f) (formula-dimension model f)) (mixed-boundary-left boundary)))
(define (boundary-shape model boundary)
  (list (formula-dimension model (mixed-boundary-right boundary))
        (product (left-dimensions model boundary))))
(define (shape-check who matrix shape)
  (unless (and (qmatrix? matrix) (= (qmatrix-rows matrix) (first shape))
               (= (qmatrix-cols matrix) (second shape)))
    (raise-arguments-error who "matrix differs from exact typed interface" "required shape" shape "matrix" matrix)))
(define (make-rational-model calculus dimensions maps #:version [version 'q-v1])
  (unless (mixed-schema-calculus? calculus)
    (raise-argument-error 'make-rational-model "exact mixed-schema calculus" calculus))
  (unless (and (hash? dimensions) (for/and ([(atom dim) (in-hash dimensions)])
                                   (and (symbol? atom) (exact-positive-integer? dim))))
    (raise-argument-error 'make-rational-model "atom to positive dimension hash" dimensions))
  (unless (and (hash? maps) (formula-datum? version))
    (raise-arguments-error 'make-rational-model "maps must be a hash and version immutable symbolic data"))
  (define model (rational-model/internal calculus (make-immutable-hash (hash->list dimensions))
                                         (make-immutable-hash (hash->list maps)) version))
  (define materials (mixed-schema-material-occurrences calculus))
  (unless (= (length materials) (hash-count (rational-model-material-maps model)))
    (raise-arguments-error 'make-rational-model "assignment must contain precisely the ambient material IDs"))
  (for ([occ (in-list materials)])
    (define id (concrete-occurrence-id occ))
    (shape-check 'make-rational-model
                 (hash-ref (rational-model-material-maps model) id
                           (lambda () (error 'make-rational-model "missing material ID: ~a" id)))
                 (boundary-shape model (concrete-occurrence-conclusion occ))))
  model)
(define (rational-model-extension? old new)
  ;; An explicit semantic assignment inclusion, not a native provenance cast.
  ;; Every checked proof/summary still belongs to its own exact registry.
  (and (rational-model? old) (rational-model? new)
       (equal? (rational-model-atom-dimensions old) (rational-model-atom-dimensions new))
       (for/and ([occ (in-list (mixed-schema-material-occurrences (rational-model-calculus old)))])
         (equal? occ (calculus-lookup (rational-model-calculus new) (concrete-occurrence-id occ))))
       (for/and ([(id matrix) (in-hash (rational-model-material-maps old))])
         (equal? matrix (hash-ref (rational-model-material-maps new) id #f)))))

;; Decode and encode coherent ordered tensor coordinates without identifying
;; duplicate formula occurrences.  Physical slot/index routes, never names,
;; supply every premise coordinate.
(define (decode index dimensions)
  (let loop ([ds (reverse dimensions)] [n index] [xs '()])
    (if (null? ds) xs (loop (cdr ds) (quotient n (car ds)) (cons (remainder n (car ds)) xs)))))
(define (encode xs dimensions)
  (for/fold ([n 0]) ([x (in-list xs)] [d (in-list dimensions)]) (+ (* n d) x)))
(define (interpret-rule model occurrence matrices)
  (define K (rational-model-calculus model))
  (define data (mixed-occurrence-data K occurrence))
  (define family (hash-ref data 'family))
  (define boundary (concrete-occurrence-conclusion occurrence))
  (cond
    [(eq? family 'material)
     (charge! 'material-lookups)
     (inspect-matrix! (hash-ref (rational-model-material-maps model) (concrete-occurrence-id occurrence)))]
    [else
     (define premises (vector->list (concrete-occurrence-premises occurrence)))
     (define ds (left-dimensions model boundary))
     (define shape (boundary-shape model boundary))
     (define routes (hash-ref data 'routing))
     (define (column slot external active)
       (define pd (left-dimensions model (list-ref premises (sub1 slot))))
       (encode
        (for/list ([i (in-range 1 (add1 (length pd)))])
          (define route (findf (lambda (r) (and (= (first r) slot) (eq? (second r) 'left)
                                               (= (third r) i))) routes))
          (match (drop route 3)
            [(list 'left out '()) (list-ref external (sub1 out))]
            [(list 'left out (list branch))
             (case branch
               [(left right)
                (define formula (list-ref (mixed-boundary-left boundary) (sub1 out)))
                (define right-dim (formula-dimension model (third formula)))
                (if (eq? branch 'left) (quotient (list-ref external (sub1 out)) right-dim)
                    (remainder (list-ref external (sub1 out)) right-dim))]
               [(codomain) active]
               [else (error 'interpret-rule "unsupported antecedent path")])]
            [(list (or 'cut 'right) _ _) active]
            [_ (error 'interpret-rule "unsupported exact occurrence route")])) pd))
     (define (entry slot row external [active #f])
       (qmatrix-ref (list-ref matrices (sub1 slot)) row (column slot external active)))
     (build-matrix (first shape) (second shape)
       (lambda (row col)
         (define external (decode col ds))
         (case family
           [(tensorR)
            (define right-dim (formula-dimension model (hash-ref data 'B)))
            (q* (entry 1 (quotient row right-dim) external)
                (entry 2 (remainder row right-dim) external))]
           [(tensorL) (entry 1 row external)]
           [(impliesR)
            (define b (formula-dimension model (hash-ref data 'B)))
            (entry 1 (remainder row b) external (quotient row b))]
           [(impliesL)
            (define b (formula-dimension model (hash-ref data 'B)))
            (define hom (list-ref external (sub1 (hash-ref data 'principal-output-index))))
            (q* (entry 1 (quotient hom b) external)
                (entry 2 row external (remainder hom b)))]
           [(cut+ cut-)
            (define producer (if (eq? family 'cut+) 1 2))
            (define consumer (- 3 producer))
            (define n (formula-dimension model (hash-ref data 'formula)))
            (for/fold ([sum 0]) ([a (in-range n)])
              (q+ sum (q* (entry producer a external) (entry consumer row external a))))]
           [else (error 'interpret-rule "unadmitted logical family")])))]))

(define (check-native who model term #:complete? [complete? #f])
  (unless (and (rational-model? model) (checked-term? term)
               (eq? (checked-term-calculus term) (rational-model-calculus model))
               (or (not complete?) (complete-proof? term)))
    (raise-arguments-error who "native term must have exact model provenance and required completeness")))
(define (evaluate-native model proof)
  ;; Independent traversal: deliberately no context compiler, DAG, summaries,
  ;; or cached provider matrices are used for the counterinput's filled proofs.
  (charge! 'proof-nodes)
  (when (null? (checked-node-children proof)) (charge! 'material-admissions))
  (interpret-rule model (checked-node-occurrence proof)
                  (map (lambda (child) (evaluate-native model child)) (checked-node-children proof))))
(define (admit-rational-proof model proof #:budget [budget default-budget])
  (check-native 'admit-rational-proof model proof #:complete? #t)
  (with-work budget
    (lambda ()
      (define matrix (evaluate-native model proof))
      (semantic-summary/internal model proof (derivation-root-boundary proof) matrix (work-snapshot)))))

(define (compile-rational-context model source #:budget [budget default-budget])
  (check-native 'compile-rational-context model source)
  (with-work budget
    (lambda ()
      (define intern (make-hash))
      (define closed-cache (make-hasheq))
      (define nodes '())
      (define holes '())
      (define next-hole-index 0)
      (define (walk term address)
        (define boundary (derivation-root-boundary term))
        (cond
          [(checked-hole? term)
           (define shape (boundary-shape model boundary))
           (define hole (rational-hole/internal address boundary (first shape) (second shape)))
           (define node (circuit-node 'hole next-hole-index '() boundary))
           (set! next-hole-index (add1 next-hole-index))
           (set! holes (cons hole holes))
           (set! nodes (cons node nodes))
           (charge! 'context-nodes)
           node]
          [(hash-ref closed-cache term #f) => values]
          [else
           (define occurrence (checked-node-occurrence term))
           (define holes-before next-hole-index)
           (define children
             (for/list ([child (in-list (checked-node-children term))] [slot (in-naturals 1)])
               (walk child (append address (list slot)))))
           (define key (list occurrence children))
           (define node (hash-ref! intern key
             (lambda ()
               (charge! 'context-nodes)
               (define node (circuit-node 'rule occurrence children boundary))
               (set! nodes (cons node nodes))
               node)))
           (when (= holes-before next-hole-index) (hash-set! closed-cache term node))
           node]))
      (define root (walk source '()))
      (compiled-rational-context/internal model source root
                                         (vector->immutable-vector (list->vector (reverse nodes)))
                                         (reverse holes) (work-snapshot)))))
(define (evaluate-context/internal compiled providers)
  (unless (and (list? providers) (= (length providers) (length (compiled-rational-context-holes compiled))))
    (raise-argument-error 'evaluate-rational-context "one ordered provider per physical hole" providers))
  (define model (compiled-rational-context-model compiled))
  (define matrices
    (for/vector ([provider (in-list providers)] [hole (in-list (compiled-rational-context-holes compiled))])
      (charge! 'hole-bindings)
      (define matrix
        (cond [(semantic-summary? provider)
               (unless (and (rational-model-extension? model (semantic-summary-model provider))
                            (equal? (semantic-summary-boundary provider) (rational-hole-boundary hole)))
                 (error 'evaluate-rational-context "stale model or wrong exact hole interface"))
               (semantic-summary-matrix provider)]
              [(qmatrix? provider) provider]
              [else (raise-argument-error 'evaluate-rational-context "admitted summary or typed matrix" provider)]))
      (shape-check 'evaluate-rational-context matrix (list (rational-hole-rows hole) (rational-hole-cols hole)))
      (inspect-matrix! matrix)))
  (define values (make-hasheq))
  (for ([node (in-vector (compiled-rational-context-dag compiled))])
    (charge! 'context-nodes)
    (hash-set! values node
      (if (eq? (circuit-node-kind node) 'hole)
          (vector-ref matrices (circuit-node-payload node))
          (interpret-rule model (circuit-node-payload node)
                          (map (lambda (child) (hash-ref values child)) (circuit-node-children node))))))
  (hash-ref values (compiled-rational-context-root compiled)))
(define (evaluate-rational-context compiled providers #:budget [budget default-budget])
  (unless (compiled-rational-context? compiled)
    (raise-argument-error 'evaluate-rational-context "compiled-rational-context?" compiled))
  (with-work budget
    (lambda () (define result (evaluate-context/internal compiled providers))
      (semantic-evaluation/internal result (work-snapshot)))))

(define (observe matrix observation)
  (cond [(not observation) matrix]
        [(qmatrix? observation)
         (unless (= (qmatrix-cols observation) (qmatrix-rows matrix))
           (error 'compare-rational-tuples "linear observation has wrong output interface"))
         (qmatrix-multiply observation matrix)]
        [else (error 'compare-rational-tuples "unsupported nonlinear or untyped observation")]))
(define (verify-semantic-counterinput model old-proof new-proof observation witness
                                      #:new-model [new-model model]
                                      #:budget [budget default-budget])
  (check-native 'verify-semantic-counterinput model old-proof #:complete? #t)
  (check-native 'verify-semantic-counterinput new-model new-proof #:complete? #t)
  (unless (rational-model-extension? model new-model)
    (error 'verify-semantic-counterinput "new model changes an old ambient assignment"))
  (unless (equal? (derivation-root-boundary old-proof) (derivation-root-boundary new-proof))
    (error 'verify-semantic-counterinput "different external interfaces"))
  (with-work budget
    (lambda ()
      (define old (observe (evaluate-native model old-proof) observation))
      (define new (observe (evaluate-native new-model new-proof) observation))
      (define input (semantic-counterinput-input-index witness))
      (define output (semantic-counterinput-observed-index witness))
      (and (exact-nonnegative-integer? input) (< input (qmatrix-cols old))
           (exact-nonnegative-integer? output) (< output (qmatrix-rows old))
           (= (qmatrix-ref old output input) (semantic-counterinput-old-value witness))
           (= (qmatrix-ref new output input) (semantic-counterinput-new-value witness))
           (not (= (semantic-counterinput-old-value witness) (semantic-counterinput-new-value witness)))))))
(define (compare-rational-tuples compiled old-providers new-providers
                                 #:observation [observation #f]
                                 #:old-proof [old-proof #f] #:new-proof [new-proof #f]
                                 #:new-model [declared-new-model #f]
                                 #:budget [budget default-budget])
  (with-work budget
    (lambda ()
      (with-handlers
          ([exn:fail:semantic-budget?
            (lambda (e) (behavior-result/internal 'UNKNOWN #f #f #f
                                                 (exn:fail:semantic-budget-reason e) (work-snapshot)))])
        (cond
          [(not (or (not observation) (qmatrix? observation)))
           (behavior-result/internal 'UNKNOWN #f #f #f 'unsupported-observation (work-snapshot))]
          [else
           (define old-full (evaluate-context/internal compiled old-providers))
           (define new-full (evaluate-context/internal compiled new-providers))
           (define model (compiled-rational-context-model compiled))
           (define new-model
             (or declared-new-model
                 (for/first ([p (in-list new-providers)] #:when (semantic-summary? p))
                   (semantic-summary-model p)) model))
           (unless (rational-model-extension? model new-model)
             (error 'compare-rational-tuples "new interpretation changes an old ambient assignment"))
           ;; If native artifacts are supplied, bind them even on the EQUAL
           ;; branch.  With sealed summaries, structural filling suffices and
           ;; unchanged provider pointers remain opaque.  Raw matrix tuples
           ;; have no native proof link and require an independent tree check.
           (define (bind-proof! proof providers proof-model expected)
             (when proof
               (check-native 'compare-rational-tuples proof-model proof #:complete? #t)
               (unless (equal? (derivation-root-boundary proof)
                               (derivation-root-boundary (compiled-rational-context-source compiled)))
                 (error 'compare-rational-tuples "filled proof has wrong external interface"))
               (cond
                 [(andmap semantic-summary? providers)
                  (define remaining providers)
                  (define (matches? context filled)
                    (charge! 'context-nodes)
                    (cond
                      [(checked-hole? context)
                       (define summary (car remaining))
                       (set! remaining (cdr remaining))
                       (and (eq? (semantic-summary-model summary) proof-model)
                            (or (eq? filled (semantic-summary-proof summary))
                                (equal? filled (semantic-summary-proof summary))))]
                      [else
                       (and (checked-node? filled)
                            (equal? (checked-node-occurrence context) (checked-node-occurrence filled))
                            (= (length (checked-node-children context)) (length (checked-node-children filled)))
                            (for/and ([a (in-list (checked-node-children context))]
                                      [b (in-list (checked-node-children filled))]) (matches? a b)))]))
                  (unless (matches? (compiled-rational-context-source compiled) proof)
                    (error 'compare-rational-tuples "native proof is not this context filled with these providers"))]
                 [else
                  (unless (equal? (evaluate-native proof-model proof) expected)
                    (error 'compare-rational-tuples "native proof map differs from supplied matrix tuple"))])))
           (bind-proof! old-proof old-providers model old-full)
           (bind-proof! new-proof new-providers new-model new-full)
           (define old (observe old-full observation))
           (define new (observe new-full observation))
           (define differing
             (for*/first ([r (in-range (qmatrix-rows old))] [c (in-range (qmatrix-cols old))]
                          #:unless (= (qmatrix-ref old r c) (qmatrix-ref new r c))) (cons r c)))
           (cond
             [(not differing)
              (behavior-result/internal 'EQUAL old new #f 'all-external-vectors-in-declared-model (work-snapshot))]
             [else
              (define (proof-or-fill proposed providers)
                (or proposed
                    (and (andmap semantic-summary? providers)
                         (complete-fill (compiled-rational-context-source compiled)
                                        (map semantic-summary-proof providers)))))
              (define op (proof-or-fill old-proof old-providers))
              (define np (proof-or-fill new-proof new-providers))
              (define r (car differing))
              (define c (cdr differing))
              (cond
                [(not (and (checked-node? op) (checked-node? np)))
                 (behavior-result/internal 'UNKNOWN old new #f 'independent-filled-proofs-required (work-snapshot))]
                [else
                 (check-native 'compare-rational-tuples model op #:complete? #t)
                 (check-native 'compare-rational-tuples new-model np #:complete? #t)
                 ;; Evaluate the native filled trees anew, not the DAG or
                 ;; cached summaries; equality of complete maps also binds
                 ;; the offered proof artifacts to the compared operation.
                 (define native-old (evaluate-native model op))
                 (define native-new (evaluate-native new-model np))
                 (unless (and (equal? (derivation-root-boundary op)
                                      (derivation-root-boundary (compiled-rational-context-source compiled)))
                              (equal? (derivation-root-boundary np) (derivation-root-boundary op))
                              (equal? native-old old-full) (equal? native-new new-full))
                   (error 'compare-rational-tuples "filled-proof artifacts do not match compared context maps"))
                 (define input (for/list ([i (in-range (qmatrix-cols old))]) (if (= i c) 1 0)))
                 (define ov (list-ref (qmatrix-apply (or observation (qmatrix-identity (qmatrix-rows native-old)))
                                                   (qmatrix-apply native-old input)) r))
                 (define nv (list-ref (qmatrix-apply (or observation (qmatrix-identity (qmatrix-rows native-new)))
                                                   (qmatrix-apply native-new input)) r))
                 (unless (and (= ov (qmatrix-ref old r c)) (= nv (qmatrix-ref new r c)) (not (= ov nv)))
                   (error 'compare-rational-tuples "counterinput failed independent evaluation"))
                 (behavior-result/internal 'DIFFERENT old new
                   (semantic-counterinput/internal c r ov nv #t) 'verified-rational-basis-counterinput
                   (work-snapshot))])])])))))
