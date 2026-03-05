#!/usr/bin/env python3

import subprocess
import os
import sys
import signal
import time
from datetime import datetime

# Configuration
WHISPER_MODEL = "medium"
AUDIO_FILE = "/tmp/speech_recording.wav"
RECORDING_PID_FILE = "/tmp/speech_recording.pid"
DEBUG_LOG = "/tmp/speech_debug.log"

def debug_log(message):
    """Write debug message to log file"""
    try:
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        with open(DEBUG_LOG, 'a') as f:
            f.write(f"[{timestamp}] {message}\n")
        print(f"DEBUG: {message}")
    except:
        print(f"DEBUG: {message}")  # Fallback to stdout if log fails

def show_notification(message, urgency="normal"):
    """Show desktop notification"""
    debug_log(f"Showing notification: {message} (urgency: {urgency})")
    try:
        result = subprocess.run([
            "notify-send",
            "--urgency", urgency,
            "--app-name", "Speech-to-Text",
            "--expire-time", "3000",
            "Voice Dictation",
            message
        ], check=False, capture_output=True, text=True)
        if result.returncode != 0:
            debug_log(f"notify-send failed: {result.stderr}")
    except Exception as e:
        debug_log(f"Notification failed: {e}")

def is_recording():
    """Check if recording is active by checking PID file"""
    debug_log("Checking if recording is active...")

    if not os.path.exists(RECORDING_PID_FILE):
        debug_log("No PID file found - not recording")
        return False

    try:
        with open(RECORDING_PID_FILE, 'r') as f:
            pid_str = f.read().strip()
            debug_log(f"Found PID file with content: '{pid_str}'")
            pid = int(pid_str)

        # Check if process is still running
        debug_log(f"Checking if PID {pid} is still running...")
        os.kill(pid, 0)  # This will raise OSError if process doesn't exist
        debug_log(f"PID {pid} is still running - recording is active")
        return True
    except (OSError, ValueError) as e:
        debug_log(f"PID check failed: {e} - cleaning up stale PID file")
        # Clean up stale PID file
        try:
            os.remove(RECORDING_PID_FILE)
            debug_log("Removed stale PID file")
        except Exception as cleanup_e:
            debug_log(f"Failed to remove PID file: {cleanup_e}")
        return False

def start_recording():
    """Start recording audio"""
    debug_log("Starting recording process...")
    try:
        # Clean up any existing files
        debug_log("Cleaning up existing files...")
        for f in [AUDIO_FILE, RECORDING_PID_FILE]:
            if os.path.exists(f):
                debug_log(f"Removing existing file: {f}")
                os.remove(f)

        show_notification("🎤 Recording... Press Super+Space to stop")

        # Check if parec is available
        try:
            subprocess.run(["parec", "--help"], check=True, capture_output=True)
            debug_log("parec is available")
        except:
            debug_log("ERROR: parec is not available!")
            show_notification("parec not found - install pulseaudio", "critical")
            return False

        # Start recording using parec (PulseAudio record)
        cmd = [
            "parec",
            "--format=s16le",
            "--rate=16000",
            "--channels=1",
            "--file-format=wav",
            AUDIO_FILE
        ]
        debug_log(f"Starting parec with command: {' '.join(cmd)}")

        process = subprocess.Popen(cmd,
                                 stdout=subprocess.PIPE,
                                 stderr=subprocess.PIPE)

        # Wait a moment to see if the process starts successfully
        time.sleep(0.2)

        if process.poll() is not None:
            # Process has already terminated
            stdout, stderr = process.communicate()
            debug_log(f"pactl failed immediately! returncode: {process.returncode}")
            debug_log(f"stdout: {stdout.decode()}")
            debug_log(f"stderr: {stderr.decode()}")
            show_notification(f"Recording failed: {stderr.decode()[:100]}", "critical")
            return False

        # Save PID for later termination
        with open(RECORDING_PID_FILE, 'w') as f:
            f.write(str(process.pid))

        debug_log(f"Started recording with PID {process.pid}")
        print(f"Started recording with PID {process.pid}")
        return True

    except Exception as e:
        debug_log(f"Exception in start_recording: {e}")
        show_notification(f"Recording failed: {e}", "critical")
        return False

def stop_recording():
    """Stop recording and transcribe audio"""
    debug_log("Stopping recording process...")
    try:
        if not os.path.exists(RECORDING_PID_FILE):
            debug_log("No PID file found - no recording in progress")
            show_notification("No recording in progress", "normal")
            return False

        # Get and kill recording process
        with open(RECORDING_PID_FILE, 'r') as f:
            pid_str = f.read().strip()
            debug_log(f"Found PID to kill: {pid_str}")
            pid = int(pid_str)

        try:
            debug_log(f"Sending SIGTERM to PID {pid}")
            os.kill(pid, signal.SIGTERM)
            debug_log(f"Successfully stopped recording process {pid}")
            print(f"Stopped recording process {pid}")
        except OSError as e:
            debug_log(f"Process {pid} already stopped or doesn't exist: {e}")
            print("Recording process already stopped")

        # Clean up PID file
        os.remove(RECORDING_PID_FILE)
        debug_log("Removed PID file")

        # Wait for file to be fully written
        debug_log("Waiting 0.5s for file to be fully written...")
        time.sleep(0.5)

        # Check if audio file exists and has reasonable size
        if not os.path.exists(AUDIO_FILE):
            debug_log(f"Audio file {AUDIO_FILE} does not exist!")
            show_notification("No audio file created", "normal")
            cleanup_files()
            return False

        file_size = os.path.getsize(AUDIO_FILE)
        debug_log(f"Audio file size: {file_size} bytes")

        if file_size < 3000:
            debug_log(f"Audio file too small ({file_size} bytes < 3000)")
            show_notification("Recording too short - try speaking longer", "normal")
            cleanup_files()
            return False

        # Transcribe audio
        debug_log("Starting transcription...")
        show_notification("🔄 Processing speech...")
        text = transcribe_audio()
        debug_log(f"Transcription result: '{text}'")

        # Clean up audio file
        cleanup_files()
        debug_log("Cleaned up temporary files")

        if not text or not text.strip():
            debug_log("No text returned from transcription")
            show_notification("No speech detected", "normal")
            return False

        # Inject text
        text = text.strip()
        debug_log(f"Attempting to inject text: '{text[:100]}{'...' if len(text) > 100 else ''}'")
        time.sleep(0.1)  # Small delay before injection

        if inject_text(text):
            debug_log("Text injection successful")
            show_notification(f"✅ {text[:60]}{'...' if len(text) > 60 else ''}")
            return True
        else:
            debug_log("Text injection failed")
            return False

    except Exception as e:
        debug_log(f"Exception in stop_recording: {e}")
        show_notification(f"Stop recording failed: {e}", "critical")
        cleanup_files()
        return False

def transcribe_audio():
    """Transcribe audio using whisper-cpp"""
    debug_log("Starting audio transcription...")
    model_path = f"/etc/nixos/models/ggml-{WHISPER_MODEL}.bin"
    debug_log(f"Model path: {model_path}")

    if not os.path.exists(model_path):
        debug_log(f"ERROR: Model file does not exist: {model_path}")
        show_notification(f"Whisper model not found: {model_path}", "critical")
        return None

    try:
        cmd = [
            "whisper-cli",
            "-m", model_path,
            "-f", AUDIO_FILE,
            "-l", "auto",  # Auto-detect language (supports French, English, etc.)
            "--output-txt"
        ]
        debug_log(f"Running whisper-cli command: {' '.join(cmd)}")

        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        debug_log(f"whisper-cli exit code: {result.returncode}")
        debug_log(f"whisper-cli stdout: {result.stdout}")
        debug_log(f"whisper-cli stderr: {result.stderr}")

        # Extract text from stdout (it's between timestamps)
        stdout_text = ""
        if result.stdout:
            # Parse stdout to extract transcribed text
            lines = result.stdout.strip().split('\n')
            for line in lines:
                if '-->' in line and ']' in line:
                    # Extract text after the timestamp
                    parts = line.split(']', 1)
                    if len(parts) > 1:
                        stdout_text += parts[1].strip() + " "
            stdout_text = stdout_text.strip()
            debug_log(f"Extracted text from stdout: '{stdout_text}'")

        # Also try reading generated text file (whisper-cli outputs filename.wav.txt)
        txt_file = AUDIO_FILE + ".txt"
        debug_log(f"Looking for output file: {txt_file}")

        file_text = ""
        if os.path.exists(txt_file):
            debug_log("Output file found, reading content...")
            with open(txt_file, 'r') as f:
                file_text = f.read().strip()
            debug_log(f"Read text from file: '{file_text}'")
            os.remove(txt_file)
            debug_log("Removed temporary text file")

        # Return the longer of the two texts (or stdout if file is empty)
        if len(stdout_text) > len(file_text):
            return stdout_text
        elif file_text:
            return file_text
        else:
            debug_log("No text found in stdout or file")
            return ""

    except subprocess.CalledProcessError as e:
        debug_log(f"whisper-cli failed: returncode={e.returncode}")
        debug_log(f"whisper-cli stdout: {e.stdout}")
        debug_log(f"whisper-cli stderr: {e.stderr}")
        show_notification(f"Transcription failed: {e}", "critical")
        return None
    except Exception as e:
        debug_log(f"Exception in transcribe_audio: {e}")
        show_notification(f"Error: {e}", "critical")
        return None

def inject_text(text):
    """Inject text using clipboard backup/restore method"""
    debug_log(f"Injecting text via clipboard: '{text[:50]}{'...' if len(text) > 50 else ''}'")

    try:
        # Step 1: Backup current clipboard content
        debug_log("Backing up current clipboard content...")
        backup_clipboard = ""
        try:
            result = subprocess.run(["xclip", "-selection", "clipboard", "-o"],
                                  capture_output=True, text=True, timeout=3)
            if result.returncode == 0:
                backup_clipboard = result.stdout
                debug_log(f"Clipboard backup: '{backup_clipboard[:30]}{'...' if len(backup_clipboard) > 30 else ''}'")
        except Exception as e:
            debug_log(f"Clipboard backup failed (non-critical): {e}")

        # Step 2: Copy transcribed text to clipboard
        debug_log("Copying transcribed text to clipboard...")
        result = subprocess.run(["xclip", "-selection", "clipboard"],
                              input=text, text=True, timeout=3)
        if result.returncode != 0:
            debug_log("Failed to copy text to clipboard")
            show_notification("Failed to copy to clipboard", "critical")
            return False

        # Step 3: Small delay to ensure clipboard is ready
        time.sleep(0.1)

        # Step 4: Paste with Ctrl+V using xdotool
        debug_log("Pasting with Ctrl+V...")
        result = subprocess.run(["xdotool", "key", "ctrl+v"],
                              capture_output=True, text=True, timeout=5)
        if result.returncode != 0:
            debug_log(f"Ctrl+V failed: {result.stderr}")
            show_notification("Paste operation failed", "critical")
            return False

        # Step 5: Restore original clipboard content
        debug_log("Restoring original clipboard content...")
        time.sleep(0.2)  # Give paste operation time to complete
        try:
            subprocess.run(["xclip", "-selection", "clipboard"],
                         input=backup_clipboard, text=True, timeout=3)
            debug_log("Clipboard restored successfully")
        except Exception as e:
            debug_log(f"Clipboard restore failed (non-critical): {e}")

        debug_log("Text injection completed successfully")
        return True

    except Exception as e:
        debug_log(f"Exception in inject_text: {e}")
        show_notification(f"Text injection failed: {e}", "critical")
        return False

def cleanup_files():
    """Clean up temporary files"""
    for f in [AUDIO_FILE, RECORDING_PID_FILE]:
        if os.path.exists(f):
            try:
                os.remove(f)
            except:
                pass

def main():
    """Main toggle function"""
    debug_log("=== SPEECH-TO-TEXT SCRIPT STARTED ===")
    debug_log(f"Python version: {sys.version}")
    debug_log(f"Working directory: {os.getcwd()}")
    debug_log(f"User: {os.getenv('USER', 'unknown')}")
    debug_log(f"Audio file path: {AUDIO_FILE}")
    debug_log(f"PID file path: {RECORDING_PID_FILE}")
    debug_log(f"Debug log: {DEBUG_LOG}")

    # Check basic environment
    debug_log("Checking environment...")
    for cmd in ["parec", "notify-send", "whisper-cli", "xdotool", "xclip"]:
        try:
            if cmd == "parec":
                result = subprocess.run([cmd, "--help"], capture_output=True, text=True, timeout=5)
            elif cmd == "xdotool":
                result = subprocess.run([cmd, "--help"], capture_output=True, text=True, timeout=5)
            elif cmd == "xclip":
                result = subprocess.run([cmd, "-version"], capture_output=True, text=True, timeout=5)
            else:
                result = subprocess.run([cmd, "--version"], capture_output=True, text=True, timeout=5)
            debug_log(f"{cmd}: Available (exit code {result.returncode})")
        except Exception as e:
            debug_log(f"{cmd}: NOT AVAILABLE - {e}")

    try:
        recording_status = is_recording()
        debug_log(f"Current recording status: {recording_status}")

        if recording_status:
            debug_log("Attempting to stop recording...")
            print("Stopping recording...")
            success = stop_recording()
            debug_log(f"Stop recording result: {success}")
            return 0 if success else 1
        else:
            debug_log("Attempting to start recording...")
            print("Starting recording...")
            success = start_recording()
            debug_log(f"Start recording result: {success}")
            return 0 if success else 1

    except KeyboardInterrupt:
        debug_log("Received KeyboardInterrupt")
        if is_recording():
            stop_recording()
        return 0
    except Exception as e:
        debug_log(f"Unhandled exception in main: {e}")
        show_notification(f"Error: {e}", "critical")
        return 1
    finally:
        debug_log("=== SPEECH-TO-TEXT SCRIPT ENDED ===\n")

if __name__ == "__main__":
    sys.exit(main())