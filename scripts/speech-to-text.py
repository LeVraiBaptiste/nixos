#!/usr/bin/env python3

import json
import os
import signal
import subprocess
import sys
import time
import uuid
from datetime import datetime
from urllib.error import URLError
from urllib.request import Request, urlopen

# Configuration
WHISPER_SERVER_URL = "http://127.0.0.1:8080/inference"
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
            "--expire-time", "1000",
            "--hint=int:transient:1", 
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
    """Transcribe audio via whisper-server HTTP API"""
    debug_log("Starting audio transcription via whisper-server...")
    debug_log(f"Server URL: {WHISPER_SERVER_URL}")

    try:
        boundary = uuid.uuid4().hex

        with open(AUDIO_FILE, "rb") as f:
            audio_data = f.read()

        filename = os.path.basename(AUDIO_FILE)

        # Build multipart/form-data body
        parts = []
        parts.append(
            f"--{boundary}\r\n"
            f'Content-Disposition: form-data; name="file"; filename="{filename}"\r\n'
            f"Content-Type: audio/wav\r\n\r\n"
        )
        parts.append(audio_data)
        parts.append(b"\r\n")
        parts.append(
            f"--{boundary}\r\n"
            f'Content-Disposition: form-data; name="response_format"\r\n\r\n'
            f"json\r\n"
        )
        parts.append(
            f"--{boundary}\r\n"
            f'Content-Disposition: form-data; name="temperature"\r\n\r\n'
            f"0.0\r\n"
        )
        parts.append(f"--{boundary}--\r\n")

        body = b""
        for part in parts:
            if isinstance(part, str):
                body += part.encode("utf-8")
            else:
                body += part

        req = Request(
            WHISPER_SERVER_URL,
            data=body,
            headers={"Content-Type": f"multipart/form-data; boundary={boundary}"},
            method="POST",
        )

        debug_log("Sending request to whisper-server...")
        response = urlopen(req, timeout=30)
        result = json.loads(response.read().decode("utf-8"))
        text = result.get("text", "").strip()
        debug_log(f"Server response text: '{text}'")
        return text

    except (ConnectionRefusedError, URLError) as e:
        debug_log(f"Whisper server not reachable: {e}")
        show_notification("Whisper server not running", "critical")
        return None
    except Exception as e:
        debug_log(f"Exception in transcribe_audio: {e}")
        show_notification(f"Transcription error: {e}", "critical")
        return None

# ydotool sends raw QWERTY keycodes — remap characters so AZERTY layout
# produces the intended output.
# Desired AZERTY char → char to feed ydotool (QWERTY keycode equivalent)
AZERTY_TO_YDOTOOL = {
    # Swapped letters
    'a': 'q', 'A': 'Q',
    'q': 'a', 'Q': 'A',
    'z': 'w', 'Z': 'W',
    'w': 'z', 'W': 'Z',
    'm': ';', 'M': ':',
    # Digits (AZERTY needs Shift for digits)
    '1': '!', '2': '@', '3': '#', '4': '$', '5': '%',
    '6': '^', '7': '&', '8': '*', '9': '(', '0': ')',
    # Punctuation at different positions
    ',': 'm', '.': '<', '?': 'M',
    ';': ',', ':': '.', '!': '/', '/': '>',
    "'": '4', '"': '3', '-': '6', '_': '8',
    '(': '5', ')': '-', '&': '1',
    # French accented (AZERTY number row, unshifted)
    '\u00e9': '2', '\u00e8': '7', '\u00e7': '9', '\u00e0': '0',
}

def remap_for_azerty(text):
    """Remap text so ydotool QWERTY keycodes produce correct AZERTY output"""
    return ''.join(AZERTY_TO_YDOTOOL.get(c, c) for c in text)

def inject_text(text):
    """Inject text line by line via clipboard paste (wl-copy + Ctrl+V).

    Each line is copied to the clipboard and pasted instantly, with
    Shift+Enter keystrokes between lines.  Saves and restores the
    previous clipboard contents.
    """
    debug_log(f"Injecting text via clipboard paste: '{text[:50]}{'...' if len(text) > 50 else ''}'")

    try:
        # Save current clipboard contents
        old_clipboard = None
        try:
            result = subprocess.run(
                ["wl-paste", "--no-newline"],
                capture_output=True, timeout=2
            )
            if result.returncode == 0:
                old_clipboard = result.stdout
                debug_log("Saved existing clipboard contents")
        except Exception as e:
            debug_log(f"Could not save clipboard (empty?): {e}")

        lines = text.split('\n')
        for i, line in enumerate(lines):
            if line:
                # Copy line to clipboard (pipe via stdin, don't wait for wl-copy to exit
                # since it stays alive to serve the clipboard on Wayland)
                proc = subprocess.Popen(
                    ["wl-copy"],
                    stdin=subprocess.PIPE,
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL
                )
                proc.communicate(input=line.encode("utf-8"), timeout=5)

                time.sleep(0.05)

                # Paste with Ctrl+Shift+V (keycode 29=LCtrl, 42=LShift, 47=V)
                result = subprocess.run(
                    ["ydotool", "key", "29:1", "42:1", "47:1", "47:0", "42:0", "29:0"],
                    capture_output=True, text=True, timeout=5
                )
                if result.returncode != 0:
                    debug_log(f"ydotool Ctrl+V failed: {result.stderr}")
                    show_notification("Paste failed", "critical")
                    return False

                debug_log(f"Pasted line {i}: '{line[:50]}{'...' if len(line) > 50 else ''}'")

            # Send Shift+Enter between lines (not after the last one)
            if i < len(lines) - 1:
                debug_log(f"Sending Shift+Enter after line {i}")
                result = subprocess.run(
                    ["ydotool", "key", "42:1", "28:1", "28:0", "42:0"],
                    capture_output=True, text=True, timeout=5
                )
                if result.returncode != 0:
                    debug_log(f"ydotool key Shift+Enter failed: {result.stderr}")
                    return False

        debug_log("Text injection completed successfully")

        # Restore previous clipboard after a short delay
        if old_clipboard is not None:
            time.sleep(0.3)
            try:
                proc = subprocess.Popen(
                    ["wl-copy"],
                    stdin=subprocess.PIPE,
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL
                )
                proc.communicate(input=old_clipboard, timeout=5)
                debug_log("Restored previous clipboard contents")
            except Exception as e:
                debug_log(f"Could not restore clipboard: {e}")

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
    for cmd in ["parec", "notify-send", "ydotool"]:
        try:
            if cmd == "parec":
                result = subprocess.run([cmd, "--help"], capture_output=True, text=True, timeout=5)
            elif cmd == "ydotool":
                result = subprocess.run([cmd, "--help"], capture_output=True, text=True, timeout=5)
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