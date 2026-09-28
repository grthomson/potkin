#lang racket/base

(require rackunit
         racket/list
         "../potkin/main.rkt"
         "../potkin/analysis/atomic-cycle-ck.rkt")

(define certificate (certify-atomic-four-cycle #:limit 64))
(check-true (atomic-cycle-ck-certificate? certificate))
(check-true (atomic-cycle-ck-certificate-verified? certificate))
(define fixture (atomic-cycle-ck-certificate-fixture certificate))
(define calculus (atomic-four-cycle-fixture-calculus fixture))
(define request (atomic-four-cycle-fixture-request fixture))
(define generators (atomic-four-cycle-fixture-generators fixture))
(define source (atomic-four-cycle-fixture-source fixture))
(define comb (atomic-four-cycle-fixture-comb fixture))
(define balanced (atomic-four-cycle-fixture-balanced fixture))

;; One immutable exact registry admits all four generators, five genuine Com
;; instances, and the concrete four-premise R4 occurrence.
(check-equal? (calculus-size calculus) 10)
(check-equal? (length generators) 4)
(check-equal?
 (map atomic-generator-id generators)
 '(g1 g2 g3 g4))
(for ([proof (in-list (append
                       (atomic-four-cycle-fixture-generator-proofs fixture)
                       (list source comb balanced)))])
  (check-true (complete-proof? proof))
  (check-true (checked-term-has-exact-calculus? proof calculus)))
(check-eq? (checked-node-occurrence source)
           (atomic-four-cycle-fixture-r4-occurrence fixture))
(check-equal? (length (checked-node-children source)) 4)
(check-equal? (derivation-root-boundary source) request)
(check-equal? (derivation-root-boundary comb) request)
(check-equal? (derivation-root-boundary balanced) request)

;; Full base: SCC cycle, preserved generator IDs, and native comb quotation.
(define decision (atomic-four-cycle-fixture-decision fixture))
(check-equal? (atomic-preorder-result-status decision) 'valid-quoted)
(check-equal? (atomic-preorder-result-proof decision) comb)
(define signed-cycle (atomic-preorder-result-cycle decision))
(check-true (atomic-signed-cycle? signed-cycle))
(check-equal?
 (append-map
  (lambda (path)
    (map (lambda (edge)
           (atomic-generator-id (atomic-cycle-edge-evidence edge)))
         (atomic-base-path-edges path)))
  (atomic-signed-cycle-base-paths signed-cycle))
 '(g1 g2 g3 g4))

;; Removing any one base generator yields a checked finite rank model.
(define removals (atomic-cycle-ck-certificate-removals certificate))
(check-equal? (length removals) 4)
(for ([removal (in-list removals)])
  (check-true (atomic-removal-certificate-verified? removal))
  (define removal-decision (atomic-removal-certificate-decision removal))
  (check-equal? (atomic-preorder-result-status removal-decision)
                'invalid-countervaluation)
  (define valuation
    (atomic-preorder-result-countervaluation removal-decision))
  (check-true (atomic-countervaluation-verifies? valuation))
  (check-true (hash? (atomic-countervaluation-ranks valuation))))

(define source-audit (atomic-cycle-ck-certificate-source-coaction certificate))
(define comb-certificate (atomic-cycle-ck-certificate-comb certificate))
(define balanced-certificate (atomic-cycle-ck-certificate-balanced certificate))

(define (check-transport target-certificate expected-target-addresses)
  (define transport (atomic-target-ck-certificate-transport target-certificate))
  (check-equal? (atomic-cut-transport-classification transport) 'inherited)
  (check-true (atomic-cut-transport-verified? transport))
  (check-equal?
   (cut-witness-addresses (atomic-cut-transport-source-witness transport))
   '((1) (2) (3) (4)))
  (check-equal?
   (cut-witness-addresses (atomic-cut-transport-target-witness transport))
   expected-target-addresses)
  (check-equal? (atomic-cut-transport-source-holes transport)
                '((1) (2) (3) (4)))
  (check-equal? (atomic-cut-transport-target-holes transport)
                expected-target-addresses)
  (check-equal? (atomic-cut-transport-source-refill transport) source)
  (check-equal? (atomic-cut-transport-target-refill transport)
                (atomic-target-ck-certificate-proof target-certificate))
  (check-equal?
   (map detached-entry-address
        (cut-witness-detached
         (atomic-cut-transport-target-witness transport)))
   expected-target-addresses))

(check-transport comb-certificate '((1 1 1) (1 1 2) (1 2) (2)))
(check-transport balanced-certificate '((1 1) (1 2) (2 1) (2 2)))

;; Every one of the 16 source ordinary witnesses has an exact target witness.
;; The left forests agree natively; both typed remainders refill independently.
(for ([target-certificate (in-list (list comb-certificate
                                         balanced-certificate))])
  (define matches
    (atomic-target-ck-certificate-witness-matches target-certificate))
  (check-equal? (length matches) 16)
  (for ([match (in-list matches)])
    (check-true (atomic-witness-match-detached-forest-equal? match))
    (check-true (atomic-witness-match-source-refills? match))
    (check-true (atomic-witness-match-target-refills? match))
    (define source-contribution
      (atomic-witness-match-source-contribution match))
    (define target-contribution
      (atomic-witness-match-target-contribution match))
    (check-true (material-witness-contribution? source-contribution))
    (check-true (material-witness-contribution? target-contribution))
    (check-true
     (positive?
      (formal-sum-coefficient
       (atomic-coaction-audit-coaction source-audit)
       (material-contribution-tensor source-contribution))))
    (check-true
     (positive?
      (formal-sum-coefficient
       (atomic-coaction-audit-coaction
        (atomic-target-ck-certificate-coaction target-certificate))
       (material-contribution-tensor target-contribution))))))

;; Full-support proper cuts: one inherited leaf frontier plus the new native
;; block frontiers.  The whole endpoint has no witness and is not included.
(check-equal?
 (length (atomic-target-ck-certificate-full-support-witnesses
          comb-certificate))
 3)
(check-equal?
 (length (atomic-target-ck-certificate-new-full-support-witnesses
          comb-certificate))
 2)
(check-equal?
 (length (atomic-target-ck-certificate-full-support-witnesses
          balanced-certificate))
 4)
(check-equal?
 (length (atomic-target-ck-certificate-new-full-support-witnesses
          balanced-certificate))
 3)
(for ([target-certificate (in-list (list comb-certificate
                                         balanced-certificate))])
  (define top
    (atomic-target-ck-certificate-top-child-block-witness
     target-certificate))
  (check-true (cut-witness? top))
  (check-equal? (cut-witness-addresses top) '((1) (2)))
  (check-true (cut-witness-reconstructs? top))
  (check-equal?
   (atomic-target-ck-certificate-top-child-refill target-certificate)
   (atomic-target-ck-certificate-proof target-certificate)))

;; Exact old-base coactions, with endpoint classes kept separate.
(define comb-audit (atomic-target-ck-certificate-coaction comb-certificate))
(define balanced-audit
  (atomic-target-ck-certificate-coaction balanced-certificate))
(for ([audit (in-list (list source-audit comb-audit balanced-audit))])
  (check-true (atomic-coaction-audit-equal? audit))
  (check-equal? (atomic-coaction-audit-coaction audit)
                (atomic-coaction-audit-reconstructed audit))
  (check-equal? (atomic-coaction-audit-coefficient-mass audit)
                (material-query-result-coefficient
                 (atomic-coaction-audit-result audit))))
(check-equal?
 (map (lambda (audit)
        (material-query-result-coefficient
         (atomic-coaction-audit-result audit)))
      (list source-audit comb-audit balanced-audit))
 '(16 23 26))
(check-equal?
 (map (lambda (audit)
        (list (length (atomic-coaction-audit-empty-contributions audit))
              (length (atomic-coaction-audit-proper-contributions audit))
              (length (atomic-coaction-audit-whole-contributions audit))))
      (list source-audit comb-audit balanced-audit))
 '((1 15 0) (1 21 1) (1 24 1)))
(check-equal? (atomic-target-ck-certificate-full-excess comb-certificate) 7)
(check-equal?
 (atomic-target-ck-certificate-full-excess balanced-certificate) 10)
(check-equal?
 (length (atomic-target-ck-certificate-new-contributions comb-certificate))
 7)
(check-equal?
 (length (atomic-target-ck-certificate-new-contributions
          balanced-certificate))
 10)

;; Positive quotation coverage beyond R4: a two-edge path uses a concrete
;; atomic Cut, then a genuine external weakening adds the passive request.
(define A 'quote-a)
(define B 'quote-b)
(define C 'quote-c)
(define P 'quote-p)
(define Q 'quote-q)
(define AB (singleton-hypersequent (list A) (list B)))
(define BC (singleton-hypersequent (list B) (list C)))
(define AC (singleton-hypersequent (list A) (list C)))
(define AA (singleton-hypersequent (list A) (list A)))
(define PQ (make-sequent (list P) (list Q)))
(define AC+PQ
  (make-hypersequent (list (car (hypersequent-sequents AC)) PQ)))
(define qab
  (make-concrete-occurrence 'quote-ab '() AB #:instance '(base quote-ab)))
(define qbc
  (make-concrete-occurrence 'quote-bc '() BC #:instance '(base quote-bc)))
(define qid
  (make-concrete-occurrence 'quote-id-a '() AA #:instance '(identity quote-a)))
(define qcut
  (make-concrete-occurrence
   'quote-cut-ab-bc (list AB BC) AC #:instance '(gentzen-cut quote-b)))
(define qweak
  (make-concrete-occurrence
   'quote-ew-pq (list AC) AC+PQ #:instance '(external-weakening quote-pq)))
(define quote-calculus
  (make-equipped-calculus (list qab qbc qid qcut qweak)))
(define quote-generators
  (list (make-atomic-generator quote-calculus 'qab A B qab)
        (make-atomic-generator quote-calculus 'qbc B C qbc)))
(define quote-kit
  (make-atomic-quotation-kit
   quote-calculus
   (list (make-atomic-identity-instance quote-calculus A qid))
   (list (make-atomic-cut-instance quote-calculus A B C qcut))
   '()
   (list (make-atomic-weakening-instance quote-calculus qweak PQ))))
(define cut+weak-decision
  (decide-atomic-preorder
   quote-calculus quote-generators AC+PQ
   #:quotation-kit quote-kit #:limit 128))
(check-equal? (atomic-preorder-result-status cut+weak-decision) 'valid-quoted)
(check-true (complete-proof? (atomic-preorder-result-proof cut+weak-decision)))
(check-equal?
 (derivation-root-boundary (atomic-preorder-result-proof cut+weak-decision))
 AC+PQ)
(define identity-decision
  (decide-atomic-preorder
   quote-calculus '() AA #:quotation-kit quote-kit #:limit 64))
(check-equal? (atomic-preorder-result-status identity-decision) 'valid-quoted)
(check-eq? (checked-node-occurrence
            (atomic-preorder-result-proof identity-decision))
           qid)

;; Missing quotation evidence never fabricates a proof.
(define empty-kit
  (make-atomic-quotation-kit calculus '() '() '() '()))
(define unavailable
  (decide-atomic-preorder
   calculus generators request #:quotation-kit empty-kit #:limit 256))
(check-equal? (atomic-preorder-result-status unavailable)
              'valid-quotation-unavailable)
(check-false (atomic-preorder-result-proof unavailable))
(check-equal?
 (atomic-quotation-unavailable-reason
  (atomic-preorder-result-quotation-obstruction unavailable))
 'missing-communication-instance)

;; Wrong route is rejected before native quotation.
(define paths (atomic-signed-cycle-base-paths signed-cycle))
(define first-path (car paths))
(define wrong-path
  (struct-copy atomic-base-path first-path [source 'not-the-request-source]))
(define wrong-cycle
  (struct-copy atomic-signed-cycle signed-cycle
               [base-paths (cons wrong-path (cdr paths))]))
(define wrong-route-result
  (quote-atomic-cycle
   calculus generators request wrong-cycle
   (atomic-four-cycle-fixture-quotation-kit fixture)))
(check-true (atomic-quotation-unavailable? wrong-route-result))
(check-equal? (atomic-quotation-unavailable-reason wrong-route-result)
              'wrong-cycle-routing)

;; A claimed Com conclusion that drops its passive component is not genuine.
(define com123
  (second (atomic-four-cycle-fixture-communication-occurrences fixture)))
(define com123-premises
  (vector->list (concrete-occurrence-premises com123)))
(define missing-passive-conclusion
  (make-hypersequent
   (list (make-sequent '(x1) '(y3))
         (make-sequent '(x3) '(y2)))))
(define bad-com
  (make-concrete-occurrence
   'bad-missing-passive-com
   com123-premises
   missing-passive-conclusion
   #:kind 'structural
   #:instance '(bad-com missing-passive)))
(define bad-calculus (make-equipped-calculus (list bad-com)))
(check-exn
 exn:fail?
 (lambda ()
   (make-atomic-com-instance bad-calculus bad-com 1 1)))

;; Foreign provenance, root cuts, graph limits, and CK-enumeration limits are
;; rejected or explicitly inconclusive.
(define clone-calculus
  (make-equipped-calculus (calculus-occurrences calculus)))
(define foreign-generators
  (for/list ([generator (in-list generators)])
    (make-atomic-generator
     clone-calculus
     (atomic-generator-id generator)
     (atomic-generator-source generator)
     (atomic-generator-target generator)
     (atomic-generator-occurrence generator))))
(check-exn
 exn:fail?
 (lambda ()
   (decide-atomic-preorder
    calculus foreign-generators request #:limit 256)))
(define fabricated-root (make-cut-witness balanced (list root-address)))
(check-true (cut-error? fabricated-root))
(check-equal? (cut-error-code fabricated-root) 'root-cut)
(define graph-truncated
  (decide-atomic-preorder calculus generators request #:limit 0))
(check-true (analysis-limit? graph-truncated))
(check-equal? (analysis-limit-metric graph-truncated) 'atomic-graph-work)
(define ck-truncated (certify-atomic-four-cycle #:limit 1))
(check-true (analysis-limit? ck-truncated))
(check-equal? (analysis-limit-metric ck-truncated)
              'ordinary-witness-count)

(displayln
 "atomic-cycle-ck: SCC/countermodels, native quotation, inherited/new CK witnesses, exact old-base coactions, and rejection checks passed")
