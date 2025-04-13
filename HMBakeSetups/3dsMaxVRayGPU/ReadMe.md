# ⚙️Six-Way Volumetric Lighting Bake Setup for 3ds Max (V-Ray GPU)

A full setup scene for **Autodesk 3ds Max** using **V-Ray GPU** renderer to quickly render all required maps for **Six-Way Volumetric Lighting Shader** within a single render.

![vraygpusixwaybaker](https://github.com/user-attachments/assets/784205c3-5f4c-43ed-8506-b7738488b332)

## 📓 Steps to Use the Setup

1. Open the setup in **3ds Max 2020+** with **V-Ray GPU** installed.
2. Select the object `Volume` and set the input VDB file.
3. Position your volume in the center and hit the **Render** button.
4. In the **V-Ray Framebuffer**, select **Source : LightMix** from **Layers** and set it to **Composite**.
5. Access the **RTB**, **LBF**, **TEA**, and **Normal** channels.
6. Copy or save the composite layers for use in the shader.
7. Done!


**Created by Hamid.Memar**
