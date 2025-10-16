function [adcp,xsect,ctd,folder,filepath]=LoadDeployment(basepath)

% This function displays an numbered list of processed ADCP files in the basepath directory and its subdirectories
% 
% usage:
%   adcp = LoadDeployment(basepath);
%
% The user enters the line number for the desired file and it is loaded into the output structure
% Additional outputs can be used to load transect times/indices, ctd data, and the folder/filepath info for the file

files=dir([basepath '**/adcp_deploy_*.mat']);
files(contains({files.name},'._'))=[];

filenames={files.name};
prompt="Enter the line number for the file you wish to load\n";

number=1:length(filenames);
fS='%d %s\n';
for i=1:length(filenames)
    fprintf(fS,number(i),filenames{i})
end
ii=input(prompt);

if isempty(ii)
    adcp=[];
    return
end

folder={files(ii).folder};
folder=[folder{:} '/'];
filepath=fullfile(folder,filenames{ii});

adcp=load(filepath);
adcp=adcp.adcp;

files=dir([folder '**/Sections_*.mat']);
if ~isempty(files)
    xsect=load(fullfile(files.folder,files.name));
    xsect=xsect.Xsect;
else
    xsect=[];
end

ctdfolder=split(folder,'/');
ctdfolder=string(join(ctdfolder(1:end-2),'/'));
ctdfolder=[convertStringsToChars(ctdfolder) '/CTD/'];
if exist(ctdfolder,'dir')
    ctdfile=dir([ctdfolder '*.mat']);
    ctdfile(startsWith({ctdfile.name},'._'))=[];
    ctdfile(endsWith({ctdfile.name},'_AriesPolly.mat'))=[];
    ctd=load(fullfile(ctdfile.folder,ctdfile.name));
    ctd=ctd.ctd;
else
    ctd=[];
end
