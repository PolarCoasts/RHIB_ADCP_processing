function adcp=ClipAirTime(adcp,opt)

arguments
    adcp
    opt.binthresh (1,1) double=3        % number of bins in a profile that can be above thresholds and still get clipped
    opt.cthresh (1,1) double=20         % correlation threshold
    opt.ethresh (1,1) double=50         % echo intensity threshold
end

% This function removes the beginning/ending portion of a record collected while the adcp was in the air
% To do this, it assumes that bins below the specified number will have very low correlation and echo intensity

nb=adcp.config.n_beams;

% find first and last times where each beam looks like it has good data
for i=1:nb
    corr=squeeze(adcp.corr(:,i,:));
    echo=squeeze(adcp.echo_intens(:,i,:));
    okcorr=corr>opt.cthresh; sumcorr=sum(okcorr);
    okecho=echo>=opt.ethresh; sumecho=sum(okecho);
    start(i,:)=[find(sumcorr>opt.binthresh,1,'first') find(sumecho>opt.binthresh,1,'first')];
    fin(i,:)=[find(sumcorr>opt.binthresh,1,'last') find(sumecho>opt.binthresh,1,'last')];
end

% set the start and final times to earliest and latest good data, respectively
startI=min(start,[],'all');
finI=max(fin,[],'all');

% trim record
len=length(adcp.time);
fn=fieldnames(adcp);
for i=1:length(fn)
    sz=size(adcp.(fn{i}));
    if ~isempty(find(sz==len, 1))
        if find(sz==len)==1
            adcp.(fn{i})=adcp.(fn{i})(startI:finI,:,:);
        elseif find(sz==len)==2
            adcp.(fn{i})=adcp.(fn{i})(:,startI:finI,:);
        elseif find(sz==len)==3
            adcp.(fn{i})=adcp.(fn{i})(:,:,startI:finI);
        end
    end
end



