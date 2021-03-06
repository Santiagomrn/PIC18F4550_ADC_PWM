 #include "C:\Program Files (x86)\Microchip\MPLABX\v5.25\mpasmx\p18f4550.inc"
  LIST p=18F4550	    ;Tipo de microprocesador

 udata_acs
 ;Variables

;Periodo = (PR2+1)*Prescaler*4*Tosc
	    
Duty_On	    EQU	    0x20	;Vairalbes de ancho de pulso
Duty_Off    EQU	    0x21
    
  CODE 0x00
;---------FRECUENCIA DEL OSCILADOR------------------
;seleccion del oscilador interno como fuente de reloj del CPU
BSF OSCCON,SCS1,0 ;
BSF OSCCON,SCS0,0 ; 
;configuro el PLL para 8MHz de fosc al cpu 
BSF OSCCON, IRCF2,0
BSF OSCCON, IRCF1,0
BSF OSCCON, IRCF0,0
;--------DEFINO PUERTOS--------------
;CONFIGURO PUERTO B0 Y B1 COMO SALIDA
CLRF PORTB	    ;limpia puerto B
MOVLW B'00000000'   ;mueve 0 a w
MOVWF TRISB,ACCESS  ;mueve w a TRISB
MOVLW B'00000000'   ;mueve 0 a w
MOVWF LATB,ACCESS   ;mueve w a LATB
  
 ;configuro puerto D como salida
CLRF PORTD	    ;limpia el puerto D
MOVLW B'00000000'   ;mueve 0 a W
MOVWF TRISD,ACCESS  ;mueve W a TRISD 
MOVLW B'00000000'   ;mueve 0 a W
MOVWF LATD,ACCESS   ;mueve W a LATD
;Set CCP1 pin como salida puerto C como salida
CLRF TRISC
  ;----------configuracion de ADC----

MOVWF B'00000000'  ;CONFIGURO EL CANAL 0 AN0
MOVWF ADCON0
 
MOVLW B'00001110'  ;CONFIGURA EL VOTAJE DE REFERENCIA IGUAL AL DE LA ALIMENTACION PIC Y CONFIGURA EL PUERTO AN0 COMO ENTRADA ANALOGICA
MOVWF ADCON1 

MOVLW B'00111010'  ;ACTIVA JUSTIFICACION A LA IZQUIERDA -- TIMEPO DE ADQUISICION 20 TAD -- TAD=fOSC/32 =8MHZ/32
MOVWF ADCON2

MOVLW B'00000001'  ;ENCIENDE EL ADC
MOVWF ADCON0
;-------------CONFIGURACION DE PWM --------------------------  
  ;load period value in PR2 register 
    MOVLW .255 ; periodo del pwm 1024*tosc    tosc=1/2Mhz frecPWM 7812.5Hz
    MOVWF PR2, ACCESS 
;No pre-scalar, timer2 is off
    MOVLW B'00000000'
    MOVWF T2CON
;set PWM mode and  decimal value for PWM [10 bits]
    MOVLW 0x0C ;configura PWM como solo una salida en el puerto CCP1/RC2/PA1
    MOVWF CCP1CON
    
MAIN:
   ;----INICIA ADC-------
   MOVLW B'00000011'; ENCIENDE EL ADC Y COLOCA EL BIT DE CONVERSION EN PROGRESO
   MOVWF ADCON0
LOOP1:
   MOVLW B'00000010'
   ANDWF ADCON0,0,ACCESS; ESPERA A QUE TERMINE LA CONVERSION
   BNZ LOOP1
   ;----TERMINA ADC------
   ;----INICIA PWM Y SALIDAS EN LOS PUERTO

    MOVF    ADRESH,W
    MOVWF   Duty_On	;Registra el valor para el periodo
    RRNCF   ADRESL,F	;Hace un corrimiento a la derecha aumentando 1
    RRNCF   ADRESL,W
    ANDLW   B'00110000'
    MOVWF   Duty_Off	;Se guarda la conversión más baja en Duty_Off
;Configuración PWM
    MOVLW   B'00001100'
    IORWF   Duty_Off,F	;Se obtienen los valores del Duty_Off
    MOVWF   CCP1CON	;Modo PWM para el CCP1
;Registro PR2
    MOVLW   .255
    MOVWF   PR2		;Periodo se guarda en el PR2
;Anchura del pulso
    MOVF    Duty_On,W	;Guardamos Duty_On -> W
    MOVWF   CCPR1L	;Y se determina concatenando en el registro CCPR1L
;Prescaler
    MOVLW   B'00000111'	;Prescaler 1:16 y frecuencia de 8MHz 
    MOVWF   T2CON
       
   GOTO MAIN
   
  ;-------------------------------------Configuración del SPI al Inicio-------------------------------------
Start_SPI:
    ; Limpiamos puertos a utilizar
    CLRF PORTC				    ; Limpiamos puerto C
    CLRF PORTB				    ; Limpiasmo puerto B
    ;B1 SCK
    ;B0 (MOSI)
    ;C7 SDO (MISO)
    ;
    ;Configuración del B1 SCK como salida en el puerto y RB0 SDI(MOSI) como entrada en el puerto 0
    MOVLW 0x01				    ; Pasamos 0x01 al registro W, para poner a pi1 como salida y pin 0 como entrada
    MOVWF TRISB, ACCESS			    ; Movemos lo que está en el registro W a TRISB
    
    ;Configuración del SDO(MISO) como salida en el puerto C7
    CLRF TRISC			            ; Definimos el registro TRISC pin 7 como salida
    CLRF SSPCON1
    ;Configuración del Registro SSPCON1
    MOVF SSPCON1,W,ACCESS		    ; Movemos SSPCON1 al registro W
    IORLW b'11110000'			    ; Configuración de control del SPI con registro SSPBUF
    MOVWF SSPCON1,ACCESS		    ; Pasamos lo que está en el registro W a SSPCON1
    
    MOVF SSPCON1, W, ACCESS		    ; Movemos SSPCON1 al registro W
    IORLW b'00000010'			    ; Iniciamos con una frecuencia base 
    MOVWF SSPCON1, ACCESS		    ; Pasamos lo que está en el registro W a SSPCON1
    
    ;Configuración polaridad del reloj
    BCF SSPCON1,4,ACCESS		    ; El estado inactivo para el reloj es un nivel bajo
      
    ;Configuración del Registro SSPSTAT, realizar muestreo al final del tiempo de salida de datos por flanco de bajada
    BSF SSPSTAT,7,ACCESS		    ; Habilitamos muestreo por tiempo de salida de datos
    BSF SSPSTAT,6,ACCESS		    ; Habilitamos flanco de bajada
   
    ;Configuración interrupción SPI en el registro PIE
    BCF PIE1,3,ACCESS			    ; Ponemos el Registro PIE1 la deshabilitación de la interrupción de MSSP
      
    ;Prioridad de interrupción 
    CLRF IPR1				    ; Ponemos el Registro IPR1 como baja prioridad
   
    ;Definir configuración del SPI
    BCF PIR1,3,ACCESS			    ; Ponemos el Registro PIR1 en espera para transmitir o recibir
   
    ;Habilitar Configuración SPI en el pin 5
    BSF SSPCON1,5,ACCESS		    ; Habilita el puerto serie y configura SCK, SDO, SDI y SS
   
    RETURN				    ; Retornamos 
   
  END