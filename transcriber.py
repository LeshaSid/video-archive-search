import static_ffmpeg
static_ffmpeg.add_paths()
import streamlit as st
from faster_whisper import WhisperModel

@st.cache_resource
def get_whisper_model():
    model = WhisperModel(
        "small",
        device="cpu",
        compute_type="int8"
    )
    return model

def transcribe_video(video_path: str, words_per_chunk=40) -> list:
    model = get_whisper_model()

    segments, info = model.transcribe(
        video_path,
        beam_size=10,
        language="ru",
        vad_filter=True,
        initial_prompt="Разговорная речь, русский язык.",
        vad_parameters={
            "threshold": 0.3, 
            "min_speech_duration_ms": 250,
            "min_silence_duration_ms": 500,
            "speech_pad_ms": 400
        }
    )

    chunks = []
    current_chunk_text = []
    current_start_time = None   
    current_word_count = 0

    for segment in segments:
        text = segment.text.strip()
        if not text:
            continue
        if current_start_time is None:
            current_start_time = segment.start

        current_chunk_text.append(text)
        current_word_count += len(text.split())
        current_end_time = segment.end

        if current_word_count >= words_per_chunk:
            joined_text = " ".join(current_chunk_text)
            chunks.append({
                "start": current_start_time,
                "end": current_end_time, 
                "text": joined_text
            })

            current_chunk_text = []
            current_start_time = None
            current_word_count = 0

    if current_chunk_text:
        joined_text = " ".join(current_chunk_text)
        chunks.append({
            "start": current_start_time,
            "end": current_end_time, 
            "text": joined_text
        })

    return chunks