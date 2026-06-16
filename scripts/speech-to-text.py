#!/usr/bin/env python3

import json
import os
import re
import signal
import subprocess
import sys
import time
import uuid
from datetime import datetime
from urllib.error import URLError
from urllib.request import Request, urlopen

# Configuration
WHISPER_LOCAL_URL = "http://127.0.0.1:8080/inference"
WHISPER_TIMEOUT = 120
OLLAMA_LOCAL_URL = "http://localhost:11434/api/generate"
OLLAMA_MODEL = "gemma4:e4b"
OLLAMA_TIMEOUT = 120

# Remote desktop for GPU-accelerated transcription (set via env)
WHISPER_REMOTE_HOST = os.environ.get("WHISPER_REMOTE_HOST", "")
WHISPER_REMOTE_PORT = os.environ.get("WHISPER_REMOTE_PORT", "8080")
OLLAMA_REMOTE_PORT = os.environ.get("OLLAMA_REMOTE_PORT", "11434")

# Resolved server URLs (set by resolve_servers())
_resolved = None

AUDIO_FILE = "/tmp/speech_recording.wav"
RECORDING_PID_FILE = "/tmp/speech_recording.pid"
MEDIA_WAS_PLAYING_FILE = "/tmp/speech_media_was_playing"
MODE_FILE = "/tmp/speech_recording.mode"
DEBUG_LOG = "/tmp/speech_debug.log"
SEGMENT_PREFIX = "/tmp/speech_segment_"

DICTATION_DIR = os.path.expanduser("~/dictation")

# Silence detection params
SILENCE_NOISE_THRESHOLD = "-30dB"
SILENCE_MIN_DURATION = "2"  # seconds


def debug_log(message):
    """Write debug message to log file"""
    try:
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        with open(DEBUG_LOG, 'a') as f:
            f.write(f"[{timestamp}] {message}\n")
        print(f"DEBUG: {message}")
    except:
        print(f"DEBUG: {message}")


def show_notification(message, urgency="normal", timeout_ms=1000):
    """Show desktop notification and auto-close it after timeout_ms.

    GNOME ignores --expire-time, so we grab the notification ID and
    close it ourselves via D-Bus after the requested delay.
    """
    debug_log(f"Showing notification: {message} (urgency: {urgency}, timeout: {timeout_ms}ms)")
    try:
        result = subprocess.run([
            "notify-send",
            "--urgency", urgency,
            "--app-name", "Speech-to-Text",
            "--hint=int:transient:1",
            "--print-id",
            "Voice Dictation",
            message
        ], check=False, capture_output=True, text=True)
        if result.returncode != 0:
            debug_log(f"notify-send failed: {result.stderr}")
            return

        nid = result.stdout.strip()
        if nid:
            subprocess.Popen(
                ["bash", "-c",
                 f"sleep {timeout_ms / 1000:.2f} && "
                 f"gdbus call --session "
                 f"--dest org.freedesktop.Notifications "
                 f"--object-path /org/freedesktop/Notifications "
                 f"--method org.freedesktop.Notifications.CloseNotification "
                 f"{nid}"],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                start_new_session=True,
            )
    except Exception as e:
        debug_log(f"Notification failed: {e}")


# --- Media pause/resume ---

def pause_media():
    """Pause any playing media via playerctl and remember it was playing."""
    try:
        result = subprocess.run(
            ["playerctl", "status"],
            capture_output=True, text=True, timeout=2
        )
        if result.returncode == 0 and result.stdout.strip() == "Playing":
            subprocess.run(["playerctl", "pause"], timeout=2, check=False)
            with open(MEDIA_WAS_PLAYING_FILE, 'w') as f:
                f.write("1")
            debug_log("Paused playing media")
        else:
            debug_log("No media playing, nothing to pause")
    except Exception as e:
        debug_log(f"Failed to pause media: {e}")


def resume_media():
    """Resume media if it was paused by us."""
    try:
        if os.path.exists(MEDIA_WAS_PLAYING_FILE):
            os.remove(MEDIA_WAS_PLAYING_FILE)
            subprocess.run(["playerctl", "play"], timeout=2, check=False)
            debug_log("Resumed media playback")
    except Exception as e:
        debug_log(f"Failed to resume media: {e}")


# --- Server resolution ---

def resolve_servers():
    """Determine which servers to use: remote GPU desktop or local CPU fallback."""
    global _resolved
    if _resolved is not None:
        return _resolved

    whisper_url = WHISPER_LOCAL_URL
    ollama_url = OLLAMA_LOCAL_URL
    remote = False

    if WHISPER_REMOTE_HOST:
        try:
            req = Request(
                f"http://{WHISPER_REMOTE_HOST}:{WHISPER_REMOTE_PORT}/",
                method="GET",
            )
            urlopen(req, timeout=1)
            whisper_url = f"http://{WHISPER_REMOTE_HOST}:{WHISPER_REMOTE_PORT}/inference"
            ollama_url = f"http://{WHISPER_REMOTE_HOST}:{OLLAMA_REMOTE_PORT}/api/generate"
            remote = True
            debug_log(f"Remote desktop available at {WHISPER_REMOTE_HOST}")
        except Exception:
            debug_log(f"Remote desktop {WHISPER_REMOTE_HOST} unavailable, using local CPU")

    _resolved = (whisper_url, ollama_url, remote)
    return _resolved


# --- Mode persistence ---

def write_mode(mode):
    with open(MODE_FILE, 'w') as f:
        f.write(mode)
    debug_log(f"Wrote mode: {mode}")


def read_mode():
    try:
        with open(MODE_FILE, 'r') as f:
            mode = f.read().strip()
        debug_log(f"Read mode: {mode}")
        return mode if mode in ("raw", "llm") else "raw"
    except Exception:
        debug_log("No mode file found, defaulting to raw")
        return "raw"


# --- Recording state ---

def is_recording():
    """Check if recording is active by checking PID file"""
    if not os.path.exists(RECORDING_PID_FILE):
        return False
    try:
        with open(RECORDING_PID_FILE, 'r') as f:
            pid = int(f.read().strip())
        os.kill(pid, 0)
        return True
    except (OSError, ValueError):
        try:
            os.remove(RECORDING_PID_FILE)
        except Exception:
            pass
        return False


def start_recording(mode):
    """Start recording audio"""
    debug_log(f"Starting recording in {mode} mode...")
    try:
        for f in [AUDIO_FILE, RECORDING_PID_FILE, MODE_FILE]:
            if os.path.exists(f):
                os.remove(f)

        pause_media()

        mode_label = "LLM" if mode == "llm" else "Raw"
        show_notification(f"🎤 Recording ({mode_label})... Press shortcut to stop")

        write_mode(mode)

        cmd = [
            "parec",
            "--format=s16le",
            "--rate=16000",
            "--channels=1",
            "--file-format=wav",
            AUDIO_FILE
        ]
        debug_log(f"Starting parec: {' '.join(cmd)}")

        process = subprocess.Popen(cmd,
                                   stdout=subprocess.PIPE,
                                   stderr=subprocess.PIPE)

        time.sleep(0.2)

        if process.poll() is not None:
            stdout, stderr = process.communicate()
            debug_log(f"parec failed: {stderr.decode()}")
            show_notification(f"Recording failed: {stderr.decode()[:100]}", "critical")
            return False

        with open(RECORDING_PID_FILE, 'w') as f:
            f.write(str(process.pid))

        # Preload Ollama model into VRAM while user is still speaking
        if mode == "llm":
            preload_ollama_model()

        debug_log(f"Started recording with PID {process.pid}")
        return True

    except Exception as e:
        debug_log(f"Exception in start_recording: {e}")
        show_notification(f"Recording failed: {e}", "critical")
        return False


# --- Audio analysis ---

def get_audio_duration(filepath):
    """Get audio duration in seconds from file size (16kHz, 16-bit mono = 32000 bytes/sec)"""
    try:
        file_size = os.path.getsize(filepath)
        # WAV header is 44 bytes
        duration = max(0, (file_size - 44)) / 32000.0
        debug_log(f"Audio duration: {duration:.1f}s (file size: {file_size} bytes)")
        return duration
    except Exception as e:
        debug_log(f"Failed to get audio duration: {e}")
        return 0.0


def detect_silence_breaks(filepath):
    """Detect silence boundaries using ffmpeg silencedetect.
    Returns list of split-point timestamps (midpoints of silence regions)."""
    debug_log("Running silence detection...")
    try:
        result = subprocess.run([
            "ffmpeg", "-i", filepath,
            "-af", f"silencedetect=n={SILENCE_NOISE_THRESHOLD}:d={SILENCE_MIN_DURATION}",
            "-f", "null", "-"
        ], capture_output=True, text=True, timeout=60)

        stderr = result.stderr
        # Parse silence_start and silence_end pairs
        starts = [float(m) for m in re.findall(r'silence_start:\s*([\d.]+)', stderr)]
        ends = [float(m) for m in re.findall(r'silence_end:\s*([\d.]+)', stderr)]

        # Compute midpoints of silence regions as split points
        split_points = []
        for s, e in zip(starts, ends):
            midpoint = (s + e) / 2.0
            split_points.append(midpoint)

        debug_log(f"Found {len(split_points)} silence breaks: {split_points}")
        return split_points

    except Exception as e:
        debug_log(f"Silence detection failed: {e}")
        return []


def split_audio_segments(filepath, split_points, duration):
    """Split audio file at given timestamps. Returns list of segment file paths."""
    if not split_points:
        debug_log("No split points, using whole file as single segment")
        return [filepath]

    # Build segment boundaries: [(start, end), ...]
    boundaries = []
    prev = 0.0
    for point in split_points:
        if point > prev:
            boundaries.append((prev, point))
        prev = point
    if prev < duration:
        boundaries.append((prev, duration))

    if len(boundaries) <= 1:
        debug_log("Only one segment after splitting, using whole file")
        return [filepath]

    segment_files = []
    for i, (start, end) in enumerate(boundaries):
        segment_path = f"{SEGMENT_PREFIX}{i}.wav"
        try:
            subprocess.run([
                "ffmpeg", "-y",
                "-ss", str(start),
                "-to", str(end),
                "-i", filepath,
                "-c", "copy",
                segment_path
            ], capture_output=True, text=True, timeout=30, check=True)
            segment_files.append(segment_path)
            debug_log(f"Segment {i}: {start:.1f}s - {end:.1f}s → {segment_path}")
        except Exception as e:
            debug_log(f"Failed to extract segment {i}: {e}")

    if not segment_files:
        debug_log("All segment extractions failed, falling back to whole file")
        return [filepath]

    return segment_files


# --- Transcription ---

def transcribe_audio(filepath):
    """Transcribe a single audio file via whisper-server HTTP API"""
    whisper_url, _, _ = resolve_servers()
    debug_log(f"Transcribing {filepath} via {whisper_url}...")

    try:
        boundary = uuid.uuid4().hex
        with open(filepath, "rb") as f:
            audio_data = f.read()

        filename = os.path.basename(filepath)

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
            whisper_url,
            data=body,
            headers={"Content-Type": f"multipart/form-data; boundary={boundary}"},
            method="POST",
        )

        response = urlopen(req, timeout=WHISPER_TIMEOUT)
        result = json.loads(response.read().decode("utf-8"))
        text = result.get("text", "").strip()
        debug_log(f"Transcription result: '{text[:100]}{'...' if len(text) > 100 else ''}'")
        return text

    except (ConnectionRefusedError, URLError) as e:
        debug_log(f"Whisper server not reachable: {e}")
        show_notification("Whisper server not running", "critical")
        return None
    except Exception as e:
        debug_log(f"Transcription error: {e}")
        return None


def transcribe_segments(segment_files):
    """Transcribe multiple audio segments and concatenate results."""
    texts = []
    for filepath in segment_files:
        text = transcribe_audio(filepath)
        if text:
            texts.append(text)
    combined = " ".join(texts)
    debug_log(f"Combined transcription ({len(texts)} segments): '{combined[:100]}...'")
    return combined


# --- LLM cleanup ---

def load_llm_prompt():
    """Load LLM system prompt from external file."""
    prompt_path = os.environ.get("DICTATION_LLM_PROMPT", "")
    if prompt_path and os.path.isfile(prompt_path):
        with open(prompt_path, 'r') as f:
            return f.read().strip()
    debug_log(f"LLM prompt file not found at: {prompt_path}")
    return "Clean up this French speech transcription. Fix punctuation, remove filler words and repetitions. Return only the cleaned text."


def preload_ollama_model():
    """Spawn a detached subprocess to load the Ollama model into VRAM.

    Uses a separate process (not a thread) because start_recording exits
    immediately after launching parec — a daemon thread would be killed
    before completing the HTTP request.
    """
    _, ollama_url, _ = resolve_servers()
    debug_log(f"Preloading Ollama model via background process ({ollama_url})...")
    try:
        subprocess.Popen(
            [
                sys.executable, "-c",
                "import json,sys; from urllib.request import Request,urlopen; "
                "urlopen(Request(sys.argv[1], data=json.dumps("
                "{'model':sys.argv[2],'keep_alive':'5m'}).encode(),"
                "headers={'Content-Type':'application/json'},method='POST'), timeout=60)",
                ollama_url, OLLAMA_MODEL,
            ],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
        debug_log("Ollama preload process spawned")
    except Exception as e:
        debug_log(f"Ollama model preload failed (non-fatal): {e}")


def llm_cleanup(text):
    """Pass text through Ollama for cleanup. Falls back to raw text on failure."""
    _, ollama_url, _ = resolve_servers()
    debug_log(f"Running LLM cleanup on {len(text)} chars via {ollama_url}...")
    system_prompt = load_llm_prompt()

    try:
        payload = json.dumps({
            "model": OLLAMA_MODEL,
            "prompt": f"{system_prompt}\n\nTranscription:\n{text}",
            "stream": False,
            "think": False,
        }).encode("utf-8")

        req = Request(
            ollama_url,
            data=payload,
            headers={"Content-Type": "application/json"},
            method="POST",
        )

        response = urlopen(req, timeout=OLLAMA_TIMEOUT)
        result = json.loads(response.read().decode("utf-8"))
        cleaned = result.get("response", "").strip()

        if cleaned:
            debug_log(f"LLM cleanup result: '{cleaned[:100]}...'")
            return cleaned
        else:
            debug_log("LLM returned empty response, using raw text")
            return text

    except Exception as e:
        debug_log(f"LLM cleanup failed: {e}")
        show_notification(f"LLM cleanup failed, using raw text", "normal")
        return text


# --- Text output ---

# ydotool sends raw QWERTY keycodes — remap characters so AZERTY layout
# produces the intended output.
AZERTY_TO_YDOTOOL = {
    'a': 'q', 'A': 'Q',
    'q': 'a', 'Q': 'A',
    'z': 'w', 'Z': 'W',
    'w': 'z', 'W': 'Z',
    'm': ';', 'M': ':',
    '1': '!', '2': '@', '3': '#', '4': '$', '5': '%',
    '6': '^', '7': '&', '8': '*', '9': '(', '0': ')',
    ',': 'm', '.': '<', '?': 'M',
    ';': ',', ':': '.', '!': '/', '/': '>',
    "'": '4', '"': '3', '-': '6', '_': '8',
    '(': '5', ')': '-', '&': '1',
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
    debug_log(f"Injecting text via clipboard paste: '{text[:50]}...'")

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
        except Exception:
            pass

        lines = text.split('\n')
        for i, line in enumerate(lines):
            if line:
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
                    debug_log(f"ydotool paste failed: {result.stderr}")
                    show_notification("Paste failed", "critical")
                    return False

            # Send Shift+Enter between lines (not after the last one)
            if i < len(lines) - 1:
                result = subprocess.run(
                    ["ydotool", "key", "42:1", "28:1", "28:0", "42:0"],
                    capture_output=True, text=True, timeout=5
                )
                if result.returncode != 0:
                    debug_log(f"ydotool Shift+Enter failed: {result.stderr}")
                    return False

        debug_log("Text injection completed successfully")

        # Restore previous clipboard
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
            except Exception:
                pass

        return True

    except Exception as e:
        debug_log(f"Exception in inject_text: {e}")
        show_notification(f"Text injection failed: {e}", "critical")
        return False


def output_result(text, duration, mode):
    """Output text via clipboard paste."""
    mode_label = "LLM" if mode == "llm" else "Raw"

    debug_log(f"Recording ({duration:.0f}s), pasting to clipboard")
    if inject_text(text):
        show_notification(f"✅ ({mode_label}) {text[:60]}{'...' if len(text) > 60 else ''}")
        return True
    else:
        return False


# --- Main pipeline ---

def cleanup_files():
    """Clean up temporary files"""
    for f in [AUDIO_FILE, RECORDING_PID_FILE, MODE_FILE]:
        if os.path.exists(f):
            try:
                os.remove(f)
            except Exception:
                pass
    # Clean up any segment files
    import glob
    for f in glob.glob(f"{SEGMENT_PREFIX}*.wav"):
        try:
            os.remove(f)
        except Exception:
            pass


def stop_recording():
    """Stop recording and process audio through the pipeline."""
    debug_log("Stopping recording...")
    mode = read_mode()
    segment_files = []

    try:
        if not os.path.exists(RECORDING_PID_FILE):
            show_notification("No recording in progress", "normal")
            return False

        # Kill recording process
        with open(RECORDING_PID_FILE, 'r') as f:
            pid = int(f.read().strip())

        try:
            os.kill(pid, signal.SIGTERM)
            debug_log(f"Stopped recording PID {pid}")
        except OSError:
            debug_log(f"Process {pid} already stopped")

        os.remove(RECORDING_PID_FILE)
        resume_media()
        time.sleep(0.5)

        # Validate audio file
        if not os.path.exists(AUDIO_FILE):
            show_notification("No audio file created", "normal")
            cleanup_files()
            return False

        file_size = os.path.getsize(AUDIO_FILE)
        if file_size < 3000:
            debug_log(f"Audio file too small ({file_size} bytes)")
            show_notification("Recording too short", "normal")
            cleanup_files()
            return False

        # Pipeline: duration → silence detect → split → transcribe → [llm] → output
        _, _, remote = resolve_servers()
        if remote:
            backend = "GPU (remote)"
        elif os.path.exists("/dev/nvidia0"):
            backend = "GPU (local)"
        else:
            backend = "CPU (local)"
        show_notification(f"🔄 Processing speech... [{backend}]")
        pipeline_start = time.time()

        duration = get_audio_duration(AUDIO_FILE)

        t0 = time.time()
        split_points = detect_silence_breaks(AUDIO_FILE)
        debug_log(f"[BENCH] silence detect: {time.time() - t0:.2f}s")

        t0 = time.time()
        segment_files = split_audio_segments(AUDIO_FILE, split_points, duration)
        debug_log(f"[BENCH] audio split: {time.time() - t0:.2f}s ({len(segment_files)} segments)")

        t0 = time.time()
        text = transcribe_segments(segment_files)
        debug_log(f"[BENCH] transcription: {time.time() - t0:.2f}s ({len(text)} chars)")

        if not text or not text.strip():
            show_notification("No speech detected", "normal")
            cleanup_files()
            return False

        text = text.strip()

        if mode == "llm":
            show_notification("🤖 Cleaning up with LLM...")
            t0 = time.time()
            text = llm_cleanup(text)
            debug_log(f"[BENCH] LLM cleanup: {time.time() - t0:.2f}s ({len(text)} chars)")

        debug_log(f"[BENCH] total pipeline: {time.time() - pipeline_start:.2f}s")

        success = output_result(text, duration, mode)
        return success

    except Exception as e:
        debug_log(f"Exception in stop_recording: {e}")
        show_notification(f"Processing failed: {e}", "critical")
        return False
    finally:
        # Always clean up segment files
        for seg in segment_files:
            if seg != AUDIO_FILE and os.path.exists(seg):
                try:
                    os.remove(seg)
                except Exception:
                    pass
        cleanup_files()


def main():
    """Main toggle function"""
    debug_log("=== SPEECH-TO-TEXT SCRIPT STARTED ===")

    mode_arg = sys.argv[1] if len(sys.argv) > 1 else "raw"
    if mode_arg not in ("raw", "llm"):
        debug_log(f"Unknown mode '{mode_arg}', defaulting to raw")
        mode_arg = "raw"

    debug_log(f"Mode argument: {mode_arg}")

    try:
        if is_recording():
            debug_log("Currently recording, stopping...")
            success = stop_recording()
            return 0 if success else 1
        else:
            debug_log(f"Not recording, starting in {mode_arg} mode...")
            success = start_recording(mode_arg)
            return 0 if success else 1

    except KeyboardInterrupt:
        if is_recording():
            stop_recording()
        return 0
    except Exception as e:
        debug_log(f"Unhandled exception: {e}")
        show_notification(f"Error: {e}", "critical")
        return 1
    finally:
        debug_log("=== SPEECH-TO-TEXT SCRIPT ENDED ===\n")


if __name__ == "__main__":
    sys.exit(main())
