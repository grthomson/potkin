#lang racket/base
(require rackunit racket/list
         "../potkin/main.rkt" "../potkin/analysis/ck-protected-reuse.rkt")

(define (H left right) (singleton-hypersequent left (list right)))
(define (ground id left right)
  (define h (H left right))
  (make-concrete-occurrence id '() h #:kind 'material
    #:incidence (make-component-incidence '() h '())))
(define stock (list (ground 'P '() 'a) (ground 'Q '() 'b) (ground 'R '(a b) 'c)
                    (ground 'S '() 'd) (ground 'P-dependent '(d) 'a)
                    (ground 'Q-dependent '(d) 'b)
                    (ground 'E '(a g) 'b) (ground 'D '(h) 'a) (ground 'C '(b) 'c)))
(define K (make-mixed-schema-calculus stock))
(define (g id [k K]) (validate-candidate k (raw-app id)))
(define (app f ps [indices '()] [k K]) (mixed-apply k f ps #:indices indices))
(define (principal p [k K])
  (hash-ref (mixed-occurrence-data k (checked-node-occurrence p)) 'principal-output-index))
(define (bundle [j 0] [k K])
  (define tr (app 'tensorR (list (g (if (= j 1) 'P-dependent 'P) k)
                                  (g (if (= j 2) 'Q-dependent 'Q) k)) '() k))
  (define tl (app 'tensorL (list (g 'R k)) '(1 2) k))
  (app 'cut+ (list tr tl) (list (principal tl k)) k))
(define t (bundle))
(define (contextual j) (app 'cut+ (list (g 'S) (bundle j)) '(1)))
(define arrow
  (let ([ar (app 'impliesR (list (g 'E)) '(1))]
        [al (app 'impliesL (list (g 'D) (g 'C)) '(1))])
    (app 'cut+ (list ar al) (list (principal al)))))
(define profile '(P Q R))
(define (evidence q [policy 'bidirectional])
  (define r (prepare-ck-protection q #:policy policy #:state-limit 256))
  (check-equal? (ck-protection-result-status r) 'SAFE)
  (ck-protection-result-evidence r))

(test-case "strict tensor and implication templates have replayed exact scaffold blocks"
  (for ([q (in-list (list t arrow))] [name (in-list '(tensor-bundle curried-application))])
    (define e (evidence q))
    (define c (ck-protection-evidence-certificate e))
    (check-true (ck-structured-certificate? c))
    (check-equal? (ck-structured-certificate-family c) name)
    (check-true (ck-closure-report-valid? (verify-structured-ck-certificate c)))
    (check-equal? (length (remove-duplicates (vector->list (ck-protection-evidence-partition e)))) 4)))

(test-case "structured verifier rejects stale source, invented partition and omitted history"
  (define e (evidence t))
  (define c (ck-protection-evidence-certificate e))
  (check-false (ck-closure-report-valid?
                (verify-structured-ck-certificate (struct-copy ck-structured-certificate c [history '()]))))
  (check-false (ck-closure-report-valid?
                (verify-ck-protection-evidence (struct-copy ck-protection-evidence e [source (bundle)]))))
  (check-false (ck-closure-report-valid?
                (verify-structured-ck-certificate (struct-copy ck-structured-certificate c [partition '#(0)])))))

(test-case "whole bundle edge has exact contextual forward/bidirectional distinction"
  (for ([j '(1 2)])
    (define q (contextual j))
    (define w (make-cut-witness q '((2))))
    (define f (evidence q 'forward))
    (define b (evidence q 'bidirectional))
    (check-true (ck-protection-retains-cut? q (ck-protection-evidence-partition f) w))
    (check-equal? (ck-protection-retains-cut? q (ck-protection-evidence-partition b) w) (= j 1))))

(test-case "equal presentation from a foreign snapshot cannot forge a history target"
  (define c (ck-protection-evidence-certificate (evidence t)))
  (define m (car (ck-structured-certificate-history c)))
  (define foreign-K (make-mixed-schema-calculus stock))
  (define foreign-target (validate-candidate foreign-K (checked-term->raw (ck-schema-move-target m))))
  (check-equal? foreign-target (ck-schema-move-target m))
  (check-false (eq? foreign-K K))
  (define forged (struct-copy ck-schema-move m [target foreign-target]))
  (define report
    (verify-structured-ck-certificate
     (struct-copy ck-structured-certificate c
       [history (cons forged (cdr (ck-structured-certificate-history c)))])))
  (check-false (ck-closure-report-valid? report))
  (check-equal? (ck-closure-report-reason report) 'foreign-history-target-provenance))

(test-case "compound providers are not admitted by primitive family recognizer"
  (define compound (app 'tensorR (list (g 'P) (g 'Q))))
  (check-equal? (ck-protection-result-status (certify-structured-ck-protection compound)) 'UNKNOWN))

(test-case "retained indexed terms preserve typed attachments before collection"
  (define o (protected-ck-observables (evidence t) profile))
  (check-equal? (ck-protected-observables-status o) 'SAFE)
  (check-equal? (length (ck-protected-observables-occurrence-terms o)) 9)
  (check-true (ck-protected-observables-live-eligible? o))
  (check-true (ordered-zero? (ck-protected-observables-core o)))
  (define max-term
    (findf (lambda (x) (= (ordered-forest-size (ck-occurrence-term-left x)) 3))
           (ck-protected-observables-occurrence-terms o)))
  (check-equal? (cut-witness-addresses (ck-occurrence-term-witness max-term)) '((1 1) (1 2) (2 1)))
  (check-equal? (map telescope-entry-requirement
                   (premise-telescope (cut-witness-remainder (ck-occurrence-term-witness max-term))))
                (map (lambda (id) (derivation-root-boundary (g id))) profile)))

(test-case "profile eligibility is not historical-spectrum erasure or expression equality"
  (define e (evidence t))
  (define small (protected-ck-observables e '(P)))
  (define large (protected-ck-observables e profile))
  (check-false (ck-protected-observables-live-eligible? small))
  (check-equal? (map second (ck-protected-observables-historical-spectrum small)) profile)
  (check-false (ordered-zero? (ck-protected-observables-core small)))
  (check-equal? (ck-closure-report-status (full-protected-fidelity small large)) 'UNSAFE)
  (check-equal? (ck-closure-report-status (full-protected-fidelity large large)) 'SAFE))

(test-case "native shape equality is not implied by behavior or common provider stock"
  (define e (evidence t))
  (define c (ck-protection-evidence-certificate e))
  (define target (ck-schema-move-target (car (ck-structured-certificate-history c))))
  (define before (protected-ck-observables e profile))
  (define after (protected-ck-observables (evidence target) profile))
  (check-equal? (ck-closure-report-status (full-protected-fidelity before after)) 'UNSAFE))

(test-case "materialization caps return UNKNOWN with no partial equality verdict"
  (define o (protected-ck-observables (evidence t) profile #:cut-limit 1))
  (check-equal? (ck-protected-observables-status o) 'UNKNOWN)
  (check-false (ck-protected-observables-coaction o))
  (check-equal? (ck-closure-report-status (full-protected-fidelity o o)) 'UNKNOWN))

(test-case "independent observable verification rejects invented eligibility and foreign source"
  (define e (evidence t))
  (define o (protected-ck-observables e '(P)))
  (check-true (ck-closure-report-valid? (verify-protected-ck-observables e '(P) o)))
  (check-false (ck-closure-report-valid?
                (verify-protected-ck-observables e '(P)
                  (struct-copy ck-protected-observables o [live-eligible? #t]))))
  (check-false (ck-closure-report-valid?
                (verify-protected-ck-observables e '(P)
                  (struct-copy ck-protected-observables o
                    [details (hash-set (ck-protected-observables-details o) 'source (bundle))])))))

(test-case "safe factor/remainder heredity is recomputed with exact address transports"
  (define e (evidence t))
  (define w (make-cut-witness t '((1 1) (2 1))))
  (define h (verify-ck-heredity e w #:state-limit 256))
  (check-equal? (ck-closure-report-status h) 'SAFE)
  (check-equal? (length (hash-ref (ck-closure-report-details h) 'entries)) 3)
  (check-equal? (ck-closure-report-status (verify-ck-heredity e (make-cut-witness t '((1))))) 'UNSAFE))

(test-case "protected rank-three flags agree under independent left and right separations"
  (define e (evidence t))
  (define left (protected-ck-iterated-coproduct e 3 #:side 'left #:cut-limit 20000))
  (define right (protected-ck-iterated-coproduct e 3 #:side 'right #:cut-limit 20000))
  (check-equal? (ck-iterated-result-status left) 'SAFE)
  (check-equal? (ck-iterated-result-status right) 'SAFE)
  (check-equal? (ck-iterated-result-sum left) (ck-iterated-result-sum right))
  (define flags (protected-ck-flags e 3 #:cut-limit 20000))
  (define Kt (checked-term-calculus t))
  (define assembled
    (make-ordered-sum Kt 3
      (for/list ([f (in-list (ck-flag-result-flags flags))])
        (cons (list->vector (ck-protected-flag-coordinates f)) 1))))
  (check-equal? assembled (ck-iterated-result-sum right)))

(test-case "genuine tensor-to-mixed sector inclusion transports all represented observables"
  (define old-K (make-mixed-schema-calculus stock #:sector 'tensor))
  (define old (bundle 0 old-K))
  (define maps (hash 'P 'fixed-P-map 'Q 'fixed-Q-map 'R 'fixed-R-map))
  (define c (certify-tensor-mixed-comparison old (list '(P) profile) maps #:target K))
  (check-true (ck-comparison-certificate? c))
  (check-true (ck-closure-report-valid? (verify-tensor-mixed-comparison c)))
  (check-false (eq? (checked-term-calculus old)
                    (checked-term-calculus (ck-protection-evidence-source (ck-comparison-certificate-mixed-evidence c)))))
  (check-false (ck-closure-report-valid?
                (verify-tensor-mixed-comparison
                 (struct-copy ck-comparison-certificate c [profiles (list profile '(P))])))))
