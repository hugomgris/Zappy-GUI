# Zappy GUI - Devlog - 6

## Table of Contents
1. [Looking Good Has Never Been This Easy: You Just Need to Harness All Mathematical Knowledge Ever Compiled Through Human Existence](#61---looking-good-has-never-been-this-easy-you-just-need-to-harness-all-mathematical-knowledge-ever-compiled-through-human-existence)
2. [Shaders 101](#62-shaders-101)

<br>
<br>

# 6.1 - Looking Good Has Never Been This Easy: You Just Need to Harness All Mathematical Knowledge Ever Compiled Through Human Existence
The first version of this GUI was quite ugly (ngl, fr fr). I tried to go through a minimalist 3D approach, based on clean objects (mostly primitives) through my already classic CRT treatment in a post-processing pass, which resulted in something that 1) I hated, and 2) was way too commonplace in my visual design approach, in a way that didn't fit this project, nor was true to my first ambitions. Back in the first days of working in the GUI, I had a very clear vision, I wanted to design an interface that looked like a **risograph print**, something that very quickly revealed itself as hard as *insert-here-your-preffered-comparison*. Facing this situation, I did what every sane person would do in the context of this project, run far, far away, without looking back. Well, I did look back, to be fair, constantly, with weeping eyes for what this could be and was not going to be because of cowardice. Now that I'm back at it, I feel like the hiatus might have been beneficial towards this avoidance, maybe because of all the walls I hit during those months in a wide array of projects and topics, maybe because upon returning this just felt like one more of those battles that never end, one after another. Thing is, this time I decided that there were only going to be two possible outcomes: either I achieved my riso dreams of a better world, or I would just give in to failure and crawl back to wherever corner of existence I should have never come out from. Luckily, things have been going quite well, so I'm not writing from the void, and instead I come bearing cute graphic gifts. I have spent around one and a half week working in the rendering pipeline that would take the GUI to the intended aesthetic, in a code war that was very close to being too much for the specific mix that my *here* and my *now* make up to dress the torments of my day to day life. And although the shader I achieved is still a work in progress, and will stay that way at least until this GUI is set us finished (most likely longer, the amount of effort put into this and the attachment I have to the results will surely call for more experimenting, and it would be a shame if all of this was just left as a GUI implementation in a not so important project), I think this is a good time to break down the current state of its code and, more importantly, what the process was during the development. What concepts and ideas lighted the sparks, how was the general pipeline design, how did the shader code slowly come to life. We will dedicate this entire log to this, mainly for two reasons, one being that there is a lot to say, the other being that graphics programming, in general,and shader coding, in particular, is, at least in my humble opinion, a very complex field. So I really need this recap. Hope it ends up being useful to others, too. Even to you.

As I mentioned, writing shaders is no joke, or at least I stopped laughing like a 100 hours of sitting in front of the failing graphics ago. In our specific context we will be writing our shader in **Godot's shading language**, which is quite similar to **OpenGL's GLSL**. If you have never gotten into shader programming, this might not be the right entry point for you, and although I will try my best, taking some time to learn shader basics by oneself (types, uniforms, pass structure, color management, ...) might be the right call if you found yourself reading this wanting to write shaders but never having done so. My current shader code is long and complex, it has a ton of uniforms and functions, and I'm pretty sure that is messy and needs a lot of refactoring and cleanup, but I myself am in my own graphic programming journey. This is me learning, trying to help others learn along the way, so bare with me if things get out of hand, and get in touch if you have any edits, observations or any other thing you want to tell me in regards to the contents of this logs, or any other document while we're at it.

If you want/need resources regarding shader development and graphics programming, my best recommendations are [Freya Holmér's Shader Basics video](https://www.youtube.com/watch?v=kfM-yu0iQBk), [Acerol'as whole Youtube channel](https://www.youtube.com/@Acerola_t), and, specifically targetted at learning raw OpenGL, [The Cherno's OpenGL playlist](https://youtu.be/W3gAzLwfIP0?list=PLlrATfBNZ98foTJPJ_Ev03o2oq3-GGOS2), both available in youtube, and both by what are, to me, teaching superstars. Shout out to them, I own them so much. If you want to complement these with some theory, I'd say to add [Dan Hollick's Shader page in their Making Software site](https://www.makingsoftware.com/chapters/shaders), which is one of my favorite web pages in the whole world, trully love the design (those graphics and diagrams!!) and how they explain things from the ground up. And top it off with (the sadly unfinished) [Patricio Gonzalez Vivo and Jen Lowe's Book of Shaders](https://thebookofshaders.com/)

> If you're specifically working in Unity and have the money, you can also go for the [Unity Shader Bible](https://jettelly.com/store/the-unity-shaders-bible), a work in progress (actively) that, although aimed at mastering the titular engine, can be easily extrapolated to any other tool, language or approach of your choice.

<br>
<br>

# 6.2 — Shaders 101

So. Shaders. Let's talk about what they actually are before we get into the specifics of what I built, because if you've never written one, jumping straight into a multi-layered risograph rendering pipeline with noise functions and animated UV warping is going to feel less like learning and more like being pushed into the deep end of a pool without knowing how to swim.

## What Even Is a Shader

A shader is a small program that runs on your GPU. That's it. Most of the times, when you find the word "shader" out there, in the vast wild, it will refer to that piece of code doing a very specific thing: deciding what color a pixel on your screen should be. That's the whole thing. There's nothing more, trust me. Well, I guess that I should state that any given shader does this *for every pixel, every frame, all at the same time*, in parallel, which is both what makes shaders incredibly powerful and what makes thinking in them feel so alien at first. Like trying to make sense of the Matrix.

Paraphrasing a million of explanations on this topic, we could say that your CPU is a very smart worker that does tasks one after another, keeping track of a lot of context and state along the way. Your GPU is thousands of much simpler workers that each do one tiny job simultaneously, with basically no memory of anything else going on around them. When you write a shader, you're writing the instructions for one of those workers. It will be run for every pixel independently, and it cannot look at what its neighbor is doing. It just gets its coordinates, does its hellish math, and outputs a color.

This is a fundamental thing to have in mind when getting into shaders. The code is not written as a loop, but already taking into consideration that it will be executed in a loop, which means that its contents would *"just"* be directed towards the color calculation of the pixels. If going through the loop, the GPU is making calculations for the nth pixel of the output image, it will take into consideration anything we tell it to: mesh information, position, rotation; what light sources there are, what's the ambience context, where is the POV placed; what's the base color, how many effects layer on top of it, what specific conditions are taking place during the rendering. And so on, and so freaking forth.


## The Fragment Shader

There are multiple types of shaders (vertex shaders, compute shaders, geometry shaders...), but the one we care about here is the **fragment shader**, also called a pixel shader depending on the API you're using. In Godot's shading language, it lives inside a `fragment()` function, and this is where all the visual magic happens. Every time the GPU needs to render a pixel covered by your material or canvas item, it calls this function and uses whatever you write into `COLOR` as the result.

```glsl
void fragment() {
	COLOR = vec4(1.0, 0.0, 0.0, 1.0); // everything is red. This should be the first of your neverending shader journey
}
```

That's a complete, valid shader. Not a useful one, but a valid one. From here, the entire craft is about making that COLOR output increasingly interesting. Just notice that the code itself is just the `fragment()` function and a single instruction regarding the color of the pixel (full red). The looping call to this function is beyond our reach and our need for reach. We are just telling the GPU: "hey, everytime you want to draw a pixel in screen, do this, and by this I mean just paint it pure red".

Other shader types are irrelevant for us today, but just know that **vertex shaders** are also quite important, their main role being to transform vertex data — i.e., taking the existing vertices of a mesh and moving them through the rendering pipeline (from model space all the way to screen space). They don't define the mesh itself (that already exists), but instead decide where each vertex ends up on screen and what data gets passed along to the next stages. We don't need to write those in our shader because we're working in a pre-built engine that takes care of that for us. If we build a scene with a cube at 0,0,0, with no rotation and in a default status, the rendering pipeline inside Godot will take care of communicating that data to the GPU. We sort of implicitly write the vertex shader by creating, placing and editing objects in our scene. But because achieving complex results regarding *how they look* is a way more complex thing, most of the time we do need to write the fragment shader ourselves. That's life, and life's hard.

> Okay, going a little bit deeper into **vertex shaders**, we should say that this is also a for loop that goes through all the vertices of a mesh and takes care (well, *we* take care of it when writing it) of translating their global/world position into their screen position. In other words, were would this specific pixel related to that concrete mesh land in the screen after going through the necessary transformations (perspective deformation, camera position, any effects that could have an effect in this regard, ...). During this translation process, there's a **clip space** sort of in-between, which can be understood as the space where the GPU decides what is visible and what gets discarded (wouldn't make sense to try to draw anything that will not landi in the generated image, and if you think about it, how would you even do that?).
>
> **Clip space** is called lke that because the GPU actually performs clipping by either keeping, discarding or slicing a a triangle (the smallest building block of a mesh). There's complex stuff taking place in all of this, mostly a process that we can tie to what is called the **projection matrix**, the matrix containing all the necessary for the GPU to know how a mesh is positioned, projected, viewed and modeled, which looks like this:
>
> `vec4 clipPos = projection * view * model * vec4(position, 1.0);`
>
> In clip space, coordinates are still 4D (a 4-part vector), `x, y, z, w`, with the last component, `w`, which is used to determine how coordinates are scaled and ultimately what ends up visible after projection, clamping XYZ values to `-W`/`W`. And at this point, you might be asking yourself, "what the hell is `W`??? I know about `X`, `Y`, and `Z`, but nobody ever mentioned this fourth weird member of the family, WHAT IS GOING ON???". Totally normal, don't panic. `W` is just an extra coordinate for the GPU to know about projection and depth in a *mathematical way*. Just take it as a value that the GPU will use to transform the raw XYZ values into derived ones affected by how things are positioned, where they are looked from, etc. Or, put in a different way, `W` is the GPU wondering about “how much should this point shrink when projected onto the screen?”. And with an example:
>
>`A: (2, 2, ?, w = 1)   → after divide → (2, 2)`
>
>`B: (2, 2, ?, w = 2)   → after divide → (1, 1)`
>
> Both `A` and `B` have the same 2D coordinates, but their different `w` values will result in `B` being scaled further down than `A`, which in human lingo just means that we're using `w` to tell the GPU which point is "farther" in our composition.
>
> And because we're having so much fun and knowing this won't hurt us, here's how a simplified rendering pipeline looks like:
>
> 1. Model space → object’s local coordinates
>
> 2. World space → placed in the scene
>
> 3. View space → relative to the camera
>
> 4. Clip space
>
> 5. NDC (Normalized Device Coordinates) → after dividing by w
>
> 6. Screen space → pixels

> ALso, and FYI, `vertex shaders` would be the ones to use if you wanted to write, say, how a body of water moves, or how the leaves of a tree sway, or how some object is distorted in any other shape or form.

In general terms, and parafrasing Freya Holmér's video, writing shaders is fronteer discipline, closely tied to visual output (i.e., front-end related), but one that needs a low-level mindset and approach (i.e., back-end feeling). My experience is that writing in `GLSL` (Open`GL` `S`hading `L`anguage) feels like when I build stuff in C/C++, but it's applications are always tied to some front-end related tool or context (web design, game development, creative coding, etc), so having a background or at least some rudimentary knowledge in both is always welcomed. Similarly, writing in `HLSL` (`H`igh-`L`evel `S`hader `L`anguage), related to DirectX (and used, for example, in Unity), will benefit from these, and in a broad sense approaches can be easily transfered between languages and pipelines, although never a 1:1 process. 

And at this point, you might be asking what the difference is between a **shader** and a **material** in the context of an engine/tool/editor like Unity, Godot, Unreal, Blender, wherever you come from. And it all boils down to data wrapping:
- **A shader is the actual GPU program**, the code that runs on the vertex and fragment stages.
- **A material, on the other hand, is a higher-level construct that wraps that shader together with its parameters** (most of which end up being uniforms). It defines *how* a specific object uses a shader.

In a raw OpenGL context, all of this data would need to be manually provided by us (uniforms, textures, parameters, everything) directly through code (for example, if you were writing your own rendering engine in C++ over [GLFW](https://www.glfw.org/)). But in a pre-built engine, this management is abstracted away and handled through the editor. A mesh provides the per-vertex data (positions, normals, UVs, etc.), while a material provides the configuration that tells the GPU how that data should be rendered. For example, when we add a surface material to a mesh in Godot and set the `albedo` to (1.0, 0, 0), it's roughly equivalent to writing a fragment shader that outputs red. But under the hood, a lot more is happening: lighting, environment contribution, and other effects are automatically integrated into the shader pipeline.

If we want more control, we can switch to a **shader material**, assign a custom shader, and define everything ourselves (via uniforms, functions, and custom logic). Even then, depending on the setup, the engine may still inject or combine additional rendering steps (like lighting), resulting in a final color computed through a layered process. It's also **important to know** that in your regular pre-built engines, **you never add a shader directly to an object: An object always has an intermediary material that has a reference to our written shader**.

> If you are now wondering what is a `uniform`, they're just variables you set from the CPU that stay the same for all vertices or fragments during a single draw call. Hence the name. If it helps, think of it this way:
>
> `Vertex Data = each triangle's unique points`
>
> `Uniforms = global settings like: camera position, lightning, time, environment state, etc`
>
> They're also what bridges the CPU code and the GPU code in the how-do-we-control-things lane. Imagine you wanted, I don't know, have the albedo of a cube change when you move the mouse cursor around. You could wire the mouse detected position vector to a uniform color in the shader file to achieve this. Not necessarily the most practical example, but I hope it makes the point.

****** Use and propose the progressive return of values as a way of knowing what's currently happening at a specific shader code phase (kind of a visual print debugging)

## UV Coordinates

The main tool you have for knowing *where* you are as a pixel is `UV` — a two-dimensional coordinate that goes from `(0.0, 0.0)` at the top-left of your texture to `(1.0, 1.0)` at the bottom-right. It doesn't care about resolution. It doesn't care about how many actual pixels there are. It's always this normalized 0-to-1 space, and everything you do spatially in a shader is usually expressed relative to it.

```glsl
void fragment() {
    COLOR = vec4(UV.x, UV.y, 0.0, 1.0);
}
```

This gives you a gradient: black at the top-left, red towards the right, green towards the bottom, yellow at the bottom-right. You've just visualized the UV space itself. This kind of "let me see what this value looks like as a color" debug approach is something you'll do constantly, because shaders don't have print statements or debuggers. Your only output channel is the screen.

## Types and Vector Math

Shaders live and breathe in vectors. A color is a `vec4` (red, green, blue, alpha) or a `vec3` (just the color channels). A UV coordinate is a `vec2`. You'll be doing a lot of math on these — adding, multiplying, mixing — and the shader language handles it component-wise automatically, which is convenient:

```glsl
vec3 a = vec3(1.0, 0.5, 0.0);
vec3 b = vec3(0.0, 0.5, 1.0);
vec3 c = a + b; // vec3(1.0, 1.0, 1.0) — white
```

A few functions you'll see absolutely everywhere and should know before going further:

**`mix(a, b, t)`** — linearly interpolates between `a` and `b` based on `t`, where 0.0 returns `a` and 1.0 returns `b`. This is how you blend everything — colors, patterns, anything.

**`clamp(x, min, max)`** — keeps a value within a range. Essential for making sure your colors don't go below 0 or above 1, because if they do, things get weird fast.

**`smoothstep(edge0, edge1, x)`** — returns 0 if `x < edge0`, 1 if `x > edge1`, and a smooth curve in between. Think of it as a soft threshold. You'll use this constantly to create soft edges, gradients that feel natural, and blending regions instead of hard cuts.

**`fract(x)`** — returns only the fractional part of a number (everything after the decimal point). `fract(3.7)` is `0.7`. This is the secret ingredient in most noise and tiling techniques because it creates endlessly repeating 0-to-1 patterns.

**`floor(x)`** — rounds down to the nearest integer. Paired with `fract`, this is how you identify *which tile* you're in versus *where within that tile* you are — a pattern that shows up constantly in procedural texturing.

## Uniforms

A uniform is a value you pass into a shader from the outside — from your game code, from the inspector, from wherever. It's "uniform" because it stays the same for every pixel during a given draw call (as opposed to `UV`, which is different for every pixel). In Godot, you declare them at the top of the shader:

```glsl
uniform vec3 my_color = vec3(1.0, 0.0, 0.0);
uniform float my_strength = 0.5;
```

They'll show up in the material inspector automatically, which means you can tweak them in real time without recompiling anything. When you're doing visual work, this is the loop that keeps you sane: change a uniform, see the result immediately, iterate. A lot of shader development is essentially just figuring out which uniforms to expose and what ranges make them useful.

## Textures and Sampling

Most of the time your shader isn't working in a vacuum — it's processing a texture, whether that's a sprite, a screen capture, or something else entirely. You sample a texture using the `texture()` function:

```glsl
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_nearest;

void fragment() {
    vec4 pixel = texture(SCREEN_TEXTURE, UV);
    COLOR = pixel;
}
```

This reads the color at `UV` from `SCREEN_TEXTURE` and outputs it unchanged — effectively a pass-through. But now you have the original pixel color to work with, and you can start doing things to it: shift the UV before sampling to distort the image, read the color and replace it with something else based on conditions, sample the same texture at multiple nearby coordinates to fake blur or edge detection. The whole pipeline of this risograph shader is essentially: sample what's already on screen, figure out what ink color each pixel represents, and then *replace* it with a procedurally generated print texture.

## TIME and Animation

The built-in `TIME` variable gives you the elapsed time in seconds since the shader started running. Since the fragment function runs every frame, `TIME` gives you a continuously changing value, which is the hook for any animation. You can feed it into your math to make patterns drift, shimmer, or pulse over time. The key insight is that TIME itself is smooth and continuous — if you want something to *snap* between states rather than smoothly interpolate (which, as you'll see, is critical for the cel-printed feel of this particular shader), you need to discretize it yourself by rounding or flooring it.

---

That's enough groundwork to read everything that comes next without getting lost. If any of this felt too fast, the resources linked back in section 6.1 will fill in the gaps — especially Freya's video and the Book of Shaders for the math intuition side of things. If it felt too slow, hang on, because we're about to get into the actual shader, and things are going to get considerably messier.
