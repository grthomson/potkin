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

;; --------------------------------------------------------------------------
;; Arity-four positive elaboration, staged causal composition, and source
;; pullback.  This is one fixed coarse presentation cell, not unrestricted
;; Cut elimination for a mixed coarse/binary calculus.

(define B4-a1 (one-sided 'p-perp 'p))
(define B4-a2 (one-sided 'p-perp 'p)) ; equal display, distinct physical slot
(define B4-a3 (one-sided 'q-perp 'q))
(define B4-a4 (one-sided 'r-perp 'r))
(define B4-t12 (one-sided 'p-perp 'p-perp '(tensor p p)))
(define B4-t123
  (one-sided 'p-perp 'p-perp 'q-perp
             '(tensor (tensor p p) q)))
(define B4-t1234
  (one-sided 'p-perp 'p-perp 'q-perp 'r-perp
             '(tensor (tensor (tensor p p) q) r)))
(define B4-Q (one-sided 'p-perp 'p-perp 'q-perp 'r-perp))
(define B4-p12
  (one-sided '(par p-perp p-perp) 'q-perp 'r-perp))
(define B4-p123
  (one-sided '(par (par p-perp p-perp) q-perp) 'r-perp))
(define B4-p1234
  (one-sided '(par (par (par p-perp p-perp) q-perp) r-perp)))

(define (occurrence4 id premises conclusion [kind 'logical])
  (make-concrete-occurrence
   id premises conclusion
   #:kind kind
   #:tag 'arity-four-normalization
   #:instance (list 'arity-four-instance id)
   #:incidence (total-component-incidence premises conclusion)))

(define ax4-1-occ (occurrence4 'a4-ax-1 '() B4-a1 'material))
(define ax4-2-occ (occurrence4 'a4-ax-2 '() B4-a2 'material))
(define ax4-3-occ (occurrence4 'a4-ax-3 '() B4-a3 'material))
(define ax4-4-occ (occurrence4 'a4-ax-4 '() B4-a4 'material))
(define q4-leaf-occ (occurrence4 'a4-q-leaf '() B4-Q 'material))
(define q4-wrap-occ (occurrence4 'a4-q-wrap (list B4-Q) B4-Q 'material))
(define q4-alt-leaf-occ (occurrence4 'a4-q-alt-leaf '() B4-Q 'material))
(define q4-alt-wrap-occ
  (occurrence4 'a4-q-alt-wrap (list B4-Q) B4-Q 'material))

(define tensor4-12-occ
  (occurrence4 'a4-tensor-12 (list B4-a1 B4-a2) B4-t12))
(define tensor4-123-occ
  (occurrence4 'a4-tensor-123 (list B4-t12 B4-a3) B4-t123))
(define tensor4-1234-occ
  (occurrence4 'a4-tensor-1234 (list B4-t123 B4-a4) B4-t1234))
(define par4-12-occ (occurrence4 'a4-par-12 (list B4-Q) B4-p12))
(define par4-123-occ (occurrence4 'a4-par-123 (list B4-p12) B4-p123))
(define par4-1234-occ
  (occurrence4 'a4-par-1234 (list B4-p123) B4-p1234))

(define cut4-top-occ
  (occurrence4 'a4-cut-top (list B4-t1234 B4-p1234) B4-Q))
(define cut4-123-occ
  (occurrence4 'a4-cut-123 (list B4-t123 B4-p123) B4-Q))
(define cut4-12-occ
  (occurrence4 'a4-cut-12 (list B4-t12 B4-p12) B4-Q))
(define cut4-a1-occ (occurrence4 'a4-cut-a1 (list B4-a1 B4-Q) B4-Q))
(define cut4-a2-occ (occurrence4 'a4-cut-a2 (list B4-a2 B4-Q) B4-Q))
(define cut4-a3-occ (occurrence4 'a4-cut-a3 (list B4-a3 B4-Q) B4-Q))
(define cut4-a4-occ (occurrence4 'a4-cut-a4 (list B4-a4 B4-Q) B4-Q))

(define coarse4-tensor-occ
  (occurrence4 'a4-coarse-tensor
               (list B4-a1 B4-a2 B4-a3 B4-a4) B4-t1234))
(define coarse4-par-occ
  (occurrence4 'a4-coarse-par (list B4-Q) B4-p1234))
(define coarse4-cut-occ
  (occurrence4 'a4-coarse-cut (list B4-t1234 B4-p1234) B4-Q))

(define occurrences4
  (list ax4-1-occ ax4-2-occ ax4-3-occ ax4-4-occ
        q4-leaf-occ q4-wrap-occ q4-alt-leaf-occ q4-alt-wrap-occ
        tensor4-12-occ tensor4-123-occ tensor4-1234-occ
        par4-12-occ par4-123-occ par4-1234-occ
        cut4-top-occ cut4-123-occ cut4-12-occ
        cut4-a1-occ cut4-a2-occ cut4-a3-occ cut4-a4-occ
        coarse4-tensor-occ coarse4-par-occ coarse4-cut-occ))
(define K4 (make-equipped-calculus occurrences4))
(define target-signature4
  (make-normalization-signature
   K4
   (list cut4-top-occ cut4-123-occ cut4-12-occ
         cut4-a1-occ cut4-a2-occ cut4-a3-occ cut4-a4-occ)
   (list tensor4-12-occ tensor4-123-occ tensor4-1234-occ)
   (list par4-12-occ par4-123-occ par4-1234-occ)
   1))

(define (checked4 raw expected)
  (define result (validate-candidate K4 raw #:expected expected))
  (check-true (checked-term? result))
  result)

(define ax4-1 (checked4 (raw-app 'a4-ax-1) B4-a1))
(define ax4-2 (checked4 (raw-app 'a4-ax-2) B4-a2))
(define ax4-3 (checked4 (raw-app 'a4-ax-3) B4-a3))
(define ax4-4 (checked4 (raw-app 'a4-ax-4) B4-a4))
(define Q4
  (checked4 (raw-app 'a4-q-wrap (raw-app 'a4-q-leaf)) B4-Q))
(define Q4-prime
  (checked4 (raw-app 'a4-q-alt-wrap (raw-app 'a4-q-alt-leaf)) B4-Q))

(define expanded4-source
  (checked4
   (raw-app
    'a4-cut-top
    (raw-app
     'a4-tensor-1234
     (raw-app
      'a4-tensor-123
      (raw-app 'a4-tensor-12
               (checked-term->raw ax4-1)
               (checked-term->raw ax4-2))
      (checked-term->raw ax4-3))
     (checked-term->raw ax4-4))
    (raw-app 'a4-par-1234
             (raw-app 'a4-par-123
                      (raw-app 'a4-par-12 (checked-term->raw Q4)))))
   B4-Q))

(define coarse4-source
  (checked4
   (raw-app
    'a4-coarse-cut
    (raw-app 'a4-coarse-tensor
             (checked-term->raw ax4-1)
             (checked-term->raw ax4-2)
             (checked-term->raw ax4-3)
             (checked-term->raw ax4-4))
    (raw-app 'a4-coarse-par (checked-term->raw Q4)))
   B4-Q))

(define coarse4-principal-target
  (checked4
   (raw-app 'a4-cut-a4 (checked-term->raw ax4-4)
            (raw-app 'a4-cut-a3 (checked-term->raw ax4-3)
                     (raw-app 'a4-cut-a2 (checked-term->raw ax4-2)
                              (raw-app 'a4-cut-a1
                                       (checked-term->raw ax4-1)
                                       (checked-term->raw Q4)))))
   B4-Q))

(check-equal? (derivation-vertex-count coarse4-source) 9)
(check-equal? (derivation-vertex-count expanded4-source) 13)
(check-equal? (derivation-vertex-count coarse4-principal-target) 10)

(define identity-B4-Q (identity-boundary-routing B4-Q))
(define survivor-route4
  (make-normalization-port-routing 'provider identity-B4-Q))

(define principal4-outer-lhs
  (checked4
   (raw-app 'a4-cut-top
            (raw-app 'a4-tensor-1234 raw-hole raw-hole)
            (raw-app 'a4-par-1234 raw-hole))
   B4-Q))
(define principal4-outer-rhs
  (checked4
   (raw-app 'a4-cut-a4 raw-hole
            (raw-app 'a4-cut-123 raw-hole raw-hole))
   B4-Q))
(define principal4-outer-cell
  (register-principal-tensor-par-cell
   'a4-principal-outer target-signature4
   principal4-outer-lhs principal4-outer-rhs
   '(tensor-prefix p4 par-prefix) '(p4 tensor-prefix par-prefix)
   identity-B4-Q))

(define principal4-middle-lhs
  (checked4
   (raw-app 'a4-cut-123
            (raw-app 'a4-tensor-123 raw-hole raw-hole)
            (raw-app 'a4-par-123 raw-hole))
   B4-Q))
(define principal4-middle-rhs
  (checked4
   (raw-app 'a4-cut-a3 raw-hole
            (raw-app 'a4-cut-12 raw-hole raw-hole))
   B4-Q))
(define principal4-middle-cell
  (register-principal-tensor-par-cell
   'a4-principal-middle target-signature4
   principal4-middle-lhs principal4-middle-rhs
   '(tensor-prefix p3 par-prefix) '(p3 tensor-prefix par-prefix)
   identity-B4-Q))

(define principal4-inner-lhs
  (checked4
   (raw-app 'a4-cut-12
            (raw-app 'a4-tensor-12 raw-hole raw-hole)
            (raw-app 'a4-par-12 raw-hole))
   B4-Q))
(define principal4-inner-rhs
  (checked4
   (raw-app 'a4-cut-a2 raw-hole
            (raw-app 'a4-cut-a1 raw-hole raw-hole))
   B4-Q))
(define principal4-inner-cell
  (register-principal-tensor-par-cell
   'a4-principal-inner target-signature4
   principal4-inner-lhs principal4-inner-rhs
   '(p1 p2 provider) '(p2 p1 provider)
   identity-B4-Q #:port-routings (list survivor-route4)))

(define identity4-rhs (identity-context K4 B4-Q))
(define (identity4-cell id cut-id ax-id ax-boundary register)
  (register
   id target-signature4
   (checked4 (raw-app cut-id (raw-app ax-id) raw-hole) B4-Q)
   identity4-rhs
   '(provider) '(provider) identity-B4-Q
   #:port-routings (list survivor-route4)))
(define identity4-a1-cell
  (identity4-cell 'a4-identity-a1 'a4-cut-a1 'a4-ax-1 B4-a1
                  register-left-identity-cut-cell))
(define identity4-a2-cell
  (identity4-cell 'a4-identity-a2 'a4-cut-a2 'a4-ax-2 B4-a2
                  register-left-identity-cut-cell))
(define identity4-a3-cell
  (identity4-cell 'a4-identity-a3 'a4-cut-a3 'a4-ax-3 B4-a3
                  register-left-identity-cut-cell))
(define identity4-a4-cell
  (identity4-cell 'a4-identity-a4 'a4-cut-a4 'a4-ax-4 B4-a4
                  register-left-identity-cut-cell))

(define registry4
  (make-normalization-cell-registry
   target-signature4
   (list principal4-outer-cell principal4-middle-cell principal4-inner-cell
         identity4-a1-cell identity4-a2-cell
         identity4-a3-cell identity4-a4-cell)))

(define principal4-requests
  (list
   (make-normalization-event-request registry4 'a4-stage-principal-1
                                     'a4-principal-outer '())
   (make-normalization-event-request registry4 'a4-stage-principal-2
                                     'a4-principal-middle '(2))
   (make-normalization-event-request registry4 'a4-stage-principal-3
                                     'a4-principal-inner '(2 2))))
(define identity4-requests
  (list
   (make-normalization-event-request registry4 'a4-stage-identity-1
                                     'a4-identity-a1 '(2 2 2))
   (make-normalization-event-request registry4 'a4-stage-identity-2
                                     'a4-identity-a2 '(2 2))
   (make-normalization-event-request registry4 'a4-stage-identity-3
                                     'a4-identity-a3 '(2))
   (make-normalization-event-request registry4 'a4-stage-identity-4
                                     'a4-identity-a4 '())))
(define direct4-requests
  (append
   (for/list ([request (in-list principal4-requests)] [index (in-naturals 1)])
     (make-normalization-event-request
      registry4
      (string->symbol (format "a4-direct-principal-~a" index))
      (normalization-cell-id (normalization-event-request-cell request))
      (normalization-event-request-address request)))
   (for/list ([request (in-list identity4-requests)] [index (in-naturals 1)])
     (make-normalization-event-request
      registry4
      (string->symbol (format "a4-direct-identity-~a" index))
      (normalization-cell-id (normalization-event-request-cell request))
      (normalization-event-request-address request)))))

;; Old target constructors are exact material stock.  The new coarse tensor
;; and par declarations are deliberately not source-old, exposing the positive
;; provenance-reclassification sector rather than silently relabelling them.
(define B4-source
  (make-material-profile
   K4 (list ax4-1-occ ax4-2-occ ax4-3-occ ax4-4-occ
            q4-leaf-occ q4-wrap-occ coarse4-cut-occ)))
(define B4-target
  (make-material-profile
   K4
   (list ax4-1-occ ax4-2-occ ax4-3-occ ax4-4-occ
         q4-leaf-occ q4-wrap-occ q4-alt-leaf-occ q4-alt-wrap-occ
         tensor4-12-occ tensor4-123-occ tensor4-1234-occ
         par4-12-occ par4-123-occ par4-1234-occ
         cut4-top-occ cut4-123-occ cut4-12-occ
         cut4-a1-occ cut4-a2-occ cut4-a3-occ cut4-a4-occ)))

;; Native positive macro interpretations of every constructor used by the
;; coarse source.  Every source physical port occurs exactly once.
(define coarse-cut-macro
  (compile-macro-summary
   K4 (checked4 (raw-app 'a4-cut-top raw-hole raw-hole) B4-Q)
   (list (make-macro-port 'tensor B4-t1234)
         (make-macro-port 'par B4-p1234))
   (list (cons '(1) 'tensor) (cons '(2) 'par))))
(define coarse-tensor-macro
  (compile-macro-summary
   K4
   (checked4
    (raw-app 'a4-tensor-1234
             (raw-app 'a4-tensor-123
                      (raw-app 'a4-tensor-12 raw-hole raw-hole)
                      raw-hole)
             raw-hole)
    B4-t1234)
   (list (make-macro-port 'p1 B4-a1)
         (make-macro-port 'p2 B4-a2)
         (make-macro-port 'p3 B4-a3)
         (make-macro-port 'p4 B4-a4))
   (list (cons '(1 1 1) 'p1) (cons '(1 1 2) 'p2)
         (cons '(1 2) 'p3) (cons '(2) 'p4))))
(define coarse-par-macro
  (compile-macro-summary
   K4
   (checked4
    (raw-app 'a4-par-1234
             (raw-app 'a4-par-123
                      (raw-app 'a4-par-12 raw-hole)))
    B4-p1234)
   (list (make-macro-port 'provider B4-Q))
   (list (cons '(1 1 1) 'provider))))
(define q-wrap-macro
  (compile-macro-summary
   K4 (checked4 (raw-app 'a4-q-wrap raw-hole) B4-Q)
   (list (make-macro-port 'q-body B4-Q))
   (list (cons '(1) 'q-body))))
(define (nullary-macro raw boundary)
  (compile-macro-summary K4 (checked4 raw boundary) '() '()))

(define interpretations4
  (list
   (make-normalization-macro-interpretation
    K4 coarse4-cut-occ coarse-cut-macro '(tensor par))
   (make-normalization-macro-interpretation
    K4 coarse4-tensor-occ coarse-tensor-macro '(p1 p2 p3 p4))
   (make-normalization-macro-interpretation
    K4 coarse4-par-occ coarse-par-macro '(provider))
   (make-normalization-macro-interpretation
    K4 ax4-1-occ (nullary-macro (raw-app 'a4-ax-1) B4-a1) '())
   (make-normalization-macro-interpretation
    K4 ax4-2-occ (nullary-macro (raw-app 'a4-ax-2) B4-a2) '())
   (make-normalization-macro-interpretation
    K4 ax4-3-occ (nullary-macro (raw-app 'a4-ax-3) B4-a3) '())
   (make-normalization-macro-interpretation
    K4 ax4-4-occ (nullary-macro (raw-app 'a4-ax-4) B4-a4) '())
   (make-normalization-macro-interpretation
    K4 q4-wrap-occ q-wrap-macro '(q-body))
   (make-normalization-macro-interpretation
    K4 q4-leaf-occ (nullary-macro (raw-app 'a4-q-leaf) B4-Q) '())))

(define elaboration4
  (compile-positive-normalization-elaboration
   coarse4-source expanded4-source interpretations4 target-signature4
   #:source-profile B4-source #:target-profile B4-target))
(check-true (positive-normalization-elaboration? elaboration4))
(check-equal?
 (positive-normalization-elaboration-positive-provenance-reclassification-addresses
  elaboration4)
 '((1) (2)))
(check-false
 (positive-normalization-elaboration-local-base-fidelity? elaboration4))

(define initial4-frontier (make-cut-witness expanded4-source '((2))))
(define principal4-certificate
  (compile-normalization-replay
   expanded4-source initial4-frontier registry4 principal4-requests
   #:material-profile B4-target #:polynomial-term-cap 128))
(check-true (normalization-replay-certificate? principal4-certificate))
(check-equal?
 (map normalization-potential-A
      (normalization-replay-certificate-potentials principal4-certificate))
 '(7 6 5 4))

(define principal4-target
  (normalization-replay-certificate-target principal4-certificate))
(check-equal? principal4-target coarse4-principal-target)
(define identity4-frontier
  (make-cut-witness principal4-target '((2 2 2 2))))
(define identity4-certificate
  (compile-normalization-replay
   principal4-target identity4-frontier registry4 identity4-requests
   #:material-profile B4-target #:polynomial-term-cap 128))
(check-true (normalization-replay-certificate? identity4-certificate))

(define direct4-certificate
  (compile-normalization-replay
   expanded4-source initial4-frontier registry4 direct4-requests
   #:material-profile B4-target #:polynomial-term-cap 128))
(check-true (normalization-replay-certificate? direct4-certificate))
(check-equal?
 (map normalization-potential-A
      (normalization-replay-certificate-potentials direct4-certificate))
 '(7 6 5 4 3 2 1 0))
(define psi4-sequence
  (map normalization-potential-psi
       (normalization-replay-certificate-potentials direct4-certificate)))
(check-true
 (for/and ([before (in-list psi4-sequence)]
           [after (in-list (cdr psi4-sequence))])
   (> before after)))
(check-true
 (andmap (lambda (potential) (= (normalization-potential-M potential) 1))
         (normalization-replay-certificate-potentials direct4-certificate)))

(define (count-active proof occurrences)
  (for/sum ([address (in-list (vertex-addresses proof))])
    (if (memq (checked-node-occurrence (vertex-at-address proof address))
              occurrences)
        1 0)))
(define coarse-active-occurrences
  (list coarse4-cut-occ coarse4-tensor-occ coarse4-par-occ
        cut4-a1-occ cut4-a2-occ cut4-a3-occ cut4-a4-occ))
(check-equal? (count-active coarse4-source coarse-active-occurrences) 3)
(check-equal?
 (count-active coarse4-principal-target coarse-active-occurrences) 4)

(define compositional4
  (certify-compositional-normalization
   elaboration4 principal4-certificate identity4-certificate
   direct4-certificate))
(check-true (compositional-normalization-certificate? compositional4))
(check-true
 (compositional-normalization-certificate-interface-agreement?
  compositional4))
(check-true
 (normalization-collapse-analysis-join-equal?
  (compositional-normalization-certificate-collapse-analysis
   compositional4)))
(check-equal?
 (compositional-normalization-certificate-pullback-potential compositional4)
 (first (normalization-replay-certificate-potentials direct4-certificate)))
(define missing-potential-summary
  (pullback-normalization-potential Q4-prime elaboration4))
(check-true (normalization-replay-failure? missing-potential-summary))
(check-equal? (normalization-replay-failure-code missing-potential-summary)
              'missing-potential-summary)
(check-equal?
 (compositional-normalization-certificate-empty-proper-convention
  compositional4)
 'empty+proper)
(check-equal?
 (compositional-normalization-certificate-whole-endpoint-weight
  compositional4)
 1)
(check-equal?
 (compositional-normalization-certificate-opaque-interior-inspections
  compositional4)
 0)
(check-true
 (normalization-check-report-valid?
  (check-compositional-normalization-certificate compositional4)))

;; Dead marked classes survive the staged pushout even though Q alone is live.
(define direct4-interface
  (compositional-normalization-certificate-direct-interface compositional4))
(define direct4-live-classes
  (remove-duplicates
   (hash-values (normalization-causal-interface-live-origins
                 direct4-interface))
   equal?))
(check-true
 (for/or ([marked
           (in-list
            (normalization-causal-interface-marked-classes direct4-interface))])
   (not (member marked direct4-live-classes equal?))))

;; Equal source partitions do not license a forged/swapped live map.
(define principal4-interface
  (compositional-normalization-certificate-principal-interface
   compositional4))
(define distinct-live-pair
  (for*/first ([(left-address left-origin)
                (in-hash
                 (normalization-causal-interface-live-origins
                  principal4-interface))]
               [(right-address right-origin)
                (in-hash
                 (normalization-causal-interface-live-origins
                  principal4-interface))]
               #:when (not (equal? left-origin right-origin)))
    (list left-address left-origin right-address right-origin)))
(check-not-false distinct-live-pair)
(define forged-principal4-interface
  (struct-copy
   normalization-causal-interface principal4-interface
   [live-origins
    (hash-set
     (hash-set
      (normalization-causal-interface-live-origins principal4-interface)
      (first distinct-live-pair) (fourth distinct-live-pair))
     (third distinct-live-pair) (second distinct-live-pair))]))
(define forged-composition4
  (compose-normalization-causal-interfaces
   forged-principal4-interface
   (compositional-normalization-certificate-identity-interface
    compositional4)))
(check-true (normalization-replay-failure? forged-composition4))
(check-equal? (normalization-replay-failure-code forged-composition4)
              'forged-prefix-causal-interface)

;; Source-aligned Q is an independently guarded and literally opaque region;
;; both native source and expanded anchor cuts retain ordered tuples/remainders
;; and reconstruct exactly.  The root remains only the separate whole endpoint.
(define source-Q4-certificate
  (certify-source-aligned-frontier compositional4 '((2 1))))
(check-true (source-aligned-frontier-certificate?
             source-Q4-certificate))
(check-true (source-aligned-frontier-certificate-guarded?
             source-Q4-certificate))
(check-true (source-aligned-frontier-certificate-opaque?
             source-Q4-certificate))
(check-equal?
 (source-aligned-frontier-certificate-expanded-addresses
  source-Q4-certificate)
 '((2 1 1 1)))
(check-equal?
 (source-aligned-frontier-certificate-source-refill source-Q4-certificate)
 coarse4-source)
(check-equal?
 (source-aligned-frontier-certificate-expanded-refill source-Q4-certificate)
 expanded4-source)
(check-true
 (and (cut-witness-reconstructs?
       (source-aligned-frontier-certificate-source-witness
        source-Q4-certificate))
      (cut-witness-reconstructs?
       (source-aligned-frontier-certificate-expanded-witness
        source-Q4-certificate))))
(check-true (cut-error? (make-cut-witness coarse4-source (list root-address))))

;; A second checked provider replays through all seven steps without any
;; post-admission interior read and survives by exact object identity.
(define replay4
  (replay-compiled-normalization
   (normalization-replay-certificate-compiled-history direct4-certificate)
   (list Q4-prime)))
(check-true (normalization-replay-result? replay4))
(check-eq? (normalization-replay-result-target replay4) Q4-prime)
(check-equal?
 (normalization-replay-result-opaque-interior-inspections replay4)
 0)

;; Independent bounded source-cut oracle.  It checks the pulled recurrence and
;; concrete source-aligned certificates, but is not the universal theorem.
(define source4-native-object-count 0)
(define source4-guarded-object-count 0)
(for ([witness (in-admissible-cut-witnesses coarse4-source)])
  (set! source4-native-object-count (add1 source4-native-object-count))
  (define aligned
    (certify-source-aligned-frontier
     compositional4 (cut-witness-addresses witness)))
  (check-true (source-aligned-frontier-certificate? aligned))
  (when (source-aligned-frontier-certificate-guarded? aligned)
    (set! source4-guarded-object-count (add1 source4-guarded-object-count))))
(define source4-fold
  (normalization-collapse-analysis-guarded-fold
   (compositional-normalization-certificate-collapse-analysis
    compositional4)))
(check-equal? source4-guarded-object-count
              (guarded-cut-fold-empty-and-proper-count source4-fold))

;; --------------------------------------------------------------------------
;; Checked nonidentity contextual routing with bounded backtracking.

(define route-child-boundary (one-sided 'p 'p))
(define route-output-boundary (one-sided 'p))
(define route-left-boundary (one-sided 'u))
(define route-right-boundary (one-sided 'v))

(define (route-incidence premises conclusion)
  (make-component-incidence
   premises conclusion
   (for/list ([slot (in-range 1 (add1 (length premises)))])
     (make-component-edge slot 1 1))))
(define (route-occurrence id premises conclusion tag instance incidence)
  (make-concrete-occurrence
   id premises conclusion #:tag tag #:instance instance
   #:incidence incidence))

(define route-U-occ
  (route-occurrence 'route-U '() route-left-boundary 'route-atom 'U
                    (route-incidence '() route-left-boundary)))
(define route-V-occ
  (route-occurrence 'route-V '() route-right-boundary 'route-atom 'V
                    (route-incidence '() route-right-boundary)))
(define route-W-occ
  (route-occurrence 'route-W '() route-child-boundary 'route-quote 'W
                    (route-incidence '() route-child-boundary)))
(define route-cut-occ
  (route-occurrence
   'route-cut (list route-left-boundary route-right-boundary)
   route-child-boundary 'route-cut 'cut
   (route-incidence (list route-left-boundary route-right-boundary)
                    route-child-boundary)))
(define inner-before-occ
  (route-occurrence
   'route-inner-before (list route-child-boundary) route-child-boundary
   'route-inner 'same-inner-side-condition
   (route-incidence (list route-child-boundary) route-child-boundary)))
(define inner-after-id-occ
  (route-occurrence
   'route-inner-after-id (list route-child-boundary) route-child-boundary
   'route-inner 'same-inner-side-condition
   (route-incidence (list route-child-boundary) route-child-boundary)))
(define inner-after-swap-occ
  (route-occurrence
   'route-inner-after-swap (list route-child-boundary) route-child-boundary
   'route-inner 'same-inner-side-condition
   (route-incidence (list route-child-boundary) route-child-boundary)))
(define outer-before-occ
  (route-occurrence
   'route-outer-before (list route-child-boundary) route-output-boundary
   'route-outer 'same-outer-side-condition
   (route-incidence (list route-child-boundary) route-output-boundary)))
(define outer-after-occ
  (route-occurrence
   'route-outer-after (list route-child-boundary) route-output-boundary
   'route-outer 'same-outer-side-condition
   (route-incidence (list route-child-boundary) route-output-boundary)))

(define K-route
  (make-equipped-calculus
   (list route-U-occ route-V-occ route-W-occ route-cut-occ
         inner-before-occ inner-after-id-occ inner-after-swap-occ
         outer-before-occ outer-after-occ)))
(define route-signature
  (make-normalization-signature K-route (list route-cut-occ) '() '() 1))
(define (checked-route raw expected)
  (define result (validate-candidate K-route raw #:expected expected))
  (check-true (checked-term? result))
  result)
(define route-lhs
  (checked-route (raw-app 'route-cut
                          (raw-app 'route-U) (raw-app 'route-V))
                 route-child-boundary))
(define route-rhs (checked-route (raw-app 'route-W) route-child-boundary))
(define route-positions
  (boundary-formula-occurrences route-child-boundary))
(define swap-formula-route
  (make-exact-boundary-routing
   route-child-boundary route-child-boundary
   (list (cons (first route-positions) (second route-positions))
         (cons (second route-positions) (first route-positions)))))
(define route-cell
  (register-atomic-root-pair-quote-cell
   'route-local-swap route-signature route-lhs route-rhs
   swap-formula-route))
(define route-source
  (checked-route
   (raw-app 'route-outer-before
            (raw-app 'route-inner-before
                     (checked-term->raw route-lhs)))
   route-output-boundary))

(define route-component-child
  (identity-component-routing route-child-boundary))
(define route-component-output
  (identity-component-routing route-output-boundary))
(define inner-source-positions
  (boundary-formula-occurrences route-child-boundary))
(define inner-target-positions
  (boundary-formula-occurrences route-child-boundary))
(define output-position (first (boundary-formula-occurrences
                                route-output-boundary)))

(define inner-before-equipment
  (make-normalization-rule-equipment
   K-route inner-before-occ
   (list
    (make-equipped-formula-edge inner-before-occ 1
                                (first inner-source-positions)
                                (first inner-target-positions))
    (make-equipped-formula-edge inner-before-occ 1
                                (second inner-source-positions)
                                (second inner-target-positions)))
   (list (make-normalization-principal-mark
          inner-before-occ 'principal (first inner-target-positions)))))
(define inner-after-id-equipment
  (make-normalization-rule-equipment
   K-route inner-after-id-occ
   (list
    (make-equipped-formula-edge inner-after-id-occ 1
                                (second inner-source-positions)
                                (first inner-target-positions))
    (make-equipped-formula-edge inner-after-id-occ 1
                                (first inner-source-positions)
                                (second inner-target-positions)))
   (list (make-normalization-principal-mark
          inner-after-id-occ 'principal (first inner-target-positions)))))
(define inner-after-swap-equipment
  (make-normalization-rule-equipment
   K-route inner-after-swap-occ
   (list
    (make-equipped-formula-edge inner-after-swap-occ 1
                                (second inner-source-positions)
                                (second inner-target-positions))
    (make-equipped-formula-edge inner-after-swap-occ 1
                                (first inner-source-positions)
                                (first inner-target-positions)))
   (list (make-normalization-principal-mark
          inner-after-swap-occ 'principal (second inner-target-positions)))))
(define outer-before-equipment
  (make-normalization-rule-equipment
   K-route outer-before-occ
   (list (make-equipped-formula-edge outer-before-occ 1
                                     (first inner-source-positions)
                                     output-position))
   (list (make-normalization-principal-mark
          outer-before-occ 'principal output-position))))
(define outer-after-equipment
  (make-normalization-rule-equipment
   K-route outer-after-occ
   (list (make-equipped-formula-edge outer-after-occ 1
                                     (second inner-source-positions)
                                     output-position))
   (list (make-normalization-principal-mark
          outer-after-occ 'principal output-position))))

(define inner-id-lift
  (register-normalization-ancestor-lift
   'inner-local-choice-that-dead-ends K-route
   inner-before-equipment inner-after-id-equipment 1 '(1)
   (list swap-formula-route)
   (identity-boundary-routing route-child-boundary)
   (list route-component-child) route-component-child))
(define inner-swap-lift
  (register-normalization-ancestor-lift
   'inner-backtracked-choice K-route
   inner-before-equipment inner-after-swap-equipment 1 '(1)
   (list swap-formula-route) swap-formula-route
   (list route-component-child) route-component-child))
(define outer-swap-lift
  (register-normalization-ancestor-lift
   'outer-selective-conjugate K-route
   outer-before-equipment outer-after-equipment 1 '(1)
   (list swap-formula-route)
   (identity-boundary-routing route-output-boundary)
   (list route-component-child) route-component-output))
(define routing-registry
  (make-normalization-routing-registry
   K-route (list inner-id-lift inner-swap-lift outer-swap-lift)
   #:search-limit 8))
(define routed-certificate
  (certify-contextual-normalization-event
   route-source route-cell '(1 1) routing-registry route-component-child))
(check-true (contextual-routing-certificate? routed-certificate))
(check-equal?
 (map normalization-ancestor-lift-id
      (contextual-routing-certificate-ancestor-chain routed-certificate))
 '(inner-backtracked-choice outer-selective-conjugate))
(check-true (>= (contextual-routing-certificate-examined-candidates
                 routed-certificate)
                3))
(check-eq?
 (checked-node-occurrence
  (contextual-routing-certificate-target routed-certificate))
 outer-after-occ)
(check-true (check-contextual-routing-certificate routed-certificate))

;; Boundary equality cannot fabricate the absent selective conjugate.
(define unavailable-routing-registry
  (make-normalization-routing-registry K-route (list inner-id-lift)
                                       #:search-limit 8))
(define unavailable-route
  (certify-contextual-normalization-event
   route-source route-cell '(1 1) unavailable-routing-registry
   route-component-child))
(check-true (normalization-replay-failure? unavailable-route))
(check-equal? (normalization-replay-failure-code unavailable-route)
              'routing-lift-unavailable)
(check-equal?
 (hash-ref (normalization-replay-failure-details unavailable-route)
           'missing-ancestor-address)
 root-address)
(check-eq?
 (hash-ref (normalization-replay-failure-details unavailable-route)
           'missing-occurrence)
 outer-before-occ)

;; Exhausting the bounded backtracking budget is inconclusive, never an
;; assertion that a compatible route is absent.
(define limited-routing-registry
  (make-normalization-routing-registry
   K-route (list inner-id-lift inner-swap-lift outer-swap-lift)
   #:search-limit 1))
(define limited-route
  (certify-contextual-normalization-event
   route-source route-cell '(1 1) limited-routing-registry
   route-component-child))
(check-true (normalization-replay-failure? limited-route))
(check-equal? (normalization-replay-failure-code limited-route)
              'routing-lift-inconclusive)

;; Transparent analysis records do not bypass their checked makers.
(define forged-inner-lift
  (struct-copy
   normalization-ancestor-lift inner-swap-lift
   [before
    (struct-copy normalization-rule-equipment inner-before-equipment
                 [side-condition-evidence 'forged])]))
(check-exn
 exn:fail?
 (lambda ()
   (make-normalization-routing-registry K-route (list forged-inner-lift))))

(displayln
 (format
  "normalization-replay: base replay plus arity-four elaboration, causal pushout, collapse pullback, opaque replay, and contextual routing passed (~a + ~a native source cuts checked)"
  oracle-witness-count source4-native-object-count))
