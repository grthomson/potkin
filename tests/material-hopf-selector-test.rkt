#lang racket/base

(require rackunit
         racket/list
         "../potkin/main.rkt"
         "../potkin/analysis.rkt")

;; One small exact registry.  The suggestive identifiers below are fixture
;; labels only; the implementation must classify the exact occurrence objects
;; held by `profile`, never these names, kinds, tags, or displayed terms.
(define S (singleton-hypersequent '() '(S)))
(define S0 (make-component-incidence '() S '()))

(define a-occ
  (make-concrete-occurrence
   'selector-a '() S #:kind 'logical #:tag 'same-looking
   #:instance 'material-leaf #:incidence S0))
(define u-occ
  (make-concrete-occurrence
   'selector-u (list S) S #:kind 'logical #:tag 'same-looking
   #:instance 'material-unary #:incidence 'opaque-selector-incidence))
(define m-occ
  (make-concrete-occurrence
   'selector-m (list S S) S #:kind 'logical #:tag 'same-looking
   #:instance 'material-binary #:incidence 'opaque-selector-incidence))
(define x-occ
  (make-concrete-occurrence
   'selector-x '() S #:kind 'material #:tag 'same-looking
   #:instance 'extension-leaf #:incidence S0))
(define n-occ
  (make-concrete-occurrence
   'selector-n (list S) S #:kind 'material #:tag 'same-looking
   #:instance 'extension-unary #:incidence 'opaque-selector-incidence))
(define e-occ
  (make-concrete-occurrence
   'selector-e (list S S) S #:kind 'material #:tag 'same-looking
   #:instance 'extension-binary #:incidence 'opaque-selector-incidence))

(define occurrences (list a-occ u-occ m-occ x-occ n-occ e-occ))
(define calculus (make-equipped-calculus occurrences))

(define (checked raw #:calculus [registry calculus])
  (define result (validate-candidate registry raw #:expected S))
  (check-false (validation-error? result))
  result)

(define profile
  (make-material-profile calculus (list a-occ u-occ m-occ)))
(define selector (prepare-material-hopf-selector profile))
(check-eq? (material-hopf-selector-calculus selector) calculus)
(check-eq? (material-hopf-selector-profile selector) profile)

(define a (checked (raw-app 'selector-a)))
(define x (checked (raw-app 'selector-x)))
(define ua (checked (raw-app 'selector-u (raw-app 'selector-a))))
(define na (checked (raw-app 'selector-n (raw-app 'selector-a))))
(define maa
  (checked
   (raw-app 'selector-m (raw-app 'selector-a) (raw-app 'selector-a))))
(define eaa
  (checked
   (raw-app 'selector-e (raw-app 'selector-a) (raw-app 'selector-a))))

(define empty-forest (empty-proof-forest calculus))
(define (singleton term) (make-proof-forest calculus (list term)))
(define a-forest (singleton a))
(define x-forest (singleton x))
(define ua-forest (singleton ua))
(define na-forest (singleton na))
(define maa-forest (singleton maa))
(define eaa-forest (singleton eaa))
(define aa-forest (make-proof-forest calculus (list a a)))
(define material-product-forest (make-proof-forest calculus (list a ua)))
(define mixed-product-forest (make-proof-forest calculus (list a na)))

;; Independent direct oracle: rescan native vertex addresses and exact
;; occurrence objects without calling any selector implementation function.
(define (oracle-forest-pure? forest)
  (unless (eq? (proof-forest-calculus forest) calculus)
    (error 'oracle-forest-pure? "foreign fixture forest"))
  (for/and ([factor (in-list (proof-forest-factors forest))])
    (for/and ([address (in-list (vertex-addresses factor))])
      (material-profile-designates?
       profile
       (checked-node-occurrence (vertex-at-address factor address))))))

(define (oracle-project sum)
  (make-formal-sum
   calculus
   1
   (for/list ([term (in-list (formal-sum-terms sum))]
              #:when (oracle-forest-pure? (vector-ref (car term) 0)))
     term)))

(define (oracle-coaction sum)
  (define delta (coproduct sum))
  (make-formal-sum
   calculus
   2
   (for/list ([term (in-list (formal-sum-terms delta))]
              #:when (oracle-forest-pure? (vector-ref (car term) 0)))
     term)))

(define (project-both tensor)
  (define left-projected
    (formal-sum-expand-coordinate
     tensor 1 1
     (lambda (forest)
       (material-hopf-selector-project-forest selector forest))))
  (formal-sum-expand-coordinate
   left-projected 2 1
   (lambda (forest)
     (material-hopf-selector-project-forest selector forest))))

(define (coalgebra-law? sum)
  (equal?
   (coproduct (material-hopf-selector-project selector sum))
   (project-both (coproduct sum))))

(define (coassociativity-law? sum)
  (define rho (material-hopf-selector-coaction selector sum))
  (define left
    (formal-sum-expand-coordinate rho 1 2 forest-coproduct))
  (define right
    (formal-sum-expand-coordinate
     rho 2 2
     (lambda (forest)
       (material-hopf-selector-coaction selector (forest-basis forest)))))
  (equal? left right))

;; 1. The native algebra unit and native additive zero remain distinct and are
;; each fixed by the selector.
(define one (algebra-unit calculus))
(define zero (formal-zero calculus))
(check-false (equal? one zero))
(check-false (formal-zero? one))
(check-true (formal-zero? zero))
(check-equal? (material-hopf-selector-project selector one) one)
(check-equal? (material-hopf-selector-project selector zero) zero)
(check-true
 (material-hopf-selector-forest-pure? selector empty-forest))
(check-equal?
 (material-hopf-selector-project-forest selector empty-forest)
 one)

;; 2-4. Purity is all-or-nothing for one complete forest monomial.
(for ([forest (in-list
               (list a-forest ua-forest maa-forest
                     material-product-forest))])
  (check-true (material-hopf-selector-forest-pure? selector forest))
  (check-equal? (material-hopf-selector-project-forest selector forest)
                (forest-basis forest)))
(check-false (material-hopf-selector-forest-pure? selector na-forest))
(check-true
 (formal-zero?
  (material-hopf-selector-project-forest selector na-forest)))
(check-false
 (material-hopf-selector-forest-pure? selector mixed-product-forest))
(check-true
 (formal-zero?
  (material-hopf-selector-project-forest selector mixed-product-forest)))
(check-not-equal?
 (material-hopf-selector-project-forest selector mixed-product-forest)
 (forest-basis a-forest))

;; 5. Equal-looking occurrences remain two native multiset occurrences.
(check-true (material-hopf-selector-forest-pure? selector aa-forest))
(check-equal? (proof-forest-size aa-forest) 2)
(check-equal? (proof-forest-count aa-forest a) 2)
(check-equal? (material-hopf-selector-project-forest selector aa-forest)
              (forest-basis aa-forest))

;; 6. Native Z-linear collection retains positive and negative coefficients,
;; combines duplicate support and removes cancelled support.
(define collected-linear-input
  (make-formal-sum
   calculus 1
   (list (cons (vector ua-forest) 3)
         (cons (vector ua-forest) -1)
         (cons (vector aa-forest) -4)
         (cons (vector a-forest) 5)
         (cons (vector a-forest) -5)
         (cons (vector na-forest) 7)
         (cons (vector mixed-product-forest) -2))))
(define expected-linear-projection
  (make-formal-sum
   calculus 1
   (list (cons (vector ua-forest) 2)
         (cons (vector aa-forest) -4))))
(check-equal?
 (material-hopf-selector-project selector collected-linear-input)
 expected-linear-projection)
(check-equal? (material-hopf-selector-project selector collected-linear-input)
              (oracle-project collected-linear-input))
(check-equal? (forest-coefficient expected-linear-projection ua-forest) 2)
(check-equal? (forest-coefficient expected-linear-projection aa-forest) -4)
(check-equal? (forest-coefficient expected-linear-projection a-forest) 0)

;; Declared generated family: all checked unary trees through vertex degree 2
;; over the two leaves and the material/extension unary constructors.
(define generated-degree-bound 2)
(define generated-raw
  (append
   (list (raw-app 'selector-a) (raw-app 'selector-x))
   (for*/list ([constructor (in-list '(selector-u selector-n))]
               [leaf (in-list '(selector-a selector-x))])
     (raw-app constructor (raw-app leaf)))))
(define generated (map checked generated-raw))
(check-equal? (length generated) 6)
(for ([term (in-list generated)])
  (check-true (<= (derivation-vertex-count term) generated-degree-bound)))
(define generated-bases (map checked-node-basis generated))

(define selected-linear-sums
  (list
   collected-linear-input
   (formal-sum-add (checked-node-basis ua)
                   (formal-sum-scale -2 (checked-node-basis na)))
   (formal-sum-subtract (checked-node-basis a)
                        (checked-node-basis x))))

;; 7-8. Independent oracle agreement, linearity, idempotence and the coalgebra
;; equation on every generated basis element and selected linear sums.
(for ([sum (in-list (append generated-bases selected-linear-sums))])
  (define projected (material-hopf-selector-project selector sum))
  (check-equal? projected (oracle-project sum))
  (check-equal? (material-hopf-selector-project selector projected)
                projected)
  (check-true (coalgebra-law? sum))
  (check-equal? (material-hopf-selector-coaction selector sum)
                (oracle-coaction sum)))

(define linear-left (first selected-linear-sums))
(define linear-right (second selected-linear-sums))
(check-equal?
 (material-hopf-selector-project
  selector (formal-sum-add linear-left linear-right))
 (formal-sum-add
  (material-hopf-selector-project selector linear-left)
  (material-hopf-selector-project selector linear-right)))

(for* ([left (in-list generated-bases)]
       [right (in-list generated-bases)])
  (check-equal?
   (material-hopf-selector-project
    selector (formal-sum-multiply left right))
   (formal-sum-multiply
    (material-hopf-selector-project selector left)
    (material-hopf-selector-project selector right))))

;; 9. On all-material inputs the relative coaction is exactly the native
;; collected coproduct, for connected and multi-factor inputs.
(for ([sum (in-list
            (list (checked-node-basis ua)
                  (checked-node-basis maa)
                  (forest-basis aa-forest)))])
  (check-equal? (material-hopf-selector-coaction selector sum)
                (coproduct sum)))

;; 10. A nonmaterial nullary input leaves exactly the empty-cut term 1 tensor
;; x.  Its whole endpoint x tensor 1 is removed, not represented by a root cut.
(define x-basis (checked-node-basis x))
(define x-coaction (material-hopf-selector-coaction selector x-basis))
(define x-empty-term
  (pure-tensor calculus (vector empty-forest x-forest)))
(check-equal? x-coaction x-empty-term)
(check-equal? (formal-sum-support-size x-coaction) 1)
(check-equal?
 (formal-sum-coefficient x-coaction (vector x-forest empty-forest))
 0)
(define x-root-attempt (make-cut-witness x (list root-address)))
(check-true (cut-error? x-root-attempt))
(check-equal? (cut-error-code x-root-attempt) 'root-cut)

;; 11 and 13. For n(a), retain 1 tensor n(a) and the proper material cut.
;; Filtering the right coordinate as well would kill both surviving terms.
(define na-basis (checked-node-basis na))
(define na-witness (make-cut-witness na '((1))))
(check-true (cut-witness? na-witness))
(define na-remainder-forest
  (make-proof-forest calculus (list (cut-witness-remainder na-witness))))
(define na-expected-coaction
  (formal-sum-add
   (pure-tensor calculus (vector empty-forest na-forest))
   (pure-tensor calculus
                (vector (cut-witness-forest na-witness)
                        na-remainder-forest))))
(define na-coaction (material-hopf-selector-coaction selector na-basis))
(check-equal? na-coaction na-expected-coaction)
(check-equal? (formal-sum-support-size na-coaction) 2)
(check-equal?
 (formal-sum-coefficient
  na-coaction
  (vector (cut-witness-forest na-witness) na-remainder-forest))
 1)
(check-true (formal-zero? (project-both (coproduct na-basis))))

;; 12. Two equal material factors in the native commutative forest retain the
;; collected middle coefficient 2.
(define aa-coaction
  (material-hopf-selector-coaction selector (forest-basis aa-forest)))
(check-equal? aa-coaction (coproduct (forest-basis aa-forest)))
(check-equal?
 (formal-sum-coefficient aa-coaction (vector a-forest a-forest))
 2)

;; 14. The full supported coaction on e(a,a) has empty, left-only,
;; right-only and simultaneous cuts.  The canonical slice selects only the
;; greatest simultaneous cut; the APIs intentionally answer different queries.
(define eaa-basis (checked-node-basis eaa))
(define eaa-coaction
  (material-hopf-selector-coaction selector eaa-basis))
(check-equal? (formal-sum-support-size eaa-coaction) 4)
(define eaa-slice (make-base-certificate-slice eaa profile))
(check-equal? (base-certificate-slice-kind eaa-slice) 'proper)
(check-equal?
 (cut-witness-addresses (base-certificate-slice-witness eaa-slice))
 '((1) (2)))
(define eaa-canonical-witness
  (base-certificate-slice-witness eaa-slice))
(define eaa-canonical-key
  (vector
   (cut-witness-forest eaa-canonical-witness)
   (make-proof-forest
    calculus (list (cut-witness-remainder eaa-canonical-witness)))))
(check-equal?
 (formal-sum-coefficient eaa-coaction eaa-canonical-key)
 1)
(check-true (> (formal-sum-support-size eaa-coaction) 1))

;; 15. Counit, coassociativity and multiplicativity over the bounded generated
;; family.  Native arbitrary-rank formal sums supply the ordered triple tensor.
(for ([sum (in-list (append generated-bases selected-linear-sums))])
  (check-equal?
   (tensor-counit-left
    (material-hopf-selector-coaction selector sum))
   sum)
  (check-true (coassociativity-law? sum)))

(for* ([left (in-list generated-bases)]
       [right (in-list generated-bases)])
  (check-equal?
   (material-hopf-selector-coaction
    selector (formal-sum-multiply left right))
   (formal-sum-multiply
    (material-hopf-selector-coaction selector left)
    (material-hopf-selector-coaction selector right))))

;; 16. Foreign snapshots are rejected before traversal.  A counterfeit exact
;; occurrence cannot create an indeterminate profile; the profile constructor
;; rejects it, and the public classifier is therefore total Boolean data.
(define foreign-calculus (make-equipped-calculus occurrences))
(define foreign-a
  (checked (raw-app 'selector-a) #:calculus foreign-calculus))
(define foreign-a-forest (make-proof-forest foreign-calculus (list foreign-a)))
(define foreign-a-basis (forest-basis foreign-a-forest))
(check-exn
 exn:fail:contract?
 (lambda ()
   (material-hopf-selector-forest-pure? selector foreign-a-forest)))
(check-exn
 exn:fail:contract?
 (lambda () (material-hopf-selector-project selector foreign-a-basis)))
(check-exn
 exn:fail:contract?
 (lambda () (material-hopf-selector-coaction selector foreign-a-basis)))

(define foreign-profile
  (make-material-profile foreign-calculus (list a-occ u-occ m-occ)))
(define foreign-selector (prepare-material-hopf-selector foreign-profile))
(check-exn
 exn:fail:contract?
 (lambda ()
   (material-hopf-selector-project-forest foreign-selector a-forest)))

(define counterfeit-a
  (make-concrete-occurrence
   'selector-a '() S #:kind 'logical #:tag 'same-looking
   #:instance 'material-leaf #:incidence S0))
(check-exn
 exn:fail:contract?
 (lambda () (make-material-profile calculus (list counterfeit-a))))

(printf
 "MATERIAL HOPF SELECTOR: ~a generated checked trees through degree ~a; exact-profile projection and coaction agree with the independent native oracle and bounded laws.\n"
 (length generated)
 generated-degree-bound)
