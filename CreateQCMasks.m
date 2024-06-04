function maskinfo=CreateQCMasks(data,criteria)

arguments
    data struct                             % structure containing adcp data
    criteria.xbeam (1,1) logical=0          % mask for cross-beam contamination (true or false)
    criteria.ext_bottom (1,1) double=10     % percentage of water column to mask above bottom
    criteria.corr (1,1) double=64           % correlation threshold
    criteria.turn (1,1) double=0            % turn rate threshold
    criteria.corr_echo (1,2) double=[0 0]   % thresholds for correlation and echo intensity to be used together, packed as [corr echo]
    criteria.corr_back (1,2) double=[0 0]   % thresholds for correlation and backscatter to be used together, packed as [corr back]
end

si=size(data.bvel);
nb=data.config.n_beams;
depth=data.cell_depth;
time=data.nuc_time;
dgrid=repmat(depth,[1 length(time)]);

%cross-beam contamination mask
if criteria.xbeam==1
    xb=ones(si(1),si(3));
    for i=1:nb
        bc=data.bottom_depth(i,:);
        bi=dgrid>=bc-4 & dgrid<=bc+4; % bottom contour plus one cell either side
        xb(bi)=NaN; % adds more NaNs for each beam
    end
    xb_mask=permute(repmat(xb,1,1,nb),[1 3 2]);
else
    xb_mask=ones(si);
end

% extend bottom mask
if criteria.ext_bottom>0
    bt_mask=data.bottom_mask;
    for i=1:nb
        bmask=squeeze(bt_mask(:,i,:));
        for j=1:length(time)
            di=find(isnan(bmask(:,j)),1,'first');
            if ~isempty(di)
                bt_mask(di-round(di/criteria.ext_bottom):end,i,j)=NaN;
            end
        end
    end
else
    bt_mask=data.bottom_mask;
end

% low correlation mask
if criteria.corr>0
    corr=data.corr;
    corr_mask=ones(si);
    corr_mask(corr<criteria.corr)=NaN;
else
    corr_mask=ones(si);
end

% high turn rate mask
if criteria.turn>0
    turn_mask=nan(si);
    turn_mask(:,:,data.turn_rate<criteria.turn)=1;
else
    turn_mask=ones(si);
end

% mask for combined correlation and echo intensity thresholds
corec_mask=ones(si);
if sum(criteria.corr_echo)>0
    corr=data.corr;
    echo=data.echo_intens;
    corec_mask(corr<criteria.corr_echo(1) & echo<criteria.corr_echo(2))=NaN;
end

% mask for combined correlation and backscatter thresholds
corbac_mask=ones(si);
if sum(criteria.corr_back)>0
    corr=data.corr;
    back=data.backscatter;
    corbac_mask(corr<criteria.corr_back(1) & back<criteria.corr_back(2))=NaN;
end

%combine masks
maskinfo.combo_mask=xb_mask.*bt_mask.*corr_mask.*turn_mask.*corec_mask.*corbac_mask;
maskinfo.xb_mask=xb_mask;
maskinfo.exbot_mask=bt_mask;
maskinfo.corr_mask=corr_mask;
maskinfo.turnrate_mask=turn_mask;
maskinfo.corr_echo_mask=corec_mask;
maskinfo.corr_back_mask=corbac_mask;
maskinfo.criteria=criteria;














