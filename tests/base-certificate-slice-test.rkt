#lang racket/base

(require rackunit
         racket/list
         "../potkin/main.rkt"
         "../potkin/analysis.rkt")

;; Exact occurrence objects, not their suggestive test names, determine base
;; membership.  All exhaustive traversal below is confined to these tiny
;; falsification fixtures.
(define S (singleton-hypersequent '() '(S)))
(define R (singleton-hypersequent '() '(R)))
(define S0 (make-component-incidence '() S '()))
(define R0 (make-component-incidence '() R '()))

(define a-occ
  (make-concrete-occurrence
   'slice-a '() S #:tag 'same-looking-leaf #:instance 'a #:incidence S0))
(define b-occ
  (make-concrete-occurrence
   'slice-b '() S #:tag 'same-looking-leaf #:instance 'b #:incidence S0))
(define old1-occ
  (make-concrete-occurrence
   'slice-old1 (list S) S #:instance 'protected-unary
   #:incidence 'opaque-slice-incidence))
(define old2-occ
  (make-concrete-occurrence
   'slice-old2 (list S S) S #:instance 'protected-binary
   #:incidence 'opaque-slice-incidence))
(define mid1-occ
  (make-concrete-occurrence
   'slice-mid1 (list S) S #:instance 'middle-unary
   #:incidence 'opaque-slice-incidence))
(define mid-leaf-occ
  (make-concrete-occurrence
   'slice-mid-leaf '() S #:instance 'middle-leaf #:incidence S0))
(define new1-occ
  (make-concrete-occurrence
   'slice-new1 (list S) S #:instance 'extension-unary
   #:incidence 'opaque-slice-incidence))
(define new2-occ
  (make-concrete-occurrence
   'slice-new2 (list S S) S #:instance 'extension-binary
   #:incidence 'opaque-slice-incidence))
(define new-leaf-occ
  (make-concrete-occurrence
   'slice-new-leaf '() S #:instance 'extension-leaf #:incidence S0))
(define wrong-boundary-occ
  (make-concrete-occurrence
   'slice-wrong-boundary '() R #:instance 'wrong-boundary #:incidence R0))

(define occurrences
  (list a-occ b-occ old1-occ old2-occ mid1-occ mid-leaf-occ
        new1-occ new2-occ new-leaf-occ wrong-boundary-occ))
(define calculus (make-equipped-calculus occurrences))

(define (checked raw #:calculus [registry calculus] #:expected [expected S])
  (define result (validate-candidate registry raw #:expected expected))
  (check-false (validation-error? result))
  result)

(define profile-B
  (make-material-profile calculus (list a-occ b-occ old1-occ old2-occ)))
(define profile-C
  (make-material-profile
   calculus
   (list a-occ b-occ old1-occ old2-occ mid1-occ mid-leaf-occ)))
(define profile-D
  (make-material-profile
   calculus
   (list a-occ b-occ old1-occ old2-occ mid1-occ mid-leaf-occ
         new1-occ new2-occ new-leaf-occ)))

(define all-base
  (checked
   (raw-app 'slice-old2
            (raw-app 'slice-old1 (raw-app 'slice-a))
            (raw-app 'slice-old1 (raw-app 'slice-b)))))
(define all-extension
  (checked (raw-app 'slice-new1 (raw-app 'slice-new-leaf))))
(define two-modules
  (checked
   (raw-app 'slice-new2
            (raw-app 'slice-old1 (raw-app 'slice-a))
            (raw-app 'slice-old1 (raw-app 'slice-b)))))
(define ancestor-example
  (checked
   (raw-app 'slice-old2
            (raw-app 'slice-new1
                     (raw-app 'slice-old1 (raw-app 'slice-a)))
            (raw-app 'slice-old1 (raw-app 'slice-b)))))
(define nested-extension
  (checked
   (raw-app 'slice-old2
            (raw-app 'slice-new1
                     (raw-app 'slice-new1
                              (raw-app 'slice-old1 (raw-app 'slice-a))))
            (raw-app 'slice-old1 (raw-app 'slice-b)))))
(define equal-looking-copies
  (checked
   (raw-app 'slice-new2
            (raw-app 'slice-old1 (raw-app 'slice-a))
            (raw-app 'slice-old1 (raw-app 'slice-a)))))

(define all-base-slice (make-base-certificate-slice all-base profile-B))
(define all-extension-slice
  (make-base-certificate-slice all-extension profile-B))
(define two-modules-slice
  (make-base-certificate-slice two-modules profile-B))
(define ancestor-slice
  (make-base-certificate-slice ancestor-example profile-B))
(define nested-slice
  (make-base-certificate-slice nested-extension profile-B))
(define equal-copies-slice
  (make-base-certificate-slice equal-looking-copies profile-B))

(define slices
  (list all-base-slice all-extension-slice two-modules-slice
        ancestor-slice nested-slice equal-copies-slice))

(define (mark-at slice address)
  (findf (lambda (mark)
           (equal? (base-occurrence-mark-address mark) address))
         (base-certificate-slice-classification slice)))

(define (slice-native-addresses slice)
  (if (eq? (base-certificate-slice-kind slice) 'whole)
      '()
      (cut-witness-addresses (base-certificate-slice-witness slice))))

;; Shared provenance, classification and max-choice checks.
(for ([slice (in-list slices)])
  (define source (base-certificate-slice-source slice))
  (check-eq? (base-certificate-slice-calculus slice) calculus)
  (check-eq? (base-certificate-slice-profile slice) profile-B)
  (check-equal?
   (map base-occurrence-mark-address
        (base-certificate-slice-classification slice))
   (vertex-addresses source))
  (for ([mark (in-list (base-certificate-slice-classification slice))])
    (define native-node
      (vertex-at-address source (base-occurrence-mark-address mark)))
    (check-eq? (base-occurrence-mark-occurrence mark)
               (checked-node-occurrence native-node))
    (check-equal?
     (base-occurrence-mark-base? mark)
     (material-profile-designates?
      profile-B (checked-node-occurrence native-node))))
  (check-equal?
   (base-certificate-slice-retained-addresses slice)
   (map base-occurrence-mark-address
        (filter base-occurrence-mark-retained?
                (base-certificate-slice-classification slice))))
  (define circuit (base-certificate-slice-circuit slice))
  (check-eq? (supported-ck-frontier-circuit-calculus circuit) calculus)
  (check-eq? (supported-ck-frontier-circuit-source circuit) source)
  (check-eq? (supported-ck-frontier-circuit-profile circuit) profile-B)
  (check-true (supported-ck-frontier-exists? circuit))
  (define maximum (supported-ck-frontier-max circuit))
  (check-equal? (supported-frontier-choice-kind maximum)
                (base-certificate-slice-kind slice))
  (cond
    [(eq? (base-certificate-slice-kind slice) 'whole)
     (check-false (supported-frontier-choice-witness maximum))
     (check-eq? (supported-frontier-choice-endpoint maximum)
                (base-certificate-slice-endpoint slice))]
    [else
     (check-true (cut-witness? (supported-frontier-choice-witness maximum)))
     (check-equal? (supported-frontier-choice-addresses maximum)
                   (slice-native-addresses slice))
     (check-equal?
      (reconstruct-cut-witness
       (supported-frontier-choice-witness maximum))
      source)]))

;; 1. All base: the canonical result is the explicit whole endpoint.  No
;; root-cut witness or cut-specific remainder data is fabricated.
(check-equal? (base-certificate-slice-kind all-base-slice) 'whole)
(check-true
 (base-slice-whole-endpoint?
  (base-certificate-slice-endpoint all-base-slice)))
(check-eq?
 (base-slice-whole-endpoint-source
  (base-certificate-slice-endpoint all-base-slice))
 all-base)
(check-false (base-certificate-slice-witness all-base-slice))
(check-false (base-certificate-slice-detached all-base-slice))
(check-false (base-certificate-slice-remainder all-base-slice))
(check-eq? (base-certificate-slice-reconstruction all-base-slice) all-base)
(check-equal? (base-certificate-slice-retained-addresses all-base-slice) '())
(define forbidden-root (make-cut-witness all-base (list root-address)))
(check-true (cut-error? forbidden-root))
(check-equal? (cut-error-code forbidden-root) 'root-cut)

;; 2. No nonempty detachable base subtree: retain the ordinary empty witness
;; and the structurally unchanged exact-calculus proof.
(check-equal? (base-certificate-slice-kind all-extension-slice) 'empty)
(check-equal? (slice-native-addresses all-extension-slice) '())
(check-equal?
 (base-certificate-slice-retained-addresses all-extension-slice)
 '(() (1)))
(check-equal? (base-certificate-slice-remainder all-extension-slice)
              all-extension)
(check-true
 (proof-forest-empty? (base-certificate-slice-forest all-extension-slice)))
(check-equal? (hash-count
               (base-certificate-slice-hole-module-map all-extension-slice))
              0)

;; 3. New(Old(a),Old(b)): two address-distinct native factors and a two-hole
;; residual reconstruct the exact checked source.
(check-equal? (base-certificate-slice-kind two-modules-slice) 'proper)
(check-equal? (slice-native-addresses two-modules-slice) '((1) (2)))
(check-equal?
 (map detached-entry-address
      (base-certificate-slice-detached two-modules-slice))
 '((1) (2)))
(check-equal? (length (base-certificate-slice-detached two-modules-slice)) 2)
(check-equal? (proof-forest-size
               (base-certificate-slice-forest two-modules-slice))
              2)
(check-equal? (hash-count
               (base-certificate-slice-hole-module-map two-modules-slice))
              2)
(check-equal? (puncture-addresses
               (base-certificate-slice-remainder two-modules-slice))
              '((1) (2)))
(check-equal? (base-certificate-slice-reconstruction two-modules-slice)
              two-modules)
(check-true
 (cut-witness-reconstructs?
  (base-certificate-slice-witness two-modules-slice)))

;; 4-5. A protected ancestor of an extension remains live, and nested
;; extension occurrences remain together in the least residual.
(check-equal? (base-certificate-slice-retained-addresses ancestor-slice)
              '(() (1)))
(check-equal? (slice-native-addresses ancestor-slice) '((1 1) (2)))
(check-true (base-occurrence-mark-base? (mark-at ancestor-slice '())))
(check-true (base-occurrence-mark-retained? (mark-at ancestor-slice '())))
(check-false (base-occurrence-mark-base? (mark-at ancestor-slice '(1))))
(check-equal? (vertex-addresses
               (base-certificate-slice-remainder ancestor-slice))
              '(() (1)))

(check-equal? (base-certificate-slice-retained-addresses nested-slice)
              '(() (1) (1 1)))
(check-equal? (slice-native-addresses nested-slice) '((1 1 1) (2)))
(check-equal? (vertex-addresses
               (base-certificate-slice-remainder nested-slice))
              '(() (1) (1 1)))

;; 6. Structurally equal copied modules retain two native addresses and forest
;; multiplicity instead of collapsing to one occurrence.
(define copied-detached
  (base-certificate-slice-detached equal-copies-slice))
(check-equal? (map detached-entry-address copied-detached) '((1) (2)))
(check-equal? (detached-entry-term (first copied-detached))
              (detached-entry-term (second copied-detached)))
(check-equal? (proof-forest-size
               (base-certificate-slice-forest equal-copies-slice))
              2)
(check-equal?
 (proof-forest-count (base-certificate-slice-forest equal-copies-slice)
                     (detached-entry-term (first copied-detached)))
 2)

;; 8. Native typed filling rejects both a boundary mismatch and an otherwise
;; equal-looking replacement from a foreign calculus snapshot.
(define wrong-boundary-proof
  (checked (raw-app 'slice-wrong-boundary) #:expected R))
(define mismatch-result
  (context-insert
   (base-certificate-slice-remainder two-modules-slice)
   '(1)
   wrong-boundary-proof))
(check-true (context-error? mismatch-result))

(define foreign-calculus (make-equipped-calculus occurrences))
(define foreign-old-a
  (checked
   (raw-app 'slice-old1 (raw-app 'slice-a))
   #:calculus foreign-calculus))
(define foreign-result
  (context-insert
   (base-certificate-slice-remainder two-modules-slice)
   '(1)
   foreign-old-a))
(check-true (context-error? foreign-result))
(check-exn exn:fail:contract?
           (lambda ()
             (make-base-certificate-slice foreign-old-a profile-B)))

;; 9-11. The compact recurrence is checked against a tiny independent native
;; witness oracle.  Every supported residual contains L, equality characterizes
;; the canonical choice, and the unique positive-mass maximum is that choice.
(define (mark-table slice)
  (for/hash ([mark (in-list
                    (base-certificate-slice-classification slice))])
    (values (base-occurrence-mark-address mark) mark)))

(define (supported-witnesses slice)
  (define table (mark-table slice))
  (for/list ([witness
              (in-admissible-cut-witnesses
               (base-certificate-slice-source slice))]
             #:when
             (for/and ([address
                        (in-list (cut-witness-addresses witness))])
               (base-occurrence-mark-subtree-base?
                (hash-ref table address))))
    witness))

(define (detached-vertex-mass witness)
  (for/sum ([entry (in-list (cut-witness-detached witness))])
    (derivation-vertex-count (detached-entry-term entry))))

(for ([slice (in-list slices)])
  (define supported (supported-witnesses slice))
  (check-equal?
   (supported-ck-frontier-count
    (base-certificate-slice-circuit slice))
   (length supported))
  (define live (base-certificate-slice-retained-addresses slice))
  (for ([witness (in-list supported)])
    (define remainder-addresses
      (vertex-addresses (cut-witness-remainder witness)))
    (check-not-false
     (for/and ([address (in-list live)])
       (member address remainder-addresses equal?)))
    (define canonical-native?
      (and (not (eq? (base-certificate-slice-kind slice) 'whole))
           (equal? (cut-witness-addresses witness)
                   (slice-native-addresses slice))))
    (check-equal? (equal? remainder-addresses live) canonical-native?))
  (define masses
    (append (map detached-vertex-mass supported)
            (if (eq? (base-certificate-slice-kind slice) 'whole)
                (list (derivation-vertex-count
                       (base-certificate-slice-source slice)))
                '())))
  (define maximum-mass (apply max masses))
  (check-equal? (count (lambda (mass) (= mass maximum-mass)) masses) 1)
  (check-equal?
   (supported-frontier-choice-mass
    (supported-ck-frontier-max
     (base-certificate-slice-circuit slice)))
   maximum-mass))

;; 12. Test-local staged flattening for the strict profile tower B subset C
;; subset D.  No general composition carrier is introduced.
(define (flatten-staged source)
  (define outer (make-base-certificate-slice source profile-C))
  (cond
    [(eq? (base-certificate-slice-kind outer) 'whole)
     (define inner (make-base-certificate-slice source profile-B))
     (values
      (base-certificate-slice-kind inner)
      (slice-native-addresses inner)
      'whole
      (list (base-certificate-slice-kind inner)))]
    [(eq? (base-certificate-slice-kind outer) 'empty)
     (values 'empty '() 'empty '())]
    [else
     (define inner-kinds '())
     (define flattened
       (append-map
        (lambda (entry)
          (define outer-address (detached-entry-address entry))
          (define inner
            (make-base-certificate-slice
             (detached-entry-term entry) profile-B))
          (set! inner-kinds
                (append inner-kinds
                        (list (base-certificate-slice-kind inner))))
          (case (base-certificate-slice-kind inner)
            [(whole) (list outer-address)]
            [(empty) '()]
            [(proper)
             (map (lambda (inner-address)
                    (address-append outer-address inner-address))
                  (slice-native-addresses inner))]))
        (base-certificate-slice-detached outer)))
     (values (if (null? flattened) 'empty 'proper)
             (sort flattened address<?)
             'proper
             inner-kinds)]))

(define tower-fixtures
  (list
   ;; outer whole / inner whole
   (list (checked (raw-app 'slice-a)) 'whole '(whole))
   ;; outer whole / inner proper
   (list (checked (raw-app 'slice-mid1 (raw-app 'slice-a)))
         'whole '(proper))
   ;; outer proper / inner whole
   (list (checked (raw-app 'slice-new1 (raw-app 'slice-a)))
         'proper '(whole))
   ;; outer proper / inner empty
   (list (checked (raw-app 'slice-new1 (raw-app 'slice-mid-leaf)))
         'proper '(empty))
   ;; outer proper / inner proper
   (list (checked
          (raw-app 'slice-new1
                   (raw-app 'slice-mid1 (raw-app 'slice-a))))
         'proper '(proper))
   ;; outer empty
   (list (checked (raw-app 'slice-new-leaf)) 'empty '())))

(for ([fixture (in-list tower-fixtures)])
  (define source (first fixture))
  ;; Each example is wholly admitted by D, making the comparison B/D versus
  ;; staged C/D then B/C explicit.
  (check-equal?
   (base-certificate-slice-kind
    (make-base-certificate-slice source profile-D))
   'whole)
  (define direct (make-base-certificate-slice source profile-B))
  (define-values (staged-kind staged-addresses outer-kind inner-kinds)
    (flatten-staged source))
  (check-equal? outer-kind (second fixture))
  (check-equal? inner-kinds (third fixture))
  (check-equal? staged-kind (base-certificate-slice-kind direct))
  (check-equal? staged-addresses (slice-native-addresses direct)))

;; 13. The existing Dup2 copy-macro pattern refills with distinct native copy
;; addresses.  Its saturated whole/whole audit witness is the base slice.
(define copy-port (make-macro-port 'x S))
(define copy-summary
  (compile-macro-summary
   calculus
   (checked (raw-app 'slice-new2 raw-hole raw-hole))
   (list copy-port)
   (list (cons '(1) 'x) (cons '(2) 'x))))
(define copy-filler
  (checked (raw-app 'slice-old1 (raw-app 'slice-a))))
(define copy-audit (audit-macro-cuts copy-summary 'x copy-filler))
(check-equal? (macro-cut-audit-completeness copy-audit) 'complete)
(check-true (macro-cut-audit-direct=compositional? copy-audit))
(define copy-slice
  (make-base-certificate-slice
   (macro-cut-audit-target copy-audit) profile-B))
(check-equal? (slice-native-addresses copy-slice) '((1) (2)))
(define matching-audit-entry
  (findf
   (lambda (entry)
     (equal? (macro-cut-audit-entry-addresses entry)
             (slice-native-addresses copy-slice)))
   (macro-cut-audit-entries copy-audit)))
(check-not-false matching-audit-entry)
(check-equal? (macro-cut-audit-entry-sector matching-audit-entry)
              'saturated)
(check-equal?
 (map (lambda (profile-entry)
        (macro-pointed-state-kind
         (macro-copy-profile-entry-source-state profile-entry)))
      (macro-cut-audit-entry-copy-profile matching-audit-entry))
 '(whole whole))
(check-equal?
 (map detached-entry-address
      (base-certificate-slice-detached copy-slice))
 '((1) (2)))
(check-equal? (proof-forest-size
               (base-certificate-slice-forest copy-slice))
              2)

(printf
 "BASE CERTIFICATE SLICE: 6 canonical fixtures, 6 B/C/D tower cases, compact counts and unique maxima agree with the bounded native oracle.\n")
