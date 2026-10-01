#lang racket/base

(require rackunit
         racket/list
         "../potkin/main.rkt")

(define (one-sided . formulae)
  (singleton-hypersequent '() formulae))

(define B-ax-p (one-sided 'p-perp 'p))
(define B-ax-q (one-sided 'q-perp 'q))
(define B-Q (one-sided 'p-perp 'q-perp '(tensor p q)))
(define B-P (one-sided '(tensor p q) '(par p-perp q-perp)))
(define B-U (one-sided 'p 'q))
(define B-V (one-sided 'p-perp 'r))
(define B-W (one-sided 'q 'r))

(define (total-component-incidence premises conclusion)
  (make-component-incidence
   premises conclusion
   (append-map
    (lambda (slot+premise)
      (define slot (car slot+premise))
      (define premise (cdr slot+premise))
      (for*/list ([source (in-range 1 (add1 (hypersequent-size premise)))]
                  [target
                   (in-range 1 (add1 (hypersequent-size conclusion)))])
        (make-component-edge slot source target)))
    (for/list ([premise (in-list premises)] [slot (in-naturals 1)])
      (cons slot premise)))))

(define (occurrence id premises conclusion [kind 'logical])
  (make-concrete-occurrence
   id premises conclusion
   #:kind kind
   #:tag 'normalization-replay-fixture
   #:instance (list 'exact-normalization-instance id)
   #:incidence (total-component-incidence premises conclusion)))

;; Four distinct atomic identity occurrence instances.
(define ax-p-left-occ (occurrence 'norm-ax-p-left '() B-ax-p 'material))
(define ax-q-left-occ (occurrence 'norm-ax-q-left '() B-ax-q 'material))
(define ax-p-right-occ (occurrence 'norm-ax-p-right '() B-ax-p 'material))
(define ax-q-right-occ (occurrence 'norm-ax-q-right '() B-ax-q 'material))
(define tensor-occ (occurrence 'norm-tensor (list B-ax-p B-ax-q) B-Q))
(define par-occ (occurrence 'norm-par (list B-Q) B-P))
(define cut-pq-occ (occurrence 'norm-cut-pq (list B-Q B-P) B-Q))
(define cut-p-occ (occurrence 'norm-cut-p (list B-ax-p B-Q) B-Q))
(define cut-q-occ (occurrence 'norm-cut-q (list B-ax-q B-Q) B-Q))
(define cut-p-right-occ
  (occurrence 'norm-cut-p-right (list B-Q B-ax-p) B-Q))
(define wrapper-occ (occurrence 'norm-wrapper (list B-Q) B-Q))
(define alternative-Q-occ (occurrence 'norm-Q-alternative '() B-Q 'material))

;; Explicit nonidentity atomic base U,V,W and its root-pair Cut.
(define U-occ (occurrence 'norm-U '() B-U 'material))
(define V-occ (occurrence 'norm-V '() B-V 'material))
(define W-occ (occurrence 'norm-W '() B-W 'material))
(define atomic-cut-occ
  (occurrence 'norm-atomic-cut (list B-U B-V) B-W))

(define occurrences
  (list ax-p-left-occ ax-q-left-occ ax-p-right-occ ax-q-right-occ
        tensor-occ par-occ cut-pq-occ cut-p-occ cut-q-occ cut-p-right-occ
        wrapper-occ alternative-Q-occ U-occ V-occ W-occ atomic-cut-occ))
(define K (make-equipped-calculus occurrences))

(define signature
  (make-normalization-signature
   K
   (list cut-pq-occ cut-p-occ cut-q-occ cut-p-right-occ atomic-cut-occ)
   (list tensor-occ)
   (list par-occ)
   1))

(define (checked raw expected)
  (define result (validate-candidate K raw #:expected expected))
  (check-true (checked-term? result))
  result)

(define ax-p-left (checked (raw-app 'norm-ax-p-left) B-ax-p))
(define ax-q-left (checked (raw-app 'norm-ax-q-left) B-ax-q))
(define ax-p-right (checked (raw-app 'norm-ax-p-right) B-ax-p))
(define ax-q-right (checked (raw-app 'norm-ax-q-right) B-ax-q))
(define L
  (checked
   (raw-app 'norm-tensor
            (checked-term->raw ax-p-left)
            (checked-term->raw ax-q-left))
   B-Q))
(define Q
  (checked
   (raw-app 'norm-tensor
            (checked-term->raw ax-p-right)
            (checked-term->raw ax-q-right))
   B-Q))
(define P
  (checked (raw-app 'norm-par (checked-term->raw Q)) B-P))
(define T
  (checked
   (raw-app 'norm-cut-pq (checked-term->raw L) (checked-term->raw P))
   B-Q))
(define Q-alternative
  (checked (raw-app 'norm-Q-alternative) B-Q))

(check-equal? (derivation-vertex-count T) 8)

(define identity-BQ (identity-boundary-routing B-Q))
(define survivor-route
  (make-normalization-port-routing 'survivor identity-BQ))

(define principal-lhs
  (checked
   (raw-app 'norm-cut-pq
            (raw-app 'norm-tensor raw-hole raw-hole)
            (raw-app 'norm-par raw-hole))
   B-Q))
(define principal-rhs
  (checked
   (raw-app 'norm-cut-q
            raw-hole
            (raw-app 'norm-cut-p raw-hole raw-hole))
   B-Q))
(define principal-cell
  (register-principal-tensor-par-cell
   'principal-tensor-par signature
   principal-lhs principal-rhs
   '(p-left q-left survivor)
   '(q-left p-left survivor)
   identity-BQ
   #:port-routings (list survivor-route)))

(define left-p-lhs
  (checked
   (raw-app 'norm-cut-p (raw-app 'norm-ax-p-left) raw-hole)
   B-Q))
(define left-q-lhs
  (checked
   (raw-app 'norm-cut-q (raw-app 'norm-ax-q-left) raw-hole)
   B-Q))
(define identity-rhs (identity-context K B-Q))
(define left-p-cell
  (register-left-identity-cut-cell
   'left-identity-p signature left-p-lhs identity-rhs
   '(survivor) '(survivor) identity-BQ
   #:port-routings (list survivor-route)))
(define left-q-cell
  (register-left-identity-cut-cell
   'left-identity-q signature left-q-lhs identity-rhs
   '(survivor) '(survivor) identity-BQ
   #:port-routings (list survivor-route)))

(define right-p-lhs
  (checked
   (raw-app 'norm-cut-p-right raw-hole (raw-app 'norm-ax-p-left))
   B-Q))
(define right-p-cell
  (register-right-identity-cut-cell
   'right-identity-p signature right-p-lhs identity-rhs
   '(survivor) '(survivor) identity-BQ
   #:port-routings (list survivor-route)))

(define U (checked (raw-app 'norm-U) B-U))
(define V (checked (raw-app 'norm-V) B-V))
(define W (checked (raw-app 'norm-W) B-W))
(define atomic-source
  (checked
   (raw-app 'norm-atomic-cut
            (checked-term->raw U) (checked-term->raw V))
   B-W))
(define atomic-lhs
  (checked
   (raw-app 'norm-atomic-cut
            (raw-app 'norm-U) (raw-app 'norm-V))
   B-W))
(define atomic-cell
  (register-atomic-root-pair-quote-cell
   'quote-U/V-as-W signature atomic-lhs W
   (identity-boundary-routing B-W)))

(define registry
  (make-normalization-cell-registry
   signature
   (list principal-cell left-p-cell left-q-cell right-p-cell atomic-cell)))

(define main-requests
  (list
   (make-normalization-event-request registry 'principal-event
                                     'principal-tensor-par '())
   (make-normalization-event-request registry 'inner-identity-event
                                     'left-identity-p '(2))
   (make-normalization-event-request registry 'outer-identity-event
                                     'left-identity-q '())))

(define B (make-material-profile K occurrences))
(define initial-P-frontier (make-cut-witness T '((2))))
(check-true (cut-witness? initial-P-frontier))
(check-true (cut-witness-reconstructs? initial-P-frontier))

(define certificate
  (compile-normalization-replay
   T initial-P-frontier registry main-requests
   #:material-profile B
   #:polynomial-term-cap 64))
(check-true (normalization-replay-certificate? certificate))
(check-eq? (normalization-replay-certificate-target certificate)
           (vertex-at-address T '(2 1)))

;; Exact integer potentials from the paper example.
(check-equal?
 (map normalization-potential-psi
      (normalization-replay-certificate-potentials certificate))
 '(587 313 104 17))
(check-equal?
 (map (lambda (potential)
        (list (normalization-potential-N potential)
              (normalization-potential-A potential)
              (normalization-potential-H potential)))
      (normalization-replay-certificate-potentials certificate))
 '((8 4 7) (7 3 10) (5 2 4) (3 1 0)))

;; First crossing and unique least exposure: reveal P's par root only, keep Q.
(define first-crossing
  (normalization-replay-certificate-first-crossing certificate))
(check-true (normalization-crossing? first-crossing))
(check-equal? (normalization-crossing-event-index first-crossing) 1)
(check-equal? (normalization-crossing-shell-addresses first-crossing)
              '(() (1) (2)))
(check-equal? (normalization-crossing-crossed-cache-addresses first-crossing)
              '((2)))
(define first-exposure
  (first (normalization-replay-certificate-exposures certificate)))
(check-equal? (normalization-exposure-exposed-addresses first-exposure)
              '((2)))
(check-equal?
 (map replay-cache-handle-source-address
      (normalization-exposure-retained-cache-handles first-exposure))
 '((2 1)))
(check-equal? (normalization-exposure-refined-addresses first-exposure)
              '((2 1)))
(check-true (normalization-exposure-reconstruction-ok? first-exposure))

(check-equal?
 (normalization-replay-certificate-survivor-source-addresses certificate)
 '((2 1)))
(check-equal?
 (normalization-replay-certificate-survivor-target-addresses certificate)
 '(()))
(check-equal?
 (normalization-replay-certificate-opaque-interior-inspections certificate)
 0)
(check-equal?
 (zipper-baseline-result-opaque-interior-inspections
  (normalization-replay-certificate-zipper-baseline certificate))
 0)

;; The read class retains erased identity-shell constraints.  Q stays three
;; untouched singleton classes; read singletons are not treated as opaque.
(define expected-read-class '(() (1) (1 1) (1 2) (2)))
(define partition
  (normalization-replay-certificate-read-partition certificate))
(check-equal? (replay-read-class-members (first partition))
              expected-read-class)
(check-true (replay-read-class-ever-read? (first partition)))
(check-equal? (map replay-read-class-members (rest partition))
              '(((2 1)) ((2 1 1)) ((2 1 2))))
(check-false (ormap replay-read-class-ever-read? (rest partition)))
(check-equal?
 (normalization-replay-certificate-ever-read-source-addresses certificate)
 expected-read-class)

;; P is ineligible; Q and its two children are independently eligible.
(define fold (normalization-replay-certificate-guarded-fold certificate))
(define eligibility (guarded-cut-fold-eligibility-table fold))
(check-false (hash-ref eligibility '(2)))
(check-true (hash-ref eligibility '(2 1)))
(check-true (hash-ref eligibility '(2 1 1)))
(check-true (hash-ref eligibility '(2 1 2)))
(check-equal? (guarded-cut-fold-polynomial fold) (hash 0 1 1 3 2 1))
(check-equal? (guarded-cut-fold-empty-and-proper-count fold) 5)
(check-equal? (guarded-cut-fold-proper-count fold) 4)
(check-equal? (guarded-cut-fold-whole-weight fold) 1)

;; Independent direct owner-colouring oracle over this small native cut family.
;; This does not reimplement union-find or serve as the universal proof.
(define oracle-witness-count 0)
(for ([witness (in-admissible-cut-witnesses T)])
  (set! oracle-witness-count (add1 oracle-witness-count))
  (define recurrence-guarded?
    (andmap (lambda (address) (hash-ref eligibility address))
            (cut-witness-addresses witness)))
  (check-equal? (normalization-frontier-guarded? certificate witness)
                recurrence-guarded?))
(check-true (> oracle-witness-count 0))

(define P-source-witness (make-cut-witness T '((2))))
(define Q-source-witness (make-cut-witness T '((2 1))))
(define Q-leaves-witness (make-cut-witness T '((2 1 1) (2 1 2))))
(check-false (normalization-frontier-guarded? certificate P-source-witness))
(check-true (normalization-frontier-guarded? certificate Q-source-witness))
(check-true (normalization-frontier-guarded? certificate Q-leaves-witness))

(define guarded-Q
  (certify-guarded-source-cut certificate '((2 1))
                              #:material-profile B))
(check-true (guarded-source-cut-certificate? guarded-Q))
(check-true (guarded-source-cut-certificate-guarded? guarded-Q))
(check-true (guarded-source-cut-certificate-base-pure? guarded-Q))
(check-equal?
 (map detached-entry-address
      (guarded-source-cut-certificate-detached guarded-Q))
 '((2 1)))
(check-equal? (puncture-addresses
               (guarded-source-cut-certificate-remainder guarded-Q))
              '((2 1)))
(check-equal? (guarded-source-cut-certificate-refill guarded-Q) T)
(check-true (cut-witness-reconstructs?
             (guarded-source-cut-certificate-witness guarded-Q)))

;; Whole is a separate endpoint and cannot be fabricated as a root cut.
(check-true (cut-error? (make-cut-witness T (list root-address))))

;; The projected native open history keeps Q's exact physical interface.
(define compiled
  (normalization-replay-certificate-compiled-history certificate))
(check-true (compiled-normalization-history-endpoint-capture? compiled))
(define projected (compiled-normalization-history-states compiled))
(check-equal? (length projected) 4)
(check-equal?
 (map projected-replay-state-survivor-addresses projected)
 '(((2 1)) ((2 2)) ((2)) (())))
(check-equal?
 (map projected-replay-state-cut-ancestor-counts projected)
 '((((2 1) . 1)) (((2 2) . 2)) (((2) . 1)) ((() . 0))))
(for ([state (in-list (take projected 3))])
  (check-true (cut-witness? (projected-replay-state-native-witness state)))
  (check-true
   (cut-witness-reconstructs?
    (projected-replay-state-native-witness state))))
(check-true (checked-hole? (projected-replay-state-term (last projected))))
(check-false (projected-replay-state-native-witness (last projected)))
(check-equal?
 (checked-term->raw (projected-replay-state-term (second projected)))
 (raw-app 'norm-cut-q
          (raw-app 'norm-ax-q-left)
          (raw-app 'norm-cut-p (raw-app 'norm-ax-p-left) raw-hole)))
(check-equal?
 (hash-ref (compiled-normalization-history-survivor-routings compiled)
           '(2 1))
 identity-BQ)

;; Replay with a distinct checked Cut-free proof never inspects its interior.
(define replayed
  (replay-compiled-normalization compiled (list Q-alternative)))
(check-true (normalization-replay-result? replayed))
(check-eq? (normalization-replay-result-target replayed) Q-alternative)
(check-equal?
 (normalization-replay-result-opaque-interior-inspections replayed)
 0)
(check-equal? (normalization-replay-result-output-routing replayed)
              identity-BQ)
(check-true (> (normalization-replay-result-admission-inspections replayed) 0))
(check-true (> (normalization-replay-result-replay-inspections replayed) 0))

;; The independent checker reconstructs cell matches, routing, origins,
;; potential descent, exposure, native projections and the zipper result.
(define checked-certificate
  (check-normalization-replay-certificate certificate))
(check-true (normalization-check-report? checked-certificate))
(check-true (normalization-check-report-valid? checked-certificate))
(check-equal?
 (normalization-check-report-opaque-interior-inspections checked-certificate)
 0)
(check-equal?
 (normalization-replay-certificate-replay-inspections certificate)
 (zipper-baseline-result-constructor-inspections
  (normalization-replay-certificate-zipper-baseline certificate)))

;; Focused certificate mutations.
(define omitted-par-exposure
  (struct-copy
   normalization-replay-certificate certificate
   [exposures
    (list
     (struct-copy normalization-exposure first-exposure
                  [exposed-addresses '()]))]))
(check-false
 (normalization-check-report-valid?
  (check-normalization-replay-certificate omitted-par-exposure)))

;; Splitting the erased identity-shell constraints incorrectly leaves a read
;; singleton looking opaque; recomputation rejects it.
(define lost-erased-shell-class
  (struct-copy
   normalization-replay-certificate certificate
   [read-partition
    (list
     (replay-read-class '() '(() (1) (2)) #t)
     (replay-read-class '(1 1) '((1 1)) #t)
     (replay-read-class '(1 2) '((1 2)) #t)
     (replay-read-class '(2 1) '((2 1)) #f)
     (replay-read-class '(2 1 1) '((2 1 1)) #f)
     (replay-read-class '(2 1 2) '((2 1 2)) #f))]))
(check-false
 (normalization-check-report-valid?
  (check-normalization-replay-certificate lost-erased-shell-class)))

;; Corrupting an inherited origin on the opaque Q handle is detected.
(define first-event
  (first (normalization-replay-certificate-events certificate)))
(define corrupted-first-event
  (struct-copy
   normalization-event-certificate first-event
   [after-origin-representatives
    (hash-set
     (normalization-event-certificate-after-origin-representatives first-event)
     '(2 2) '())]))
(define corrupted-origins
  (struct-copy
   normalization-replay-certificate certificate
   [events
    (cons corrupted-first-event
          (rest (normalization-replay-certificate-events certificate)))]))
(check-false
 (normalization-check-report-valid?
  (check-normalization-replay-certificate corrupted-origins)))

;; A premise permutation with incompatible physical boundaries is rejected at
;; registration, and exact routing cannot silently relabel formulae.
(check-exn
 exn:fail?
 (lambda ()
   (register-principal-tensor-par-cell
    'bad-premise-permutation signature
    principal-lhs principal-rhs
    '(p-left q-left survivor)
    '(p-left q-left survivor)
    identity-BQ)))
(define BQ-positions (boundary-formula-occurrences B-Q))
(check-exn
 exn:fail?
 (lambda ()
   (make-exact-boundary-routing
    B-Q B-Q
    (list (cons (first BQ-positions) (second BQ-positions))
          (cons (second BQ-positions) (first BQ-positions))
          (cons (third BQ-positions) (third BQ-positions))))))

;; Foreign snapshots are never accepted merely because presentations agree.
(define foreign-K (make-equipped-calculus occurrences))
(define foreign-T
  (validate-candidate foreign-K (checked-term->raw T) #:expected B-Q))
(define foreign-frontier (make-cut-witness foreign-T '((2))))
(define foreign-result
  (compile-normalization-replay foreign-T foreign-frontier registry
                                main-requests))
(check-true (normalization-replay-failure? foreign-result))
(check-equal? (normalization-replay-failure-code foreign-result)
              'invalid-source)

;; --------------------------------------------------------------------------
;; Nonidentity U/V -> W quotation and both identity orientations

(define atomic-certificate
  (compile-normalization-replay
   atomic-source (make-cut-witness atomic-source '()) registry
   (list (make-normalization-event-request
          registry 'atomic-quote-event 'quote-U/V-as-W '()))
   #:material-profile B))
(check-true (normalization-replay-certificate? atomic-certificate))
(check-equal? (normalization-replay-certificate-target atomic-certificate) W)
(check-eq?
 (checked-node-occurrence
  (normalization-replay-certificate-target atomic-certificate))
 W-occ)
(check-equal?
 (map normalization-potential-psi
      (normalization-replay-certificate-potentials atomic-certificate))
 '(19 0))
(check-equal?
 (map replay-read-class-members
      (normalization-replay-certificate-read-partition atomic-certificate))
 '((() (1) (2))))
(check-true
 (normalization-check-report-valid?
  (check-normalization-replay-certificate atomic-certificate)))

(define right-source
  (checked
   (raw-app 'norm-cut-p-right
            (checked-term->raw Q)
            (checked-term->raw ax-p-left))
   B-Q))
(define right-frontier (make-cut-witness right-source '((1))))
(define right-certificate
  (compile-normalization-replay
   right-source right-frontier registry
   (list (make-normalization-event-request
          registry 'right-identity-event 'right-identity-p '()))
   #:material-profile B))
(check-true (normalization-replay-certificate? right-certificate))
(check-eq? (normalization-replay-certificate-target right-certificate)
           (vertex-at-address right-source '(1)))
(check-false (normalization-replay-certificate-first-crossing right-certificate))
(check-equal?
 (normalization-replay-certificate-survivor-source-addresses right-certificate)
 '((1)))
(check-equal?
 (normalization-replay-certificate-survivor-target-addresses right-certificate)
 '(()))

;; --------------------------------------------------------------------------
;; Genuinely staged nested projection versus one-shot native compilation

(define wrapper-context
  (checked (raw-app 'norm-wrapper raw-hole) B-Q))
(define wrapped-T
  (checked (raw-app 'norm-wrapper (checked-term->raw T)) B-Q))
(define nested-frontier (make-cut-witness wrapped-T '((1 2))))
(define nested-requests
  (list
   (make-normalization-event-request registry 'nested-principal
                                     'principal-tensor-par '(1))
   (make-normalization-event-request registry 'nested-inner-identity
                                     'left-identity-p '(1 2))
   (make-normalization-event-request registry 'nested-outer-identity
                                     'left-identity-q '(1))))
(define nested-certificate
  (compile-normalization-replay
   wrapped-T nested-frontier registry nested-requests
   #:material-profile B))
(check-true (normalization-replay-certificate? nested-certificate))
(check-equal?
 (normalization-replay-certificate-survivor-source-addresses
  nested-certificate)
 '((1 2 1)))
(check-equal?
 (normalization-replay-certificate-survivor-target-addresses
  nested-certificate)
 '((1)))
(check-false
 (compiled-normalization-history-endpoint-capture?
  (normalization-replay-certificate-compiled-history nested-certificate)))

(define nested-compiled
  (normalization-replay-certificate-compiled-history nested-certificate))
(define nested-replay
  (replay-compiled-normalization nested-compiled (list Q-alternative)))
(define staged-target
  (complete-fill wrapper-context
                 (list (normalization-replay-result-target replayed))))
(check-equal? (normalization-replay-result-target nested-replay)
              staged-target)
(for ([inner-state (in-list projected)]
      [outer-state
       (in-list (compiled-normalization-history-states nested-compiled))])
  (define staged-context
    (context-compose wrapper-context
                     (list (projected-replay-state-term inner-state))))
  (check-equal? staged-context (projected-replay-state-term outer-state)))
(check-true
 (normalization-check-report-valid?
  (check-normalization-replay-certificate nested-certificate)))

(displayln
 (format
  "normalization-replay: native replay, least exposure, read partition, guarded CK fold, U/V quote, and nested projection passed (~a native source cuts checked)"
  oracle-witness-count))
