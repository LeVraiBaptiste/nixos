#!/usr/bin/env python3
"""Standalone whisper transcription client.

Sends audio to the local whisper-server and prints transcribed text.

Examples:
  whisper-client audio.wav
  whisper-client audio.wav -o result.json
  whisper-client audio.wav --format verbose_json
  whisper-client audio.wav --language fr --temperature 0.2
  whisper-client audio.wav --translate

Exit codes:
  0 - Success
  1 - Transcription failure
  2 - Server unreachable
"""

import argparse
import json
import os
import sys
import uuid
from urllib.error import URLError
from urllib.request import Request, urlopen

DEFAULT_SERVER_URL = "http://127.0.0.1:8080/inference"
DEFAULT_TIMEOUT = 30


def build_multipart(fields, files):
    """Build a multipart/form-data body from fields and files dicts."""
    boundary = uuid.uuid4().hex
    parts = []

    for name, value in fields.items():
        parts.append(
            f"--{boundary}\r\n"
            f'Content-Disposition: form-data; name="{name}"\r\n\r\n'
            f"{value}\r\n"
        )

    for name, (filename, data, content_type) in files.items():
        parts.append(
            f"--{boundary}\r\n"
            f'Content-Disposition: form-data; name="{name}"; filename="{filename}"\r\n'
            f"Content-Type: {content_type}\r\n\r\n"
        )
        parts.append(data)
        parts.append(b"\r\n")

    parts.append(f"--{boundary}--\r\n")

    body = b""
    for part in parts:
        body += part.encode("utf-8") if isinstance(part, str) else part

    return boundary, body


def transcribe(audio_path, server_url, timeout, form_fields):
    """Send audio file to whisper-server, return parsed JSON response."""
    with open(audio_path, "rb") as f:
        audio_data = f.read()

    filename = os.path.basename(audio_path)
    files = {"file": (filename, audio_data, "audio/wav")}

    boundary, body = build_multipart(form_fields, files)

    req = Request(
        server_url,
        data=body,
        headers={"Content-Type": f"multipart/form-data; boundary={boundary}"},
        method="POST",
    )

    response = urlopen(req, timeout=timeout)
    return json.loads(response.read().decode("utf-8"))


def parse_args():
    p = argparse.ArgumentParser(
        description="Send audio to whisper-server for transcription.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="Response formats: json, text, verbose_json, srt, vtt",
    )

    p.add_argument("audio_file", help="Path to audio file")
    p.add_argument("-o", "--output", help="Write result to file (.json writes JSON, otherwise plain text)")

    # Server connection
    conn = p.add_argument_group("server")
    conn.add_argument("--url", default=DEFAULT_SERVER_URL, help=f"Server URL (default: {DEFAULT_SERVER_URL})")
    conn.add_argument("--timeout", type=int, default=DEFAULT_TIMEOUT, help=f"Request timeout in seconds (default: {DEFAULT_TIMEOUT})")

    # Transcription parameters
    tx = p.add_argument_group("transcription")
    tx.add_argument("-f", "--format", dest="response_format", default="verbose_json",
                    choices=["json", "text", "verbose_json", "srt", "vtt"],
                    help="Response format (default: verbose_json)")
    tx.add_argument("-l", "--language", default="auto", help="Spoken language or 'auto' (default: auto)")
    tx.add_argument("-t", "--temperature", type=float, default=0.0, help="Sampling temperature (default: 0.0)")
    tx.add_argument("--translate", action="store_true", help="Translate to English")
    tx.add_argument("--prompt", help="Initial prompt / context hint")
    tx.add_argument("--no-timestamps", action="store_true", help="Disable timestamps")

    # Advanced tuning
    adv = p.add_argument_group("advanced")
    adv.add_argument("--beam-size", type=int, help="Beam size for beam search")
    adv.add_argument("--best-of", type=int, help="Number of best candidates to keep")
    adv.add_argument("--max-len", type=int, help="Maximum segment length in characters")
    adv.add_argument("--word-thold", type=float, help="Word timestamp probability threshold")
    adv.add_argument("--entropy-thold", type=float, help="Entropy threshold for decoder fail")
    adv.add_argument("--suppress-nst", action="store_true", help="Suppress non-speech tokens")
    adv.add_argument("--diarize", action="store_true", help="Enable speaker diarization")

    return p.parse_args()


def main():
    args = parse_args()

    if not os.path.isfile(args.audio_file):
        print(f"Error: file not found: {args.audio_file}", file=sys.stderr)
        return 1

    # Build form fields from args
    fields = {
        "response_format": args.response_format,
        "temperature": str(args.temperature),
        "language": args.language,
    }

    if args.translate:
        fields["translate"] = "true"
    if args.prompt:
        fields["prompt"] = args.prompt
    if args.no_timestamps:
        fields["no_timestamps"] = "true"
    if args.beam_size is not None:
        fields["beam_size"] = str(args.beam_size)
    if args.best_of is not None:
        fields["best_of"] = str(args.best_of)
    if args.max_len is not None:
        fields["max_len"] = str(args.max_len)
    if args.word_thold is not None:
        fields["word_thold"] = str(args.word_thold)
    if args.entropy_thold is not None:
        fields["entropy_thold"] = str(args.entropy_thold)
    if args.suppress_nst:
        fields["suppress_nst"] = "true"
    if args.diarize:
        fields["diarize"] = "true"

    try:
        result = transcribe(args.audio_file, args.url, args.timeout, fields)
    except (ConnectionRefusedError, URLError) as e:
        print(f"Error: whisper server not reachable: {e}", file=sys.stderr)
        return 2
    except Exception as e:
        print(f"Error: transcription failed: {e}", file=sys.stderr)
        return 1

    # Determine output
    if args.output:
        with open(args.output, "w") as f:
            if args.output.endswith(".json"):
                json.dump(result, f, ensure_ascii=False, indent=2)
            else:
                text = result.get("text", "") if isinstance(result, dict) else str(result)
                f.write(text.strip() + "\n")
    else:
        # Print to stdout
        if args.response_format in ("verbose_json", "json"):
            json.dump(result, sys.stdout, ensure_ascii=False, indent=2)
            print()
        else:
            text = result.get("text", "") if isinstance(result, dict) else str(result)
            if text.strip():
                print(text.strip())

    return 0


if __name__ == "__main__":
    sys.exit(main())
