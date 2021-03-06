%% OMEGA: Script for automatic preprocessing
% 
% ** OMEGA_BSTdb_v1_guio **
%
%%% 1) Import MEG recordings (resting state)
% 2) Compute sources
% 3) PSD on sensors (in all freqs)
% 4) PSD on sensors (in bands)
% 5) PSD on sources (in bands)
%
% 1 June 2021 (v2)
% Guiomar Niso, 6 Apr 2015 (v0)
% Guiomar Niso, 30 May 2016 (v1)

clc; clear;

%% ==== PARAMETERS ================================================

% 1) MEG datasets storage
mydirMEG = 'C:\Users\Maria\OneDrive - Universidad Politécnica de Madrid\TFM\Pruebas_sujetos\';
% 2) Dir to save progress report
mydirBST = 'C:\Users\Maria\OneDrive - Universidad Politécnica de Madrid\TFM\Reports';


mydirPROJECT= 'C:\Users\Maria\OneDrive - Universidad Politécnica de Madrid\brainstorm_db\TFM_Prueba';

% Frequency bands of interest
freq_bands = {'delta', '2, 4', 'mean';
              'theta', '5, 7', 'mean'; 
              'alpha', '8, 12', 'mean'; 
              'beta', '15, 29', 'mean'; 
              'gamma1', '30, 59', 'mean'; 
              'gamma2', '60, 90', 'mean'};

% Window length and overlap for PSD Welch method
win_length = 4; % sec
win_overlap = 50; % percentage


datefield = 4; % Field containing the DATE in the recordings name
runfield = 5; % Field containing the RUN in the recordings name

% =========================================================================

%% Prepare MEG files

sSubjects = bst_get('ProtocolSubjects');
SubjectNames = {sSubjects.Subject.Name};
%SubjectNames = {'sub-CC110033'};



 for iSubject = 2:numel(SubjectNames)-1 % 0: Group analysis, end: emptyroom

try  
%% 0) SELECT RECORDINGS

% For Brainstorm
sFiles0 = [];

% Start a new report
bst_report('Start', sFiles0);

% ==== REST ====

% Process: Select file names with tag: SUBJECT NAME
sFilesMEG = bst_process('CallProcess', 'process_select_files_data', ...
    sFiles0, [], ...
    'tag', '', ...
    'subjectname', SubjectNames{iSubject}, ...
    'condition', '');

if isempty(sFilesMEG), continue; end

% Process: Select file names with tag: high
sFilesMEG = bst_process('CallProcess', 'process_select_tag', ...
    sFilesMEG, [], ...
    'tag', 'high', ...
    'search', 1, ... % 1: Filename, 2: Comments
    'select', 1);  % Select only the files with the tag

% Process: Select file names with tag: resting
sFilesRESTING = bst_process('CallProcess', 'process_select_tag', ...
    sFilesMEG, [], ...
    'tag', 'rest', ...
    'search', 1, ... % 1: Filename, 2: Comments
    'select', 1);  % Select only the files with the tag

% ==== NOISE ====

% Process: Select file names with tag: SUBJECT NAME
sFilesER = bst_process('CallProcess', 'process_select_files_data', ...
    sFiles0, [], ...
    'tag', '', ...
    'subjectname', 'sub-emptyroom', ...
    'condition', '');

% Process: Select file names with tag: noise
sFilesNOISE = bst_process('CallProcess', 'process_select_tag', ...
    sFilesER, [], ...
    'tag', SubjectNames{iSubject}(5:end), ...
    'search', 1, ... % 1: Filename, 2: Comments
    'select', 1);  % Select only the files with the tag

% Process: Select file names with tag: high
sFilesNOISE = bst_process('CallProcess', 'process_select_tag', ...
    sFilesNOISE, [], ...
    'tag', 'high', ...
    'search', 1, ... % 1: Filename, 2: Comments
    'select', 1);  % Select only the files with the tag


% Load subject study
SubjectFile = bst_get('Subject', SubjectNames{iSubject});
SubjectStudy = bst_get('StudyWithSubject', SubjectFile.FileName);

    
%% ==== 1) Compute noise covariance ===============================

    
    % Process: Compute covariance (noise or data)
sFilesNcov = bst_process('CallProcess', 'process_noisecov', ...
    sFilesNOISE, [], ...
    'baseline',       [], ...
    'datatimewindow', [], ...
    'sensortypes',    'MEG', ...
    'target',         1, ...  % Noise covariance     (covariance over baseline time window)
    'dcoffset',       1, ...  % Block by block, to avoid effects of slow shifts in data
    'identity',       0, ...
    'copycond',       0, ...
    'copysubj',       0, ...
    'copymatch',      0, ...
    'replacefile',    1);  % Replace
    
    db_set_noisecov(sFilesNcov.iStudy, sFilesRESTING.iStudy, 0, 1);



%% ==== 2) Compute head model =====================================
 
    
    % Process: Compute head model
    sFilesHM = bst_process('CallProcess', 'process_headmodel', ...
        sFilesRESTING, [], ...
        'Comment',     '', ...
        'sourcespace', 1, ...  % Cortex surface
        'meg',         3, ...  % Overlapping spheres
        'eeg',         1, ...  % 
        'ecog',        1, ...  % 
        'seeg',        1, ...  % 
        'channelfile', '');


%% ==== 3) Compute sources ========================================
    
    % Process: Compute sources [2018]
    sFilesSRC = bst_process('CallProcess', 'process_inverse_2018', ...
        sFilesRESTING, [], ...
        'output',  1, ...  % Kernel only: shared
        'inverse', struct(...
         'Comment',        'dSPM-unscaled: MEG ALL', ...
         'InverseMethod',  'minnorm', ...
         'InverseMeasure', 'dspm2018', ...
         'SourceOrient',   {{'fixed'}}, ...
         'Loose',          0.2, ...
         'UseDepth',       1, ...
         'WeightExp',      0.5, ...
         'WeightLimit',    10, ...
         'NoiseMethod',    'reg', ...
         'NoiseReg',       0.1, ...
         'SnrMethod',      'fixed', ...
         'SnrRms',         1e-06, ...
         'SnrFixed',       3, ...
         'ComputeKernel',  1, ...
         'DataTypes',      {{'MEG GRAD', 'MEG MAG'}}));


%% ==== 4) PSD on sensors (in all freqs) ==========================

% Process: Select file names with tag: SUBJECT NAME
sFilesPSD = bst_process('CallProcess', 'process_select_files_timefreq', ...
    sFiles0, [], ...
    'subjectname', SubjectNames{iSubject}, ...
    'condition', sFilesRESTING.Condition);


% Process: Select file comments with tag: XX
sFilesPSD_sens_all = bst_process('CallProcess', 'process_select_tag', ...
    sFilesPSD, [], ...
    'tag', 'PSD sensors_all_total', ...
    'search', 2, ... % 1: Filename, 2: Comments
    'select', 1);  % Select only the files with the tag

% Process: Select file comments with tag: XX
sFilesPSD_sens_all_relative = bst_process('CallProcess', 'process_select_tag', ...
    sFilesPSD, [], ...
    'tag', 'PSD sensors_all_relative', ...
    'search', 2, ... % 1: Filename, 2: Comments
    'select', 1);  % Select only the files with the tag

if isempty(sFilesPSD_sens_all)

    % Process: Power spectrum density (Welch)
    sFilesPSD_sens_all = bst_process('CallProcess', 'process_psd', ...
        sFilesRESTING, [], ... %%%%%%
        'timewindow', [], ...
        'win_length', win_length, ...
        'win_overlap', win_overlap, ...
        'sensortypes', 'MEG, EEG', ...
        'edit', struct(...
             'Comment', 'Avg,Power', ...
             'TimeBands', [], ...
             'Freqs', [], ...
             'ClusterFuncTime', 'none', ...
             'Measure', 'power', ...
             'Output', 'all', ...
             'SaveKernel', 0));

    % Process: Set comment: sensor_all
    sFilesPSD_sens_all = bst_process('CallProcess', 'process_set_comment', ...
        sFilesPSD_sens_all, [], ...
        'tag', 'PSD sensors_all_total', ...
        'isindex', 1);

end

if isempty(sFilesPSD_sens_all_relative)
     
    % Process: Spectral flattening
    sFilesPSD_sens_all_relative = bst_process('CallProcess', 'process_tf_norm', ...
        sFilesPSD_sens_all, [], ...
        'normalize', 'relative', ...  % Relative power (divide by total power)
        'overwrite', 0);

    % Process: Set comment: sensor_all_relative
    sFilesPSD_sens_all_relative = bst_process('CallProcess', 'process_set_comment', ...
        sFilesPSD_sens_all_relative, [], ...
        'tag', 'PSD sensors_all_relative', ...
        'isindex', 1);

end


%% ==== 5) PSD on sensors (in bands) ==============================

% Process: Select file comments with tag: XX
sFilesPSD_sens_bands = bst_process('CallProcess', 'process_select_tag', ...
    sFilesPSD, [], ...
    'tag', 'PSD sensors_bands_total', ...
    'search', 2, ... % 1: Filename, 2: Comments
    'select', 1);  % Select only the files with the tag

% Process: Select file comments with tag: XX
sFilesPSD_sens_bands_relative = bst_process('CallProcess', 'process_select_tag', ...
    sFilesPSD, [], ...
    'tag', 'PSD sensors_bands_relative', ...
    'search', 2, ... % 1: Filename, 2: Comments
    'select', 1);  % Select only the files with the tag

if isempty(sFilesPSD_sens_bands)

    % Process: Power spectrum density (Welch)
    sFilesPSD_sens_bands = bst_process('CallProcess', 'process_psd', ...
        sFilesRESTING, [], ... %%%%
        'timewindow', [], ...
        'win_length', win_length, ...
        'win_overlap', win_overlap, ...
        'sensortypes', 'MEG, EEG', ...
        'edit', struct(...
             'Comment', 'Avg,Power,FreqBands', ...
             'TimeBands', [], ...
             'Freqs', {freq_bands}, ...
             'ClusterFuncTime', 'none', ...
             'Measure', 'power', ...
             'Output', 'all', ...
             'SaveKernel', 0));

    % Process: Set comment: sensor_bands
    sFilesPSD_sens_bands = bst_process('CallProcess', 'process_set_comment', ...
        sFilesPSD_sens_bands, [], ...
        'tag', 'PSD sensors_bands_total', ...
        'isindex', 1);
  

end

if isempty(sFilesPSD_sens_bands_relative)

    % Process: Spectral flattening
    sFilesPSD_sens_bands_relative = bst_process('CallProcess', 'process_tf_norm', ...
        sFilesPSD_sens_bands, [], ...
        'normalize', 'relative', ...  % Relative power (divide by total power)
        'overwrite', 0);

    % Process: Set comment: sensor_bands_relative
    sFilesPSD_sens_bands_relative = bst_process('CallProcess', 'process_set_comment', ...
        sFilesPSD_sens_bands_relative, [], ...
        'tag', 'PSD sensors_bands_relative', ...
        'isindex', 1);

end


% ==== 6) PSD on sources (in bands) ==============================

% Process: Select file comments with tag: XX
sFilesPSD_sources_bands = bst_process('CallProcess', 'process_select_tag', ...
    sFilesPSD, [], ...
    'tag', 'PSD sources_bands_total', ...
    'search', 2, ... % 1: Filename, 2: Comments
    'select', 1);  % Select only the files with the tag

% Process: Select file comments with tag: XX
sFilesPSD_sources_bands_relative = bst_process('CallProcess', 'process_select_tag', ...
    sFilesPSD, [], ...
    'tag', 'PSD sources_bands_relative', ...
    'search', 2, ... % 1: Filename, 2: Comments
    'select', 1);  % Select only the files with the tag

 if isempty(sFilesPSD_sources_bands)
    
    if isempty(sFilesSRC), continue; end

    % Process: Power spectrum density (Welch)
    sFilesPSD_sources_bands = bst_process('CallProcess', 'process_psd', ...
        sFilesSRC, [], ...
        'timewindow', [], ...
        'win_length', win_length, ...
        'win_overlap', win_overlap, ...
        'clusters', [], ...
        'scoutfunc', 1, ...
        'edit', struct(...
             'Comment', 'Avg,Power,FreqBands', ...
             'TimeBands', [], ...
             'Freqs', {freq_bands}, ...
             'ClusterFuncTime', 'none', ...
             'Measure', 'power', ...
             'Output', 'all', ...
             'SaveKernel', 0));

    % Process: Set comment: sources_bands
    sFilesPSD_sources_bands = bst_process('CallProcess', 'process_set_comment', ...
        sFilesPSD_sources_bands, [], ...
        'tag', ' PSD sources_bands_total', ...
        'isindex', 1);
    

end

if isempty(sFilesPSD_sources_bands_relative)

    % Process: Spectral flattening
    sFilesPSD_sources_bands_relative = bst_process('CallProcess', 'process_tf_norm', ...
        sFilesPSD_sources_bands, [], ...
        'normalize', 'relative', ...  % Relative power (divide by total power)
        'overwrite', 0);

    % Process: Set comment: sources_bands_relative
    sFilesPSD_sources_bands_relative = bst_process('CallProcess', 'process_set_comment', ...
        sFilesPSD_sources_bands_relative, [], ...
        'tag', ' PSD sources_bands_relative', ...
        'isindex', 1);

end


%% ==== 7) PSD on sources projected to default template (in bands) =======================================

%% PROJECT TO DEFAULT TEMPLATE

% ==== TOTAL PSD
%Process: Select file names with tag: SUBJECT NAME
sFilesPSD_sources_bandsDEF = bst_process('CallProcess', 'process_select_files_timefreq', ...
    sFiles0, [], ...
    'tag', [SubjectNames{iSubject},'/PSD sources_bands_total'], ...
    'subjectname', 'Group_analysis', ...
    'condition', '');

if isempty(sFilesPSD_sources_bandsDEF)

    % Process: Project on default anatomy: surface
    sFilesPSD_sources_bandsDEF = bst_process('CallProcess', 'process_project_sources', ...
        sFilesPSD_sources_bands, [], ...
        'headmodeltype', 'surface');  % Cortex surface

    % Process: Spatial smoothing (3.00)
    bst_process('CallProcess', 'process_ssmooth_surfstat', ...
        sFilesPSD_sources_bandsDEF, [], ...
        'fwhm',      3, ...
        'overwrite', 1);

end

% ==== RELATIVE PSD
% Process: Select file names with tag: SUBJECT NAME
sFilesPSD_sources_bands_relativeDEF = bst_process('CallProcess', 'process_select_files_timefreq', ...
    sFiles0, [], ...
    'tag', [SubjectNames{iSubject},'/PSD sources_bands_relative'], ...
    'subjectname', 'Group_analysis', ...
    'condition', '');

if isempty(sFilesPSD_sources_bands_relativeDEF)

    % Process: Project on default anatomy: surface
    sFilesPSD_sources_bands_relativeDEF = bst_process('CallProcess', 'process_project_sources', ...
        sFilesPSD_sources_bands_relative, [], ...
        'headmodeltype', 'surface');  % Cortex surface

    % Process: Spatial smoothing (3.00)
    bst_process('CallProcess', 'process_ssmooth_surfstat', ...
        sFilesPSD_sources_bands_relativeDEF, [], ...
        'fwhm',      3, ...
        'overwrite', 1);

end

catch me
 disp (strcat('*Error', me.message));% ERROR
end
end

% Save and display report
ReportFile = bst_report('Save', sFiles0);
bst_report('Open', ReportFile);
bst_report('Export', ReportFile, mydirBST);


clear