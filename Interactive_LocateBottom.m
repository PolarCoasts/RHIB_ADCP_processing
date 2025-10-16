function adcp=Interactive_LocateBottom(adcp,n)
% this function allows the user to omit regions of backscatter data that get erroneously identified as a bottom signal
%   1. when function is run, an interactive figure will appear
%   2. set input values for LocateBottom in boxes at the top
%   3. click "ID Bottom Contours"
%       - steps 2 and 3 can be repeated as needed
%   4. when identification is mostly correct, the brush tool can be used to remove selections of backscatter data
%   5. click "Brush" to turn on brush tool for all axes
%   6. use brush tool to select regions of backscatter data (zoom in if necessary)
%   7. click "Remove Brushed" to replace all brushed backscatter data with NaNs
%   8. click "ID Bottom Contours" to run LocateBottom with revised backscatter data
%       - steps 6-8 can be repeated, results will be cumulative
%   9. to start over or to compare contours to full backscatter data, press "Reset Backscatter"
%       - if "ID Bottom Contours" is pressed after "Reset Backscatter", LocateBottom will be run will full backscatter data (starting over)
%   10 when desired results have been reached, click "Save and Exit"
%       - bottom contours will be saved in the output adcp structure (a new file will not be saved)
% ** n is monitor number to display figure on **

% calculate backscatter from echo if not already done
if ~isfield(adcp,'backscatter')
    adcp=Echo2Backscatter(adcp);
end

adcp=PlotBackscatter(adcp,n);

    function adcp=PlotBackscatter(adcp,n)
        nb=adcp.config.n_beams;
        time=adcp.nuc_time;
        depth=adcp.cell_depth;
                
        c1=.01;
        r=linspace(.99,.05,nb+1); r=r(2:end);
        w1=.8; h1=.9*abs(diff(r(1:2))); 

        mp=get(0,'MonitorPositions');

        fig=uifigure('Position',mp(n,:));

        bslim=[floor(min(adcp.backscatter,[],'all','omitnan')) ceil(max(adcp.backscatter,[],'all','omitnan'))];
        
        for i=1:nb
            back=squeeze(adcp.backscatter(:,i,:));
            ax(i)=uiaxes(fig,'Position',[c1 r(i) w1 h1],'Units','normalized');
            ax(i).Position=[c1 r(i) w1 h1]; % because it gets messed up??
            h(i)=surf(ax(i),time,depth,back);
            shading(ax(i),'flat'); axis(ax(i),'ij');
            view(ax(i),2)
            hold(ax(i),'on')
            clim(ax(i),bslim)
            text(ax(i),1.01,.5,"Beam "+i,'FontSize',16,'FontWeight','bold','Units','normalized','Rotation',-90,'HorizontalAlignment','center')
            if i<nb
                xticklabels(ax(i),[]);
            else
                datetick(ax(i),'x','keeplimits')
                xlabel(ax(i),'Time')
                cbar=colorbar(ax(i),'southoutside','Position',[.85 .05 .1 .015]);
                cbar.Label.String="Backscatter (dB)";
                cbar.Label.FontSize=16;                
            end
            ylabel(ax(i),'Depth (m)')
            set(ax(i),'FontSize',16)
            ax(i).SortMethod='childorder'; %keeps contour lines visible when zooming in
        end
        
        linkaxes(ax)
        xlim(ax(i),[time(1) time(end)])
        ylim(ax(i),[depth(1) depth(end)])
        ax(nb).InnerPosition([1 3 4])=ax(nb-1).InnerPosition([1 3 4]);
        ax(nb).InnerPosition(2)=r(nb);
        drawnow
        
        % set text box position based on figure size
        xl=.83*fig.Position(3); yl=.76*fig.Position(4);
        wl=.056*fig.Position(3); hl=.03*fig.Position(4);
        sp1=.06*fig.Position(4); sp2=.002*fig.Position(4)+hl;

        bslab=uilabel(fig,'Position',[xl yl+3*sp1+sp2 wl hl/1.5],'FontSize',16,'Text',"minbs");
        minbsBox=uitextarea(fig,'Position',[xl yl+3*sp1 wl hl],'FontSize',16);
        gaplab=uilabel(fig,'Position',[xl yl+2*sp1+sp2 wl hl/1.5],'FontSize',16,'Text',"gap");
        gapBox=uitextarea(fig,'Position',[xl yl+2*sp1 wl hl],'FontSize',16);
        jumplab=uilabel(fig,'Position',[xl yl+sp1+sp2 wl hl/1.5],'FontSize',16,'Text',"binjump");
        binjumpBox=uitextarea(fig,'Position',[xl yl+sp1 wl hl],'FontSize',16);
        methlab=uilabel(fig,'Position',[xl yl+sp2 wl*2 hl/1.5],'FontSize',16,'Text',"interpmeth");
        methBox=uitextarea(fig,'Position',[xl yl wl hl],'FontSize',16);
    
        fig.UserData=struct("minbsBox",minbsBox,"gapBox",gapBox,"binjumpBox",binjumpBox,"methBox",methBox);
        backscatter_orig=adcp.backscatter; % save original for resetting later
    
        ID=uibutton(fig,'Text',"ID Bottom Contours",'Position',[xl yl-2*sp1 wl*2 hl],'FontSize',16,'ButtonPushedFcn',@(src,event) IDBot(ax,adcp));
        BB=uibutton(fig,'Text',"Brush",'Position',[xl yl-4*sp1 wl*2 hl],'FontSize',16,'ButtonPushedFcn',@(src,event) BrushOn(ax));
        BR=uibutton(fig,'Text',"Remove Brushed",'Position',[xl yl-5*sp1 wl*2 hl],'FontSize',16,'ButtonPushedFcn',@(src,event) BrushRemove(h,adcp));
        RB=uibutton(fig,'Text',"Reset Backscatter",'Position',[xl yl-7*sp1 wl*2 hl],'FontSize',16,'ButtonPushedFcn',@(src,event) Reset(adcp,backscatter_orig));
        RL=uibutton(fig,'Text',"Restore Limits",'Position',[xl yl-9*sp1 wl*2 hl],'FontSize',16,'ButtonPushedFcn',@(src,event) Restore(ax));
        EC=uibutton(fig,'Text',"Save and Exit",'Position',[xl yl-11*sp1 wl*2 hl],'FontSize',16,'ButtonPushedFcn',@(src,event) SaveExit(fig));
    
        function IDBot(src,event)
            minbs=str2double(fig.UserData.minbsBox.Value{1});
            gap=str2double(fig.UserData.gapBox.Value{1});
            binjump=str2double(fig.UserData.binjumpBox.Value{1});
            meth=fig.UserData.methBox.Value{1};
            adcp=LocateBottom(adcp,minbs=minbs,gap=gap,binjump=binjump,meth=meth);
            for i=1:nb
                if isfield(ax(i).UserData,'cont')
                    oldcont=ax(i).UserData.cont;
                    delete(oldcont)
                end
                ax(i).UserData.cont=plot(ax(i),time,adcp.bottom_depth(i,:),'LineWidth',1,'Color','k');
            end   
            if isfield(adcp,'backscatter_adj')
                if adcp.backscatter_adj
                    adcp.BottomID.adjustments="some backscatter data was omitted manually - see Interactive_LocateBottom";
                else
                    adcp.BottomID.adjustments="";
                end
            end
        end
    
        function BrushOn(src,event)
            for i=1:nb
                brush(ax(i),'on')
            end
        end
        
        function BrushRemove(src,event)
            for i=1:nb
                b=logical(h(i).BrushData);
                tempback=squeeze(adcp.backscatter(:,i,:));
                tempback(b)=NaN;
                h(i).ZData=tempback;
                adcp.backscatter(:,i,:)=tempback;
                adcp.backscatter_adj=1;
            end
        end
    
        function Reset(src,event)
            adcp.backscatter=backscatter_orig;
            adcp.backscatter_adj=0;
            for i=1:nb
                h(i).ZData=squeeze(backscatter_orig(:,i,:));
                h(i).BrushData=zeros(size(h(i).ZData));
            end
        end
    
        function Restore(src,event)
            for i=1:nb
                xlim(ax(i),[time(1) time(end)])
                ylim(ax(i),[depth(1) depth(end)])
            end
        end
    
        function SaveExit(src,event)
            adcp.backscatter=backscatter_orig;
            close(fig)
            return
        end

    waitfor(fig)
    if isfield(adcp,'backscatter_adj')
        adcp=rmfield(adcp,'backscatter_adj');
    end
    assignin('caller','adcp',adcp)

    end

end
