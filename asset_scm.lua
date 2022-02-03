# -*- scheme -*-
return {
['lib.sm'] = [[
; -*- scheme -*-
(define (add1 x) (add 1 x))

]],
['test.sm'] = [[
#lang s-expr "sm.rkt" ;; -*- scheme -*-

;; Subset of Scheme representing sm.h style protothreads.
;;
;; This is a test file with nonsense code that exercises all forms,
;; for visual inspection of code generation.  See test_csp.sm for a
;; real example.

;(let* ((a 123)
;       (b 345))
;      (add a b 1))

;; TODO:
;; - set!
;; - multi-arg tail calls

(define (fun1)
  (let*
      ((a
        (let* ((b (read chan1))
               (c (read chan1)))
          (add a ;; Free variable
               (add b c))))
       (d (read chan1))
       (e (let* ((x (add a (add 1 2)))
                 (y (add d 2)))
            (add x y)))
       (f (fun3 e))
       (g (let* ((l 5))
            (add f l)))
       (h (if g (add f g) (add f f)))
       )
    (send (add d h))
    (send e)
    (send f)
    (for ((i (in-range 3)))
      (send (add (read chan1) i)))
    
    ;; (if f (fun1) (fun2))
    (fun2)
    ))

(define (fun2)
  (let* ((abc 123)
         (def
          (select
           ;;((write 1 (add 1 2)) (write 1 123))
           ((write 1 abc) 123)
           ((read  0 v1)  (add 1 v1))
           )))
    ;;(select
    ;; ((read 0 v1)      (send 1 v1))
    ;; ((send 1 (+ 1 2)) (send 1 123)))
    (if (add def 0)
        (fun1)
        (fun2))
    ))

(define (fun3 x)
  (let*
      ((a (read chan2))
       (b (read chan2)))
    (add x (add a b))))




]],
['test1.sm'] = [[
#lang s-expr "sm.rkt" ;; -*- scheme -*-

;; Semantics

;; Attempt is to stay as close to Scheme as possible, with some
;; restrictions on valid code for the bits that get translated to C.

;; SMC (Scheme to Machine Compiler or State Machine Compiler) executes
;; the start routine at compile time.  Its purpose is to construct
;; tasks and perform a coroutine tail call into the task network.
;; That call is "frozen" and compiled to C, essentially compiling the
;; contination at that point.

;; The language subset inside the Scheme code that is compiled to C is
;; reduced: all function calls are inlined, and tail calls are mapped
;; to gotos.  All lambdas need to be combined with a "functional form"
;; so they can be inlined.  Only downward closures are (will be)
;; supported.

;; The example creates two tasks that run the same code.  The tasks
;; are instantiated with a reference to the other task so they can
;; perform a coroutine call.

;; Add 1 to value before bouncing it to the other task, then yield it
;; to C caller.  FIXME: Represent the C caller as just another
;; coroutine.
(define (test1 other)
  (define (main a)
    (let* ((b (co other (add 1 a))))
      (yield b)
      (main b)))
  main)


(define (start)
  ;; The lowest level communication primitive is a coroutine call.
  ;; Startup is a 3-step process:
  ;; 1. Create the task structures
  (let* ((t1 (make-task))
         (t2 (make-task)))
    ;; 2. Associate tasks with entry points
    (load-task! t1 (test1 t2))
    (load-task! t2 (test1 t1))
    ;; 3. Transfer control to a specific task.
    (co t1 0)))

;; Implementation: the compiler is hidden inside the 'co' function.
;; It takes the task object referred to by 't1' to recover the closure
;; created by '(test1 t2)', which contains in its environment all the
;; recursive definitions needed to compile specialized C code.
;;
;; Note that code in test1 body can be parameterized by values that
;; are only valid at compile time, e.g. 'other' contains a task and
;; can only be passed to 'co', which will compile into labels and goto
;; based on information in that task struct.





]],
['test2.sm'] = [[
#lang s-expr "sm.rkt" ;; -*- scheme -*-

(import lib)

(define (program)
  (define (f a)
    (yield a)
    (g (add 1 a)))
  (define (g a)
    (f a))
  f)
(define (start)
  (let* ((t1 (make-task)))
    (load-task! t1 (program))
    (co t1 0)))
]],
['test_co.sm'] = [[
#lang s-expr "sm.rkt" ;; -*- scheme -*-

;; Test simpler co-routine abstraction.
;; Test application is a client and a server thread.

;; FIXME: this doesn't use channels.

(define (client serv)
  (define (main ign)
    (for ((i (in-range 10)))
      ;; 'rpc' gets inlined.  the 2 calls produce 4 blocking points.
      (let* ((x (co serv i))
             (y (co serv (add 100 i))))
        ;; 'yield' performs coroutine call to C end.
        (yield (add x y))))
    (main ign))
  main ;; entry point
  )

;; Inline + recursion error test.
(define (reca) (recb))
(define (recb) (recc))
(define (recc) (reca))

;; FIXME: use if

(define (server clnt)
  (define (add1 x) (add x 1)) ;; will be inlined
  (define (main prev_rpl)
    ;; Note that this is backwards!
    (let* ((req (co clnt prev_rpl))
           (rpl (add1 req)))
      (main rpl)))
  ;; (reca) ;; inline recursion error test
  ;; client will ignore the first "reply?
  ;; yeah coroutines are a bit raw...
  main)


;; See test1.sm for comments on semantics.

(define (start)
  (let* ((t1 (make-task))
         (t2 (make-task)))
    (load-task! t1 (server t2))
    (load-task! t2 (client t1))
    (co t1 0)
    ))
]],
['test_csp.sm'] = [[
#lang s-expr "sm.rkt" ;; -*- scheme -*-

;; FIXME: This broke.  Focus is on test_co.sm first.

(define (prog1 c1 c2)

(define (fun1 x y)
  (write 1 123)
  (let* ((a (read 0)))
    (write 1 a)
    (if (add a (read 0))
        (begin
          (write 1 a)
          (fun1 a a))
        (fun2))))
  
(define (fun2)
  (let* ((abc 123)
         (def
          (select
           ;;((write 1 (add 1 2)) (write 1 123))
           ((write 1 abc) 123)
           ((read  0 v1)  (add 1 v1))
           )))
    ;;(select
    ;; ((read 0 v1)      (send 1 v1))
    ;; ((send 1 (+ 1 2)) (send 1 123)))
    (if (add def 0)
        (fun1 abc abc)
        (fun2))
    ))

(fun2)

)

;; The .sm language only allows function definitions in the module
;; form.  We do provide an 'entry point' with Scheme code that runs at
;; compile time.

(define (start)
  (let* ((c1 (make-channel))
         (c2 (make-channel)))
    (spawn! (lambda () (prog1 c1 c2)))
    (spawn! (lambda () (prog1 c2 c1)))
    ))







]],
['x.sm'] = [[
(module (test)
  (define (x)
    (let* ((a 1)
           (b 2))
      (add a b)
      (x))))]],
['hello.scm'] = [[
;; Scheme
;; Same form as .sm
(module (test)
  (define (f a)
    (let* ((b (add a a)))
      (add a b)))
  (f 3))
;(module (test)
;  (define (main)
;    (add 1 2)))
]],
['test_rvm.scm'] = [[
;; This file is modified from:
;; https://github.com/udem-dlteam/ribbit
;; https://github.com/udem-dlteam/ribbit/blob/main/src/host/scm/rvm.scm
;; BSD 3-Clause License

;; The idea is to modify this such that it can be compiled by uc_tools
;; slc.lua and possibly further minified.

;; Changes to make it work for now.  To revisit later.
;; - uc_tools/lua/lib/se.lua doesn't support strings: replaced with quoted atoms
;; - removed cond-expand debug and gambit clauses
;; - changed '#(...) to (vector ...)
;; - wrapped infix primitives

(define pair-type      0)
(define procedure-type 1)
(define symbol-type    2)
(define string-type    3)
(define vector-type    4)
(define singleton-type 5)

(define (_rib? x) (vector? x))
(define (_rib x y z) (vector x y z))
(define (_field0 x) (vector-ref x 0))
(define (_field1 x) (vector-ref x 1))
(define (_field2 x) (vector-ref x 2))
(define (_field0-set! x y) (vector-set! x 0 y))
(define (_field1-set! x y) (vector-set! x 1 y))
(define (_field2-set! x y) (vector-set! x 2 y))

(define (instance? type)
  (lambda (x) (and (_rib? x) (eqv? (_field2 x) type))))

(define _pair? (instance? pair-type))
(define (_cons car cdr) (_rib car cdr pair-type))
(define (_car pair) (_field0 pair))
(define (_cdr pair) (_field1 pair))
(define (_set-car! pair x) (_field0-set! pair x))

(define (_list->string lst) (_rib lst (_length lst) string-type))

(define (_string->uninterned-symbol str) (_rib _false str symbol-type))

(define _false (_rib 0 0 singleton-type))
(define _true  (_rib 0 0 singleton-type))
(define _nil   (_rib 0 0 singleton-type))

(define (_list-tail lst i)
  (if (< 0 i)
      (_list-tail (_cdr lst) (- i 1))
      lst))

(define (_length lst)
  (if (_pair? lst)
      (+ 1 (_length (_cdr lst)))
      0))

(define pos 0)

(define (get-byte)
  (let ((x (char->integer (string-ref input pos))))
    (set! pos (+ pos 1))
    ;; (desc x)
    x))

(define (decode)

  (define eb/2 46) ;; half of encoding base (92)

  (define (get-code)
    (let ((x (- (get-byte) 35)))
      (if (< x 0) 57 x)))

  (define (get-int n)
    (let ((x (get-code))
          (y (* n eb/2)))
      (if (< x eb/2)
          (+ y x)
          (get-int (+ y (- x eb/2))))))

  (define (build-symtbl)

    (define (add-symbol chars symtbl)
      ;; (desc symtbl)
      (_cons (_string->uninterned-symbol (_list->string chars))
             symtbl))

    (let loop1 ((n (get-int 0)) (symtbl _nil))
      (if (< 0 n)
          (loop1 (- n 1) (add-symbol _nil symtbl))
          (let loop2 ((symtbl symtbl))
            (let loop3 ((chars _nil))
              (let ((x (get-byte)))
                (if (= x 44) ;; #\, separates symbols
                    (loop2 (add-symbol chars symtbl))
                    (if (= x 59) ;; #\; terminates symbol list
                        (add-symbol chars symtbl)
                        (loop3 (_cons x chars))))))))))
  (let ((symtbl (build-symtbl)))

    (define (decode-loop stack)

      (define (sym n)
        (_car (_list-tail symtbl n)))

      (define (add-instruction op opnd stack)
;;        (pp (list (vector-ref '#(jump/call set get const if) op) opnd))
        (_set-car! stack (_rib op opnd (_car stack)))
        (decode-loop stack))

      (let ((x (get-code)))
        (let loop ((op 0) (n x))
          (let ((d (vector-ref (vector 20 30 0 10 11 4) op)))
            (if (< (+ 2 d) n)
                (loop (+ op 1) (- n (+ d 3)))
                (if (< 90 x)
                    (add-instruction 4 ;; if
                                     (_car stack)
                                     (_cdr stack))
                    (let ((stack (if (= op 0) (_cons 0 stack) stack))
                          (opnd (if (< n d)
                                    (if (< op 3)
                                        (sym n)
                                        n)
                                    (if (= n d)
                                        (get-int 0)
                                        (sym (get-int (- (- n d) 1)))))))
                      (if (< 4 op)
                          (let ((proc (_rib
                                       (_rib opnd 0 (_car stack))
                                       _nil
                                       procedure-type))
                                (stack (_cdr stack)))
                            (if (_rib? stack)
                                (add-instruction 3 ;; const-proc
                                                 proc
                                                 stack)
                                proc))
                          (add-instruction (if (< 0 op) (- op 1) 0)
                                           opnd
                                           stack)))))))))

    (let ((main-proc (decode-loop 0)))

      ;; set predefined globals (always 4 first in the symbol table)

      (define (set-global val)
        (_field0-set! (_car symtbl) val)
        (set! symtbl (_cdr symtbl)))
;;(pp (list 'pos= pos))
;;(pp (list 'symtbl= (convert symtbl)))

      (set-global (_rib 0 symtbl procedure-type)) ;; rib  = primitive 0
      (set-global _false) ;; false  = #f
      (set-global _true)  ;; true   = #t
      (set-global _nil)   ;; nil    = ()

      main-proc)))

(define (trace-instruction name opnd stack)
  (desc (vector name opnd stack))
  0)

(define (run1 pc stack)

  (let run ((pc pc) (stack stack))

  (define (get-cont stack)
    (let loop ((stack stack))
      (if (_rib? (_field2 stack)) stack (loop (_cdr stack)))))

  (define (get-var opnd)
    (_field0 (if (_rib? opnd) opnd (_list-tail stack opnd))))

  (define (set-var opnd val)
    (_field0-set! (if (_rib? opnd) opnd (_list-tail stack opnd)) val))

  (desc (_field0 pc))

  (let ((instr (_field0 pc))
        (opnd (_field1 pc))
        (next (_field2 pc)))

    (case instr

      ((0) ;; jump/call
       (trace-instruction (if (eqv? 0 next) 'jump 'call) opnd stack)
       (let* ((proc (get-var opnd))
              (code (_field0 proc)))
         (if (_rib? code)

             ;; calling a lambda
             (let ((new-cont (_rib 0 proc 0)))
               (let loop ((nargs (_field0 code))
                          (new-stack new-cont)
                          (stack stack))
                 (if (< 0 nargs)
                     (loop (- nargs 1)
                           (_cons (_car stack) new-stack)
                           (_cdr stack))
                     (begin
                       (if (_rib? next) ;; non-tail call?
                           (begin
                             (_field0-set! new-cont stack)
                             (_field2-set! new-cont next))
                           (let ((k (get-cont stack)))
                             (_field0-set! new-cont (_field0 k))
                             (_field2-set! new-cont (_field2 k))))
                       (run (_field2 code)
                            new-stack)))))

             ;; calling a primitive
             (let ((stack ((vector-ref primitives code) stack)))
               (run (if (_rib? next) ;; non-tail call?
                        next
                        (let ((cont (get-cont stack)))
                          (_field1-set! stack (_field0 cont))
                          (_field2 cont)))
                    stack)))))

      ((1) ;; set
       (trace-instruction 'set opnd stack)
       (set-var opnd (_car stack))
       (run next
            (_cdr stack)))

      ((2) ;; get
       (trace-instruction 'get opnd stack)
       (run next
            (_cons (get-var opnd) stack)))

      ((3) ;; const
       (trace-instruction 'const opnd stack)
       (run next
            (_cons opnd stack)))

      ((4) ;; if
       (trace-instruction 'if #f stack)
       (run (if (eqv? (_car stack) _false) next opnd)
            (_cdr stack))))))
)

(define (prim0 f)
  (lambda (stack)
    (_cons (f) stack)))

(define (prim1 f)
  (lambda (stack)
    (let* ((x (_car stack)) (stack (_cdr stack)))
      (_cons (f x) stack))))

(define (prim2 f)
  (lambda (stack)
    (let* ((y (_car stack)) (stack (_cdr stack))
           (x (_car stack)) (stack (_cdr stack)))
      (_cons (f x y) stack))))

(define (prim3 f)
  (lambda (stack)
    (let* ((z (_car stack)) (stack (_cdr stack))
           (y (_car stack)) (stack (_cdr stack))
           (x (_car stack)) (stack (_cdr stack)))
      (_cons (f x y z) stack))))

(define (boolean x)
  (if x _true _false))

(define primitives
  (vector (prim3 _rib)             ;; 0
          (prim1 (lambda (x) x))   ;; 1
          _cdr                     ;; 2
          (prim2 (lambda (y x) x)) ;; 3

          (lambda (stack) ;; 4
            (let* ((x (_car stack)) (stack (_cdr stack)))
              (_cons (_rib (_field0 x) stack procedure-type) stack)))

          (prim1 (lambda (x) (boolean (_rib? x)))) ;; 5
          (prim1 _field0) ;; 6
          (prim1 _field1) ;; 7
          (prim1 _field2) ;; 8
          (prim2 (lambda (x y) (_field0-set! x y) y)) ;; 9
          (prim2 (lambda (x y) (_field1-set! x y) y)) ;; 10
          (prim2 (lambda (x y) (_field2-set! x y) y)) ;; 11
          (prim2 (lambda (x y) (boolean (eqv? x y)))) ;; 12
          (prim2 (lambda (x y) (boolean (< x y)))) ;; 13
          (prim2 (lambda (x y) (+ x y))) ;; 14
          (prim2 (lambda (x y) (- x y))) ;; 15
          (prim2 (lambda (x y) (* x y))) ;; 16
          (prim2 quotient) ;; 17

          (prim0 (lambda () ;; 18
                   (if (< pos (string-length input))
                       (get-byte)
                       (let ((c (read-char)))
                         (if (char? c) (char->integer c) -1)))))

          (prim1 (lambda (x) ;; 19
                   (write-char (integer->char x))
                   x))))


(let ((x (decode)))
  ;; (desc x)
  (run1 (_field2 (_field0 x)) ;; instruction stream of main procedure
        (_rib 0 0 (_rib 5 0 0)))) ;; primordial continuation = halt
]],
['test_scheme.scm'] = [[
(define (x a b) (add a b))
(define (y z q) (add z q))


;; Note that non-definitions are currently not handled properly for
;; hoas mode.
;;(add 1 2)
;;(x 1 (x 2 3))
;;
(define (test_if)  (let* ((a (if 1 2 3))) a))

;; \(define (test_anf) (add 1 (add 2 3)))

(define lala (x 1 2))
lala
123
asdf




]],
['test_slc.scm'] = [[
(define (test_add a b) (add a b))
(define (test_if) (let* ((a (if 1 2 3))) a))
(define (test_assign a) (set! a 123) a)
(define (test_infix a b) (< a b))

(define (test_inner)
  (define (a) 123)
  (a 123))
    
  
1
2
3




]],
['test_slc_debug.scm'] = [[
(let ((symtbl (build-symtbl)))
  (define (decode-loop stack)
    (define (sym n) 123)
    456)
  123)
                    
]],
['test_slc_hoas.scm'] = [[
(define (test_if) (let* ((a (if 1 2 3))) a))


]],
}
