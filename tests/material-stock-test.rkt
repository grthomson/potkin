#lang racket/base

(require rackunit
         racket/list
         "../potkin/main.rkt")

;; One deliberately small native fixture exercises repeated occurrences,
;; ordered premises, positive-arity material occurrences, opaque incidence,
;; resource filtering, and every one of its finite CK witnesses.  This is a
;; differential falsification fixture, not the proof of index correctness.
(define S (singleton-hypersequent '() '(S)))
(define known-empty-ground-incidence
  (make-component-incidence '() S '()))

(define g-occ
  (make-concrete-occurrence
   'material-index-g '() S
   #:kind 'material
   #:tag 'same-looking-ground
   #:instance 'g
   #:incidence known-empty-ground-incidence))
(define g-prime-occ
  (make-concrete-occurrence
   'material-index-g-prime '() S
   #:kind 'material
   #:tag 'same-looking-ground
   #:instance 'g-prime
   #:incidence known-empty-ground-incidence))
(define mat2-occ
  (make-concrete-occurrence
   'material-index-mat2 (list S S) S
   #:kind 'material
   #:tag 'positive-material
   #:instance 'mat2
   #:incidence 'opaque-mat2-incidence))
(define neutral2-occ
  (make-concrete-occurrence
   'material-index-neutral2 (list S S) S
   #:kind 'logical
   #:tag 'neutral
   #:instance 'neutral2
   #:incidence '()))
(define kind-only-occ
  (make-concrete-occurrence
   'material-index-kind-only '() S
   #:kind 'material
   #:tag 'not-designated-by-profile
   #:instance 'kind-only
   #:incidence known-empty-ground-incidence))

(define calculus
  (make-equipped-calculus
   (list g-occ g-prime-occ mat2-occ neutral2-occ kind-only-occ)))

(define source-raw
  (raw-app
   'material-index-neutral2
   (raw-app 'material-index-mat2
            (raw-app 'material-index-g)
            (raw-app 'material-index-g))
   (raw-app
    'material-index-neutral2
    (raw-app 'material-index-mat2
             (raw-app 'material-index-g)
             (raw-app 'material-index-g-prime))
    (raw-app 'material-index-g))))

(define source (validate-candidate calculus source-raw #:expected S))
(check-true (complete-proof? source))
(check-equal? (derivation-vertex-count source) 9)

;; The profile is explicit exact registry data.  In particular, `kind-only`
;; remains nonmaterial even though its registry kind happens to be material.
(define profile
  (make-material-profile
   calculus
   (list g-occ g-prime-occ mat2-occ)
   #:resource-dimensions 2
   #:demands
   (list (cons g-occ '(1 0))
         (cons g-prime-occ '(2 0))
         (cons mat2-occ '(0 1)))))

(check-true (material-profile-designates? profile g-occ))
(check-false (material-profile-designates? profile neutral2-occ))
(check-false (material-profile-designates? profile kind-only-occ))
(check-equal? (material-profile-demand profile mat2-occ) '(0 1))

;; Stock membership is an explicit observer designation, independent of the
;; occurrence's kind in the registry (and distinct from repair policy).
(define explicit-logical-profile
  (make-material-profile calculus (list neutral2-occ)))
(check-true
 (material-profile-designates? explicit-logical-profile neutral2-occ))

;; A structurally equal occurrence manufactured outside the registry is not
;; the exact registry object and cannot silently enter a profile.
(define counterfeit-g-occ
  (make-concrete-occurrence
   'material-index-g '() S
   #:kind 'material
   #:tag 'same-looking-ground
   #:instance 'g
   #:incidence known-empty-ground-incidence))
(check-exn
 exn:fail:contract?
 (lambda () (make-material-profile calculus (list counterfeit-g-occ))))
(check-exn
 exn:fail:contract?
 (lambda () (make-material-profile calculus (list g-occ g-occ))))
(check-exn
 exn:fail:contract?
 (lambda ()
   (make-material-profile
    calculus
    (list g-occ)
    #:resource-dimensions 2
    #:demands (list (cons g-occ '(1))))))
(check-exn
 exn:fail:contract?
 (lambda ()
   (make-material-profile
    calculus
    (list g-occ)
    #:resource-dimensions 2
    #:demands (list (cons g-occ '(1 0))
                    (cons g-occ '(1 0))))))

(define index (prepare-material-stock-index source profile))
(check-eq? (material-stock-index-source index) source)
(check-eq? (material-profile-calculus
            (material-stock-index-profile index))
           calculus)
(check-equal? (material-stock-index-vertex-count index) 9)

(define expected-material-use-addresses
  '((1) (1 1) (1 2) (2 1) (2 1 1) (2 1 2) (2 2)))
(define direct-uses (direct-material-uses source profile))
(define indexed-uses (material-stock-index-uses index))
(check-equal? indexed-uses direct-uses)
(check-equal?
 (map material-use-address
      (filter material-use-designated? indexed-uses))
 expected-material-use-addresses)
(check-equal?
 (for/list ([occurrence (in-list (list mat2-occ g-occ g-prime-occ))])
   (count (lambda (use)
            (eq? occurrence (material-use-occurrence use)))
          indexed-uses))
 '(2 4 1))

(define (use-at address [uses indexed-uses])
  (findf (lambda (use) (equal? address (material-use-address use))) uses))

(check-true (component-incidence? (material-use-incidence (use-at '(1 1)))))
(check-true
 (component-analysis-unavailable? (material-use-incidence (use-at '(1)))))
(check-equal?
 (component-analysis-unavailable-reason
  (material-use-incidence (use-at '(1))))
 'legacy-opaque-incidence)

(define direct-decomposition
  (direct-material-decomposition source profile))
(define indexed-decomposition
  (indexed-material-decomposition index))
(check-equal? indexed-decomposition direct-decomposition)
(check-equal?
 (map material-module-address
      (material-decomposition-modules indexed-decomposition))
 '((1) (2 1) (2 2)))
(check-equal?
 (map material-blocker-address
      (material-decomposition-blockers indexed-decomposition))
 '(() (2)))

(for ([address (in-list (vertex-addresses source))]
      #:unless (null? address))
  (check-equal?
   (indexed-material-subtree-available? index address)
   (direct-material-subtree-available? source profile address)))
(check-true
 (indexed-material-subtree-available? index '(1) #:budget '(2 1)))
(check-false
 (indexed-material-subtree-available? index '(1) #:budget '(1 1)))

(define ambient-witnesses
  (for/list ([witness (in-admissible-cut-witnesses source)]) witness))
(check-equal? (length ambient-witnesses) 55)
(check-equal? (material-stock-index-ordinary-witness-count index) 55)
(check-equal? (material-stock-index-material-witness-count index) 50)
(check-equal? (direct-material-stock-count source profile) 50)
(check-equal? (indexed-material-stock-count index) 50)
(define limited-index
  (prepare-material-stock-index source profile #:limit 54))
(check-true (analysis-limit? limited-index))
(check-equal? (analysis-limit-operation limited-index)
              'prepare-material-stock-index)
(check-equal? (analysis-limit-metric limited-index)
              'ordinary-witness-count)
(check-equal? (analysis-limit-limit limited-index) 54)
(check-true (>= (analysis-limit-required limited-index) 55))
(check-true
 (material-stock-index?
  (prepare-material-stock-index source profile #:limit 55)))

(define (choice-of witness)
  (if (null? (cut-witness-addresses witness))
      (empty-cut-choice)
      (proper-cut-choice (cut-witness-addresses witness))))

(define (check-direct/index query)
  (define direct (direct-material-query source profile query))
  (define indexed (indexed-material-query index query))
  (check-equal? indexed direct)
  (check-equal? (indexed-material-available? index query)
                (material-query-result-available? direct))
  indexed)

;; Every native witness choice in this source is checked occurrence-for-
;; occurrence, including the five nonmaterial openings rejected by the profile.
(for ([witness (in-list ambient-witnesses)])
  (check-direct/index
   (make-material-choice-query (choice-of witness))))

;; Compare every left-forest bucket and every retained exact tensor bucket.
(define distinct-forests
  (remove-duplicates (map cut-witness-forest ambient-witnesses) equal?))
(for ([forest (in-list distinct-forests)])
  (define query (make-material-forest-query forest))
  (define result (check-direct/index query))
  (check-equal?
   (material-query-result-coefficient result)
   (indexed-material-coefficient index forest))
  (check-equal?
   (direct-material-coefficient source profile forest)
   (indexed-material-coefficient index forest)))

(define all-result
  (check-direct/index (make-material-all-query)))
(check-equal? (material-query-result-coefficient all-result) 50)
(for ([witness (in-list (material-query-result-witnesses all-result))])
  (check-true (cut-witness-reconstructs? witness))
  (check-equal? (reconstruct-cut-witness witness) source))
(check-equal?
 (length
  (remove-duplicates
   (map cut-witness-addresses
        (material-query-result-witnesses all-result))
   equal?))
 50)
(define distinct-tensors
  (remove-duplicates
   (map material-contribution-tensor
        (material-query-result-contributions all-result))
   equal?))
(for ([tensor (in-list distinct-tensors)])
  (define query (make-material-tensor-query tensor))
  (define result (check-direct/index query))
  (check-equal?
   (material-query-result-coefficient result)
   (indexed-material-tensor-coefficient index tensor))
  (check-equal?
   (direct-material-tensor-coefficient source profile tensor)
   (indexed-material-tensor-coefficient index tensor)))

;; On every retained tensor key, the occurrence count agrees with the existing
;; collected root coaction.  The query layer keeps the witnesses that the
;; formal sum intentionally forgets.
(define native-root-coaction (root-coaction source))
(for ([tensor (in-list distinct-tensors)])
  (check-equal?
   (indexed-material-tensor-coefficient index tensor)
   (formal-sum-coefficient native-root-coaction tensor)))

;; Equal g subproofs at four different addresses share one collected left
;; forest bucket, but retrieval preserves four separate witnesses and residues.
(define g-proof
  (validate-candidate calculus (raw-app 'material-index-g) #:expected S))
(define singleton-g-forest (make-proof-forest calculus (list g-proof)))
(check-equal? (indexed-material-coefficient index singleton-g-forest) 4)
(check-equal?
 (direct-material-coefficient
  source profile singleton-g-forest #:budget '(1 0))
 4)
(check-equal?
 (indexed-material-coefficient
  index singleton-g-forest #:budget '(1 0))
 4)
(check-equal?
 (direct-material-coefficient
  source profile singleton-g-forest #:budget '(0 0))
 0)
(check-equal?
 (indexed-material-coefficient
  index singleton-g-forest #:budget '(0 0))
 0)
(define singleton-g-query
  (make-material-forest-query singleton-g-forest))
(define singleton-g-witnesses
  (indexed-material-witnesses index singleton-g-query))
(check-equal?
 (map (lambda (witness) (car (cut-witness-addresses witness)))
      singleton-g-witnesses)
 '((1 1) (1 2) (2 1 1) (2 2)))
(check-equal? singleton-g-witnesses
              (direct-material-witnesses source profile singleton-g-query))

;; Multiplicity two in the commutative forest does not erase the aligned
;; addresses, and detaching the connected parent remains a different query.
(define two-g-choice (proper-cut-choice '((1 1) (1 2))))
(define two-g-result
  (check-direct/index (make-material-choice-query two-g-choice)))
(define two-g-witness
  (first (material-query-result-witnesses two-g-result)))
(check-equal? (map detached-entry-address
                   (cut-witness-detached two-g-witness))
              '((1 1) (1 2)))
(check-equal? (puncture-addresses (cut-witness-remainder two-g-witness))
              '((1 1) (1 2)))
(check-equal? (proof-forest-count
               (cut-witness-forest two-g-witness) g-proof)
              2)
(define parent-result
  (check-direct/index
   (make-material-choice-query (proper-cut-choice '((1))))))
(check-not-equal?
 (cut-witness-forest
  (first (material-query-result-witnesses parent-result)))
 (cut-witness-forest two-g-witness))

;; The proper-cut component profile retains opaque incidence as unavailable;
;; material availability remains an orthogonal, positive result.
(define parent-contribution
  (first (material-query-result-contributions parent-result)))
(define parent-component-profile
  (material-witness-contribution-component-profile parent-contribution))
(check-true (ck-component-profile? parent-component-profile))
(check-true
 (component-trace-unavailable?
  (ck-component-profile-trace parent-component-profile)))
(check-not-equal?
 (component-trace-unavailable-blockers
  (ck-component-profile-trace parent-component-profile))
 '())

;; Empty witness, proper witness, and whole algebraic endpoint remain disjoint.
(define empty-result
  (check-direct/index
   (make-material-choice-query (empty-cut-choice) #:budget '(0 0))))
(define empty-contribution
  (first (material-query-result-contributions empty-result)))
(check-true (material-witness-contribution? empty-contribution))
(check-equal?
 (cut-witness-addresses
  (material-witness-contribution-witness empty-contribution))
 '())
(check-true
 (proof-forest-empty?
  (vector-ref (material-witness-contribution-tensor empty-contribution) 0)))
(check-true
 (material-component-not-applicable?
  (material-witness-contribution-component-profile empty-contribution)))

(define material-source (vertex-at-address source '(1)))
(define material-index (prepare-material-stock-index material-source profile))
(define whole-query
  (make-material-choice-query (whole-cut-choice) #:budget '(2 1)))
(define whole-direct
  (direct-material-query material-source profile whole-query))
(define whole-indexed (indexed-material-query material-index whole-query))
(check-equal? whole-indexed whole-direct)
(check-equal? (material-query-result-coefficient whole-indexed) 1)
(check-equal? (material-query-result-witnesses whole-indexed) '())
(define whole-contribution
  (first (material-query-result-contributions whole-indexed)))
(check-true
 (material-whole-endpoint-contribution? whole-contribution))
(check-false (material-contribution-witness whole-contribution))
(check-equal? (whole-cut-choice)
              (material-contribution-choice whole-contribution))
(check-equal?
 (cut-error-code
  (make-cut-witness material-source (list root-address)))
 'root-cut)

(define material-source-forest
  (make-proof-forest calculus (list material-source)))
(check-equal?
 (indexed-material-coefficient material-index material-source-forest)
 0)
(check-equal?
 (indexed-material-coefficient
  material-index material-source-forest
  #:include-whole-endpoint? #t)
 1)
(define whole-tensor (material-contribution-tensor whole-contribution))
(check-equal?
 (indexed-material-tensor-coefficient material-index whole-tensor)
 0)
(check-equal?
 (indexed-material-tensor-coefficient
  material-index whole-tensor #:include-whole-endpoint? #t)
 1)

;; A typed hole contributes no vertex and is retained inside the connected
;; factor.  It does not turn that factor into the empty-forest unit.
(define open-material-source
  (validate-candidate
   calculus
   (raw-app 'material-index-mat2 raw-hole (raw-app 'material-index-g))
   #:expected S))
(define open-index
  (prepare-material-stock-index open-material-source profile))
(define open-whole-result
  (indexed-material-query
   open-index (make-material-choice-query (whole-cut-choice))))
(define open-left
  (vector-ref
   (material-contribution-tensor
    (first (material-query-result-contributions open-whole-result)))
   0))
(check-false (proof-forest-empty? open-left))
(check-equal? (proof-forest-size open-left) 1)
(check-true (proof-context? (first (proof-forest-factors open-left))))
(define open-proper-query
  (make-material-choice-query (proper-cut-choice '((2)))))
(define open-proper-direct
  (direct-material-query open-material-source profile open-proper-query))
(define open-proper-indexed
  (indexed-material-query open-index open-proper-query))
(check-equal? open-proper-indexed open-proper-direct)
(check-equal? (material-query-result-coefficient open-proper-indexed) 1)
(define open-proper-witness
  (first (material-query-result-witnesses open-proper-indexed)))
(check-equal? (puncture-addresses (cut-witness-remainder open-proper-witness))
              '((1) (2)))
(check-true (cut-witness-reconstructs? open-proper-witness))
(check-true
 (component-analysis-unavailable?
  (material-witness-contribution-component-profile
   (first (material-query-result-contributions open-proper-indexed)))))
(check-exn
 exn:fail:contract?
 (lambda ()
   (prepare-material-stock-index (identity-context calculus S) profile)))

;; Resource budgets are checked before collection and preserve rejected
;; occurrence evidence.
(define full-material-choice
  (proper-cut-choice '((1) (2 1) (2 2))))
(define exact-budget-query
  (make-material-choice-query full-material-choice #:budget '(6 2)))
(define insufficient-budget-query
  (make-material-choice-query full-material-choice #:budget '(5 2)))
(check-equal?
 (material-query-result-coefficient
  (check-direct/index exact-budget-query))
 1)
(define insufficient-result
  (check-direct/index insufficient-budget-query))
(check-equal? (material-query-result-coefficient insufficient-result) 0)
(check-equal?
 (map material-blocker-reason
      (material-query-result-blockers insufficient-result))
 '(resource-deficit))
(check-equal?
 (hash-ref
  (material-blocker-details
   (first (material-query-result-blockers insufficient-result)))
  'deficit)
 '(1 0))
(check-equal?
 (direct-material-stock-count source profile #:budget '(0 0))
 1)
(check-equal?
 (indexed-material-stock-count index #:budget '(0 0))
 1)
(check-equal?
 (direct-material-stock-count source profile #:budget '(6 2))
 (indexed-material-stock-count index #:budget '(6 2)))
(check-exn
 exn:fail:contract?
 (lambda ()
   (indexed-material-stock-count index #:budget '(1))))

;; An empty exact profile has no maximal material module and reports every
;; source vertex as a blocker; this remains distinct from opaque incidence.
(define empty-profile (make-material-profile calculus '()))
(define empty-index (prepare-material-stock-index source empty-profile))
(check-equal?
 (material-decomposition-modules
  (indexed-material-decomposition empty-index))
 '())
(check-equal?
 (length
  (material-decomposition-blockers
   (indexed-material-decomposition empty-index)))
 9)
(check-equal? (indexed-material-stock-count empty-index) 1)

;; A material `kind` not named by the profile remains unavailable, with the
;; exact occurrence/address retained as its blocker.
(define kind-only-proof
  (validate-candidate
   calculus (raw-app 'material-index-kind-only) #:expected S))
(define kind-only-index
  (prepare-material-stock-index kind-only-proof profile))
(define kind-only-result
  (indexed-material-query
   kind-only-index (make-material-choice-query (whole-cut-choice))))
(check-equal? (material-query-result-coefficient kind-only-result) 0)
(check-eq?
 (material-blocker-occurrence
  (first (material-query-result-blockers kind-only-result)))
 kind-only-occ)
(check-equal?
 (material-blocker-address
  (first (material-query-result-blockers kind-only-result)))
 root-address)

;; Premise order remains presentation data even though the scalar stock count
;; happens to agree after swapping g and g-prime in one ordered constructor.
(define swapped-source
  (validate-candidate
   calculus
   (raw-app
    'material-index-neutral2
    (raw-app 'material-index-mat2
             (raw-app 'material-index-g)
             (raw-app 'material-index-g))
    (raw-app
     'material-index-neutral2
     (raw-app 'material-index-mat2
              (raw-app 'material-index-g-prime)
              (raw-app 'material-index-g))
     (raw-app 'material-index-g)))
   #:expected S))
(check-not-equal? swapped-source source)
(define swapped-index
  (prepare-material-stock-index swapped-source profile))
(check-eq? (material-use-occurrence
            (use-at '(2 1 1) (material-stock-index-uses swapped-index)))
           g-prime-occ)
(check-eq? (material-use-occurrence
            (use-at '(2 1 2) (material-stock-index-uses swapped-index)))
           g-occ)
(check-equal? (indexed-material-stock-count swapped-index) 50)

;; Structurally equal presentation data from another calculus snapshot cannot
;; authorize a lookup in this index.
(define foreign-calculus
  (make-equipped-calculus
   (list g-occ g-prime-occ mat2-occ neutral2-occ kind-only-occ)))
(define foreign-g
  (validate-candidate
   foreign-calculus (raw-app 'material-index-g) #:expected S))
(define foreign-query
  (make-material-forest-query
   (make-proof-forest foreign-calculus (list foreign-g))))
(define foreign-direct
  (direct-material-query source profile foreign-query))
(define foreign-indexed
  (indexed-material-query index foreign-query))
(check-equal? foreign-indexed foreign-direct)
(check-equal? (material-query-result-coefficient foreign-indexed) 0)
(check-equal?
 (map material-blocker-reason
      (material-query-result-blockers foreign-indexed))
 '(wrong-calculus-provenance))

(printf
 "MATERIAL INDEX DIFFERENTIAL FIXTURE: ~a vertices; ~a native witnesses; ~a material witnesses; ~a distinct forest queries; ~a distinct tensor queries.\n"
 (derivation-vertex-count source)
 (length ambient-witnesses)
 (material-query-result-coefficient all-result)
 (length distinct-forests)
 (length distinct-tensors))
