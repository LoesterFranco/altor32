AltOR32 RTOS Example
--------------------

To compile, just type...

   make

To run on the verilator RTL model...

   make run


Expected Output:

Running
Starting RTOS...
thread1
thread2
thread2
thread2
thread2
thread2
thread1
thread2
thread2
thread2
thread2
thread2
thread1
thread2
thread2
thread2
thread2
thread2
thread1
thread2
thread2
thread2
thread2
thread2
thread1
thread2
thread2
thread2
thread2
thread2
thread1
thread2
thread2
thread2
thread2
thread2
Thread Dump:
Num     Name        Pri    State    Sleep    Runs    Free Stack
1:	|   THREAD2|	8	R	0	36	84
2:	|   THREAD1|	9	*	0	7	83
3:	| IDLE_TASK|	-1	R	0	60	90
