#lang racket/base

(require rackunit
         racket/list
         "../potkin/main.rkt")

(define (boundary tag)
  (make-hypersequent
   (list (make-sequent (list tag) (list (string->symbol
                                         (format "~a-out" tag)))))))

(define (occurrence id premises conclusion kind)
  (make-concrete-occurrence
   id premises conclusion
   #:kind kind
   #:tag 'base-replacement-fixture
   #:instance (list 'fixture id)
   #:incidence (make-component-incidence premises conclusion '())))

(define (ground id conclusion kind)
  (occurrence id '() conclusion kind))

(define leaf-boundary (boundary 'leaf))
(define first-boundary (boundary 'first))
(define second-boundary (boundary 'second))
(define pair-boundary (boundary 'pair))
(define final-boundary (boundary 'final))

;; Old primitives are exact checked nullaries but deliberately absent from B.
(define old-first-occurrence
  (ground 'replacement-old-first first-boundary 'material))
(define old-second-occurrence
  (ground 'replacement-old-second second-boundary 'material))

;; Q_1 has two equal-looking but physically distinct pure leaves.  A cut at
;; both leaves repeats region 1 and must survive union-mask multiplication.
(define leaf-occurrence
  (ground 'replacement-leaf leaf-boundary 'material))
(define first-Q-occurrence
  (occurrence 'replacement-first-Q
              (list leaf-boundary leaf-boundary)
              first-boundary
              'logical))
(define second-Q-occurrence
  (ground 'replacement-second-Q second-boundary 'material))
(define simple-Q-occurrence
  (ground 'replacement-simple-Q first-boundary 'material))

(define pair-occurrence
  (occurrence 'replacement-pair
              (list first-boundary second-boundary)
              pair-boundary
              'logical))
(define wrapper-occurrence
  (occurrence 'replacement-wrapper
              (list pair-boundary) final-boundary 'logical))

;; This old proof is B-impure at its unary root but has a B-pure child.  It is
;; used only to show why the positive theorem cannot drop nullarity.
(define old-unary-occurrence
  (occurrence 'replacement-old-unary
              (list leaf-boundary) first-boundary 'logical))

(define occurrences
  (list old-first-occurrence old-second-occurrence
        leaf-occurrence first-Q-occurrence second-Q-occurrence
        simple-Q-occurrence pair-occurrence wrapper-occurrence
        old-unary-occurrence))
(define K (make-equipped-calculus occurrences))

(define (checked id expected . children)
  (define result
    (validate-candidate
     K (apply raw-app id (map checked-term->raw children))
     #:expected expected))
  (check-true (checked-node? result))
  result)

(define old-first (checked 'replacement-old-first first-boundary))
(define old-second (checked 'replacement-old-second second-boundary))
(define leaf (checked 'replacement-leaf leaf-boundary))
(define first-Q
  (checked 'replacement-first-Q first-boundary leaf leaf))
(define second-Q (checked 'replacement-second-Q second-boundary))
(define simple-Q (checked 'replacement-simple-Q first-boundary))
(define old-unary
  (checked 'replacement-old-unary first-boundary leaf))

(define context
  (validate-candidate
   K
   (raw-app 'replacement-wrapper
            (raw-app 'replacement-pair raw-hole raw-hole))
   #:expected final-boundary))
(check-true (proof-context? context))
(check-equal? (puncture-addresses context) '((1 1) (1 2)))

(define B-occurrences
  (list leaf-occurrence first-Q-occurrence second-Q-occurrence
        simple-Q-occurrence pair-occurrence wrapper-occurrence))
(define B (make-material-profile K B-occurrences))
(define selector (prepare-material-hopf-selector B))

;; The logical label deliberately repeats.  Physical addresses and bits do not.
(define replacements
  (list
   (make-base-replacement '(1 1) 'shared-port old-first first-Q)
   (make-base-replacement '(1 2) 'shared-port old-second second-Q)))

(define enclosing
  (certify-simultaneous-base-cuts context replacements B #b11 1
                                  #:limit 2048))
(define independent
  (certify-simultaneous-base-cuts context replacements B #b11 2
                                  #:limit 2048))
(define repeated
  (certify-simultaneous-base-cuts context replacements B #b01 2
                                  #:limit 2048))

(for ([certificate (in-list (list enclosing independent repeated))])
  (check-true (simultaneous-base-cut-certificate? certificate))
  (check-true (simultaneous-base-cut-certificate-verified? certificate))
  (check-true (simultaneous-base-cut-certificate-positive? certificate))
  (check-equal? (length
                 (simultaneous-base-cut-certificate-hybrids certificate))
                4)
  (for ([hybrid
         (in-list
          (simultaneous-base-cut-certificate-hybrids certificate))])
    (check-true (complete-proof? (replacement-hybrid-proof hybrid)))
    (check-true
     (checked-term-has-exact-calculus?
      (replacement-hybrid-proof hybrid) K))))

(define regions
  (simultaneous-base-cut-certificate-regions independent))
(check-equal? (map replacement-region-hole-address regions)
              '((1 1) (1 2)))
(check-equal? (map replacement-region-port-label regions)
              '(shared-port shared-port))
(check-equal? (map replacement-region-mask regions) '(1 2))

;; One enclosing factor versus independent factors.  The factor-two
;; coefficient is three because Q_1 offers its root or either pure leaf.
(check-equal? (simultaneous-base-cut-certificate-coefficient enclosing) 1)
(check-equal? (cut-witness-addresses
               (simultaneous-base-cut-certificate-witness enclosing))
              '((1)))
(check-equal? (simultaneous-base-cut-certificate-overlap-kind enclosing)
              'one-factor-enclosing-multiple-regions)

(check-equal? (simultaneous-base-cut-certificate-coefficient independent) 3)
(check-equal? (cut-witness-addresses
               (simultaneous-base-cut-certificate-witness independent))
              '((1 1) (1 2)))
(check-equal? (simultaneous-base-cut-certificate-overlap-kind independent)
              'separate-region-factors)

;; Repeated region marker regression: two incomparable roots in Q_1 remain
;; two detached factors although their union mask is the singleton {1}.
(check-equal? (simultaneous-base-cut-certificate-coefficient repeated) 1)
(check-equal? (cut-witness-addresses
               (simultaneous-base-cut-certificate-witness repeated))
              '((1 1 1) (1 1 2)))
(check-equal? (simultaneous-base-cut-certificate-overlap-kind repeated)
              'general-overlap)
(check-equal?
 (map replacement-factor-overlap-region-mask
      (simultaneous-base-cut-certificate-factor-overlaps repeated))
 '(1 1))
(check-equal?
 (proof-forest-count
  (simultaneous-base-cut-certificate-forest repeated) leaf)
 2)

(define (check-native-certificate certificate)
  (define witness
    (simultaneous-base-cut-certificate-witness certificate))
  (check-true (cut-witness? witness))
  (check-false (member root-address
                       (cut-witness-addresses witness) equal?))
  (check-equal?
   (map detached-entry-address
        (simultaneous-base-cut-certificate-detached certificate))
   (cut-witness-addresses witness))
  (check-equal?
   (puncture-addresses
    (simultaneous-base-cut-certificate-remainder certificate))
   (cut-witness-addresses witness))
  (check-true (cut-witness-reconstructs? witness))
  (check-equal?
   (simultaneous-base-cut-certificate-refill certificate)
   (simultaneous-base-cut-certificate-all-new certificate))
  (check-equal?
   (complete-fill
    (simultaneous-base-cut-certificate-remainder certificate)
    (map detached-entry-term
         (simultaneous-base-cut-certificate-detached certificate)))
   (simultaneous-base-cut-certificate-all-new certificate)))

(for-each check-native-certificate (list enclosing independent repeated))

;; The whole endpoint remains a separate native rank-one projection and has
;; no root-cut witness.  The empty cut is absent from the proper polynomial.
(define whole
  (simultaneous-base-cut-certificate-whole-endpoint independent))
(check-true (formal-sum? whole))
(check-equal? (formal-sum-rank whole) 1)
(check-false (formal-zero? whole))
(check-false
 (hash-has-key?
  (simultaneous-base-cut-certificate-polynomial independent)
  (list 0 0)))

;; --------------------------------------------------------------------------
;; Bounded direct native oracle and four-corner finite difference

(define (bounded-witnesses proof [limit 256])
  (define reversed '())
  (define truncated? #f)
  (for ([witness (in-admissible-cut-witnesses proof)]
        [index (in-range (add1 limit))])
    (if (= index limit)
        (set! truncated? #t)
        (set! reversed (cons witness reversed))))
  (check-false truncated?)
  (reverse reversed))

(define (oracle-factor-mask regions address)
  (for/fold ([mask 0]) ([region (in-list regions)]
                        #:when
                        (or (address-prefix?
                             address
                             (replacement-region-hole-address region))
                            (address-prefix?
                             (replacement-region-hole-address region)
                             address)))
    (bitwise-ior mask (replacement-region-mask region))))

(define (direct-polynomial proof regions selector)
  (for/fold ([polynomial (hash)])
            ([witness (in-list (bounded-witnesses proof))]
             #:when
             (and (pair? (cut-witness-addresses witness))
                  (material-hopf-selector-forest-pure?
                   selector (cut-witness-forest witness))))
    (define mask
      (for/fold ([combined 0])
                ([address (in-list (cut-witness-addresses witness))])
        (bitwise-ior combined (oracle-factor-mask regions address))))
    (hash-update polynomial
                 (list mask (proof-forest-size (cut-witness-forest witness)))
                 add1 0)))

(define production-polynomial
  (simultaneous-base-cut-certificate-polynomial independent))
(define oracle-polynomial
  (direct-polynomial
   (simultaneous-base-cut-certificate-all-new independent)
   regions selector))
(check-equal? production-polynomial oracle-polynomial)
(check-equal? (hash-ref production-polynomial (list #b11 1)) 1)
(check-equal? (hash-ref production-polynomial (list #b11 2)) 3)
(check-equal? (hash-ref production-polynomial (list #b11 3)) 1)

(define (mask-size mask)
  (let loop ([value mask] [count 0])
    (if (zero? value)
        count
        (loop (arithmetic-shift value -1)
              (+ count (bitwise-and value 1))))))

(define (selected-witness-count proof factor-count selector)
  (count
   (lambda (witness)
     (and (= (proof-forest-size (cut-witness-forest witness)) factor-count)
          (material-hopf-selector-forest-pure?
           selector (cut-witness-forest witness))))
   (bounded-witnesses proof)))

(define (four-corner factor-count)
  (for/sum ([hybrid
             (in-list
              (simultaneous-base-cut-certificate-hybrids independent))])
    (define mask (replacement-hybrid-mask hybrid))
    (define sign
      (if (even? (- 2 (mask-size mask))) 1 -1))
    (* sign
       (selected-witness-count
        (replacement-hybrid-proof hybrid) factor-count selector))))

;; At factor zero this is the empty cut, which cancels.  At positive degrees
;; it agrees with the full-region coefficients of the production recurrence.
(check-equal? (four-corner 0) 0)
(for ([factor-count (in-list '(1 2 3))])
  (check-equal?
   (four-corner factor-count)
   (hash-ref production-polynomial (list #b11 factor-count) 0)))

;; --------------------------------------------------------------------------
;; Comparison with the deliberately squarefree occurrence-colour query

(define colour-assignment
  (make-ck-colour-assignment
   K
   (list (cons 'region-1 first-Q-occurrence)
         (cons 'region-1 leaf-occurrence))))
(define coloured
  (query-coloured-ck-cuts
   (simultaneous-base-cut-certificate-all-new independent)
   colour-assignment '(region-1) #:limit 512))
(check-true (coloured-cut-result? coloured))
;; The three one-factor choices agree.  The fourth region-1 cut selects both
;; equal-looking leaves and is intentionally discarded by squarefree colours,
;; but retained by union-mask region semantics.
(check-equal? (coloured-cut-result-coefficient coloured) 3)
(check-equal? (+ (hash-ref production-polynomial (list #b01 1) 0)
                 (hash-ref production-polynomial (list #b01 2) 0))
              4)

;; --------------------------------------------------------------------------
;; Provenance, truncation, and the nullarity boundary of the theorem

(define foreign-K (make-equipped-calculus occurrences))
(define foreign-B (make-material-profile foreign-K B-occurrences))
(define foreign-result
  (certify-simultaneous-base-cuts
   context replacements foreign-B #b11 1 #:limit 64))
(check-true (simultaneous-base-cut-failure? foreign-result))
(check-equal? (simultaneous-base-cut-failure-code foreign-result)
              'foreign-profile)

(define truncated
  (certify-simultaneous-base-cuts
   context replacements B #b11 1 #:limit 0))
(check-true (analysis-limit? truncated))

(define unary-context (identity-context K first-boundary))
(define unary-replacement
  (list (make-base-replacement '() 'unary-old old-unary simple-Q)))
(define unary-rejected
  (certify-simultaneous-base-cuts
   unary-context unary-replacement B #b1 1 #:limit 64))
(check-true (simultaneous-base-cut-failure? unary-rejected))
(check-equal? (simultaneous-base-cut-failure-code unary-rejected)
              'old-not-nullary)
;; Directly outside the contract, new minus old is negative: Q has no proper
;; cut while the impure unary old proof retains its pure-child cut.
(check-equal?
 (- (selected-witness-count simple-Q 1 selector)
    (selected-witness-count old-unary 1 selector))
 -1)

;; --------------------------------------------------------------------------
;; Genuine antecedent-repartition Communication instance

(define (ifo id formula)
  (make-indexed-formula-occurrence id formula))

(define communication-layout
  (make-communication-layout
   '() '()
   (list (ifo 'comm-gamma 'U))
   (list (ifo 'comm-gamma-prime 'V))
   (list (ifo 'comm-lambda 'U))
   (list (ifo 'comm-lambda-prime 'V))
   'R 'R))
(define communication-shape
  (prepare-communication-float-shape
   communication-layout
   (make-communication-iw-action (ifo 'comm-iw 'W) 'gamma)))
(define communication-profile
  (communication-float-shape-target-communication-profile
   communication-shape))
(define communication-premises
  (communication-occurrence-profile-premises communication-profile))
(check-equal? (first communication-premises)
              (second communication-premises))

(define communication-occurrence
  (make-concrete-occurrence
   'replacement-genuine-communication
   communication-premises
   (communication-occurrence-profile-conclusion communication-profile)
   #:kind 'structural
   #:tag (communication-occurrence-profile-role communication-profile)
   #:instance (communication-occurrence-profile-instance communication-profile)
   #:incidence (communication-occurrence-profile-incidence
                communication-profile)))
(check-true (component-incidence?
             (concrete-occurrence-incidence communication-occurrence)))
(check-equal? (concrete-occurrence-incidence communication-occurrence)
              (communication-occurrence-profile-incidence
               communication-profile))
(check-equal? (concrete-occurrence-instance communication-occurrence)
              (communication-occurrence-profile-instance
               communication-profile))

(define communication-hole-boundary (first communication-premises))
(define comm-old-1
  (ground 'replacement-comm-old-1 communication-hole-boundary 'material))
(define comm-old-2
  (ground 'replacement-comm-old-2 communication-hole-boundary 'material))
(define comm-Q-1
  (ground 'replacement-comm-Q-1 communication-hole-boundary 'material))
(define comm-Q-2
  (ground 'replacement-comm-Q-2 communication-hole-boundary 'material))
(define comm-occurrences
  (list communication-occurrence comm-old-1 comm-old-2 comm-Q-1 comm-Q-2))
(define K-comm (make-equipped-calculus comm-occurrences))
(define comm-context
  (validate-candidate
   K-comm
   (raw-app 'replacement-genuine-communication raw-hole raw-hole)
   #:expected
   (communication-occurrence-profile-conclusion communication-profile)))
(check-true (proof-context? comm-context))
(check-equal? (puncture-addresses comm-context) '((1) (2)))

(define (comm-checked id)
  (define proof
    (validate-candidate
     K-comm (raw-app id) #:expected communication-hole-boundary))
  (check-true (checked-node? proof))
  proof)
(define comm-old-proof-1 (comm-checked 'replacement-comm-old-1))
(define comm-old-proof-2 (comm-checked 'replacement-comm-old-2))
(define comm-Q-proof-1 (comm-checked 'replacement-comm-Q-1))
(define comm-Q-proof-2 (comm-checked 'replacement-comm-Q-2))
(define B-comm
  (make-material-profile
   K-comm (list communication-occurrence comm-Q-1 comm-Q-2)))
(define comm-certificate
  (certify-simultaneous-base-cuts
   comm-context
   (list
    (make-base-replacement '(1) 'left-active
                           comm-old-proof-1 comm-Q-proof-1)
    (make-base-replacement '(2) 'right-active
                           comm-old-proof-2 comm-Q-proof-2))
   B-comm #b11 2 #:limit 256))
(check-true (simultaneous-base-cut-certificate? comm-certificate))
(check-true (simultaneous-base-cut-certificate-verified? comm-certificate))
(check-equal? (simultaneous-base-cut-certificate-coefficient comm-certificate)
              1)
(check-equal? (cut-witness-addresses
               (simultaneous-base-cut-certificate-witness comm-certificate))
              '((1) (2)))
(check-equal? (length
               (simultaneous-base-cut-certificate-hybrids comm-certificate))
              4)

(displayln
 "base-replacement-cut: union-mask recurrence, native witnesses, four corners, repeated regions, and genuine Communication passed")
