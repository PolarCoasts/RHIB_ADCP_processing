function adcp=ProcADCP(data,yaw_offset,vessel_vel_method,beam5_weight)
% This function manages the processing of ADCP data, including transformation to earth coordinates and removal of RHIB velocity
% It is called by RHIBproc, but can also be used independently
% usage:
%   adcp = ProcADCP(data,yaw_offset,vessel_vel_method,beam5_weight)


adcp=data.adcp;
gps=data.gps;

if isfield(adcp,'nuc_time')
    adcp=nucRepair(adcp);
    time=adcp.nuc_time;
else
    time=adcp.time;
end

% duplicate raw beam velocities to retain them after vel field gets overwritten
adcp.bvel=adcp.vel;

%% Get vessel motion from GPS
% velocity
vessel_vel0=compute_vessel_vel(data,vessel_vel_method);
flds={'lon','lat','vel'};
for i=1:length(flds)
    adcp.(['vessel_' flds{i}])=interp1(vessel_vel0.time,vessel_vel0.(flds{i}),time);
end
% convert lat,lon to UTM
zonechar=utmzone(adcp.vessel_lat,adcp.vessel_lon);
zone=sscanf(zonechar,'%d');
m_proj('UTM','ellipsoid','wgs84','zone',zone)
[adcp.vessel_X,adcp.vessel_Y]=m_ll2xy(adcp.vessel_lon,adcp.vessel_lat,'clip','off');

% heading
h=gps_line_interp(gps,'GPRMC','HEHDT','head','angular');
[~,iu]=unique(gps.GPRMC.dn);
adcp.vessel_heading=mod(180/pi*angle(interp1(gps.GPRMC.dn(iu),cosd(h(iu))+1i*sind(h(iu)),time)),360);
adcp.instrument_heading=adcp.vessel_heading+yaw_offset;
adcp.config.yaw_offset=yaw_offset;

%% Transform velocities into Earth coordinates and subtract vessel velocity
angles=[-adcp.roll', -adcp.pitch', adcp.instrument_heading'];
orientation=quaternion(angles,'eulerd','YXZ','frame');
adcp=adcp_beam2earth(adcp,orientation,b5w=beam5_weight);

adcp.vel(:,1,:)=squeeze(adcp.vel(:,1,:))+adcp.vessel_vel(:,1)';
adcp.vel(:,2,:)=squeeze(adcp.vel(:,2,:))+adcp.vessel_vel(:,2)';
%% Add some notes about velocities
adcp.vel_notes(1)={"Columns of vel are u,v,w, and error velocity"};
if adcp.config.n_beams==5
    adcp.vel_notes(2)={"Transformation of velocities is calculated with vertical velocity weighted "+beam5_weight*100+"% towards beam 5"};
end
adcp.vel_notes(3)={"Raw beam velocities are stored under bvel"};

