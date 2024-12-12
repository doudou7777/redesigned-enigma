#!/bin/bash
cd data_standard
# for sub in *
# do
#     echo $sub
#     cd $sub/dti
#     echo "convert nifti t o native format MIF"
#     mrconvert -fslgrad b0_AP.bvec b0_AP.bval b0_AP.nii.gz b0_AP.mif 
#     mrconvert -fslgrad b0_PA.bvec b0_PA.bval b0_PA.nii.gz b0_PA.mif 
#     mrconvert -fslgrad dti_1k2k_AP.bvec dti_1k2k_AP.bval dti_1k2k_AP.nii raw_dwi_AP.mif 
#     mrcat b0_PA.mif  b0_AP.mif raw_dwi_AP.mif dwi.mif
#     mkdir -p DTI/preprocess
#     mv dwi.mif DTI/preprocess
#     cd ../..
# done

echo denoising
for_each * : dwidenoise IN/dti/DTI/preprocess/dwi.mif IN/dti/DTI/preprocess/dwi_denoised.mif -nthreads 8 
echo degibbs
for_each * : mrdegibbs IN/dti/DTI/preprocess/dwi_denoised.mif IN/dti/DTI/preprocess/dwi_denoised_unringed.mif -nthreads 8 
echo extract_b0pair
for_each * : dwiextract IN/dti/DTI/preprocess/dwi_denoised_unringed.mif IN/dti/DTI/prep.rocess/b0_pair.mif -bzero -nthreads 8
echo preprocess
for_each * : dwifslpreproc IN/dti/DTI/preprocess/dwi_denoised_unringed.mif IN/dti/DTI/preprocess/dwi_denoised_unringed_preproc.mif -pe_dir AP -rpe_pair -se_epi IN/dti/DTI/preprocess/b0_pair.mif -eddy_options "--data_is_shelled --slm=linear --niter=5" -nthreads 16 
echo create_mask
for_each * : dwi2mask IN/dti/DTI/preprocess/dwi_denoised_unringed_preproc.mif IN/dti/DTI/preprocess/dwi_temp_mask.mif -nthreads 8
echo bias_correct
for_each * : dwibiascorrect ants IN/dti/DTI/preprocess/dwi_denoised_unringed_preproc.mif IN/dti/DTI/preprocess/dwi_denoised_unringed_preproc_unbiased.mif -mask IN/dti/DTI/preprocess/dwi_temp_mask.mif -nthreads 8 
echo convert_to_nifti
for_each * : mrconvert IN/dti/DTI/preprocess/dwi_denoised_unringed_preproc_unbiased.mif IN/dti/DTI/preprocess/dwi_denoised_unringed_preproc_unbiased.nii.gz -export_grad_fsl IN/dti/DTI/preprocess/dwi_denoised_unringed_preproc_unbiased.bvec IN/dti/DTI/preprocess/dwi_denoised_unringed_preproc_unbiased.bval  -nthreads 8
echo normalise
mkdir -p ../dwinormalise/dwi_input
mkdir ../dwinormalise/mask_input
for_each * : cp IN/DTI/prep/dwi_denoised_unringed_preproc_unbiased.mif ../dwinormalise/dwi_input/IN.mif
for_each * : cp IN/DTI/prep/dwi_temp_mask.mif ../dwinormalise/mask_input/IN.mif
dwinormalise group ../dwinormalise/dwi_input/ ../dwinormalise/mask_input/ ../dwinormalise/dwi_output/ ../dwinormalise/fa_template.mif ../dwinormalise/fa_template_wm_mask.mif -force
for_each ../dwinormalise/dwi_output/* : cp IN PRE/DTI/prep/dwi_denoised_unringed_preproc_unbiased_normalised.mif

for_each * : mrconvert IN/DTI/prep/dwi_denoised_unringed_preproc_unbiased_normalised.mif -coord 3 0 -axes 0,1,2 IN/DTI/prep/bzero.mif -force
for_each * : mrconvert IN/DTI/prep/bzero.mif IN/DTI/prep/bzero.nii.gz -force
for_each * : bet2 IN/DTI/prep/bzero.nii.gz IN/DTI/prep/dwi_brain -f 0.3 -m
for_each * : mrview IN/DTI/prep/dwi_denoised_unringed_preproc_unbiased_normalised.mif -overlay.load IN/DTI/prep/dwi_brain_mask.nii.gz -overlay.opacity 0.2 -mode 2 -size 2000,1200

echo generate FOD
for_each * : dwi2response tournier IN/DTI/prep/dwi_denoised_unringed_preproc_unbiased_normalised.mif IN/DTI/prep/response.txt -force
responsemean */DTI/prep/response.txt ../group_average_response.txt -force
shview ../group_average_response.txt -force
for_each * : dwi2fod csd IN/DTI/prep/dwi_denoised_unringed_preproc_unbiased_normalised.mif ../group_average_response.txt IN/DTI/prep/wmfod.mif -mask IN/DTI/prep/dwi_brain_mask.nii.gz -force
for_each * : mrview IN/DTI/prep/wmfod.mif -mode 2 -size 2000,1200

echo averge fod template
for_each * : mrconvert IN/DTI/prep/dwi_brain_mask.nii.gz IN/DTI/prep/dwi_brain_mask.mif -force
mkdir -p ../template/fod_input
mkdir ../template/mask_input
for_each * : cp IN/DTI/prep/wmfod.mif ../template/fod_input/PRE.mif
for_each * : cp IN/DTI/prep/dwi_brain_mask.mif ../template/mask_input/PRE.mif
population_template ../template/fod_input -mask_dir ../template/mask_input ../template/wmfod_template.mif -voxel_size 1.25 -scratch ../template/temp_population_template

echo trace fibure
cd ../template
mrconvert /opt/fsl/data/standard/MNI152_T1_1mm.nii.gz t1_skull.mif
mrconvert wmfod_template.mif  wmfod_template.nii.gz -force
5ttgen fsl t1_skull.mif 5tt_skull_nocoreg.mif -force
mrview 5tt_skull_nocoreg.mif
mrconvert 5tt_skull_nocoreg.mif 5tt_skull_nocoreg.nii.gz -force
fslroi 5tt_skull_nocoreg.nii.gz 5tt_skull_nocoreg_vol0.nii.gz 0 1 
fslroi 5tt_skull_nocoreg.nii.gz 5tt_skull_nocoreg_vol2.nii.gz 2 1 
fslroi wmfod_template.nii.gz wmfod_template_vol0.nii.gz 0 1
flirt -in 5tt_skull_nocoreg_vol0.nii.gz -ref /opt/fsl/data/standard/MNI152_T1_1mm_brain.nii.gz -out 5tt_skull_nocoreg_vol0_brainspc.nii.gz -omat skull2brain.mat -dof 6
fslmaths 5tt_skull_nocoreg_vol0_brainspc.nii.gz -mul /opt/fsl/data/standard/MNI152_T1_1mm_brain_mask.nii.gz 5tt_skull_nocoreg_gm.nii.gz 
flirt -in 5tt_skull_nocoreg_vol2.nii.gz -ref /opt/fsl/data/standard/MNI152_T1_1mm_brain.nii.gz -applyxfm -init skull2brain.mat -out 5tt_skull_nocoreg_wm.nii.gz 
antsRegistrationSyNQuick.sh -d 3 -f /opt/fsl/data/standard/MNI152_T1_1mm_brain.nii.gz -m wmfod_template_vol0.nii.gz -o fod2t1_ -t s -n 20
antsApplyTransforms -d 3 -i 5tt_skull_nocoreg_gm.nii.gz -o 5tt_t1coreg_gm.nii.gz -r wmfod_template_vol0.nii.gz -t [fod2t1_0GenericAffine.mat,1] -t fod2t1_1InverseWarp.nii.gz -n NearestNeighbor 
antsApplyTransforms -d 3 -i 5tt_skull_nocoreg_wm.nii.gz -o 5tt_t1coreg_wm.nii.gz -r wmfod_template_vol0.nii.gz -t [fod2t1_0GenericAffine.mat,1] -t fod2t1_1InverseWarp.nii.gz -n NearestNeighbor 
antsApplyTransforms -d 3 -i /opt/fsl/data/standard/MNI152_T1_1mm_brain_mask.nii.gz -o brain_mask_fodspc.nii.gz -r wmfod_template_vol0.nii.gz -t [fod2t1_0GenericAffine.mat,1] -t fod2t1_1InverseWarp.nii.gz 
echo extract regions
mkdir -p ../cortex_ROI_std/mask_thr50
fslmaths /opt/fsl/data/atlases/HarvardOxford/HarvardOxford-sub-maxprob-thr25-1mm.nii.gz -thr 4 -uthr 4 -bin Thal_L_std.nii.gz
fslmaths /opt/fsl/data/atlases/HarvardOxford/HarvardOxford-sub-maxprob-thr25-1mm.nii.gz -thr 15 -uthr 15 -bin Thal_R_std.nii.gz
#sensory region
fslmaths /opt/fsl/data/atlases/HarvardOxford/HarvardOxford-cort-maxprob-thr25-1mm.nii.gz -thr 17 -uthr 17 -bin ../cortex_ROI_std/mask_thr50/postcentral_mask.nii.gz
#motor region
fslmaths /opt/fsl/data/atlases/HarvardOxford/HarvardOxford-cort-maxprob-thr25-1mm.nii.gz -thr 7 -uthr 7 -bin ../cortex_ROI_std/mask_thr50/motor_mask1.nii.gz
fslmaths /opt/fsl/data/atlases/HarvardOxford/HarvardOxford-cort-maxprob-thr25-1mm.nii.gz -thr 26 -uthr 26 -bin ../cortex_ROI_std/mask_thr50/motor_mask2.nii.gz
fslmaths  ../cortex_ROI_std/mask_thr50/motor_mask1.nii.gz -add  ../cortex_ROI_std/mask_thr50/motor_mask2.nii.gz   ../cortex_ROI_std/mask_thr50/motor_mask.nii.gz
#partietal region
fslmaths /opt/fsl/data/atlases/HarvardOxford/HarvardOxford-cort-maxprob-thr25-1mm.nii.gz -thr 18 -uthr 21 -bin ../cortex_ROI_std/mask_thr50/parietal_mask1.nii.gz
fslmaths /opt/fsl/data/atlases/HarvardOxford/HarvardOxford-cort-maxprob-thr25-1mm.nii.gz -thr 30 -uthr 30 -bin ../cortex_ROI_std/mask_thr50/parietal_mask2.nii.gz
fslmaths /opt/fsl/data/atlases/HarvardOxford/HarvardOxford-cort-maxprob-thr25-1mm.nii.gz -thr 43 -uthr 43 -bin ../cortex_ROI_std/mask_thr50/parietal_mask3.nii.gz
fslmaths  ../cortex_ROI_std/mask_thr50/parietal_mask1.nii.gz -add  ../cortex_ROI_std/mask_thr50/parietal_mask2.nii.gz  -add  ../cortex_ROI_std/mask_thr50/parietal_mask3.nii.gz    ../cortex_ROI_std/mask_thr50/parietal_mask.nii.gz
#temporal region
fslmaths /opt/fsl/data/atlases/HarvardOxford/HarvardOxford-cort-maxprob-thr25-1mm.nii.gz -thr 8 -uthr 16 -bin ../cortex_ROI_std/mask_thr50/temporal_mask1.nii.gz
fslmaths /opt/fsl/data/atlases/HarvardOxford/HarvardOxford-cort-maxprob-thr25-1mm.nii.gz -thr 34 -uthr 35 -bin ../cortex_ROI_std/mask_thr50/temporal_mask2.nii.gz
fslmaths /opt/fsl/data/atlases/HarvardOxford/HarvardOxford-cort-maxprob-thr25-1mm.nii.gz -thr 37 -uthr 39 -bin ../cortex_ROI_std/mask_thr50/temporal_mask3.nii.gz
fslmaths /opt/fsl/data/atlases/HarvardOxford/HarvardOxford-cort-maxprob-thr25-1mm.nii.gz -thr 42 -uthr 42 -bin ../cortex_ROI_std/mask_thr50/temporal_mask4.nii.gz
fslmaths /opt/fsl/data/atlases/HarvardOxford/HarvardOxford-cort-maxprob-thr25-1mm.nii.gz -thr 44 -uthr 46 -bin ../cortex_ROI_std/mask_thr50/temporal_mask5.nii.gz
fslmaths  ../cortex_ROI_std/mask_thr50/temporal_mask1.nii.gz -add  ../cortex_ROI_std/mask_thr50/temporal_mask2.nii.gz  -add  ../cortex_ROI_std/mask_thr50/temporal_mask3.nii.gz  -add  ../cortex_ROI_std/mask_thr50/temporal_mask4.nii.gz  -add  ../cortex_ROI_std/mask_thr50/temporal_mask5.nii.gz  ../cortex_ROI_std/mask_thr50/temporal_mask.nii.gz
#occipital region
fslmaths /opt/fsl/data/atlases/HarvardOxford/HarvardOxford-cort-maxprob-thr25-1mm.nii.gz -thr 22 -uthr 24 -bin ../cortex_ROI_std/mask_thr50/occipital_mask1.nii.gz
fslmaths /opt/fsl/data/atlases/HarvardOxford/HarvardOxford-cort-maxprob-thr25-1mm.nii.gz -thr 31 -uthr 32 -bin ../cortex_ROI_std/mask_thr50/occipital_mask2.nii.gz
fslmaths /opt/fsl/data/atlases/HarvardOxford/HarvardOxford-cort-maxprob-thr25-1mm.nii.gz -thr 36 -uthr 36 -bin ../cortex_ROI_std/mask_thr50/occipital_mask3.nii.gz
fslmaths /opt/fsl/data/atlases/HarvardOxford/HarvardOxford-cort-maxprob-thr25-1mm.nii.gz -thr 40 -uthr 40 -bin ../cortex_ROI_std/mask_thr50/occipital_mask4.nii.gz
fslmaths /opt/fsl/data/atlases/HarvardOxford/HarvardOxford-cort-maxprob-thr25-1mm.nii.gz -thr 47 -uthr 48 -bin ../cortex_ROI_std/mask_thr50/occipital_mask5.nii.gz
fslmaths  ../cortex_ROI_std/mask_thr50/occipital_mask1.nii.gz -add  ../cortex_ROI_std/mask_thr50/occipital_mask2.nii.gz  -add  ../cortex_ROI_std/mask_thr50/occipital_mask3.nii.gz  -add  ../cortex_ROI_std/mask_thr50/occipital_mask4.nii.gz  -add  ../cortex_ROI_std/mask_thr50/occipital_mask5.nii.gz ../cortex_ROI_std/mask_thr50/occipital_mask.nii.gz
#frontal regions  
fslmaths /opt/fsl/data/atlases/HarvardOxford/HarvardOxford-cort-maxprob-thr25-1mm.nii.gz -thr 1 -uthr 6 -bin ../cortex_ROI_std/mask_thr50/frontal_mask1.nii.gz
fslmaths /opt/fsl/data/atlases/HarvardOxford/HarvardOxford-cort-maxprob-thr25-1mm.nii.gz -thr 25 -uthr 25 -bin ../cortex_ROI_std/mask_thr50/frontal_mask2.nii.gz
fslmaths /opt/fsl/data/atlases/HarvardOxford/HarvardOxford-cort-maxprob-thr25-1mm.nii.gz -thr 27 -uthr 29 -bin ../cortex_ROI_std/mask_thr50/frontal_mask3.nii.gz
fslmaths /opt/fsl/data/atlases/HarvardOxford/HarvardOxford-cort-maxprob-thr25-1mm.nii.gz -thr 33 -uthr 33 -bin ../cortex_ROI_std/mask_thr50/frontal_mask4.nii.gz
fslmaths  ../cortex_ROI_std/mask_thr50/frontal_mask1.nii.gz -add  ../cortex_ROI_std/mask_thr50/frontal_mask2.nii.gz  -add  ../cortex_ROI_std/mask_thr50/frontal_mask3.nii.gz  -add  ../cortex_ROI_std/mask_thr50/frontal_mask4.nii.gz  ../cortex_ROI_std/mask_thr50/frontal_mask.nii.gz 

antsApplyTransforms -d 3 -i Thal_L_std.nii.gz -o Thal_L_t1tofod.nii.gz -r wmfod_template_vol0.nii.gz -t [fod2t1_0GenericAffine.mat,1] -t fod2t1_1InverseWarp.nii.gz -n NearestNeighbor
antsApplyTransforms -d 3 -i Thal_R_std.nii.gz -o Thal_R_t1tofod.nii.gz -r wmfod_template_vol0.nii.gz -t [fod2t1_0GenericAffine.mat,1] -t fod2t1_1InverseWarp.nii.gz -n NearestNeighbor
fslmaths Thal_L_t1tofod.nii.gz -add Thal_R_t1tofod.nii.gz Thals_t1tofod.nii.gz #FOD模板空间的丘脑mask

echo track fibure
tckgen wmfod_template.mif wholebrain_10m.tck -seed_image Thals_t1tofod.nii.gz -seed_unidirectional -include_ordered 5tt_t1coreg_wm.nii.gz -include_ordered 5tt_t1coreg_gm.nii.gz -mask brain_mask_fodspc.nii.gz -select 10m -force
tcksift wholebrain_10m.tck wmfod_template.mif wholebrain_10m_sift_1m.tck -term_number 1m


echo find the classification
mkdir cortex_ROI_template_space
cd ../cortex_ROI_std/mask_thr50/
for_each * : antsApplyTransforms -d 3 -i IN -o ../../template/cortex_ROI_template_space/IN -r ../../template/wmfod_template_vol0.nii.gz -t [../../template/fod2t1_0GenericAffine.mat,1] -t ../../template/fod2t1_1InverseWarp.nii.gz -n NearestNeighbor
cd ../../template
mkdir tracks_by_cortex_ROIs
tckedit wholebrain_10m_sift_1m.tck tracks_by_cortex_ROIs/frontal.tck -include cortex_ROI_template_space/frontal_mask.nii.gz -force
tckedit wholebrain_10m_sift_1m.tck tracks_by_cortex_ROIs/motor.tck -include cortex_ROI_template_space/motor_mask.nii.gz -force
tckedit wholebrain_10m_sift_1m.tck tracks_by_cortex_ROIs/occipital.tck -include cortex_ROI_template_space/occipital_mask.nii.gz -force
tckedit wholebrain_10m_sift_1m.tck tracks_by_cortex_ROIs/parietal.tck -include cortex_ROI_template_space/parietal_mask.nii.gz -force
tckedit wholebrain_10m_sift_1m.tck tracks_by_cortex_ROIs/postcentral.tck -include cortex_ROI_template_space/postcentral_mask.nii.gz -force
tckedit wholebrain_10m_sift_1m.tck tracks_by_cortex_ROIs/temporal.tck -include cortex_ROI_template_space/temporal_mask.nii.gz -force
cd tracks_by_cortex_ROIs
mkdir ../tckmap_by_cortex_ROIs
mkdir ../L_tckmap_thals
mkdir ../R_tckmap_thals
mkdir ../tckmap_nii_gz
mkdir ../tckmap_thals
for_each * : tckmap IN ../tckmap_by_cortex_ROIs/PRE.mif -template ../wmfod_template_vol0.nii.gz -force
for_each * : mrconvert ../tckmap_by_cortex_ROIs/PRE.mif ../tckmap_nii_gz/PRE.nii.gz -force
for_each * : fslmaths ../tckmap_nii_gz/PRE.nii.gz -mul ../Thals_t1tofod.nii.gz ../tckmap_thals/PRE.nii.gz
for_each * : fslmaths ../tckmap_nii_gz/PRE.nii.gz -mul ../Thal_R_t1tofod.nii.gz ../R_tckmap_thals/PRE.nii.gz
for_each * : fslmaths ../tckmap_nii_gz/PRE.nii.gz -mul ../Thal_L_t1tofod.nii.gz ../L_tckmap_thals/PRE.nii.gz
cd ../tckmap_thals
find_the_biggest * biggest
mkdir ../classification
mkdir ../classification_R
mkdir ../classification_L
fslmaths biggest.nii.gz -thr 1 -uthr 1 -bin ../classification/frontal.nii.gz
fslmaths biggest.nii.gz -thr 2 -uthr 2 -bin ../classification/motor.nii.gz
fslmaths biggest.nii.gz -thr 3 -uthr 3 -bin ../classification/occipital.nii.gz
fslmaths biggest.nii.gz -thr 4 -uthr 4 -bin ../classification/parietal.nii.gz
fslmaths biggest.nii.gz -thr 5 -uthr 5 -bin ../classification/postcentral.nii.gz
fslmaths biggest.nii.gz -thr 6 -uthr 6 -bin ../classification/temporal.nii.gz
cd ../R_tckmap_thals
find_the_biggest * biggest
mkdir ../classification
fslmaths biggest.nii.gz -thr 1 -uthr 1 -bin ../classification_R/frontal.nii.gz
fslmaths biggest.nii.gz -thr 2 -uthr 2 -bin ../classification_R/motor.nii.gz
fslmaths biggest.nii.gz -thr 3 -uthr 3 -bin ../classification_R/occipital.nii.gz
fslmaths biggest.nii.gz -thr 4 -uthr 4 -bin ../classification_R/parietal.nii.gz
fslmaths biggest.nii.gz -thr 5 -uthr 5 -bin ../classification_R/postcentral.nii.gz
fslmaths biggest.nii.gz -thr 6 -uthr 6 -bin ../classification_R/temporal.nii.gz
cd ../L_tckmap_thals
find_the_biggest * biggest
mkdir ../classification
fslmaths biggest.nii.gz -thr 1 -uthr 1 -bin ../classification_L/frontal.nii.gz
fslmaths biggest.nii.gz -thr 2 -uthr 2 -bin ../classification_L/motor.nii.gz
fslmaths biggest.nii.gz -thr 3 -uthr 3 -bin ../classification_L/occipital.nii.gz
fslmaths biggest.nii.gz -thr 4 -uthr 4 -bin ../classification_L/parietal.nii.gz
fslmaths biggest.nii.gz -thr 5 -uthr 5 -bin ../classification_L/postcentral.nii.gz
fslmaths biggest.nii.gz -thr 6 -uthr 6 -bin ../classification_L/temporal.nii.gz

cd ../../data_clear
for_each * : mrconvert IN/DTI/prep/wmfod.mif -coord 3 0 -axes 0,1,2 IN/DTI/prep/wmfod_vol0.mif -force
for_each * : mrconvert IN/DTI/prep/wmfod_vol0.mif IN/DTI/prep/wmfod_vol0.nii.gz -force
for_each * : antsRegistrationSyNQuick.sh -d 3 -f ../template/wmfod_template_vol0.nii.gz -m IN/DTI/prep/wmfod_vol0.nii.gz -o IN/DTI/prep/sub2template_ -t s -n 20
for_each * : mkdir IN/DTI/prep/subregions
for_each * : mkdir IN/DTI/prep/subregions_L
for_each * : mkdir IN/DTI/prep/subregions_R
for_each * : antsApplyTransforms -d 3 -i ../template/classification/frontal.nii.gz -o IN/DTI/prep/subregions/frontal.nii.gz -r IN/DTI/prep/wmfod_vol0.nii.gz -t [IN/DTI/prep/sub2template_0GenericAffine.mat,1] -t IN/DTI/prep/sub2template_1InverseWarp.nii.gz -n NearestNeighbor
for_each * : antsApplyTransforms -d 3 -i ../template/classification/motor.nii.gz -o IN/DTI/prep/subregions/motor.nii.gz -r IN/DTI/prep/wmfod_vol0.nii.gz -t [IN/DTI/prep/sub2template_0GenericAffine.mat,1] -t IN/DTI/prep/sub2template_1InverseWarp.nii.gz -n NearestNeighbor
for_each * : antsApplyTransforms -d 3 -i ../template/classification/occipital.nii.gz -o IN/DTI/prep/subregions/occipital.nii.gz -r IN/DTI/prep/wmfod_vol0.nii.gz -t [IN/DTI/prep/sub2template_0GenericAffine.mat,1] -t IN/DTI/prep/sub2template_1InverseWarp.nii.gz -n NearestNeighbor
for_each * : antsApplyTransforms -d 3 -i ../template/classification/parietal.nii.gz -o IN/DTI/prep/subregions/parietal.nii.gz -r IN/DTI/prep/wmfod_vol0.nii.gz -t [IN/DTI/prep/sub2template_0GenericAffine.mat,1] -t IN/DTI/prep/sub2template_1InverseWarp.nii.gz -n NearestNeighbor
for_each * : antsApplyTransforms -d 3 -i ../template/classification/postcentral.nii.gz -o IN/DTI/prep/subregions/postcentral.nii.gz -r IN/DTI/prep/wmfod_vol0.nii.gz -t [IN/DTI/prep/sub2template_0GenericAffine.mat,1] -t IN/DTI/prep/sub2template_1InverseWarp.nii.gz -n NearestNeighbor
for_each * : antsApplyTransforms -d 3 -i ../template/classification/temporal.nii.gz -o IN/DTI/prep/subregions/temporal.nii.gz -r IN/DTI/prep/wmfod_vol0.nii.gz -t [IN/DTI/prep/sub2template_0GenericAffine.mat,1] -t IN/DTI/prep/sub2template_1InverseWarp.nii.gz -n NearestNeighbor
for_each * : antsApplyTransforms -d 3 -i ../template/Thals_t1tofod.nii.gz -o IN/DTI/prep/subregions/Thals.nii.gz -r IN/DTI/prep/wmfod_vol0.nii.gz -t [IN/DTI/prep/sub2template_0GenericAffine.mat,1] -t IN/DTI/prep/sub2template_1InverseWarp.nii.gz -n NearestNeighbor
for_each * : antsApplyTransforms -d 3 -i ../template/classification_L/frontal.nii.gz -o IN/DTI/prep/subregions_L/frontal.nii.gz -r IN/DTI/prep/wmfod_vol0.nii.gz -t [IN/DTI/prep/sub2template_0GenericAffine.mat,1] -t IN/DTI/prep/sub2template_1InverseWarp.nii.gz -n NearestNeighbor
for_each * : antsApplyTransforms -d 3 -i ../template/classification_L/motor.nii.gz -o IN/DTI/prep/subregions_L/motor.nii.gz -r IN/DTI/prep/wmfod_vol0.nii.gz -t [IN/DTI/prep/sub2template_0GenericAffine.mat,1] -t IN/DTI/prep/sub2template_1InverseWarp.nii.gz -n NearestNeighbor
for_each * : antsApplyTransforms -d 3 -i ../template/classification_L/occipital.nii.gz -o IN/DTI/prep/subregions_L/occipital.nii.gz -r IN/DTI/prep/wmfod_vol0.nii.gz -t [IN/DTI/prep/sub2template_0GenericAffine.mat,1] -t IN/DTI/prep/sub2template_1InverseWarp.nii.gz -n NearestNeighbor
for_each * : antsApplyTransforms -d 3 -i ../template/classification_L/parietal.nii.gz -o IN/DTI/prep/subregions_L/parietal.nii.gz -r IN/DTI/prep/wmfod_vol0.nii.gz -t [IN/DTI/prep/sub2template_0GenericAffine.mat,1] -t IN/DTI/prep/sub2template_1InverseWarp.nii.gz -n NearestNeighbor
for_each * : antsApplyTransforms -d 3 -i ../template/classification_L/postcentral.nii.gz -o IN/DTI/prep/subregions_L/postcentral.nii.gz -r IN/DTI/prep/wmfod_vol0.nii.gz -t [IN/DTI/prep/sub2template_0GenericAffine.mat,1] -t IN/DTI/prep/sub2template_1InverseWarp.nii.gz -n NearestNeighbor
for_each * : antsApplyTransforms -d 3 -i ../template/classification_L/temporal.nii.gz -o IN/DTI/prep/subregions_L/temporal.nii.gz -r IN/DTI/prep/wmfod_vol0.nii.gz -t [IN/DTI/prep/sub2template_0GenericAffine.mat,1] -t IN/DTI/prep/sub2template_1InverseWarp.nii.gz -n NearestNeighbor
for_each * : antsApplyTransforms -d 3 -i ../template/Thal_L_t1tofod.nii.gz -o IN/DTI/prep/subregions_L/Thals.nii.gz -r IN/DTI/prep/wmfod_vol0.nii.gz -t [IN/DTI/prep/sub2template_0GenericAffine.mat,1] -t IN/DTI/prep/sub2template_1InverseWarp.nii.gz -n NearestNeighbor
for_each * : antsApplyTransforms -d 3 -i ../template/classification_R/frontal.nii.gz -o IN/DTI/prep/subregions_R/frontal.nii.gz -r IN/DTI/prep/wmfod_vol0.nii.gz -t [IN/DTI/prep/sub2template_0GenericAffine.mat,1] -t IN/DTI/prep/sub2template_1InverseWarp.nii.gz -n NearestNeighbor
for_each * : antsApplyTransforms -d 3 -i ../template/classification_R/motor.nii.gz -o IN/DTI/prep/subregions_R/motor.nii.gz -r IN/DTI/prep/wmfod_vol0.nii.gz -t [IN/DTI/prep/sub2template_0GenericAffine.mat,1] -t IN/DTI/prep/sub2template_1InverseWarp.nii.gz -n NearestNeighbor
for_each * : antsApplyTransforms -d 3 -i ../template/classification_R/occipital.nii.gz -o IN/DTI/prep/subregions_R/occipital.nii.gz -r IN/DTI/prep/wmfod_vol0.nii.gz -t [IN/DTI/prep/sub2template_0GenericAffine.mat,1] -t IN/DTI/prep/sub2template_1InverseWarp.nii.gz -n NearestNeighbor
for_each * : antsApplyTransforms -d 3 -i ../template/classification_R/parietal.nii.gz -o IN/DTI/prep/subregions_R/parietal.nii.gz -r IN/DTI/prep/wmfod_vol0.nii.gz -t [IN/DTI/prep/sub2template_0GenericAffine.mat,1] -t IN/DTI/prep/sub2template_1InverseWarp.nii.gz -n NearestNeighbor
for_each * : antsApplyTransforms -d 3 -i ../template/classification_R/postcentral.nii.gz -o IN/DTI/prep/subregions_R/postcentral.nii.gz -r IN/DTI/prep/wmfod_vol0.nii.gz -t [IN/DTI/prep/sub2template_0GenericAffine.mat,1] -t IN/DTI/prep/sub2template_1InverseWarp.nii.gz -n NearestNeighbor
for_each * : antsApplyTransforms -d 3 -i ../template/classification_R/temporal.nii.gz -o IN/DTI/prep/subregions_R/temporal.nii.gz -r IN/DTI/prep/wmfod_vol0.nii.gz -t [IN/DTI/prep/sub2template_0GenericAffine.mat,1] -t IN/DTI/prep/sub2template_1InverseWarp.nii.gz -n NearestNeighbor
for_each * : antsApplyTransforms -d 3 -i ../template/Thal_R_t1tofod.nii.gz -o IN/DTI/prep/subregions_R/Thals.nii.gz -r IN/DTI/prep/wmfod_vol0.nii.gz -t [IN/DTI/prep/sub2template_0GenericAffine.mat,1] -t IN/DTI/prep/sub2template_1InverseWarp.nii.gz -n NearestNeighbor

for_each * : mrview IN/wmfod_vol0.mif -roi.load IN/subregions/Thals.nii.gz
for_each * : mrview IN/wmfod_vol0.mif -roi.load IN/subregions/frontal.nii.gz -roi.load IN/subregions/motor.nii.gz -roi.load IN/subregions/occipital.nii.gz -roi.load IN/subregions/parietal.nii.gz -roi.load IN/subregions/postcentral.nii.gz -roi.load IN/subregions/temporal.nii.gz

cd ..
bash extract_new.sh
cd data_clear
##prepare for tracking
for_each * : mkdir IN/DTI/prep/cortex_mask
for_each * : antsApplyTransforms -d 3 -i ../template/cortex_ROI_template_space/frontal_mask.nii.gz -o IN/DTI/prep/cortex_mask/frontal_mask.nii.gz -r IN/DTI/prep/wmfod_vol0.nii.gz -t [IN/DTI/prep/sub2template_0GenericAffine.mat,1] -t IN/DTI/prep/sub2template_1InverseWarp.nii.gz -n NearestNeighbor
for_each * : antsApplyTransforms -d 3 -i ../template/cortex_ROI_template_space/motor_mask.nii.gz -o IN/DTI/prep/cortex_mask/motor_mask.nii.gz -r IN/DTI/prep/wmfod_vol0.nii.gz -t [IN/DTI/prep/sub2template_0GenericAffine.mat,1] -t IN/DTI/prep/sub2template_1InverseWarp.nii.gz -n NearestNeighbor
for_each * : antsApplyTransforms -d 3 -i ../template/cortex_ROI_template_space/occipital_mask.nii.gz -o IN/DTI/prep/cortex_mask/occipital_mask.nii.gz -r IN/DTI/prep/wmfod_vol0.nii.gz -t [IN/DTI/prep/sub2template_0GenericAffine.mat,1] -t IN/DTI/prep/sub2template_1InverseWarp.nii.gz -n NearestNeighbor
for_each * : antsApplyTransforms -d 3 -i ../template/cortex_ROI_template_space/parietal_mask.nii.gz -o IN/DTI/prep/cortex_mask/parietal_mask.nii.gz -r IN/DTI/prep/wmfod_vol0.nii.gz -t [IN/DTI/prep/sub2template_0GenericAffine.mat,1] -t IN/DTI/prep/sub2template_1InverseWarp.nii.gz -n NearestNeighbor
for_each * : antsApplyTransforms -d 3 -i ../template/cortex_ROI_template_space/postcentral_mask.nii.gz -o IN/DTI/prep/cortex_mask/postcentral_mask.nii.gz -r IN/DTI/prep/wmfod_vol0.nii.gz -t [IN/DTI/prep/sub2template_0GenericAffine.mat,1] -t IN/DTI/prep/sub2template_1InverseWarp.nii.gz -n NearestNeighbor
for_each * : antsApplyTransforms -d 3 -i ../template/cortex_ROI_template_space/temporal_mask.nii.gz -o IN/DTI/prep/cortex_mask/temporal_mask.nii.gz -r IN/DTI/prep/wmfod_vol0.nii.gz -t [IN/DTI/prep/sub2template_0GenericAffine.mat,1] -t IN/DTI/prep/sub2template_1InverseWarp.nii.gz -n NearestNeighbor
for_each * : antsApplyTransforms -d 3 -i ../template/Thals_t1tofod.nii.gz -o IN/DTI/prep/Thals_t1tofod.nii.gz -r IN/DTI/prep/wmfod_vol0.nii.gz -t [IN/DTI/prep/sub2template_0GenericAffine.mat,1] -t IN/DTI/prep/sub2template_1InverseWarp.nii.gz -n NearestNeighbor
for_each * : antsApplyTransforms -d 3 -i ../template/5tt_t1coreg_wm.nii.gz -o IN/DTI/prep/5tt_t1coreg_wm.nii.gz -r IN/DTI/prep/wmfod_vol0.nii.gz -t [IN/DTI/prep/sub2template_0GenericAffine.mat,1] -t IN/DTI/prep/sub2template_1InverseWarp.nii.gz -n NearestNeighbor
for_each * : antsApplyTransforms -d 3 -i ../template/5tt_t1coreg_gm.nii.gz -o IN/DTI/prep/5tt_t1coreg_gm.nii.gz -r IN/DTI/prep/wmfod_vol0.nii.gz -t [IN/DTI/prep/sub2template_0GenericAffine.mat,1] -t IN/DTI/prep/sub2template_1InverseWarp.nii.gz -n NearestNeighbor
##tracking!!!!!!
for_each * : tckgen IN/DTI/prep/wmfod.mif IN/DTI/prep/wholebrain_0.05m.tck -seed_image IN/DTI/prep/Thals_t1tofod.nii.gz -seed_unidirectional -include_ordered IN/DTI/prep/5tt_t1coreg_wm.nii.gz -include_ordered IN/DTI/prep/5tt_t1coreg_gm.nii.gz -mask IN/DTI/prep/dwi_brain_mask.nii.gz -select 0.05m -force
for_each * : tcksift IN/DTI/prep/wholebrain_0.05m.tck IN/DTI/prep/wmfod.mif IN/DTI/prep/wholebrain_0.05m_sift_0.01m.tck -term_number 0.01m
##extract track
for_each * : mkdir IN/DTI/prep/track_from_ROI
for_each * : tckedit IN/DTI/prep/wholebrain_0.05m_sift_0.01m.tck IN/DTI/prep/track_from_ROI/L_frontal.tck -include IN/DTI/prep/cortex_mask/frontal_mask.nii.gz -include IN/DTI/prep/subregions_L/frontal.nii.gz
for_each * : tckedit IN/DTI/prep/wholebrain_0.05m_sift_0.01m.tck IN/DTI/prep/track_from_ROI/L_motor.tck -include IN/DTI/prep/cortex_mask/motor_mask.nii.gz -include IN/DTI/prep/subregions_L/motor.nii.gz
for_each * : tckedit IN/DTI/prep/wholebrain_0.05m_sift_0.01m.tck IN/DTI/prep/track_from_ROI/L_occipital.tck -include IN/DTI/prep/cortex_mask/occipital_mask.nii.gz -include IN/DTI/prep/subregions_L/occipital.nii.gz
for_each * : tckedit IN/DTI/prep/wholebrain_0.05m_sift_0.01m.tck IN/DTI/prep/track_from_ROI/L_parietal.tck -include IN/DTI/prep/cortex_mask/parietal_mask.nii.gz -include IN/DTI/prep/subregions_L/parietal.nii.gz
for_each * : tckedit IN/DTI/prep/wholebrain_0.05m_sift_0.01m.tck IN/DTI/prep/track_from_ROI/L_postcentral.tck -include IN/DTI/prep/cortex_mask/postcentral_mask.nii.gz -include IN/DTI/prep/subregions_L/postcentral.nii.gz
for_each * : tckedit IN/DTI/prep/wholebrain_0.05m_sift_0.01m.tck IN/DTI/prep/track_from_ROI/L_temporal.tck -include IN/DTI/prep/cortex_mask/temporal_mask.nii.gz -include IN/DTI/prep/subregions_L/temporal.nii.gz
for_each * : tckedit IN/DTI/prep/wholebrain_0.05m_sift_0.01m.tck IN/DTI/prep/track_from_ROI/R_frontal.tck -include IN/DTI/prep/cortex_mask/frontal_mask.nii.gz -include IN/DTI/prep/subregions_R/frontal.nii.gz
for_each * : tckedit IN/DTI/prep/wholebrain_0.05m_sift_0.01m.tck IN/DTI/prep/track_from_ROI/R_motor.tck -include IN/DTI/prep/cortex_mask/motor_mask.nii.gz -include IN/DTI/prep/subregions_R/motor.nii.gz
for_each * : tckedit IN/DTI/prep/wholebrain_0.05m_sift_0.01m.tck IN/DTI/prep/track_from_ROI/R_occipital.tck -include IN/DTI/prep/cortex_mask/occipital_mask.nii.gz -include IN/DTI/prep/subregions_R/occipital.nii.gz
for_each * : tckedit IN/DTI/prep/wholebrain_0.05m_sift_0.01m.tck IN/DTI/prep/track_from_ROI/R_parietal.tck -include IN/DTI/prep/cortex_mask/parietal_mask.nii.gz -include IN/DTI/prep/subregions_R/parietal.nii.gz
for_each * : tckedit IN/DTI/prep/wholebrain_0.05m_sift_0.01m.tck IN/DTI/prep/track_from_ROI/R_postcentral.tck -include IN/DTI/prep/cortex_mask/postcentral_mask.nii.gz -include IN/DTI/prep/subregions_R/postcentral.nii.gz
for_each * : tckedit IN/DTI/prep/wholebrain_0.05m_sift_0.01m.tck IN/DTI/prep/track_from_ROI/R_temporal.tck -include IN/DTI/prep/cortex_mask/temporal_mask.nii.gz -include IN/DTI/prep/subregions_R/temporal.nii.gz
for_each * : tckedit IN/DTI/prep/wholebrain_0.05m_sift_0.01m.tck IN/DTI/prep/track_from_ROI/T_frontal.tck -include IN/DTI/prep/cortex_mask/frontal_mask.nii.gz -include IN/DTI/prep/subregions/frontal.nii.gz
for_each * : tckedit IN/DTI/prep/wholebrain_0.05m_sift_0.01m.tck IN/DTI/prep/track_from_ROI/T_motor.tck -include IN/DTI/prep/cortex_mask/motor_mask.nii.gz -include IN/DTI/prep/subregions/motor.nii.gz
for_each * : tckedit IN/DTI/prep/wholebrain_0.05m_sift_0.01m.tck IN/DTI/prep/track_from_ROI/T_occipital.tck -include IN/DTI/prep/cortex_mask/occipital_mask.nii.gz -include IN/DTI/prep/subregions/occipital.nii.gz
for_each * : tckedit IN/DTI/prep/wholebrain_0.05m_sift_0.01m.tck IN/DTI/prep/track_from_ROI/T_parietal.tck -include IN/DTI/prep/cortex_mask/parietal_mask.nii.gz -include IN/DTI/prep/subregions/parietal.nii.gz
for_each * : tckedit IN/DTI/prep/wholebrain_0.05m_sift_0.01m.tck IN/DTI/prep/track_from_ROI/T_postcentral.tck -include IN/DTI/prep/cortex_mask/postcentral_mask.nii.gz -include IN/DTI/prep/subregions/postcentral.nii.gz
for_each * : tckedit IN/DTI/prep/wholebrain_0.05m_sift_0.01m.tck IN/DTI/prep/track_from_ROI/T_temporal.tck -include IN/DTI/prep/cortex_mask/temporal_mask.nii.gz -include IN/DTI/prep/subregions/temporal.nii.gz
