#!/usr/bin/env python3
"""Build a BGO multi-representation asset manifest from a model and turntable media."""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
from pathlib import Path


def _run(command: list[str]) -> str:
    result = subprocess.run(command, check=True, text=True, capture_output=True)
    return result.stdout


def _probe_frames(ffprobe: str, media: Path) -> tuple[int, int, int]:
    payload = json.loads(
        _run(
            [
                ffprobe,
                "-v",
                "error",
                "-count_frames",
                "-select_streams",
                "v:0",
                "-show_entries",
                "stream=width,height,nb_read_frames",
                "-of",
                "json",
                str(media),
            ]
        )
    )
    stream = payload["streams"][0]
    return int(stream["nb_read_frames"]), int(stream["width"]), int(stream["height"])


def _resource_path(project_root: Path, path: Path) -> str:
    return "res://" + path.resolve().relative_to(project_root.resolve()).as_posix()


def _validate_glb(model: Path, label: str) -> None:
    if model.suffix.lower() != ".glb":
        raise SystemExit(f"{label} must be an optimized .glb: {model}")
    if model.stat().st_size > 50 * 1024 * 1024:
        raise SystemExit(f"{label} exceeds the 50 MiB runtime model budget: {model}")
    with model.open("rb") as handle:
        if handle.read(4) != b"glTF":
            raise SystemExit(f"{label} is not a valid binary GLB: {model}")


def _validate_source_model(model: Path) -> None:
    if model.suffix.lower() not in {".fbx", ".blend", ".obj"}:
        raise SystemExit(f"source-model must be an authoring model (.fbx/.blend/.obj): {model}")
    if model.stat().st_size == 0:
        raise SystemExit(f"source-model is empty: {model}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--asset-id", required=True)
    parser.add_argument("--model", type=Path, required=True)
    parser.add_argument("--lod-model", type=Path)
    parser.add_argument("--source-model", type=Path)
    parser.add_argument("--turntable", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--project-root", type=Path, default=Path.cwd())
    parser.add_argument("--front-frame", type=int, default=0)
    parser.add_argument("--direction", choices=("clockwise", "counter_clockwise"), default="clockwise")
    parser.add_argument("--model-front-axis", choices=("+z", "-z"), default="-z")
    parser.add_argument("--near-distance", type=float, default=9.0)
    parser.add_argument("--height-cm", type=float)
    parser.add_argument("--base-diameter-cm", type=float)
    parser.add_argument("--world-units-per-cm-fallback", type=float, default=0.24)
    parser.add_argument("--billboard-vertical-offset-cm", type=float, default=0.0)
    parser.add_argument("--ffmpeg", default=shutil.which("ffmpeg") or "ffmpeg")
    parser.add_argument("--ffprobe", default=shutil.which("ffprobe") or "ffprobe")
    args = parser.parse_args()

    project_root = args.project_root.resolve()
    model = args.model.resolve()
    turntable = args.turntable.resolve()
    output = args.output.resolve()
    if not model.is_file():
        raise SystemExit(f"model not found: {model}")
    if not turntable.is_file():
        raise SystemExit(f"turntable not found: {turntable}")
    _validate_glb(model, "model")
    lod_model = args.lod_model.resolve() if args.lod_model else None
    if lod_model is not None:
        if not lod_model.is_file():
            raise SystemExit(f"lod-model not found: {lod_model}")
        _validate_glb(lod_model, "lod-model")
    source_model = args.source_model.resolve() if args.source_model else None
    if source_model is not None:
        if not source_model.is_file():
            raise SystemExit(f"source-model not found: {source_model}")
        _validate_source_model(source_model)
    output.mkdir(parents=True, exist_ok=True)

    frame_count, source_width, source_height = _probe_frames(args.ffprobe, turntable)
    if frame_count < 4:
        raise SystemExit("turntable must contain at least four frames")
    if not 0 <= args.front_frame < frame_count:
        raise SystemExit("front-frame is outside the media frame range")

    frames_dir = output / "frames"
    frames_dir.mkdir(parents=True, exist_ok=True)
    for stale_frame in frames_dir.glob("frame_*.png"):
        stale_frame.unlink()
    _run(
        [
            args.ffmpeg,
            "-y",
            "-v",
            "error",
            "-i",
            str(turntable),
            "-vsync",
            "0",
            "-start_number",
            "0",
            str(frames_dir / "frame_%03d.png"),
        ]
    )
    frame_files = sorted(frames_dir.glob("frame_*.png"))
    if len(frame_files) != frame_count:
        raise SystemExit(f"expected {frame_count} frames, extracted {len(frame_files)}")

    angle_step = 360.0 / frame_count
    frames = []
    direction_sign = 1.0 if args.direction == "clockwise" else -1.0
    for frame_index in range(frame_count):
        relative_index = (frame_index - args.front_frame) % frame_count
        frames.append(
            {
                "frame": frame_index,
                "angle_degrees": round((relative_index * angle_step * direction_sign) % 360.0, 6),
                "path": _resource_path(project_root, frame_files[frame_index]),
                "calibration": {"scale": 1.0, "offset_pixels": [0.0, 0.0]},
            }
        )

    manifest = {
        "schema": "bgo.asset-representations",
        "version": 1,
        "asset_id": args.asset_id,
        "physical_size_cm": {
            "height": args.height_cm,
            "base_diameter": args.base_diameter_cm,
        },
        "world_units_per_cm_fallback": args.world_units_per_cm_fallback,
        "source": {
            "model": _resource_path(project_root, model),
            "turntable": _resource_path(project_root, turntable),
            "turntable_size": [source_width, source_height],
        },
        "selection": {
            "desktop_near_distance": args.near_distance,
            "desktop_near": "desktop_model",
            "desktop_far": "desktop_lod" if lod_model is not None else "billboard",
            "web": "billboard",
            "mobile": "billboard",
            "fallback": "billboard",
        },
        "representations": {
            "desktop_model": {
                "type": "model",
                "path": _resource_path(project_root, model),
                "profile": "desktop_high",
            },
            "billboard": {
                "type": "billboard_frames",
                "profile": "web_mobile",
                "frame_count": frame_count,
                "frame_size": [source_width, source_height],
                "front_frame": args.front_frame,
                "direction": args.direction,
                "front_axis": args.model_front_axis,
                "vertical_offset_cm": args.billboard_vertical_offset_cm,
                "transparent_background": "source_alpha",
                "frames": frames,
            },
        },
    }
    if source_model is not None:
        manifest["source"]["original_model"] = _resource_path(project_root, source_model)
    if lod_model is not None:
        manifest["representations"]["desktop_lod"] = {
            "type": "model",
            "path": _resource_path(project_root, lod_model),
            "profile": "desktop_standard",
        }
    if args.height_cm is None or args.base_diameter_cm is None:
        manifest.pop("physical_size_cm")
    manifest_path = output / "representation.json"
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(manifest_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
