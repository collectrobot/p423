;; finalize-frame-locations.ss
;;
;; part of p423-sp12/srwaggon-p423
;; http://github.iu.edu/p423-sp12/srwaggon-p423
;; introduced in A5
;; 2012 / 2 / 28
;;
;; Samuel Waggoner
;; srwaggon@indiana.edu
;; revised in A7
;; 2012 / 4 / 10

#!chezscheme
(library (compiler finalize-frame-locations)
  (export finalize-frame-locations)
  (import
   ;; Load Chez Scheme primitives:
   (chezscheme)
   ;; Load compiler framework:
   (framework match)
   (framework helpers)
   (compiler helpers)
  )


  #|
  || Sure, a grammar walk, why not?
  || I mean, people used to entertain themselves
  || by rolling a hoop down a hill with a stick.
  |#
(define-who (finalize-frame-locations program)

  (define (Var env)
    (lambda (var)
      (match var
        [,uvar (guard (uvar? uvar) (assq uvar env))
               (let ([x (cdr (assq uvar env))])
                 (if (list? x) (car x) x))]
        [,reg (guard (register? reg)) reg]
        [,fvar (guard (frame-var? fvar)) fvar]
        [,else else]
        )))

  (define (Triv env)
    (lambda (triv)
      (match triv
        [,int (guard (integer? int)) int]
        [,label (guard (label? label)) label]
        [,[(Var env) -> var] var]
        [,else (invalid who 'Triv else)]
        )))

  (define (Effect env)
    (lambda (effect)
      (match effect
        [(begin ,[effect*] ... ,[effect])
         `(begin ,effect* ... ,effect)]
        [(if ,[(Pred env) -> pred] ,[conseq] ,[altern])
         `(if ,pred ,conseq ,altern)]
        [(mset! ,[(Triv env) -> base] ,[(Triv env) -> offset] ,[(Triv env) -> val])
         `(mset! ,base ,offset ,val)]
        [(nop) `(nop)]
        [(return-point ,label ,[(Tail env) -> t]) `(return-point ,label ,t)]
        [(set! ,[(Var env) -> var] (mref ,[(Triv env) -> triv0] ,[(Triv env) -> triv1]))
         `(set! ,var (mref ,triv0 ,triv1))]
        [(set! ,[(Var env) -> var] (,binop ,[(Triv env) -> triv0] ,[(Triv env) -> triv1]))
         (guard (binop? binop)) `(set! ,var (,binop ,triv0 ,triv1))]
        [(set! ,[(Var env) -> var] ,[(Triv env) -> triv])
         (if (eq? var triv) `(nop) `(set! ,var ,triv))]
        [,else (invalid who 'Effect else)]
        )))
  
  (define (Pred env)
    (lambda (pred)
      (match pred
        [(true) `(true)]
        [(false) `(false)]
        [(begin ,[(Effect env) -> effect*] ... ,[pred])
         `(begin ,effect* ... ,pred)]
        [(if ,[pred] ,[conseq] ,[altern])
         `(if ,pred ,conseq ,altern)]
        [(,relop ,[(Triv env) -> triv0] ,[(Triv env) -> triv1])
         `(,relop ,triv0 ,triv1)]
        [,else (invalid who 'Pred else)]
        )))
  
  (define (Tail env)
    (lambda (tail)
      (match tail
        [(begin ,[(Effect env) -> effect*] ... ,[tail])
         `(begin ,effect* ... ,tail)]
        [(if ,[(Pred env) -> pred] ,[conseq] ,[altern])
         `(if ,pred ,conseq ,altern)]
        [(,[(Triv env) -> triv] ,[(Triv env) -> loc*] ...) `(,triv ,loc* ...)]
        [,else (invalid who 'Tail else)]
        )))

  (define (loop als tail)
    (match tail
      [,x (guard (uvar? x))
          (cond
            [(assq x als) => cadr]
            [else x])]
      [(set! ,[x] ,[y]) (if (eq? x y)
                            `(nop)
                            `(set! ,x ,y))]
      [(,[x] ...) `(,x ...)]
      [,else else]))

  (define (Body body)
    (match body
      [(locals (,local* ...)
         (ulocals (,ulocal* ...)
           (locate ([,uvar* ,loc*] ...)
             (frame-conflict ,fgraph
               ,[(Tail (map cons uvar* loc*)) -> tail]))))
       `(locals (,local* ...)
          (ulocals (,ulocal* ...)
            (locate ([,uvar* ,loc*] ...)
              (frame-conflict ,fgraph ,tail))))]
      [(locate (,home* ...) ,[(Tail home*) -> tail])
       `(locate (,home* ...) ,tail)]
      [,else (invalid who 'Body else)]
      ))
  
  (define (Program program)
    (match program
      [(letrec ([,label* (lambda () ,[Body -> body*])] ...) ,[Body -> body])
       `(letrec ([,label* (lambda () ,body*)] ...) ,body)]
      [,else (invalid who 'Program else)]
      ))
  
  (Program program)
    
)) ;; end library
