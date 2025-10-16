function [termfile,termdate,termdt]=AddTerm(basepath,termfolder)

termfiles=dir([basepath termfolder '**/*.mat']);
termfiles(contains({termfiles.name},'._'))=[];
termfilenames={termfiles.name};
prompt="Enter the line number for the terminus file you wish to use\n";
number=1:length(termfilenames);
fS='%d %s\n';
for i=1:length(termfilenames)
    fprintf(fS,number(i),termfilenames{i})
end
ii=input(prompt);

if isempty(ii)
    termfile=[];
    termdate=[];
    termdt=[];
else
    termfile=fullfile(termfiles(ii).folder,termfiles(ii).name);
    termdate=split(termfilenames{ii},'_');
    termdate=termdate{2};
    termdt=datetime(termdate,'InputFormat','MMddyyyy');
end
