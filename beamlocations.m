function adcp=beamlocations(adcp)

% this function calculates the 3D location for each adcp beam depth bin
% accounts for rhib heading and tilt

nc=adcp.config.n_cells;
nb=adcp.config.n_beams;
nt=length(adcp.time);

%% Get locations in relative instrument coordinates (offset from adcp position)
depth=-adcp.cell_depth;
offset=abs(depth)*tand(adcp.config.beam_angle); %horizontal offset for each depth
xyzoff=[offset offset depth]'; % potential offset in each direction at each depth

%   b1      b2      b3      b4      (direction of offsets for each beam)
dr=[-1      1       0       0;       % x (instrument coords)
     0      0       1      -1;       % y
     1      1       1       1];      % z
if nb==5
    dr(:,5)=[0 0 1]'; % b5
end
Iloc=permute(repmat(xyzoff,1,1,nb),[2 3 1]).*permute(repmat(dr,1,1,40),[3 2 1]);
Iloc=permute(repmat(Iloc,1,1,1,nt),[1 2 4 3]); %packed as depth x beam x time x direction

%% Convert to relative location in Earth coordinates 
angles=[adcp.roll' adcp.pitch' -adcp.instrument_heading'];
I2Equat=quaternion(angles,'eulerd','YXZ','point');
Eloc=rotatepoint(repelem(I2Equat,nc*nb),reshape(Iloc,nc*nb*nt,3));
Eloc=reshape(Eloc,nc,nb,nt,3);

%% Add relative location to rhib location
rhibloc=[adcp.vessel_X',adcp.vessel_Y',zeros(nt,1)];
rhibloc=permute(repmat(rhibloc,1,1,nc,nb),[3 4 1 2]);
adcp.beam_loc_XYZ=Eloc+rhibloc;

%% Convert XY locations to lat/lon
zonechar=utmzone(adcp.vessel_lat,adcp.vessel_lon);
zone=sscanf(zonechar,'%d');
m_proj('UTM','ellipsoid','wgs84','zone',zone)
[adcp.beam_loc_lat,adcp.beam_loc_lon]=m_xy2ll(adcp.beam_loc_XYZ(:,:,:,1),adcp.beam_loc_XYZ(:,:,:,2));


