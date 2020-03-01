#version 110

attribute vec2 position;
attribute vec3 color;
uniform float rot_k;

void main()
{
	
	gl_Position.x = position.x*rot_k;
	gl_Position.y = position.y;
	gl_Position.z = 0.0f;
	gl_Position.w = 1.0f;
	
	gl_FrontColor.rgb = color;
	gl_FrontColor.a = 1.0f;
	
}
