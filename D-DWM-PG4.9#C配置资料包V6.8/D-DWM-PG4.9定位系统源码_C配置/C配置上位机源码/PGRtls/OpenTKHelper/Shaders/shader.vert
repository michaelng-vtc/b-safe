// For more information on how shaders work, check out the web version of this tutorial.
// I'll include a simpler summary here.
#version 330 core

layout(location = 0) in vec3 aPosition;
layout(location = 1) in vec3 aColor;

out vec3 ourColor; // output a color to the fragment shader
uniform mat4 model;
uniform mat4 view;
uniform mat4 projection;

void main(void)
{
    // Then, we further the input texture coordinate to the output one.
    // texCoord can now be used in the fragment shader.
  
    gl_Position = vec4(aPosition, 1.0) * model * view * projection;
    ourColor = aColor;
    gl_PointSize = 7;
}