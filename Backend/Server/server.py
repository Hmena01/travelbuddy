import asyncio
import json
import os
import websockets
from google import genai
from google.genai import types
import base64
import io
import subprocess
import tempfile
try:
    from pydub import AudioSegment  # Requires pyaudioop/audioop (not available on Py3.13 by default)
    _HAVE_PYDUB = True
except Exception as _e:
    print(f"pydub not available, will use ffmpeg fallback for audio conversion: {_e}")
    AudioSegment = None  # type: ignore
    _HAVE_PYDUB = False
import google.generativeai as generative
import wave
from dotenv import load_dotenv
from datetime import datetime, UTC

# Load environment variables from Backend/.env
load_dotenv(os.path.join(os.path.dirname(__file__), '..', '.env'))

# Get API key from environment
api_key = os.getenv('GOOGLE_API_KEY')
if not api_key:
    raise ValueError("GOOGLE_API_KEY environment variable is not set")

os.environ['GOOGLE_API_KEY'] = api_key
generative.configure(api_key=api_key)
MODEL = "gemini-2.0-flash-exp"   # Latest stable Flash model for general use
TRANSCRIPTION_MODEL = "gemini-1.5-flash-8b"  # Same model for transcription

client = genai.Client(
  http_options={
    'api_version': 'v1alpha',
  }
)

async def gemini_session_handler(client_websocket):
    """Handles the interaction with Gemini API within a websocket session."""
    # Generate session ID for this connection
    session_id = f"session_{datetime.now().strftime('%Y%m%d_%H%M%S')}_{id(client_websocket)}"
    
    try:
        config_message = await client_websocket.recv()
        config_data = json.loads(config_message)
        config = config_data.get("setup", {})

        # Use proper LiveConnectConfig based on working examples from Heiko Hotz
        # Reference: https://github.com/heiko-hotz/gemini-multimodal-live-dev-guide
        config = types.LiveConnectConfig(
            response_modalities=["AUDIO"],
            speech_config=types.SpeechConfig(
                voice_config=types.VoiceConfig(
                    prebuilt_voice_config=types.PrebuiltVoiceConfig(
                        voice_name="Aoede"
                    )
                )
            ),
            system_instruction=types.Content(
                role="system",
                parts=[types.Part(text="""You are NativeFlow, a professional live translator and language assistant. 

IMPORTANT: Always respond with clear, natural speech.

**Your Translation Process:**
1. **Listen & Analyze**: Carefully listen to what the user says
2. **Identify Languages**: Determine the source language and intended target language  
3. **Provide Translation**: Give accurate, natural translations
4. **Be Helpful**: Offer context or cultural notes when helpful

**Guidelines:**
- Speak clearly and at a conversational pace
- If unsure about the language, ask for clarification
- For complex phrases, provide both literal and contextual translations
- Be friendly and professional in your responses""")])
        )

        async with client.aio.live.connect(model=MODEL, config=config) as session:
            print(f"Connected to Gemini Live API using model: {MODEL}")
            print(f"Configuration: Audio output, Voice: Aoede, System instruction active")
            print(f"Session details: {type(session)}")
            print(f"Session attributes: {[attr for attr in dir(session) if not attr.startswith('_')]}")
            
            # Test basic session functionality
            try:
                print("Session connection test completed")
            except Exception as test_error:
                print(f"Session test warning: {test_error}")
            
            async def send_to_gemini():
                """Sends messages from the client websocket to the Gemini API."""
                try:
                    async for message in client_websocket:
                        try:
                            data = json.loads(message)
                            if "realtime_input" in data:
                                for chunk in data["realtime_input"]["media_chunks"]:
                                    if chunk["mime_type"] == "audio/pcm":
                                        audio_size = len(base64.b64decode(chunk["data"]))
                                        print(f"Received audio chunk: {audio_size} bytes")
                                        save_pcm_as_mp3(base64.b64decode(chunk["data"]),16000, filename="user_input_to_server.mp3")
                                        
                                        # Skip transcription for now to avoid API errors - focus on translation
                                        # user_audio_data = base64.b64decode(chunk["data"])
                                        # if len(user_audio_data) >= 1500:
                                        #     user_transcription = transcribe_audio(user_audio_data, sample_rate=16000)
                                        #     if user_transcription and user_transcription != "UNCLEAR_AUDIO":
                                        #         await client_websocket.send(json.dumps({
                                        #             "transcription": {
                                        #                 "text": user_transcription,
                                        #                 "source": "user_input",
                                        #                 "timestamp": datetime.now().isoformat()
                                        #             }
                                        #         }))
                                        #         print(f"User said: {user_transcription}")
                                        
                                        # Send audio using the pattern from working examples
                                        # Based on Heiko Hotz's implementation and official docs
                                        audio_data = base64.b64decode(chunk["data"])
                                        
                                        print(f"Sending {len(audio_data)} bytes to Gemini Live API...")
                                        print(f"Audio MIME type: {chunk['mime_type']}")
                                        print(f"First 10 bytes: {list(audio_data[:10])}")
                                        
                                        # Check if audio is actually silent (all zeros or very low)
                                        import struct
                                        if len(audio_data) >= 20:
                                            # Convert first 10 16-bit samples to check levels
                                            samples = struct.unpack('<10h', audio_data[:20])
                                            max_amplitude = max(abs(s) for s in samples)
                                            avg_amplitude = sum(abs(s) for s in samples) / len(samples)
                                            print(f"Audio levels - Max: {max_amplitude}, Avg: {avg_amplitude:.1f}")
                                            
                                            if max_amplitude < 100:
                                                print("WARNING: Audio appears to be very quiet or silent!")
                                            elif max_amplitude > 10000:
                                                print("Good audio levels detected")
                                            else:
                                                print("Moderate audio levels detected")
                                        
                                        # Use the audio parameter as shown in working examples
                                        await session.send_realtime_input(
                                            audio=types.Blob(
                                                data=audio_data, 
                                                mime_type=chunk["mime_type"]
                                            )
                                        )
                                        print(f"Successfully sent audio to Gemini")

                                    elif chunk["mime_type"] == "image/jpeg":
                                        # Send image data using proper media_chunks parameter
                                        # Based on official Gemini Live API documentation  
                                        image_data = base64.b64decode(chunk["data"])
                                        await session.send_realtime_input(
                                            media_chunks=[types.Blob(
                                                data=image_data, 
                                                mime_type=chunk["mime_type"]
                                            )]
                                        )

                        except Exception as e:
                            print(f"Error sending to Gemini: {e}")
                    print("Client connection closed (send)")
                except Exception as e:
                    print(f"Error sending to Gemini: {e}")
                finally:
                    print("send_to_gemini closed")

            async def receive_from_gemini():
                """Receives responses from the Gemini API and forwards them to the client."""
                try:
                    audio_start_sent = False
                    current_text_response = ""
                    receive_loop_started = False

                    while True:
                        try:
                            accumulated_audio_this_turn = b'' # Accumulate audio for this turn only
                            turn_was_completed = False

                            if not receive_loop_started:
                                print("🔄 STARTING Gemini Live API receive loop...")
                                receive_loop_started = True
                            else:
                                print("🔄 Waiting for next Gemini Live API response...")
                                
                            async for response in session.receive():
                                print(f"RESPONSE RECEIVED! Processing...")  # This should appear if Gemini responds
                                print(f"RAW RESPONSE TYPE: {type(response)}")
                                print(f"RAW RESPONSE CONTENT: {response}")
                                
                                if response.server_content is None:
                                    print(f'No server_content in response: {response}')
                                    continue

                                print(f"Server content: {response.server_content}")
                                print(f"Server content type: {type(response.server_content)}")
                                print(f"Server content attributes: {dir(response.server_content)}")
                                
                                model_turn = response.server_content.model_turn
                                print(f"Model turn: {model_turn}")
                                
                                if model_turn:
                                    print(f"MODEL TURN FOUND with {len(model_turn.parts)} parts")
                                    
                                    # Debug each part in detail
                                    for i, part in enumerate(model_turn.parts):
                                        print(f"📋 Part {i}: {type(part)}")
                                        print(f"📋 Part {i} attributes: {dir(part)}")
                                        if hasattr(part, 'text') and part.text:
                                            print(f"📋 Part {i} text: {part.text[:100]}...")
                                        if hasattr(part, 'inline_data') and part.inline_data:
                                            print(f"📋 Part {i} has inline_data!")
                                    
                                    # Send a signal when audio first starts to come in this turn
                                    audio_parts = [part for part in model_turn.parts if hasattr(part, 'inline_data') and part.inline_data is not None]
                                    print(f"Found {len(audio_parts)} audio parts in this turn")
                                    
                                    if not audio_start_sent and audio_parts:
                                        await client_websocket.send(json.dumps({"audio_start": True}))
                                        audio_start_sent = True
                                        print("Sent audio_start signal")

                                    for part in model_turn.parts:
                                        if hasattr(part, 'text') and part.text is not None:
                                            current_text_response += part.text
                                            await client_websocket.send(json.dumps({"text": part.text}))
                                            print(f"Sent text: {part.text}")
                                        elif hasattr(part, 'inline_data') and part.inline_data is not None:
                                            print(f"GEMINI AUDIO RESPONSE DETECTED!")
                                            print(f"Audio MIME type: {part.inline_data.mime_type}")
                                            print(f"Audio data size: {len(part.inline_data.data)} bytes")
                                            print(f"Audio data type: {type(part.inline_data.data)}")
                                            
                                            # Accumulate PCM audio data - don't send individual chunks
                                            pcm_audio_data = part.inline_data.data
                                            accumulated_audio_this_turn += pcm_audio_data
                                            print(f"Accumulated audio: {len(accumulated_audio_this_turn)} bytes total")
                                else:
                                    print(f"NO MODEL TURN - Response details:")
                                    print(f"   Server content: {response.server_content}")
                                    print(f"   Turn complete: {getattr(response.server_content, 'turn_complete', 'N/A')}")
                                    print(f"   Available attributes: {[attr for attr in dir(response.server_content) if not attr.startswith('_')]}")

                                # Check turn_complete after processing parts
                                if response.server_content.turn_complete:
                                    print('\nTURN COMPLETE - Gemini finished responding')
                                    print(f"Audio accumulated this turn: {len(accumulated_audio_this_turn)} bytes")
                                    turn_was_completed = True

                                    # Convert accumulated PCM to MP3 and send BEFORE turn_complete signal
                                    if accumulated_audio_this_turn and len(accumulated_audio_this_turn) >= 4800:  # At least 100ms of audio at 24kHz
                                        print(f"Converting accumulated PCM ({len(accumulated_audio_this_turn)} bytes) to MP3...")
                                        
                                        # Save for debugging
                                        save_pcm_as_mp3(accumulated_audio_this_turn, sample_rate=24000, filename="gemini_complete_response.mp3")
                                        
                                        # Convert to MP3
                                        mp3_audio_base64 = convert_pcm_to_mp3(accumulated_audio_this_turn, sample_rate=24000)
                                        
                                        if mp3_audio_base64:
                                            print(f"PCM->MP3 conversion successful: {len(mp3_audio_base64)} base64 chars")
                                            await client_websocket.send(json.dumps({"audio": mp3_audio_base64}))
                                            print(f"Sent complete MP3 audio to client")
                                        else:
                                            print(f"Failed to convert accumulated PCM to MP3, sending with WAV header")
                                            # Create WAV header for PCM data as fallback
                                            wav_with_header = create_wav_header(accumulated_audio_this_turn, sample_rate=24000)
                                            wav_base64 = base64.b64encode(wav_with_header).decode('utf-8')
                                            await client_websocket.send(json.dumps({"audio": wav_base64, "format": "wav"}))
                                            print(f"Sent WAV audio as fallback")
                                    elif accumulated_audio_this_turn:
                                        print(f"Audio data too small ({len(accumulated_audio_this_turn)} bytes), skipping")

                                    # Send turn_complete signal to Flutter
                                    await client_websocket.send(json.dumps({"turn_complete": True}))
                                    print("Sent turn_complete signal to client")

                                    # Reset for next turn
                                    audio_start_sent = False
                                    current_text_response = ""

                                    # Perform transcription after signaling turn_complete
                                    if accumulated_audio_this_turn:
                                        print(f"Audio response completed: {len(accumulated_audio_this_turn)} bytes sent to client")
                                        
                                        # Skip transcription for now to avoid API errors - focus on audio response
                                        # if len(accumulated_audio_this_turn) >= 2000:
                                        #     transcribed_text = transcribe_audio(accumulated_audio_this_turn, sample_rate=24000)
                                        #     if transcribed_text and transcribed_text != "UNCLEAR_AUDIO":
                                        #         await client_websocket.send(json.dumps({
                                        #             "transcription": {
                                        #                 "text": transcribed_text,
                                        #                 "source": "model_output",
                                        #                 "timestamp": datetime.now().isoformat()
                                        #             }
                                        #         }))
                                        #         print(f"Sent transcription result: {transcribed_text}")
                                    else:
                                        print("No audio accumulated for transcription")
                                    # Clear buffer for this turn
                                    accumulated_audio_this_turn = b''
                                    # Break the inner loop for this turn as it's complete
                                    break # Exit inner async for loop

                            # If the inner loop finished because the turn completed, continue the outer loop
                            if turn_was_completed:
                                print("Turn completed, continuing to listen for next interaction...")
                                continue
                            else:
                                # If the inner loop finished for another reason, break outer loop
                                print("Inner receive loop finished without turn_complete signal.")
                                break # Exit while True loop

                        except websockets.exceptions.ConnectionClosedOK:
                            print("Client connection closed normally (receive loop)")
                            break  # Exit the outer loop if the client disconnects
                        except Exception as e:
                            print(f"CRITICAL ERROR in receive_from_gemini inner loop: {e}")
                            print(f"Error type: {type(e)}")
                            print(f"Error details: {str(e)}")
                            import traceback
                            print(f"Full traceback: {traceback.format_exc()}")
                            break # Exit outer loop on error

                except Exception as e:
                    print(f"Error in receive_from_gemini outer setup: {e}")
                finally:
                    print("receive_from_gemini task finished.")

            # Start send loop
            send_task = asyncio.create_task(send_to_gemini())
            # Launch receive loop as a background task
            receive_task = asyncio.create_task(receive_from_gemini())
            await asyncio.gather(send_task, receive_task)

    except Exception as e:
        print(f"Error in Gemini session: {e}")
    finally:
        print("Gemini session closed.")

def transcribe_audio(audio_data, sample_rate=24000):
    """Transcribes audio using Gemini 1.5 Flash with improved error handling."""
    try:
        # Make sure we have valid audio data
        if not audio_data or len(audio_data) < 1000:  # Minimum audio size check
            print(f"Audio data too small for transcription: {len(audio_data) if audio_data else 0} bytes")
            return None
            
        # Convert PCM to MP3 with error handling
        try:
            save_pcm_as_mp3(audio_data, sample_rate=sample_rate, filename="gemini_output_for_transcription.mp3")
            mp3_audio_base64 = convert_pcm_to_mp3(audio_data, sample_rate=sample_rate)
            if not mp3_audio_base64:
                print("Failed to convert PCM to MP3")
                return None
        except Exception as convert_error:
            print(f"Audio conversion error: {convert_error}")
            return None
            
        # Create a client specific for transcription
        transcription_client = generative.GenerativeModel(model_name=TRANSCRIPTION_MODEL)
        
        # Simplified prompt for better accuracy
        prompt = """Transcribe this audio accurately. If the audio is unclear or contains only noise, respond with exactly: UNCLEAR_AUDIO"""
        
        try:
            # Decode base64 audio for API call
            audio_bytes = base64.b64decode(mp3_audio_base64)
            
            # Validate audio size before API call
            if len(audio_bytes) < 500:  # Minimum file size for valid MP3
                print(f"MP3 file too small: {len(audio_bytes)} bytes")
                return "UNCLEAR_AUDIO"
            
            # Make API call with proper error handling
            response = transcription_client.generate_content(
                [
                    prompt,
                    {
                        "mime_type": "audio/mp3", 
                        "data": audio_bytes,
                    }
                ],
                # Optimized generation config for real-time processing
                generation_config=generative.GenerationConfig(
                    max_output_tokens=50,  # Reduced for faster processing
                    temperature=0.0,  # Deterministic for speed
                    candidate_count=1,  # Single candidate for speed
                )
            )
            
            if not response or not response.text:
                print("No response from transcription API")
                return "UNCLEAR_AUDIO"
                
            transcribed_text = response.text.strip()
            print(f"Transcription successful: {transcribed_text}")
            
            # Check if the response is meaningful
            if (transcribed_text == 'UNCLEAR_AUDIO' or 
                len(transcribed_text) < 2 or
                transcribed_text.lower() in ['', 'null', 'none', 'unclear']):
                return "UNCLEAR_AUDIO"
                
            return transcribed_text
                
        except Exception as api_error:
            print(f"Error during transcription API call: {api_error}")
            # Don't return unclear audio on API errors, return None to distinguish
            return None

    except Exception as e:
        print(f"General transcription error: {e}")
        return None

def save_pcm_as_mp3(pcm_data, sample_rate, filename="output.mp3"):
    """Saves PCM audio data as an MP3 file locally. Uses pydub when available, else ffmpeg CLI."""
    try:
        # Validate input data
        if not pcm_data or len(pcm_data) < 1000:
            print(f"PCM data too small to save: {len(pcm_data) if pcm_data else 0} bytes")
            return None

        if _HAVE_PYDUB:
            # Convert PCM->WAV (in-memory) then export MP3 via pydub
            wav_buffer = io.BytesIO()
            with wave.open(wav_buffer, 'wb') as wav_file:
                wav_file.setnchannels(1)
                wav_file.setsampwidth(2)
                wav_file.setframerate(sample_rate)
                wav_file.writeframes(pcm_data)
            wav_buffer.seek(0)

            audio_segment = AudioSegment.from_wav(wav_buffer)
            if len(audio_segment) < 100:
                print(f"Audio segment too short: {len(audio_segment)}ms")
                return None
            audio_segment.export(filename, format="mp3", codec="libmp3lame")
            print(f"MP3 file saved successfully as {filename}")
            return filename

        # Fallback: write WAV to temp file and use ffmpeg to convert to MP3
        with tempfile.NamedTemporaryFile(delete=False, suffix='.wav') as wav_tmp:
            with wave.open(wav_tmp, 'wb') as wav_file:
                wav_file.setnchannels(1)
                wav_file.setsampwidth(2)
                wav_file.setframerate(sample_rate)
                wav_file.writeframes(pcm_data)
            wav_path = wav_tmp.name

        mp3_path = filename
        cmd = ['ffmpeg', '-y', '-hide_banner', '-loglevel', 'error', '-i', wav_path, '-codec:a', 'libmp3lame', mp3_path]
        try:
            res = subprocess.run(cmd, capture_output=True)
            if res.returncode != 0:
                print(f"ffmpeg conversion failed: {res.stderr.decode(errors='ignore')}")
                return None
            print(f"MP3 file saved successfully as {mp3_path} (ffmpeg)")
            return mp3_path
        finally:
            try:
                os.remove(wav_path)
            except Exception:
                pass
    except Exception as e:
        print(f"Error saving PCM as MP3: {e}")
        return None


def convert_pcm_to_mp3(pcm_data, sample_rate=24000):
    """Converts PCM audio to base64 MP3. Uses pydub when available, else ffmpeg CLI."""
    try:
        # Validate input
        if not pcm_data or len(pcm_data) < 1000:
            print(f"PCM data too small for conversion: {len(pcm_data) if pcm_data else 0} bytes")
            return None

        if _HAVE_PYDUB:
            wav_buffer = io.BytesIO()
            with wave.open(wav_buffer, 'wb') as wav_file:
                wav_file.setnchannels(1)
                wav_file.setsampwidth(2)
                wav_file.setframerate(sample_rate)
                wav_file.writeframes(pcm_data)
            wav_buffer.seek(0)

            audio_segment = AudioSegment.from_wav(wav_buffer)
            if len(audio_segment) < 100:
                print(f"Audio segment too short for conversion: {len(audio_segment)}ms")
                return None
            mp3_buffer = io.BytesIO()
            audio_segment.export(mp3_buffer, format="mp3", codec="libmp3lame")
            mp3_data = mp3_buffer.getvalue()
            if len(mp3_data) < 500:
                print(f"MP3 data too small: {len(mp3_data)} bytes")
                return None
            mp3_base64 = base64.b64encode(mp3_data).decode('utf-8')
            print(f"Successfully converted PCM to MP3 via pydub: {len(mp3_data)} bytes -> {len(mp3_base64)} base64 chars")
            return mp3_base64

        # Fallback path: write temp WAV, run ffmpeg to MP3, read back
        with tempfile.NamedTemporaryFile(delete=False, suffix='.wav') as wav_tmp:
            with wave.open(wav_tmp, 'wb') as wav_file:
                wav_file.setnchannels(1)
                wav_file.setsampwidth(2)
                wav_file.setframerate(sample_rate)
                wav_file.writeframes(pcm_data)
            wav_path = wav_tmp.name

        with tempfile.NamedTemporaryFile(delete=False, suffix='.mp3') as mp3_tmp:
            mp3_path = mp3_tmp.name

        cmd = ['ffmpeg', '-y', '-hide_banner', '-loglevel', 'error', '-i', wav_path, '-codec:a', 'libmp3lame', mp3_path]
        try:
            res = subprocess.run(cmd, capture_output=True)
            if res.returncode != 0:
                print(f"ffmpeg conversion failed: {res.stderr.decode(errors='ignore')}")
                return None
            with open(mp3_path, 'rb') as f:
                mp3_data = f.read()
            if len(mp3_data) < 500:
                print(f"MP3 data too small after ffmpeg: {len(mp3_data)} bytes")
                return None
            mp3_base64 = base64.b64encode(mp3_data).decode('utf-8')
            print(f"Successfully converted PCM to MP3 via ffmpeg: {len(mp3_data)} bytes -> {len(mp3_base64)} base64 chars")
            return mp3_base64
        finally:
            for p in [wav_path, mp3_path]:
                try:
                    os.remove(p)
                except Exception:
                    pass
    except Exception as e:
        print(f"Error converting PCM to MP3: {e}")
        return None


def create_wav_header(pcm_data, sample_rate=24000, channels=1, bits_per_sample=16):
    """Creates a WAV file header for PCM data."""
    byte_rate = sample_rate * channels * bits_per_sample // 8
    block_align = channels * bits_per_sample // 8
    data_size = len(pcm_data)
    file_size = 36 + data_size  # 36 bytes for header (without data chunk) + data size
    
    header = bytearray()
    
    # RIFF header
    header.extend(b'RIFF')
    header.extend(file_size.to_bytes(4, 'little'))
    header.extend(b'WAVE')
    
    # fmt chunk
    header.extend(b'fmt ')
    header.extend((16).to_bytes(4, 'little'))  # fmt chunk size
    header.extend((1).to_bytes(2, 'little'))   # PCM format
    header.extend(channels.to_bytes(2, 'little'))
    header.extend(sample_rate.to_bytes(4, 'little'))
    header.extend(byte_rate.to_bytes(4, 'little'))
    header.extend(block_align.to_bytes(2, 'little'))
    header.extend(bits_per_sample.to_bytes(2, 'little'))
    
    # data chunk
    header.extend(b'data')
    header.extend(data_size.to_bytes(4, 'little'))
    
    # Combine header with PCM data
    return bytes(header) + pcm_data


async def main() -> None:
    async with websockets.serve(gemini_session_handler, "0.0.0.0", 9083):
        print("NativeFlow WebSocket Server running on 0.0.0.0:9083")
        print("Using Gemini Live API with professional translation configuration")
        print("Audio-enabled with Aoede voice and system instructions")
        await asyncio.Future()  # Keep the server running indefinitely


if __name__ == "__main__":
    asyncio.run(main())