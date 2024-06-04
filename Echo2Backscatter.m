function adcp=Echo2Backscatter(adcp,options)

% This function converts echo intensity (counts) to backscatter (dB) accounting for beam spreading and water absorption
% see Deines (1999) and Mullison (2017)
%
% S = C + 10 log(TR^2) - 10 log(L/cosθ) + P + 2αR + 10 log(10^(Kc(E-Er)/10)-1)
%
%   C       instrument-specific constant
%   T       transducer temperature in Kelvin
%   R       along-beam distance to sample location
%   L       transmit pulse length
%   θ       beam angle
%   P       10 log(Px), where Px is transmit power
%   α       sound absorption coefficient for water
%   Kc      instrument-specific conversion factor
%   E       echo intensity
%   Er      instrument noise level
%
% This equation is only valid at distances where beam is fully formed (R>π*Dr/4), where 
%   Dr = transducer area/wavelength
%   R  = d/cosθ for center of depth cell, R = (d + D/4)/cosθ for last quarter of depth cell
%       d = vertical distance to center of depth cell
%       D = depth cell length
%
% Note: If absolute values of backscatter are not needed, Kc, Er, and α do not need to be precise


arguments
    adcp
    options.power (1,:) {mustBeMember(options.power,["internal","external"])}="external"
    options.Px (1,1) double=0
    options.alpha (1,1) double=.068
    options.Kc (1,1) double=.5
    options.Er (1,1) double=40
end

% set up table of estimated values
WH=[14 17.5 -140.87 -151.64 options.Kc options.Er .87 .068]';
SV=[14 16.2 -144.74 -151.24 .5 40 .86,.068]';
tab=table(WH,SV,'RowNames',["P_int","P_ext","C_bb","C_nb","Kc","Er","Dr","alpha"]);

% get some basic information about instrument and data
nb=adcp.config.n_beams;
nc=adcp.config.n_cells;
nt=length(adcp.nuc_time);
theta=adcp.config.beam_angle;
D=adcp.config.depth_cell_length;
L=adcp.config.xmit_pulse_length;
bw=adcp.config.sys_bandwidth;
f=adcp.config.frequency;
if nb==4 && f==300
    inst="WH"; % Workhorse
elseif nb==5 && f==300
    inst="SV"; % Sentinel V
end
if strcmp(inst,"WH")
    offset=D/4;
elseif strcmp(inst,"SV")
    offset=0;
end

% pull values from table
if options.Px==0
    if strcmp(options.power,"internal")
        P=tab{"P_int",inst};
    elseif strcmp(options.power,"external")
        P=tab{"P_int",inst};
    end
else
    P=10*log10(options.Px);
end
if bw==0
    C=tab{"C_bb",inst};
elseif bw==1
    C=tab{"C_nb",inst};
end
Kc=tab{"Kc",inst};
Er=tab{"Kc",inst};
Dr=tab{"Dr",inst};
Rmin=pi/4*Dr;

% pull data
E=adcp.echo_intens;
T=adcp.temperature+273.16;
d=adcp.cell_depth;

% calculate terms
beam_angles=repelem(theta,nb);
if nb==5
    beam_angles(5)=0;
end
beam_angles=repmat(beam_angles,nc,1,nt);
dd=repmat(d,1,nb,nt);
R=(dd+offset)./cosd(beam_angles);
T=permute(repmat(T,nc,1,nb),[1 3 2]);
spread=10*log10(T.*R.*R);
pulse=10*log10(L/cosd(beam_angles));
absorption=2*options.alpha*R;
conversion=10*log10(10.^(Kc*(E-Er)./10)-1);

S=C+spread-pulse+P+absorption+conversion;
S(R(:,1,1)<Rmin,:,:)=NaN;

adcp.backscatter=S;

end



