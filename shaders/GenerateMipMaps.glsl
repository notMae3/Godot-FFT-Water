#[compute]
#version 460

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba32f, binding = 0) restrict uniform image2DArray _DisplacementTextures;
layout(rgba32f, binding = 1) restrict uniform image2DArray _DisplacementTextures_mipmap;
layout(rg32f, binding = 2) restrict uniform image2DArray _SlopeTextures;
layout(rg32f, binding = 3) restrict uniform image2DArray _SlopeTextures_mipmap;
layout(r32f, binding = 4) restrict uniform image2D _BuoyancyData;
layout(r32f, binding = 5) restrict uniform image2D _BuoyancyData_mipmap;

// Generate mipmaps by taking the average of the corresponding pixels from the higher res texture

void main() {
    int scale_factor = imageSize(_DisplacementTextures).x / imageSize(_DisplacementTextures_mipmap).x;

    ivec2 small_tex_coords = ivec2(gl_GlobalInvocationID.xy);
    ivec2 large_tex_coords = small_tex_coords * scale_factor;


    // Displacement textures
    for (int i = 0 ; i < 4 ; ++i) {
        vec4 color_sum = vec4(0.0);

        for (int y = 0 ; y < scale_factor ; ++y) {
            for (int x = 0 ; x < scale_factor ; ++x) {
                color_sum += imageLoad(_DisplacementTextures, ivec3(large_tex_coords.x + x, large_tex_coords.y + y, i));
            }
        }

        vec4 avrg_color = color_sum / pow(scale_factor, 2);
        imageStore(_DisplacementTextures_mipmap, ivec3(small_tex_coords, i), avrg_color);
    }

    // Slope textures
    for (int i = 0 ; i < 4 ; ++i) {
        vec4 color_sum = vec4(0.0);

        for (int y = 0 ; y < scale_factor ; ++y) {
            for (int x = 0 ; x < scale_factor ; ++x) {
                color_sum += imageLoad(_SlopeTextures, ivec3(large_tex_coords.x + x, large_tex_coords.y + y, i));
            }
        }

        vec4 avrg_color = color_sum / pow(scale_factor, 2);
        imageStore(_SlopeTextures_mipmap, ivec3(small_tex_coords, i), avrg_color);
    }

    // Buoyancy textures
    vec4 color_sum = vec4(0.0);

    for (int y = 0 ; y < scale_factor ; ++y) {
        for (int x = 0 ; x < scale_factor ; ++x) {
            color_sum += imageLoad(_BuoyancyData, ivec2(large_tex_coords.x + x, large_tex_coords.y + y));
        }
    }

    vec4 avrg_color = color_sum / pow(scale_factor, 2);
    imageStore(_BuoyancyData_mipmap, small_tex_coords, avrg_color);



    // // Displacement textures
    // for (int i = 0 ; i < 4 ; ++i) {
    //     vec4[4] colors;
    //     colors[0] = imageLoad(_DisplacementTextures, ivec3(large_tex_coords, i));
    //     colors[1] = imageLoad(_DisplacementTextures, ivec3(large_tex_coords + ivec2(1,0), i));
    //     colors[2] = imageLoad(_DisplacementTextures, ivec3(large_tex_coords + ivec2(0,1), i));
    //     colors[3] = imageLoad(_DisplacementTextures, ivec3(large_tex_coords + ivec2(1,1), i));

    //     vec4 avrg_color = (colors[0] + colors[1] + colors[2] + colors[3]) / 4.0;
    //     imageStore(_DisplacementTextures_mipmap, ivec3(small_tex_coords, i), avrg_color);
    // }

    // // Slope textures
    // for (int i = 0 ; i < 4 ; ++i) {
    //     vec4[4] colors;
    //     colors[0] = imageLoad(_SlopeTextures, ivec3(large_tex_coords, i));
    //     colors[1] = imageLoad(_SlopeTextures, ivec3(large_tex_coords + ivec2(1,0), i));
    //     colors[2] = imageLoad(_SlopeTextures, ivec3(large_tex_coords + ivec2(0,1), i));
    //     colors[3] = imageLoad(_SlopeTextures, ivec3(large_tex_coords + ivec2(1,1), i));

    //     vec4 avrg_color = (colors[0] + colors[1] + colors[2] + colors[3]) / 4.0;
    //     imageStore(_SlopeTextures_mipmap, ivec3(small_tex_coords, i), avrg_color);
    // }

    // // Buoyancy data
    // vec4[4] colors;
    // colors[0] = imageLoad(_BuoyancyData, large_tex_coords);
    // colors[1] = imageLoad(_BuoyancyData, large_tex_coords + ivec2(1,0));
    // colors[2] = imageLoad(_BuoyancyData, large_tex_coords + ivec2(0,1));
    // colors[3] = imageLoad(_BuoyancyData, large_tex_coords + ivec2(1,1));

    // vec4 avrg_color = (colors[0] + colors[1] + colors[2] + colors[3]) / 4.0;
    // imageStore(_BuoyancyData_mipmap, small_tex_coords, avrg_color);
}