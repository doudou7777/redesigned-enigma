clc;clear
restoredefaultpath
addpath(genpath('D:\Zhao_project\iHarbour\NODDI\nifti_matlab-master'));
addpath(genpath('D:\Zhao_project\iHarbour\NODDI\NODDI_toolbox_v1.04'));
subfolderNames = dir('D:\Zhao_project\iHarbour_project_classified/*');  
cd D:\Zhao_project\iHarbour_project_classified
sub_number = length(subfolderNames)-2;
h = waitbar(0, 'processing...');
for i = 3:length(subfolderNames)  
    j = i-2;
    subfolder = subfolderNames(i).name;  
    cd(fullfile(subfolder,'dti','DTI','preprocess'));
    CreateROI('dwi_denoised_unringed_preproc_unbiased.nii','dwi_brain_mask.nii','NODDI.mat')
    protocol = FSL2Protocol('dwi_denoised_unringed_preproc_unbiased.bval','dwi_denoised_unringed_preproc_unbiased.bvec')
    noddi = MakeModel('WatsonSHStickTortIsoV_B0')
    batch_fitting('NODDI.mat',protocol,noddi,'FittedParams.mat',24)
    SaveParamsAsNIfTI('FittedParams.mat','NODDI.mat','b0_brain_mask.nii','NODDI')
    waitbar(j / sub_number, h, sprintf('processing: %d/%d', j, sub_number));
    cd ..
end
close(h);