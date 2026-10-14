#lang racket/base

;; Four-schema, source-relative CK protection. All endpoints, vacancies,
;; provider ports and frontier witnesses below are native checked objects.
;; The additional records are evidence, not another proof syntax.
(require racket/list racket/match racket/vector
         "../kernel/address.rkt" "../kernel/boundary.rkt"
         "../kernel/calculus.rkt" "../kernel/check.rkt"
         "../kernel/context.rkt" "../kernel/cut.rkt"
         "../kernel/mixed-schema.rkt" "../hopf/ordered-ck.rkt")

(provide ck-conversion-version ck-canonicalization-version
         (struct-out ck-marked-state) (struct-out ck-schema-move)
         (struct-out ck-state-edge) (struct-out ck-boundary-certificate)
         (struct-out ck-boundary-result) (struct-out ck-closure-report)
         (struct-out ck-protected-coproduct)
         enumerate-ck-schema-moves ck-marked-successor
         mixed-proof-invariants
         certify-native-ck-boundary verify-ck-boundary-certificate
         ck-certificate-protection ck-protection-retains-cut?
         certified-ordered-coproduct)

(define ck-conversion-version '(native-positive-mixed-four-cells 1))
(define ck-canonicalization-version '(canonical-local-position-routing 1))
(struct ck-marked-state (endpoint partition origins) #:transparent)
(struct ck-schema-move
  (schema direction address target read-shell replacement-shell providers)
  #:transparent)
(struct ck-state-edge (from to move) #:transparent)
(struct ck-boundary-certificate
  (source frontier policy conversion-version canonicalization-version
          states edges terminal crossing) #:transparent)
(struct ck-boundary-result (status certificate reason details) #:transparent)
(struct ck-closure-report (valid? status reason details) #:transparent)
(struct ck-protected-coproduct (sum witnesses protection) #:transparent)
(struct work-budget (left deadline) #:mutable)
(struct exn:ck-limit exn:fail (reason) #:transparent)

(define (tick! b)
  (when (or (zero? (work-budget-left b))
            (>= (current-inexact-milliseconds) (work-budget-deadline b)))
    (raise (exn:ck-limit "CK instance generation incomplete"
                        (current-continuation-marks)
                        (if (zero? (work-budget-left b)) 'generation-limit 'time-limit))))
  (set-work-budget-left! b (sub1 (work-budget-left b))))
(define current-budget (make-parameter #f))
(define (budget-tick!) (when (current-budget) (tick! (current-budget))))
(define (family K p)
  (and (checked-node? p)
       (mixed-occurrence-family K (checked-node-occurrence p))))
(define (indices K p)
  (mixed-occurrence-indices K (checked-node-occurrence p)))
(define (order K p)
  (mixed-occurrence-order K (checked-node-occurrence p)))
(define (child p i) (list-ref (checked-node-children p) (sub1 i)))
(define (position-of token tokens)
  (for/first ([x (in-list tokens)] [i (in-naturals 1)] #:when (equal? x token)) i))
(define (at-left K p i) (list-ref (order K p) (sub1 i)))

;; Exhaust every coherent output exchange, including exchanges of equal
;; formulas at distinct physical positions. Generation is lazy and budgeted.
(define (each-app K f ps is emit)
  (for ([o (in-mixed-rule-orders K f (map derivation-root-boundary ps) #:indices is)])
    (budget-tick!)
    (define p (mixed-apply K f ps #:indices is #:order o))
    (unless (checked-node? p)
      (error 'enumerate-ck-schema-moves "schema produced unchecked endpoint: ~e" p))
    (emit p)))

;; This compositional route expression stops at the open provider interfaces.
;; It does not inspect their bodies. Principal/discharge selections are checked
;; by the separate schema-specific matching below. Equality here retains the
;; individual passive occurrences, not just their displayed formulas.
(define (shell-interface K p provider-addresses)
  (define ports
    (for/hash ([a (in-list provider-addresses)] [i (in-naturals)]) (values a i)))
  (define (walk q a)
    (cond
      [(hash-has-key? ports a)
       (define i (hash-ref ports a))
       (list (for/list ([f (in-list (mixed-boundary-left (derivation-root-boundary q)))]
                        [j (in-naturals 1)]) (list 'input i j))
             (list 'output i))]
      [else
       (define f (family K q))
       (define cs
         (for/list ([c (in-list (checked-node-children q))] [s (in-naturals 1)])
           (walk c (append a (list s)))))
       (define is (indices K q))
       (define (l s i) (list-ref (first (list-ref cs (sub1 s))) (sub1 i)))
       (define (r s) (second (list-ref cs (sub1 s))))
       (define principal
         (case f
           [(tensorL) (list 'tensor (l 1 (first is)) (l 1 (second is)))]
           [(impliesL) (list 'implies (r 1) (l 2 (first is)))]
           [else #f]))
       (list
        (for/list ([t (in-list (order K q))])
          (if (eq? t 'principal) principal (l (first t) (second t))))
        (case f
          [(tensorR) (list 'tensor (r 1) (r 2))]
          [(impliesR) (list 'implies (l 1 (first is)) (r 1))]
          [(cut+ impliesL) (r 2)] [(cut- tensorL) (r 1)]
          [else (error 'shell-interface "unsupported rigid constructor ~e" f)]))]))
  (walk p '()))

(define (replace-native K p a q)
  (if (null? a) q
      (let ([cs (checked-node-children p)])
        (assemble-checked-application
         K (checked-node-occurrence p)
         (for/list ([c (in-list cs)] [s (in-naturals 1)])
           (if (= s (car a)) (replace-native K c (cdr a) q) c))))))

;; Exactly the four equations and their inverses. No name/kind classifier,
;; Cut/Cut permutation, orientation flip or identity erasure is used.
(define (local-moves K p a policy emit)
  (define f (family K p))
  (define (finish schema dir q read new-read old-ports new-ports)
    (when (and (equal? (derivation-root-boundary p) (derivation-root-boundary q))
               (equal? (shell-interface K p old-ports)
                       (shell-interface K q new-ports)))
      (emit (ck-schema-move schema dir a q read new-read
                            (map list old-ports new-ports)))))
  (when (eq? f 'cut+)
    (define producer (child p 1))
    (define consumer (child p 2))
    (define selected (first (indices K p)))
    ;; Tensor principal, forward. The cut selects the actual packed output.
    (when (and (eq? (family K producer) 'tensorR)
               (eq? (family K consumer) 'tensorL)
               (eq? (at-left K consumer selected) 'principal))
      (define P (child producer 1)) (define Q (child producer 2))
      (define R (child consumer 1))
      (define ij (indices K consumer))
      (when (and (equal? (mixed-boundary-right (derivation-root-boundary P))
                         (list-ref (mixed-boundary-left (derivation-root-boundary R))
                                   (sub1 (first ij))))
                 (equal? (mixed-boundary-right (derivation-root-boundary Q))
                         (list-ref (mixed-boundary-left (derivation-root-boundary R))
                                   (sub1 (second ij)))))
        (each-app K 'cut+ (list Q R) (list (second ij))
          (lambda (inner)
            (define ai (position-of (list 2 (first ij)) (order K inner)))
            (each-app K 'cut+ (list P inner) (list ai)
              (lambda (q) (finish 'tensor-principal 'forward q
                '(() (1) (2)) '(() (2))
                '((1 1) (1 2) (2 1)) '((1) (2 1) (2 2)))))))))
    ;; Tensor-left commute, forward: D must be outside the packed pair.
    (when (eq? (family K consumer) 'tensorL)
      (define token (at-left K consumer selected))
      (when (pair? token)
        (define R (child consumer 1))
        (define ij (indices K consumer))
        (each-app K 'cut+ (list producer R) (list (second token))
          (lambda (inner)
            (define ai (position-of (list 2 (first ij)) (order K inner)))
            (define bi (position-of (list 2 (second ij)) (order K inner)))
            (when (and ai bi)
              (each-app K 'tensorL (list inner) (list ai bi)
                (lambda (q) (finish 'tensor-commute 'forward q
                  '(() (2)) '(() (1)) '((1) (2 1)) '((1 1) (1 2))))))))))
    ;; Arrow principal preserves E,D,R physically; inner cut is NEGATIVE.
    (when (and (eq? (family K producer) 'impliesR)
               (eq? (family K consumer) 'impliesL)
               (eq? (at-left K consumer selected) 'principal))
      (define E (child producer 1)) (define D (child consumer 1))
      (define R (child consumer 2))
      (each-app K 'cut- (list E D) (indices K producer)
        (lambda (inner)
          (each-app K 'cut+ (list inner R) (indices K consumer)
            (lambda (q) (finish 'arrow-principal 'forward q
              '(() (1) (2)) '(() (1))
              '((1 1) (2 1) (2 2)) '((1 1) (1 2) (2))))))))
    (when (eq? policy 'bidirectional)
      ;; Both inverse tensor selected occurrences must lie in R, not in Q.
      (when (eq? (family K consumer) 'cut+)
        (define token (at-left K consumer selected))
        (when (and (pair? token) (= (first token) 2))
          (define P producer) (define Q (child consumer 1))
          (define R (child consumer 2))
          (define ai (second token)) (define bi (first (indices K consumer)))
          (when (not (= ai bi))
            (each-app K 'tensorR (list P Q) '()
              (lambda (tr)
                (each-app K 'tensorL (list R) (list ai bi)
                  (lambda (tl)
                    (each-app K 'cut+ (list tr tl)
                              (list (position-of 'principal (order K tl)))
                      (lambda (q) (finish 'tensor-principal 'inverse q
                        '(() (2)) '(() (1) (2))
                        '((1) (2 1) (2 2)) '((1 1) (1 2) (2 1))))))))))))
      (when (eq? (family K producer) 'cut-)
        (define E (child producer 1)) (define D (child producer 2))
        (each-app K 'impliesR (list E) (indices K producer)
          (lambda (ar)
            (each-app K 'impliesL (list D consumer) (indices K p)
              (lambda (al)
                (each-app K 'cut+ (list ar al)
                          (list (position-of 'principal (order K al)))
                  (lambda (q) (finish 'arrow-principal 'inverse q
                    '(() (1)) '(() (1) (2))
                    '((1 1) (1 2) (2)) '((1 1) (2 1) (2 2))))))))))))
  ;; Arrow-right commute, forward. Route D back through the arrow-right;
  ;; its index must be distinct from the originally discharged index.
  (when (and (eq? f 'cut-) (eq? (family K (child p 1)) 'impliesR))
    (define ar (child p 1)) (define P (child p 2))
    (define token (at-left K ar (first (indices K p))))
    (define E (child ar 1))
    (define ai (first (indices K ar)))
    (when (and (pair? token) (not (= (second token) ai)))
      (each-app K 'cut- (list E P) (list (second token))
        (lambda (inner)
          (define discharge (position-of (list 1 ai) (order K inner)))
          (when discharge
            (each-app K 'impliesR (list inner) (list discharge)
              (lambda (q) (finish 'arrow-commute 'forward q
                '(() (1)) '(() (1)) '((1 1) (2)) '((1 1) (1 2))))))))))
  (when (eq? policy 'bidirectional)
    (when (and (eq? f 'tensorL) (eq? (family K (child p 1)) 'cut+))
      (define inner (child p 1)) (define ij (indices K p))
      (define at (at-left K inner (first ij)))
      (define bt (at-left K inner (second ij)))
      (when (and (pair? at) (pair? bt) (= (first at) 2) (= (first bt) 2))
        (define P (child inner 1)) (define R (child inner 2))
        (define di (first (indices K inner)))
        (each-app K 'tensorL (list R) (list (second at) (second bt))
          (lambda (tl)
            (define dnew (position-of (list 1 di) (order K tl)))
            (when dnew
              (each-app K 'cut+ (list P tl) (list dnew)
                (lambda (q) (finish 'tensor-commute 'inverse q
                  '(() (1)) '(() (2)) '((1 1) (1 2)) '((1) (2 1))))))))))
    (when (and (eq? f 'impliesR) (eq? (family K (child p 1)) 'cut-))
      (define inner (child p 1))
      (define token (at-left K inner (first (indices K p))))
      (when (and (pair? token) (= (first token) 1))
        (define E (child inner 1)) (define P (child inner 2))
        (define di (first (indices K inner)))
        (each-app K 'impliesR (list E) (list (second token))
          (lambda (ar)
            (define dnew (position-of (list 1 di) (order K ar)))
            (when dnew
              (each-app K 'cut- (list ar P) (list dnew)
                (lambda (q) (finish 'arrow-commute 'inverse q
                  '(() (1)) '(() (1)) '((1 1) (1 2)) '((1 1) (2))))))))))))

(define (check-policy p)
  (unless (memq p '(forward bidirectional))
    (raise-argument-error 'ck-boundary "(or/c 'forward 'bidirectional)" p)))
(define (supported-source? p)
  (and (checked-term? p)
       (mixed-schema-calculus? (checked-term-calculus p))
       (checked-term-has-exact-calculus? p (checked-term-calculus p))
       (mixed-boundary? (derivation-root-boundary p))
       (for/and ([a (in-list (puncture-addresses p))])
         (mixed-boundary? (puncture-requirement p a)))
       (for/and ([a (in-list (vertex-addresses p))])
         (define q (vertex-at-address p a))
         (or (family (checked-term-calculus p) q)
             (memq (checked-node-occurrence q)
                   (mixed-schema-material-occurrences (checked-term-calculus p)))))))

;; The source bounds are mathematical termination invariants, not a claimed
;; polynomial complexity bound. All constructor/interface cases are counted,
;; including the negative Cut's contribution to K and arrow charge.
(define (formula-size f)
  (if (symbol? f) 1 (+ 1 (formula-size (second f)) (formula-size (third f)))))
(define (atom-mass f)
  (if (symbol? f) 1 (+ (atom-mass (second f)) (atom-mass (third f)))))
(define (boundary-mass h)
  (+ (for/sum ([f (in-list (mixed-boundary-left h))]) (atom-mass f))
     (atom-mass (mixed-boundary-right h))))
(define (mixed-proof-invariants p)
  (define K (checked-term-calculus p))
  (define cs 0) (define logical 0) (define mass 0) (define charge 0)
  (define leaves '())
  (define (walk q)
    (cond
      [(checked-hole? q)
       (set! leaves (append leaves (list (list 'vacancy (derivation-root-boundary q)))))]
      [else
       (define f (family K q))
       (case f
         [(material) (set! leaves (append leaves (list (list 'material (checked-node-occurrence q)))))]
         [(cut+ cut-)
          (set! cs (add1 cs))
          (define d (mixed-occurrence-data K (checked-node-occurrence q)))
          (set! mass (+ mass 1 (formula-size (hash-ref d 'formula))))
          (when (eq? f 'cut-) (set! charge (+ charge 2)))]
         [else (set! logical (add1 logical))
               (when (memq f '(impliesR impliesL)) (set! charge (add1 charge)))])
       (for-each walk (checked-node-children q))]))
  (walk p)
  (define b
    (for/sum ([leaf (in-list leaves)])
      (boundary-mass (if (eq? (car leaf) 'material)
                         (concrete-occurrence-conclusion (second leaf)) (second leaf)))))
  (hash 'W (+ (* 2 cs) logical) 'K mass 'arrow-charge charge
        'frontier leaves 'interface-mass-bound b))

;; The bool explicitly distinguishes exhaustive one-step generation from a
;; prefix. The verifier calls this afresh; it never calls the search operation.
(define (enumerate-ck-schema-moves p #:policy [policy 'bidirectional]
                                   #:generation-limit [limit 20000]
                                   #:time-limit-ms [ms 30000])
  (check-policy policy)
  (unless (supported-source? p)
    (raise-argument-error 'enumerate-ck-schema-moves "native mixed-schema source" p))
  (define K (checked-term-calculus p))
  (define moves '())
  (define reason #f)
  (with-handlers ([exn:ck-limit? (lambda (e) (set! reason (exn:ck-limit-reason e)))])
    (parameterize ([current-budget
                    (work-budget limit (+ (current-inexact-milliseconds) ms))])
      (for ([a (in-list (vertex-addresses p))])
        (budget-tick!)
        (local-moves K (vertex-at-address p a) a policy
          (lambda (m)
            (define q (replace-native K p a (ck-schema-move-target m)))
            (unless (checked-term? q) (error 'ck-boundary "native context lift failed: ~e" q))
            (unless (equal? (mixed-proof-invariants p) (mixed-proof-invariants q))
              (error 'ck-boundary "schema violated a conserved source invariant"))
            (define lifted (struct-copy ck-schema-move m [target q]))
            (unless (member lifted moves equal?) (set! moves (cons lifted moves))))))))
  (values (reverse moves) (not reason) reason))

(define (initial-state p)
  (define vs (vertex-addresses p))
  (ck-marked-state p (vector->immutable-vector (list->vector (range (length vs))))
                   (for/hash ([a (in-list vs)] [i (in-naturals)]) (values a i))))

(define (ck-marked-successor state move)
  (define root (ck-schema-move-address move))
  (define old-pi (ck-marked-state-partition state))
  (define old-lambda (ck-marked-state-origins state))
  (define read (map (lambda (a) (append root a)) (ck-schema-move-read-shell move)))
  (define merged (remove-duplicates (map (lambda (a) (hash-ref old-lambda a)) read)))
  (define rep (apply min merged))
  (define (relabel v) (if (member v merged) rep v))
  (define pi (vector->immutable-vector (vector-map relabel old-pi)))
  (define replaced (map (lambda (a) (append root a))
                        (ck-schema-move-replacement-shell move)))
  (define providers (ck-schema-move-providers move))
  (define new-lambda
    (for/hash ([a (in-list (vertex-addresses (ck-schema-move-target move)))])
      (values a
        (cond
          [(member a replaced equal?) rep]
          [else
           (define provider
             (findf (lambda (pr) (address-prefix? (append root (second pr)) a)) providers))
           (define old-a
             (if provider
                 (append root (first provider)
                         (drop a (+ (length root) (length (second provider))))) a))
           ;; ALL outside vertices are relabelled, including an outside vertex
           ;; sharing a previously created origin with the present read shell.
           (relabel (hash-ref old-lambda old-a))]))))
  (ck-marked-state (ck-schema-move-target move) pi new-lambda))

(define (frontier-ok? source frontier)
  (if (checked-hole? source) (null? frontier)
      (and (cut-witness? frontier) (eq? (cut-witness-source frontier) source)
           (cut-witness-reconstructs? frontier))))
(define (compartments source frontier)
  (define cuts (if (cut-witness? frontier) (cut-witness-addresses frontier) '()))
  (for/vector ([a (in-list (vertex-addresses source))])
    (or (for/first ([c (in-list cuts)] #:when (address-prefix? c a)) c) 'remainder)))
(define (crossing pi owners)
  (for*/first ([i (in-range (vector-length pi))]
               [j (in-range (add1 i) (vector-length pi))]
               #:when (and (= (vector-ref pi i) (vector-ref pi j))
                           (not (equal? (vector-ref owners i) (vector-ref owners j)))))
    (list (vector-ref pi i) i (vector-ref owners i) j (vector-ref owners j))))
(define (valid-marked? source state)
  (define pi (ck-marked-state-partition state))
  (define ls (ck-marked-state-origins state))
  (define n (length (vertex-addresses source)))
  (and (supported-source? (ck-marked-state-endpoint state))
       (eq? (checked-term-calculus source)
            (checked-term-calculus (ck-marked-state-endpoint state)))
       (vector? pi) (immutable? pi) (= n (vector-length pi))
       (for/and ([x (in-vector pi)] [i (in-naturals)])
         (and (exact-nonnegative-integer? x) (<= x i)
              (= x (vector-ref pi x))))
       (hash? ls) (immutable? ls)
       (equal? (sort (hash-keys ls) address<?)
               (vertex-addresses (ck-marked-state-endpoint state)))
       (equal? (sort (remove-duplicates (hash-values ls)) <)
               (sort (remove-duplicates (vector->list pi)) <))))

(define (certify-native-ck-boundary source frontier #:policy [policy 'bidirectional]
                                    #:state-limit [cap 4096]
                                    #:generation-limit [gen 20000]
                                    #:time-limit-ms [ms 30000])
  (check-policy policy)
  (unless (and (exact-positive-integer? cap) (exact-nonnegative-integer? gen)
               (real? ms) (>= ms 0))
    (raise-arguments-error 'certify-native-ck-boundary "invalid resource bounds"))
  (cond
    [(not (and (supported-source? source) (frontier-ok? source frontier)))
     (ck-boundary-result 'MALFORMED #f 'unsupported-source-or-frontier (hash))]
    [else
     (define owners (compartments source frontier))
     (define initial (initial-state source))
     (define states (list initial)) (define edges '())
     (define visited (make-hash (list (cons initial 0))))
     (define processed 0) (define terminal #f) (define crossed #f) (define stopped #f)
     (define deadline (+ (current-inexact-milliseconds) ms))
     (let loop ()
       (when (and (< processed (length states)) (not terminal) (not stopped))
         (define state (list-ref states processed))
         (define-values (moves complete? why)
           (enumerate-ck-schema-moves (ck-marked-state-endpoint state) #:policy policy
             #:generation-limit gen #:time-limit-ms (max 0 (- deadline (current-inexact-milliseconds)))))
         (for ([m (in-list moves)] #:break (or terminal stopped))
           (define next (ck-marked-successor state m))
           (define hit (crossing (ck-marked-state-partition next) owners))
           (define id (hash-ref visited next #f))
           (cond
             [(and (not id) (>= (length states) cap) (not hit)) (set! stopped 'state-limit)]
             [else
              (unless id
                (set! id (length states))
                (hash-set! visited next id)
                (set! states (append states (list next))))
              (set! edges (cons (ck-state-edge processed id m) edges))
              (when hit (set! terminal id) (set! crossed hit))]))
         (unless complete? (set! stopped why))
         (set! processed (add1 processed)) (loop)))
     (define c (ck-boundary-certificate source frontier policy ck-conversion-version
                  ck-canonicalization-version states (reverse edges) terminal crossed))
     (cond
       [terminal (ck-boundary-result 'UNSAFE c 'crossing (hash 'crossing crossed))]
       [stopped (ck-boundary-result 'UNKNOWN c stopped (hash 'states (length states)))]
       [else
        ;; SAFE is contingent on a separate fresh closure check, not the worklist
        ;; having stopped. That checker independently enumerates all successors.
        (define v (verify-ck-boundary-certificate c #:source source #:policy policy
                                                 #:generation-limit gen #:time-limit-ms ms))
        (if (and (ck-closure-report-valid? v) (eq? (ck-closure-report-status v) 'SAFE))
            (ck-boundary-result 'SAFE c 'verified-complete-closure (hash 'states (length states)))
            (ck-boundary-result 'UNKNOWN c 'verification-incomplete (hash 'verification v)))])]))

(define (verify-ck-boundary-certificate c #:source [expected #f] #:frontier [frontier #f]
                                         #:policy [policy #f]
                                         #:generation-limit [gen 20000]
                                         #:time-limit-ms [ms 30000])
  (let/ec reject
    (define (bad reason [data (hash)]) (reject (ck-closure-report #f 'INVALID reason data)))
    (with-handlers ([exn:fail? (lambda (e) (bad 'malformed-evidence (hash 'message (exn-message e))))])
      (unless (ck-boundary-certificate? c) (bad 'not-a-certificate))
      (define source (ck-boundary-certificate-source c))
      (define f (ck-boundary-certificate-frontier c))
      (define p (ck-boundary-certificate-policy c))
      (unless (and (or (not expected) (eq? source expected))
                   (or (not frontier) (equal? f frontier))
                   (or (not policy) (eq? p policy))
                   (equal? (ck-boundary-certificate-conversion-version c) ck-conversion-version)
                   (equal? (ck-boundary-certificate-canonicalization-version c) ck-canonicalization-version)
                   (supported-source? source) (frontier-ok? source f))
        (bad 'source-policy-or-version-mismatch))
      (check-policy p)
      (define ss (ck-boundary-certificate-states c))
      (define es (ck-boundary-certificate-edges c))
      (unless (and (pair? ss) (list? es) (not (check-duplicates ss equal?))
                   (equal? (car ss) (initial-state source))
                   (andmap (lambda (s) (and (ck-marked-state? s) (valid-marked? source s))) ss))
        (bad 'invalid-marked-state))
      (define terminal (ck-boundary-certificate-terminal c))
      (define owners (compartments source f))
      (define successors (make-hash))
      (define generation-complete (make-hash))
      (define deadline (+ (current-inexact-milliseconds) ms))
      ;; Fresh instance generation, not supplied-edge replay and not a call to
      ;; certify-native-ck-boundary. Store neither a search verdict nor its cache.
      (for ([s (in-list ss)] [i (in-naturals)])
        (define-values (moves complete? reason)
          (enumerate-ck-schema-moves (ck-marked-state-endpoint s) #:policy p
            #:generation-limit gen #:time-limit-ms (max 0 (- deadline (current-inexact-milliseconds)))))
        (when (and (not terminal) (not complete?))
          (reject (ck-closure-report #f 'UNKNOWN reason (hash 'state i))))
        (hash-set! successors i moves)
        (hash-set! generation-complete i complete?))
      (define reachable (make-hash (list (cons 0 #t))))
      (for ([e (in-list es)])
        (unless (and (ck-state-edge? e)
                     (exact-nonnegative-integer? (ck-state-edge-from e))
                     (exact-nonnegative-integer? (ck-state-edge-to e))
                     (< (ck-state-edge-from e) (length ss)) (< (ck-state-edge-to e) (length ss)))
          (bad 'invalid-edge-index))
        (define s (list-ref ss (ck-state-edge-from e)))
        (unless (member (ck-state-edge-move e)
                        (hash-ref successors (ck-state-edge-from e)) equal?)
          (unless (hash-ref generation-complete (ck-state-edge-from e))
            (reject (ck-closure-report #f 'UNKNOWN 'instance-generation-incomplete
                                       (hash 'state (ck-state-edge-from e)))))
          (bad 'invalid-local-move))
        (unless (equal? (ck-marked-successor s (ck-state-edge-move e))
                        (list-ref ss (ck-state-edge-to e)))
          (bad 'invalid-origin-update)))
      (let reach ()
        (define before (hash-count reachable))
        (for ([e (in-list es)] #:when (hash-has-key? reachable (ck-state-edge-from e)))
          (hash-set! reachable (ck-state-edge-to e) #t))
        (unless (= before (hash-count reachable)) (reach)))
      (unless (= (hash-count reachable) (length ss)) (bad 'unreachable-listed-state))
      (cond
        [terminal
         (unless (and (exact-nonnegative-integer? terminal) (< terminal (length ss)))
           (bad 'invalid-terminal))
         (define x (crossing (ck-marked-state-partition (list-ref ss terminal)) owners))
         (unless (and x (equal? x (ck-boundary-certificate-crossing c)))
           (bad 'not-a-crossing))
         (ck-closure-report #t 'UNSAFE 'checked-crossing-history (hash 'crossing x))]
        [else
         (for ([s (in-list ss)] [i (in-naturals)])
           (when (crossing (ck-marked-state-partition s) owners) (bad 'unsafe-state-in-safe-certificate))
           (for ([m (in-list (hash-ref successors i))])
             (unless (for/or ([e (in-list es)])
                       (and (= i (ck-state-edge-from e)) (equal? m (ck-state-edge-move e))))
               (bad 'missing-admitted-successor (hash 'state i 'move m)))))
         (when (ck-boundary-certificate-crossing c) (bad 'unexpected-crossing-field))
         (ck-closure-report #t 'SAFE 'complete-one-step-closure (hash 'states (length ss)))]))))

(define (ck-certificate-protection c)
  (define report (verify-ck-boundary-certificate c))
  (unless (and (ck-closure-report-valid? report) (eq? (ck-closure-report-status report) 'SAFE))
    (raise-arguments-error 'ck-certificate-protection "requires independently verified complete closure"
                           "report" report))
  (define n (length (vertex-addresses (ck-boundary-certificate-source c))))
  (define labels (list->vector (range n)))
  (for ([s (in-list (ck-boundary-certificate-states c))])
    (define pi (ck-marked-state-partition s))
    (for ([i (in-range n)])
      (define a (vector-ref labels i)) (define b (vector-ref labels (vector-ref pi i)))
      (define rep (min a b))
      (for ([j (in-range n)] #:when (or (= a (vector-ref labels j)) (= b (vector-ref labels j))))
        (vector-set! labels j rep))))
  (vector->immutable-vector labels))
(define (ck-protection-retains-cut? source protection witness)
  (and (cut-witness? witness) (eq? source (cut-witness-source witness))
       (not (crossing protection (compartments source witness)))))
(define (certified-ordered-coproduct c #:cut-limit [cap 4096] #:time-limit-ms [ms 30000])
  (define source (ck-boundary-certificate-source c))
  (define protection (ck-certificate-protection c))
  (define K (checked-term-calculus source))
  (when (checked-hole? source)
    (raise-arguments-error 'certified-ordered-coproduct "Box is not a positive algebra generator"))
  (let/ec incomplete
    (define budget (work-budget cap (+ (current-inexact-milliseconds) ms)))
    (with-handlers ([exn:ck-limit?
                     (lambda (e)
                       (incomplete (ck-boundary-result 'UNKNOWN #f 'cut-sector-incomplete
                                                      (hash 'reason (exn:ck-limit-reason e)))))])
      (define kept
        (for/list ([w (in-admissible-cut-witnesses source)]
                   #:do [(tick! budget)]
                   #:when (ck-protection-retains-cut? source protection w)) w))
      (define endpoint
        (ordered-pure-tensor K
          (vector (make-ordered-forest K (list source)) (make-ordered-forest K '()))))
      (define sum
        (for/fold ([s endpoint]) ([w (in-list kept)])
          (ordered-sum-add s
            (ordered-pure-tensor K
              (vector (ordered-cut-forest w)
                      (make-ordered-forest K (list (cut-witness-remainder w))))))))
      (ck-protected-coproduct sum kept protection))))
