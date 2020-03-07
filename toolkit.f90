!FORTRAN 90 subroutines to optimize mathematical operations, currently including:
! 1- AIC generation
! 2- Calculation of local self-induced velocity based on adjacent lines
! 3- Quickly calculate argument in yz plane
! 4- Calculate point arguments and local coord. system matrix for input surface abutment guiding panel
subroutine aicm_lines_gen(npan, nlin, lines, colpoints, aicm)
    integer, intent(IN) :: npan, nlin
    real(8), intent(IN) :: lines(1:nlin, 1:3, 1:2), colpoints(1:npan, 1:3)
    real(8), intent(OUT) :: aicm(1:3, 1:npan, 1:nlin)

    integer :: i, j
    real(8) :: a(3), b(3), na, nb

    do i=1, npan
        do j=1, nlin
            a=lines(j, 1:3, 1)-colpoints(i, 1:3)
            b=lines(j, 1:3, 2)-colpoints(i, 1:3)
            na=norm2(a)
            nb=norm2(b)
            aicm(1:3, i, j)=(((/a(2)*b(3)-a(3)*b(2), &
            a(3)*b(1)-a(1)*b(3), &
            a(1)*b(2)-a(2)*b(1)/)*(1.0/na+1.0/nb))/&
            (na*nb+dot_product(a, b)))/12.5663706
        end do
    end do
end subroutine aicm_lines_gen

subroutine self_influence(nlin, nloc, lines, solution, S, nvec, loclines, vdv)
    integer, intent(IN) :: nlin, nloc
    real(8), intent(IN) :: lines(1:nlin, 1:3, 1:2), solution(1:nlin), S, nvec(1:3)
    integer, intent(IN) :: loclines(1:nloc)
    real(8), intent(OUT) :: vdv(3)

    integer :: i
    real(8) :: Gamma(3)

    vdv=(/0.0, 0.0, 0.0/)

    do i=1, nloc
        Gamma=solution(loclines(i))*(lines(loclines(i), 1:3, 2)-lines(loclines(i), 1:3, 1))
        vdv=vdv+(/Gamma(2)*nvec(3)-Gamma(3)*nvec(2), Gamma(3)*nvec(1)-Gamma(1)*nvec(3), Gamma(1)*nvec(2)-Gamma(2)*nvec(1)/)
    end do

    vdv=vdv/(nloc*S)
end subroutine self_influence

subroutine pointarg(point1, point2, arg)
    real(8), intent(IN) :: point1(1:3), point2(1:3)
    real(8), intent(OUT) :: arg

    arg=atan2(point2(2)-point1(2), point2(3)-point1(3))
end subroutine pointarg

subroutine body_panel_process(points, tolerance, p0, Mtosys, Mtouni, ptsconv)
    real(8), intent(IN) :: points(1:3, 1:4), tolerance
    real(8), intent(OUT) :: p0(1:3), Mtosys(1:3, 1:3), Mtouni(1:3, 1:3), ptsconv(1:3, 1:4)

    integer :: i

    p0=sum(points, dim=2)/4

    Mtosys(1, 1:3)=points(1:3, 2)-points(1:3, 1)
    if(norm2(Mtosys(1, 1:3))<tolerance) then
        Mtosys(1, 1:3)=points(1:3, 3)-points(1:3, 4)
    end if
    Mtosys(2, 1:3)=points(1:3, 3)-points(1:3, 1)
    if(norm2(Mtosys(2, 1:3))<tolerance) then
        Mtosys(2, 1:3)=points(1:3, 3)-points(1:3, 2)
    end if
    Mtosys(1, 1:3)=Mtosys(1, 1:3)/norm2(Mtosys(1, 1:3))
    Mtosys(2, 1:3)=Mtosys(2, 1:3)-Mtosys(1, 1:3)*dot_product(Mtosys(1, 1:3), Mtosys(2, 1:3))
    Mtosys(2, 1:3)=Mtosys(2, 1:3)/norm2(Mtosys(2, 1:3))
    Mtosys(3, 1:3)=(/Mtosys(1, 2)*Mtosys(2, 3)-Mtosys(1, 3)*Mtosys(2, 2), &
    Mtosys(1, 3)*Mtosys(2, 1)-Mtosys(1, 1)*Mtosys(2, 3), Mtosys(1, 1)*Mtosys(2, 2)-Mtosys(1, 2)*Mtosys(2, 1)/)
    Mtouni=transpose(Mtosys)

    do i=1, 4
        ptsconv(1:3, i)=points(1:3, i)-p0
    end do
    ptsconv=matmul(Mtosys, ptsconv)
end subroutine body_panel_process

subroutine get_panel_contact(npan, p, u, Mtosys_set, Mtouni_set, points_set, p0_set, tolerance, pcont, error)
    integer, intent(IN) :: npan
    real(8), intent(IN) :: p(1:3), u(1:3), Mtosys_set(1:npan, 1:3, 1:3), &
    Mtouni_set(1:npan, 1:3, 1:3), points_set(1:npan, 1:3, 1:4), p0_set(1:npan, 1:3), tolerance
    real(8), intent(OUT) :: pcont(1:3)
    logical, intent(OUT) :: error

    real(8) :: pl(1:3), ul(1:3), locpoints(1:3, 1:4), lambda, side(1:3), vect(1:3)
    integer :: n, i
    logical :: found, isin

    found=.FALSE.
    pcont=(/0.0, 0.0, 0.0/)
    n=1

    do while((.NOT. found).AND.(n<=npan))
        if(dot_product(Mtosys_set(n, 3, 1:3), u)<0.0) then
            pl=matmul(Mtosys_set(n, 1:3, 1:3), p-p0_set(n, 1:3))
            ul=matmul(Mtosys_set(n, 1:3, 1:3), u)
            locpoints=points_set(n, 1:3, 1:4)
            if(pl(3)==0.0) then
                pcont=pl
                i=1
                isin=.TRUE.
                do while(i<=4 .AND. isin)
                    side=locpoints(1:3, mod(i, 4)+1)-locpoints(1:3, i)
                    vect=pcont-locpoints(1:3, i)
                    isin=(isin .AND. ((vect(1)*side(2)-vect(2)*side(1))<0.0))
                    i=i+1
                end do
                if(isin) then
                    found=.TRUE.
                end if
            else
                if(abs(ul(3))<tolerance) then
                    found=.FALSE.
                else
                    lambda=-pl(3)/ul(3)
                    pcont=pl+lambda*ul
                    i=1
                    isin=.TRUE.
                    do while(i<=4 .AND. isin)
                        side=locpoints(1:3, mod(i, 4)+1)-locpoints(1:3, i)
                        vect=pcont-locpoints(1:3, i)
                        isin=(isin .AND. ((vect(1)*side(2)-vect(2)*side(1))<0.0))
                        i=i+1
                    end do
                    if(isin) then
                        found=.TRUE.
                    end if
                end if
            end if
        end if
        if(.NOT. found) then
            n=n+1
        end if
    end do
    pcont=matmul(Mtouni_set(n, 1:3, 1:3), pcont)+p0_set(n, 1:3)

    error=(.NOT. found)
end subroutine get_panel_contact