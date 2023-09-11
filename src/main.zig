const std = @import("std");
const glfw = @cImport({
    @cDefine("GLFW_INCLUDE_NONE", "1");
    @cInclude("GLFW/glfw3.h");
});
const glad = @cImport({
    @cInclude("glad/glad.h");
});
const alloc = std.heap.c_allocator;

const vert_shader_source = @embedFile("shader.v.glsl");
const frag_shader_source = @embedFile("shader.f.glsl");

const Rect = struct {
    x: f32,
    y: f32,
    width: f32,
    height: f32,
};

const Vector3 = extern struct {
    x: f32,
    y: f32,
    z: f32,
};

const Color = extern struct {
    r: f32,
    g: f32,
    b: f32,
    a: f32,
};

const Vertex = extern struct {
    pos: Vector3,
    color: Color,
};

comptime {
    // For some reason this fails if the structs are packed
    // I'm really confused about it
    std.debug.assert(@sizeOf(Vector3) == 3 * @sizeOf(f32));
    std.debug.assert(@sizeOf(Color) == 4 * @sizeOf(f32));
    std.debug.assert(@sizeOf(Vertex) == (3 + 4) * @sizeOf(f32));
}

const OpenGLError = error {
    ShaderCompile,
    ShaderLink
};

fn compile_shader(src: []const u8, shader_type: glad.GLenum) OpenGLError!glad.GLuint {
    const shader = glad.glCreateShader(shader_type);
    glad.glShaderSource(shader, 1, @ptrCast(&src), null);
    glad.glCompileShader(shader);

    var success: glad.GLint = 0;
    glad.glGetShaderiv(shader, glad.GL_COMPILE_STATUS, &success);
    if (success == glad.GL_FALSE) {
        glad.glDeleteShader(shader);
        return OpenGLError.ShaderCompile;
    }

    return shader;
}

fn link_shader(vertex_shader: glad.GLuint,
               frag_shader: glad.GLuint) anyerror!glad.GLuint {
    const program = glad.glCreateProgram();
    glad.glAttachShader(program, vertex_shader);
    glad.glAttachShader(program, frag_shader);
    glad.glLinkProgram(program);

    var success: glad.GLint = 0;
    glad.glGetProgramiv(program, glad.GL_LINK_STATUS, &success);
    if (success == glad.GL_FALSE) {
        return OpenGLError.ShaderLink;
    }

    return program;
}

fn compile_and_link_shader(vert_src: []const u8,
                           frag_src: []const u8) anyerror!glad.GLuint {
    const vert_shader = try compile_shader(vert_src, glad.GL_VERTEX_SHADER);
    const frag_shader = try compile_shader(frag_src, glad.GL_FRAGMENT_SHADER);
    const program = try link_shader(vert_shader, frag_shader);
    return program;
}

const Renderer = struct {
    vao: glad.GLuint,
    vbo: glad.GLuint,
    ebo: glad.GLuint,

    vertex_data: []Vertex,
    vertex_count: usize,
    index_data: []u32,
    index_count: usize,
    shader: glad.GLuint,

    pub fn init() anyerror!Renderer {
        std.debug.print("OpenGL info:\n\tVersion: {s}\n\tGLSL Version: {s}\n\tVendor: {s}\n\tRenderer: {s}\n",
                        .{ glad.glGetString(glad.GL_VERSION),
                           glad.glGetString(glad.GL_SHADING_LANGUAGE_VERSION),
                           glad.glGetString(glad.GL_VENDOR),
                           glad.glGetString(glad.GL_RENDERER) });

        var buffers: [2]glad.GLuint = undefined;
        glad.glGenBuffers(2, &buffers);

        const vbo = buffers[0];
        const ebo = buffers[1];

        var vao: glad.GLuint = undefined;
        glad.glGenVertexArrays(1, &vao);
        glad.glBindVertexArray(vao);

        glad.glBindBuffer(glad.GL_ARRAY_BUFFER, vbo);
        glad.glBindBuffer(glad.GL_ELEMENT_ARRAY_BUFFER, ebo);

        const stride = @sizeOf(Vertex);

        glad.glVertexAttribPointer(0,
                                   3,
                                   glad.GL_FLOAT,
                                   glad.GL_FALSE,
                                   stride,
                                   null);
        glad.glEnableVertexAttribArray(0);
        glad.glVertexAttribPointer(1,
                                   3,
                                   glad.GL_FLOAT,
                                   glad.GL_FALSE,
                                   stride,
                                   @ptrFromInt(3 * @sizeOf(f32)));
        glad.glEnableVertexAttribArray(1);

        const max_triangles = 1000;
        const vertex_data = try alloc.alloc(Vertex, max_triangles * 3);
        const index_data = try alloc.alloc(u32, max_triangles * 3);

        const shader = try compile_and_link_shader(vert_shader_source,
                                                   frag_shader_source);

        return .{
            .vao = 0,
            .vbo = vbo,
            .ebo = ebo,
            .vertex_data = vertex_data,
            .vertex_count = 0,
            .index_data = index_data,
            .index_count = 0,
            .shader = shader,
        };
    }

    pub fn render_frame(self: *Renderer, render_fn: *const fn (*Renderer) void) void {
        glad.glClearColor(1.0, 0.0, 1.0, 1.0);
        glad.glClear(glad.GL_COLOR_BUFFER_BIT);

        self.vertex_data[0] = .{ .pos = .{ .x =  0.0, .y =  0.5, .z = 0.0 }, .color = .{ .r = 1.0, .g = 0.0, .b = 0.0, .a = 1.0 }};
        self.vertex_data[1] = .{ .pos = .{ .x =  0.5, .y =  -0.5, .z = 0.0 }, .color = .{ .r = 0.0, .g = 1.0, .b = 0.0, .a = 1.0 }};
        self.vertex_data[2] = .{ .pos = .{ .x =  -0.5, .y =  -0.5, .z = 0.0 }, .color = .{ .r = 0.0, .g = 0.0, .b = 1.0, .a = 1.0 }};
        self.vertex_count = 3;

        self.index_data[0] = 0;
        self.index_data[1] = 1;
        self.index_data[2] = 2;
        self.index_count = 3;

        glad.glUseProgram(self.shader);

        glad.glBufferData(glad.GL_ARRAY_BUFFER,
                          3 * @sizeOf(Vertex),
                          @ptrCast(self.vertex_data),
                          glad.GL_STATIC_DRAW);
        glad.glBufferData(glad.GL_ELEMENT_ARRAY_BUFFER,
                          3 * @sizeOf(u32),
                          @ptrCast(self.index_data),
                          glad.GL_STATIC_DRAW);

        glad.glDrawElements(glad.GL_TRIANGLES,
                            @intCast(self.index_count),
                            glad.GL_UNSIGNED_INT,
                            null);

        render_fn(self);
    }

    pub fn draw_rect(self: *Renderer, rect: Rect) void {
        _ = self;
        _ = rect;
    }
};

fn frame_fn(ren: *Renderer) void {
    _ = ren;
}

pub fn main() !void {
    if (glfw.glfwInit() == glfw.GLFW_FALSE) {
        std.debug.print("Error initializing GLFW\n", .{});
        return;
    }
    defer glfw.glfwTerminate();

    glfw.glfwWindowHint(glfw.GLFW_RESIZABLE, glfw.GLFW_FALSE);

    const window = glfw.glfwCreateWindow(640, 480, "Window title", null, null);
    if (window == null) {
        std.debug.print("Error creating window\n", .{});
        return;
    }
    glfw.glfwMakeContextCurrent(window);

    _ = glad.gladLoadGLLoader(@ptrCast(&glfw.glfwGetProcAddress));
    var ren = try Renderer.init();

    while (glfw.glfwWindowShouldClose(window) == glfw.GLFW_FALSE) {
        glfw.glfwPollEvents();

        if (glfw.glfwGetKey(window, glfw.GLFW_KEY_ESCAPE) == glfw.GLFW_PRESS) {
            break;
        }
        
        ren.render_frame(&frame_fn);

        glfw.glfwSwapBuffers(window);
    }
}
