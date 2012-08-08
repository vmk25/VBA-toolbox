function demo_RockScissorsPaper

% demo for evolutionary selection of rock-scissors-paper game

% cf. 'Evolution and the theory of Games', Maynard-Smith, 1982.

c = -0.1; % cost of draw

% Parameters of the simulation
n_t = 4e3;
dt = 1e-1;
f_fname = @log_replicator;
g_fname = @g_odds;
alpha   = Inf;
sigma   = Inf;
theta   = [c];
phi     = [];
u = [];


in.f_fitness = @fitness_rsp;
in.dt = dt;
options.inF         = in;
options.inG         = in;
dim.n_theta         = length(theta);
dim.n_phi           = 0;
dim.n               = 3;
dim.p               = 3;
dim.n_t             = n_t;
options.dim = dim;


% Build time series of hidden states and observations
[eq,X,out,ha,ha2] = findEquilibria(n_t,f_fname,g_fname,theta,phi,u,alpha,sigma,options,dim);
legend(ha2,{'rock frequency','scissors frequency','paper frequency'})
hf = figure('color',[1 1 1],'name','rock-paper-scissors');
ha = subplot(2,2,1,'parent',hf,'nextplot','add');
x0 = zeros(dim.n,1);
[y,x,x0,eta,e] = simulateNLSS(n_t,f_fname,g_fname,theta,phi,u,alpha,sigma,options,x0);
plot(ha,y','linewidth',2)
xlabel(ha,'time')
ylabel(ha,'frequency')
legend(ha,{'rock frequency','scissors frequency','paper frequency'})
title(ha,'phenotypes'' evolutionary dynamics')
ha = subplot(2,2,2,'parent',hf);
plot(ha,x')
xlabel(ha,'time')
ylabel(ha,'log-odds')
title(ha,'deterministic log-odds dynamics')

% evaluate stability of steady state
J = numericDiff(@f_replicator,1,y(:,end),theta,[],in);
ev = eig((J-eye(dim.n))./dt);
ha = subplot(2,2,3,'parent',hf,'nextplot','add');
rectangle('Position',[-1,-1,2,2],'curvature',[1 1],'parent',ha)
for i=1:length(ev)
    plot(ha,real(ev(i)),imag(ev(i)),'r+')
end
axis(ha,'equal')
grid(ha,'on')
xlabel(ha,'eigenvalues real axis')
ylabel(ha,'eigenvalues imaginary axis')
title(ha,'ESS: stability analysis')




getSubplots
