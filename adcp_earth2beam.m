function adcp=adcp_earth2beam(adcp)

% transform vessel velocity from earth coordinates to beam coordinates
% this function is used to remove vessel velocity from beam velocities
% aids user in identifying features in the water column that are smaller than ADCP beam spread

%% Constants
nb = adcp.config.n_beams;
nc = adcp.config.n_cells;
nt = length(adcp.nuc_time);

%% Transform vessel velocity to instrument coordinates

E2Iquat=conj(adcp.I2Equat);
vessel_Ivel=rotateframe(E2Iquat,adcp.vessel_vel);

%% Transform rhib velocity to beam coordinates 
cb=cosd(adcp.config.beam_angle);
sb=sind(adcp.config.beam_angle);

%    X      Y       Z
I2B=[sb     0       cb;  % b1
    -sb     0       cb;  % b2
    0       -sb     cb;  % b3
    0       sb      cb]; % b4
if nb==5
    I2B(5,:)=[0 0 1]; % b5
end

vessel_Bvel=I2B*vessel_Ivel';

%% Remove vessel velocity from beam velocities
adcp.vessel_vel_bcoords=permute(repmat(vessel_Bvel,1,1,nc),[3 1 2]);
adcp.bvel_water=adcp.bvel+adcp.vessel_vel_bcoords;
adcp.vel_notes=[adcp.vel_notes {"vessel_vel_bcoords is vessel velocity in beam coordinates (how vessel motion affects each beam)"} {"bvel_water is beam velocity with vessel velocity removed (water velocity in beam coordinates)"}];


