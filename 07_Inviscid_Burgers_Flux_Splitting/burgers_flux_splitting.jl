using CPUTime
using Printf
using Plots
font = Plots.font("Times New Roman", 18)
pyplot(guidefont=font, xtickfont=font, ytickfont=font, legendfont=font)

#-----------------------------------------------------------------------------#
# Compute numerical solution
#   - Time integration using Runge-Kutta third order
#   - 5th-order Compact WENO scheme for spatial terms
#-----------------------------------------------------------------------------#
function numerical(nx,ns,nt,dx,dt,q)
    x = Array{Float64}(undef, nx)
    un = Array{Float64}(undef, nx) # numerical solsution at every time step
    ut = Array{Float64}(undef, nx) # temporary array during RK3 integration
    r = Array{Float64}(undef, nx)

    k = 1 # record index
    freq = Int64(nt/ns)

    for i = 1:nx
        x[i] = -0.5*dx + dx*(i)
        un[i] = sin(2.0*pi*x[i])
        u[i,k] = un[i] # store solution at t=0
    end

	# TVD RK3 for time integration
    for n = 1:nt # time step

        rhs(nx,dx,un,r)

        for i = 1:nx
            ut[i] = un[i] + dt*r[i]
        end

        rhs(nx,dx,ut,r)

        for i = 1:nx
            ut[i] = 0.75*un[i] + 0.25*ut[i] + 0.25*dt*r[i]
        end

        rhs(nx,dx,ut,r)

        for i = 1:nx
            un[i] = (1.0/3.0)*un[i] + (2.0/3.0)*ut[i] + (2.0/3.0)*dt*r[i]
        end

        if (mod(n,freq) == 0)
            k = k+1
			println(n)
			for i = 1:nx
            	u[i,k] = un[i]
			end
        end
    end
end

#-----------------------------------------------------------------------------#
# Calculate right hand side terms of the Euler equations
#-----------------------------------------------------------------------------#
function rhs(nx,dx,u,r)
	# flux computed at nodal points and positive and negative splitting
	f = Array{Float64}(undef,nx)
    fP = Array{Float64}(undef,nx)
    fN = Array{Float64}(undef,nx)

	# wave speed at nodal points
	ps = Array{Float64}(undef,nx)

	# left and right side fluxes at the interface
	fL = Array{Float64}(undef,nx+1)
    fR = Array{Float64}(undef,nx+1)

	for i = 1:nx
		f[i] = 0.5*u[i]*u[i]
	end

	wavespeed(nx,u,ps)

	for i = 1:nx
		fP[i] = 0.5*(f[i] + ps[i]*u[i])
		fN[i] = 0.5*(f[i] - ps[i]*u[i])
	end

	# WENO Reconstruction
	# compute upwind reconstruction for positive flux (left to right)
	fL = wenoL(nx,fP)
	# compute downwind reconstruction for negative flux (right to left)
    fR = wenoR(nx,fN)

	# compute RHS using flux splitting
	for i = 1:nx
		r[i] = -(fL[i+1] - fL[i])/dx - (fR[i+1] - fR[i])/dx
	end
end

#-----------------------------------------------------------------------------#
# Compute wave speed (Jacobian = df/du)
#-----------------------------------------------------------------------------#
function wavespeed(n,u,ps)
	for i = 3:n-2
		ps[i] = max(abs(u[i-2]), abs(u[i-1]), abs(u[i]), abs(u[i+1]), abs(u[i+2]))
	end
	# periodicity
	i = 1
	ps[i] = max(abs(u[n-1]), abs(u[n]), abs(u[i]), abs(u[i+1]), abs(u[i+2]))
	i = 2
	ps[i] = max(abs(u[n]), abs(u[i-1]), abs(u[i]), abs(u[i+1]), abs(u[i+2]))
	i = n-1
	ps[i] = max(abs(u[i-2]), abs(u[i-1]), abs(u[i]), abs(u[i+1]), abs(u[1]))
	i = n
	ps[i] = max(abs(u[i-2]), abs(u[i-1]), abs(u[i]), abs(u[1]), abs(u[2]))
end

#-----------------------------------------------------------------------------#
# WENO reconstruction for upwind direction (positive; left to right)
# u(i): solution values at finite difference grid nodes i = 1,...,N
# f(j): reconstructed values at nodes j = i-1/2; j = 1,...,N+1
#-----------------------------------------------------------------------------#
function wenoL(n,u)
	f = Array{Float64}(undef,n+1)

    i = 0
    v1 = u[n-2]
    v2 = u[n-1]
    v3 = u[n]
    v4 = u[i+1]
    v5 = u[i+2]
    f[i+1] = wcL(v1,v2,v3,v4,v5)

	i = 1
    v1 = u[n-1]
    v2 = u[n]
    v3 = u[i]
    v4 = u[i+1]
    v5 = u[i+2]
    f[i+1] = wcL(v1,v2,v3,v4,v5)

    i = 2
    v1 = u[n]
    v2 = u[i-1]
    v3 = u[i]
    v4 = u[i+1]
    v5 = u[i+2]
    f[i+1] = wcL(v1,v2,v3,v4,v5)

    for i = 3:n-2
        v1 = u[i-2]
        v2 = u[i-1]
        v3 = u[i]
        v4 = u[i+1]
        v5 = u[i+2]
        f[i+1] = wcL(v1,v2,v3,v4,v5)
    end

    i = n-1
    v1 = u[i-2]
    v2 = u[i-1]
    v3 = u[i]
    v4 = u[i+1]
    v5 = u[1]
    f[i+1] = wcL(v1,v2,v3,v4,v5)

    i = n
    v1 = u[i-2]
    v2 = u[i-1]
    v3 = u[i]
    v4 = u[1]
    v5 = u[2]
    f[i+1] = wcL(v1,v2,v3,v4,v5)

	return f
end

#-----------------------------------------------------------------------------#
# WENO reconstruction for downwind direction (negative; right to left)
# u(i): solution values at finite difference grid nodes i = 1,...,N+1
# f(j): reconstructed values at nodes j = i-1/2; j = 2,...,N+1
#-----------------------------------------------------------------------------#
function wenoR(n,u)
	f = Array{Float64}(undef,n+1)

    i = 1
    v1 = u[n-1]
    v2 = u[n]
    v3 = u[i]
    v4 = u[i+1]
    v5 = u[i+2]
    f[i] = wcR(v1,v2,v3,v4,v5)

    i = 2
    v1 = u[n]
    v2 = u[i-1]
    v3 = u[i]
    v4 = u[i+1]
    v5 = u[i+2]
    f[i] = wcR(v1,v2,v3,v4,v5)

    for i = 3:n-2
        v1 = u[i-2]
        v2 = u[i-1]
        v3 = u[i]
        v4 = u[i+1]
        v5 = u[i+2]
        f[i] = wcR(v1,v2,v3,v4,v5)
    end

    i = n-1
    v1 = u[i-2]
    v2 = u[i-1]
    v3 = u[i]
    v4 = u[i+1]
    v5 = u[1]
    f[i] = wcR(v1,v2,v3,v4,v5)

    i = n
    v1 = u[i-2]
    v2 = u[i-1]
    v3 = u[i]
    v4 = u[1]
    v5 = u[2]
    f[i] = wcR(v1,v2,v3,v4,v5)

    i = n+1
    v1 = u[i-2]
    v2 = u[i-1]
    v3 = u[1]
    v4 = u[2]
    v5 = u[3]
    f[i] = wcR(v1,v2,v3,v4,v5)

	return f

end

#---------------------------------------------------------------------------#
#nonlinear weights for upwind direction
#---------------------------------------------------------------------------#
function wcL(v1,v2,v3,v4,v5)
    eps = 1.0e-6

    # smoothness indicators
    s1 = (13.0/12.0)*(v1-2.0*v2+v3)^2 + 0.25*(v1-4.0*v2+3.0*v3)^2
    s2 = (13.0/12.0)*(v2-2.0*v3+v4)^2 + 0.25*(v2-v4)^2
    s3 = (13.0/12.0)*(v3-2.0*v4+v5)^2 + 0.25*(3.0*v3-4.0*v4+v5)^2

    # computing nonlinear weights w1,w2,w3
    c1 = 1.0e-1/((eps+s1)^2)
    c2 = 6.0e-1/((eps+s2)^2)
    c3 = 3.0e-1/((eps+s3)^2)

    w1 = c1/(c1+c2+c3)
    w2 = c2/(c1+c2+c3)
    w3 = c3/(c1+c2+c3)

    # candiate stencils
    q1 = v1/3.0 - 7.0/6.0*v2 + 11.0/6.0*v3
    q2 =-v2/6.0 + 5.0/6.0*v3 + v4/3.0
    q3 = v3/3.0 + 5.0/6.0*v4 - v5/6.0

    # reconstructed value at interface
    f = (w1*q1 + w2*q2 + w3*q3)

    return f

end

#---------------------------------------------------------------------------#
#nonlinear weights for downwind direction
#---------------------------------------------------------------------------#
function wcR(v1,v2,v3,v4,v5)
    eps = 1.0e-6

    s1 = (13.0/12.0)*(v1-2.0*v2+v3)^2 + 0.25*(v1-4.0*v2+3.0*v3)^2
    s2 = (13.0/12.0)*(v2-2.0*v3+v4)^2 + 0.25*(v2-v4)^2
    s3 = (13.0/12.0)*(v3-2.0*v4+v5)^2 + 0.25*(3.0*v3-4.0*v4+v5)^2

    c1 = 3.0e-1/(eps+s1)^2
    c2 = 6.0e-1/(eps+s2)^2
    c3 = 1.0e-1/(eps+s3)^2

    w1 = c1/(c1+c2+c3)
    w2 = c2/(c1+c2+c3)
    w3 = c3/(c1+c2+c3)

    # candiate stencils
    q1 =-v1/6.0      + 5.0/6.0*v2 + v3/3.0
    q2 = v2/3.0      + 5.0/6.0*v3 - v4/6.0
    q3 = 11.0/6.0*v3 - 7.0/6.0*v4 + v5/3.0

    # reconstructed value at interface
    f = (w1*q1 + w2*q2 + w3*q3)
end

#---------------------------------------------------------------------------#
# main program
#---------------------------------------------------------------------------#
nx = 150
ns = 10
dt = 0.0001
tm = 0.25

dx = 1.0/nx
nt = Int64(tm/dt)
ds = tm/ns

u = Array{Float64}(undef, nx,ns+1)

numerical(nx,ns,nt,dx,dt,u)

x = Array(0.5*dx:dx:1.0-0.5*dx)

solution = open("solution_p.txt", "w")

for i = 1:nx
    write(solution, string(x[i]), " ",)
	for n = 1:ns+1
        write(solution, string(u[i,n]), " ")
    end
    write(solution, "\n",)

end
close(solution)
