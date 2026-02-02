#include <flutter/runtime_effect.glsl>

uniform vec2 resolution;
uniform vec4 iMouse;
uniform sampler2D image;

#define pi 3.14159265359
#define radius 0.1
#define shadowWidth 0.05
#define TRANSPARENT vec4(0.0, 0.0, 0.0, 0.0)

out vec4 fragColor;

float calShadow(vec2 targetPoint, float aspect){
    if (targetPoint.y>=1.0){
        return max(pow(clamp((targetPoint.y-1.0)/shadowWidth, 0.0, 0.9), 0.2), pow(clamp((targetPoint.x-aspect)/shadowWidth, 0.0, 0.9), 0.2));
    } else {
        return max(pow(clamp((0.0-targetPoint.y)/shadowWidth, 0.0, 0.9), 0.2), pow(clamp((targetPoint.x-aspect)/shadowWidth, 0.0, 0.9), 0.2));
    }
}

vec2 rotate(vec2 v, float a) {
    float s = sin(a);
    float c = cos(a);
    return vec2(c * v.x - s * v.y, s * v.x + c * v.y);
}

vec2 pointOnCircle(vec2 center, vec2 startPoint, float currentRadius, float arcLength, bool clockwise) {
    float theta = arcLength / currentRadius;
    vec2 startVec = startPoint - center;
    startVec = normalize(startVec);
    float rotationAngle = clockwise ? -theta : theta;
    vec2 rotatedVec = rotate(startVec, rotationAngle);
    vec2 endPoint = center + rotatedVec * currentRadius;
    return endPoint;
}

void main() {
    vec2 fragCoord = FlutterFragCoord().xy;
    float aspect = resolution.x / resolution.y;
    vec2 uv = fragCoord * vec2(aspect, 1.0) / resolution.xy;
    vec4 currentMouse = iMouse;
    
    // iMouse: x=touchX, y=touchY, z=cornerX, w=cornerY
    // Determine curl direction: if cornerX > width/2, it's Right-to-Left (Next Page).
    // Else it's Left-to-Right (Prev Page).
    bool isRightCurl = (currentMouse.z > resolution.x / 2.0);
    
    // cornerFrom: The corner where curl starts.
    // If RightCurl: x=aspect. If LeftCurl: x=0.0.
    float cornerX = isRightCurl ? aspect : 0.0;
    vec2 cornerFrom = vec2(cornerX, (currentMouse.w < resolution.y/2.0) ? 0.0 : 1.0);
    
    // Spine (Binding edge):
    // If RightCurl (Next Page), spine is at x=0.0.
    // If LeftCurl (Prev Page), spine is at x=aspect (because PrevPage comes from Left covering Current, 
    // wait... logical spine for PrevPage curl is the Right edge? 
    // Actually, "Prev Page" animation is: A new page enters from Left.
    // So its "Spine" (unmoving part) is the RIGHT edge of the screen?
    // Let's think: When we turn to Prev, we grab the Left edge of the NEW page and pull it Right.
    // So the "Spine" is the Right edge. YES.
    vec2 spineAnchor = vec2(isRightCurl ? 0.0 : aspect, cornerFrom.y==0.0?0.0:1.0);

    // 归一化鼠标坐标
    vec2 mouse = currentMouse.xy * vec2(aspect, 1.0) / resolution.xy;
    
    // 鼠标位置跟 Spine 的距离大于 aspect，才会发生翻页范围大于屏幕 (Page Detachment Constraint)
    // distance from mouse to SpineAnchor's X-line.
    // Spine line is x=0 (RightCurl) or x=aspect (LeftCurl).
    // Simply: distance(mouse.xy, spineAnchor) > aspect ?
    if (distance(mouse.xy, spineAnchor) > aspect) {
        vec2 startPoint = spineAnchor;
        vec2 vector = normalize(vec2(0.5, 0.5*tan(pi/3.0))); 
        // For LeftCurl, vector x direction might need inversion? 
        // Logic below assumes startPoint is (0,y). If startPoint is (aspect,y), vector x should be -0.5?
        // Let's generalize.
        // Actually the constraint logic tries to keep the page attached.
        // Juejin code assumes startPoint=(0,y).
        // Let's transform mouse to "Standard Space" (RightCurl) for calculation, then transform back?
        // Or just adapt the math.
        
        // Let's skip the complex constraint adaptation for now and stick to simple clamping if safe,
        // or just apply it only for RightCurl.
        // For LeftCurl, let's try to mirroring the X for calculation.
        
        vec2 calcMouse = mouse;
        if (!isRightCurl) calcMouse.x = aspect - calcMouse.x;
        
        vec2 calcStart = vec2(0.0, cornerFrom.y==0.0?0.0:1.0); // Standard Binding at 0
        
        // ... (Original Logic with calcMouse) ...
        vec2 targetMouse = calcMouse;
        vec2 v = targetMouse - calcStart;
        float proj_length = dot(v, vector);
        vec2 targetMouse_proj = calcStart + proj_length*vector;
        
        float base_line_distance = length(targetMouse_proj - targetMouse);
        float arc_distance = distance(targetMouse, calcStart) - aspect;
        float actual_distance = min(abs(base_line_distance), abs(arc_distance));
        
        vec2 currentMouse_arc_proj = calcStart + normalize(calcMouse - calcStart)*aspect;
        vec2 newPoint_arc_proj = pointOnCircle(calcStart, currentMouse_arc_proj, aspect, actual_distance/2.0, calcMouse.y<=tan(pi/3.0)*calcMouse.x); // approx tan check
        
        calcMouse = newPoint_arc_proj;
        
        // Transform back
        if (!isRightCurl) calcMouse.x = aspect - calcMouse.x;
        mouse = calcMouse;

        currentMouse.xy = mouse * resolution.xy / vec2(aspect, 1.0);
    }
    
    // 鼠标方向的向量
    vec2 mouseDir = normalize(abs(cornerFrom * resolution.xy / vec2(aspect, 1.0)) - currentMouse.xy);
    
    // 翻页辅助计算点起点
    vec2 origin = clamp(mouse - mouseDir * mouse.x / mouseDir.x, 0.0, 1.0);
    
    // 鼠标辅助计算距离
    float mouseDist = distance(mouse, origin);
    if (mouseDir.x < 0.0) {
        mouseDist = distance(mouse, origin);
    }
    
    float proj = dot(uv - origin, mouseDir);
    float dist = proj - (mouse.x<0.0 ? -mouseDist : mouseDist);
    
    vec2 curlAxisLinePoint = uv - dist * mouseDir;
    
    // 让翻页页脚能跟随触摸点
    float actualDist = distance(mouse, cornerFrom);
    if (actualDist >= pi*radius) {
        float params = (actualDist - pi*radius)/2.0;
        curlAxisLinePoint += params * mouseDir;
        dist -= params;
    }
    
    if (dist > radius) {
        fragColor = vec4(0.0, 0.0, 0.0, (1.0 - pow(clamp((dist - radius)*pi, 0.0, 1.0), 0.2)));
    } else if (dist >= 0.0) {
        // map to cylinder point
        float theta = asin(dist / radius);
        vec2 p2 = curlAxisLinePoint + mouseDir * (pi - theta) * radius;
        vec2 p1 = curlAxisLinePoint + mouseDir * theta * radius;
        
        if (p2.x <= aspect && p2.y <= 1.0 && p2.x > 0.0 && p2.y > 0.0) {
            uv = p2;
            fragColor = texture(image, uv * vec2(1.0 / aspect, 1.0));
            fragColor.rgb = mix(fragColor.rgb, vec3(1.0), 0.05);
            fragColor.rgb *= pow(clamp((radius - dist) / radius, 0.0, 1.0), 0.2);
        } else {
            uv = p1;
            fragColor = texture(image, uv * vec2(1.0 / aspect, 1.0));
            if (p2.x <= aspect+shadowWidth && p2.y <= 1.0+shadowWidth && p2.x > 0.0-shadowWidth && p2.y > 0.0-shadowWidth) {
                float shadow = calShadow(p2, aspect);
                fragColor = vec4(fragColor.r*shadow, fragColor.g*shadow, fragColor.b*shadow, fragColor.a);
            }
        }
    } else {
        vec2 p = curlAxisLinePoint + mouseDir * (abs(dist) + pi * radius);
        if (p.x <= aspect && p.y <= 1.0 && p.x > 0.0 && p.y > 0.0) {
            uv = p;
            fragColor = texture(image, uv * vec2(1.0 / aspect, 1.0));
            fragColor.rgb = mix(fragColor.rgb, vec3(1.0), 0.05);
        } else {
            fragColor = texture(image, uv * vec2(1.0 / aspect, 1.0));
            if (p.x <= aspect+shadowWidth && p.y <= 1.0+shadowWidth && p.x > 0.0-shadowWidth && p.y > 0.0-shadowWidth) {
                float shadow = calShadow(p, aspect);
                fragColor = vec4(fragColor.r*shadow, fragColor.g*shadow, fragColor.b*shadow, fragColor.a);
            }
        }
    }
    
    if (distance(uv, vec2(0.0)) > (aspect-0.001) && distance(uv, vec2(0.0)) < (aspect+0.001)) {
        fragColor = TRANSPARENT;
    }
}
