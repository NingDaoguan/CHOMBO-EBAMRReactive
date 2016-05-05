      PROGRAM TC
C
C EVALUTES THERMAL MIXTURE CONDUCTIVITY AT A SINGLE TEMPERATURE
C REQUIRES LINKING WITH CHEMKIN LIBRARIES CKLIB,CMLIB,DMATH
C LINKING FILES chem.bin tran.bin
C JES JULY 96
C
      IMPLICIT REAL*8 (A-H,O-Z)
C
C ALL DIMENSIONS AND I/O UNITS GIVEN IN THESE PARAMETER
C STATEMENTS
C
      PARAMETER (NEL = 6, NK = 60, NREAC = 500, NO = 4, NLITE = 1,
     1 LINK = 25, LINKMC = 35, NCHAR = 76, LIN =5, LOUT=6, LSAVE=7,
     2 LENIWK = 5000, LENWK = 5000, lencwk = 500, SMALL = 1.D-100,
     3 LENIMC =   4*NK + NLITE,
     4 LENRMC =  NK*(19 + 2*NO + NO*NLITE) + (NO+15)*NK**2 )
C
      DIMENSION X(NK), Y(NK), D(NK), VIS(NK), CON(NK), DJK(NK,NK),
     1 WT(NK), VAL(10),ICKWRK(LENIWK),CKWRK(LENWK),IMCWRK(LENIMC),
     2 RMCWRK(LENRMC), TDR(NK), EPS(NK),SIG(NK),DIP(NK),POL(NK),
     3 ZROT(NK),F(NK,NK), NLIN(NK)
      character cckwrk(lencwk)*16, ksym(nk)*16, line*80
      logical kerr,ierr
C
      data kerr/.false./, x/nk*small/, ksym/nk*' '/
      DATA BOLTZ, BOLTZ1, PI/1.38D-16, 8.314D07, 3.141592D0/
C
C         OPEN THE LINK FILES
C
      OPEN(UNIT=LINK, STATUS='OLD', FORM='UNFORMATTED', 
     &     FILE='chem.bin')
      OPEN(UNIT=LINKMC, STATUS='OLD', FORM='UNFORMATTED',
     1     FILE='tran.bin')
C
C         INITIALIZE CHEMKIN
C
      CALL CKINIT (LENIWK, LENWK, lencwk, LINK, LOUT, ICKWRK, CKWRK,
     &              cckwrk)
      CALL CKINDX (ICKWRK, CKWRK, MM, KK, II, NFIT)
      if (kk.gt.nk) then
          write(lout,*)'  Species dimension too small..must 
     & be at least ',KK
          stop
      endif
c
      CALL CKSYMS (cckwrk, lout,ksym,ierr)
      if (ierr) kerr = .true.
      call ckwt(ickwrk,rkwrk,wt)
      CALL CKRP (ICKWRK, CKWRK, RU, RUC, PATM)
C
C         INITIALIZE THE TRANSPORT PACKAGE
C
      CALL MCINIT (LINKMC, LOUT, LENIMC, LENRMC, IMCWRK, RMCWRK)
C
C         SET ALL INITIAL MOLE FRACTIONS TO A SMALL NUMBER
c         DON't use zero or MS FORTRAN gets upset.
C
      DO 20 K=1,KK
      X(K) = small
   20 CONTINUE
C
C         READ PRESSURE 
C
      WRITE (LOUT,7000)
      READ (LIN,*) PA
      P =  PATM*PA
C
C         READ THE INITIAL NON-ZERO MOLES
C
   40 CONTINUE
      WRITE(LOUT,*)' Enter the species followed by the mole fraction'
      WRITE(LOUT,*)' Enter END after entering the last species'
      READ  (LIN,7600,END=45)LINE
      WRITE (LOUT,7610)LINE
      ILEN = INDEX (LINE, '!')
      IF (ILEN .EQ. 1) GO TO 40
C
      ILEN = ILEN - 1
      IF (ILEN .LE. 0) ILEN = LEN(LINE)
      IF (INDEX(LINE(:ILEN), 'END') .EQ. 0) THEN
         IF (LINE(:ILEN) .NE. ' ') THEN
            CALL CKSNUM (LINE(:ILEN), 1, LOUT, KSYM, KK, KNUM,
     1                   NVAL, VAL, IERR)
            IF (IERR) THEN
               WRITE (LOUT,*) ' Error reading moles...'
               KERR = .TRUE.
            ELSE
               X(KNUM) = VAL(1)
            ENDIF
         ENDIF
         GO TO 40
      ENDIF
C
   45 CONTINUE
C
C        NORMALIZE THE MOLE FRACTIONS, ECHO OUT
C
      XTOT=0.0D0
      DO 50 K=1,KK
      XTOT = XTOT + X(K)
   50 CONTINUE
      DO 55 K=1,KK
      X(K) = X(K)/XTOT
   55 CONTINUE
C
      WRITE (LOUT,*) ' ENTER THE TEMPERATURE (K) '
      READ (LIN,*) T
C
C	Calculate the thermodynamic properties
C
      CALL CKMMWX(X,ICKWRK,CKWRK,WTM)
      CALL CKWT(ICKWRK,CKWRK,WT)
C
      WRITE (LOUT,9000) WTM, PA, T
 9000 FORMAT(//2X,'MEAN MOLECULAR WEIGHT ',1PD12.4/,
     1 2X,' PRESSURE (ATM) ',D12.4/,
     1 2X,' TEMPERATURE (K) ',D12.4//)
C
C 	DENSITY
C
      CALL CKRHOX(P,T,X,ICKWRK,CKWRK,RHO)
C
C         CONVERT TO MASS FRACTION
C
      CALL CKXTY (X, ICKWRK, CKWRK, Y)
C
C       MEAN SPECIFIC HEAT (MASS UNITS)
C
      CALL CKCPBS(T,Y,ICKWRK,CKWRK,CPBMS)
C
C        EVALUATE MIXTURE CONDUCTIVITY AND VISCOSITY
C
      CALL MCACON (T, X, RMCWRK, COND)
      CALL MCAVIS (T, X, RMCWRK, VISC)
      TDIF = 1.D-4*COND/(CPBMS*RHO)
      Avisc = 1.D-4*VISC/RHO
C
C ALL VALUES ARE CONVERTED TO MKS UNITS
C PRINT OUT
C
      WRITE (LOUT, 9100) RHO*1.D+3, CPBMS*1.D-04,
     1 COND*1.D-05,TDIF,AVISC
9100  FORMAT( //2X,'DENSITY (KG/M3)',1PD12.4/, 
     1 2X,' Specific heat (J/KG-K)',D12.4/,
     1 2X,' Thermal conductivity (W/M-K)', D12.4/,
     1 2X,' Thermal diffusivity (M2/S)', D12.4/
     1 2X,' Kinematic visocity  (M2/S)',D12.4)
C
C        FORMATS
C
 7000 FORMAT (1X, 'INPUT PRESSURE(ATM)')
 7020 FORMAT (1X, 'INPUT MOLES OF NEXT SPECIES')
C
 7600 FORMAT (1A80)
 7610 FORMAT (1X, 1A80)
C
 8000 FORMAT (2X, 7(2X, 1PG12.4))
C
      END
      
