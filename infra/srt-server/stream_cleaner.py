from __future__ import annotations

import argparse
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path
import re
import subprocess
from typing import List, Optional


@dataclass
class Segment:
    filename: str
    start: datetime
    duration: float
    end: datetime


def parse_program_datetime(raw: str) -> datetime:
    """
    Parse values like '2025-11-21T00:08:04.921+0000' into a timezone-aware datetime.
    """
    raw = raw.strip()
    # Convert +0000 / -0300 into +00:00 / -03:00 for fromisoformat
    m = re.search(r"([+-])(\d{2})(\d{2})$", raw)
    if m:
        sign, hh, mm = m.groups()
        raw = raw[: m.start()] + f"{sign}{hh}:{mm}"
    # fromisoformat supports fractional seconds and timezone offsets
    return datetime.fromisoformat(raw)


def parse_m3u8(playlist_path: Path) -> List[Segment]:
    segments: List[Segment] = []
    current_duration: Optional[float] = None
    current_pdt: Optional[datetime] = None

    with playlist_path.open("r", encoding="utf-8") as f:
        for raw_line in f:
            line = raw_line.strip()
            if not line:
                continue

            if line.startswith("#EXTINF:"):
                # e.g. '#EXTINF:33.333333,'
                try:
                    duration_str = line.split(":", 1)[1].split(",", 1)[0]
                    current_duration = float(duration_str)
                except Exception:
                    current_duration = None

            elif line.startswith("#EXT-X-PROGRAM-DATE-TIME:"):
                # e.g. '#EXT-X-PROGRAM-DATE-TIME:2025-11-21T00:08:04.921+0000'
                dt_str = line.split(":", 1)[1].strip()
                try:
                    current_pdt = parse_program_datetime(dt_str)
                except Exception:
                    current_pdt = None

            elif line.startswith("#"):
                # other tags we don't care about
                continue

            else:
                # Should be the TS segment file name / URI
                if current_duration is None or current_pdt is None:
                    # malformed entry; skip it
                    current_duration = None
                    current_pdt = None
                    continue

                start = current_pdt
                end = start + timedelta(seconds=current_duration)
                segments.append(
                    Segment(filename=line, start=start, duration=current_duration, end=end)
                )

                # reset for next segment
                current_duration = None
                current_pdt = None

    if not segments:
        raise RuntimeError(f"No segments found in playlist {playlist_path}")

    return segments


def get_mkv_duration(path: Path) -> float:
    """
    Use ffprobe (from ffmpeg) to read the duration of an mkv file in seconds.
    """
    cmd = [
        "ffprobe",
        "-v",
        "error",
        "-show_entries",
        "format=duration",
        "-of",
        "default=noprint_wrappers=1:nokey=1",
        str(path),
    ]
    try:
        result = subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            check=True,
        )
    except FileNotFoundError as exc:
        raise RuntimeError(
            "ffprobe not found. Please install ffmpeg and ensure 'ffprobe' is on PATH."
        ) from exc
    except subprocess.CalledProcessError as exc:
        raise RuntimeError(f"ffprobe failed for {path}: {exc.stderr}") from exc

    try:
        return float(result.stdout.strip())
    except ValueError as exc:
        raise RuntimeError(
            f"Could not parse duration from ffprobe output for {path!s}: {result.stdout!r}"
        ) from exc


def parse_mkv_start_from_name(path: Path) -> Optional[datetime]:
    """
    Extract start datetime from a file name like:
      stream_2025-11-20_23-27-34.mkv

    Returns an aware datetime in UTC (adjust if needed).
    """
    m = re.search(r"(\d{4})-(\d{2})-(\d{2})_(\d{2})-(\d{2})-(\d{2})", path.name)
    if not m:
        return None

    year, month, day, hour, minute, second = map(int, m.groups())
    return datetime(year, month, day, hour, minute, second, tzinfo=timezone.utc)


def is_mkv_fully_in_playlist(
    mkv_start: datetime,
    mkv_duration: float,
    segments: List[Segment],
    tolerance_seconds: float = 0.5,
) -> bool:
    """
    Check whether the time span covered by the MKV is entirely present inside
    the playlist, using segment start/end times and durations.

    We compute the total intersection of the MKV interval with all segments
    and compare it to the MKV's duration.
    """
    mkv_end = mkv_start + timedelta(seconds=mkv_duration)

    covered_seconds = 0.0
    for seg in segments:
        # Find overlap between [seg.start, seg.end] and [mkv_start, mkv_end]
        overlap_start = max(seg.start, mkv_start)
        overlap_end = min(seg.end, mkv_end)
        if overlap_end > overlap_start:
            covered_seconds += (overlap_end - overlap_start).total_seconds()

    return covered_seconds + tolerance_seconds >= mkv_duration


def find_candidate_mkvs(live_dir: Path, threshold_seconds: int) -> List[Path]:
    """
    Return MKV files whose last modification time is older than
    now - threshold_seconds.
    """
    now = datetime.now(timezone.utc)
    candidates: List[Path] = []

    for mkv in sorted(live_dir.glob("*.mkv")):
        stat = mkv.stat()
        mtime = datetime.fromtimestamp(stat.st_mtime, tz=timezone.utc)
        if mtime + timedelta(seconds=threshold_seconds) < now:
            candidates.append(mkv)

    return candidates


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Check live MKV recordings against a base HLS playlist and mark "
            "those that are fully represented in the playlist."
        )
    )
    parser.add_argument(
        "--base-dir",
        required=True,
        type=Path,
        help="BASE_RECORDINGS_DIR that contains playlist.m3u8",
    )
    parser.add_argument(
        "--live-dir",
        required=True,
        type=Path,
        help="LIVE_RECORDING_DIR that contains live .mkv files",
    )
    parser.add_argument(
        "--threshold",
        type=int,
        default=300,
        help=(
            "LIVE_CHECK_THERSHOLD in seconds; "
            "MKV files newer than now-threshold are ignored."
        ),
    )
    parser.add_argument(
        "--playlist-name",
        default="playlist.m3u8",
        help="Name of the playlist file inside BASE_RECORDINGS_DIR (default: playlist.m3u8)",
    )
    parser.add_argument(
        "--delete",
        action="store_true",
        help=(
            "Actually delete MKV files that are fully covered by the playlist. "
            "Without this flag, the script only prints what it would delete."
        ),
    )

    args = parser.parse_args()

    base_dir: Path = args.base_dir
    live_dir: Path = args.live_dir
    threshold: int = args.threshold
    playlist_path = base_dir / args.playlist_name

    if not playlist_path.is_file():
        raise SystemExit(f"Playlist file not found: {playlist_path}")

    if not live_dir.is_dir():
        raise SystemExit(f"Live recordings directory not found: {live_dir}")

    print(f"Loading playlist from {playlist_path} ...")
    segments = parse_m3u8(playlist_path)
    print(f"Parsed {len(segments)} segments from playlist.")

    candidates = find_candidate_mkvs(live_dir, threshold)
    if not candidates:
        print("No MKV files qualify for checking (none older than threshold).")
        return

    print(f"Found {len(candidates)} MKV file(s) older than threshold to inspect.\n")

    files_to_delete: List[Path] = []

    for mkv in candidates:
        mkv_start = parse_mkv_start_from_name(mkv)
        if mkv_start is None:
            print(f"[SKIP] Could not parse start time from file name: {mkv.name}")
            continue

        try:
            mkv_duration = get_mkv_duration(mkv)
        except RuntimeError as e:
            print(f"[SKIP] Could not get duration for {mkv.name}: {e}")
            continue

        fully_covered = is_mkv_fully_in_playlist(mkv_start, mkv_duration, segments)

        start_str = mkv_start.isoformat()
        print(f"{mkv.name}: start={start_str}, duration={mkv_duration:.3f}s -> ", end="")
        if fully_covered:
            print("FULLY PRESENT in playlist (marking for deletion).")
            files_to_delete.append(mkv)
        else:
            print("NOT fully present in playlist (keeping).")

    if not files_to_delete:
        print("\nNo MKV files are fully present in the playlist. Nothing to delete.")
        return

    print("\nSummary of MKV files fully present in playlist:")
    for mkv in files_to_delete:
        print(f"  - {mkv}")

    if args.delete:
        print("\n--delete given, deleting files...")
        for mkv in files_to_delete:
            try:
                mkv.unlink()
                print(f"Deleted {mkv}")
            except Exception as e:
                print(f"Failed to delete {mkv}: {e}")
    else:
        print("\nRun again with --delete to actually remove these files.")


if __name__ == "__main__":
    main()
