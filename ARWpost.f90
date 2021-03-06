MODULE ARWpost

  IMPLICIT NONE

  real, parameter                                              ::gamma_recp=1.0/.0065
  real, parameter                                              ::g_recp=1.0/9.8
  integer            ::  iprogram = 8                         ! wrfout
  logical            ::  extrapolate=.True. 
!      integer, parameter :: number_of_zlevs  = 28                 ! no of constant pressure levels
!      real, dimension(number_of_zlevs) :: z_levs                  ! constant pressure levels (hPa)
!      data z_levs/              70., 100., 125., 150., 175., 200., 225., 250., &
!                300., 350., 400., 450., 500., 550., 600., 650., 700., 750., &
!                775., 800., 825., 850., 875., 900., 925., 950., 975.,1000./

  real                                :: missing_value
  parameter (MISSING_VALUE=1.00E30)

   real, parameter :: epsilon0 = 1e-3
   real, parameter :: pi = 3.141592653589793
   real, parameter :: omega_e = 7.292e-5 ! angular rotation rate of the earth

   real, parameter :: deg_per_rad = 180./pi
   real, parameter :: rad_per_deg = pi/180.
 
   ! mean earth radius in m.  the value below is consistent
   ! with ncep's routines and grids.
   real, parameter :: earth_radius_m = 6370000.   ! same as mm5 system
   real, parameter :: earth_circ_m = 2.*pi*earth_radius_m

   real, parameter :: g = 9.81
   real, parameter :: rd = 287.04
   real, parameter :: rv = 461.6
   real, parameter :: rm = .608 
   !real, parameter :: cp = 1004.
   real, parameter :: cp = 7.*rd/2.
   real, parameter :: cv = cp-rd
   real, parameter :: cpmd = 0.887
   real, parameter :: rcp = rd/cp
   real, parameter :: t0 = 273.16
   real, parameter :: p0 = 100000.
   real, parameter :: gamma = 0.0065
   real, parameter :: gamma_rip = rd/cp 
   real, parameter :: gammamd = rm-cpmd

   real, parameter :: celkel = 273.15
   real, parameter :: rhowat = 1000.
   real, parameter :: eps = 0.622
   real, parameter :: ezero = 6.112

   real, parameter :: eslcon1 = 17.67
   real, parameter :: eslcon2 = 29.65
   real, parameter :: thtecon1 = 3376.
   real, parameter :: thtecon2 = 2.54
   real, parameter :: thtecon3 = 0.81
   real, parameter :: tlclc1 = 2840.
   real, parameter :: TLCLC2 = 3.5
   real, parameter :: TLCLC3 = 4.805
   real, parameter :: TLCLC4 = 55.

  real, dimension(150)                                           :: buoy, zrel, benaccum
  real, dimension(150)                                           :: psadithte, psadiprs
  real, dimension(150,150)                                       :: psaditmk



CONTAINS
   REAL FUNCTION virtual (tmp,rmix)
!      This function returns virtual temperature in K, given temperature
!      in K and mixing ratio in kg/kg.
 
     real                              :: tmp, rmix !, virtual
 
     virtual=tmp*(0.622+rmix)/(0.622*(1.+rmix))


   END FUNCTION virtual

!! Calculate pressure (Pa) from MU and MUB (wrfinput data)


  SUBROUTINE pressure(znw,znu,ptop,MU,MUB,qv                          , &
                      prs                                         , &
                      bottom_top_dim,south_north_dim,west_east_dim) 

! USE module_model_basics

  !Arguments
  integer, intent(in)                   :: bottom_top_dim,south_north_dim,west_east_dim
  real,                           intent(in):: PTOP
  real, dimension(bottom_top_dim+1),intent(in):: znw
  real, dimension(bottom_top_dim),intent(in):: znu
  real, dimension(               south_north_dim,west_east_dim) ,intent(in ):: MU,MUB 
  real, dimension(bottom_top_dim,south_north_dim,west_east_dim) ,intent(in ):: QV 
  real, dimension(bottom_top_dim,south_north_dim,west_east_dim) ,intent(out):: prs
  !local
  real, dimension(bottom_top_dim)       :: rdnw, rdn
  real                                  :: dnw, dn
  real                                  :: qvf1, qvf2
  real                                  :: p_base
  integer                               :: i, j, k
   




     DO k = 1, bottom_top_dim
        dnw=(ZNW(k+1) - ZNW(k))
        rdnw(k) = 1./dnw
     END DO
     DO k = 1, bottom_top_dim
        dn=.5 * ( 1./rdnw(k+1) + 1./rdnw(k))
        rdn(k)=1./dn
     END DO



     DO j = 1, south_north_dim
       DO i = 1, west_east_dim

  !      Get pressure perturbation at model top
         k = bottom_top_dim  
         qvf1 = QV(k,i,j) * .001
         qvf2 = 1. / (1.+qvf1)
         qvf1 = qvf1 * qvf2
         prs(k,i,j) = - 0.5 * ( MU(i,j) + qvf1*MUB(i,j) ) / rdnw(k) / qvf2


  !      Now get pressure perturbation at levels below
         DO k = 1, bottom_top_dim-1
            qvf1 = 0.5 * (QV(k,i,j)+QV(k+1,i,j)) * .001
            qvf2 = 1. / (1.+qvf1)
            qvf1 = qvf1 * qvf2
            prs(k,i,j) = prs(k+1,i,j) - ( MU(i,j) + qvf1*MUB(i,j) ) / qvf2 / rdn(k)
         END DO


  !      Finally compute base state pressure and add to pressure perturbation
  !      to get total pressure
         DO k = 1, bottom_top_dim
            p_base = ZNU(k) * MUB(i,j) + PTOP
            prs(k,i,j) =  prs(k,i,j) + p_base     ! Pa 
         END DO

       END DO
     END DO


  END SUBROUTINE pressure

!----------------------------------------------

  SUBROUTINE interp_1d( a, xa, na, b, xb, nb, vertical_type)

  implicit none

 ! Arguments
  integer, intent(in)              :: na, nb
  real, intent(in), dimension(na)  :: a, xa
  real, intent(in), dimension(nb)  :: xb
  real, intent(out), dimension(nb) :: b
  character (len=1)                :: vertical_type

  ! Local variables
  integer                          :: n_in, n_out
  real                             :: w1, w2
  logical                          :: interp

  IF ( vertical_type == 'p' ) THEN

    n_in = 1
    DO n_out = 1, nb

      b(n_out) = missing_value

      DO WHILE (  n_in <= na )
        IF (n_in< na) THEN   
          IF( abs(xa(n_in)-xb(n_out))<epsilon0) THEN
            b(n_out) =a(n_in)
            EXIT
          ENDIF
          IF( (xa(n_in)   >= xb(n_out)) .and. &
              (xa(n_in+1) <= xb(n_out))        ) THEN
  !         interp = .true.
            w1 = (xa(n_in+1)-xb(n_out))/(xa(n_in+1)-xa(n_in))
            w2 = 1. - w1
            b(n_out) = w1*a(n_in) + w2*a(n_in+1)
            EXIT
          END IF
          n_in = n_in +1
        ELSE  ! here it means the outpub level b is below the first layer of xa, in this situation, we need to reinitialize the n_in to 1 for nextloop of searching
          n_in=1
          EXIT
        END IF
      ENDDO

    ENDDO

  ELSE

    n_in = 1
    DO n_out = 1, nb
  
      b(n_out) = missing_value
  
      DO WHILE (  (n_in <= na) )
        IF (n_in< na) THEN   
          IF( abs(xa(n_in)-xb(n_out))<epsilon0) THEN
            b(n_out) =a(n_in)
            EXIT
          ENDIF
          IF( (xa(n_in)   <= xb(n_out)) .and. &
              (xa(n_in+1) >= xb(n_out))        ) THEN
!           interp = .true.
            w1 = (xa(n_in+1)-xb(n_out))/(xa(n_in+1)-xa(n_in))
            w2 = 1. - w1
            b(n_out) = w1*a(n_in) + w2*a(n_in+1)
            EXIT
          END IF
          n_in = n_in +1
        ELSE  ! here it means the outpub level b is below the first layer of xa, in this situation, we need to reinitialize the n_in to 1 for nextloop of searching
          n_in=1
          EXIT
        END IF
      ENDDO

    ENDDO

  END IF

  END SUBROUTINE interp_1d

!-------------------------------------------------------------------------

  SUBROUTINE interp(cname , vertical_type   , &
  data_in                 , &
  z_data                  , &
  data_out                , &
  number_of_zlevs         , z_levs          , &
  psfc                    , hgt             , pres           , geopt , tk , qv , &
  nx                      , ny              , nz             , &
  bottom_top_dim          , south_north_dim , west_east_dim)


  implicit none
  
 ! Arguments
!f2py integer,intent(in) ::bottom_top_dim,south_north_dim,west_east_dim,nx,ny,nz
!f2py real, dimension(bottom_top_dim,south_north_dim,west_east_dim),intent(in) ::z_data,pres,geopt,tk,qv
!f2py real, dimension(south_north_dim,west_east_dim),intent(in) ::psfc,hgt,
!f2py real, dimension(nz,ny,nx),intent(in) :: data_in
!f2py character (len=*), intent(in)                                 ::cname
!f2py intent(in) vertical_type,number_of_zlevs,z_levs
!f2py real, dimension(number_of_zlevs,south_north_dim,west_east_dim),intent(out)                           :: data_out
  integer, intent(in)                                                  :: bottom_top_dim,south_north_dim,west_east_dim  
  ! the difference between bottom_top_dim etc. to nx ny nz is nx ny might be stagged
  integer, intent(in)                                                                                :: nx, ny, nz
  real, dimension(bottom_top_dim,south_north_dim,west_east_dim),intent(in)                           :: z_data
  real, dimension(bottom_top_dim,south_north_dim,west_east_dim),intent(in),optional                  :: PRES,GEOPT,TK,QV
  real, dimension(south_north_dim,west_east_dim),intent(in),optional                                 :: PSFC,HGT
  real, dimension(nz,ny,nx),intent(in)                                                               :: data_in
  character (len=*), intent(in)                                 :: cname
  character (len=1), intent(in)                                 :: vertical_type
  integer, intent(in)                                           :: number_of_zlevs                      ! no of constant pressure levels
  real, intent(in), dimension(number_of_zlevs)                  :: z_levs                               ! constant pressure levels (hPa)

  real, dimension(number_of_zlevs,south_north_dim,west_east_dim),intent(out)                           :: data_out


  ! Local variables
  real     , dimension(south_north_dim,west_east_dim)                           :: hgt_firstlayer
  real    ,  dimension(bottom_top_dim)  :: data_in_1d  , z_data_1d
  real    ,  dimension(number_of_zlevs) :: data_out_1d
  integer :: nxout                      ,  nyout       , nzout
  integer :: k                          ,  i           , j         , kk
  real    :: ptarget                    ,  dpmin       , dp        , pbot   , zbot
  real    :: tbotextrap                 ,  tvbotextrap , expon     , exponi
  real    :: zlev                       ,  plev        , tlev      , gamma
  integer :: kupper                     ,  kin

  expon=287.04*.0065/9.81
  exponi=1./expon

  nxout = west_east_dim
  nyout = south_north_dim
  nzout = nz

  !! We may be dealing with a staggered field


  DO j=1,west_east_dim
    DO i=1,south_north_dim

      IF ( nx .gt. west_east_dim ) THEN
        data_in_1d(:) = (data_in(:,i,j)+data_in(:,i,j+1))*0.5
      ELSE IF ( ny .gt. south_north_dim ) THEN
        data_in_1d(:) = (data_in(:,i,j)+data_in(:,i+1,j))*0.5
      ELSE
        data_in_1d(:) = data_in(:,i,j)
      ENDIF
      call interp_1d( data_in_1d, z_data(:,i,j), bottom_top_dim, &
                      data_out(:,i,j), z_levs, number_of_zlevs,  &
                      vertical_type)
    ENDDO
  ENDDO
    
      
  nzout = number_of_zlevs
  IF (present(GEOPT)) THEN
    hgt_firstlayer=geopt(1,:,:)*g_recp 
  ENDIF


!!! STOP here if we don't want to extrapolate
  IF ( .not. extrapolate  .OR. nz .lt. bottom_top_dim ) RETURN


      ! first find where about 400hpa/7km is located
      kk = 0
      find_kk : do k = 1, nzout
         kk = k
!. the vertical level is from small to large
         if ( vertical_type == 'p' .and. z_levs(k) <= 40000. ) exit find_kk
!cCS corrct the value for z which is supposed to be 7000
         if ( vertical_type == 'z' .and. z_levs(k) >= 7000. )  exit find_kk
!.CS
      end do find_kk

    
      if ( vertical_type == 'p' ) then
        !!! need to do something special for height and temparature
        if ( cname=="height" .or. cname=="geopt" .or. &
             cname=="tk" .or. cname=="tc" .or. cname=="theta" ) then
          do k = 1, kk
           do j = 1, nxout
           do i = 1, nyout
              if ( data_out(k,i,j) == missing_value .and. z_levs(k) < psfc(i,j) ) then

  !             we are below the first model level, but above the ground
  !             we need meter for the calculations so, geopt/g
    
                zlev = (((z_levs(k) - pres(1,i,j))*hgt(i,j) +  &
                       (psfc(i,j) - z_levs(k))*hgt_firstlayer(i,j) ) /   &
                       (psfc(i,j) - pres(1,i,j))) 
!c CS we want in meter
                if ( cname == "height" ) data_out(k,i,j) = zlev !/ 1000.
!. CS we want in meter
                if ( cname == "geopt" )  data_out(k,i,j) = zlev * 9.81
                if ( cname(1:1) == "t") then
                  tlev = tk(1,i,j) + (hgt_firstlayer(i,j)-zlev)*.0065
                  if ( cname == "tk" ) data_out(k,i,j) = tlev 
                  if ( cname == "tc" ) data_out(k,i,j) = tlev - 273.15
                  if ( cname == "theta" ) then
                    gamma = (287.04/1004.)*(1.+(0.608-0.887)*qv(k,i,j))
                    data_out(k,i,j) = tlev * (100000./z_levs(k))**gamma
                  ENDIF
                ENDIF
    
              ELSEIF ( data_out(k,i,j) == MISSING_VALUE ) THEN

  !             We are below both the ground and the lowest data level.
  !             First, find the model level that is closest to a "target" pressure
  !             level, where the "target" pressure is delta-p less that the local
  !             value of a horizontally smoothed surface pressure field.  We use
  !             delta-p = 150 hPa here. A standard lapse rate temperature profile
  !             passing through the temperature at this model level will be used
  !             to define the temperature profile below ground.  This is similar
  !             to the Benjamin and Miller (1990) method, except that for
  !             simplicity, they used 700 hPa everywhere for the "target" pressure.
  !             Code similar to what is implemented in RIP4

                ptarget = (PSFC(i,j)*.01) - 150.
                dpmin=1.e4
                kupper = 0
                loop_kIN : DO kin=nz,1,-1
                   kupper = kin
                   dp=abs( (PRES(kin,i,j)*.01) - ptarget )
                   IF (dp.gt.dpmin) exit loop_kIN
                   dpmin=min(dpmin,dp)
                ENDDO loop_kIN

                pbot=max(PRES(1,i,j),PSFC(i,j))
                zbot=min(hgt_firstlayer(i,j),HGT(i,j))   ! need height in meter

                tbotextrap=TK(kupper,i,j)*(pbot/PRES(kupper,i,j))**expon
                tvbotextrap=virtual(tbotextrap,QV(1,i,j))
! change hard code devide into multi
!               zlev = (zbot+tvbotextrap/.0065*(1.-(z_levs(k)/pbot)**expon)) 
                zlev = (zbot+tvbotextrap*gamma_recp*(1.-(z_levs(k)/pbot)**expon)) 
!.CS
!c CS we want in meter
                IF ( cname == "height" ) data_out(k,i,j) = zlev !/ 1000.
!. CS we want in meter
                IF ( cname == "geopt" )  data_out(k,i,j) = zlev * 9.81
                IF ( cname(1:1) == "t") THEN
                  tlev = TK(1,i,j) + (hgt_firstlayer(i,j)-zlev)*.0065
                  IF ( cname == "tk" ) data_out(k,i,j) = tlev 
                  IF ( cname == "tc" ) data_out(k,i,j) = tlev - 273.15
                  IF ( cname == "theta" ) THEN
                    gamma = (287.04/1004.)*(1.+(0.608-0.887)*QV(k,i,j))
                    data_out(k,i,j) = tlev * (100000./z_levs(k))**gamma
                  ENDIF
                ENDIF
                
              ENDIF


            ENDDO
            ENDDO
          ENDDO

        ENDIF
      ENDIF
    
      IF ( vertical_type == 'z' ) THEN
        !!! Need to do something special for height and temparature
        IF ( cname=="pressure" .OR. &
             cname=="tk" .OR. cname=="tc" .OR. cname=="theta" ) THEN
          DO k = 1, kk
            DO j = 1, nxout
            DO i = 1, nyout
!c change the km into m CS
!             IF ( data_out(k,i,j) == MISSING_VALUE .AND. 1000.*z_levs(k) > HGT(i,j) ) THEN
              IF ( data_out(k,i,j) == MISSING_VALUE .AND. z_levs(k) > HGT(i,j) ) THEN
!.CS

  !             We are below the first model level, but above the ground
  !             We need meter for the calculations so, GEOPT/G
    
!c change the km into m CS
!               plev = (((1000.*z_levs(k) - hgt_firstlayer(i,j))*PSFC(i,j) +  &
!                      (HGT(i,j) - 1000.*z_levs(k))*PRES(1,i,j)) /   &
!                      (HGT(i,j) - hgt_firstlayer(i,j))) 
                plev = (((z_levs(k) - hgt_firstlayer(i,j))*PSFC(i,j) +  &
                       (HGT(i,j) - z_levs(k))*PRES(1,i,j)) /   &
                       (HGT(i,j) - hgt_firstlayer(i,j))) 
!.CS
                IF ( cname == "pressure" ) data_out(k,i,j) = plev * 0.01
                IF ( cname(1:1) == "t") THEN
!c change the km into m CS
!                 tlev = TK(1,i,j) + (hgt_firstlayer(i,j)-1000.*z_levs(k))*.0065
                  tlev = TK(1,i,j) + (hgt_firstlayer(i,j)-z_levs(k))*.0065
!.CS
                  IF ( cname == "tk" ) data_out(k,i,j) = tlev 
                  IF ( cname == "tc" ) data_out(k,i,j) = tlev - 273.15
                  IF ( cname == "theta" ) THEN
                    gamma = (287.04/1004.)*(1.+(0.608-0.887)*QV(k,i,j))
!c change the km into m CS
!                   data_out(k,i,j) = tlev * (1000./plev)**gamma
                    data_out(k,i,j) = tlev * (100000./plev)**gamma
!.CS
                  ENDIF
                ENDIF
    
              ELSEIF ( data_out(k,i,j) == MISSING_VALUE ) THEN

  !             We are below both the ground and the lowest data level.
  !             First, find the model level that is closest to a "target" pressure
  !             level, where the "target" pressure is delta-p less that the local
  !             value of a horizontally smoothed surface pressure field.  We use
  !             delta-p = 150 hPa here. A standard lapse rate temperature profile
  !             passing through the temperature at this model level will be used
  !             to define the temperature profile below ground.  This is similar
  !             to the Benjamin and Miller (1990) method, except that for
  !             simplicity, they used 700 hPa everywhere for the "target" pressure.
  !             Code similar to what is implemented in RIP4

                ptarget = (PSFC(i,j)*.01) - 150.
                dpmin=1.e4
                kupper = 0
                loop_kIN_z : DO kin=nz,1,-1
                   kupper = kin
                   dp=abs( (PRES(kin,i,j)*.01) - ptarget )
                   IF (dp.gt.dpmin) exit loop_kIN_z
                   dpmin=min(dpmin,dp)
                ENDDO loop_kIN_z

                pbot=max(PRES(1,i,j),PSFC(i,j))
                zbot=min(hgt_firstlayer(i,j),HGT(i,j))   ! need height in meter

                tbotextrap=TK(kupper,i,j)*(pbot/PRES(kupper,i,j))**expon
                tvbotextrap=virtual(tbotextrap,QV(1,i,j))

  !             Calculations use height in meter, but we want the output in km
!c change the km into m CS
!               plev = pbot*(1.+0.0065/tvbotextrap*(zbot-1000.*z_levs(k)))**exponi
                plev = pbot*(1.+0.0065/tvbotextrap*(zbot-z_levs(k)))**exponi
!.CS
                IF ( cname == "pressure" ) data_out(k,i,j) = plev * 0.01
                IF ( cname(1:1) == "t") THEN
!c change the km into m CS
!                 tlev = TK(1,i,j) + (hgt_firstlayer(i,j)-1000.*z_levs(k))*.0065
                  tlev = TK(1,i,j) + (hgt_firstlayer(i,j)-z_levs(k))*.0065
!.CS
                IF ( cname == "pressure" ) data_out(k,i,j) = plev * 0.01
                  IF ( cname == "tk" ) data_out(k,i,j) = tlev 
                  IF ( cname == "tc" ) data_out(k,i,j) = tlev - 273.15
                  IF ( cname == "theta" ) THEN
                    gamma = (287.04/1004.)*(1.+(0.608-0.887)*QV(k,i,j))
!c change the mba into Pa CS
!                   data_out(k,i,j) = tlev * (1000./plev)**gamma
                    data_out(k,i,j) = tlev * (100000./plev)**gamma
!.CS
                  ENDIF
                ENDIF
                
              ENDIF


            ENDDO
            ENDDO
          ENDDO

        ENDIF
      ENDIF


      !!! All fields and geopt at higher levels come here
      DO j = 1, nxout
      DO i = 1, nyout
        DO k = 1, kk     
           if ( data_out(k,i,j) == MISSING_VALUE ) data_out(k,i,j) = data_in(1,i,j)
        END DO
        DO k = kk+1, nzout
           if ( data_out(k,i,j) == MISSING_VALUE ) data_out(k,i,j) = data_in(bottom_top_dim,i,j)
        END DO
      END DO
      END DO



  END SUBROUTINE interp




  SUBROUTINE calc_uvmet_3d(UUU ,   VVV,  &
                          u_met, v_met,  &
                          lon  , lat  ,  &
                          map_proj,truelat1,truelat2,stand_lon, &
                          nz,ny,nx)

  IMPLICIT NONE

  !Arguments
  real,  dimension(nz,ny,nx),intent(in)  :: UUU, VVV
  real,  dimension(ny,nx),intent(in)  :: lon, lat
  integer,intent(in)                  :: map_proj
  real,  dimension(nz,ny,nx),intent(out) :: u_met,v_met
  integer, intent(in)                                                                  :: nx, ny, nz
  real, intent(in)                  ::stand_lon
  real, optional,intent(in)                  ::truelat1,truelat2

  !Local
  integer                                         :: i, j, k
  real                                            :: cone
  real, dimension(ny,nx)  :: diff, alpha

  
  


  cone = 1.                                          !  PS
  IF ( map_proj .eq. 1) THEN                         !  Lambert Conformal mapping
    IF (present(truelat1).and.present(truelat2)) THEN
      IF (ABS(truelat1-truelat2) .GT. 0.1) THEN
         cone=(ALOG(COS(truelat1*RAD_PER_DEG))-            &
               ALOG(COS(truelat2*RAD_PER_DEG))) /          &
         (ALOG(TAN((90.-ABS(truelat1))*RAD_PER_DEG*0.5 ))- &
          ALOG(TAN((90.-ABS(truelat2))*RAD_PER_DEG*0.5 )) )
      ELSE
         cone = SIN(ABS(truelat1)*RAD_PER_DEG )
      ENDIF
    ELSE
      stop "we need tuelat 1 and 2 to do lambert mapping"
    ENDIF
  END IF


  diff = lon - stand_lon
  DO i = 1, nx
  DO j = 1, ny
    IF ( diff(j,i) .gt. 180. ) THEN
      diff(j,i) = diff(j,i) - 360.
    END IF
    IF ( diff(j,i) .lt. -180. ) THEN
      diff(j,i) = diff(j,i) + 360.
    END IF
  END DO
  END DO


  DO i = 1, nx
  DO j = 1, ny
     IF ( lat(j,i) .lt. 0. ) THEN
       alpha(j,i) = - diff(j,i) * cone * RAD_PER_DEG
     ELSE
       alpha(j,i) = diff(j,i) * cone * RAD_PER_DEG
     END IF
  END DO
  END DO

  

  DO k = 1,nz
    u_met(:,:,k) = VVV(:,:,k)*sin(alpha) + UUU(:,:,k)*cos(alpha)
    v_met(:,:,k) = VVV(:,:,k)*cos(alpha) - UUU(:,:,k)*sin(alpha)
  END DO

  END SUBROUTINE calc_uvmet_3d

  SUBROUTINE calc_uvmet_2d(U10 ,   V10,  &
                          u_met, v_met,  &
                          lon  , lat  ,  &
                          map_proj,truelat1,truelat2,stand_lon, &
                          nz,ny,nx)

  IMPLICIT NONE

  !Arguments
  real,  dimension(ny,nx),intent(in)  :: U10, V10
  real,  dimension(ny,nx),intent(in)  :: lon, lat
  integer,intent(in)                  :: map_proj
  real,  dimension(ny,nx),intent(out) :: u_met,v_met
  integer, intent(in)                                                                  :: nx, ny, nz
  real, intent(in)                  ::stand_lon
  real, optional,intent(in)                  ::truelat1,truelat2

  !Local
  integer                                         :: i, j, k
  real                                            :: cone
  real, dimension(ny,nx)  :: diff, alpha

  
  


  cone = 1.                                          !  PS
  IF ( map_proj .eq. 1) THEN                         !  Lambert Conformal mapping
    IF (present(truelat1).and.present(truelat2)) THEN
      IF (ABS(truelat1-truelat2) .GT. 0.1) THEN
         cone=(ALOG(COS(truelat1*RAD_PER_DEG))-            &
               ALOG(COS(truelat2*RAD_PER_DEG))) /          &
         (ALOG(TAN((90.-ABS(truelat1))*RAD_PER_DEG*0.5 ))- &
          ALOG(TAN((90.-ABS(truelat2))*RAD_PER_DEG*0.5 )) )
      ELSE
         cone = SIN(ABS(truelat1)*RAD_PER_DEG )
      ENDIF
    ELSE
      stop "we need tuelat 1 and 2 to do lambert mapping"
    ENDIF
  END IF


  diff = lon - stand_lon
  DO i = 1, nx
  DO j = 1, ny
    IF ( diff(j,i) .gt. 180. ) THEN
      diff(j,i) = diff(j,i) - 360.
    END IF
    IF ( diff(j,i) .lt. -180. ) THEN
      diff(j,i) = diff(j,i) + 360.
    END IF
  END DO
  END DO


  DO i = 1, nx
  DO j = 1, ny
     IF ( lat(j,i) .lt. 0. ) THEN
       alpha(j,i) = - diff(j,i) * cone * RAD_PER_DEG
     ELSE
       alpha(j,i) = diff(j,i) * cone * RAD_PER_DEG
     END IF
  END DO
  END DO

  

  u_met(:,:) = V10(:,:)*sin(alpha) + U10(:,:)*cos(alpha)
  v_met(:,:) = V10(:,:)*cos(alpha) - U10(:,:)*sin(alpha)

  END SUBROUTINE calc_uvmet_2d




  SUBROUTINE CAPE_init()

     INTEGER                                                        :: i,jt,ip,nthte,nprs,  iustnlist
     LOGICAL                                                        :: is_used
     character (len=20)                                             :: fname
     ! Open psadilookup.dat     
     DO iustnlist = 10,100
        INQUIRE(unit=iustnlist, opened=is_used)
        if (.not. is_used) exit
     END DO
     fname = 'psadilookup.dat' 
     OPEN (unit=iustnlist,file=fname,form='formatted',status='old')

     DO i = 1,14
       READ (iustnlist,*)
     ENDDO
     READ (iustnlist,*) nthte,nprs
     IF ( nthte.ne.150 .OR. nprs.ne.150 ) then
       PRINT*, 'Number of pressure or theta_e levels in lookup table'
       PRINT*, '     file not = 150.  Check lookup table file.'
       STOP
     ENDIF
 173 FORMAT (5e15.7)
     READ (iustnlist,173) (psadithte(jt),jt=1,nthte) 
     READ (iustnlist,173) (psadiprs(ip),ip=1,nprs)
     READ (iustnlist,173) ((psaditmk(ip,jt),ip=1,nprs),jt=1,nthte)
     CLOSE (iustnlist)  



  END SUBROUTINE CAPE_init

  SUBROUTINE calc_cape(cape, cin, &
                      hgt,  qv,  pres, tk, geopt,psfc,&
                      bottom_top_dim          , south_north_dim , west_east_dim)

!   If i3dflag=1, this routine calculates CAPE and CIN (in m**2/s**2,
!   or J/kg) for every grid point in the entire 3D domain (treating
!   each grid point as a parcel).  If i3dflag=0, then it
!   calculates CAPE and CIN only for the parcel with max theta-e in
!   the column, (i.e. something akin to Colman's MCAPE).  By "parcel",
!   we mean a 500-m deep parcel, with actual temperature and moisture
!   averaged over that depth.
!
!   In the case of i3dflag=0,
!   MCAPE, MCIN, LCL and LFC (2D fields are calculated)

  IMPLICIT NONE

  integer,parameter::i3dflag=1 ! currently, I only use the 3D function for my study

!f2py intent(in) bottom_top_dim,south_north_dim,west_east_dim
!f2py intent(in) hgt,psfc,qv,pres,tk,geopt
!f2py intent(out) cin,cape
!f2py depend(bottom_top_dim,south_north_dim,west_east_dim) cin,cape

  integer, intent(in)                                                  :: bottom_top_dim,south_north_dim,west_east_dim  
  real, dimension(               south_north_dim,west_east_dim),intent(in)                           :: HGT
  real, dimension(               south_north_dim,west_east_dim),intent(in)                           :: PSFC
  real, dimension(bottom_top_dim,south_north_dim,west_east_dim),intent(in)                           :: QV
  real, dimension(bottom_top_dim,south_north_dim,west_east_dim),intent(in)                           :: PRES
  real, dimension(bottom_top_dim,south_north_dim,west_east_dim),intent(in)                           :: TK
  real, dimension(bottom_top_dim,south_north_dim,west_east_dim),intent(in)                           :: GEOPT



  !Arguments
  real, dimension(bottom_top_dim,south_north_dim,west_east_dim),intent(out)  :: cape, cin

  ! Local variables
  integer                                                        :: i, j, k, kk, jt, ip
  integer                                                        :: kpar, kpar1, kpar2, kmax, klev, kel
  integer                                                        :: ilcl, klcl, klfc
  real, dimension(bottom_top_dim,south_north_dim,west_east_dim)  :: prs
  real, dimension(bottom_top_dim,south_north_dim,west_east_dim)  :: prsf
  real, dimension(bottom_top_dim,south_north_dim,west_east_dim)  :: ght
  real                                                           :: ethpari, zlcl, tvenv
  real                                                           :: p1, p2, pp1, pp2, pup, pdn
  real                                                           :: totprs, totqvp, totthe
  real                                                           :: eslift, ghtlift, qvplift, tmklift, tvlift
  real                                                           :: ghtpari, prspari, qvppari, tmkpari
  real                                                           :: tmkenv, qvpenv, tlcl
  real                                                           :: fac1, fac2, facden, th, deltap
  real                                                           :: benamin, davg, pavg, pressure, temp
  real                                                           :: e, eth, ethmax, q, dz, cpm

  
  !! Get fields we want from the ones we have
    
     prs      = PRES * 0.01                ! pressure in hPa
     ght      = GEOPT / G                  ! height in m


  !! First calculate a pressure array on FULL SIGMA levels
  !! Similar to the pfcalc.f routine from RIP4
  !! Top full sigma level is ommitted
     prsf(:,:,1) = PSFC(:,:)             !! Lowest full sigma set to surface pressure
     DO k = 2, bottom_top_dim
       prsf(:,:,k)=.5*(prs(:,:,k-1)+prs(:,:,k))
     END DO

     
     cape = 0.0
     cin  = 0.0

     DO i = 1,west_east_dim
     DO j = 1,south_north_dim          !! BIG i/j loop

       IF ( i3dflag == 1 ) THEN       !! 3D case

         kpar1=bottom_top_dim-1
         kpar2=1

       ELSE                           !! 2D case
 
!      Find parcel with max theta-e in lowest 3 km AGL.
         ethmax = -1.
         DO k = 1, bottom_top_dim
           IF ( ght(k,j,i)-HGT(j,i) .lt. 3000. ) THEN
             q        = max(QV(k,j,i),1.e-15)
             temp     = TK(k,j,i)
             pressure = prs(k,j,i)
             e        = (q*pressure)/(EPS+q)
             tlcl     = TLCLC1/(log(temp**TLCLC2/e)-TLCLC3)+TLCLC4
             eth  =     temp*(1000./pressure)**( GAMMA_RIP*(1.+GAMMAMD*q) )*     &
                        exp( (THTECON1/tlcl-THTECON2)*q*(1.+THTECON3*q) )
             IF ( eth .gt. ethmax ) THEN
               klev=k
               ethmax=eth
             END IF
           END IF
         END DO
         kpar1=klev
         kpar2=klev
 
!      Establish average properties of that parcel
!      (over depth of approximately davg meters)
         davg = 500.
         pavg = davg*prs(kpar1,j,i)*G /                        &
                ( Rd*virtual(TK(kpar1,j,i),QV(kpar1,j,i)) )
         p2 = min(prs(kpar1,j,i)+.5*pavg,prsf(i,j,1))
         p1 = p2-pavg
         totthe = 0.
         totqvp = 0.
         totprs = 0.
         DO k = 1,bottom_top_dim-1
           IF ( prsf(k,j,i)   .le. p1 ) GOTO 35
           IF ( prsf(k+1,j,i) .ge. p2 ) GOTO 34
           pressure = prs(k,j,i)
           pup      = prsf(k,j,i)
           pdn      = prsf(k+1,j,i)
           q        = max(QV(k,j,i),1.e-15)
           th       = TK(k,j,i)*(1000./pressure)**(GAMMA_RIP*(1.+GAMMAMD*q))
           pp1      = max(p1,pdn)
           pp2      = min(p2,pup)
           IF ( pp2 .gt. pp1 ) THEN
             deltap = pp2-pp1
             totqvp = totqvp+q*deltap
             totthe = totthe+th*deltap
             totprs = totprs+deltap
           END IF
 34        CONTINUE
         END DO
 35      CONTINUE
         qvppari = totqvp/totprs
         tmkpari = (totthe/totprs)*(prs(kpar1,j,i)/1000.)**    &
                   (GAMMA_RIP*(1.+GAMMAMD*QV(kpar1,j,i)))
       ENDIF

       !!!   END of 2D / 3D specific bits 


       DO kpar = kpar1,kpar2,-1                      !! This loop is done for both 2D / 3D
 
!   Calculate temperature and moisture properties of parcel

         IF ( i3dflag == 1 ) THEN    ! (Note, qvppari and tmkpari already calculated above for 2D case.)
           qvppari = QV(kpar,j,i)
           tmkpari = TK(kpar,j,i)
         END IF
         prspari = prs(kpar,j,i)
         ghtpari = ght(kpar,j,i)
         cpm     = cp*(1.+CPMD*qvppari)
 
         e       = max(1.e-20,qvppari*prspari/(EPS+qvppari))
         tlcl    = TLCLC1/(log(tmkpari**TLCLC2/e)-TLCLC3)+TLCLC4
         ethpari = tmkpari*(1000./prspari)**(GAMMA_RIP*(1.+GAMMAMD*qvppari))*   &
                   exp((THTECON1/tlcl-THTECON2)*qvppari*                    &
                   (1.+THTECON3*qvppari))
         zlcl    = ghtpari+(tmkpari-tlcl)/(G/cpm)

!   Calculate buoyancy and relative height of lifted parcel at
!   all levels, and store in bottom up arrays.  Add a level at the LCL,
!   and at all points where buoyancy is zero.
 
         kk = 0                    ! for arrays that go bottom to top
         ilcl = 0
         IF ( ghtpari .ge. zlcl ) THEN
           !! initial parcel already saturated or supersaturated.
           ilcl = 2
           klcl = 1
         END IF

         DO k = kpar,bottom_top_dim
 33        kk=kk+1                ! for arrays that go bottom to top

           IF ( ght(k,j,i) .lt. zlcl ) THEN ! model level is below LCL
             qvplift = qvppari
             tmklift = tmkpari-G/cpm*(ght(k,j,i)-ghtpari)
             tvenv   = virtual(TK(k,j,i),QV(k,j,i))
             tvlift  = virtual(tmklift,qvplift)
             ghtlift = ght(k,j,i)
           ELSE IF ( ght(k,j,i) .ge. zlcl .AND. ilcl .eq. 0 ) THEN
             !! This model level and previous model level straddle the LCL,
             !! so first create a new level in the bottom-up array, at the LCL.
             tmklift = tlcl
             qvplift = qvppari
             facden  = ght(k,j,i)-ght(k-1,j,i)
             fac1    = (zlcl-ght(k-1,j,i))/facden
             fac2    = (ght(k,j,i)-zlcl)/facden
             tmkenv  = TK(k-1,j,i)*fac2+TK(k,j,i)*fac1
             qvpenv  = QV(k-1,j,i)*fac2+QV(k,j,i)*fac1
             tvenv   = virtual(tmkenv,qvpenv)
             tvlift  = virtual(tmklift,qvplift)
             ghtlift = zlcl
             ilcl    = 1
           ELSE
             tmklift = tonpsadiabat(ethpari,prs(k,j,i))                                
             eslift  = EZERO*exp(eslcon1*(tmklift-CELKEL)/    &
                       (tmklift-eslcon2))
             qvplift = EPS*eslift/(prs(k,j,i)-eslift)
             tvenv   = virtual(TK(k,j,i),QV(k,j,i))
             tvlift  = virtual(tmklift,qvplift)
             ghtlift = ght(k,j,i)
           END IF

           buoy(kk) = G*(tvlift-tvenv)/tvenv  ! buoyancy
           zrel(kk) = ghtlift-ghtpari

           IF ( (buoy(kk)*buoy(kk-1).lt.0.0) .AND. (kk.gt.1) ) THEN
             !! Parcel ascent curve crosses sounding curve, so create a new level
             !! in the bottom-up array at the crossing.
             kk = kk+1
             buoy(kk)   = buoy(kk-1)
             zrel(kk)   = zrel(kk-1)
             buoy(kk-1) = 0.
             zrel(kk-1) = zrel(kk-2) + buoy(kk-2)/(buoy(kk-2)-buoy(kk))*  &
                          (zrel(kk)-zrel(kk-2))
           END IF

           IF (ilcl == 1) THEN
             klcl = kk
             ilcl = 2
             GOTO 33
           END IF

         END DO         !! END DO k = kpar,bottom_top_dim

         kmax = kk
         IF (kmax .gt. 150) THEN
           PRINT*, 'in calc_cape: kmax got too big. kmax=',kmax
           STOP
         ENDIF

 
!        Get the accumulated buoyant energy from the parcel's starting
!        point, at all levels up to the top level.

         benaccum(1) = 0.0
         benamin     = 9e9
         DO k = 2,kmax
           dz          = zrel(k)-zrel(k-1)
           benaccum(k) = benaccum(k-1)+.5*dz*(buoy(k-1)+buoy(k))
             IF ( benaccum(k) .lt. benamin ) THEN
               benamin = benaccum(k)
             END IF
         END DO


!        Determine equilibrium level (EL), which we define as the highest
!        level of non-negative buoyancy above the LCL. Note, this may be
!        the top level if the parcel is still buoyant there.

         DO k = kmax,klcl,-1
           IF ( buoy(k) .ge. 0. ) THEN
             kel = k   ! k of equilibrium level
             GOTO 50
           END IF
         END DO


!        If we got through that loop, then there is no non-negative
!        buoyancy above the LCL in the sounding.  In these situations,
!        both CAPE and CIN will be set to -0.1 J/kg.  Also, where CAPE is
!        non-zero, CAPE and CIN will be set to a minimum of +0.1 J/kg, so
!        that the zero contour in either the CIN or CAPE fields will
!        circumscribe regions of non-zero CAPE.
 
         cape(kpar,j,i) = -0.1
         cin(kpar,j,i)  = -0.1
         klfc = kmax
 
         GOTO 102
 
 50      CONTINUE

 

!        If there is an equilibrium level, then CAPE is positive.  We'll
!        define the level of free convection (LFC) as the point below the
!        EL, but at or above the LCL, where accumulated buoyant energy is a
!        minimum.  The net positive area (accumulated buoyant energy) from
!        the LFC up to the EL will be defined as the CAPE, and the net
!        negative area (negative of accumulated buoyant energy) from the
!        parcel starting point to the LFC will be defined as the convective
!        inhibition (CIN).
 
!        First get the LFC according to the above definition.
 
         benamin = 9e9
         klfc = kmax
         DO k = klcl,kel
           IF ( benaccum(k) .lt. benamin ) THEN
             benamin = benaccum(k)
             klfc = k
           END IF
         END DO
 
!        Now we can assign values to cape and cin
 
         cape(kpar,j,i) = max(benaccum(kel)-benamin,0.1)
         cin(kpar,j,i)  = max(-benamin,0.1)
 
!        CIN is uninteresting when CAPE is small (< 100 J/kg), so set
!        CIN to -.1 in that case.
 
         IF ( cape(kpar,j,i) .lt. 100. ) cin(kpar,j,i) = -0.1

 102     CONTINUE

       ENDDO          !! END of BIG 2D/3D loop


!       IF ( i3dflag == 0 ) THEN
!         SCRa(i,j,1) = cape(kpar1,j,i)
!         SCRa(i,j,2) = cin(kpar1,j,i)
!         SCRa(i,j,3) = zrel(klcl)+ghtpari-HGT(j,i)   ! meters AGL (LCL)
!         SCRa(i,j,4) = zrel(klfc)+ghtpari-HGT(j,i)   ! meters AGL (LFC)
!       ENDIF

 
     END DO
     END DO                !! END BIG i/j loop
 

  !! These will be set by module_diagnostics as we have more than 1 field

!  IF ( i3dflag == 1 ) THEN
!   SCRa = cape
!   SCRb = cin
!  ENDIF


  END SUBROUTINE calc_cape


!*********************************************************************c
!*********************************************************************c
  FUNCTION tonpsadiabat (thte,prs)
 
 
!   This function gives the temperature (in K) on a moist adiabat
!   (specified by thte in K) given pressure in hPa.  It uses a
!   lookup table, with data that was generated by the Bolton (1980)
!   formula for theta_e.
      REAL, INTENT (in)          :: thte,prs
      REAL                       :: tonpsadiabat
      REAL                       :: fracjt,fracjt2  
      REAL                       :: fracip,fracip2  
! local varirables
      INTEGER                    :: IPCH
      INTEGER                    :: JTCH
      INTEGER                    :: JT,IP

 
!     First check if pressure is less than min pressure in lookup table.
!     If it is, assume parcel is so dry that the given theta-e value can
!     be interpretted as theta, and get temperature from the simple dry
!     theta formula.
      
 
      IF ( prs .le. psadiprs(150) ) THEN
        tonpsadiabat = thte*(prs/1000.)**GAMMA_RIP
        RETURN
      ENDIF
 

!     Otherwise, look for the given thte/prs point in the lookup table.
 
      DO jtch = 1,150-1
        IF ( thte.ge.psadithte(jtch) .AND. thte.lt.psadithte(jtch+1) ) THEN
          jt = jtch
          GOTO 213
        END IF
      END DO
      jt = -1
 213  CONTINUE

      DO ipch = 1,150-1
        if ( prs.le.psadiprs(ipch) .AND. prs.gt.psadiprs(ipch+1) ) THEN
          ip = ipch
          GOTO 215
        END IF
      ENDDO
      ip = -1
 215  CONTINUE


      IF ( jt.eq.-1 .OR. ip.eq.-1 ) THEN
        PRINT*, 'Outside of lookup table bounds. prs,thte=',prs,thte
        STOP 
      ENDIF


      fracjt  = (thte-psadithte(jt))/(psadithte(jt+1)-psadithte(jt))
      fracjt2 = 1.-fracjt
      fracip  = (psadiprs(ip)-prs)/(psadiprs(ip)-psadiprs(ip+1))
      fracip2 = 1.-fracip

      IF ( psaditmk(ip,jt  ).gt.1e9 .OR. psaditmk(ip+1,jt  ).gt.1e9 .OR.   &
           psaditmk(ip,jt+1).gt.1e9 .OR. psaditmk(ip+1,jt+1).gt.1e9 ) THEN
        PRINT*, 'Tried to access missing tmperature in lookup table.'
        PRINT*, 'Prs and Thte probably unreasonable. prs,thte=',prs,thte
        STOP
      ENDIF

      tonpsadiabat = fracip2*fracjt2*psaditmk(ip  ,jt  )+   &
                     fracip *fracjt2*psaditmk(ip+1,jt  )+   &
                     fracip2*fracjt *psaditmk(ip  ,jt+1)+   &
                     fracip *fracjt *psaditmk(ip+1,jt+1)
      

  END FUNCTION tonpsadiabat 

  FUNCTION tdewq(q,p) RESULT (tdew)
   REAL    , PARAMETER :: SVP1=0.6112
   REAL    , PARAMETER :: SVP2=17.67
   REAL    , PARAMETER :: eps = 0.622,  s1 = 243.5,s2 = svp2 ,  s3 = svp1*10

!
! dew point temperature : Bolton (1980) Eq (11)
!
   REAL, INTENT(IN) :: & 
        q(:),         &! water vapor mixing ratio [kg/kg]
        p(:)           ! pressure [Pa]

   REAL ::        &    
        tdew(size(q)),      &! temperature at the dew point [C]
        lnew(size(q))        ! ln(ew)
       
!-----------------------------------------------------------------------
!
      lnew = log(max(1.e-8, p*q/(eps+q)))
      tdew = (243.5*lnew-1562.159)/(24.085-lnew) 

  END FUNCTION tdewq



!-----------------------------------------------------------------------
!ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
!-----------------------------------------------------------------------

 subroutine getcape_3d( pres , tc, qv, cape , cin, &! a 3d wrapper for python
                      bottom_top_dim          , south_north_dim , west_east_dim)
    implicit none

!f2py intent(in)  pres,tc,qv,bottom_top_dim          , south_north_dim , west_east_dim
!f2py intent(inplace) cape,cin
!f2py 
    integer, intent(in)                                                  :: bottom_top_dim,south_north_dim,west_east_dim  
    real, dimension(bottom_top_dim,south_north_dim,west_east_dim),intent(in)                           :: PRES
    real, dimension(bottom_top_dim,south_north_dim,west_east_dim),intent(in)                           :: TC
    real, dimension(bottom_top_dim,south_north_dim,west_east_dim),intent(in)                           :: QV
    real, dimension(bottom_top_dim)                                                                    :: TD
    real, dimension(south_north_dim,west_east_dim),intent(out)  :: cape, cin



  !Arguments
    integer i,j
    DO i = 1,west_east_dim
      DO j = 1,south_north_dim          !! BIG i/j loop
        td(:)=tdewq(qv(:,j,i),pres(:,j,i)) 
        call getcape(nk=bottom_top_dim, p_in=pres(:,j,i) ,t_in=tc(:,j,i),td_in=td(:)    , cape=cape(j,i),cin=cin(j,i)) 
      END DO
    END DO



  end subroutine getcape_3d
  subroutine getcape( nk , p_in , t_in , td_in, cape , cin )
    implicit none
    integer, intent(in) :: nk
    real, dimension(nk), intent(in) :: p_in,t_in,td_in
    real, intent(out) :: cape,cin

!-----------------------------------------------------------------------
!
!  getcape - a fortran90 subroutine to calculate Convective Available
!            Potential Energy (CAPE) from a sounding.
!
!  Version 1.02                           Last modified:  10 October 2008
!
!  Author:  George H. Bryan
!           Mesoscale and Microscale Meteorology Division
!           National Center for Atmospheric Research
!           Boulder, Colorado, USA
!           gbryan@ucar.edu
!
!  Disclaimer:  This code is made available WITHOUT WARRANTY.
!
!  References:  Bolton (1980, MWR, p. 1046) (constants and definitions)
!               Bryan and Fritsch (2004, MWR, p. 2421) (ice processes)
!
!-----------------------------------------------------------------------
!
!  Input:     nk - number of levels in the sounding (integer)
!
!           p_in - one-dimensional array of pressure (mb) (real)   !!!should be Pa!!!!
!
!           t_in - one-dimensional array of temperature (C) (real)
!
!          td_in - one-dimensional array of dewpoint temperature (C) (real)
!
!  Output:  cape - Convective Available Potential Energy (J/kg) (real)
!
!            cin - Convective Inhibition (J/kg) (real)
!
!-----------------------------------------------------------------------
!  User options:

    real, parameter :: pinc = 100.0   ! Pressure increment (Pa)
                                      ! (smaller number yields more accurate
                                      !  results,larger number makes code 
                                      !  go faster)

    integer, parameter :: source = 2    ! Source parcel:
                                        ! 1 = surface
                                        ! 2 = most unstable (max theta-e)
                                        ! 3 = mixed-layer (specify ml_depth)

    real, parameter :: ml_depth =  200.0  ! depth (m) of mixed layer 
                                          ! for source=3

    integer, parameter :: adiabat = 1   ! Formulation of moist adiabat:
                                        ! 1 = pseudoadiabatic, liquid only
                                        ! 2 = reversible, liquid only
                                        ! 3 = pseudoadiabatic, with ice
                                        ! 4 = reversible, with ice

!-----------------------------------------------------------------------
!ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
!-----------------------------------------------------------------------
!            No need to modify anything below here:
!-----------------------------------------------------------------------
!ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
!-----------------------------------------------------------------------

    logical :: doit,ice,cloud,not_converged
    integer :: k,kmax,n,nloop,i,orec
    real, dimension(nk) :: p,t,td,pi,q,th,thv,z,pt,pb,pc,pn,ptv

    real :: the,maxthe,parea,narea,lfc
    real :: th1,p1,t1,qv1,ql1,qi1,b1,pi1,thv1,qt,dp,dz,ps,frac
    real :: th2,p2,t2,qv2,ql2,qi2,b2,pi2,thv2
    real :: thlast,fliq,fice,tbar,qvbar,qlbar,qibar,lhv,lhs,lhf,rm,cpm
    real*8 :: avgth,avgqv
!   real :: getqvs,getqvi,getthe

!-----------------------------------------------------------------------

    real, parameter :: g     = 9.81
    real, parameter :: p00   = 100000.0
    real, parameter :: cp    = 1005.7
    real, parameter :: rd    = 287.04
    real, parameter :: rv    = 461.5
    real, parameter :: xlv   = 2501000.0
    real, parameter :: xls   = 2836017.0
    real, parameter :: t0    = 273.15
    real, parameter :: cpv   = 1875.0
    real, parameter :: cpl   = 4190.0
    real, parameter :: cpi   = 2118.636
    real, parameter :: lv1   = xlv+(cpl-cpv)*t0
    real, parameter :: lv2   = cpl-cpv
    real, parameter :: ls1   = xls+(cpi-cpv)*t0
    real, parameter :: ls2   = cpi-cpv

    real, parameter :: rp00  = 1.0/p00
    real, parameter :: eps   = rd/rv
    real, parameter :: reps  = rv/rd
    real, parameter :: rddcp = rd/cp
    real, parameter :: cpdrd = cp/rd
    real, parameter :: cpdg  = cp/g

    real, parameter :: converge = 0.0002

    integer, parameter :: debug_level =   0

!-----------------------------------------------------------------------

!---- convert p,t,td to mks units; get pi,q,th,thv ----!

    do k=1,nk
        p(k) = p_in(k)
        t(k) = 273.15+t_in(k)
       td(k) = 273.15+td_in(k)
       pi(k) = (p(k)*rp00)**rddcp
        q(k) = getqvs(p(k),td(k))
       th(k) = t(k)/pi(k)
      thv(k) = th(k)*(1.0+reps*q(k))/(1.0+q(k))
    enddo

!---- get height using the hydrostatic equation ----!

    z(1) = 0.0
    do k=2,nk
      dz = -cpdg*0.5*(thv(k)+thv(k-1))*(pi(k)-pi(k-1))
      z(k) = z(k-1) + dz
    enddo

!---- find source parcel ----!

  IF(source.eq.1)THEN
    ! use surface parcel
    kmax = 1

  ELSEIF(source.eq.2)THEN
    ! use most unstable parcel (max theta-e)

    IF(p(1).lt.50000.0)THEN
      ! first report is above 500 mb ... just use the first level reported
      kmax = 1
      maxthe = getthe(p(1),t(1),td(1),q(1))
    ELSE
      ! find max thetae below 500 mb
      maxthe = 0.0
      do k=1,nk
        if(p(k).ge.50000.0)then
          the = getthe(p(k),t(k),td(k),q(k))
          if( the.gt.maxthe )then
            maxthe = the
            kmax = k
          endif
        endif
      enddo
    ENDIF
    if(debug_level.ge.100) print *,'  kmax,maxthe = ',kmax,maxthe

  ELSEIF(source.eq.3)THEN
    ! use mixed layer

    IF( (z(2)-z(1)).gt.ml_depth )THEN
      ! the second level is above the mixed-layer depth:  just use the
      ! lowest level

      avgth = th(1)
      avgqv = q(1)
      kmax = 1

    ELSEIF( z(nk).lt.ml_depth )THEN
      ! the top-most level is within the mixed layer:  just use the
      ! upper-most level

      avgth = th(nk)
      avgqv = q(nk)
      kmax = nk

    ELSE
      ! calculate the mixed-layer properties:

      avgth = 0.0
      avgqv = 0.0
      k = 2
      if(debug_level.ge.100) print *,'  ml_depth = ',ml_depth
      if(debug_level.ge.100) print *,'  k,z,th,q:'
      if(debug_level.ge.100) print *,1,z(1),th(1),q(1)

      do while( (z(k).le.ml_depth) .and. (k.le.nk) )

        if(debug_level.ge.100) print *,k,z(k),th(k),q(k)

        avgth = avgth + 0.5*(z(k)-z(k-1))*(th(k)+th(k-1))
        avgqv = avgqv + 0.5*(z(k)-z(k-1))*(q(k)+q(k-1))

        k = k + 1

      enddo

      th2 = th(k-1)+(th(k)-th(k-1))*(ml_depth-z(k-1))/(z(k)-z(k-1))
      qv2 =  q(k-1)+( q(k)- q(k-1))*(ml_depth-z(k-1))/(z(k)-z(k-1))

      if(debug_level.ge.100) print *,999,ml_depth,th2,qv2

      avgth = avgth + 0.5*(ml_depth-z(k-1))*(th2+th(k-1))
      avgqv = avgqv + 0.5*(ml_depth-z(k-1))*(qv2+q(k-1))

      if(debug_level.ge.100) print *,k,z(k),th(k),q(k)

      avgth = avgth/ml_depth
      avgqv = avgqv/ml_depth

      kmax = 1

    ENDIF

    if(debug_level.ge.100) print *,avgth,avgqv

  ELSE

    print *
    print *,'  Unknown value for source'
    print *
    print *,'  source = ',source
    print *
    stop

  ENDIF

!---- define parcel properties at initial location ----!
    narea = 0.0

  if( (source.eq.1).or.(source.eq.2) )then
    k    = kmax
    th2  = th(kmax)
    pi2  = pi(kmax)
    p2   = p(kmax)
    t2   = t(kmax)
    thv2 = thv(kmax)
    qv2  = q(kmax)
    b2   = 0.0
  elseif( source.eq.3 )then
    k    = kmax
    th2  = avgth
    qv2  = avgqv
    thv2 = th2*(1.0+reps*qv2)/(1.0+qv2)
    pi2  = pi(kmax)
    p2   = p(kmax)
    t2   = th2*pi2
    b2   = g*( thv2-thv(kmax) )/thv(kmax)
  endif

    ql2 = 0.0
    qi2 = 0.0
    qt  = qv2

    cape = 0.0
    cin  = 0.0
    lfc  = 0.0

    doit = .true.
    cloud = .false.
    if(adiabat.eq.1.or.adiabat.eq.2)then
      ice = .false.
    else
      ice = .true.
    endif

      the = getthe(p2,t2,t2,qv2)
      if(debug_level.ge.100) print *,'  the = ',the

!---- begin ascent of parcel ----!

      if(debug_level.ge.100)then
        print *,'  Start loop:'
        print *,'  p2,th2,qv2 = ',p2,th2,qv2
      endif

    do while( doit .and. (k.lt.nk) )

        k = k+1
       b1 =  b2

       dp = p(k-1)-p(k)

      if( dp.lt.pinc )then
        nloop = 1
      else
        nloop = 1 + int( dp/pinc )
        dp = dp/float(nloop)
      endif

      do n=1,nloop

         p1 =  p2
         t1 =  t2
        pi1 = pi2
        th1 = th2
        qv1 = qv2
        ql1 = ql2
        qi1 = qi2
        thv1 = thv2

        p2 = p2 - dp
        pi2 = (p2*rp00)**rddcp

        thlast = th1
        i = 0
        not_converged = .true.

        do while( not_converged )
          i = i + 1
          t2 = thlast*pi2
          if(ice)then
            fliq = max(min((t2-233.15)/(273.15-233.15),1.0),0.0)
            fice = 1.0-fliq
          else
            fliq = 1.0
            fice = 0.0
          endif
          qv2 = min( qt , fliq*getqvs(p2,t2) + fice*getqvi(p2,t2) )
          qi2 = max( fice*(qt-qv2) , 0.0 )
          ql2 = max( qt-qv2-qi2 , 0.0 )

          tbar  = 0.5*(t1+t2)
          qvbar = 0.5*(qv1+qv2)
          qlbar = 0.5*(ql1+ql2)
          qibar = 0.5*(qi1+qi2)

          lhv = lv1-lv2*tbar
          lhs = ls1-ls2*tbar
          lhf = lhs-lhv

          rm=rd+rv*qvbar
          cpm=cp+cpv*qvbar+cpl*qlbar+cpi*qibar
          th2=th1*exp(  lhv*(ql2-ql1)/(cpm*tbar)     &
                       +lhs*(qi2-qi1)/(cpm*tbar)     &
                       +(rm/cpm-rd/cp)*alog(p2/p1) )

          if(i.gt.90) print *,i,th2,thlast,th2-thlast
          if(i.gt.100)then
            print *
            print *,'  Error:  lack of convergence'
            print *
            print *,'  ... stopping iteration '
            print *
            stop 1001
          endif
          if( abs(th2-thlast).gt.converge )then
            thlast=thlast+0.3*(th2-thlast)
          else
            not_converged = .false.
          endif
        enddo

        ! Latest pressure increment is complete.  Calculate some
        ! important stuff:

        if( ql2.ge.1.0e-10 ) cloud = .true.

        IF(adiabat.eq.1.or.adiabat.eq.3)THEN
          ! pseudoadiabat
          qt  = qv2
          ql2 = 0.0
          qi2 = 0.0
        ELSEIF(adiabat.le.0.or.adiabat.ge.5)THEN
          print *
          print *,'  Undefined adiabat'
          print *
          stop 10000
        ENDIF

      enddo

      thv2 = th2*(1.0+reps*qv2)/(1.0+qv2+ql2+qi2)
        b2 = g*( thv2-thv(k) )/thv(k)
        dz = -cpdg*0.5*(thv(k)+thv(k-1))*(pi(k)-pi(k-1))

      the = getthe(p2,t2,t2,qv2)

      ! Get contributions to CAPE and CIN:

      if( (b2.ge.0.0) .and. (b1.lt.0.0) )then
        ! first trip into positive area
        ps = p(k-1)+(p(k)-p(k-1))*(0.0-b1)/(b2-b1)
        frac = b2/(b2-b1)
        parea =  0.5*b2*dz*frac
        narea = narea-0.5*b1*dz*(1.0-frac)
        if(debug_level.ge.200)then
          print *,'      b1,b2 = ',b1,b2
          print *,'      p1,ps,p2 = ',p(k-1),ps,p(k)
          print *,'      frac = ',frac
          print *,'      parea = ',parea
          print *,'      narea = ',narea
        endif
        cin  = cin  + narea
        narea = 0.0
      elseif( (b2.lt.0.0) .and. (b1.gt.0.0) )then
        ! first trip into neg area
        ps = p(k-1)+(p(k)-p(k-1))*(0.0-b1)/(b2-b1)
        frac = b1/(b1-b2)
        parea =  0.5*b1*dz*frac
        narea = -0.5*b2*dz*(1.0-frac)
        if(debug_level.ge.200)then
          print *,'      b1,b2 = ',b1,b2
          print *,'      p1,ps,p2 = ',p(k-1),ps,p(k)
          print *,'      frac = ',frac
          print *,'      parea = ',parea
          print *,'      narea = ',narea
        endif
      elseif( b2.lt.0.0 )then
        ! still collecting negative buoyancy
        parea =  0.0
        narea = narea-0.5*dz*(b1+b2)
      else
        ! still collecting positive buoyancy
        parea =  0.5*dz*(b1+b2)
        narea =  0.0
      endif

      cape = cape + max(0.0,parea)

      if(debug_level.ge.200)then
        write(6,102) p2,b1,b2,cape,cin,cloud
102     format(5(f13.4),2x,l1)
      endif

      if( (p(k).le.10000.0).and.(b2.lt.0.0) )then
        ! stop if b < 0 and p < 100 mb
        doit = .false.
      endif

    enddo

!---- All done ----!

    return
    end subroutine getcape

!-----------------------------------------------------------------------
!ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
!-----------------------------------------------------------------------

    real function getqvs(p,t)
    implicit none

    real :: p,t,es

    real, parameter :: eps = 287.04/461.5

    es = 611.2*exp(17.67*(t-273.15)/(t-29.65))
    getqvs = eps*es/(p-es)

    return
    end function getqvs

!-----------------------------------------------------------------------
!ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
!-----------------------------------------------------------------------

    real function getqvi(p,t)
    implicit none

    real :: p,t,es

    real, parameter :: eps = 287.04/461.5

    es = 611.2*exp(21.8745584*(t-273.15)/(t-7.66))
    getqvi = eps*es/(p-es)

    return
    end function getqvi

!-----------------------------------------------------------------------
!ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
!-----------------------------------------------------------------------

    real function getthe(p,t,td,q) 
    implicit none

    real :: p,t,td,q
    real :: tlcl

    if( (td-t).ge.-0.1 )then
      tlcl = t
    else
      tlcl = 56.0 + ( (td-56.0)**(-1) + 0.00125*alog(t/td) )**(-1)
    endif

    getthe=t*( (100000.0/p)**(0.2854*(1.0-0.28*q)) )   &
            *exp( ((3376.0/tlcl)-2.54)*q*(1.0+0.81*q) )

    end function getthe

!-----------------------------------------------------------------------
!ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
!-----------------------------------------------------------------------

END MODULE ARWpost
