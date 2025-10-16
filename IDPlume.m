function plume=IDPlume(adcp,qcmask,di,thresh)

arguments
    adcp                                                            % structure containing raw beam velocities
    qcmask                                                          % matrix containing QC mask to be applied
    di (1,:) =8:40                                                  % indices of depths in which to search for plume
    thresh.minv (1,1) {mustBeGreaterThan(thresh.minv,0)}=.3         % minimum beam velocity to include
    thresh.peakv (1,1) {mustBeGreaterThan(thresh.peakv,0)}=.8       % peak beam velocity that plume region must include
    thresh.gap (1,1) double=0                                       % space between IDs to merge across (single value to represent # of time steps and # of depth bins)
end

% get time step and bin size for merging IDs
dt=1/mode(diff(adcp.time));
dd=1/adcp.config.depth_cell_length;

% extract data and apply mask
depth=adcp.cell_depth;
time=adcp.nuc_time;
nb=adcp.config.n_beams;
bvel=adcp.bvel_water.*qcmask;

% replace NaNs with a numeric value so that contours aren't interupted 
bvel999=bvel; 
bvel999(isnan(bvel))=-999;

% identify plume
plumemask=[];
top=depth(di(1));
excltop=polyshape([time(1) time(1) time(end) time(end)],[depth(1) top top depth(1)]);
bot=depth(di(end))+adcp.config.depth_cell_length;
exclbot=polyshape([time(1) time(1) time(end) time(end)],[depth(end) bot bot depth(end)]);

for j=1:nb
    fprintf("Working on ID for beam "+j+"...\n")
    [plumemask,plumepoly]=ContourMask(time,depth,squeeze(bvel999(:,j,:)),thresh.minv,thresh.peakv,thresh.gap,dt,dd);
    plume.mask(:,j,:)=NaN(size(plumemask));
    plume.mask(di,j,:)=plumemask(di,:,:);
    for p=1:length(plumepoly)
        plumepolyx(p)=subtract(plumepoly(p),excltop);
        plumepolyx(p)=subtract(plumepolyx(p),exclbot);
    end
    plume.polyshapes(j)={plumepolyx};
    clear plumepolyx
end
fprintf("Plume ID complete \n\n")
plume.thresholds=thresh;




