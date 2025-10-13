# Core ML Models Documentation

This document outlines the input and output specifications for the Core ML models used in the LiveCapture project. All models share a consistent interface.

## Models

The following models are included in the project:

- `AdacropRLModel_final_fp16.mlpackage`
- `AdacropRLModel_final_fp32.mlpackage`
- `Stu_model_final_fp16.mlpackage`
- `Stu_model_final_fp32.mlpackage`

## Model Interface

All models have the same input and output structure.

### Inputs

The models expect two inputs:

1.  **`img_tensor`**:
    -   **Type**: `MultiArray (Float32)`
    -   **Shape**: `[1, 3, 224, 224]`
    -   **Description**: This is the primary image input to the model. The shape corresponds to a batch size of 1, 3 color channels (RGB), and a resolution of 224x224 pixels.

2.  **`state_workaround`**:
    -   **Type**: `MultiArray (Float32)`
    -   **Shape**: `[1, 4]`
    -   **Description**: This input provides additional state information to the model.

### Outputs

The models produce two outputs:

1.  **`value`**:
    -   **Type**: `MultiArray (Float32)`
    -   **Shape**: `[1, 1]`
    -   **Description**: A single floating-point value, likely representing an evaluation or a state value in a reinforcement learning context.

2.  **`action_probs`**:
    -   **Type**: `MultiArray (Float32)`
    -   **Shape**: `[1, 11]`
    -   **Description**: A vector of 11 floating-point values, representing the probability distribution over a set of possible actions.
