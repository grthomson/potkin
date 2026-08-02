#lang racket/base

(require racket/list
         "boundary.rkt")

(provide component-edge?
         make-component-edge
         component-edge-premise-slot
         component-edge-source-index
         component-edge-target-index
         component-source?
         component-source-premise-slot
         component-source-component-index
         component-incidence?
         make-component-incidence
         component-incidence-premises
         component-incidence-conclusion
         component-incidence-edges
         component-incidence-matches-profile?
         component-incidence-source-universe
         component-incidence-target-universe
         component-incidence-functional?
         component-incidence-inverse-functional?
         component-incidence-total?
         component-incidence-surjective?
         component-incidence-splitting?
         component-incidence-merger?
         component-incidence-erasure?
         component-incidence-unsupported-creation?)

;; A component edge names one ordered proof-premise slot, one local component
;; occurrence in that whole premise boundary, and one local component
;; occurrence in the conclusion.  Constructors are controlled so a typed
;; incidence value cannot contain unchecked endpoints.
(struct component-edge (premise-slot source-index target-index)
  #:constructor-name make-component-edge/internal
  #:sealed
  #:property prop:equal+hash
  (list
   (lambda (left right recur)
     (and (component-edge? right)
          (= (component-edge-premise-slot left)
             (component-edge-premise-slot right))
          (= (component-edge-source-index left)
             (component-edge-source-index right))
          (= (component-edge-target-index left)
             (component-edge-target-index right))))
   (lambda (value recur)
     (recur (list (component-edge-premise-slot value)
                  (component-edge-source-index value)
                  (component-edge-target-index value))))
   (lambda (value recur)
     (recur (list (component-edge-target-index value)
                  (component-edge-source-index value)
                  (component-edge-premise-slot value))))))

(struct component-source (premise-slot component-index)
  #:constructor-name make-component-source/internal
  #:sealed
  #:property prop:equal+hash
  (list
   (lambda (left right recur)
     (and (component-source? right)
          (= (component-source-premise-slot left)
             (component-source-premise-slot right))
          (= (component-source-component-index left)
             (component-source-component-index right))))
   (lambda (value recur)
     (recur (list (component-source-premise-slot value)
                  (component-source-component-index value))))
   (lambda (value recur)
     (recur (list (component-source-component-index value)
                  (component-source-premise-slot value))))))

;; Exact endpoint boundaries are part of the controlled value.  This lets the
;; occurrence constructor reject a typed relation prepared for a different
;; concrete rule profile while leaving legacy opaque incidence untouched.
(struct component-incidence (premises conclusion edges)
  #:constructor-name make-component-incidence/internal
  #:sealed
  #:property prop:equal+hash
  (list
   (lambda (left right recur)
     (and (component-incidence? right)
          (recur (component-incidence-premises left)
                 (component-incidence-premises right))
          (recur (component-incidence-conclusion left)
                 (component-incidence-conclusion right))
          (recur (component-incidence-edges left)
                 (component-incidence-edges right))))
   (lambda (value recur)
     (recur (list (component-incidence-premises value)
                  (component-incidence-conclusion value)
                  (component-incidence-edges value))))
   (lambda (value recur)
     (recur (list (component-incidence-edges value)
                  (component-incidence-conclusion value)
                  (component-incidence-premises value))))))

(define (make-component-edge premise-slot source-index target-index)
  (unless (exact-positive-integer? premise-slot)
    (raise-argument-error
     'make-component-edge "exact-positive-integer? premise-slot" premise-slot))
  (unless (exact-positive-integer? source-index)
    (raise-argument-error
     'make-component-edge "exact-positive-integer? source-index" source-index))
  (unless (exact-positive-integer? target-index)
    (raise-argument-error
     'make-component-edge "exact-positive-integer? target-index" target-index))
  (make-component-edge/internal premise-slot source-index target-index))

(define (component-edge<? left right)
  (or (< (component-edge-premise-slot left)
         (component-edge-premise-slot right))
      (and (= (component-edge-premise-slot left)
              (component-edge-premise-slot right))
           (or (< (component-edge-source-index left)
                  (component-edge-source-index right))
               (and (= (component-edge-source-index left)
                       (component-edge-source-index right))
                    (< (component-edge-target-index left)
                       (component-edge-target-index right)))))))

(define (check-edge-endpoints premises conclusion edge)
  (define premise-slot (component-edge-premise-slot edge))
  (unless (<= premise-slot (length premises))
    (raise-arguments-error
     'make-component-incidence
     "an incidence edge names a nonexistent ordered premise slot"
     "premise slot" premise-slot
     "premise count" (length premises)
     "edge" edge))
  (define premise (list-ref premises (sub1 premise-slot)))
  (define source-index (component-edge-source-index edge))
  (unless (<= source-index (hypersequent-size premise))
    (raise-arguments-error
     'make-component-incidence
     "an incidence edge names a nonexistent component occurrence in its premise"
     "premise slot" premise-slot
     "source component index" source-index
     "premise component count" (hypersequent-size premise)
     "edge" edge))
  (define target-index (component-edge-target-index edge))
  (unless (<= target-index (hypersequent-size conclusion))
    (raise-arguments-error
     'make-component-incidence
     "an incidence edge names a nonexistent conclusion component occurrence"
     "target component index" target-index
     "conclusion component count" (hypersequent-size conclusion)
     "edge" edge)))

(define (make-component-incidence premises conclusion edges)
  (unless (and (list? premises) (andmap hypersequent? premises))
    (raise-argument-error
     'make-component-incidence "(listof hypersequent?)" premises))
  (unless (hypersequent? conclusion)
    (raise-argument-error
     'make-component-incidence "hypersequent? conclusion" conclusion))
  (unless (and (list? edges) (andmap component-edge? edges))
    (raise-argument-error
     'make-component-incidence "(listof component-edge?)" edges))
  (for ([edge (in-list edges)])
    (check-edge-endpoints premises conclusion edge))
  (make-component-incidence/internal
   (for/list ([premise (in-list premises)]) premise)
   conclusion
   (sort (remove-duplicates edges equal?) component-edge<?)))

(define (component-incidence-matches-profile? incidence premises conclusion)
  (unless (component-incidence? incidence)
    (raise-argument-error
     'component-incidence-matches-profile? "component-incidence?" incidence))
  (unless (and (list? premises) (andmap hypersequent? premises))
    (raise-argument-error
     'component-incidence-matches-profile? "(listof hypersequent?)" premises))
  (unless (hypersequent? conclusion)
    (raise-argument-error
     'component-incidence-matches-profile? "hypersequent? conclusion" conclusion))
  (and (equal? (component-incidence-premises incidence) premises)
       (equal? (component-incidence-conclusion incidence) conclusion)))

(define (component-incidence-source-universe incidence)
  (unless (component-incidence? incidence)
    (raise-argument-error
     'component-incidence-source-universe "component-incidence?" incidence))
  (append*
   (for/list ([premise (in-list (component-incidence-premises incidence))]
              [slot (in-naturals 1)])
     (for/list ([component-index
                 (in-range 1 (add1 (hypersequent-size premise)))])
       (make-component-source/internal slot component-index)))))

(define (component-incidence-target-universe incidence)
  (unless (component-incidence? incidence)
    (raise-argument-error
     'component-incidence-target-universe "component-incidence?" incidence))
  (range 1
         (add1
          (hypersequent-size (component-incidence-conclusion incidence)))))

(define (component-incidence-functional? incidence)
  (unless (component-incidence? incidence)
    (raise-argument-error
     'component-incidence-functional? "component-incidence?" incidence))
  (for/and ([source (in-list (component-incidence-source-universe incidence))])
    (<= (length
         (remove-duplicates
          (for/list ([edge (in-list (component-incidence-edges incidence))]
                     #:when
                     (and (= (component-source-premise-slot source)
                             (component-edge-premise-slot edge))
                          (= (component-source-component-index source)
                             (component-edge-source-index edge))))
            (component-edge-target-index edge))))
        1)))

(define (component-incidence-inverse-functional? incidence)
  (unless (component-incidence? incidence)
    (raise-argument-error
     'component-incidence-inverse-functional? "component-incidence?" incidence))
  (for/and ([target (in-list (component-incidence-target-universe incidence))])
    (<= (length
         (remove-duplicates
          (for/list ([edge (in-list (component-incidence-edges incidence))]
                     #:when (= target (component-edge-target-index edge)))
            (cons (component-edge-premise-slot edge)
                  (component-edge-source-index edge)))
          equal?))
        1)))

(define (component-incidence-total? incidence)
  (unless (component-incidence? incidence)
    (raise-argument-error
     'component-incidence-total? "component-incidence?" incidence))
  (for/and ([source (in-list (component-incidence-source-universe incidence))])
    (for/or ([edge (in-list (component-incidence-edges incidence))])
      (and (= (component-source-premise-slot source)
              (component-edge-premise-slot edge))
           (= (component-source-component-index source)
              (component-edge-source-index edge))))))

(define (component-incidence-surjective? incidence)
  (unless (component-incidence? incidence)
    (raise-argument-error
     'component-incidence-surjective? "component-incidence?" incidence))
  (for/and ([target (in-list (component-incidence-target-universe incidence))])
    (for/or ([edge (in-list (component-incidence-edges incidence))])
      (= target (component-edge-target-index edge)))))

(define (component-incidence-splitting? incidence)
  (not (component-incidence-functional? incidence)))

(define (component-incidence-merger? incidence)
  (not (component-incidence-inverse-functional? incidence)))

(define (component-incidence-erasure? incidence)
  (not (component-incidence-total? incidence)))

(define (component-incidence-unsupported-creation? incidence)
  (not (component-incidence-surjective? incidence)))
