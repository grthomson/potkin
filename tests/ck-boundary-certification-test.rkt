#lang racket/base

(require rackunit racket/list racket/vector
         "../potkin/main.rkt"
         "ordered-ck-test.rkt")

;; Fixed, small theorem-regression fixtures. No exhaustive degree parameter,
;; assertion-count target, or claimed universal result from these checks.
(define (H left right) (singleton-hypersequent left (list right)))
(define (ground id left right)
  (define h (H left right))
  (make-concrete-occurrence id '() h #:kind 'material
    #:incidence (make-component-incidence '() h '())))
(define stock
  (list (ground 'S '() 'd)
        (ground 'P1 '() 'a) (ground 'P1-dependent '(d) 'a)
        (ground 'P2 '() 'b) (ground 'P2-dependent '(d) 'b)
        (ground 'R '(a b) 'c)
        (ground 'commute-R '(a b d) 'c)
        (ground 'body '(a g) 'b) (ground 'argument '(h) 'a)
        (ground 'continuation '(b) 'c)
        (ground 'equal-body '(a a) 'b) (ground 'equal-argument '() 'a)
        (ground 'curried-body '(a b g) 'v)
        (ground 'curried-continuation '(v) 'o)))
(define K (make-mixed-schema-calculus stock))
(define (g id [calculus K])
  (define p (validate-candidate calculus (raw-app id)))
  (unless (checked-node? p) (error 'fixture "ground is not checked: ~e" p)) p)
(define (app f ps [is '()] [o #f])
  (define p (mixed-apply K f ps #:indices is #:order o))
  (unless (checked-node? p) (error 'fixture "schema application not checked: ~e" p)) p)
(define (datum p) (mixed-occurrence-data K (checked-node-occurrence p)))
(define (principal p) (hash-ref (datum p) 'principal-output-index))
(define (cut P R i) (app 'cut+ (list P R) (list i)))
(define (bundle j)
  (define tr (app 'tensorR (list (g (if (= j 1) 'P1-dependent 'P1))
                                     (g (if (= j 2) 'P2-dependent 'P2)))))
  (define tl (app 'tensorL (list (g 'R)) '(1 2)))
  (cut tr tl (principal tl)))
(define (contextual j) (cut (g 'S) (bundle j) 1))
(define (moves p [policy 'bidirectional])
  (define-values (ms complete? why) (enumerate-ck-schema-moves p #:policy policy))
  (unless complete? (error 'fixture "small one-step generation incomplete: ~e" why)) ms)
(define (named-move p schema direction)
  (findf (lambda (m) (and (eq? schema (ck-schema-move-schema m))
                          (eq? direction (ck-schema-move-direction m))
                          (null? (ck-schema-move-address m)))) (moves p)))
(define (empty-frontier p) (make-cut-witness p '()))
(define (result p frontier policy)
  (certify-native-ck-boundary p frontier #:policy policy #:state-limit 256))
(define (state-count r)
  (length (ck-boundary-certificate-states (ck-boundary-result-certificate r))))

(test-case "native order, multiplicity, attachments and reconstruction precede collection"
  (define p (app 'tensorR (list (g 'P1) (g 'P1))))
  (define w (make-cut-witness p '((2) (1))))
  (check-equal? (cut-witness-addresses w) '((1) (2)))
  (check-equal? (map detached-entry-address (cut-witness-detached w)) '((1) (2)))
  (check-equal? (ordered-forest-size (ordered-cut-forest w)) 2)
  (check-equal? (proof-forest-count (cut-witness-forest w) (g 'P1)) 2)
  (check-equal? (puncture-addresses (cut-witness-remainder w)) '((1) (2)))
  (check-equal? (map telescope-entry-requirement (premise-telescope (cut-witness-remainder w)))
                (list (H '() 'a) (H '() 'a)))
  (check-true (cut-witness-reconstructs? w)))

(test-case "frozen schemas generate inverse-created instances in one exact snapshot"
  (define p (contextual 2))
  (define inner (findf (lambda (m) (equal? (ck-schema-move-address m) '(2))) (moves p 'forward)))
  (check-true (ck-schema-move? inner))
  (define q (ck-schema-move-target inner))
  (define back (named-move q 'tensor-principal 'inverse))
  (check-true (ck-schema-move? back))
  (define generated (ck-schema-move-target back))
  (check-equal? (hash-ref (datum generated) 'formula) '(tensor d a))
  (check-eq? (checked-term-calculus generated) K)
  (check-eq? (checked-node-occurrence generated)
             (calculus-lookup K (concrete-occurrence-id (checked-node-occurrence generated))))
  (check-equal? (mixed-proof-invariants p) (mixed-proof-invariants generated))
  (check-exn exn:fail:contract? (lambda () (calculus-occurrences K)))
  (check-exn exn:fail:contract? (lambda () (calculus-size K))))

(define tensor-simple
  (let ([tr (app 'tensorR (list (g 'P1) (g 'P2)))]
        [tl (app 'tensorL (list (g 'R)) '(1 2))]) (cut tr tl (principal tl))))
(define tensor-commute
  (let ([tl (app 'tensorL (list (g 'commute-R)) '(1 2))])
    (define di (index-of (mixed-boundary-left (derivation-root-boundary tl)) 'd))
    (cut (g 'S) tl (add1 di))))
(define arrow-simple
  (let ([ar (app 'impliesR (list (g 'body)) '(1))]
        [al (app 'impliesL (list (g 'argument) (g 'continuation)) '(1))])
    (cut ar al (principal al))))
(define arrow-commute
  (app 'cut- (list (app 'impliesR (list (g 'equal-body)) '(1))
                  (g 'equal-argument)) '(1)))

(test-case "all four checked cells and inverses, with equal-looking distinct discharge indices"
  (for ([p (in-list (list tensor-simple tensor-commute arrow-simple arrow-commute))]
        [schema (in-list '(tensor-principal tensor-commute arrow-principal arrow-commute))])
    (define m (named-move p schema 'forward))
    (check-true (ck-schema-move? m))
    (define q (ck-schema-move-target m))
    (check-true (checked-term-has-exact-calculus? q K))
    (check-equal? (derivation-root-boundary p) (derivation-root-boundary q))
    (check-equal? (mixed-proof-invariants p) (mixed-proof-invariants q))
    (check-true (ormap (lambda (m) (equal? p (ck-schema-move-target m)))
                       (filter (lambda (m) (and (eq? schema (ck-schema-move-schema m))
                                               (eq? 'inverse (ck-schema-move-direction m)))) (moves q)))))
  (define q (ck-schema-move-target (named-move arrow-commute 'arrow-commute 'forward)))
  (check-equal? (mixed-occurrence-indices K (checked-node-occurrence q)) '(1))
  (check-equal? (mixed-occurrence-indices K (checked-node-occurrence (car (checked-node-children q)))) '(2))
  ;; Equal formula a is not enough to authorize discharging a removed index.
  (check-exn exn:fail:contract?
    (lambda () (app 'impliesR (list (g 'equal-body)) '(3))))
  (check-exn exn:fail:contract?
    (lambda () (app 'tensorL (list (g 'equal-body)) '(1 1))))
  (check-exn exn:fail:contract?
    (lambda () (app 'impliesR (list (g 'equal-body)) '(1) '((1 1)))))
  (define wrong-outer
    (app 'cut- (reverse (checked-node-children tensor-simple))
               (mixed-occurrence-indices K (checked-node-occurrence tensor-simple))))
  (check-false (named-move wrong-outer 'tensor-principal 'forward))
  (define ar (car (checked-node-children arrow-simple)))
  (define al (cadr (checked-node-children arrow-simple)))
  (define wrong-inner
    (cut (cut (car (checked-node-children al)) (car (checked-node-children ar)) 1)
         (cadr (checked-node-children al)) 1))
  (check-false (named-move wrong-inner 'arrow-principal 'inverse)))

(test-case "all coherent equal-formula exchanges preserve actual routes and canonical IDs"
  (define ps (list (H '(a a) 'b)))
  (define orders (mixed-rule-orders K 'tensorL ps #:indices '(1 2)))
  (check-equal? orders '((principal)))
  (define cut-orders
    (mixed-rule-orders K 'cut+ (list (H '(a) 'a) (H '(a a) 'b)) #:indices '(1)))
  (check-equal? (length cut-orders) 2)
  (define a1 (mixed-rule-occurrence K 'cut+ (list (H '(a) 'a) (H '(a a) 'b))
                                   #:indices '(1) #:order (first cut-orders)))
  (define a2 (mixed-rule-occurrence K 'cut+ (list (H '(a) 'a) (H '(a a) 'b))
                                   #:indices '(1) #:order (second cut-orders)))
  (check-not-equal? a1 a2)
  (check-not-equal? (mixed-occurrence-routing K a1) (mixed-occurrence-routing K a2))
  (check-eq? a1 (calculus-lookup K (concrete-occurrence-id a1))))

(define T1 (contextual 1)) (define T2 (contextual 2))
(define j1-forward (result T1 (make-cut-witness T1 '((2))) 'forward))
(define j1-both (result T1 (make-cut-witness T1 '((2))) 'bidirectional))
(define j2-forward (result T2 (make-cut-witness T2 '((2))) 'forward))
(define j2-both (result T2 (make-cut-witness T2 '((2))) 'bidirectional))

(test-case "m=2 exact policy distinction and latent two-step inverse crossing"
  (check-eq? (ck-boundary-result-status j1-forward) 'SAFE)
  (check-eq? (ck-boundary-result-status j1-both) 'SAFE)
  (check-eq? (ck-boundary-result-status j2-forward) 'SAFE)
  (check-eq? (ck-boundary-result-status j2-both) 'UNSAFE)
  (check-false (named-move T1 'tensor-principal 'inverse))
  (check-false (named-move T2 'tensor-principal 'inverse))
  (define c (ck-boundary-result-certificate j2-both))
  (check-true (ck-closure-report-valid? (verify-ck-boundary-certificate c)))
  (check-equal? (map (lambda (e) (ck-schema-move-direction (ck-state-edge-move e)))
                    (ck-boundary-certificate-edges c)) '(forward inverse))
  (define last-state (list-ref (ck-boundary-certificate-states c) (ck-boundary-certificate-terminal c)))
  ;; W is outside the second read shell but shares its previously merged origin.
  (check-equal? (hash-ref (ck-marked-state-origins last-state) '(2 1))
                (hash-ref (ck-marked-state-origins last-state) '()))
  (check-eq? (ck-closure-report-status
              (verify-ck-boundary-certificate c #:generation-limit 0)) 'UNKNOWN))

(define bundle-certificate
  (ck-boundary-result-certificate (result tensor-simple (empty-frontier tensor-simple) 'bidirectional)))
(test-case "full-triple dedup and complete scaffold partition retain primitive singletons"
  (define ss (ck-boundary-certificate-states bundle-certificate))
  (define same-endpoints
    (for*/list ([s (in-list ss)] [t (in-list ss)]
                #:when (and (not (equal? s t))
                            (equal? (ck-marked-state-endpoint s) (ck-marked-state-endpoint t)))) (list s t)))
  (check-not-equal? same-endpoints '())
  (define protection (ck-certificate-protection bundle-certificate))
  (define vs (vertex-addresses tensor-simple))
  (define blocks (remove-duplicates (vector->list protection)))
  (check-equal? (sort (map (lambda (b) (count (lambda (x) (= b x)) (vector->list protection))) blocks) <)
                '(1 1 1 3))
  (check-equal? (map (lambda (a) (vector-ref protection (index-of vs a))) '(() (1) (2))) '(0 0 0)))

(test-case "curried m=2 scaffold and conserved arrow charge, with all providers retained"
  (define inner (app 'impliesR (list (g 'curried-body)) '(2)))
  (define curried (app 'impliesR (list inner) '(1)))
  (define continuation (g 'curried-continuation))
  (define al2 (app 'impliesL (list (g 'P2) continuation) '(1)))
  (define al1 (app 'impliesL (list (g 'P1) al2) (list (principal al2))))
  (define p (cut curried al1 (principal al1)))
  (define r (result p (empty-frontier p) 'bidirectional))
  (check-eq? (ck-boundary-result-status r) 'SAFE)
  (check-equal? (hash-ref (mixed-proof-invariants p) 'arrow-charge) 4)
  (define pi (ck-certificate-protection (ck-boundary-result-certificate r)))
  (check-equal? (sort (map (lambda (b) (count (lambda (x) (= b x)) (vector->list pi)))
                         (remove-duplicates (vector->list pi))) <) '(1 1 1 1 5)))

(test-case "tampered closure, routes, origins, reachability, source and policy are rejected"
  (define c bundle-certificate)
  (define (invalid c) (check-false (ck-closure-report-valid? (verify-ck-boundary-certificate c))))
  (invalid (struct-copy ck-boundary-certificate c
             [edges (drop-right (ck-boundary-certificate-edges c) 1)]))
  (define ss (ck-boundary-certificate-states c))
  (define s (second ss))
  (invalid (struct-copy ck-boundary-certificate c
             [states (cons (car ss) (cons (struct-copy ck-marked-state s
                           [origins (hash-set (ck-marked-state-origins s) '() 999)]) (cddr ss)))]))
  (define first-edge (car (ck-boundary-certificate-edges c)))
  (define first-move (ck-state-edge-move first-edge))
  (invalid (struct-copy ck-boundary-certificate c
             [edges (cons (struct-copy ck-state-edge first-edge
                     [move (struct-copy ck-schema-move first-move [providers '(((1) (2)))])])
                          (cdr (ck-boundary-certificate-edges c)))]))
  (define n (length (vertex-addresses tensor-simple)))
  (define unreachable (ck-marked-state tensor-simple
                        (vector->immutable-vector (make-vector n 0))
                        (for/hash ([a (in-list (vertex-addresses tensor-simple))]) (values a 0))))
  (invalid (struct-copy ck-boundary-certificate c [states (append ss (list unreachable))]))
  (check-false (ck-closure-report-valid? (verify-ck-boundary-certificate c #:policy 'forward)))
  (check-false (ck-closure-report-valid? (verify-ck-boundary-certificate c #:source T1)))
  (invalid (struct-copy ck-boundary-certificate c [conversion-version '(other-registry)])))

(test-case "resource limits and unsupported/foreign provenance never become SAFE"
  (check-eq? (ck-boundary-result-status
    (certify-native-ck-boundary T2 (make-cut-witness T2 '((2))) #:state-limit 1)) 'UNKNOWN)
  (check-eq? (ck-boundary-result-status
    (certify-native-ck-boundary T2 (make-cut-witness T2 '((2))) #:generation-limit 0)) 'UNKNOWN)
  (check-eq? (ck-boundary-result-status
    (certify-native-ck-boundary T2 (make-cut-witness T2 '((2))) #:time-limit-ms 0)) 'UNKNOWN)
  (check-eq? (ck-boundary-result-status
    (certify-native-ck-boundary T2 (make-cut-witness T1 '((2))))) 'MALFORMED)
  (define foreign (make-mixed-schema-calculus stock))
  (define e (mixed-apply K 'tensorR (list (g 'P1 foreign) (g 'P2))))
  (check-eq? (validation-error-code e) 'wrong-calculus-provenance)
  (define box (identity-context K (H '(a) 'b)))
  (check-eq? (ck-boundary-result-status (certify-native-ck-boundary box '())) 'SAFE))

(test-case "exact protection enters ordered native cuts without losing typed reconstruction"
  (define out (certified-ordered-coproduct bundle-certificate))
  (check-true (ck-protected-coproduct? out))
  (define ws (ck-protected-coproduct-witnesses out))
  (check-equal? (length ws) 8) ; three independent providers, not a proof by counting
  (define full (findf (lambda (w) (= 3 (length (cut-witness-addresses w)))) ws))
  (check-equal? (cut-witness-addresses full) '((1 1) (1 2) (2 1)))
  (check-equal? (map (lambda (e) (concrete-occurrence-id (checked-node-occurrence (detached-entry-term e))))
                    (cut-witness-detached full)) '(P1 P2 R))
  (check-true (cut-witness-reconstructs? full))
  (check-equal? (puncture-addresses (cut-witness-remainder full)) '((1 1) (1 2) (2 1)))
  (check-false (ck-protection-retains-cut? tensor-simple (ck-protected-coproduct-protection out)
                                          (make-cut-witness tensor-simple '((1)))))
  (check-eq? (cut-error-code (make-cut-witness tensor-simple '(()))) 'root-cut)
  (check-eq? (ck-boundary-result-status (certified-ordered-coproduct bundle-certificate #:cut-limit 1)) 'UNKNOWN))

(test-case "actual typed Cut orientation gives the ordered three-provider coefficient obstruction"
  (define residual (ck-schema-move-target (named-move arrow-simple 'arrow-principal 'forward)))
  (define inner (car (checked-node-children residual)))
  (define E (car (checked-node-children inner)))
  (define D (cadr (checked-node-children inner)))
  (define R (cadr (checked-node-children residual)))
  (define erased (cut (cut D E 1) R 1))
  (define w (make-cut-witness residual '((1 1) (1 2) (2))))
  (define ew (make-cut-witness erased '((1 1) (1 2) (2))))
  (check-true (cut-witness-reconstructs? w))
  (check-true (cut-witness-reconstructs? ew))
  (define edr (ordered-cut-forest w))
  (define der (ordered-cut-forest ew))
  (check-not-equal? edr der)
  (check-equal? (ordered-forest->commutative edr) (ordered-forest->commutative der))
  (check-equal? (ordered-sum-coefficient (ordered-connected-coproduct erased)
                (vector edr (make-ordered-forest K (list (cut-witness-remainder ew))))) 0)
  (check-equal? (ordered-sum-coefficient (ordered-connected-coproduct erased)
                (vector der (make-ordered-forest K (list (cut-witness-remainder ew))))) 1))

(printf "CK certification fixed evidence: contextual marked states j1 forward/both=~a/~a; j2 forward/counterhistory=~a/~a; bundle states=~a. No exhaustive family or assertion-count target.\n"
        (state-count j1-forward) (state-count j1-both)
        (state-count j2-forward) (state-count j2-both)
        (length (ck-boundary-certificate-states bundle-certificate)))
