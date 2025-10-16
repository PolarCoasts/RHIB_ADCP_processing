function adcp=Interactive_IDPlume(adcp,fb,rb,n)
% ** n is monitor number to display figure on **

nb=adcp.config.n_beams;
time=adcp.nuc_time;
depth=adcp.cell_depth;
dt=1/mode(diff(adcp.time));
dd=1/adcp.config.depth_cell_length;

c1=.01;
r=linspace(.99,.05,nb+1); r=r(2:end);
w1=.8; h1=.9*abs(diff(r(1:2))); 

mp=get(0,'MonitorPositions');

fig=uifigure('Position',mp(n,:),'HandleVisibility','on');

% plot data
bslim=[floor(min(adcp.backscatter,[],'all','omitnan')) ceil(max(adcp.backscatter,[],'all','omitnan'))];
eclim=[floor(min(adcp.echo_intens,[],'all','omitnan')) ceil(max(adcp.echo_intens,[],'all','omitnan'))];

for i=1:nb
    bvel=squeeze(adcp.bvel_water(:,i,:));
    axp(i)=CreateAxes([c1 r(i) w1 h1],time,depth,NaN(size(bvel)),[0 1],0,i,'Plume',0);
    [axv(i),cbarv]=CreateAxes([c1 r(i) w1 h1],time,depth,bvel,[-1 1],1,i,'Beam Velocity (m/s)',1);
    text(axv(i),1.01,.5,"Beam "+i,'FontSize',16,'FontWeight','bold','Units','normalized','Rotation',-90,'HorizontalAlignment','center')
end

linkaxes([axv axp])
xlim(axv(1),[time(1) time(end)])
ylim(axv(1),[depth(1) depth(end)])
ip=axv(nb-1).InnerPosition; ip(2)=r(nb);
axv(nb).InnerPosition=ip; 
axp(nb).InnerPosition=ip;
drawnow

% designate spacing for controls based on figure size
xl=.84*fig.Position(3); yl=.1*fig.Position(4);
wl=.06*fig.Position(3); hl=.03*fig.Position(4);
sp1=.052*fig.Position(4); sp2=.002*fig.Position(4)+hl; sp3=.03*fig.Position(3)+wl;

% add input boxes for QCmasks
instart=yl+13*sp1;
qslab=uilabel(fig,'Position',[xl instart+5*sp2 3*wl hl],'FontSize',16,'Text','Quality Control Inputs','FontWeight','bold');
exbotlab=uilabel(fig,'Position',[xl instart+4*sp2 2*wl hl/1.5],'FontSize',16,'Text',"ext_bottom (%)");
exbotBox=uitextarea(fig,'Position',[xl+sp3 instart+4*sp2 wl hl],'FontSize',16,'Value','10');
corrlab=uilabel(fig,'Position',[xl instart+3*sp2 2*wl hl/1.5],'FontSize',16,'Text',"corr");
corrBox=uitextarea(fig,'Position',[xl+sp3 instart+3*sp2 wl hl],'FontSize',16,'Value','64');
turnlab=uilabel(fig,'Position',[xl instart+2*sp2 2*wl hl/1.5],'FontSize',16,'Text',"turn");
turnBox=uitextarea(fig,'Position',[xl+sp3 instart+2*sp2 wl hl],'FontSize',16,'Value','.2');
celab=uilabel(fig,'Position',[xl instart+sp2 2*wl hl/1.5],'FontSize',16,'Text',"corr_echo");
ceBox1=uitextarea(fig,'Position',[xl+sp3 instart+sp2 wl*.48 hl],'FontSize',16,'Value','100');
ceBox2=uitextarea(fig,'Position',[xl+sp3+wl/2 instart+sp2 wl*.48 hl],'FontSize',16,'Value','80');
fllab=uilabel(fig,'Position',[xl instart 2*wl hl/1.5],'FontSize',16,'Text',"flag");
flBox=uitextarea(fig,'Position',[xl+sp3 instart wl hl],'FontSize',16,'Value','-32.768');

% add button to get QC masks
AP=uibutton(fig,'Text','Get QC Masks','Position',[xl yl+12*sp1 2*wl hl],'FontSize',16,'ButtonPushedFcn',@(src,event) GetQC(adcp));

% add checkboxes to control which QC masks are applied
checkstart=yl+7*sp1;
masklab=uilabel(fig,'Position',[xl checkstart+7*sp2 2*wl hl],'FontSize',16,'FontWeight','bold','Text','QC masks to apply');
XB=uicheckbox(fig,'Text','Cross-Beam Contamination','Position',[xl checkstart+6*sp2 3*wl hl],'FontSize',14,'ValueChangedFcn',@(src,event) Check(fig));
SB=uicheckbox(fig,'Text','Standard Bottom','Position',[xl checkstart+5*sp2 2*wl hl],'FontSize',14,'ValueChangedFcn',@(src,event) Check(fig));
EX=uicheckbox(fig,'Text','Extend Bottom','Position',[xl checkstart+4*sp2 2*wl hl],'FontSize',14,'ValueChangedFcn',@(src,event) Check(fig));
CR=uicheckbox(fig,'Text','Correlation Threshold','Position',[xl checkstart+3*sp2 2*wl hl],'FontSize',14,'ValueChangedFcn',@(src,event) Check(fig));
TN=uicheckbox(fig,'Text','Turn Rate Threshold','Position',[xl checkstart+2*sp2 2*wl hl],'FontSize',14,'ValueChangedFcn',@(src,event) Check(fig));
CE=uicheckbox(fig,'Text','Corr-Echo Combo','Position',[xl checkstart+sp2 2*wl hl],'FontSize',14,'ValueChangedFcn',@(src,event) Check(fig));
FL=uicheckbox(fig,'Text','Flagged Data','Position',[xl checkstart 2*wl hl],'FontSize',14,'ValueChangedFcn',@(src,event) Check(fig));

% add input boxes for Plume ID
idstart=yl+3*sp1;
idlab=uilabel(fig,'Position',[xl idstart+5*sp2 3*wl hl],'FontSize',16,'Text','Plume ID Inputs','FontWeight','bold');
dilab=uilabel(fig,'Position',[xl idstart+4*sp2 2*wl hl/1.5],'FontSize',16,'Text',"depth range");
diBox1=uitextarea(fig,'Position',[xl+sp3 idstart+4*sp2 wl*.48 hl],'FontSize',16,'Value','30');
diBox2=uitextarea(fig,'Position',[xl+sp3+wl/2 idstart+4*sp2 wl*.48 hl],'FontSize',16,'Value','160');
minlab=uilabel(fig,'Position',[xl idstart+3*sp2 2*wl hl/1.5],'FontSize',16,'Text',"min vel");
minBox=uitextarea(fig,'Position',[xl+sp3 idstart+3*sp2 wl hl],'FontSize',16,'Value','.3');
peaklab=uilabel(fig,'Position',[xl idstart+2*sp2 2*wl hl/1.5],'FontSize',16,'Text',"peak");
peakBox=uitextarea(fig,'Position',[xl+sp3 idstart+2*sp2 wl hl],'FontSize',16,'Value','.8');
gaplab=uilabel(fig,'Position',[xl idstart+sp2 2*wl hl/1.5],'FontSize',16,'Text',"gap");
gapBox=uitextarea(fig,'Position',[xl+sp3 idstart+sp2 wl hl],'FontSize',16,'Value','2');
L2lab=uilabel(fig,'Position',[xl idstart 2*wl hl/1.5],'FontSize',16,'Text',"L2 (buffer/min)");
L2Box1=uitextarea(fig,'Position',[xl+sp3 idstart wl*.48 hl],'FontSize',16,'Value','1');
L2Box2=uitextarea(fig,'Position',[xl+sp3+wl/2 idstart wl*.48 hl],'FontSize',16,'Value','2');

% put input boxes and checkboxes in user data for access later
fig.UserData=struct("exbot_val",exbotBox,"corr_val",corrBox,"turn_val",turnBox,"ce_val1",ceBox1,"ce_val2",ceBox2,"fl_val",flBox,"xbeam",XB,"stbot",SB,"exbot",EX,"corr",CR,"turn",TN,"CE",CE,"FL",FL,"di_val1",diBox1,"di_val2",diBox2,"min_val",minBox,"peak_val",peakBox,"gap_val",gapBox,"L2buff_val",L2Box1,"L2thresh_val",L2Box2);

% add buttons to ID as L1-3 plume
name1='L1plume'; name2='L2plume'; name3='L3plume';
L1=uibutton(fig,'Text','ID L1','Position',[.975*xl yl+1.6*sp1 .8*wl hl],'FontSize',14,'ButtonPushedFcn',@(src,event) PlumeID(src,event,name1));
L2=uibutton(fig,'Text','ID L2','Position',[.975*xl yl+.8*sp1 .8*wl hl],'FontSize',14,'ButtonPushedFcn',@(src,event) PlumeID(src,event,name2));
L3=uibutton(fig,'Text','ID L3','Position',[.975*xl yl .8*wl hl],'FontSize',14,'ButtonPushedFcn',@(src,event) PlumeID(src,event,name3));

% add buttons to show L1-3 plume
SL1=uibutton(fig,'state','Text','Show L1','Position',[.975*xl+.6*sp3 yl+1.6*sp1 .8*wl hl],'FontSize',14,'FontColor','k','FontWeight','bold','ValueChangedFcn',@(src,event) ShowID(src,event,name1));
SL2=uibutton(fig,'state','Text','Show L2','Position',[.975*xl+.6*sp3 yl+.8*sp1 .8*wl hl],'FontSize',14,'FontColor','g','FontWeight','bold','ValueChangedFcn',@(src,event) ShowID(src,event,name2));
SL3=uibutton(fig,'state','Text','Show L3','Position',[.975*xl+.6*sp3 yl .8*wl hl],'FontSize',14,'FontColor','y','FontWeight','bold','ValueChangedFcn',@(src,event) ShowID(src,event,name3));

% add a button to save current plume ID
RB=uibutton(fig,'Text','Save','Position',[xl+sp3 yl+.8*sp1 .85*wl hl],'FontSize',16,'ButtonPushedFcn',@(src,event) SaveID());


    function [ax,cbar]=CreateAxes(pos,time,depth,data,vlim,vmap,i,lab,vis)
        ax=uiaxes(fig,'Position',pos,'Units','normalized','Color',[.72 .6 .48]);
        ax.Position=pos;
        set(fig,'CurrentAxes',ax)
        pc=pcolorjw(time,depth,data);
        axis(ax,'ij');
        clim(ax,vlim)
        if vmap
            colormap(ax,cmocean('balance'))
        end
        if i<nb
            xticklabels(ax,[])
            cbar=[];
        else
            ip=ax.InnerPosition;
            datetick(ax,'x','keeplimits')
            xlabel(ax,'Time')
            cbar=colorbar(ax,'southoutside','Position',[.85 .05 .1 .015]);
            cbar.Label.String=lab;
            cbar.Label.FontSize=16;
            ax.InnerPosition=ip;
        end
        ylabel(ax,'Depth (m)')
        set(ax,'FontSize',16)
        ax.SortMethod='childorder';
        if ~vis
            cbar.Visible='off';
            disableDefaultInteractivity(ax)
            ax.Toolbar.Visible='off';
        end
    end

    function GetQC(src,event)
        ex=str2double(fig.UserData.exbot_val.Value{1});
        cr=str2double(fig.UserData.corr_val.Value{1});
        tn=str2double(fig.UserData.turn_val.Value{1});
        ce=[str2double(fig.UserData.ce_val1.Value{1}) str2double(fig.UserData.ce_val2.Value{1})];
        fl=str2double(fig.UserData.fl_val.Value{1});
        fig.UserData.QC=CreateQCMasks(adcp,xbeam=1,ext_bottom=ex,corr=cr,turn=tn,corr_echo=ce,flag=fl);  
    end

    function Check(fig)
        mask=ones(size(adcp.bvel));
        if fig.UserData.xbeam.Value
            mask=mask.*fig.UserData.QC.xb_mask;
            fig.UserData.QC.xbeam=1;
        else
            fig.UserData.QC.xbeam=0;
        end
        if fig.UserData.stbot.Value
            mask=mask.*adcp.bottom_mask;
            fig.UserData.QC.bottom_cont=1;
        else
            fig.UserData.QC.bottom_cont=0;
        end
        if fig.UserData.exbot.Value
            mask=mask.*fig.UserData.QC.exbot_mask;
            fig.UserData.QC.ext_bottom=str2double(fig.UserData.exbot_val.Value{1});
        else
            fig.UserData.QC.ext_bottom=[];
        end
        if fig.UserData.corr.Value
            mask=mask.*fig.UserData.QC.corr_mask;
            fig.UserData.QC.corr=str2double(fig.UserData.corr_val.Value{1});
        else
            fig.UserData.QC.corr=[];
        end
        if fig.UserData.turn.Value
            mask=mask.*fig.UserData.QC.turnrate_mask;
            fig.UserData.QC.turn=str2double(fig.UserData.turn_val.Value{1});
        else
            fig.UserData.QC.turn=[];
        end
        if fig.UserData.CE.Value
            mask=mask.*fig.UserData.QC.corr_echo_mask;
            fig.UserData.QC.corr_echo=[str2double(fig.UserData.ce_val1.Value{1}) str2double(fig.UserData.ce_val2.Value{1})];
        else
            fig.UserData.QC.corr_echo=[];
        end
        if fig.UserData.FL.Value
            mask=mask.*fig.UserData.QC.flag_mask;
            fig.UserData.QC.flag=str2double(fig.UserData.fl_val.Value{1});
        else
            fig.UserData.QC.flag=[];
        end
        fig.UserData.QC.current_mask=mask;
        for i=1:nb
            bvel=squeeze(adcp.bvel_water(:,i,:).*mask(:,i,:));
            pcolor(axv(i),time,depth,bvel); shading(axv(i),'flat')
        end
    end

    function PlumeID(src,event,name)
        fig.UserData.(name)=[];
        if strcmp(name,name1) || strcmp(name,name2)
            fprintf("Identifying "+name+"...\n")
            col='k';
            d1=find(depth>str2double(fig.UserData.di_val1.Value{1}),1,'first');
            d2=find(depth<str2double(fig.UserData.di_val2.Value{1}),1,'last');
            di=d1:d2;
            minv=str2double(fig.UserData.min_val.Value{1});
            peak=str2double(fig.UserData.peak_val.Value{1});
            gap=str2double(fig.UserData.gap_val.Value{1});
            fig.UserData.(name)=IDPlume(adcp,fig.UserData.QC.current_mask,di,minv=minv,peak=peak,gap=gap);
            if strcmp(name,name2)
                fprintf("L2 adjustments...")
                col='g';
                buff=str2double(fig.UserData.L2buff_val.Value{1});
                thresh=str2double(fig.UserData.L2thresh_val.Value{1});
                fig.UserData.(name)=RemoveXbeam(fig.UserData.(name),adcp.bottom_depth,time,depth,dt,dd,buff,thresh,fb,rb);
                fprintf("complete\n\n")
            end
            fig.UserData.(name).QC=fig.UserData.QC;
        elseif strcmp(name,name3)
            if ~isempty(fig.UserData.L2plume)
                fprintf("Identifying "+name+"...\n")
                col='y';
                plume=fig.UserData.L2plume;
                %remove potential side-lobe contamination (w/in X% of bottom)
                xbot=fig.UserData.QC.exbot_mask;
                xbot999=xbot; xbot999(isnan(xbot))=-999;
                for i=1:nb
                    data=squeeze(xbot999(:,i,:));
                    data(:,[1 end])=zeros(length(depth),2); %to ensure that bottom creates a complete convex polyshape
                    [~,pg]=ContourMask(time,depth,data,0,0,0,dt,dd);
                    pgu=union(pg);
                    pu=union(plume.polyshapes{i});
                    ps(i)=subtract(pu,pgu);
                end
                %remove cross-beam contamination
                bc=adcp.bottom_depth;
                [xx,yy]=meshgrid(time,depth);
                X=reshape(xx,length(depth)*length(time),1);
                Y=reshape(yy,length(depth)*length(time),1);
                sub=polyshape([time(1) time(end) time(end) time(1)],[220 220 depth(end) depth(end)]);
                for i=1:nb
                    xbc(i)=polybuffer([(time*dt)' (bc(i,:)*dd)'],'lines',2); %bin of bottom contour plus one either side
                    xbc(i).Vertices(:,1)=xbc(i).Vertices(:,1)/dt;
                    xbc(i).Vertices(:,2)=xbc(i).Vertices(:,2)/dd;
                    xbc(i)=subtract(xbc(i),sub);
                    %snap to data grid
                    xbcsplit=regions(xbc(i));
                    ns=length(xbcsplit);
                    for p=1:ns
                        px=xbcsplit(p).Vertices(:,1);
                        py=xbcsplit(p).Vertices(:,2);
                        k=dsearchn([X Y],[px py]);
                        xbcsplit(p).Vertices=[X(k) Y(k)];
                    end
                    snapxbc(i)=union(xbcsplit);
                end
                xb=union(snapxbc);
                %subtract from plume ID
                L3plume.mask=NaN(size(plume.mask));
                for i=1:nb
                    pss(i)=subtract(ps(i),xb);
                    L3mask(:,i,:)=inpolygon(xx,yy,pss(i).Vertices(:,1),pss(i).Vertices(:,2));
                    L3plume.polyshapes(i)={regions(pss(i))};
                end
                L3plume.mask(L3mask==1)=1;
                
                fig.UserData.(name)=L3plume;
                fig.UserData.(name).thresholds=fig.UserData.L2plume.thresholds;
                fig.UserData.(name).QC=fig.UserData.L2plume.QC;
                
                fprintf("Plume ID complete\n\n")
            else
                fprintf("L2 must be established before L3 plume can be identified\n")
            end
        end
        for i=1:nb
            hold(axp(i),'off')
            pshape=fig.UserData.(name).polyshapes{i};
            for s=1:length(pshape)
                if ~isempty(pshape(s))
                    pshape(s).Vertices(:,2)=pshape(s).Vertices(:,2)+adcp.config.depth_cell_length/2; %adjust position so that it plots in center of pcolorjw cells
                    pshape(s).Vertices(:,1)=pshape(s).Vertices(:,1)+mode(diff(adcp.time)/2);
                end
            end        
            plot(axp(i),pshape,'FaceColor','none','EdgeColor',col,'LineWidth',1.5);
            yline(axp(i),str2double(fig.UserData.di_val1.Value{1}),':')
            yline(axp(i),str2double(fig.UserData.di_val2.Value{1}),':')
            axp(i).Visible='off';
            xlim(axp(i),[time(1) time(end)])
            xticklabels(axp(i),'auto')
            datetick(axp(i),'x','keeplimits')
            axp(i).InnerPosition=axv(i).InnerPosition;
        end
        uistack(axp,'top')
        if strcmp(name,name1)
            SL1.Value=1;
            SL2.Value=0;
            SL3.Value=0;
        elseif strcmp(name,name2)
            SL1.Value=0;
            SL2.Value=1;
            SL3.Value=0;
        elseif strcmp(name,name3)
            SL1.Value=0;
            SL2.Value=0;
            SL3.Value=1;
        end
    end
    
    function ShowID(src,event,name)
        l1status=NaN; l2status=NaN; l3status=NaN;
        uistack(axp,'top')
        for i=1:nb
            hold(axp(i),'off')
            plot(axp(i),NaN,NaN);
            hold(axp(i),'on')
            if SL1.Value
                if isfield(fig.UserData,'L1plume') && ~isempty(fig.UserData.L1plume)
                    pshape=fig.UserData.L1plume.polyshapes{i};
                    for s=1:length(pshape)
                        if ~isempty(pshape(s))
                            pshape(s).Vertices(:,2)=pshape(s).Vertices(:,2)+adcp.config.depth_cell_length/2; %adjust position so that it plots in center of pcolorjw cells
                            pshape(s).Vertices(:,1)=pshape(s).Vertices(:,1)+mode(diff(adcp.time)/2);
                        end
                    end        
                    plot(axp(i),pshape,'FaceColor','none','EdgeColor','k','LineWidth',1.5);
                elseif isfield(adcp,'L1plume')
                    pshape=adcp.L1plume.polyshapes{i};
                    for s=1:length(pshape)
                        if ~isempty(pshape(s))
                            pshape(s).Vertices(:,2)=pshape(s).Vertices(:,2)+adcp.config.depth_cell_length/2; %adjust position so that it plots in center of pcolorjw cells
                            pshape(s).Vertices(:,1)=pshape(s).Vertices(:,1)+mode(diff(adcp.time)/2);
                        end
                    end        
                    plot(axp(i),pshape,'FaceColor','none','EdgeColor','k','LineWidth',1.5);
                    l1status=1;
                else
                    l1status=0;
                end
            end
            if SL2.Value
                if isfield(fig.UserData,'L2plume') && ~isempty(fig.UserData.L2plume)
                    pshape=fig.UserData.L2plume.polyshapes{i};
                    for s=1:length(pshape)
                        if ~isempty(pshape(s))
                            pshape(s).Vertices(:,2)=pshape(s).Vertices(:,2)+adcp.config.depth_cell_length/2; %adjust position so that it plots in center of pcolorjw cells
                            pshape(s).Vertices(:,1)=pshape(s).Vertices(:,1)+mode(diff(adcp.time)/2);
                        end
                    end        
                    plot(axp(i),pshape,'FaceColor','none','EdgeColor','g','LineWidth',1.5);
                elseif isfield(adcp,'L2plume')
                    pshape=adcp.L2plume.polyshapes{i};
                    for s=1:length(pshape)
                        if ~isempty(pshape(s))
                            pshape(s).Vertices(:,2)=pshape(s).Vertices(:,2)+adcp.config.depth_cell_length/2; %adjust position so that it plots in center of pcolorjw cells
                            pshape(s).Vertices(:,1)=pshape(s).Vertices(:,1)+mode(diff(adcp.time)/2);
                        end
                    end        
                    plot(axp(i),pshape,'FaceColor','none','EdgeColor','g','LineWidth',1.5);
                    l2status=1;
                else
                    l2status=0;
                end
            end
            if SL3.Value
                if isfield(fig.UserData,'L3plume') && ~isempty(fig.UserData.L3plume)
                    pshape=fig.UserData.L3plume.polyshapes{i};
                    for s=1:length(pshape)
                        if ~isempty(pshape(s))
                            pshape(s).Vertices(:,2)=pshape(s).Vertices(:,2)+adcp.config.depth_cell_length/2; %adjust position so that it plots in center of pcolorjw cells
                            pshape(s).Vertices(:,1)=pshape(s).Vertices(:,1)+mode(diff(adcp.time)/2);
                        end
                    end        
                    plot(axp(i),pshape,'FaceColor','none','EdgeColor','y','LineWidth',1.5);
                elseif isfield(adcp,'L3plume')
                    pshape=adcp.L3plume.polyshapes{i};
                    for s=1:length(pshape)
                        if ~isempty(pshape(s))
                            pshape(s).Vertices(:,2)=pshape(s).Vertices(:,2)+adcp.config.depth_cell_length/2; %adjust position so that it plots in center of pcolorjw cells
                            pshape(s).Vertices(:,1)=pshape(s).Vertices(:,1)+mode(diff(adcp.time)/2);
                        end
                    end        
                    plot(axp(i),pshape,'FaceColor','none','EdgeColor','y','LineWidth',1.5);
                    l3status=1;
                else
                    l3status=0;
                end
            end
            axp(i).InnerPosition=axv(i).InnerPosition;
            axp(i).Visible='off';
        end
        if strcmp(name,'L1plume') 
            if l1status==1
                fprintf("L1 plume has not been identified in this session - Displaying saved L1 plume\n")
            elseif l1status==0
                fprintf("L1 plume has not been identified\n")
            end
        elseif strcmp(name,'L2plume')
            if l2status==1
                fprintf("L2 plume has not been identified in this session - Displaying saved L2 plume\n")
            elseif l2status==0
                fprintf("L2 plume has not been identified\n")
            end
        elseif strcmp(name,'L3plume')
            if l3status==1
                fprintf("L3 plume has not been identified in this session - Displaying saved L3 plume\n")
            elseif l3status==0
                fprintf("L3 plume has not been identified\n")
            end
        end
    end

    function SaveID(src,event)
        ver="";
        if isfield(fig.UserData,'L1plume')
            adcp.L1plume=fig.UserData.L1plume;
            ver=ver+" L1 ";
        end
        if isfield(fig.UserData,'L2plume')
            adcp.L2plume=fig.UserData.L2plume;
            ver=ver+" L2 ";
        end
        if isfield(fig.UserData,'L3plume')
            adcp.L3plume=fig.UserData.L3plume;
            ver=ver+" L3 ";
        end
        if isempty(ver)
            ver="none";
        end
        fprintf("Plume IDs saved: "+ver+"\n")
    end


waitfor(fig)

end






