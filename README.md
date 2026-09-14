# sobel_3x3_core_axis

A **3x3 Sobel Edge Detection** HDL IP core featuring an **AXI4-Stream** video interface for real-time image processing in Xilinx FPGAs.

## Gradient Computation

The sliding 3x3 pixel matrix is formatted as follows:

$$
P = \begin{bmatrix}
P1 & P4 & P7 \\
P2 & P5 & P8 \\
P3 & P6 & P9
\end{bmatrix}
$$

The horizontal ($G_x$) and vertical ($G_y$) gradients are two images which at each point contain the horizontal and vertical derivative approximations respectively. Their computations are as follows:

$$
Gx = \begin{bmatrix}
-1 & 0 & +1 \\
-2 & 0 & +2 \\
-1 & 0 & +1
\end{bmatrix} * P
$$

$$
Gy = \begin{bmatrix}
-1 & -2 & -1 \\
 0 &  0 &  0 \\
+1 & +2 & +1
\end{bmatrix} * P
$$

## Gradient Magnitude Approximation

To avoid computationally expensive square root hardware ($\sqrt{G_x^2 + G_y^2}$), the core uses a fixed-point **Alpha Max Linear Approximation**: 

$$|G| \approx \max(|G_x|, |G_y|) + 0.375 \times \min(|G_x|, |G_y|)$$

In hardware, this is implemented without a floating-point multiplier by utilizing logic additions and structural bit-shifts ($384/1024 = 0.375$):

$$|G| \approx \max(|G_x|, |G_y|) + \left(384 \times \min(|G_x|, |G_y|)\right) \gg 10$$

## Interface Signals

| Signal Name | Direction | Description |
| :--- | :---: | :--- |
| `aclk` | Input | Clock signal |
| `aresetn` | Input | Active-Low Reset |
| `enable` | Input | Enable sobel edge detection |
| ---------------- | ----- | -------------------------------|
| `s_axis_tdata` | Input | Input Video Pixel Data |
| `s_axis_tvalid` | Input | Input Data Valid |
| `s_axis_tready` | Output | Core Ready for Input |
| `s_axis_tuser` | Input | Start of Frame (SOF) |
| `s_axis_tlast` | Input | End of Line (EOL) |
| ---------------- | ----- | -------------------------------|
| `m_axis_tdata` | Output | Processed Edge Output Data |
| `m_axis_tvalid` | Output | Output Data Valid |
| `m_axis_tready` | Input | Downstream Ready for Output |
| `m_axis_tuser` | Output | Output Start of Frame |
| `m_axis_tlast` | Output | Output End of Line |

## Operational Modes
The core includes an `enable` signal that allows runtime switching between processing and bypass modes:

* **Active Mode (`enable = 1`):** The core performs real-time 3x3 Sobel edge detection on the incoming AXI-Stream video.
* **Bypass Mode (`enable = 0`):** Processing is disabled, and the input video stream is forwarded directly to the output.

*Note: To prevent visual glitches or frame corruption, changes to the `enable` signal are registered and only take effect at the next frame boundary (End of Frame).*

## Testbench
To use the testbench as provided, you will need an input frame in hex-file format named ```input_frame.hex```
