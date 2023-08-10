function adcp = adcp_beam2earth(adcp,q,opt)

arguments
    adcp struct                         % structure containing raw adcp data
    q quaternion                        % quaternion containing rotation info
    opt.b5w (1,1) double=1              % weighting of vertical velocity from beam 5
    opt.convex logical=true             % indicate if adcp is convex
    opt.up logical=false                % indicate if adcp is upward-facing
end

% Transforms ADCP velocities from beam to earth coordinates
% usage:
%   adcp = adcp_beam2earth(adcp,q,opt)
% 
% q is a quaternion containing the rotational info
% opt is a placeholder for additional optional arguments
%
% By default, the calculation for 5-beam ADCPs will impose the velocity observed by the vertical beam as the vertical velocity component observed by all beams
% This behavior can be modified by adjusting the beam 5 weighting factor to any value between 0 and 1 as below:
%   adcp = adcp_beam2earth(adcp,q,b5w=0)

%% Constants
nb = adcp.config.n_beams;
nc = adcp.config.n_cells;
nt = length(adcp.time);

%% Instrument coordinate transformation
K = opt.b5w;
K1 = (1-K); % weight for beams 1-4

% This depends on beam angle and beam configuration
cb = cosd(adcp.config.beam_angle);
sb = sind(adcp.config.beam_angle);
if isfield(adcp.config,'beam2inst')
    % Sometimes we can get this directly from parsed ADCP data
    B2I = [adcp.config.beam2inst, zeros(4,adcp.config.n_beams-4)];
else
    c = 2*[~(opt.convex==opt.up), opt.up | ~opt.convex, ~opt.convex, opt.up | opt.convex] - 1;
    a = 1/(2*sb)*c;
    [a1,a2,a3,a4] = deal(a(1),a(2),a(3),a(4));
    b = 1/(4*cb);
    if nb==5
        %      v1       v2    v3    v4    v5
        B2I = [a1       a2    0     0     0 ; % X
               0        0     a3    a4    0 ; % Y
               K1*b  K1*b     K1*b  K1*b  K ; % Z
               b        b    -b     -b    0]; % E
    elseif nb==4
        B2I = [a1 a2  0   0;
               0  0   a3  a4;
               b  b   b   b
               b  b  -b  -b];
    end
    % Flip towards-transducer velocity for up-facing ADCPs
    if opt.up
        B2I(3,:) = -B2I(3,:);
    end
end
% Reshape velocity matrix and transform to instrument coordinates
vb = reshape(permute(adcp.vel,[3 1 2]),nc*nt,nb);
vi = (B2I * vb')';

%% Instrument-to-earth transformation
% Create orientation quaternions for reshaped velocity matrix
q_rep = repmat(q(:),nc,1);

% Apply quaternion trasformations to instrument-coordinate data to get
% earth-coordinate data. Preserve 4th dimension (error velocity).
ve = vi;
ve(:,1:3) = rotateframe(q_rep,vi(:,1:3));

% Reshape velocity matrix to original size and store in output structure.
adcp.vel = permute(reshape(ve',4,nt,nc), [3 1 2]);
