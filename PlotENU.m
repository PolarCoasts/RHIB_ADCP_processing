function [fig,ax]=PlotENU(adcp,vlim)

arguments
    adcp struct
    vlim (1,2) double=[-1 1]        % colorbar limits
end

% This function plots the processed velocities for the given data
% 
% usage:
%   [fig,ax] = PlotENU(adcp,vlim)
%
% vlim is the colorbar limits, default is [-1 1]


if isfield(adcp,'nuc_time')
    time=adcp.nuc_time;
else
    time=adcp.time;
end

labels=["u","v","w","error"];

xx=.06; yy=linspace(.08,.98,5);
ww=.88; hh=.195;

fig=figure('Position',[10 10 1800 800]);
for i=1:4
    ax(i)=axes('Position',[xx yy(5-i) ww hh]);
    pcolorjw(time,adcp.cell_depth,squeeze(adcp.vel(:,i,:)))
    axis ij
    colormap(cmocean('balance'))
    clim(vlim)
    text(time(10),25,labels(i),"FontSize",16,"BackgroundColor",'w')
    if i<4
        xticklabels([])
        if i==1
            title(string(datetime(time(1),'ConvertFrom','datenum')))
        end
    else
        cbar=colorbar('Position',[.95 .4 .008 .2],'FontSize',16);
        cbar.Label.String="Velocity (m/s)";
        xlabel('Time')
        datetick('x','keeplimits')
        yl=ylabel('Depth');
    end
    set(gca,'FontSize',16)
end
yl.Position(2)=-max(adcp.cell_depth,[],'omitnan')*1.3;
linkaxes


