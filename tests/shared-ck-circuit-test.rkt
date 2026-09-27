#lang racket/base

(require rackunit
         racket/list
         "../potkin/main.rkt"
         "../potkin/analysis.rkt")

(define S (singleton-hypersequent '() '(S)))
(define I0 (make-component-incidence '() S '()))
(define I1 (make-component-incidence (list S) S '()))
(define I2 (make-component-incidence (list S S) S '()))

(define a-occ
  (make-concrete-occurrence
   'circuit-a '() S #:instance 'a #:incidence I0))
(define c-occ
  (make-concrete-occurrence
   'circuit-c '() S #:instance 'c #:incidence I0))
(define u-occ
  (make-concrete-occurrence
   'circuit-u (list S) S #:instance 'u #:incidence I1))
(define e-occ
  (make-concrete-occurrence
   'circuit-e (list S) S #:instance 'extension #:incidence I1))
(define left-occ
  (make-concrete-occurrence
   'circuit-left (list S) S #:instance 'left #:incidence I1))
(define right-occ
  (make-concrete-occurrence
   'circuit-right (list S) S #:instance 'right #:incidence I1))
(define j-occ
  (make-concrete-occurrence
   'circuit-j (list S S) S #:instance 'join #:incidence I2))
(define r-occ
  (make-concrete-occurrence
   'circuit-r (list S S) S #:instance 'root #:incidence I2))
(define occurrences
  (list a-occ c-occ u-occ e-occ left-occ right-occ j-occ r-occ))
(define calculus (make-equipped-calculus occurrences))

(define (checked raw #:calculus [registry calculus])
  (define result (validate-candidate registry raw #:expected S))
  (check-false (validation-error? result))
  result)

(define (qmap bindings #:calculus [registry calculus])
  (make-sharing-source-map registry bindings))

(define (compile proof bindings #:witness-limit [witness-limit 4096]
                 #:antichain-limit [antichain-limit 4096])
  (compile-shared-ck-circuit
   (audit-sharing-saturation
    proof (qmap bindings)
    #:witness-limit witness-limit
    #:antichain-limit antichain-limit)))

(define (gate circuit source)
  (findf
   (lambda (candidate)
     (equal?
      (sharing-source-node-id (shared-ck-gate-source-node candidate))
      source))
   (shared-ck-circuit-gates circuit)))

(define (decode-addresses circuit rank)
  (define decoded (shared-ck-circuit-decode circuit rank))
  (check-true (shared-ck-choice? decoded))
  (check-true (shared-ck-choice-native-agreement? decoded))
  (shared-ck-choice-addresses decoded))

(define (check-agreement circuit expected-count #:limit [limit 4096])
  (check-equal? (shared-ck-circuit-choice-count circuit) expected-count)
  (define agreement
    (shared-ck-circuit-native-agreement circuit #:rank-limit limit))
  (check-equal? (shared-ck-native-agreement-status agreement) 'certified)
  (check-equal? (shared-ck-native-agreement-reasons agreement) '())
  (check-equal? (length (shared-ck-native-agreement-choices agreement))
                expected-count)
  (check-equal? (shared-ck-native-agreement-unexpected agreement) '())
  (check-equal? (shared-ck-native-agreement-missing agreement) '())
  circuit)

;; 1. No-sharing chain.
(define chain
  (checked
   (raw-app 'circuit-u
            (raw-app 'circuit-u (raw-app 'circuit-a)))))
(define chain-circuit
  (check-agreement
   (compile chain
            (list (cons '() 'outer-u)
                  (cons '(1) 'inner-u)
                  (cons '(1 1) 'a)))
   4))
(check-equal? (shared-ck-circuit-node-count chain-circuit) 3)
(check-equal? (shared-ck-circuit-edge-count chain-circuit) 2)
(check-equal? (shared-ck-circuit-unfolded-occurrence-count chain-circuit) 3)
(check-equal? (map (lambda (rank) (decode-addresses chain-circuit rank))
                   '(0 1 2 3))
              '(() ((1)) ((1 1)) ()))
(check-equal?
 (map (lambda (rank)
        (shared-ck-choice-kind
         (shared-ck-circuit-decode chain-circuit rank)))
      '(0 1 2 3))
 '(whole proper proper empty))

;; 2. Minimal diamond.  The two parallel use edges share one child gate but
;; retain independent choices and distinct address lenses.
(define diamond
  (checked (raw-app 'circuit-j (raw-app 'circuit-a) (raw-app 'circuit-a))))
(define diamond-audit
  (audit-sharing-saturation
   diamond
   (qmap (list (cons '() 'j)
               (cons '(1) 'a)
               (cons '(2) 'a)))
   #:antichain-limit 8))
(define diamond-circuit
  (check-agreement (compile-shared-ck-circuit diamond-audit) 5))
(check-equal? (shared-ck-circuit-node-count diamond-circuit) 2)
(check-equal? (shared-ck-circuit-edge-count diamond-circuit) 2)
(check-equal? (shared-ck-circuit-unfolded-occurrence-count diamond-circuit) 3)
(check-equal? (shared-ck-circuit-source-use-multiplicity diamond-circuit 'a) 2)
(define diamond-root-gate (gate diamond-circuit 'j))
(define diamond-lenses (shared-ck-gate-edge-lenses diamond-root-gate))
(check-equal? (map shared-ck-edge-lens-premise-slot diamond-lenses) '(1 2))
(check-equal?
 (map (lambda (lens)
        (sharing-use-edge-child-source
         (shared-ck-edge-lens-use-edge lens)))
      diamond-lenses)
 '(a a))
(check-equal?
 (map (lambda (lens)
        (shared-ck-edge-lens-prefix-address lens root-address root-address))
      diamond-lenses)
 '((1) (2)))

;; Select is rank 0.  In Keep's mixed-radix product, premise 1 is the most
;; significant coordinate and premise order determines singleton ranks.
(check-equal? (map (lambda (rank) (decode-addresses diamond-circuit rank))
                   '(0 1 2 3 4))
              '(() ((1) (2)) ((1)) ((2)) ()))
(check-equal?
 (map (lambda (rank)
        (shared-ck-choice-kind
         (shared-ck-circuit-decode diamond-circuit rank)))
      '(0 1 2 3 4))
 '(whole proper proper proper empty))

;; Correlating the two aliases would offer only whole, both, and empty: count
;; 3 rather than 5.  Reusing the first lens also collapses the right use.
(define correlated-mutant-count
  (add1 (shared-ck-gate-choice-count (gate diamond-circuit 'a))))
(check-equal? correlated-mutant-count 3)
(check-not-equal? correlated-mutant-count
                  (shared-ck-circuit-choice-count diamond-circuit))
(define dropped-lens-mutant-addresses
  (list
   (shared-ck-edge-lens-prefix-address
    (first diamond-lenses) root-address root-address)
   (shared-ck-edge-lens-prefix-address
    (first diamond-lenses) root-address root-address)))
(check-not-equal? dropped-lens-mutant-addresses '((1) (2)))
;; A premise permutation would swap deterministic ranks 2 and 3.
(check-not-equal? (list (decode-addresses diamond-circuit 3)
                        (decode-addresses diamond-circuit 2))
                  '(((1)) ((2))))

;; Whole is witness-free and cannot be decoded as a root cut.
(define diamond-whole (shared-ck-circuit-decode diamond-circuit 0))
(check-equal? (shared-ck-choice-kind diamond-whole) 'whole)
(check-false (shared-ck-choice-resolved-witness diamond-whole))
(check-false
 (sharing-cut-record-native-witness
  (shared-ck-choice-native-record diamond-whole)))
(define root-cut-attempt (make-cut-witness diamond (list root-address)))
(check-true (cut-error? root-cut-attempt))
(check-equal? (cut-error-code root-cut-attempt) 'root-cut)

;; Counts may be evaluated through the generic compact fold without forcing
;; any trace family.
(check-equal?
 (shared-ck-circuit-fold
  diamond-circuit
  #:select (lambda (_node) 1)
  #:keep (lambda (_node retained) retained)
  #:plus + #:times * #:one 1)
 5)

;; 3. Two-level diamond.
(define two-level
  (checked
   (raw-app 'circuit-r
            (raw-app 'circuit-left (raw-app 'circuit-c))
            (raw-app 'circuit-right (raw-app 'circuit-c)))))
(define two-level-audit
  (audit-sharing-saturation
   two-level
   (qmap (list (cons '() 'r)
               (cons '(1) 'left)
               (cons '(1 1) 'c)
               (cons '(2) 'right)
               (cons '(2 1) 'c)))
   #:antichain-limit 32))
(define two-level-circuit
  (check-agreement (compile-shared-ck-circuit two-level-audit) 10))
(for ([addresses
       (in-list '(((1 1)) ((2 1)) ((1) (2 1)) ((1 1) (2))))])
  (define record
    (findf (lambda (candidate)
             (equal? addresses (sharing-cut-record-addresses candidate)))
           (sharing-saturation-audit-unsaturated two-level-audit)))
  (check-not-false record)
  (check-not-false
   (findf (lambda (choice)
            (equal? addresses (shared-ck-choice-addresses choice)))
          (shared-ck-native-agreement-choices
           (shared-ck-circuit-native-agreement two-level-circuit)))))

;; 4. Nested copied macro: one-shot and staged native targets agree, then the
;; compact circuit retains the two copied input addresses in one source fibre.
(define x-port (make-macro-port 'x S))
(define chain-summary
  (compile-macro-summary
   calculus
   (checked (raw-app 'circuit-e (raw-app 'circuit-u raw-hole)))
   (list x-port)
   (list (cons '(1 1) 'x))))
(define dup-summary
  (compile-macro-summary
   calculus
   (checked (raw-app 'circuit-j raw-hole raw-hole))
   (list x-port)
   (list (cons '(1) 'x) (cons '(2) 'x))))
(define macro-profile
  (make-material-profile calculus (list a-occ u-occ j-occ)))
(define macro-selector (prepare-material-hopf-selector macro-profile))
(define a-proof (checked (raw-app 'circuit-a)))
(define macro-comparison
  (audit-material-macro-composition
   chain-summary 'x dup-summary 'x a-proof macro-selector #:limit 128))
(check-true (material-macro-composition-certified? macro-comparison))
(define one-shot-target
  (material-macro-transport-target
   (material-macro-composition-one-shot-audit macro-comparison)))
(define staged-target
  (material-macro-transport-target
   (material-macro-composition-two-stage-audit macro-comparison)))
(check-equal? one-shot-target staged-target)
(define macro-audit
  (audit-sharing-saturation
   one-shot-target
   (qmap (list (cons '() 'extension)
               (cons '(1) 'chain)
               (cons '(1 1) 'copy)
               (cons '(1 1 1) 'input-a)
               (cons '(1 1 2) 'input-a)))
   #:antichain-limit 32))
(define macro-circuit
  (check-agreement (compile-shared-ck-circuit macro-audit) 7))
(check-equal? (shared-ck-circuit-source-use-multiplicity
               macro-circuit 'input-a)
              2)
(define input-gate (gate macro-circuit 'input-a))
(check-equal?
 (sharing-source-node-fibre (shared-ck-gate-source-node input-gate))
 '((1 1 1) (1 1 2)))

;; 5. Sharing tower D3.  Four cached source gates and six ordered use edges
;; represent fifteen occurrence vertices and 677 endpoint-completed choices.
(define (tower-raw depth)
  (if (zero? depth)
      (raw-app 'circuit-a)
      (raw-app 'circuit-j (tower-raw (sub1 depth))
               (tower-raw (sub1 depth)))))
(define tower-depth 3)
(define tower (checked (tower-raw tower-depth)))
(define tower-bindings
  (for/list ([address (in-list (vertex-addresses tower))])
    (cons address
          (string->symbol
           (format "d~a" (- tower-depth (length address)))))))
(define tower-audit
  (audit-sharing-saturation
   tower (qmap tower-bindings)
   #:witness-limit 1024 #:antichain-limit 32))
(define tower-circuit
  (check-agreement (compile-shared-ck-circuit tower-audit) 677 #:limit 700))
(check-equal? (shared-ck-circuit-node-count tower-circuit) 4)
(check-equal? (shared-ck-circuit-edge-count tower-circuit) 6)
(check-equal? (shared-ck-circuit-unfolded-occurrence-count tower-circuit) 15)
(check-equal?
 (map (lambda (source)
        (shared-ck-gate-choice-count (gate tower-circuit source)))
      '(d0 d1 d2 d3))
 '(2 5 26 677))
(check-equal?
 (map (lambda (source)
        (shared-ck-circuit-source-use-multiplicity tower-circuit source))
      '(d0 d1 d2 d3))
 '(8 4 2 1))

(define cap-exact
  (shared-ck-circuit-capped-choice-count tower-circuit 677))
(define cap-small
  (shared-ck-circuit-capped-choice-count tower-circuit 100))
(check-equal? (shared-ck-capped-count-status cap-exact) 'exact)
(check-equal? (shared-ck-capped-count-value cap-exact) 677)
(check-equal? (shared-ck-capped-count-status cap-small) 'exceeds-cap)
(check-false (shared-ck-capped-count-value cap-small))
(define refused-capped-rank
  (shared-ck-circuit-decode tower-circuit 0 #:count-result cap-small))
(check-true (shared-ck-decode-error? refused-capped-rank))
(check-equal? (shared-ck-decode-error-code refused-capped-rank)
              'inexact-capped-count)
(define out-of-range (shared-ck-circuit-decode tower-circuit 677))
(check-true (shared-ck-decode-error? out-of-range))
(check-equal? (shared-ck-decode-error-code out-of-range)
              'rank-out-of-range)

(define truncated-character
  (shared-ck-circuit-character tower-circuit #:term-limit 2))
(check-equal? (sharing-character-expansion-status truncated-character)
              'truncated)
(check-false (sharing-character-expansion-polynomial truncated-character))
(define exact-character
  (shared-ck-circuit-character tower-circuit #:term-limit 4096))
(check-equal? (sharing-character-expansion-status exact-character) 'exact)
(check-equal?
 (sharing-character-expansion-polynomial exact-character)
 (sharing-saturation-audit-recurrence-character tower-audit))

;; 6. Exact profile filtering.  J(A,U(E(A))) has nine full choices.  With E
;; excluded, root-labelled U is not sufficient: whole U(E(A)) is impure, and
;; the two-factor cut {A,U(E(A))} is killed as one complete left monomial.
(define mixed-material
  (checked
   (raw-app 'circuit-j
            (raw-app 'circuit-a)
            (raw-app 'circuit-u
                     (raw-app 'circuit-e (raw-app 'circuit-a))))))
(define mixed-map
  (qmap (list (cons '() 'j)
              (cons '(1) 'left-a)
              (cons '(2) 'u)
              (cons '(2 1) 'e)
              (cons '(2 1 1) 'right-a))))
(define mixed-audit
  (audit-sharing-saturation mixed-material mixed-map
                            #:antichain-limit 32))
(define mixed-circuit
  (check-agreement (compile-shared-ck-circuit mixed-audit) 9))
(define all-profile
  (make-material-profile calculus (list a-occ u-occ e-occ j-occ)))
(define base-profile
  (make-material-profile calculus (list a-occ u-occ j-occ)))
(define all-selector (prepare-material-hopf-selector all-profile))
(define base-selector (prepare-material-hopf-selector base-profile))
(define all-material
  (shared-ck-circuit-material-audit mixed-circuit all-selector
                                    #:rank-limit 16))
(define base-material
  (shared-ck-circuit-material-audit mixed-circuit base-selector
                                    #:rank-limit 16))
(check-equal? (shared-ck-material-audit-status all-material) 'certified)
(check-equal? (shared-ck-material-audit-choice-count all-material) 9)
(check-equal? (shared-ck-material-audit-status base-material) 'certified)
(check-equal? (shared-ck-material-audit-choice-count base-material) 4)
(check-equal? (shared-ck-material-audit-collected-coaction base-material)
              (shared-ck-material-audit-reference-coaction base-material))

(define impure-whole-u
  (findf
   (lambda (record)
     (equal? (sharing-cut-record-addresses record) '((2))))
   (sharing-saturation-audit-records mixed-audit)))
(define impure-multifactor
  (findf
   (lambda (record)
     (equal? (sharing-cut-record-addresses record) '((1) (2))))
   (sharing-saturation-audit-records mixed-audit)))
(define pure-multifactor
  (findf
   (lambda (record)
     (equal? (sharing-cut-record-addresses record) '((1) (2 1 1))))
   (sharing-saturation-audit-records mixed-audit)))
(check-not-false impure-whole-u)
(check-not-false impure-multifactor)
(check-not-false pure-multifactor)
;; Both selected roots look designated in the naive root-only mutant.
(check-true
 (andmap
  (lambda (address)
    (material-profile-designates?
     base-profile
     (checked-node-occurrence
      (vertex-at-address mixed-material address))))
  '((1) (2))))
(check-false
 (material-hopf-selector-forest-pure?
  base-selector (sharing-cut-record-forest impure-whole-u)))
(check-false
 (material-hopf-selector-forest-pure?
  base-selector (sharing-cut-record-forest impure-multifactor)))
(check-true
 (material-hopf-selector-forest-pure?
  base-selector (sharing-cut-record-forest pure-multifactor)))
(check-false (memq impure-multifactor
                   (shared-ck-material-audit-records base-material)))
(check-not-false (memq pure-multifactor
                       (shared-ck-material-audit-records base-material)))

;; Box^G, the empty-forest algebra unit, and formal additive zero remain three
;; distinct native notions.  The empty choice contributes the unit even when
;; a Select alternative has material weight zero.
(define box (identity-context calculus S))
(define empty-forest (empty-proof-forest calculus))
(define additive-zero (formal-zero calculus))
(check-false (complete-proof? box))
(check-true (proof-forest-empty? empty-forest))
(check-true (formal-zero? additive-zero))
(check-false (formal-zero? (forest-basis empty-forest)))
(check-exn
 exn:fail:contract?
 (lambda ()
   (audit-sharing-saturation box (qmap '()))))

;; Failed/truncated and foreign audits cannot be compiled.  The source-
;; saturated sector remains the original limit-guarded oracle, not a compact
;; circuit claim.
(define truncated-audit
  (audit-sharing-saturation diamond
                            (sharing-saturation-audit-source-map diamond-audit)
                            #:antichain-limit 1))
(check-equal? (sharing-saturation-audit-status truncated-audit) 'inconclusive)
(check-exn exn:fail:contract?
           (lambda () (compile-shared-ck-circuit truncated-audit)))
(define foreign-calculus (make-equipped-calculus occurrences))
(check-exn
 exn:fail:contract?
 (lambda ()
   (compile-shared-ck-circuit diamond-audit
                              #:calculus foreign-calculus)))

(printf
 (string-append
  "SHARED CK CIRCUIT: chain gates/edges/occurrences/choices=3/2/3/4; "
  "diamond=2/2/3/5; two-level choices=10; nested macro choices=7; "
  "tower D3=4/6/15/677 with gate counts 2,5,26,677; "
  "material J(A,U(E(A))) full/base=9/4; all bounded native agreements "
  "certified.\n"))
