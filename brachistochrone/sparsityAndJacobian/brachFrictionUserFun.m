%{
    The UserFun for the Brach Problem. This function is called by SNOPT to
    converge to an optimal solution.  In this function
        1) We pack the nonlinear constraints into F.
        2) We calculate the Jacobian of the constraints with respect to the
           decision variables (variable G).
    In this function, we discritize the dynamics of the Brach problem which were
    set as equality constraints (using Flow and Fupp in the script that calls
    this userFun).

    We discritize with respect to Euler's Method: For all i=0,...,N-1, we have
                      \dot x_{i} = (x_{i+1} - x_i)/dt
    where dt = t_{i+1}-ti == (tf-t0)/N 

    Inputs:
        decVars: Column vector whose order is determined on how xInit was
                 packed

    Outputs:
        F: The column vector containing the nonlinear constraints
        G: The Jacobian of the constraints with respect to the decision
           variables; G is a column vector
%}
function [ F, G ] = brachFrictionUserFun( decVars )

    global t0 kFr N D index4G;
    
    %Unpack 'x' into meangful variables; memory and speed are not an issue here.
    %Hence use as many temporary variable as you want.  For performance, only
    %work with the passed-in decVars column vector.
    x = decVars(1:N+1);
    y = decVars(N+2: 2*N+2);
    v = decVars(2*N+3:3*N+3);
    theta = decVars(3*N+4: 4*N+3);
    
    %This is the objective function (final transfer time)
    tf = decVars(4*N+4);
    
    dt = (tf-t0)/N; %i.e 'h' the time step of uniform length
    
    %Here we discritize the dynamics of the Brach Problem wrt Euler's Method.
    %Note that dt is multiplied away from Euler's Differentation matrix D
    %because doing so creates a linearity in the Jacobian
    dynamicsX = D*x - dt*v(1:end-1).*sin(theta(1:end));         %colVec N by 1
    dynamicsY = D*y - dt*v(1:end-1).*cos(theta(1:end));         %colVec N by 1
    E = D; E(1:N+1:(N+1)*N)=-1 + kFr*dt;
    dynamicsV = E*v - dt*cos(theta(1:end)); %colVec N by 1
    
    %The way F is packed here determines the order of Fupp Flow and the order of
    %the Jacobian of the constraints wrt the decision variables.  F stores the
    %objective function as well as the constraints.  Note, if you set A iAfun
    %jAvar (the linear parts of the Jacobian) then do not pack those variables
    %in F--this is just a heads up; see the code example where we identify the
    %linear and nonlinear portions (and calculate the Jacobian).
    F = [ tf;
          dynamicsX;
          dynamicsY;
          dynamicsV;
          x(1);
          y(1);
          v(1);
          x(end);
          y(end) ];
     
     %The Jacobian of the constraints with respect to the decision variables
     %(henceforth always refered to as, 'The Jacobian'). In the script that
     %calls snopt with this userFun, we supplied the sparsity pattern of the
     %Jacobian. Keeping G=[], then Snopt calculates only the jacobian elements
     %specified by the sparsity.  Below we explicityly calculate the nonzero
     %elements of the Jacobian.
     % G=[];
     
     %Since G must be a column vector, to handle the annoying indexing issues,
     %we build a full-version of G (denoted fullG) and then pull the values we
     %need out of it by using index4G.  Note: this is not a good method to use
     %for large applications as the line 'G = fullG(index4G);' was the reason
     %one of my research topics was crashing because of memory issues; for that
     %project, there were 40,000 or more constraints.
     
     %Note: the names of the matricies match identically to the paper; do this
     %with your research, as it will make your code and paper much more readible

     alpha = horzcat( -dt*bsxfun(@times, sin(theta(1:end)), eye(N)), ...
                      zeros(N,1));
     delta = horzcat( -dt*bsxfun(@times, cos(theta(1:end)), eye(N)), ...
                      zeros(N,1));
     %For setting pi, notice if there is no friction (i.e.: kFr==0) then pi
     %degenerates into D, which is linear; if kFr~=0 then pi is nonlinear
     %because of the presence of dt (which contains tf).  This is exploited in
     %the final version of the Brach problem where we seperate the linear from
     %the nonlinear sections of the Jacobian.
     pi = E;
                  
     beta = -dt*bsxfun(@times,v(1:end-1).*cos(theta(1:end)),eye(N));
     
     epsilon = dt*bsxfun(@times, v(1:end-1).*sin(theta(1:end)), eye(N));
     mu = dt*bsxfun(@times, sin(theta(1:end)), eye(N));
     
     gamma = (-1/N)*v(1:end-1).*sin(theta(1:end));
     kappa = (-1/N)*v(1:end-1).*cos(theta(1:end));
     psi =   (-1/N)*(cos(theta(1:end)) - kFr*v(1:end-1));
     
     initCon = horzcat( 1, zeros(1,N));
     endCon = horzcat( zeros(1,N), 1);     
    
     %{
        By how we packed the decision variables (in xInit when the cmex calls
        Snopt), and how we packed the constraints (in F), the Jacobian is
        ordered as follows (which matches the paper):
                       x      y      v           theta         tf
               -------------------------------------------------------
                tf     0      0      0             0            1   
               dynX    D      0     alpha         beta        gamma
               dynY    0      D     delta        epsilon      kappa
               dynV    0      0     pi             mu         psi
               initX   *      0      0             0           0  
               initY   0      *      0             0           0 
               initV   0      0      *             0           0
               endX    *      0      0             0           0
               endY    0      *      0             0           0
     %}
     
     fullG =  ...
        [ zeros(1, N+1) zeros(1, N+1) zeros(1, N+1) zeros(1, N)    1;     ...
               D        zeros(N, N+1)    alpha        beta       gamma;     ...
         zeros(N, N+1)     D             delta       epsilon     kappa;     ...
         zeros(N, N+1)  zeros(N, N+1)     pi         mu           psi;     ...
             initCon    zeros(1, N+1) zeros(1, N+1) zeros(1, N)    0;     ...
         zeros(1, N+1)    initCon     zeros(1, N+1) zeros(1, N)    0;     ...
         zeros(1, N+1)  zeros(1, N+1)    initCon    zeros(1, N)    0;     ...
             endCon     zeros(1, N+1) zeros(1, N+1) zeros(1, N)    0;     ...
         zeros(1, N+1)     endCon     zeros(1, N+1) zeros(1, N)    0    ];

     %Now iGfun and jGvar tell SNOPT which elements of G need to be computed,
     %and by Snopt G must be packed as a column vector that contains the
     %values at (iGfun,jGvar).  To avoid a nasty indexing issue, index4G is the
     %logicall addressing of the sparsity of the Jacobian, and hence can be used
     %to pull all of the values out of fullG in the correct order of the
     %supplied sparsity as well as into a colunm vector.
     %----tl;DR: make fullG a column matrix with only the nonzero entries, in
     %the order specified by the sparsity pattern set in the main script file
     G = fullG(index4G);

end

