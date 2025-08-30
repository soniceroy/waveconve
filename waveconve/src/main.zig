const std = @import("std");
const MidiForge = @import("midi_forge.zig").MidiForge;

const c = @cImport({
    @cInclude("lv2/core/lv2.h");
    @cInclude("lv2/urid/urid.h");
    @cInclude("lv2/atom/atom.h");
    @cInclude("lv2/atom/forge.h");
    @cInclude("lv2/midi/midi.h");
});

const PortIndex = enum(c_uint) {
    in_l = 0,
    midi_out = 1,
    threshold = 2,
};

const URIS = struct {
    midi_MidiEvent: c.LV2_URID,
    atom_Sequence: c.LV2_URID,
};

const Plugin = struct {
    audio_in: [*]const f32 = undefined,
    midi_out: *c.LV2_Atom_Sequence = undefined,
    threshold: *const f32 = undefined,

    map: ?*const c.LV2_URID_Map = null,
    uris: URIS = undefined,

    note_on: bool = false,

    forge: MidiForge(4096) = undefined,

    pub fn instantiate(_: [*]const c.LV2_Descriptor, _: f64, _: [*]const u8, features: [*]?*const c.LV2_Feature) ?*anyopaque {
        var self = std.heap.c_allocator.create(Plugin) catch return null;
        self.* = Plugin{};

        var i: usize = 0;
        while (features[i] != null) : (i += 1) {
            const f = features[i].?;
            if (std.mem.eql(u8, std.mem.span(@ptrCast([*:0]const u8, f.URI)), "http://lv2plug.in/ns/ext/urid#map")) {
                self.map = @ptrCast(*const c.LV2_URID_Map, f.data);
            }
        }
        if (self.map == null) return null;

        const map = self.map.?;
        self.uris = URIS{
            .midi_MidiEvent = map.map.?(@ptrCast(*anyopaque, map.handle), "http://lv2plug.in/ns/ext/midi#MidiEvent"),
            .atom_Sequence = map.map.?(@ptrCast(*anyopaque, map.handle), "http://lv2plug.in/ns/ext/atom#Sequence"),
        };

        self.forge = MidiForge(4096).init(map);
        return self;
    }

    pub fn connect_port(self: *Plugin, port: c_uint, data: ?*anyopaque) void {
        switch (@intToEnum(PortIndex, port)) {
            .in_l => self.audio_in = @ptrCast([*]const f32, data),
            .midi_out => self.midi_out = @ptrCast(*c.LV2_Atom_Sequence, data),
            .threshold => self.threshold = @ptrCast(*const f32, data),
        }
    }

    pub fn run(self: *Plugin, n_samples: c_uint) void {
        const th = if (self.threshold) |p| p.* else 0.1;

        var peak: f32 = 0;
        var i: usize = 0;
        while (i < n_samples) : (i += 1) {
            const s = self.audio_in[i];
            const a = if (s >= 0) s else -s;
            if (a > peak) peak = a;
        }

        self.forge.begin(self.midi_out);

        const on_level: f32 = th;
        const off_level: f32 = th * 0.6;

        if (!self.note_on and peak > on_level) {
            self.forge.note_on(0, self.uris.midi_MidiEvent, 60, 100);
            self.note_on = true;
        } else if (self.note_on and peak < off_level) {
            self.forge.note_off(0, self.uris.midi_MidiEvent, 60);
            self.note_on = false;
        }
    }

    pub fn cleanup(self: *Plugin) void {
        std.heap.c_allocator.destroy(self);
    }
};

export fn lv2_descriptor(index: c_uint) ?*const c.LV2_Descriptor {
    if (index != 0) return null;
    const desc = struct {
        pub var d = c.LV2_Descriptor{
            .URI = "http://example.org/my-a2m",
            .instantiate = @ptrCast(c.LV2_Instantiate, Plugin.instantiate),
            .connect_port = @ptrCast(c.LV2_Connect_Port, Plugin.connect_port),
            .activate = null,
            .run = @ptrCast(c.LV2_Run, Plugin.run),
            .deactivate = null,
            .cleanup = @ptrCast(c.LV2_Cleanup, Plugin.cleanup),
            .extension_data = null,
        };
    };
    return &desc.d;
}
