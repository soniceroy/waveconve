const std = @import("std");
const c = @cImport({
    @cInclude("lv2/atom/atom.h");
    @cInclude("lv2/atom/forge.h");
    @cInclude("lv2/midi/midi.h");
});

pub fn MidiForge(comptime BufferSize: usize) type {
    return struct {
        forge: c.LV2_Atom_Forge = undefined,
        buffer: [BufferSize]u8 = undefined,

        pub fn init(map: *const c.LV2_URID_Map) MidiForge {
            var mf = MidiForge(BufferSize){};
            c.lv2_atom_forge_init(&mf.forge, map);
            return mf;
        }

        pub fn begin(self: *MidiForge, out: *c.LV2_Atom_Sequence) void {
            const atom = @ptrCast(*c.LV2_Atom, out);
            atom.size = 0;
            atom.type = 0;

            c.lv2_atom_forge_set_buffer(&self.forge, &self.buffer, BufferSize);

            var frame: c.LV2_Atom_Forge_Frame = undefined;
            _ = c.lv2_atom_forge_sequence_head(&self.forge, &frame, 0);
        }

        pub fn note_on(self: *MidiForge, time: u32, urid: c.LV2_URID, note: u8, velocity: u8) void {
            self.emit_midi(time, urid, 0x90, note, velocity);
        }

        pub fn note_off(self: *MidiForge, time: u32, urid: c.LV2_URID, note: u8) void {
            self.emit_midi(time, urid, 0x80, note, 0);
        }

        fn emit_midi(self: *MidiForge, time: u32, urid: c.LV2_URID, status: u8, data1: u8, data2: u8) void {
            var ev: [3]u8 = .{ status, data1, data2 };
            _ = c.lv2_atom_forge_frame_time(&self.forge, time);
            _ = c.lv2_atom_forge_atom(&self.forge, @sizeOf(@TypeOf(ev)), urid);
            _ = c.lv2_atom_forge_write(&self.forge, &ev, @sizeOf(@TypeOf(ev)));
            _ = c.lv2_atom_forge_pad(&self.forge, @sizeOf(@TypeOf(ev)));
        }
    };
}
