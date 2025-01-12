
# NODDI Data Processing and Thalamic Tractography

## Overview

This project contains two main scripts for processing NODDI (Neurite Orientation Dispersion and Density Imaging) data and performing thalamic tractography. The first script, `calculate_noddi_waitbar.m`, is a MATLAB script designed for batch processing of NODDI data and generating fitting parameters. The second script, `full_pipeline_of_thalamus_tracts.sh`, is a Bash script that executes a complete pipeline from data preprocessing to fiber tractography.

## Software Versions

- **MATLAB**: Version recommended: R2020b or later
- **FSL**: Version recommended: FSL 6.0 or later
- **MRtrix3**: Version recommended: MRtrix3 3.0 or later
- **ANTs**: Version recommended: ANTs 2.3 or later

## File Descriptions

### `calculate_noddi_waitbar.m`

This script is used for batch processing of NODDI data. Its main functions include:

1. **Path Setup**: Adds paths for the NODDI toolbox and NIfTI toolbox.
2. **Batch Processing**: Iterates through all subfolders in a specified directory and processes NODDI data in each subfolder.
3. **ROI Creation**: Uses the `CreateROI` function to create regions of interest (ROIs).
4. **Protocol Conversion**: Converts FSL-format bval and bvec files into NODDI protocols using the `FSL2Protocol` function.
5. **Model Fitting**: Performs NODDI model fitting using the `MakeModel` and `batch_fitting` functions.
6. **Result Saving**: Saves the fitting results in NIfTI format using the `SaveParamsAsNIfTI` function.

### `full_pipeline_of_thalamus_tracts.sh`

This script executes a complete pipeline from data preprocessing to fiber tractography. The main steps include:

1. **Data Preprocessing**:
   - Denoising (`dwidenoise`)
   - Gibbs artifact removal (`mrdegibbs`)
   - b0 image extraction (`dwiextract`)
   - Preprocessing using FSL (`dwifslpreproc`)
   - Brain mask creation (`dwi2mask`)
   - Bias field correction (`dwibiascorrect`)

2. **Data Normalization**:
   - Data normalization using `dwinormalise`.

3. **FOD (Fiber Orientation Distribution) Generation**:
   - Response function generation using `dwi2response`.
   - FOD generation using `dwi2fod`.

4. **Fiber Tractography**:
   - Whole-brain fiber tract generation using `tckgen`.
   - Fiber tract filtering using `tcksift`.

5. **Thalamic Tract Classification**:
   - Extracts specific fiber tracts based on cortical regions using `tckedit`.

6. **Result Visualization**:
   - Visualizes results using `mrview`.

## Usage Instructions

### `calculate_noddi_waitbar.m`

1. Ensure MATLAB is installed and the NODDI and NIfTI toolboxes are properly configured.
2. Run the script in MATLAB. It will automatically iterate through all subfolders in the specified directory and process the data.

### `full_pipeline_of_thalamus_tracts.sh`

1. Ensure FSL, MRtrix3, and ANTs are installed and added to the system path.
2. Run the script in the terminal. It will automatically execute the complete pipeline from data preprocessing to fiber tractography.

## Dependencies

- **MATLAB**: Required for running the `calculate_noddi_waitbar.m` script.
- **FSL**: Used for data preprocessing and some image processing tasks.
- **MRtrix3**: Used for fiber tractography and FOD generation.
- **ANTs**: Used for image registration and transformation.

## Notes

- Ensure all dependencies are correctly installed and configured.
- Before running the scripts, verify that the paths and filenames are correct.
- Due to the computational intensity of the scripts, it is recommended to run them on a high-performance computing cluster or workstation.


## License

This project is licensed under the MIT License. For more details, see the LICENSE file.
