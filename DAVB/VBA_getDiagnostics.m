function [diagnostics,out] = VBA_getDiagnostics(posterior,out)
% this function derives diagnostics of the VBA model inversion

u = out.u;
y = out.y;

try; out.fit; catch; out.fit = VBA_fit(posterior,out); end

if out.dim.n_t>1 && out.dim.u >= 1 && ~isempty(out.options.f_fname)
    try
        [kernels] = VBA_VolterraKernels(posterior,out);
    catch
        kernels = [];
    end
else
    kernels = [];
end


% get null model (H0) evidence
[LLH0] = VBA_LMEH0(y,out.options);

% Entropies and KL divergences
if ~out.options.binomial
    efficiency.sigma = -out.suffStat.Ssigma;
    m0 = out.options.priors.a_sigma./out.options.priors.b_sigma;
    v0 = out.options.priors.a_sigma./out.options.priors.b_sigma^2;
    m = posterior.a_sigma(end)./posterior.b_sigma(end);
    v = posterior.a_sigma(end)./posterior.b_sigma(end)^2;
    DKL.sigma = VBA_KL(m0,v0,m,v,'Gamma');
else
    efficiency.sigma = NaN;
    DKL.sigma = NaN;
end

if out.dim.n > 0 % hidden states and initial conditions
    efficiency.X = -out.suffStat.SX;
    efficiency.X0 = -out.suffStat.SX0;
    if isinf(out.options.priors.a_alpha) ...
            && isequal(out.options.priors.b_alpha,0)
        efficiency.alpha = NaN;
        DKL.alpha = NaN;
    else
        efficiency.alpha = -out.suffStat.Salpha;
        m0 = out.options.priors.a_alpha./out.options.priors.b_alpha;
        v0 = out.options.priors.a_alpha./out.options.priors.b_alpha^2;
        m = posterior.a_alpha(end)./posterior.b_alpha(end);
        v = posterior.a_alpha(end)./posterior.b_alpha(end)^2;
        DKL.alpha = VBA_KL(m0,v0,m,v,'Gamma');
    end
    try
        DKL.X = 0;
        for t=1:out.dim.n_t
            IN = out.options.params2update.x{t};
            m0 = out.options.priors.muX(IN,t);
            v0 = out.options.priors.SigmaX.current{t}(IN,IN);
            m = posterior.muX(IN,t);
            v = posterior.SigmaX.current{t}(IN,IN);
            DKL.X = DKL.X + VBA_KL(m0,v0,m,v,'Normal');
        end
    catch
        DKL.X = NaN;
    end
    IN = out.options.params2update.x0;
    m0 = out.options.priors.muX0(IN);
    v0 = out.options.priors.SigmaX0(IN,IN);
    m = posterior.muX0(IN);
    v = posterior.SigmaX0(IN,IN);
    DKL.X0 = VBA_KL(m0,v0,m,v,'Normal');
else
    efficiency.X = NaN;
    efficiency.X0 = NaN;
    efficiency.alpha = NaN;
    DKL.X = NaN;
    DKL.X0 = NaN;
    DKL.alpha = NaN;
end
if out.dim.n_phi > 0 % observation parameters
    efficiency.Phi = -out.suffStat.Sphi;
    IN = out.options.params2update.phi;
    m0 = out.options.priors.muPhi(IN);
    v0 = out.options.priors.SigmaPhi(IN,IN);
    if ~out.options.OnLine
        m = posterior.muPhi(IN);
        v = posterior.SigmaPhi(IN,IN);
    else
        m = posterior.muPhi(IN,end);
        v = posterior.SigmaPhi{end}(IN,IN);
    end
    DKL.Phi = VBA_KL(m0,v0,m,v,'Normal');
else
    efficiency.Phi = NaN;
    DKL.Phi = NaN;
end
if out.dim.n_theta > 0 % evolution parameters
    efficiency.Theta = -out.suffStat.Stheta;
    IN = out.options.params2update.theta;
    m0 = out.options.priors.muTheta(IN);
    v0 = out.options.priors.SigmaTheta(IN,IN);
    if ~out.options.OnLine
        m = posterior.muTheta(IN);
        v = posterior.SigmaTheta(IN,IN);
    else
        m = posterior.muTheta(IN,end);
        v = posterior.SigmaTheta{end}(IN,IN);
    end
    DKL.Theta = VBA_KL(m0,v0,m,v,'Normal');
else
    efficiency.Theta = NaN;
    DKL.Theta = NaN;
end

% get prior predictive density
try
    [muy,Vy] = VBA_getLaplace(u,out.options.f_fname,out.options.g_fname,out.dim,out.options);
catch
    muy =[];
    Vy = [];
end

% get micro-time posterior hidden-states estimates
try
    [MT_x,MT_gx,microTime,sampleInd] = VBA_microTime(posterior,u,out);
catch
    MT_x = [];
    MT_gx = [];
    microTime = 1:out.dim.n_t;
    sampleInd = 1:out.dim.n_t;
end

% get residuals: data noise
dy.dy = out.suffStat.dy(:);
dy.R = spm_autocorr(out.suffStat.dy);
dy.m = mean(dy.dy);
dy.v = var(dy.dy);
[dy.ny,dy.nx] = hist(dy.dy,10);
dy.ny = dy.ny./sum(dy.ny);
d = diff(dy.nx);
d = abs(d(1));
dy.d = d;
spgy = sum(exp(-0.5.*(dy.m-dy.nx).^2./dy.v));
dy.grid = dy.nx(1):d*1e-2:dy.nx(end);
dy.pg = exp(-0.5.*(dy.m-dy.grid).^2./dy.v);
dy.pg = dy.pg./spgy;
if  ~out.options.binomial
    shat = posterior.a_sigma(end)./posterior.b_sigma(end);
    spgy = sum(exp(-0.5.*shat.*dy.nx.^2));
    dy.pg2 = exp(-0.5.*shat.*dy.grid.^2);
    dy.pg2 = dy.pg2./spgy;
end

% get residuals: state noise
dx.dx = out.suffStat.dx(:);
if ~isempty(dx.dx)
    dx.m = mean(dx.dx);
    dx.v = var(dx.dx);
    [dx.ny,dx.nx] = hist(dx.dx,10);
    dx.ny = dx.ny./sum(dx.ny);
    d = diff(dx.nx);
    d = abs(d(1));
    dx.d = d;
    spgy = sum(exp(-0.5.*(dx.m-dx.nx).^2./dx.v));
    dx.grid = dx.nx(1):d*1e-2:dx.nx(end);
    dx.pg = exp(-0.5.*(dx.m-dx.grid).^2./dx.v);
    dx.pg = dx.pg./spgy;
    ahat = posterior.a_alpha(end)./posterior.b_alpha(end);
    spgy = sum(exp(-0.5.*ahat.*dx.nx.^2));
    dx.pg2 = exp(-0.5.*ahat.*dx.grid.^2);
    dx.pg2 = dx.pg2./spgy;
end

% get parameters posterior correlation matrix
if out.dim.n > 0 && isinf(out.options.priors.a_alpha) && isequal(out.options.priors.b_alpha,0)
    S = out.suffStat.ODE_posterior.SigmaPhi;
else
    S = NaN*zeros(out.dim.n+out.dim.n_theta+out.dim.n_phi);
    ind = 0;
    if out.dim.n_phi > 0
        if iscell(posterior.SigmaPhi) % online version
            SP = posterior.SigmaPhi{end};
        else
            SP = posterior.SigmaPhi;
        end
        S(1:out.dim.n_phi,1:out.dim.n_phi) = SP;
        ind = out.dim.n_phi;
    end
    if out.dim.n_theta > 0
        if iscell(posterior.SigmaTheta) % online version
            SP = posterior.SigmaTheta{end};
        else
            SP = posterior.SigmaTheta;
        end
        S(ind+1:ind+out.dim.n_theta,ind+1:ind+out.dim.n_theta) = SP;
        ind = ind + out.dim.n_theta;
    end
    if out.dim.n > 0 && out.options.updateX0
        if iscell(posterior.SigmaX0) % online version
            SP = posterior.SigmaX0{end};
        else
            SP = posterior.SigmaX0;
        end
        S(ind+1:ind+out.dim.n,ind+1:ind+out.dim.n) = SP;
    end
end
C = cov2corr(S);
C = C + diag(NaN.*diag(C));
tick = [0];
ltick = [];
ticklabel = cell(0,0);
if out.dim.n_phi > 0
    ltick = [ltick,tick(end)+out.dim.n_phi/2];
    tick = [tick,out.dim.n_phi];
    ticklabel{end+1} = 'phi';
end
if out.dim.n_theta > 0
    ltick = [ltick,tick(end)+out.dim.n_theta/2];
    tick = [tick,tick(end)+out.dim.n_theta];
    ticklabel{end+1} = 'theta';
end
if out.dim.n > 0 && out.options.updateX0
    ltick = [ltick,tick(end)+out.dim.n/2];
    tick = [tick,tick(end)+out.dim.n];
    ticklabel{end+1} = 'x0';
end
tick = tick +0.5;
tick = tick(2:end-1);
ltick = ltick + 0.5;

% wrap up
diagnostics.pgx = reshape(muy,out.dim.p,[]);
diagnostics.pvy = reshape(diag(Vy),out.dim.p,[]);
diagnostics.kernels = kernels;
diagnostics.efficiency = efficiency;
diagnostics.DKL = DKL;
diagnostics.LLH0 = LLH0;
diagnostics.MT_x = MT_x;
diagnostics.MT_gx = MT_gx;
diagnostics.microTime = microTime;
diagnostics.sampleInd = sampleInd;
diagnostics.dy = dy;
diagnostics.dx = dx;
diagnostics.ltick = ltick;
diagnostics.tick = tick;
diagnostics.ticklabel = ticklabel;
diagnostics.C = C;
out.diagnostics = diagnostics;



