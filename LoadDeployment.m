function adcp=LoadDeployment

% This function displays an numbered list of processed ADCP files in the working directory and its subdirectories
% 
% usage:
%   adcp = LoadDeployment;
%
% The user enters the line number for the desired file and it is loaded into the output structure

files=dir('**/*.mat');

filenames={files.name};
prompt="Enter the line number for the file you wish to load\n";
% ii=listdlg('PromptString',prompt,'ListString',filenames,'ListSize',[300 100],'OKString','Load','SelectionMode','single');

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

filepath=fullfile(files(ii).folder,filenames{ii});

adcp=load(filepath);
adcp=adcp.adcp;
