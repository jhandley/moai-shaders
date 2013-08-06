local screenWidth = MOAIEnvironment.screenWidth
local screenHeight = MOAIEnvironment.screenHeight

if screenWidth == nil then screenWidth = 640 end
if screenHeight == nil then screenHeight = 480 end
local screenAspectRatio = screenWidth/screenHeight

MOAISim.openWindow ( "sphere", screenWidth, screenHeight )

viewport = MOAIViewport.new ()
viewport:setSize ( screenWidth, screenHeight )
local worldWidth = 500
viewport:setScale ( worldWidth, 0 )

layer = MOAILayer2D.new ()
layer:setViewport ( viewport )
MOAISim.pushRenderPass ( layer )
 
local vertexShader = [[
  attribute vec4 position;
  attribute vec2 uv;   
  varying vec2 v_texCoord;

  void main()                  
  {                            
     gl_Position = position; 
     v_texCoord = uv;  
  }
]]

local fragmentShader = [[
  varying vec2 v_texCoord;
  uniform sampler2D sampler;
  uniform float u_lightDir_x;  // in model coords
  uniform float u_lightDir_y;  // in model coords
  uniform float u_lightDir_z;  // in model coords
  uniform float u_diffuse; // diffuse light coefficient
  uniform float u_ambient; // ambient light coefficient
  uniform float u_specular; // specular light coefficient
  uniform float u_shine; // shininess
  uniform float u_yAxisRotationDegrees;
  const float radius = 64.0;
  const float pi = 3.14159;
  const float twopi = 3.14159*2.0;
  const float halfpi = 3.14159/2.0;
  
  float degreesToRadians(in float degrees) {
    return pi * degrees/180.0;
  }
  
  // return texture coordinates for a point on the sphere
  vec2 getTextureCoords(in vec3 p) {
    float theta = acos(p.y); // angle from y-axis
    float rr = sin(theta); // radius of sphere slice at p.y
    // acos(-p.x/rr) is angle from x-axis, add rotation about y-axis
    float phi = mod(degreesToRadians(u_yAxisRotationDegrees) + acos(clamp(-p.x/rr, -1.0, 1.0)), twopi);
    // theta ranges from 0 to pi and is mapped to range 0 to 1
    // for positive z phi ranges from 0 to pi and is mapped to 0 to 0.5 (phi/2pi)
    // for negative z phi ranges from 0 to pi and is mapped from 1 to 0.5 (1-phi/2pi)
    return vec2(float(int((1.0-sign(p.z)))/2) + sign(p.z) * phi/twopi, theta/pi);
  }
  
  // compute diffuse and specular lighting components at point p
  void lighting(in vec3 normal, out float diffuse, out float specular)
  {
    vec3 L = normalize(vec3(u_lightDir_x, u_lightDir_y, u_lightDir_z));
    diffuse = clamp(dot(L, normal),0.0, 1.0);
    vec3 halfdir = normalize (L + normal); // viewdir == normal
    float nh = max(0.0, dot(normal, halfdir));
    specular = pow(nh, u_shine);    
  }
    
  void main()
  {
    // distance squared in texture coords from point to center of sphere
    float dsq = dot(v_texCoord, v_texCoord);
    // radius of sphere in texture coords is 1 so anything bigger is outside
    if (dsq > 1.0) {
      discard;
    } else {
      // use pythag to get z of normal
      vec3 normal = vec3(v_texCoord.st, sqrt(1.0 - dsq));
      vec2 realTex = getTextureCoords(normal.xyz);
      float diffuse, specular;
      lighting(normal, diffuse, specular);
      gl_FragColor = vec4((u_ambient+u_diffuse*diffuse) * texture2D(sampler, realTex).rgb + u_specular*specular*vec3(1.0,1.0,1.0), 1.0);
      //gl_FragColor = vec4((u_ambient+diffuse*u_diffuse+specular)*vec3(1.0,1.0,1.0), 1.0);
     }
  }
]]

gfxQuad = MOAIGfxQuad2D.new ()
gfxQuad:setTexture ( "earth_no_clouds.jpg" )
gfxQuad:setRect ( -64, -64, 64, 64 )
gfxQuad:setUVRect ( -1, -1, 1, 1 )

prop = MOAIProp2D.new ()
prop:setDeck ( gfxQuad )
layer:insertProp ( prop )

shader = MOAIShader.new ()
shader:reserveUniforms ( 8 )
shader:declareUniformFloat(1, 'u_yAxisRotationDegrees', 0)
shader:declareUniformFloat(2, 'u_lightDir_x', 0)
shader:declareUniformFloat(3, 'u_lightDir_y', 0)
shader:declareUniformFloat(4, 'u_lightDir_z', 0)
shader:declareUniformFloat(5, 'u_ambient', 0.05)
shader:declareUniformFloat(6, 'u_diffuse', 0.5)
shader:declareUniformFloat(7, 'u_specular', 0.4)
shader:declareUniformFloat(8, 'u_shine', 70)

light = MOAITransform.new()
light:setLoc(-5, 3, 10)

shader:setAttrLink(2, light, MOAITransform.ATTR_X_LOC)
shader:setAttrLink(3, light, MOAITransform.ATTR_Y_LOC)
shader:setAttrLink(4, light, MOAITransform.ATTR_Z_LOC)

rotation = MOAITransform.new()
shader:setAttrLink(1, rotation, MOAITransform.ATTR_X_ROT)

shader:setVertexAttribute ( 1, 'position' )
shader:setVertexAttribute ( 2, 'uv' )
shader:load ( vertexShader, fragmentShader )

gfxQuad:setShader ( shader )

function wait ( action )
    while action:isBusy () do coroutine:yield () end
end

function threadFunc ()
    wait(rotation:moveRot(270,0,0,10, MOAIEaseType.LINEAR))
    light:moveLoc(-100, 0, 10)
    wait(light:moveLoc(200, 0, 10, 8, MOAIEaseType.LINEAR))
end

thread = MOAIThread.new ()
thread:run ( threadFunc )
