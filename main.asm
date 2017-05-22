;
; Snake.asm
;
; Created: 2017-04-20 15:17:06
; Author : a15kriel
;


;avrdude -C "C:\WinAVR-20100110\bin\avrdude.conf" -patmega328p -Pcom4 -carduino -b115200 -Uflash:w:SnakeBuild.hex

; Registerdefinitioner
	.DEF rTemp			= r16
	.DEF rDirection		= r18
	.DEF rLength		= r20	
	.DEF rUpdateFlag	= r22
	.DEF rUpdateDelay	= r23
	.DEF rCounter       = r24

	/* Lediga Register 
	r17
	r19
	
	
	*/

; Datasegment
	.DSEG

	matrix: .BYTE 32
	mat: .BYTE 2

	

	.CSEG
	// Interrupt vector table 
	.ORG 0x0000 
 		jmp init // Reset vector 
	.ORG 0x0020 
 		jmp isr_timerOF 
	.ORG INT_VECTORS_SIZE 


init:
    // Sätt stackpekaren till högsta minnesadressen. Detta initialiseras först för att vi ska kunna använda oss utav push och pop-instruktionerna. 
    ldi rTemp, HIGH(RAMEND)
    out SPH, rTemp ; Stackpointer High
    ldi rTemp, LOW(RAMEND)
    out SPL, rTemp ; Stackpointer Low

	ldi rTemp, 0b11111111

	; Sätter allt som output
	out DDRB, rTemp
	out DDRC, rTemp
	out DDRD, rTemp

	; Sätter portarna för Y och X led i joytsticken som input
	cbi DDRC, PC4
	cbi DDRC, PC5

	
	
	; Initiering av timer
	; Pre-scaling konfigurerad genom att s�tta bit 0-2 i TCCR0B (SIDA 7 ledjoy spec)
	ldi rTemp, 0x00
	in rTemp, TCCR0B
	sbr rTemp,(1<<CS00)|(0<<CS01)|(1<<CS02) ; Timern ökas med 1 för varje 1024:e klockcykel
	out TCCR0B, rTemp

	; Aktivera globala avbrott genom instruktionen sei
	sei

	; Aktivera overflow-avbrottet f�r Timer0 genom att s�tta bit 0 i TIMSK0 till 1
	ldi rTemp, 0x00
	lds rTemp, TIMSK0
	sbr rTemp,(1<<TOIE0)
	sts TIMSK0, rTemp
	
	
	; A/D omvandling

	ldi rTemp, 0x00 ;värde 0 laddas in i rTemp
	lds rTemp, ADMUX; ADMUX värde laddas in i hela rTemp
	sbr rTemp,(1<<REFS0)|(0<<REFS1)|(1<<ADLAR) ; Alla bitar ändras enligt instruktioner från led spec och laddas in i rTemp, genom att sätta ADLAR till 1 så ställer vi in A/D omvandlaren till 8-bitarsläge.
	sts ADMUX, rTemp ; Bitarna som ändrats i rTemp skickas till ADMUX register

	ldi rTemp, 0x00	
	lds rTemp, ADCSRA ; värde 0 laddas in i ADSCRA
	sbr rTemp,(1<<ADPS0)|(1<<ADPS1)|(1<<ADPS2)|(1<<ADEN)
	sts ADCSRA, rTemp ;Värdet på bitarna som ändrats i rTemp sätts in i ADSCRA

	ldi YH, HIGH(matrix)
	ldi YL, LOW(matrix)

	ldi ZH, HIGH(matrix)
	ldi ZL, LOW(matrix)

	ldi XH, HIGH(mat)
	ldi XL, LOW(mat)

	ldi rTemp, 0
	out PORTB, rTemp ; Aktivering av alla rader
	out PORTC, rTemp
	out PORTD, rTemp

	ldi rUpdateDelay, 0b00000000
	ldi rDirection, 0b00000000
	ldi rCounter, 0b00000000
	ldi rLength, 2

	

	rcall clear 	

	.DEF rYkord = r21
	.DEF rXkord = r25

	ldi rXkord, 16
	ldi rYkord, 2

	ldi YH, 0
	ldi YL, 0

	st Y+, rXkord
	st Y+, rYkord

	ldi rXkord, 8
	ldi rYkord, 2

	st Y+, rXkord
	st Y+, rYkord

	ldi rXkord, 4
	ldi rYkord, 2

	st Y+, rXkord
	st Y+, rYkord

	.UNDEF rYkord
	.UNDEF rXKord

	.DEF rComp = r25
	ldi rComp, 6
	.DEF FinnsDetMat = r21

	ldi FinnsDetMat, 1

	ldi XH, 0
	ldi XL, 0

	ldi rTemp, 0b00100000

	st X+, rTemp

	ldi rTemp, 0b00100000

	st X, rTemp
	ldi YH, 0
	ldi YL, 0

	ldi ZH, 0
	ldi ZL, 0
main:
	.DEF rTemp2 = r17
	ldi rCounter, 0
	ldi XL, 0
	/*
	mainCont: ; Denna label kontrollerar ifall 
	
	cp ZL, rComp
	brlo ladda

	resetZL:
	ldi ZL, 0
	jmp mainCont
	*/
	ldi ZL, 1
	
	
	ladda:


	// Test med att ladda för varje kord //
	
	
	ld rTemp2, Z
	cpi rTemp2, 1
	brsh laddaCont


	inc rCounter
	cpi rCounter, 7
	brsh OutOfMain


	jmp ladda






	laddaCont:

	rcall laddaraden


	dec ZL
	rcall laddakord
	rcall clear
	inc rCounter
	cpi rCounter, 7
	brsh OutOfMain


	inc ZL
	cp ZL, RComp
	brlo noReset

	ldi ZL, 1
	jmp ladda
	
	noReset:
	inc ZL
	
	jmp ladda
	
	
	OutOfMain:
	jmp update
	
	
	

	/*

	rcall laddarad
	rcall laddarader
;	rcall laddamat



	rcall clear
	inc rCounter
	cp rCounter, rLength
	breq update
	

	jmp mainCont
	*/
	update:
	.UNDEF rTemp2
	cpi rUpdateFlag, 1 ;Jämför om rUpdateFlag är detsamma som värdet 1
	breq updateloop ;Branchar till updateloop ifall rUpdateFlag har samma värde som 1

    jmp main


updateloop: 
	inc rUpdateDelay ;Inkrementering av rUpdateDelay
	cpi rUpdateDelay, 15 ; Uppdaterar efter var 15:e interrupt
	brne skip ; Om inte 15 interrupts inte har gått så skippas contUpdate
	rcall contUpdate
	skip:
	ldi rUpdateFlag, 0b00000000 ; rUpdateFlag nollställs inför nästa interrupt
	jmp main
	

contUpdate:

	.DEF rXvalue = r17
	.DEF rYvalue = r19

	ldi rUpdatedelay, 0b00000000 ; utan denna rad så kommer ingen rendering ske under updateloop
; Välj x-axel 
 	ldi rTemp, 0x00 
 	lds rTemp, ADMUX 
 	sbr rTemp,(0<<MUX3)|(1<<MUX2)|(0<<MUX1)|(1<<MUX0) ; (0b0101 = 5) Dessa är de lägsta bitarna i ADMUX och genom att sätta dessa väljer man analogingång på ledjoyen. I detta fall har vi valt analogingång 5 (0b0101).
 	sts ADMUX, rTemp 
 
 
 	; Starta A/D-konvertering.  
 	ldi rTemp, 0x00 
 	lds rTemp, ADCSRA		; Get ADCSRA 
 	sbr rTemp,(1<<ADSC)		; Starta konvertering ---> ADSC = 1 (bit 6) 
 	sts ADCSRA, rTemp		; Ladda in 
 	 
iterate_x: 
 	ldi rTemp, 0x00 
 	lds rTemp, ADCSRA		; Ta nuvarande ADCSRA för att jämföra 
 	sbrc rTemp, 6			; Kolla om bit 6 (ADSC) är 0 i rSettings (reflekterar ADCSRA) (instruktion = Skip next instruction if bit in register is cleared) ; Alltså om ej cleared, iterera. 	 
 	jmp iterate_x			; Iterera 
 	nop 
 
 
 	lds rXvalue, ADCH	; Läs av (kopiera) ADCH, som är de 8 bitarna.  


	; Välj y-axel 
 	ldi rTemp, 0x00 
 	lds rTemp, ADMUX 
 	sbr rTemp,(0<<MUX3)|(1<<MUX2)|(0<<MUX1)|(0<<MUX0) ; (0b0100 = 4) 
 	cbr rTemp,(1<<MUX3)|(1<<MUX1)|(1<<MUX0) 
 	sts ADMUX, rTemp 
 
 
	; Starta A/D-konvertering.  
 	ldi rTemp, 0x00 
 	lds rTemp, ADCSRA		; Get ADCSRA 
 	sbr rTemp,(1<<ADSC)		; Starta konvertering ---> ADSC = 1 (bit 6) 
 	sts ADCSRA, rTemp		; Ladda in 
 	 
 iterate_y: 
 	ldi rTemp, 0x00 
 	lds rTemp, ADCSRA		; Ta nuvarande ADCSRA för att jämföra 
 	sbrc rTemp, 6			; Kolla om bit 6 (ADSC) är 0 i rSettings (reflekterar ADCSRA) (instruktion = Skip next instruction if bit in register is cleared) ; Alltså om ej cleared, iterera. 	 
 	jmp iterate_y			; Iterera 
 	nop 
 
 
 	lds rYvalue, ADCH		; Läs av resultat 
	rcall kontrolleraMat

	cpi rXvalue, 165	; Deadzone (var 165)
 	brsh go_left 
 
 
 	cpi rXvalue, 91		
 	brlo go_right 

	cpi rYvalue, 165 
 	brsh go_up 
 
 
 	cpi rYvalue, 91 
 	brlo go_down 
	



	jmp checkdir
	go_left:
 		ldi rDirection, 1 
 	jmp checkdir 
 	go_right: 
 		ldi rDirection, 2
 	jmp checkdir 
	
 	go_up: 
 		ldi rDirection, 4
 	jmp checkdir 
 	go_down: 
 		ldi rDirection, 8
		

checkdir:

		.UNDEF rXvalue
		.UNDEF rYvalue
		



checkdircont:

		cpi rDirection, 0
		breq noDirection
		
		cpi rDirection, 1
		breq left

		cpi rDirection, 2
		breq right
		
		cpi rDirection, 4
		breq up

		cpi rDirection, 8
		breq down
		
		jmp outsidecheckdone

		noDirection:
		ret ; Subrutin returnering ifall det saknas en direction

		left:
		ld rTemp, Y
		cpi rTemp, 128
		brsh outsideleft

		lsl rTemp
		jmp outsidecheckdone
		
		

		right:
		ld rTemp, Y
		cpi rTemp, 2
		brlo outsideright

		lsr rTemp
		jmp outsidecheckdone
			
		up:
		inc YL
		ld rTemp, Y
		cpi rTemp, 2
		brlo outsideup
		
		lsr rTemp
		jmp outsidecheckdone


		down:
		inc YL
		ld rTemp, Y
		cpi rTemp, 128
		brsh outsidedown
		
		lsl rTemp
		jmp outsidecheckdone
 

 
 
 	outsideleft:
	ldi rTemp, 1 
	jmp outsidecheckdone

 	outsideright:
	ldi rTemp, 128
	jmp outsidecheckdone
		
	outsideup:
	ldi rTemp, 128
	jmp outsidecheckdone

	outsidedown: 
	ldi rTemp, 1

	

outsidecheckdone: 
	.DEF rBuffer = r17
/*  0,1 2,3 4,5                  */

	cpi rDirection, 4
	brsh updown
	
	leftright:	
	inc YL
	ld rBuffer, Y
	inc YL

	cp YL, rComp
	breq resetYLforX

	st Y+, rTemp
	st Y, rBuffer
	dec YL


	jmp main
	resetYLforX:

	ldi YL, 0

	st Y+, rTemp
	st Y, rBuffer
	dec YL

	jmp main

	updown:

	dec YL
	ld rBuffer, Y+

	inc YL
	inc YL
	cp YL, rComp 
	brsh resetYLforY

	st Y, rTemp
	dec YL
	st Y, rBuffer
	jmp main
	
	resetYLforY:
	ldi YL, 0
	st Y, rBuffer
	inc YL
	st Y, rTemp
	dec YL
	jmp main

	.UNDEF rBuffer
done:
	ret
	/*
Laddarad: 
	.DEF rTempPortBuffer = r17
	.DEF rTemp2 = r19
	ldi XL, 0

 
 	in rTemp, PORTD 
	ld rTempPortBuffer, Z+
	ld rTemp2, X+

	;cpi rCounter, 1
	;brsh skipOr
	or rTempPortBuffer, rTemp2

	skipOr:
	bst rTempPortBuffer, 7 
 	bld rTemp, 6 
	bst rTempPortBuffer, 6 
	bld rTemp, 7 
 	out PORTD, rTemp 

 	in rTemp, PORTB 
	 
 	bst rTempPortBuffer, 5 
 	bld rTemp, 0 
 	bst rTempPortBuffer, 4 
 	bld rTemp, 1 
 	bst rTempPortBuffer, 3 
 	bld rTemp, 2 
 	bst rTempPortBuffer, 2 
 	bld rTemp, 3 
 	bst rTempPortBuffer, 1 
 	bld rTemp, 4 
 	bst rTempPortBuffer, 0 
 	bld rTemp, 5 
	 
 	out PORTB, rTemp  
	.UNDEF rTempPortBuffer 
	.UNDEF rTemp2
 	ret 

Laddarader: 
	.DEF rTempPortBuffer = r17
	.DEF rTemp2 = r19

 	in rTemp, PORTC 
	ld rTempPortBuffer, Z+
	ld rTemp2, X+

	cpi rCounter, 1
	brsh skipOr2
	or rTempPortBuffer, rTemp2

	skipOr2:
	bst rTempPortBuffer, 0 
 	bld rTemp, 0
	bst rTempPortBuffer, 1 
	bld rTemp, 1
	bst rTempPortBuffer, 2
	bld rTemp, 2
	bst rTempPortBuffer, 3
	bld rTemp, 3
	out PORTC, rTemp 

 	in rTemp, PORTD 
	 
 	bst rTempPortBuffer, 4 
 	bld rTemp, 2 
 	bst rTempPortBuffer, 5 
 	bld rTemp, 3 
 	bst rTempPortBuffer, 6 
 	bld rTemp, 4 
 	bst rTempPortBuffer, 7 
 	bld rTemp, 5	 
 	out PORTD, rTemp  
 

	.UNDEF rTempPortBuffer
 	ret */
	/*
laddamat:

	.DEF rTempPortBuffer = r17
	.DEF rTemp2 = r19
	cpi FinnsDetMat, 0
	breq skipladdamat
	ldi XL, 0


	in rTemp, PORTD 
	ld rTempPortBuffer, X+ 

	bst rTempPortBuffer, 7 
 	bld rTemp2, 6 
	bst rTempPortBuffer, 6 
	bld rTemp2, 7
	or rTemp, rTemp2 
 	out PORTD, rTemp 

 	in rTemp, PORTB 
	 
 	bst rTempPortBuffer, 5 
 	bld rTemp2, 0 
 	bst rTempPortBuffer, 4 
 	bld rTemp2, 1 
 	bst rTempPortBuffer, 3 
 	bld rTemp2, 2 
 	bst rTempPortBuffer, 2 
 	bld rTemp2, 3 
 	bst rTempPortBuffer, 1 
 	bld rTemp2, 4 
 	bst rTempPortBuffer, 0 
 	bld rTemp2, 5 
	 
	or rTemp, rTemp2

 	out PORTB, rTemp


 	in rTemp, PORTC 
	ld rTempPortBuffer, X+

	bst rTempPortBuffer, 0 
 	bld rTemp2, 0
	bst rTempPortBuffer, 1 
	bld rTemp2, 1
	bst rTempPortBuffer, 2
	bld rTemp2, 2
	bst rTempPortBuffer, 3
	bld rTemp2, 3
	or rTemp, rTemp2
	out PORTC, rTemp 

 	in rTemp, PORTD 
	 
 	bst rTempPortBuffer, 4 
 	bld rTemp2, 2 
 	bst rTempPortBuffer, 5 
 	bld rTemp2, 3 
 	bst rTempPortBuffer, 6 
 	bld rTemp2, 4 
 	bst rTempPortBuffer, 7 
 	bld rTemp2, 5
	or rTemp, rTemp2	 
 	out PORTD, rTemp  
 


	skipladdamat:
	.UNDEF rTemp2
	.UNDEF rTempPortBuffer
	ret
	*/
kontrolleraMat:
	cpi FinnsDetMat, 1
	breq Return
	ldi XL, 0

	st X+, r19
	st X, r17
	ldi FinnsDetMat, 1

	Return:
	ret

clear:

	cbi PORTD, PD6
	cbi PORTD, PD7
	cbi PORTB, PB0
	cbi PORTB, PB1
	cbi PORTB, PB2
	cbi PORTB, PB3
	cbi PORTB, PB4
	cbi PORTB, PB5

	cbi PORTC, PC0
	cbi PORTC, PC1
	cbi PORTC, PC2
	cbi PORTC, PC3
	cbi PORTD, PD2
	cbi PORTD, PD3
	cbi PORTD, PD4
	cbi PORTD, PD5

	ret

isr_timerOF:
	ldi rUpdateFlag, 0b00000001
	reti




laddakord:
	.DEF rX = r17
	
	in rTemp, PORTD
	ld rX, Z+

	bst rX, 7 
 	bld rTemp, 6 
	bst rX, 6 
	bld rTemp, 7 
 	out PORTD, rTemp 

 	in rTemp, PORTB 
	 
 	bst rX, 5 
 	bld rTemp, 0 
 	bst rX, 4 
 	bld rTemp, 1 
 	bst rX, 3 
 	bld rTemp, 2 
 	bst rX, 2 
 	bld rTemp, 3 
 	bst rX, 1 
 	bld rTemp, 4 
 	bst rX, 0 
 	bld rTemp, 5 
	 
 	out PORTB, rTemp  


	.UNDEF rX
ret

laddaRaden:
	.DEF rY = r17

	in rTemp, PORTC 
	ld rY, Z


	
	bst rY, 0 
 	bld rTemp, 0
	bst rY, 1 
	bld rTemp, 1
	bst rY, 2
	bld rTemp, 2
	bst rY, 3
	bld rTemp, 3
	out PORTC, rTemp 

 	in rTemp, PORTD 
	 
 	bst rY, 4 
 	bld rTemp, 2 
 	bst rY, 5 
 	bld rTemp, 3 
 	bst rY, 6 
 	bld rTemp, 4 
 	bst rY, 7 
 	bld rTemp, 5	 
 	out PORTD, rTemp
	
	ret  