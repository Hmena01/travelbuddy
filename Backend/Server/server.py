import asyncio
import json
import os
import websockets
from google import genai
from google.genai import types
import base64
import io
from pydub import AudioSegment
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

        # Configure for audio generation with correct Gemini Live API format
        config = {
            "response_modalities": ["AUDIO"],  # Enable audio responses - at root level
            "speech_config": {
                "voice_config": {
                    "prebuilt_voice_config": {
                        "voice_name": "Aoede"  # High-quality voice
                    }
                }
            },
            "system_instruction": {
                "parts": [{
                    "text": """You are NativeFlow, a professional live translator and language assistant. 

IMPORTANT: Always respond with AUDIO. Speak your responses clearly and naturally.

**Your Translation Process:**
1. **Listen & Analyze**: Carefully listen to what the user says
2. **Identify Languages**: Determine the source language and intended target language  
3. **Provide Translation**: Give the most natural and accurate translation in AUDIO

**Response Format:**
- Always respond with SPOKEN audio
- Use authentic native pronunciation for each target language
- Speak clearly and at natural pace
- For pronunciation help, speak slower with emphasis on difficult sounds

**For Translation Requests**: 
- Acknowledge what they want to translate
- Provide the translation clearly in speech
- Use authentic native accent for that language

**For Understanding Foreign Phrases**:
- Identify the language in speech
- Provide the English meaning clearly in speech
- Add cultural context if relevant

You must ALWAYS respond with audio. Never just send text - speak your response."""
                }]
            }
        }

        async with client.aio.live.connect(model=MODEL, config=config) as session:
            print("Connected to Gemini API")

            async def send_to_gemini():
                """Sends messages from the client websocket to the Gemini API."""
                try:
                  async for message in client_websocket:
                      try:
                          data = json.loads(message)
                          if "realtime_input" in data:
                              for chunk in data["realtime_input"]["media_chunks"]:
                                  if chunk["mime_type"] == "audio/pcm":
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
                                      
                                      # Use the correct method for sending realtime audio input
                                      # According to Live API docs, audio should be sent as binary data
                                      audio_data = base64.b64decode(chunk["data"])
                                      await session.send_realtime_input(
                                          audio=types.Blob(data=audio_data, mime_type=chunk["mime_type"])
                                      )

                                  elif chunk["mime_type"] == "image/jpeg":
                                      # Use the correct method for sending realtime image input
                                      image_data = base64.b64decode(chunk["data"])
                                      await session.send_realtime_input(
                                          media_chunks=[types.Blob(data=image_data, mime_type=chunk["mime_type"])]
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

                    while True:
                        try:
                            accumulated_audio_this_turn = b'' # Accumulate audio for this turn only
                            turn_was_completed = False

                            print("Receiving from Gemini...")
                            async for response in session.receive():
                                if response.server_content is None:
                                    print(f'Unhandled server message! - {response}')
                                    continue

                                model_turn = response.server_content.model_turn
                                if model_turn:
                                    # Send a signal when audio first starts to come in this turn
                                    if not audio_start_sent and any(hasattr(part, 'inline_data') for part in model_turn.parts):
                                        await client_websocket.send(json.dumps({"audio_start": True}))
                                        audio_start_sent = True
                                        print("Sent audio_start signal")

                                    for part in model_turn.parts:
                                        if hasattr(part, 'text') and part.text is not None:
                                            current_text_response += part.text
                                            await client_websocket.send(json.dumps({"text": part.text}))
                                            print(f"Sent text: {part.text}")
                                        elif hasattr(part, 'inline_data') and part.inline_data is not None:
                                            print("audio mime_type:", part.inline_data.mime_type)
                                            base64_audio = base64.b64encode(part.inline_data.data).decode('utf-8')

                                            await client_websocket.send(json.dumps({"audio": base64_audio}))

                                            # get the audio data after this turn 
                                            accumulated_audio_this_turn += part.inline_data.data

                                            print(f"Sent audio chunk: {len(part.inline_data.data)} bytes")

                                # Check turn_complete after processing parts
                                if response.server_content.turn_complete:
                                    print('\n<Turn complete signal received from Gemini>')
                                    turn_was_completed = True

                                    # Send turn_complete signal to Flutter immediately
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
                            print(f"Error in receive_from_gemini inner loop: {e}")
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
    """Saves PCM audio data as an MP3 file locally with improved error handling."""
    try:
        # Validate input data
        if not pcm_data or len(pcm_data) < 1000:
            print(f"PCM data too small to save: {len(pcm_data) if pcm_data else 0} bytes")
            return None
            
        # Convert PCM to WAV format in memory
        wav_buffer = io.BytesIO()
        try:
            with wave.open(wav_buffer, 'wb') as wav_file:
                wav_file.setnchannels(1)  # Mono
                wav_file.setsampwidth(2)  # 16-bit
                wav_file.setframerate(sample_rate)  # Set sample rate to match recording
                wav_file.writeframes(pcm_data)
        except Exception as wav_error:
            print(f"Error creating WAV data: {wav_error}")
            return None
        
        # Reset buffer position
        wav_buffer.seek(0)

        try:
            # Convert WAV to MP3
            audio_segment = AudioSegment.from_wav(wav_buffer)
            
            # Validate audio segment
            if len(audio_segment) < 100:  # Less than 0.1 seconds
                print(f"Audio segment too short: {len(audio_segment)}ms")
                return None
                
            audio_segment.export(filename, format="mp3", codec="libmp3lame")
            print(f"MP3 file saved successfully as {filename}")
            return filename  # Return the filename for reference
        except Exception as mp3_error:
            print(f"Error converting to MP3: {mp3_error}")
            return None
            
    except Exception as e:
        print(f"Error saving PCM as MP3: {e}")
        return None


def convert_pcm_to_mp3(pcm_data, sample_rate=24000):
    """Converts PCM audio to base64 encoded MP3 with improved error handling."""
    try:
        # Validate input
        if not pcm_data or len(pcm_data) < 1000:
            print(f"PCM data too small for conversion: {len(pcm_data) if pcm_data else 0} bytes")
            return None
            
        # Create a WAV in memory first
        wav_buffer = io.BytesIO()
        try:
            with wave.open(wav_buffer, 'wb') as wav_file:
                wav_file.setnchannels(1)  # mono
                wav_file.setsampwidth(2)  # 16-bit
                wav_file.setframerate(sample_rate)  # Use the provided sample rate
                wav_file.writeframes(pcm_data)
        except Exception as wav_error:
            print(f"Error creating WAV in memory: {wav_error}")
            return None
        
        # Reset buffer position
        wav_buffer.seek(0)
        
        try:
            # Convert WAV to MP3
            audio_segment = AudioSegment.from_wav(wav_buffer)
            
            # Validate audio segment
            if len(audio_segment) < 100:  # Less than 0.1 seconds
                print(f"Audio segment too short for conversion: {len(audio_segment)}ms")
                return None
            
            # Export as MP3
            mp3_buffer = io.BytesIO()
            audio_segment.export(mp3_buffer, format="mp3", codec="libmp3lame")
            
            # Get MP3 data
            mp3_data = mp3_buffer.getvalue()
            
            # Validate MP3 data
            if len(mp3_data) < 500:  # Minimum reasonable MP3 size
                print(f"MP3 data too small: {len(mp3_data)} bytes")
                return None
            
            # Convert to base64
            mp3_base64 = base64.b64encode(mp3_data).decode('utf-8')
            print(f"Successfully converted PCM to MP3: {len(mp3_data)} bytes -> {len(mp3_base64)} base64 chars")
            return mp3_base64
        except Exception as conversion_error:
            print(f"Error during MP3 conversion: {conversion_error}")
            return None
        
    except Exception as e:
        print(f"Error converting PCM to MP3: {e}")
        return None


async def main() -> None:
    async with websockets.serve(gemini_session_handler, "0.0.0.0", 9083):
        print("Running websocket server on 0.0.0.0:9083...")
        await asyncio.Future()  # Keep the server running indefinitely


if __name__ == "__main__":
    asyncio.run(main())