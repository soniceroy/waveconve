pub fn simple_sound_play() -> bool {

    
    use std::fs::File;
    use std::io::BufReader;
    use std::time::Duration;
    use rodio::{Decoder, OutputStream, Sink};
    use rodio::source::{SineWave, Source};
    
    // _stream must live as long as the sink
    let (_stream, stream_handle) = OutputStream::try_default().unwrap();
    
    let sink = Sink::try_new(&stream_handle).unwrap();
    
    // Add a dummy source of the sake of the example.
    let source = SineWave::new(440.0).take_duration(Duration::from_secs_f32(0.25)).amplify(0.20);
    sink.append(source);

    // The sound plays in a separate thread. This call will block the current thread until the sink
    // has finished playing all its queued sounds.
    sink.sleep_until_end();
    sink.empty()
}




pub fn simple_midi_send() -> bool {
    use midir::MidiOutput;
    use midi_msg::{ MidiMsg, ChannelVoiceMsg, Channel };
    let channel = Channel::Ch10; 
    let note = 24;
    let velocity = 96;
    let note_on = MidiMsg::ChannelVoice { channel, msg:  ChannelVoiceMsg::NoteOn { note, velocity }
    }.to_midi();
    let note_off = MidiMsg::ChannelVoice { channel, msg: ChannelVoiceMsg::NoteOff { note, velocity}
    }.to_midi();

    let midi_output = MidiOutput::new("midi_send_test").unwrap();
    let ports = midi_output.ports();
    if ports.len() == 0 {
        false
    } else {
        let mut connection = midi_output.connect(&ports[0], "send_test_port").unwrap();
        connection.send(&note_on).unwrap();
        connection.send(&note_off).unwrap();
        true
    }

}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn play_simple_sound() {
        let finished = simple_sound_play();
        assert!(finished);
    }

    #[test]
    fn send_midi() {
        let finished: bool = simple_midi_send();
        assert!(finished);
    }
}
