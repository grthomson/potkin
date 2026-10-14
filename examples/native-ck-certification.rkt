#lang racket/base

(require racket/list "../potkin/main.rkt")

;; Run: racket examples/native-ck-certification.rkt
;; The same native boundary is SAFE forward but crossed by an inverse-created
;; tensor instance under the bidirectional policy. No commutative API changes.
(define (h left right) (singleton-hypersequent left (list right)))
(define (ground id left right)
  (make-concrete-occurrence id '() (h left right) #:kind 'material))
(define K (make-mixed-schema-calculus
           (list (ground 's '() 'd) (ground 'p '() 'a)
                 (ground 'q '(d) 'b) (ground 'r '(a b) 'c))))
(define (g id) (validate-candidate K (raw-app id)))
(define tr (mixed-apply K 'tensorR (list (g 'p) (g 'q))))
(define tl (mixed-apply K 'tensorL (list (g 'r)) #:indices '(1 2)))
(define inner (mixed-apply K 'cut+ (list tr tl) #:indices '(1)))
(define source (mixed-apply K 'cut+ (list (g 's) inner) #:indices '(1)))
(define frontier (make-cut-witness source '((2))))
(for ([policy '(forward bidirectional)])
  (define answer (certify-native-ck-boundary source frontier #:policy policy))
  (printf "~a: ~a (~a)\n" policy (ck-boundary-result-status answer)
          (ck-boundary-result-reason answer))
  (define certificate (ck-boundary-result-certificate answer))
  (when certificate
    (printf "  independent verifier: ~a\n"
            (ck-closure-report-status (verify-ck-boundary-certificate certificate)))
    (for ([edge (in-list (ck-boundary-certificate-edges certificate))])
      (define move (ck-state-edge-move edge))
      (printf "  ~a at ~a: ~a\n" (ck-schema-move-schema move)
              (ck-schema-move-address move) (ck-schema-move-direction move)))
    (when (ck-boundary-certificate-crossing certificate)
      (printf "  crossing (block, vertex, compartment, vertex, compartment): ~s\n"
              (ck-boundary-certificate-crossing certificate)))))
